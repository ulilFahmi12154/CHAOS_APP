import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NutrientRecommendationScreen extends StatefulWidget {
  const NutrientRecommendationScreen({super.key});

  @override
  State<NutrientRecommendationScreen> createState() =>
      _NutrientRecommendationScreenState();
}

class _NutrientRecommendationScreenState
    extends State<NutrientRecommendationScreen> {
  final db = FirebaseDatabase.instance.ref();
  String? activeVarietas;

  // Threshold defaults
  double nitrogenMin = 0, nitrogenMax = 4095;
  double phosphorusMin = 0, phosphorusMax = 4095;
  double potassiumMin = 0, potassiumMax = 4095;
  double ecMin = 500, ecMax = 2000;
  double phMin = 5.8, phMax = 6.5;

  @override
  void initState() {
    super.initState();
    _loadActiveVarietas();
    _loadVarietasConfig();
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    db.child('users/${user.uid}/active_varietas').onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          activeVarietas = event.snapshot.value.toString();
        });
        _loadVarietasConfig();
      }
    });
  }

  Future<void> _loadVarietasConfig() async {
    if (activeVarietas == null || activeVarietas!.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('varietas_config')
          .doc(activeVarietas)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          nitrogenMin = (data['nitrogen_min'] ?? 0).toDouble();
          nitrogenMax = (data['nitrogen_max'] ?? 4095).toDouble();
          phosphorusMin = (data['phosphorus_min'] ?? 0).toDouble();
          phosphorusMax = (data['phosphorus_max'] ?? 4095).toDouble();
          potassiumMin = (data['potassium_min'] ?? 0).toDouble();
          potassiumMax = (data['potassium_max'] ?? 4095).toDouble();
          ecMin = (data['ec_min'] ?? 500).toDouble();
          ecMax = (data['ec_max'] ?? 2000).toDouble();
          phMin = (data['ph_min'] ?? 5.8).toDouble();
          phMax = (data['ph_max'] ?? 6.5).toDouble();
        });
      }
    } catch (e) {
      print('Error loading varietas config: $e');
    }
  }

  String _getNutrientStatus(double value, double min, double max) {
    if (value < min) return 'Kekurangan';
    if (value > max) return 'Berlebih';
    return 'Normal';
  }

  Color _getNutrientColor(double value, double min, double max) {
    if (value < min) return Colors.red;
    if (value > max) return Colors.orange;
    return Colors.green;
  }

  String _getRecommendation(
    String nutrient,
    double value,
    double min,
    double max,
  ) {
    if (value < min) {
      return '❌ $nutrient KEKURANGAN\n\n'
          'Nilai saat ini: ${value.toStringAsFixed(0)}\n'
          'Minimal yang diperlukan: ${min.toStringAsFixed(0)}\n\n'
          '✅ Solusi:\n'
          '• Tambahkan pupuk $nutrient secara bertahap\n'
          '• Gunakan pupuk cair untuk hasil cepat\n'
          '• Lakukan penyiraman merata\n'
          '• Periksa kembali dalam 2-3 hari';
    } else if (value > max) {
      return '⚠️ $nutrient BERLEBIH\n\n'
          'Nilai saat ini: ${value.toStringAsFixed(0)}\n'
          'Maksimal yang dianjurkan: ${max.toStringAsFixed(0)}\n\n'
          '✅ Solusi:\n'
          '• Hentikan pemberian pupuk untuk sementara\n'
          '• Lakukan penyiraman dengan air bersih\n'
          '• Tingkatkan drainase/pengaliran air\n'
          '• Periksa kembali dalam 3-5 hari';
    } else {
      return '✅ $nutrient OPTIMAL\n\n'
          'Nilai saat ini: ${value.toStringAsFixed(0)}\n'
          'Range ideal: ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)}\n\n'
          '✅ Rekomendasi:\n'
          '• Pertahankan kondisi saat ini\n'
          '• Lanjutkan jadwal pemupukan rutin\n'
          '• Monitor secara berkala\n'
          '• Sesuaikan dosis jika diperlukan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final varietasToUse = activeVarietas ?? 'default';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Nutrisi Tanaman'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rekomendasi berdasarkan nilai sensor NPK dan EC/TDS real-time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // NPK Section
            const Text(
              'Nutrisi Utama (NPK)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Nitrogen Card
            StreamBuilder<dynamic>(
              stream: db
                  .child('smartfarm/sensors/$varietasToUse/nitrogen')
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                final nitrogen = (snapshot.data ?? 0).toDouble();
                final status = _getNutrientStatus(
                  nitrogen,
                  nitrogenMin,
                  nitrogenMax,
                );
                final color = _getNutrientColor(
                  nitrogen,
                  nitrogenMin,
                  nitrogenMax,
                );

                return _buildNutrientCard(
                  'Nitrogen (N)',
                  nitrogen,
                  nitrogenMin,
                  nitrogenMax,
                  'Pertumbuhan daun & batang',
                  color,
                  status,
                  _getRecommendation(
                    'Nitrogen',
                    nitrogen,
                    nitrogenMin,
                    nitrogenMax,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Phosphorus Card
            StreamBuilder<dynamic>(
              stream: db
                  .child('smartfarm/sensors/$varietasToUse/phosphorus')
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                final phosphorus = (snapshot.data ?? 0).toDouble();
                final status = _getNutrientStatus(
                  phosphorus,
                  phosphorusMin,
                  phosphorusMax,
                );
                final color = _getNutrientColor(
                  phosphorus,
                  phosphorusMin,
                  phosphorusMax,
                );

                return _buildNutrientCard(
                  'Phosphorus (P)',
                  phosphorus,
                  phosphorusMin,
                  phosphorusMax,
                  'Pembentukan bunga & akar',
                  color,
                  status,
                  _getRecommendation(
                    'Phosphorus',
                    phosphorus,
                    phosphorusMin,
                    phosphorusMax,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Potassium Card
            StreamBuilder<dynamic>(
              stream: db
                  .child('smartfarm/sensors/$varietasToUse/potassium')
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                final potassium = (snapshot.data ?? 0).toDouble();
                final status = _getNutrientStatus(
                  potassium,
                  potassiumMin,
                  potassiumMax,
                );
                final color = _getNutrientColor(
                  potassium,
                  potassiumMin,
                  potassiumMax,
                );

                return _buildNutrientCard(
                  'Potassium (K)',
                  potassium,
                  potassiumMin,
                  potassiumMax,
                  'Kekuatan batang & resistensi penyakit',
                  color,
                  status,
                  _getRecommendation(
                    'Potassium',
                    potassium,
                    potassiumMin,
                    potassiumMax,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // EC/TDS Section
            const Text(
              'Konduktivitas Elektrik & Nutrisi Terlarut',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // EC/TDS Card
            StreamBuilder<dynamic>(
              stream: db
                  .child('smartfarm/sensors/$varietasToUse/ec')
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                final ec = (snapshot.data ?? 0).toDouble();
                final status = _getNutrientStatus(ec, ecMin, ecMax);
                final color = _getNutrientColor(ec, ecMin, ecMax);

                return _buildNutrientCard(
                  'EC/TDS (Nutrisi Terlarut)',
                  ec,
                  ecMin,
                  ecMax,
                  'Total nutrisi yang tersedia di dalam larutan',
                  color,
                  status,
                  _getRecommendation('Nutrisi Terlarut (EC)', ec, ecMin, ecMax),
                );
              },
            ),
            const SizedBox(height: 24),

            // Tips Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Tips Pemupukan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTipItem(
                    '1. Waktu Pemupukan',
                    'Lakukan pemupukan pada pagi atau sore hari untuk hasil optimal. Hindari siang hari yang panas.',
                  ),
                  const SizedBox(height: 8),
                  _buildTipItem(
                    '2. Takaran Pupuk',
                    'Ikuti dosis yang dianjurkan. Lebih baik kurang dari berlebih - nutrisi berlebih dapat merusak tanaman.',
                  ),
                  const SizedBox(height: 8),
                  _buildTipItem(
                    '3. Jenis Pupuk',
                    'Gunakan pupuk berkualitas tinggi (NPK seimbang) atau pupuk organik untuk hasil jangka panjang.',
                  ),
                  const SizedBox(height: 8),
                  _buildTipItem(
                    '4. Monitoring',
                    'Periksa sensor NPK secara berkala (setiap 3-5 hari) untuk memantau efektivitas pemupukan.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientCard(
    String title,
    double value,
    double min,
    double max,
    String function,
    Color statusColor,
    String status,
    String recommendation,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Fungsi: $function',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Value display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nilai Saat Ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Range Ideal',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ((value - min) / (max - min)).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),

          // Recommendation
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(child: Text(recommendation)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lihat rekomendasi pemupukan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
