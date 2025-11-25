import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/kontrol_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';

/// Template scaffold dengan app bar dan bottom navigation
/// yang bisa digunakan di semua halaman utama
class AppScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;

  const AppScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _lastOpenedMillis = 0;
  // Cache untuk menyimpan instance screen agar tidak rebuild terus
  static final Map<int, Widget> _cachedScreens = {};

  @override
  void initState() {
    super.initState();
    _loadLastOpened();
  }

  Future<void> _loadLastOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _lastOpenedMillis = prefs.getInt('notifications_last_opened') ?? 0;
      });
    } catch (_) {}
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
        // Only update docs that are not already opened/read to minimize writes
        if (data['opened'] == true && data['read'] == true) continue;
        final Map<String, dynamic> upd = {};
        if (data['opened'] != true) upd['opened'] = true;
        if (data['read'] != true) upd['read'] = true;
        if (upd.isNotEmpty) {
          batch.update(d.reference, upd);
          updates++;
        }
      }
      if (updates > 0) await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark notifications opened from AppScaffold: $e');
    }
  }

  Future<void> _markOpenedNow() async {
    try {
      // Mark in Firestore first so queries in other clients update quickly.
      await _markNotificationsOpenedInFirestore();
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('notifications_last_opened', now);
      setState(() {
        _lastOpenedMillis = now;
      });
    } catch (_) {}
    // Preload semua screen saat pertama kali
    _preloadScreens();
  }

  void _preloadScreens() {
    // Cache semua screen untuk navigasi instant
    if (_cachedScreens.isEmpty) {
      _cachedScreens[0] = const KontrolScreen();
      _cachedScreens[1] = const HistoryScreen();
      _cachedScreens[2] = const HomeScreen();
      _cachedScreens[3] = const SettingsScreen();
      _cachedScreens[4] = const ProfileScreen();
    }
  }

  Widget _getScreen(int index) {
    return _cachedScreens[index] ?? const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Image.asset(
            'assets/images/logo.png',
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.eco, color: Colors.white),
          ),
        ),
        actions: [
          // Show unread badge if: (A) any doc has opened==false/read==false,
          // or (B) latest notification timestamp > last-opened timestamp.
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, latestSnap) {
              bool hasUnread = false;
              int latestMillis = 0;

              if (latestSnap.hasData &&
                  (latestSnap.data?.docs.isNotEmpty ?? false)) {
                final first = latestSnap.data!.docs.first.data();
                if (first is Map<String, dynamic>) {
                  final ts = first['timestamp'];
                  try {
                    if (ts is Timestamp) {
                      latestMillis = ts.toDate().millisecondsSinceEpoch;
                    } else if (ts is int)
                      latestMillis = ts;
                    else
                      latestMillis = int.tryParse(ts.toString()) ?? 0;
                  } catch (_) {
                    latestMillis = 0;
                  }
                }
                if (latestMillis > _lastOpenedMillis) hasUnread = true;
              }

              // Also check explicit flags (opened/read)
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('opened', isEqualTo: false)
                    .limit(1)
                    .snapshots(),
                builder: (context, openedSnap) {
                  if (openedSnap.hasData &&
                      (openedSnap.data?.docs.isNotEmpty ?? false)) {
                    hasUnread = true;
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('read', isEqualTo: false)
                        .limit(1)
                        .snapshots(),
                    builder: (context, readSnap) {
                      if (readSnap.hasData &&
                          (readSnap.data?.docs.isNotEmpty ?? false)) {
                        hasUnread = true;
                      }

                      return IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                            ),
                            if (hasUnread)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () async {
                          await _markOpenedNow();
                          Navigator.pushNamed(context, '/notifikasi');
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: widget.body,
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
                  context,
                  icon: Icons.toggle_on_outlined,
                  label: 'Kontrol',
                  index: 0,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.history,
                  label: 'Histori',
                  index: 1,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  index: 2,
                ),
                _buildNavItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  index: 3,
                ),
                _buildNavItem(
                  context,
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

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = widget.currentIndex == index;
    return InkWell(
      onTap: () => _navigateTo(context, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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

  void _navigateTo(BuildContext context, int index) {
    if (index == widget.currentIndex) return;

    // Use the app-level named routes so MainNavigationScreen remains
    // the single source of truth for the bottom navigation. This avoids
    // pushing raw screen widgets (that might not include the nav bar)
    // and prevents visual corruption when switching from the
    // notifications route back into the main app.
    final routeForIndex = <int, String>{
      0: '/kontrol',
      1: '/history',
      2: '/home',
      3: '/settings',
      4: '/profile',
    };

    final routeName = routeForIndex[index] ?? '/home';
    Navigator.of(context).pushReplacementNamed(routeName);
  }
}
