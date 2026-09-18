import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badges/badges.dart' as badges;
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../utils/page_transitions.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'user_main_screen.dart';
import 'printer_screen.dart';
import 'debts_screen.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const MainScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDarkMode,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {

  // ══════════════════════════════════
  //  State
  // ══════════════════════════════════
  List<Brand>   brands         = [];
  List<Brand>   filteredBrands = [];
  List<CartItem> cart          = [];
  List<Order>   recentOrders   = [];
  Map<String, dynamic> stats   = {};

  final searchController = TextEditingController();

  bool isLoading      = true;
  bool isStatsLoading = true;
  int  _currentNavIndex = 0;

  // ✅ Drawer (موبايل فقط) + بيانات الأدمن الحالي
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserModel? _adminUser;

  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double>   _fadeAnimation;

  final ScrollController _dashboardScroll = ScrollController();
  final ScrollController _brandsScroll    = ScrollController();
  final FocusNode _keyboardFocus          = FocusNode();

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  bool get isTablet  => MediaQuery.of(context).size.width >= 600;

  int _getCrossAxisCount() {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1400) return 8;
    if (w >= 1100) return 6;
    if (w >= 800)  return 5;
    if (w >= 600)  return 4;
    return 3;
  }

  ScrollController get _activeScroll =>
      _currentNavIndex == 2 ? _brandsScroll : _dashboardScroll;

  // ══════════════════════════════════
  //  Keyboard Handler
  // ══════════════════════════════════
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    final ctrl = _activeScroll;
    if (!ctrl.hasClients) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      ctrl.animateTo(
        (ctrl.offset + 80).clamp(0.0, ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowUp) {
      ctrl.animateTo(
        (ctrl.offset - 80).clamp(0.0, ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      ctrl.animateTo(
        (ctrl.offset + 400).clamp(0.0, ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      ctrl.animateTo(
        (ctrl.offset - 400).clamp(0.0, ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      ctrl.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.end) {
      ctrl.animateTo(ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  // ══════════════════════════════════
  //  Lifecycle
  // ══════════════════════════════════
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOutCubic);
    _loadAll();
    searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    searchController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    _dashboardScroll.dispose();
    _brandsScroll.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════
  //  Data Loading
  // ══════════════════════════════════
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { isLoading = true; isStatsLoading = true; });
    await Future.wait(
        [_loadBrands(), _loadStats(), _loadRecentOrders(), _loadAdminUser()]);
    if (mounted) _fadeController.forward(from: 0);
  }

  Future<void> _loadAdminUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) setState(() => _adminUser = user);
    } catch (e) {
      debugPrint('❌ _loadAdminUser: $e');
    }
  }

  Future<void> _loadBrands() async {
    try {
      final data = await DataService.getBrands();
      if (mounted) setState(() { brands = data; filteredBrands = data; isLoading = false; });
    } catch (e) {
      debugPrint('❌ _loadBrands: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await DataService.getStats();
      if (mounted) setState(() { stats = data; isStatsLoading = false; });
    } catch (e) {
      debugPrint('❌ _loadStats: $e');
      if (mounted) setState(() => isStatsLoading = false);
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final data = await DataService.getAllOrders();
      if (mounted) setState(() => recentOrders = data.take(10).toList());
    } catch (e) {
      debugPrint('❌ _loadRecentOrders: $e');
    }
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredBrands = q.isEmpty
          ? brands
          : brands.where((b) => b.name.toLowerCase().contains(q)).toList();
    });
  }

  // ══════════════════════════════════
  //  Actions
  // ══════════════════════════════════
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
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    cart.clear();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, FadeScaleRoute(
      page: LoginScreen(
          onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode),
    ));
  }

  Future<void> _previewAsUser() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted || user == null) return;
    Navigator.push(context, SlidePageRoute(
      page: UserMainScreen(
        user: user,
        onToggleDarkMode: widget.onToggleDarkMode,
        isDarkMode: widget.isDarkMode,
        isPreviewMode: true,
      ),
    ));
  }

  Future<void> _printOrder(Order order) async {
    if (!PrinterService.isConnected) {
      final connected = await Navigator.push<bool>(
          context, SlidePageRoute(page: const PrinterScreen()));
      if (connected != true || !mounted) return;
    }
    final success = await PrinterService.printReceipt(
      order: order,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? '✅ تم الطباعة بنجاح' : '❌ فشلت الطباعة — تحقق من الطابعة'),
      backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════
  //  Desktop Sidebar
  // ══════════════════════════════════
  Widget _buildDesktopSidebar(bool isDark) {
    final bg        = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final items = [
      {'icon': Icons.home_rounded,         'label': 'الرئيسية',     'index': 0},
      {'icon': Icons.receipt_long_rounded, 'label': 'الطلبات',      'index': 1},
      {'icon': Icons.store_rounded,        'label': 'المتجر',       'index': 2},
      {'icon': Icons.settings_rounded,     'label': 'الإعدادات',    'index': 3},
    ];

    return Container(
      width: 220,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(2, 0))],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
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
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.store_rounded, color: Colors.white, size: 28)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('القناعة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Text('لوحة التحكم',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          // ── Navigation Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final idx        = item['index'] as int;
                final isSelected = _currentNavIndex == idx;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2E7D32).withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3))
                            : null,
                      ),
                      child: Row(children: [
                        idx == 1
                            ? StreamBuilder<int>(
                          stream: DataService.getPendingOrdersCount(),
                          builder: (context, snap) {
                            final count = snap.data ?? 0;
                            return badges.Badge(
                              showBadge: count > 0,
                              badgeContent: Text('$count',
                                  style: const TextStyle(color: Colors.white, fontSize: 9)),
                              badgeStyle: const badges.BadgeStyle(
                                  badgeColor: Colors.red, padding: EdgeInsets.all(4)),
                              child: Icon(item['icon'] as IconData,
                                  color: isSelected
                                      ? const Color(0xFF2E7D32)
                                      : textColor.withOpacity(0.6),
                                  size: 22),
                            );
                          },
                        )
                            : Icon(item['icon'] as IconData,
                            color: isSelected
                                ? const Color(0xFF2E7D32)
                                : textColor.withOpacity(0.6),
                            size: 22),
                        const SizedBox(width: 12),
                        Text(item['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? const Color(0xFF2E7D32) : textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            )),
                        if (isSelected) ...[
                          const Spacer(),
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF2E7D32), shape: BoxShape.circle)),
                        ],
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Footer Actions ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _sidebarAction(Icons.account_balance_wallet_rounded, 'الزبائن',
                      () => Navigator.push(context, SlidePageRoute(page: const DebtsScreen())),
                  isDark),
              const SizedBox(height: 6),
              _sidebarAction(Icons.visibility_rounded, 'معاينة كزبون', _previewAsUser, isDark),
              const SizedBox(height: 6),
              _sidebarAction(
                widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                widget.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
                widget.onToggleDarkMode, isDark,
              ),
              const SizedBox(height: 6),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('تسجيل الخروج',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sidebarAction(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF2E7D32), size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                )),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  ✅ Drawer الأدمن (موبايل فقط)
  // ══════════════════════════════════
  Widget _buildAdminDrawer(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final name = _adminUser?.name ?? 'الأدمن';
    final email = _adminUser?.email ?? '';

    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'الرئيسية', 'index': 0},
      {'icon': Icons.receipt_long_rounded, 'label': 'الطلبات', 'index': 1},
      {'icon': Icons.store_rounded, 'label': 'المتجر', 'index': 2},
      {'icon': Icons.settings_rounded, 'label': 'الإعدادات', 'index': 3},
    ];

    return Drawer(
      backgroundColor: cardColor,
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 24),
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
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('لوحة الإدارة',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...navItems.map((item) {
                  final idx = item['index'] as int;
                  final isSelected = _currentNavIndex == idx;
                  return _drawerItem(
                    icon: item['icon'] as IconData,
                    label: item['label'] as String,
                    isDark: isDark,
                    textColor: textColor,
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentNavIndex = idx);
                    },
                  );
                }),
                Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 24),
                _drawerItem(
                  icon: Icons.shopping_cart_rounded,
                  label: cart.isEmpty
                      ? 'السلة'
                      : 'السلة (${cart.fold(0, (sum, item) => sum + item.quantity)})',
                  isDark: isDark,
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SlidePageRoute(
                      page: CartScreen(cart: cart, isAdmin: true),
                      direction: SlideDirection.fromBottom,
                    )).then((_) => setState(() {}));
                  },
                ),
                _drawerItem(
                  icon: Icons.people_alt_rounded,
                  label: 'الزبائن',
                  isDark: isDark,
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SlidePageRoute(page: const DebtsScreen()));
                  },
                ),
                _drawerItem(
                  icon: Icons.print_rounded,
                  label: 'الطابعة',
                  isDark: isDark,
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, SlidePageRoute(page: const PrinterScreen()))
                        .then((_) => setState(() {}));
                  },
                ),
                _drawerItem(
                  icon: Icons.visibility_rounded,
                  label: 'معاينة كزبون',
                  isDark: isDark,
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                    _previewAsUser();
                  },
                ),
                Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 24),
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
                          Switch(
                              value: isDark,
                              activeColor: Colors.amber,
                              onChanged: (_) => widget.onToggleDarkMode()),
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
                  _logout();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 22),
                      SizedBox(width: 10),
                      Text('تسجيل الخروج',
                          style: TextStyle(
                              color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold)),
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
    required IconData icon,
    required String label,
    required bool isDark,
    required Color textColor,
    required VoidCallback onTap,
    bool isSelected = false,
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
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDarkMode;
    final cartCount = cart.fold(0, (sum, item) => sum + item.quantity);

    final pages = [
      _buildDashboard(isDark),
      const OrdersScreen(),
      _buildBrandsTab(isDark),
      const AdminScreen(),
    ];

    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: isDesktop ? null : _buildAdminDrawer(isDark),

        appBar: isDesktop ? null : PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            automaticallyImplyLeading: false,
            leading: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.store_rounded, color: Colors.white, size: 22)),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('القناعة',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('لوحة التحكم',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),

        body: isDesktop
            ? Row(
          children: [
            _buildDesktopSidebar(isDark),
            Expanded(
              child: Column(
                children: [
                  // Desktop Top Bar
                  Container(
                    height: 56,
                    color: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          ['الرئيسية','الطلبات','المتجر','الإعدادات'][_currentNavIndex],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        const Spacer(),
                        MouseRegion(cursor: SystemMouseCursors.click,
                          child: badges.Badge(
                            badgeContent: Text('$cartCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10)),
                            showBadge: cart.isNotEmpty,
                            badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                            child: _AdminAppBarBtn(
                              icon: Icons.shopping_cart_outlined,
                              onTap: () => Navigator.push(context, SlidePageRoute(
                                page: CartScreen(cart: cart, isAdmin: true),
                                direction: SlideDirection.fromBottom,
                              )).then((_) => setState(() {})),
                            ),
                          ),
                        ),
                        MouseRegion(cursor: SystemMouseCursors.click,
                          child: _AdminAppBarBtn(
                            icon: PrinterService.isConnected
                                ? Icons.print_rounded
                                : Icons.print_outlined,
                            onTap: () => Navigator.push(
                                context, SlidePageRoute(page: const PrinterScreen()))
                                .then((_) => setState(() {})),
                            tooltip: PrinterService.isConnected
                                ? 'الطابعة متصلة'
                                : 'توصيل الطابعة',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: IndexedStack(index: _currentNavIndex, children: pages)),
                ],
              ),
            ),
          ],
        )
            : IndexedStack(index: _currentNavIndex, children: pages),

        bottomNavigationBar: isDesktop ? null : Container(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2))],
          ),
          child: NavigationBar(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (index) => setState(() => _currentNavIndex = index),
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            indicatorColor: const Color(0xFF2E7D32).withOpacity(0.15),
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0, height: 65,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF2E7D32)),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: StreamBuilder<int>(
                  stream: DataService.getPendingOrdersCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return badges.Badge(
                      showBadge: count > 0,
                      badgeContent: Text('$count',
                          style: const TextStyle(color: Colors.white, fontSize: 9)),
                      badgeStyle: const badges.BadgeStyle(
                          badgeColor: Colors.red, padding: EdgeInsets.all(4)),
                      child: Icon(Icons.receipt_long_outlined,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    );
                  },
                ),
                selectedIcon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2E7D32)),
                label: 'الطلبات',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.store_rounded, color: Color(0xFF2E7D32)),
                label: 'المتجر',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                selectedIcon: const Icon(Icons.settings_rounded, color: Color(0xFF2E7D32)),
                label: 'الإعدادات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Dashboard Tab
  // ══════════════════════════════════
  Widget _buildDashboard(bool isDark) {
    final cardBg    = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final pendingOrders = recentOrders.where((o) => o.status == 'pending').toList();
    final todayOrders   = stats['todayOrders'] ?? 0;
    final todaySales    = stats['todaySales']  ?? 0.0;

    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _loadAll,
      child: Scrollbar(
        controller: _dashboardScroll,
        thumbVisibility: isDesktop,
        child: SingleChildScrollView(
          controller: _dashboardScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 12,
            isDesktop ? 20 : 12,
            isDesktop ? 24 : 12,
            80,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: isDesktop
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(children: [
                        if (pendingOrders.isNotEmpty)
                          _buildAlertBanner(pendingOrders.length, isDark),
                        if (pendingOrders.isNotEmpty) const SizedBox(height: 12),
                        _buildSalesCard(todaySales, todayOrders, isDark),
                        const SizedBox(height: 16),
                        _buildSectionTitle('📊 نظرة سريعة', isDark),
                        const SizedBox(height: 8),
                        _buildStatsGrid(isDark, cardBg),
                      ]),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(children: [
                        _buildSectionTitle('🚀 إجراءات سريعة', isDark),
                        const SizedBox(height: 8),
                        _buildQuickActions(isDark, cardBg),
                        if (pendingOrders.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSectionTitle('🔴 طلبات تنتظر المراجعة', isDark),
                          const SizedBox(height: 8),
                          ...pendingOrders.take(5).map(
                                (order) => _buildOrderCard(
                                order, isDark, cardBg, textColor, subColor),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              ],
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingOrders.isNotEmpty)
                  _buildAlertBanner(pendingOrders.length, isDark),
                const SizedBox(height: 12),
                _buildSalesCard(todaySales, todayOrders, isDark),
                const SizedBox(height: 16),
                _buildSectionTitle('📊 نظرة سريعة', isDark),
                const SizedBox(height: 8),
                _buildStatsGrid(isDark, cardBg),
                const SizedBox(height: 16),
                _buildSectionTitle('🚀 إجراءات سريعة', isDark),
                const SizedBox(height: 8),
                _buildQuickActions(isDark, cardBg),
                const SizedBox(height: 16),
                if (pendingOrders.isNotEmpty) ...[
                  _buildSectionTitle('🔴 طلبات تنتظر المراجعة', isDark),
                  const SizedBox(height: 8),
                  ...pendingOrders.take(5).map(
                        (order) => _buildOrderCard(
                        order, isDark, cardBg, textColor, subColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBanner(int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withOpacity(0.15) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Row(children: [
        const Text('🔔', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$count طلبات جديدة تنتظر المراجعة',
              style: TextStyle(
                color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                fontWeight: FontWeight.bold, fontSize: 14,
              )),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _currentNavIndex = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('عرض',
                  style: TextStyle(
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                    fontWeight: FontWeight.bold, fontSize: 12,
                  )),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSalesCard(double sales, int orders, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💰 مبيعات اليوم',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text('${sales.toStringAsFixed(0)} DA',
              style: const TextStyle(
                  color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('$orders طلب اليوم',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.68,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 DA', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('68% من الهدف', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('66,000 DA', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ التعديل: childAspectRatio من 2.2 إلى 1.8
  Widget _buildStatsGrid(bool isDark, Color cardBg) {
    final pending   = recentOrders.where((o) => o.status == 'pending').length;
    final completed = recentOrders.where((o) => o.status == 'delivered').length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isDesktop ? 2.5 : 1.8, // ✅ تم التعديل
      children: [
        _buildStatCard('📦', '$pending', 'طلبات تنتظر', Colors.red, isDark, cardBg),
        _buildStatCard('✅', '$completed', 'طلبات مكتملة', const Color(0xFF2E7D32), isDark, cardBg),
        _buildStatCard('🏪', '${brands.length}', 'علامة تجارية', Colors.blue, isDark, cardBg),
        _buildStatCard('📋', '${stats['totalOrders'] ?? 0}', 'إجمالي الطلبات', Colors.purple, isDark, cardBg),
      ],
    );
  }

  // ✅ التعديل الرئيسي: إضافة height + Expanded + mainAxisSize.min
  Widget _buildStatCard(String icon, String value, String label,
      Color color, bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ✅ مهم جداً
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0, // ✅ يزيل المسافة الزائدة
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.2, // ✅ يزيل المسافة الزائدة
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, Color cardBg) {
    final actions = [
      {
        'icon': Icons.settings_rounded,
        'label': 'إدارة',
        'subtitle': 'الفئات، المنتجات، الطلبات، الإعلانات',
        'colors': const [Color(0xFF283593), Color(0xFF3949AB), Color(0xFF5C6BC0)],
        'onTap': () => Navigator.push(
            context, SlidePageRoute(page: const AdminScreen()))
            .then((_) => _loadAll()),
      },
      {
        'icon': Icons.print_rounded,
        'label': 'الطابعة',
        'subtitle': 'ربط وإدارة الطابعة الحرارية',
        'colors': const [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFFAB47BC)],
        'onTap': () => Navigator.push(
            context, SlidePageRoute(page: const PrinterScreen())),
      },
      {
        'icon': Icons.visibility_rounded,
        'label': 'معاينة',
        'subtitle': 'شاهد التطبيق كما يراه الزبون',
        'colors': const [Color(0xFFE65100), Color(0xFFEF6C00), Color(0xFFFF9800)],
        'onTap': () => _previewAsUser(),
      },
    ];

    return Column(
      children: [
        // ✅ بطاقة "الزبائن" — منفصلة لأنها تعرض شارة إجمالي الدين الحيّة
        _buildCustomersQuickAction(isDark, cardBg),
        const SizedBox(height: 10),
        ...actions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: action['onTap'] as VoidCallback,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: action['colors'] as List<Color>,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: (action['colors'] as List<Color>)[1]
                            .withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action['icon'] as IconData,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action['label'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(action['subtitle'] as String,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white70, size: 16),
                  ]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ✅ بطاقة "الزبائن" — نفس أسلوب البطاقات الجديد + شارة إجمالي الدين
  Widget _buildCustomersQuickAction(bool isDark, Color cardBg) {
    return StreamBuilder<List<CustomerModel>>(
      stream: DataService.getCustomersStream(),
      builder: (context, snapshot) {
        final totalDebt = (snapshot.data ?? const <CustomerModel>[])
            .fold<double>(0, (sum, c) => sum + c.balance);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.push(
                context, SlidePageRoute(page: const DebtsScreen())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFAD1457), Color(0xFFD81B60), Color(0xFFEC407A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFD81B60).withOpacity(0.35),
                    blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الزبائن',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        totalDebt > 0
                            ? 'إجمالي الدين: ${totalDebt.toStringAsFixed(0)} DA'
                            : 'دليل الزبائن وسجل الديون',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white70, size: 16),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order, bool isDark, Color cardBg,
      Color textColor, Color subColor) {
    Color statusColor;
    String statusLabel;
    switch (order.status) {
      case 'confirmed': statusColor = Colors.blue; statusLabel = 'مؤكد'; break;
      case 'delivered': statusColor = const Color(0xFF2E7D32); statusLabel = 'تم التسليم'; break;
      case 'cancelled': statusColor = Colors.red; statusLabel = 'ملغى'; break;
      default: statusColor = Colors.orange; statusLabel = 'قيد الانتظار';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(right: BorderSide(color: statusColor, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  order.customerName.isNotEmpty ? order.customerName[0] : '?',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.customerName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                Text('${order.items.length} منتج • ${order.customerPhone}',
                    style: TextStyle(fontSize: 11, color: subColor)),
                Text(_formatDate(order.createdAt),
                    style: TextStyle(fontSize: 11, color: subColor)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${order.total.toStringAsFixed(0)} DA',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32))),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: MouseRegion(cursor: SystemMouseCursors.click,
              child: _actionButton('✅ تأكيد', const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32), () async {
                    await DataService.updateOrderStatus(order.id, 'confirmed');
                    _loadRecentOrders();
                  }),
            )),
            const SizedBox(width: 6),
            Expanded(child: MouseRegion(cursor: SystemMouseCursors.click,
              child: _actionButton('❌ رفض', const Color(0xFFFFEBEE),
                  Colors.red, () async {
                    await DataService.updateOrderStatus(order.id, 'cancelled');
                    _loadRecentOrders();
                  }),
            )),
            const SizedBox(width: 6),
            Expanded(child: MouseRegion(cursor: SystemMouseCursors.click,
              child: _actionButton('🖨️ طباعة', const Color(0xFFE3F2FD),
                  Colors.blue, () => _printOrder(order)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _actionButton(String label, Color bg, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(children: [
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1,
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
    ]);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    final ctrl = _currentNavIndex == 1 ? _brandsScroll : _dashboardScroll;
    if (!ctrl.hasClients) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      ctrl.animateTo((ctrl.offset + 80).clamp(0.0, ctrl.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      ctrl.animateTo((ctrl.offset - 80).clamp(0.0, ctrl.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ══════════════════════════════════
  //  Brands Tab
  // ══════════════════════════════════
  Widget _buildBrandsTab(bool isDark) {
    final cardBg    = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final searchBg  = isDark ? const Color(0xFF2A2A3E) : Colors.white;

    return Column(children: [
      Container(
        color: const Color(0xFF2E7D32),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'ابحث عن علامة تجارية...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () { searchController.clear(); _onSearch(); })
                : null,
            filled: true, fillColor: searchBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.store_rounded, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text('العلامات التجارية',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${filteredBrands.length} علامة',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      Expanded(
        child: isLoading
            ? _buildShimmer(isDark)
            : filteredBrands.isEmpty
            ? _buildEmpty(isDark)
            : RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: _loadBrands,
          child: Scrollbar(
            controller: _brandsScroll,
            thumbVisibility: isDesktop,
            child: GridView.builder(
              controller: _brandsScroll,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _getCrossAxisCount(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: filteredBrands.length,
              itemBuilder: (context, index) => _AnimatedBrandCard(
                brand: filteredBrands[index],
                index: index,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                onTap: () => Navigator.push(context, SlidePageRoute(
                  page: ProductsScreen(
                      brand: filteredBrands[index], cart: cart, isAdmin: true),
                )).then((_) => setState(() {})),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildShimmer(bool isDark) {
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.9),
      itemCount: 6,
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
              color: baseColor, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.store_outlined, size: 80,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('لا توجد علامات تجارية',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey,
                fontSize: 16)),
      ]),
    );
  }
}

// ══════════════════════════════════
//  AppBar Button
// ══════════════════════════════════
class _AdminAppBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _AdminAppBarBtn({required this.icon, required this.onTap, this.tooltip});
  @override
  State<_AdminAppBarBtn> createState() => _AdminAppBarBtnState();
}

class _AdminAppBarBtnState extends State<_AdminAppBarBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
          onTapCancel: () => _ctrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 36, height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//  Brand Card
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + widget.index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.identity()..scale(_pressed ? 0.94 : 1.0),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: _pressed
                    ? const Color(0xFF2E7D32).withOpacity(0.3)
                    : Colors.black.withOpacity(widget.isDark ? 0.3 : 0.06),
                blurRadius: _pressed ? 16 : 8,
                offset: Offset(0, _pressed ? 6 : 3),
              )],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.brand.logoPath.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.brand.logoPath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.store, size: 28,
                        color: widget.isDark
                            ? Colors.green.shade400
                            : const Color(0xFF2E7D32)),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF2E7D32), strokeWidth: 2),
                      );
                    },
                  ),
                )
                    : Icon(Icons.store, size: 28,
                    color: widget.isDark
                        ? Colors.green.shade400
                        : const Color(0xFF2E7D32)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(widget.brand.name,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: _pressed
                            ? const Color(0xFF2E7D32)
                            : widget.textColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}