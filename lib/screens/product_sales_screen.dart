import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

enum _Period { all, today, week, month, custom }

enum _Sort { quantity, sales, profit, name }

class _Cost {
  final double? value; // تكلفة الوحدة المباعة (كرتون أو حبة) أو null إن لم تُعرف
  final bool exact; // true = مسجّلة وقت البيع، false = تقديرية
  const _Cost(this.value, this.exact);
}

class _DayAgg {
  double cartons = 0, units = 0, revenue = 0;
}

class _CustAgg {
  final String name;
  double cartons = 0, units = 0, revenue = 0;
  _CustAgg(this.name);
}

class _ProductSales {
  final String key;
  final String name;
  final Product? product;
  double cartons = 0, units = 0, revenue = 0, profit = 0;
  int unknownItems = 0, estimatedItems = 0;
  final Set<String> orderIds = {};
  final Map<String, _DayAgg> days = {};
  final Map<String, _CustAgg> customers = {};
  _ProductSales(this.key, this.name, this.product);

  int get ordersCount => orderIds.length;

  int get _upc {
    final u = product?.unitsPerCarton ?? 1;
    return u > 0 ? u : 1;
  }

  /// إجمالي الحبات (إن كان عدد الحبات في الكرتون معروفاً)، وإلا null
  int? get totalPieces => _upc > 1 ? (cartons * _upc + units).round() : null;

  /// قيمة للترتيب: كل شيء محسوب بالحبات
  double get sortQty => cartons * _upc + units;
}

class _Report {
  final List<_ProductSales> products;
  final double revenue;
  final double cartons;
  final double units;
  final int orders;
  _Report(this.products, this.revenue, this.cartons, this.units, this.orders);
}

class ProductSalesScreen extends StatefulWidget {
  const ProductSalesScreen({super.key});

  @override
  State<ProductSalesScreen> createState() => _ProductSalesScreenState();
}

class _ProductSalesScreenState extends State<ProductSalesScreen> {
  static const _green = Color(0xFF2E7D32);

  final _moneyFmt = NumberFormat('#,##0', 'fr_FR');
  final _dayFmt = DateFormat('yyyy/MM/dd');
  final _searchCtrl = TextEditingController();

  List<Order> _orders = [];
  final Map<String, Product> _productsById = {};
  final Map<String, List<Product>> _productsByName = {};

  bool _isLoading = true;
  _Period _period = _Period.month;
  DateTimeRange? _range;
  _Sort _sort = _Sort.quantity;

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
    final ordersFuture = DataService.getAllOrders();
    final productsFuture = DataService.getAllProducts();
    final orders = await ordersFuture;
    final products = await productsFuture;
    if (!mounted) return;
    _productsById.clear();
    _productsByName.clear();
    for (final p in products) {
      _productsById[p.id] = p;
      _productsByName.putIfAbsent(p.name, () => []).add(p);
    }
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  // ══════════════════════════════════
  //  الحساب
  // ══════════════════════════════════
  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// نص الكمية: "5 كرتون و 20 حبة"
  String _qtyText(double cartons, double units) {
    final parts = <String>[
      if (cartons > 0) '${_fmtQty(cartons)} كرتون',
      if (units > 0) '${_fmtQty(units)} حبة',
    ];
    return parts.isEmpty ? '0' : parts.join(' و ');
  }

  _Cost _costOf(Map<String, dynamic> it, Product? prod) {
    final snap = it['cost'];
    if (snap is num && snap > 0) return _Cost(snap.toDouble(), true);
    if (prod == null || prod.purchasePrice <= 0) return const _Cost(null, false);
    final isCarton = it['isCarton'] == true;
    final upc = prod.unitsPerCarton > 0 ? prod.unitsPerCarton : 1;
    return _Cost(isCarton ? prod.purchasePrice * upc : prod.purchasePrice, false);
  }

