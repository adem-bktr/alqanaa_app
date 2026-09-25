import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'package:badges/badges.dart' as badges;

class ProductsScreen extends StatefulWidget {
  final Brand brand;
  final List<CartItem> cart;
  final bool isAdmin;
  final UserModel? user;

  const ProductsScreen({
    super.key,
    required this.brand,
    required this.cart,
    required this.isAdmin,
    this.user,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isSpecialPrice = false;
  final searchController = TextEditingController();
  bool isGridView = true;
  bool isLoading = true;
  UserModel? currentUser;
  String selectedSort = 'name';

  late AnimationController _shimmerController;

  // ✅ Scroll + Keyboard
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocus = FocusNode();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    // تقصير المنطق: على الحاسوب نبدأ دائماً بنظام القائمة List
    isGridView = MediaQuery.of(context).size.width < 900; 
    currentUser = widget.user;
    loadData();
    searchController.addListener(_onSearch);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    searchController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  // ✅ Keyboard Scroll Handler
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (!_scrollController.hasClients) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
      );
    }
  }

  void _onSearch() => _applyFilterAndSort();

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      if (currentUser == null) {
        currentUser = await AuthService.getCurrentUser();
      }
      if (currentUser != null && !currentUser!.isAdmin) {
        isSpecialPrice = currentUser!.isSpecial;
      } else {
        isSpecialPrice = await DataService.getIsSpecialPrice();
      }
      final data = await DataService.getProducts(widget.brand.id);
      if (mounted) {
        setState(() {
          products = data;
          filteredProducts = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilterAndSort() {
    final q = searchController.text.toLowerCase();
    List<Product> filtered = q.isEmpty
        ? List.from(products)
        : products.where((p) => p.name.toLowerCase().contains(q)).toList();

    switch (selectedSort) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'priceAsc':
        filtered.sort(
                (a, b) => a.priceCartonNormal.compareTo(b.priceCartonNormal));
        break;
      case 'priceDesc':
        filtered.sort(
                (a, b) => b.priceCartonNormal.compareTo(a.priceCartonNormal));
        break;
      case 'available':
        filtered.sort((a, b) => b.isAvailable ? 1 : -1);
        break;
    }
    setState(() => filteredProducts = filtered);
  }

  bool _isMaxQtyReached(Product product) {
    if (currentUser == null || currentUser!.isAdmin) return false;
    final maxQty = currentUser!.isSpecial
        ? product.maxQtySpecial
        : product.maxQtyNormal;
    if (maxQty <= 0) return false;
    final cartQty = widget.cart
        .where((i) => i.product.id == product.id && i.isCarton)
        .fold(0, (sum, i) => sum + i.quantity);
    return cartQty >= maxQty;
  }

  void addToCart(Product product) {
    if (!product.isAvailable) {
      _showSnackBar('❌ المنتج غير متوفر', Colors.red);
      return;
    }
    if (_isMaxQtyReached(product)) {
      final maxQty = currentUser != null && currentUser!.isSpecial
          ? product.maxQtySpecial
          : product.maxQtyNormal;
      _showSnackBar('❌ لا يمكنك طلب أكثر من $maxQty كرتون', Colors.red);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          cart: widget.cart,
          isSpecialPrice: isSpecialPrice,
          currentUser: currentUser,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5);
    final searchBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final cartCount =
    widget.cart.fold(0, (sum, item) => sum + item.quantity);

    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: bgColor,

        // ══════════════════════════════════
        //  Desktop: بدون AppBar عادي
        // ══════════════════════════════════
        appBar: isDesktop ? null : AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: Text(widget.brand.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          leading: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: [
            if (isSpecialPrice)
              Container(
                margin:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57F17).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Text(
                  '⭐ مميز',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: Colors.white),
                onSelected: (value) {
                  setState(() => selectedSort = value);
                  _applyFilterAndSort();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'name',
                    child: Row(children: [
                      Icon(Icons.sort_by_alpha,
                          color: selectedSort == 'name'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text('ترتيب بالاسم',
                          style: TextStyle(
                              color: selectedSort == 'name'
                                  ? const Color(0xFF2E7D32)
                                  : null)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'priceAsc',
                    child: Row(children: [
                      Icon(Icons.arrow_upward,
                          color: selectedSort == 'priceAsc'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text('الأرخص أولاً',
                          style: TextStyle(
                              color: selectedSort == 'priceAsc'
                                  ? const Color(0xFF2E7D32)
                                  : null)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'priceDesc',
                    child: Row(children: [
                      Icon(Icons.arrow_downward,
                          color: selectedSort == 'priceDesc'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text('الأغلى أولاً',
                          style: TextStyle(
                              color: selectedSort == 'priceDesc'
                                  ? const Color(0xFF2E7D32)
                                  : null)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'available',
                    child: Row(children: [
                      Icon(Icons.check_circle,
                          color: selectedSort == 'available'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text('المتوفر أولاً',
                          style: TextStyle(
                              color: selectedSort == 'available'
                                  ? const Color(0xFF2E7D32)
                                  : null)),
                    ]),
                  ),
                ],
              ),
            ),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: badges.Badge(
                badgeContent: Text(
                  '$cartCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                showBadge: widget.cart.isNotEmpty,
                badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        cart: widget.cart,
                        isAdmin: widget.isAdmin,
                        user: currentUser,
                      ),
                    ),
                  ).then((_) => setState(() {})),
                ),
              ),
            ),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                  isGridView ? Icons.view_list : Icons.grid_view,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => isGridView = !isGridView),
              ),
            ),
          ],
        ),

        // ══════════════════════════════════
        //  Desktop: Top Bar
        // ══════════════════════════════════
        body: isDesktop
            ? Column(
          children: [
            // Desktop Top Bar
            Container(
              height: 60,
              color: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(widget.brand.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Spacer(),
                  if (isSpecialPrice)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF57F17).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: const Text(
                        '⭐ مميز',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  const SizedBox(width: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, color: Colors.white),
                      onSelected: (value) {
                        setState(() => selectedSort = value);
                        _applyFilterAndSort();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'name',
                          child: Row(children: [
                            Icon(Icons.sort_by_alpha,
                                color: selectedSort == 'name'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                            const SizedBox(width: 8),
                            Text('ترتيب بالاسم',
                                style: TextStyle(
                                    color: selectedSort == 'name'
                                        ? const Color(0xFF2E7D32)
                                        : null)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'priceAsc',
                          child: Row(children: [
                            Icon(Icons.arrow_upward,
                                color: selectedSort == 'priceAsc'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                            const SizedBox(width: 8),
                            Text('الأرخص أولاً',
                                style: TextStyle(
                                    color: selectedSort == 'priceAsc'
                                        ? const Color(0xFF2E7D32)
                                        : null)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'priceDesc',
                          child: Row(children: [
                            Icon(Icons.arrow_downward,
                                color: selectedSort == 'priceDesc'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                            const SizedBox(width: 8),
                            Text('الأغلى أولاً',
                                style: TextStyle(
                                    color: selectedSort == 'priceDesc'
                                        ? const Color(0xFF2E7D32)
                                        : null)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'available',
                          child: Row(children: [
                            Icon(Icons.check_circle,
                                color: selectedSort == 'available'
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                            const SizedBox(width: 8),
                            Text('المتوفر أولاً',
                                style: TextStyle(
                                    color: selectedSort == 'available'
                                        ? const Color(0xFF2E7D32)
                                        : null)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: badges.Badge(
                      badgeContent: Text(
                        '$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      showBadge: widget.cart.isNotEmpty,
                      badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
                      child: IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CartScreen(
                              cart: widget.cart,
                              isAdmin: widget.isAdmin,
                              user: currentUser,
                            ),
                          ),
                        ).then((_) => setState(() {})),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: Icon(
                        isGridView ? Icons.view_list : Icons.grid_view,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => isGridView = !isGridView),
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Container(
              color: const Color(0xFF2E7D32),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: searchController,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج...',
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                  prefixIcon: Icon(Icons.search,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                  filled: true,
                  fillColor: searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? _buildShimmerLoading(isDark)
                  : filteredProducts.isEmpty
                  ? _buildEmpty(isDark)
                  : RefreshIndicator(
                color: const Color(0xFF2E7D32),
                onRefresh: loadData,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: isGridView
                      ? _buildGridView(isDark)
                      : _buildListView(isDark),
                ),
              ),
            ),
          ],
        )

        // ══════════════════════════════════
        //  Mobile Layout
        // ══════════════════════════════════
            : SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: const Color(0xFF2E7D32),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'بحث عن منتج...',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    prefixIcon: Icon(Icons.search,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                    filled: true,
                    fillColor: searchBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? _buildShimmerLoading(isDark)
                    : filteredProducts.isEmpty
                    ? _buildEmpty(isDark)
                    : RefreshIndicator(
                  color: const Color(0xFF2E7D32),
                  onRefresh: loadData,
                  child: isGridView
                      ? _buildGridView(isDark)
                      : _buildListView(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //    Grid View
  // ══════════════════════════════════
  Widget _buildGridView(bool isDark) {
    // ✅ عدد أعمدة متغير حسب الشاشة
    final crossAxisCount = isDesktop
        ? (MediaQuery.of(context).size.width / 300).floor().clamp(2, 6)
        : 2;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _AnimatedProductCard(
          product: product,
          index: index,
          isDark: isDark,
          isSpecialPrice: isSpecialPrice,
          maxReached: _isMaxQtyReached(product),
          onAdd: () => addToCart(product),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: product,
                  cart: widget.cart,
                  isSpecialPrice: isSpecialPrice,
                  currentUser: currentUser,
                ),
              ),
            ).then((_) => setState(() {}));
          },
        );
      },
    );
  }

  // ══════════════════════════════════
  //    List View
  // ══════════════════════════════════
  Widget _buildListView(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _AnimatedProductListItem(
          product: product,
          index: index,
          isDark: isDark,
          isSpecialPrice: isSpecialPrice,
          maxReached: _isMaxQtyReached(product),
          onAdd: () => addToCart(product),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: product,
                  cart: widget.cart,
                  isSpecialPrice: isSpecialPrice,
                  currentUser: currentUser,
                ),
              ),
            ).then((_) => setState(() {}));
          },
        );
      },
    );
  }

  // ══════════════════════════════════
  //    Shimmer Loading
  // ══════════════════════════════════
  Widget _buildShimmerLoading(bool isDark) {
    final baseColor =
    isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    final highlightColor =
    isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100;

    // ✅ عدد أعمدة متغير
    final crossAxisCount = isDesktop
        ? (MediaQuery.of(context).size.width / 300).floor().clamp(2, 6)
        : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (_, value, child) {
            return Opacity(
              opacity: value * 0.6,
              child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)), child: child),
            );
          },
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              final shimmerValue = _shimmerController.value;
              const shimmerWidth = 0.3;
              final left =
                  (shimmerValue * (1 + shimmerWidth)) - shimmerWidth;

              return Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: isDark
                                  ? const Color(0xFF1E1E2E)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 80,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: baseColor,
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 60,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: baseColor,
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: baseColor,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      FractionallySizedBox(
                        widthFactor: shimmerWidth,
                        child: Align(
                          alignment: Alignment(
                              -1.0 + (left / shimmerWidth) * 2, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  highlightColor.withValues(alpha: 0),
                                  highlightColor.withValues(alpha: 0.4),
                                  highlightColor.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ══════════════════════════════════
  //    Empty Screen
  // ══════════════════════════════════
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (_, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)), child: child),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (_, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Icon(
                searchController.text.isNotEmpty
                    ? Icons.search_off
                    : Icons.inventory_2_outlined,
                size: 80,
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searchController.text.isNotEmpty
                  ? 'لا توجد نتائج'
                  : 'لا توجد منتجات',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                  fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//    Product Card (3D Tilt)
// ══════════════════════════════════
class _AnimatedProductCard extends StatefulWidget {
  final Product product;
  final int index;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool isSpecialPrice;
  final bool maxReached;

  const _AnimatedProductCard({
    required this.product,
    required this.index,
    required this.isDark,
    required this.onAdd,
    required this.onTap,
    required this.isSpecialPrice,
    required this.maxReached,
  });

  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard>
    with SingleTickerProviderStateMixin {
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  bool _pressed = false;

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    setState(() {
      _rotateX = (details.localPosition.dy - (size.height / 2)) /
          (size.height / 2) *
          -0.08;
      _rotateY = (details.localPosition.dx - (size.width / 2)) /
          (size.width / 2) *
          0.08;
      _rotateX = _rotateX.clamp(-0.08, 0.08);
      _rotateY = _rotateY.clamp(-0.08, 0.08);
    });
  }

  void _resetRotation() {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final cartonPrice = widget.isSpecialPrice
        ? widget.product.discountedPrice(widget.product.priceCartonSpecial)
        : widget.product.discountedPrice(widget.product.priceCartonNormal);
    final unitPrice = widget.isSpecialPrice
        ? widget.product.discountedPrice(widget.product.priceUnitSpecial)
        : widget.product.discountedPrice(widget.product.priceUnitNormal);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (widget.index * 80)),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)), child: child),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _resetRotation(),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            _resetRotation();
            widget.onTap();
          },
          onTapCancel: _resetRotation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotateX)
              ..rotateY(_rotateY),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _pressed
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                      : Colors.black.withValues(
                      alpha: widget.isDark ? 0.3 : 0.06),
                  blurRadius: _pressed ? 20 : 8,
                  offset: Offset(0, _pressed ? 8 : 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: widget.product.imagePath.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: widget.product.imagePath,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Icon(Icons.image,
                                size: 50,
                                color: Color(0xFF2E7D32)),
                          ),
                        )
                            : Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                            child: Icon(Icons.inventory_2,
                                size: 50,
                                color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ),
                      if (widget.product.discount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${widget.product.discount.toInt()}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.product.sellType ==
                                SellType.cartonOnly
                                ? '📦'
                                : widget.product.sellType ==
                                SellType.unitOnly
                                ? '🛍️'
                                : '📦🛍️',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      if (!widget.product.isAvailable)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Text('غير متوفر',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      if (widget.maxReached)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: Container(
                              color: Colors.orange.withValues(alpha: 0.7),
                              child: const Center(
                                child: Text('وصلت الحد الأقصى',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            if (widget.product.canSellCarton)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('📦 كرتون:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    '${cartonPrice.toStringAsFixed(0)} DA',
                                    style: TextStyle(
                                        color: widget.isDark ? Colors.green.shade400 : const Color(0xFF2E7D32),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            if (widget.product.canSellCarton && widget.product.canSellUnit) 
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Divider(height: 1, thickness: 0.5, color: widget.isDark ? Colors.white10 : Colors.black12),
                              ),
                            if (widget.product.canSellUnit)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('🛍️ قطعة:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    '${unitPrice.toStringAsFixed(0)} DA',
                                    style: TextStyle(
                                        color: widget.isDark ? Colors.green.shade300 : const Color(0xFF388E3C),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: MouseRegion(
                          cursor: widget.product.isAvailable && !widget.maxReached
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.forbidden,
                          child: ElevatedButton(
                            onPressed: widget.product.isAvailable &&
                                !widget.maxReached
                                ? widget.onAdd
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.maxReached
                                  ? Colors.orange
                                  : widget.product.isAvailable
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey,
                              padding:
                              const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(widget.maxReached ? Icons.error_outline : Icons.add_shopping_cart, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  widget.maxReached ? 'الحد الأقصى' : 'إضافة',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockPill(Product p) {
    Color color = Colors.green;
    String label = 'متوفر';
    if (!p.isAvailable || p.stockQuantity <= 0) {
      color = Colors.red;
      label = 'نفد';
    } else if (p.stockQuantity <= 5 * (p.unitsPerCarton > 0 ? p.unitsPerCarton : 1)) {
      color = Colors.orange;
      label = 'قليل';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════
//    Product List Item (3D Tilt)
// ══════════════════════════════════
class _AnimatedProductListItem extends StatefulWidget {
  final Product product;
  final int index;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool isSpecialPrice;
  final bool maxReached;

  const _AnimatedProductListItem({
    required this.product,
    required this.index,
    required this.isDark,
    required this.onAdd,
    required this.onTap,
    required this.isSpecialPrice,
    required this.maxReached,
  });

  @override
  State<_AnimatedProductListItem> createState() =>
      _AnimatedProductListItemState();
}

class _AnimatedProductListItemState
    extends State<_AnimatedProductListItem>
    with SingleTickerProviderStateMixin {
  double _rotateX = 0.0;
  double _rotateY = 0.0;

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    setState(() {
      _rotateX = (details.localPosition.dy - (size.height / 2)) /
          (size.height / 2) *
          -0.06;
      _rotateY = (details.localPosition.dx - (size.width / 2)) /
          (size.width / 2) *
          0.06;
      _rotateX = _rotateX.clamp(-0.06, 0.06);
      _rotateY = _rotateY.clamp(-0.06, 0.06);
    });
  }

  void _resetRotation() {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final cartonPrice = widget.isSpecialPrice
        ? widget.product.discountedPrice(widget.product.priceCartonSpecial)
        : widget.product.discountedPrice(widget.product.priceCartonNormal);
    final unitPrice = widget.isSpecialPrice
        ? widget.product.discountedPrice(widget.product.priceUnitSpecial)
        : widget.product.discountedPrice(widget.product.priceUnitNormal);

    // التحقق هل نحن على الحاسوب لتغيير شكل السطر بالكامل
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 200 + (widget.index * 40)),
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70, height: 70,
                      child: widget.product.imagePath.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.product.imagePath,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.inventory_2, color: Colors.grey),
                            ),
                          )
                        : Container(color: Colors.grey.shade100, child: const Icon(Icons.inventory_2, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 4),
                        if (widget.product.flavors.isNotEmpty)
                          Text('الأذواق: ${widget.product.flavors.map((f) => f.name).join(" - ")}', 
                               style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.product.canSellCarton)
                        Text('${cartonPrice.toStringAsFixed(0)} DA', 
                             style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 15)),
                      if (widget.product.canSellUnit)
                        Text('${unitPrice.toStringAsFixed(0)} DA / حبة', 
                             style: TextStyle(color: Colors.blue.shade700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton.icon(
                    onPressed: widget.product.isAvailable && !widget.maxReached ? widget.onAdd : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('أضف للسلة', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // التصميم القديم للهاتف يبقى كما هو
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (widget.index * 80)),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)), child: child),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _resetRotation(),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotateX)
              ..rotateY(_rotateY),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: widget.isDark ? 0.3 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14)),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: widget.product.imagePath.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: widget.product.imagePath,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Icon(Icons.image,
                            color: Color(0xFF2E7D32)),
                      ),
                    )
                        : Container(
                      color: const Color(0xFFE8F5E9),
                      child: const Icon(Icons.inventory_2,
                          color: Color(0xFF2E7D32), size: 40),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor),
                        ),
                        const SizedBox(height: 4),
                        if (widget.product.canSellCarton)
                          Text(
                            'كرتون: ${cartonPrice.toStringAsFixed(0)} DA',
                            style: TextStyle(
                                color: widget.isDark
                                    ? Colors.green.shade400
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        if (widget.product.discount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'خصم ${widget.product.discount.toInt()}%',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (widget.maxReached)
                          const Text(
                            '⚠️ وصلت الحد الأقصى',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: MouseRegion(
                    cursor: widget.product.isAvailable && !widget.maxReached
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.forbidden,
                    child: ElevatedButton(
                      onPressed:
                      widget.product.isAvailable && !widget.maxReached
                          ? widget.onAdd
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.maxReached
                            ? Colors.orange
                            : const Color(0xFF2E7D32),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 20),
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