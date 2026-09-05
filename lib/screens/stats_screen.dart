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
      final data = await DataService.getStats();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor =
    isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final totalSales = (stats['totalSales'] ?? 0.0) as double;
    final totalOrders = (stats['totalOrders'] ?? 0) as int;
    final avgOrder =
    totalOrders > 0 ? totalSales / totalOrders : 0.0;

    if (isDesktop) {
      return _buildDesktopLayout(
          isDark, bgColor, cardColor, textColor, avgOrder,
          totalOrders);
    }

    return _buildMobileLayout(
        isDark, bgColor, cardColor, textColor, avgOrder, totalOrders);
  }

  // ══════════════════════════════════
  //  Desktop Layout
  // ══════════════════════════════════
  Widget _buildDesktopLayout(
      bool isDark,
      Color bgColor,
      Color cardColor,
      Color textColor,
      double avgOrder,
      int totalOrders,
      ) {
    return Scaffold(
      backgroundColor: bgColor,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── الصف الأول: بطاقة المتوسط + Grid الإحصائيات ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة المتوسط
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1B5E20),
                            Color(0xFF2E7D32),
                            Color(0xFF43A047),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                        BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32)
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text('💰 متوسط قيمة الطلب',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(
                            '${formatter.format(avgOrder)} DA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'من أصل $totalOrders طلب',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius:
                            BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0.7,
                              backgroundColor: Colors.white
                                  .withOpacity(0.2),
                              valueColor:
                              const AlwaysStoppedAnimation<
                                  Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Grid الإحصائيات الأربعة
                  Expanded(
                    flex: 6,
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        _statCard(
                          title: 'مبيعات اليوم',
                          value:
                          '${formatter.format(stats['todaySales'] ?? 0)} DA',
                          subtitle:
                          '${stats['todayOrders'] ?? 0} طلب',
                          icon: Icons.today,
                          color: const Color(0xFF2E7D32),
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        _statCard(
                          title: 'مبيعات الأسبوع',
                          value:
                          '${formatter.format(stats['weekSales'] ?? 0)} DA',
                          subtitle:
                          '${stats['weekOrders'] ?? 0} طلب',
                          icon: Icons.date_range,
                          color: Colors.blue,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        _statCard(
                          title: 'مبيعات الشهر',
                          value:
                          '${formatter.format(stats['monthSales'] ?? 0)} DA',
                          subtitle:
                          '${stats['monthOrders'] ?? 0} طلب',
                          icon: Icons.calendar_month,
                          color: Colors.purple,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        _statCard(
                          title: 'إجمالي المبيعات',
                          value:
                          '${formatter.format(stats['totalSales'] ?? 0)} DA',
                          subtitle:
                          '${stats['totalOrders'] ?? 0} طلب',
                          icon: Icons.bar_chart,
                          color: Colors.orange,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── أكثر المنتجات مبيعاً ──
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          isDark ? 0.3 : 0.06),
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
                        const Icon(Icons.trending_up,
                            color: Color(0xFF2E7D32),
                            size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'أكثر المنتجات مبيعاً',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (stats['topProducts'] == null ||
                        (stats['topProducts'] as List).isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'لا توجد بيانات بعد',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                    // Desktop: عمودين للمنتجات
                      _buildTopProductsDesktop(
                          isDark, textColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── أكثر المنتجات مبيعاً - Desktop (عمودين) ──
  Widget _buildTopProductsDesktop(bool isDark, Color textColor) {
    final topProducts = stats['topProducts'] as List;
    final firstProduct =
    topProducts.first as Map<String, dynamic>;
    final firstQty = (firstProduct['quantity'] ?? 1) as int;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 12,
        childAspectRatio: 4,
      ),
      itemCount: topProducts.length,
      itemBuilder: (context, index) {
        final product =
        topProducts[index] as Map<String, dynamic>;
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

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2A2A3E)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
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
                        fontSize: 11,
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
                minHeight: 6,
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════
  //  Mobile Layout
  // ══════════════════════════════════
  Widget _buildMobileLayout(
      bool isDark,
      Color bgColor,
      Color cardColor,
      Color textColor,
      double avgOrder,
      int totalOrders,
      ) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          '📊 الإحصائيات',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // بطاقة المتوسط
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2E7D32),
                      Color(0xFF43A047),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 متوسط قيمة الطلب',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(avgOrder)} DA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'من أصل $totalOrders طلب',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grid الإحصائيات
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.3,
                children: [
                  _statCard(
                    title: 'مبيعات اليوم',
                    value:
                    '${formatter.format(stats['todaySales'] ?? 0)} DA',
                    subtitle:
                    '${stats['todayOrders'] ?? 0} طلب',
                    icon: Icons.today,
                    color: const Color(0xFF2E7D32),
                    cardColor: cardColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                  _statCard(
                    title: 'مبيعات الأسبوع',
                    value:
                    '${formatter.format(stats['weekSales'] ?? 0)} DA',
                    subtitle:
                    '${stats['weekOrders'] ?? 0} طلب',
                    icon: Icons.date_range,
                    color: Colors.blue,
                    cardColor: cardColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                  _statCard(
                    title: 'مبيعات الشهر',
                    value:
                    '${formatter.format(stats['monthSales'] ?? 0)} DA',
                    subtitle:
                    '${stats['monthOrders'] ?? 0} طلب',
                    icon: Icons.calendar_month,
                    color: Colors.purple,
                    cardColor: cardColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                  _statCard(
                    title: 'إجمالي المبيعات',
                    value:
                    '${formatter.format(stats['totalSales'] ?? 0)} DA',
                    subtitle:
                    '${stats['totalOrders'] ?? 0} طلب',
                    icon: Icons.bar_chart,
                    color: Colors.orange,
                    cardColor: cardColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // أكثر المنتجات مبيعاً
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up,
                            color: Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        Text(
                          'أكثر المنتجات مبيعاً',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (stats['topProducts'] == null ||
                        (stats['topProducts'] as List)
                            .isEmpty)
                      Center(
                        child: Padding(
                          padding:
                          const EdgeInsets.all(16),
                          child: Text(
                            'لا توجد بيانات بعد',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._buildTopProducts(
                          isDark, textColor),
                  ],
                ),
              ),
            ],
          ),
        ),
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