import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'kontrol_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'notifikasi_screen.dart';
import 'report_screen.dart';
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
    'laporan_button': GlobalKey(),
    'settings_button': GlobalKey(),
  };

  // List semua screen dengan index yang jelas
  // Bottom Nav (0-4): Kontrol, Histori, Dashboard, Laporan, Pengaturan
  // Header (5-6): Profile, Notifikasi
  List<Widget> get _screens => [
    const KontrolScreen(), // 0 - Bottom Nav (Kontrol)
    const HistoryScreen(), // 1 - Bottom Nav (Histori)
    const HomeScreen(), // 2 - Bottom Nav (Dashboard)
    const ReportScreen(), // 3 - Bottom Nav (Laporan) ⚠️
    const SettingsScreen(), // 4 - Bottom Nav (Pengaturan) ⚠️
    const ProfileScreen(), // 5 - Header Left (Profile) ⚠️
    const NotifikasiScreen(), // 6 - Header Right (Notifikasi) ⚠️
  ];

  bool _hasProcessedArgs = false;

  @override
  void initState() {
    super.initState();
    // Validate initialIndex to prevent out of bounds
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
    _tabHistory.clear();
    // Don't add initialIndex to history - only add for notification flows

    debugPrint(
      '🔧 MainNavigation initialized with index: $_currentIndex (requested: ${widget.initialIndex})',
    );

    // Verify screen types
    debugPrint('📋 Screen verification:');
    for (int i = 0; i < _screens.length; i++) {
      debugPrint('   [$i] ${_screens[i].runtimeType}');
    }

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
    debugPrint('📱 Bottom nav tapped: index $index (current: $_currentIndex)');
    if (_currentIndex != index && index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
        debugPrint('✅ Navigated to index $_currentIndex');
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
              centerTitle: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 80,
              leading: IconButton(
                onPressed: () {
                  debugPrint('👤 Profile button tapped, navigating to index 5');
                  if (mounted) {
                    setState(() {
                      _currentIndex = 5; // Index ProfileScreen
                    });
                  }
                },
                icon: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Profile',
              ),
              title: Image.asset(
                'assets/images/logo.png',
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.eco, color: Colors.white, size: 50),
              ),
              actions: [
                NotificationBadgeStream(
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  onTap: () {
                    debugPrint(
                      '🔔 Notification button tapped, navigating to index 6',
                    );
                    if (mounted) {
                      setState(() {
                        // Add current tab to history before switching to notifications
                        if (_currentIndex != 6 &&
                            !_tabHistory.contains(_currentIndex)) {
                          _tabHistory.add(_currentIndex);
                        }
                        _currentIndex = 6; // Index NotifikasiScreen
                        _tabHistory.add(6);
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Builder(
                builder: (context) {
                  final clampedIndex = _currentIndex.clamp(
                    0,
                    _screens.length - 1,
                  );
                  debugPrint('🖥️ Rendering screen at index: $clampedIndex');
                  debugPrint(
                    '   Screen type: ${_screens[clampedIndex].runtimeType}',
                  );
                  return IndexedStack(index: clampedIndex, children: _screens);
                },
              ),
            ),
            bottomNavigationBar: SizedBox(
              height: 80,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Custom shaped bottom navigation bar
                  CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 80),
                    painter: BottomNavPainter(
                      bubblePosition: _calculateBubblePosition(_currentIndex),
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  // Animated bubble indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    left: _calculateBubblePosition(_currentIndex),
                    top: -8,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIconForIndex(_currentIndex),
                        color: const Color(0xFF1B5E20),
                        size: 32,
                      ),
                    ),
                  ),
                  // Navigation items
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 80,
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
                            key: _navButtonKeys['laporan_button'],
                            child: _buildNavItem(
                              icon: Icons.bar_chart_rounded,
                              label: 'Laporan',
                              index: 3,
                            ),
                          ),
                          Container(
                            key: _navButtonKeys['settings_button'],
                            child: _buildNavItem(
                              icon: Icons.settings_outlined,
                              label: 'Pengaturan',
                              index: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tour overlay - muncul di atas UI asli
          if (_showTourOverlay) _buildTourOverlay(),
        ],
      ),
    );
  }

  // Calculate bubble position based on selected index
  double _calculateBubblePosition(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Only show bubble for bottom nav items (0-4), not for profile(5) or notif(6)
    if (index < 0 || index >= 5) return -100; // Hide bubble for header items
    final itemWidth = screenWidth / 5; // 5 items in bottom nav
    return (itemWidth * index) +
        (itemWidth / 2) -
        34; // Center bubble (68/2 = 34)
  }

  // Get icon for current index
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.toggle_on_outlined;
      case 1:
        return Icons.history;
      case 2:
        return Icons.dashboard_outlined;
      case 3:
        return Icons.bar_chart_rounded;
      case 4:
        return Icons.settings_outlined;
      case 5:
        return Icons.person_outline; // Profile (header)
      case 6:
        return Icons.notifications_outlined; // Notifikasi (header)
      default:
        return Icons.dashboard_outlined;
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(top: isActive ? 20 : 8, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Icon dengan opacity saat active (karena icon utama ada di bubble)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isActive ? 0.0 : 1.0,
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white70,
                  size: 26,
                ),
              ),
              SizedBox(height: isActive ? 8 : 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: isActive ? 12 : 10.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
      case 'laporan_button':
        return 3;
      case 'settings_button':
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

// Custom painter untuk membuat navigation bar dengan curve untuk bubble
class BottomNavPainter extends CustomPainter {
  final double bubblePosition;
  final Color color;

  BottomNavPainter({required this.bubblePosition, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..isAntiAlias = true;

    final path = Path();

    // Start dari kiri bawah
    path.moveTo(0, 20);

    // Curve ke atas kiri untuk rounded corner
    path.quadraticBezierTo(0, 0, 20, 0);

    // Line ke posisi sebelum bubble
    path.lineTo(bubblePosition - 10, 0);

    // Curve naik untuk bubble (membuat cekungan simetris dan smooth)
    // Curve kiri masuk
    path.quadraticBezierTo(bubblePosition + 8, 0, bubblePosition + 15, 12);
    // Curve lengkung dalam
    path.quadraticBezierTo(bubblePosition + 22, 20, bubblePosition + 34, 20);
    // Curve kanan keluar (mirror dari kiri)
    path.quadraticBezierTo(bubblePosition + 46, 20, bubblePosition + 53, 12);
    path.quadraticBezierTo(bubblePosition + 60, 0, bubblePosition + 78, 0);

    // Line ke kanan atas
    path.lineTo(size.width - 20, 0);

    // Curve ke kanan bawah untuk rounded corner
    path.quadraticBezierTo(size.width, 0, size.width, 20);

    // Line ke kanan bawah
    path.lineTo(size.width, size.height);

    // Line ke kiri bawah
    path.lineTo(0, size.height);

    // Close path
    path.close();

    // Draw shadow first
    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 8, false);

    // Draw the actual shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BottomNavPainter oldDelegate) {
    return oldDelegate.bubblePosition != bubblePosition;
  }
}
