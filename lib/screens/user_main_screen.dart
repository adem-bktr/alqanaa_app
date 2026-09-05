import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../utils/page_transitions.dart';
import 'products_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'user_orders_screen.dart';
import 'login_screen.dart';
import 'category_products_screen.dart';
import 'profile_screen.dart';
import 'contact_screen.dart';

class UserMainScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;
  final bool isPreviewMode;

  const UserMainScreen({
    super.key,
    required this.user,
    required this.onToggleDarkMode,
    required this.isDarkMode,
    this.isPreviewMode = false,
  });

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen>
    with TickerProviderStateMixin {

  List<Brand>       brands      = [];
  List<Category>    categories  = [];
  List<Product>     allProducts = [];
  List<BannerModel> banners     = [];
  List<CartItem>    cart        = [];
  final searchController = TextEditingController();
  bool isLoading         = true;
  bool isProductsLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _headerController;
  late AnimationController _searchController2;
  late AnimationController _welcomeController;
  late AnimationController _shimmerController;
  late AnimationController _fabPulseController;
  late AnimationController _scrollToTopController;

  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _searchSlide;
  late Animation<double> _searchFade;
  late Animation<Offset> _welcomeSlide;
  late Animation<double> _welcomeFade;
  late Animation<double> _fabPulse;
  late Animation<double> _scrollToTopFade;

  int  _currentNavIndex   = 0;
  int  _currentBannerIndex = 0;
  bool _showScrollToTop   = false;

  final ScrollController _scrollController      = ScrollController();
  final ScrollController _brandsScrollController = ScrollController();
  // ✅ FocusNode للتمرير بالأسهم
  final FocusNode _keyboardFocusNode = FocusNode();

  late PageController _bannerController;

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 8;
    if (width >= 1100) return 6;
    if (width >= 800)  return 5;
    if (width >= 600)  return 4;
    return 3;
  }

  // ✅ ScrollController الحالي حسب التبويب
  ScrollController get _activeScrollController {
    if (_currentNavIndex == 1) return _brandsScrollController;
    return _scrollController;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    loadBrands();
    loadCategories();
    loadAllProducts();
    loadBanners();
    if (!widget.isPreviewMode) _loadSavedCart();
    searchController.addListener(_onSearch);
    _scrollController.addListener(_onScroll);
    _bannerController = PageController();
    _startBannerAutoPlay();
  }

  // ══════════════════════════════════
  //  ✅ معالج لوحة المفاتيح
  // ══════════════════════════════════
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key        = event.logicalKey;
    final controller = _activeScrollController;
    if (!controller.hasClients) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      controller.animateTo(
        (controller.offset + 80).clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowUp) {
      controller.animateTo(
        (controller.offset - 80).clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      controller.animateTo(
        (controller.offset + 400).clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      controller.animateTo(
        (controller.offset - 400).clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      controller.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.end) {
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadSavedCart() async {
    try {
      final savedCart = await CartService.loadCart();
      if (savedCart.isNotEmpty && mounted) {
        setState(() => cart = savedCart);
      }
    } catch (e) {
      debugPrint('⚠️ فشل استعادة السلة: $e');
    }
  }

  Future<void> loadBrands() async {
    setState(() => isLoading = true);
    try {
      final data = await DataService.getBrands();
      if (mounted) setState(() { brands = data; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadCategories() async {
    try {
      final data = await DataService.getCategories();
      if (mounted) setState(() => categories = data);
    } catch (e) {
      debugPrint('❌ loadCategories: $e');
    }
  }

  Future<void> loadAllProducts() async {
    setState(() => isProductsLoading = true);
    try {
      final data = await DataService.getAllProducts();
      if (mounted) setState(() { allProducts = data; isProductsLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isProductsLoading = false);
    }
  }

  Future<void> loadBanners() async {
    try {
      final data = await DataService.getBanners();
      if (mounted) setState(() => banners = data);
    } catch (e) {
      debugPrint('❌ loadBanners: $e');
    }
  }

  void _startBannerAutoPlay() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      final displayBanners = banners.isEmpty ? _getDefaultBanners() : banners;
      if (displayBanners.isEmpty) return true;
      final next = (_currentBannerIndex + 1) % displayBanners.length;
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(next,
            duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      return true;
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 300 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
      _scrollToTopController.forward();
    } else if (_scrollController.offset <= 300 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
      _scrollToTopController.reverse();
    }
  }

  void _scrollToTop() {
    _activeScrollController.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  void _setupAnimations() {
    _headerController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _searchController2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _welcomeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

    _headerSlide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    _headerFade  = Tween<double>(begin: 0.0, end: 1.0).animate(_headerController);
    _searchSlide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _searchController2, curve: Curves.easeOutCubic));
    _searchFade  = Tween<double>(begin: 0.0, end: 1.0).animate(_searchController2);
    _welcomeSlide = Tween<Offset>(begin: const Offset(-0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _welcomeController, curve: Curves.easeOutCubic));
    _welcomeFade  = Tween<double>(begin: 0.0, end: 1.0).animate(_welcomeController);

    _fabPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _fabPulse = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut));

    _scrollToTopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scrollToTopFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scrollToTopController, curve: Curves.easeInOut));
  }

  void _startAnimations() async {
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _searchController2.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _welcomeController.forward();
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    _brandsScrollController.dispose();
    _bannerController.dispose();
    _keyboardFocusNode.dispose();
    _headerController.dispose();
    _searchController2.dispose();
    _welcomeController.dispose();
    _shimmerController.dispose();
    _fabPulseController.dispose();
    _scrollToTopController.dispose();
    super.dispose();
  }

  void _onSearch() => setState(() {});

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:0666629473');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إجراء الاتصال')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
        ]),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    cart.clear();
    await CartService.clearCart();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, FadeScaleRoute(
      page: LoginScreen(onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode),
    ));
  }

  // ══════════════════════════════════
  //  Drawer
  // ══════════════════════════════════
  Widget _buildDrawer(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: cardColor,
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.user.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.user.email,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                if (widget.isPreviewMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, color: Colors.orange, size: 14),
                        SizedBox(width: 4),
                        Text('وضع المعاينة',
                            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                if (widget.user.isSpecial && !widget.isPreviewMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text('مميز', style: TextStyle(
                            color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(icon: Icons.home_rounded, label: 'الرئيسية', isDark: isDark,
                    textColor: textColor, isSelected: _currentNavIndex == 0,
                    onTap: () { Navigator.pop(context); setState(() => _currentNavIndex = 0); }),
                _drawerItem(icon: Icons.store_rounded, label: 'العلامات التجارية', isDark: isDark,
                    textColor: textColor, isSelected: _currentNavIndex == 1,
                    onTap: () { Navigator.pop(context); setState(() => _currentNavIndex = 1); }),
                if (!widget.isPreviewMode)
                  _drawerItem(icon: Icons.receipt_long_rounded, label: 'طلباتي', isDark: isDark,
                      textColor: textColor, isSelected: _currentNavIndex == 2,
                      onTap: () { Navigator.pop(context); setState(() => _currentNavIndex = 2); }),
                Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 24),
                if (!widget.isPreviewMode) ...[
                  _drawerItem(icon: Icons.person_rounded, label: 'الملف الشخصي', isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, SlidePageRoute(page: ProfileScreen(user: widget.user)));
                      }),
                  _drawerItem(icon: Icons.headset_mic_rounded, label: 'تواصل معنا', isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, SlidePageRoute(page: const ContactScreen()));
                      }),
                  Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 24),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onToggleDarkMode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.amber.withOpacity(0.15)
                                  : Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                color: isDark ? Colors.amber : Colors.indigo, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Text(isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                              style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Switch(value: isDark, activeColor: Colors.amber, onChanged: (_) => widget.onToggleDarkMode()),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.isPreviewMode) Navigator.pop(context);
                  else _logout();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: widget.isPreviewMode
                        ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: widget.isPreviewMode
                            ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isPreviewMode ? Icons.arrow_back_rounded : Icons.logout_rounded,
                        color: widget.isPreviewMode ? Colors.orange : Colors.red, size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.isPreviewMode ? 'الرجوع للوحة الأدمن' : 'تسجيل الخروج',
                        style: TextStyle(
                            color: widget.isPreviewMode ? Colors.orange : Colors.red,
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon, required String label, required bool isDark,
    required Color textColor, required VoidCallback onTap, bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2E7D32).withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)) : null,
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E7D32).withOpacity(0.15)
                      : isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: isSelected ? const Color(0xFF2E7D32) : textColor.withOpacity(0.7), size: 22),
              ),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(
                fontSize: 15,
                color: isSelected ? const Color(0xFF2E7D32) : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              )),
              if (isSelected) ...[
                const Spacer(),
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  شريط المعاينة
  // ══════════════════════════════════
  Widget _buildPreviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange,
      child: Row(children: [
        const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('وضع المعاينة — ترى التطبيق كالزبون',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('رجوع',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════
  //  Announcement Banner
  // ══════════════════════════════════
  Widget _buildAnnouncementBanner() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: DataService.getAnnouncementsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final announcements = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: announcements.map((announcement) {
              Color bgColor, borderColor, textColor;
              IconData icon;
              switch (announcement.type) {
                case 'warning':
                  bgColor = const Color(0xFFFFF3E0); borderColor = Colors.orange;
                  textColor = Colors.orange.shade800; icon = Icons.warning_amber_rounded; break;
                case 'offer':
                  bgColor = const Color(0xFFFFEBEE); borderColor = Colors.red;
                  textColor = Colors.red.shade700; icon = Icons.local_offer; break;
                case 'info':
                  bgColor = const Color(0xFFE3F2FD); borderColor = Colors.blue;
                  textColor = Colors.blue.shade700; icon = Icons.info_outline; break;
                default:
                  bgColor = const Color(0xFFE8F5E9); borderColor = const Color(0xFF2E7D32);
                  textColor = const Color(0xFF2E7D32); icon = Icons.campaign;
              }
              final isDark = Theme.of(context).brightness == Brightness.dark;
              if (isDark) bgColor = borderColor.withOpacity(0.15);
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
                ),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(icon, color: borderColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(announcement.message,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                          textDirection: TextDirection.rtl)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════
  //  Banner Slider
  // ══════════════════════════════════
  Widget _buildBannerSlider() {
    final displayBanners = banners.isEmpty ? _getDefaultBanners() : banners;
    if (displayBanners.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      SizedBox(
        height: 170,
        child: PageView.builder(
          controller: _bannerController,
          onPageChanged: (index) => setState(() => _currentBannerIndex = index),
          itemCount: displayBanners.length,
          itemBuilder: (context, index) {
            final banner = displayBanners[index];
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: banner.color.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(children: [
                  if (banner.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: banner.imageUrl, width: double.infinity, height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildBannerBg(banner),
                      errorWidget: (_, __, ___) => _buildBannerBg(banner),
                    )
                  else _buildBannerBg(banner),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  _buildBannerContent(banner),
                ]),
              ),
            );
          },
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          displayBanners.length,
              (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            width: _currentBannerIndex == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: _currentBannerIndex == index ? const Color(0xFF2E7D32) : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBannerBg(BannerModel banner) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [banner.color, banner.color.withOpacity(0.7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
  );

  Widget _buildBannerContent(BannerModel banner) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(banner.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(banner.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    textDirection: TextDirection.rtl),
                const SizedBox(height: 6),
                Text(banner.subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                    textDirection: TextDirection.rtl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BannerModel> _getDefaultBanners() => [
    BannerModel(id: '1', title: 'عروض حصرية هذا الأسبوع', subtitle: 'خصومات تصل إلى 50%',
        color: const Color(0xFF1B5E20), icon: Icons.local_offer),
    BannerModel(id: '2', title: 'منتجات جديدة', subtitle: 'تشكيلة واسعة من أفضل الماركات',
        color: const Color(0xFF2E7D32), icon: Icons.new_releases),
    BannerModel(id: '3', title: 'توصيل سريع', subtitle: 'لجميع المناطق',
        color: const Color(0xFF388E3C), icon: Icons.delivery_dining),
  ];

  // ══════════════════════════════════
  //  الفئات
  // ══════════════════════════════════
  Widget _buildCategoriesRow(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.grid_view_rounded, color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            Text('الفئات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
      SizedBox(
        height: 110,
        child: categories.isEmpty
            ? _buildCategoriesShimmer(isDark)
            : ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                  SlidePageRoute(page: CategoryProductsScreen(
                      category: cat, cart: cart, user: widget.user)),
                ).then((_) async {
                  setState(() {});
                  if (!widget.isPreviewMode) await CartService.saveCart(cart);
                }),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + index * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
                  ),
                  child: Container(
                    width: 90, margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 34)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(cat.name,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildCategoriesShimmer(bool isDark) {
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 90, margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // ══════════════════════════════════
  //  جميع المنتجات
  // ══════════════════════════════════
  Widget _buildAllProductsSection(bool isDark) {
    final cardBg    = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final q         = searchController.text.toLowerCase();
    final filtered  = q.isEmpty ? allProducts : allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    final crossAxisCount = _getCrossAxisCount(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.inventory_2_rounded, color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            Text('جميع المنتجات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${filtered.length} منتج',
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      isProductsLoading
          ? _buildShimmerLoading(isDark)
          : filtered.isEmpty
          ? _buildEmptyProducts(isDark)
          : GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final product = filtered[index];
          return _ProductMiniCard(
            product: product, index: index, isDark: isDark,
            cardBg: cardBg, textColor: textColor,
            onTap: () => Navigator.push(context,
              SlidePageRoute(page: ProductDetailScreen(
                product: product, cart: cart,
                isSpecialPrice: widget.user.isSpecial, currentUser: widget.user,
              )),
            ).then((_) async {
              setState(() {});
              if (!widget.isPreviewMode) await CartService.saveCart(cart);
            }),
          );
        },
      ),
    ]);
  }

  Widget _buildEmptyProducts(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: 60,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('لا توجد منتجات',
            style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 15)),
      ]),
    ),
  );

  // ══════════════════════════════════
  //  تبويب الرئيسية
  // ══════════════════════════════════
  Widget _buildHomeTab() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final searchBg  = isDark ? const Color(0xFF2A2A3E) : Colors.white;

    return Column(children: [
      if (widget.isPreviewMode) _buildPreviewBanner(),
      SlideTransition(
        position: _searchSlide,
        child: FadeTransition(
          opacity: _searchFade,
          child: Container(
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              SlideTransition(
                position: _welcomeSlide,
                child: FadeTransition(
                  opacity: _welcomeFade,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            widget.isPreviewMode ? 'معاينة كالزبون 👁️' : 'مرحباً ${widget.user.name}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (widget.user.isSpecial && !widget.isPreviewMode)
                            Text('زبون مميز ⭐',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                          if (widget.isPreviewMode)
                            Text('ترى التطبيق كما يراه الزبون',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                        ]),
                      ),
                      if (widget.user.isSpecial && !widget.isPreviewMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                          child: const Text('مميز',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ]),
                  ),
                ),
              ),
              TextField(
                controller: searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded),
                      onPressed: () { searchController.clear(); setState(() {}); })
                      : null,
                  filled: true, fillColor: searchBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ]),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: () async {
            await loadAllProducts();
            await loadBanners();
            await loadCategories();
          },
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                _buildAnnouncementBanner(),
                _buildBannerSlider(),
                _buildCategoriesRow(isDark),
                _buildAllProductsSection(isDark),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════
  //  تبويب العلامات التجارية
  // ══════════════════════════════════
  Widget _buildBrandsTab() {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final cardBg         = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor      = isDark ? Colors.white : Colors.black87;
    final searchBg       = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final q              = searchController.text.toLowerCase();
    final filteredBrands = q.isEmpty ? brands : brands.where((b) => b.name.toLowerCase().contains(q)).toList();

    return Column(children: [
      if (widget.isPreviewMode) _buildPreviewBanner(),
      Container(
        color: const Color(0xFF2E7D32),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'بحث عن علامة تجارية...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded),
                onPressed: () { searchController.clear(); setState(() {}); })
                : null,
            filled: true, fillColor: searchBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.store_rounded, color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            Text('العلامات التجارية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${filteredBrands.length} علامة',
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      Expanded(
        child: isLoading
            ? _buildShimmerLoading(isDark)
            : filteredBrands.isEmpty
            ? _buildEmpty(isDark)
            : RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: loadBrands,
          child: Scrollbar(
            controller: _brandsScrollController,
            thumbVisibility: true,
            child: GridView.builder(
              controller: _brandsScrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
              itemCount: filteredBrands.length,
              itemBuilder: (context, index) => _AnimatedBrandCard(
                brand: filteredBrands[index], index: index, isDark: isDark,
                cardBg: cardBg, textColor: textColor,
                onTap: () => Navigator.push(context,
                  SlidePageRoute(page: ProductsScreen(
                      brand: filteredBrands[index], cart: cart, isAdmin: false, user: widget.user)),
                ).then((_) async {
                  setState(() {});
                  if (!widget.isPreviewMode) await CartService.saveCart(cart);
                }),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════
  //  Build
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cartCount = cart.fold(0, (sum, item) => sum + item.quantity);

    // ✅ KeyboardListener يغلف كل الشاشة
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildDrawer(isDark),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerFade,
              child: AppBar(
                backgroundColor: widget.isPreviewMode
                    ? Colors.orange.shade700 : const Color(0xFF2E7D32),
                automaticallyImplyLeading: false,
                leading: widget.isPreviewMode
                    ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
                    : _AppBarBtn(
                  icon: Icons.menu_rounded,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.isPreviewMode) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset('assets/logo.png', width: 32, height: 32, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.store_rounded, color: Colors.white, size: 28)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.isPreviewMode ? '👁️ وضع المعاينة' : 'القناعة',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
                centerTitle: true,
                actions: [
                  if (!widget.isPreviewMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: badges.Badge(
                          position: badges.BadgePosition.topEnd(top: 2, end: 2),
                          badgeContent: Text('$cartCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10)),
                          showBadge: cart.isNotEmpty,
                          badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                          child: IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
                            onPressed: () => Navigator.push(context,
                              SlidePageRoute(
                                page: CartScreen(cart: cart, isAdmin: false, user: widget.user),
                                direction: SlideDirection.fromBottom,
                              ),
                            ).then((_) => setState(() {})),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: widget.isPreviewMode
            ? null
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _scrollToTopFade,
              child: _showScrollToTop
                  ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _scrollToTop,
                  child: Container(
                    width: 42, height: 42,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFF2E7D32), size: 26),
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
            ScaleTransition(
              scale: _fabPulse,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: FloatingActionButton(
                  onPressed: _makeCall,
                  backgroundColor: const Color(0xFF2E7D32),
                  elevation: 8,
                  child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: NavigationBar(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (index) => setState(() => _currentNavIndex = index),
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            indicatorColor: widget.isPreviewMode
                ? Colors.orange.withOpacity(0.15) : const Color(0xFF2E7D32).withOpacity(0.15),
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0, height: 65,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 400),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: Icon(Icons.home_rounded,
                    color: widget.isPreviewMode ? Colors.orange : const Color(0xFF2E7D32)),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: Icon(Icons.store_rounded,
                    color: widget.isPreviewMode ? Colors.orange : const Color(0xFF2E7D32)),
                label: 'العلامات',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: Icon(Icons.receipt_long_rounded,
                    color: widget.isPreviewMode ? Colors.orange : const Color(0xFF2E7D32)),
                label: 'طلباتي',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _currentNavIndex,
            children: [
              _buildHomeTab(),
              _buildBrandsTab(),
              widget.isPreviewMode
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off_rounded, size: 80,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('طلباتي غير متاحة في وضع المعاينة',
                        style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            fontSize: 15)),
                  ],
                ),
              )
                  : _KeepAliveWrapper(child: UserOrdersScreen(userId: widget.user.id)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor      = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    final highlightColor = isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100;
    final crossAxisCount = _getCrossAxisCount(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
      itemCount: crossAxisCount * 2,
      itemBuilder: (context, index) => AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final shimmerValue = _shimmerController.value;
          const shimmerWidth = 0.3;
          final left = (shimmerValue * (1 + shimmerWidth)) - shimmerWidth;
          return Container(
            decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _shimmerBox(50, 50, baseColor, isCircle: true),
                  const SizedBox(height: 10),
                  _shimmerBox(60, 10, baseColor),
                ]),
                FractionallySizedBox(
                  widthFactor: shimmerWidth,
                  child: Align(
                    alignment: Alignment(-1.0 + (left / shimmerWidth) * 2, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          highlightColor.withValues(alpha: 0),
                          highlightColor.withValues(alpha: 0.4),
                          highlightColor.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerBox(double w, double h, Color color, {bool isCircle = false}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: color,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : BorderRadius.circular(6),
    ),
  );

  Widget _buildEmpty(bool isDark) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.store_outlined, size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('لا توجد علامات تجارية',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 16)),
      ],
    ),
  );
}

// ══════════════════════════════════
//  KeepAlive
// ══════════════════════════════════
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});
  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ══════════════════════════════════
//  بطاقة منتج صغيرة
// ══════════════════════════════════
class _ProductMiniCard extends StatefulWidget {
  final Product product;
  final int index;
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final VoidCallback onTap;

  const _ProductMiniCard({
    required this.product, required this.index, required this.isDark,
    required this.cardBg, required this.textColor, required this.onTap,
  });

  @override
  State<_ProductMiniCard> createState() => _ProductMiniCardState();
}

class _ProductMiniCardState extends State<_ProductMiniCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (widget.index % 10) * 40),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: MouseRegion(
        // ✅ تغيير شكل الفأرة على بطاقة المنتج
        cursor: widget.product.isAvailable
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.identity()..scale(_pressed ? 0.95 : 1.0),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.08),
                  blurRadius: _pressed ? 4 : 10,
                  offset: Offset(0, _pressed ? 1 : 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.product.imagePath.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: widget.product.imagePath, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: const Color(0xFFE8F5E9),
                              child: const Center(child: CircularProgressIndicator(
                                  color: Color(0xFF2E7D32), strokeWidth: 2))),
                          errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFE8F5E9),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: Color(0xFF2E7D32), size: 32)),
                        )
                            : Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Center(child: Icon(Icons.inventory_2_rounded,
                                color: Color(0xFF2E7D32), size: 32))),
                        if (widget.product.discount > 0)
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                              child: Text('-${widget.product.discount.toInt()}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (!widget.product.isAvailable)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Center(child: Text('غير متوفر',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.product.name,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.textColor),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right, textDirection: TextDirection.rtl),
                        const SizedBox(height: 3),
                        Text('${widget.product.priceCartonNormal.toStringAsFixed(0)} DA',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            textDirection: TextDirection.rtl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//  AppBar Button
// ══════════════════════════════════
class _AppBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});
  @override
  State<_AppBarBtn> createState() => _AppBarBtnState();
}

class _AppBarBtnState extends State<_AppBarBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(widget.icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//  Animated Brand Card
// ══════════════════════════════════
class _AnimatedBrandCard extends StatefulWidget {
  final Brand brand;
  final int index;
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final VoidCallback onTap;

  const _AnimatedBrandCard({
    required this.brand, required this.index, required this.isDark,
    required this.cardBg, required this.textColor, required this.onTap,
  });

  @override
  State<_AnimatedBrandCard> createState() => _AnimatedBrandCardState();
}

class _AnimatedBrandCardState extends State<_AnimatedBrandCard> {
  double _rotateX = 0.0;
  double _rotateY = 0.0;

  void _onPanUpdate(DragUpdateDetails details) {
    final box  = context.findRenderObject() as RenderBox;
    final size = box.size;
    setState(() {
      _rotateX = (details.localPosition.dy - (size.height / 2)) / (size.height / 2) * -0.12;
      _rotateY = (details.localPosition.dx - (size.width / 2))  / (size.width / 2)  *  0.12;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + widget.index * 50),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: MouseRegion(
        // ✅ تغيير شكل الفأرة على بطاقة العلامة
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => setState(() { _rotateX = 0.0; _rotateY = 0.0; }),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotateX)
              ..rotateY(_rotateY),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08),
                  blurRadius: 10, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.brand.logoPath.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.brand.logoPath, width: 56, height: 56, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                    const Icon(Icons.store_rounded, size: 32, color: Color(0xFF2E7D32)),
                  ),
                )
                    : const Icon(Icons.store_rounded, size: 32, color: Color(0xFF2E7D32)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(widget.brand.name,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
