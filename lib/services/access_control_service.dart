import '../features/logbook/models/log_model.dart';

class UserRole {
  static const String ketua   = 'Ketua';
  static const String anggota = 'Anggota';
}

class LogAction {
  static const String create = 'create';
  static const String read   = 'read';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Policy Manager terpusat
class AccessPolicy {
  static bool canPerform({
    required String currentUsername,
    required String currentRole,
    required String action,
    LogModel? log,
  }) {
    switch (action) {

      // Semua orang boleh membuat catatan baru
      case LogAction.create:
        return true;

      // Boleh baca jika pemilik, atau catatan publik
      case LogAction.read:
        if (log == null) return true;
        return isOwner(currentUsername: currentUsername, log: log) || log.isPublic;

       // Update: hanya pemilik catatan yang boleh edit
      case LogAction.update:
        if (log == null) return false;
        return isOwner(currentUsername: currentUsername, log: log);

      // Delete: hanya pemilik catatan yang boleh hapus
      case LogAction.delete:
        if (log == null) return false;
        return isOwner(currentUsername: currentUsername, log: log);

      default:
        return false;
    }
  }

  /// Cek kepemilikan catatan
  static bool isOwner({required String currentUsername, required LogModel log}) {
    return log.username == currentUsername || log.authorId == currentUsername;
  }

  // Cek apakah user bisa melihat catatan
  static bool canView({
    required String currentUsername,
    required String teamId,
    required LogModel log,
  }) {
    if (isOwner(currentUsername: currentUsername, log: log)) return true;
    if (log.isPublic && log.teamId == teamId) return true;
    return false;
  }
}