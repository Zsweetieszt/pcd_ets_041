// File: lib/features/vision/vision_dashboard_view.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'vision_view.dart';

// ─────────────────────────────────────────────
//  MODEL: Statistik Distribusi Kontras
// ─────────────────────────────────────────────
class ImageStats {
  final int totalPixels;
  final double minIntensity;
  final double maxIntensity;
  final double meanGray;
  final double stdDevGray;
  final double contrast;
  final List<int> histogramGray;
  final List<int> histogramR;
  final List<int> histogramG;
  final List<int> histogramB;

  const ImageStats({
    required this.totalPixels,
    required this.minIntensity,
    required this.maxIntensity,
    required this.meanGray,
    required this.stdDevGray,
    required this.contrast,
    required this.histogramGray,
    required this.histogramR,
    required this.histogramG,
    required this.histogramB,
  });
}

// ─────────────────────────────────────────────
//  ENUM: Efek Konvolusi
// ─────────────────────────────────────────────
enum ConvolutionEffect { none, blur, sharpen, edge }

// ─────────────────────────────────────────────
//  ISOLATE: Payload untuk background processing
// ─────────────────────────────────────────────
class _ProcessPayload {
  final Uint8List imageBytes;
  final double brightness;
  final double contrast;
  final ConvolutionEffect convolution;
  final String filterName; // filter dari live camera
  final bool equalizeHistogram;
  final SendPort sendPort;

  const _ProcessPayload({
    required this.imageBytes,
    required this.brightness,
    required this.contrast,
    required this.convolution,
    required this.filterName,
    required this.equalizeHistogram,
    required this.sendPort,
  });
}

class _ProcessResult {
  final Uint8List? processedBytes;
  final ImageStats? stats;
  final String? error;

  const _ProcessResult({this.processedBytes, this.stats, this.error});
}

// ─────────────────────────────────────────────
//  TOP-LEVEL FUNCTION untuk isolate (harus top-level)
// ─────────────────────────────────────────────
void _imageProcessIsolate(_ProcessPayload payload) {
  try {
    final decoded = img.decodeImage(payload.imageBytes);
    if (decoded == null) {
      payload.sendPort.send(const _ProcessResult(error: 'Gagal decode gambar'));
      return;
    }

    // Resize dulu untuk performa jika gambar besar
    img.Image working = decoded;
    if (decoded.width > 1200 || decoded.height > 1200) {
      final scale = 1200 / max(decoded.width, decoded.height);
      working = img.copyResize(decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round());
    }

    img.Image processed = working;

    // 1. Apply camera-style filter dulu
    processed = _applyNamedFilter(processed, payload.filterName);

    // 2. Apply brightness & contrast
    if (payload.brightness != 1.0 || payload.contrast != 1.0) {
      processed = img.adjustColor(
        processed,
        brightness: payload.brightness,
        contrast: payload.contrast,
      );
    }

    // 3. Apply convolution
    switch (payload.convolution) {
      case ConvolutionEffect.blur:
        processed = img.gaussianBlur(processed, radius: 3);
        break;
      case ConvolutionEffect.sharpen:
        processed = img.convolution(processed,
            filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1, offset: 0);
        break;
      case ConvolutionEffect.edge:
        processed = img.sobel(img.grayscale(processed));
        break;
      case ConvolutionEffect.none:
        break;
    }

    // 4. Histogram Equalization (opsional)
    if (payload.equalizeHistogram) {
      processed = _histogramEqualize(processed);
    }

    // 5. Compute stats
    final stats = _computeStatsInternal(processed);

    final resultBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
    payload.sendPort.send(_ProcessResult(processedBytes: resultBytes, stats: stats));
  } catch (e) {
    payload.sendPort.send(_ProcessResult(error: e.toString()));
  }
}

