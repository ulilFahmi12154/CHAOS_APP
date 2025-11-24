import 'main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'welcome_screen.dart';
import 'intro_slides_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  void _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 2),
        ),
      );
    } else {
      // Jika belum login, tampilkan intro slides terlebih dahulu
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const IntroSlidesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match the provided Splash.png: pale mint background, centered logo,
    // small subtitle text under the logo. Keep the same navigation logic.
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFE6FAEE), // soft pale mint similar to Splash.png
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo: use the provided asset and keep a large size like in the image
                Image.asset(
                  'assets/images/logo.png',
                  height: 250,
                  fit: BoxFit.contain,
                  // If asset missing, show a simple placeholder icon so app doesn't crash
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.eco, size: 200, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
