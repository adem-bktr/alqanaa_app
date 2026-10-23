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
      // ✅ إصلاح 5: لا تُغلق النافذة بلمسة خارجها (كانت تُرجع null أثناء الطباعة فيُعتبر الطلب ملغى)
      barrierDismissible: false,
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
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intDigits = parts[0];
    final decPart = parts[1];

    final buf = StringBuffer();
    for (int i = 0; i < intDigits.length; i++) {
      if (i > 0 && (intDigits.length - i) % 3 == 0) {
        buf.write(' ');
      }
      buf.write(intDigits[i]);
    }
    buf.write('.$decPart');
    return (isNeg ? '-' : '') + buf.toString();
  }

  String _fmtQty(num qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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
        // فشلت الطباعة — نسأل المستخدم هل يريد حفظ الطلب بدون طباعة؟
        final saveAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('الطابعة غير متصلة'),
              ],
            ),
            content: Text(
                PrinterService.lastError ?? 'تعذر الاتصال بالطابعة. هل تريد حفظ الطلب وتخطي الطباعة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text('حفظ بدون طباعة'),
              ),
            ],
          ),
        );

        if (saveAnyway == true && mounted) {
          Navigator.of(context).pop(true);
        }
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
                  onPressed: _isPrinting
                      ? null
                      : () => Navigator.of(context).pop(false),
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
                        // العنوان (بدون لوغو وأسود فاقع للوضوح)
                        const Center(
                          child: Text(
                            'AL QANAA GROSSISTE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Vente de produits alimentaires',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            '--------------------------------------------',
                            style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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
                                  flavors.add('$flavor (${_fmtQty(qty)})');
                                }
                              } else {
                                final flavor = it['flavor']?.toString() ?? '';
                                grouped[key] = {
                                  'productName': name,
                                  'quantity': qty,
                                  'total': qty * price,
                                  'isCarton': isCarton,
                                  'flavors': flavor.isNotEmpty
                                      ? ['$flavor (${_fmtQty(qty)})']
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
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$idx. $name ($type)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11.5,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '   Qte: ${_fmtQty(qty)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            '${_money(total)} DA',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (flavorsList.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 12, top: 1),
                                          child: Text(
                                            '   Aromes: ${flavorsList.join(", ")}',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Colors.black,
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
                            style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // الحسابات والإجماليات (أسود وأبيض فقط - خطوط بارزة وواضحة جداً)
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black, width: 2.0),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL A PAYER :',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Colors.black,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    '${_money(total)} DA',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Montant Verse :',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                  Text('${_money(paid)} DA',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black)),
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
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      '${_money(remaining)} DA',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (prevDebt > 0 || (prevDebt + (remaining > 0 ? remaining : 0)) > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black, width: 2.2),
                            ),
                            child: Column(
                              children: [
                                const Center(
                                  child: Text(
                                    '=== COMPTE CLIENT / كشف الحساب ===',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: Colors.black,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Divider(height: 10, thickness: 1.5, color: Colors.black),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Ancien Solde :',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                    Text('${_money(prevDebt)} DA',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'NOUVEAU SOLDE :',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      '${_money(prevDebt + (remaining > 0 ? remaining : 0))} DA',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

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
            Column(
              children: [
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPrinting
                            ? null
                            : () => Navigator.of(context).pop(true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('حفظ بدون طباعة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
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
                      _isPrinting ? 'جاري الطباعة...' : 'طباعة وتأكيد',
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