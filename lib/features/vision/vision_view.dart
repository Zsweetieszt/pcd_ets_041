import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'vision_controller.dart';
import 'damage_painter.dart';

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
    _requestPermissionAndInit();
  }

  // Minta permission dulu, baru init controller
  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _visionController = VisionController();
      _visionController.startMockDetection();
      setState(() {});
    } else {
      // Tampilkan pesan jika permission ditolak
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin kamera diperlukan!')),
        );
      }
    }
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Smart-Patrol Vision"),
        actions: [
          // Tombol flashlight
          ListenableBuilder(
            listenable: _visionController,
            builder: (context, _) => IconButton(
              icon: Icon(
                _visionController.isFlashlightOn
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _visionController.toggleFlashlight,
            ),
          ),
          // Tombol overlay
          ListenableBuilder(
            listenable: _visionController,
            builder: (context, _) => IconButton(
              icon: Icon(
                _visionController.isOverlayVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: _visionController.toggleOverlay,
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
          return Column(
            children: [
              // Area kamera (pakai Expanded agar mengisi ruang)
              Expanded(child: _buildVisionStack()),
              // Panel filter di bawah
              _buildFilterPanel(),
            ],
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _visionController,
        builder: (context, _) => FloatingActionButton(
          onPressed: () async {
            final image = await _visionController.takePhoto();
            if (image != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Foto disimpan: ${image.path}')),
              );
            }
          },
          child: const Icon(Icons.camera),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Menghubungkan ke Sensor Visual...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (_visionController.errorMessage != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _visionController.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text("Buka Pengaturan"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisionStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // LAYER 1: Camera Preview dengan filter warna
        Center(
          child: AspectRatio(
            aspectRatio: _visionController.controller!.value.aspectRatio,
            child: _buildFilteredPreview(),
          ),
        ),

        // LAYER 2: Detection overlay
        if (_visionController.isOverlayVisible)
          Positioned.fill(
            child: CustomPaint(
              painter: DamagePainter(_visionController.currentDetections),
            ),
          ),

        // LAYER 3: Label filter aktif (pojok kiri atas)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _visionController.currentFilter.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // Terapkan ColorFilter di atas CameraPreview
  Widget _buildFilteredPreview() {
    final colorFilter = _visionController.currentFilter.colorFilter;
    final preview = CameraPreview(_visionController.controller!);

    if (colorFilter == null) {
      return preview; // Mode normal, tidak ada filter
    }

    return ColorFiltered(
      colorFilter: colorFilter,
      child: preview,
    );
  }

  // Panel pilihan filter di bagian bawah
  Widget _buildFilterPanel() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Filter',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: CameraFilter.values.length,
              itemBuilder: (context, index) {
                final filter = CameraFilter.values[index];
                final isSelected =
                    _visionController.currentFilter == filter;
                return GestureDetector(
                  onTap: () => _visionController.setFilter(filter),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 65,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.indigo
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.indigoAccent, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filterIcon(filter),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filter.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _filterIcon(CameraFilter filter) {
    switch (filter) {
      case CameraFilter.normal:
        return Icons.photo_camera;
      case CameraFilter.grayscale:
        return Icons.contrast;
      case CameraFilter.sepia:
        return Icons.wb_sunny_outlined;
      case CameraFilter.inverted:
        return Icons.invert_colors;
      case CameraFilter.cool:
        return Icons.ac_unit;
      case CameraFilter.warm:
        return Icons.local_fire_department;
    }
  }
}