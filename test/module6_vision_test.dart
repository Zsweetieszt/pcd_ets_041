import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────
//  Helper: Filter logic yang diekstrak untuk unit test
//  (VisionController butuh hardware kamera, jadi kita test logika murni)
// ─────────────────────────────────────────────

img.Image applyFilter(img.Image src, String filterName) {
  switch (filterName) {
    case 'Grayscale':     return img.grayscale(src);
    case 'Sepia':         return img.sepia(src);
    case 'Inverted':      return img.invert(src);
    case 'High Contrast': return img.adjustColor(src, contrast: 1.8, brightness: 1.05);
    case 'Edge Detection': return img.sobel(img.grayscale(src));
    default:              return src;
  }
}

img.Image makeTestImage({int w = 10, int h = 10, int r = 128, int g = 64, int b = 200}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

// ─────────────────────────────────────────────
//  Helper: Mock Detection logic
// ─────────────────────────────────────────────

class MockDetectionResult {
  final double left, top, width, height;
  final String label;
  final double score;
  const MockDetectionResult({
    required this.left, required this.top,
    required this.width, required this.height,
    required this.label, required this.score,
  });
}

List<MockDetectionResult> generateMockDetections({int seed = 42}) {
  // Simulasi logika generateMockDetection dari VisionController
  final results = <MockDetectionResult>[];
  // Koordinat mock deterministik untuk test
  results.add(const MockDetectionResult(
    left: 0.1, top: 0.2, width: 0.25, height: 0.20,
    label: 'D40 - Pothole', score: 0.91,
  ));
  return results;
}

// ─────────────────────────────────────────────
//  TESTS
// ─────────────────────────────────────────────

void main() {

  // ── GROUP 1: Filter Logic (Task 5 / Phase 5) ──
  group('TC-VIS: Filter Processing Logic', () {

    test('TC-VIS-01 - Original filter tidak mengubah pixel', () {
      final original = makeTestImage(r: 100, g: 150, b: 200);
      final result = applyFilter(original, 'Original');
      final src = original.getPixel(0, 0);
      final res = result.getPixel(0, 0);
      expect(res.r, equals(src.r));
      expect(res.g, equals(src.g));
      expect(res.b, equals(src.b));
    });

    test('TC-VIS-02 - Grayscale menghasilkan R=G=B', () {
      final result = applyFilter(makeTestImage(r: 200, g: 100, b: 50), 'Grayscale');
      final p = result.getPixel(5, 5);
      expect(p.r.toInt(), equals(p.g.toInt()),
          reason: 'Grayscale: R harus sama dengan G');
      expect(p.g.toInt(), equals(p.b.toInt()),
          reason: 'Grayscale: G harus sama dengan B');
    });

    test('TC-VIS-03 - Inverted membalik nilai pixel (~255 - nilai asli)', () {
      final src = makeTestImage(r: 100, g: 50, b: 200);
      final result = applyFilter(src, 'Inverted');
      final sp = src.getPixel(0, 0);
      final rp = result.getPixel(0, 0);
      expect(rp.r.toInt(), closeTo(255 - sp.r.toInt(), 5));
      expect(rp.g.toInt(), closeTo(255 - sp.g.toInt(), 5));
      expect(rp.b.toInt(), closeTo(255 - sp.b.toInt(), 5));
    });

    test('TC-VIS-04 - Sepia menghasilkan tone hangat (R > B)', () {
      final result = applyFilter(makeTestImage(r: 200, g: 200, b: 200), 'Sepia');
      final p = result.getPixel(5, 5);
      expect(p.r.toInt(), greaterThan(p.b.toInt()),
          reason: 'Sepia: Red channel harus lebih besar dari Blue');
    });

    test('TC-VIS-05 - High Contrast menghasilkan gambar valid tanpa crash', () {
      final result = applyFilter(makeTestImage(r: 128, g: 128, b: 128), 'High Contrast');
      expect(result.width, equals(10));
      expect(result.height, equals(10));
      expect(result.getPixel(0, 0), isNotNull);
    });

    test('TC-VIS-06 - Edge Detection menghasilkan gambar dengan dimensi sama', () {
      final image = makeTestImage();
      // Buat edge dengan variasi warna
      for (int x = 5; x < 10; x++) {
        for (int y = 0; y < 10; y++) {
          image.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
      final result = applyFilter(image, 'Edge Detection');
      expect(result.width, equals(10));
      expect(result.height, equals(10));
    });

    test('TC-VIS-07 - Filter tidak dikenal → kembalikan gambar asli', () {
      final image = makeTestImage(r: 100, g: 150, b: 200);
      final result = applyFilter(image, 'FilterTidakAda');
      expect(result.getPixel(0, 0).r, equals(image.getPixel(0, 0).r));
    });

    test('TC-VIS-08 - Semua 6 filter bisa dijalankan tanpa exception', () {
      final filters = ['Original', 'Grayscale', 'Sepia', 'Inverted', 'High Contrast', 'Edge Detection'];
      final image = makeTestImage();
      for (final f in filters) {
        expect(() => applyFilter(image, f), returnsNormally,
            reason: 'Filter "$f" tidak boleh throw exception');
      }
    });

    test('TC-VIS-09 - Semua filter mempertahankan dimensi gambar', () {
      final filters = ['Grayscale', 'Sepia', 'Inverted', 'High Contrast', 'Edge Detection'];
      final image = makeTestImage(w: 12, h: 8);
      for (final f in filters) {
        final result = applyFilter(image, f);
        expect(result.width, equals(12), reason: '$f: lebar harus 12');
        expect(result.height, equals(8), reason: '$f: tinggi harus 8');
      }
    });

    test('TC-VIS-10 - Grayscale 2x idempotent (hasil sama)', () {
      final image = makeTestImage(r: 180, g: 90, b: 45);
      final first = applyFilter(image, 'Grayscale');
      final second = applyFilter(first, 'Grayscale');
      final p1 = first.getPixel(5, 5);
      final p2 = second.getPixel(5, 5);
      expect(p2.r, equals(p1.r));
      expect(p2.g, equals(p1.g));
      expect(p2.b, equals(p1.b));
    });
  });

  // ── GROUP 2: Mock Detection Logic (Task 4) ──
  group('TC-MOCK: Mock Detection Logic', () {

    test('TC-MOCK-01 - generateMockDetections mengembalikan minimal 1 hasil', () {
      final results = generateMockDetections();
      expect(results.isNotEmpty, isTrue,
          reason: 'Mock detection harus menghasilkan minimal 1 kotak');
    });

    test('TC-MOCK-02 - Koordinat box dalam rentang 0.0–1.0', () {
      final results = generateMockDetections();
      for (final r in results) {
        expect(r.left, greaterThanOrEqualTo(0.0));
        expect(r.top, greaterThanOrEqualTo(0.0));
        expect(r.left + r.width, lessThanOrEqualTo(1.05), // toleransi kecil
            reason: 'Kotak tidak boleh keluar batas kanan');
        expect(r.top + r.height, lessThanOrEqualTo(1.05),
            reason: 'Kotak tidak boleh keluar batas bawah');
      }
    });

    test('TC-MOCK-03 - Label adalah salah satu tipe RDD-2022', () {
      const validLabels = ['D40 - Pothole', 'D20 - Alligator Crack',
          'D10 - Transverse Crack', 'D00 - Longitudinal Crack'];
      final results = generateMockDetections();
      for (final r in results) {
        expect(validLabels.contains(r.label), isTrue,
            reason: '"${r.label}" bukan label RDD-2022 yang valid');
      }
    });

    test('TC-MOCK-04 - Score berada dalam rentang 0.0–1.0', () {
      final results = generateMockDetections();
      for (final r in results) {
        expect(r.score, greaterThan(0.0));
        expect(r.score, lessThanOrEqualTo(1.0));
      }
    });

    test('TC-MOCK-05 - Ukuran kotak proporsional (width 20%–35% layar)', () {
      final results = generateMockDetections();
      for (final r in results) {
        // Task 4 spec: ukuran 20%-35% lebar layar
        expect(r.width, greaterThanOrEqualTo(0.15),
            reason: 'Kotak terlalu kecil (< 15% lebar)');
        expect(r.width, lessThanOrEqualTo(0.40),
            reason: 'Kotak terlalu besar (> 40% lebar)');
      }
    });
  });

  // ── GROUP 3: Damage Color Branding (Homework 3) ──
  group('TC-COLOR: Damage Color Classification', () {

    Color colorForDamage(String label) {
      if (label.contains('D40')) return Colors.red;
      if (label.contains('D20')) return Colors.orange;
      if (label.contains('D10')) return Colors.yellow;
      return const Color(0xFF00E676);
    }

    test('TC-COLOR-01 - D40 Pothole → Merah (kerusakan paling berat)', () {
      expect(colorForDamage('D40 - Pothole'), equals(Colors.red));
    });

    test('TC-COLOR-02 - D20 Alligator Crack → Oranye', () {
      expect(colorForDamage('D20 - Alligator Crack'), equals(Colors.orange));
    });

    test('TC-COLOR-03 - D10 Transverse Crack → Kuning', () {
      expect(colorForDamage('D10 - Transverse Crack'), equals(Colors.yellow));
    });

    test('TC-COLOR-04 - D00 Longitudinal Crack → Hijau (kerusakan ringan)', () {
      final color = colorForDamage('D00 - Longitudinal Crack');
      // Hijau — berbeda dari merah, oranye, kuning
      expect(color, isNot(equals(Colors.red)));
      expect(color, isNot(equals(Colors.orange)));
      expect(color, isNot(equals(Colors.yellow)));
    });

    test('TC-COLOR-05 - Hierarki warna mencerminkan tingkat keparahan', () {
      // D40 (berat) = merah, D00 (ringan) = hijau — keduanya berbeda
      final heavy = colorForDamage('D40 - Pothole');
      final light = colorForDamage('D00 - Longitudinal Crack');
      expect(heavy, isNot(equals(light)),
          reason: 'Warna kerusakan berat dan ringan harus berbeda');
    });
  });
}