import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';
import 'register_screen.dart';
import '../widgets/custom_input.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final auth = AuthService();
  bool loading = false;
  String? _loginError;

  void _login() async {
    setState(() => loading = true);
    try {
      await auth.login(emailCtrl.text.trim(), passCtrl.text.trim());
      // clear any previous login error on success
      setState(() => _loginError = null);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(initialIndex: 2),
          ),
        );
      }
    } catch (e) {
      // On login failure, show a single centered alert below the password field
      setState(() {
        _loginError = 'Login Gagal, Username atau Password Anda Salah';
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (top area)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45, // tampilkan 55% dari tinggi layar
            child: Image.asset(
              'assets/images/logregfor.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (c, e, s) =>
                  Container(color: const Color(0xFF0B6623)),
            ),
          ),

          // Fixed content sheet positioned at bottom (non-scrollable)
          Positioned(
            top: size.height * 0.40,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              // allow content to scroll when keyboard appears
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small centered logo inside the sheet
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.agriculture,
                                size: 64,
                                color: Colors.green,
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Center(
                      child: Column(
                        children: const [
                          Text(
                            "Selamat datang !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Masuk ke Akun Anda",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    CustomInput(
                      controller: emailCtrl,
                      label: "Masukkan Email",
                      icon: Icons.email_outlined,
                      onChanged: (_) {
                        if (_loginError != null)
                          setState(() => _loginError = null);
                      },
                    ),
                    const SizedBox(height: 15),
                    CustomInput(
                      controller: passCtrl,
                      label: "Masukkan Sandi",
                      icon: Icons.lock_outline,
                      obscure: true,
                      onChanged: (_) {
                        if (_loginError != null)
                          setState(() => _loginError = null);
                      },
                    ),
                    // Centered login error shown below password field
                    if (_loginError != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 12.0,
                          left: 12.0,
                          right: 12.0,
                        ),
                        child: Center(
                          child: Text(
                            _loginError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text(
                          "Lupa Sandi ?",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: _login,
                            child: const Text(
                              "Masuk",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Belum punya akun? ",
                          style: TextStyle(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            "Daftar sekarang",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ), // end Column (inside SingleChildScrollView)
              ), // end SingleChildScrollView
            ), // end Container
          ), // end Positioned
        ],
      ), // end Stack
    ); // end Scaffold
  }
}
