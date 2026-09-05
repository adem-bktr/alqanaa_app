import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

// ══════════════════════════════════════════════════════════
//   شاشة دليل الزبائن والديون
// ══════════════════════════════════════════════════════════
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final searchController = TextEditingController();
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  String _query = '';

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String formatPrice(double price) => '${formatter.format(price)} DA';

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════
  //  إضافة زبون جديد
  // ══════════════════════════════════
  Future<void> _showAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('زبون جديد',
                style: TextStyle(color: Color(0xFF2E7D32))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'اسم الزبون',
                prefixIcon: const Icon(Icons.person_outline,
                    color: Color(0xFF2E7D32)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                prefixIcon: const Icon(Icons.phone,
                    color: Color(0xFF2E7D32)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                hintText: 'العنوان (اختياري)',
                prefixIcon: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF2E7D32)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('أدخل اسم ورقم الزبون', Colors.red);
      return;
    }

    final customer = CustomerModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
      address: addressCtrl.text.trim().isEmpty
          ? null
          : addressCtrl.text.trim(),
    );
    await DataService.saveCustomer(customer);
    if (!mounted) return;
    _showSnackBar('✅ تم إضافة الزبون', const Color(0xFF2E7D32));
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('دليل الزبائن',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('زبون جديد',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon:
                Icon(Icons.search_rounded, color: Colors.grey.shade500),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    searchController.clear();
                    setState(() => _query = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CustomerModel>>(
              stream: DataService.getCustomersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2E7D32)));
                }
                var customers = snapshot.data!;
                if (_query.isNotEmpty) {
                  customers = customers
                      .where((c) =>
                  c.name.toLowerCase().contains(_query) ||
                      c.phone.contains(_query))
                      .toList();
                }

                final totalDebt = snapshot.data!
                    .fold<double>(0, (sum, c) => sum + c.balance);

                if (customers.isEmpty) {
                  return _buildEmpty(isDark);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  children: [
                    if (_query.isEmpty)
                      _buildSummaryCard(
                          totalDebt, snapshot.data!.length, isDark),
                    const SizedBox(height: 12),
                    ...customers.map((c) => _buildCustomerTile(
                        c, isDark, cardColor, textColor)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalDebt, int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي الديون',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(formatPrice(totalDebt),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('$count زبون',
                    style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(
      CustomerModel c, bool isDark, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor:
          c.hasDebt ? Colors.red.shade50 : const Color(0xFFE8F5E9),
          child: Text(
            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: c.hasDebt ? Colors.red : const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        title: Text(c.name,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(c.phone,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              c.hasDebt ? formatPrice(c.balance) : 'لا يوجد دين',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: c.hasDebt ? 13 : 11,
                color: c.hasDebt
                    ? Colors.red
                    : (isDark ? Colors.grey.shade500 : Colors.grey),
              ),
            ),
            const Icon(Icons.chevron_left, color: Colors.grey, size: 18),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => CustomerDebtScreen(customer: c)),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 80,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty ? 'لا يوجد زبائن بعد' : 'لا نتائج',
            style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey,
                fontSize: 16),
          ),
          if (_query.isEmpty) ...[
            const SizedBox(height: 8),
            Text('اضغط على + لإضافة أول زبون',
                style: TextStyle(
                    color: isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//   شاشة تفاصيل زبون: الرصيد + سجل الحركات + إضافة/تسديد
// ══════════════════════════════════════════════════════════
class CustomerDebtScreen extends StatefulWidget {
  final CustomerModel customer;
  const CustomerDebtScreen({super.key, required this.customer});

  @override
  State<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends State<CustomerDebtScreen> {
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  final dateFormatter = DateFormat('dd/MM/yyyy - HH:mm');
  late CustomerModel _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  String formatPrice(double price) => '${formatter.format(price)} DA';

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════
  //  إضافة دين / تسديد
  // ══════════════════════════════════
  Future<void> _showTransactionDialog(String type) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isCharge = type == 'charge';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isCharge ? Icons.add_circle : Icons.check_circle,
                color: isCharge ? Colors.red : const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Text(isCharge ? 'إضافة دين' : 'تسديد دفعة',
                style: TextStyle(
                    color: isCharge ? Colors.red : const Color(0xFF2E7D32))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'المبلغ',
                suffixText: 'DA',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: 'ملاحظة (اختياري)',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                isCharge ? Colors.red : const Color(0xFF2E7D32)),
            child: const Text('تأكيد',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount =
    double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showSnackBar('أدخل مبلغًا صحيحًا', Colors.red);
      return;
    }

    try {
      await DataService.addDebtTransaction(
        customerId: _customer.id,
        type: type,
        amount: amount,
        note: noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _showSnackBar(
          isCharge ? '✅ تم تسجيل الدين' : '✅ تم تسجيل التسديد',
          const Color(0xFF2E7D32));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('حدث خطأ، حاول مجددًا', Colors.red);
    }
  }

  // ══════════════════════════════════
  //  تعديل بيانات الزبون
  // ══════════════════════════════════
  Future<void> _showEditCustomerDialog() async {
    final nameCtrl = TextEditingController(text: _customer.name);
    final phoneCtrl = TextEditingController(text: _customer.phone);
    final addressCtrl =
    TextEditingController(text: _customer.address ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل بيانات الزبون',
            style: TextStyle(color: Color(0xFF2E7D32))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: 'اسم الزبون',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                hintText: 'العنوان (اختياري)',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('أدخل اسم ورقم الزبون', Colors.red);
      return;
    }

    final updated = _customer.copyWith(
      name: name,
      phone: phone,
      address: addressCtrl.text.trim().isEmpty
          ? null
          : addressCtrl.text.trim(),
    );
    await DataService.updateCustomerInfo(updated);
    if (!mounted) return;
    setState(() => _customer = updated);
    _showSnackBar('✅ تم تعديل بيانات الزبون', const Color(0xFF2E7D32));
  }

  Future<void> _confirmDeleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الزبون'),
        content: Text(
            'هل تريد حذف "${_customer.name}" وكل سجل ديونه؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DataService.deleteCustomer(_customer.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('فشل حذف الزبون', Colors.red);
    }
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Text(_customer.name,
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditCustomerDialog,
            tooltip: 'تعديل البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmDeleteCustomer,
            tooltip: 'حذف الزبون',
          ),
        ],
      ),
      body: StreamBuilder<CustomerModel?>(
        stream: DataService.getCustomerStream(_customer.id),
        builder: (context, snapshot) {
          final customer = snapshot.data ?? _customer;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildBalanceCard(customer),
                const SizedBox(height: 12),
                _buildInfoCard(customer, isDark, cardColor, textColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showTransactionDialog('charge'),
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white),
                        label: const Text('إضافة دين',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showTransactionDialog('payment'),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                        label: const Text('تسديد',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('سجل الحركات',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Container(
                            height: 1,
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<DebtTransactionModel>>(
                  stream:
                  DataService.getCustomerTransactionsStream(_customer.id),
                  builder: (context, txnSnapshot) {
                    if (!txnSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: Color(0xFF2E7D32)),
                      );
                    }
                    final txns = txnSnapshot.data!;
                    if (txns.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('لا توجد حركات بعد',
                            style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey)),
                      );
                    }
                    return Column(
                      children: txns
                          .map((t) => _buildTransactionTile(
                          t, isDark, cardColor, textColor))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(CustomerModel customer) {
    final hasDebt = customer.hasDebt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasDebt
              ? [Colors.red.shade700, Colors.red.shade400]
              : const [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF43A047)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: (hasDebt ? Colors.red : const Color(0xFF2E7D32))
                  .withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرصيد الحالي',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(formatPrice(customer.balance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              hasDebt
                  ? 'يوجد دين مستحق'
                  : 'لا يوجد دين — الحساب متوازن',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      CustomerModel customer, bool isDark, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phone, color: Color(0xFF2E7D32), size: 18),
            const SizedBox(width: 8),
            Text(customer.phone, style: TextStyle(color: textColor)),
          ]),
          if (customer.address != null && customer.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(customer.address!,
                      style: TextStyle(color: textColor))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
      DebtTransactionModel t, bool isDark, Color cardColor, Color textColor) {
    final isCharge = t.isCharge;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCharge
                  ? Colors.red.withOpacity(0.12)
                  : const Color(0xFF2E7D32).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCharge ? Icons.arrow_upward : Icons.arrow_downward,
              color: isCharge ? Colors.red : const Color(0xFF2E7D32),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCharge ? 'دين جديد' : 'تسديد',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: textColor)),
                if (t.note.isNotEmpty)
                  Text(t.note,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey)),
                if (t.createdAt != null)
                  Text(dateFormatter.format(t.createdAt!),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500)),
              ],
            ),
          ),
          Text(
            '${isCharge ? '+' : '-'} ${formatPrice(t.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCharge ? Colors.red : const Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }
}