  bool _inPeriod(DateTime? d) {
    if (_period == _Period.all) return true;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.today:
        return !d.isBefore(today);
      case _Period.week:
        return !d.isBefore(today.subtract(const Duration(days: 6)));
      case _Period.month:
        return d.year == now.year && d.month == now.month;
      case _Period.custom:
        if (_range == null) return true;
        return !d.isBefore(_range!.start) &&
            d.isBefore(_range!.end.add(const Duration(days: 1)));
      case _Period.all:
        return true;
    }
  }

  _Report _buildReport() {
    final map = <String, _ProductSales>{};
    final orderIds = <String>{};
    double revenue = 0, cartons = 0, units = 0;

    for (final o in _orders) {
      if (o.isRejected) continue; // المرفوضة لا تُحتسب
      final date = o.createdAt ?? o.dateTime;
      if (!_inPeriod(date)) continue;
      orderIds.add(o.id);

      final dayKey = date != null ? _dayFmt.format(date) : 'غير محدد';
      final phone = o.customerPhone.trim();
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final custName = o.customerName.trim().isEmpty ? 'بدون اسم' : o.customerName.trim();
      final custKey = digits.length >= 6 ? digits : 'n:${custName.toLowerCase()}';

      for (final it in o.items) {
        final pid = it['productId']?.toString() ?? '';
        final name = it['productName']?.toString() ?? 'منتج';

        Product? prod = pid.isNotEmpty ? _productsById[pid] : null;
        if (prod == null) {
          final list = _productsByName[name];
          if (list != null && list.length == 1) prod = list.first;
        }
        // دمج الطلبات القديمة (بلا معرّف) مع الجديدة إذا كان الاسم يطابق منتجاً واحداً
        final key = pid.isNotEmpty ? pid : (prod != null ? prod.id : 'n:$name');

        final ps = map.putIfAbsent(key, () => _ProductSales(key, name, prod));
        final qty = _num(it['quantity']);
        final price = _num(it['price']);
        final isCarton = it['isCarton'] == true;
        final line = price * qty;

        ps.orderIds.add(o.id);
        ps.revenue += line;
        revenue += line;
        if (isCarton) {
          ps.cartons += qty;
          cartons += qty;
        } else {
          ps.units += qty;
          units += qty;
        }

        final cost = _costOf(it, prod);
        if (cost.value == null) {
          ps.unknownItems++;
        } else {
          ps.profit += (price - cost.value!) * qty;
          if (!cost.exact) ps.estimatedItems++;
        }

        final day = ps.days.putIfAbsent(dayKey, () => _DayAgg());
        day.revenue += line;
        final cust = ps.customers.putIfAbsent(custKey, () => _CustAgg(custName));
        cust.revenue += line;
        if (isCarton) {
          day.cartons += qty;
          cust.cartons += qty;
        } else {
          day.units += qty;
          cust.units += qty;
        }
      }
    }

    var products = map.values.toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      products = products.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    switch (_sort) {
      case _Sort.quantity:
        products.sort((a, b) => b.sortQty.compareTo(a.sortQty));
        break;
      case _Sort.sales:
        products.sort((a, b) => b.revenue.compareTo(a.revenue));
        break;
      case _Sort.profit:
        products.sort((a, b) => b.profit.compareTo(a.profit));
        break;
      case _Sort.name:
        products.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    return _Report(products, revenue, cartons, units, orderIds.length);
  }

  // ══════════════════════════════════
  //  الفترة
  // ══════════════════════════════════
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _period = _Period.custom;
      });
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _Period.all:
        return 'كل الفترات';
      case _Period.today:
        return 'اليوم';
      case _Period.week:
        return 'آخر 7 أيام';
      case _Period.month:
        return 'هذا الشهر';
      case _Period.custom:
        if (_range == null) return 'فترة مخصصة';
        return '${_dayFmt.format(_range!.start)} → ${_dayFmt.format(_range!.end)}';
    }
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text('📦 مبيعات المنتجات',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'اختيار فترة',
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'تحديث',
            onPressed: _load,
          ),
        ],
      ),
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
    final report = _buildReport();
    final pad = _isDesktop ? 24.0 : 12.0;
    final unknownTotal = report.products.fold<int>(0, (s, p) => s + p.unknownItems);
    final estimatedTotal = report.products.fold<int>(0, (s, p) => s + p.estimatedItems);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // الفترة
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _periodChip('اليوم', _Period.today),
                  _periodChip('7 أيام', _Period.week),
                  _periodChip('هذا الشهر', _Period.month),
                  _periodChip('الكل', _Period.all),
                  ChoiceChip(
                    label: Text(
                        _period == _Period.custom && _range != null
                            ? _periodLabel()
                            : 'فترة مخصصة',
                        style: TextStyle(
                            color: _period == _Period.custom ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    selected: _period == _Period.custom,
                    selectedColor: _green,
                    showCheckmark: false,
                    onSelected: (_) => _pickRange(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ملخص الفترة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📦 ما بعته • ${_periodLabel()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(_qtyText(report.cartons, report.units),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _heroInfo('المنتجات', '${report.products.length}',
                            CrossAxisAlignment.start),
                        _heroInfo('المبيعات',
                            '${_moneyFmt.format(report.revenue)} DA',
                            CrossAxisAlignment.center),
                        _heroInfo('الطلبات', '${report.orders}',
                            CrossAxisAlignment.end),
                      ],
                    ),
                  ],
                ),
              ),

              if (unknownTotal > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '$unknownTotal سطراً بلا سعر شراء معروف، لذلك لم يدخل ربحه في ربح المنتج. '
                      'ضع سعر الشراء في المنتج ليظهر.',
                  Colors.orange,
                  Icons.warning_amber_rounded,
                ),
              ],
              if (estimatedTotal > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '$estimatedTotal سطراً (من طلبات أقدم) حُسب ربحه بسعر الشراء الحالي، فهو تقديري.',
                  Colors.blue,
                  Icons.info_outline,
                ),
              ],
              const SizedBox(height: 12),

              // بحث + ترتيب
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
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_Sort>(
                    tooltip: 'ترتيب',
                    icon: const Icon(Icons.sort, color: _green),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                          value: _Sort.quantity,
                          checked: _sort == _Sort.quantity,
                          child: const Text('الأكثر كمية (بالحبات)')),
                      CheckedPopupMenuItem(
                          value: _Sort.sales,
                          checked: _sort == _Sort.sales,
                          child: const Text('الأعلى مبيعاً (DA)')),
                      CheckedPopupMenuItem(
                          value: _Sort.profit,
                          checked: _sort == _Sort.profit,
                          child: const Text('الأعلى ربحاً')),
                      CheckedPopupMenuItem(
                          value: _Sort.name,
                          checked: _sort == _Sort.name,
                          child: const Text('حسب الاسم')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: _green, size: 20),
                  const SizedBox(width: 6),
                  Text('المنتجات المباعة (${report.products.length})',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor)),
                ],
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        if (report.products.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text('لا توجد مبيعات في هذه الفترة',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) => _productTile(
                    report.products[i], isDark, cardColor, textColor),
                childCount: report.products.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _periodChip(String label, _Period p) {
    final selected = _period == p;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : null,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
      selected: selected,
      selectedColor: _green,
      showCheckmark: false,
      onSelected: (_) => setState(() => _period = p),
    );
  }

  Widget _heroInfo(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _productTile(
      _ProductSales p, bool isDark, Color cardColor, Color textColor) {
    final profitColor = p.profit < 0 ? Colors.red : _green;
    final pieces = p.totalPieces;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showProductDetails(p, isDark, textColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
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
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 22),
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
                  const SizedBox(height: 3),
                  Text(_qtyText(p.cartons, p.units),
                      style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  if (pieces != null)
                    Text('≈ $pieces حبة إجمالاً',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Text('${p.ordersCount} طلب',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_moneyFmt.format(p.revenue)} DA',
                    style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('ربح ${_moneyFmt.format(p.profit)}',
                    style: TextStyle(
                        color: profitColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                if (p.unknownItems > 0)
                  Text('ربح غير مكتمل',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  تفاصيل منتج: يوماً بيوم + أكثر الزبائن شراءً
  // ══════════════════════════════════
  void _showProductDetails(_ProductSales p, bool isDark, Color textColor) {
    final sheetColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    final days = p.days.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // الأحدث أولاً (yyyy/MM/dd يُرتَّب نصياً)
    final customers = p.customers.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(p.name,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              Text(_periodLabel(),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sheetStat('الكمية', _qtyText(p.cartons, p.units), Colors.blue),
                  _sheetStat('المبيعات', '${_moneyFmt.format(p.revenue)} DA', _green),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _sheetStat('الربح', '${_moneyFmt.format(p.profit)} DA',
                      p.profit < 0 ? Colors.red : _green),
                  _sheetStat('الطلبات', '${p.ordersCount}', Colors.purple),
                ],
              ),
              if (p.totalPieces != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('إجمالي الحبات تقريباً: ${p.totalPieces}',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              const Divider(height: 26),
              Text('📅 يوماً بيوم',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor)),
              const SizedBox(height: 4),
              ...days.map((e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor)),
                subtitle: Text(_qtyText(e.value.cartons, e.value.units),
                    style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                trailing: Text('${_moneyFmt.format(e.value.revenue)} DA',
                    style: const TextStyle(
                        color: _green, fontWeight: FontWeight.bold)),
              )),
              const Divider(height: 26),
              Text('👥 أكثر الزبائن شراءً لهذا المنتج',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor)),
              const SizedBox(height: 4),
              ...customers.take(10).map((c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _green.withValues(alpha: 0.12),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: _green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                title: Text(c.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor)),
                subtitle: Text(_qtyText(c.cartons, c.units),
                    style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                trailing: Text('${_moneyFmt.format(c.revenue)} DA',
                    style: const TextStyle(
                        color: _green, fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}