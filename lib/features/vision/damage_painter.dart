import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'vision_controller.dart';

/// DamagePainter menggambar dua lapisan overlay di atas camera preview:
///
/// 1. Static Anchor (Task 3): Crosshair di tengah layar + label "Searching..."
/// 2. Detection Boxes (Task 4 + Homework 3): Kotak deteksi mock dengan
///    skema warna RDD-2022 (Merah=berat, Kuning=ringan) dan shadow pada teks.
///
/// Single Responsibility: hanya urusan menggambar, state dikelola VisionController.
class DamagePainter extends CustomPainter {
  final List<DetectionResult> results;
  final bool showSearching; // true = tampilkan label "Searching..."

  const DamagePainter({
    required this.results,
    this.showSearching = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Selalu gambar crosshair di tengah (Task 3)
    _drawCrosshair(canvas, size);

    if (results.isEmpty) {
      // Tidak ada deteksi → tampilkan label searching (Task 3)
      if (showSearching) {
        _drawSearchingLabel(canvas, size);
      }
      return;
    }

    // Gambar setiap kotak deteksi (Task 4 + Homework 3)
    for (final result in results) {
      _drawDetectionBox(canvas, size, result);
    }
  }

  // ─────────────────────────────────────────────
  //  TASK 3: Static Crosshair Anchor
  // ─────────────────────────────────────────────

  void _drawCrosshair(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 28.0;
    const gap = 7.0;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Shadow di belakang garis (agar terbaca di latar terang)
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2);

    final lines = [
      [Offset(cx - arm, cy), Offset(cx - gap, cy)],
      [Offset(cx + gap, cy), Offset(cx + arm, cy)],
      [Offset(cx, cy - arm), Offset(cx, cy - gap)],
      [Offset(cx, cy + gap), Offset(cx, cy + arm)],
    ];

    for (final line in lines) {
      canvas.drawLine(line[0], line[1], shadowPaint);
      canvas.drawLine(line[0], line[1], paint);
    }

    // Lingkaran kecil di tengah
    canvas.drawCircle(
      Offset(cx, cy), 4,
      Paint()..color = Colors.white.withOpacity(0.6),
    );
  }

  // ─────────────────────────────────────────────
  //  TASK 3: Label "Searching..." dengan TextPainter
  // ─────────────────────────────────────────────

  void _drawSearchingLabel(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Gambar label di bawah crosshair
    _drawTextWithBackground(
      canvas: canvas,
      text: 'Searching for Road Damage...',
      position: Offset(cx, cy + 45),
      textColor: Colors.white,
      backgroundColor: Colors.black.withOpacity(0.55),
      fontSize: 13,
      centered: true,
    );
  }

  // ─────────────────────────────────────────────
  //  TASK 4 + HOMEWORK 3: Detection Box
  // ─────────────────────────────────────────────

  void _drawDetectionBox(Canvas canvas, Size size, DetectionResult result) {
    // Scale koordinat ternormalisasi ke pixel
    final box = Rect.fromLTWH(
      result.box.left * size.width,
      result.box.top * size.height,
      result.box.width * size.width,
      result.box.height * size.height,
    );

    // ── Homework 3: Skema warna berdasarkan severity ──
    final color = _colorForDamage(result.label);

    // Shadow box (agar terlihat di latar apapun)
    canvas.drawRect(
      box,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );

    // Kotak utama
    canvas.drawRect(
      box,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Sudut kotak (corner marks) — lebih estetis
    _drawCornerMarks(canvas, box, color);

    // Label teks dengan background + shadow (Homework 3)
    final labelText =
        '${result.label}  ${(result.score * 100).toStringAsFixed(0)}%';
    _drawTextWithBackground(
      canvas: canvas,
      text: labelText,
      position: Offset(box.left, box.top - 22),
      textColor: Colors.white,
      backgroundColor: color.withOpacity(0.85),
      fontSize: 11.5,
      centered: false,
    );
  }

  /// Homework 3: Warna berdasarkan tingkat keparahan kerusakan jalan (RDD-2022).
  /// D40 Pothole         → Merah (paling berat)
  /// D20 Alligator Crack → Oranye (berat)
  /// D10 Transverse Crack → Kuning (sedang)
  /// D00 Longitudinal    → Hijau (ringan)
  Color _colorForDamage(String label) {
    if (label.contains('D40')) return Colors.red;
    if (label.contains('D20')) return Colors.orange;
    if (label.contains('D10')) return Colors.yellow;
    return const Color(0xFF00E676); // hijau terang untuk D00
  }

  /// Gambar tanda sudut pada kotak deteksi (estetika enterprise).
  void _drawCornerMarks(Canvas canvas, Rect box, Color color) {
    const len = 14.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(box.topLeft, box.topLeft.translate(len, 0), paint);
    canvas.drawLine(box.topLeft, box.topLeft.translate(0, len), paint);
    // Top-right
    canvas.drawLine(box.topRight, box.topRight.translate(-len, 0), paint);
    canvas.drawLine(box.topRight, box.topRight.translate(0, len), paint);
    // Bottom-left
    canvas.drawLine(box.bottomLeft, box.bottomLeft.translate(len, 0), paint);
    canvas.drawLine(box.bottomLeft, box.bottomLeft.translate(0, -len), paint);
    // Bottom-right
    canvas.drawLine(box.bottomRight, box.bottomRight.translate(-len, 0), paint);
    canvas.drawLine(box.bottomRight, box.bottomRight.translate(0, -len), paint);
  }

  // ─────────────────────────────────────────────
  //  HELPER: Teks dengan background + shadow (Homework 3)
  // ─────────────────────────────────────────────

  void _drawTextWithBackground({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Color textColor,
    required Color backgroundColor,
    double fontSize = 13,
    bool centered = false,
  }) {
    final textSpan = TextSpan(
      text: ' $text ',
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        // Shadow pada teks agar terbaca di latar yang mirip warna teks
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
          Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2)),
        ],
      ),
    );

    final painter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final dx = centered ? position.dx - painter.width / 2 : position.dx;
    final dy = position.dy;

    // Background pill
    final bgRect = Rect.fromLTWH(dx - 2, dy - 2, painter.width + 4, painter.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = backgroundColor,
    );

    // Gambar teks di atas background
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.showSearching != showSearching;
  }
}