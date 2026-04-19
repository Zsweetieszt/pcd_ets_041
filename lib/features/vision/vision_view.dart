import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'vision_controller.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  late VisionController _visionController;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
  }

  @override
  void dispose() {
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Smart Vision Camera"),
        backgroundColor: Colors.black87,
        actions: [
          // Flashlight toggle
          ListenableBuilder(
            listenable: _visionController,
            builder: (context, _) => IconButton(
              icon: Icon(
                _visionController.isFlashlightOn 
                    ? Icons.flash_on 
                    : Icons.flash_off,
                color: _visionController.isFlashlightOn 
                    ? Colors.yellow 
                    : Colors.white,
              ),
              onPressed: _visionController.toggleFlashlight,
              tooltip: 'Toggle Flashlight',
            ),
          ),
          // Filter toggle
          ListenableBuilder(
            listenable: _visionController,
            builder: (context, _) => IconButton(
              icon: Icon(
                _visionController.isFilterEnabled
                    ? Icons.filter_vintage
                    : Icons.filter_vintage_outlined,
                color: _visionController.isFilterEnabled
                    ? Colors.blue
                    : Colors.white,
              ),
              onPressed: _visionController.toggleFilter,
              tooltip: 'Toggle Filter',
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _visionController,
        builder: (context, child) {
          if (!_visionController.isInitialized) {
            return _buildLoadingState();
          }
          return _buildCameraStack();
        },
      ),
      bottomNavigationBar: _buildFilterSelector(),
      floatingActionButton: FloatingActionButton(
        onPressed: _capturePhoto,
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera, color: Colors.black, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _visionController.errorMessage ?? "Menghubungkan kamera...",
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Camera Preview
        Center(
          child: AspectRatio(
            aspectRatio: _visionController.controller!.value.aspectRatio,
            child: CameraPreview(_visionController.controller!),
          ),
        ),
        
        // Layer 2: Filtered Image Overlay (jika ada)
        if (_visionController.isFilterEnabled && 
            _visionController.processedImageBytes != null)
          Center(
            child: AspectRatio(
              aspectRatio: _visionController.controller!.value.aspectRatio,
              child: Image.memory(
                _visionController.processedImageBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true, // Smooth transition
              ),
            ),
          ),
        
        // Layer 3: Info Overlay
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Filter: ${_visionController.currentFilter}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSelector() {
    return Container(
      height: 100,
      color: Colors.black87,
      child: ListenableBuilder(
        listenable: _visionController,
        builder: (context, _) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: _visionController.availableFilters.length,
          itemBuilder: (context, index) {
            final filterName = _visionController.availableFilters[index];
            final isSelected = _visionController.currentFilter == filterName;
            
            return GestureDetector(
              onTap: () => _visionController.setFilter(filterName),
              child: Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getFilterIcon(filterName),
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filterName) {
    switch (filterName) {
      case 'Grayscale':
        return Icons.gradient;
      case 'Sepia':
        return Icons.wb_sunny;
      case 'Inverted':
        return Icons.invert_colors;
      case 'High Contrast':
        return Icons.contrast;
      case 'Edge Detection':
        return Icons.border_outer;
      default:
        return Icons.camera_alt;
    }
  }

  Future<void> _capturePhoto() async {
    final image = await _visionController.takePhoto();
    
    if (image != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Photo saved: ${image.path}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}