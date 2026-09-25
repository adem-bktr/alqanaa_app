import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../utils/page_transitions.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'package:badges/badges.dart' as badges;

/// شاشة تعرض جميع منتجات فئة معينة
class CategoryProductsScreen extends StatefulWidget {
  final Category category;
  final List<CartItem> cart;
  final UserModel? user;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    required this.cart,
    this.user,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen>
    with SingleTickerProviderStateMixin {

  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  bool isSpecialPrice = false;
  UserModel? currentUser;
  final searchController = TextEditingController();
  bool isGridView = true;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // على الحاسوب نبدأ بنظام القائمة List
    isGridView = MediaQuery.of(context).size.width < 900;
    currentUser = widget.user;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    loadData();
    searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

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

      // جلب منتجات هذه الفئة
      final data = await DataService.getProductsByCategory(widget.category.id);
      if (mounted) {
        setState(() {
          products = data;
          filteredProducts = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('❌ CategoryProductsScreen loadData: $e');
    }
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredProducts = q.isEmpty
          ? products
          : products.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  bool _isMaxQtyReached(Product product) {
    if (currentUser == null || currentUser!.isAdmin) return false;
    final maxQty = currentUser!.isSpecial ? product.maxQtySpecial : product.maxQtyNormal;
    if (maxQty <= 0) return false;
    final cartQty = widget.cart
        .where((i) => i.product.id == product.id && i.isCarton)
        .fold(0, (sum, i) => sum + i.quantity);
    return cartQty >= maxQty;
  }

  void _addToCart(Product product) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final cartCount = widget.cart.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.category.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.category.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (isSpecialPrice)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF57F17).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: const Text('⭐ مميز', style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          badges.Badge(
            badgeContent: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
            showBadge: widget.cart.isNotEmpty,
            badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScreen(cart: widget.cart, isAdmin: false, user: currentUser),
                ),
              ).then((_) => setState(() {})),
            ),
          ),
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // شريط البحث
            Container(
              color: const Color(0xFF2E7D32),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () { searchController.clear(); _onSearch(); },
                  )
                      : null,
                  filled: true,
                  fillColor: searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // عداد المنتجات
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      '${filteredProducts.length} منتج',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            // قائمة المنتجات
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
    );
  }

  Widget _buildGridView(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _buildProductCard(product, index, isDark);
      },
    );
  }

  Widget _buildListView(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _buildProductListItem(product, index, isDark);
      },
    );
  }

  Widget _buildProductCard(Product product, int index, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final price = isSpecialPrice
        ? product.discountedPrice(product.priceCartonSpecial)
        : product.discountedPrice(product.priceCartonNormal);
    final maxReached = _isMaxQtyReached(product);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              cart: widget.cart,
              isSpecialPrice: isSpecialPrice,
              currentUser: currentUser,
            ),
          ),
        ).then((_) => setState(() {})),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: product.imagePath.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: product.imagePath,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.inventory_2, size: 50, color: Color(0xFF2E7D32)),
                        ),
                      )
                          : Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(child: Icon(Icons.inventory_2, size: 50, color: Color(0xFF2E7D32))),
                      ),
                    ),
                    if (product.discount > 0)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                          child: Text('-${product.discount.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (!product.isAvailable)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Container(
                            color: Colors.black54,
                            child: const Center(child: Text('غير متوفر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    if (maxReached)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Container(
                            color: Colors.orange.withOpacity(0.7),
                            child: const Center(child: Text('وصلت الحد الأقصى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
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
                      product.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (product.canSellCarton)
                      Text(
                        'كرتون: ${price.toStringAsFixed(0)} DA',
                        style: TextStyle(
                          color: isDark ? Colors.green.shade400 : const Color(0xFF2E7D32),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: product.isAvailable && !maxReached ? () => _addToCart(product) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: maxReached ? Colors.orange : product.isAvailable ? const Color(0xFF2E7D32) : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          maxReached ? 'وصلت الحد' : '+ إضافة',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
    );
  }

  Widget _buildProductListItem(Product product, int index, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final price = isSpecialPrice
        ? product.discountedPrice(product.priceCartonSpecial)
        : product.discountedPrice(product.priceCartonNormal);
    final maxReached = _isMaxQtyReached(product);

    // التحقق هل نحن على الحاسوب لتغيير شكل السطر بالكامل
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 200 + (index * 40)),
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: product,
                  cart: widget.cart,
                  isSpecialPrice: isSpecialPrice,
                  currentUser: currentUser,
                ),
              ),
            ).then((_) => setState(() {})),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 70, height: 70,
                      child: product.imagePath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imagePath,
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
                        Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 4),
                        if (product.flavors.isNotEmpty)
                          Text('الأذواق: ${product.flavors.map((f) => f.name).join(" - ")}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (product.canSellCarton)
                        Text('${price.toStringAsFixed(0)} DA',
                            style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 15)),
                      if (product.canSellUnit)
                        Text('${product.priceUnitNormal.toStringAsFixed(0)} DA / حبة',
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton.icon(
                    onPressed: product.isAvailable && !maxReached ? () => _addToCart(product) : null,
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product,
              cart: widget.cart,
              isSpecialPrice: isSpecialPrice,
              currentUser: currentUser,
            ),
          ),
        ).then((_) => setState(() {})),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: product.imagePath.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: product.imagePath,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.image, color: Color(0xFF2E7D32)),
                        ),
                      )
                      : Container(color: const Color(0xFFE8F5E9), child: const Icon(Icons.inventory_2, color: Color(0xFF2E7D32), size: 40)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      const SizedBox(height: 4),
                      if (product.canSellCarton)
                        Text(
                          'كرتون: ${price.toStringAsFixed(0)} DA',
                          style: TextStyle(color: isDark ? Colors.green.shade400 : const Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      if (product.discount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text('خصم ${product.discount.toInt()}%', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      if (maxReached)
                        const Text('⚠️ وصلت الحد الأقصى', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton(
                  onPressed: product.isAvailable && !maxReached ? () => _addToCart(product) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maxReached ? Colors.orange : const Color(0xFF2E7D32),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.68,
      ),
      itemCount: 4,
      itemBuilder: (_, index) => AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) => Container(
          decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.category.icon, style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            searchController.text.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد منتجات في هذه الفئة',
            style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}