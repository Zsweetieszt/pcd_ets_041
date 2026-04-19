import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/services/mongo_services.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';

void main() {
  group('Module 4 - Save Data to Cloud (MongoService)', () {
    late MongoService mongoService;

    // Data uji — pakai teamId khusus testing agar tidak campur data produksi
    const testTeamId = 'team_test_modul6';
    const testUsername = 'test_modul6';

    setUpAll(() async {
      // (1) setup global: load env dan koneksi sekali untuk semua test
      await dotenv.load(fileName: ".env");
      mongoService = MongoService();
      await mongoService.connect();
    });

    tearDownAll(() async {
      // Bersihkan data uji setelah semua test selesai
      await mongoService.close();
    });

    // Helper: buat LogModel uji
    LogModel _makeTestLog({
      String title = 'Test Log Modul 6',
      String description = 'Deskripsi uji coba',
      String category = 'Umum',
    }) {
      return LogModel(
        title: title,
        description: description,
        category: category,
        date: '1 Jan 2025, 00:00',
        username: testUsername,
        authorId: testUsername,
        teamId: testTeamId,
        isPublic: false,
        isSynced: false,
      );
    }

    //  TC-CLOUD-01: Path A — Insert log baru ke cloud 
    // Flow: insertLog() → _getSafeCollection() → collection.insertOne(log.toMap())
    test('TC-CLOUD-01 - insertLog should save log to MongoDB Atlas', () async {
      // (1) arrange
      final log = _makeTestLog(title: 'TC-CLOUD-01 Insert Test');

      // (2) exercise
      // insertLog tidak throw berarti berhasil
      expect(
        () async => await mongoService.insertLog(log),
        returnsNormally,
        reason: 'insertLog harus berhasil tanpa throw exception',
      );
    }, tags: ['cloud']);

    //  TC-CLOUD-02: Path A — getLogs berdasarkan teamId ─
    // Flow: getLogs(teamId) → query where.eq('teamId', teamId) → return List<LogModel>
    test('TC-CLOUD-02 - getLogs should return logs filtered by teamId', () async {
      // (1) arrange: insert dulu agar ada data
      final log = _makeTestLog(title: 'TC-CLOUD-02 GetLogs Test');
      await mongoService.insertLog(log);

      // (2) exercise
      final logs = await mongoService.getLogs(teamId: testTeamId);

      // (3) verify
      expect(logs, isA<List<LogModel>>(),
          reason: 'getLogs harus mengembalikan List<LogModel>');
      expect(logs.isNotEmpty, isTrue,
          reason: 'Harus ada minimal 1 log setelah insert');

      final found = logs.any((l) => l.title.contains('TC-CLOUD-02'));
      expect(found, isTrue,
          reason: 'Log yang baru diinsert harus ada di hasil getLogs');

      // Semua log harus punya teamId yang sesuai filter
      for (final l in logs) {
        expect(l.teamId, equals(testTeamId),
            reason: 'Semua log harus berasal dari teamId yang sama');
      }
    }, tags: ['cloud']);

    //  TC-CLOUD-03: Path B — Update log yang sudah ada ─
    // Flow: updateLog(log dengan id) → replaceOne(where.id(log.id!), log.toMap())
    test('TC-CLOUD-03 - updateLog should modify existing log in cloud', () async {
      // (1) arrange: insert log lalu ambil id-nya
      final log = _makeTestLog(title: 'TC-CLOUD-03 Before Update');
      await mongoService.insertLog(log);

      // ambil log dari cloud untuk dapat ObjectId
      final logsBeforeUpdate = await mongoService.getLogs(teamId: testTeamId);
      final insertedLog = logsBeforeUpdate
          .firstWhere((l) => l.title.contains('TC-CLOUD-03 Before Update'));

      expect(insertedLog.id, isNotNull,
          reason: 'Log dari cloud harus punya ObjectId');

      // (2) exercise: update judulnya
      final updatedLog = insertedLog.copyWith(
        title: 'TC-CLOUD-03 After Update',
        isSynced: false,
      );
      await mongoService.updateLog(updatedLog);

      // (3) verify: ambil ulang dan cek apakah sudah berubah
      final logsAfterUpdate = await mongoService.getLogs(teamId: testTeamId);
      final afterUpdate = logsAfterUpdate
          .any((l) => l.title.contains('TC-CLOUD-03 After Update'));

      expect(afterUpdate, isTrue,
          reason: 'Judul log harus berubah setelah updateLog');
    }, tags: ['cloud']);

    //  TC-CLOUD-04: Path B — Delete log berdasarkan ObjectId ─
    // Flow: deleteLog(id) → collection.remove(where.id(id))
    test('TC-CLOUD-04 - deleteLog should remove log from cloud', () async {
      // (1) arrange: insert log baru untuk dihapus
      final log = _makeTestLog(title: 'TC-CLOUD-04 Will Be Deleted');
      await mongoService.insertLog(log);

      // ambil log dari cloud untuk dapat ObjectId
      final logsBefore = await mongoService.getLogs(teamId: testTeamId);
      final toDelete = logsBefore
          .firstWhere((l) => l.title.contains('TC-CLOUD-04 Will Be Deleted'));

      expect(toDelete.id, isNotNull);

      // (2) exercise
      await mongoService.deleteLog(toDelete.id!);

      // (3) verify: log tidak ada lagi
      final logsAfter = await mongoService.getLogs(teamId: testTeamId);
      final stillExists = logsAfter
          .any((l) => l.title.contains('TC-CLOUD-04 Will Be Deleted'));

      expect(stillExists, isFalse,
          reason: 'Log harus sudah terhapus dari MongoDB setelah deleteLog');
    }, tags: ['cloud']);

    //  TC-CLOUD-05: Path C — getLogs filter by username ─
    test('TC-CLOUD-05 - getLogs by username should return only that user logs', () async {
      // (1) arrange: insert log dengan username spesifik
      final log = _makeTestLog(title: 'TC-CLOUD-05 Username Filter');
      await mongoService.insertLog(log);

      // (2) exercise
      final logs = await mongoService.getLogs(username: testUsername);

      // (3) verify
      expect(logs.isNotEmpty, isTrue);
      for (final l in logs) {
        expect(l.username, equals(testUsername));
      }
    }, tags: ['cloud']);
  });
}