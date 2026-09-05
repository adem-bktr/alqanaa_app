import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/page_transitions.dart';
import 'main_screen.dart';
import 'user_main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const LoginScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  late AnimationController _mainController;
  late AnimationController _buttonController;
  late AnimationController _bgController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;
  late Animation<double> _buttonScale;
  late Animation<double> _bgFade;

  // ✅ Keyboard Focus
  final FocusNode _keyboardFocus = FocusNode();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _bgFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeOut,
    ));

    _logoScale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));

    _logoFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    ));

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _formFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
    ));

    _buttonScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _mainController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _mainController.dispose();
    _buttonController.dispose();
    _bgController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('الرجاء إدخال البريد وكلمة المرور');
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await AuthService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        await NotificationService.saveToken(user.id);

        if (user.isAdmin) {
          Navigator.pushReplacement(
            context,
            FadeScaleRoute(
              page: MainScreen(
                onToggleDarkMode: widget.onToggleDarkMode,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            FadeScaleRoute(
              page: UserMainScreen(
                user: user,
                onToggleDarkMode: widget.onToggleDarkMode,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
        }
      } else {
        _showError('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      _showError(_getErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found') ||
        error.contains('invalid-credential') ||
        error.contains('INVALID_LOGIN_CREDENTIALS') ||
        error.contains('wrong-password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    } else if (error.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صالحة';
    } else if (error.contains('user-disabled')) {
      return 'هذا الحساب موقوف، تواصل مع الإدارة';
    } else if (error.contains('too-many-requests')) {
      return 'تم تجاوز عدد المحاولات، حاول مجدداً لاحقاً';
    } else if (error.contains('network-request-failed')) {
      return 'تحقق من اتصالك بالإنترنت';
    } else if (error.contains('email-already-in-use')) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل';
    } else if (error.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً، استخدم 6 أحرف على الأقل';
    } else {
      return 'حدث خطأ، حاول مجدداً';
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset,
                      color: Color(0xFF2E7D32), size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'أدخل بريدك الإلكتروني وسنرسل لك رابط لإعادة تعيين كلمة المرور',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'البريد الإلكتروني',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFF2E7D32)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                  if (resetEmailController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'الرجاء إدخال البريد الإلكتروني'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  setDialogState(() => isSending = true);

                  try {
                    await AuthService.resetPassword(
                        resetEmailController.text.trim());

                    if (!mounted) return;
                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'تم إرسال رابط إعادة التعيين إلى بريدك'),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF2E7D32),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => isSending = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_getErrorMessage(e.toString())),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'إرسال',
                  style:
                  TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _bgController,
            _mainController,
          ]),
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(
                      isDark
                          ? const Color(0xFF0F0F1A)
                          : Colors.white,
                      isDark
                          ? const Color(0xFF1A3A1A)
                          : const Color(0xFFE8F5E9),
                      _bgFade.value,
                    )!,
                    isDark ? const Color(0xFF0F0F1A) : Colors.white,
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: isDesktop
            // ══════════════════════════════════
            //  Desktop Layout
            // ══════════════════════════════════
                ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      // ── Logo ──
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (_, child) {
                          return FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'القناعة',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2E7D32),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Grossiste',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 50),

                      // ── Form ──
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (_, child) {
                          return SlideTransition(
                            position: _formSlide,
                            child: FadeTransition(
                              opacity: _formFade,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            // Email
                            _buildField(
                              controller: emailController,
                              hint: 'البريد الإلكتروني',
                              icon: Icons.email_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            _buildField(
                              controller: passwordController,
                              hint: 'كلمة المرور',
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              obscure: obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                        () => obscurePassword = !obscurePassword),
                              ),
                            ),

                            // نسيت كلمة المرور
                            Align(
                              alignment: Alignment.centerLeft,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text(
                                    'نسيت كلمة المرور؟',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Button
                            _buildLoginButton(isDark),

                            const SizedBox(height: 24),

                            // إنشاء حساب جديد
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ليس لديك حساب؟',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        SlidePageRoute(
                                          page: RegisterScreen(
                                            onToggleDarkMode: widget.onToggleDarkMode,
                                            isDarkMode: widget.isDarkMode,
                                          ),
                                          direction: SlideDirection.fromBottom,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                        const Color(0xFF2E7D32).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF2E7D32)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Text(
                                        'إنشاء حساب جديد',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Dark Mode Toggle
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (_, child) {
                          return FadeTransition(
                            opacity: _formFade,
                            child: child,
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onToggleDarkMode,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isDark ? Icons.light_mode : Icons.dark_mode,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )

            // ══════════════════════════════════
            //  Mobile Layout
            // ══════════════════════════════════
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // ── Logo ──
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, child) {
                      return FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'القناعة',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2E7D32),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Grossiste',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  // ── Form ──
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, child) {
                      return SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(
                          opacity: _formFade,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        // Email
                        _buildField(
                          controller: emailController,
                          hint: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildField(
                          controller: passwordController,
                          hint: 'كلمة المرور',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          obscure: obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword),
                          ),
                        ),

                        // نسيت كلمة المرور
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Button
                        _buildLoginButton(isDark),

                        const SizedBox(height: 24),

                        // إنشاء حساب جديد
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ليس لديك حساب؟',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    SlidePageRoute(
                                      page: RegisterScreen(
                                        onToggleDarkMode: widget.onToggleDarkMode,
                                        isDarkMode: widget.isDarkMode,
                                      ),
                                      direction: SlideDirection.fromBottom,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                    const Color(0xFF2E7D32).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF2E7D32)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'إنشاء حساب جديد',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Dark Mode Toggle
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, child) {
                      return FadeTransition(
                        opacity: _formFade,
                        child: child,
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onToggleDarkMode,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDark ? Icons.light_mode : Icons.dark_mode,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _buttonController.forward(),
        onTapUp: (_) {
          _buttonController.reverse();
          _login();
        },
        onTapCancel: () => _buttonController.reverse(),
        child: ScaleTransition(
          scale: _buttonScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}