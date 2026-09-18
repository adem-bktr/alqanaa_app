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
import 'stats_screen.dart';
import 'scan_invoice_screen.dart';

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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // ── State ──
  List<Brand> brands = [];
  List<Brand> filteredBrands = [];
  List<CartItem> cart = [];
  List<Order> recentOrders = [];
  Map<String, dynamic> stats = {};

  final searchController = TextEditingController();
  final _storeSearchCtrl = TextEditingController();

  bool isLoading = true;
  bool isStatsLoading = true;
  int _currentNavIndex = 0;
  bool isSpecialPrice = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  UserModel? _adminUser;

  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final ScrollController _dashboardScroll = ScrollController();
  final ScrollController _brandsScroll = ScrollController();
  final FocusNode _keyboardFocus = FocusNode();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

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
    _storeSearchCtrl.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    _dashboardScroll.dispose();
    _brandsScroll.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { isLoading = true; isStatsLoading = true; });
    await Future.wait([
      _loadBrands(),
      _loadStats(),
      _loadRecentOrders(),
      _loadAdminUser()
    ]);
    if (mounted) {
      _fadeController.forward(from: 0);
      _applyStoreFilter(); // Initial filter
    }
  }

  Future<void> _loadAdminUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) setState(() => _adminUser = user);
    } catch (_) {}
  }

  Future<void> _loadBrands() async {
    try {
      final data = await DataService.getBrands();
      if (mounted) {
        setState(() {
          brands = data;
          filteredBrands = data;
          isLoading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _loadStats() async {
    try {
      final data = await DataService.getStats();
      final special = await DataService.getIsSpecialPrice();
      if (mounted) {
        setState(() {
          stats = data;
          isSpecialPrice = special;
          isStatsLoading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => isStatsLoading = false); }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final data = await DataService.getAllOrders();
      if (mounted) setState(() => recentOrders = data.take(10).toList());
    } catch (_) {}
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredBrands = q.isEmpty
          ? brands
          : brands.where((b) => b.name.toLowerCase().contains(q)).toList();
    });
  }

  void _applyStoreFilter() async {
    final q = _storeSearchCtrl.text.toLowerCase();
    final p = await DataService.getAllProducts();
    if (mounted) {
      setState(() {
        _allProducts = p;
        _storeFilteredProducts = _allProducts.where((prod) {
          final matchesBrand = _selectedBrandId.isEmpty || prod.brandId == _selectedBrandId;
          final matchesSearch = q.isEmpty || prod.name.toLowerCase().contains(q);
          return matchesBrand && matchesSearch;
        }).toList();
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, FadeScaleRoute(page: LoginScreen(onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode)));
  }

  Future<void> _previewAsUser() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted || user == null) return;
    Navigator.push(context, SlidePageRoute(page: UserMainScreen(user: user, onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode, isPreviewMode: true)));
  }

  Future<void> _printOrder(Order order) async {
    if (!PrinterService.isConnected) {
      await Navigator.push(context, SlidePageRoute(page: const PrinterScreen()));
    }
    await PrinterService.printReceipt(order: order, customerName: order.customerName, customerPhone: order.customerPhone);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final ctrl = _currentNavIndex == 1 ? _brandsScroll : _dashboardScroll;
    if (!ctrl.hasClients) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ctrl.animateTo(ctrl.offset + 100, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ctrl.animateTo(ctrl.offset - 100, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  // ── Tabs ──

  Widget _buildDashboard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final pendingOrders = recentOrders.where((o) => o.status == 'pending').toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        controller: _dashboardScroll,
        padding: const EdgeInsets.all(16),
        children: [
          if (pendingOrders.isNotEmpty) _buildAlertBanner(pendingOrders.length, isDark),
          const SizedBox(height: 16),
          _buildStatsGrid(isDark, cardBg),
          const SizedBox(height: 24),
          const Text('🚀 إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildQuickActionsList(isDark, cardBg),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 12),
        Text('لديك $count طلبات بانتظار التأكيد', style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton(onPressed: () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen())), child: const Text('عرض الكل'))
      ]),
    );
  }

  Widget _buildStatsGrid(bool isDark, Color cardBg) {
    return GridView.count(
      shrinkWrap: true, crossAxisCount: isDesktop ? 4 : 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2, physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard('الطلبات', '${stats['totalOrders'] ?? 0}', Icons.shopping_bag, Colors.blue, cardBg),
        _statCard('المنتجات', '${_allProducts.length}', Icons.inventory, Colors.orange, cardBg),
        _statCard('العلامات', '${brands.length}', Icons.branding_watermark, Colors.purple, cardBg),
        _statCard('الإحصائيات', 'عرض', Icons.analytics, Colors.green, cardBg, onTap: () => Navigator.push(context, SlidePageRoute(page: const StatsScreen()))),
      ],
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color col, Color bg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
        child: Row(children: [
          Icon(icon, color: col),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ])
        ]),
      ),
    );
  }

  Widget _buildQuickActionsList(bool isDark, Color cardBg) {
    return Column(children: [
      _quickActionTile('سكان فاتورة مورد', Icons.qr_code_scanner, Colors.teal, () => Navigator.push(context, SlidePageRoute(page: const ScanInvoiceScreen())), cardBg),
      _quickActionTile('إدارة الديون', Icons.money_off, Colors.redAccent, () => Navigator.push(context, SlidePageRoute(page: const DebtsScreen())), cardBg),
      _quickActionTile('لوحة الإدارة', Icons.admin_panel_settings, Colors.blueGrey, () => Navigator.push(context, SlidePageRoute(page: const AdminScreen())), cardBg),
    ]);
  }

  Widget _quickActionTile(String title, IconData icon, Color col, VoidCallback onTap, Color bg) {
    return Card(
      color: bg, margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(leading: Icon(icon, color: col), title: Text(title), trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: onTap),
    );
  }

  // ── Store Tab ──
  String _selectedBrandId = '';
  Widget _buildAdminStoreTab(bool isDark) {
    return _buildBrandsTab(isDark); // Simplified for now, or keep your custom store logic
  }

  Widget _buildBrandsTab(bool isDark) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: searchController, decoration: InputDecoration(hintText: 'بحث...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
      Expanded(child: GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: filteredBrands.length, itemBuilder: (context, i) => _brandCard(filteredBrands[i], isDark))),
    ]);
  }

  Widget _brandCard(Brand b, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(context, SlidePageRoute(page: ProductsScreen(brand: b, cart: cart, isAdmin: true))).then((_) => setState(() {})),
      child: Container(
        decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (b.logoPath.isNotEmpty) Image.network(b.logoPath, height: 50, errorBuilder: (_,__,___) => const Icon(Icons.store, size: 40)) else const Icon(Icons.store, size: 40),
          const SizedBox(height: 8),
          Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final pages = [_buildDashboard(isDark), _buildAdminStoreTab(isDark)];

    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildAdminDrawer(isDark),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('القناعة - لوحة التحكم', style: TextStyle(color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          actions: [
             if (cart.isNotEmpty)
              badges.Badge(
                badgeContent: Text('${cart.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                child: IconButton(icon: const Icon(Icons.shopping_cart, color: Colors.white), onPressed: () => Navigator.push(context, SlidePageRoute(page: CartScreen(cart: cart, isAdmin: true))).then((_) => setState((){}))),
              ),
            const SizedBox(width: 10),
          ],
        ),
        body: isDesktop 
          ? Row(children: [
              _buildDesktopSidebar(isDark),
              Expanded(child: IndexedStack(index: _currentNavIndex, children: pages))
            ])
          : IndexedStack(index: _currentNavIndex, children: pages),
        bottomNavigationBar: isDesktop ? null : BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (i) => setState(() => _currentNavIndex = i),
          selectedItemColor: const Color(0xFF2E7D32),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(bool isDark) {
    return Container(
      width: 250, color: isDark ? Colors.black26 : Colors.grey[100],
      child: Column(children: [
        const DrawerHeader(child: Center(child: Text('القناعة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
        ListTile(leading: const Icon(Icons.dashboard), title: const Text('الرئيسية'), selected: _currentNavIndex == 0, onTap: () => setState(() => _currentNavIndex = 0)),
        ListTile(leading: const Icon(Icons.store), title: const Text('المتجر'), selected: _currentNavIndex == 1, onTap: () => setState(() => _currentNavIndex = 1)),
        const Divider(),
        ListTile(leading: const Icon(Icons.receipt), title: const Text('الطلبات'), onTap: () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen()))),
        ListTile(leading: const Icon(Icons.analytics), title: const Text('الإحصائيات'), onTap: () => Navigator.push(context, SlidePageRoute(page: const StatsScreen()))),
        const Spacer(),
        ListTile(leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode), title: const Text('الوضع'), onTap: widget.onToggleDarkMode),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('خروج'), onTap: _logout),
      ]),
    );
  }

  Widget _buildAdminDrawer(bool isDark) {
    return Drawer(
      child: ListView(children: [
        const DrawerHeader(decoration: BoxDecoration(color: Color(0xFF2E7D32)), child: Center(child: Text('القناعة', style: TextStyle(color: Colors.white, fontSize: 24)))),
        ListTile(leading: const Icon(Icons.receipt_long), title: const Text('الطلبات'), onTap: () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen()))),
        ListTile(leading: const Icon(Icons.bar_chart), title: const Text('الإحصائيات'), onTap: () => Navigator.push(context, SlidePageRoute(page: const StatsScreen()))),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('خروج'), onTap: _logout),
      ]),
    );
  }
}
