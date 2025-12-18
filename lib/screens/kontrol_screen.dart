import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/plant_utils.dart';

class KontrolScreen extends StatefulWidget {
  const KontrolScreen({super.key});

  @override
  State<KontrolScreen> createState() => _KontrolScreenState();
}

class _KontrolScreenState extends State<KontrolScreen> {
  final db = FirebaseDatabase.instance.ref();
  bool modeOtomatis = true;
  bool pompaState = false;
  String? activeVarietas;
  bool _isTogglingPompa = false; // Track if pompa toggle is in progress

  // Firestore instance
  final _firestore = FirebaseFirestore.instance;
  int? waktuTanamMillis;

  // Multi-lokasi
  String activeLocationId = 'lokasi_1';
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _setupLocationListener();
    _loadInitialWaktuTanam();
    _setupWaktuTanamListener();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Setup listener untuk perubahan lokasi aktif
  void _setupLocationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _locationSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final newLocationId =
                snapshot.data()?['active_location'] ?? 'lokasi_1';
            if (newLocationId != activeLocationId) {
              print('📍 KONTROL: Location changed to $newLocationId');
              setState(() {
                activeLocationId = newLocationId;
              });
              // Reload varietas dan waktu tanam untuk lokasi baru
              _loadActiveVarietas();
              _setupWaktuTanamListener();
            } else if (activeLocationId == newLocationId &&
                activeVarietas == null) {
              // First load
              _loadActiveVarietas();
            }
          }
        });
  }

  /// Load initial waktu_tanam data once from RTDB per location
  Future<void> _loadInitialWaktuTanam() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🚫 KONTROL: User is null, cannot load initial data');
      return;
    }

    try {
      // Get active location first
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final locationId = userDoc.data()?['active_location'] ?? 'lokasi_1';
        setState(() {
          activeLocationId = locationId;
        });
      }

      print(
        '🔄 KONTROL: Loading initial waktu_tanam from location: $activeLocationId',
      );
      final snapshot = await FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .get();

      if (snapshot.exists && mounted) {
        final newWaktuTanam = snapshot.value as int?;
        print('✅ KONTROL: Initial waktu_tanam = $newWaktuTanam');

        setState(() {
          waktuTanamMillis = newWaktuTanam;
        });

        if (newWaktuTanam != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(newWaktuTanam);
          print('📅 KONTROL: Initial waktu tanam date: $date');
        }
      } else {
        print('⚠️ KONTROL: No waktu_tanam found');
      }
    } catch (e) {
      print('❌ KONTROL: Error loading initial waktu_tanam: $e');
    }
  }

  /// Setup real-time listener for waktu_tanam from RTDB per location
  void _setupWaktuTanamListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🚫 KONTROL: User is null, cannot setup listener');
      return;
    }

    print(
      '🔄 KONTROL: Setting up waktu_tanam listener for location: $activeLocationId',
    );

    // Listen to real-time changes in waktu_tanam per location
    FirebaseDatabase.instance
        .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
        .onValue
        .listen((event) {
          print('📡 KONTROL: Received RTDB snapshot for waktu_tanam');

          if (mounted) {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final newWaktuTanam = event.snapshot.value as int?;
              print('✅ KONTROL: Found waktu_tanam = $newWaktuTanam');

              setState(() {
                waktuTanamMillis = newWaktuTanam;
              });

              if (newWaktuTanam != null) {
                final date = DateTime.fromMillisecondsSinceEpoch(newWaktuTanam);
                print('📅 KONTROL: Waktu tanam date: $date');
              }
            } else {
              // Field deleted, reset to null
              print('⚠️ KONTROL: waktu_tanam not found, setting to null');
              setState(() {
                waktuTanamMillis = null;
              });
            }
          }
        });
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // MULTI-LOKASI: Load varietas dari lokasi aktif
    print('🔄 KONTROL: Loading varietas from location: $activeLocationId');
    db
        .child('smartfarm/locations/$activeLocationId/active_varietas')
        .onValue
        .listen((event) {
          if (event.snapshot.exists && mounted) {
            final varietas = event.snapshot.value.toString();
            print('✅ KONTROL: Varietas loaded: $varietas');
            setState(() {
              activeVarietas = varietas;
            });
          } else if (mounted) {
            print('⚠️ KONTROL: No varietas found');
            setState(() {
              activeVarietas = null;
            });
          }
        });
  }

  Future<void> _toggleMode(bool value) async {
    // MULTI-LOKASI: Update mode per lokasi (WOKWI BACA PATH INI!)
    await db
        .child('smartfarm/locations/$activeLocationId/mode_otomatis')
        .set(value);

    // Backup: Update juga path global untuk kompatibilitas
    await db.child('smartfarm/mode_otomatis').set(value);

    setState(() {
      modeOtomatis = value;
    });

    print(
      '✅ Mode updated: ${value ? "Otomatis" : "Manual"} for location: $activeLocationId',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mode berubah ke ${value ? "Otomatis" : "Manual"}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _togglePompa(bool state) async {
    print(
      'DEBUG: _togglePompa called with state=$state, activeVarietas=$activeVarietas',
    );

    if (activeVarietas == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih varietas terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_isTogglingPompa) {
      print('DEBUG: Already toggling, returning');
      return;
    }

    setState(() => _isTogglingPompa = true);
    print('DEBUG: Set _isTogglingPompa to true');

    try {
      // Update Firebase command ke MULTIPLE paths supaya Wokwi pasti bisa baca
      final commandValue = state ? 1 : 0;
      final statusValue = state ? 'ON' : 'OFF';

      // Path 1: MULTI-LOKASI command (WOKWI BACA PATH INI!)
      final commandPath1 =
          'smartfarm/locations/$activeLocationId/commands/relay_$activeVarietas';
      print(
        'DEBUG: Updating LOCATION command: $commandPath1 with value: $commandValue',
      );
      await db.child(commandPath1).set(commandValue);

      // Path 2: Global command (backup untuk kompatibilitas)
      final commandPath2 = 'smartfarm/commands/relay_$activeVarietas';
      print(
        'DEBUG: Updating GLOBAL command: $commandPath2 with value: $commandValue',
      );
      await db.child(commandPath2).set(commandValue);

      // Path 3: UPDATE SENSOR STATUS LANGSUNG (untuk UI realtime)
      // MULTI-LOKASI: Update sensor di lokasi aktif
      final sensorPath =
          'smartfarm/locations/$activeLocationId/sensors/$activeVarietas/pompa';
      print(
        'DEBUG: Updating sensor status: $sensorPath with value: $statusValue',
      );
      await db.child(sensorPath).set(statusValue);

      print('DEBUG: All Firebase updates sent successfully');

      // Tunggu sebentar untuk propagasi
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pompa ${state ? "Dinyalakan" : "Dimatikan"}'),
            backgroundColor: state ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _togglePompa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status pompa: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingPompa = false);
        print('DEBUG: Set _isTogglingPompa to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          // balanced bottom padding to avoid overlap with bottom navigation
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeaderCard(),
              const SizedBox(height: 24),

              // Status Dashboard
              _buildStatusDashboard(),
              const SizedBox(height: 24),

              // Mode Control Card
              _buildModeControlCard(),
              const SizedBox(height: 20),

              // Pompa Control Card
              _buildPompaControlCard(),
              const SizedBox(height: 20),

              // Ambang Batas Settings
              _buildThresholdSettingsCard(),
              const SizedBox(height: 20),
              // extra space to ensure controls don't get hidden by bottom nav
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantInfoCard() {
    print(
      '🏗️ KONTROL: Building PlantInfoCard, waktuTanamMillis = $waktuTanamMillis',
    );

    if (waktuTanamMillis == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.settings, color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Waktu tanam belum diatur. Silakan atur di halaman Pengaturan untuk memantau fase pertumbuhan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final info = PlantUtils.calculateGrowthInfo(
      waktuTanamMillis: waktuTanamMillis!,
      jadwalPupuk: PlantUtils.defaultJadwalPupuk(),
    );
    final faseColor = PlantUtils.faseColor(info.fase);
    final progressPercent = (info.progressPanen * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [faseColor.withOpacity(0.18), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: faseColor.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
              Icon(Icons.eco, color: faseColor, size: 32),
              const SizedBox(width: 12),
              Text(
                'Info Tanaman',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: faseColor,
                  shadows: [
                    Shadow(
                      color: faseColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _build3DProgressBar(info.progressPanen, faseColor),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.shrink(),
                    Text(
                      'Umur',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      '${info.umurHari} hari',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: faseColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fase',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: faseColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        info.fase,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: faseColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.emoji_events, color: faseColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Progress Panen: ',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: faseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (info.jadwalPupukBerikutnya != null)
            Row(
              children: [
                Icon(Icons.local_florist, color: Colors.brown, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pupuk berikutnya: ',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Flexible(
                  child: Text(
                    'Hari ke-${info.jadwalPupukBerikutnya!['hari']} (${info.jadwalPupukBerikutnya!['nama']})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Semua jadwal pupuk selesai',
                  style: TextStyle(fontSize: 13, color: Colors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _build3DProgressBar(double value, Color color) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.18), Colors.white],
          center: Alignment(-0.2, -0.2),
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor: color.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: Icon(Icons.spa, color: color, size: 28)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade600,
            Colors.green.shade400,
            Colors.green.shade300,
          ],
          stops: const [0.0, 0.75, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade400.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kontrol Sistem Irigasi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola pompa dan mode otomatis/manual',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.95),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeControlCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_mode,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Otomatis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pompa mengikuti kelembapan tanah',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StreamBuilder<dynamic>(
                stream: db
                    .child(
                      'smartfarm/locations/$activeLocationId/mode_otomatis',
                    )
                    .onValue
                    .map((e) => e.snapshot.value),
                builder: (context, snapshot) {
                  bool isAuto = snapshot.data == true;
                  return Switch(
                    value: isAuto,
                    onChanged: _toggleMode,
                    activeColor: Colors.green,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.autorenew,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mode Otomatis: Pompa otomatis ON jika tanah kering dan OFF jika tanah basah sesuai ambang batas.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade100.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mode Manual: Anda bisa mengontrol pompa ON/OFF secara manual.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPompaControlCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade100, Colors.green.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.water_drop,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kontrol Pompa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<dynamic>(
            stream: db
                .child('smartfarm/locations/$activeLocationId/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, modeSnapshot) {
              bool isAuto = modeSnapshot.data == true;

              // Mode Otomatis - hanya tampilkan info
              if (isAuto) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_mode,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.settings_suggest,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'MODE OTOMATIS AKTIF',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pompa dikontrol otomatis berdasarkan kelembapan tanah',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Aktifkan Mode Manual untuk kontrol pompa secara manual',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mode Manual - tampilkan kontrol lengkap
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade100, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        StreamBuilder<dynamic>(
                          stream: db
                              .child(
                                'smartfarm/locations/$activeLocationId/sensors/$activeVarietas/pompa',
                              )
                              .onValue
                              .map((e) => e.snapshot.value),
                          builder: (context, snapshot) {
                            bool isOn = snapshot.data == 'ON';
                            return Column(
                              children: [
                                // Animated pump icon container
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: isOn
                                          ? [
                                              Colors.green.shade400,
                                              Colors.green.shade600,
                                            ]
                                          : [
                                              Colors.grey.shade300,
                                              Colors.grey.shade500,
                                            ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isOn
                                            ? Colors.green.withOpacity(0.4)
                                            : Colors.grey.withOpacity(0.3),
                                        blurRadius: isOn ? 30 : 15,
                                        spreadRadius: isOn ? 8 : 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isOn
                                        ? Icons.water
                                        : Icons.water_drop_outlined,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isOn
                                          ? [
                                              Colors.green.shade400,
                                              Colors.green.shade600,
                                            ]
                                          : [
                                              Colors.red.shade400,
                                              Colors.red.shade600,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isOn
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.red.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: isOn ? 10 : 5,
                                              spreadRadius: isOn ? 2 : 0,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOn ? 'POMPA AKTIF' : 'POMPA STANDBY',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isOn
                                      ? 'Pompa sedang menyiram tanaman'
                                      : 'Pompa dalam mode standby',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isAuto)
                    StreamBuilder<dynamic>(
                      stream: db
                          .child(
                            'smartfarm/locations/$activeLocationId/sensors/$activeVarietas/pompa',
                          )
                          .onValue
                          .map((e) => e.snapshot.value),
                      builder: (context, pompaSnapshot) {
                        bool isOn = pompaSnapshot.data == 'ON';
                        print(
                          'DEBUG: pompaSnapshot.data = ${pompaSnapshot.data}, isOn = $isOn, _isTogglingPompa = $_isTogglingPompa',
                        );
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: (_isTogglingPompa || isOn)
                                            ? [
                                                Colors.grey.shade300,
                                                Colors.grey.shade400,
                                              ]
                                            : [
                                                Colors.green.shade400,
                                                Colors.green.shade600,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        if (!_isTogglingPompa && !isOn)
                                          BoxShadow(
                                            color: Colors.green.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 6),
                                          ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isTogglingPompa
                                          ? null
                                          : (isOn
                                                ? null
                                                : () {
                                                    _togglePompa(true);
                                                  }),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.power_settings_new,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Nyalakan Pompa',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: (_isTogglingPompa || !isOn)
                                            ? [
                                                Colors.grey.shade300,
                                                Colors.grey.shade400,
                                              ]
                                            : [
                                                Colors.red.shade400,
                                                Colors.red.shade600,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        if (!_isTogglingPompa && isOn)
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.4),
                                            blurRadius: 15,
                                            offset: const Offset(0, 6),
                                          ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isTogglingPompa
                                          ? null
                                          : (!isOn
                                                ? null
                                                : () {
                                                    _togglePompa(false);
                                                  }),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.power_off, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Matikan Pompa',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_isTogglingPompa)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mengirim perintah ke pompa...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade100, Colors.purple.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune,
                  color: Colors.purple.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pengaturan Ambang Batas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.white],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade100, width: 1.5),
            ),
            child: const Text(
              'Pengaturan ambang batas kelembapan tanah, suhu, dan cahaya dapat diatur dari halaman Profile sesuai dengan varietas yang dipilih.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              icon: const Icon(Icons.settings, size: 20),
              label: const Text(
                'Pergi ke Pengaturan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: Colors.purple.shade200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDashboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade100, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dashboard_outlined,
                  color: Colors.indigo.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Status Sistem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<dynamic>(
            stream: db
                .child('smartfarm/locations/$activeLocationId/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isAuto = snapshot.data == true;
              return _buildStatusItem(
                'Mode Sistem',
                isAuto ? '⚙️ Otomatis' : '🖱️ Manual',
                isAuto ? Colors.blue : Colors.orange,
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<dynamic>(
            stream: db
                .child(
                  'smartfarm/locations/$activeLocationId/sensors/$activeVarietas/pompa',
                )
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isOn = snapshot.data == 'ON';
              return _buildStatusItem(
                'Status Pompa',
                isOn ? '🟢 ON' : '🔴 OFF',
                isOn ? Colors.green : Colors.red,
              );
            },
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            'Varietas Aktif',
            activeVarietas?.replaceAll('_', ' ').toUpperCase() ??
                'Belum dipilih',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
