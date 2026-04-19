import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import package markdown

import 'log_controller.dart';
import 'log_editor_page.dart';
import 'counter_view.dart';
import 'models/log_model.dart';
import '../../services/access_control_service.dart';
import '../onboarding/onboarding_view.dart';

class LogView extends StatefulWidget {
  final String username;
  final String role;
  final String teamId;

  const LogView({
    super.key,
    required this.username,
    required this.role,
    required this.teamId,
  });

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late LogController _controller;
  final TextEditingController _searchTextController = TextEditingController();

  bool _isOnline = true;
  bool _isSyncing = false;

  // Subscription & timer untuk deteksi koneksi yang reliable
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _controller = LogController(
      username: widget.username,
      teamId: widget.teamId,
    );

    // Cek status awal, lalu pasang listener + timer
    _initConnectivity();

    _searchTextController.addListener(() {
      _controller.searchQuery.value = _searchTextController.text;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityTimer?.cancel();
    _searchTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // CONNECTIVITY: inisialisasi, listener, dan timer fallback
  // ─────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    // 1. Cek status awal secara aktual (bukan hanya sinyal WiFi)
    final online = await _checkRealInternet();
    if (mounted) setState(() => _isOnline = online);

    // Jika online dari awal, langsung sync
    if (online) _syncFromCloud();

    // 2. Listen ke perubahan tipe koneksi (WiFi ↔ Mobile ↔ None)
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // 3. Timer fallback setiap 5 detik — untuk kasus di mana
    //    connectivity_plus tidak fire event (terutama Android)
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollInternetStatus(),
    );
  }

  /// Cek koneksi internet sesungguhnya lewat DNS lookup.
  /// Mengembalikan true jika benar-benar bisa akses internet.
  Future<bool> _checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Dipanggil oleh stream connectivity_plus saat tipe koneksi berubah.
  /// Tipe koneksi berubah != internet tersedia, jadi tetap verifikasi lewat DNS.
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasNetworkInterface = results.any((r) => r != ConnectivityResult.none);

