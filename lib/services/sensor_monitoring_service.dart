import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_notification_service.dart';

/// Service untuk monitoring sensor data dan trigger notifikasi
/// ketika nilai sensor mendekati atau melewati ambang batas
class SensorMonitoringService {
  static final SensorMonitoringService _instance =
      SensorMonitoringService._internal();
  factory SensorMonitoringService() => _instance;
  SensorMonitoringService._internal();

  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _thresholdSubscription;
  final LocalNotificationService _notificationService =
      LocalNotificationService();

  // Threshold values (akan di-load dari user settings)
  Map<String, dynamic> _thresholds = {};
  String? _userId;
  String? _varietas;
  bool _isMonitoring = false;

  // Debounce untuk prevent spam notifications
  final Map<String, DateTime> _lastNotificationTime = {};
  final Duration _notificationCooldown = const Duration(minutes: 5);

  // Track apakah notifikasi enabled
  bool _notificationEnabled = true;
  bool _criticalNotificationEnabled = true;

  /// Start monitoring sensor data
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Cannot start monitoring: User not logged in');
      return;
    }

    _userId = user.uid;
    print('🔔 Starting sensor monitoring for user: $_userId');

    // Initialize notification service
    await _notificationService.initialize();
    await _notificationService.requestPermissions();

    // Load user settings (varietas & thresholds)
    await _loadUserSettings();

    // Start listening to sensor data
    _listenToSensorData();

    // Listen to threshold changes
    _listenToThresholdChanges();

    _isMonitoring = true;
    print('✅ Sensor monitoring started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    print('🛑 Stopping sensor monitoring');
    _sensorSubscription?.cancel();
    _thresholdSubscription?.cancel();
    _isMonitoring = false;
    _lastNotificationTime.clear();
  }

  /// Load user settings dari Firebase
  Future<void> _loadUserSettings() async {
    if (_userId == null) return;

    try {
      final db = FirebaseDatabase.instance.ref();
      final userSnapshot = await db.child('users').child(_userId!).get();

      if (userSnapshot.exists && userSnapshot.value is Map) {
        final userData = userSnapshot.value as Map;

        // Get varietas
        _varietas =
            (userData['active_varietas'] ??
                    (userData['settings'] is Map
                        ? userData['settings']['varietas']
                        : null))
                ?.toString();

        // Get notification settings
        if (userData['settings'] is Map) {
          final settings = userData['settings'] as Map;
          _notificationEnabled = settings['notifikasi_enabled'] ?? true;
          _criticalNotificationEnabled = settings['notifikasi_kritis'] ?? true;
        }

        // Get thresholds
        if (userData['thresholds'] is Map) {
          _thresholds = Map<String, dynamic>.from(
            userData['thresholds'] as Map,
          );
          print('📊 Loaded thresholds: $_thresholds');
        }
      }

      // Fallback to global varietas if not set
      if (_varietas == null || _varietas!.isEmpty) {
        final globalSnapshot = await db
            .child('smartfarm')
            .child('active_varietas')
            .get();
        if (globalSnapshot.exists) {
          _varietas = globalSnapshot.value.toString();
        }
      }

      print('🌾 Monitoring varietas: $_varietas');
    } catch (e) {
      print('❌ Error loading user settings: $e');
    }
  }

  /// Listen to threshold changes in real-time
  void _listenToThresholdChanges() {
    if (_userId == null) return;

    final thresholdRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(_userId!)
        .child('thresholds');

    _thresholdSubscription = thresholdRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        _thresholds = Map<String, dynamic>.from(event.snapshot.value as Map);
        print('🔄 Thresholds updated: $_thresholds');
      }
    });
  }

  /// Listen to sensor data in real-time
  void _listenToSensorData() {
    if (_varietas == null || _varietas!.isEmpty) {
      print('⚠️ Cannot listen to sensor data: Varietas not set');
      return;
    }

    final sensorRef = FirebaseDatabase.instance
        .ref()
        .child('smartfarm')
        .child('sensors')
        .child(_varietas!);

    print('👂 Listening to sensor data at: smartfarm/sensors/$_varietas');

    _sensorSubscription = sensorRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data = event.snapshot.value;
      if (data is! Map) return;

      _checkSensorValues(Map<String, dynamic>.from(data));
    });
  }

  /// Check sensor values against thresholds
  void _checkSensorValues(Map<String, dynamic> sensorData) {
    if (!_notificationEnabled || !_criticalNotificationEnabled) return;

    print('📊 Checking sensor values: $sensorData');
    print('🎯 Against thresholds: $_thresholds');

    // Check Suhu
    if (sensorData['suhu'] != null && _thresholds['suhu_min'] != null) {
      final suhu = _parseDouble(sensorData['suhu']);
      final suhuMin = _parseDouble(_thresholds['suhu_min']);
      final suhuMax = _parseDouble(_thresholds['suhu_max']);

      if (suhu < suhuMin) {
        _sendWarningNotification(
          type: 'suhu',
          title: '🥶 Suhu Terlalu Rendah',
          message:
              'Suhu saat ini ${suhu.toStringAsFixed(1)}°C, di bawah batas minimum ${suhuMin.toStringAsFixed(1)}°C',
          severity: 'high',
        );
      } else if (suhu > suhuMax) {
        _sendWarningNotification(
          type: 'suhu',
          title: '🔥 Suhu Terlalu Tinggi',
          message:
              'Suhu saat ini ${suhu.toStringAsFixed(1)}°C, melebihi batas maksimum ${suhuMax.toStringAsFixed(1)}°C',
          severity: 'high',
        );
      } else if (suhu <= suhuMin + 1) {
        // Approaching minimum
        _sendWarningNotification(
          type: 'suhu',
          title: '⚠️ Suhu Mendekati Batas Minimum',
          message:
              'Suhu saat ini ${suhu.toStringAsFixed(1)}°C, mendekati batas minimum ${suhuMin.toStringAsFixed(1)}°C',
          severity: 'medium',
        );
      } else if (suhu >= suhuMax - 1) {
        // Approaching maximum
        _sendWarningNotification(
          type: 'suhu',
          title: '⚠️ Suhu Mendekati Batas Maksimum',
          message:
              'Suhu saat ini ${suhu.toStringAsFixed(1)}°C, mendekati batas maksimum ${suhuMax.toStringAsFixed(1)}°C',
          severity: 'medium',
        );
      }
    }

    // Check Kelembapan Udara
    if (sensorData['kelembapan_udara'] != null &&
        _thresholds['kelembapan_udara_min'] != null) {
      final humidity = _parseDouble(sensorData['kelembapan_udara']);
      final humMin = _parseDouble(_thresholds['kelembapan_udara_min']);
      final humMax = _parseDouble(_thresholds['kelembapan_udara_max']);

      if (humidity < humMin) {
        _sendWarningNotification(
          type: 'kelembapan',
          title: '💨 Kelembapan Udara Rendah',
          message:
              'Kelembapan ${humidity.toStringAsFixed(1)}%, di bawah batas minimum ${humMin.toStringAsFixed(1)}%',
          severity: 'high',
        );
      } else if (humidity > humMax) {
        _sendWarningNotification(
          type: 'kelembapan',
          title: '💧 Kelembapan Udara Tinggi',
          message:
              'Kelembapan ${humidity.toStringAsFixed(1)}%, melebihi batas maksimum ${humMax.toStringAsFixed(1)}%',
          severity: 'high',
        );
      } else if (humidity <= humMin + 3) {
        _sendWarningNotification(
          type: 'kelembapan',
          title: '⚠️ Kelembapan Mendekati Batas Minimum',
          message:
              'Kelembapan ${humidity.toStringAsFixed(1)}%, mendekati batas minimum ${humMin.toStringAsFixed(1)}%',
          severity: 'medium',
        );
      } else if (humidity >= humMax - 3) {
        _sendWarningNotification(
          type: 'kelembapan',
          title: '⚠️ Kelembapan Mendekati Batas Maksimum',
          message:
              'Kelembapan ${humidity.toStringAsFixed(1)}%, mendekati batas maksimum ${humMax.toStringAsFixed(1)}%',
          severity: 'medium',
        );
      }
    }

    // Check Kelembapan Tanah
    if (sensorData['kelembaban_tanah'] != null &&
        _thresholds['kelembapan_tanah_min'] != null) {
      final soilMoisture = _parseDouble(sensorData['kelembaban_tanah']);
      final soilMin = _parseDouble(_thresholds['kelembapan_tanah_min']);
      final soilMax = _parseDouble(_thresholds['kelembapan_tanah_max']);

      if (soilMoisture < soilMin) {
        _sendWarningNotification(
          type: 'tanah',
          title: '🌵 Tanah Terlalu Kering',
          message:
              'Kelembapan tanah ${soilMoisture.toStringAsFixed(0)}, di bawah batas minimum ${soilMin.toStringAsFixed(0)}',
          severity: 'high',
        );
      } else if (soilMoisture > soilMax) {
        _sendWarningNotification(
          type: 'tanah',
          title: '💦 Tanah Terlalu Basah',
          message:
              'Kelembapan tanah ${soilMoisture.toStringAsFixed(0)}, melebihi batas maksimum ${soilMax.toStringAsFixed(0)}',
          severity: 'high',
        );
      } else if (soilMoisture <= soilMin + 50) {
        _sendWarningNotification(
          type: 'tanah',
          title: '⚠️ Kelembapan Tanah Mendekati Minimum',
          message:
              'Kelembapan tanah ${soilMoisture.toStringAsFixed(0)}, mendekati batas minimum ${soilMin.toStringAsFixed(0)}',
          severity: 'medium',
        );
      } else if (soilMoisture >= soilMax - 50) {
        _sendWarningNotification(
          type: 'tanah',
          title: '⚠️ Kelembapan Tanah Mendekati Maksimum',
          message:
              'Kelembapan tanah ${soilMoisture.toStringAsFixed(0)}, mendekati batas maksimum ${soilMax.toStringAsFixed(0)}',
          severity: 'medium',
        );
      }
    }

    // Check pH Tanah
    if (sensorData['ph_tanah'] != null && _thresholds['ph_tanah_min'] != null) {
      final ph = _parseDouble(sensorData['ph_tanah']);
      final phMin = _parseDouble(_thresholds['ph_tanah_min']);
      final phMax = _parseDouble(_thresholds['ph_tanah_max']);

      if (ph < phMin) {
        _sendWarningNotification(
          type: 'ph',
          title: '🧪 pH Tanah Terlalu Asam',
          message:
              'pH tanah ${ph.toStringAsFixed(1)}, di bawah batas minimum ${phMin.toStringAsFixed(1)}',
          severity: 'high',
        );
      } else if (ph > phMax) {
        _sendWarningNotification(
          type: 'ph',
          title: '🧪 pH Tanah Terlalu Basa',
          message:
              'pH tanah ${ph.toStringAsFixed(1)}, melebihi batas maksimum ${phMax.toStringAsFixed(1)}',
          severity: 'high',
        );
      } else if (ph <= phMin + 0.2) {
        _sendWarningNotification(
          type: 'ph',
          title: '⚠️ pH Mendekati Batas Minimum',
          message:
              'pH tanah ${ph.toStringAsFixed(1)}, mendekati batas minimum ${phMin.toStringAsFixed(1)}',
          severity: 'medium',
        );
      } else if (ph >= phMax - 0.2) {
        _sendWarningNotification(
          type: 'ph',
          title: '⚠️ pH Mendekati Batas Maksimum',
          message:
              'pH tanah ${ph.toStringAsFixed(1)}, mendekati batas maksimum ${phMax.toStringAsFixed(1)}',
          severity: 'medium',
        );
      }
    }

    // Check Intensitas Cahaya
    if (sensorData['intensitas_cahaya'] != null &&
        _thresholds['intensitas_cahaya_min'] != null) {
      final lux = _parseDouble(sensorData['intensitas_cahaya']);
      final luxMin = _parseDouble(_thresholds['intensitas_cahaya_min']);
      final luxMax = _parseDouble(_thresholds['intensitas_cahaya_max']);

      if (lux < luxMin) {
        _sendWarningNotification(
          type: 'cahaya',
          title: '🌑 Cahaya Terlalu Rendah',
          message:
              'Intensitas cahaya ${lux.toStringAsFixed(0)} lux, di bawah batas minimum ${luxMin.toStringAsFixed(0)} lux',
          severity: 'medium',
        );
      } else if (lux > luxMax) {
        _sendWarningNotification(
          type: 'cahaya',
          title: '☀️ Cahaya Terlalu Tinggi',
          message:
              'Intensitas cahaya ${lux.toStringAsFixed(0)} lux, melebihi batas maksimum ${luxMax.toStringAsFixed(0)} lux',
          severity: 'medium',
        );
      } else if (lux <= luxMin + 1000) {
        _sendWarningNotification(
          type: 'cahaya',
          title: '⚠️ Cahaya Mendekati Minimum',
          message:
              'Intensitas cahaya ${lux.toStringAsFixed(0)} lux, mendekati batas minimum ${luxMin.toStringAsFixed(0)} lux',
          severity: 'low',
        );
      } else if (lux >= luxMax - 1000) {
        _sendWarningNotification(
          type: 'cahaya',
          title: '⚠️ Cahaya Mendekati Maksimum',
          message:
              'Intensitas cahaya ${lux.toStringAsFixed(0)} lux, mendekati batas maksimum ${luxMax.toStringAsFixed(0)} lux',
          severity: 'low',
        );
      }
    }
  }

  /// Send warning notification with cooldown
  Future<void> _sendWarningNotification({
    required String type,
    required String title,
    required String message,
    required String severity,
  }) async {
    // Check cooldown
    final now = DateTime.now();
    if (_lastNotificationTime.containsKey(type)) {
      final lastTime = _lastNotificationTime[type]!;
      if (now.difference(lastTime) < _notificationCooldown) {
        print('⏳ Cooldown active for $type notification');
        return;
      }
    }

    // Update last notification time
    _lastNotificationTime[type] = now;

    // Save warning to Firebase Realtime Database
    await _saveWarningToDatabase(type, message, severity);

    // Send local notification
    try {
      await _notificationService.showImmediateNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        body: message,
      );
      print('✅ Notification sent: $title');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Save warning to Firebase for history
  Future<void> _saveWarningToDatabase(
    String sensorType,
    String message,
    String severity,
  ) async {
    if (_varietas == null || _varietas!.isEmpty) return;

    try {
      final db = FirebaseDatabase.instance.ref();
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final warningRef = db
          .child('smartfarm')
          .child('warning')
          .child(_varietas!)
          .child(dateKey)
          .child(sensorType)
          .push();

      await warningRef.set({
        'message': message,
        'timestamp': ServerValue.timestamp,
        'severity': severity,
        'isRead': false,
      });

      print('💾 Warning saved to database: $sensorType');
    } catch (e) {
      print('❌ Error saving warning to database: $e');
    }
  }

  /// Parse double from dynamic value
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
