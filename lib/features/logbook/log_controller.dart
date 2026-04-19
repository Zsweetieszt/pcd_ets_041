import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/mongo_services.dart';
import '../../services/access_control_service.dart';
import 'models/log_model.dart';

class LogController {
  static const String _boxName = 'logs_box';

  // Box khusus untuk menyimpan daftar key yang perlu dihapus dari cloud saat online
  static const String _pendingDeleteBox = 'pending_deletes_box';

  final MongoService _mongo = MongoService();

  final String username;
  final String teamId;

  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<String> searchQuery = ValueNotifier('');

  LogController({required this.username, required this.teamId}) {
    _loadFromHive();
    searchQuery.addListener(_loadFromHive);
  }

  Box<LogModel> get _box => Hive.box<LogModel>(_boxName);

  // HELPER: generate key yang konsisten untuk setiap log
  // Setelah dapat ObjectId dari cloud, kita pakai hex-nya.
  // Sebelum sync, pakai kombinasi username+date agar unik & deterministik.
  String _keyFor(LogModel log) {
    if (log.id != null) return log.id!.toHexString();
    return '${log.username}_${log.date}';
  }

  // LOAD & FILTER
  void _loadFromHive() {
    final query = searchQuery.value.toLowerCase();
    final allLogs = _box.values.toList();

    final visible = allLogs.where((log) {
      final canSee = AccessPolicy.canView(
        currentUsername: username,
        teamId: teamId,
        log: log,
      );
      if (!canSee) return false;
      if (query.isEmpty) return true;
      return log.title.toLowerCase().contains(query) ||
          log.description.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    logsNotifier.value = visible;
  }

  // SYNC FROM CLOUD
  // Hanya ambil data cloud yang BELUM ada di lokal.
  // Data lokal yang belum sync (isSynced==false) TIDAK ditimpa.
  Future<void> syncFromCloud() async {
    try {
      final cloudLogs = await _mongo.getLogs(
        username: username,
        teamId: teamId,
      );

      for (final cloudLog in cloudLogs) {
        final cloudKey = _keyFor(cloudLog);

        // Cek apakah sudah ada di lokal (berdasarkan ObjectId hex)
        final existsById = _box.containsKey(cloudKey);

        // Cek duplikat lama dengan key username_date (sebelum dapat ObjectId)
        final legacyKey = '${cloudLog.username}_${cloudLog.date}';
        final existsByLegacy = _box.containsKey(legacyKey);

        if (existsById) {
          // Sudah ada, skip agar tidak menimpa perubahan lokal yang belum sync
          final localLog = _box.get(cloudKey);
          if (localLog != null && !localLog.isSynced) continue;
          // Kalau sudah sync, aman di-refresh dari cloud
          await _box.put(cloudKey, cloudLog.copyWith(isSynced: true));
        } else if (existsByLegacy) {
          final localLog = _box.get(legacyKey);
          if (localLog != null && !localLog.isSynced) {
            // Belum tersync, hapus legacy key, simpan ulang dengan key baru
            await _box.delete(legacyKey);
            await _box.put(cloudKey, cloudLog.copyWith(isSynced: true));
          } else {
            // Sudah sync, replace dengan versi cloud
            await _box.delete(legacyKey);
            await _box.put(cloudKey, cloudLog.copyWith(isSynced: true));
          }
        } else {
          // Belum ada sama sekali di lokal — tambahkan
          await _box.put(cloudKey, cloudLog.copyWith(isSynced: true));
        }
      }

      _loadFromHive();
    } catch (e) {
      debugPrint("Sync from cloud failed (offline?): $e");
      // Tidak throw — biarkan app tetap jalan dengan data lokal
    }
  }

  // CREATE
  Future<void> addLog(LogModel log) async {
    final key = _keyFor(log);

    // 1. Simpan ke Hive dulu (offline-first), tandai belum sync
    await _box.put(key, log.copyWith(isSynced: false));
    _loadFromHive();

    // 2. Coba upload ke cloud di background
    try {
      await _mongo.insertLog(log);

      // Setelah insert, MongoDB buat ObjectId baru di dalam log.toMap()
      // Kita perlu ambil kembali agar dapat id-nya.
      // Trik: hapus key lama, simpan ulang dengan flag synced.
      // (ObjectId di-generate di toMap(), jadi kita buat ulang dari data yang sama)
      await _box.delete(key);
      await _box.put(key, log.copyWith(isSynced: true));
      _loadFromHive();
    } catch (e) {
      debugPrint("Cloud insert failed, kept in Hive as pending: $e");
      // Data tetap di Hive dengan isSynced=false — akan di-sync nanti
    }
  }

  // UPDATE
  Future<void> updateLog(LogModel updatedLog) async {
    final key = _keyFor(updatedLog);

    // 1. Update Hive dulu
    await _box.put(key, updatedLog.copyWith(isSynced: false));
    _loadFromHive();

    // 2. Coba sync ke cloud
    try {
      if (updatedLog.id != null) {
        await _mongo.updateLog(updatedLog);
      } else {
        // Belum punya ObjectId (belum pernah ke cloud) — insert sebagai baru
        await _mongo.insertLog(updatedLog);
      }
      await _box.put(key, updatedLog.copyWith(isSynced: true));
      _loadFromHive();
    } catch (e) {
      debugPrint("Cloud update failed, kept as pending: $e");
    }
  }

  // DELETE
  // Kalau offline: hapus dari Hive, tapi queue ObjectId untuk dihapus dari cloud nanti.
  // Kalau online: hapus Hive + cloud sekaligus.
  Future<void> removeLog(LogModel log) async {
    final key = _keyFor(log);

    // Hapus dari Hive lokal
    await _box.delete(key);
    _loadFromHive();

    if (log.id != null) {
      // Coba hapus dari cloud
      try {
        await _mongo.deleteLog(log.id!);
      } catch (e) {
        debugPrint("Cloud delete failed, queueing for later: $e");
        // Simpan ObjectId hex ke pending-delete box agar dihapus saat online kembali
        await _enqueuePendingDelete(log.id!.toHexString());
      }
    }
    // Kalau log.id == null berarti belum pernah ke cloud — tidak perlu hapus cloud
  }

  // PENDING DELETE QUEUE
  Future<void> _enqueuePendingDelete(String objectIdHex) async {
    // Simpan sebagai entry di box terpisah (key = objectIdHex, value = dummy string)
    final box = await Hive.openBox<String>(_pendingDeleteBox);
    await box.put(objectIdHex, objectIdHex);
    debugPrint("Queued pending delete: $objectIdHex");
  }

  Future<void> _flushPendingDeletes() async {
    try {
      final box = await Hive.openBox<String>(_pendingDeleteBox);
      final keys = box.keys.toList();
      for (final key in keys) {
        try {
          final hexId = box.get(key as String);
          if (hexId != null) {
            // Parse ObjectId dari hex string
            final mongo = MongoService();
            // Gunakan _mongo yang sudah ada (singleton)
            await _mongo.deleteLogByHex(hexId);
            await box.delete(key);
            debugPrint("Flushed pending delete: $hexId");
          }
        } catch (e) {
          debugPrint("Failed to flush delete $key: $e");
          // Biarkan di queue, coba lagi nanti
        }
      }
    } catch (e) {
      debugPrint("Cannot open pending_deletes_box: $e");
    }
  }

  // SYNC PENDING LOGS (dipanggil saat kembali online)
  // Handles: insert/update yang pending + pending deletes
  Future<void> syncPendingLogs() async {
    // 1. Flush pending deletes dulu
    await _flushPendingDeletes();

    // 2. Sync log yang belum ter-upload / ter-update ke cloud
    final pending = _box.values.where((log) => !log.isSynced).toList();

    for (final log in pending) {
      try {
        final key = _keyFor(log);

        if (log.id != null) {
          // Sudah pernah ke cloud sebelumnya → update
          await _mongo.updateLog(log);
        } else {
          // Belum pernah ke cloud → insert baru
          await _mongo.insertLog(log);
        }

        // Tandai sudah sync
        await _box.put(key, log.copyWith(isSynced: true));
        debugPrint("Synced pending log: '${log.title}'");
      } catch (e) {
        debugPrint("Pending sync failed for '${log.title}': $e");
        // Biarkan isSynced=false, coba lagi next time
      }
    }

    _loadFromHive();
  }

  // FORMAT DATE
  static String formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void dispose() {
    searchQuery.removeListener(_loadFromHive);
    searchQuery.dispose();
    logsNotifier.dispose();
  }
}