import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

enum _Period { all, today, week, month, custom }

enum _CustSort { profit, sales, orders }

class _Cost {
  final double? value; // تكلفة الوحدة المباعة (كرتون أو حبة) أو null إن لم تُعرف
  final bool exact; // true = مسجّلة وقت البيع، false = تقديرية (من سعر الشراء الحالي)
  const _Cost(this.value, this.exact);
}

class _OrderProfit {
  final Order order;
  final DateTime? date;
  double revenue = 0;
  double knownRevenue = 0;
  double profit = 0;
  int unknownItems = 0;
  int estimatedItems = 0;
  _OrderProfit(this.order, this.date);
}

class _CustomerProfit {
  final String key;
  final String name;
  final String phone;
  final List<_OrderProfit> orders = [];
  _CustomerProfit(this.key, this.name, this.phone);

  double get revenue => orders.fold(0.0, (s, o) => s + o.revenue);
  double get knownRevenue => orders.fold(0.0, (s, o) => s + o.knownRevenue);
  double get profit => orders.fold(0.0, (s, o) => s + o.profit);
  int get unknownItems => orders.fold(0, (s, o) => s + o.unknownItems);
  int get estimatedItems => orders.fold(0, (s, o) => s + o.estimatedItems);
  double get margin => knownRevenue > 0 ? (profit / knownRevenue) * 100 : 0;
}

class _Report {
  final List<_CustomerProfit> customers;
  final double revenue;
  final double knownRevenue;
  final double profit;
  final int orders;
  final int unknownItems;
  final int estimatedItems;
  _Report(this.customers, this.revenue, this.knownRevenue, this.profit,
      this.orders, this.unknownItems, this.estimatedItems);

