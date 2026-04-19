import 'package:flutter/material.dart';
import 'counter_controller.dart';
import '../onboarding/onboarding_view.dart';

class CounterView extends StatefulWidget {
  final String username;
  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();
  final TextEditingController _stepController = TextEditingController(text: '1');
  
  // State untuk menandakan apakah data sedang dimuat
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Selamat Pagi';
    } else if (hour < 15) {
      return 'Selamat Siang';
    } else if (hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  // Fungsi memuat data dari memori HP
  void _loadInitialData() async {
    // Panggil fungsi load di controller
    await _controller.loadData(widget.username);
    
    // Setelah selesai, refresh UI
    if (mounted) { // Cek apakah widget masih aktif
      setState(() {
        _isLoading = false; // Loading selesai
      });
    }
  }

  // Fungsi untuk menampilkan dialog konfirmasi reset
  Future<void> _showResetConfirmation() async {
    // showDialog menampilkan popup dialog
    // await menunggu hingga user memilih
    final result = await showDialog<bool>(
      context: context,
      //user harus pilih tombol, tidak bisa tap di luar dialog
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 50,
          ),
          title: const Text(
            'Konfirmasi Reset',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Apakah Anda yakin ingin mereset counter ke 0?\n\nTindakan ini tidak dapat dibatalkan.',
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Navigator.pop mengembalikan nilai false dan menutup dialog
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Mengembalikan nilai true (user konfirmasi reset)
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    // Jika user memilih "Reset" (result == true)
        if (result == true) {
      await _controller.reset(widget.username);
      setState(() {});
    }
  }

  // Mengembalikan Color yang sesuai dengan tipe aksi
  Color _getHistoryColor(String type) {
    switch (type) {
      case 'add':
        return Colors.green.shade50;
      case 'subtract':
        return Colors.red.shade50;
      case 'reset':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  // Mengembalikan Border Color yang sesuai dengan tipe aksi
  Color _getHistoryBorderColor(String type) {
    switch (type) {
      case 'add':
        return Colors.green;
      case 'subtract':
        return Colors.red;
      case 'reset':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Mendapatkan icon berdasarkan jenis aksi
  IconData _getHistoryIcon(String type) {
    switch (type) {
      case 'add':
        return Icons.add_circle_outline;
      case 'subtract':
        return Icons.remove_circle_outline;
      case 'reset':
        return Icons.refresh;
      default:
        return Icons.circle_outlined;
    }
  }

  // Fungsi Logout
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Batal
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup Dialog
              // Kembali ke Onboarding dan hapus semua history halaman sebelumnya
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingView()),
                (route) => false,
              );
            },
            child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Logbook: By ${widget.username}",
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
            tooltip: "Logout",
          ),
        ],
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  children: [
                    Text(
                      _getGreeting(), // Memanggil fungsi waktu
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.username, // Nama User
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 5,
                        offset:
                            const Offset(0, 3),
                      )
                    ]),
                child: Column(
                  children: [
                    const Text(
                      "Total Hitungan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_controller.value}',
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Input untuk menentukan nilai step
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _stepController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                  decoration: InputDecoration(
                    labelText: "Step Value",
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.edit, color: Colors.purple),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _controller.updateStep(value);
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Tombol increment, decrement dan reset
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: "minus",
                    onPressed: () async {
                      await _controller.decrement(widget.username);
                      setState(() {});
                    },
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    heroTag: "plus",
                    onPressed: () async {
                      await _controller.increment(widget.username);
                      setState(() {});
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    heroTag: "reset",
                    backgroundColor: Colors.red,
                    onPressed: _showResetConfirmation,
                    child: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Riwayat
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text(
                          "Riwayat Aktivitas",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _controller.history.isEmpty
                        ? const SizedBox(
                            height: 60,
                            child: Center(
                              child: Text(
                                "Belum ada aktivitas",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: List.generate(
                              _controller.history.length > 5
                                  ? 5
                                  : _controller.history.length,
                              (index) {
                                final historyItem = _controller.history[index];
                                final action = historyItem['action'] ?? '';
                                final type = historyItem['type'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getHistoryColor(type),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getHistoryBorderColor(type),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getHistoryIcon(type),
                                        color: _getHistoryBorderColor(type),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          action,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _getHistoryBorderColor(type)
                                                .withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}