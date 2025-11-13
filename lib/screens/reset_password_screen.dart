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

  void _submit() async {
    final p = passCtrl.text.trim();
    final c = confirmCtrl.text.trim();
    if (p.isEmpty || c.isEmpty || p != c) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Periksa input')));
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
                            style: TextStyle(color: Colors.grey, fontSize: 15),
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
                    ),
                    const SizedBox(height: 12),
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
