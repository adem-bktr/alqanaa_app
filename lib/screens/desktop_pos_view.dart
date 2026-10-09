import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/receipt_preview_dialog.dart';
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
  List<CustomerModel> allCustomers = [];
  final searchController = TextEditingController();
  bool isLoading = true;
  bool _isSaving = false; // ✅ يمنع إتمام فاتورتين في نفس الوقت (نقر مزدوج / F10 متكرر)
  bool _specialPrice = false; // ✅ البيع بالسعر الخاص
  final formatter = NumberFormat('#,##0', 'en_US');
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode(); // ✅ كان يُنشأ FocusNode جديد في كل build

  @override
  void initState() {
    super.initState();
    _loadData();
    searchController.addListener(_applyFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ══════════════════════════════════
  //  تحميل البيانات
  // ══════════════════════════════════
  Future<void> _loadData({bool silent = false}) async {
    try {
      final pData = await DataService.getAllProducts();
      final cData = await DataService.getCustomers();
      if (!mounted) return;
      setState(() {
        allProducts = pData;
        allCustomers = cData;
        isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      debugPrint('❌ _loadData: $e');
      if (mounted && !silent) setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    final q = searchController.text.toLowerCase().trim();
    setState(() {
      filteredProducts = q.isEmpty
          ? List.of(allProducts)
          : allProducts
          .where((p) => p.name.toLowerCase().contains(q) || p.id.contains(q))
          .toList();
    });
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════
  //  الأسعار والمخزون
  // ══════════════════════════════════
  double _cartonPrice(Product p) => p.discountedPrice(
      _specialPrice ? p.priceCartonSpecial : p.priceCartonNormal);

  double _unitPrice(Product p) => p.discountedPrice(
      _specialPrice ? p.priceUnitSpecial : p.priceUnitNormal);

  String _stockLabel(Product p) {
    final s = p.stockQuantity;
    if (s < 0) return 'المخزون: ${formatQuantity(s)} حبة';
    if (p.unitsPerCarton > 1) {
      final crt = s ~/ p.unitsPerCarton;
      final pcs = s % p.unitsPerCarton;
      return 'المخزون: $crt كرتون و ${formatQuantity(pcs)} حبة';
    }
    return 'المخزون: ${formatQuantity(s)} قطعة';
  }

  /// عدد الحبات التي في السلة لمنتج معيّن (الكرتون يُحوَّل إلى حبات)
  double _piecesInCart(String productId) {
    double total = 0.0;
    for (final i in widget.cart) {
      if (i.product.id != productId) continue;
      final upc = i.product.unitsPerCarton > 0 ? i.product.unitsPerCarton : 1;
      total += i.isCarton ? i.quantity * upc : i.quantity;
    }
    return total;
  }

  Product _freshProduct(Product fallback) {
    for (final p in allProducts) {
      if (p.id == fallback.id) return p;
    }
    return fallback;
  }

  void _warnIfOverStock(Product p) {
    final fresh = _freshProduct(p);
    final inCart = _piecesInCart(fresh.id);
    if (inCart > fresh.stockQuantity) {
      _snack(
        '⚠️ ${fresh.name}: في السلة ${formatQuantity(inCart)} حبة والمخزون ${formatQuantity(fresh.stockQuantity)} حبة',
        Colors.orange,
      );
    }
  }

  /// أسطر تصف المنتجات التي تتجاوز كميتها المخزون
  List<String> _overStockLines() {
    final lines = <String>[];
    final ids = widget.cart.map((i) => i.product.id).toSet();
    for (final id in ids) {
      final inCartProduct =
          widget.cart.firstWhere((i) => i.product.id == id).product;
      final fresh = _freshProduct(inCartProduct);
      final inCart = _piecesInCart(id);
      if (inCart > fresh.stockQuantity) {
        lines.add('• ${fresh.name}: في السلة ${formatQuantity(inCart)} حبة، المخزون ${formatQuantity(fresh.stockQuantity)}');
      }
    }
    return lines;
  }

  // ══════════════════════════════════
  //  السلة
  // ══════════════════════════════════
  Future<String?> _selectFlavorDialog(Product p) async {
    if (p.flavors.isEmpty) return null;
    final availableFlavors = p.flavors.where((f) => f.isAvailable).toList();
    if (availableFlavors.isEmpty) return null;

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر الذوق لـ ${p.name}'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableFlavors.length,
            itemBuilder: (context, i) {
              final flavor = availableFlavors[i];
              return ListTile(
                title: Text(flavor.name),
                leading: const Icon(Icons.restaurant_menu, color: Color(0xFF2E7D32)),
                onTap: () => Navigator.pop(context, flavor.name),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addToCart(Product p, bool isCarton) async {
    // ✅ لا يُباع منتج غير متوفر
    if (!p.isAvailable) {
      _snack('⛔ ${p.name} غير متوفر حالياً', Colors.red);
      _searchFocusNode.requestFocus();
      return;
    }

    String? chosenFlavor;
    if (p.flavors.isNotEmpty) {
      chosenFlavor = await _selectFlavorDialog(p);
      if (chosenFlavor == null) {
        _searchFocusNode.requestFocus();
        return;
      }
    }
    if (!mounted) return;

    final idx = widget.cart.indexWhere((i) =>
    i.product.id == p.id &&
        i.isCarton == isCarton &&
        i.flavor == chosenFlavor &&
        i.isSpecialPrice == _specialPrice);

    setState(() {
      if (idx >= 0) {
        widget.cart[idx].quantity++;
      } else {
        widget.cart.add(CartItem(
          product: p,
          quantity: 1,
          isCarton: isCarton,
          flavor: chosenFlavor,
          isSpecialPrice: _specialPrice,
        ));
      }
    });
    widget.onCartChanged();
    _warnIfOverStock(p);
    _searchFocusNode.requestFocus();
  }

  /// ✅ تبديل السعر العادي/الخاص: نعيد بناء عناصر السلة (isSpecialPrice غير قابل للتعديل)
  void _setSpecialPrice(bool v) {
    setState(() {
      _specialPrice = v;
      for (int i = 0; i < widget.cart.length; i++) {
        final it = widget.cart[i];
        widget.cart[i] = CartItem(
          product: it.product,
          quantity: it.quantity,
          isSpecialPrice: v,
          isCarton: it.isCarton,
          flavor: it.flavor,
          overridePrice: it.overridePrice,
        );
      }
    });
    widget.onCartChanged();
  }

  /// ✅ تعديل سعر صنف لهذه الفاتورة فقط
  Future<void> _editItemPrice(CartItem item) async {
    final result = await showDialog<_PriceResult>(
      context: context,
      builder: (_) => _EditPriceDialog(item: item),
    );
    if (result == null || !mounted) return;
    setState(() {
      item.overridePrice = result.reset ? null : result.price;
    });
    widget.onCartChanged();
    _searchFocusNode.requestFocus();
  }

  // ══════════════════════════════════
  //  إتمام البيع
  // ══════════════════════════════════
  Future<void> _showCheckoutDialog() async {
    if (widget.cart.isEmpty || _isSaving) return;

    // ✅ تنبيه إذا كانت الكميات تتجاوز المخزون (يمكنك المتابعة)
    final over = _overStockLines();
    if (over.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('كميات تتجاوز المخزون'),
            ],
          ),
          content: Text('${over.join('\n')}\n\nهل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('رجوع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    final total = widget.cart.fold(0.0, (s, i) => s + i.totalPrice);
    final result = await showDialog<_CheckoutResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        total: total,
        customers: allCustomers,
        formatter: formatter,
      ),
    );
    if (result == null || !mounted) {
      _searchFocusNode.requestFocus();
      return;
    }
    await _completeSale(total, result);
  }

  Future<void> _completeSale(double total, _CheckoutResult r) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final remaining = total - r.paid;
      final debt = remaining > 0.05 ? remaining : 0.0;
      final prevBalance = r.customer?.balance ?? 0.0;
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final order = Order(
        id: orderId,
        customerName: r.name.isEmpty ? 'زبون عادي' : r.name,
        customerPhone: r.phone,
        items: widget.cart
            .map((i) => {
          // ✅ بدون productId لا يخصم saveOrder المخزون ولا يُحسب الربح بدقة
          'productId': i.product.id,
          'productName': i.product.name,
          'quantity': i.quantity,
          'price': i.unitPrice,
          'unitPrice': i.unitPrice,
          'isCarton': i.isCarton,
          'typeLabel': i.typeLabel,
          'flavor': i.flavor ?? '',
          // ✅ تكلفة الشراء وقت البيع (لسجل الأرباح)
          'cost': i.isCarton
              ? i.product.purchasePrice * i.product.unitsPerCarton
              : i.product.purchasePrice,
          'priceOverridden': i.hasOverridePrice,
        })
            .toList(),
        total: total,
        createdAt: DateTime.now(),
        // 'confirmed' يعرفه التطبيق في كل الشاشات (بخلاف 'delivered' الذي كان يظهر "قيد المراجعة")
        status: 'confirmed',
        isSpecialPrice: _specialPrice,
        date: DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now()),
        paidAmount: r.paid,
        // نفس منطق cart_screen: رصيد الزبون بعد هذه الفاتورة (0 إن لم تُربط بزبون)
        remainingBalance: r.customer != null ? prevBalance + debt : 0.0,
      );

      await DataService.saveOrder(order);

      // ✅ تسجيل الدين على الزبون مع ربطه بالفاتورة (لمزامنته عند تعديلها)
      if (r.customer != null && debt > 0) {
        try {
          await DataService.addDebtTransaction(
            customerId: r.customer!.id,
            type: 'charge',
            amount: debt,
            note:
            'دين متبقي من فاتورة بيع سريع رقم #${orderId.substring(orderId.length - 4)}',
            orderId: orderId,
          );
        } catch (e) {
          debugPrint('❌ فشل تسجيل الدين: $e');
          _snack(
              '⚠️ الفاتورة حُفظت لكن تسجيل الدين فشل. سجّله يدوياً على ${r.customer!.name}.',
              Colors.orange);
        }
      }

      if (!mounted) return;

      // ✅ نفرّغ السلة فور نجاح الحفظ (قبل المعاينة) حتى لا تتكرر الفاتورة
      setState(() => widget.cart.clear());
      widget.onCartChanged();
      _loadData(silent: true); // تحديث المخزون وأرصدة الزبائن في الذاكرة

      await ReceiptPreviewDialog.show(
        context,
        order: order,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        amountPaid: r.paid,
        customerDebtBalance: prevBalance, // ✅ الرصيد السابق (Ancien Solde)
      );
    } catch (e) {
      debugPrint('❌ _completeSale: $e');
      _snack('❌ فشل حفظ الفاتورة، لم يُسجَّل شيء. السلة ما زالت كما هي. ($e)', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
      _searchFocusNode.requestFocus();
    }
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            _searchFocusNode.requestFocus();
          } else if (event.logicalKey == LogicalKeyboardKey.f10 || event.logicalKey == LogicalKeyboardKey.f5) {
            _showCheckoutDialog();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            FocusScope.of(context).unfocus();
          }
        }
      },
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'بحث عن منتج بالاسم... [F1]',
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
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, i) => _productRow(filteredProducts[i], isDark),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              border: Border(right: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: _buildCartSidebar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _productRow(Product p, bool isDark) {
    final showCarton = p.sellType == SellType.cartonOnly || p.sellType == SellType.both;
    final showUnit = p.sellType == SellType.unitOnly || p.sellType == SellType.both;
    final available = p.isAvailable;

    return Opacity(
      opacity: available ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.imagePath.isNotEmpty
                      ? CachedNetworkImage(imageUrl: p.imagePath, width: 55, height: 55, fit: BoxFit.cover)
                      : Container(width: 55, height: 55, color: Colors.grey.shade100, child: const Icon(Icons.fastfood, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (!available) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Text('غير متوفر', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (p.discount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                            child: Text('-${p.discount.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stockLabel(p),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: p.stockQuantity <= 0 ? Colors.red : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (p.flavors.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: p.flavors.map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: f.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(f.name, style: TextStyle(fontSize: 10, color: f.isAvailable ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                        )).toList(),
                      )
                    else
                      Text('بدون أذواق فرعية', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showCarton) Text('${formatter.format(_cartonPrice(p))} DA', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 14)),
                  if (showUnit) Text('${formatter.format(_unitPrice(p))} DA / حبة', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showCarton)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      onPressed: available ? () => _addToCart(p, true) : null,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('أضف كرتون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  if (showUnit)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      onPressed: available ? () => _addToCart(p, false) : null,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('أضف حبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSidebar(bool isDark) {
    final total = widget.cart.fold(0.0, (s, i) => s + i.totalPrice);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          color: const Color(0xFF2E7D32),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('سلة البيع السريعة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              // ✅ البيع بالسعر الخاص
              const Text('سعر خاص', style: TextStyle(color: Colors.white, fontSize: 12)),
              Switch(
                value: _specialPrice,
                activeColor: Colors.amber,
                onChanged: _setSpecialPrice,
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.cart.isEmpty
              ? const Center(child: Text('السلة فارغة، أضف سلعاً لبدء البيع'))
              : ListView.builder(
            itemCount: widget.cart.length,
            itemBuilder: (context, i) {
              final it = widget.cart[i];
              return _CartItemTileWidget(
                key: ValueKey('${it.product.id}_${it.isCarton}_${it.flavor}_${it.isSpecialPrice}'),
                item: it,
                formatter: formatter,
                onChanged: () {
                  setState(() {});
                  widget.onCartChanged();
                },
                onRemove: () {
                  setState(() {
                    widget.cart.remove(it);
                  });
                  widget.onCartChanged();
                },
                onEditPrice: () => _editItemPrice(it),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('${formatter.format(total)} DA', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))]),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                    onPressed: (widget.cart.isEmpty || _isSaving) ? null : _showCheckoutDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('إتمام وحفظ الفاتورة (F10)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
                )
            ),
          ]),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
//  نافذة إتمام البيع (تملك متحكماتها وتتلفها بنفسها)
// ══════════════════════════════════════════════════════
class _CheckoutResult {
  final CustomerModel? customer;
  final String name;
  final String phone;
  final double paid;
  const _CheckoutResult({
    required this.customer,
    required this.name,
    required this.phone,
    required this.paid,
  });
}

class _CheckoutDialog extends StatefulWidget {
  final double total;
  final List<CustomerModel> customers;
  final NumberFormat formatter;
  const _CheckoutDialog({
    required this.total,
    required this.customers,
    required this.formatter,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late List<CustomerModel> _customers;
  CustomerModel? _selected;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _customers = List.of(widget.customers);
    // ✅ لا نقرّب المبلغ المدفوع (كان toStringAsFixed(0) فيظهر دين وهمي)
    final t = widget.total;
    _paidCtrl.text = t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _paidCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double? _parsePaid() {
    final t = _paidCtrl.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return widget.total;
    return double.tryParse(t);
  }

  void _select(CustomerModel c) {
    setState(() {
      _selected = c;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _searchCtrl.text = c.name;
      _error = null;
    });
  }

  void _confirm() {
    final paid = _parsePaid();
    if (paid == null || paid < 0) {
      setState(() => _error = 'أدخل مبلغاً مدفوعاً صحيحاً');
      return;
    }
    final rest = widget.total - paid;
    // ✅ لا نترك ديناً بلا صاحب
    if (rest > 0.05 && _selected == null) {
      setState(() => _error =
      'يوجد دين متبقٍ (${widget.formatter.format(rest)} DA). اختر زبوناً من الدليل أو أضف زبوناً جديداً لتسجيله عليه، أو سدّد المبلغ كاملاً.');
      return;
    }
    Navigator.pop(
      context,
      _CheckoutResult(
        customer: _selected,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        paid: paid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.formatter;
    final q = _searchCtrl.text.toLowerCase();
    final filtered = _customers
        .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();

    final paid = _parsePaid() ?? widget.total;
    final rest = widget.total - paid;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.monetization_on, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Text('إتمام البيع واختيار الزبون'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إجمالي الفاتورة: ${f.format(widget.total)} DA',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const Divider(height: 24),

              // البحث الذكي عن زبون
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'ابحث عن زبون (الاسم أو الهاتف)...',
                                icon: Icon(Icons.person_search, color: Color(0xFF2E7D32)),
                                border: InputBorder.none,
                              ),
                              onChanged: (v) => setState(() {}),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty && _selected == null)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final c = filtered[i];
                                  return ListTile(
                                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                    subtitle: Text(c.phone),
                                    trailing: Text('${f.format(c.balance)} DA',
                                        style: const TextStyle(color: Colors.red, fontSize: 11)),
                                    onTap: () => _select(c),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final newC = await showDialog<CustomerModel>(
                        context: context,
                        builder: (_) => const _AddCustomerDialog(),
                      );
                      if (newC != null && mounted) {
                        _customers.add(newC);
                        _select(newC);
                      }
                    },
                    icon: const Icon(Icons.person_add),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    tooltip: 'إضافة زبون جديد',
                  ),
                ],
              ),

              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'تم اختيار: ${_selected!.name}'
                              '${_selected!.balance > 0 ? '  •  دين سابق: ${f.format(_selected!.balance)} DA' : ''}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selected = null;
                          _searchCtrl.clear();
                          _nameCtrl.clear();
                          _phoneCtrl.clear();
                        }),
                        child: const Text('تغيير', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الزبون (يدوي)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع (كاش)', border: OutlineInputBorder(), suffixText: 'DA'),
                onChanged: (v) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rest > 0.05 ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('حالة الحساب:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    Flexible(
                      child: Text(
                        rest > 0.05
                            ? 'باقي دين: ${f.format(rest)} DA'
                            : rest < -0.05
                            ? 'الباقي للزبون: ${f.format(-rest)} DA'
                            : 'خالص (مدفوع بالكامل)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: rest > 0.05 ? Colors.red : Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: _confirm,
          child: const Text('إتمام وحفظ الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
//  نافذة إضافة زبون جديد
// ══════════════════════════════════════════════════════
class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog();

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'أدخل اسم الزبون ورقم هاتفه');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = CustomerModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phone: phone,
        balance: 0,
        createdAt: DateTime.now(),
      );
      await DataService.saveCustomer(c);
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'فشل حفظ الزبون، تحقق من الاتصال';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [Icon(Icons.person_add, color: Color(0xFF2E7D32)), SizedBox(width: 8), Text('إضافة زبون جديد')],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الزبون الكامل', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('حفظ الزبون', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
//  نافذة تعديل سعر صنف (لهذه الفاتورة فقط)
// ══════════════════════════════════════════════════════
class _PriceResult {
  final double? price;
  final bool reset;
  const _PriceResult({this.price, this.reset = false});
}

class _EditPriceDialog extends StatefulWidget {
  final CartItem item;
  const _EditPriceDialog({required this.item});

  @override
  State<_EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<_EditPriceDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.unitPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return AlertDialog(
      title: Text('تعديل سعر ${it.product.name}', style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السعر الأصلي للوحدة (${it.typeLabel}): ${it.originalUnitPrice.toStringAsFixed(2)} DA',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'السعر الجديد للوحدة',
              suffixText: 'DA',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        if (it.hasOverridePrice)
          TextButton(
            onPressed: () => Navigator.pop(context, const _PriceResult(reset: true)),
            child: const Text('السعر الأصلي', style: TextStyle(color: Colors.orange)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
          onPressed: _save,
          child: const Text('حفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _save() {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0) {
      setState(() => _error = 'أدخل سعراً صحيحاً');
      return;
    }
    Navigator.pop(context, _PriceResult(price: v));
  }
}

// ══════════════════════════════════════════════════════
//  عنصر السلة
// ══════════════════════════════════════════════════════
class _CartItemTileWidget extends StatefulWidget {
  final CartItem item;
  final NumberFormat formatter;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onEditPrice;

  const _CartItemTileWidget({
    super.key,
    required this.item,
    required this.formatter,
    required this.onChanged,
    required this.onRemove,
    required this.onEditPrice,
  });

  @override
  State<_CartItemTileWidget> createState() => _CartItemTileWidgetState();
}

class _CartItemTileWidgetState extends State<_CartItemTileWidget> {
  late TextEditingController _qtyController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: formatQuantity(widget.item.quantity));
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (_qtyController.text.trim().isEmpty || toDouble(_qtyController.text) <= 0) {
          widget.item.quantity = 1;
          _qtyController.text = '1';
          widget.onChanged();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CartItemTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      if (_qtyController.text != formatQuantity(widget.item.quantity)) {
        _qtyController.text = formatQuantity(widget.item.quantity);
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(it.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${widget.formatter.format(it.totalPrice)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${it.typeLabel} ${it.flavor != null && it.flavor!.isNotEmpty ? "(${it.flavor})" : ""}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                // ✅ سعر الوحدة + تعديله (لهذه الفاتورة فقط)
                InkWell(
                  onTap: widget.onEditPrice,
                  child: Row(
                    children: [
                      Text(
                        '${widget.formatter.format(it.unitPrice)} DA / ${it.typeLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: it.hasOverridePrice ? Colors.orange.shade800 : Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.edit, size: 12, color: it.hasOverridePrice ? Colors.orange.shade800 : Colors.blue.shade700),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 22),
                  onPressed: () {
                    if (it.quantity > 1) {
                      it.quantity--;
                      _qtyController.text = formatQuantity(it.quantity);
                      widget.onChanged();
                    } else {
                      widget.onRemove();
                    }
                  },
                ),
                SizedBox(
                  width: 55,
                  height: 32,
                  child: TextField(
                    controller: _qtyController,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder()),
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        return; // السماح بمسح الخانة بالكامل أثناء الكتابة
                      }
                      final newQty = toDouble(value);
                      if (newQty > 0) {
                        it.quantity = newQty;
                        widget.onChanged();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 22),
                  onPressed: () {
                    it.quantity++;
                    _qtyController.text = formatQuantity(it.quantity);
                    widget.onChanged();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                  tooltip: 'حذف',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}