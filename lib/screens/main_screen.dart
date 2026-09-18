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
  bool isSpecialPrice = false;

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

  ScrollController get _activeScroll =>
      _currentNavIndex == 1 ? _brandsScroll : _dashboardScroll;

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
    await Future.wait(
        [_loadBrands(), _loadStats(), _loadRecentOrders(), _loadAdminUser()]);
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

  Future<void> _printOrder(Order order) async {
    if (!PrinterService.isConnected) {
      final connected = await Navigator.push<bool>(context, SlidePageRoute(page: const PrinterScreen()));
      if (connected != true || !mounted) return;
    }
    final success = await PrinterService.printReceipt(order: order, customerName: order.customerName, customerPhone: order.customerPhone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? '✅ تم الطباعة بنجاح' : '❌ فشلت الطباعة'),
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

    return Container(
      width: 220,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(2, 0))],
      ),
      child: Column(
        children: [
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
                        errorBuilder: (_, __, ___) => const Icon(Icons.store_rounded, color: Colors.white, size: 28)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('القناعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Text('لوحة التحكم', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sidebarItem(Icons.home_rounded, 'الرئيسية', 0, textColor),
                _sidebarItem(Icons.store_rounded, 'المتجر (POS)', 1, textColor),
                const Divider(),
                _sidebarAction(Icons.receipt_long_rounded, 'سجل الطلبات', () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen())), isDark),
                _sidebarAction(Icons.camera_enhance_rounded, 'سكان فاتورة مورد', () => Navigator.push(context, SlidePageRoute(page: const ScanInvoiceScreen())), isDark),
                _sidebarAction(Icons.people_alt_rounded, 'الزبائن والديون', () => Navigator.push(context, SlidePageRoute(page: const DebtsScreen())), isDark),
                _sidebarAction(Icons.bar_chart_rounded, 'الإحصائيات والربح', () => Navigator.push(context, SlidePageRoute(page: const StatsScreen())), isDark),
                _sidebarAction(Icons.admin_panel_settings_rounded, 'لوحة الإدارة', () => Navigator.push(context, SlidePageRoute(page: const AdminScreen())), isDark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _sidebarAction(Icons.visibility_rounded, 'معاينة كزبون', _previewAsUser, isDark),
              const SizedBox(height: 6),
              _sidebarAction(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, widget.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي', widget.onToggleDarkMode, isDark),
              const SizedBox(height: 6),
              ListTile(
                tileColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: const Text('خروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                onTap: _logout,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index, Color textColor) {
    final isSelected = _currentNavIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF2E7D32) : textColor.withOpacity(0.6)),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF2E7D32) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      onTap: () => setState(() => _currentNavIndex = index),
    );
  }

  Widget _sidebarAction(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    );
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
  //  Rich Dashboard Tab
  // ══════════════════════════════════
  Widget _buildDashboard(bool isDark) {
    final cardBg    = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final pendingOrders = recentOrders.where((o) => o.status == 'pending').toList();

    return RefreshIndicator(
      color: const Color(0xFF2E7D32),
      onRefresh: _loadAll,
      child: Scrollbar(
        controller: _dashboardScroll,
        thumbVisibility: isDesktop,
        child: SingleChildScrollView(
          controller: _dashboardScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingOrders.isNotEmpty) _buildAlertBanner(pendingOrders.length, isDark),
                const SizedBox(height: 16),
                _buildSectionTitle('📊 نظرة سريعة', isDark),
                const SizedBox(height: 8),
                _buildStatsGrid(isDark, cardBg),
                const SizedBox(height: 16),
                _buildSectionTitle('🚀 إجراءات سريعة', isDark),
                const SizedBox(height: 8),
                _buildQuickActionsList(isDark, cardBg),
                if (pendingOrders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionTitle('🔴 طلبات تنتظر المراجعة', isDark),
                  const SizedBox(height: 8),
                  ...pendingOrders.take(5).map((order) => _buildOrderCard(order, isDark, cardBg, textColor, subColor)),
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
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange, width: 1.5)),
      child: Row(children: [
        const Text('🔔', style: TextStyle(fontSize: 22)), const SizedBox(width: 10),
        Expanded(child: Text('$count طلبات جديدة تنتظر المراجعة', style: TextStyle(color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 14))),
        GestureDetector(onTap: () => setState(() => _currentNavIndex = 1), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('عرض', style: TextStyle(color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)))),
      ]),
    );
  }

  Widget _buildStatsGrid(bool isDark, Color cardBg) {
    final pending   = recentOrders.where((o) => o.status == 'pending').length;
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
      children: [
        _buildStatCard('📦', '$pending', 'طلبات تنتظر', Colors.red, isDark, cardBg),
        _buildStatCard('🏪', '${brands.length}', 'علامة تجارية', Colors.blue, isDark, cardBg),
        _buildStatCard('📋', '${stats['totalOrders'] ?? 0}', 'إجمالي الطلبات', Colors.purple, isDark, cardBg),
        _buildStatCard('📈', 'الإحصائيات', 'عرض التقارير والربح', Colors.green, isDark, cardBg, onTap: () => Navigator.push(context, SlidePageRoute(page: const StatsScreen()))),
      ],
    );
  }

  Widget _buildStatCard(String icon, String value, String label, Color color, bool isDark, Color cardBg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(icon, style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, height: 1.0)),
            Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  Widget _buildQuickActionsList(bool isDark, Color cardBg) {
    final actions = [
      {'icon': Icons.camera_enhance_rounded, 'label': 'سكان فاتورة مورد', 'subtitle': 'تحديث المخزن', 'colors': [const Color(0xFF006064), const Color(0xFF00ACC1)], 'onTap': () => Navigator.push(context, SlidePageRoute(page: const ScanInvoiceScreen()))},
      {'icon': Icons.receipt_long_rounded, 'label': 'طلبات اليوم', 'subtitle': 'تحضير الطلبيات', 'colors': [const Color(0xFF2E7D32), const Color(0xFF43A047)], 'onTap': () => Navigator.push(context, SlidePageRoute(page: const OrdersScreen(showTodayOnly: true)))},
      {'icon': Icons.people_alt_rounded, 'label': 'الزبائن والديون', 'subtitle': 'إدارة الديون', 'colors': [const Color(0xFFAD1457), const Color(0xFFEC407A)], 'onTap': () => Navigator.push(context, SlidePageRoute(page: const DebtsScreen()))},
      {'icon': Icons.admin_panel_settings_rounded, 'label': 'لوحة الإدارة', 'subtitle': 'المنتجات والبانرات', 'colors': [const Color(0xFF283593), const Color(0xFF5C6BC0)], 'onTap': () => Navigator.push(context, SlidePageRoute(page: const AdminScreen()))},
    ];
    return Column(children: actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GestureDetector(onTap: a['onTap'] as VoidCallback, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: a['colors'] as List<Color>), borderRadius: BorderRadius.circular(16)), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(a['icon'] as IconData, color: Colors.white, size: 24)), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['label'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), Text(a['subtitle'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11))])),
      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
    ]))))).toList());
  }

  Widget _buildOrderCard(Order order, bool isDark, Color cardBg, Color textColor, Color subColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: const Border(right: BorderSide(color: Colors.orange, width: 4))),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(order.customerName.isNotEmpty ? order.customerName[0] : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(order.customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)), Text('${order.items.length} منتج • ${_formatDate(order.createdAt ?? order.dateTime)}', style: TextStyle(fontSize: 11, color: subColor))])),
          Text('${order.total.toStringAsFixed(0)} DA', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _actionButton('✅ تأكيد', const Color(0xFFE8F5E9), const Color(0xFF2E7D32), () async { await DataService.updateOrderStatus(order.id, 'confirmed'); _loadRecentOrders(); })),
          const SizedBox(width: 6),
          Expanded(child: _actionButton('🖨️ طباعة', const Color(0xFFE3F2FD), Colors.blue, () => _printOrder(order))),
        ]),
      ]),
    );
  }

  Widget _actionButton(String label, Color bg, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)))));
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)), const SizedBox(width: 8), Expanded(child: Container(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200))]);
  }

  // ══════════════════════════════════
  //  UI Structure
  // ══════════════════════════════════
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
        drawer: isDesktop ? null : _buildAdminDrawer(isDark),
        appBar: isDesktop ? null : AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 2,
          leading: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          title: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/logo.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.store, color: Colors.white, size: 20)))),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('القناعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('لوحة التحكم', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ]),
          actions: [
            if (cart.isNotEmpty)
              badges.Badge(
                badgeContent: Text('${cart.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                child: IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white), onPressed: () => Navigator.push(context, SlidePageRoute(page: CartScreen(cart: cart, isAdmin: true))).then((_) => setState((){}))),
              ),
            const SizedBox(width: 10),
          ],
        ),
        body: isDesktop 
          ? Row(children: [
              _buildDesktopSidebar(isDark),
              Expanded(child: IndexedStack(index: _currentNavIndex, children: pages)),
            ])
          : IndexedStack(index: _currentNavIndex, children: pages),
        bottomNavigationBar: isDesktop ? null : Container(
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
          child: NavigationBar(
            selectedIndex: _currentNavIndex,
            onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            indicatorColor: const Color(0xFF2E7D32).withOpacity(0.15),
            height: 65,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF2E7D32)), label: 'الرئيسية'),
              NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store_rounded, color: Color(0xFF2E7D32)), label: 'المتجر'),
            ])),
      ),
    );
  }

  Widget _buildAdminDrawer(bool isDark) {
    final name = _adminUser?.name ?? 'الأدمن';
    return Drawer(child: ListView(children: [
      UserAccountsDrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
        currentAccountPicture: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
        accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        accountEmail: Text(_adminUser?.email ?? ''),
      ),
      ListTile(leading: const Icon(Icons.receipt_long, color: Color(0xFF2E7D32)), title: const Text('سجل الطلبات'), onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const OrdersScreen())); }),
      ListTile(leading: const Icon(Icons.camera_enhance, color: Color(0xFF2E7D32)), title: const Text('سكان فاتورة مورد'), onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const ScanInvoiceScreen())); }),
      ListTile(leading: const Icon(Icons.people_alt, color: Color(0xFF2E7D32)), title: const Text('الزبائن والديون'), onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const DebtsScreen())); }),
      ListTile(leading: const Icon(Icons.bar_chart, color: Color(0xFF2E7D32)), title: const Text('الإحصائيات والربح'), onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const StatsScreen())); }),
      ListTile(leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF2E7D32)), title: const Text('لوحة الإدارة'), onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const AdminScreen())); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.visibility), title: const Text('معاينة كزبون'), onTap: () { Navigator.pop(context); _previewAsUser(); }),
      ListTile(leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode), title: Text(isDark ? 'الوضع النهاري' : 'الوضع الليلي'), onTap: () { Navigator.pop(context); widget.onToggleDarkMode(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('تسجيل الخروج'), onTap: () { Navigator.pop(context); _logout(); }),
    ]));
  }
}
