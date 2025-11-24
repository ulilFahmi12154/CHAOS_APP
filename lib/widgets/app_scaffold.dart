import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _markOpenedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('notifications_last_opened', now);
      setState(() {
        _lastOpenedMillis = now;
      });
    } catch (_) {}
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

    String routeName;
    switch (index) {
      case 0:
        routeName = '/kontrol';
        break;
      case 1:
        routeName = '/history';
        break;
      case 2:
        routeName = '/home';
        break;
      case 3:
        routeName = '/settings';
        break;
      case 4:
        routeName = '/profile';
        break;
      default:
        return;
    }

    Navigator.pushReplacementNamed(context, routeName);
  }
}
