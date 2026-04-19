import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────
//  MODEL: Hasil deteksi satu objek (Task 4)
// ─────────────────────────────────────────────

/// Representasi satu kotak deteksi mock (simulasi YOLO / RDD-2022).
/// Koordinat dalam rentang 0.0–1.0 (ternormalisasi terhadap ukuran layar).
class DetectionResult {
  final Rect box;       // koordinat ternormalisasi
  final String label;   // contoh: "D40 - Pothole"
  final double score;   // confidence 0.0–1.0

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
  String? errorMessage; // 'CAMERA_DENIED' atau pesan error lain

  // ── UX toggles ──
  bool isFlashlightOn = false;
  bool isFilterEnabled = true;
  bool isOverlayEnabled = true; // Homework 1: toggle overlay painter

  // ── Filter ──
  String currentFilter = 'Original';
  final List<String> availableFilters = [
    'Original',
    'Grayscale',
    'Sepia',
    'Inverted',
    'High Contrast',
    'Edge Detection',
  ];

  // ── Preview overlay ──
  Uint8List? processedImageBytes;

  // ── Mock Detection (Task 4) ──
  List<DetectionResult> detections = [];
  Timer? _mockDetectionTimer;

  // ── Sensor orientation (fix rotasi) ──
  int _sensorOrientation = 90;

  // ── Throttle ──
  bool _isProcessing = false;
  DateTime _lastFrameTime = DateTime(0);
  static const _minFrameIntervalMs = 120; // ~8 fps

  // ── RDD-2022 damage catalogue ──
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
  //  MOCK DETECTION (Task 4)
  // ─────────────────────────────────────────────

  void _startMockDetection() {
    _mockDetectionTimer?.cancel();
    _generateMockDetection(); // langsung satu kali
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
    final count = rng.nextInt(2) + 1; // 1 atau 2 kotak
    final newDetections = <DetectionResult>[];

    for (int i = 0; i < count; i++) {
      // Ukuran proporsional: 20%–35% lebar layar (Task 4 - Scaling Calibration)
      final w = 0.20 + rng.nextDouble() * 0.15;
      final h = w * (0.55 + rng.nextDouble() * 0.45);

      // Posisi acak, tidak keluar batas
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
    if (now.difference(_lastFrameTime).inMilliseconds < _minFrameIntervalMs) return;

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
  //  YUV420 → RGB (Full Color)
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
          final uvIdx = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          if (yIdx >= yBytes.length || uvIdx >= uBytes.length || uvIdx >= vBytes.length) continue;

          final yv = yBytes[yIdx] & 0xFF;
          final uv = (uBytes[uvIdx] & 0xFF) - 128;
          final vv = (vBytes[uvIdx] & 0xFF) - 128;

          final r = (yv + 1.402 * vv).round().clamp(0, 255);
          final g = (yv - 0.344 * uv - 0.714 * vv).round().clamp(0, 255);
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

  /// FIX: Rotasi gambar sesuai sensor orientation agar tidak terbalik.
  /// Kamera Android memiliki sensor yang dipasang miring 90°.
  img.Image _rotateCameraImage(img.Image source) {
    switch (_sensorOrientation) {
      case 90:  return img.copyRotate(source, angle: 90);
      case 180: return img.copyRotate(source, angle: 180);
      case 270: return img.copyRotate(source, angle: 270);
      default:  return source;
    }
  }

  // ─────────────────────────────────────────────
  //  FILTER ENGINE
  // ─────────────────────────────────────────────

  img.Image _applyFilter(img.Image src, String name) {
    switch (name) {
      case 'Grayscale':     return img.grayscale(src);
      case 'Sepia':         return img.sepia(src);
      case 'Inverted':      return img.invert(src);
      case 'High Contrast': return img.adjustColor(src, contrast: 1.8, brightness: 1.05);
      case 'Edge Detection': return img.sobel(img.grayscale(src));
      default:              return src;
    }
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
      isFlashlightOn = !isFlashlightOn; // rollback
      debugPrint('Flash error: $e');
    }
    notifyListeners();
  }

  /// FIX: Tidak null-kan processedImageBytes setelah foto sehingga overlay tetap tampil.
  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return null;
    final wasStreaming = isFilterEnabled && controller!.value.isStreamingImages;
    try {
      if (wasStreaming) _stopImageStream();
      await Future.delayed(const Duration(milliseconds: 150));
      final image = await controller!.takePicture();
      if (wasStreaming) _startImageStream(); // restart, TANPA null-kan bytes
      return image;
    } catch (e) {
      errorMessage = 'Gagal mengambil foto: $e';
      if (wasStreaming) _startImageStream();
      notifyListeners();
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  LIFECYCLE (Resource Guard - Task 4)
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