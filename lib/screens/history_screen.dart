import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Tab selections
  int _selectedDataType =
      0; // 0: Kelembapan Tanah, 1: Suhu Udara, 2: Intensitas Cahaya
  int _selectedTimeFilter = 0; // 0: Hari Ini, 1: Minggu Ini, 2: Bulan Ini

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  double _average = 0.0;
  double _max = 0.0;
  double _min = 0.0;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _dbRef.child('dewata_f1').get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> tempData = [];
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((dateKey, dateValue) {
          if (dateValue is Map) {
            dateValue.forEach((timeKey, timeValue) {
              if (timeValue is Map) {
                tempData.add({
                  'date': dateKey,
                  'timeKey': timeKey,
                  'kelembaban_tanah': timeValue['kelembaban_tanah'] ?? 0,
                  'suhu': timeValue['suhu'] ?? 0,
                  'intensitas_cahaya': timeValue['intensitas_cahaya'] ?? 0,
                  'kelembapan_udara': timeValue['kelembapan_udara'] ?? 0,
                  'timestamp': timeValue['timestamp'] ?? 0,
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
      return itemDate.isAfter(startDate);
    }).toList();
  }

  void _calculateStats() {
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
    return AppScaffold(
      currentIndex: 1,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header with back button
                  Container(
                    color: const Color(0xFF2D5F40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Image.asset(
                          'assets/ikon/logo.png',
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              'CHAOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

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

                  const SizedBox(height: 16),

                  // Data Type Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDataTypeTab('Kelembapan\nTanah', 0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _buildDataTypeTab('Suhu\nUdara', 1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDataTypeTab('Intensitas\nCahaya', 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Time Filter Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildTimeFilterTab('Hari Ini', 0)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTimeFilterTab('Minggu Ini', 1)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTimeFilterTab('Bulan Ini', 2)),
                      ],
                    ),
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
                          // Chart
                          SizedBox(height: 250, child: _buildChart()),

                          const SizedBox(height: 16),

                          // Statistics
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rata-rata: ${_average.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Maks: ${_max.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Min: ${_min.toStringAsFixed(0)}%',
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

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
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
              interval: 10,
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
        minY: 0,
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
            // tooltipBgColor: const Color(0xFF2D5F40),
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)}%',
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
        return 'Kelembaban (%)';
      case 1:
        return 'Suhu (%)';
      case 2:
        return 'Intensitas (%)';
      default:
        return 'Value (%)';
    }
  }

  double _getMaxYValue() {
    switch (_selectedDataType) {
      case 0:
        return 100; // Kelembaban Tanah
      case 1:
        return 50; // Suhu Udara
      case 2:
        return 400; // Intensitas Cahaya
      default:
        return 100;
    }
  }
}