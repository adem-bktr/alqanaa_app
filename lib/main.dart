import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'services/printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // ✅ تفعيل ميزة العمل بدون إنترنت (Offline Persistence)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // تخزين غير محدود للبيانات محلياً
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  PrinterService.autoConnect();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(AlqanaaApp(initialDarkMode: isDark, onboardingDone: onboardingDone));
}

class AlqanaaApp extends StatefulWidget {
  final bool initialDarkMode;
  final bool onboardingDone;
  const AlqanaaApp({super.key, this.initialDarkMode = false, this.onboardingDone = false});
  @override
  State<AlqanaaApp> createState() => _AlqanaaAppState();
}

class _AlqanaaAppState extends State<AlqanaaApp> {
  late bool isDarkMode;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;
  }

  Future<void> _toggleDarkMode() async {
    setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القناعة',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      navigatorKey: _navigatorKey,
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (!widget.onboardingDone) return OnboardingScreen(onToggleDarkMode: _toggleDarkMode, isDarkMode: isDarkMode);
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return LoginScreen(onToggleDarkMode: _toggleDarkMode, isDarkMode: isDarkMode);
    return SplashScreen(onToggleDarkMode: _toggleDarkMode, isDarkMode: isDarkMode);
  }

  ThemeData _lightTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white, elevation: 0),
  );

  ThemeData _darkTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF43A047), brightness: Brightness.dark, surface: const Color(0xFF161625)),
    scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    cardColor: const Color(0xFF1E1E2E),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF161625), foregroundColor: Colors.white, elevation: 0, centerTitle: true),
  );
}
