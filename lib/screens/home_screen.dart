import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_db_service.dart';
import 'package:chaos_app/screens/plant_detail_screen.dart';
import 'package:chaos_app/screens/warning_detail_screen.dart';
import 'package:chaos_app/screens/main_navigation_screen.dart';

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
  String _userLocation = 'Loading...';

  // MULTI-LOKASI
  String activeLocationId = 'lokasi_1'; // Default
  String activeLocationName = 'Lokasi 1';
  List<Map<String, String>> userLocations = [];

  /// Load nama lokasi dari Firebase (tidak perlu GPS/Weather API lagi)
  Future<void> _fetchLocationAndWeather() async {
    // Fungsi ini tidak perlu lagi karena nama lokasi sudah di-load via _loadUserLocations()
    // Kept for backward compatibility
  }

  // Get user location from Firebase
  Future<void> _loadUserLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          setState(() {
            _userLocation = data?['location'] ?? 'Unknown Location';
          });
        }
      } catch (e) {
        setState(() {
          _userLocation = 'Unknown Location';
        });
      }
    } else {
      setState(() {
        _userLocation = 'Not Logged In';
      });
    }
  }

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
    _loadUserLocations(); // Load lokasi user dulu
    _loadActiveVarietas();
    _loadUserSettings();
    _loadUserLocation();
    _fetchLocationAndWeather();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data saat widget di-update (misal setelah kembali dari Settings)
    print('🔄 HomeScreen didUpdateWidget: reloading all data');
    _loadUserLocations(); // Reload lokasi dulu
    _loadActiveVarietas();
    _loadUserSettings();
    _fetchLocationAndWeather();
  }

  // Helper: Generate path Firebase dengan lokasi aktif
  String _locationPath(String path) {
    return 'smartfarm/locations/$activeLocationId/$path';
  }

  // Load lokasi yang dimiliki user dari Firestore
  Future<void> _loadUserLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        final locationIds = List<String>.from(
          data['locations'] ?? ['lokasi_1'],
        );
        final activeLocId = data['active_location'] ?? 'lokasi_1';

        // Load detail setiap lokasi dari Realtime DB
        List<Map<String, String>> locs = [];
        Set<String> seenIds = {}; // Track IDs untuk avoid duplicate

        for (var locId in locationIds) {
          // Skip jika ID sudah ada (avoid duplicate)
          if (seenIds.contains(locId)) continue;
          seenIds.add(locId);

          final locSnapshot = await FirebaseDatabase.instance
              .ref('smartfarm/locations/$locId')
              .get();

          if (locSnapshot.exists) {
            final locData = Map<String, dynamic>.from(locSnapshot.value as Map);
            locs.add({
              'id': locId,
              'name': locData['name'] ?? locId,
              'address': locData['address'] ?? '',
            });
          } else {
            locs.add({
              'id': locId,
              'name': 'Lokasi ${locs.length + 1}',
              'address': '',
            });
          }
        }

        // Pastikan activeLocationId ada dalam list
        if (locs.isEmpty) {
          locs.add({'id': 'lokasi_1', 'name': 'Lokasi 1', 'address': ''});
        }

        // Validasi activeLocationId ada dalam list, jika tidak set ke lokasi pertama
        final validActiveId = locs.any((l) => l['id'] == activeLocId)
            ? activeLocId
            : locs.first['id']!;

        setState(() {
          userLocations = locs;
          activeLocationId = validActiveId;
          activeLocationName =
              locs.firstWhere(
                (l) => l['id'] == validActiveId,
                orElse: () => locs.first,
              )['name'] ??
              validActiveId;
        });
      }
    } catch (e) {
      print('Error loading user locations: $e');
    }
  }

  // Ganti lokasi aktif
  Future<void> _switchLocation(String newLocationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'active_location': newLocationId},
      );

      setState(() {
        activeLocationId = newLocationId;
        activeLocationName =
            userLocations.firstWhere(
              (l) => l['id'] == newLocationId,
              orElse: () => {'name': newLocationId},
            )['name'] ??
            newLocationId;
      });

      // Reload data untuk lokasi baru
      _loadActiveVarietas();
      _fetchLocationAndWeather();
    } catch (e) {
      print('Error switching location: $e');
    }
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
    // Method ini sekarang tidak perlu listener karena sudah ada di _loadActiveVarietas()
    // Kept for backward compatibility, bisa dihapus nanti
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        activeVarietas = null;
      });
      return;
    }

    // MULTI-LOKASI: Baca varietas dari lokasi aktif
    final varietasRef = FirebaseDatabase.instance.ref(
      'smartfarm/locations/$activeLocationId/active_varietas',
    );
    varietasRef.onValue.listen((event) async {
      if (event.snapshot.exists && mounted) {
        final varietas = event.snapshot.value.toString();
        setState(() {
          activeVarietas = varietas;
        });
        // Load config untuk varietas ini agar threshold terupdate
        await _loadVarietasConfig(varietas);
        print('🔄 Dashboard sync: varietas updated to $varietas');
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

    // MULTI-LOKASI: Path warning per lokasi
    final path =
        'smartfarm/locations/$activeLocationId/warning/$varietasToUse/$dateStr';

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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernHeader(context),
            const SizedBox(height: 20),
            _buildWeatherLocationCard(),
            const SizedBox(height: 20),
            // Warning/Alert Section - Priority!
            _buildWarningNotif(),
            const SizedBox(height: 20),
            _buildPlantHealthCard(),
            const SizedBox(height: 20),
            _buildPumpModeCard(context),
            const SizedBox(height: 20),
            _buildSensorSection(),
            const SizedBox(height: 24),
            const Text(
              'Quick Access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRecommendationRow(),
            const SizedBox(height: 20),
            _buildUpcomingTasksSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Weather & Location Card with Real Weather API
  Widget _buildWeatherLocationCard() {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.teal.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.agriculture,
                  color: Colors.teal.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeLocationName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lokasi Greenhouse',
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
          const SizedBox(height: 16),

          // Date & Time
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.teal.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time, color: Colors.teal.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  // Pump & Mode Card (merged, clickable)
  Widget _buildPumpModeCard(BuildContext context) {
    final varietasToUse = activeVarietas ?? 'default';
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/kontrol');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.shade700.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            StreamBuilder<dynamic>(
              stream: FirebaseDatabase.instance
                  .ref(_locationPath('sensors/$varietasToUse/pompa'))
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                bool isOn = snapshot.data == 'ON';
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isOn
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOn ? Icons.water : Icons.water_drop_outlined,
                        color: isOn ? Colors.blue : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOn ? 'Pump ON' : 'Pump OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOn ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 24),
            StreamBuilder<dynamic>(
              stream: FirebaseDatabase.instance
                  .ref(_locationPath('mode_otomatis'))
                  .onValue
                  .map((e) => e.snapshot.value),
              builder: (context, snapshot) {
                bool isAuto = snapshot.data == true;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAuto
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAuto ? Icons.auto_mode : Icons.touch_app,
                        color: isAuto ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAuto ? 'Auto Mode' : 'Manual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isAuto ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.shade700,
              size: 22,
            ),
          ],
        ),
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
                  .ref(_locationPath('sensors/$varietasToUse'))
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

  // Modern Header with greeting and date
  Widget _buildModernHeader(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 18) greeting = 'Good Afternoon';
    if (hour >= 18) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Farmer',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // MULTI-LOKASI: Location Selector Dropdown
            if (userLocations.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeLocationId,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.green.shade700,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                    items: userLocations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc['id'],
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    loc['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (loc['address'] != null &&
                                      loc['address']!.isNotEmpty &&
                                      loc['address'] != 'Unknown Location')
                                    Text(
                                      loc['address']!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _switchLocation(value);
                      }
                    },
                  ),
                ),
              ),
            // Tombol Manage Locations
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/locations');
              },
              icon: Icon(Icons.settings, color: Colors.grey.shade700),
              tooltip: 'Kelola Lokasi',
            ),
          ],
        ),
        // Card Info Lokasi (address)
        if (userLocations.isNotEmpty && activeLocationId != null)
          Builder(
            builder: (context) {
              final currentLocation = userLocations.firstWhere(
                (loc) => loc['id'] == activeLocationId,
                orElse: () => {'id': '', 'name': '', 'address': ''},
              );
              final address = currentLocation['address'];
              if (address != null &&
                  address.isNotEmpty &&
                  address != 'Unknown Location') {
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.place, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        const SizedBox(height: 8),
        Row(children: []),
        const SizedBox(height: 16),
        // Varietas Selection Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: activeVarietas != null
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.spa,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently Growing',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeVarietas!.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      icon: Icon(Icons.edit, color: Colors.green.shade700),
                      tooltip: 'Change Variety',
                    ),
                    IconButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Varietas'),
                            content: const Text(
                              'Yakin ingin menghapus varietas yang sedang dipilih?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final db = FirebaseDatabase.instance.ref();
                            await db
                                .child('users/${user.uid}/active_varietas')
                                .remove();
                            await db.child('smartfarm/active_varietas').set("");
                            if (mounted) {
                              setState(() {
                                activeVarietas = null;
                              });
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Varietas dihapus.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Hapus Varietas',
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.eco_outlined,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No Variety Selected',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose what you want to plant',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Select'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // Plant Health Card - large card with image, circular progress
  Widget _buildPlantHealthCard() {
    // MULTI-LOKASI: Load waktu tanam dari lokasi aktif
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildEmptyPlantCard();
        }

        final waktuTanam = snapshot.data!.snapshot.value as int?;
        if (waktuTanam == null) {
          return _buildEmptyPlantCard();
        }

        // Hitung umur dan fase
        final tanamDate = DateTime.fromMillisecondsSinceEpoch(waktuTanam);
        final umurHari = DateTime.now().difference(tanamDate).inDays + 1;
        final progressPanen = (umurHari / 91).clamp(0.0, 1.0);

        String fase = 'Vegetatif';
        Color faseColor = Colors.green;
        if (umurHari > 90) {
          fase = 'Siap Panen';
          faseColor = Colors.red;
        } else if (umurHari > 70) {
          fase = 'Pembuahan';
          faseColor = Colors.orange;
        } else if (umurHari > 60) {
          fase = 'Pembungaan';
          faseColor = Colors.purple;
        } else if (umurHari > 30) {
          fase = 'Generatif';
          faseColor = Colors.blue;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [faseColor.withOpacity(0.15), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: faseColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: faseColor.withOpacity(0.3), width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Circular Progress
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: progressPanen,
                          strokeWidth: 10,
                          backgroundColor: faseColor.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(faseColor),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.eco, color: faseColor, size: 36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fase Pertumbuhan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fase,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: faseColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: faseColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Umur: $umurHari hari',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 18, color: faseColor),
                            const SizedBox(width: 6),
                            Text(
                              'Progress: ${(progressPanen * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.water_drop, color: faseColor, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Ditanam',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${tanamDate.day}/${tanamDate.month}/${tanamDate.year}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: faseColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Column(
                      children: [
                        Icon(Icons.agriculture, color: faseColor, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Target Panen',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          umurHari >= 91
                              ? 'Siap Panen!'
                              : '${91 - umurHari} hari lagi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: umurHari >= 91 ? Colors.green : faseColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlantCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today,
              size: 48,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Waktu Tanam Belum Diatur',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Atur waktu tanam di halaman Pengaturan untuk memantau pertumbuhan tanaman Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings, size: 20),
            label: const Text(
              'Pergi ke Pengaturan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Stats Row - pompa status, warnings, etc
  Widget _buildQuickStatsRow() {
    final varietasToUse = activeVarietas ?? 'default';

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<dynamic>(
            stream: FirebaseDatabase.instance
                .ref(_locationPath('sensors/$varietasToUse/pompa'))
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isOn = snapshot.data == 'ON';
              return _buildQuickStatCard(
                'Pump',
                isOn ? 'Active' : 'Off',
                isOn ? Icons.water : Icons.water_drop_outlined,
                isOn ? Colors.blue : Colors.grey,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<dynamic>(
            stream: FirebaseDatabase.instance
                .ref('smartfarm/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isAuto = snapshot.data == true;
              return _buildQuickStatCard(
                'Mode',
                isAuto ? 'Auto' : 'Manual',
                isAuto ? Icons.auto_mode : Icons.touch_app,
                isAuto ? Colors.green : Colors.orange,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Weather',
            'Sunny',
            Icons.wb_sunny,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Sensor Section - horizontal scroll cards
  Widget _buildSensorSection() {
    final varietasToUse = activeVarietas ?? 'default';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sensor Data',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Grid 3 kolom
        Row(
          children: [
            Expanded(
              child: _buildModernSensorCard(
                'Temperature',
                Icons.thermostat,
                Colors.orange,
                _dbService.suhuStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                '°C',
                suhuMin,
                suhuMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSensorCard(
                'Humidity',
                Icons.opacity,
                Colors.blue,
                _dbService.kelembapanUdaraStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                '%',
                humMin,
                humMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSensorCard(
                'Soil Moisture',
                Icons.water_drop,
                Colors.green,
                _dbService.kelembapanTanahStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                '',
                soilMin,
                soilMax,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernSensorCard(
                'Light',
                Icons.light_mode,
                Colors.amber,
                _dbService.cahayaStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                'lux',
                luxMin,
                luxMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSensorCard(
                'pH Soil',
                Icons.science,
                Colors.purple,
                _dbService.phTanahStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                'pH',
                phMin,
                phMax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernSensorCard(
                'EC/TDS',
                Icons.water,
                Colors.teal,
                _dbService.ecStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
                '',
                ecMin,
                ecMax,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernSensorCard(
    String title,
    IconData icon,
    Color color,
    Stream<dynamic> dataStream,
    String unit,
    num minBatas,
    num maxBatas,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: StreamBuilder<dynamic>(
        stream: dataStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final value = snapshot.data;
            final progress = ((value - minBatas) / (maxBatas - minBatas)).clamp(
              0.0,
              1.0,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 14),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Value
                Text(
                  value is num
                      ? '${value.toStringAsFixed(unit == 'pH' ? 1 : 0)}$unit'
                      : '$value$unit',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color.withOpacity(0.5), size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '--',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Upcoming Tasks Section
  Widget _buildUpcomingTasksSection() {
    // MULTI-LOKASI: Load waktu tanam dari lokasi aktif
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final waktuTanam = snapshot.data!.snapshot.value as int?;
        if (waktuTanam == null) return const SizedBox.shrink();

        final tanamDate = DateTime.fromMillisecondsSinceEpoch(waktuTanam);
        final umurHari = DateTime.now().difference(tanamDate).inDays + 1;

        // Tentukan fase berdasarkan umur tanaman
        String fase = '';
        if (umurHari <= 30) {
          fase = 'Vegetatif';
        } else if (umurHari <= 60) {
          fase = 'Generatif';
        } else if (umurHari <= 70) {
          fase = 'Pembungaan';
        } else if (umurHari <= 90) {
          fase = 'Pembuahan';
        } else {
          fase = 'Siap Panen';
        }

        // Jadwal pupuk DINAMIS berdasarkan fase pertumbuhan
        final jadwalPupuk = [
          // FASE VEGETATIF (Hari 1-30) - Fokus Nitrogen tinggi
          {
            'hari': 7,
            'task': 'Pupuk Urea (N tinggi)',
            'type': 'Vegetatif',
            'icon': '🌱',
          },
          {
            'hari': 14,
            'task': 'NPK 20-10-10',
            'type': 'Vegetatif',
            'icon': '🌱',
          },
          {
            'hari': 21,
            'task': 'Pupuk Organik + Urea',
            'type': 'Vegetatif',
            'icon': '🌱',
          },
          {'hari': 28, 'task': 'NPK 25-5-5', 'type': 'Vegetatif', 'icon': '🌱'},

          // FASE GENERATIF (Hari 31-60) - NPK Seimbang
          {
            'hari': 35,
            'task': 'NPK 15-15-15 (Seimbang)',
            'type': 'Generatif',
            'icon': '🌿',
          },
          {
            'hari': 42,
            'task': 'TSP/SP-36 (Fosfor)',
            'type': 'Generatif',
            'icon': '🌿',
          },
          {
            'hari': 49,
            'task': 'NPK 16-16-16',
            'type': 'Generatif',
            'icon': '🌿',
          },
          {
            'hari': 56,
            'task': 'Pupuk Organik Cair',
            'type': 'Generatif',
            'icon': '🌿',
          },

          // FASE PEMBUNGAAN (Hari 61-70) - P & K tinggi
          {
            'hari': 63,
            'task': 'NPK 10-20-20 (P & K tinggi)',
            'type': 'Pembungaan',
            'icon': '🌸',
          },
          {
            'hari': 67,
            'task': 'Pupuk Daun + KCl',
            'type': 'Pembungaan',
            'icon': '🌸',
          },

          // FASE PEMBUAHAN (Hari 71-90) - K sangat tinggi
          {
            'hari': 73,
            'task': 'NPK 10-10-30 (K tinggi)',
            'type': 'Pembuahan',
            'icon': '🌶',
          },
          {
            'hari': 77,
            'task': 'KCl + Kalsium',
            'type': 'Pembuahan',
            'icon': '🌶',
          },
          {
            'hari': 82,
            'task': 'Pupuk Organik Cair',
            'type': 'Pembuahan',
            'icon': '🌶',
          },
          {
            'hari': 87,
            'task': 'NPK 8-12-32',
            'type': 'Pembuahan',
            'icon': '🌶',
          },

          // FASE SIAP PANEN (Hari 90+) - Pemeliharaan minimal
          {'hari': 92, 'task': 'Panen Perdana', 'type': 'Panen', 'icon': '🎉'},
          {
            'hari': 95,
            'task': 'NPK Pemeliharaan 10-10-10',
            'type': 'Panen',
            'icon': '🎉',
          },
          {'hari': 100, 'task': 'Panen Berkala', 'type': 'Panen', 'icon': '🎉'},
        ];

        final upcomingTasks = jadwalPupuk
            .where((j) => umurHari <= (j['hari'] as int))
            .take(3)
            .toList();

        if (upcomingTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate ke History screen tab Jadwal Pupuk
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainNavigationScreen(
                          initialIndex: 1, // History screen
                          historyTabIndex: 1, // Tab Jadwal Pupuk
                        ),
                      ),
                    );
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcomingTasks.map((task) {
              final hari = task['hari'] as int;
              final taskName = task['task'] as String;
              final taskType = task['type'] as String;
              final taskIcon = task['icon'] as String;
              final daysLeft = hari - umurHari;

              // Warna badge sesuai fase
              Color badgeColor;
              switch (taskType) {
                case 'Vegetatif':
                  badgeColor = Colors.green;
                  break;
                case 'Generatif':
                  badgeColor = Colors.blue;
                  break;
                case 'Pembungaan':
                  badgeColor = Colors.purple;
                  break;
                case 'Pembuahan':
                  badgeColor = Colors.orange;
                  break;
                case 'Panen':
                  badgeColor = Colors.red;
                  break;
                default:
                  badgeColor = Colors.grey;
              }

              // Urgent jika tinggal 3 hari atau kurang
              if (daysLeft <= 3) badgeColor = Colors.red.shade700;

              return InkWell(
                onTap: () {
                  // Navigate to nutrient recommendation for fertilizer tasks
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavigationScreen(
                        initialIndex: 7, // Nutrient Recommendation
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$daysLeft',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                            Text(
                              'days',
                              style: TextStyle(fontSize: 10, color: badgeColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  taskIcon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    taskName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: badgeColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Fase $taskType',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: badgeColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Day $hari',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
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

      // MULTI-LOKASI: Hapus varietas dari path per-lokasi
      // 1. Hapus dari lokasi aktif (UTAMA)
      await db
          .child('smartfarm/locations/$activeLocationId/active_varietas')
          .remove();

      // 2. Hapus waktu tanam juga
      await db
          .child('smartfarm/locations/$activeLocationId/waktu_tanam')
          .remove();

      // 3. Hapus dari path global Wokwi agar ESP32 berhenti membaca
      await db.child('smartfarm/active_varietas').set("");

      setState(() {
        activeVarietas = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Varietas dihapus dari lokasi ini. ESP32 akan berhenti membaca.',
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
                    .ref(_locationPath('sensors/$varietasToUse/pompa'))
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
                _dbService.suhuStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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
                _dbService.kelembapanUdaraStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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
                _dbService.kelembapanTanahStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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
                _dbService.cahayaStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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
                _dbService.phTanahStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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
                _dbService.ecStream(
                  varietasToUse,
                  locationId: activeLocationId,
                ),
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

  Widget _buildFasePertumbuhanCard() {
    // MULTI-LOKASI: Load waktu tanam dari lokasi aktif
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Atur waktu tanam saat menambah/edit lokasi untuk memantau fase pertumbuhan',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        final waktuTanam = snapshot.data!.snapshot.value as int?;
        if (waktuTanam == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Atur waktu tanam saat menambah/edit lokasi untuk memantau fase pertumbuhan',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        // Hitung umur dan fase
        final tanamDate = DateTime.fromMillisecondsSinceEpoch(waktuTanam);
        final umurHari = DateTime.now().difference(tanamDate).inDays + 1;
        String fase = '';
        Color faseColor = Colors.green;
        IconData faseIcon = Icons.eco;

        if (umurHari <= 30) {
          fase = 'Vegetatif';
          faseColor = Colors.green;
          faseIcon = Icons.grass;
        } else if (umurHari <= 60) {
          fase = 'Generatif';
          faseColor = Colors.blue;
          faseIcon = Icons.spa;
        } else if (umurHari <= 70) {
          fase = 'Pembungaan';
          faseColor = Colors.purple;
          faseIcon = Icons.local_florist;
        } else if (umurHari <= 90) {
          fase = 'Pembuahan';
          faseColor = Colors.orange;
          faseIcon = Icons.energy_savings_leaf;
        } else {
          fase = 'Siap Panen';
          faseColor = Colors.red;
          faseIcon = Icons.agriculture;
        }

        // Jadwal pupuk (contoh sederhana)
        final jadwalPupuk = [
          {'hari': 7, 'pupuk': 'Pupuk NPK 1'},
          {'hari': 14, 'pupuk': 'Pupuk NPK 2'},
          {'hari': 21, 'pupuk': 'Pupuk NPK 3'},
          {'hari': 30, 'pupuk': 'Pupuk Organik'},
          {'hari': 45, 'pupuk': 'Pupuk NPK 4'},
          {'hari': 60, 'pupuk': 'Pupuk Daun'},
        ];

        String? pupukBerikutnya;
        int? hariPupuk;
        for (var jadwal in jadwalPupuk) {
          final hariJadwal = jadwal['hari'] as int;
          if (umurHari < hariJadwal) {
            pupukBerikutnya = jadwal['pupuk'] as String;
            hariPupuk = hariJadwal;
            break;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [faseColor.withOpacity(0.3), faseColor.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: faseColor.withOpacity(0.5)),
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
                children: [
                  Icon(faseIcon, color: faseColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Fase: $fase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: faseColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Umur Tanaman',
                        style: TextStyle(fontSize: 12, color: faseColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$umurHari Hari',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: faseColor,
                        ),
                      ),
                    ],
                  ),
                  if (pupukBerikutnya != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Pupuk Berikutnya',
                          style: TextStyle(fontSize: 12, color: faseColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hari ke-$hariPupuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: faseColor,
                          ),
                        ),
                        Text(
                          pupukBerikutnya,
                          style: TextStyle(fontSize: 11, color: faseColor),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: faseColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: faseColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fase == 'Siap Panen'
                            ? 'Tanaman sudah siap dipanen! 🌶️'
                            : 'Pastikan kelembapan dan nutrisi optimal untuk fase $fase',
                        style: TextStyle(fontSize: 11, color: faseColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            Colors.red,
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
    return GestureDetector(
      onTap: () {
        if (title.toLowerCase().contains('pupuk')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(
                initialIndex: 7, // Nutrient Recommendation
              ),
            ),
          );
        } else if (title.toLowerCase().contains('tanaman')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KenaliTanamanmuScreen(),
            ),
          );
        }
      },
      child: Container(
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Builder(
                builder: (context) {
                  // Use chili emoji for Kenali Tanamanmu card in fixed box for symmetry
                  if (title.toLowerCase().contains('tanaman')) {
                    return const SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Text(
                          '🌶',
                          textAlign: TextAlign.center,
                          // Slightly smaller to avoid clipping in circle
                          style: TextStyle(fontSize: 24, height: 1.0),
                        ),
                      ),
                    );
                  }
                  return Icon(icon, color: color, size: 28);
                },
              ),
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
                if (title.toLowerCase().contains('pupuk')) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainNavigationScreen(
                        initialIndex: 7, // Nutrient Recommendation
                      ),
                    ),
                  );
                } else if (title.toLowerCase().contains('tanaman')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KenaliTanamanmuScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                elevation: 0,
              ),
              child: const Text("Lihat Detail"),
            ),
          ],
        ),
      ),
    );
  }
}
