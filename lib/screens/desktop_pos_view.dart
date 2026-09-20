import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DesktopPosView extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onCartChanged;
  const DesktopPosView({super.key, required this.cart, required this.onCartChanged});

  @override
  State<DesktopPosView> createState() => _DesktopPosViewState();
}

class _DesktopPosViewState extends State<DesktopPosView> {
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  final searchController = TextEditingController();
  bool isLoading = true;
  final formatter = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadProducts();
    searchController.addListener(_onSearch);
  }

  Future<void> _loadProducts() async {
    final data = await DataService.getAllProducts();
    if (mounted) {
      setState(() {
        allProducts = data;
        filteredProducts = data;
        isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredProducts = allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  void _addToCart(Product p, bool isCarton) {
    final existing = widget.cart.firstWhere(
      (i) => i.product.id == p.id && i.isCarton == isCarton,
      orElse: () => CartItem(product: p, quantity: 0, isCarton: isCarton),
    );

    if (existing.quantity > 0) {
      setState(() => existing.quantity++);
    } else {
      setState(() => widget.cart.add(CartItem(product: p, quantity: 1, isCarton: isCarton)));
    }
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن منتج (الاسم أو الباركود)...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: isLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, i) => _productTile(filteredProducts[i], isDark),
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            border: Border(right: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
          ),
          child: _buildCartSidebar(isDark),
        ),
      ],
    );
  }

  Widget _productTile(Product p, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _addToCart(p, true),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: p.imagePath.isNotEmpty 
                  ? CachedNetworkImage(imageUrl: p.imagePath, fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _quickAddBtn('كرتون', () => _addToCart(p, true), Colors.green),
                      _quickAddBtn('حبة', () => _addToCart(p, false), Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAddBtn(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCartSidebar(bool isDark) {
    final total = widget.cart.fold(0.0, (s, i) => s + i.totalPrice);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2E7D32),
          child: const Row(children: [Icon(Icons.shopping_cart, color: Colors.white), SizedBox(width: 8), Text('السلة السريعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
        ),
        Expanded(
          child: widget.cart.isEmpty 
            ? const Center(child: Text('السلة فارغة')) 
            : ListView.builder(
                itemCount: widget.cart.length,
                itemBuilder: (context, i) {
                  final it = widget.cart[i];
                  return ListTile(
                    title: Text(it.product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('${it.quantity} × ${it.typeLabel}', style: const TextStyle(fontSize: 11)),
                    trailing: Text('${formatter.format(it.totalPrice)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  );
                },
              ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المجموع:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${formatter.format(total)} DA', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: widget.cart.isEmpty ? null : () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)), child: const Text('إتمام البيع (F10)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ),
      ],
    );
  }
}
