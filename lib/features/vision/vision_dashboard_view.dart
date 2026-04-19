// File: lib/features/vision/vision_dashboard_view.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
  final List<int> histogramGray;   // 256 bins
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
//  MAIN VIEW
// ─────────────────────────────────────────────
class VisionDashboardView extends StatefulWidget {
  const VisionDashboardView({super.key});

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
  double _brightness = 1.0;   // 0.2 – 2.0
  double _contrast = 1.0;     // 0.2 – 3.0
  ConvolutionEffect _convolution = ConvolutionEffect.none;

  // ── Animation ──
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
    setState(() => _isProcessing = true);
    _originalFile = file;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      setState(() => _isProcessing = false);
      return;
    }

    await _applyFilters(decoded);
    _fadeCtrl.forward(from: 0);
  }

  // ─────────────────────────────────────────────
  //  FILTER ENGINE
  // ─────────────────────────────────────────────

  Future<void> _applyFilters(img.Image? source) async {
    if (source == null && _originalFile == null) return;

    setState(() => _isProcessing = true);

    final bytes = source == null
        ? await _originalFile!.readAsBytes()
        : Uint8List.fromList(img.encodePng(source));

    final decoded = source ?? img.decodeImage(bytes);
    if (decoded == null) {
      setState(() => _isProcessing = false);
      return;
    }

    img.Image processed = decoded;

    // Apply brightness & contrast
    if (_brightness != 1.0 || _contrast != 1.0) {
      processed = img.adjustColor(
        processed,
        brightness: _brightness,
        contrast: _contrast,
      );
    }

    // Apply convolution
    switch (_convolution) {
      case ConvolutionEffect.blur:
        processed = img.gaussianBlur(processed, radius: 4);
        break;
      case ConvolutionEffect.sharpen:
        processed = _applySharpen(processed);
        break;
      case ConvolutionEffect.edge:
        processed = img.sobel(img.grayscale(processed));
        break;
      case ConvolutionEffect.none:
        break;
    }

    // Compute stats
    final stats = _computeStats(processed);

    setState(() {
      _processedBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 90));
      _stats = stats;
      _isProcessing = false;
    });
  }

  img.Image _applySharpen(img.Image src) {
    return img.convolution(src, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0,
    ], div: 1, offset: 0);
  }

  Future<void> _reprocess() async {
    if (_originalFile == null) return;
    final bytes = await _originalFile!.readAsBytes();
    final decoded = img.decodeImage(bytes);
    await _applyFilters(decoded);
  }

  // ─────────────────────────────────────────────
  //  STATISTICS
  // ─────────────────────────────────────────────

  ImageStats _computeStats(img.Image image) {
    // Sample every 4th pixel for performance
    const step = 4;
    final histGray = List<int>.filled(256, 0);
    final histR    = List<int>.filled(256, 0);
    final histG    = List<int>.filled(256, 0);
    final histB    = List<int>.filled(256, 0);

    double sum = 0;
    double minI = 255, maxI = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt().clamp(0, 255);
        final g = p.g.toInt().clamp(0, 255);
        final b = p.b.toInt().clamp(0, 255);
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

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

  void _resetFilters() {
    setState(() {
      _brightness = 1.0;
      _contrast = 1.0;
      _convolution = ConvolutionEffect.none;
    });
    _reprocess();
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
          child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
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
        // Tombol Live Camera
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VisionView()),
            ),
            icon: const Icon(Icons.videocam, size: 16),
            label: const Text('Live', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          if (_stats != null) ...[
            const SizedBox(height: 16),
            _buildFilterControls(),
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
          sublabel: 'Preview real-time',
          gradient: const [Color(0xFF00D4FF), Color(0xFF0099CC)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VisionView()),
          ),
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
                        style:
                            TextStyle(color: Color(0xFF6C7A8D), fontSize: 13)),
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
                        const Text('Pilih gambar untuk mulai analisis',
                            style: TextStyle(
                                color: Color(0xFF6C7A8D), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _processedBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
    );
  }

  // ─────────────────────────────────────────────
  //  FILTER CONTROLS
  // ─────────────────────────────────────────────

  Widget _buildFilterControls() {
    return _DashboardCard(
      title: 'Pengaturan Filter',
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
          // Brightness Slider
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
              _debounceReprocess();
            },
          ),
          const SizedBox(height: 12),
          // Contrast Slider
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
              _debounceReprocess();
            },
          ),
          const SizedBox(height: 16),
          // Convolution Effect
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
                    _reprocess();
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
                          color:
                              selected ? Colors.white : const Color(0xFF6C7A8D),
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
        ],
      ),
    );
  }

  // Debounce untuk slider
  DateTime _lastSliderChange = DateTime(0);
  void _debounceReprocess() {
    _lastSliderChange = DateTime.now();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (DateTime.now().difference(_lastSliderChange).inMilliseconds >= 380) {
        _reprocess();
      }
    });
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
                label: 'Total Piksel Sampel',
                value: '${s.totalPixels.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
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
            data: _stats!.histogramGray,
            color: Colors.white,
          ),
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
                style: const TextStyle(
                    color: Color(0xFF6C7A8D), fontSize: 11)),
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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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

    // Gradient fill
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

    // Axis line
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = const Color(0xFF2A3147)..strokeWidth = 1,
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
      painter: _RGBHistPainter(dataR: dataR, dataG: dataG, dataB: dataB),
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
    final allMax = [
      ...dataR,
      ...dataG,
      ...dataB,
    ].reduce(max).toDouble();
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
        path,
        Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.fill,
      );

      // Stroke
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
          ..strokeWidth = 1.2,
      );
    }

    drawChannel(dataB, Colors.blue);
    drawChannel(dataG, Colors.green);
    drawChannel(dataR, Colors.red);

    // Axis
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = const Color(0xFF2A3147)..strokeWidth = 1,
    );

    // Legend
    const legendStyle = TextStyle(fontSize: 9);
    final legends = [
      ('R', Colors.red),
      ('G', Colors.green),
      ('B', Colors.blue),
    ];
    for (int i = 0; i < legends.length; i++) {
      final (label, color) = legends[i];
      final tp = TextPainter(
        text: TextSpan(text: label, style: legendStyle.copyWith(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8 + i * 24.0, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _RGBHistPainter old) =>
      old.dataR != dataR || old.dataG != dataG || old.dataB != dataB;
}