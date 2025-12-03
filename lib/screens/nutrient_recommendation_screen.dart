import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/notification_badge.dart';
import 'main_navigation_screen.dart';

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
  // Keep a small varietas list for the compact selector UI (no full merge)
  final List<String> varietasList = [
    "Dewata F1",
    "CRV 211",
    "Patra 3",
    "Mhanu XR",
    "Tavi",
    "Bara",
    "Juwiring",
  ];

  // Display name for currently selected varietas (compact header)
  String displayVarietas = 'Dewata F1';

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
        final key = event.snapshot.value.toString();
        // Map sensor key back to display name if possible
        final found = varietasList.firstWhere(
          (v) => _normalizeToKey(v) == key,
          orElse: () => varietasList.first,
        );

        setState(() {
          activeVarietas = key;
          displayVarietas = found;
        });
        _loadVarietasConfig();
      }
    });
  }

  Future<void> _loadVarietasConfig() async {
    // Use a normalized key for document id (fall back to 'dewata_f1')
    final key = _normalizeToKey(activeVarietas ?? 'Dewata F1');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('varietas_config')
          .doc(key)
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

  // Normalize display name or key to the sensor/doc key form
  String _normalizeToKey(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+\$'), '');
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

  Map<String, dynamic> _getRecommendationDetail(
    String nutrient,
    double value,
    double min,
    double max,
  ) {
    String status;
    String title;
    String description;
    List<String> solutions;
    List<String> fertilizers;
    String dosage;
    String frequency;
    String checkTime;
    Color color;
    IconData icon;

    if (value < min) {
      status = 'KEKURANGAN';
      title = '$nutrient Kekurangan';
      description =
          'Tanaman kekurangan unsur $nutrient. Segera lakukan tindakan pemupukan untuk mengembalikan kesehatan tanaman.';
      color = Colors.red;
      icon = Icons.error;
      checkTime = '2-3 hari';

      if (nutrient == 'Nitrogen') {
        fertilizers = ['Urea (46% N)', 'ZA (21% N)', 'Amonium Sulfat'];
        dosage = '15-20 gram per tanaman';
        frequency = '2x seminggu';
        solutions = [
          'Tambahkan pupuk Urea 15-20 gr per tanaman',
          'Larutkan pupuk dengan air (1:10)',
          'Siram pada pagi/sore hari',
          'Fokus pada area sekitar batang',
          'Hindari langsung ke daun',
        ];
      } else if (nutrient == 'Phosphorus') {
        fertilizers = [
          'TSP/SP-36 (36% P₂O₅)',
          'DAP (46% P₂O₅)',
          'NPK 15-15-15',
        ];
        dosage = '10-15 gram per tanaman';
        frequency = '1x seminggu';
        solutions = [
          'Tambahkan pupuk TSP/SP-36 10-15 gr',
          'Aplikasi pupuk dekat akar',
          'Campur dengan tanah sekitar',
          'Siram setelah aplikasi',
          'Kombinasi dengan kompos lebih baik',
        ];
      } else if (nutrient == 'Potassium') {
        fertilizers = ['KCl (60% K₂O)', 'KNO₃', 'NPK 16-16-16'];
        dosage = '10-15 gram per tanaman';
        frequency = '1x seminggu';
        solutions = [
          'Tambahkan pupuk KCl 10-15 gr',
          'Aplikasi merata di sekitar tanaman',
          'Siram dengan air bersih',
          'Monitoring batang & daun',
          'Perhatikan kekuatan batang',
        ];
      } else {
        fertilizers = ['Pupuk NPK Lengkap', 'Pupuk Organik Cair'];
        dosage = '20-30 ml per liter air';
        frequency = '2x seminggu';
        solutions = [
          'Gunakan nutrisi hidroponik lengkap',
          'Sesuaikan EC/TDS target',
          'Ganti larutan nutrisi',
          'Cek pH larutan (5.5-6.5)',
          'Monitor secara berkala',
        ];
      }
    } else if (value > max) {
      status = 'BERLEBIH';
      title = '$nutrient Berlebihan';
      description =
          'Kadar $nutrient terlalu tinggi. Dapat menyebabkan gangguan penyerapan unsur lain dan kerusakan akar.';
      color = Colors.orange.shade700;
      icon = Icons.warning;
      checkTime = '3-5 hari';
      fertilizers = ['Tidak perlu pupuk tambahan'];
      dosage = 'STOP pemupukan';
      frequency = 'Sampai nilai normal';
      solutions = [
        'HENTIKAN semua pemberian pupuk $nutrient',
        'Lakukan flushing/penyiraman intensif',
        'Gunakan air bersih (pH netral)',
        'Tingkatkan drainase sistem',
        'Monitor nilai sensor harian',
        'Cek kondisi akar (busuk/coklat)',
      ];
    } else {
      status = 'OPTIMAL';
      title = '$nutrient dalam Kondisi Ideal';
      description =
          'Kadar $nutrient sudah optimal. Pertahankan kondisi ini dengan pemupukan rutin sesuai jadwal.';
      color = Colors.green;
      icon = Icons.check_circle;
      checkTime = '5-7 hari';
      fertilizers = ['NPK Seimbang (16-16-16)', 'Pupuk Organik'];
      dosage = 'Sesuai jadwal rutin';
      frequency = '1-2x seminggu (pemeliharaan)';
      solutions = [
        'Lanjutkan jadwal pemupukan rutin',
        'Gunakan dosis pemeliharaan (50-70%)',
        'Rotasi jenis pupuk organik & kimia',
        'Monitor sensor secara berkala',
        'Catat pertumbuhan tanaman',
        'Sesuaikan jika ada perubahan fase',
      ];
    }

    return {
      'status': status,
      'title': title,
      'description': description,
      'solutions': solutions,
      'fertilizers': fertilizers,
      'dosage': dosage,
      'frequency': frequency,
      'checkTime': checkTime,
      'color': color,
      'icon': icon,
    };
  }

  @override
  Widget build(BuildContext context) {
    // ensure we use a sensor-safe key; fall back to 'dewata_f1' if not set
    final varietasToUse = (activeVarietas == null || activeVarietas!.isEmpty)
        ? 'dewata_f1'
        : _normalizeToKey(activeVarietas!);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Image.asset(
            'assets/images/logo.png',
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.eco, color: Colors.white),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: [
          NotificationBadgeStream(
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
            ),
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const MainNavigationScreen(initialIndex: 5),
                  settings: const RouteSettings(
                    arguments: {'initialIndex': 5, 'lastIndex': 2},
                  ),
                ),
              );
            },
          ),
        ],
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

            // Varietas header removed (integrated with dashboard)

            // EC/TDS Section (moved to top)
            const Text(
              'Konduktivitas Elektrik & Nutrisi Terlarut',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // EC/TDS Card with condition summary
            StreamBuilder<DatabaseEvent>(
              stream: db.child('smartfarm/sensors/$varietasToUse').onValue,
              builder: (context, snapshot) {
                double ec = 0;

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  ec = (data['ec'] is num)
                      ? (data['ec'] as num).toDouble()
                      : 0.0;
                }

                final ecStatus = _getNutrientStatus(ec, ecMin, ecMax);

                // Determine EC condition
                String ecCondition;
                String ecAdvice;
                Color ecConditionColor;
                Color ecTextColor;
                IconData ecConditionIcon;

                if (ecStatus == 'Normal') {
                  ecCondition = 'Konsentrasi Nutrisi Ideal';
                  ecAdvice = 'Larutan nutrisi dalam kondisi optimal';
                  ecConditionColor = const Color(0xFF4CAF50); // Green 500
                  ecTextColor = const Color(0xFF2E7D32); // Green 800
                  ecConditionIcon = Icons.check_circle;
                } else if (ecStatus == 'Kekurangan') {
                  ecCondition = 'Konsentrasi Nutrisi Rendah';
                  ecAdvice = 'Tambahkan larutan nutrisi hidroponik';
                  ecConditionColor = const Color(0xFFE53935); // Red 600
                  ecTextColor = const Color(0xFFC62828); // Red 800
                  ecConditionIcon = Icons.error;
                } else {
                  ecCondition = 'Konsentrasi Nutrisi Tinggi';
                  ecAdvice = 'Encerkan larutan atau ganti dengan air bersih';
                  ecConditionColor = Colors.orange.shade700;
                  ecTextColor = Colors.orange.shade900;
                  ecConditionIcon = Icons.warning;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // EC condition summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ecConditionColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ecConditionColor.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                ecConditionIcon,
                                color: ecTextColor,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kondisi Larutan Nutrisi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ecCondition,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: ecTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'EC/TDS: $ecStatus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: ecConditionColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: ecTextColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ecAdvice,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ecTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // EC nutrient card
                    _buildNutrientCard(
                      'EC/TDS (Nutrisi Terlarut)',
                      ec,
                      ecMin,
                      ecMax,
                      'Total nutrisi yang tersedia di dalam larutan',
                      _getNutrientColor(ec, ecMin, ecMax),
                      ecStatus,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // NPK Section
            const Text(
              'Nutrisi Utama (NPK)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Combined NPK StreamBuilder with plant condition summary
            StreamBuilder<DatabaseEvent>(
              stream: db.child('smartfarm/sensors/$varietasToUse').onValue,
              builder: (context, snapshot) {
                // Parse sensor values
                double nitrogen = 0, phosphorus = 0, potassium = 0;

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final data =
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  nitrogen = (data['nitrogen'] is num)
                      ? (data['nitrogen'] as num).toDouble()
                      : 0.0;
                  phosphorus = (data['phosphorus'] is num)
                      ? (data['phosphorus'] as num).toDouble()
                      : 0.0;
                  potassium = (data['potassium'] is num)
                      ? (data['potassium'] as num).toDouble()
                      : 0.0;
                }

                // Calculate status for each nutrient
                final nStatus = _getNutrientStatus(
                  nitrogen,
                  nitrogenMin,
                  nitrogenMax,
                );
                final pStatus = _getNutrientStatus(
                  phosphorus,
                  phosphorusMin,
                  phosphorusMax,
                );
                final kStatus = _getNutrientStatus(
                  potassium,
                  potassiumMin,
                  potassiumMax,
                );

                // Determine overall plant condition with detailed scenarios
                String plantCondition;
                String plantAdvice;
                Color conditionColor;
                IconData conditionIcon;

                final normalCount = [
                  nStatus,
                  pStatus,
                  kStatus,
                ].where((s) => s == 'Normal').length;
                final kekuranganCount = [
                  nStatus,
                  pStatus,
                  kStatus,
                ].where((s) => s == 'Kekurangan').length;
                final berlebihCount = [
                  nStatus,
                  pStatus,
                  kStatus,
                ].where((s) => s == 'Berlebih').length;

                // Detailed condition analysis based on NPK combination
                Color conditionTextColor;

                if (normalCount == 3) {
                  plantCondition = 'Tanaman Sehat & Optimal';
                  plantAdvice = 'Pertahankan kondisi nutrisi saat ini';
                  conditionColor = const Color(0xFF4CAF50); // Green 500
                  conditionTextColor = const Color(0xFF2E7D32); // Green 800
                  conditionIcon = Icons.check_circle;
                } else if (kekuranganCount == 3) {
                  plantCondition = 'Nutrisi Sangat Kurang';
                  plantAdvice = 'Segera lakukan pemupukan NPK lengkap';
                  conditionColor = const Color(0xFFE53935); // Red 600
                  conditionTextColor = const Color(0xFFC62828); // Red 800
                  conditionIcon = Icons.error;
                } else if (berlebihCount == 3) {
                  plantCondition = 'Nutrisi Berlebihan';
                  plantAdvice = 'Hentikan pemupukan, tingkatkan penyiraman';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning;
                } else if (nStatus == 'Kekurangan' &&
                    pStatus == 'Normal' &&
                    kStatus == 'Normal') {
                  plantCondition = 'Kurang Nitrogen (N)';
                  plantAdvice = 'Daun menguning - tambah pupuk Urea/N';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning_amber;
                } else if (pStatus == 'Kekurangan' &&
                    nStatus == 'Normal' &&
                    kStatus == 'Normal') {
                  plantCondition = 'Kurang Fosfor (P)';
                  plantAdvice = 'Pertumbuhan lambat - tambah pupuk TSP/P';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning_amber;
                } else if (kStatus == 'Kekurangan' &&
                    nStatus == 'Normal' &&
                    pStatus == 'Normal') {
                  plantCondition = 'Kurang Kalium (K)';
                  plantAdvice = 'Batang lemah - tambah pupuk KCl/K';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning_amber;
                } else if (nStatus == 'Kekurangan' && pStatus == 'Kekurangan') {
                  plantCondition = 'Kurang N & P';
                  plantAdvice = 'Pertumbuhan terhambat - perlu NPK';
                  conditionColor = const Color(0xFFE53935); // Red 600
                  conditionTextColor = const Color(0xFFC62828); // Red 800
                  conditionIcon = Icons.error_outline;
                } else if (nStatus == 'Kekurangan' && kStatus == 'Kekurangan') {
                  plantCondition = 'Kurang N & K';
                  plantAdvice = 'Tanaman lemah - perlu pupuk N & K';
                  conditionColor = const Color(0xFFE53935); // Red 600
                  conditionTextColor = const Color(0xFFC62828); // Red 800
                  conditionIcon = Icons.error_outline;
                } else if (pStatus == 'Kekurangan' && kStatus == 'Kekurangan') {
                  plantCondition = 'Kurang P & K';
                  plantAdvice = 'Akar & batang lemah - perlu P & K';
                  conditionColor = const Color(0xFFE53935); // Red 600
                  conditionTextColor = const Color(0xFFC62828); // Red 800
                  conditionIcon = Icons.error_outline;
                } else if (nStatus == 'Berlebih') {
                  plantCondition = 'Nitrogen Berlebih';
                  plantAdvice = 'Risiko pertumbuhan vegetatif berlebih';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning;
                } else if (pStatus == 'Berlebih') {
                  plantCondition = 'Fosfor Berlebih';
                  plantAdvice = 'Dapat menghambat unsur mikro lain';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning;
                } else if (kStatus == 'Berlebih') {
                  plantCondition = 'Kalium Berlebih';
                  plantAdvice = 'Dapat mengganggu penyerapan Mg & Ca';
                  conditionColor = Colors.orange.shade700;
                  conditionTextColor = Colors.orange.shade900;
                  conditionIcon = Icons.warning;
                } else if (normalCount >= 2) {
                  plantCondition = 'Tanaman Cukup Baik';
                  plantAdvice = 'Perlu sedikit penyesuaian nutrisi';
                  conditionColor = const Color(0xFF66BB6A); // Light Green 400
                  conditionTextColor = const Color(0xFF388E3C); // Green 700
                  conditionIcon = Icons.check_circle_outline;
                } else {
                  plantCondition = 'Nutrisi Tidak Seimbang';
                  plantAdvice = 'Evaluasi dan sesuaikan pemupukan';
                  conditionColor = const Color(0xFFFFCA28); // Amber 400
                  conditionTextColor = const Color(0xFFF57F17); // Yellow 900
                  conditionIcon = Icons.warning_amber;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plant condition summary card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: conditionColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: conditionColor.withOpacity(0.5),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: conditionColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                conditionIcon,
                                color: conditionTextColor,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kondisi Tanaman',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plantCondition,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: conditionTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'N: $nStatus • P: $pStatus • K: $kStatus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: conditionColor.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: conditionTextColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    plantAdvice,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: conditionTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Individual nutrient cards
                    _buildNutrientCard(
                      'Nitrogen (N)',
                      nitrogen,
                      nitrogenMin,
                      nitrogenMax,
                      'Pertumbuhan daun & batang',
                      _getNutrientColor(nitrogen, nitrogenMin, nitrogenMax),
                      nStatus,
                    ),
                    const SizedBox(height: 12),

                    _buildNutrientCard(
                      'Phosphorus (P)',
                      phosphorus,
                      phosphorusMin,
                      phosphorusMax,
                      'Pembentukan bunga & akar',
                      _getNutrientColor(
                        phosphorus,
                        phosphorusMin,
                        phosphorusMax,
                      ),
                      pStatus,
                    ),
                    const SizedBox(height: 12),

                    _buildNutrientCard(
                      'Potassium (K)',
                      potassium,
                      potassiumMin,
                      potassiumMax,
                      'Kekuatan batang & resistensi penyakit',
                      _getNutrientColor(potassium, potassiumMin, potassiumMax),
                      kStatus,
                    ),
                  ],
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.toggle_on_outlined,
                  label: 'Kontrol',
                  route: '/main',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.history,
                  label: 'Histori',
                  route: '/main',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/main',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  route: '/main',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  route: '/main',
                  index: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required int index,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushReplacementNamed(
          context,
          route,
          arguments: {'initialIndex': index},
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
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
              final detail = _getRecommendationDetail(
                title.split(' ')[0], // Extract nutrient name
                value,
                min,
                max,
              );
              _showDetailedRecommendation(context, detail, value, min, max);
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

  void _showDetailedRecommendation(
    BuildContext context,
    Map<String, dynamic> detail,
    double currentValue,
    double minValue,
    double maxValue,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: detail['color'],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(detail['icon'], color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail['status'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              detail['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        detail['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current values card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: detail['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: detail['color'].withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
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
                                      currentValue.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: detail['color'],
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
                                      '${minValue.toStringAsFixed(0)} - ${maxValue.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value:
                                    ((currentValue - minValue) /
                                            (maxValue - minValue))
                                        .clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  detail['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fertilizer recommendation
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.spa,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pupuk yang Direkomendasikan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...detail['fertilizers']
                                .map<Widget>(
                                  (fertilizer) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            fertilizer,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.water_drop,
                                        color: Colors.blue.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Dosis',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail['dosage'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.purple.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Frekuensi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail['frequency'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Solutions
                      Text(
                        '✅ Langkah-langkah yang Harus Dilakukan:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        detail['solutions'].length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: detail['color'],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  detail['solutions'][index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Check reminder
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Periksa kembali dalam ${detail['checkTime']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mengerti'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: detail['color'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  // Varietas header removed interactive picker: integration with dashboard used

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
