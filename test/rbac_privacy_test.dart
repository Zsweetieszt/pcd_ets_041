import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/access_control_service.dart';

void main() {

  // Catatan PRIVATE milik User A (anggota biasa)
  final privateLogByUserA = LogModel(
    title: 'Catatan Rahasia Rancangan PCB',
    description: '# Desain Sensor\nSkema **rahasia** belum dipublikasikan.',
    date: '1 Jan 2025, 10:00',
    username: 'user_a',
    category: 'Electronic',
    authorId: 'user_a',
    teamId: 'team_041',
    isPublic: false,
    isSynced: true,
  );

  // Catatan PUBLIC milik User A
  final publicLogByUserA = LogModel(
    title: 'Progress Mingguan Tim',
    description: 'Update kemajuan sprint bisa dilihat semua.',
    date: '2 Jan 2025, 09:00',
    username: 'user_a',
    category: 'Organisasi',
    authorId: 'user_a',
    teamId: 'team_041',
    isPublic: true,
    isSynced: true,
  );

  // Catatan PRIVATE milik Ketua
  final privateLogByKetua = LogModel(
    title: 'Evaluasi Rahasia Anggota',
    description: 'Penilaian internal tidak untuk disebarkan.',
    date: '3 Jan 2025, 08:00',
    username: 'ketua',
    category: 'Organisasi',
    authorId: 'ketua',
    teamId: 'team_041',
    isPublic: false,
    isSynced: true,
  );

// GROUP 1: Task 5 Visibility — "CanView Logic"
  group('Task 5 — Visibility (canView)', () {

    test('Pemilik selalu bisa melihat catatan PRIVATE miliknya sendiri', () {
      final result = AccessPolicy.canView(
        currentUsername: 'user_a',
        teamId: 'team_041',
        log: privateLogByUserA,
      );
      expect(result, isTrue,
          reason: 'User A harus bisa lihat catatan privatenya sendiri');
    });

    test('User B (rekan tim) TIDAK boleh melihat catatan PRIVATE User A', () {
      final result = AccessPolicy.canView(
        currentUsername: 'user_b',
        teamId: 'team_041',
        log: privateLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Catatan Private hanya boleh dilihat pemiliknya');
    });

    test('Ketua TIDAK boleh melihat catatan PRIVATE anggota', () {
      final result = AccessPolicy.canView(
        currentUsername: 'ketua',
        teamId: 'team_041',
        log: privateLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Sovereignty: Ketua pun tidak berhak akses catatan private anggota');
    });

    test('Catatan PUBLIC boleh dilihat semua anggota tim yang sama', () {
      for (final user in ['user_b', 'user_c', 'ketua']) {
        final result = AccessPolicy.canView(
          currentUsername: user,
          teamId: 'team_041',
          log: publicLogByUserA,
        );
        expect(result, isTrue,
            reason: '$user harus bisa lihat catatan public dari tim yang sama');
      }
    });

    test('Anggota tim LAIN tidak boleh lihat catatan PUBLIC tim ini', () {
      final result = AccessPolicy.canView(
        currentUsername: 'outsider',
        teamId: 'team_999',  // Tim berbeda
        log: publicLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Catatan public hanya untuk tim yang sama');
    });
  });

  // GROUP 2: Task 5 Sovereignty — "Owner-Only Edit/Delete"

  group('Task 5 — Sovereignty (canPerform update/delete)', () {

    test('Pemilik bisa mengedit catatannya sendiri', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'user_a',
        currentRole: UserRole.anggota,
        action: LogAction.update,
        log: privateLogByUserA,
      );
      expect(result, isTrue);
    });

    test('Pemilik bisa menghapus catatannya sendiri', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'user_a',
        currentRole: UserRole.anggota,
        action: LogAction.delete,
        log: privateLogByUserA,
      );
      expect(result, isTrue);
    });

    test('Ketua TIDAK boleh mengedit catatan milik anggota lain', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'ketua',
        currentRole: UserRole.ketua,
        action: LogAction.update,
        log: privateLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Task 5 Sovereignty: Ketua tidak punya hak edit catatan anggota');
    });

    test('Ketua TIDAK boleh mengedit catatan PUBLIC milik anggota lain', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'ketua',
        currentRole: UserRole.ketua,
        action: LogAction.update,
        log: publicLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Task 5 Sovereignty: catatan public pun bukan milik Ketua, tidak boleh diedit');
    });


    test('Ketua TIDAK boleh menghapus catatan milik anggota lain', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'ketua',
        currentRole: UserRole.ketua,
        action: LogAction.delete,
        log: privateLogByUserA,
      );
      expect(result, isFalse,
          reason: 'Task 5 Sovereignty: Ketua tidak punya hak hapus catatan anggota');
    });

    test('Anggota lain tidak boleh mengedit catatan bukan miliknya', () {
      final result = AccessPolicy.canPerform(
        currentUsername: 'user_b',
        currentRole: UserRole.anggota,
        action: LogAction.update,
        log: privateLogByUserA,
      );
      expect(result, isFalse);
    });

    test('Semua user boleh membuat catatan baru (create)', () {
      for (final role in [UserRole.ketua, UserRole.anggota]) {
        final result = AccessPolicy.canPerform(
          currentUsername: 'anyone',
          currentRole: role,
          action: LogAction.create,
        );
        expect(result, isTrue);
      }
    });
  });

  // GROUP 3: Ownership check

  group('isOwner — validasi kepemilikan', () {

    test('isOwner benar berdasarkan username', () {
      expect(
        AccessPolicy.isOwner(currentUsername: 'user_a', log: privateLogByUserA),
        isTrue,
      );
    });

    test('isOwner benar berdasarkan authorId', () {
      final logWithDifferentUsername = LogModel(
        title: 'Test',
        description: '',
        date: '1 Jan 2025',
        username: 'old_username',
        category: 'Umum',
        authorId: 'user_a',
        teamId: 'team_041',
        isPublic: false,
        isSynced: false,
      );
      expect(
        AccessPolicy.isOwner(currentUsername: 'user_a', log: logWithDifferentUsername),
        isTrue,
      );
    });

    test('isOwner false untuk user yang bukan pemilik', () {
      expect(
        AccessPolicy.isOwner(currentUsername: 'user_b', log: privateLogByUserA),
        isFalse,
      );
    });
  });
}