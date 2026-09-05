import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'user_main_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const SplashScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDarkMode,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _shimmerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoRotate;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _loadingFade;
  late Animation<double> _bgGradient;
  late Animation<double> _shimmer;

  final bool _userAlreadyLoggedIn =
      FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _bgController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500));
    _bgGradient = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _bgController, curve: Curves.easeOut));

    _logoController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoController, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _logoRotate = Tween<double>(begin: -0.1, end: 0.0).animate(
        CurvedAnimation(
            parent: _logoController, curve: Curves.elasticOut));

    _shimmerController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500))
      ..repeat();
    _shimmer = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(
            parent: _shimmerController,
            curve: Curves.easeInOut));

    _textController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textController, curve: Curves.easeIn));
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _textController,
            curve: Curves.easeOutCubic));

    _loadingController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500));
    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _loadingController, curve: Curves.easeIn));
  }

  Future<void> _startAnimations() async {
    if (_userAlreadyLoggedIn) {
      _bgController.forward();
      _logoController.forward();
      _textController.forward();
      _loadingController.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _checkAuth();
      return;
    }

    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadingController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    _checkAuth();
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
                parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.05, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _checkAuth() async {
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
    }

    if (!mounted) return;

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        _navigateTo(LoginScreen(
          onToggleDarkMode: widget.onToggleDarkMode,
          isDarkMode: widget.isDarkMode,
        ));
        return;
      }

      var user = await AuthService.getCurrentUser();

      if (user == null) {
        await Future.delayed(const Duration(seconds: 1));
        user = await AuthService.getCurrentUser(forceRefresh: true);
      }

      if (!mounted) return;

      if (user == null) {
        await Future.delayed(const Duration(seconds: 2));
        user = await AuthService.getCurrentUser(forceRefresh: true);
      }

      if (!mounted) return;

      if (user == null) {
        _navigateTo(LoginScreen(
          onToggleDarkMode: widget.onToggleDarkMode,
          isDarkMode: widget.isDarkMode,
        ));
        return;
      }

      if (user.isAdmin) {
        await NotificationService.saveToken(user.id);
        _navigateTo(MainScreen(
          onToggleDarkMode: widget.onToggleDarkMode,
          isDarkMode: widget.isDarkMode,
        ));
      } else {
        await NotificationService.saveToken(user.id);
        _navigateTo(UserMainScreen(
          user: user,
          onToggleDarkMode: widget.onToggleDarkMode,
          isDarkMode: widget.isDarkMode,
        ));
      }
    } catch (e) {
      debugPrint('❌ Auth error: $e');
      if (!mounted) return;

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        try {
          final user =
          await AuthService.getCurrentUser(forceRefresh: true);
          if (!mounted) return;
          if (user != null) {
            if (user.isAdmin) {
              _navigateTo(MainScreen(
                onToggleDarkMode: widget.onToggleDarkMode,
                isDarkMode: widget.isDarkMode,
              ));
            } else {
              _navigateTo(UserMainScreen(
                user: user,
                onToggleDarkMode: widget.onToggleDarkMode,
                isDarkMode: widget.isDarkMode,
              ));
            }
            return;
          }
        } catch (_) {}
      }

      _navigateTo(LoginScreen(
        onToggleDarkMode: widget.onToggleDarkMode,
        isDarkMode: widget.isDarkMode,
      ));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _shimmerController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _logoController,
          _textController,
          _loadingController,
          _shimmerController,
        ]),
        builder: (context, child) {
          return Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF1B5E20),
                      const Color(0xFF1B5E20), _bgGradient.value)!,
                  Color.lerp(const Color(0xFF1B5E20),
                      const Color(0xFF2E7D32), _bgGradient.value)!,
                  Color.lerp(const Color(0xFF1B5E20),
                      const Color(0xFF388E3C), _bgGradient.value)!,
                  Color.lerp(const Color(0xFF1B5E20),
                      const Color(0xFF43A047), _bgGradient.value)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              _buildLogo(),
                              const SizedBox(height: 40),
                              _buildText(),
                            ],
                          ),
                        ),
                      ),
                      _buildLoading(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Opacity(
      opacity: _logoFade.value,
      child: Transform.scale(
        scale: _logoScale.value,
        child: Transform.rotate(
          angle: _logoRotate.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2),
                ),
              ),
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 2),
                    BoxShadow(
                        color: const Color(0xFF43A047)
                            .withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Image.asset('assets/logo.png',
                          fit: BoxFit.cover,
                          width: 130,
                          height: 130),
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin:
                              Alignment(_shimmer.value - 1, 0),
                              end: Alignment(_shimmer.value, 0),
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.3),
                                Colors.transparent
                              ],
                            ).createShader(bounds);
                          },
                          child: Container(color: Colors.white),
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
    );
  }

  Widget _buildText() {
    return SlideTransition(
      position: _textSlide,
      child: FadeTransition(
        opacity: _textFade,
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.white,
                  Color(0xFFE8F5E9),
                  Colors.white
                ],
              ).createShader(bounds),
              child: const Text(
                'القناعة',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 5))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('G R O S S I S T E',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(width: 8),
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDividerLine(),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.store,
                      color: Colors.white.withOpacity(0.7),
                      size: 16),
                ),
                _buildDividerLine(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerLine() {
    return Container(
      width: 60,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.6),
            Colors.transparent
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return FadeTransition(
      opacity: _loadingFade,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: null,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8)),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.7),
                      strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('جاري التحميل...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}