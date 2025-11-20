import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../services/auth_service.dart';
import '../services/realtime_db_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Services
  final RealtimeDbService _dbService = RealtimeDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Key to anchor the custom dropdown menu right under the field
  final GlobalKey _varietasFieldKey = GlobalKey();
  // Dropdown varietas - akan di-load dari Firestore
  List<String> _varietasList = [];
  String _selectedVarietas = 'patra_3';

  // Notifikasi
  bool notifEnabled = true;
  bool notifKritis = true;
  // notifSiklus used for pump on/off notifications
  bool notifSiklus = true;

  // Stream subscription untuk real-time updates
  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;

  // Nilai ambang (editable via slider) - akan di-update dari Firestore
  double suhuMin = 22, suhuMax = 28;
  double suhu = 24;
  double humMin = 50, humMax = 58;
  double kelembapanUdara = 53;
  double soilMin = 1100, soilMax = 1900;
  double kelembapanTanah = 1500;
  double phMin = 5.8, phMax = 6.5;
  double phTanah = 6.0;
  double luxMin = 19000, luxMax = 55000;
  double intensitasCahaya = 22000;

  // Loading state
  bool _isLoading = true;
  String? _userId;

  // Asset icon paths to verify and precache
  final List<String> _iconAssets = [
    'assets/ikon/cabai.png',
    'assets/ikon/material-symbols_air.png',
    'assets/ikon/game-icons_land-mine.png',
    'assets/ikon/cahaya.png',
  ];

  /// Convert ID varietas (bara, patra_3) ke display name (Bara, Patra 3)
  String _getVarietasDisplayName(String id) {
    // Cari di list varietas yang sudah di-load dari Firestore
    final match = _varietasList.firstWhere(
      (v) => v.toLowerCase().replaceAll(' ', '_') == id.toLowerCase(),
      orElse: () => id
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' '),
    );
    return match;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Try to precache icon assets after first frame to surface any missing asset errors early
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final path in _iconAssets) {
        try {
          await precacheImage(AssetImage(path), context);
          // ignore: avoid_print
          print('Precache OK: $path');
        } catch (e) {
          // ignore: avoid_print
          print('Precache FAILED for $path -> $e');
        }
      }
    });
  }

  /// Initialize data: load varietas list dan user settings
  Future<void> _initializeData() async {
    await _loadVarietasList();
    await _loadUserSettings();
  }

  /// Load list varietas dari Firestore
  Future<void> _loadVarietasList() async {
    try {
      final snapshot = await _firestore.collection('varietas_config').get();
      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _varietasList = snapshot.docs
              .map((doc) => doc['nama'] as String? ?? doc.id)
              .toList();
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading varietas list: $e');
    }
  }

  /// Load config varietas dari Firestore berdasarkan nama varietas
  Future<void> _loadVarietasConfig(String varietasId) async {
    try {
      final doc = await _firestore
          .collection('varietas_config')
          .doc(varietasId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;

        // Update range suhu
        final newSuhuMin = (data['suhu_min'] ?? 22).toDouble();
        final newSuhuMax = (data['suhu_max'] ?? 28).toDouble();

        // Update range kelembapan udara
        final newHumMin = (data['kelembapan_udara_min'] ?? 50).toDouble();
        final newHumMax = (data['kelembapan_udara_max'] ?? 58).toDouble();

        // Update range pH tanah - cek apakah ada field ph_min/ph_max di Firestore
        // Jika tidak ada, gunakan nilai default yang sesuai untuk cabai
        final newPhMin = (data['ph_min'] ?? 5.8).toDouble();
        final newPhMax = (data['ph_max'] ?? 6.5).toDouble();

        // Update range kelembapan tanah (soil moisture sensor)
        final newSoilMin = (data['soil_min'] ?? 1100).toDouble();
        final newSoilMax = (data['soil_max'] ?? 1900).toDouble();

        // Update range intensitas cahaya
        final newLuxMin = (data['light_min'] ?? 1800).toDouble();
        final newLuxMax = (data['light_max'] ?? 4095).toDouble();

        setState(() {
          // Set ranges baru
          suhuMin = newSuhuMin;
          suhuMax = newSuhuMax;
          humMin = newHumMin;
          humMax = newHumMax;
          soilMin = newSoilMin;
          soilMax = newSoilMax;
          phMin = newPhMin;
          phMax = newPhMax;
          luxMin = newLuxMin;
          luxMax = newLuxMax;

          // Clamp nilai current agar dalam range baru
          suhu = suhu.clamp(suhuMin, suhuMax);
          kelembapanUdara = kelembapanUdara.clamp(humMin, humMax);
          kelembapanTanah = kelembapanTanah.clamp(soilMin, soilMax);
          phTanah = phTanah.clamp(phMin, phMax);
          intensitasCahaya = intensitasCahaya.clamp(luxMin, luxMax);
        });

        // ignore: avoid_print
        print('Loaded config for $varietasId:');
        // ignore: avoid_print
        print('  Suhu: $suhuMin - $suhuMax (current: $suhu)');
        // ignore: avoid_print
        print(
          '  Kelembapan Udara: $humMin - $humMax (current: $kelembapanUdara)',
        );
        // ignore: avoid_print
        print(
          '  Kelembapan Tanah: $soilMin - $soilMax (current: $kelembapanTanah)',
        );
        // ignore: avoid_print
        print('  pH: $phMin - $phMax (current: $phTanah)');
        // ignore: avoid_print
        print('  Cahaya: $luxMin - $luxMax (current: $intensitasCahaya)');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading varietas config: $e');
    }
  }

  /// Load settings dari Firebase dan setup real-time listener
  Future<void> _loadUserSettings() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.uid;

      // Load settings dari Firebase (one-time untuk initial load)
      final settings = await _dbService.getUserSettings(_userId!);

      // Juga cek active_varietas untuk sinkronisasi dengan home screen
      final activeVarietasRef = FirebaseDatabase.instance.ref(
        'users/$_userId/active_varietas',
      );
      final activeVarietasSnapshot = await activeVarietasRef.get();

      if (settings != null && mounted) {
        // Load varietas - prioritaskan active_varietas jika ada
        if (activeVarietasSnapshot.exists) {
          _selectedVarietas = activeVarietasSnapshot.value.toString();
        } else {
          _selectedVarietas = settings['varietas'] ?? 'patra_3';
        }

        // Load config varietas dari Firestore untuk mendapatkan min/max
        await _loadVarietasConfig(_selectedVarietas);

        setState(() {
          // Load ambang batas
          final ambangBatas =
              settings['ambang_batas'] as Map<dynamic, dynamic>?;
          if (ambangBatas != null) {
            // Load values dan langsung clamp agar dalam range yang valid
            suhu = (ambangBatas['suhu'] ?? 24).toDouble().clamp(
              suhuMin,
              suhuMax,
            );
            kelembapanUdara = (ambangBatas['kelembapan_udara'] ?? 53)
                .toDouble()
                .clamp(humMin, humMax);
            kelembapanTanah = (ambangBatas['kelembapan_tanah'] ?? 1500)
                .toDouble()
                .clamp(soilMin, soilMax);
            phTanah = (ambangBatas['ph_tanah'] ?? 6.0).toDouble().clamp(
              phMin,
              phMax,
            );
            intensitasCahaya = (ambangBatas['intensitas_cahaya'] ?? 22000)
                .toDouble()
                .clamp(luxMin, luxMax);
          }

          // Load notifikasi settings
          final notifikasi = settings['notifikasi'] as Map<dynamic, dynamic>?;
          if (notifikasi != null) {
            notifEnabled = notifikasi['enabled'] ?? true;
            notifSiklus = notifikasi['pompa_irigasi'] ?? true;
            notifKritis = notifikasi['tanaman_kritis'] ?? true;
          }

          _isLoading = false;
        });

        // Log untuk debugging
        print('Loaded user settings:');
        print('  Suhu: $suhu (range: $suhuMin - $suhuMax)');
        print(
          '  Kelembapan Udara: $kelembapanUdara (range: $humMin - $humMax)',
        );
        print(
          '  Kelembapan Tanah: $kelembapanTanah (range: $soilMin - $soilMax)',
        );
        print('  pH: $phTanah (range: $phMin - $phMax)');
        print('  Cahaya: $intensitasCahaya (range: $luxMin - $luxMax)');

        // Setup real-time listener untuk notifikasi
        _setupRealtimeListener();
      } else {
        // Jika belum ada settings, buat default settings
        await _saveDefaultSettings();
        setState(() => _isLoading = false);

        // Setup listener setelah save default
        _setupRealtimeListener();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Setup real-time listener untuk Firebase Realtime Database
  void _setupRealtimeListener() {
    if (_userId == null) return;

    // Cancel existing subscription jika ada
    _settingsSubscription?.cancel();

    // Listen to changes in real-time
    _settingsSubscription = _dbService
        .userSettingsStream(_userId!)
        .listen(
          (settings) {
            if (settings == null || !mounted) return;

            // Update notifikasi settings secara real-time
            final notifikasi = settings['notifikasi'] as Map<dynamic, dynamic>?;
            if (notifikasi != null) {
              setState(() {
                notifEnabled = notifikasi['enabled'] ?? true;
                notifSiklus = notifikasi['pompa_irigasi'] ?? true;
                notifKritis = notifikasi['tanaman_kritis'] ?? true;
              });

              print('Real-time update - Notifikasi:');
              print('  Enabled: $notifEnabled');
              print('  Pompa: $notifSiklus');
              print('  Kritis: $notifKritis');
            }
          },
          onError: (error) {
            print('Error in settings stream: $error');
          },
        );
  }

  @override
  void dispose() {
    // Cancel subscription saat widget di-dispose
    _settingsSubscription?.cancel();
    super.dispose();
  }

  /// Simpan default settings ke Firebase
  Future<void> _saveDefaultSettings() async {
    if (_userId == null) return;

    final defaultSettings = {
      'varietas': _selectedVarietas,
      'ambang_batas': {
        'suhu': suhu,
        'kelembapan_udara': kelembapanUdara,
        'kelembapan_tanah': kelembapanTanah,
        'ph_tanah': phTanah,
        'intensitas_cahaya': intensitasCahaya,
      },
      'notifikasi': {
        'enabled': notifEnabled,
        'pompa_irigasi': notifSiklus,
        'tanaman_kritis': notifKritis,
      },
    };

    await _dbService.updateAllSettings(_userId!, defaultSettings);
  }

  /// Update varietas ke Firebase
  Future<void> _updateVarietas(String varietas) async {
    if (_userId == null) return;
    await _dbService.updateVarietas(_userId!, varietas);
  }

  /// Update ambang suhu ke Firebase
  Future<void> _updateSuhu(double value) async {
    if (_userId == null) return;
    await _dbService.updateAmbangSuhu(_userId!, value);
  }

  /// Update ambang kelembapan udara ke Firebase
  Future<void> _updateKelembapanUdara(double value) async {
    if (_userId == null) return;
    await _dbService.updateAmbangKelembapanUdara(_userId!, value);
  }

  /// Update ambang kelembapan tanah ke Firebase
  Future<void> _updateKelembapanTanah(double value) async {
    if (_userId == null) return;
    await _dbService.updateAmbangKelembapanTanah(_userId!, value);
  }

  /// Update ambang pH tanah ke Firebase
  Future<void> _updatePhTanah(double value) async {
    if (_userId == null) return;
    await _dbService.updateAmbangPhTanah(_userId!, value);
  }

  /// Update ambang intensitas cahaya ke Firebase
  Future<void> _updateIntensitasCahaya(double value) async {
    if (_userId == null) return;
    await _dbService.updateAmbangIntensitasCahaya(_userId!, value);
  }

  /// Update notifikasi enabled ke Firebase
  Future<void> _updateNotifikasiEnabled(bool value) async {
    if (_userId == null) return;
    await _dbService.updateNotifikasiEnabled(_userId!, value);
  }

  /// Update notifikasi pompa ke Firebase
  Future<void> _updateNotifikasiPompa(bool value) async {
    if (_userId == null) return;
    await _dbService.updateNotifikasiPompa(_userId!, value);
  }

  /// Update notifikasi kritis ke Firebase
  Future<void> _updateNotifikasiKritis(bool value) async {
    if (_userId == null) return;
    await _dbService.updateNotifikasiKritis(_userId!, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }
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
              // Varietas yang ditanam saat ini
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
                        children: [
                          Image.asset(
                            'assets/ikon/cabai.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.local_fire_department,
                                  color: Color(0xFF234D2B),
                                  size: 20,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Varietas yang ditanam saat ini',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        key: _varietasFieldKey,
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final selected = await _showVarietasMenu(context);
                          if (selected != null) {
                            // Konversi nama varietas ke ID (lowercase dengan underscore)
                            final varietasId = selected
                                .toLowerCase()
                                .replaceAll(' ', '_');

                            try {
                              // Tampilkan loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Mengubah varietas & sync config...',
                                      ),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // 1. Load config varietas dari Firestore
                              final docSnapshot = await _firestore
                                  .collection('varietas_config')
                                  .doc(varietasId)
                                  .get();

                              if (!docSnapshot.exists) {
                                throw Exception(
                                  'Data varietas tidak ditemukan',
                                );
                              }

                              final data = docSnapshot.data()!;

                              // 2. Sync config ke Realtime Database untuk ESP32/Wokwi
                              await FirebaseDatabase.instance
                                  .ref('smartfarm/varietas_config/$varietasId')
                                  .set({
                                    'soil_min': data['soil_min'] ?? 1100,
                                    'soil_max': data['soil_max'] ?? 1900,
                                    'suhu_min': data['suhu_min'] ?? 22,
                                    'suhu_max': data['suhu_max'] ?? 28,
                                    'kelembapan_udara_min':
                                        data['kelembapan_udara_min'] ?? 50,
                                    'kelembapan_udara_max':
                                        data['kelembapan_udara_max'] ?? 58,
                                    'light_min': data['light_min'] ?? 1800,
                                    'light_max': data['light_max'] ?? 4095,
                                    'ph_min': data['ph_min'] ?? 5.8,
                                    'ph_max': data['ph_max'] ?? 6.5,
                                    'nama': data['nama'] ?? varietasId,
                                  });

                              // 3. Update active_varietas global untuk ESP32
                              await FirebaseDatabase.instance
                                  .ref('smartfarm/active_varietas')
                                  .set(varietasId);

                              // 4. Load config ke UI
                              await _loadVarietasConfig(varietasId);

                              // 5. Update user settings
                              setState(() => _selectedVarietas = varietasId);
                              await _updateVarietas(varietasId);

                              // Tampilkan sukses
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '✅ Varietas berhasil di-sync ke Wokwi!\n${varietasId.replaceAll('_', ' ').toUpperCase()}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Gagal sync: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2D5F40),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _getVarietasDisplayName(_selectedVarietas),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ambang Batas Optimal
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
                        children: [
                          const Expanded(
                            child: Text(
                              'Ambang Batas Optimal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            child: Text(
                              _getVarietasDisplayName(_selectedVarietas),
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Suhu
                      _SliderIndicator(
                        icon: const Icon(
                          Icons.thermostat_outlined,
                          color: Color(0xFF234D2B),
                        ),
                        label: 'Suhu',
                        minLabel: '${suhuMin.toStringAsFixed(0)}°C',
                        maxLabel: '${suhuMax.toStringAsFixed(0)}°C',
                        min: suhuMin,
                        max: suhuMax,
                        value: suhu,
                        valueLabel: '${suhu.toStringAsFixed(0)}°C',
                        onChanged: (v) {
                          setState(() => suhu = v);
                          _updateSuhu(v);
                        },
                        divisions: (suhuMax - suhuMin).toInt(),
                      ),
                      const SizedBox(height: 14),

                      // Kelembapan Udara
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/material-symbols_air.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'Kelembapan Udara',
                        minLabel: '${humMin.toStringAsFixed(0)}%',
                        maxLabel: '${humMax.toStringAsFixed(0)}%',
                        min: humMin,
                        max: humMax,
                        value: kelembapanUdara,
                        valueLabel: '${kelembapanUdara.toStringAsFixed(0)}%',
                        onChanged: (v) {
                          setState(() => kelembapanUdara = v);
                          _updateKelembapanUdara(v);
                        },
                        divisions: (humMax - humMin).toInt(),
                      ),
                      const SizedBox(height: 14),

                      // Kelembapan Tanah
                      _SliderIndicator(
                        icon: const Icon(
                          Icons.terrain,
                          color: Color(0xFF234D2B),
                          size: 20,
                        ),
                        label: 'Kelembapan Tanah',
                        minLabel: soilMin.toStringAsFixed(0),
                        maxLabel: soilMax.toStringAsFixed(0),
                        min: soilMin,
                        max: soilMax,
                        value: kelembapanTanah,
                        valueLabel: kelembapanTanah.toStringAsFixed(0),
                        onChanged: (v) {
                          setState(() => kelembapanTanah = v);
                          _updateKelembapanTanah(v);
                        },
                        divisions: ((soilMax - soilMin) / 10).toInt(),
                      ),
                      const SizedBox(height: 14),

                      // pH Tanah
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/game-icons_land-mine.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.grass_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'pH Tanah',
                        minLabel: phMin.toStringAsFixed(1),
                        maxLabel: phMax.toStringAsFixed(1),
                        min: phMin,
                        max: phMax,
                        value: phTanah,
                        valueLabel: phTanah.toStringAsFixed(1),
                        onChanged: (v) {
                          setState(() => phTanah = v);
                          _updatePhTanah(v);
                        },
                        divisions: 7, // ~0.1 step
                      ),
                      const SizedBox(height: 14),

                      // Intensitas Cahaya
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/cahaya.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.wb_sunny_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'Intensitas Cahaya',
                        minLabel: '${_formatNumber(luxMin)} lux',
                        maxLabel: '${_formatNumber(luxMax)} lux',
                        min: luxMin,
                        max: luxMax,
                        value: intensitasCahaya,
                        valueLabel: _formatNumber(intensitasCahaya),
                        onChanged: (v) {
                          setState(() => intensitasCahaya = v);
                          _updateIntensitasCahaya(v);
                        },
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
                      const Text(
                        'Notifikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktifkan notifikasi aplikasi',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Switch(
                            value: notifEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.green,
                            onChanged: (v) {
                              setState(() => notifEnabled = v);
                              _updateNotifikasiEnabled(v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Keep only two notification options: Pump status and critical plant alerts
                      _notifTile(
                        'Notifikasi Status Pompa Irigasi',
                        notifSiklus,
                        (v) {
                          setState(() => notifSiklus = v ?? false);
                          _updateNotifikasiPompa(v ?? false);
                        },
                      ),
                      _notifTile('Notifikasi Tanaman Kritis', notifKritis, (v) {
                        setState(() => notifKritis = v ?? false);
                        _updateNotifikasiKritis(v ?? false);
                      }),
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
                  onTap: () async {
                    final oldPasswordController = TextEditingController();
                    final newPasswordController = TextEditingController();
                    final confirmPasswordController = TextEditingController();
                    bool showOldPassword = false;
                    bool showNewPassword = false;
                    bool showConfirmPassword = false;

                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                          title: const Text('Ubah Kata Sandi'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: oldPasswordController,
                                obscureText: !showOldPassword,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi Lama',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showOldPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showOldPassword = !showOldPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newPasswordController,
                                obscureText: !showNewPassword,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi Baru',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showNewPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showNewPassword = !showNewPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: !showConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Konfirmasi Kata Sandi Baru',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showConfirmPassword =
                                            !showConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (result == true) {
                      final oldPassword = oldPasswordController.text.trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kata sandi baru tidak cocok'),
                          ),
                        );
                        return;
                      }

                      try {
                        final authService = AuthService();
                        await authService.changePassword(
                          oldPassword,
                          newPassword,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kata sandi berhasil diubah'),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Gagal mengubah kata sandi: ${e.toString()}',
                            ),
                          ),
                        );
                      }
                    }
                  },
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
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Dialog(
                        backgroundColor: const Color(0xFF0B6623),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Anda yakin ingin keluar dari akun?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Keluar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE5E5E5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'Kembali',
                                    style: TextStyle(
                                      color: Color(0xFF0B6623),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (confirm == true) {
                      try {
                        final authService = AuthService();
                        await authService.logout();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/welcome',
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal keluar: ${e.toString()}'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showVarietasMenu(BuildContext context) async {
    final RenderBox button =
        _varietasFieldKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonTopLeft = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final Offset buttonBottomLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    // Position the menu right under the field
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonBottomLeft.dx,
      buttonBottomLeft.dy,
      overlay.size.width - buttonTopLeft.dx - button.size.width,
      overlay.size.height - buttonBottomLeft.dy,
    );

    // Ensure non-transparent popup background with rounded corners
    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      items: _varietasList.map((v) {
        final bool isSelected = v == _selectedVarietas;
        return PopupMenuItem<String>(
          value: v,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFB9B9B9) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              v,
              style: TextStyle(
                color: isSelected ? Colors.black87 : const Color(0xFF2D5F40),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );

    return result;
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

  // Versi interaktif: slider tipis + label nilai + min/max
  Widget _SliderIndicator({
    required Widget icon,
    required String label,
    required String minLabel,
    required String maxLabel,
    required double min,
    required double max,
    required double value,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                valueLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            inactiveTrackColor: Colors.grey.shade300,
            activeTrackColor: const Color(0xFF2E7D32),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel, style: const TextStyle(color: Colors.black54)),
            Text(maxLabel, style: const TextStyle(color: Colors.black45)),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double v) {
    if (v >= 1000) {
      final k = (v / 1000).round();
      return '${k}k';
    }
    return v.toStringAsFixed(0);
  }
}
