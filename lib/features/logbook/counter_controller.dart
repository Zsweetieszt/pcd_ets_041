// File: lib/features/logbook/counter_controller.dart
import 'dart:convert'; // Untuk mengubah List jadi Teks JSON
import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  int _counter = 0;
  int _step = 1;
  // Hapus 'final' agar bisa di-update saat load data
  List<Map<String, String>> _history = []; 

  int get value => _counter;
  List<Map<String, String>> get history => List.unmodifiable(_history);

  // Fungsi Load Data (Dipanggil saat layar dibuka)
  // Kita butuh 'key' yang unik per user, jadi kita minta parameter username
  Future<void> loadData(String username) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Ambil Angka Terakhir
    // Key-nya misal: 'counter_admin' atau 'counter_budi'
    _counter = prefs.getInt('counter_$username') ?? 0;

    // 2. Ambil Riwayat
    String? historyString = prefs.getString('history_$username');
    if (historyString != null) {
      // Ubah teks JSON kembali menjadi List
      List<dynamic> decodedList = jsonDecode(historyString);
      // Pastikan format datanya benar (Map<String, String>)
      _history = decodedList.map((item) => Map<String, String>.from(item)).toList();
    }
  }

  // Fungsi Save Data (Dipanggil setiap kali ada perubahan)
  Future<void> _saveData(String username) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Simpan Angka
    await prefs.setInt('counter_$username', _counter);
    
    // Simpan Riwayat (Ubah List jadi Teks JSON dulu)
    String historyString = jsonEncode(_history);
    await prefs.setString('history_$username', historyString);
  }

  // --- Fungsi Logika (Diupdate untuk auto-save) ---

  void updateStep(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed != 0) {
      _step = parsed;
    }
  }
  
  // Kita butuh username di sini untuk tahu data siapa yang disimpan
  Future<void> increment(String username) async {
  _counter += _step;
  _addHistory("Menambah $_step", 'add', username);
  await _saveData(username); // Auto Save
}

Future<void> decrement(String username) async {
  if (_counter - _step >= 0) {
    _counter -= _step;
  } else {
    _counter = 0;
  }
  _addHistory("Mengurangi $_step", 'subtract', username);
  await _saveData(username);
}

Future<void> reset(String username) async {
  _counter = 0;
  _addHistory("Reset counter", 'reset', username);
  await _saveData(username); // Auto Save
}
  
  void _addHistory(String action, String type, String username) {
    final time = DateTime.now();
    final formattedTime =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    _history.insert(0, { // Gunakan insert(0) agar yang baru ada di atas
      'action': "$action pada jam $formattedTime",
      'type': type,
      'time': formattedTime,
    });

    if (_history.length > 5) {
      _history.removeLast();
    }
  }
}