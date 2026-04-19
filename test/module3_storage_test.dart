import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_001/features/logbook/counter_controller.dart';

void main() {
  group('Module 3 - Save Data to Disk (SharedPreferences)', () {
    const username = 'test_user';

    setUp(() async {
      // Sebelum setiap test, reset storage ke kondisi kosong
      SharedPreferences.setMockInitialValues({});
    });

    //  TC-DISK-01: Path 1 — Load dari storage kosong → nilai default 0 
    // Flow: loadData() → prefs.getInt('counter_$username') = null → _counter = 0
    test('TC-DISK-01 - loadData on empty storage should return default value 0', () async {
      // (1) arrange
      final controller = CounterController();

      // (2) exercise
      await controller.loadData(username);

      // (3) verify
      expect(controller.value, equals(0),
          reason: 'Nilai counter harus 0 saat storage kosong (pakai ?? 0)');
    });

    //  TC-DISK-02: Path 2 — Data tersimpan dan bisa dimuat ulang ─
    // Flow: increment() → _saveData() → loadData() pada controller baru → nilai terbaca
    test('TC-DISK-02 - data should persist after save and reload', () async {
      // (1) arrange: increment 3x dengan step 1
      final controller = CounterController();
      await controller.loadData(username);
      controller.updateStep('3');
      await controller.increment(username); // counter = 3, auto-save
      
      // buat controller baru (simulasi app restart)
      final freshController = CounterController();

      // (2) exercise
      await freshController.loadData(username);

      // (3) verify
      expect(freshController.value, equals(3),
          reason: 'Data counter harus tetap 3 setelah dimuat ulang dari SharedPreferences');
    });

    //  TC-DISK-03: Path 2 variasi — history tersimpan dan bisa dimuat ──
    test('TC-DISK-03 - history should persist after reload', () async {
      // (1) arrange
      final controller = CounterController();
      await controller.loadData(username);
      controller.updateStep('1');
      await controller.increment(username);
      await controller.increment(username); // 2 entri history

      // (2) exercise: muat ulang di controller baru
      final freshController = CounterController();
      await freshController.loadData(username);

      // (3) verify
      expect(freshController.history.isNotEmpty, isTrue,
          reason: 'History harus termuat dari SharedPreferences');
      expect(freshController.history.length, lessThanOrEqualTo(5),
          reason: 'History tidak boleh melebihi 5 item');
    });

    //  TC-DISK-04: Path 3 — Data per-user terpisah (tidak saling campur) ─
    // Ini path penting: key di SharedPreferences menggunakan username sebagai suffix
    test('TC-DISK-04 - data should be isolated per username', () async {
      // (1) arrange: simpan data untuk user A dan user B
      final controllerA = CounterController();
      await controllerA.loadData('user_a');
      controllerA.updateStep('5');
      controllerA.increment('user_a'); // user_a counter = 5

      final controllerB = CounterController();
      await controllerB.loadData('user_b');
      controllerB.updateStep('10');
      controllerB.increment('user_b'); // user_b counter = 10

      // (2) exercise: muat ulang data untuk masing-masing user
      final reloadA = CounterController();
      final reloadB = CounterController();
      await reloadA.loadData('user_a');
      await reloadB.loadData('user_b');

      // (3) verify: data tidak campur
      expect(reloadA.value, equals(5),
          reason: 'Data user_a harus 5, tidak tercampur data user_b');
      expect(reloadB.value, equals(10),
          reason: 'Data user_b harus 10, tidak tercampur data user_a');
    });

    //  TC-DISK-05: Reset lalu save → loadData mengembalikan 0 ─
    test('TC-DISK-05 - reset then reload should return 0', () async {
      // (1) arrange: naikkan counter lalu reset
      final controller = CounterController();
      await controller.loadData(username);
      controller.updateStep('2');
      await controller.increment(username); // counter = 2
      await controller.reset(username);     // counter = 0, auto-save

      // (2) exercise: muat ulang
      final freshController = CounterController();
      await freshController.loadData(username);

      // (3) verify
      expect(freshController.value, equals(0),
          reason: 'Counter harus 0 setelah reset dan dimuat ulang');
    });
  });
}