// File: lib/features/vision/vision_view.dart
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

  // Filter strength (0.0 – 1.0)
  double _filterStrength = 1.0;

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
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: _ctrl.isInitialized
          ? FloatingActionButton(
              onPressed: _capturePhoto,
              backgroundColor: Colors.white,
              child:
                  const Icon(Icons.camera_alt, color: Colors.black, size: 30),
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
                ? 'Filter: ${_ctrl.currentFilter} · ${(_filterStrength * 100).round()}%'
                : 'Menghubungkan ke Sensor Visual...',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Flashlight
        IconButton(
          icon: Icon(
            _ctrl.isFlashlightOn ? Icons.flashlight_on : Icons.flashlight_off,
            color: _ctrl.isFlashlightOn ? Colors.yellow : Colors.white,
          ),
          tooltip: 'Flash',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleFlashlight : null,
        ),
        // Toggle overlay
        IconButton(
          icon: Icon(
            _ctrl.isOverlayEnabled ? Icons.layers : Icons.layers_clear,
            color: _ctrl.isOverlayEnabled
                ? Colors.lightBlueAccent
                : Colors.white54,
          ),
          tooltip: _ctrl.isOverlayEnabled
              ? 'Sembunyikan Overlay'
              : 'Tampilkan Overlay',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleOverlay : null,
        ),
        // Toggle filter stream
        IconButton(
          icon: Icon(
            _ctrl.isFilterEnabled
                ? Icons.filter_vintage
                : Icons.filter_vintage_outlined,
            color: _ctrl.isFilterEnabled ? Colors.blue : Colors.white54,
          ),
          tooltip: _ctrl.isFilterEnabled
              ? 'Matikan Filter'
              : 'Aktifkan Filter',
          onPressed: _ctrl.isInitialized ? _ctrl.toggleFilter : null,
        ),
        // Thumbnail
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
    if (_ctrl.errorMessage == 'CAMERA_DENIED') {
      return _buildPermissionDeniedScreen();
    }
    if (!_ctrl.isInitialized) {
      return _buildLoadingScreen();
    }
    return _buildCameraView();
  }

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
                    color: Colors.white, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              const Text('Menghubungkan ke Sensor Visual...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Mohon tunggu, mempersiapkan kamera belakang.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center),
            ] else ...[
              const Icon(Icons.error_outline, color: Colors.orange, size: 56),
              const SizedBox(height: 16),
              Text(_ctrl.errorMessage!,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

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
              child: const Icon(Icons.no_photography,
                  color: Colors.redAccent, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('No Camera Access',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Aplikasi membutuhkan izin kamera untuk mendeteksi kerusakan jalan.\n\n'
              'Buka Settings dan aktifkan izin kamera untuk aplikasi ini.',
              style:
                  TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _ctrl.initCamera(),
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CAMERA VIEW
  // ─────────────────────────────────────────────

  Widget _buildCameraView() {
    final cam = _ctrl.controller!;
    final previewSize = cam.value.previewSize;
    double previewAspect;
    if (previewSize != null) {
      previewAspect = previewSize.height / previewSize.width;
    } else {
      previewAspect = 1 / cam.value.aspectRatio;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Camera Preview
        Center(
          child: AspectRatio(
            aspectRatio: previewAspect,
            child: CameraPreview(cam),
          ),
        ),

        // Layer 2: Filtered overlay
        if (_ctrl.isFilterEnabled &&
            _ctrl.currentFilter != 'Original' &&
            _ctrl.processedImageBytes != null)
          Center(
            child: AspectRatio(
              aspectRatio: previewAspect,
              child: Opacity(
                opacity: _filterStrength,
                child: Image.memory(
                  _ctrl.processedImageBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),

        // Layer 3: DamagePainter overlay
        if (_ctrl.isOverlayEnabled)
          CustomPaint(
            painter: DamagePainter(
              results: _ctrl.detections,
              showSearching: true,
            ),
            child: const SizedBox.expand(),
          ),

        // Layer 4: Filter badge
        Positioned(
          top: 12,
          left: 12,
          child: _buildFilterBadge(),
        ),

        // Layer 5: Strength slider (hanya saat filter aktif & bukan Original)
        if (_ctrl.isFilterEnabled && _ctrl.currentFilter != 'Original')
          Positioned(
            top: 60,
            left: 12,
            right: 12,
            child: _buildStrengthSlider(),
          ),
      ],
    );
  }

  Widget _buildFilterBadge() {
    final active =
        _ctrl.isFilterEnabled && _ctrl.currentFilter != 'Original';
    final filterMeta = _filterMeta(_ctrl.currentFilter);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? filterMeta.color.withOpacity(0.85)
            : Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active
                ? filterMeta.color.withOpacity(0.5)
                : Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(active ? filterMeta.icon : Icons.camera_alt_outlined,
            color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(
          active ? _ctrl.currentFilter : 'Original',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        if (active) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(_filterStrength * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildStrengthSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Icon(Icons.exposure, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        const Text('Kekuatan',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _filterStrength,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => setState(() => _filterStrength = v),
            ),
          ),
        ),
        Text(
          '${(_filterStrength * 100).round()}%',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  BOTTOM BAR: Filter + Category Tabs
  // ─────────────────────────────────────────────

  Widget _buildBottomBar() {
    if (!_ctrl.isInitialized) return const SizedBox.shrink();

    // Group filters by category
    final categories = _filterCategories();

    return Container(
      height: 130,
      color: Colors.black87,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            _ctrl.isFilterEnabled ? 'Pilih Filter' : 'Filter Dinonaktifkan',
            style: TextStyle(
                color: _ctrl.isFilterEnabled
                    ? Colors.white54
                    : Colors.white24,
                fontSize: 11),
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final entry in categories.entries)
                for (final filterName in entry.value)
                  _buildFilterTile(filterName),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterTile(String name) {
    final selected = _ctrl.currentFilter == name;
    final enabled = _ctrl.isFilterEnabled;
    final meta = _filterMeta(name);

    return GestureDetector(
      onTap: enabled
          ? () {
              _ctrl.setFilter(name);
              if (name == 'Original') {
                setState(() => _filterStrength = 1.0);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected && enabled
              ? meta.color.withOpacity(0.25)
              : Colors.grey.shade800.withOpacity(enabled ? 1 : 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected && enabled
                ? meta.color
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(meta.icon,
              color: enabled
                  ? (selected ? meta.color : Colors.white70)
                  : Colors.white38,
              size: 22),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
                color: enabled
                    ? (selected ? meta.color : Colors.white70)
                    : Colors.white38,
                fontSize: 8.5,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  FILTER META & CATEGORIES
  // ─────────────────────────────────────────────

  _FilterMeta _filterMeta(String name) {
    switch (name) {
      case 'Grayscale':
        return _FilterMeta(Icons.gradient, Colors.grey);
      case 'Sepia':
        return _FilterMeta(Icons.wb_sunny_outlined, const Color(0xFFC8A46E));
      case 'Inverted':
        return _FilterMeta(Icons.invert_colors, Colors.purple);
      case 'High Contrast':
        return _FilterMeta(Icons.contrast, Colors.cyan);
      case 'Edge Detection':
        return _FilterMeta(Icons.border_outer, Colors.white);
      case 'Warm':
        return _FilterMeta(Icons.local_fire_department, Colors.orange);
      case 'Cold':
        return _FilterMeta(Icons.ac_unit, Colors.lightBlue);
      case 'Vivid':
        return _FilterMeta(Icons.color_lens, Colors.pink);
      case 'Fade':
        return _FilterMeta(Icons.flare, Colors.grey.shade400);
      case 'Red':
        return _FilterMeta(Icons.circle, Colors.red);
      case 'Green':
        return _FilterMeta(Icons.circle, Colors.green);
      case 'Blue':
        return _FilterMeta(Icons.circle, Colors.blue);
      case 'Cyan':
        return _FilterMeta(Icons.circle, Colors.cyan);
      case 'Yellow':
        return _FilterMeta(Icons.circle, Colors.yellow);
      case 'Magenta':
        return _FilterMeta(Icons.circle, Colors.pink);
      case 'Noir':
        return _FilterMeta(Icons.dark_mode, Colors.grey.shade300);
      case 'Posterize':
        return _FilterMeta(Icons.auto_awesome, Colors.deepOrange);
      case 'Emboss':
        return _FilterMeta(Icons.layers_outlined, Colors.teal);
      default:
        return _FilterMeta(Icons.camera_alt_outlined, Colors.white);
    }
  }

  Map<String, List<String>> _filterCategories() {
    return {
      'Original': ['Original'],
      'Classic': ['Grayscale', 'Sepia', 'Noir', 'Fade'],
      'Tone': ['Warm', 'Cold', 'Vivid'],
      'Color': ['Red', 'Green', 'Blue', 'Cyan', 'Yellow', 'Magenta'],
      'Effect': [
        'Inverted',
        'High Contrast',
        'Edge Detection',
        'Posterize',
        'Emboss'
      ],
    };
  }
}

class _FilterMeta {
  final IconData icon;
  final Color color;
  const _FilterMeta(this.icon, this.color);
}

// ─────────────────────────────────────────────
//  PHOTO PREVIEW BOTTOM SHEET
// ─────────────────────────────────────────────

class _PhotoPreviewSheet extends StatelessWidget {
  final String imagePath;
  final String filterName;

  const _PhotoPreviewSheet(
      {required this.imagePath, required this.filterName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Foto Terambil',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text('Filter: $filterName',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ]),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Foto berhasil disimpan',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(
                      imagePath.split('/').last,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
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