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
    required String customerPhone,
    this.amountPaid,
    this.customerDebtBalance,
  }) : customerPhone = customerPhone;

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
                sum + ((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 0)));

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
            // العنوان الرئيسي للمعاينة
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

            // محاكاة الورقة الحرارية (Thermal Receipt Paper Card)
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // الشعار
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo.png',
                            height: 60,
                            width: 60,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.store_rounded,
                              size: 50,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'القناعة - AL QANAA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'لبيع المواد الغذائية بالجملة',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '---------------------------------------',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),

                        // تفاصيل الفاتورة والزبون
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('التاريخ : $dateStr',
                                  style: const TextStyle(fontSize: 11)),
                              Text('رقم الطلب : #$shortId',
                                  style: const TextStyle(fontSize: 11)),
                              Text(
                                'الزبون : ${widget.customerName.isEmpty ? "عادي" : widget.customerName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.customerPhone.isNotEmpty)
                                Text('الهاتف : ${widget.customerPhone}',
                                    style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '---------------------------------------',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),

                        // جدول المنتجات (سطرين لكل منتج)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'المنتجات :   ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        ...widget.order.items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final it = entry.value;
                          final name =
                              it['productName']?.toString() ?? 'منتج غير معروف';
                          final qty = (it['quantity'] as num? ?? 0).toDouble();
                          final price = (it['price'] as num? ?? 0).toDouble();
                          final lineTotal = qty * price;
                          final flavor = it['flavor']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // السطر 1: الترقيم واسم المنتج
                                Text(
                                  '$idx. $name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // السطر 2: الكمية × السعر والمجموع
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '   الكمية: ${qty.toStringAsFixed(0)} × ${_money(price)} دج',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '${_money(lineTotal)} دج',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                                // تفاصيل النكهات إذا وجدت
                                if (flavor.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '   النكهة: $flavor',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const Divider(height: 8, thickness: 0.5),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 6),
                        const Text(
                          '---------------------------------------',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),

                        // التفاصيل المالية والديون
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'مجموع الفاتورة :',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    '${_money(total)} دج',
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
                                  const Text('المبلغ المدفوع :',
                                      style: TextStyle(fontSize: 12)),
                                  Text('${_money(paid)} دج',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              if (remaining > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('متبقي الفاتورة :',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    Text(
                                      '${_money(remaining)} دج',
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
                                          const Text('الدين السابق :',
                                              style: TextStyle(fontSize: 11)),
                                          Text('${_money(prevDebt)} دج',
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
                                            'إجمالي الدين الجديد :',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${_money(prevDebt + (remaining > 0 ? remaining : 0))} دج',
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

                        const SizedBox(height: 8),
                        const Text(
                          '---------------------------------------',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'شكراً لتعاملكم معنا وثقتكم بنا',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'الهاتف: 0666629473',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // أزرار العمليات (تأكيد الطباعة / إلغاء)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isPrinting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                          borderRadius: BorderRadius.circular(10)),
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
                    label: Text(_isPrinting ? 'جاري الطباعة...' : 'تأكيد الطباعة'),
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
