import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../services/printer_service.dart';
import '../utils/converters.dart';

class OrdersScreen extends StatefulWidget {
  final bool showTodayOnly;
  const OrdersScreen({super.key, this.showTodayOnly = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final searchController = TextEditingController();
  final NumberFormat formatter = NumberFormat('#,##0', 'en_US');
  late String selectedFilter;

  bool _isDisposed = false;
  bool _isActive = true;

  double _d(dynamic v) => toDouble(v);
  int _i(dynamic v) => toInt(v);

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    selectedFilter = widget.showTodayOnly ? 'today' : 'all';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    searchController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed) return;
    setState(fn);
  }

  List<Order> _filterOrders(List<Order> orders) {
    final q = searchController.text.toLowerCase();
    final now = DateTime.now();

    List<Order> filtered = orders.where((o) {
      return o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.contains(q);
    }).toList();

    if (selectedFilter != 'all') {
      filtered = filtered.where((o) {
        final d = o.createdAt ?? o.dateTime;
        if (d == null) return false;
        if (selectedFilter == 'today') {
          return d.year == now.year && d.month == now.month && d.day == now.day;
        } else if (selectedFilter == 'week') {
          return now.difference(d).inDays <= 7;
        } else if (selectedFilter == 'month') {
          return d.year == now.year && d.month == now.month;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  Future<void> _showEditPaidAmountDialog(Order order) async {
    final ctrl = TextEditingController(text: order.paidAmount.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل تسديد ${order.customerName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ المسدد', suffixText: 'DA', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)), child: const Text('حفظ')),
        ],
      ),
    );

    if (result != null) {
      try {
        final updatedOrder = order.copyWith(paidAmount: result);
        await DataService.updateFullOrder(updatedOrder);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تحديث المبلغ')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Text(widget.showTodayOnly ? 'طلبات اليوم' : 'سجل الطلبات', style: const TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<List<Order>>(
        stream: DataService.getOrdersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          final filtered = _filterOrders(snapshot.data!);
          
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final order = filtered[index];
              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Row(children: [
                    Expanded(child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _showEditPaidAmountDialog(order)),
                  ]),
                  subtitle: Text('مسدد: ${formatter.format(order.paidAmount)} / إجمالي: ${formatter.format(order.total)} DA', style: const TextStyle(fontSize: 12)),
                  children: [
                    Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('📅 ${order.date}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              if (order.latitude != null && order.longitude != null)
                                IconButton(
                                  icon: const Icon(Icons.location_on, color: Colors.redAccent),
                                  tooltip: 'فتح الموقع في الخريطة',
                                  onPressed: () => _openMap(order.latitude!, order.longitude!),
                                ),
                              IconButton(
                                icon: const Icon(Icons.print, color: Color(0xFF2E7D32)),
                                tooltip: 'إعادة طباعة الوصل',
                                onPressed: () => _printOrder(order),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      ...order.items.map((i) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), 
                        child: Text('• ${i['productName']} x ${i['quantity']} ${i['typeLabel']} = ${formatter.format(toDouble(i['price']) * toDouble(i['quantity']))} DA', style: TextStyle(color: textColor)))),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الباقي: ${formatter.format(order.total - order.paidAmount)} DA', 
                            style: TextStyle(color: (order.total - order.paidAmount) > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () => _showEditOrderItemsDialog(order),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل الطلب كاملاً', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ]))
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _printOrder(Order order) async {
    final ok = await PrinterService.printReceipt(
      order: order,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      amountPaid: order.paidAmount,
      customerDebtBalance: order.remainingBalance,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '✅ جاري الطباعة' : '❌ فشلت الطباعة'), backgroundColor: ok ? Colors.green : Colors.red),
      );
    }
  }

import 'edit_order_screen.dart';

  Future<void> _showEditOrderItemsDialog(Order order) async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditOrderScreen(order: order)));
  }

}
