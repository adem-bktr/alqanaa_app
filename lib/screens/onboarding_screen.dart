import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/page_transitions.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const OnboardingScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDarkMode,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _animController;
  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.storefront_rounded,
      emoji: '🛒',
      title: 'اكتشف منتجاتنا',
      subtitle: 'تشكيلة واسعة من أفضل الماركات\nبأسعار الجملة المميزة',
      gradient: [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
      lightBg: const Color(0xFFE8F5E9),
    ),
    _OnboardingData(
      icon: Icons.shopping_cart_checkout_rounded,
      emoji: '📦',
      title: 'اطلب بسهولة',
      subtitle: 'أضف المنتجات للسلة\nوأكد طلبك في ثوانٍ',
      gradient: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
      lightBg: const Color(0xFFE3F2FD),
    ),
    _OnboardingData(
      icon: Icons.local_shipping_rounded,
      emoji: '🚚',
      title: 'توصيل سريع',
      subtitle: 'نوصل لباب متجرك\nفي أسرع وقت ممكن',
      gradient: [const Color(0xFF6A1B9A), const Color(0xFF7B1FA2)],
      lightBg: const Color(0xFFF3E5F5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _iconController, curve: Curves.elasticOut),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeIn),
    );
    _animController.forward();
    _iconController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconController.reset();
    _iconController.forward();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      FadeScaleRoute(
        page: LoginScreen(
          onToggleDarkMode: widget.onToggleDarkMode,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = _pages[_currentPage];
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : page.lightBg,
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopLayout(isDark, page)
            : _buildMobileLayout(isDark, page),
      ),
    );
  }

  // ══════════════════════════════════
  //  Desktop Layout
  // ══════════════════════════════════
  Widget _buildDesktopLayout(bool isDark, _OnboardingData page) {
    return Row(
      children: [
        // ── الجانب الأيسر: الأيقونة والعنوان ──
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ اللوغو
                ScaleTransition(
                  scale: _iconScale,
                  child: FadeTransition(
                    opacity: _iconFade,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(page.emoji,
                                  style: const TextStyle(fontSize: 80)),
                              const SizedBox(height: 4),
                              Icon(page.icon,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 36),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // العنوان
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: child,
                  ),
                  child: Text(
                    page.title,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // الوصف
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: child,
                  ),
                  child: Text(
                    page.subtitle,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── الجانب الأيمن: التنقل ──
        Expanded(
          flex: 4,
          child: Container(
            color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ الشعار في الجانب الأيمن
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: page.gradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.store_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'مرحباً بك في القناعة',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'تصفح الشاشات واكتشف ما يميزنا',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),

                // مؤشر الصفحات
                Row(
                  children: List.generate(
                    _pages.length,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      width: _currentPage == index ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? page.gradient[0]
                            : (isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // أزرار التنقل
                Row(
                  children: [
                    // زر التخطي
                    if (_currentPage < _pages.length - 1)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skip,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: page.gradient[0]),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'تخطي',
                            style: TextStyle(
                              color: page.gradient[0],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage < _pages.length - 1)
                      const SizedBox(width: 16),

                    // زر التالي / ابدأ
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: page.gradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: page.gradient[0].withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'ابدأ الآن'
                                    : 'التالي',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  _currentPage == _pages.length - 1
                                      ? Icons.rocket_launch_rounded
                                      : Icons.arrow_forward_rounded,
                                  key: ValueKey(_currentPage),
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // PageView مخفي للتنقل
                SizedBox(
                  height: 0,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (_, __) => const SizedBox(),
                  ),
                ),

                // أزرار الصفحات المباشرة
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                        (index) => MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _pages[index].emoji,
                            style: TextStyle(
                              fontSize: _currentPage == index ? 28 : 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════
  //  Mobile Layout
  // ══════════════════════════════════
  Widget _buildMobileLayout(bool isDark, _OnboardingData page) {
    return Column(
      children: [
        // ── زر التخطي ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  _pages.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? page.gradient[0]
                          : (isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              if (_currentPage < _pages.length - 1)
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    'تخطي',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const SizedBox(width: 60),
            ],
          ),
        ),

        // ── المحتوى ──
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _OnboardingPage(
                data: _pages[index],
                isDark: isDark,
                iconScale: _iconScale,
                iconFade: _iconFade,
              );
            },
          ),
        ),

        // ── زر التالي ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: page.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient[0].withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentPage == _pages.length - 1
                          ? 'ابدأ الآن'
                          : 'التالي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _currentPage == _pages.length - 1
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        key: ValueKey(_currentPage),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════
// صفحة onboarding واحدة
// ══════════════════════════════════
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final bool isDark;
  final Animation<double> iconScale;
  final Animation<double> iconFade;

  const _OnboardingPage({
    required this.data,
    required this.isDark,
    required this.iconScale,
    required this.iconFade,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ اللوغو في Mobile
          ScaleTransition(
            scale: iconScale,
            child: FadeTransition(
              opacity: iconFade,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient[0].withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(data.emoji,
                            style: const TextStyle(fontSize: 60)),
                        const SizedBox(height: 4),
                        Icon(data.icon,
                            color: Colors.white.withOpacity(0.4),
                            size: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            ),
            child: Text(
              data.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            ),
            child: Text(
              data.subtitle,
              style: TextStyle(
                fontSize: 16,
                color: subColor,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════
// نموذج البيانات
// ══════════════════════════════════
class _OnboardingData {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color lightBg;

  const _OnboardingData({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.lightBg,
  });
}