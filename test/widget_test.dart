import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App dapat menampilkan widget dasar tanpa crash', (WidgetTester tester) async {
    // Build MaterialApp minimal untuk verifikasi bahwa widget tree bisa dibuild
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Logbook App'),
          ),
        ),
      ),
    );

    // Verifikasi widget dasar tersedia
    expect(find.text('Logbook App'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Scaffold dengan AppBar dapat dirender', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Logbook Test')),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Logbook Test'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}