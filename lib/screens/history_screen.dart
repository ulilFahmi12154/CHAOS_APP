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

  // Tab selections
  int _selectedDataType =
      0; // 0: Kelembapan Tanah, 1: Suhu Udara, 2: Intensitas Cahaya, 3: Kelembapan Udara
  int _selectedTimeFilter = 0; // 0: Hari Ini, 1: Minggu Ini, 2: Bulan Ini

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  double _average = 0.0;
  double _max = 0.0;
  double _min = 0.0;

  @override
  void initState() {
    super.initState();
    _loadActiveVarietasAndHistory();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveVarietasAndHistory() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user's active varietas
      final userSnap = await _dbRef.child('users').child(uid).get();
      String? varietasKey;
      if (userSnap.exists && userSnap.value is Map) {
        final map = userSnap.value as Map;
        varietasKey =
            (map['active_varietas'] ??
                    map['active_varieta'] ??
                    map['active_varietes'])
                as String?;
      }
      _activeVarietas = varietasKey;

      await _loadHistoryData(varietasKey);
    } catch (e) {
      print('Error loading active varietas/history: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadHistoryData(String? varietasKey) async {
    setState(() => _isLoading = true);

    try {
      // Determine history node to load based on user's active varietas.
      // Prefer smartfarm/history/<varietas>, fallback to <varietas>, and finally legacy 'dewata_f1'.
      DataSnapshot? chosen;
      if (varietasKey != null && varietasKey.isNotEmpty) {
        final primary = await _dbRef
            .child('smartfarm')
            .child('history')
            .child(varietasKey)
            .get();
        if (primary.exists) {
          chosen = primary;
        } else {
          final fallback = await _dbRef.child(varietasKey).get();
          if (fallback.exists) chosen = fallback;
        }
      }

      var snapshot = chosen;
      if (snapshot == null || !snapshot.exists) {
        // Final fallback for older data paths
        snapshot = await _dbRef
            .child('smartfarm')
            .child('history')
            .child('dewata_f1')
            .get();
        if (!snapshot.exists) {
          snapshot = await _dbRef.child('dewata_f1').get();
        }
      }

      if (snapshot.exists) {
        List<Map<String, dynamic>> tempData = [];
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((dateKey, dateValue) {
          if (dateValue is Map) {
            dateValue.forEach((timeKey, timeValue) {
              if (timeValue is Map) {
                // Normalize values: timestamps from the device may be in
                // seconds (10-digit) or milliseconds (13-digit). Also sensor
                // values may be stored as strings — coerce to numbers.
                int toMillis(dynamic ts) {
                  if (ts == null) return 0;
                  if (ts is int) {
                    // seconds -> convert to ms
                    if (ts < 100000000000) return ts * 1000;
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

                tempData.add({
                  'date': dateKey,
                  'timeKey': timeKey,
                  'kelembaban_tanah': toDouble(timeValue['kelembaban_tanah']),
                  'suhu': toDouble(timeValue['suhu']),
                  'intensitas_cahaya': toDouble(timeValue['intensitas_cahaya']),
                  'kelembapan_udara': toDouble(
                    timeValue['kelembapan_udara'] ??
                        timeValue['kelembaban_udara'],
                  ),
                  'timestamp': toMillis(timeValue['timestamp']),
                });
              }
            });
          }
        });

        // Sort by timestamp
        tempData.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        setState(() {
          _historyData = tempData;
          _calculateStats();
        });
      }
    } catch (e) {
      print('Error loading history data: $e');
    }

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFilteredData() {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_selectedTimeFilter) {
      case 0: // Hari Ini
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 1: // Minggu Ini
        startDate = now.subtract(Duration(days: 7));
        break;
      case 2: // Bulan Ini
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return _historyData.where((item) {
      int timestamp = item['timestamp'] as int;
      DateTime itemDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      // include items on or after startDate
      return !itemDate.isBefore(startDate);
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
      default:
        dataKey = 'kelembaban_tanah';
    }

    // Group data by hour for better visualization
    Map<int, List<double>> groupedByHour = {};

    for (var item in filteredData) {
      int timestamp = item['timestamp'] as int;
      DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      int hour = dateTime.hour;

      var value = item[dataKey];
      double doubleValue = (value is int)
          ? value.toDouble()
          : (value as double);

      if (!groupedByHour.containsKey(hour)) {
        groupedByHour[hour] = [];
      }
      groupedByHour[hour]!.add(doubleValue);
    }

    // Calculate average for each hour
    List<FlSpot> spots = [];
    groupedByHour.forEach((hour, values) {
      double avg = values.reduce((a, b) => a + b) / values.length;
      spots.add(FlSpot(hour.toDouble(), avg));
    });

    spots.sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Data Historis Tanaman',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D5F40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Varietas: ${_activeVarietas ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),

                const SizedBox(height: 16),

                // Data Type Grid (2 x 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.8,
                    children: [
                      _buildDataTypeTab('Kelembapan\nTanah', 0),
                      _buildDataTypeTab('Suhu\nUdara', 1),
                      _buildDataTypeTab('Intensitas\nCahaya', 2),
                      _buildDataTypeTab('Kelembapan\nUdara', 3),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Time Filter Choice Chips
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
                            height: 250,
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

  Widget _buildDataTypeTab(String text, int index) {
    bool isSelected = _selectedDataType == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDataType = index;
          _calculateStats();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterTab(String text, int index) {
    bool isSelected = _selectedTimeFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeFilter = index;
          _calculateStats();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5F40) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D5F40) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // Removed _buildDataTypeChips (replaced by 2x2 GridView)

  Widget _buildTimeFilterChips() {
    final labels = const ['Hari Ini', 'Minggu Ini', 'Bulan Ini'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        final selected = _selectedTimeFilter == i;
        return ChoiceChip(
          label: Text(
            labels[i],
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
          selected: selected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFF2D5F40),
          side: BorderSide(
            color: selected ? const Color(0xFF2D5F40) : Colors.grey.shade300,
          ),
          onSelected: (_) {
            setState(() {
              _selectedTimeFilter = i;
              _calculateStats();
            });
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
              interval: 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${value.toInt()}:00',
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
        minX: 0,
        maxX: 24,
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
      default:
        return '';
    }
  }
}
