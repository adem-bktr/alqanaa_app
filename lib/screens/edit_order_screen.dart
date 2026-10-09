import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/receipt_preview_dialog.dart';
import '../utils/order_helpers.dart';
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
    // ✅ نسخة عميقة: تعديل الكميات هنا لا يغيّر الطلب الأصلي في الذاكرة قبل الحفظ
    items = widget.order.items
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    paidAmountController = TextEditingController(text: widget.order.paidAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    paidAmountController.dispose();
    super.dispose();
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
                            final q = toDouble(item['quantity']);
                            if (q > 1) {
                              item['quantity'] = q - 1;
                            } else {
                              items.removeAt(index);
                            }
                          });
                        }),
                        SizedBox(
                          width: 50,
                          height: 32,
                          child: TextFormField(
                            key: ValueKey('order_item_${index}_${item['quantity']}'),
                            initialValue: formatQuantity(item['quantity']),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              if (val.trim().isEmpty) return;
                              final newQ = toDouble(val);
                              if (newQ > 0) {
                                setState(() => item['quantity'] = newQ);
                              }
                            },
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                          setState(() => item['quantity'] = toDouble(item['quantity']) + 1);
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع حالياً', suffixText: 'DA', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() {}),
                ),
                // ✅ المتبقي (دين) بعد التعديل
                Builder(builder: (_) {
                  final paid = double.tryParse(paidAmountController.text.trim().replaceAll(',', '.')) ?? 0;
                  final rem = total - paid;
                  if (rem <= 0.05) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المتبقي (دين):', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${formatter.format(rem)} DA',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  );
                }),
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
      final newTotal = total;
      final paid = double.tryParse(paidAmountController.text.trim().replaceAll(',', '.')) ?? newTotal;
      final newRemaining = (newTotal - paid) > 0 ? (newTotal - paid) : 0.0;

      // ✅ مزامنة دين الزبون (إن كانت الطلبية مسجّلة على زبون)
      final customerBalance = await DataService.syncOrderDebt(
        orderId: widget.order.id,
        newRemaining: newRemaining,
      );

      final updatedOrder = widget.order.copyWith(
        items: items,
        total: newTotal,
        paidAmount: paid,
        remainingBalance: customerBalance ?? widget.order.remainingBalance,
      );

      // 1. تحديث في Firestore
      await DataService.updateFullOrder(updatedOrder);
      if (!mounted) return;

      // 2. معاينة وطباعة الوصل المحدث
      // ✅ الرصيد السابق (وليس الرصيد بعد الفاتورة) حتى لا يُحسب دين الفاتورة مرتين على الورقة
      await ReceiptPreviewDialog.show(
        context,
        order: updatedOrder,
        customerName: updatedOrder.customerName,
        customerPhone: updatedOrder.customerPhone,
        amountPaid: paid,
        customerDebtBalance: previousDebtOf(updatedOrder),
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

  // ══════════════════════════════════
  //  إضافة منتج للطلبية (حبة أو كرتون حسب نوع البيع، وبسعر الطلبية)
  // ══════════════════════════════════
  double _orderPriceFor(Product p, bool isCarton) {
    final useSpecial = widget.order.isSpecialPrice;
    final base = isCarton
        ? (useSpecial ? p.priceCartonSpecial : p.priceCartonNormal)
        : (useSpecial ? p.priceUnitSpecial : p.priceUnitNormal);
    return p.discountedPrice(base);
  }

  String _productPriceHint(Product p) {
    final c = '${formatter.format(_orderPriceFor(p, true))} DA';
    final u = '${formatter.format(_orderPriceFor(p, false))} DA';
    switch (p.sellType) {
      case SellType.cartonOnly:
        return 'كرتون: $c';
      case SellType.unitOnly:
        return 'حبة: $u';
      case SellType.both:
        return 'كرتون: $c  |  حبة: $u';
    }
  }

  Map<String, dynamic> _orderItemFromProduct(Product p, bool isCarton) {
    final price = _orderPriceFor(p, isCarton);
    return {
      'productId': p.id,
      'productName': p.name,
      'quantity': 1,
      'price': price,
      'unitPrice': price,
      'isCarton': isCarton,
      'typeLabel': isCarton ? 'كرتون' : 'حبة',
      'flavor': '',
      // تكلفة الشراء وقت الإضافة (لسجل الأرباح)
      'cost': isCarton ? p.purchasePrice * p.unitsPerCarton : p.purchasePrice,
    };
  }

  /// true = كرتون، false = حبة، null = إلغاء (ويُختار تلقائياً إذا كان المنتج يُباع بنوع واحد)
  Future<bool?> _askCartonOrUnit(Product p) async {
    if (p.sellType == SellType.cartonOnly) return true;
    if (p.sellType == SellType.unitOnly) return false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(p.name, style: const TextStyle(fontSize: 16)),
        content: const Text('كيف تريد إضافة هذا المنتج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('حبة', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('كرتون', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showSelectProductForOrder() async {
    final products = await DataService.getAllProducts();
    if (products.isEmpty || !mounted) return null;

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
                        subtitle: Text(_productPriceHint(p)),
                        onTap: () async {
                          final isCarton = await _askCartonOrUnit(p);
                          if (isCarton == null || !context.mounted) return;
                          Navigator.pop(context, _orderItemFromProduct(p, isCarton));
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