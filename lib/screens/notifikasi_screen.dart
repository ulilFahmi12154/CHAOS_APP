import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';

// Helper: fetch the closest history record from the Realtime Database for a given timestamp (ms)
// This helper can accept an optional cachedRecords list to avoid re-reading
// the whole history for each notification. If `cachedRecords` is provided
// it will use that list; otherwise it will read the DB once.
Future<Map<String, dynamic>?> _getClosestHistoryRecord(
  int targetMillis, {
  List<Map<String, dynamic>>? cachedRecords,
}) async {
  try {
    List<Map<String, dynamic>> records = [];

    int toMillis(dynamic ts) {
      if (ts == null) return 0;
      if (ts is int) {
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

    if (cachedRecords != null) {
      records = cachedRecords;
    } else {
      final db = FirebaseDatabase.instance.ref();
      DatabaseEvent snap = await db.child('dewata_f1').once();
      if (!snap.snapshot.exists) {
        snap = await db
            .child('smartfarm')
            .child('history')
            .child('dewata_f1')
            .once();
        if (!snap.snapshot.exists) return null;
      }

      final Map<dynamic, dynamic>? root =
          snap.snapshot.value as Map<dynamic, dynamic>?;
      if (root == null) return null;

      root.forEach((dateKey, dateValue) {
        if (dateValue is Map) {
          dateValue.forEach((timeKey, timeValue) {
            if (timeValue is Map) {
              final ts = toMillis(timeValue['timestamp']);
              records.add({
                'date': dateKey,
                'timeKey': timeKey,
                'kelembaban_tanah': toDouble(timeValue['kelembaban_tanah']),
                'suhu': toDouble(timeValue['suhu']),
                'intensitas_cahaya': toDouble(timeValue['intensitas_cahaya']),
                'kelembapan_udara': toDouble(
                  timeValue['kelembapan_udara'] ??
                      timeValue['kelembaban_udara'],
                ),
                'timestamp': ts,
              });
            }
          });
        }
      });
    }

    if (records.isEmpty) return null;

    records.sort(
      (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
    );

    Map<String, dynamic>? best;
    int bestDiff = 1 << 62;
    for (final r in records) {
      final int t = r['timestamp'] as int;
      final diff = (t - targetMillis).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = r.cast<String, dynamic>();
      }
    }

    if (best != null && bestDiff <= 5 * 60 * 1000) return best;
    return null;
  } catch (e) {
    debugPrint('Error fetching history record: $e');
    return null;
  }
}

Widget _buildSimpleNotifCard({
  required String title,
  required String message,
  required String timeStr,
  required Color statusColor,
}) {
  return Container(
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
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeStr,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<Map<String, dynamic>>? _cachedRecords;

  @override
  void initState() {
    super.initState();
    _loadHistoryCache();
    // Ensure notifications are marked opened in Firestore when this screen is opened
    // so the unread badge on the app bar is cleared immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markNotificationsOpenedInFirestore();
    });
  }

  Future<void> _markNotificationsOpenedInFirestore() async {
    try {
      final col = FirebaseFirestore.instance.collection('notifications');
      final snap = await col
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      var updates = 0;
      for (final d in snap.docs) {
        final data = d.data();
        if (data['opened'] == true) continue;
        batch.update(d.reference, {'opened': true});
        updates++;
      }
      if (updates > 0) await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark notifications opened: $e');
    }
  }

  Future<void> _loadHistoryCache() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      // Try multiple likely paths where history might be stored. Some projects
      // use `/dewata_f1`, others use `/smartfarm/history/dewata_f1`,
      // `/smartfarm/dewata_f1`, `/smartfarm/data/dewata_f1`, or `/devices/dewata_f1`.
      final tryPaths = [
        ['dewata_f1'],
        ['smartfarm', 'history', 'dewata_f1'],
        ['smartfarm', 'dewata_f1'],
        ['smartfarm', 'data', 'dewata_f1'],
        ['devices', 'dewata_f1'],
      ];

      DatabaseEvent? snap;
      for (final pathParts in tryPaths) {
        final ref = pathParts.fold<DatabaseReference>(
          db,
          (prev, p) => prev.child(p),
        );
        final s = await ref.once();
        if (s.snapshot.exists) {
          snap = s;
          break;
        }
      }

      if (snap == null || !snap.snapshot.exists) {
        setState(() {
          _cachedRecords = [];
        });
        return;
      }

      final Map<dynamic, dynamic>? root =
          snap.snapshot.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> records = [];

      int toMillis(dynamic ts) {
        if (ts == null) return 0;
        if (ts is int) {
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

      if (root != null) {
        root.forEach((dateKey, dateValue) {
          if (dateValue is Map) {
            dateValue.forEach((timeKey, timeValue) {
              if (timeValue is Map) {
                final ts = toMillis(timeValue['timestamp']);
                records.add({
                  'date': dateKey,
                  'timeKey': timeKey,
                  'kelembaban_tanah': toDouble(timeValue['kelembaban_tanah']),
                  'suhu': toDouble(timeValue['suhu']),
                  'intensitas_cahaya': toDouble(timeValue['intensitas_cahaya']),
                  'kelembapan_udara': toDouble(
                    timeValue['kelembapan_udara'] ??
                        timeValue['kelembaban_udara'],
                  ),
                  'timestamp': ts,
                });
              }
            });
          }
        });
      }

      records.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

      setState(() {
        _cachedRecords = records;
      });
    } catch (e) {
      debugPrint('Failed to load history cache: $e');
      setState(() {
        _cachedRecords = [];
      });
    }
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
              'Notifikasi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 12, 51, 13),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SizedBox(height: 24),
                      Center(child: Text('Belum ada notifikasi')),
                    ],
                  );
                }

                // Group documents by day (localized date string) to make the list easier to read.
                final Map<String, List<QueryDocumentSnapshot>> groups = {};
                final Map<String, DateTime> groupDates = {};

                for (final doc in docs) {
                  final data = (doc.data() as Map<String, dynamic>?) ?? {};
                  DateTime? dt;
                  if (data['timestamp'] != null) {
                    try {
                      final ts = data['timestamp'];
                      if (ts is Timestamp) {
                        dt = ts.toDate();
                      } else if (ts is int)
                        dt = DateTime.fromMillisecondsSinceEpoch(ts);
                      else
                        dt = DateTime.parse(ts.toString());
                    } catch (_) {
                      dt = null;
                    }
                  }
                  final dateKey = dt != null
                      ? DateFormat('dd MMM yyyy').format(dt)
                      : 'Unknown';
                  groups.putIfAbsent(dateKey, () => []).add(doc);
                  if (dt != null) groupDates[dateKey] = dt;
                }

                final sortedKeys = groups.keys.toList()
                  ..sort((a, b) {
                    final da = groupDates[a];
                    final dbd = groupDates[b];
                    if (da == null && dbd == null) return 0;
                    if (da == null) return 1;
                    if (dbd == null) return -1;
                    return dbd.compareTo(da);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, sectionIndex) {
                    final key = sortedKeys[sectionIndex];
                    final items = groups[key] ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...items.map((doc) {
                          final data =
                              (doc.data() as Map<String, dynamic>?) ?? {};

                          // Build title/message but strip any 'real time warning' phrase
                          var title =
                              (data['title'] as String?) ??
                              (data['sensor'] as String?) ??
                              'Notifikasi';
                          title = title
                              .replaceAll(
                                RegExp(
                                  r'real\s*time\s*warning',
                                  caseSensitive: false,
                                ),
                                '',
                              )
                              .trim();
                          var message = (data['message'] as String?) ?? '';
                          message = message
                              .replaceAll(
                                RegExp(
                                  r'real\s*time\s*warning',
                                  caseSensitive: false,
                                ),
                                '',
                              )
                              .trim();

                          String timeStr = '';
                          DateTime? dt;
                          if (data['timestamp'] != null) {
                            try {
                              final ts = data['timestamp'];
                              if (ts is Timestamp) {
                                dt = ts.toDate();
                              } else if (ts is int)
                                dt = DateTime.fromMillisecondsSinceEpoch(ts);
                              else
                                dt = DateTime.parse(ts.toString());
                              timeStr = DateFormat('HH:mm').format(dt);
                            } catch (_) {
                              timeStr = '';
                            }
                          }

                          // collect details like before
                          Map<String, dynamic> details = {};
                          if (data['data'] is Map) {
                            details = Map<String, dynamic>.from(data['data']);
                          } else {
                            final skip = {
                              'title',
                              'message',
                              'timestamp',
                              'level',
                              'sensor',
                              'source',
                            };
                            data.forEach((k, v) {
                              if (!skip.contains(k)) details[k] = v;
                            });
                          }
                          if (details.isEmpty) {
                            for (final k in [
                              'payload',
                              'data',
                              'values',
                              'body',
                            ]) {
                              if (data[k] is Map) {
                                details = Map<String, dynamic>.from(data[k]);
                                break;
                              }
                            }
                          }

                          // attempt to extract a few numeric values (reuse existing heuristics)
                          dynamic findValue(List<String> keys) {
                            for (final k in keys) {
                              if (details.containsKey(k)) return details[k];
                              if (data.containsKey(k)) return data[k];
                            }
                            return null;
                          }

                          final tempCandidates = [
                            'suhu',
                            'temperature',
                            'temp',
                            'air_temp',
                            't',
                            'temp_c',
                          ];
                          final humCandidates = [
                            'kelembapan_udara',
                            'kelembapan',
                            'humidity',
                            'hum',
                            'humid',
                            'humidity_percent',
                            'hum_pct',
                            'humid_pct',
                          ];
                          final luxCandidates = [
                            'intensitas_cahaya',
                            'lux',
                            'illuminance',
                            'light',
                            'light_lux',
                          ];
                          final soilCandidates = [
                            'kelembaban_tanah',
                            'soil_moisture',
                            'soil',
                            'moisture',
                          ];

                          double? tempValue;
                          double? humidityValue;
                          try {
                            final tv = findValue(tempCandidates);
                            if (tv != null) {
                              tempValue = tv is num
                                  ? tv.toDouble()
                                  : double.tryParse(tv.toString());
                            }
                          } catch (_) {}
                          try {
                            final hv = findValue(humCandidates);
                            if (hv != null) {
                              if (hv is num) {
                                humidityValue = hv.toDouble();
                              } else {
                                humidityValue = double.tryParse(
                                  hv.toString().replaceAll('%', ''),
                                );
                              }
                            }
                          } catch (_) {}
                          double? luxValue;
                          try {
                            final lv = findValue(luxCandidates);
                            if (lv != null) {
                              if (lv is num) {
                                luxValue = lv.toDouble();
                              } else {
                                final p = lv.toString().replaceAll(
                                  RegExp(r'[^0-9\.,-]'),
                                  '',
                                );
                                luxValue = double.tryParse(
                                  p.replaceAll(',', '.'),
                                );
                              }
                            }
                          } catch (_) {}
                          double? soilValue;
                          try {
                            final sv = findValue(soilCandidates);
                            if (sv != null) {
                              if (sv is num) {
                                soilValue = sv.toDouble();
                              } else {
                                final p = sv.toString().replaceAll('%', '');
                                soilValue = double.tryParse(
                                  p.replaceAll(',', '.'),
                                );
                              }
                            }
                          } catch (_) {}

                          // Parsed numeric values (kept for potential drill-down UI)
                          // tempValue, humidityValue, luxValue, soilValue are available above.
                          // Reference them to avoid unused-variable warnings for now.
                          final numericValuesUsed = [
                            tempValue,
                            humidityValue,
                            luxValue,
                            soilValue,
                          ];
                          debugPrint(
                            'numericValuesUsed: ${numericValuesUsed.length}',
                          );

                          // Determine severity color (green -> orange -> red)
                          Color getSeverityColor(Map<String, dynamic> d) {
                            final defaultGreen = const Color.fromARGB(
                              255,
                              17,
                              120,
                              49,
                            );
                            try {
                              final level = d['level'];
                              if (level != null) {
                                if (level is num) {
                                  if (level >= 2) return Colors.red;
                                  if (level == 1) return Colors.orange;
                                  return defaultGreen;
                                }
                                final s = level.toString().toLowerCase();
                                if (s.contains('crit') ||
                                    s.contains('danger') ||
                                    s.contains('severe') ||
                                    s.contains('parah') ||
                                    s.contains('red')) {
                                  return Colors.red;
                                }
                                if (s.contains('warn') ||
                                    s.contains('orange') ||
                                    s.contains('medium') ||
                                    s.contains('moderate')) {
                                  return Colors.orange;
                                }
                              }

                              // fallback to other fields or title/message hints
                              final titleLower = title.toLowerCase();
                              final msgLower = message.toLowerCase();
                              if (titleLower.contains('parah') ||
                                  msgLower.contains('parah') ||
                                  titleLower.contains('krit') ||
                                  msgLower.contains('krit')) {
                                return Colors.red;
                              }
                              if (titleLower.contains('peringatan') ||
                                  msgLower.contains('peringatan') ||
                                  titleLower.contains('warning') ||
                                  msgLower.contains('waspada')) {
                                return Colors.orange;
                              }

                              return defaultGreen;
                            } catch (_) {
                              return defaultGreen;
                            }
                          }

                          final severityColor = getSeverityColor(data);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildSimpleNotifCard(
                              title: title,
                              message: message,
                              timeStr: timeStr,
                              statusColor: severityColor,
                            ),
                          );
                        }),
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
}
