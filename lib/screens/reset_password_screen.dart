import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_input.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? oobCode;
  const ResetPasswordScreen({super.key, this.oobCode});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final auth = AuthService();
  bool loading = false;
  String? expiredError;
  // Live password criteria flags
  bool _hasMinLen = false;
  bool _hasUpperLower = false;
  bool _hasDigit = false;
  bool _hasSymbol = false;

  @override
  void initState() {
    super.initState();
    _verifyCodeOnInit();
  }

  Future<void> _verifyCodeOnInit() async {
    if (widget.oobCode == null) {
      setState(() => expiredError = 'Kode reset tidak ditemukan');
      return;
    }

    try {
      print('🔍 DEBUG: Verifying code: ${widget.oobCode}');
      await auth.verifyPasswordResetCode(widget.oobCode!);
      print('🔍 DEBUG: Code is valid');
    } catch (e) {
      print('🔍 DEBUG: Code verification failed: $e');
      setState(
        () => expiredError =
            'Link reset sudah expired atau tidak valid. Silakan request ulang.',
      );
    }
  }

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
    final hasSymbol = RegExp(
      r'[!@#\$%\^&*(),.?":{}|<>_\-\[\]\\/;\"]',
    ).hasMatch(password);
    if (!hasSymbol) {
      issues.add('• Harus mengandung simbol (mis. !@#\$%^&*)');
    }
    return issues;
  }

  void _submit() async {
    final p = passCtrl.text.trim();
    final c = confirmCtrl.text.trim();

    // Validate password strength
    final issues = _passwordIssues(p);
    if (issues.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password tidak valid:\n${issues.join('\n')}')),
      );
      return;
    }

    // Validate password confirmation
    if (p.isEmpty || c.isEmpty || p != c) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi sandi tidak cocok')),
      );
      return;
    }
    if (widget.oobCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode reset tidak ditemukan')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await auth.confirmPasswordReset(widget.oobCode!, p);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sandi berhasil diubah')));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
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
          Positioned(
            top: size.height * 0.40,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
                    // Logo
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
                    // Jika link expired, tampilkan error message
                    if (expiredError != null) ...[
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              expiredError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              ),
                              child: const Text(
                                "Kembali ke Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Title & subtitle
                      Center(
                        child: Column(
                          children: const [
                            Text(
                              "Atur ulang sandi baru",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Masukkan sandi baru Anda",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Password input
                      CustomInput(
                        controller: passCtrl,
                        label: "Buat Sandi Baru",
                        icon: Icons.lock_outline,
                        obscure: true,
                        onChanged: _updatePasswordIndicators,
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 15),
                      // Confirm password input
                      CustomInput(
                        controller: confirmCtrl,
                        label: "Konfirmasi Sandi",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 18),
                      // Submit button
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
                              onPressed: _submit,
                              child: const Text(
                                "Atur Ulang",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
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
