import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// Enum untuk jenis filter yang tersedia
enum CameraFilter { normal, grayscale, sepia, inverted, cool, warm }

extension CameraFilterExtension on CameraFilter {
  String get displayName {
    switch (this) {
      case CameraFilter.normal:
        return 'Normal';
      case CameraFilter.grayscale:
        return 'Grayscale';
      case CameraFilter.sepia:
        return 'Sepia';
      case CameraFilter.inverted:
        return 'Inverted';
      case CameraFilter.cool:
        return 'Cool';
      case CameraFilter.warm:
        return 'Warm';
    }
  }

  // ColorFilter matrix untuk setiap filter
  ColorFilter? get colorFilter {
    switch (this) {
      case CameraFilter.normal:
        return null; // Tidak ada filter

      case CameraFilter.grayscale:
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);

      case CameraFilter.sepia:
        return const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0,     0,     0,     1, 0,
        ]);

      case CameraFilter.inverted:
        return const ColorFilter.matrix(<double>[
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]);

      case CameraFilter.cool:
        return const ColorFilter.matrix(<double>[
          1.0,  0.0,  0.0, 0,  0,
          0.0,  1.0,  0.0, 0,  0,
          0.0,  0.0,  1.3, 0, -30,
          0,    0,    0,   1,  0,
        ]);

      case CameraFilter.warm:
        return const ColorFilter.matrix(<double>[
          1.3,  0.0, 0.0, 0,  0,
          0.0,  1.05, 0.0, 0, 0,
          0.0,  0.0, 0.8, 0,  0,
          0,    0,   0,   1,  0,
        ]);
    }
  }
}

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;
  List<DetectionResult> currentDetections = [];
  Timer? _mockDetectionTimer;

  bool isFlashlightOn = false;
  bool isOverlayVisible = true;

  // Filter yang sedang aktif
  CameraFilter currentFilter = CameraFilter.normal;

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        errorMessage = "Tidak ada kamera yang terdeteksi.";
        notifyListeners();
        return;
      }

      controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;
    } catch (e) {
      errorMessage = "Gagal inisialisasi kamera: $e";
    }

    notifyListeners();
  }

  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return null;

    try {
      await controller!.pausePreview();
      await Future.delayed(const Duration(milliseconds: 100));
      final image = await controller!.takePicture();
      await controller!.resumePreview();
      return image;
    } catch (e) {
      errorMessage = "Gagal mengambil foto: $e";
      notifyListeners();
      return null;
    }
  }

  // Ganti filter aktif
  void setFilter(CameraFilter filter) {
    currentFilter = filter;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  Future<void> toggleFlashlight() async {
    if (controller == null || !controller!.value.isInitialized) return;
    isFlashlightOn = !isFlashlightOn;
    try {
      await controller!.setFlashMode(
        isFlashlightOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      errorMessage = "Gagal toggle flashlight: $e";
    }
    notifyListeners();
  }

  void toggleOverlay() {
    isOverlayVisible = !isOverlayVisible;
    notifyListeners();
  }

  void startMockDetection() {
    _mockDetectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _generateMockDetection(),
    );
  }

  void _generateMockDetection() {
    final random = Random();
    final x = random.nextDouble() * 0.8 + 0.1;
    final y = random.nextDouble() * 0.8 + 0.1;
    final width = 0.2 + random.nextDouble() * 0.2;
    final height = 0.1 + random.nextDouble() * 0.1;

    currentDetections = [
      DetectionResult(
        box: Rect.fromLTWH(x, y, width, height),
        label: _getRandomDamageType(),
        score: 0.85 + random.nextDouble() * 0.14,
      ),
    ];
    notifyListeners();
  }

  String _getRandomDamageType() {
    final types = ['D00', 'D10', 'D20', 'D40'];
    final labels = {
      'D00': 'Longitudinal Crack',
      'D10': 'Transverse Crack',
      'D20': 'Alligator Crack',
      'D40': 'Pothole',
    };
    final type = types[Random().nextInt(types.length)];
    return '[$type] ${labels[type]!}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mockDetectionTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }
}

class DetectionResult {
  final Rect box;
  final String label;
  final double score;

  DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}