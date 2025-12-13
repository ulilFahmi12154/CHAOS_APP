import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _activeVarietas;
  final TransformationController _zoomController = TransformationController();
  StreamSubscription<DatabaseEvent>? _historySubscription;
  StreamSubscription<DatabaseEvent>? _activeVarietasSubscription;

  // Tab selections
  int _selectedDataType =
      0; // 0: Kelembapan Tanah, 1: Suhu Udara, 2: Intensitas Cahaya, 3: Kelembapan Udara, 4: pH Tanah
  int _selectedTimeFilter = 0; // 0: Hari Ini, 1: Bulan Ini, 2: Tahun Ini

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  double _average = 0.0;
  double _max = 0.0;
  double _min = 0.0;

  // Dynamic chart axis config (updated by _getChartData)
  double _minX = 0;
  double _maxX = 24;
  double _bottomInterval = 4;

  @override
  void initState() {
    super.initState();
    _loadActiveVarietasAndHistory();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _activeVarietasSubscription?.cancel();
    _zoomController.dispose();
    super.dispose();
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
                      _selectedTimeFilter == 0
                          ? 'Hari Ini'
                          : _selectedTimeFilter == 1
                          ? 'Bulan Ini'
                          : 'Tahun Ini',
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
      // Tentukan varietas pilihan user
      final varietasKey = await _getActiveVarietas();
      _activeVarietas = varietasKey;

      // Baca dari root smartfarm/history (semua data), tapi filter di UI
      final ref = await _resolveHistoryRef(null);
      await _loadHistoryDataFromRef(ref);
      _subscribeHistory(ref);

      // Dengarkan perubahan pilihan varietas user
      _activeVarietasSubscription?.cancel();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _activeVarietasSubscription = _dbRef
            .child('users')
            .child(uid)
            .onValue
            .listen((event) {
              if (event.snapshot.value is Map) {
                final map = event.snapshot.value as Map;
                final v =
                    (map['active_varietas'] ??
                            (map['settings'] is Map
                                ? map['settings']['varietas']
                                : null))
                        ?.toString();
                if (v != null && v.isNotEmpty && v != _activeVarietas) {
                  setState(() => _activeVarietas = v);
                  _calculateStats();
                }
              }
            });
      }
    } catch (e) {
      print('Error loading active varietas/history: $e');
    }
    setState(() => _isLoading = false);
  }

  // Ambil varietas pilihan user dari users/<uid>/active_varietas atau smartfarm/active_varietas
  Future<String?> _getActiveVarietas() async {
    String? varietasKey;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSnap = await _dbRef.child('users').child(uid).get();
        if (userSnap.exists && userSnap.value is Map) {
          final map = userSnap.value as Map;
          varietasKey =
              (map['active_varietas'] ??
                      (map['settings'] is Map
                          ? map['settings']['varietas']
                          : null))
                  ?.toString();
        }
      }

      // Fallback ke smartfarm/active_varietas
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
    // Selalu gunakan root history agar menggabungkan semua varietas
    return _dbRef.child('smartfarm').child('history');
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

    // Flatten: smartfarm/history/<varietas>/<yyyy-MM-dd>/<pushId>
    data.forEach((varietasKey, varietasData) {
      if (varietasData is Map) {
        varietasData.forEach((dateKey, dateValue) {
          if (dateValue is Map) {
            dateValue.forEach((timeKey, timeValue) {
              if (timeValue is Map) {
                DateTime? dateFromKey;
                try {
                  dateFromKey = DateFormat('yyyy-MM-dd').parse(dateKey);
                } catch (_) {}

                final parsedTs = toMillis(timeValue['timestamp']);
                final effectiveTs =
                    parsedTs < DateTime(2005).millisecondsSinceEpoch &&
                        dateFromKey != null
                    ? dateFromKey.millisecondsSinceEpoch
                    : parsedTs;

                tempData.add({
                  'varietas': varietasKey.toString(),
                  'date': dateKey,
                  'timeKey': timeKey,
                  'kelembaban_tanah': toDouble(timeValue['kelembaban_tanah']),
                  'suhu': toDouble(timeValue['suhu']),
                  'intensitas_cahaya': toDouble(timeValue['intensitas_cahaya']),
                  'kelembapan_udara': toDouble(
                    timeValue['kelembapan_udara'] ??
                        timeValue['kelembaban_udara'],
                  ),
                  'ph_tanah': toDouble(timeValue['ph_tanah']),
                  'timestamp': effectiveTs,
                  'effectiveDate': dateFromKey?.millisecondsSinceEpoch,
                });
              }
            });
          }
        });
      }
    });

    tempData.sort(
      (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
    );
    setState(() {
      _historyData = tempData;
      _calculateStats();
    });
  }

  List<Map<String, dynamic>> _getFilteredData() {
    final now = DateTime.now();

    // Filter berdasarkan varietas pilihan user TERLEBIH DAHULU
    List<Map<String, dynamic>> base = _historyData;
    if (_activeVarietas != null && _activeVarietas!.isNotEmpty) {
      base = base
          .where((item) => item['varietas']?.toString() == _activeVarietas)
          .toList();
    }

    // Lalu filter berdasarkan waktu
    if (_selectedTimeFilter == 0) {
      // Hari Ini: 24 jam terakhir (lebih praktis untuk melihat data terbaru)
      final cutoff = now
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      return base.where((item) {
        final ts = item['timestamp'] as int;
        return ts >= cutoff;
      }).toList();
    }

    if (_selectedTimeFilter == 1) {
      return base.where((item) {
        final ts = item['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return dt.year == now.year && dt.month == now.month;
      }).toList();
    }
    if (_selectedTimeFilter == 2) {
      return base.where((item) {
        final ts = item['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return dt.year == now.year;
      }).toList();
    }
    return [];
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

    // Grouping disesuaikan dengan filter waktu:
    // - Hari ini -> 1 data per jam (grouping per jam)
    // - Bulan ini -> 1 data per hari (grouping per hari)
    // - Tahun ini -> tampilkan semua data
    Map<int, List<double>> buckets = {};

    // Untuk "Hari Ini", grouping per jam (1 data per jam)
    if (_selectedTimeFilter == 0) {
      // Group by hour
      for (var item in filteredData) {
        int ts = item['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        int hourKey = dt.hour; // 0..23

        final v = item[dataKey];
        final doubleValue = (v is int) ? v.toDouble() : (v as double);

        buckets.putIfAbsent(hourKey, () => []);
        buckets[hourKey]!.add(doubleValue);
      }

      // Rata-rata tiap jam -> FlSpot
      final spots = buckets.entries.map((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return FlSpot(e.key.toDouble(), avg);
      }).toList()..sort((a, b) => a.x.compareTo(b.x));

      // Update axis untuk hari ini
      _minX = 0;
      _maxX = 23;
      _bottomInterval = 4; // Tampilkan: 0, 4, 8, 12, 16, 20

      return spots;
    }

    // Untuk "Bulan Ini", grouping per hari (1 data per hari)
    if (_selectedTimeFilter == 1) {
      // Group by day
      for (var item in filteredData) {
        int ts = item['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        int dayKey = dt.day; // 1..31

        final v = item[dataKey];
        final doubleValue = (v is int) ? v.toDouble() : (v as double);

        buckets.putIfAbsent(dayKey, () => []);
        buckets[dayKey]!.add(doubleValue);
      }

      // Rata-rata tiap hari -> FlSpot
      final spots = buckets.entries.map((e) {
        final avg = e.value.reduce((a, b) => a + b) / e.value.length;
        return FlSpot(e.key.toDouble(), avg);
      }).toList()..sort((a, b) => a.x.compareTo(b.x));

      // Update axis untuk bulan ini
      _minX = 1;
      _maxX = 30;
      _bottomInterval = 6; // Tampilkan: 1, 6, 12, 18, 24, 30

      return spots;
    }

    // Untuk "Tahun Ini", grouping per bulan (1 data per bulan)
    // Group by month
    for (var item in filteredData) {
      int ts = item['timestamp'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      int monthKey = dt.month; // 1..12

      final v = item[dataKey];
      final doubleValue = (v is int) ? v.toDouble() : (v as double);

      buckets.putIfAbsent(monthKey, () => []);
      buckets[monthKey]!.add(doubleValue);
    }

    // Rata-rata tiap bulan -> FlSpot
    final spots = buckets.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return FlSpot(e.key.toDouble(), avg);
    }).toList()..sort((a, b) => a.x.compareTo(b.x));

    // Update axis untuk Tahun Ini
    _minX = 1;
    _maxX = 12;
    _bottomInterval = 1; // Tampilkan semua bulan: 1-12

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Header shape (match Kontrol style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Historis Tanaman',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilih data dan rentang waktu untuk ditampilkan',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showLaporanDialog,
                          icon: const Icon(Icons.assessment, size: 18),
                          label: const Text('Lihat Laporan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Data Type Dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2D5F40),
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedDataType,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF2D5F40),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D5F40),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Kelembapan Tanah'),
                          ),
                          DropdownMenuItem(value: 1, child: Text('Suhu Udara')),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Intensitas Cahaya'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('Kelembapan Udara'),
                          ),
                          DropdownMenuItem(value: 4, child: Text('pH Tanah')),
                        ],
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedDataType = newValue;
                              _calculateStats();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Time Filter Choice Chips (Hari Ini / Bulan Ini / Tahun Ini)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTimeFilterChips(),
                ),

                const SizedBox(height: 24),

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

  Widget _buildTimeFilterChips() {
    final labels = const ['Hari Ini', 'Bulan Ini', 'Tahun Ini'];
    return Row(
      children: List.generate(labels.length, (i) {
        final selected = _selectedTimeFilter == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 4,
              right: i == labels.length - 1 ? 0 : 4,
            ),
            child: ChoiceChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              selected: selected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF2D5F40),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF2D5F40)
                    : Colors.grey.shade300,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedTimeFilter = i;
                  _calculateStats();
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChart() {
    List<FlSpot> spots = _getChartData();

    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data untuk ditampilkan',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    // choose left axis interval depending on selected data type
    // for intensity and kelembapan tanah we use 1k steps; otherwise smaller steps
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

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: leftInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              _getYAxisLabel(),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: leftInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _bottomInterval,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _bottomTitle(value),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: _minX,
        maxX: _maxX,
        minY: minY,
        maxY: _getMaxYValue(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF10B981),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF10B981).withOpacity(0.3),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)}${_unitSuffix()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _getYAxisLabel() {
    switch (_selectedDataType) {
      case 0:
        return 'Kelembaban Tanah';
      case 1:
        return 'Suhu Udara';
      case 2:
        return 'Intensitas Cahaya';
      case 3:
        return 'Kelembapan Udara';
      case 4:
        return 'pH Tanah';
      default:
        return 'Nilai';
    }
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
      case 2:
        return ''; // Intensitas (lux) – omit unit here to keep compact
      case 1:
        return '°'; // temperature (approx)
      case 0:
      case 3:
        return '%';
      case 4:
        return ' pH'; // pH Tanah
      default:
        return '';
    }
  }

  String _bottomTitle(double x) {
    final xi = x.round();
    switch (_selectedTimeFilter) {
      case 0:
        return '$xi:00';
      case 1:
        return xi.toString();
      case 2:
        const months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        if (xi >= 1 && xi <= 12) return months[xi];
        return xi.toString();
      default:
        return xi.toString();
    }
  }
}
