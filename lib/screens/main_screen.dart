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
  const MainScreen({super.key, required this.onToggleDarkMode, required this.isDarkMode});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  List<Brand> brands = [];
  List<Brand> filteredBrands = [];
  List<CartItem> cart = [];
  List<Order> recentOrders = [];
  Map<String, dynamic> stats = {};
  final searchController = TextEditingController();
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
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _loadAll();
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

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { isLoading = true; isStatsLoading = true; });
    await Future.wait([_loadBrands(), _loadStats(), _loadRecentOrders(), _loadAdminUser()]);
    if (mounted) _fadeController.forward(from: 0);
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
      if (mounted) setState(() { brands = data; filteredBrands = data; isLoading = false; });
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _loadStats() async {
    try {
      final data = await DataService.getStats();
      final special = await DataService.getIsSpecialPrice();
      if (mounted) setState(() { stats = data; isSpecialPrice = special; isStatsLoading = false; });
    } catch (_) { if (mounted) setState(() => isStatsLoading = false); }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final data = await DataService.getAllOrders();
      if (mounted) setState(() => recentOrders = data.take(10).toList());
    } catch (_) {}
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _logout() async {
    cart.clear(); await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, FadeScaleRoute(page: LoginScreen(onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode)));
  }

  Future<void> _previewAsUser() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted || user == null) return;
    Navigator.push(context, SlidePageRoute(page: UserMainScreen(user: user, onToggleDarkMode: widget.onToggleDarkMode, isDarkMode: widget.isDarkMode, isPreviewMode: true)));
  }

  // ══════════════════════════════════
  //  Fast Store Logic
  // ══════════════════════════════════
  String _selectedBrandId = '';
  List<Product> _allProducts = [];
  List<Product> _storeFilteredProducts = [];
  final _storeSearchCtrl = TextEditingController();
  final Map<String, bool> _itemIsCartonMap = {};

  Future<void> _loadStoreData() async {
    final b = await DataService.getBrands();
    final p = await DataService.getAllProducts();
    setState(() {
      brands = b; _allProducts = p;
      if (brands.isNotEmpty && _selectedBrandId.isEmpty) _selectedBrandId = brands.first.id;
      _applyStoreFilter();
    });
  }

  void _applyStoreFilter() {
    final q = _storeSearchCtrl.text.toLowerCase();
    setState(() {
      _storeFilteredProducts = _allProducts.where((p) {
        final matchesBrand = _selectedBrandId.isEmpty || p.brandId == _selectedBrandId;
        final matchesSearch = q.isEmpty || p.name.toLowerCase().contains(q);
        return matchesBrand && matchesSearch;
      }).toList();
    });
  }

  Widget _buildAdminStoreTab(bool isDark) {
    if (_allProducts.isEmpty && !isLoading) _loadStoreData();
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 3 : 1);

    return Column(children: [
      Container(width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)])), padding: const EdgeInsets.all(12),
        child: TextField(controller: _storeSearchCtrl, onChanged: (_) => _applyStoreFilter(), decoration: InputDecoration(hintText: 'بحث سريع عن منتج...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
      Container(height: 100, color: isDark ? const Color(0xFF161625) : Colors.white,
        child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: brands.length, itemBuilder: (context, i) {
          final b = brands[i]; final isSel = _selectedBrandId == b.id;
          return GestureDetector(onTap: () { setState(() => _selectedBrandId = b.id); _applyStoreFilter(); },
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 80, margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10), decoration: BoxDecoration(color: isSel ? const Color(0xFF2E7D32).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSel ? const Color(0xFF2E7D32) : Colors.grey.shade300, width: isSel ? 2 : 1)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (b.logoPath.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(b.logoPath, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.store))) else const Icon(Icons.store),
                const SizedBox(height: 4), Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFF2E7D32) : textColor))
              ])));
        })),
      Expanded(child: crossAxisCount > 1 
        ? GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85), itemCount: _storeFilteredProducts.length, itemBuilder: (context, i) => _buildAdvancedProductCard(_storeFilteredProducts[i], isDark, cardColor, textColor))
        : ListView.builder(padding: const EdgeInsets.all(10), itemCount: _storeFilteredProducts.length, itemBuilder: (context, i) => _buildFastProductCard(_storeFilteredProducts[i], isDark, cardColor, textColor))),
      _buildFloatingCartBar(),
    ]);
  }

  Widget _buildAdvancedProductCard(Product p, bool isDark, Color cardColor, Color textColor) {
    bool isCarton = _itemIsCartonMap[p.id] ?? true;
    return Opacity(opacity: p.isAvailable ? 1.0 : 0.6, child: Container(decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(children: [
        Expanded(child: Stack(children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: p.imagePath.isNotEmpty ? Image.network(p.imagePath, width: double.infinity, fit: BoxFit.cover) : Container(color: Colors.grey.shade100, child: const Icon(Icons.image, size: 50))),
          Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10)), child: Text(_getStockLabel(p), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
          if (p.isAvailable) Column(children: [
            Row(children: [ _unitToggle(p, true, isCarton), const SizedBox(width: 5), if (p.canSellUnit) _unitToggle(p, false, !isCarton) ]),
            if (p.hasFlavors) _buildFlavorChips(p, isCarton),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(isCarton ? p.priceCartonNormal : p.priceUnitNormal).toStringAsFixed(0)} DA', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
              _buildQtySelector(p, isCarton: isCarton),
            ]),
          ]) else const Text('غير متوفر', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ])),
      ])));
  }

  Widget _buildFastProductCard(Product p, bool isDark, Color cardColor, Color textColor) {
    bool isCarton = _itemIsCartonMap[p.id] ?? true;
    return Opacity(opacity: p.isAvailable ? 1.0 : 0.5, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: p.imagePath.isNotEmpty ? Image.network(p.imagePath, width: 60, height: 60, fit: BoxFit.cover) : Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.image))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('المخزن: ${_getStockLabel(p)}', style: const TextStyle(color: Colors.blue, fontSize: 10)),
            Row(children: [ _unitToggle(p, true, isCarton), const SizedBox(width: 5), if (p.canSellUnit) _unitToggle(p, false, !isCarton) ]),
          ])),
          if (p.isAvailable) _buildQtySelector(p, isCarton: isCarton)
        ]),
        if (p.hasFlavors && p.isAvailable) _buildFlavorChips(p, isCarton),
      ])));
  }

  Widget _buildFlavorChips(Product p, bool isCarton) {
    return SizedBox(height: 35, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: p.flavors.length, itemBuilder: (context, i) {
      final f = p.flavors[i]; if (!f.isAvailable) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.only(left: 5), child: ActionChip(label: Text(f.name, style: const TextStyle(fontSize: 10)), 
        onPressed: () => _fastAddToCart(p, flavor: f.name, isCarton: isCarton), backgroundColor: Colors.purple.withOpacity(0.05)));
    }));
  }

  Widget _unitToggle(Product p, bool forCarton, bool isSelected) {
    return GestureDetector(onTap: () => setState(() => _itemIsCartonMap[p.id] = forCarton), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      decoration: BoxDecoration(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: Text(forCarton ? '📦 كرتون' : '🛍️ حبة', style: TextStyle(fontSize: 9, color: isSelected ? Colors.white : Colors.grey))));
  }

  Widget _buildQtySelector(Product p, {required bool isCarton}) {
    final cartItem = cart.firstWhere((it) => it.product.id == p.id && it.isCarton == isCarton, orElse: () => CartItem(product: p, quantity: 0, isCarton: isCarton));
    return Row(children: [
      if (cartItem.quantity > 0) ...[
        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() { if (cartItem.quantity > 1) cartItem.quantity--; else cart.removeWhere((it) => it.product.id == p.id && it.isCarton == isCarton); })),
        Text('${cartItem.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
      IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 30), onPressed: () => setState(() {
        final idx = cart.indexWhere((it) => it.product.id == p.id && it.isCarton == isCarton);
        if (idx != -1) cart[idx].quantity++; else cart.add(CartItem(product: p, quantity: 1, isCarton: isCarton, isSpecialPrice: isSpecialPrice));
      })),
    ]);
  }

  void _fastAddToCart(Product p, {String? flavor, required bool isCarton}) {
    setState(() {
      final existing = cart.indexWhere((it) => it.product.id == p.id && it.isCarton == isCarton && it.flavor == flavor);
      if (existing != -1) cart[existing].quantity++; else cart.add(CartItem(product: p, quantity: 1, isCarton: isCarton, isSpecialPrice: isSpecialPrice, flavor: flavor));
    });
  }

  String _getStockLabel(Product p) {
    if (p.unitsPerCarton > 1) {
      int crt = p.stockQuantity ~/ p.unitsPerCarton; int pcs = p.stockQuantity % p.unitsPerCarton;
      return '$crt كرتون و $pcs حبة';
    }
    return '${p.stockQuantity} حبة';
  }

  Widget _buildFloatingCartBar() {
    if (cart.isEmpty) return const SizedBox.shrink();
    final total = cart.fold(0.0, (sum, it) => sum + it.totalPrice);
    return GestureDetector(onTap: () => Navigator.push(context, SlidePageRoute(page: CartScreen(cart: cart, isAdmin: true))).then((_) => setState((){})),
      child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(15)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${cart.length} أصناف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('الإجمالي: ${total.toStringAsFixed(0)} DA', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ])));
  }

  // ══════════════════════════════════
  //  Dashboard
  // ══════════════════════════════════
  Widget _buildDashboard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final pendingCount = recentOrders.where((o) => o.status == 'pending').length;

    return RefreshIndicator(onRefresh: _loadAll, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _buildStatsGrid(isDark, cardBg, pendingCount),
      const SizedBox(height: 20),
      _buildQuickAction(Icons.camera_alt, 'سكان فاتورة مورد', 'تحديث المخزن', [const Color(0xFF006064), const Color(0xFF00ACC1)], () => Navigator.push(context, SlidePageRoute(page: const ScanInvoiceScreen()))),
      const SizedBox(height: 10),
      _buildQuickAction(Icons.receipt, 'طلبات اليوم', 'تحضير الطلبيات', [const Color(0xFF2E7D32), const Color(0xFF43A047)], () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen(showTodayOnly: true)))),
      const SizedBox(height: 10),
      _buildQuickAction(Icons.people, 'الزبائن والديون', 'إدارة الديون', [const Color(0xFFAD1457), const Color(0xFFEC407A)], () => Navigator.push(context, SlidePageRoute(page: const DebtsScreen()))),
    ])));
  }

  Widget _buildStatsGrid(bool isDark, Color cardBg, int pending) {
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: isDesktop ? 4 : 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.0, children: [
      _statCard('📦', '$pending', 'طلبات تنتظر', Colors.red, isDark, cardBg),
      _statCard('🏪', '${brands.length}', 'علامة تجارية', Colors.blue, isDark, cardBg),
      _statCard('📋', '${stats['totalOrders'] ?? 0}', 'إجمالي الطلبات', Colors.purple, isDark, cardBg),
      _statCard('💰', '${(stats['totalSales'] ?? 0).toStringAsFixed(0)}', 'إجمالي مبيعات', Colors.green, isDark, cardBg),
    ]);
  }

  Widget _statCard(String icon, String val, String label, Color color, bool isDark, Color cardBg) {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]));
  }

  Widget _buildQuickAction(IconData icon, String title, String sub, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 30), const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
      ])));
  }

  // ══════════════════════════════════
  //  UI Structure
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final pages = [_buildDashboard(isDark), _buildAdminStoreTab(isDark), const AdminScreen()];
    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : _buildAdminDrawer(isDark),
      appBar: isDesktop ? null : AppBar(backgroundColor: const Color(0xFF2E7D32), title: const Text('القناعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: IndexedStack(index: _currentNavIndex, children: pages),
      bottomNavigationBar: isDesktop ? null : NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.store), label: 'المتجر'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإدارة'),
        ]),
    );
  }

  Widget _buildAdminDrawer(bool isDark) {
    return Drawer(child: ListView(children: [
      const DrawerHeader(decoration: BoxDecoration(color: Color(0xFF2E7D32)), child: Center(child: Text('لوحة الإدارة', style: TextStyle(color: Colors.white, fontSize: 20)))),
      ListTile(leading: const Icon(Icons.visibility), title: const Text('معاينة كزبون'), onTap: () { Navigator.pop(context); _previewAsUser(); }),
      ListTile(leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode), title: Text(isDark ? 'الوضع النهاري' : 'الوضع الليلي'), onTap: () { Navigator.pop(context); widget.onToggleDarkMode(); }),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('تسجيل الخروج'), onTap: () { Navigator.pop(context); _logout(); }),
    ]));
  }
}
