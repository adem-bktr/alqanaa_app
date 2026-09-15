import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> stats = {};
  bool isLoading = true;
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  DateTime selectedDate = DateTime.now(); // ✅

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {
    setState(() => isLoading = true);
    try {
      final data = await DataService.getStats(specificDate: selectedDate);
      if (mounted) {
        setState(() {
          stats = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor =
    isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop ? null : AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('📊 الإحصائيات', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _pickDate,
            tooltip: 'اختر التاريخ',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: loadStats,
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: isDark
              ? Colors.green.shade400
              : const Color(0xFF2E7D32),
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF2E7D32),
        onRefresh: loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) _buildDesktopHeader(isDark, textColor),
              
              // بطاقة التاريخ المختار (موبايل)
              if (!isDesktop) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'بيانات يوم: ${DateFormat('yyyy/MM/dd').format(selectedDate)}',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(onPressed: _pickDate, child: const Text('تغيير')),
                    ],
                  ),
                ),
              ],

              // بطاقة المبيعات والربح لهذا اليوم
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
                    Text(
                      '💰 مبيعات ${isDesktop ? DateFormat('yyyy/MM/dd').format(selectedDate) : "اليوم المختار"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(stats['targetDaySales'] ?? 0.0)} DA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('عدد الطلبات', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text('${stats['targetDayOrdersCount'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('صافي الربح التقديري', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text('${formatter.format(stats['targetDayProfit'] ?? 0.0)} DA', 
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grid الإحصائيات (تاريخي)
              _buildStatsGrid(isDark, cardColor, textColor),

              const SizedBox(height: 16),
              // أكثر المنتجات مبيعاً
              _buildTopProductsSection(isDark, cardColor, textColor),

              const SizedBox(height: 16),
              // جرد منتجات اليوم المختار
              _buildTodayProductsTable(isDark, cardColor, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Text('📊 تقارير المبيعات والأرباح',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text('تاريخ: ${DateFormat('yyyy/MM/dd').format(selectedDate)}'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark, Color cardColor, Color textColor) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isDesktop ? 2.0 : 1.3,
      children: [
        _statCard(
          title: 'مبيعات اليوم',
          value: '${formatter.format(stats['todaySales'] ?? 0)} DA',
          subtitle: '${stats['todayOrders'] ?? 0} طلب',
          icon: Icons.today,
          color: const Color(0xFF2E7D32),
          cardColor: cardColor,
          textColor: textColor,
          isDark: isDark,
        ),
        _statCard(
          title: 'مبيعات الأسبوع',
          value: '${formatter.format(stats['weekSales'] ?? 0)} DA',
          subtitle: '${stats['weekOrders'] ?? 0} طلب',
          icon: Icons.date_range,
          color: Colors.blue,
          cardColor: cardColor,
          textColor: textColor,
          isDark: isDark,
        ),
        _statCard(
          title: 'مبيعات الشهر',
          value: '${formatter.format(stats['monthSales'] ?? 0)} DA',
          subtitle: '${stats['monthOrders'] ?? 0} طلب',
          icon: Icons.calendar_month,
          color: Colors.purple,
          cardColor: cardColor,
          textColor: textColor,
          isDark: isDark,
        ),
        _statCard(
          title: 'إجمالي المبيعات',
          value: '${formatter.format(stats['totalSales'] ?? 0)} DA',
          subtitle: '${stats['totalOrders'] ?? 0} طلب',
          icon: Icons.bar_chart,
          color: Colors.orange,
          cardColor: cardColor,
          textColor: textColor,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTopProductsSection(bool isDark, Color cardColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                'أكثر المنتجات مبيعاً (إجمالي)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats['topProducts'] == null || (stats['topProducts'] as List).isEmpty)
            const Center(child: Text('لا توجد بيانات بعد'))
          else
            ..._buildTopProducts(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildTodayProductsTable(bool isDark, Color cardColor, Color textColor) {
    final products = (stats['targetDayProducts'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory, color: Colors.blue, size: 24),
              const SizedBox(width: 10),
              Text(
                'جرد المنتجات المباعة في هذا اليوم',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد بيانات لهذا التاريخ',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Table(
              border: TableBorder(
                horizontalInside: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 1),
              ),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _tableHeader('المنتج', isDark),
                    _tableHeader('الكمية', isDark),
                    _tableHeader('الإجمالي', isDark),
                  ],
                ),
                ...products.map((p) => TableRow(
                  children: [
                    _tableCell(p['name']?.toString() ?? '', textColor),
                    _tableCell(p['quantity']?.toString() ?? '0', textColor),
                    _tableCell('${formatter.format(p['revenue'] ?? 0)} DA',
                        const Color(0xFF2E7D32),
                        bold: true),
                  ],
                )),
              ],
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //  أكثر المنتجات مبيعاً - Mobile
  // ══════════════════════════════════
  List<Widget> _buildTopProducts(bool isDark, Color textColor) {
    final topProducts = stats['topProducts'] as List;
    final firstProduct =
    topProducts.first as Map<String, dynamic>;
    final firstQty = (firstProduct['quantity'] ?? 1) as int;

    return topProducts.asMap().entries.map((entry) {
      final index = entry.key;
      final product = entry.value as Map<String, dynamic>;
      final qty = (product['quantity'] ?? 0) as int;
      final name = product['name'] as String? ?? '';

      Color medalColor;
      if (index == 0) {
        medalColor = Colors.amber;
      } else if (index == 1) {
        medalColor = Colors.grey;
      } else if (index == 2) {
        medalColor = Colors.brown;
      } else {
        medalColor = const Color(0xFF2E7D32);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: medalColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$qty وحدة',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: firstQty > 0 ? qty / firstQty : 0,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                index == 0
                    ? Colors.amber
                    : const Color(0xFF2E7D32),
              ),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
          ],
        ),
      );
    }).toList();
  }

  // ══════════════════════════════════
  //  بطاقة إحصائية
  // ══════════════════════════════════
  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_upward,
                    color: color, size: 14),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title,
              style: TextStyle(fontSize: 11, color: textColor)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}