import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_db_service.dart';
import 'package:chaos_app/screens/plant_detail_screen.dart';
import 'package:chaos_app/screens/warning_detail_screen.dart';

Widget _buildSensorCard(
  String title,
  IconData icon,
  Color color,
  Stream<dynamic> dataStream,
  String unit,
  num minBatas,
  num maxBatas,
) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StreamBuilder<dynamic>(
          stream: dataStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final value = snapshot.data;
              return Column(
                children: [
                  Text(
                    '$value$unit',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ideal: $minBatas - $maxBatas',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((value - minBatas) / (maxBatas - minBatas)).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const Text(
              '--',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
      ],
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RealtimeDbService _dbService = RealtimeDbService();
  String? activeVarietas;
  bool pompaStatus = false;

  // Ambang batas dari settings (default values)
  double suhuMin = 22, suhuMax = 28;
  double humMin = 50, humMax = 58;
  double soilMin = 1100, soilMax = 1900;
  double phMin = 5.8, phMax = 6.5;
  double luxMin = 1800, luxMax = 4095;

  // Threshold NPK (default values)
  double nitrogenMin = 0, nitrogenMax = 4095;
  double phosphorusMin = 0, phosphorusMax = 4095;
  double potassiumMin = 0, potassiumMax = 4095;

  // Threshold EC/TDS (default values)
  double ecMin = 500, ecMax = 2000;
  @override
  void initState() {
    super.initState();
    _loadActiveVarietas();
    _loadUserSettings();
  }

  /// Load config varietas dari Firestore untuk mendapatkan min/max ranges
  Future<void> _loadVarietasConfig(String varietasId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('varietas_config')
          .doc(varietasId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;

        setState(() {
          // Update range dari Firestore config
          suhuMin = (data['suhu_min'] ?? 22).toDouble();
          suhuMax = (data['suhu_max'] ?? 28).toDouble();
          humMin = (data['kelembapan_udara_min'] ?? 50).toDouble();
          humMax = (data['kelembapan_udara_max'] ?? 58).toDouble();
          soilMin = (data['soil_min'] ?? 1100).toDouble();
          soilMax = (data['soil_max'] ?? 1900).toDouble();
          phMin = (data['ph_min'] ?? 5.8).toDouble();
          phMax = (data['ph_max'] ?? 6.5).toDouble();
          luxMin = (data['light_min'] ?? 1800).toDouble();
          luxMax = (data['light_max'] ?? 4095).toDouble();

          // Load NPK threshold
          nitrogenMin = (data['nitrogen_min'] ?? 0).toDouble();
          nitrogenMax = (data['nitrogen_max'] ?? 4095).toDouble();
          phosphorusMin = (data['phosphorus_min'] ?? 0).toDouble();
          phosphorusMax = (data['phosphorus_max'] ?? 4095).toDouble();
          potassiumMin = (data['potassium_min'] ?? 0).toDouble();
          potassiumMax = (data['potassium_max'] ?? 4095).toDouble();

          // Load EC/TDS threshold
          ecMin = (data['ec_min'] ?? 500).toDouble();
          ecMax = (data['ec_max'] ?? 2000).toDouble();
        });
      }
    } catch (e) {
      print('Error loading varietas config: $e');
    }
  }

  /// Load ambang batas dari user settings
  Future<void> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to varietas changes
    final varietasRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/active_varietas',
    );

    varietasRef.onValue.listen((event) async {
      if (event.snapshot.exists && mounted) {
        final varietas = event.snapshot.value.toString();
        // Load config untuk varietas ini
        await _loadVarietasConfig(varietas);
      }
    });
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        activeVarietas = null;
      });
      return;
    }

    // Baca pilihan varietas per user
    final userRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/active_varietas',
    );
    userRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          activeVarietas = event.snapshot.value.toString();
        });
      } else {
        setState(() {
          activeVarietas = null;
        });
      }
    });
  }

  Stream<List<Map<String, dynamic>>> getWarningStream() {
    final varietasToUse = activeVarietas ?? 'default';

    // Ambil tanggal hari ini untuk path warning
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final path = 'smartfarm/warning/$varietasToUse/$dateStr';

    final db = FirebaseDatabase.instance.ref(path);
    return db.onValue.map((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> warnings = [];

      if (data is Map) {
        // Data struktur: {suhu: {push1: {...}, push2: {...}}, tanah: {...}, ...}
        data.forEach((sensorType, sensorData) {
          if (sensorData is Map) {
            // Setiap sensor type punya multiple warnings (dari pushJSON)
            sensorData.forEach((pushKey, warningData) {
              if (warningData is Map) {
                final warning = Map<String, dynamic>.from(warningData);
                // Tambahkan sensor type
                warning['sensor'] = sensorType.toString();
                warnings.add(warning);
              }
            });
          }
        });

        // Sort by timestamp descending (terbaru dulu)
        warnings.sort((a, b) {
          final timeA = a['timestamp'] ?? 0;
          final timeB = b['timestamp'] ?? 0;
          return timeB.compareTo(timeA);
        });

        // Ambil hanya 4 warning terbaru
        if (warnings.length > 4) {
          warnings = warnings.sublist(0, 4);
        }
      }

      return warnings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final belumPilih = activeVarietas == null || activeVarietas!.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          if (belumPilih)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard Default',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Pilih varietas untuk data real-time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          _buildIrigasiCard(),
          const SizedBox(height: 16),
          _buildWarningNotif(),
          const SizedBox(height: 16),
          _buildSensorGrid(),
          const SizedBox(height: 16),
          _buildNutrisiCard(),
          const SizedBox(height: 16),
          _buildRecommendationRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Card untuk menampilkan nutrisi NPK (Real-time dari Firebase)
  Widget _buildNutrisiCard() {
    final varietasToUse = activeVarietas ?? 'default';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: activeVarietas == null || activeVarietas!.isEmpty
          ? Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pilih varietas untuk melihat nutrisi NPK',
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                ),
              ],
            )
          : StreamBuilder<dynamic>(
              stream: FirebaseDatabase.instance
                  .ref('smartfarm/sensors/$varietasToUse')
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Menunggu data sensor...',
                          style: TextStyle(fontSize: 14, color: Colors.orange),
                        ),
                      ),
                    ],
                  );
                }

                final sensorData = snapshot.data as Map<dynamic, dynamic>;
                final nitrogen = (sensorData['nitrogen'] ?? 0).toDouble();
                final phosphorus = (sensorData['phosphorus'] ?? 0).toDouble();
                final potassium = (sensorData['potassium'] ?? 0).toDouble();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Nutrisi Tanaman (NPK)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _nutrisiItem(
                            'N',
                            'Nitrogen',
                            nitrogen,
                            nitrogenMin,
                            nitrogenMax,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _nutrisiItem(
                            'P',
                            'Phosphorus',
                            phosphorus,
                            phosphorusMin,
                            phosphorusMax,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _nutrisiItem(
                            'K',
                            'Potassium',
                            potassium,
                            potassiumMin,
                            potassiumMax,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _nutrisiItem(
    String shortLabel,
    String fullLabel,
    double value,
    double minBatas,
    double maxBatas,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shortLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            fullLabel,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ideal: ${minBatas.toStringAsFixed(0)} - ${maxBatas.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ((value - minBatas) / (maxBatas - minBatas)).clamp(
                0.0,
                1.0,
              ),
              minHeight: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final belumPilih = activeVarietas == null || activeVarietas!.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Halo Farmer!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Varietas yang sedang dimonitor:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          if (belumPilih)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Belum ada varietas yang dipilih',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activeVarietas!.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  icon: Icon(belumPilih ? Icons.add : Icons.edit),
                  label: Text(belumPilih ? 'Pilih Varietas' : 'Ubah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (!belumPilih) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showDeleteConfirmation(context);
                    },
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Hapus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Varietas'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus varietas yang sedang dimonitor?\n\n'
            'Dashboard akan menampilkan data default.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                _deleteActiveVarietas();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteActiveVarietas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final db = FirebaseDatabase.instance.ref();

      // 1. Hapus pilihan varietas dari profile user
      await db.child('users/${user.uid}/active_varietas').remove();

      // 2. Hapus juga dari path global ESP32 agar Wokwi berhenti membaca
      await db.child('smartfarm/active_varietas').set("");

      setState(() {
        activeVarietas = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Varietas dihapus. ESP32 akan berhenti membaca sensor.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildIrigasiCard() {
    final varietasToUse = activeVarietas ?? 'default';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Sistem Irigasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.tune, color: Colors.blue.shade700),
                onPressed: () {
                  Navigator.pushNamed(context, '/kontrol');
                },
                tooltip: 'Ke Halaman Kontrol',
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<dynamic>(
            stream: FirebaseDatabase.instance
                .ref('smartfarm/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, modeSnapshot) {
              bool isAuto = modeSnapshot.data == true;

              return StreamBuilder<dynamic>(
                stream: FirebaseDatabase.instance
                    .ref('smartfarm/sensors/$varietasToUse/pompa')
                    .onValue
                    .map((e) => e.snapshot.value),
                builder: (context, pompaSnapshot) {
                  bool isOn = pompaSnapshot.data == 'ON';

                  return Column(
                    children: [
                      // Status Mode
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAuto
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAuto
                                ? Colors.blue.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAuto ? Icons.auto_mode : Icons.touch_app,
                              color: isAuto
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mode: ${isAuto ? "Otomatis" : "Manual"}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isAuto
                                          ? Colors.blue.shade800
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAuto
                                        ? 'Pompa dikontrol berdasarkan kelembapan tanah'
                                        : 'Pompa dikontrol manual dari aplikasi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status Pompa
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOn
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOn
                                ? Colors.green.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isOn ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOn
                                    ? Icons.water_drop
                                    : Icons.water_drop_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Pompa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOn ? 'AKTIF (ON)' : 'TIDAK AKTIF (OFF)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isOn
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isOn ? Colors.green : Colors.grey,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOn ? 'ON' : 'OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWarningNotif() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getWarningStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Semua kondisi dalam keadaan normal ✨',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final warnings = snapshot.data!;

        // Filter hanya warning yang punya level (warning terkini dari ESP32)
        // Dan urutkan berdasarkan level: critical dulu, baru warning
        final activeWarnings = warnings
            .where((w) => w['level'] != null)
            .toList();
        activeWarnings.sort((a, b) {
          // Critical (⚠️) lebih prioritas daripada warning (⚡)
          final levelA = a['level'] == 'critical' ? 0 : 1;
          final levelB = b['level'] == 'critical' ? 0 : 1;
          return levelA.compareTo(levelB);
        });

        if (activeWarnings.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Semua sensor dalam kondisi optimal ✨',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.red.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Peringatan Terkini (${activeWarnings.length} sensor)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...activeWarnings.map(
                (w) => GestureDetector(
                  onTap: () {
                    // Get sensor type untuk match dengan threshold
                    final sensorType = (w['sensor'] ?? '')
                        .toString()
                        .toLowerCase();
                    double? minVal, maxVal;
                    String unit = '';

                    // Match sensor dengan threshold yang sesuai
                    if (sensorType.contains('suhu')) {
                      minVal = suhuMin;
                      maxVal = suhuMax;
                      unit = '°C';
                    } else if (sensorType.contains('kelembapan')) {
                      minVal = humMin;
                      maxVal = humMax;
                      unit = '%';
                    } else if (sensorType.contains('tanah')) {
                      minVal = soilMin;
                      maxVal = soilMax;
                      unit = '';
                    } else if (sensorType.contains('cahaya')) {
                      minVal = luxMin;
                      maxVal = luxMax;
                      unit = 'lux';
                    } else if (sensorType.contains('ph')) {
                      minVal = phMin;
                      maxVal = phMax;
                      unit = '';
                    } else if (sensorType.contains('nitrogen')) {
                      minVal = nitrogenMin;
                      maxVal = nitrogenMax;
                      unit = '';
                    } else if (sensorType.contains('phosphorus')) {
                      minVal = phosphorusMin;
                      maxVal = phosphorusMax;
                      unit = '';
                    } else if (sensorType.contains('potassium')) {
                      minVal = potassiumMin;
                      maxVal = potassiumMax;
                      unit = '';
                    } else if (sensorType.contains('ec') ||
                        sensorType.contains('tds')) {
                      minVal = ecMin;
                      maxVal = ecMax;
                      unit = 'µS/cm';
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WarningDetailScreen(
                          warning: w,
                          minThreshold: minVal,
                          maxThreshold: maxVal,
                          actualValue: w['value'] != null
                              ? double.tryParse(w['value'].toString())
                              : null,
                          unit: unit,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: w['level'] == 'critical'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: w['level'] == 'critical'
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          w['level'] == 'critical'
                              ? Icons.error
                              : Icons.warning,
                          color: w['level'] == 'critical'
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w['type'] ?? 'Sensor',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: w['level'] == 'critical'
                                      ? Colors.red.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                w['message'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorGrid() {
    final varietasToUse = activeVarietas ?? 'default';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Sensor Real-time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                'Suhu Udara',
                Icons.thermostat,
                Colors.orange,
                _dbService.suhuStream(varietasToUse),
                '°C',
                suhuMin,
                suhuMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                'Kelembapan Udara',
                Icons.opacity,
                Colors.blue,
                _dbService.kelembapanUdaraStream(varietasToUse),
                '%',
                humMin,
                humMax,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                'Kelembapan Tanah',
                Icons.water_drop,
                Colors.green,
                _dbService.kelembapanTanahStream(varietasToUse),
                'ADC',
                soilMin,
                soilMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                'Intensitas Cahaya',
                Icons.light_mode,
                Colors.yellow.shade700,
                _dbService.cahayaStream(varietasToUse),
                'Lux',
                luxMin,
                luxMax,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                'pH Tanah',
                Icons.science,
                Colors.purple,
                _dbService.phTanahStream(varietasToUse),
                'pH',
                phMin,
                phMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                'EC/TDS',
                Icons.water,
                Colors.teal,
                _dbService.ecStream(varietasToUse),
                'ADC',
                ecMin,
                ecMax,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationRow() {
    return Row(
      children: [
        Expanded(
          child: _buildRecommendationCard(
            context,
            'Rekomendasi\nPupuk',
            Icons.eco,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRecommendationCard(
            context,
            'Kenali\nTanamanmu',
            Icons.local_florist,
            Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Jika kartu adalah Rekomendasi Pupuk, buka halaman rekomendasi nutrisi interaktif
              if (title.toLowerCase().contains('pupuk')) {
                Navigator.pushNamed(context, '/nutrient-recommendation');
              } else if (title.toLowerCase().contains('tanaman')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KenaliTanamanmuScreen(),
                  ),
                );
              } else {
                Navigator.pushNamed(context, '/profile');
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("Lihat Detail"),
          ),
        ],
      ),
    );
  }
}
