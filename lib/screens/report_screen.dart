import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as ex;
import 'dart:io';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadActiveVarietas();
    _loadReportData();
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref(
        'users/${user.uid}/varietas_aktif',
      );
      final snapshot = await ref.get();
      if (snapshot.exists && mounted) {
        setState(() {
          _activeVarietas = snapshot.value.toString();
        });
      }
    }
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

      // Tentukan range waktu berdasarkan periode
      switch (_selectedPeriod) {
        case 'Hari Ini':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Minggu Ini':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'Bulan Ini':
        default:
          startDate = DateTime(now.year, now.month, 1);
          break;
      }

      // Ambil data dari Firebase
      final varietasRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/varietas_aktif',
      );
      final varietasSnapshot = await varietasRef.get();
      final varietas = varietasSnapshot.exists
          ? varietasSnapshot.value.toString()
          : 'default';

      // Ambil data sensor history
      final sensorRef = FirebaseDatabase.instance.ref('sensor_data/$varietas');
      final sensorSnapshot = await sensorRef.get();

      int totalPenyiraman = 0;
      double totalDurasi = 0;
      List<double> suhuList = [];
      List<double> humidityList = [];
      List<double> soilList = [];
      Map<String, int> dailyIrrigation = {};

      if (sensorSnapshot.exists) {
        final data = sensorSnapshot.value as Map;
        // Simulasi data untuk demo - dalam implementasi nyata, ambil dari database
        // Untuk sekarang kita generate data berdasarkan periode
        final daysDiff = now.difference(startDate).inDays + 1;

        totalPenyiraman = daysDiff * (15 + (daysDiff % 5));
        totalDurasi = totalPenyiraman * 0.35;

        // Generate data untuk grafik mingguan
        for (int i = 0; i < 7; i++) {
          final day = startDate.add(Duration(days: i));
          if (day.isBefore(now) || day.day == now.day) {
            final dayKey = DateFormat('EEE').format(day);
            dailyIrrigation[dayKey] = 10 + (i * 2) + (daysDiff % 3);
          }
        }

        // Simulasi sensor data
        for (int i = 0; i < totalPenyiraman; i++) {
          suhuList.add(24 + (i % 8) * 0.5);
          humidityList.add(60 + (i % 15) * 0.8);
          soilList.add(1400 + (i % 20) * 15.0);
        }
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
          'dailyIrrigation': dailyIrrigation,
          'periodStart': DateFormat('dd MMM yyyy').format(startDate),
          'periodEnd': DateFormat('dd MMM yyyy').format(now),
          'varietas': varietas,
        };
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading report data: $e');
      setState(() => _isLoadingData = false);
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
            // Header dengan Export Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Laporan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analisis data dan performa pertanian',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildExportButton(),
              ],
            ),

            // Period Info
            if (_reportData.isNotEmpty) ...[
              const SizedBox(height: 12),
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
            const SizedBox(height: 24),

            // Period Selector
            _buildPeriodSelector(),
            const SizedBox(height: 20),

            // Summary Cards
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

            // Performance Overview
            _buildPerformanceCard(),
            const SizedBox(height: 20),

            // Weekly Activity
            _buildWeeklyActivityCard(),
            const SizedBox(height: 20),

            // Recommendations
            _buildRecommendationsCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
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
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = period);
          _loadReportData(); // Reload data saat periode berubah
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

  // Export Button Widget
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

  // Export to PDF
  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Text(
                  'Laporan Pertanian CHAOS',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Periode: ${_reportData['periodStart']} - ${_reportData['periodEnd']}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Varietas: ${_reportData['varietas']}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),

                // Summary
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Ringkasan Data',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _buildPDFRow(
                        'Total Penyiraman',
                        '${_reportData['totalPenyiraman']} kali',
                      ),
                      _buildPDFRow(
                        'Durasi Total',
                        '${_reportData['totalDurasi']} jam',
                      ),
                      _buildPDFRow(
                        'Rata-rata Suhu',
                        '${_reportData['avgSuhu']}°C',
                      ),
                      _buildPDFRow(
                        'Rata-rata Kelembapan',
                        '${_reportData['avgHumidity']}%',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Performance
                pw.Text(
                  'Performa Sistem',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPDFRow('Efisiensi Penyiraman', '87%'),
                _buildPDFRow('Kondisi Tanaman', '92%'),
                _buildPDFRow('Stabilitas Sensor', '95%'),

                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

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

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Export to Excel
  Future<void> _exportToExcel() async {
    try {
      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Laporan'];

      // Header
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

      // Summary Data
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
      sheetObject.appendRow([ex.TextCellValue('')]);

      // Performance Data
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

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel tersimpan: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
              onPressed: () {
                // Implement open file
              },
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
