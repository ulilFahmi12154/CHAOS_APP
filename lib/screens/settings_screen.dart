import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifEnabled = true;
  bool notifKritis = true;
  bool notifSiklus = true;
  bool notifKelembapan = false;
  bool notifSuhu = false;
  double kelembapan = 45;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 3,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Pengaturan Sistem',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF234D2B),
                ),
              ),
              const SizedBox(height: 24),
              // Otomasi irigasi
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Otomasi irigasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ambang batas kelembaban otomatis',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Slider(
                            value: kelembapan,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: '${kelembapan.round()}%',
                            onChanged: (v) {
                              setState(() => kelembapan = v);
                            },
                          ),
                          Positioned(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF234D2B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${kelembapan.round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Notifikasi
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktifkan notifikasi aplikasi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: notifEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.green,
                            onChanged: (v) {
                              setState(() => notifEnabled = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _notifTile(
                        'Notifikasi kondisi tanaman kritis',
                        notifKritis,
                        (v) => setState(() => notifKritis = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi siklus irigasi (pompa on/off)',
                        notifSiklus,
                        (v) => setState(() => notifSiklus = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi perubahan Kelembapan drastis',
                        notifKelembapan,
                        (v) => setState(() => notifKelembapan = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi perubahan suhu drastis',
                        notifSuhu,
                        (v) => setState(() => notifSuhu = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ubah kata sandi
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF234D2B),
                  ),
                  title: const Text(
                    'Ubah kata sandi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 16),
              // Keluar akun
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Keluar akun',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifTile(String text, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
