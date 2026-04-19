import '../../services/access_control_service.dart';

class UserData {
  final String username;
  final String password;
  final String role;
  final String teamId;

  const UserData({
    required this.username,
    required this.password,
    required this.role,
    required this.teamId,
  });
}

class LoginController {
  // Data user dengan role dan teamId
  // 'Ketua' punya akses penuh, 'Anggota' terbatas
  final List<UserData> _users = const [
    UserData(username: 'admin',     password: '123', role: UserRole.ketua,    teamId: 'team_041'),
    UserData(username: 'mahasiswa', password: '123', role: UserRole.anggota,  teamId: 'team_041'),
    UserData(username: 'budi',      password: '123', role: UserRole.anggota,  teamId: 'team_041'),
    UserData(username: 'udin',      password: '123', role: UserRole.anggota,  teamId: 'team_045'),
  ];

  // Hitung percobaan gagal
  int failedAttempts = 0;

  // Simpan data user yang berhasil login
  UserData? _loggedInUser;

  UserData? get loggedInUser => _loggedInUser;
  String get currentRole => _loggedInUser?.role ?? UserRole.anggota;
  String get currentTeamId => _loggedInUser?.teamId ?? '';

  bool login(String username, String password) {
    final user = _users.where(
      (u) => u.username == username && u.password == password,
    ).firstOrNull;

    if (user != null) {
      failedAttempts = 0;
      _loggedInUser = user;
      return true;
    } else {
      failedAttempts++;
      return false;
    }
  }

  bool isLocked() => failedAttempts >= 3;

  void resetLock() => failedAttempts = 0;

  void logout() => _loggedInUser = null;
}