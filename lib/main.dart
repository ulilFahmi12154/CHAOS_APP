import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart'; // 🔹 Ganti dari uni_links
import 'dart:async';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/kontrol_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/intro_slides_screen.dart';
import 'screens/welcome_screen.dart';

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
        // Global page transition: slide from right with fade
        pageTransitionsTheme: PageTransitionsTheme(builders: {
          for (var platform in TargetPlatform.values)
            platform: _SlideFadePageTransitionsBuilder(),
        }),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/kontrol': (context) => const KontrolScreen(),
        '/history': (context) => const HistoryScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/intro': (context) => const IntroSlidesScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
    );
  }
}

class _SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Use Curved animation for smoother effect
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
