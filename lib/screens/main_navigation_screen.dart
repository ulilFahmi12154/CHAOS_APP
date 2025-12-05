import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'kontrol_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'notifikasi_screen.dart';
import '../widgets/tour_overlay.dart';
import '../widgets/notification_badge.dart';

/// Screen utama dengan bottom navigation yang statis
/// Hanya konten yang berubah, navigation bar tetap
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final bool showTour;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 2, // Default ke Dashboard
    this.showTour = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  // Deprecated by _tabHistory, kept only if needed later
  // int _lastNonNotifIndex = 2;
  final List<int> _tabHistory = [];
  bool _showTourOverlay = false;
  int _currentTourStep = 0;

  // GlobalKeys untuk track posisi navbar buttons
  final Map<String, GlobalKey> _navButtonKeys = {
    'kontrol_button': GlobalKey(),
    'history_button': GlobalKey(),
    'dashboard_button': GlobalKey(),
    'settings_button': GlobalKey(),
    'profile_button': GlobalKey(),
  };

  // List semua screen
  final List<Widget> _screens = [
    const KontrolScreen(),
    const HistoryScreen(),
    const HomeScreen(),
    const SettingsScreen(),
    const ProfileScreen(),
    const NotifikasiScreen(),
  ];

  bool _hasProcessedArgs = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _tabHistory.clear();
    // Don't add initialIndex to history - only add for notification flows

    // Show tour overlay after frame is built and layout is complete
    if (widget.showTour) {
      // Set screen to first tour step (Kontrol)
      _currentIndex = _getScreenIndexFromTargetKey(
        appTourSteps[_currentTourStep].targetKey,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait for another frame to ensure all widgets are fully laid out
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showTourOverlay = true;
            });
          }
        });
      });
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        // Don't add to history for direct tab taps - user expects back to exit
        // Only navigation flows (like notifications) should add to history
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Process route arguments for notification navigation with lastIndex
    if (!_hasProcessedArgs) {
      _hasProcessedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final initialIdx = args['initialIndex'];
        final lastIdx = args['lastIndex'];
        if (initialIdx == 5 && lastIdx is int && _currentIndex == 5) {
          // Seed history when opening notifications from another screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _tabHistory.isEmpty) {
              setState(() {
                _tabHistory
                  ..clear()
                  ..add(lastIdx)
                  ..add(5);
              });
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Use tab history to navigate back through tabs
        if (_tabHistory.length > 1) {
          setState(() {
            // Remove current tab
            _tabHistory.removeLast();
            // Go to previous tab
            _currentIndex = _tabHistory.last;
          });
          return false; // consume back press
        }
        // No history left: allow system back (exit/minimize)
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
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
                    setState(() {
                      // Add current tab to history before switching to notifications
                      if (_currentIndex != 5 &&
                          !_tabHistory.contains(_currentIndex)) {
                        _tabHistory.add(_currentIndex);
                      }
                      _currentIndex = 5; // Index NotifikasiScreen
                      _tabHistory.add(5);
                    });
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: IndexedStack(index: _currentIndex, children: _screens),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        key: _navButtonKeys['kontrol_button'],
                        child: _buildNavItem(
                          icon: Icons.toggle_on_outlined,
                          label: 'Kontrol',
                          index: 0,
                        ),
                      ),
                      Container(
                        key: _navButtonKeys['history_button'],
                        child: _buildNavItem(
                          icon: Icons.history,
                          label: 'Histori',
                          index: 1,
                        ),
                      ),
                      Container(
                        key: _navButtonKeys['dashboard_button'],
                        child: _buildNavItem(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                          index: 2,
                        ),
                      ),
                      Container(
                        key: _navButtonKeys['settings_button'],
                        child: _buildNavItem(
                          icon: Icons.settings_outlined,
                          label: 'Pengaturan',
                          index: 3,
                        ),
                      ),
                      Container(
                        key: _navButtonKeys['profile_button'],
                        child: _buildNavItem(
                          icon: Icons.person_outline,
                          label: 'Profile',
                          index: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tour overlay - muncul di atas UI asli
          if (_showTourOverlay) _buildTourOverlay(),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
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

  Future<void> _completeTour() async {
    // Simpan status tour ke Firestore per user
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'tourCompleted': true,
      }, SetOptions(merge: true));
    }
    if (mounted) {
      setState(() {
        _showTourOverlay = false;
        // Kembali ke dashboard setelah tour selesai
        _currentIndex = 2;
      });
    }
  }

  // Mapping dari targetKey ke screen index
  int _getScreenIndexFromTargetKey(String targetKey) {
    switch (targetKey) {
      case 'kontrol_button':
        return 0;
      case 'history_button':
        return 1;
      case 'dashboard_button':
        return 2;
      case 'settings_button':
        return 3;
      case 'profile_button':
        return 4;
      default:
        return 2; // Default to dashboard
    }
  }

  void _nextStep() {
    if (_currentTourStep < appTourSteps.length - 1) {
      setState(() {
        _currentTourStep++;
        // Pindah ke screen yang sesuai dengan step berikutnya
        _currentIndex = _getScreenIndexFromTargetKey(
          appTourSteps[_currentTourStep].targetKey,
        );
      });
    } else {
      _completeTour();
    }
  }

  void _previousStep() {
    if (_currentTourStep > 0) {
      setState(() {
        _currentTourStep--;
        // Pindah ke screen yang sesuai dengan step sebelumnya
        _currentIndex = _getScreenIndexFromTargetKey(
          appTourSteps[_currentTourStep].targetKey,
        );
      });
    }
  }

  void _skipTour() {
    _completeTour();
  }

  Widget _buildTourOverlay() {
    return TourOverlayWidget(
      key: ValueKey(
        'tour_step_$_currentTourStep',
      ), // Force rebuild on step change
      step: appTourSteps[_currentTourStep],
      currentStep: _currentTourStep,
      totalSteps: appTourSteps.length,
      targetKey: _navButtonKeys[appTourSteps[_currentTourStep].targetKey],
      onNext: _nextStep,
      onPrevious: _previousStep,
      onSkip: _skipTour,
    );
  }
}