  double get margin => knownRevenue > 0 ? (profit / knownRevenue) * 100 : 0;
}

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({super.key});

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  static const _green = Color(0xFF2E7D32);

  final _moneyFmt = NumberFormat('#,##0', 'fr_FR');
  final _dateFmt = DateFormat('yyyy/MM/dd HH:mm');
  final _searchCtrl = TextEditingController();

  List<Order> _orders = [];
  final Map<String, Product> _productsById = {};
  final Map<String, List<Product>> _productsByName = {};

  bool _isLoading = true;
  _Period _period = _Period.all;
  DateTimeRange? _range;
  _CustSort _sort = _CustSort.profit;

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

  /// تكلفة الوحدة المباعة (كرتون أو حبة):
  /// 1) التكلفة المسجّلة في الطلب وقت البيع (دقيقة)
  /// 2) وإلا من سعر شراء المنتج الحالي (بالمعرّف، ثم بالاسم إن كان فريداً) — تقديرية
  _Cost _costOf(Map<String, dynamic> it) {
    final snap = it['cost'];
    if (snap is num && snap > 0) return _Cost(snap.toDouble(), true);

    Product? p;
    final pid = it['productId']?.toString() ?? '';
    if (pid.isNotEmpty) p = _productsById[pid];
    if (p == null) {
      final name = it['productName']?.toString() ?? '';
      final list = _productsByName[name];
      if (list != null && list.length == 1) p = list.first;
    }
    if (p == null || p.purchasePrice <= 0) return const _Cost(null, false);

    final isCarton = it['isCarton'] == true;
    final upc = p.unitsPerCarton > 0 ? p.unitsPerCarton : 1;
    final unit = isCarton ? p.purchasePrice * upc : p.purchasePrice;
    return _Cost(unit, false);
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
    final Map<String, _CustomerProfit> byCustomer = {};
    double revenue = 0, knownRevenue = 0, profit = 0;
    int ordersCount = 0, unknown = 0, estimated = 0;

    // الطلبات مرتبة من الأحدث للأقدم: أول اسم نراه لكل زبون هو الأحدث
    for (final o in _orders) {
      if (o.isRejected) continue; // المرفوضة لا تُحتسب
      final date = o.createdAt ?? o.dateTime;
      if (!_inPeriod(date)) continue;

      final op = _OrderProfit(o, date);
      for (final it in o.items) {
        final price = _num(it['price']);
        final qty = _num(it['quantity']);
        final lineRevenue = price * qty;
        op.revenue += lineRevenue;

        final cost = _costOf(it);
        if (cost.value == null) {
          op.unknownItems++;
        } else {
          op.knownRevenue += lineRevenue;
          op.profit += (price - cost.value!) * qty;
          if (!cost.exact) op.estimatedItems++;
        }
      }

      final phone = o.customerPhone.trim();
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final name = o.customerName.trim();
      final key = digits.length >= 6 ? digits : 'n:${name.toLowerCase()}';
      final cust = byCustomer.putIfAbsent(
          key, () => _CustomerProfit(key, name.isEmpty ? 'بدون اسم' : name, phone));
      cust.orders.add(op);

      ordersCount++;
      revenue += op.revenue;
      knownRevenue += op.knownRevenue;
      profit += op.profit;
      unknown += op.unknownItems;
      estimated += op.estimatedItems;
    }

    var customers = byCustomer.values.toList();

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      customers = customers
          .where((c) =>
      c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
    }

    switch (_sort) {
      case _CustSort.profit:
        customers.sort((a, b) => b.profit.compareTo(a.profit));
        break;
      case _CustSort.sales:
        customers.sort((a, b) => b.revenue.compareTo(a.revenue));
        break;
      case _CustSort.orders:
        customers.sort((a, b) => b.orders.length.compareTo(a.orders.length));
        break;
    }

    return _Report(customers, revenue, knownRevenue, profit, ordersCount,
        unknown, estimated);
  }

  // ══════════════════════════════════
  //  الفترة
  // ══════════════════════════════════
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
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
        final f = DateFormat('yyyy/MM/dd');
        return '${f.format(_range!.start)} → ${f.format(_range!.end)}';
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
        title: const Text('📒 سجل الأرباح',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            tooltip: 'حاسبة وتدقيق الأرباح',
            onPressed: _showProfitCalculatorDialog,
          ),
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
                  _periodChip('الكل', _Period.all),
                  _periodChip('اليوم', _Period.today),
                  _periodChip('7 أيام', _Period.week),
                  _periodChip('هذا الشهر', _Period.month),
                  ChoiceChip(
                    label: Text(
                        _period == _Period.custom && _range != null
                            ? _periodLabel()
                            : 'فترة مخصصة',
                        style: TextStyle(
                            color: _period == _Period.custom
                                ? Colors.white
                                : null,
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

              // بطاقة الأرباح الكلية
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
                    Text('💰 إجمالي الأرباح • ${_periodLabel()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${_moneyFmt.format(report.profit)} DA',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _heroInfo('المبيعات',
                            '${_moneyFmt.format(report.revenue)} DA',
                            CrossAxisAlignment.start),
                        _heroInfo(
                            'نسبة الربح',
                            '${report.margin.toStringAsFixed(1)}%',
                            CrossAxisAlignment.center),
                        _heroInfo('الطلبات', '${report.orders}',
                            CrossAxisAlignment.end),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _showProfitCalculatorDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              '🔍 فحص وتدقيق معادلة حساب الربح',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // تنبيهات الدقة
              if (report.unknownItems > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '${report.unknownItems} صنف بدون سعر شراء معروف، لذلك لم يدخل ربحه في الحساب. '
                      'ضع سعر الشراء في المنتج ليظهر.',
                  Colors.orange,
                  Icons.warning_amber_rounded,
                ),
              ],
              if (report.estimatedItems > 0) ...[
                const SizedBox(height: 10),
                _warnBox(
                  '${report.estimatedItems} صنف (من طلبات أقدم) حُسب ربحه بسعر الشراء الحالي، '
                      'فقد يختلف قليلاً عن الحقيقي. الطلبات الجديدة تُسجَّل بتكلفتها وقت البيع.',
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
                        hintText: 'بحث عن زبون (اسم أو هاتف)...',
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
                  PopupMenuButton<_CustSort>(
                    tooltip: 'ترتيب',
                    icon: const Icon(Icons.sort, color: _green),
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                          value: _CustSort.profit,
                          checked: _sort == _CustSort.profit,
                          child: const Text('الأعلى ربحاً')),
                      CheckedPopupMenuItem(
                          value: _CustSort.sales,
                          checked: _sort == _CustSort.sales,
                          child: const Text('الأعلى مبيعات')),
                      CheckedPopupMenuItem(
                          value: _CustSort.orders,
                          checked: _sort == _CustSort.orders,
                          child: const Text('الأكثر طلبات')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded,
                      color: _green, size: 20),
                  const SizedBox(width: 6),
                  Text('الأرباح حسب الزبون (${report.customers.length})',
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
        if (report.customers.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text('لا توجد طلبات في هذه الفترة',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) => _customerTile(
                    report.customers[i], isDark, cardColor, textColor),
                childCount: report.customers.length,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _customerTile(
      _CustomerProfit c, bool isDark, Color cardColor, Color textColor) {
    final profit = c.profit;
    final profitColor = profit < 0 ? Colors.red : _green;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showCustomerDetails(c, isDark, textColor),
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
            CircleAvatar(
              backgroundColor: profitColor.withValues(alpha: 0.12),
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: profitColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor)),
                  if (c.phone.isNotEmpty)
                    Text(c.phone,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(
                    '${c.orders.length} طلب • مبيعات ${_moneyFmt.format(c.revenue)} DA',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (c.unknownItems > 0)
                    Text('ربح غير مكتمل (أصناف بلا سعر شراء)',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_moneyFmt.format(profit)} DA',
                    style: TextStyle(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('${c.margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: profitColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  تفاصيل زبون (طلباته وربح كل طلب)
  // ══════════════════════════════════
  void _showCustomerDetails(_CustomerProfit c, bool isDark, Color textColor) {
    final sheetColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final orders = [...c.orders]..sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(c.name,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              if (c.phone.isNotEmpty)
                Text(c.phone,
                    style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sheetStat('الربح', '${_moneyFmt.format(c.profit)} DA',
                      c.profit < 0 ? Colors.red : _green),
                  _sheetStat('المبيعات', '${_moneyFmt.format(c.revenue)} DA',
                      Colors.blue),
                  _sheetStat('الطلبات', '${c.orders.length}', Colors.purple),
                ],
              ),
              const SizedBox(height: 6),
              Text('نسبة الربح: ${c.margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const Divider(height: 24),
              Text('الطلبات',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor)),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    final profitColor =
                    o.profit < 0 ? Colors.red : _green;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _showOrderProfitAudit(o),
                      title: Text(
                        o.date != null ? _dateFmt.format(o.date!) : o.order.date,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor),
                      ),
                      subtitle: Text(
                        '${o.order.items.length} منتج • مبيعات ${_moneyFmt.format(o.revenue)} DA'
                            '${o.unknownItems > 0 ? ' • ربح غير مكتمل' : ''}'
                            '${o.estimatedItems > 0 ? ' • ≈ تقديري' : ''}',
                        style: TextStyle(
                            fontSize: 11,
                            color: o.unknownItems > 0
                                ? Colors.orange.shade700
                                : Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_moneyFmt.format(o.profit)} DA',
                            style: TextStyle(
                                color: profitColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
                        ],
                      ),
                    );
                  },
                ),
              ),
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
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  تدقيق أرباح الطلبية التفصيلي
  // ══════════════════════════════════
  void _showOrderProfitAudit(_OrderProfit op) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final o = op.order;
    double orderTotalSales = 0;
    double orderTotalCost = 0;

    final List<Map<String, dynamic>> auditItems = [];

    for (final it in o.items) {
      final name = it['productName']?.toString() ?? 'منتج';
      final price = _num(it['price']);
      final qty = _num(it['quantity']);
      final lineRevenue = price * qty;
      final isCarton = it['isCarton'] == true;

      final cost = _costOf(it);
      final unitCost = cost.value ?? 0.0;
      final lineCost = unitCost * qty;
      final lineProfit = lineRevenue - lineCost;
      final isKnown = cost.value != null;

      orderTotalSales += lineRevenue;
      if (isKnown) orderTotalCost += lineCost;

      auditItems.add({
        'name': name,
        'type': isCarton ? 'كرتون' : 'حبة',
        'qty': qty,
        'price': price,
        'unitCost': unitCost,
        'lineRevenue': lineRevenue,
        'lineCost': lineCost,
        'lineProfit': lineProfit,
        'isKnown': isKnown,
        'isExact': cost.exact,
      });
    }

    final netProfit = orderTotalSales - orderTotalCost;
    final margin =
        orderTotalSales > 0 ? (netProfit / orderTotalSales) * 100 : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Row(
          children: [
            const Icon(Icons.analytics_rounded, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تدقيق أرباح الطلب #${o.shortId}',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تاريخ الطلب: ${o.date}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      _auditSummaryRow('إجمالي المبيعات:',
                          '${_moneyFmt.format(orderTotalSales)} DA', textColor),
                      _auditSummaryRow('إجمالي التكلفة:',
                          '${_moneyFmt.format(orderTotalCost)} DA', textColor),
                      const Divider(),
                      _auditSummaryRow(
                          'صافي الربح:',
                          '${_moneyFmt.format(netProfit)} DA',
                          netProfit >= 0 ? _green : Colors.red,
                          isBold: true),
                      _auditSummaryRow('هامش الربح:',
                          '${margin.toStringAsFixed(1)}%',
                          netProfit >= 0 ? _green : Colors.red,
                          isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('تفاصيل الحساب لكل عنصر:',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                ...auditItems.map((item) {
                  final isKnown = item['isKnown'] as bool;
                  final isExact = item['isExact'] as bool;
                  final lineProfit = item['lineProfit'] as double;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['name']} (${item['type']})',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• سعر البيع: ${_moneyFmt.format(item['price'])} DA × ${item['qty']} = ${_moneyFmt.format(item['lineRevenue'])} DA',
                          style: TextStyle(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.8)),
                        ),
                        if (isKnown) ...[
                          Text(
                            '• سعر الشراء والتكلفة: ${_moneyFmt.format(item['unitCost'])} DA × ${item['qty']} = ${_moneyFmt.format(item['lineCost'])} DA (${isExact ? "مؤكدة وقت البيع" : "تقديرية"})',
                            style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.8)),
                          ),
                          Text(
                            '• معادلة الربح: (${_moneyFmt.format(item['price'])} - ${_moneyFmt.format(item['unitCost'])}) × ${item['qty']} = ${_moneyFmt.format(lineProfit)} DA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: lineProfit >= 0 ? _green : Colors.red,
                            ),
                          ),
                        ] else
                          Text(
                            '⚠️ سعر الشراء غير معروف، لم يدخل في حساب الربح.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _auditSummaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //  حاسبة وتدقيق الأرباح التفاعلية
  // ══════════════════════════════════
  void _showProfitCalculatorDialog() {
    final buyPriceCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();
    final unitsCtrl = TextEditingController(text: '1');
    final qtyCtrl = TextEditingController(text: '1');
    bool isCarton = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;

          final buyUnit =
              double.tryParse(buyPriceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final units = int.tryParse(unitsCtrl.text) ?? 1;
          final sellPrice =
              double.tryParse(sellPriceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final qty = double.tryParse(qtyCtrl.text) ?? 1.0;

          final unitCost = isCarton ? (buyUnit * units) : buyUnit;
          final totalSales = sellPrice * qty;
          final totalCost = unitCost * qty;
          final netProfit = totalSales - totalCost;
          final margin =
              totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;
          final markup =
              totalCost > 0 ? (netProfit / totalCost) * 100 : 0.0;

          return AlertDialog(
            backgroundColor: dialogBg,
            title: Row(
              children: [
                const Icon(Icons.calculate_rounded, color: _green),
                const SizedBox(width: 8),
                Text('حاسبة وتدقيق معادلة الربح',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('أدخل أسعار تجريبية للتحقق من صحة المعادلة:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('كرتون'),
                            selected: isCarton,
                            selectedColor: _green,
                            labelStyle: TextStyle(
                                color: isCarton ? Colors.white : textColor),
                            onSelected: (v) => setSt(() => isCarton = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('حبة'),
                            selected: !isCarton,
                            selectedColor: _green,
                            labelStyle: TextStyle(
                                color: !isCarton ? Colors.white : textColor),
                            onSelected: (v) => setSt(() => isCarton = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: buyPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        labelText: 'سعر شراء الحبة (الأصلي)',
                        suffixText: 'DA',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSt(() {}),
                    ),
                    if (isCarton) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: unitsCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          labelText: 'عدد الحبات في الكرتون',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: sellPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText:
                            isCarton ? 'سعر بيع الكرتون' : 'سعر بيع الحبة',
                        suffixText: 'DA',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSt(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        labelText: 'الكمية المباعة',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSt(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (buyUnit > 0 && sellPrice > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📐 مراحل حساب المعادلة:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _green,
                                    fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                                '1. تكلفة الوحدة (${isCarton ? "كرتون" : "حبة"}): ${_moneyFmt.format(unitCost)} DA',
                                style: TextStyle(
                                    fontSize: 12, color: textColor)),
                            Text(
                                '2. إجمالي المبيعات: ${_moneyFmt.format(sellPrice)} × $qty = ${_moneyFmt.format(totalSales)} DA',
                                style: TextStyle(
                                    fontSize: 12, color: textColor)),
                            Text(
                                '3. إجمالي التكلفة: ${_moneyFmt.format(unitCost)} × $qty = ${_moneyFmt.format(totalCost)} DA',
                                style: TextStyle(
                                    fontSize: 12, color: textColor)),
                            const Divider(),
                            Text(
                                '4. صافي الربح: ${_moneyFmt.format(totalSales)} - ${_moneyFmt.format(totalCost)} = ${_moneyFmt.format(netProfit)} DA',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: netProfit >= 0
                                        ? _green
                                        : Colors.red)),
                            const SizedBox(height: 4),
                            Text(
                                '• نسبة هامش الربح (Margin): ${margin.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textColor)),
                            Text(
                                '• نسبة الفائدة على التكلفة (Markup): ${markup.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textColor)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}