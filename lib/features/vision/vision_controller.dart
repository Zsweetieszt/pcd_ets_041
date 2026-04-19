import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// VisionController manages camera lifecycle and real-time image processing
class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  
  bool isInitialized = false;
  String? errorMessage;
  
  // UX Enhancement: Flash & Filter toggles
  bool isFlashlightOn = false;
  bool isFilterEnabled = true; // Toggle untuk enable/disable filter
  
  // Filter state
  String currentFilter = 'Original'; // Default: no filter
  final List<String> availableFilters = [
    'Original',
    'Grayscale',
    'Sepia',
    'Inverted',
    'High Contrast',
    'Edge Detection',
  ];
  
  // Processed image untuk ditampilkan
  Uint8List? processedImageBytes;
  bool isProcessing = false;
  
  // Stream subscription untuk camera frames
  StreamSubscription<CameraImage>? _imageStreamSubscription;

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  /// Initialize rear camera with high resolution
  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = "No camera detected on device.";
        notifyListeners();
        return;
      }

      controller = CameraController(
        cameras[0], // Rear camera
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;
      
      // Start image stream untuk real-time processing
      if (isFilterEnabled) {
        startImageStream();
      }
    } catch (e) {
      errorMessage = "Failed to initialize camera: $e";
    }
    notifyListeners();
  }

  /// Start image stream untuk real-time filter processing
  void startImageStream() {
    if (controller == null || !controller!.value.isInitialized) return;

    controller!.startImageStream((CameraImage image) {
      if (!isProcessing && isFilterEnabled) {
        _processCameraImage(image);
      }
    });
  }

  /// Stop image stream
  void stopImageStream() {
    _imageStreamSubscription?.cancel();
    _imageStreamSubscription = null;
  }

  /// Process camera frame dengan filter yang dipilih
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (isProcessing) return;
    
    isProcessing = true;
    
    try {
      // Convert CameraImage to image package format
      final img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) {
        isProcessing = false;
        return;
      }
      
      // Apply selected filter
      final img.Image filtered = _applyFilter(image, currentFilter);
      
      // Convert back to bytes untuk ditampilkan
      processedImageBytes = Uint8List.fromList(img.encodeJpg(filtered));
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      isProcessing = false;
    }
  }

  /// Convert CameraImage (YUV420/NV21) ke img.Image (RGB)
  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      // Get Y plane (luminance)
      final Plane yPlane = cameraImage.planes[0];
      final Uint8List yBytes = yPlane.bytes;
      
      // Create image from Y plane (grayscale approximation untuk speed)
      // Untuk full color conversion, perlu UV planes processing
      final img.Image image = img.Image(width: width, height: height);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yPlane.bytesPerRow + x;
          final int gray = yBytes[yIndex];
          image.setPixelRgba(x, y, gray, gray, gray, 255);
        }
      }
      
      return image;
    } catch (e) {
      debugPrint("Error converting camera image: $e");
      return null;
    }
  }

  /// Apply filter berdasarkan nama filter
  img.Image _applyFilter(img.Image src, String filterName) {
    switch (filterName) {
      case 'Grayscale':
        return img.grayscale(src);
      
      case 'Sepia':
        return img.sepia(src);
      
      case 'Inverted':
        return img.invert(src);
      
      case 'High Contrast':
        return img.adjustColor(src, contrast: 1.5);
      
      case 'Edge Detection':
        return img.sobel(src);
      
      case 'Original':
      default:
        return src;
    }
  }

  /// Change current filter
  void setFilter(String filterName) {
    if (availableFilters.contains(filterName)) {
      currentFilter = filterName;
      notifyListeners();
    }
  }

  /// Toggle filter on/off
  void toggleFilter() {
    isFilterEnabled = !isFilterEnabled;
    
    if (isFilterEnabled) {
      startImageStream();
    } else {
      stopImageStream();
      processedImageBytes = null;
    }
    
    notifyListeners();
  }

  /// Toggle flashlight
  Future<void> toggleFlashlight() async {
    if (controller == null || !controller!.value.isInitialized) return;

    isFlashlightOn = !isFlashlightOn;
    
    try {
      await controller!.setFlashMode(
        isFlashlightOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      errorMessage = "Failed to toggle flashlight: $e";
    }
    
    notifyListeners();
  }

  /// Capture photo (paused preview)
  Future<XFile?> takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return null;

    try {
      // Stop stream sementara
      stopImageStream();
      
      await controller!.pausePreview();
      await Future.delayed(const Duration(milliseconds: 100));
      
      final image = await controller!.takePicture();
      
      await controller!.resumePreview();
      
      // Restart stream
      if (isFilterEnabled) {
        startImageStream();
      }
      
      return image;
    } catch (e) {
      errorMessage = "Failed to capture photo: $e";
      notifyListeners();
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      stopImageStream();
      cameraController.dispose();
      isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopImageStream();
    controller?.dispose();
    super.dispose();
  }
}