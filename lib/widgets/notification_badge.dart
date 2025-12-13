import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chaos_app/services/notification_read_cache.dart';

/// Widget reusable untuk menampilkan badge notifikasi
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;

  const NotificationBadge({
    required this.child,
    required this.count,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: count > 9 ? BorderRadius.circular(10) : null,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: count > 9
                  ? Text(
                      '9+',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
      ],
    );
  }
}

/// StreamBuilder untuk notifikasi yang belum dibaca
class NotificationBadgeStream extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NotificationBadgeStream({required this.child, this.onTap, super.key});

  Stream<int> _getUnreadNotificationCount() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield 0;
      return;
    }

    final userId = user.uid;
    final db = FirebaseDatabase.instance.ref();

    // Ambil varietas user
    String? userVarietas;
    try {
      final userSnapshot = await db.child('users').child(userId).get();
      if (userSnapshot.exists && userSnapshot.value is Map) {
        final userData = userSnapshot.value as Map;
        userVarietas =
            (userData['active_varietas'] ??
                    (userData['settings'] is Map
                        ? userData['settings']['varietas']
                        : null))
                ?.toString();
      }

      // Fallback ke smartfarm/active_varietas
      if (userVarietas == null || userVarietas.isEmpty) {
        final globalSnapshot = await db
            .child('smartfarm/active_varietas')
            .get();
        if (globalSnapshot.exists) {
          userVarietas = globalSnapshot.value?.toString();
        }
      }
    } catch (e) {
      yield 0;
      return;
    }

    if (userVarietas == null || userVarietas.isEmpty) {
      yield 0;
      return;
    }

    // Listen untuk warnings dari 7 hari terakhir
    await for (final event
        in db.child('smartfarm/warning/$userVarietas').onValue.handleError((
          error,
        ) {
          debugPrint('⚠️ [NOTIFICATION] Error accessing warnings: $error');
        })) {
      if (event.snapshot.value == null) {
        yield 0;
        continue;
      }

      try {
        final data = event.snapshot.value as Map;
        List<Map<String, dynamic>> allWarnings = [];

        // Ambil 7 hari terakhir
        final now = DateTime.now();
        final dates = List.generate(7, (i) {
          final date = now.subtract(Duration(days: i));
          return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        });

        // Iterasi per tanggal - sama persis dengan notifikasi_screen
        data.forEach((dateKey, dateData) {
          if (dates.contains(dateKey.toString()) && dateData is Map) {
            // Iterasi per sensor type
            dateData.forEach((sensorType, sensorData) {
              if (sensorData is Map) {
                // Iterasi per warning
                sensorData.forEach((pushKey, warningData) {
                  if (warningData is Map) {
                    // Copy semua data dari warningData (termasuk isRead)
                    final warning = Map<String, dynamic>.from(warningData);
                    // Tambahkan ID agar bisa disilangkan dengan cache lokal
                    warning['id'] =
                        '${dateKey.toString()}-${sensorType.toString()}-${pushKey.toString()}';
                    allWarnings.add(warning);
                  }
                });
              }
            });
          }
        });

        // Sort by timestamp descending (terbaru dulu)
        allWarnings.sort((a, b) {
          final timeA = a['timestamp'] ?? 0;
          final timeB = b['timestamp'] ?? 0;
          return timeB.compareTo(timeA);
        });

        // Ambil hanya 50 warning terbaru (sama seperti di notifikasi_screen)
        if (allWarnings.length > 50) {
          allWarnings = allWarnings.sublist(0, 50);
        }

        // Hitung yang belum dibaca dari 50 terbaru
        bool _isReadValue(dynamic v) =>
            v == true || v == 'true' || v == 1 || v == '1';

        final cache = NotificationReadCache.instance;
        int unreadCount = 0;
        for (final w in allWarnings) {
          final isReadValue = w['isRead'];
          final id = (w['id'] ?? '').toString();
          final isReadDb = _isReadValue(isReadValue);
          final isReadLocal = id.isNotEmpty && cache.contains(id);
          if (!(isReadDb || isReadLocal)) {
            unreadCount++;
          }
        }

        yield unreadCount;
      } catch (e) {
        yield 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _getUnreadNotificationCount(),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                child, // Icon lonceng
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
