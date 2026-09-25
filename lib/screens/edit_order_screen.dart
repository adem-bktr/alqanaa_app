import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/printer_service.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'package:intl/intl.dart';

class EditOrderScreen extends StatefulWidget {
  final Order order;
  const EditOrderScreen({super.key, required this.order});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  late List<Map<String, dynamic>> items;
  late TextEditingController paidAmountController;
  bool isLoading = false;
  final formatter = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    items = List<Map<String, dynamic>>.from(widget.order.items);
    paidAmountController = TextEditingController(text: widget.order.paidAmount.toStringAsFixed(0));
  }

  double get total => items.fold(0, (sum, i) => sum + (toDouble(i['price']) * toDouble(i['quantity'])));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل طلب ${widget.order.customerName}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final newItem = await _showSelectProductForOrder();
                  if (newItem != null) {
                    setState(() => items.add(newItem));
                  }
                },
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('إضافة منتج جديد للطلبية', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item['productName']),
                    subtitle: Text('${formatter.format(item['price'])} DA لكل ${item['typeLabel']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
                          setState(() {
                            if (item['quantity'] > 1) {
                              item['quantity']--;
                            } else {
                              items.removeAt(index);
                            }
                          });
                        }),
                        Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                          setState(() => item['quantity']++);
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, border: const Border(top: BorderSide(color: Colors.grey))),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('المجموع المحدث:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${formatter.format(total)} DA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: paidAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع حالياً', suffixText: 'DA', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    onPressed: _saveAndPrint,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('حفظ وطباعة الوصل المحدث', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _saveAndPrint() async {
    setState(() => isLoading = true);
    try {
      final paid = double.tryParse(paidAmountController.text) ?? total;
      final updatedOrder = widget.order.copyWith(
        items: items,
        total: total,
        paidAmount: paid,
      );

      // 1. تحديث في Firestore
      await DataService.updateFullOrder(updatedOrder);

      // 2. معاينة وطباعة الوصل المحدث
      await ReceiptPreviewDialog.show(
        context,
        order: updatedOrder,
        customerName: updatedOrder.customerName,
        customerPhone: updatedOrder.customerPhone,
        amountPaid: paid,
        customerDebtBalance: updatedOrder.remainingBalance,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم التعديل والحفظ بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _showSelectProductForOrder() async {
    final products = await DataService.getAllProducts();
    if (products.isEmpty) return null;

    String query = '';
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('اختر منتجاً لإضافته'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'بحث...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setSt(() => query = v.toLowerCase()),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final p = products[i];
                      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) return const SizedBox.shrink();
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('${formatter.format(p.priceCartonNormal)} DA'),
                        onTap: () {
                          Navigator.pop(context, {
                            'productId': p.id,
                            'productName': p.name,
                            'quantity': 1,
                            'price': p.priceCartonNormal,
                            'unitPrice': p.priceCartonNormal,
                            'isCarton': true,
                            'typeLabel': 'كرتون',
                            'flavor': '',
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
