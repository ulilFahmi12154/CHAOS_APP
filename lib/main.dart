import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart'; // 🔹 Ganti dari uni_links
import 'dart:async';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/rekomendasi_pupuk_screen.dart';
import 'screens/nutrient_recommendation_screen.dart';
import 'screens/intro_slides_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/location_manager_screen.dart';
import 'services/phase_threshold_sync_service.dart';
import 'services/sensor_monitoring_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initPhaseSync();
  }

  // Auto-start phase threshold sync service saat user login
  void _initPhaseSync() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // User login, start sync service
        PhaseThresholdSyncService.startSync();
        // Start sensor monitoring service untuk notifikasi otomatis
        SensorMonitoringService().startMonitoring();
      } else {
        // User logout, stop sync service
        PhaseThresholdSyncService.stopSync();
        SensorMonitoringService().stopMonitoring();
      }
    });
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link (cold start)
    final Uri? uri = await _appLinks.getInitialAppLink();
    if (uri != null) {
      _handleDeepLink(uri);
    }

    // Listen untuk incoming links
    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');

    if (uri.scheme == 'chaosapp' && uri.host == 'reset') {
      final oobCode = uri.queryParameters['oobCode'];
      if (oobCode != null) {
        print('OOB Code: $oobCode');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(oobCode: oobCode),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartFarm Chaos App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: Colors.green.shade50,
        // Global page transition: fade dengan scale seperti app modern
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeScalePageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeScalePageTransitionsBuilder(),
            TargetPlatform.linux: FadeScalePageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(initialIndex: 2),
        '/home': (context) => const MainNavigationScreen(initialIndex: 2),
        '/kontrol': (context) => const MainNavigationScreen(initialIndex: 0),
        '/history': (context) => const MainNavigationScreen(initialIndex: 1),
        '/laporan': (context) => const MainNavigationScreen(initialIndex: 3),
        '/settings': (context) => const MainNavigationScreen(initialIndex: 4),
        '/profile': (context) => const MainNavigationScreen(initialIndex: 5),
        '/welcome': (context) => const WelcomeScreen(),
        '/rekomendasi-pupuk': (context) => const RekomendasiPupukPage(),
        '/nutrient-recommendation': (context) =>
            const NutrientRecommendationScreen(),
        '/intro': (context) => const IntroSlidesScreen(),
        '/locations': (context) => const LocationManagerScreen(),
        // Route alias: always open notifications within MainNavigationScreen
        '/notifikasi': (context) => const MainNavigationScreen(initialIndex: 6),
      },
    );
  }
}

// Custom transition builder untuk efek fade + scale modern
class FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeInOut;

    var fadeAnimation = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    var scaleAnimation = Tween(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(scale: scaleAnimation, child: child),
    );
  }
}
