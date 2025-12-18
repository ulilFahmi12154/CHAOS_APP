import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedPeriod = 'Bulan Ini';
  String? _activeVarietas;
  bool _isLoadingData = true;
  Map<String, dynamic> _reportData = {};
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  StreamSubscription<DatabaseEvent>? _varietasSubscription;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  // MULTI-LOKASI
  String? activeLocationId;

  @override
  void initState() {
    super.initState();
    _setupVarietasListener();
  }

  @override
  void dispose() {
    _varietasSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _setupVarietasListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // MULTI-LOKASI: Load active location dulu
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        activeLocationId = userDoc.data()?['active_location'] ?? 'lokasi_1';
        print('📍 REPORT: Active location loaded: $activeLocationId');
      } else {
        activeLocationId = 'lokasi_1';
      }
    } catch (e) {
      print('❌ Error loading location: $e');
      activeLocationId = 'lokasi_1';
    }

    // Listen to location changes from Firestore
    _locationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final newLocationId =
                snapshot.data()?['active_location'] ?? 'lokasi_1';
            if (newLocationId != activeLocationId) {
              print(
                '📍 REPORT: Location changed: $activeLocationId → $newLocationId',
              );
              activeLocationId = newLocationId;

              // Cancel dan re-setup listener varietas untuk lokasi baru
              _varietasSubscription?.cancel();
              _setupVarietasListenerForLocation();
            }
          }
        });

    // Setup listener varietas untuk lokasi aktif
    _setupVarietasListenerForLocation();
  }

  void _setupVarietasListenerForLocation() {
    if (activeLocationId == null) {
      print('⚠️ REPORT: Cannot setup varietas listener, location not loaded');
      return;
    }

    print(
      '🔔 REPORT: Setting up varietas listener for location: $activeLocationId',
    );

    // MULTI-LOKASI: Listen ke path active_varietas per-lokasi
    final varietasRef = FirebaseDatabase.instance.ref(
      'smartfarm/locations/$activeLocationId/active_varietas',
    );

    // Listen to real-time changes
    _varietasSubscription = varietasRef.onValue.listen(
      (event) {
        print('📡 REPORT: Varietas listener triggered');
        print('  → Snapshot exists: ${event.snapshot.exists}');
        print('  → Snapshot value: ${event.snapshot.value}');

        if (event.snapshot.exists && mounted) {
          final newVarietas = event.snapshot.value.toString();
          print('🔄 REPORT: Varietas changed to $newVarietas');
          setState(() {
            _activeVarietas = newVarietas;
          });
          // Always reload data when varietas changes or on first load
          _loadReportData();
        } else if (mounted) {
          // Varietas dihapus atau belum ada
          print('🗑️ REPORT: No varietas selected (deleted or empty)');
          setState(() {
            _activeVarietas = null;
            _isLoadingData = false;
            _reportData = {};
          });
        }
      },
      onError: (error) {
        print('❌ Error listening to varietas: $error');
      },
    );
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoadingData = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingData = false);
      return;
    }

    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      // Gunakan custom date jika ada
      if (_customStartDate != null && _customEndDate != null) {
        startDate = _customStartDate!;
        endDate = _customEndDate!;
      } else {
        switch (_selectedPeriod) {
          case 'Hari Ini':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'Minggu Ini':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            break;
          case 'Bulan Ini':
          default:
            startDate = DateTime(now.year, now.month, 1);
            break;
        }
      }

      // Pastikan varietas sudah di-set oleh listener
      if (_activeVarietas == null) {
        // Jika belum ada varietas, stop loading
        setState(() => _isLoadingData = false);
        return;
      }

      final varietas = _activeVarietas!;
      print('📊 Loading report data for: $varietas');
      print('📍 Active location: $activeLocationId');

      // Ambil data sensor history dari Firebase (per-location)
      final sensorHistoryRef = FirebaseDatabase.instance.ref(
        'smartfarm/locations/$activeLocationId/history/$varietas',
      );
      final sensorHistorySnapshot = await sensorHistoryRef.get();
      print('📦 Sensor history exists: ${sensorHistorySnapshot.exists}');

      // Ambil data irrigation history (per-location)
      final irrigationHistoryRef = FirebaseDatabase.instance.ref(
        'smartfarm/locations/$activeLocationId/irrigation_history/$varietas',
      );
      final irrigationHistorySnapshot = await irrigationHistoryRef.get();
      print(
        '💧 Irrigation history exists: ${irrigationHistorySnapshot.exists}',
      );

      int totalPenyiraman = 0;
      double totalDurasi = 0;
      List<double> suhuList = [];
      List<double> humidityList = [];
      List<double> soilList = [];
      List<double> lightList = [];
      List<double> phList = [];
      Map<String, int> dailyIrrigation = {};
      Map<String, double> weeklySuhu = {};
      Map<String, double> weeklyHumidity = {};
      Map<String, double> weeklySoil = {};
      int penyiramanOtomatis = 0;
      int penyiramanManual = 0;
      double totalAirUsed = 0;

      // Process sensor history data
      if (sensorHistorySnapshot.exists) {
        final historyData = sensorHistorySnapshot.value as Map;
        print('📊 Processing ${historyData.length} history entries');

        historyData.forEach((key, value) {
          try {
            // Check if this is a date-based structure
            if (value is Map && !value.containsKey('timestamp')) {
              // Nested structure: date -> pushKey -> data
              value.forEach((pushKey, sensorData) {
                if (sensorData is Map) {
                  final timestamp = sensorData['timestamp'] as int?;
                  if (timestamp != null) {
                    final dateTime = DateTime.fromMillisecondsSinceEpoch(
                      timestamp,
                    );
                    if (dateTime.isAfter(
                          startDate.subtract(const Duration(days: 1)),
                        ) &&
                        dateTime.isBefore(
                          endDate.add(const Duration(days: 1)),
                        )) {
                      // Process nested sensor data
                      if (sensorData['suhu'] != null) {
                        final temp = (sensorData['suhu'] as num).toDouble();
                        suhuList.add(temp);
                        final dayKey = DateFormat('EEE').format(dateTime);
                        weeklySuhu[dayKey] = (weeklySuhu[dayKey] ?? 0) + temp;
                      }
                      if (sensorData['kelembapan_udara'] != null) {
                        final hum = (sensorData['kelembapan_udara'] as num)
                            .toDouble();
                        humidityList.add(hum);
                        final dayKey = DateFormat('EEE').format(dateTime);
                        weeklyHumidity[dayKey] =
                            (weeklyHumidity[dayKey] ?? 0) + hum;
                      }
                      if (sensorData['kelembapan_tanah'] != null) {
                        final soil = (sensorData['kelembapan_tanah'] as num)
                            .toDouble();
                        soilList.add(soil);
                        final dayKey = DateFormat('EEE').format(dateTime);
                        weeklySoil[dayKey] = (weeklySoil[dayKey] ?? 0) + soil;
                      }
                      if (sensorData['intensitas_cahaya'] != null) {
                        lightList.add(
                          (sensorData['intensitas_cahaya'] as num).toDouble(),
                        );
                      }
                      if (sensorData['ph_tanah'] != null) {
                        phList.add((sensorData['ph_tanah'] as num).toDouble());
                      }
                    }
                  }
                }
              });
            } else if (value is Map) {
              // Direct structure: pushKey -> data
              final timestamp = value['timestamp'] as int?;
              if (timestamp != null) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

                // Filter berdasarkan range tanggal
                if (dateTime.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    dateTime.isBefore(endDate.add(const Duration(days: 1)))) {
                  // Ambil data sensor (field names sesuai Firebase)
                  if (value['suhu'] != null) {
                    final temp = (value['suhu'] as num).toDouble();
                    suhuList.add(temp);

                    // Aggregate weekly data
                    final dayKey = DateFormat('EEE').format(dateTime);
                    weeklySuhu[dayKey] = (weeklySuhu[dayKey] ?? 0) + temp;
                  }
                  if (value['kelembapan_udara'] != null) {
                    final hum = (value['kelembapan_udara'] as num).toDouble();
                    humidityList.add(hum);

                    final dayKey = DateFormat('EEE').format(dateTime);
                    weeklyHumidity[dayKey] =
                        (weeklyHumidity[dayKey] ?? 0) + hum;
                  }
                  if (value['kelembapan_tanah'] != null) {
                    final soil = (value['kelembapan_tanah'] as num).toDouble();
                    soilList.add(soil);

                    final dayKey = DateFormat('EEE').format(dateTime);
                    weeklySoil[dayKey] = (weeklySoil[dayKey] ?? 0) + soil;
                  }
                  if (value['intensitas_cahaya'] != null) {
                    lightList.add(
                      (value['intensitas_cahaya'] as num).toDouble(),
                    );
                  }
                  if (value['ph_tanah'] != null) {
                    phList.add((value['ph_tanah'] as num).toDouble());
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error processing sensor data: $e');
          }
        });
      }

      // Process irrigation history data
      if (irrigationHistorySnapshot.exists) {
        final irrigationData = irrigationHistorySnapshot.value as Map;

        irrigationData.forEach((key, value) {
          try {
            if (value is Map) {
              final timestamp = value['timestamp'] as int?;
              if (timestamp != null) {
                // PENTING: timestamp dari ESP32 dalam DETIK, bukan milliseconds!
                // Convert ke milliseconds untuk DateTime parsing
                final timestampMs = timestamp * 1000;
                final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  timestampMs,
                );

                // Filter berdasarkan range tanggal
                if (dateTime.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    dateTime.isBefore(endDate.add(const Duration(days: 1)))) {
                  totalPenyiraman++;

                  // Hitung durasi (duration dari Firebase dalam DETIK)
                  if (value['duration'] != null) {
                    final durationSeconds = (value['duration'] as num)
                        .toDouble();
                    final durationMinutes =
                        durationSeconds / 60; // detik → menit
                    final durationHours = durationMinutes / 60; // menit → jam
                    totalDurasi += durationHours;

                    // Estimasi penggunaan air (asumsi 5 liter/menit)
                    totalAirUsed += durationMinutes * 5;
                  }

                  // Hitung penyiraman per hari
                  final dayKey = DateFormat('yyyy-MM-dd').format(dateTime);
                  dailyIrrigation[dayKey] = (dailyIrrigation[dayKey] ?? 0) + 1;

                  // Kategorikan tipe penyiraman
                  final mode = value['mode']?.toString() ?? 'auto';
                  if (mode == 'manual') {
                    penyiramanManual++;
                  } else {
                    penyiramanOtomatis++;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error processing irrigation data: $e');
          }
        });
      }

      // Hitung statistik tambahan
      double? maxSuhu, minSuhu, maxHumidity, minHumidity, maxSoil, minSoil;
      double? avgLight, avgPh;

      if (suhuList.isNotEmpty) {
        maxSuhu = suhuList.reduce((a, b) => a > b ? a : b);
        minSuhu = suhuList.reduce((a, b) => a < b ? a : b);
      }
      if (humidityList.isNotEmpty) {
        maxHumidity = humidityList.reduce((a, b) => a > b ? a : b);
        minHumidity = humidityList.reduce((a, b) => a < b ? a : b);
      }
      if (soilList.isNotEmpty) {
        maxSoil = soilList.reduce((a, b) => a > b ? a : b);
        minSoil = soilList.reduce((a, b) => a < b ? a : b);
      }
      if (lightList.isNotEmpty) {
        avgLight = lightList.reduce((a, b) => a + b) / lightList.length;
      }
      if (phList.isNotEmpty) {
        avgPh = phList.reduce((a, b) => a + b) / phList.length;
      }

      // Hitung rata-rata penyiraman per hari
      final totalDays = endDate.difference(startDate).inDays + 1;
      final avgPenyiramanPerHari = totalPenyiraman / totalDays;

      // Jika tidak ada data, gunakan nilai default
      if (suhuList.isEmpty) {
        suhuList.add(25.3);
      }
      if (humidityList.isEmpty) {
        humidityList.add(65.0);
      }

      setState(() {
        _reportData = {
          'totalPenyiraman': totalPenyiraman,
          'totalDurasi': totalDurasi.toStringAsFixed(1),
          'avgSuhu': suhuList.isNotEmpty
              ? (suhuList.reduce((a, b) => a + b) / suhuList.length)
                    .toStringAsFixed(1)
              : '25.3',
          'avgHumidity': humidityList.isNotEmpty
              ? (humidityList.reduce((a, b) => a + b) / humidityList.length)
                    .toInt()
              : 65,
          'avgSoil': soilList.isNotEmpty
              ? (soilList.reduce((a, b) => a + b) / soilList.length)
                    .toStringAsFixed(0)
              : '1450',
          'avgLight': avgLight?.toStringAsFixed(0) ?? '-',
          'avgPh': avgPh?.toStringAsFixed(1) ?? '-',
          'maxSuhu': maxSuhu?.toStringAsFixed(1) ?? '-',
          'minSuhu': minSuhu?.toStringAsFixed(1) ?? '-',
          'maxHumidity': maxHumidity?.toInt() ?? 0,
          'minHumidity': minHumidity?.toInt() ?? 0,
          'maxSoil': maxSoil?.toStringAsFixed(0) ?? '-',
          'minSoil': minSoil?.toStringAsFixed(0) ?? '-',
          'totalAirUsed': totalAirUsed.toStringAsFixed(1),
          'penyiramanOtomatis': penyiramanOtomatis,
          'penyiramanManual': penyiramanManual,
          'avgPenyiramanPerHari': avgPenyiramanPerHari.toStringAsFixed(1),
          'totalDays': totalDays,
          'dailyIrrigation': dailyIrrigation,
          'weeklySuhu': weeklySuhu,
          'weeklyHumidity': weeklyHumidity,
          'weeklySoil': weeklySoil,
          'periodStart': DateFormat('dd MMM yyyy').format(startDate),
          'periodEnd': DateFormat('dd MMM yyyy').format(endDate),
          'varietas': varietas,
          'dataCount': suhuList.length,
        };
        // Update _activeVarietas to match loaded data
        _activeVarietas = varietas;
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading report data: $e');
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF1B5E20),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFF1B5E20),
              headerForegroundColor: Colors.white,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedPeriod = 'Custom';
      });
      await _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Header Laporan - Style konsisten dengan History
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1B5E20),
                    const Color(0xFF2E7D32),
                    const Color(0xFF4CAF50),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.assessment,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Analisis data dan performa pertanian',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section Download Laporan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_download_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Laporan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Anda bisa mendownload laporan dalam format PDF atau Excel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildExportButton(),
                ],
              ),
            ),

            // Tampilkan peringatan jika belum ada varietas
            if (_activeVarietas == null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belum ada varietas yang dipilih',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pilih varietas di menu Pengaturan untuk melihat laporan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_reportData.isNotEmpty && _activeVarietas != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Varietas Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          _activeVarietas!.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Period Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Periode: $_selectedPeriod',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date Range Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_reportData['periodStart']} - ${_reportData['periodEnd']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            _buildPeriodSelector(),
            const SizedBox(height: 20),

            _isLoadingData
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Penyiraman',
                          _reportData['totalPenyiraman']?.toString() ?? '0',
                          'kali',
                          Icons.water_drop,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Durasi Total',
                          _reportData['totalDurasi'] ?? '0',
                          'jam',
                          Icons.timer,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Rata-rata Suhu',
                    _reportData['avgSuhu'] ?? '25.3',
                    '°C',
                    Icons.thermostat,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Kelembapan Rata-rata',
                    _reportData['avgHumidity']?.toString() ?? '65',
                    '%',
                    Icons.water,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistik Detail
            _buildDetailStatsCard(),
            const SizedBox(height: 20),

            // Statistik Penyiraman
            _buildIrrigationStatsCard(),
            const SizedBox(height: 20),

            // Range Sensor Data
            _buildSensorRangeCard(),
            const SizedBox(height: 20),

            _buildPerformanceCard(),
            const SizedBox(height: 20),

            _buildWeeklyActivityCard(),
            const SizedBox(height: 20),

            _buildRecommendationsCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
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
          child: Row(
            children: [
              _buildPeriodButton('Hari Ini'),
              _buildPeriodButton('Minggu Ini'),
              _buildPeriodButton('Bulan Ini'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tombol Custom Date Range
        InkWell(
          onTap: _showDateRangePicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _selectedPeriod == 'Custom'
                  ? const Color(0xFF1B5E20)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPeriod == 'Custom'
                    ? const Color(0xFF1B5E20)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.date_range,
                  size: 18,
                  color: _selectedPeriod == 'Custom'
                      ? Colors.white
                      : const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 8),
                Text(
                  _customStartDate != null && _customEndDate != null
                      ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}'
                      : 'Pilih Rentang Tanggal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _selectedPeriod == 'Custom'
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: _selectedPeriod == 'Custom'
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
            // Reset custom date ketika memilih periode preset
            _customStartDate = null;
            _customEndDate = null;
          });
          _loadReportData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Performa Sistem',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPerformanceItem('Efisiensi Penyiraman', 87, Colors.blue),
          const SizedBox(height: 12),
          _buildPerformanceItem('Kondisi Tanaman', 92, Colors.green),
          const SizedBox(height: 12),
          _buildPerformanceItem('Stabilitas Sensor', 95, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Mingguan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDayColumn('Sen', 12, 15),
              _buildDayColumn('Sel', 15, 15),
              _buildDayColumn('Rab', 14, 15),
              _buildDayColumn('Kam', 10, 15),
              _buildDayColumn('Jum', 13, 15),
              _buildDayColumn('Sab', 8, 15),
              _buildDayColumn('Min', 6, 15),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Penyiraman per hari',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(String day, int value, int max) {
    final percentage = value / max;
    return Column(
      children: [
        Container(
          width: 32,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 32,
            height: 80 * percentage,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Widget Statistik Detail
  Widget _buildDetailStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: Colors.purple.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Statistik Detail',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatRow(
            'Total Hari Monitoring',
            '${_reportData['totalDays'] ?? 0} hari',
            Icons.today,
          ),
          const Divider(height: 24),
          _buildStatRow(
            'Data Sensor Tercatat',
            '${_reportData['dataCount'] ?? 0} record',
            Icons.sensors,
          ),
          const Divider(height: 24),
          _buildStatRow(
            'Rata-rata Penyiraman/Hari',
            '${_reportData['avgPenyiramanPerHari'] ?? '0'} kali',
            Icons.water_drop,
          ),
          const Divider(height: 24),
          _buildStatRow(
            'Total Penggunaan Air',
            '${_reportData['totalAirUsed'] ?? '0'} liter',
            Icons.opacity,
          ),
          if (_reportData['avgSoil'] != null &&
              _reportData['avgSoil'] != '-') ...[
            const Divider(height: 24),
            _buildStatRow(
              'Kelembapan Tanah',
              '${_reportData['avgSoil']} ADC',
              Icons.grass,
            ),
          ],
          if (_reportData['avgLight'] != null &&
              _reportData['avgLight'] != '-') ...[
            const Divider(height: 24),
            _buildStatRow(
              'Intensitas Cahaya',
              '${_reportData['avgLight']} lux',
              Icons.wb_sunny,
            ),
          ],
          if (_reportData['avgPh'] != null && _reportData['avgPh'] != '-') ...[
            const Divider(height: 24),
            _buildStatRow(
              'pH Tanah',
              _reportData['avgPh'] ?? '-',
              Icons.science,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Widget Statistik Penyiraman
  Widget _buildIrrigationStatsCard() {
    final total = _reportData['totalPenyiraman'] ?? 0;
    final otomatis = _reportData['penyiramanOtomatis'] ?? 0;
    final manual = _reportData['penyiramanManual'] ?? 0;
    final percentOtomatis = total > 0 ? (otomatis / total * 100).round() : 0;
    final percentManual = total > 0 ? (manual / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.cyan.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Analisis Penyiraman',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildIrrigationTypeCard(
                  'Otomatis',
                  otomatis,
                  percentOtomatis,
                  Colors.green,
                  Icons.settings_suggest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIrrigationTypeCard(
                  'Manual',
                  manual,
                  percentManual,
                  Colors.orange,
                  Icons.touch_app,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationTypeCard(
    String label,
    int count,
    int percent,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count kali',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$percent%',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Widget Range Sensor
  Widget _buildSensorRangeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.thermostat_outlined,
                color: Colors.green.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Range Data Sensor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_reportData['maxSuhu'] != null && _reportData['maxSuhu'] != '-')
            _buildRangeItem(
              'Suhu',
              _reportData['minSuhu'] ?? '-',
              _reportData['maxSuhu'] ?? '-',
              '°C',
              Colors.red,
              Icons.thermostat,
            ),
          const SizedBox(height: 16),
          if (_reportData['maxHumidity'] != null &&
              _reportData['maxHumidity'] != 0)
            _buildRangeItem(
              'Kelembapan Udara',
              '${_reportData['minHumidity'] ?? 0}',
              '${_reportData['maxHumidity'] ?? 0}',
              '%',
              Colors.blue,
              Icons.water,
            ),
          const SizedBox(height: 16),
          if (_reportData['maxSoil'] != null && _reportData['maxSoil'] != '-')
            _buildRangeItem(
              'Kelembapan Tanah',
              _reportData['minSoil'] ?? '-',
              _reportData['maxSoil'] ?? '-',
              'ADC',
              Colors.brown,
              Icons.grass,
            ),
        ],
      ),
    );
  }

  Widget _buildRangeItem(
    String label,
    String min,
    String max,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Min: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '$min$unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Max: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '$max$unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
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
  }

  Widget _buildRecommendationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Rekomendasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem(
            '✓ Efisiensi penyiraman baik, pertahankan pola saat ini',
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            '! Perhatikan kelembapan tanah pada siang hari',
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildRecommendationItem(
            '✓ Suhu dan kelembapan dalam rentang ideal',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // EXPORT BUTTON
  // =========================
  Widget _buildExportButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.file_download, color: Colors.white, size: 20),
      ),
      onSelected: (value) {
        if (value == 'pdf') {
          _exportToPDF();
        } else if (value == 'excel') {
          _exportToExcel();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Export PDF'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Text('Export Excel'),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // PDF HELPERS (SMARTFARM STYLE)
  // =========================
  pw.Widget _pdfCard(pw.Widget child) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: child,
    );
  }

  pw.Widget _pdfKV(String label, String value, {PdfColor? valueColor}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: valueColor ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfProgress(String label, int pct, PdfColor primary) {
    final width = 460.0; // kira-kira lebar konten A4 margin 28
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
              '$pct%',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Stack(
          children: [
            pw.Container(
              height: 8,
              width: width,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
            pw.Container(
              height: 8,
              width: width * pct / 100,
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfRangeRow(String label, String min, String max) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Row(
          children: [
            pw.Text(
              'Min: ',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              min,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              'Max: ',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              max,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================
  // EXPORT TO PDF (CUSTOM SMARTFARM)
  // =========================
  Future<void> _exportToPDF() async {
    // Validasi: pastikan ada data dan varietas
    if (_reportData.isEmpty || _activeVarietas == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada data untuk diekspor. Pilih varietas terlebih dahulu.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final pdf = pw.Document();

      final primary = PdfColor.fromInt(0xFF1B5E20);
      final bg = PdfColor.fromInt(0xFFF6FBF7);

      // Load fonts from assets with fallback
      pw.Font? fontReg;
      pw.Font? fontBold;
      try {
        fontReg = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
        );
        fontBold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
        );
      } catch (e) {
        debugPrint('Font loading failed, using default: $e');
      }

      final theme = fontReg != null && fontBold != null
          ? pw.ThemeData.withFont(base: fontReg, bold: fontBold)
          : pw.ThemeData.base();

      // Load logo with fallback
      pw.ImageProvider? logo;
      try {
        final logoBytes = (await rootBundle.load(
          'assets/images/logo.png',
        )).buffer.asUint8List();
        logo = pw.MemoryImage(logoBytes);
      } catch (e) {
        debugPrint('Logo loading failed: $e');
      }

      final periodStart = (_reportData['periodStart'] ?? '-').toString();
      final periodEnd = (_reportData['periodEnd'] ?? '-').toString();
      final varietas = (_reportData['varietas'] ?? 'default').toString();

      final totalPenyiraman = (_reportData['totalPenyiraman'] ?? 0).toString();
      final totalDurasi = (_reportData['totalDurasi'] ?? '0').toString();
      final avgSuhu = (_reportData['avgSuhu'] ?? '0').toString();
      final avgHumidity = (_reportData['avgHumidity'] ?? 0).toString();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
            theme: theme,
            buildBackground: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: bg),
            ),
          ),
          header: (_) => pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 34,
                    height: 34,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Image(logo),
                  ),
                  pw.SizedBox(width: 10),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'LAPORAN SMARTFARM',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '$periodStart - $periodEnd  •  Varietas: $varietas  •  Periode: $_selectedPeriod',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Hal ${ctx.pageNumber}/${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          build: (_) => [
            pw.SizedBox(height: 14),

            pw.Text(
              'Ringkasan',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            // Grid 2x2
            pw.Row(
              children: [
                pw.Expanded(
                  child: _pdfCard(
                    _pdfKV(
                      'Total Penyiraman',
                      '$totalPenyiraman kali',
                      valueColor: primary,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _pdfCard(
                    _pdfKV(
                      'Durasi Total',
                      '$totalDurasi jam',
                      valueColor: primary,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _pdfCard(
                    _pdfKV(
                      'Rata-rata Suhu',
                      '$avgSuhu °C',
                      valueColor: primary,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _pdfCard(
                    _pdfKV(
                      'Rata-rata Kelembapan',
                      '$avgHumidity %',
                      valueColor: primary,
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            // Statistik Detail
            pw.Text(
              'Statistik Detail',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfCard(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfDetailRow(
                    'Total Hari',
                    '${_reportData['totalDays'] ?? 0} hari',
                  ),
                  pw.SizedBox(height: 8),
                  _pdfDetailRow(
                    'Data Sensor',
                    '${_reportData['dataCount'] ?? 0} record',
                  ),
                  pw.SizedBox(height: 8),
                  _pdfDetailRow(
                    'Rata-rata/Hari',
                    '${_reportData['avgPenyiramanPerHari'] ?? '0'} kali',
                  ),
                  pw.SizedBox(height: 8),
                  _pdfDetailRow(
                    'Penggunaan Air',
                    '${_reportData['totalAirUsed'] ?? '0'} liter',
                  ),
                  if (_reportData['avgSoil'] != null &&
                      _reportData['avgSoil'] != '-') ...[
                    pw.SizedBox(height: 8),
                    _pdfDetailRow(
                      'Kelembapan Tanah',
                      '${_reportData['avgSoil']} ADC',
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Analisis Penyiraman
            pw.Text(
              'Analisis Penyiraman',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _pdfCard(
                    pw.Column(
                      children: [
                        pw.Text(
                          'Otomatis',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${_reportData['penyiramanOtomatis'] ?? 0} kali',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _pdfCard(
                    pw.Column(
                      children: [
                        pw.Text(
                          'Manual',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${_reportData['penyiramanManual'] ?? 0} kali',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            // Range Sensor
            if (_reportData['maxSuhu'] != null &&
                _reportData['maxSuhu'] != '-') ...[
              pw.Text(
                'Range Data Sensor',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _pdfCard(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfRangeRow(
                      'Suhu',
                      '${_reportData['minSuhu']}°C',
                      '${_reportData['maxSuhu']}°C',
                    ),
                    if (_reportData['maxHumidity'] != null &&
                        _reportData['maxHumidity'] != 0) ...[
                      pw.SizedBox(height: 8),
                      _pdfRangeRow(
                        'Kelembapan',
                        '${_reportData['minHumidity']}%',
                        '${_reportData['maxHumidity']}%',
                      ),
                    ],
                    if (_reportData['maxSoil'] != null &&
                        _reportData['maxSoil'] != '-') ...[
                      pw.SizedBox(height: 8),
                      _pdfRangeRow(
                        'Tanah',
                        '${_reportData['minSoil']}',
                        '${_reportData['maxSoil']}',
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            pw.Text(
              'Performa Sistem',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfCard(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfProgress('Efisiensi Penyiraman', 87, primary),
                  pw.SizedBox(height: 10),
                  _pdfProgress('Kondisi Tanaman', 92, primary),
                  pw.SizedBox(height: 10),
                  _pdfProgress('Stabilitas Sensor', 95, primary),
                ],
              ),
            ),

            // Page break sebelum rekomendasi
            pw.NewPage(),

            pw.SizedBox(height: 14),

            pw.Text(
              'Rekomendasi',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _pdfCard(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '• Efisiensi penyiraman baik, pertahankan pola saat ini',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '• Perhatikan kelembapan tanah pada siang hari',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '• Suhu dan kelembapan dalam rentang ideal',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibuat! Silakan simpan atau share.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // =========================
  // EXPORT TO EXCEL (tetap)
  // =========================
  Future<void> _exportToExcel() async {
    // Validasi: pastikan ada data dan varietas
    if (_reportData.isEmpty || _activeVarietas == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada data untuk diekspor. Pilih varietas terlebih dahulu.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Buat Excel tanpa sheet default
      var excel = ex.Excel.createExcel();

      // Buat sheet 'Laporan'
      ex.Sheet sheetObject = excel['Laporan'];

      // Hapus semua sheet lain kecuali 'Laporan'
      final sheetsToDelete = excel.tables.keys
          .where((name) => name != 'Laporan')
          .toList();
      for (var sheetName in sheetsToDelete) {
        excel.delete(sheetName);
      }

      sheetObject.appendRow([ex.TextCellValue('LAPORAN PERTANIAN CHAOS')]);
      sheetObject.appendRow([
        ex.TextCellValue(
          'Periode: ${_reportData['periodStart']} - ${_reportData['periodEnd']}',
        ),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Varietas: ${_reportData['varietas']}'),
      ]);
      sheetObject.appendRow([ex.TextCellValue('')]);

      sheetObject.appendRow([ex.TextCellValue('Ringkasan Data')]);
      sheetObject.appendRow([
        ex.TextCellValue('Metrik'),
        ex.TextCellValue('Nilai'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Total Penyiraman'),
        ex.TextCellValue('${_reportData['totalPenyiraman']} kali'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Durasi Total'),
        ex.TextCellValue('${_reportData['totalDurasi']} jam'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Rata-rata Suhu'),
        ex.TextCellValue('${_reportData['avgSuhu']}°C'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Rata-rata Kelembapan'),
        ex.TextCellValue('${_reportData['avgHumidity']}%'),
      ]);
      if (_reportData['avgSoil'] != null && _reportData['avgSoil'] != '-') {
        sheetObject.appendRow([
          ex.TextCellValue('Kelembapan Tanah'),
          ex.TextCellValue('${_reportData['avgSoil']} ADC'),
        ]);
      }
      sheetObject.appendRow([ex.TextCellValue('')]);

      sheetObject.appendRow([ex.TextCellValue('Statistik Detail')]);
      sheetObject.appendRow([
        ex.TextCellValue('Metrik'),
        ex.TextCellValue('Nilai'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Total Hari Monitoring'),
        ex.TextCellValue('${_reportData['totalDays'] ?? 0} hari'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Data Sensor Tercatat'),
        ex.TextCellValue('${_reportData['dataCount'] ?? 0} record'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Rata-rata Penyiraman/Hari'),
        ex.TextCellValue('${_reportData['avgPenyiramanPerHari'] ?? '0'} kali'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Total Penggunaan Air'),
        ex.TextCellValue('${_reportData['totalAirUsed'] ?? '0'} liter'),
      ]);
      sheetObject.appendRow([ex.TextCellValue('')]);

      sheetObject.appendRow([ex.TextCellValue('Analisis Penyiraman')]);
      sheetObject.appendRow([
        ex.TextCellValue('Tipe'),
        ex.TextCellValue('Jumlah'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Penyiraman Otomatis'),
        ex.TextCellValue('${_reportData['penyiramanOtomatis'] ?? 0} kali'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Penyiraman Manual'),
        ex.TextCellValue('${_reportData['penyiramanManual'] ?? 0} kali'),
      ]);
      sheetObject.appendRow([ex.TextCellValue('')]);

      if (_reportData['maxSuhu'] != null && _reportData['maxSuhu'] != '-') {
        sheetObject.appendRow([ex.TextCellValue('Range Data Sensor')]);
        sheetObject.appendRow([
          ex.TextCellValue('Sensor'),
          ex.TextCellValue('Min'),
          ex.TextCellValue('Max'),
        ]);
        sheetObject.appendRow([
          ex.TextCellValue('Suhu'),
          ex.TextCellValue('${_reportData['minSuhu']}°C'),
          ex.TextCellValue('${_reportData['maxSuhu']}°C'),
        ]);
        if (_reportData['maxHumidity'] != null &&
            _reportData['maxHumidity'] != 0) {
          sheetObject.appendRow([
            ex.TextCellValue('Kelembapan Udara'),
            ex.TextCellValue('${_reportData['minHumidity']}%'),
            ex.TextCellValue('${_reportData['maxHumidity']}%'),
          ]);
        }
        if (_reportData['maxSoil'] != null && _reportData['maxSoil'] != '-') {
          sheetObject.appendRow([
            ex.TextCellValue('Kelembapan Tanah'),
            ex.TextCellValue('${_reportData['minSoil']} ADC'),
            ex.TextCellValue('${_reportData['maxSoil']} ADC'),
          ]);
        }
        sheetObject.appendRow([ex.TextCellValue('')]);
      }

      sheetObject.appendRow([ex.TextCellValue('Performa Sistem')]);
      sheetObject.appendRow([
        ex.TextCellValue('Metrik'),
        ex.TextCellValue('Persentase'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Efisiensi Penyiraman'),
        ex.TextCellValue('87%'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Kondisi Tanaman'),
        ex.TextCellValue('92%'),
      ]);
      sheetObject.appendRow([
        ex.TextCellValue('Stabilitas Sensor'),
        ex.TextCellValue('95%'),
      ]);

      // Encode Excel to bytes
      final excelBytes = excel.encode();
      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      // Convert List<int> to Uint8List
      final bytes = Uint8List.fromList(excelBytes);

      // Save to Downloads directory (sama seperti PDF behavior)
      Directory directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        // Fallback to Documents if Downloads not accessible
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName =
          'Laporan SmartFarm - ${DateFormat('dd MMMM yyyy').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel tersimpan di:\nDownload/$fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
