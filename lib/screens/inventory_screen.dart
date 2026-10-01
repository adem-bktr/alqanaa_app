import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

enum _InvFilter { all, outOfStock, noCost }

enum _InvSort { name, value, stock }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _green = Color(0xFF2E7D32);

  final _moneyFmt = NumberFormat('#,##0', 'fr_FR');
  final _priceFmt = NumberFormat('#,##0.##', 'fr_FR');
  final _searchCtrl = TextEditingController();

  List<Product> _products = [];
  Map<String, String> _brandNames = {};
  bool _isLoading = true;
  _InvFilter _filter = _InvFilter.all;
  _InvSort _sort = _InvSort.name;

  bool get _isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final productsFuture = DataService.getAllProducts();
    final brandsFuture = DataService.getBrands();
    final products = await productsFuture;
    final brands = await brandsFuture;
    if (!mounted) return;
    setState(() {
      _products = products;
      _brandNames = {for (final b in brands) b.id: b.name};
      _isLoading = false;
    });
  }

  // قيمة مخزون المنتج بسعر الشراء (سعر الحبة × عدد الحبات). المخزون السالب لا يُحتسب.
  double _valueOf(Product p) =>
      (p.stockQuantity > 0 ? p.stockQuantity : 0) * p.purchasePrice;

  String _stockLabel(Product p) {
    final s = p.stockQuantity;
    if (s < 0) return '$s حبة';
    if (p.unitsPerCarton > 1) {
      final crt = s ~/ p.unitsPerCarton;
      final pcs = s % p.unitsPerCarton;
      if (crt == 0) return '$pcs حبة';
      if (pcs == 0) return '$crt كرتون';
      return '$crt كرتون و $pcs حبة';
    }
    return '$s قطعة';
  }

  List<Product> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _products.where((p) {
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      return switch (_filter) {
        _InvFilter.all => true,
        _InvFilter.outOfStock => p.stockQuantity <= 0,
        _InvFilter.noCost => p.purchasePrice <= 0,
      };
    }).toList();

    switch (_sort) {
      case _InvSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _InvSort.value:
        list.sort((a, b) => _valueOf(b).compareTo(_valueOf(a)));
        break;
      case _InvSort.stock:
        list.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            color: _green,
            onRefresh: _load,
            child: _buildBody(isDark, cardColor, textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color cardColor, Color textColor) {
    final totalValue =
    _products.fold<double>(0, (s, p) => s + _valueOf(p));
    final totalPieces = _products.fold<int>(
        0, (s, p) => s + (p.stockQuantity > 0 ? p.stockQuantity : 0));
    final outCount = _products.where((p) => p.stockQuantity <= 0).length;
    final negCount = _products.where((p) => p.stockQuantity < 0).length;
    final noCostWithStock = _products
        .where((p) => p.stockQuantity > 0 && p.purchasePrice <= 0)
        .length;
    final visible = _visible;
    final pad = _isDesktop ? 24.0 : 12.0;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // العنوان
              Row(
                children: [
                  Text('📦 المخزون',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: _green),
                    tooltip: 'تحديث',
                    onPressed: _load,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // بطاقة القيمة الإجمالية
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💰 القيمة الإجمالية للمخزون (بسعر الشراء)',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${_moneyFmt.format(totalValue)} DA',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _totalInfo('عدد المنتجات', '${_products.length}',
                            CrossAxisAlignment.start),
                        _totalInfo('إجمالي القطع',
                            _moneyFmt.format(totalPieces),
                            CrossAxisAlignment.center),
                        _totalInfo('منتجات نافدة', '$outCount',
                            CrossAxisAlignment.end),
                      ],
                    ),
                  ],
                ),
              ),

              // تنبيهات
              if (noCostWithStock > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '$noCostWithStock منتج له مخزون وليس له سعر شراء، لذلك لم يدخل في القيمة الإجمالية.',
                  Colors.orange,
                  Icons.warning_amber_rounded,
                ),
              ],
              if (negCount > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '$negCount منتج مخزونه بالسالب (بيع أكثر من المسجل). راجع الكميات.',
                  Colors.red,
                  Icons.error_outline,
                ),
              ],
              const SizedBox(height: 12),

              // البحث + الترتيب
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'بحث عن منتج...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon:
                        Icon(Icons.search, color: Colors.grey.shade500),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: cardColor,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_InvSort>(
                    tooltip: 'ترتيب',
                    icon: const Icon(Icons.sort, color: _green),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                          value: _InvSort.name,
                          checked: _sort == _InvSort.name,
                          child: const Text('حسب الاسم')),
                      CheckedPopupMenuItem(
                          value: _InvSort.value,
                          checked: _sort == _InvSort.value,
                          child: const Text('الأعلى قيمة')),
                      CheckedPopupMenuItem(
                          value: _InvSort.stock,
                          checked: _sort == _InvSort.stock,
                          child: const Text('الأقل كمية')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // فلاتر
              Wrap(
                spacing: 8,
                children: [
                  _chip('الكل', _InvFilter.all),
                  _chip('نافد', _InvFilter.outOfStock),
                  _chip('بدون سعر شراء', _InvFilter.noCost),
                ],
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
        if (visible.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text('لا توجد منتجات',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                    _buildTile(visible[i], isDark, cardColor, textColor),
                childCount: visible.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _totalInfo(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _warnBox(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _InvFilter f) {
    final selected = _filter == f;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
      selected: selected,
      selectedColor: _green,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = f),
    );
  }

  Widget _buildTile(
      Product p, bool isDark, Color cardColor, Color textColor) {
    final stock = p.stockQuantity;
    final out = stock <= 0;
    final stockColor = stock < 0
        ? Colors.red
        : out
        ? Colors.orange.shade800
        : _green;
    final brand = _brandNames[p.brandId] ?? '';
    final hasCost = p.purchasePrice > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: out
            ? Border.all(color: stockColor.withValues(alpha: 0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_rounded,
                color: stockColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor)),
                if (brand.isNotEmpty)
                  Text(brand,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text(_stockLabel(p),
                    style: TextStyle(
                        color: stockColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text(
                  hasCost
                      ? 'سعر الشراء: ${_priceFmt.format(p.purchasePrice)} DA / حبة'
                      : 'بدون سعر شراء',
                  style: TextStyle(
                      fontSize: 11,
                      color: hasCost
                          ? Colors.grey.shade500
                          : Colors.orange.shade700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hasCost ? '${_moneyFmt.format(_valueOf(p))} DA' : '—',
                  style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Text('القيمة',
                  style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}