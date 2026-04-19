import 'dart:developer' as dev;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

class LogHelper {
  static Future<void> writeLog(
    String message, {
    String source = "Unknown",
    int level = 2,
  }) async {
    final int configLevel = int.tryParse(dotenv.env['LOG_LEVEL'] ?? '2') ?? 2;
    final String muteList = dotenv.env['LOG_MUTE'] ?? '';

    if (level > configLevel) return;
    if (muteList.split(',').map((e) => e.trim()).contains(source)) return;

    try {
      String timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      String label = _getLabel(level);
      String color = _getColor(level);

      dev.log(message, name: source, time: DateTime.now(), level: level * 100);
      print('$color[$timestamp][$label][$source] -> $message\x1B[0m');

      await _writeToFile(message, label: label, source: source);
    } catch (e) {
      dev.log("Logging failed: $e", name: "SYSTEM", level: 1000);
    }
  }

  static Future<void> _writeToFile(
    String message, {
    required String label,
    required String source,
  }) async {
    try {
      final String dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final String timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

      Directory logsDir;

      if (Platform.isAndroid) {
        // Minta permission storage
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Fallback: coba permission biasa
          await Permission.storage.request();
        }

        // Simpan ke Downloads/logbook_logs/ — bisa diakses bebas
        logsDir = Directory('/storage/emulated/0/Download/logbook_logs');
      } else if (Platform.isWindows) {
        logsDir = Directory('${Directory.current.path}\\logs');
      } else {
        logsDir = Directory('${Directory.current.path}/logs');
      }

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final File logFile = File('${logsDir.path}/$dateStr.log');
      final String logLine = '[$timeStr][$label][$source] -> $message\n';
      await logFile.writeAsString(logLine, mode: FileMode.append);

    } catch (e) {
      dev.log("File write failed: $e", name: "LOG_HELPER", level: 1000);
    }
  }

  static String _getLabel(int level) {
    switch (level) {
      case 1: return "ERROR";
      case 2: return "INFO";
      case 3: return "VERBOSE";
      default: return "LOG";
    }
  }

  static String _getColor(int level) {
    switch (level) {
      case 1: return '\x1B[31m';
      case 2: return '\x1B[32m';
      case 3: return '\x1B[34m';
      default: return '\x1B[0m';
    }
  }
}