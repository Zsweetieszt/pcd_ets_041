import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_001/features/logbook/counter_controller.dart';

void main() {
  var actual, expected;

  group('Module 1 - CounterController (TC01–TC10)', () {
    late CounterController controller;
    const username = "admin";

    setUp(() async {
      // (1) setup (arrange, build) — dijalankan sebelum setiap test
      SharedPreferences.setMockInitialValues({});
      controller = CounterController();
      await controller.loadData(username);
    });

    // TC01: loadCounter — nilai awal harus 0
    test('TC01 - initial value should be 0', () {
      actual = controller.value;
      expected = 0;
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC02: setStep positif
    test('TC02 - setStep should change step value', () {
      // (2) exercise
      controller.updateStep('5');
      actual = controller.value; // cek counter tidak berubah
      expected = 0;
      expect(actual, expected, reason: 'Expected counter $expected but got $actual');
    });

    // TC03: setStep negatif — harus diabaikan
    test('TC03 - setStep should ignore invalid/negative value', () {
      // (1) arrange: set step dulu ke 3
      controller.updateStep('3');
      // (2) exercise: coba update dengan nilai tidak valid
      controller.updateStep('-1');
      // step tetap 3, counter tetap 0
      actual = controller.value;
      expected = 0;
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC04: increment dengan step 2
    test('TC04 - increment should increase counter based on step', () async {
      // (1) arrange
      controller.updateStep('2');
      // (2) exercise
      await controller.increment(username);
      actual = controller.value;
      expected = 2;
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC05: decrement path True (counter - step >= 0)
    test('TC05 - decrement should decrease counter based on step (path True)', () async {
      // (1) arrange: naikkan counter ke 4 dulu
      controller.updateStep('2');
      await controller.increment(username);
      await controller.increment(username); // counter = 4
      // (2) exercise
      await controller.decrement(username);
      actual = controller.value;
      expected = 2; // 4 - 2
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC06: decrement path False (counter < step → harus 0)
    test('TC06 - decrement should not go below zero (path False)', () async {
      // (1) arrange: counter = 0, step = 5
      controller.updateStep('5');
      // (2) exercise
      await controller.decrement(username);
      actual = controller.value;
      expected = 0;
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC07: reset harus set counter ke 0
    test('TC07 - reset should set counter to zero', () async {
      // (1) arrange
      await controller.increment(username); // counter = 1
      // (2) exercise
      await controller.reset(username);
      actual = controller.value;
      expected = 0;
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC08: history harus merekam aksi
    test('TC08 - history should record actions after increment', () async {
      // (1) arrange
      controller.updateStep('1');
      // (2) exercise
      await controller.increment(username);
      var actual1 = controller.history.isNotEmpty;
      var expected1 = true;
      var actual2 = controller.history.first['action']?.contains('Menambah') ?? false;
      var expected2 = true;
      // (3) verify
      expect(actual1, expected1, reason: 'History harus tidak kosong');
      expect(actual2, expected2, reason: 'History harus mengandung kata Menambah');
    });

    // TC09: history tidak boleh melebihi 5 item
    test('TC09 - history should not exceed 5 items', () async {
      // (1) arrange
      controller.updateStep('1');
      // (2) exercise: increment 6x (melebihi batas)
      for (int i = 0; i < 6; i++) {
        await controller.increment(username);
      }
      actual = controller.history.length;
      expected = 5;
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    // TC10: counter harus persist via SharedPreferences
    test('TC10 - counter should persist after app restart simulation', () async {
      // (1) arrange: increment dengan step 3
      controller.updateStep('3');
      await controller.increment(username); // counter = 3
      // Simpan manual (karena increment sudah auto-save)
      
      // Buat instance baru (simulasi app restart)
      final newController = CounterController();
      // (2) exercise
      await newController.loadData(username);
      actual = newController.value;
      expected = 3;
      // (3) verify
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });
  });
}