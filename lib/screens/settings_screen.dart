import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_db_service.dart';
import '../services/phase_threshold_sync_service.dart';
import '../services/local_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
  String _selectedVarietas = ''; // Start with empty string

  // Notifikasi
  bool notifEnabled = true;
  bool notifKritis = true;
  // notifSiklus used for pump on/off notifications
  bool notifSiklus = true;

  // Stream subscription untuk real-time updates
  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;
  StreamSubscription<DatabaseEvent>? _activeVarietasSubscription;
  StreamSubscription<DocumentSnapshot>? _activeLocationSubscription;

  // Nilai ambang batas (min/max range yang bisa di-edit user via RangeSlider)
  // Ini adalah nilai CUSTOM user, bukan default dari Firestore
  RangeValues suhuRange = const RangeValues(22, 28);
  RangeValues kelembapanUdaraRange = const RangeValues(50, 58);
  RangeValues kelembapanTanahRange = const RangeValues(1100, 1900);
  RangeValues phTanahRange = const RangeValues(5.8, 6.5);
  RangeValues intensitasCahayaRange = const RangeValues(19000, 55000);

  // Batas absolut dari Firestore (untuk membatasi RangeSlider)
  double suhuAbsMin = 20, suhuAbsMax = 30;
  double humAbsMin = 40, humAbsMax = 70;
  double soilAbsMin = 1000, soilAbsMax = 2000;
  double phAbsMin = 5.0, phAbsMax = 7.0;
  double luxAbsMin = 15000, luxAbsMax = 60000;

  // Loading state
  bool _isLoading = true;
  String? _userId;

  // Planting date
  DateTime? _waktuTanam;

  // Lokasi aktif (multi-lokasi)
  String? activeLocationId;

  // Key untuk force rebuild varietas field
  Key _varietasWidgetKey = UniqueKey();

  // Asset icon paths to verify and precache
  final List<String> _iconAssets = [
    'assets/ikon/cabai.png',
    'assets/ikon/material-symbols_air.png',
    'assets/ikon/game-icons_land-mine.png',
    'assets/ikon/cahaya.png',
  ];

  /// Convert ID varietas (bara, patra_3) ke display name (Bara, Patra 3)
  String _getVarietasDisplayName(String id) {
    // Return empty jika id kosong
    if (id.isEmpty) return '';

    // Cari di list varietas yang sudah di-load dari Firestore
    final match = _varietasList.firstWhere(
      (v) => v.toLowerCase().replaceAll(' ', '_') == id.toLowerCase(),
      orElse: () => id
          .replaceAll('_', ' ')
          .split(' ')
          .where((word) => word.isNotEmpty) // Filter empty words
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' '),
    );
    return match;
  }

  /// Clamp range values agar selalu dalam batas absolut
  RangeValues _clampRange(
    double min,
    double max,
    double absMin,
    double absMax,
  ) {
    // Pastikan min tidak lebih kecil dari absMin
    final clampedMin = min.clamp(absMin, absMax);
    // Pastikan max tidak lebih besar dari absMax
    final clampedMax = max.clamp(absMin, absMax);
    // Pastikan min <= max
    if (clampedMin > clampedMax) {
      return RangeValues(absMin, absMax);
    }
    return RangeValues(clampedMin, clampedMax);
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
    await _loadPlantingDate();
  }

  /// Load list varietas dari Firestore
  Future<void> _loadVarietasList() async {
    try {
      print('🌱 Loading varietas list from Firestore...');
      final snapshot = await _firestore.collection('varietas_config').get();
      print('📦 Total documents in Firestore: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty && mounted) {
        final varietasList = <String>[];

        for (final doc in snapshot.docs) {
          // Skip dokumen yang bukan varietas (seperti _seeded_flag)
          if (doc.id.startsWith('_')) {
            print('  ⏩ Skipping system document: ${doc.id}');
            continue;
          }

          try {
            final data = doc.data();
            final nama = data['nama'] as String? ?? doc.id;
            print('  - ${doc.id}: $nama');
            varietasList.add(nama);
          } catch (e) {
            print('  ⚠️ Error reading ${doc.id}: $e');
            // Fallback: gunakan doc.id sebagai nama
            varietasList.add(doc.id);
          }
        }

        setState(() {
          _varietasList = varietasList;
        });
        print('✅ Varietas list loaded: $_varietasList');
      } else {
        // Fallback: gunakan list default jika Firestore benar-benar kosong
        print('⚠️ No varietas found or widget not mounted');
        setState(() {
          _varietasList = ['Bara', 'Juwiring', 'Patra 3'];
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading varietas list: $e');
      // Fallback: gunakan list default jika error
      if (mounted) {
        setState(() {
          _varietasList = ['Bara', 'Juwiring', 'Patra 3'];
        });
      }
    }
  }

  /// Load planting date from RTDB per lokasi aktif
  Future<void> _loadPlantingDate() async {
    if (_userId == null) return;

    try {
      // Get active location dari user profile
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      final activeLocationId = userDoc.exists
          ? (userDoc.data()?['active_location'] ?? 'lokasi_1')
          : 'lokasi_1';

      // Load waktu tanam dari lokasi aktif di RTDB
      final snapshot = await FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .get();

      if (snapshot.exists && mounted) {
        final waktuTanamMs = snapshot.value as int?;
        if (waktuTanamMs != null) {
          setState(() {
            _waktuTanam = DateTime.fromMillisecondsSinceEpoch(waktuTanamMs);
          });
        }
      }
    } catch (e) {
      print('Error loading planting date: $e');
    }
  }

  /// Show date picker and save planting date
  Future<void> _showPlantingDatePicker() async {
    if (_userId == null) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _waktuTanam ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2E7D32),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      try {
        // Get active location dari user profile
        final userDoc = await _firestore.collection('users').doc(_userId).get();
        final activeLocationId = userDoc.exists
            ? (userDoc.data()?['active_location'] ?? 'lokasi_1')
            : 'lokasi_1';

        // Save waktu tanam ke lokasi aktif di RTDB
        await FirebaseDatabase.instance
            .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
            .set(picked.millisecondsSinceEpoch);

        setState(() {
          _waktuTanam = picked;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Waktu tanam berhasil disimpan untuk lokasi aktif',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Auto-sync threshold fase ke RTDB setelah waktu tanam diubah
          _syncThresholdPhase();

          // Schedule all fertilization reminders
          _scheduleTaskReminders(picked);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Gagal menyimpan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Schedule task reminders based on planting date
  Future<void> _scheduleTaskReminders(DateTime plantingDate) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Menjadwalkan pengingat tugas...'),
          duration: Duration(seconds: 2),
        ),
      );

      final notificationService = LocalNotificationService();
      await notificationService.initialize();
      await notificationService.requestPermissions();
      await notificationService.scheduleAllFertilizationReminders(
        plantingDate: plantingDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pengingat tugas berhasil dijadwalkan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error scheduling reminders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Gagal menjadwalkan pengingat: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Auto-sync threshold fase ke RTDB
  Future<void> _syncThresholdPhase() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Menyinkronkan threshold fase ke Wokwi...'),
          duration: Duration(seconds: 2),
        ),
      );

      await PhaseThresholdSyncService.forceSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Threshold fase berhasil disinkronkan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sync warning: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
          // Set batas absolut dari Firestore (untuk RangeSlider limits)
          suhuAbsMin = newSuhuMin;
          suhuAbsMax = newSuhuMax;
          humAbsMin = newHumMin;
          humAbsMax = newHumMax;
          soilAbsMin = newSoilMin;
          soilAbsMax = newSoilMax;
          phAbsMin = newPhMin;
          phAbsMax = newPhMax;
          luxAbsMin = newLuxMin;
          luxAbsMax = newLuxMax;

          // Re-clamp existing ranges agar sesuai dengan batas absolut baru
          suhuRange = _clampRange(
            suhuRange.start,
            suhuRange.end,
            suhuAbsMin,
            suhuAbsMax,
          );
          kelembapanUdaraRange = _clampRange(
            kelembapanUdaraRange.start,
            kelembapanUdaraRange.end,
            humAbsMin,
            humAbsMax,
          );
          kelembapanTanahRange = _clampRange(
            kelembapanTanahRange.start,
            kelembapanTanahRange.end,
            soilAbsMin,
            soilAbsMax,
          );
          phTanahRange = _clampRange(
            phTanahRange.start,
            phTanahRange.end,
            phAbsMin,
            phAbsMax,
          );
          intensitasCahayaRange = _clampRange(
            intensitasCahayaRange.start,
            intensitasCahayaRange.end,
            luxAbsMin,
            luxAbsMax,
          );
        });

        // ignore: avoid_print
        print('Loaded absolute limits for $varietasId:');
        // ignore: avoid_print
        print('  Suhu: $suhuAbsMin - $suhuAbsMax');
        // ignore: avoid_print
        print('  Kelembapan Udara: $humAbsMin - $humAbsMax');
        // ignore: avoid_print
        print('  Kelembapan Tanah: $soilAbsMin - $soilAbsMax');
        // ignore: avoid_print
        print('  pH: $phAbsMin - $phAbsMax');
        // ignore: avoid_print
        print('  Cahaya: $luxAbsMin - $luxAbsMax');
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

      // Ambil activeLocationId dari user profile (Firestore)
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      activeLocationId = userDoc.exists
          ? (userDoc.data()?['active_location'] ?? 'lokasi_1')
          : 'lokasi_1';

      // MULTI-LOKASI: Cek active_varietas dari lokasi aktif
      final activeVarietasRef = FirebaseDatabase.instance.ref(
        'smartfarm/locations/$activeLocationId/active_varietas',
      );
      final activeVarietasSnapshot = await activeVarietasRef.get();

      if (settings != null && mounted) {
        // Load varietas - HANYA dari active_varietas (multi-lokasi)
        if (activeVarietasSnapshot.exists &&
            activeVarietasSnapshot.value != null &&
            activeVarietasSnapshot.value.toString().isNotEmpty) {
          final varietasId = activeVarietasSnapshot.value.toString();
          _selectedVarietas = _getVarietasDisplayName(varietasId);
          print(
            '✅ Initial load: varietas = \"$_selectedVarietas\" (ID: $varietasId)',
          );
        } else {
          // Tidak ada varietas aktif - set ke empty string
          _selectedVarietas = '';
          print('⚠️ Initial load: No active varietas, set to empty');
        }

        // Load config varietas dari Firestore hanya jika varietas ada
        if (_selectedVarietas.isNotEmpty) {
          final varietasId = _selectedVarietas.toLowerCase().replaceAll(
            ' ',
            '_',
          );
          await _loadVarietasConfig(varietasId);
        }

        setState(() {
          // Load ambang batas (min/max ranges yang user set)
          final ambangBatas =
              settings['ambang_batas'] as Map<dynamic, dynamic>?;
          if (ambangBatas != null) {
            // Load suhu range
            final suhuData = ambangBatas['suhu'];
            if (suhuData is Map) {
              final min = (suhuData['min'] ?? suhuAbsMin).toDouble();
              final max = (suhuData['max'] ?? suhuAbsMax).toDouble();
              suhuRange = _clampRange(min, max, suhuAbsMin, suhuAbsMax);
            } else {
              // Backward compatibility: jika masih nilai tunggal, use as midpoint
              suhuRange = RangeValues(suhuAbsMin, suhuAbsMax);
            }

            // Load kelembapan udara range
            final humData = ambangBatas['kelembapan_udara'];
            if (humData is Map) {
              final min = (humData['min'] ?? humAbsMin).toDouble();
              final max = (humData['max'] ?? humAbsMax).toDouble();
              kelembapanUdaraRange = _clampRange(
                min,
                max,
                humAbsMin,
                humAbsMax,
              );
            } else {
              kelembapanUdaraRange = RangeValues(humAbsMin, humAbsMax);
            }

            // Load kelembapan tanah range
            final soilData = ambangBatas['kelembapan_tanah'];
            if (soilData is Map) {
              final min = (soilData['min'] ?? soilAbsMin).toDouble();
              final max = (soilData['max'] ?? soilAbsMax).toDouble();
              kelembapanTanahRange = _clampRange(
                min,
                max,
                soilAbsMin,
                soilAbsMax,
              );
            } else {
              kelembapanTanahRange = RangeValues(soilAbsMin, soilAbsMax);
            }

            // Load pH range
            final phData = ambangBatas['ph_tanah'];
            if (phData is Map) {
              final min = (phData['min'] ?? phAbsMin).toDouble();
              final max = (phData['max'] ?? phAbsMax).toDouble();
              phTanahRange = _clampRange(min, max, phAbsMin, phAbsMax);
            } else {
              phTanahRange = RangeValues(phAbsMin, phAbsMax);
            }

            // Load intensitas cahaya range
            final luxData = ambangBatas['intensitas_cahaya'];
            if (luxData is Map) {
              final min = (luxData['min'] ?? luxAbsMin).toDouble();
              final max = (luxData['max'] ?? luxAbsMax).toDouble();
              intensitasCahayaRange = _clampRange(
                min,
                max,
                luxAbsMin,
                luxAbsMax,
              );
            } else {
              intensitasCahayaRange = RangeValues(luxAbsMin, luxAbsMax);
            }
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
        print('  Suhu: ${suhuRange.start} - ${suhuRange.end}');
        print(
          '  Kelembapan Udara: ${kelembapanUdaraRange.start} - ${kelembapanUdaraRange.end}',
        );
        print(
          '  Kelembapan Tanah: ${kelembapanTanahRange.start} - ${kelembapanTanahRange.end}',
        );
        print('  pH: ${phTanahRange.start} - ${phTanahRange.end}');
        print(
          '  Cahaya: ${intensitasCahayaRange.start} - ${intensitasCahayaRange.end}',
        );

        // Sync threshold ke Wokwi
        await _syncAllThresholdsToWokwi();

        // Setup real-time listener untuk notifikasi DAN varietas
        // PENTING: Panggil setelah activeLocationId sudah di-set!
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
    _activeVarietasSubscription?.cancel();

    // Listen to settings changes in real-time
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

    // Listen to active_location changes from Firestore
    _activeLocationSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final newActiveLocationId =
                snapshot.data()?['active_location'] ?? 'lokasi_1';

            final bool isFirstLoad = activeLocationId == null;

            // Jika lokasi berubah, refresh listener varietas
            if (newActiveLocationId != activeLocationId) {
              print(
                '📍 Lokasi berubah: $activeLocationId → $newActiveLocationId',
              );
              activeLocationId = newActiveLocationId;

              // Cancel dan re-setup listener varietas untuk lokasi baru
              _activeVarietasSubscription?.cancel();
              _setupVarietasListener();

              // Jika ini first load, tampilkan log saja (bukan notification)
              if (isFirstLoad) {
                print('✅ Initial location loaded: $activeLocationId');
                return; // Skip notification untuk first load
              }

              // Reload data untuk lokasi baru
              _loadPlantingDate();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Lokasi aktif berubah'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        });

    // Setup listener varietas untuk lokasi aktif
    // PASTIKAN activeLocationId sudah di-set sebelum panggil ini!
    print('🔍 DEBUG: activeLocationId before setup = $activeLocationId');
    if (activeLocationId != null) {
      _setupVarietasListener();
    } else {
      print(
        '⚠️ WARNING: activeLocationId is null, listener will be setup when location loads',
      );
    }
  }

  /// Setup listener untuk varietas di lokasi aktif
  void _setupVarietasListener() {
    // Listen to active_varietas changes/deletions (MULTI-LOKASI)
    if (activeLocationId == null) {
      print('⚠️ Cannot setup varietas listener: activeLocationId is null');
      return;
    }

    print('🔔 Setting up varietas listener for location: $activeLocationId');
    final activeVarietasRef = FirebaseDatabase.instance.ref(
      'smartfarm/locations/$activeLocationId/active_varietas',
    );

    _activeVarietasSubscription = activeVarietasRef.onValue.listen(
      (event) {
        print('📡 Varietas listener triggered!');
        print('  → Snapshot exists: ${event.snapshot.exists}');
        print('  → Snapshot value: ${event.snapshot.value}');
        print('  → Current _selectedVarietas: "$_selectedVarietas"');

        if (!mounted) {
          print('  ⚠️ Widget not mounted, skipping update');
          return;
        }

        if (!event.snapshot.exists || event.snapshot.value == null) {
          // Varietas dihapus di Dashboard/Home
          print(
            '🗑️ Active varietas dihapus dari Dashboard, kosongkan di Settings',
          );
          print('  → Old value: "$_selectedVarietas"');

          if (mounted) {
            // Force reset to empty string dan regenerate key untuk force rebuild
            setState(() {
              _selectedVarietas = '';
              _waktuTanam = null;
              _varietasWidgetKey = UniqueKey(); // Force rebuild UI
            });

            print(
              '  ✓ State updated: _selectedVarietas = "$_selectedVarietas"',
            );
            print('  ✓ Widget key regenerated untuk force UI rebuild');
            print('  ✓ UI should now show: "Belum ada varietas yang dipilih"');

            // Force immediate frame rebuild
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {}); // Trigger extra rebuild
                print('  ✓ Post-frame rebuild triggered');
              }
            });

            // Hapus varietas dari user settings di Firestore juga
            if (_userId != null) {
              _firestore
                  .collection('users')
                  .doc(_userId)
                  .update({
                    'settings.varietas': '',
                    'active_varietas': FieldValue.delete(),
                  })
                  .then((_) {
                    print('  ✓ Firestore user settings cleared');
                  })
                  .catchError((e) {
                    print('  ❌ Error clearing Firestore: $e');
                  });
            }

            // Tampilkan notifikasi bahwa varietas telah dihapus
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🗑️ Varietas telah dihapus dari Dashboard'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Hapus waktu_tanam dari RTDB per lokasi aktif
          if (activeLocationId != null) {
            FirebaseDatabase.instance
                .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
                .remove()
                .catchError((e) {
                  print('Error deleting waktu_tanam: $e');
                });
          }
        } else {
          // Varietas berubah
          final newVarietasId = event.snapshot.value.toString().trim();

          // Cek jika varietasId kosong atau 'null'
          if (newVarietasId.isEmpty || newVarietasId == 'null') {
            print(
              '🗑️ Settings listener: terdeteksi varietas kosong/null dari RTDB',
            );
            if (mounted) {
              setState(() {
                _selectedVarietas = '';
                _waktuTanam = null;
                _varietasWidgetKey = UniqueKey(); // Force rebuild UI
              });
            }
            print('  ✓ Widget key regenerated untuk force UI rebuild');
            return;
          }

          // Convert ID ke display name
          final displayName = _getVarietasDisplayName(newVarietasId);

          // Bandingkan dengan display name yang sekarang
          if (displayName != _selectedVarietas) {
            print(
              '🔄 Settings sync: varietas berubah dari "$_selectedVarietas" → "$displayName" (ID: $newVarietasId)',
            );

            setState(() {
              _selectedVarietas = displayName;
            });

            // Load config varietas baru
            _loadVarietasConfig(newVarietasId);
          }
        }
      },
      onError: (error) {
        print('Error in active_varietas stream: $error');
      },
    );
  }

  @override
  void dispose() {
    // Cancel subscription saat widget di-dispose
    _settingsSubscription?.cancel();
    _activeVarietasSubscription?.cancel();
    _activeLocationSubscription?.cancel();
    super.dispose();
  }

  /// Simpan default settings ke Firebase
  Future<void> _saveDefaultSettings() async {
    if (_userId == null) return;

    final defaultSettings = {
      'varietas': _selectedVarietas,
      'ambang_batas': {
        'suhu': {'min': suhuRange.start, 'max': suhuRange.end},
        'kelembapan_udara': {
          'min': kelembapanUdaraRange.start,
          'max': kelembapanUdaraRange.end,
        },
        'kelembapan_tanah': {
          'min': kelembapanTanahRange.start,
          'max': kelembapanTanahRange.end,
        },
        'ph_tanah': {'min': phTanahRange.start, 'max': phTanahRange.end},
        'intensitas_cahaya': {
          'min': intensitasCahayaRange.start,
          'max': intensitasCahayaRange.end,
        },
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

  /// Update ambang suhu ke Firebase dan Wokwi (min dan max)
  Future<void> _updateSuhu(RangeValues range) async {
    if (_userId == null) return;
    print('🔥 UPDATING SUHU: ${range.start} - ${range.end}');
    // Update user settings
    await _dbService.updateAmbangSuhu(_userId!, range.start, range.end);
    // Sync ke Wokwi threshold untuk varietas aktif
    if (_selectedVarietas.isNotEmpty) {
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');
      print('📡 Syncing to: smartfarm/threshold/$varietasId/suhu');
      await FirebaseDatabase.instance
          .ref('smartfarm/threshold/$varietasId/suhu')
          .set({'min': range.start, 'max': range.end});
      print('✅ Suhu synced to Wokwi');
    }
  }

  /// Update ambang kelembapan udara ke Firebase dan Wokwi (min dan max)
  Future<void> _updateKelembapanUdara(RangeValues range) async {
    if (_userId == null) return;
    print('💧 UPDATING KELEMBAPAN UDARA: ${range.start} - ${range.end}');
    // Update user settings
    await _dbService.updateAmbangKelembapanUdara(
      _userId!,
      range.start,
      range.end,
    );
    // Sync ke Wokwi threshold untuk varietas aktif
    if (_selectedVarietas.isNotEmpty) {
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');
      print('📡 Syncing to: smartfarm/threshold/$varietasId/kelembapan_udara');
      await FirebaseDatabase.instance
          .ref('smartfarm/threshold/$varietasId/kelembapan_udara')
          .set({'min': range.start, 'max': range.end});
      print('✅ Kelembapan Udara synced to Wokwi');
    }
  }

  /// Update ambang kelembapan tanah ke Firebase dan Wokwi (min dan max)
  Future<void> _updateKelembapanTanah(RangeValues range) async {
    if (_userId == null) return;
    print('🌱 UPDATING KELEMBAPAN TANAH: ${range.start} - ${range.end}');
    // Update user settings
    await _dbService.updateAmbangKelembapanTanah(
      _userId!,
      range.start,
      range.end,
    );
    // Sync ke Wokwi threshold untuk varietas aktif
    if (_selectedVarietas.isNotEmpty) {
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');
      print('📡 Syncing to: smartfarm/threshold/$varietasId/kelembapan_tanah');
      await FirebaseDatabase.instance
          .ref('smartfarm/threshold/$varietasId/kelembapan_tanah')
          .set({'min': range.start, 'max': range.end});
      print('✅ Kelembapan Tanah synced to Wokwi');
    }
  }

  /// Update ambang pH tanah ke Firebase dan Wokwi (min dan max)
  Future<void> _updatePhTanah(RangeValues range) async {
    if (_userId == null) return;
    print('🧪 UPDATING PH TANAH: ${range.start} - ${range.end}');
    // Update user settings
    await _dbService.updateAmbangPhTanah(_userId!, range.start, range.end);
    // Sync ke Wokwi threshold untuk varietas aktif
    if (_selectedVarietas.isNotEmpty) {
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');
      print('📡 Syncing to: smartfarm/threshold/$varietasId/ph_tanah');
      await FirebaseDatabase.instance
          .ref('smartfarm/threshold/$varietasId/ph_tanah')
          .set({'min': range.start, 'max': range.end});
      print('✅ pH Tanah synced to Wokwi');
    }
  }

  /// Update ambang intensitas cahaya ke Firebase dan Wokwi (min dan max)
  Future<void> _updateIntensitasCahaya(RangeValues range) async {
    if (_userId == null) return;
    print('☀️ UPDATING INTENSITAS CAHAYA: ${range.start} - ${range.end}');
    // Update user settings
    await _dbService.updateAmbangIntensitasCahaya(
      _userId!,
      range.start,
      range.end,
    );
    // Sync ke Wokwi threshold untuk varietas aktif
    if (_selectedVarietas.isNotEmpty) {
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');
      print('📡 Syncing to: smartfarm/threshold/$varietasId/intensitas_cahaya');
      await FirebaseDatabase.instance
          .ref('smartfarm/threshold/$varietasId/intensitas_cahaya')
          .set({'min': range.start, 'max': range.end});
      print('✅ Intensitas Cahaya synced to Wokwi');
    }
  }

  /// Sync semua threshold ke Wokwi untuk varietas yang dipilih (min dan max)
  Future<void> _syncAllThresholdsToWokwi() async {
    if (_selectedVarietas.isEmpty) return;

    try {
      // Konversi display name ke varietasId (lowercase dengan underscore)
      final varietasId = _selectedVarietas.toLowerCase().replaceAll(' ', '_');

      // Sync semua nilai threshold (min/max) ke path Wokwi
      final thresholdRef = FirebaseDatabase.instance.ref(
        'smartfarm/threshold/$varietasId',
      );

      await thresholdRef.set({
        'suhu': {'min': suhuRange.start, 'max': suhuRange.end},
        'kelembapan_udara': {
          'min': kelembapanUdaraRange.start,
          'max': kelembapanUdaraRange.end,
        },
        'kelembapan_tanah': {
          'min': kelembapanTanahRange.start,
          'max': kelembapanTanahRange.end,
        },
        'ph_tanah': {'min': phTanahRange.start, 'max': phTanahRange.end},
        'intensitas_cahaya': {
          'min': intensitasCahayaRange.start,
          'max': intensitasCahayaRange.end,
        },
      });

      print(
        '✅ All thresholds synced to Wokwi for $varietasId (from display: $_selectedVarietas)',
      );
    } catch (e) {
      print('❌ Error syncing thresholds to Wokwi: $e');
    }
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengaturan Sistem',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Atur varietas, notifikasi, dan batas sensor',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 🆕 MULTI-LOKASI: Menu Kelola Lokasi
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pushNamed(context, '/locations');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kelola Lokasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Atur dan kelola multiple lokasi greenhouse',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Varietas yang ditanam saat ini
            Card(
              key:
                  _varietasWidgetKey, // Force rebuild saat varietas berubah/dihapus
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
                        // Check if varietas list is loaded
                        if (_varietasList.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Loading varietas list...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          // Try to reload
                          await _loadVarietasList();
                          if (_varietasList.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tidak ada varietas tersedia'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                        }

                        final selected = await _showVarietasMenu(context);
                        if (selected != null) {
                          // Konversi nama varietas ke ID (lowercase dengan underscore)
                          final varietasId = selected.toLowerCase().replaceAll(
                            ' ',
                            '_',
                          );

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
                                    Text('Mengubah varietas & sync config...'),
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
                              throw Exception('Data varietas tidak ditemukan');
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
                                  'nitrogen_min': data['nitrogen_min'] ?? 200,
                                  'nitrogen_max': data['nitrogen_max'] ?? 340,
                                  'phosphorus_min':
                                      data['phosphorus_min'] ?? 150,
                                  'phosphorus_max':
                                      data['phosphorus_max'] ?? 240,
                                  'potassium_min': data['potassium_min'] ?? 190,
                                  'potassium_max': data['potassium_max'] ?? 320,
                                  'ec_min': data['ec_min'] ?? 1000,
                                  'ec_max': data['ec_max'] ?? 3000,
                                  'nama': data['nama'] ?? varietasId,
                                });

                            // 3. Update active_varietas global untuk ESP32


                            // 3b. 🆕 MULTI-LOKASI: Update active_varietas PER LOKASI
                            // Ambil active_location dari Firestore user profile
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_userId)
                                .get();
                            final activeLocationId = userDoc.exists
                                ? (userDoc.data()?['active_location'] ??
                                      'lokasi_1')
                                : 'lokasi_1';

                            // Update varietas untuk lokasi aktif
                            await FirebaseDatabase.instance
                                .ref(
                                  'smartfarm/locations/$activeLocationId/active_varietas',
                                )
                                .set(varietasId);
                            print(
                              '📍 Updated varietas for location: $activeLocationId → $varietasId',
                            );

                            // 4. Load config ke UI
                            await _loadVarietasConfig(varietasId);

                            // 5. Update user settings
                            setState(() => _selectedVarietas = selected);
                            await _updateVarietas(varietasId);

                            // 6. Sync threshold values ke Wokwi
                            await _syncAllThresholdsToWokwi();

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
                              child: _selectedVarietas.isEmpty
                                  ? Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.white.withOpacity(0.7),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Belum ada varietas yang dipilih',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _getVarietasDisplayName(
                                        _selectedVarietas,
                                      ),
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
            // Waktu Tanam Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              color: const Color(0xFF2D5F40),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Waktu Tanam',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectedVarietas.isEmpty
                          ? null
                          : _showPlantingDatePicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedVarietas.isEmpty
                              ? Colors.grey.shade300
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _selectedVarietas.isEmpty
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pilih varietas terlebih dahulu',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _waktuTanam == null
                                            ? 'Belum diatur'
                                            : '${_waktuTanam!.day}/${_waktuTanam!.month}/${_waktuTanam!.year}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _waktuTanam == null
                                              ? Colors.grey.shade600
                                              : const Color(0xFF2E7D32),
                                        ),
                                      ),
                                      if (_waktuTanam != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${DateTime.now().difference(_waktuTanam!).inDays + 1} hari yang lalu',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Icon(
                                    Icons.edit_calendar,
                                    color: const Color(0xFF2E7D32),
                                    size: 24,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_selectedVarietas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Atur waktu tanam untuk melacak umur dan fase tanaman',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Info auto-sync
                    if (_waktuTanam != null && _selectedVarietas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.sync, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Threshold NPK otomatis disesuaikan dengan fase pertumbuhan',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
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
                            border: Border.all(color: const Color(0xFF2E7D32)),
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
                    _RangeSliderIndicator(
                      icon: const Icon(
                        Icons.thermostat_outlined,
                        color: Color(0xFF234D2B),
                      ),
                      label: 'Suhu',
                      absMinLabel: '${suhuAbsMin.toStringAsFixed(0)}°C',
                      absMaxLabel: '${suhuAbsMax.toStringAsFixed(0)}°C',
                      absMin: suhuAbsMin,
                      absMax: suhuAbsMax,
                      values: suhuRange,
                      unit: '°C',
                      onChanged: (v) {
                        setState(() => suhuRange = v);
                        _updateSuhu(v);
                      },
                      divisions: (suhuAbsMax - suhuAbsMin).toInt(),
                    ),
                    const SizedBox(height: 14),

                    // Kelembapan Udara
                    _RangeSliderIndicator(
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
                      absMinLabel: '${humAbsMin.toStringAsFixed(0)}%',
                      absMaxLabel: '${humAbsMax.toStringAsFixed(0)}%',
                      absMin: humAbsMin,
                      absMax: humAbsMax,
                      values: kelembapanUdaraRange,
                      unit: '%',
                      onChanged: (v) {
                        setState(() => kelembapanUdaraRange = v);
                        _updateKelembapanUdara(v);
                      },
                      divisions: (humAbsMax - humAbsMin).toInt(),
                    ),
                    const SizedBox(height: 14),

                    // Kelembapan Tanah
                    _RangeSliderIndicator(
                      icon: const Icon(
                        Icons.terrain,
                        color: Color(0xFF234D2B),
                        size: 20,
                      ),
                      label: 'Kelembapan Tanah',
                      absMinLabel: soilAbsMin.toStringAsFixed(0),
                      absMaxLabel: soilAbsMax.toStringAsFixed(0),
                      absMin: soilAbsMin,
                      absMax: soilAbsMax,
                      values: kelembapanTanahRange,
                      unit: '',
                      onChanged: (v) {
                        setState(() => kelembapanTanahRange = v);
                        _updateKelembapanTanah(v);
                      },
                      divisions: ((soilAbsMax - soilAbsMin) / 10).toInt(),
                    ),
                    const SizedBox(height: 14),

                    // pH Tanah
                    _RangeSliderIndicator(
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
                      absMinLabel: phAbsMin.toStringAsFixed(1),
                      absMaxLabel: phAbsMax.toStringAsFixed(1),
                      absMin: phAbsMin,
                      absMax: phAbsMax,
                      values: phTanahRange,
                      unit: '',
                      onChanged: (v) {
                        setState(() => phTanahRange = v);
                        _updatePhTanah(v);
                      },
                      divisions: ((phAbsMax - phAbsMin) * 10).toInt(),
                    ),
                    const SizedBox(height: 14),

                    // Intensitas Cahaya
                    _RangeSliderIndicator(
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
                      absMinLabel: '${_formatNumber(luxAbsMin)} lux',
                      absMaxLabel: '${_formatNumber(luxAbsMax)} lux',
                      absMin: luxAbsMin,
                      absMax: luxAbsMax,
                      values: intensitasCahayaRange,
                      unit: ' lux',
                      onChanged: (v) {
                        setState(() => intensitasCahayaRange = v);
                        _updateIntensitasCahaya(v);
                      },
                      divisions: ((luxAbsMax - luxAbsMin) / 1000).toInt(),
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
                          activeThumbColor: Colors.white,
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
                    _notifTile('Notifikasi Status Pompa Irigasi', notifSiklus, (
                      v,
                    ) {
                      setState(() => notifSiklus = v ?? false);
                      _updateNotifikasiPompa(v ?? false);
                    }),
                    _notifTile('Notifikasi Tanaman Kritis', notifKritis, (v) {
                      setState(() => notifKritis = v ?? false);
                      _updateNotifikasiKritis(v ?? false);
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<String?> _showVarietasMenu(BuildContext context) async {
    // Validasi: pastikan ada varietas yang tersedia
    if (_varietasList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada varietas yang tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

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

    // Position menu tepat di bawah field dengan margin yang sama
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonTopLeft.dx, // Left edge sejajar dengan field
      buttonBottomLeft.dy + 4, // 4px gap dari field
      overlay.size.width -
          buttonTopLeft.dx -
          button.size.width, // Right edge sejajar
      overlay.size.height - buttonBottomLeft.dy - 4,
    );

    // Menu dengan background putih, rounded corners, dan shadow
    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      constraints: BoxConstraints(
        minWidth: button.size.width, // Width sama dengan field
        maxWidth: button.size.width,
      ),
      items: _varietasList.map((v) {
        // Konversi display name ke ID untuk perbandingan
        final varietasId = v.toLowerCase().replaceAll(' ', '_');
        final bool isSelected = varietasId == _selectedVarietas;
        return PopupMenuItem<String>(
          value: v,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.green.shade200, width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.eco,
                  size: 18,
                  color: isSelected
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    v,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.green.shade800
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green.shade700,
                  ),
              ],
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
  Widget _RangeSliderIndicator({
    required Widget icon,
    required String label,
    required String absMinLabel,
    required String absMaxLabel,
    required double absMin,
    required double absMax,
    required RangeValues values,
    required String unit,
    required ValueChanged<RangeValues> onChanged,
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
                '${_formatNumber(values.start)} - ${_formatNumber(values.end)}$unit',
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
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: RangeSlider(
            values: values,
            min: absMin,
            max: absMax,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(absMinLabel, style: const TextStyle(color: Colors.black54)),
            Text(absMaxLabel, style: const TextStyle(color: Colors.black45)),
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
