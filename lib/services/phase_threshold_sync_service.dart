import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service untuk auto-sync threshold NPK berdasarkan fase pertumbuhan
/// dari Firestore ke Realtime Database supaya Wokwi bisa baca
class PhaseThresholdSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static StreamSubscription? _userListener;
  static StreamSubscription? _varietasListener;

  static String? _currentVarietas;
  static int? _waktuTanam;
  static String _currentFase = '';

  /// Start listening untuk auto-sync
  static Future<void> startSync() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️ [PhaseSync] User belum login, skip sync');
      return;
    }

    print('🚀 [PhaseSync] Starting auto-sync service...');

    // Listen perubahan waktu_tanam & fase
    _userListener = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;

          final data = snapshot.data();
          final wt = data?['waktu_tanam'] as int?;

          if (wt != null) {
            _waktuTanam = wt;
            await _syncThresholdIfNeeded();
          }
        });

    // Listen perubahan active_varietas
    _varietasListener = _rtdb
        .ref('users/${user.uid}/active_varietas')
        .onValue
        .listen((event) async {
          if (event.snapshot.value != null) {
            final newVarietas = event.snapshot.value.toString();
            if (newVarietas != _currentVarietas) {
              _currentVarietas = newVarietas;
              print('🌶 [PhaseSync] Varietas berubah: $_currentVarietas');
              await _syncThresholdIfNeeded();
            }
          }
        });

    print('✅ [PhaseSync] Service started!');
  }

  /// Stop listening
  static Future<void> stopSync() async {
    await _userListener?.cancel();
    await _varietasListener?.cancel();
    _userListener = null;
    _varietasListener = null;
    print('🛑 [PhaseSync] Service stopped');
  }

  /// Hitung fase berdasarkan umur tanaman
  static String _calculateFase(int umurHari) {
    if (umurHari <= 30) {
      return 'vegetatif';
    } else if (umurHari <= 60) {
      return 'generatif';
    } else if (umurHari <= 70) {
      return 'pembungaan';
    } else if (umurHari <= 90) {
      return 'pembuahan';
    } else {
      return 'siap panen';
    }
  }

  /// Sync threshold ke RTDB jika diperlukan
  static Future<void> _syncThresholdIfNeeded() async {
    if (_currentVarietas == null || _waktuTanam == null) {
      print(
        '⏳ [PhaseSync] Belum siap sync (varietas: $_currentVarietas, waktu_tanam: $_waktuTanam)',
      );
      return;
    }

    // Hitung umur tanaman dan fase
    final tanamDate = DateTime.fromMillisecondsSinceEpoch(_waktuTanam!);
    final umurHari = DateTime.now().difference(tanamDate).inDays + 1;
    final fase = _calculateFase(umurHari);

    // Cek apakah fase berubah
    if (fase == _currentFase) {
      // Fase tidak berubah, skip sync
      return;
    }

    _currentFase = fase;

    print('📊 [PhaseSync] Umur: $umurHari hari, Fase: $fase');
    print('📥 [PhaseSync] Loading threshold dari Firestore...');

    // Normalize varietas key
    final varietasKey = _normalizeToKey(_currentVarietas!);

    try {
      // Baca threshold fase dari Firestore
      final phaseDoc = await _firestore
          .collection('varietas_config')
          .doc(varietasKey)
          .collection('phases')
          .doc(fase)
          .get();

      if (!phaseDoc.exists) {
        print(
          '❌ [PhaseSync] Data fase tidak ditemukan di Firestore: $varietasKey/$fase',
        );
        return;
      }

      final data = phaseDoc.data()!;

      // Sync ke RTDB dengan struktur yang sama dengan ESP32 baca
      final rtdbPath = 'smartfarm/varietas_config/$varietasKey';

      await _rtdb.ref(rtdbPath).set({
        'nitrogen_min': data['nitrogen_min'] ?? 0,
        'nitrogen_max': data['nitrogen_max'] ?? 4095,
        'phosphorus_min': data['phosphorus_min'] ?? 0,
        'phosphorus_max': data['phosphorus_max'] ?? 4095,
        'potassium_min': data['potassium_min'] ?? 0,
        'potassium_max': data['potassium_max'] ?? 4095,
        'fase': fase,
        'umur_hari': umurHari,
        'last_sync': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ [PhaseSync] Threshold fase $fase berhasil di-sync ke RTDB!');
      print('   📍 Path: $rtdbPath');
      print('   🧪 N: ${data['nitrogen_min']}-${data['nitrogen_max']}');
      print('   🧪 P: ${data['phosphorus_min']}-${data['phosphorus_max']}');
      print('   🧪 K: ${data['potassium_min']}-${data['potassium_max']}');
    } catch (e) {
      print('❌ [PhaseSync] Error sync threshold: $e');
    }
  }

  /// Normalize varietas name ke key format
  static String _normalizeToKey(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Manual trigger sync (untuk testing atau force refresh)
  static Future<void> forceSync() async {
    _currentFase = ''; // Reset fase untuk trigger sync
    await _syncThresholdIfNeeded();
  }
}
