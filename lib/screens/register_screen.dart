import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';
import '../widgets/custom_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final auth = AuthService();
  bool loading = false;
  // Live password criteria flags
  bool _hasMinLen = false;
  bool _hasUpperLower = false;
  bool _hasDigit = false;
  bool _hasSymbol = false;
  bool _showPasswordCriteria = false;
  late FocusNode _passFocus;
  String? _registerError;

  void _updatePasswordIndicators(String password) {
    setState(() {
      _hasMinLen = password.length >= 8;
      final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
      final hasLower = RegExp(r'[a-z]').hasMatch(password);
      _hasUpperLower = hasUpper && hasLower;
      _hasDigit = RegExp(r'\d').hasMatch(password);
      _hasSymbol = RegExp(
        r'[!@#\$%\^&*(),.?":{}|<>_\-\[\]\\/;\"]',
      ).hasMatch(password);
    });
  }

  @override
  void initState() {
    super.initState();
    _passFocus = FocusNode();
    _passFocus.addListener(() {
      if (_passFocus.hasFocus) {
        setState(() => _showPasswordCriteria = true);
      } else {
        setState(() => _showPasswordCriteria = false);
      }
    });
  }

  List<String> _passwordIssues(String password) {
    final issues = <String>[];
    if (password.length < 8) {
      issues.add('• Minimal 8 karakter');
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    if (!(hasUpper && hasLower)) {
      issues.add('• Harus mengandung huruf besar dan huruf kecil');
    }
    final hasDigit = RegExp(r'\d').hasMatch(password);
    if (!hasDigit) {
      issues.add('• Harus mengandung angka (0-9)');
    }
    // Symbol: at least one non-alphanumeric common symbol
    final hasSymbol = RegExp(
      r'[!@#\$%\^&*(),.?":{}|<>_\-\[\]\\/;\"]',
    ).hasMatch(password);
    if (!hasSymbol) {
      issues.add('• Harus mengandung simbol (mis. !@#\$%^&*)');
    }
    return issues;
  }

  void _register() async {
    // clear previous error
    setState(() => _registerError = null);

    // validate password strength
    final pwd = passCtrl.text.trim();
    final issues = _passwordIssues(pwd);
    if (issues.isNotEmpty) {
      setState(
        () => _registerError = 'Password tidak valid:\n${issues.join('\n')}',
      );
      return;
    }

    // validate password confirmation before attempting register
    if (passCtrl.text != confirmCtrl.text) {
      setState(() => _registerError = 'Konfirmasi Password tidak cocok');
      return;
    }

    setState(() => loading = true);
    try {
      await auth.register(emailCtrl.text.trim(), passCtrl.text.trim());
      // clear any previous register error on success
      setState(() => _registerError = null);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(initialIndex: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String userMsg;
      switch (e.code) {
        case 'email-already-in-use':
          userMsg = 'Email sudah digunakan';
          break;
        case 'invalid-email':
          userMsg = 'Email tidak valid';
          break;
        case 'weak-password':
          userMsg = 'Password terlalu lemah';
          break;
        default:
          userMsg = 'Register gagal, silakan coba lagi';
      }
      setState(() => _registerError = userMsg);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _passFocus.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background positioned to match LoginScreen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: Image.asset(
              'assets/images/logregfor.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (c, e, s) =>
                  Container(color: const Color(0xFF0B6623)),
            ),
          ),

          // Fixed white sheet positioned the same as login
          Positioned(
            top: size.height * 0.40,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
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
                            "Daftar Akun Baru",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    CustomInput(
                      controller: emailCtrl,
                      label: "Email",
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 15),
                    CustomInput(
                      controller: passCtrl,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscure: true,
                      onChanged: (v) {
                        _updatePasswordIndicators(v);
                        if (_registerError != null)
                          setState(() => _registerError = null);
                      },
                      focusNode: _passFocus,
                    ),
                    const SizedBox(height: 10),
                    if (_showPasswordCriteria) ...[
                      _CriteriaRow(ok: _hasMinLen, text: 'Minimal 8 karakter'),
                      _CriteriaRow(
                        ok: _hasUpperLower,
                        text: 'Harus mengandung huruf besar dan huruf kecil',
                      ),
                      _CriteriaRow(
                        ok: _hasDigit,
                        text: 'Harus mengandung angka (0-9)',
                      ),
                      _CriteriaRow(
                        ok: _hasSymbol,
                        text: 'Harus mengandung simbol (mis. !@#\$%^&*)',
                      ),
                    ],
                    const SizedBox(height: 15),
                    // confirmation field
                    CustomInput(
                      controller: confirmCtrl,
                      label: "Konfirmasi Password",
                      icon: Icons.lock_outline,
                      obscure: true,
                      onChanged: (_) {
                        if (_registerError != null)
                          setState(() => _registerError = null);
                      },
                    ),
                    // Centered register error shown below confirmation field
                    if (_registerError != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8.0,
                          left: 12.0,
                          right: 12.0,
                        ),
                        child: Center(
                          child: Text(
                            _registerError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 25),
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
                            onPressed: _register,
                            child: const Text(
                              "Daftar",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Sudah punya akun? ",
                          style: TextStyle(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            "Masuk di sini",
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

class _CriteriaRow extends StatelessWidget {
  final bool ok;
  final String text;

  const _CriteriaRow({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF10B981) : Colors.redAccent;
    final icon = ok ? Icons.check_circle : Icons.close_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