// Filter engine (mirroring VisionController) — top-level untuk isolate
img.Image _applyNamedFilter(img.Image src, String name) {
  switch (name) {
    case 'Grayscale':
      return img.grayscale(src);
    case 'Sepia':
      return img.sepia(src);
    case 'Noir':
      final gray = img.grayscale(src);
      return img.adjustColor(gray, contrast: 2.0, brightness: 0.9);
    case 'Fade':
      return img.adjustColor(src,
          saturation: 0.3, brightness: 1.15, contrast: 0.7);
    case 'Warm':
      return _colorBalance(src, rShift: 30, gShift: 10, bShift: -20);
    case 'Cold':
      return _colorBalance(src, rShift: -20, gShift: 10, bShift: 35);
    case 'Vivid':
      return img.adjustColor(src, saturation: 2.0, contrast: 1.3);
    case 'Red':
      return _colorTint(src, r: 255, g: 0, b: 0);
    case 'Green':
      return _colorTint(src, r: 0, g: 255, b: 0);
    case 'Blue':
      return _colorTint(src, r: 0, g: 0, b: 255);
    case 'Cyan':
      return _colorTint(src, r: 0, g: 255, b: 255, strength: 0.35);
    case 'Yellow':
      return _colorTint(src, r: 255, g: 255, b: 0, strength: 0.35);
    case 'Magenta':
      return _colorTint(src, r: 255, g: 0, b: 255, strength: 0.35);
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

img.Image _colorTint(img.Image src,
    {required int r, required int g, required int b, double strength = 0.4}) {
  final result = img.Image(width: src.width, height: src.height);
  final inv = 1.0 - strength;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final nr = (p.r.toDouble() * inv + r * strength).round().clamp(0, 255);
      final ng = (p.g.toDouble() * inv + g * strength).round().clamp(0, 255);
      final nb = (p.b.toDouble() * inv + b * strength).round().clamp(0, 255);
      result.setPixelRgba(x, y, nr, ng, nb, 255);
    }
  }
  return result;
}

img.Image _colorBalance(img.Image src,
    {int rShift = 0, int gShift = 0, int bShift = 0}) {
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

/// Histogram Equalization — meratakan distribusi intensitas per channel R/G/B
/// sehingga kontras gambar meningkat secara global.
img.Image _histogramEqualize(img.Image src) {
  // Bangun histogram untuk setiap channel
  final histR = List<int>.filled(256, 0);
  final histG = List<int>.filled(256, 0);
  final histB = List<int>.filled(256, 0);

  final totalPixels = src.width * src.height;

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      histR[p.r.toInt().clamp(0, 255)]++;
      histG[p.g.toInt().clamp(0, 255)]++;
      histB[p.b.toInt().clamp(0, 255)]++;
    }
  }

  // Bangun CDF (Cumulative Distribution Function) dan lookup table
  final lut = List.generate(3, (_) => List<int>.filled(256, 0));

  // R channel
  int cumR = 0, minCdfR = -1;
  for (int i = 0; i < 256; i++) {
    cumR += histR[i];
    if (histR[i] > 0 && minCdfR == -1) minCdfR = cumR;
  }
  minCdfR = minCdfR == -1 ? 0 : minCdfR;
  cumR = 0;
  for (int i = 0; i < 256; i++) {
    cumR += histR[i];
    final denom = totalPixels - minCdfR;
    lut[0][i] = denom == 0
        ? i
        : ((cumR - minCdfR) / denom * 255).round().clamp(0, 255);
  }

  // G channel
  int cumG = 0, minCdfG = -1;
  for (int i = 0; i < 256; i++) {
    cumG += histG[i];
    if (histG[i] > 0 && minCdfG == -1) minCdfG = cumG;
  }
  minCdfG = minCdfG == -1 ? 0 : minCdfG;
  cumG = 0;
  for (int i = 0; i < 256; i++) {
    cumG += histG[i];
    final denom = totalPixels - minCdfG;
    lut[1][i] = denom == 0
        ? i
        : ((cumG - minCdfG) / denom * 255).round().clamp(0, 255);
  }

  // B channel
  int cumB = 0, minCdfB = -1;
  for (int i = 0; i < 256; i++) {
    cumB += histB[i];
    if (histB[i] > 0 && minCdfB == -1) minCdfB = cumB;
  }
  minCdfB = minCdfB == -1 ? 0 : minCdfB;
  cumB = 0;
  for (int i = 0; i < 256; i++) {
    cumB += histB[i];
    final denom = totalPixels - minCdfB;
    lut[2][i] = denom == 0
        ? i
        : ((cumB - minCdfB) / denom * 255).round().clamp(0, 255);
  }

  // Apply lookup table ke setiap piksel
  final result = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      result.setPixelRgba(
        x,
        y,
        lut[0][p.r.toInt().clamp(0, 255)],
        lut[1][p.g.toInt().clamp(0, 255)],
        lut[2][p.b.toInt().clamp(0, 255)],
        255,
      );
    }
  }
  return result;
}

