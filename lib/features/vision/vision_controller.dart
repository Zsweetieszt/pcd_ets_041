// File: lib/features/vision/vision_controller.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────
//  MODEL: Hasil deteksi satu objek (Task 4)
// ─────────────────────────────────────────────

class DetectionResult {
  final Rect box;
  final String label;
  final double score;

  const DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}

// ─────────────────────────────────────────────
//  CONTROLLER
// ─────────────────────────────────────────────

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;

  bool isInitialized = false;
  String? errorMessage;

  // ── UX toggles ──
  bool isFlashlightOn = false;
  bool isFilterEnabled = true;
  bool isOverlayEnabled = true;

  // ── Filter ──
  String currentFilter = 'Original';

  // EXPANDED filter list — grouped
  final List<String> availableFilters = [
    // Original
    'Original',
    // Classic
    'Grayscale', 'Sepia', 'Noir', 'Fade',
    // Tone
    'Warm', 'Cold', 'Vivid',
    // Color tint
    'Red', 'Green', 'Blue', 'Cyan', 'Yellow', 'Magenta',
    // Special effects
    'Inverted', 'High Contrast', 'Edge Detection', 'Posterize', 'Emboss',
  ];

  // ── Preview overlay ──
  Uint8List? processedImageBytes;

  // ── Mock Detection (Task 4) ──
  List<DetectionResult> detections = [];
  Timer? _mockDetectionTimer;

  // ── Sensor orientation ──
  int _sensorOrientation = 90;

  // ── Throttle ──
  bool _isProcessing = false;
  DateTime _lastFrameTime = DateTime(0);
  static const _minFrameIntervalMs = 120;

  static const _damageTypes = [
    {'label': 'D40 - Pothole',            'score': 0.91},
    {'label': 'D20 - Alligator Crack',    'score': 0.83},
    {'label': 'D10 - Transverse Crack',   'score': 0.76},
    {'label': 'D00 - Longitudinal Crack', 'score': 0.68},
  ];

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  // ─────────────────────────────────────────────
  //  INIT KAMERA
  // ─────────────────────────────────────────────

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = 'Tidak ada kamera yang terdeteksi.';
        notifyListeners();
        return;
      }

      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _sensorOrientation = rearCamera.sensorOrientation;

      controller = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;

      if (isFilterEnabled) _startImageStream();
      _startMockDetection();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('CameraAccessDenied') ||
          msg.contains('PERMISSION_DENIED') ||
          msg.contains('Access denied')) {
        errorMessage = 'CAMERA_DENIED';
      } else {
        errorMessage = 'Gagal inisialisasi kamera:\n$e';
      }
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  MOCK DETECTION
  // ─────────────────────────────────────────────

  void _startMockDetection() {
    _mockDetectionTimer?.cancel();
    _generateMockDetection();
    _mockDetectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _generateMockDetection(),
    );
  }

  void _stopMockDetection() {
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = null;
    detections = [];
  }

  void _generateMockDetection() {
    final rng = Random();
    final count = rng.nextInt(2) + 1;
    final newDetections = <DetectionResult>[];

    for (int i = 0; i < count; i++) {
      final w = 0.20 + rng.nextDouble() * 0.15;
      final h = w * (0.55 + rng.nextDouble() * 0.45);
      final x = rng.nextDouble() * (1.0 - w);
      final y = rng.nextDouble() * (1.0 - h);

      final dmg = _damageTypes[rng.nextInt(_damageTypes.length)];
      newDetections.add(DetectionResult(
        box: Rect.fromLTWH(x, y, w, h),
        label: dmg['label'] as String,
        score: (dmg['score'] as double) - rng.nextDouble() * 0.05,
      ));
    }

    detections = newDetections;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  IMAGE STREAM
  // ─────────────────────────────────────────────

  void _startImageStream() {
    if (controller == null || !controller!.value.isInitialized) return;
    if (controller!.value.isStreamingImages) return;
    controller!.startImageStream(_onCameraFrame);
  }

  void _stopImageStream() {
    if (controller == null) return;
    if (!controller!.value.isStreamingImages) return;
    controller!.stopImageStream();
  }

  void _onCameraFrame(CameraImage image) {
    final now = DateTime.now();
    if (_isProcessing) return;
    if (now.difference(_lastFrameTime).inMilliseconds < _minFrameIntervalMs)
      return;

    if (currentFilter == 'Original') {
      if (processedImageBytes != null) {
        processedImageBytes = null;
        notifyListeners();
      }
      return;
    }

    _isProcessing = true;
    _lastFrameTime = now;

    _processFrame(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processFrame(CameraImage cameraImage) async {
    final converted = _yuv420ToRgb(cameraImage);
    if (converted == null) return;

    final rotated = _rotateCameraImage(converted);
    final filtered = _applyFilter(rotated, currentFilter);
    processedImageBytes = Uint8List.fromList(
      img.encodeJpg(filtered, quality: 72),
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  YUV420 → RGB
  // ─────────────────────────────────────────────

  img.Image? _yuv420ToRgb(CameraImage cameraImage) {
    try {
      final w = cameraImage.width;
      final h = cameraImage.height;
      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];
      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      final result = img.Image(width: w, height: h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final yIdx = y * yPlane.bytesPerRow + x;
          final uvIdx =
              (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          if (yIdx >= yBytes.length ||
              uvIdx >= uBytes.length ||
              uvIdx >= vBytes.length) continue;

          final yv = yBytes[yIdx] & 0xFF;
          final uv = (uBytes[uvIdx] & 0xFF) - 128;
          final vv = (vBytes[uvIdx] & 0xFF) - 128;

          final r = (yv + 1.402 * vv).round().clamp(0, 255);
          final g =
              (yv - 0.344 * uv - 0.714 * vv).round().clamp(0, 255);
          final b = (yv + 1.772 * uv).round().clamp(0, 255);
          result.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return result;
    } catch (e) {
      debugPrint('YUV error: $e');
      return null;
    }
  }

  img.Image _rotateCameraImage(img.Image source) {
    switch (_sensorOrientation) {
      case 90:
        return img.copyRotate(source, angle: 90);
      case 180:
        return img.copyRotate(source, angle: 180);
      case 270:
        return img.copyRotate(source, angle: 270);
      default:
        return source;
    }
  }

  // ─────────────────────────────────────────────
  //  FILTER ENGINE — EXTENDED
  // ─────────────────────────────────────────────

  img.Image _applyFilter(img.Image src, String name) {
    switch (name) {
      // ── Classic ──
      case 'Grayscale':
        return img.grayscale(src);

      case 'Sepia':
        return img.sepia(src);

      case 'Noir':
        // High-contrast B&W
        final gray = img.grayscale(src);
        return img.adjustColor(gray, contrast: 2.0, brightness: 0.9);

      case 'Fade':
        // Desaturate + brighten + lower contrast
        final faded = img.adjustColor(
          src,
          saturation: 0.3,
          brightness: 1.15,
          contrast: 0.7,
        );
        return faded;

      // ── Tone ──
      case 'Warm':
        return _applyColorBalance(src, rShift: 30, gShift: 10, bShift: -20);

      case 'Cold':
        return _applyColorBalance(src, rShift: -20, gShift: 10, bShift: 35);

      case 'Vivid':
        return img.adjustColor(src, saturation: 2.0, contrast: 1.3);

      // ── Color Tint ──
      case 'Red':
        return _applyColorTint(src, r: 255, g: 0, b: 0, tintStrength: 0.4);
      case 'Green':
        return _applyColorTint(src, r: 0, g: 255, b: 0, tintStrength: 0.4);
      case 'Blue':
        return _applyColorTint(src, r: 0, g: 0, b: 255, tintStrength: 0.4);
      case 'Cyan':
        return _applyColorTint(src, r: 0, g: 255, b: 255, tintStrength: 0.35);
      case 'Yellow':
        return _applyColorTint(src, r: 255, g: 255, b: 0, tintStrength: 0.35);
      case 'Magenta':
        return _applyColorTint(src, r: 255, g: 0, b: 255, tintStrength: 0.35);

      // ── Special Effects ──
      case 'Inverted':
        return img.invert(src);

      case 'High Contrast':
        return img.adjustColor(src, contrast: 1.8, brightness: 1.05);

      case 'Edge Detection':
        return img.sobel(img.grayscale(src));

      case 'Posterize':
        return img.quantize(src, numberOfColors: 16);

      case 'Emboss':
        return img.emboss(src);

      default:
        return src;
    }
  }

  /// Tint warna: blending gambar asli dengan warna solid
  img.Image _applyColorTint(
    img.Image src, {
    required int r,
    required int g,
    required int b,
    double tintStrength = 0.4,
  }) {
    final result = img.Image(width: src.width, height: src.height);
    final inv = 1.0 - tintStrength;
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final nr = (p.r.toDouble() * inv + r * tintStrength).round().clamp(0, 255);
        final ng = (p.g.toDouble() * inv + g * tintStrength).round().clamp(0, 255);
        final nb = (p.b.toDouble() * inv + b * tintStrength).round().clamp(0, 255);
        result.setPixelRgba(x, y, nr, ng, nb, 255);
      }
    }
    return result;
  }

  /// Warm/Cold: shift warna channel secara manual
  img.Image _applyColorBalance(
    img.Image src, {
    int rShift = 0,
    int gShift = 0,
    int bShift = 0,
  }) {
    final result = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final nr = (p.r.toInt() + rShift).clamp(0, 255);
        final ng = (p.g.toInt() + gShift).clamp(0, 255);
        final nb = (p.b.toInt() + bShift).clamp(0, 255);
        result.setPixelRgba(x, y, nr, ng, nb, 255);
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────
  //  PUBLIC CONTROLS
  // ─────────────────────────────────────────────

  void setFilter(String name) {
    if (!availableFilters.contains(name)) return;
    currentFilter = name;
    if (name == 'Original') processedImageBytes = null;
    notifyListeners();
  }

  void toggleFilter() {
    isFilterEnabled = !isFilterEnabled;
    if (isFilterEnabled) {
      _startImageStream();
    } else {
      _stopImageStream();
      processedImageBytes = null;
    }
    notifyListeners();
  }

  void toggleOverlay() {
    isOverlayEnabled = !isOverlayEnabled;
    notifyListeners();
  }

  Future<void> toggleFlashlight() async {
    if (controller == null || !controller!.value.isInitialized) return;
    isFlashlightOn = !isFlashlightOn;
    try {
      await controller!.setFlashMode(
        isFlashlightOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      isFlashlightOn = !isFlashlightOn;
      debugPrint('Flash error: $e');
    }
    notifyListeners();
  }

  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return null;
    final wasStreaming =
        isFilterEnabled && controller!.value.isStreamingImages;
    try {
      if (wasStreaming) _stopImageStream();
      await Future.delayed(const Duration(milliseconds: 150));
      final image = await controller!.takePicture();
      if (wasStreaming) _startImageStream();
      return image;
    } catch (e) {
      errorMessage = 'Gagal mengambil foto: $e';
      if (wasStreaming) _startImageStream();
      notifyListeners();
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = controller;
    if (cam == null || !cam.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
      _stopMockDetection();
      cam.dispose();
      isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
    _stopMockDetection();
    controller?.dispose();
    super.dispose();
  }
}