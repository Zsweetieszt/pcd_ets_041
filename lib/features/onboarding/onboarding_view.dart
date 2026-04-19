// File: lib/features/onboarding/onboarding_view.dart
import 'package:flutter/material.dart';
import '../auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int _currentIndex = 0; // Ganti _step jadi index (mulai dari 0)

  // Data Onboarding (Gambar/Icon, Judul, Deskripsi)
  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Selamat Datang",
      "desc": "Aplikasi Logbook digital untuk mencatat aktivitas harian Anda dengan mudah.",
      "image": "assets/raising-hand.gif",
      "color": Colors.orange,
    },
    {
      "title": "Aman & Privat",
      "desc": "Login dengan akun Anda sendiri. Data Anda tidak akan tertukar dengan pengguna lain.",
      "image": "assets/security.gif",
      "color": Colors.blue,
    },
    {
      "title": "Riwayat Tersimpan",
      "desc": "Semua catatan hitungan dan aktivitas Anda tersimpan otomatis di dalam perangkat.",
      "image": "assets/history.gif",
      "color": Colors.purple,
    },
  ];

  void _nextPage() {
    if (_currentIndex < _onboardingData.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Pindah ke Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _onboardingData[_currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              // 1. Visual (Gambar/Icon)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: (data['color'] as Color).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    data['image'],
                    height: 160,
                    width: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Teks Judul
              Text(
                data['title'],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: data['color'],
                ),
              ),
              const SizedBox(height: 16),
              
              // Teks Deskripsi
              Text(
                data['desc'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const Spacer(),

              // 2. Page Indicator (Titik-titik)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentIndex == index ? 24 : 8, // Panjang jika aktif
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? data['color']
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Tombol Lanjut
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: data['color'],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentIndex == _onboardingData.length - 1
                      ? "Mulai Sekarang"
                      : "Lanjut",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}