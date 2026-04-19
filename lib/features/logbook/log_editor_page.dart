import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'models/log_model.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel? existingLog; // null = mode Tambah, diisi = mode Edit
  final String username;
  final String teamId;

  const LogEditorPage({
    super.key,
    this.existingLog,
    required this.username,
    required this.teamId,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  String _selectedCategory = 'Umum';
  bool _isPublic = false;

  static const List<String> _categories = [
    'Umum', 'Organisasi', 'Tugas', 'Kuliah', 'Pribadi', 'Urgent',
    'Mechanical', 'Electronic', 'Software',
  ];

  bool get _isEditMode => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Isi controller dengan data yang ada jika mode Edit
    _titleController = TextEditingController(
      text: widget.existingLog?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingLog?.description ?? '',
    );
    _selectedCategory = widget.existingLog?.category ?? 'Umum';
    _isPublic = widget.existingLog?.isPublic ?? false;

    // Update preview setiap kali teks berubah
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun',
                    'Jul','Ags','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Organisasi': return Colors.blue;
      case 'Tugas':      return Colors.orange;
      case 'Kuliah':     return Colors.green;
      case 'Pribadi':    return Colors.purple;
      case 'Urgent':     return Colors.red;
      default:           return Colors.blueGrey;
    }
  }

  void _handleSave() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul tidak boleh kosong!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Buat LogModel dari input user
    final savedLog = LogModel(
      id: widget.existingLog?.id, // kunci ID nya jika edit
      title: _titleController.text.trim(),
      description: _contentController.text.trim(),
      category: _selectedCategory,
      date: widget.existingLog?.date ?? _formatDate(DateTime.now()),
      username: widget.username,
      authorId: widget.username,
      teamId: widget.teamId,
      isPublic: _isPublic,
      isSynced: false,
    );

    Navigator.of(context).pop(savedLog);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Catatan' : 'Catatan Baru',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _handleSave,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Editor'),
            Tab(icon: Icon(Icons.preview), text: 'Pratinjau'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: EDITOR
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input Judul
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Judul Catatan',
                    hintText: 'Masukkan judul catatan...',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Dropdown Kategori
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(
                      Icons.label,
                      color: _getCategoryColor(_selectedCategory),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundColor: _getCategoryColor(cat),
                        ),
                        const SizedBox(width: 10),
                        Text(cat),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 16),

                // Toggle isPublic
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public : Icons.lock,
                        color: _isPublic ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Publik (tim bisa lihat)' : 'Privat (hanya kamu)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _isPublic
                                  ? 'Semua anggota tim dapat membaca catatan ini'
                                  : 'Hanya kamu yang dapat melihat catatan ini',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Label petunjuk Markdown
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.indigo.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mendukung Markdown: **bold**, *italic*, `kode`, # Heading, - List',
                          style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Textarea Konten (Markdown)
                TextField(
                  controller: _contentController,
                  maxLines: null,
                  minLines: 10,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: '# Judul Bagian\n\nTulis isi catatan di sini...\n\n**Teks Tebal**, *Miring*, `kode`\n\n- Item 1\n- Item 2',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          //TAB 2: PRATINJAU MARKDOWN
          _contentController.text.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.preview, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Pratinjau akan muncul\nsetelah Anda mulai menulis',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, height: 1.6),
                      ),
                    ],
                  ),
                )
              : Markdown(
                  data: _contentController.text,
                  padding: const EdgeInsets.all(20),
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                    h2: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                    p: const TextStyle(fontSize: 15, height: 1.6),
                    code: TextStyle(
                      backgroundColor: Colors.grey.shade100,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.indigo.shade300, width: 4),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}