import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/notification_badge.dart';

class WarningDetailScreen extends StatelessWidget {
  final Map<String, dynamic> warning;
  final String? notificationId;
  final double? minThreshold;
  final double? maxThreshold;
  final double? actualValue;
  final String? unit;

  const WarningDetailScreen({
    required this.warning,
    this.notificationId,
    this.minThreshold,
    this.maxThreshold,
    this.actualValue,
    this.unit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Image.asset(
            'assets/images/logo.png',
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.eco, color: Colors.white),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: [
          NotificationBadgeStream(
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 20),

            // Informasi Sensor
            _buildSensorInfoCard(),
            const SizedBox(height: 20),

            // Pesan Detail
            _buildDetailMessageCard(),
            const SizedBox(height: 20),

            // Waktu Terjadinya
            _buildTimestampCard(),
            const SizedBox(height: 20),

            // Data Sensor (jika tersedia)
            _buildSensorDataCard(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.toggle_on_outlined,
                  label: 'Kontrol',
                  index: 0,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.history,
                  label: 'Histori',
                  index: 1,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  index: 2,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  index: 3,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.person_outline,
                  label: 'Profile',
                  index: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(
          context,
        ).pushReplacementNamed('/main', arguments: {'initialIndex': index});
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final level = warning['level'] ?? 'warning';
    final isoCritical = level == 'critical';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isoCritical ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isoCritical ? Colors.red.shade300 : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isoCritical ? Icons.error_rounded : Icons.warning_amber_rounded,
            size: 40,
            color: isoCritical ? Colors.red.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isoCritical ? 'KRITIS' : 'PERINGATAN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isoCritical
                        ? Colors.red.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isoCritical
                      ? 'Kondisi sangat kritis, tindakan segera diperlukan'
                      : 'Perhatian: Kondisi mulai tidak normal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isoCritical
                        ? Colors.red.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorInfoCard() {
    final sensorType =
        warning['sensor'] ?? warning['type'] ?? 'Sensor Tidak Diketahui';
    final message = warning['message'] ?? '';

    // Icon mapping untuk sensor type
    final iconMap = {
      'suhu': Icons.thermostat_rounded,
      'kelembapan_udara': Icons.opacity_rounded,
      'kelembaban_tanah': Icons.water_rounded,
      'cahaya': Icons.light_mode_rounded,
      'ph': Icons.science_rounded,
      'nitrogen': Icons.grain_rounded,
      'phosphorus': Icons.spa_rounded,
      'potassium': Icons.local_florist_rounded,
      'ec': Icons.flash_on_rounded,
      'tds': Icons.flash_on_rounded,
    };

    final colorMap = {
      'suhu': Colors.red,
      'kelembapan_udara': Colors.blue,
      'kelembaban_tanah': Colors.brown,
      'cahaya': Colors.yellow.shade700,
      'ph': Colors.purple,
      'nitrogen': Colors.green,
      'phosphorus': Colors.green.shade700,
      'potassium': Colors.lightGreen,
      'ec': Colors.teal,
      'tds': Colors.teal,
    };

    final icon = iconMap[sensorType.toLowerCase()] ?? Icons.sensors_rounded;
    final color = colorMap[sensorType.toLowerCase()] ?? Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSensorName(sensorType),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailMessageCard() {
    final details = <String, dynamic>{};

    // Extract details dari warning
    if (warning['data'] is Map) {
      details.addAll(Map<String, dynamic>.from(warning['data']));
    } else {
      final skip = {
        'title',
        'message',
        'timestamp',
        'level',
        'sensor',
        'source',
        'type',
        'id',
      };
      warning.forEach((k, v) {
        if (!skip.contains(k)) {
          details[k] = v;
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Peringatan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Nilai Sebenarnya
          if (actualValue != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nilai Sebenarnya',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$actualValue${unit ?? ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Threshold Range
          if (minThreshold != null && maxThreshold != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batasan Minimum',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$minThreshold${unit ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Batasan Maksimum',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$maxThreshold${unit ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Additional Details
          if (details.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            ...details.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatKeyName(entry.key),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      _formatValue(entry.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTimestampCard() {
    String timeStr = '--:--';
    String dateStr = 'Tanggal tidak tersedia';

    try {
      // Format time from timestamp (matching notifikasi_screen logic)
      if (warning['timestamp'] != null) {
        final ts = warning['timestamp'];
        int millis = 0;

        if (ts is Timestamp) {
          millis = ts.toDate().millisecondsSinceEpoch;
        } else if (ts is int) {
          millis = ts < 100000000000 ? ts * 1000 : ts;
        } else if (ts is String) {
          millis = int.tryParse(ts) ?? 0;
          if (millis < 100000000000) millis *= 1000;
        }

        if (millis > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(millis);
          timeStr = DateFormat('HH:mm').format(dt);
        }
      }

      // Format date label (matching notifikasi_screen logic)
      if (warning['date'] != null && warning['date'].toString().isNotEmpty) {
        final date = warning['date'].toString();
        final dt = DateTime.parse(date);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final itemDate = DateTime(dt.year, dt.month, dt.day);

        if (itemDate == today) {
          dateStr = 'Hari Ini, $timeStr';
        } else if (itemDate == yesterday) {
          dateStr = 'Kemarin, $timeStr';
        } else {
          dateStr = '${DateFormat('d MMM', 'id_ID').format(dt)}, $timeStr';
        }
      } else {
        dateStr = timeStr;
      }
    } catch (_) {
      // Keep default values
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Waktu Terjadinya',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDataCard() {
    // Try to extract sensor values
    final sensorValues = <String, String>{};

    final tempCandidates = ['suhu', 'temperature', 'temp', 'temp_c'];
    final humCandidates = [
      'kelembapan_udara',
      'humidity',
      'hum',
      'humid_percent',
    ];
    final luxCandidates = ['intensitas_cahaya', 'lux', 'light'];
    final soilCandidates = ['kelembaban_tanah', 'soil_moisture', 'moisture'];

    _extractValue(tempCandidates, '°C', sensorValues, 'Suhu');
    _extractValue(humCandidates, '%', sensorValues, 'Kelembapan Udara');
    _extractValue(luxCandidates, 'lux', sensorValues, 'Intensitas Cahaya');
    _extractValue(soilCandidates, '%', sensorValues, 'Kelembaban Tanah');

    if (sensorValues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nilai Sensor',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...sensorValues.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _extractValue(
    List<String> candidates,
    String unit,
    Map<String, String> result,
    String displayName,
  ) {
    for (final k in candidates) {
      if (warning.containsKey(k)) {
        final value = warning[k];
        if (value != null) {
          result[displayName] = '$value$unit';
          return;
        }
      }
    }
  }

  String _formatSensorName(String sensor) {
    final nameMap = {
      'suhu': 'Suhu',
      'kelembapan_udara': 'Kelembapan Udara',
      'kelembaban_tanah': 'Kelembaban Tanah',
      'cahaya': 'Intensitas Cahaya',
      'ph': 'pH Tanah',
      'nitrogen': 'Nitrogen (N)',
      'phosphorus': 'Phosphorus (P)',
      'potassium': 'Potassium (K)',
      'ec': 'Electrical Conductivity',
      'tds': 'Total Dissolved Solids',
    };

    return nameMap[sensor.toLowerCase()] ?? sensor;
  }

  String _formatKeyName(String key) {
    final nameMap = {
      'message': 'Pesan',
      'type': 'Tipe',
      'level': 'Level',
      'sensor': 'Sensor',
      'value': 'Nilai',
      'min': 'Minimum',
      'max': 'Maksimum',
      'threshold': 'Ambang Batas',
      'status': 'Status',
    };

    return nameMap[key] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'Ya' : 'Tidak';
    if (value is num) return value.toString();
    return value.toString();
  }
}
