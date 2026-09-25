import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';
import '../services/printer_service.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  final Order order;
  final String customerName;
  final String customerPhone;
  final double? amountPaid;
  final double? customerDebtBalance;

  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.customerName,
    required this.customerPhone,
    this.amountPaid,
    this.customerDebtBalance,
  });

  static Future<bool?> show(
      BuildContext context, {
        required Order order,
        required String customerName,
        required String customerPhone,
        double? amountPaid,
        double? customerDebtBalance,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptPreviewDialog(
        order: order,
        customerName: customerName,
        customerPhone: customerPhone,
        amountPaid: amountPaid,
        customerDebtBalance: customerDebtBalance,
      ),
    );
  }

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _isPrinting = false;

  String _money(num value) {
    final isNeg = value < 0;
    final digits = value.abs().round().toString();
    final buf = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buf.write(' ');
      }
      buf.write(digits[i]);
    }
    return (isNeg ? '-' : '') + buf.toString();
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);

    try {
      final success = await PrinterService.printReceipt(
        order: widget.order,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
        amountPaid: widget.amountPaid,
        customerDebtBalance: widget.customerDebtBalance,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال الوصل للطابعة بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تعذر إرسال الوصل. يرجى التحقق من اتصال الطابعة.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في الطباعة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now());
    final total = widget.order.total > 0
        ? widget.order.total
        : widget.order.items.fold<double>(
        0,
            (sum, item) =>
        sum +
            ((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 0)));

    final paid = widget.amountPaid ?? widget.order.paidAmount;
    final remaining = total - paid;
    final prevDebt = widget.customerDebtBalance ?? 0;
    final shortId = widget.order.id.length > 6
        ? widget.order.id.substring(widget.order.id.length - 6)
        : widget.order.id;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // رأس النافذة
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text(
                  'معاينة الوصل الحراري',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // محاكاة الورقة الحرارية المطبوعة (LTR بالفرنسية)
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr, // اتجاه LTR
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الشعار
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/logo.png',
                              height: 90,
                              width: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.store_rounded,
                                size: 75,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'AL QANAA GROSSISTE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Vente de produits alimentaires',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            '--------------------------------------------',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),

                        // معلومات الوصل والزبون
                        Text('Date   : $dateStr',
                            style: const TextStyle(fontSize: 11)),
                        Text('Order  : #$shortId',
                            style: const TextStyle(fontSize: 11)),
                        Text(
                          'Client : ${widget.customerName.isEmpty ? "-" : widget.customerName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.customerPhone.isNotEmpty)
                          Text('Tel    : ${widget.customerPhone}',
                              style: const TextStyle(fontSize: 11)),

                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            '--------------------------------------------',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),

                        // قائمة المنتجات (مجمعة تماماً كالطباعة الفعلية)
                        Builder(
                          builder: (context) {
                            final Map<String, Map<String, dynamic>> grouped = {};
                            for (final it in widget.order.items) {
                              final name = it['productName']?.toString() ?? 'Produit';
                              final isCarton = it['isCarton'] == true;
                              final key = '$name-$isCarton';
                              final price = (it['price'] as num? ?? 0).toDouble();
                              final qty = (it['quantity'] as num? ?? 0).toDouble();

                              if (grouped.containsKey(key)) {
                                grouped[key]!['quantity'] = (grouped[key]!['quantity'] as double) + qty;
                                grouped[key]!['total'] = (grouped[key]!['total'] as double) + (qty * price);
                                final flavor = it['flavor']?.toString() ?? '';
                                if (flavor.isNotEmpty) {
                                  final flavors = grouped[key]!['flavors'] as List<String>;
                                  flavors.add('$flavor (${qty.toStringAsFixed(0)})');
                                }
                              } else {
                                final flavor = it['flavor']?.toString() ?? '';
                                grouped[key] = {
                                  'productName': name,
                                  'quantity': qty,
                                  'total': qty * price,
                                  'isCarton': isCarton,
                                  'flavors': flavor.isNotEmpty
                                      ? ['$flavor (${qty.toStringAsFixed(0)})']
                                      : <String>[],
                                };
                              }
                            }

                            final groupedList = grouped.values.toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: groupedList.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final data = entry.value;
                                final name = data['productName'] as String;
                                final qty = data['quantity'] as double;
                                final total = data['total'] as double;
                                final isCarton = data['isCarton'] == true;
                                final type = isCarton ? 'Crt' : 'Unt';
                                final flavorsList = data['flavors'] as List<String>;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$idx. $name ($type)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '   Qte: ${qty.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            '${_money(total)} DA',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (flavorsList.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12, top: 1),
                                          child: Text(
                                            '   Aromes: ${flavorsList.join(", ")}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blueGrey.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            '--------------------------------------------',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),

                        // الحسابات والإجماليات
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL A PAYER :',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${_money(total)} DA',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Montant Verse :',
                                      style: TextStyle(fontSize: 11)),
                                  Text('${_money(paid)} DA',
                                      style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                              if (remaining > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Reste Facture :',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      '${_money(remaining)} DA',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (prevDebt > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Ancien Solde :',
                                              style: TextStyle(fontSize: 11)),
                                          Text('${_money(prevDebt)} DA',
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'NOUVEAU SOLDE :',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${_money(prevDebt + (remaining > 0 ? remaining : 0))} DA',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            '--------------------------------------------',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Merci pour votre confiance !',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Tel: 0666629473',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // أزرار التحكم
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isPrinting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isPrinting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.print_rounded),
                    label: Text(
                      _isPrinting ? 'جاري الطباعة...' : 'تأكيد الطباعة',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
