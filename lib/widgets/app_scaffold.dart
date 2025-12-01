import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () async {
              await _markOpenedNow();
              Navigator.pushNamed(context, '/notifikasi');
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

  Future<void> _markOpenedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'notifications_last_opened',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}
