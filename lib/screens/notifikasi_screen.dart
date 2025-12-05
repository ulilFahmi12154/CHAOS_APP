import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:chaos_app/screens/warning_detail_screen.dart';
import 'package:chaos_app/services/notification_read_cache.dart';

Widget _buildSimpleNotifCard({
  required String title,
  required String message,
  required String timeStr,
  required Color statusColor,
  required bool isRead,
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRead
              ? Colors.grey.shade200
              : const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
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
          Stack(
            children: [
              Icon(Icons.notifications, size: 24, color: statusColor),
              if (!isRead)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
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
  final Set<String> _readNotifications = {};
  String? _currentUserId;
  String? _userVarietas;

  bool _isReadValue(dynamic v) {
    return v == true || v == 'true' || v == 1 || v == '1';
  }

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    // Ambil varietas user
    final db = FirebaseDatabase.instance.ref();
    final userSnapshot = await db.child('users').child(user.uid).get();

    if (userSnapshot.exists && userSnapshot.value is Map) {
      final userData = userSnapshot.value as Map;
      _userVarietas =
          (userData['active_varietas'] ??
                  (userData['settings'] is Map
                      ? userData['settings']['varietas']
                      : null))
              ?.toString();
    }

    // Fallback ke smartfarm/active_varietas
    if (_userVarietas == null || _userVarietas!.isEmpty) {
      final globalSnapshot = await db
          .child('smartfarm')
          .child('active_varietas')
          .get();
      if (globalSnapshot.exists) {
        _userVarietas = globalSnapshot.value.toString();
      }
    }

    // Load status notifikasi yang sudah dibaca
    await _loadReadNotifications();

    setState(() {
      _warningStream = _getWarningsFromRealtimeDB().asBroadcastStream();
    });
  }

  Future<void> _loadReadNotifications() async {
    // Status isRead sekarang disimpan langsung di warning data
    // Tidak perlu load dari user's read_notifications lagi
    // Status akan di-load langsung dari stream
    setState(() {
      _readNotifications.clear();
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_currentUserId == null || _userVarietas == null) return;

    // Parse notification ID: format {date}-{sensorType}-{pushKey}
    try {
      final parts = notificationId.split('-');
      if (parts.length >= 3) {
        final date = parts[0];
        final sensorType = parts[1];
        final pushKey = parts.sublist(2).join('-');

        final db = FirebaseDatabase.instance.ref();
        await db
            .child(
              'smartfarm/warning/$_userVarietas/$date/$sensorType/$pushKey',
            )
            .update({'isRead': true});

        setState(() {
          _readNotifications.add(notificationId);
        });
        // Reflect immediately in badge via shared cache
        NotificationReadCache.instance.add(notificationId);
      }
    } catch (e) {
      // Error handling
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> warnings) async {
    if (_currentUserId == null || _userVarietas == null) return;

    try {
      final db = FirebaseDatabase.instance.ref();
      int updateCount = 0;

      // Update setiap notifikasi yang belum dibaca
      print('Total warnings to check: ${warnings.length}');

      for (final warning in warnings) {
        final isReadValue = warning['isRead'];
        final isAlreadyRead = _isReadValue(isReadValue);

        print(
          'Warning ID: ${warning['id']}, isRead: $isReadValue, isAlreadyRead: $isAlreadyRead',
        );

        if (!isAlreadyRead) {
          final notifId = warning['id'] ?? '';
          if (notifId.isNotEmpty) {
            final parts = notifId.split('-');
            if (parts.length >= 3) {
              final date = parts[0];
              final sensorType = parts[1];
              final pushKey = parts.sublist(2).join('-');

              final path =
                  'smartfarm/warning/$_userVarietas/$date/$sensorType/$pushKey';
              print('Updating path: $path');

              // Update langsung ke path yang spesifik
              try {
                await db.child(path).update({'isRead': true});
                print('Successfully updated: $path');
                updateCount++;

                setState(() {
                  _readNotifications.add(notifId);
                });
                // Reflect immediately in badge via shared cache
                NotificationReadCache.instance.add(notifId);
              } catch (e) {
                print('Error updating $path: $e');
              }
            }
          }
        }
      }

      print('Total updated: $updateCount');

      // Show success message
      if (mounted && updateCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$updateCount notifikasi telah ditandai sebagai sudah dibaca',
            ),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 2),
          ),
        );

        // Force refresh stream so badge + list update instantly
        setState(() {
          _warningStream = _getWarningsFromRealtimeDB().asBroadcastStream();
        });
      }
    } catch (e) {
      print('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menandai notifikasi'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Ambil warning dari Realtime Database hanya untuk varietas user
  Stream<List<Map<String, dynamic>>> _getWarningsFromRealtimeDB() {
    final db = FirebaseDatabase.instance.ref();

    // Ambil 7 hari terakhir
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final date = now.subtract(Duration(days: i));
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    });

    if (_userVarietas == null || _userVarietas!.isEmpty) {
      return Stream.value([]);
    }

    // Path: smartfarm/warning/{varietas}/{tanggal}
    // Hanya ambil warning untuk varietas user
    final varietasPath = 'smartfarm/warning/$_userVarietas';

    return db.child(varietasPath).onValue.map((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> allWarnings = [];

      if (data is Map) {
        // data = {2025-12-01: {suhu: {...}, ...}, 2025-12-02: {...}}
        data.forEach((dateKey, dateData) {
          // Hanya ambil dari 7 hari terakhir
          if (dates.contains(dateKey.toString()) && dateData is Map) {
            // dateData = {suhu: {push1: {...}, push2: {...}}, tanah: {...}, ...}
            dateData.forEach((sensorType, sensorData) {
              if (sensorData is Map) {
                // sensorData = {push1: {...}, push2: {...}}
                sensorData.forEach((pushKey, warningData) {
                  if (warningData is Map) {
                    final warning = Map<String, dynamic>.from(warningData);
                    warning['sensor'] = sensorType.toString();
                    warning['varietas'] = _userVarietas;
                    warning['sensorType'] = sensorType.toString();
                    warning['date'] = dateKey.toString();
                    warning['id'] = '$dateKey-$sensorType-$pushKey';
                    allWarnings.add(warning);
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

      // Ambil hanya 50 warning terbaru (lebih banyak untuk 7 hari)
      if (allWarnings.length > 50) {
        allWarnings = allWarnings.sublist(0, 50);
      }

      return allWarnings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _userVarietas == null
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Mark All as Read button
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '7 Hari Terakhir',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _warningStream,
                        builder: (context, snapshot) {
                          final warnings = snapshot.data ?? [];
                          final hasUnread = warnings.any(
                            (w) => !_isReadValue(w['isRead']),
                          );

                          if (!hasUnread) return const SizedBox.shrink();

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () => _markAllAsRead(warnings),
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Tandai Sudah Dibaca'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1B5E20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Notification List
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _warningStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: ${snapshot.error}'),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final warnings = snapshot.data ?? [];
                    if (warnings.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
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
                        child: const Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tidak ada peringatan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Semua sensor dalam kondisi normal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // List notifications
                    return Column(
                      children: warnings.map((warning) {
                        final notifId = warning['id'] ?? '';
                        final isReadValue = warning['isRead'];
                        final isRead =
                            _isReadValue(isReadValue) ||
                            _readNotifications.contains(notifId);
                        final sensorType = (warning['sensor'] ?? '')
                            .toString()
                            .toUpperCase();
                        final message = warning['message'] ?? '';
                        final level = warning['level'] ?? 'warning';
                        final timeStr = _formatTimestamp(warning['timestamp']);
                        final date = warning['date'] ?? '';

                        final statusColor = level == 'critical'
                            ? Colors.red
                            : Colors.orange;

                        // Format tanggal untuk ditampilkan
                        String dateLabel = '';
                        try {
                          final dt = DateTime.parse(date);
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final yesterday = today.subtract(
                            const Duration(days: 1),
                          );
                          final itemDate = DateTime(dt.year, dt.month, dt.day);

                          if (itemDate == today) {
                            dateLabel = 'Hari Ini, $timeStr';
                          } else if (itemDate == yesterday) {
                            dateLabel = 'Kemarin, $timeStr';
                          } else {
                            dateLabel =
                                '${DateFormat('d MMM', 'id_ID').format(dt)}, $timeStr';
                          }
                        } catch (_) {
                          dateLabel = timeStr;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildSimpleNotifCard(
                            title: sensorType,
                            message: message,
                            timeStr: dateLabel,
                            statusColor: statusColor,
                            isRead: isRead,
                            onTap: () {
                              if (!isRead) {
                                _markAsRead(notifId);
                              }
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
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