    if (!hasNetworkInterface) {
      // Jaringan jelas putus — langsung tandai offline
      _applyOnlineStatus(false);
    } else {
      // Ada sinyal, tapi verifikasi dulu apakah benar-benar bisa internet
      final online = await _checkRealInternet();
      _applyOnlineStatus(online);
    }
  }

  /// Polling periodik — sebagai fallback agar deteksi tetap akurat
  /// di device yang connectivity stream-nya lambat/tidak reliable.
  Future<void> _pollInternetStatus() async {
    if (!mounted) return;
    final online = await _checkRealInternet();
    if (online != _isOnline) {
      // Status berubah → terapkan
      _applyOnlineStatus(online);
    }
  }

  /// Terapkan status online/offline ke UI, dan trigger auto-sync jika perlu.
  void _applyOnlineStatus(bool nowOnline) {
    if (!mounted) return;
    final wasOffline = !_isOnline;

    if (_isOnline == nowOnline) return; // tidak ada perubahan, skip

    setState(() => _isOnline = nowOnline);

    if (nowOnline && wasOffline) {
      // ✅ Baru kembali online → auto-sync tanpa perlu refresh manual
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Koneksi kembali! Menyinkronkan data...'),
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // Jalankan sync di background — tidak perlu await di sini
      _syncPending().then((_) => _syncFromCloud());
    } else if (!nowOnline) {
      // ❌ Baru offline
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Koneksi terputus. Mode Offline aktif.'),
          ]),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _syncFromCloud() async {
    if (!_isOnline) return;
    if (mounted) setState(() => _isSyncing = true);
    await _controller.syncFromCloud();
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _syncPending() async {
    if (!_isOnline) return;
    if (mounted) setState(() => _isSyncing = true);
    await _controller.syncPendingLogs();
    if (mounted) setState(() => _isSyncing = false);
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Organisasi':
        return Colors.blue;
      case 'Tugas':
        return Colors.orange;
      case 'Kuliah':
        return Colors.green;
      case 'Pribadi':
        return Colors.purple;
      case 'Urgent':
        return Colors.red;
      case 'Mechanical':
        return Colors.teal;
      case 'Electronic':
        return Colors.blueAccent;
      case 'Software':
        return Colors.deepPurple;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatRelativeTime(String dateStr) {
    try {
      final parsed = DateFormat("d MMM yyyy, HH:mm", "id").parse(dateStr);
      final diff = DateTime.now().difference(parsed);
      if (diff.inSeconds < 60) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return DateFormat("d MMM yyyy", "id").format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _openEditor({LogModel? existing}) async {
    // Tampilkan peringatan jika offline (tetap bisa tambah/edit, tersimpan lokal)
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mode Offline: Catatan tersimpan di perangkat dan akan disinkronkan saat online.',
              ),
            ),
          ]),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }

    final result = await Navigator.push<LogModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditorPage(
          existingLog: existing,
          username: widget.username,
          teamId: widget.teamId,
        ),
      ),
    );

    if (result != null) {
      if (existing != null) {
        await _controller.updateLog(result);
      } else {
        await _controller.addLog(result);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(
              _isOnline ? Icons.cloud_done : Icons.save,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(existing != null
                ? (_isOnline
                    ? 'Catatan berhasil diperbarui & disinkronkan'
                    : 'Catatan diperbarui (akan sync saat online)')
                : (_isOnline
                    ? 'Catatan berhasil ditambahkan & disinkronkan'
                    : 'Catatan tersimpan lokal (akan sync saat online)')),
          ]),
          backgroundColor: _isOnline ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> _deleteLog(LogModel log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${log.title}" akan dihapus permanen.'),
            if (!_isOnline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.wifi_off,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mode Offline: Penghapusan dari cloud akan dilakukan saat online kembali.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _controller.removeLog(log);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isOnline
                ? '"${log.title}" dihapus'
                : '"${log.title}" dihapus dari perangkat (cloud sync pending)',
          ),
          backgroundColor:
              _isOnline ? Colors.red.shade400 : Colors.orange.shade600,
        ));
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingView()),
                (route) => false,
              );
            },
            child: const Text('Ya, Keluar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearching}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: isSearching
                  ? Lottie.network(
                      'https://assets1.lottiefiles.com/packages/lf20_wnqlfojb.json',
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.search_off_rounded,
                        size: 80,
                        color: Colors.orange.shade300,
                      ),
                    )
                  : Lottie.network(
                      'https://assets9.lottiefiles.com/packages/lf20_qp1q7mct.json',
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.menu_book_rounded,
                        size: 80,
                        color: Colors.indigo.shade200,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'Catatan tidak ditemukan'
                  : 'Belum ada aktivitas hari ini?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Coba kata kunci yang berbeda'
                  : 'Mulai catat kemajuan proyek Anda!\nKetuk tombol + di bawah untuk memulai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                height: 1.6,
                fontSize: 14,
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Buat Catatan Pertama'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logbook: ${widget.username}',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _isSyncing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: _isOnline
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                    tooltip: _isOnline
                        ? 'Tersinkron ke Cloud, Ketuk untuk refresh'
                        : 'Offline — Data tersimpan di perangkat',
                    onPressed: _isOnline ? _syncFromCloud : null,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CounterView(username: widget.username),
              ),
            ),
            tooltip: 'Counter',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Header: greeting + role badge ──
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getGreeting(),
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.indigo.shade400)),
                    Text(widget.username,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.role == UserRole.ketua
                        ? Colors.amber.shade100
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.role == UserRole.ketua
                          ? Colors.amber
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      widget.role == UserRole.ketua
                          ? Icons.star
                          : Icons.person,
                      size: 14,
                      color: widget.role == UserRole.ketua
                          ? Colors.amber.shade700
                          : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.role,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.role == UserRole.ketua
                            ? Colors.amber.shade700
                            : Colors.blue,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Offline Banner (lebih informatif) ──
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                border: Border(
                  bottom: BorderSide(
                      color: Colors.orange.shade300, width: 1),
                ),
              ),
              child: Row(children: [
                Icon(Icons.wifi_off,
                    size: 16, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode Offline — Perubahan tersimpan di perangkat & akan disinkronkan otomatis saat koneksi pulih.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]),
            ),

          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: ValueListenableBuilder<String>(
              valueListenable: _controller.searchQuery,
              builder: (_, query, __) => TextField(
                controller: _searchTextController,
                decoration: InputDecoration(
                  hintText: 'Cari judul atau isi catatan...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchTextController.clear();
                            _controller.searchQuery.value = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ),
          ),

          // ── Log List ──
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.logsNotifier,
              builder: (context, logs, _) {
                final isSearching =
                    _controller.searchQuery.value.isNotEmpty;

                if (logs.isEmpty) {
                  return _buildEmptyState(isSearching: isSearching);
                }

                return RefreshIndicator(
                  onRefresh: _syncFromCloud,
                  color: Colors.indigo,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final catColor = _getCategoryColor(log.category);

                      final canEdit = AccessPolicy.canPerform(
                        currentUsername: widget.username,
                        currentRole: widget.role,
                        action: LogAction.update,
                        log: log,
                      );
                      final canDelete = AccessPolicy.canPerform(
                        currentUsername: widget.username,
                        currentRole: widget.role,
                        action: LogAction.delete,
                        log: log,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border(
                                left: BorderSide(
                                    color: catColor, width: 5)),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor:
                                  catColor.withValues(alpha: 0.2),
                              child: Text('${index + 1}',
                                  style: TextStyle(
                                      color: catColor,
                                      fontWeight:
                                          FontWeight.bold)),
                            ),
                            title: Text(log.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (log.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  // Menggunakan MarkdownBody dan menghapus maxLines
                                  MarkdownBody(
                                    data: log.description,
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                      listBullet: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                      h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    // Category chip
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                          color: catColor,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  20)),
                                      child: Text(log.category,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                    // Public/Private chip
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: log.isPublic
                                            ? Colors.green.shade50
                                            : Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(
                                                20),
                                        border: Border.all(
                                          color: log.isPublic
                                              ? Colors.green.shade300
                                              : Colors
                                                  .grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(
                                              log.isPublic
                                                  ? Icons.public
                                                  : Icons.lock,
                                              size: 10,
                                              color: log.isPublic
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(
                                                width: 3),
                                            Text(
                                              log.isPublic
                                                  ? 'Publik'
                                                  : 'Privat',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: log.isPublic
                                                      ? Colors.green
                                                      : Colors.grey),
                                            ),
                                          ]),
                                    ),
                                    // Sync status + time
                                    Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Icon(
                                            log.isSynced
                                                ? Icons.cloud_done
                                                : Icons.cloud_upload,
                                            size: 12,
                                            color: log.isSynced
                                                ? Colors
                                                    .green.shade400
                                                : Colors
                                                    .orange.shade400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.isSynced
                                                ? _formatRelativeTime(
                                                    log.date)
                                                : 'Pending sync',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: log.isSynced
                                                    ? Colors
                                                        .grey.shade400
                                                    : Colors.orange
                                                        .shade600),
                                          ),
                                        ]),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              children: [
                                if (canEdit)
                                  IconButton(
                                    icon: Icon(Icons.edit,
                                        color: catColor,
                                        size: 20),
                                    onPressed: () =>
                                        _openEditor(existing: log),
                                    tooltip: 'Edit',
                                  ),
                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () =>
                                        _deleteLog(log),
                                    tooltip: 'Hapus',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}