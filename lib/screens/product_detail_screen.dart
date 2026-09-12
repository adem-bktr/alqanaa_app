import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import '../models/models.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final List<CartItem> cart;
  final bool isSpecialPrice;
  final UserModel? currentUser;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.cart,
    required this.isSpecialPrice,
    this.currentUser,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool isCarton = true;
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  late Map<String, int> flavorQuantities;
  int quantity = 1;

  String? _focusedFlavor;
  bool _quantityFocused = false;
  final FocusNode _screenFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  bool get isTablet  => MediaQuery.of(context).size.width >= 600;

  @override
  void initState() {
    super.initState();
    if (widget.product.sellType == SellType.unitOnly) isCarton = false;
    flavorQuantities = {
      for (var f in widget.product.flavors) f.name: 0,
    };
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════
  //  لوحة المفاتيح
  // ══════════════════════════════════
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;

    // ── تمرير الصفحة دائماً بـ ↑↓ ──
    if (!widget.product.hasFlavors || _focusedFlavor == null) {
      if (!_quantityFocused) {
        if (key == LogicalKeyboardKey.arrowUp) {
          _scrollController.animateTo(
            (_scrollController.offset - 80).clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          return;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _scrollController.animateTo(
            (_scrollController.offset + 80).clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          return;
        }
      }
    }

    // ── الأذواق ──
    if (widget.product.hasFlavors && _focusedFlavor != null) {
      final flavor = widget.product.flavors
          .firstWhere((f) => f.name == _focusedFlavor, orElse: () => widget.product.flavors.first);
      if (!flavor.isAvailable) return;

      if (key == LogicalKeyboardKey.arrowUp) {
        increaseFlavor(_focusedFlavor!);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        decreaseFlavor(_focusedFlavor!);
      } else if (key == LogicalKeyboardKey.tab) {
        _focusNextFlavor();
      }
      return;
    }

    // ── الكمية العادية ──
    if (!widget.product.hasFlavors && _quantityFocused) {
      if (key == LogicalKeyboardKey.arrowUp) {
        if (isCarton && maxQty > 0 && currentCartQty + quantity >= maxQty) {
          _showMaxQtySnackBar(); return;
        }
        setState(() => quantity++);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        if (quantity > 1) setState(() => quantity--);
      }
    }
  }

  void _focusNextFlavor() {
    final available = widget.product.flavors.where((f) => f.isAvailable).toList();
    if (available.isEmpty) return;
    final idx  = available.indexWhere((f) => f.name == _focusedFlavor);
    final next = (idx + 1) % available.length;
    setState(() => _focusedFlavor = available[next].name);
  }

  // ══════════════════════════════════
  //  Getters
  // ══════════════════════════════════
  int get maxQty {
    if (widget.currentUser == null || widget.currentUser!.isAdmin) return 0;
    if (widget.currentUser!.isSpecial) return widget.product.maxQtySpecial;
    return widget.product.maxQtyNormal;
  }

  double get cartonPrice => widget.isSpecialPrice
      ? widget.product.discountedPrice(widget.product.priceCartonSpecial)
      : widget.product.discountedPrice(widget.product.priceCartonNormal);

  double get unitPrice => widget.isSpecialPrice
      ? widget.product.discountedPrice(widget.product.priceUnitSpecial)
      : widget.product.discountedPrice(widget.product.priceUnitNormal);

  double get currentPrice    => isCarton ? cartonPrice : unitPrice;
  int    get totalFlavorQty  => flavorQuantities.values.fold(0, (s, q) => s + q);
  double get totalFlavorPrice => currentPrice * totalFlavorQty;

  int get currentCartQty => widget.cart
      .where((i) => i.product.id == widget.product.id && i.isCarton == isCarton)
      .fold(0, (s, i) => s + i.quantity);

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showMaxQtySnackBar() =>
      _showSnackBar('⚠️ لا يمكنك طلب أكثر من $maxQty كرتون', Colors.orange);

  void increaseFlavor(String name) {
    if (isCarton && maxQty > 0 && currentCartQty + totalFlavorQty >= maxQty) {
      _showMaxQtySnackBar(); return;
    }
    setState(() => flavorQuantities[name] = (flavorQuantities[name] ?? 0) + 1);
  }

  void decreaseFlavor(String name) {
    final cur = flavorQuantities[name] ?? 0;
    if (cur > 0) setState(() => flavorQuantities[name] = cur - 1);
  }

  void addToCart() {
    if (!widget.product.isAvailable) return;

    if (widget.product.hasFlavors) {
      if (totalFlavorQty == 0) {
        _showSnackBar('⚠️ الرجاء اختيار كمية طعم واحد على الأقل', Colors.orange);
        return;
      }
      for (final entry in flavorQuantities.entries) {
        if (entry.value > 0) {
          final existing = widget.cart.firstWhere(
                (i) => i.product.id == widget.product.id &&
                i.isCarton == isCarton && i.flavor == entry.key,
            orElse: () => CartItem(
              product: widget.product, quantity: 0,
              isSpecialPrice: widget.isSpecialPrice,
              isCarton: isCarton, flavor: entry.key,
            ),
          );
          if (existing.quantity > 0) {
            existing.quantity += entry.value;
          } else {
            widget.cart.add(CartItem(
              product: widget.product, quantity: entry.value,
              isSpecialPrice: widget.isSpecialPrice,
              isCarton: isCarton, flavor: entry.key,
            ));
          }
        }
      }
      _showSnackBar(
        '✅ تمت الإضافة - $totalFlavorQty ${isCarton ? 'كرتون' : 'حبة'}',
        const Color(0xFF2E7D32),
      );
    } else {
      if (isCarton && maxQty > 0 && currentCartQty + quantity > maxQty) {
        _showSnackBar('❌ لا يمكنك طلب أكثر من $maxQty كرتون', Colors.red);
        return;
      }
      final existing = widget.cart.firstWhere(
            (i) => i.product.id == widget.product.id &&
            i.isCarton == isCarton && i.flavor == null,
        orElse: () => CartItem(
          product: widget.product, quantity: 0,
          isSpecialPrice: widget.isSpecialPrice, isCarton: isCarton,
        ),
      );
      if (existing.quantity > 0) {
        existing.quantity += quantity;
      } else {
        widget.cart.add(CartItem(
          product: widget.product, quantity: quantity,
          isSpecialPrice: widget.isSpecialPrice, isCarton: isCarton,
        ));
      }
      _showSnackBar(
        '✅ تمت الإضافة - $quantity ${isCarton ? 'كرتون' : 'حبة'}',
        const Color(0xFF2E7D32),
      );
    }
    Navigator.pop(context);
  }

  // ══════════════════════════════════
  //  Price Row
  // ══════════════════════════════════
  Widget _priceRow({
    required IconData icon, required String label,
    required double price, double? originalPrice,
    required Color color, required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (originalPrice != null)
              Text('${formatter.format(originalPrice)} DA',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11, decoration: TextDecoration.lineThrough)),
            Text('${formatter.format(price)} DA',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //  قسم الأذواق
  // ══════════════════════════════════
  Widget _buildFlavorsSection(
      Color cardColor, Color textColor, Color subColor, bool isDark) {
    return _SectionAnimator(
      delay: 400,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('اختر الأذواق',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                if (totalFlavorQty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                    child: Text('المجموع: $totalFlavorQty ${isCarton ? 'كرتون' : 'حبة'}',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            // ✅ تم حذف النص التلميحي هنا

            const SizedBox(height: 12),

            ...widget.product.flavors.map((flavor) {
              final qty          = flavorQuantities[flavor.name] ?? 0;
              final isMaxReached = isCarton && maxQty > 0 && currentCartQty + totalFlavorQty >= maxQty;
              final isUnavailable = !flavor.isAvailable;
              final isFocused    = isDesktop && _focusedFlavor == flavor.name;

              return Opacity(
                opacity: isUnavailable ? 0.5 : 1.0,
                child: MouseRegion(
                  // ✅ تغيير شكل الفأرة
                  cursor: isUnavailable
                      ? SystemMouseCursors.forbidden
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: isDesktop && !isUnavailable
                        ? () => setState(() {
                      _focusedFlavor   = flavor.name;
                      _quantityFocused = false;
                      _screenFocusNode.requestFocus();
                    })
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUnavailable
                            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                            : qty > 0
                            ? const Color(0xFFE8F5E9)
                            : isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? Colors.blue
                              : isUnavailable
                              ? Colors.grey.shade400
                              : qty > 0
                              ? const Color(0xFF2E7D32)
                              : Colors.transparent,
                          width: isFocused ? 2 : 1.5,
                        ),
                        boxShadow: isFocused
                            ? [BoxShadow(
                            color: Colors.blue.withOpacity(0.25),
                            blurRadius: 8, spreadRadius: 1)]
                            : null,
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isUnavailable
                                  ? Colors.grey.shade400
                                  : isFocused
                                  ? Colors.blue
                                  : qty > 0
                                  ? const Color(0xFF2E7D32)
                                  : isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: isUnavailable
                                  ? const Icon(Icons.block, color: Colors.white, size: 20)
                                  : isFocused
                                  ? const Icon(Icons.unfold_more_rounded, color: Colors.white, size: 20)
                                  : const Icon(Icons.icecream_outlined, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(flavor.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isFocused
                                            ? Colors.blue
                                            : isUnavailable ? Colors.grey : textColor,
                                        fontSize: 14,
                                        decoration: isUnavailable ? TextDecoration.lineThrough : null,
                                      )),
                                  const SizedBox(width: 8),
                                  if (isFocused)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blue.withOpacity(0.4)),
                                      ),
                                      child: const Text('↑↓ للتعديل',
                                          style: TextStyle(
                                              color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  if (isUnavailable)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                                      ),
                                      child: const Text('غير متوفر',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ]),
                                if (qty > 0 && !isUnavailable)
                                  Text('${formatter.format(currentPrice * qty)} DA',
                                      style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          // ✅ أزرار +/- مع تغيير شكل الفأرة
                          Row(children: [
                            MouseRegion(
                              cursor: isUnavailable
                                  ? SystemMouseCursors.forbidden
                                  : qty > 0
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              child: GestureDetector(
                                onTap: isUnavailable ? null : () => decreaseFlavor(flavor.name),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: isUnavailable
                                        ? Colors.grey.shade300
                                        : qty > 0
                                        ? const Color(0xFF2E7D32)
                                        : isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.remove, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Center(
                                child: Text('$qty',
                                    style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold,
                                      color: isUnavailable
                                          ? Colors.grey
                                          : qty > 0 ? const Color(0xFF2E7D32) : subColor,
                                    )),
                              ),
                            ),
                            MouseRegion(
                              cursor: isUnavailable
                                  ? SystemMouseCursors.forbidden
                                  : isMaxReached
                                  ? SystemMouseCursors.forbidden
                                  : SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: isUnavailable ? null : () => increaseFlavor(flavor.name),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: isUnavailable
                                        ? Colors.grey.shade300
                                        : isMaxReached
                                        ? isDark ? Colors.grey.shade700 : Colors.grey.shade300
                                        : const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            if (isCarton && maxQty > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (maxQty - currentCartQty - totalFlavorQty) <= 0
                      ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      color: (maxQty - currentCartQty - totalFlavorQty) <= 0
                          ? Colors.red : Colors.orange,
                      size: 16),
                  const SizedBox(width: 6),
                  Text('متبقي: ${maxQty - currentCartQty - totalFlavorQty} كرتون من $maxQty',
                      style: TextStyle(
                        color: (maxQty - currentCartQty - totalFlavorQty) <= 0
                            ? Colors.red : Colors.orange,
                        fontSize: 12, fontWeight: FontWeight.bold,
                      )),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  قسم الكمية العادية
  // ══════════════════════════════════
  Widget _buildNormalQuantitySection(Color cardColor, Color textColor, Color subColor) {
    final isMaxReached = isCarton && maxQty > 0 && currentCartQty + quantity >= maxQty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SectionAnimator(
      delay: 400,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isDesktop
              ? () => setState(() {
            _quantityFocused = true;
            _focusedFlavor   = null;
            _screenFocusNode.requestFocus();
          })
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isDesktop && _quantityFocused
                  ? Border.all(color: Colors.blue, width: 2) : null,
              boxShadow: [
                if (isDesktop && _quantityFocused)
                  BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 8, spreadRadius: 1)
                else
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('الكمية (${isCarton ? 'كرتون' : 'حبة'})',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const Spacer(),
                  if (isDesktop && _quantityFocused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_up_rounded, color: Colors.blue, size: 14),
                          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue, size: 14),
                          SizedBox(width: 4),
                          Text('للتعديل', style: TextStyle(color: Colors.blue, fontSize: 11)),
                        ],
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✅ زر - مع تغيير شكل الفأرة
                    MouseRegion(
                      cursor: quantity > 1
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.forbidden,
                      child: GestureDetector(
                        onTap: () { if (quantity > 1) setState(() => quantity--); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: quantity > 1 ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.remove, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    Column(children: [
                      if (isDesktop && _quantityFocused)
                        const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.blue, size: 20),
                      Text('$quantity',
                          style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold,
                            color: _quantityFocused ? Colors.blue : const Color(0xFF2E7D32),
                          )),
                      if (isDesktop && _quantityFocused)
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blue, size: 20),
                      Text('${formatter.format(currentPrice * quantity)} DA',
                          style: TextStyle(color: subColor, fontSize: 13)),
                      if (isCarton && maxQty > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMaxReached
                                ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('متبقي: ${maxQty - currentCartQty - quantity} كرتون',
                              style: TextStyle(
                                color: isMaxReached ? Colors.red : Colors.orange,
                                fontSize: 11, fontWeight: FontWeight.bold,
                              )),
                        ),
                      ],
                    ]),
                    // ✅ زر + مع تغيير شكل الفأرة
                    MouseRegion(
                      cursor: isMaxReached
                          ? SystemMouseCursors.forbidden
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (isCarton && maxQty > 0 && currentCartQty + quantity >= maxQty) {
                            _showMaxQtySnackBar(); return;
                          }
                          setState(() => quantity++);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: isMaxReached ? Colors.grey.shade300 : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  المحتوى المشترك
  // ══════════════════════════════════
  Widget _buildContent(Color bgColor, Color cardColor, Color textColor, Color subColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionAnimator(
          delay: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(widget.product.name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.product.isAvailable
                      ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.product.isAvailable ? '✅ متوفر' : '❌ غير متوفر',
                  style: TextStyle(
                    color: widget.product.isAvailable ? const Color(0xFF2E7D32) : Colors.red,
                    fontWeight: FontWeight.bold, fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (widget.isSpecialPrice)
          _SectionAnimator(
            delay: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFC107)),
              ),
              child: const Text('⭐ سعر مميز',
                  style: TextStyle(
                      color: Color(0xFFF57F17), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 16),

        if (widget.product.sellType == SellType.both)
          _SectionAnimator(
            delay: 200,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => isCarton = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isCarton ? const Color(0xFF2E7D32) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2, size: 18,
                                color: isCarton ? Colors.white : subColor),
                            const SizedBox(width: 6),
                            Text('كرتون', style: TextStyle(
                                color: isCarton ? Colors.white : subColor,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() { isCarton = false; quantity = 1; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isCarton ? const Color(0xFF2E7D32) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 18,
                                color: !isCarton ? Colors.white : subColor),
                            const SizedBox(width: 6),
                            Text('حبة', style: TextStyle(
                                color: !isCarton ? Colors.white : subColor,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        if (widget.product.sellType == SellType.both) const SizedBox(height: 16),

        _SectionAnimator(
          delay: 300,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              if (widget.product.canSellCarton)
                _priceRow(
                  icon: Icons.inventory_2, label: 'سعر الكرتون', price: cartonPrice,
                  originalPrice: widget.product.discount > 0
                      ? (widget.isSpecialPrice
                      ? widget.product.priceCartonSpecial
                      : widget.product.priceCartonNormal)
                      : null,
                  color: const Color(0xFF2E7D32), textColor: textColor,
                ),
              if (widget.product.sellType == SellType.both)
                Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              if (widget.product.canSellUnit)
                _priceRow(
                  icon: Icons.shopping_bag_outlined, label: 'سعر الحبة', price: unitPrice,
                  originalPrice: widget.product.discount > 0
                      ? (widget.isSpecialPrice
                      ? widget.product.priceUnitSpecial
                      : widget.product.priceUnitNormal)
                      : null,
                  color: const Color(0xFF388E3C), textColor: textColor,
                ),
              if (isCarton && maxQty > 0) ...[
                Divider(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text('الحد الأقصى', style: TextStyle(color: subColor, fontSize: 13)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text('$maxQty كرتون',
                          style: const TextStyle(
                              color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),

        if (widget.product.hasFlavors)
          _buildFlavorsSection(cardColor, textColor, subColor, isDark)
        else
          _buildNormalQuantitySection(cardColor, textColor, subColor),

        const SizedBox(height: 100),
      ],
    );
  }

  // ══════════════════════════════════
  //  زر إضافة للسلة
  // ══════════════════════════════════
  Widget _buildAddToCartButton(Color cardColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Transform.translate(
        offset: Offset(0, 50 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: MouseRegion(
            // ✅ تغيير شكل الفأرة على زر الإضافة
            cursor: widget.product.isAvailable
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: ElevatedButton.icon(
              onPressed: widget.product.isAvailable ? addToCart : null,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                widget.product.hasFlavors
                    ? totalFlavorQty > 0
                    ? 'إضافة للسلة - ${formatter.format(totalFlavorPrice)} DA'
                    : 'اختر الأذواق أولاً'
                    : 'إضافة للسلة - ${formatter.format(currentPrice * quantity)} DA',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.product.isAvailable
                    ? const Color(0xFF2E7D32) : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Build
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return KeyboardListener(
      focusNode: _screenFocusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: bgColor,

        // ══════════════════════════════════
        //  Desktop
        // ══════════════════════════════════
        body: isDesktop
            ? Row(children: [
          // الجانب الأيسر: صورة
          Expanded(
            flex: 5,
            child: Stack(children: [
              Positioned.fill(
                child: widget.product.imagePath.isNotEmpty
                    ? Image.network(
                  widget.product.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFE8F5E9),
                    child: const Icon(Icons.image, size: 80, color: Color(0xFF2E7D32)),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFE8F5E9),
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
                    );
                  },
                )
                    : Container(
                  color: const Color(0xFFE8F5E9),
                  child: const Icon(Icons.inventory_2, size: 80, color: Color(0xFF2E7D32)),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, bgColor.withOpacity(0.9)],
                    ),
                  ),
                ),
              ),
              if (widget.product.discount > 0)
                Positioned(
                  top: 24, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    child: Text('-${widget.product.discount.toInt()}%',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              Positioned(
                top: 16, left: 16,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // الجانب الأيمن: تفاصيل
          Expanded(
            flex: 5,
            child: Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  child: _buildContent(bgColor, cardColor, textColor, subColor, isDark),
                ),
              ),
              _buildAddToCartButton(cardColor),
            ]),
          ),
        ])

        // ══════════════════════════════════
        //  Mobile / Tablet
        // ══════════════════════════════════
            : Column(children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: const Color(0xFF2E7D32),
                  leading: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.product.imagePath.isNotEmpty
                            ? Image.network(
                          widget.product.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE8F5E9),
                            child: const Icon(Icons.image, size: 80, color: Color(0xFF2E7D32)),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFE8F5E9),
                              child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
                            );
                          },
                        )
                            : Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.inventory_2, size: 80, color: Color(0xFF2E7D32)),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, bgColor.withOpacity(0.8)],
                              ),
                            ),
                          ),
                        ),
                        if (widget.product.discount > 0)
                          Positioned(
                            top: 80, right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.red, borderRadius: BorderRadius.circular(12)),
                              child: Text('-${widget.product.discount.toInt()}%',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildContent(bgColor, cardColor, textColor, subColor, isDark),
                  ),
                ),
              ],
            ),
          ),
          _buildAddToCartButton(cardColor),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════
//  _SectionAnimator (بدون تغيير)
// ══════════════════════════════════
class _SectionAnimator extends StatelessWidget {
  final int delay;
  final Widget child;
  const _SectionAnimator({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value.clamp(0.0, 1.0))),
          child: child,
        ),
      ),
      child: child,
    );
  }
}