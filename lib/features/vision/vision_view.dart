import 'dart:io';
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
  late VisionController _ctrl;
  String? _lastPhotoPath;

  @override
  void initState() {
    super.initState();
    _ctrl = VisionController();
    _ctrl.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  //  CAPTURE
  // ─────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    final image = await _ctrl.takePhoto();
    if (image == null || !mounted) return;
    setState(() => _lastPhotoPath = image.path);
    _showPhotoPreview(image.path);
  }

  void _showPhotoPreview(String path) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoPreviewSheet(
        imagePath: path,
        filterName: _ctrl.currentFilter,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildFilterBar(),
      floatingActionButton: _ctrl.isInitialized
          ? FloatingActionButton(
              onPressed: _capturePhoto,
              backgroundColor: Colors.white,
              child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black87,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Smart Vision Camera',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          Text(
            _ctrl.isInitialized
                ? 'Filter: ${_ctrl.currentFilter}'
                : 'Menghubungkan ke Sensor Visual...',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Flashlight (Homework 1)
        IconButton(
          icon: Icon(
            _ctrl.isFlashlightOn ? Icons.flashlight_on : Icons.flashlight_off,
            color: _ctrl.isFlashlightOn ? Colors.yellow : Colors.white,
          ),
          tooltip: 'Flash',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleFlashlight : null,
        ),
        // Toggle overlay painter (Homework 1)
        IconButton(
          icon: Icon(
            _ctrl.isOverlayEnabled ? Icons.layers : Icons.layers_clear,
            color: _ctrl.isOverlayEnabled ? Colors.lightBlueAccent : Colors.white54,
          ),
          tooltip: _ctrl.isOverlayEnabled ? 'Sembunyikan Overlay' : 'Tampilkan Overlay',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleOverlay : null,
        ),
        // Toggle filter stream (Homework 1)
        IconButton(
          icon: Icon(
            _ctrl.isFilterEnabled ? Icons.filter_vintage : Icons.filter_vintage_outlined,
            color: _ctrl.isFilterEnabled ? Colors.blue : Colors.white54,
          ),
          tooltip: _ctrl.isFilterEnabled ? 'Matikan Filter' : 'Aktifkan Filter',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleFilter : null,
        ),
        // Thumbnail foto terakhir
        if (_lastPhotoPath != null)
          GestureDetector(
            onTap: () => _showPhotoPreview(_lastPhotoPath!),
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 8, 10, 8),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white38, width: 1.5),
                image: DecorationImage(
                  image: FileImage(File(_lastPhotoPath!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  BODY
  // ─────────────────────────────────────────────

  Widget _buildBody() {
    // Homework 2: Permission denied screen
    if (_ctrl.errorMessage == 'CAMERA_DENIED') {
      return _buildPermissionDeniedScreen();
    }

    // Loading / error screen
    if (!_ctrl.isInitialized) {
      return _buildLoadingScreen();
    }

    return _buildCameraView();
  }

  /// Homework 2: Loading dengan teks instruksional
  Widget _buildLoadingScreen() {
    final hasError = _ctrl.errorMessage != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!hasError) ...[
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Menghubungkan ke Sensor Visual...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Mohon tunggu, mempersiapkan kamera belakang.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.error_outline, color: Colors.orange, size: 56),
              const SizedBox(height: 16),
              Text(
                _ctrl.errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Homework 2: "No Camera Access" + tombol "Open Settings"
  Widget _buildPermissionDeniedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_photography, color: Colors.redAccent, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Camera Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aplikasi membutuhkan izin kamera untuk mendeteksi kerusakan jalan.\n\n'
              'Buka Settings dan aktifkan izin kamera untuk aplikasi ini.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Tombol Open Settings (Homework 2)
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _ctrl.initCamera(),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CAMERA VIEW — FIX: AspectRatio portrait yang benar
  // ─────────────────────────────────────────────

  Widget _buildCameraView() {
    final cam = _ctrl.controller!;

    // FIX GEPENG: Kamera Android mengembalikan aspectRatio landscape (misal 4/3 = 1.33).
    // Untuk portrait, kita perlu membaliknya: 1 / aspectRatio.
    // Cara aman: ambil rasio dari lebar/tinggi preview value.
    final previewSize = cam.value.previewSize;
    double previewAspect;
    if (previewSize != null) {
      // previewSize.width dan .height selalu dalam orientasi landscape dari sensor
      // Untuk portrait: aspek = height/width (nilai < 1 untuk landscape, > 1 untuk portrait)
      previewAspect = previewSize.height / previewSize.width;
    } else {
      previewAspect = 1 / cam.value.aspectRatio;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Camera Preview (native, tidak gepeng) ──
        Center(
          child: AspectRatio(
            aspectRatio: previewAspect,
            child: CameraPreview(cam),
          ),
        ),

        // ── Layer 2: Filtered overlay (hanya saat non-Original & ada bytes) ──
        if (_ctrl.isFilterEnabled &&
            _ctrl.currentFilter != 'Original' &&
            _ctrl.processedImageBytes != null)
          Center(
            child: AspectRatio(
              aspectRatio: previewAspect,
              child: Image.memory(
                _ctrl.processedImageBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),

        // ── Layer 3: DamagePainter overlay (Task 3 + Task 4, Homework 1 toggle) ──
        if (_ctrl.isOverlayEnabled)
          CustomPaint(
            painter: DamagePainter(
              results: _ctrl.detections,
              showSearching: true,
            ),
            child: const SizedBox.expand(),
          ),

        // ── Layer 4: Filter badge ──
        Positioned(
          top: 12,
          left: 12,
          child: _buildFilterBadge(),
        ),
      ],
    );
  }

  Widget _buildFilterBadge() {
    final active = _ctrl.isFilterEnabled && _ctrl.currentFilter != 'Original';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.blue.withOpacity(0.8) : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          active ? Icons.auto_fix_high : Icons.camera_alt_outlined,
          color: Colors.white,
          size: 13,
        ),
        const SizedBox(width: 5),
        Text(
          active ? _ctrl.currentFilter : 'Original',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  FILTER BAR (bottom)
  // ─────────────────────────────────────────────

  Widget _buildFilterBar() {
    if (!_ctrl.isInitialized) return const SizedBox.shrink();

    return Container(
      height: 108,
      color: Colors.black87,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 3),
          child: Text(
            _ctrl.isFilterEnabled ? 'Pilih Filter' : 'Filter Dinonaktifkan',
            style: TextStyle(
              color: _ctrl.isFilterEnabled ? Colors.white54 : Colors.white24,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _ctrl.availableFilters.length,
            itemBuilder: (_, i) {
              final name = _ctrl.availableFilters[i];
              final selected = _ctrl.currentFilter == name;
              final enabled = _ctrl.isFilterEnabled;
              return GestureDetector(
                onTap: enabled ? () => _ctrl.setFilter(name) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 74,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected && enabled
                        ? Colors.blue.shade700
                        : Colors.grey.shade800.withOpacity(enabled ? 1 : 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected && enabled ? Colors.blue.shade300 : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_filterIcon(name),
                        color: enabled ? Colors.white : Colors.white38, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  IconData _filterIcon(String name) {
    switch (name) {
      case 'Grayscale':      return Icons.gradient;
      case 'Sepia':          return Icons.wb_sunny_outlined;
      case 'Inverted':       return Icons.invert_colors;
      case 'High Contrast':  return Icons.contrast;
      case 'Edge Detection': return Icons.border_outer;
      default:               return Icons.camera_alt_outlined;
    }
  }
}

// ─────────────────────────────────────────────
//  PHOTO PREVIEW BOTTOM SHEET
// ─────────────────────────────────────────────

class _PhotoPreviewSheet extends StatelessWidget {
  final String imagePath;
  final String filterName;

  const _PhotoPreviewSheet({required this.imagePath, required this.filterName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Foto Terambil',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Filter: $filterName',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        // Photo
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
        // Info
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Foto berhasil disimpan',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  imagePath.split('/').last,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}