ImageStats _computeStatsInternal(img.Image image) {
  const step = 4;
  final histGray = List<int>.filled(256, 0);
  final histR = List<int>.filled(256, 0);
  final histG = List<int>.filled(256, 0);
  final histB = List<int>.filled(256, 0);

  double sum = 0;
  double minI = 255, maxI = 0;
  int count = 0;

  for (int y = 0; y < image.height; y += step) {
    for (int x = 0; x < image.width; x += step) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt().clamp(0, 255);
      final g = p.g.toInt().clamp(0, 255);
      final b = p.b.toInt().clamp(0, 255);
      final gray =
          (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      histGray[gray]++;
      histR[r]++;
      histG[g]++;
      histB[b]++;
      sum += gray;
      if (gray < minI) minI = gray.toDouble();
      if (gray > maxI) maxI = gray.toDouble();
      count++;
    }
  }

  final mean = count > 0 ? sum / count : 0.0;
  double variance = 0;
  for (int y = 0; y < image.height; y += step) {
    for (int x = 0; x < image.width; x += step) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt().clamp(0, 255);
      final g = p.g.toInt().clamp(0, 255);
      final b = p.b.toInt().clamp(0, 255);
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).toDouble();
      variance += pow(gray - mean, 2);
    }
  }
  variance = count > 0 ? variance / count : 0;
  final stdDev = sqrt(variance);
  final contrast = maxI - minI;

  return ImageStats(
    totalPixels: count,
    minIntensity: minI,
    maxIntensity: maxI,
    meanGray: mean,
    stdDevGray: stdDev,
    contrast: contrast,
    histogramGray: histGray,
    histogramR: histR,
    histogramG: histG,
    histogramB: histB,
  );
}

// ─────────────────────────────────────────────
//  MAIN VIEW
// ─────────────────────────────────────────────
class VisionDashboardView extends StatefulWidget {
  // Foto yang langsung diteruskan dari VisionView (opsional)
  final String? initialImagePath;
  final String? initialFilterName;

  const VisionDashboardView({
    super.key,
    this.initialImagePath,
    this.initialFilterName,
  });

  @override
  State<VisionDashboardView> createState() => _VisionDashboardViewState();
}

