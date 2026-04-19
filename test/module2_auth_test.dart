import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/auth/login_controller.dart';

void main() {
  group('Module 2 - Authentication (LoginController)', () {
    late LoginController controller;

    setUp(() {
      // (1) setup (arrange, build) — fresh controller sebelum setiap test
      controller = LoginController();
    });

    // ─ TC-AUTH-01: Path 1 — Login berhasil (kredensial valid) ─
    // Flow: login() → user != null → failedAttempts=0 → simpan _loggedInUser → return true
    test('TC-AUTH-01 - valid credentials should return true and set logged-in user', () {
      // (2) exercise (act, operate)
      final result = controller.login('admin', '123');

      // (3) verify (assert, check)
      expect(result, isTrue,
          reason: 'Login dengan kredensial valid harus return true');
      expect(controller.loggedInUser, isNotNull,
          reason: 'loggedInUser harus terisi setelah login sukses');
      expect(controller.loggedInUser?.username, equals('admin'),
          reason: 'Username harus sesuai user yang login');
      expect(controller.currentRole, equals('Ketua'),
          reason: 'Role admin harus Ketua');
      expect(controller.failedAttempts, equals(0),
          reason: 'failedAttempts harus direset ke 0 setelah login sukses');
    });

    // ─ TC-AUTH-02: Path 1 variasi — login anggota biasa ─
    test('TC-AUTH-02 - member login should return correct role', () {
      // (2) exercise
      final result = controller.login('mahasiswa', '123');

      // (3) verify
      expect(result, isTrue);
      expect(controller.currentRole, equals('Anggota'),
          reason: 'Role mahasiswa harus Anggota, bukan Ketua');
      expect(controller.currentTeamId, equals('team_041'),
          reason: 'TeamId harus sesuai data user');
    });

    // ─ TC-AUTH-03: Path 2 — Login gagal, belum terkunci ─
    // Flow: login() → user == null → failedAttempts++ → isLocked() false → return false
    test('TC-AUTH-03 - wrong password should return false and increment failedAttempts', () {
      // (2) exercise: login dengan password salah
      final result = controller.login('admin', 'salah');

      // (3) verify
      expect(result, isFalse,
          reason: 'Login dengan password salah harus return false');
      expect(controller.failedAttempts, equals(1),
          reason: 'failedAttempts harus bertambah 1 setelah gagal login');
      expect(controller.isLocked(), isFalse,
          reason: 'Akun belum terkunci setelah 1x gagal');
      expect(controller.loggedInUser, isNull,
          reason: 'loggedInUser harus tetap null setelah login gagal');
    });

    // ─ TC-AUTH-04: Path 2 variasi — username tidak ditemukan 
    test('TC-AUTH-04 - unknown username should return false', () {
      // (2) exercise
      final result = controller.login('user_tidak_ada', '123');

      // (3) verify
      expect(result, isFalse);
      expect(controller.failedAttempts, equals(1));
      expect(controller.isLocked(), isFalse);
    });

    // ─ TC-AUTH-05: Path 3 — Akun terkunci setelah 3x gagal ─
    // Flow: login() gagal 3x → failedAttempts >= 3 → isLocked() = true
    test('TC-AUTH-05 - account should be locked after 3 failed attempts', () {
      // (1) arrange: gagalkan login 3x
      controller.login('admin', 'salah1');
      controller.login('admin', 'salah2');
      controller.login('admin', 'salah3');

      // (2) exercise
      final lockedStatus = controller.isLocked();

      // (3) verify
      expect(lockedStatus, isTrue,
          reason: 'Akun harus terkunci setelah 3x gagal login');
      expect(controller.failedAttempts, equals(3));
    });

    // ─ TC-AUTH-06: resetLock harus membuka kunci 
    test('TC-AUTH-06 - resetLock should unlock account', () {
      // (1) arrange: kunci akun dulu
      controller.login('admin', 'salah');
      controller.login('admin', 'salah');
      controller.login('admin', 'salah');
      expect(controller.isLocked(), isTrue); // pastikan terkunci

      // (2) exercise
      controller.resetLock();

      // (3) verify
      expect(controller.isLocked(), isFalse,
          reason: 'Akun harus terbuka setelah resetLock()');
      expect(controller.failedAttempts, equals(0));
    });

    // ─ TC-AUTH-07: logout harus clear loggedInUser 
    test('TC-AUTH-07 - logout should clear logged-in user', () {
      // (1) arrange: login dulu
      controller.login('admin', '123');
      expect(controller.loggedInUser, isNotNull);

      // (2) exercise
      controller.logout();

      // (3) verify
      expect(controller.loggedInUser, isNull,
          reason: 'loggedInUser harus null setelah logout');
      expect(controller.currentRole, equals('Anggota'),
          reason: 'Role default (saat tidak login) adalah Anggota');
    });
  });
}