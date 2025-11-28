import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'package:chaos_app/screens/warning_detail_screen.dart';

Widget _buildSimpleNotifCard({
  required String title,
  required String message,
  required String timeStr,
  required Color statusColor,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 8, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  late Stream<List<Map<String, dynamic>>> _warningStream;

  @override
  void initState() {
    super.initState();
    _warningStream = _getWarningsFromRealtimeDB();
  }

  /// Ambil warning dari Realtime Database (bukan Firestore)
  Stream<List<Map<String, dynamic>>> _getWarningsFromRealtimeDB() {
    final db = FirebaseDatabase.instance.ref();

    // Ambil hari ini
    final now = DateTime.now();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Path: smartfarm/warning/{varietas}/{tanggal}
    // Ambil dari semua varietas (monitor semua)
    final basePath = 'smartfarm/warning';

    return db.child(basePath).onValue.map((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> allWarnings = [];

      if (data is Map) {
        // data = {varietas1: {tanggal: {suhu: {...}, ...}}, varietas2: {...}}
        data.forEach((varietasKey, varietasData) {
          if (varietasData is Map) {
            // varietasData = {2025-11-28: {suhu: {push1: {...}, ...}, ...}, ...}
            varietasData.forEach((dateKey, dateData) {
              if (dateKey.toString() == dateStr && dateData is Map) {
                // dateData = {suhu: {push1: {...}, push2: {...}}, tanah: {...}, ...}
                dateData.forEach((sensorType, sensorData) {
                  if (sensorData is Map) {
                    // sensorData = {push1: {...}, push2: {...}}
                    sensorData.forEach((pushKey, warningData) {
                      if (warningData is Map) {
                        final warning = Map<String, dynamic>.from(warningData);
                        warning['sensor'] = sensorType.toString();
                        warning['varietas'] = varietasKey.toString();
                        warning['sensorType'] = sensorType.toString();
                        allWarnings.add(warning);
                      }
                    });
                  }
                });
              }
            });
          }
        });
      }

      // Sort by timestamp descending (terbaru dulu)
      allWarnings.sort((a, b) {
        final timeA = a['timestamp'] ?? 0;
        final timeB = b['timestamp'] ?? 0;
        return timeB.compareTo(timeA);
      });

      // Ambil hanya 20 warning terbaru
      if (allWarnings.length > 20) {
        allWarnings = allWarnings.sublist(0, 20);
      }

      return allWarnings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: -1,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              'Notifikasi Peringatan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 12, 51, 13),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _warningStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final warnings = snapshot.data ?? [];
                if (warnings.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 48,
                              color: Colors.green,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tidak ada peringatan hari ini',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Group by varietas
                final Map<String, List<Map<String, dynamic>>> groups = {};
                for (final warning in warnings) {
                  final varietas = warning['varietas'] ?? 'Unknown';
                  groups.putIfAbsent(varietas, () => []).add(warning);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  itemBuilder: (context, sectionIndex) {
                    final varietas = groups.keys.toList()[sectionIndex];
                    final items = groups[varietas] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Varietas: $varietas',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...items.map((warning) {
                          final sensorType = (warning['sensor'] ?? '')
                              .toString()
                              .toUpperCase();
                          final message = warning['message'] ?? '';
                          final level = warning['level'] ?? 'warning';
                          final timeStr = _formatTimestamp(
                            warning['timestamp'],
                          );

                          final statusColor = level == 'critical'
                              ? Colors.red
                              : Colors.orange;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildSimpleNotifCard(
                              title: sensorType,
                              message: message,
                              timeStr: timeStr,
                              statusColor: statusColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WarningDetailScreen(warning: warning),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return '--:--';

      int millis = 0;
      if (timestamp is int) {
        millis = timestamp < 100000000000 ? timestamp * 1000 : timestamp;
      } else if (timestamp is String) {
        millis = int.tryParse(timestamp) ?? 0;
        if (millis < 100000000000) millis *= 1000;
      }

      if (millis == 0) return '--:--';

      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '--:--';
    }
  }
}