class _VisionDashboardViewState extends State<VisionDashboardView>
    with SingleTickerProviderStateMixin {
  // ── State ──
  File? _originalFile;
  Uint8List? _processedBytes;
  ImageStats? _stats;
  bool _isProcessing = false;

  // ── Filter Controls ──
  double _brightness = 1.0;
  double _contrast = 1.0;
  ConvolutionEffect _convolution = ConvolutionEffect.none;
  bool _equalizeHistogram = false;

  // ── Camera-style filter (dari VisionController) ──
  String _selectedCameraFilter = 'Original';

  // Daftar filter yang sama dengan VisionController
  static const List<String> _cameraFilters = [
    'Original',
    'Grayscale', 'Sepia', 'Noir', 'Fade',
    'Warm', 'Cold', 'Vivid',
    'Red', 'Green', 'Blue', 'Cyan', 'Yellow', 'Magenta',
    'Inverted', 'High Contrast', 'Edge Detection', 'Posterize', 'Emboss',
  ];

  // ── Animation ──
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── Isolate & debounce ──
  Isolate? _currentIsolate;
  ReceivePort? _receivePort;
  DateTime _lastChange = DateTime(0);
  bool _pendingProcess = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Jika ada foto yang diteruskan dari live camera, load langsung
    if (widget.initialImagePath != null) {
      _selectedCameraFilter = widget.initialFilterName ?? 'Original';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadImage(File(widget.initialImagePath!));
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _currentIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  IMAGE PICKING
  // ─────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    await _loadImage(File(xfile.path));
  }

  Future<void> _loadImage(File file) async {
    _originalFile = file;
    await _runProcessInIsolate();
    _fadeCtrl.forward(from: 0);
  }

  // ─────────────────────────────────────────────
  //  ISOLATE-BASED PROCESSING
  // ─────────────────────────────────────────────

  Future<void> _runProcessInIsolate() async {
    if (_originalFile == null) return;

    // Batalkan isolate sebelumnya jika masih berjalan
    _currentIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();

    if (mounted) setState(() => _isProcessing = true);

    try {
      final bytes = await _originalFile!.readAsBytes();
      final receivePort = ReceivePort();
      _receivePort = receivePort;

      final payload = _ProcessPayload(
        imageBytes: bytes,
        brightness: _brightness,
        contrast: _contrast,
        convolution: _convolution,
        filterName: _selectedCameraFilter,
        equalizeHistogram: _equalizeHistogram,
        sendPort: receivePort.sendPort,
      );

      _currentIsolate = await Isolate.spawn(_imageProcessIsolate, payload);

      final result = await receivePort.first as _ProcessResult;
      _receivePort = null;
      _currentIsolate = null;

      if (!mounted) return;

      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }

      setState(() {
        _processedBytes = result.processedBytes;
        _stats = result.stats;
        _isProcessing = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Debounce untuk slider — tunggu 500ms setelah berhenti
  void _scheduleReprocess() {
    _lastChange = DateTime.now();
    if (_pendingProcess) return;
    _pendingProcess = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _pendingProcess = false;
      if (DateTime.now().difference(_lastChange).inMilliseconds >= 490) {
        _runProcessInIsolate();
      } else {
        _scheduleReprocess();
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _brightness = 1.0;
      _contrast = 1.0;
      _convolution = ConvolutionEffect.none;
      _equalizeHistogram = false;
      _selectedCameraFilter = 'Original';
    });
    _runProcessInIsolate();
  }

  // ─────────────────────────────────────────────
  //  OPEN LIVE CAMERA & RECEIVE PHOTO BACK
  // ─────────────────────────────────────────────

  Future<void> _openLiveCamera() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const VisionView()),
    );

    // VisionView akan push balik Map {'path': ..., 'filter': ...}
    if (result != null && result['path'] != null) {
      final path = result['path']!;
      final filter = result['filter'] ?? 'Original';
      setState(() => _selectedCameraFilter = filter);
      await _loadImage(File(path));
      _fadeCtrl.forward(from: 0);
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1220),
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.analytics_outlined,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vision Dashboard',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text('Analisis Citra & Filter',
                style: TextStyle(color: Color(0xFF6C7A8D), fontSize: 11)),
          ],
        ),
      ]),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: _openLiveCamera,
            icon: const Icon(Icons.videocam, size: 16),
            label: const Text('Live', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageSourceButtons(),
          const SizedBox(height: 16),
          _buildPreviewSection(),
          if (_originalFile != null) ...[
            const SizedBox(height: 16),
            _buildCameraFilterSection(),
            const SizedBox(height: 16),
            _buildFilterControls(),
          ],
          if (_stats != null) ...[
            const SizedBox(height: 16),
            _buildStatsSection(),
            const SizedBox(height: 16),
            _buildHistogramSection(),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SOURCE BUTTONS
  // ─────────────────────────────────────────────

  Widget _buildImageSourceButtons() {
    return Row(children: [
      Expanded(
        child: _SourceButton(
          icon: Icons.photo_library_outlined,
          label: 'Pilih dari Galeri',
          sublabel: 'JPG, PNG, dll',
          gradient: const [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
          onTap: _pickFromGallery,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _SourceButton(
          icon: Icons.videocam_outlined,
          label: 'Live Camera',
          sublabel: 'Foto langsung ke dashboard',
          gradient: const [Color(0xFF00D4FF), Color(0xFF0099CC)],
          onTap: _openLiveCamera,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  //  PREVIEW SECTION
  // ─────────────────────────────────────────────

  Widget _buildPreviewSection() {
    return _DashboardCard(
      title: 'Pratinjau Citra',
      icon: Icons.image_outlined,
      child: _isProcessing
          ? const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        color: Color(0xFF6C63FF), strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Memproses gambar...',
                        style: TextStyle(
                            color: Color(0xFF6C7A8D), fontSize: 13)),
                  ],
                ),
              ),
            )
          : _processedBytes == null
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 56, color: const Color(0xFF2A3147)),
                        const SizedBox(height: 12),
                        const Text(
                            'Pilih gambar atau ambil foto\nuntuk mulai analisis',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF6C7A8D), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _processedBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                      if (_selectedCameraFilter != 'Original') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _filterColor(_selectedCameraFilter)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _filterColor(_selectedCameraFilter)
                                    .withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_filterIcon(_selectedCameraFilter),
                                  color:
                                      _filterColor(_selectedCameraFilter),
                                  size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Filter: $_selectedCameraFilter',
                                style: TextStyle(
                                  color: _filterColor(_selectedCameraFilter),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ─────────────────────────────────────────────
  //  CAMERA FILTER SECTION (baru)
  // ─────────────────────────────────────────────

  Widget _buildCameraFilterSection() {
    return _DashboardCard(
      title: 'Filter Kamera',
      icon: Icons.filter_vintage_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih filter yang sama seperti di Live Camera',
            style: TextStyle(color: Color(0xFF6C7A8D), fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _cameraFilters.length,
              itemBuilder: (context, index) {
                final name = _cameraFilters[index];
                final selected = _selectedCameraFilter == name;
                final color = _filterColor(name);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCameraFilter = name);
                    _scheduleReprocess();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 68,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.25)
                          : const Color(0xFF1A2035),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? color
                            : const Color(0xFF2A3147),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_filterIcon(name),
                            color: selected ? color : const Color(0xFF6C7A8D),
                            size: 20),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            color: selected
                                ? color
                                : const Color(0xFF6C7A8D),
                            fontSize: 8.5,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  // ─────────────────────────────────────────────
  //  FILTER CONTROLS (brightness, contrast, convolution)
  // ─────────────────────────────────────────────

  Widget _buildFilterControls() {
    return _DashboardCard(
      title: 'Penyesuaian Lanjutan',
      icon: Icons.tune_outlined,
      trailing: TextButton.icon(
        onPressed: _resetFilters,
        icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF6C63FF)),
        label: const Text('Reset',
            style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            label: 'Kecerahan',
            icon: Icons.brightness_6_outlined,
            value: _brightness,
            min: 0.2,
            max: 2.0,
            color: const Color(0xFFFFD700),
            displayValue: '${(_brightness * 100).round()}%',
            onChanged: (v) {
              setState(() => _brightness = v);
              _scheduleReprocess();
            },
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: 'Kontras',
            icon: Icons.contrast,
            value: _contrast,
            min: 0.2,
            max: 3.0,
            color: const Color(0xFF00D4FF),
            displayValue: '${(_contrast * 100).round()}%',
            onChanged: (v) {
              setState(() => _contrast = v);
              _scheduleReprocess();
            },
          ),
          const SizedBox(height: 16),
          const Text('Efek Konvolusi',
              style: TextStyle(
                  color: Color(0xFF8A9BB0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ConvolutionEffect.values.map((e) {
              final selected = _convolution == e;
              final labels = {
                ConvolutionEffect.none: 'None',
                ConvolutionEffect.blur: 'Blur',
                ConvolutionEffect.sharpen: 'Sharpen',
                ConvolutionEffect.edge: 'Edge',
              };
              final icons = {
                ConvolutionEffect.none: Icons.crop_square,
                ConvolutionEffect.blur: Icons.blur_on,
                ConvolutionEffect.sharpen: Icons.auto_fix_high,
                ConvolutionEffect.edge: Icons.border_outer,
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _convolution = e);
                    _runProcessInIsolate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF1A2035),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF2A3147),
                      ),
                    ),
                    child: Column(children: [
                      Icon(icons[e]!,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6C7A8D),
                          size: 18),
                      const SizedBox(height: 4),
                      Text(labels[e]!,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6C7A8D),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // ── Histogram Equalization toggle ──
          const Text('Histogram Equalization',
              style: TextStyle(
                  color: Color(0xFF8A9BB0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              setState(() => _equalizeHistogram = !_equalizeHistogram);
              _runProcessInIsolate();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _equalizeHistogram
                    ? const Color(0xFF00D4FF).withOpacity(0.12)
                    : const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _equalizeHistogram
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF2A3147),
                  width: _equalizeHistogram ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _equalizeHistogram
                          ? const Color(0xFF00D4FF).withOpacity(0.2)
                          : const Color(0xFF2A3147),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.equalizer_rounded,
                      color: _equalizeHistogram
                          ? const Color(0xFF00D4FF)
                          : const Color(0xFF6C7A8D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equalize Histogram',
                          style: TextStyle(
                            color: _equalizeHistogram
                                ? const Color(0xFF00D4FF)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meratakan distribusi intensitas piksel untuk meningkatkan kontras global',
                          style: TextStyle(
                            color: _equalizeHistogram
                                ? const Color(0xFF00D4FF).withOpacity(0.7)
                                : const Color(0xFF6C7A8D),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _equalizeHistogram
                          ? const Color(0xFF00D4FF)
                          : const Color(0xFF2A3147),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: _equalizeHistogram
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  STATISTICS SECTION
  // ─────────────────────────────────────────────

  Widget _buildStatsSection() {
    final s = _stats!;
    return _DashboardCard(
      title: 'Distribusi Kontras',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: [
          Row(children: [
            _StatChip(
                label: 'Sampel Piksel',
                value: _formatNumber(s.totalPixels),
                color: const Color(0xFF6C63FF),
                icon: Icons.grid_4x4),
            const SizedBox(width: 8),
            _StatChip(
                label: 'Kontras',
                value: s.contrast.toStringAsFixed(1),
                color: const Color(0xFF00D4FF),
                icon: Icons.contrast),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatChip(
                label: 'Min Intensitas',
                value: s.minIntensity.toStringAsFixed(1),
                color: const Color(0xFF4CAF50),
                icon: Icons.arrow_downward),
            const SizedBox(width: 8),
            _StatChip(
                label: 'Max Intensitas',
                value: s.maxIntensity.toStringAsFixed(1),
                color: const Color(0xFFFF6B6B),
                icon: Icons.arrow_upward),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatChip(
                label: 'Mean Gray',
                value: s.meanGray.toStringAsFixed(2),
                color: const Color(0xFFFFD700),
                icon: Icons.functions),
            const SizedBox(width: 8),
            _StatChip(
                label: 'Std Dev Gray',
                value: s.stdDevGray.toStringAsFixed(2),
                color: const Color(0xFFFF9800),
                icon: Icons.show_chart),
          ]),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  // ─────────────────────────────────────────────
  //  HISTOGRAM SECTION
  // ─────────────────────────────────────────────

  Widget _buildHistogramSection() {
    return Column(children: [
      _DashboardCard(
        title: 'Histogram Grayscale',
        icon: Icons.equalizer_outlined,
        child: SizedBox(
          height: 120,
          child: _HistogramPainter(
              data: _stats!.histogramGray, color: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      _DashboardCard(
        title: 'Histogram RGB',
        icon: Icons.palette_outlined,
        child: SizedBox(
          height: 140,
          child: _RGBHistogramPainter(
            dataR: _stats!.histogramR,
            dataG: _stats!.histogramG,
            dataB: _stats!.histogramB,
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────
  //  FILTER META HELPERS
  // ─────────────────────────────────────────────

  IconData _filterIcon(String name) {
    switch (name) {
      case 'Grayscale': return Icons.gradient;
      case 'Sepia': return Icons.wb_sunny_outlined;
      case 'Inverted': return Icons.invert_colors;
      case 'High Contrast': return Icons.contrast;
      case 'Edge Detection': return Icons.border_outer;
      case 'Warm': return Icons.local_fire_department;
      case 'Cold': return Icons.ac_unit;
      case 'Vivid': return Icons.color_lens;
      case 'Fade': return Icons.flare;
      case 'Red': case 'Green': case 'Blue':
      case 'Cyan': case 'Yellow': case 'Magenta': return Icons.circle;
      case 'Noir': return Icons.dark_mode;
      case 'Posterize': return Icons.auto_awesome;
      case 'Emboss': return Icons.layers_outlined;
      default: return Icons.camera_alt_outlined;
    }
  }

  Color _filterColor(String name) {
    switch (name) {
      case 'Grayscale': case 'Noir': case 'Fade': return Colors.grey;
      case 'Sepia': return const Color(0xFFC8A46E);
      case 'Inverted': return Colors.purple;
      case 'High Contrast': return Colors.cyan;
      case 'Edge Detection': return Colors.white70;
      case 'Warm': return Colors.orange;
      case 'Cold': return Colors.lightBlue;
      case 'Vivid': return Colors.pink;
      case 'Red': return Colors.red;
      case 'Green': return Colors.green;
      case 'Blue': return Colors.blue;
      case 'Cyan': return Colors.cyan;
      case 'Yellow': return Colors.yellow;
      case 'Magenta': return Colors.pink;
      case 'Posterize': return Colors.deepOrange;
      case 'Emboss': return Colors.teal;
      default: return const Color(0xFF6C63FF);
    }
  }
}

// ─────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient.map((c) => c.withOpacity(0.15)).toList()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gradient[0].withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(sublabel,
                style:
                    const TextStyle(color: Color(0xFF6C7A8D), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2840)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF6C7A8D), fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final Color color;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A9BB0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(displayValue,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  HISTOGRAM PAINTERS
// ─────────────────────────────────────────────

class _HistogramPainter extends StatelessWidget {
  final List<int> data;
  final Color color;

  const _HistogramPainter({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _HistPainter(data: data, color: color),
    );
  }
}

class _HistPainter extends CustomPainter {
  final List<int> data;
  final Color color;

  const _HistPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce(max).toDouble();
    if (maxVal == 0) return;

    final barWidth = size.width / data.length;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final h = (data[i] / maxVal) * size.height;
      final t = i / 255.0;
      paint.color = Color.lerp(
              const Color(0xFF6C63FF), const Color(0xFF00D4FF), t)!
          .withOpacity(0.8);
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth, h),
        paint,
      );
    }

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = const Color(0xFF2A3147)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HistPainter old) =>
      old.data != data || old.color != color;
}

class _RGBHistogramPainter extends StatelessWidget {
  final List<int> dataR;
  final List<int> dataG;
  final List<int> dataB;

  const _RGBHistogramPainter({
    required this.dataR,
    required this.dataG,
    required this.dataB,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 140),
      painter:
          _RGBHistPainter(dataR: dataR, dataG: dataG, dataB: dataB),
    );
  }
}

class _RGBHistPainter extends CustomPainter {
  final List<int> dataR;
  final List<int> dataG;
  final List<int> dataB;

  const _RGBHistPainter(
      {required this.dataR, required this.dataG, required this.dataB});

  @override
  void paint(Canvas canvas, Size size) {
    final allMax = [...dataR, ...dataG, ...dataB].reduce(max).toDouble();
    if (allMax == 0) return;

    final barWidth = size.width / 256;

    void drawChannel(List<int> data, Color color) {
      final path = Path();
      path.moveTo(0, size.height);
      for (int i = 0; i < data.length; i++) {
        final h = (data[i] / allMax) * size.height;
        path.lineTo(i * barWidth, size.height - h);
      }
      path.lineTo(size.width, size.height);
      path.close();

      canvas.drawPath(
          path, Paint()..color = color.withOpacity(0.35)..style = PaintingStyle.fill);

      final strokePath = Path();
      strokePath.moveTo(0, size.height);
      for (int i = 0; i < data.length; i++) {
        final h = (data[i] / allMax) * size.height;
        strokePath.lineTo(i * barWidth, size.height - h);
      }
      canvas.drawPath(
          strokePath,
          Paint()
            ..color = color.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    drawChannel(dataB, Colors.blue);
    drawChannel(dataG, Colors.green);
    drawChannel(dataR, Colors.red);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = const Color(0xFF2A3147)..strokeWidth = 1,
    );

    const legendStyle = TextStyle(fontSize: 9);
    final legends = [('R', Colors.red), ('G', Colors.green), ('B', Colors.blue)];
    for (int i = 0; i < legends.length; i++) {
      final (label, color) = legends[i];
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: legendStyle.copyWith(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8 + i * 24.0, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _RGBHistPainter old) =>
      old.dataR != dataR || old.dataG != dataG || old.dataB != dataB;
}