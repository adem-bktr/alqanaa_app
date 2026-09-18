import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'services/printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // ✅ محاولة الاتصال التلقائي بالطابعة
  PrinterService.autoConnect();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(AlqanaaApp(
    initialDarkMode: isDark,
    onboardingDone: onboardingDone,
  ));
}

class AlqanaaApp extends StatefulWidget {
  final bool initialDarkMode;
  final bool onboardingDone;

  const AlqanaaApp({
    super.key,
    this.initialDarkMode = false,
    this.onboardingDone = false,
  });

  @override
  State<AlqanaaApp> createState() => _AlqanaaAppState();
}

class _AlqanaaAppState extends State<AlqanaaApp> {
  late bool isDarkMode;

  // ✅ GlobalKey للـ Navigator — لا يُعاد بناؤه عند setState
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ✅ الشاشة الأولى تُحدد مرة واحدة فقط في initState
  late Widget _initialScreen;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;

    // ✅ تحديد الشاشة الأولى مرة واحدة فقط — لا تتغير بعد ذلك
    if (!widget.onboardingDone) {
      _initialScreen = OnboardingScreen(
        onToggleDarkMode: _toggleDarkMode,
        isDarkMode: isDarkMode,
      );
    } else {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _initialScreen = LoginScreen(
          onToggleDarkMode: _toggleDarkMode,
          isDarkMode: isDarkMode,
        );
      } else {
        _initialScreen = SplashScreen(
          onToggleDarkMode: _toggleDarkMode,
          isDarkMode: isDarkMode,
        );
      }
    }
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
      // استخدام home مباشرة مع الفحص يضمن استقرار التنقل عند التحديث
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (!widget.onboardingDone) {
      return OnboardingScreen(
        onToggleDarkMode: _toggleDarkMode,
        isDarkMode: isDarkMode,
      );
    }
    
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return LoginScreen(
        onToggleDarkMode: _toggleDarkMode,
        isDarkMode: isDarkMode,
      );
    }
    
    return SplashScreen(
      onToggleDarkMode: _toggleDarkMode,
      isDarkMode: isDarkMode,
    );
  }

  ThemeData _lightTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2E7D32),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  ThemeData _darkTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    cardColor: const Color(0xFF1E1E2E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A2E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
