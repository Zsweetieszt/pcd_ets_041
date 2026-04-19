// File: lib/features/auth/login_view.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'login_controller.dart';
import '../logbook/log_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isObscure = true;
  bool _isLocked = false;

  void _handleLogin() {
    String user = _userController.text;
    String pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username dan Password tidak boleh kosong!"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    bool isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      // Kirim username, role, dan teamId ke LogView
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LogView(
            username: user,
            role: _controller.currentRole,       // BARU: kirim role
            teamId: _controller.currentTeamId,   // BARU: kirim teamId
          ),
        ),
      );
    } else {
      if (_controller.isLocked()) {
        setState(() => _isLocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terlalu banyak percobaan! Tunggu 10 detik."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        Timer(const Duration(seconds: 10), () {
          setState(() {
            _isLocked = false;
            _controller.resetLock();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Silakan coba login kembali."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Login Gagal! Sisa percobaan: ${3 - _controller.failedAttempts}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Gatekeeper")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLocked ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _isLocked ? Colors.grey : Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: Text(_isLocked ? "Tunggu..." : "Masuk"),
            ),
          ],
        ),
      ),
    );
  }
}