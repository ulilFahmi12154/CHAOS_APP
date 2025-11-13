import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class KontrolScreen extends StatelessWidget {
  const KontrolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.toggle_on_outlined,
                size: 80,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 24),
              const Text(
                'Halaman Kontrol',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kontrol sistem irigasi dan perangkat lainnya',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
