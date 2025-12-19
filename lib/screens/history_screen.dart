import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const HistoryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _activeVarietas;
  final TransformationController _zoomController = TransformationController();
  StreamSubscription<DatabaseEvent>? _historySubscription;
  StreamSubscription<DatabaseEvent>? _activeVarietasSubscription;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  final GlobalKey _sensorDropdownKey = GlobalKey();

  // Multi-lokasi
  String activeLocationId = 'lokasi_1';

  // Tab selections
  int _selectedDataType =
      0; // 0: Kelembapan Tanah, 1: Suhu Udara, 2: Intensitas Cahaya, 3: Kelembapan Udara, 4: pH Tanah
  DateTime? _startDate; // Tanggal mulai untuk range
  DateTime? _endDate; // Tanggal akhir untuk range
  String _dateFilterType = '1month'; // '1month', '1year', 'custom'

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  double _average = 0.0;
  double _max = 0.0;
  double _min = 0.0;

  // Dynamic chart axis config (updated by _getChartData)
  double _minX = 0;
  double _maxX = 24;
  double _bottomInterval = 4;

  // Chart view mode
  String _chartViewMode = 'hourly'; // 'hourly', 'daily', 'monthly'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    // Set default date range to last 1 month
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _setupLocationListener();
    _loadActiveVarietasAndHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _historySubscription?.cancel();
    _activeVarietasSubscription?.cancel();
    _locationSubscription?.cancel();
    _zoomController.dispose();
    super.dispose();
  }

  /// Setup listener untuk perubahan lokasi aktif
  void _setupLocationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _locationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final newLocationId =
                snapshot.data()?['active_location'] ?? 'lokasi_1';
            if (newLocationId != activeLocationId) {
              print('🔄 HISTORY: Location changed to $newLocationId');
              setState(() {
                activeLocationId = newLocationId;
              });
              // Reload data untuk lokasi baru
              _loadActiveVarietasAndHistory();
            }
          }
        });
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2E7D32),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
              secondary: const Color(0xFF4CAF50),
              onSecondary: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFF2E7D32),
              headerForegroundColor: Colors.white,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              rangePickerBackgroundColor: Colors.grey.shade50,
              rangeSelectionBackgroundColor: const Color(
                0xFF4CAF50,
              ).withOpacity(0.2),
              todayBorder: const BorderSide(color: Color(0xFF2E7D32), width: 2),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dateFilterType = 'custom';
        _calculateStats();
      });
    }
  }

  void _setDateFilter(String filterType) {
    setState(() {
      _dateFilterType = filterType;
      _endDate = DateTime.now();

      switch (filterType) {
        case '1month':
          _startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case '1year':
          _startDate = DateTime.now().subtract(const Duration(days: 365));
          break;
        case 'custom':
          _showDateRangePicker();
          return;
      }
      _calculateStats();
    });
  }

  Future<void> _showLaporanDialog() async {
    // Hitung rekap dari data history
    int totalDataPoints = _historyData.length;
    double avgKelembapan = 0;
    double avgSuhu = 0;
    double avgCahaya = 0;
    int countKelembapan = 0;
    int countSuhu = 0;
    int countCahaya = 0;

    for (var data in _historyData) {
      if (data['kelembapan_tanah'] != null) {
        avgKelembapan += (data['kelembapan_tanah'] as num).toDouble();
        countKelembapan++;
      }
      if (data['suhu'] != null) {
        avgSuhu += (data['suhu'] as num).toDouble();
        countSuhu++;
      }
      if (data['cahaya'] != null) {
        avgCahaya += (data['cahaya'] as num).toDouble();
        countCahaya++;
      }
    }

    if (countKelembapan > 0) avgKelembapan /= countKelembapan;
    if (countSuhu > 0) avgSuhu /= countSuhu;
    if (countCahaya > 0) avgCahaya /= countCahaya;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assessment, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Laporan Aktivitas'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rekap Data Monitoring',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildLaporanItem(
                'Total Data Points',
                '$totalDataPoints',
                Icons.data_usage,
              ),
              const Divider(height: 20),
              const Text(
                'Rata-rata Sensor:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              _buildLaporanItem(
                'Kelembapan Tanah',
                '${avgKelembapan.toStringAsFixed(1)} ADC',
                Icons.water_drop,
              ),
              _buildLaporanItem(
                'Suhu Udara',
                '${avgSuhu.toStringAsFixed(1)} °C',
                Icons.thermostat,
              ),
              _buildLaporanItem(
                'Intensitas Cahaya',
                '${avgCahaya.toStringAsFixed(0)} Lux',
                Icons.light_mode,
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Periode Data',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(_startDate ?? DateTime.now())} - ${DateFormat('dd MMM yyyy').format(_endDate ?? DateTime.now())}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _loadActiveVarietasAndHistory() async {
    setState(() => _isLoading = true);
    try {
      // Get active location first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          activeLocationId = userDoc.data()?['active_location'] ?? 'lokasi_1';
        }
      }

      print('📍 HISTORY: Loading history for location: $activeLocationId');

      // Tentukan varietas pilihan user dari lokasi aktif
      final varietasKey = await _getActiveVarietas();
      _activeVarietas = varietasKey;
      print('🌱 HISTORY: Active varietas: $_activeVarietas');

      // Baca dari smartfarm/locations/{locationId}/history
      final ref = await _resolveHistoryRef(null);
      await _loadHistoryDataFromRef(ref);
      _subscribeHistory(ref);

      // Dengarkan perubahan pilihan varietas user dari lokasi aktif (MULTI-LOKASI)
      _activeVarietasSubscription?.cancel();
      _activeVarietasSubscription = FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/active_varietas')
          .onValue
          .listen((event) {
            final newVarietas = event.snapshot.exists
                ? event.snapshot.value?.toString()
                : null;

            if (mounted) {
              setState(() {
                _activeVarietas = newVarietas;
              });
              if (newVarietas != null && newVarietas.isNotEmpty) {
                _calculateStats();
              }
            }
          });
    } catch (e) {
      print('Error loading active varietas/history: $e');
    }
    setState(() => _isLoading = false);
  }

  // Ambil varietas pilihan user dari lokasi aktif (MULTI-LOKASI)
  Future<String?> _getActiveVarietas() async {
    String? varietasKey;
    try {
      // MULTI-LOKASI: Baca dari lokasi aktif
      final activeVarietasSnap = await _dbRef
          .child('smartfarm/locations/$activeLocationId/active_varietas')
          .get();

      if (activeVarietasSnap.exists && activeVarietasSnap.value != null) {
        varietasKey = activeVarietasSnap.value.toString();
      }

      // Fallback ke smartfarm/active_varietas (global)
      if (varietasKey == null || varietasKey.isEmpty) {
        final global = await _dbRef
            .child('smartfarm')
            .child('active_varietas')
            .get();
        if (global.exists && global.value != null) {
          varietasKey = global.value.toString();
        }
      }

      // Fallback terakhir: varietas pertama di history
      if (varietasKey == null || varietasKey.isEmpty) {
        final histRoot = await _dbRef.child('smartfarm').child('history').get();
        if (histRoot.exists) {
          for (final child in histRoot.children) {
            varietasKey = child.key;
            break;
          }
        }
      }
    } catch (_) {}
    return varietasKey;
  }

  Future<DatabaseReference> _resolveHistoryRef(String? varietasKey) async {
    // Baca history dari lokasi aktif: smartfarm/locations/{locationId}/history
    return _dbRef
        .child('smartfarm')
        .child('locations')
        .child(activeLocationId)
        .child('history');
  }

  Future<void> _loadHistoryDataFromRef(DatabaseReference ref) async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await ref.get();
      _applyHistorySnapshot(snapshot.value);
    } catch (e) {
      print('Error loading history data: $e');
    }
    setState(() => _isLoading = false);
  }

  void _subscribeHistory(DatabaseReference ref) {
    _historySubscription?.cancel();
    _historySubscription = ref.onValue.listen((event) {
      _applyHistorySnapshot(event.snapshot.value);
    });
  }

  void _applyHistorySnapshot(dynamic rawValue) {
    if (rawValue == null || rawValue is! Map) {
      setState(() {
        _historyData = [];
        _calculateStats();
      });
      return;
    }
    Map<dynamic, dynamic> data = rawValue;
    List<Map<String, dynamic>> tempData = [];

    print('📊 HISTORY DATA STRUCTURE:');
    print('Top level keys: ${data.keys.toList()}');
    if (data.isNotEmpty) {
      final firstKey = data.keys.first;
      print('First key: $firstKey');
      if (data[firstKey] is Map) {
        print('Second level keys: ${(data[firstKey] as Map).keys.toList()}');
      }
    }

    int toMillis(dynamic ts) {
      if (ts == null) return 0;
      if (ts is int) {
        if (ts < 100000000000) return ts * 1000; // seconds -> ms
        return ts;
      }
      if (ts is String) {
        final parsed = int.tryParse(ts);
        if (parsed != null) {
          if (parsed < 100000000000) return parsed * 1000;
          return parsed;
        }
      }
      if (ts is double) {
        final asInt = ts.toInt();
        if (asInt < 100000000000) return asInt * 1000;
        return asInt;
      }
      return 0;
    }

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // Flatten: smartfarm/locations/{locationId}/history/<crv_name>/<yyyy-MM-dd>/<recordId>
    // Struktur: history/{crv_xxx}/{2025-12-18}/{recordId}/{ec, intensitas_cahaya, kelembaban_tanah, ...}
    int recordCount = 0;
    data.forEach((crvKey, crvData) {
      if (crvData is Map) {
        crvData.forEach((dateKey, dateValue) {
          if (dateValue is Map) {
            dateValue.forEach((recordKey, recordValue) {
              if (recordValue is Map) {
                recordCount++;
                DateTime? dateFromKey;
                try {
                  dateFromKey = DateFormat('yyyy-MM-dd').parse(dateKey);
                } catch (e) {
                  print('⚠️ Error parsing date $dateKey: $e');
                }

                final parsedTs = toMillis(recordValue['timestamp']);
                final effectiveTs =
                    parsedTs < DateTime(2005).millisecondsSinceEpoch &&
                        dateFromKey != null
                    ? dateFromKey.millisecondsSinceEpoch
                    : parsedTs;

                // Extract potassium as number (ignore if it's "ON" or invalid)
                dynamic potassiumValue = recordValue['potassium'];
                double potassiumDouble = 0.0;
                if (potassiumValue != null && potassiumValue != 'ON') {
                  potassiumDouble = toDouble(potassiumValue);
                }

                tempData.add({
                  'varietas': crvKey.toString(),
                  'date': dateKey,
                  'timeKey': recordKey,
                  'kelembaban_tanah': toDouble(recordValue['kelembaban_tanah']),
                  'suhu': toDouble(recordValue['suhu']),
                  'intensitas_cahaya': toDouble(
                    recordValue['intensitas_cahaya'],
                  ),
                  'kelembapan_udara': toDouble(
                    recordValue['kelembapan_udara'] ??
                        recordValue['kelembaban_udara'],
                  ),
                  'ph_tanah': toDouble(recordValue['ph_tanah']),
                  'ec': toDouble(recordValue['ec']),
                  'nitrogen': toDouble(recordValue['nitrogen']),
                  'phosphorus': toDouble(recordValue['phosphorus']),
                  'potassium': potassiumDouble,
                  'timestamp': effectiveTs,
                  'effectiveDate': dateFromKey?.millisecondsSinceEpoch,
                });
              }
            });
          }
        });
      }
    });
    print(
      '✅ Parsed $recordCount history records from location: $activeLocationId',
    );

    tempData.sort(
      (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
    );
    setState(() {
      _historyData = tempData;
      _calculateStats();
    });
  }

  List<Map<String, dynamic>> _getFilteredData() {
    // Filter hanya untuk varietas yang dipilih user
    List<Map<String, dynamic>> base = _historyData;
    if (_activeVarietas != null && _activeVarietas!.isNotEmpty) {
      base = base
          .where((item) => item['varietas']?.toString() == _activeVarietas)
          .toList();
    }

    // Jika belum ada date range, set default
    if (_startDate == null || _endDate == null) {
      _endDate = DateTime.now();
      _startDate = DateTime.now().subtract(const Duration(days: 30));
    }

    // Filter data untuk range tanggal yang dipilih
    final startOfRange = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      0,
      0,
      0,
    ).millisecondsSinceEpoch;

    final endOfRange = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    return base.where((item) {
      final ts = item['timestamp'] as int;
      return ts >= startOfRange && ts <= endOfRange;
    }).toList();
  }

  void _calculateStats() {
    // Calculate stats based on the same values used by the chart.
    // The chart groups points by hour and plots hourly averages; to keep
    // statistics consistent with the visual, compute average/max/min from
    // those hourly-averaged values. If no chart points exist, fall back to
    // raw filtered data.
    final spots = _getChartData();

    if (spots.isNotEmpty) {
      List<double> values = spots.map((s) => s.y).toList();
      setState(() {
        _average = values.reduce((a, b) => a + b) / values.length;
        _max = values.reduce((a, b) => a > b ? a : b);
        _min = values.reduce((a, b) => a < b ? a : b);
      });
      return;
    }

    // Fallback: use raw filtered samples (if any)
    List<Map<String, dynamic>> filteredData = _getFilteredData();
    if (filteredData.isEmpty) {
      setState(() {
        _average = 0.0;
        _max = 0.0;
        _min = 0.0;
      });
      return;
    }

    String dataKey;
    switch (_selectedDataType) {
      case 0:
        dataKey = 'kelembaban_tanah';
        break;
      case 1:
        dataKey = 'suhu';
        break;
      case 2:
        dataKey = 'intensitas_cahaya';
        break;
      case 3:
        dataKey = 'kelembapan_udara';
        break;
      case 4:
        dataKey = 'ph_tanah';
        break;
      case 5:
        dataKey = 'ec';
        break;
      case 6:
        dataKey = 'nitrogen';
        break;
      case 7:
        dataKey = 'phosphorus';
        break;
      case 8:
        dataKey = 'potassium';
        break;
      default:
        dataKey = 'kelembaban_tanah';
    }

    List<double> values = filteredData.map((item) {
      var value = item[dataKey];
      return (value is int) ? value.toDouble() : (value as double);
    }).toList();

    if (values.isNotEmpty) {
      setState(() {
        _average = values.reduce((a, b) => a + b) / values.length;
        _max = values.reduce((a, b) => a > b ? a : b);
        _min = values.reduce((a, b) => a < b ? a : b);
      });
    }
  }

  List<FlSpot> _getChartData() {
    List<Map<String, dynamic>> filteredData = _getFilteredData();

    if (filteredData.isEmpty) return [];

    String dataKey;
    switch (_selectedDataType) {
      case 0:
        dataKey = 'kelembaban_tanah';
        break;
      case 1:
        dataKey = 'suhu';
        break;
      case 2:
        dataKey = 'intensitas_cahaya';
        break;
      case 3:
        dataKey = 'kelembapan_udara';
        break;
      case 4:
        dataKey = 'ph_tanah';
        break;
      default:
        dataKey = 'kelembaban_tanah';
    }

    // Determine view mode based on date range
    if (_startDate == null || _endDate == null) {
      return [];
    }

    final daysDifference = _endDate!.difference(_startDate!).inDays;

    // Single Day View (0 days difference means same day)
    if (daysDifference == 0) {
      return _getHourlyChartData(filteredData, dataKey);
    }
    // Month/Multi-day View (1-90 days)
    else if (daysDifference <= 90) {
      return _getDailyChartData(filteredData, dataKey);
    }
    // Year View (> 90 days)
    else {
      return _getMonthlyChartData(filteredData, dataKey);
    }
  }

  List<FlSpot> _getHourlyChartData(
    List<Map<String, dynamic>> data,
    String dataKey,
  ) {
    _chartViewMode = 'hourly';

    // Return ALL raw data points without aggregation for same-day view
    List<FlSpot> spots = [];

    for (var item in data) {
      final value = item[dataKey];
      if (value == null) continue;

      final doubleValue = (value is int) ? value.toDouble() : (value as double);
      final timestamp = item['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Use hour + minute as decimal (e.g., 14:30 = 14.5)
      final x = dateTime.hour + (dateTime.minute / 60.0);
      spots.add(FlSpot(x, doubleValue));
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    // Configure axis for hourly view - adjust to actual data range
    if (spots.isNotEmpty) {
      final minHour = spots.first.x.floor().toDouble();
      final maxHour = spots.last.x.ceil().toDouble();

      // Add padding to make graph more readable
      _minX = (minHour - 1).clamp(0, 23);
      _maxX = (maxHour + 1).clamp(_minX + 1, 23);

      // Adjust interval based on range
      final range = _maxX - _minX;
      if (range <= 6) {
        _bottomInterval = 1; // Show every hour
      } else if (range <= 12) {
        _bottomInterval = 2; // Show every 2 hours
      } else {
        _bottomInterval = 4; // Show every 4 hours
      }
    } else {
      // Default if no data
      _minX = 0;
      _maxX = 23;
      _bottomInterval = 4;
    }

    return spots;
  }

  List<FlSpot> _getDailyChartData(
    List<Map<String, dynamic>> data,
    String dataKey,
  ) {
    _chartViewMode = 'daily';

    // Group by day
    Map<String, List<double>> dailyGroups = {};

    for (var item in data) {
      final value = item[dataKey];
      if (value == null) continue;

      final doubleValue = (value is int) ? value.toDouble() : (value as double);
      final timestamp = item['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dayKey =
          '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

      dailyGroups.putIfAbsent(dayKey, () => []);
      dailyGroups[dayKey]!.add(doubleValue);
    }

    // Calculate average for each day and create spots
    List<FlSpot> spots = [];
    dailyGroups.forEach((dayKey, values) {
      final avg = values.reduce((a, b) => a + b) / values.length;
      final date = DateTime.parse(dayKey);
      // Use day of month as x value (1-31)
      spots.add(FlSpot(date.day.toDouble(), avg));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));

    // Configure axis for daily view - adjust to actual data range
    if (spots.isNotEmpty) {
      final minDay = spots.first.x.floor().toDouble();
      final maxDay = spots.last.x.ceil().toDouble();

      // Add padding
      _minX = (minDay - 1).clamp(1, 31);
      _maxX = (maxDay + 1).clamp(_minX + 1, 31);

      // Adjust interval based on range
      final range = _maxX - _minX;
      if (range <= 7) {
        _bottomInterval = 1; // Show every day
      } else if (range <= 14) {
        _bottomInterval = 2; // Show every 2 days
      } else if (range <= 21) {
        _bottomInterval = 3; // Show every 3 days
      } else {
        _bottomInterval = 5; // Show every 5 days
      }
    } else {
      // Default if no data
      _minX = 1;
      _maxX = 31;
      _bottomInterval = 7;
    }

    return spots;
  }

  List<FlSpot> _getMonthlyChartData(
    List<Map<String, dynamic>> data,
    String dataKey,
  ) {
    _chartViewMode = 'monthly';

    // Group by month
    Map<int, List<double>> monthlyGroups = {};

    for (var item in data) {
      final value = item[dataKey];
      if (value == null) continue;

      final doubleValue = (value is int) ? value.toDouble() : (value as double);
      final timestamp = item['timestamp'] as int;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final month = dateTime.month; // 1-12

      monthlyGroups.putIfAbsent(month, () => []);
      monthlyGroups[month]!.add(doubleValue);
    }

    // Calculate average for each month
    List<FlSpot> spots = [];
    monthlyGroups.forEach((month, values) {
      final avg = values.reduce((a, b) => a + b) / values.length;
      spots.add(FlSpot(month.toDouble(), avg));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));

    // Configure axis for monthly view - adjust to actual data range
    if (spots.isNotEmpty) {
      final minMonth = spots.first.x.floor().toDouble();
      final maxMonth = spots.last.x.ceil().toDouble();

      _minX = minMonth;
      _maxX = maxMonth;

      // Adjust interval based on range
      final range = _maxX - _minX + 1;
      if (range <= 3) {
        _bottomInterval = 1; // Show every month
      } else if (range <= 6) {
        _bottomInterval = 1; // Show every month
      } else {
        _bottomInterval = 2; // Show every 2 months
      }
    } else {
      // Default if no data
      _minX = 1;
      _maxX = 12;
      _bottomInterval = 1;
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            // Elegant Header Section
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                      Icons.history,
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
                          'Riwayat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Data sensor & jadwal pemupukan',
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
                      Icons.auto_graph,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Custom Tab Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
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
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 20),
                          SizedBox(width: 8),
                          Text('Data Sensor'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 20),
                          SizedBox(width: 8),
                          Text('Jadwal Pupuk'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSensorHistoryTab(),
                  _buildFertilizerScheduleTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorHistoryTab() {
    // Check if varietas is empty or null
    if (!_isLoading && (_activeVarietas == null || _activeVarietas!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum Ada Varietas Yang Dipilih',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan pilih varietas terlebih dahulu\ndi halaman Pengaturan untuk melihat\nriwayat data sensor',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                icon: const Icon(Icons.settings, size: 20),
                label: const Text('Pergi ke Pengaturan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Data Type Dropdown - Modern Design
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sensors,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pilih Sensor',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          key: _sensorDropdownKey,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          onTap: () async {
                            final selected = await _showSensorMenu(context);
                            if (selected != null) {
                              setState(() {
                                _selectedDataType = selected;
                                _calculateStats();
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getSensorColor(
                                _selectedDataType,
                              ).withOpacity(0.08),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getSensorColor(
                                      _selectedDataType,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getSensorIcon(_selectedDataType),
                                    color: _getSensorColor(_selectedDataType),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getSensorLabel(_selectedDataType),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Filter Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickFilterButton('1 Bulan', '1month'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickFilterButton('1 Tahun', '1year'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickFilterButton('Custom', 'custom'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Date Range Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDateRangeDisplay(),
                ),

                const SizedBox(height: 16),

                // Chart Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Chart (clipped and zoomable via InteractiveViewer)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            height: 400,
                            child: InteractiveViewer(
                              transformationController: _zoomController,
                              minScale: 1.0,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(24),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: _buildChart(),
                              ),
                            ),
                          ),
                        ),

                        // Reset zoom button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                _zoomController.value = Matrix4.identity(),
                            icon: const Icon(Icons.zoom_out_map, size: 16),
                            label: const Text('Reset Zoom'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              foregroundColor: const Color(0xFF2D5F40),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Statistics row (average, max, min)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rata-rata: ${_average.toStringAsFixed(0)}${_unitSuffix()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Maks: ${_max.toStringAsFixed(0)}${_unitSuffix()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Min: ${_min.toStringAsFixed(0)}${_unitSuffix()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          );
  }

  Widget _buildQuickFilterButton(String label, String filterType) {
    final isActive = _dateFilterType == filterType;
    return InkWell(
      onTap: () => _setDateFilter(filterType),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeDisplay() {
    if (_startDate == null || _endDate == null) return const SizedBox.shrink();

    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.date_range,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periode Data',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    List<FlSpot> spots = _getChartData();

    if (spots.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text(
          'Tidak ada data untuk rentang tanggal ini',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // choose left axis interval depending on selected data type
    double leftInterval;
    if (_selectedDataType == 2 || _selectedDataType == 0) {
      leftInterval = 1000;
    } else if (_selectedDataType == 3) {
      leftInterval = 10;
    } else if (_selectedDataType == 4) {
      leftInterval = 4; // pH: 0,4,8,12
    } else {
      leftInterval = 10;
    }
    double minY = 0;

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minX: _minX,
          maxX: _maxX,
          minY: minY,
          maxY: _getMaxYValue(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: leftInterval,
            verticalInterval: _bottomInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: _bottomInterval,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _bottomTitle(value),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: leftInterval,
                reservedSize: 55,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _getSensorColor(_selectedDataType),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show:
                    spots.length <= 50, // Show dots only if not too many points
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: _getSensorColor(_selectedDataType),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    _getSensorColor(_selectedDataType).withOpacity(0.3),
                    _getSensorColor(_selectedDataType).withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.black87,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  String label = '';
                  switch (_chartViewMode) {
                    case 'hourly':
                      label = _bottomTitle(touchedSpot.x);
                      break;
                    case 'daily':
                      label = 'Day ${touchedSpot.x.toInt()}';
                      break;
                    case 'monthly':
                      label = _bottomTitle(touchedSpot.x);
                      break;
                  }

                  return LineTooltipItem(
                    '$label\n${touchedSpot.y.toStringAsFixed(1)}${_unitSuffix()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  double _getMaxYValue() {
    // For intensity, use fixed axis 0..10000 with steps of 1000
    if (_selectedDataType == 2) {
      return 10000;
    }

    // For kelembapan tanah use 0..5000 with steps of 1000
    if (_selectedDataType == 0) {
      return 5000;
    }

    // For kelembapan udara, 0..100
    if (_selectedDataType == 3) {
      return 100;
    }

    // For pH Tanah, 0..20
    if (_selectedDataType == 4) {
      return 20;
    }

    // Default fixed ranges for other data types
    switch (_selectedDataType) {
      case 1:
        return 50; // Suhu Udara
      default:
        return 100;
    }
  }

  String _unitSuffix() {
    // Provide unit suffix for stats/tooltip as needed
    switch (_selectedDataType) {
      case 0:
        return ''; // Kelembaban tanah (raw value)
      case 1:
        return '°C'; // Suhu
      case 2:
        return ' Lux'; // Intensitas cahaya
      case 3:
        return '%'; // Kelembapan udara
      case 4:
        return ''; // pH tanah
      default:
        return '';
    }
  }

  String _bottomTitle(double x) {
    final xi = x.round();

    switch (_chartViewMode) {
      case 'hourly':
        // Format as time (00:00, 04:00, etc.)
        return '${xi.toString().padLeft(2, '0')}:00';

      case 'daily':
        // Format as day number
        return xi.toString();

      case 'monthly':
        // Format as month number
        return xi.toString();

      default:
        return xi.toString();
    }
  }

  String _bottomSubtitle(double x) {
    final xi = x.round();

    if (_chartViewMode == 'monthly') {
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      if (xi >= 1 && xi <= 12) {
        return monthNames[xi - 1];
      }
    }
    return '';
  }

  Future<int?> _showSensorMenu(BuildContext context) async {
    final RenderBox button =
        _sensorDropdownKey.currentContext!.findRenderObject() as RenderBox;
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
      buttonTopLeft.dx,
      buttonBottomLeft.dy + 4,
      overlay.size.width - buttonTopLeft.dx - button.size.width,
      overlay.size.height - buttonBottomLeft.dy - 4,
    );

    // Data sensor options
    final List<Map<String, dynamic>> sensorOptions = [
      {
        'value': 0,
        'icon': Icons.water_drop,
        'color': Colors.brown,
        'label': 'Kelembapan Tanah',
      },
      {
        'value': 1,
        'icon': Icons.thermostat,
        'color': Colors.orange,
        'label': 'Suhu Udara',
      },
      {
        'value': 2,
        'icon': Icons.wb_sunny,
        'color': Colors.yellow.shade700,
        'label': 'Intensitas Cahaya',
      },
      {
        'value': 3,
        'icon': Icons.air,
        'color': Colors.blue,
        'label': 'Kelembapan Udara',
      },
      {
        'value': 4,
        'icon': Icons.science,
        'color': Colors.purple,
        'label': 'pH Tanah',
      },
    ];

    final result = await showMenu<int>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      constraints: BoxConstraints(
        minWidth: button.size.width,
        maxWidth: button.size.width,
      ),
      items: sensorOptions.map((sensor) {
        final bool isSelected = sensor['value'] == _selectedDataType;
        return PopupMenuItem<int>(
          value: sensor['value'],
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (sensor['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    sensor['icon'],
                    color: isSelected
                        ? Colors.green.shade700
                        : (sensor['color'] as Color).withOpacity(0.8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sensor['label'],
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

  IconData _getSensorIcon(int type) {
    switch (type) {
      case 0:
        return Icons.water_drop;
      case 1:
        return Icons.thermostat;
      case 2:
        return Icons.wb_sunny;
      case 3:
        return Icons.air;
      case 4:
        return Icons.science;
      default:
        return Icons.water_drop;
    }
  }

  Color _getSensorColor(int type) {
    switch (type) {
      case 0:
        return Colors.brown;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.yellow.shade700;
      case 3:
        return Colors.blue;
      case 4:
        return Colors.purple;
      default:
        return Colors.brown;
    }
  }

  String _getSensorLabel(int type) {
    switch (type) {
      case 0:
        return 'Kelembapan Tanah';
      case 1:
        return 'Suhu Udara';
      case 2:
        return 'Intensitas Cahaya';
      case 3:
        return 'Kelembapan Udara';
      case 4:
        return 'pH Tanah';
      default:
        return 'Kelembapan Tanah';
    }
  }

  Widget _buildSelectedItem(
    int value,
    IconData icon,
    Color color,
    String label,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color.withOpacity(0.8), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // Tab Jadwal Pupuk
  Widget _buildFertilizerScheduleTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login'));
    }

    // Check if varietas is empty or null first
    if (_activeVarietas == null || _activeVarietas!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum Ada Varietas Yang Dipilih',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Silakan pilih varietas terlebih dahulu\ndi halaman Pengaturan untuk melihat\njadwal pemupukan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                icon: const Icon(Icons.settings, size: 20),
                label: const Text('Pergi ke Pengaturan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // MULTI-LOKASI: Load waktu tanam dari lokasi aktif
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('smartfarm/locations/$activeLocationId/waktu_tanam')
          .onValue
          .asBroadcastStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Belum ada data tanam'));
        }

        final waktuTanam = snapshot.data!.snapshot.value as int?;

        if (waktuTanam == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada waktu tanam',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Atur waktu tanam di Pengaturan',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final tanamDate = DateTime.fromMillisecondsSinceEpoch(waktuTanam);
        final umurHari = DateTime.now().difference(tanamDate).inDays + 1;

        // Jadwal pupuk lengkap
        final allTasks = [
          // FASE VEGETATIF (Hari 1-30)
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

          // FASE GENERATIF (Hari 31-60)
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

          // FASE PEMBUNGAAN (Hari 61-70)
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

          // FASE PEMBUAHAN (Hari 71-90)
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

          // FASE SIAP PANEN (Hari 90+)
          {'hari': 92, 'task': 'Panen Perdana', 'type': 'Panen', 'icon': '🎉'},
          {
            'hari': 95,
            'task': 'NPK Pemeliharaan 10-10-10',
            'type': 'Panen',
            'icon': '🎉',
          },
          {'hari': 100, 'task': 'Panen Berkala', 'type': 'Panen', 'icon': '🎉'},
        ];

        // Pisahkan completed dan upcoming
        final completedTasks = allTasks
            .where((task) => umurHari > (task['hari'] as int))
            .toList();

        final upcomingTasks = allTasks
            .where((task) => umurHari <= (task['hari'] as int))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card - Compact
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
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
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$umurHari',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Hari',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ditanam ${tanamDate.day}/${tanamDate.month}/${tanamDate.year}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Upcoming Tasks Section
              if (upcomingTasks.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Jadwal Mendatang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${upcomingTasks.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...upcomingTasks.map(
                  (task) => _buildFertilizerTaskCard(
                    task,
                    umurHari,
                    isCompleted: false,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Completed Tasks Section
              if (completedTasks.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Riwayat Terlaksana',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${completedTasks.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...completedTasks.reversed.map(
                  (task) => _buildFertilizerTaskCard(
                    task,
                    umurHari,
                    isCompleted: true,
                  ),
                ),
              ],

              if (completedTasks.isEmpty && upcomingTasks.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Belum ada jadwal pemupukan',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
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

  Widget _buildFertilizerTaskCard(
    Map<String, dynamic> task,
    int umurHari, {
    required bool isCompleted,
  }) {
    final hari = task['hari'] as int;
    final taskName = task['task'] as String;
    final taskType = task['type'] as String;
    final taskIcon = task['icon'] as String;
    final daysLeft = hari - umurHari;

    // Warna untuk completed vs upcoming
    Color badgeColor;
    if (isCompleted) {
      badgeColor = Colors.grey.shade500;
    } else {
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

      if (daysLeft <= 3) badgeColor = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.grey.shade300 : Colors.transparent,
        ),
        boxShadow: isCompleted
            ? []
            : [
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(isCompleted ? 0.3 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCompleted) ...[
                  Icon(Icons.check_circle, color: badgeColor, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 10,
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Text(
                    '${daysLeft > 0 ? daysLeft : 0}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                  Text(
                    'days',
                    style: TextStyle(fontSize: 10, color: badgeColor),
                  ),
                ],
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
                      style: TextStyle(
                        fontSize: 18,
                        color: isCompleted ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        taskName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? Colors.grey.shade700
                              : Colors.black,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
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
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
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
                        color: isCompleted
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
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
}
