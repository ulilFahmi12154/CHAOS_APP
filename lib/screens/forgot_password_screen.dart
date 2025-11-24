import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/custom_input.dart';
import 'check_email_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  final auth = AuthService();
  bool loading = false;
  String? errorMsg;

  void _sendReset() async {
    final email = emailCtrl.text.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    setState(() => errorMsg = null);
    if (email.isEmpty) {
      setState(() => errorMsg = 'Email belum dimasukkan!');
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(
        () => errorMsg = 'Format email tidak valid! Contoh: nama@gmail.com',
      );
      return;
    }
    setState(() => loading = true);
    try {
      print('🔍 DEBUG: Checking email: $email');
      final methods = await auth.getSignInMethodsForEmail(email);
      print('🔍 DEBUG: Sign-in methods for $email: $methods');

      // Jika tidak ada di Auth, cek di Firestore
      if (methods == null || methods.isEmpty) {
        print('🔍 DEBUG: Email not found in Auth, checking Firestore...');
        final firestore = FirebaseFirestore.instance;
        final query = await firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (query.docs.isEmpty) {
          print('🔍 DEBUG: Email not found in Firestore either');
          setState(
            () => errorMsg =
                'Email belum pernah terdaftar! Silakan cek kembali atau daftar akun baru.',
          );
          setState(() => loading = false);
          return;
        }
        print('🔍 DEBUG: Email found in Firestore');
      }

      // Email valid dan terdaftar, kirim reset password
      print('🔍 DEBUG: Email found, sending reset password email');
      await auth.resetPassword(email);
      if (!mounted) return;
      print('🔍 DEBUG: Reset password email sent successfully');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckEmailScreen()),
      );
    } catch (e) {
      print('🔍 DEBUG: Error in _sendReset: $e');
      String msg = 'Gagal: $e';
      if (e.toString().contains('expired') ||
          e.toString().contains('OOB code')) {
        msg = 'Link reset sudah kadaluarsa, silakan request ulang.';
      }
      setState(() => errorMsg = msg);
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
                            "Pulihkan Kata Sandi",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Masukkan email untuk menerima link reset",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Email input
                    CustomInput(
                      controller: emailCtrl,
                      label: "Masukkan Email",
                      icon: Icons.email_outlined,
                    ),
                    if (errorMsg != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 6,
                          left: 4,
                          right: 4,
                          bottom: 2,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                            onPressed: _sendReset,
                            child: const Text(
                              "Pulihkan",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                    // Back button
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '< Kembali ke halaman login',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),
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
    emailCtrl.dispose();
    super.dispose();
  }
}
