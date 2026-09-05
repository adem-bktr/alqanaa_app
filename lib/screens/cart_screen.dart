import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/cart_service.dart';
import '../services/printer_service.dart';
import 'package:intl/intl.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final bool isAdmin;
  final UserModel? user;

  const CartScreen({
    super.key,
    required this.cart,
    required this.isAdmin,
    this.user,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final amountPaidController = TextEditingController();
  final formatter = NumberFormat('#,##0.00', 'fr_FR');
  bool isSpecialPrice = false;
  bool isLoading = false;

  // ✅ ربط الطلبية بزبون من دليل الديون (اختياري)
  CustomerModel? _selectedCustomer;

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      if (widget.user != null && !widget.isAdmin) {
        nameController.text = widget.user!.name;
        phoneController.text = widget.user!.phone;
        if (widget.user!.isSpecial) {
          setState(() => isSpecialPrice = true);
          return;
        }
      }
      final special = await DataService.getIsSpecialPrice();
      if (!mounted) return;
      setState(() => isSpecialPrice = special);
    } catch (e) {
      debugPrint('❌ خطأ في _initData: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    amountPaidController.dispose();
    super.dispose();
  }

  double get total =>
      widget.cart.fold(0, (sum, item) => sum + item.totalPrice);

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
  //  ✅ تعديل السعر (الأدمن فقط - خاص بهذه الطلبية)
  // ══════════════════════════════════
  Future<void> _showEditPriceDialog(int index) async {
    final item = widget.cart[index];
    final priceController = TextEditingController(
        text: item.unitPrice.toStringAsFixed(2));

    final result = await showDialog<Object>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('تعديل السعر',
                style: TextStyle(color: Color(0xFF2E7D32))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.product.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'السعر الجديد للوحدة (${item.typeLabel})',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'DA',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'));
              if (val == null || val < 0) {
                _showSnackBar('أدخل سعرًا صحيحًا', Colors.red);
                return;
              }
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() {
      if (result == 'reset') {
        widget.cart[index].overridePrice = null;
      } else if (result is double) {
        widget.cart[index].overridePrice = result;
      }
    });
  }

  // ══════════════════════════════════
  //  ✅ ربط الطلبية بزبون (اختياري - أدمن فقط)
  // ══════════════════════════════════
  Future<CustomerModel?> _showAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('زبون جديد',
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

    if (result != true) return null;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('أدخل اسم ورقم الزبون', Colors.red);
      return null;
    }
    final customer = CustomerModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
    );
    await DataService.saveCustomer(customer);
    return customer;
  }

  Future<void> _pickCustomer() async {
    String query = '';
    final selected = await showDialog<CustomerModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.people, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('اختيار زبون',
                  style: TextStyle(color: Color(0xFF2E7D32))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الهاتف...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setSt(() => query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final created = await _showAddCustomerDialog();
                      if (created != null && context.mounted) {
                        Navigator.pop(context, created);
                      }
                    },
                    icon: const Icon(Icons.person_add,
                        color: Color(0xFF2E7D32)),
                    label: const Text('إضافة زبون جديد',
                        style: TextStyle(color: Color(0xFF2E7D32))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<CustomerModel>>(
                    stream: DataService.getCustomersStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF2E7D32)));
                      }
                      var list = snapshot.data!;
                      if (query.isNotEmpty) {
                        list = list
                            .where((c) =>
                        c.name.toLowerCase().contains(query) ||
                            c.phone.contains(query))
                            .toList();
                      }
                      if (list.isEmpty) {
                        return const Center(
                            child: Text('لا يوجد زبائن',
                                style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.hasDebt
                                  ? Colors.red.shade50
                                  : const Color(0xFFE8F5E9),
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: c.hasDebt
                                        ? Colors.red
                                        : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(c.phone),
                            trailing: c.hasDebt
                                ? Text(formatPrice(c.balance),
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))
                                : null,
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCustomer = selected;
        nameController.text = selected.name;
        phoneController.text = selected.phone;
        amountPaidController.text = total.toStringAsFixed(2);
      });
    }
  }

  Widget _buildCustomerLinkSection(bool isDark) {
    if (!widget.isAdmin) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _selectedCustomer == null
          ? SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _pickCustomer,
          icon: const Icon(Icons.people_outline,
              color: Color(0xFF2E7D32)),
          label: const Text('ربط بزبون (اختياري)',
              style: TextStyle(color: Color(0xFF2E7D32))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2E7D32)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_selectedCustomer!.name,
                    style:
                    const TextStyle(fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedCustomer = null;
                  amountPaidController.clear();
                }),
                child: const Icon(Icons.close,
                    size: 18, color: Colors.red),
              ),
            ],
          ),
          if (_selectedCustomer!.hasDebt)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  'دين سابق: ${formatPrice(_selectedCustomer!.balance)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.red)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: amountPaidController,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'المبلغ المدفوع الآن',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixText: 'DA',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Builder(builder: (context) {
            final paid = double.tryParse(
                amountPaidController.text.trim().replaceAll(',', '.')) ??
                0;
            final remaining = total - paid;
            if (remaining > 0) {
              return Text(
                  'سيُسجَّل كدين: ${formatPrice(remaining)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold));
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Future<bool> showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: const Text('تأكيد الطلب',
            style: TextStyle(color: Color(0xFF2E7D32))),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration:
                const BoxDecoration(color: Color(0xFFE8F5E9)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person,
                          color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Text(nameController.text.trim(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.phone,
                          color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Text(phoneController.text.trim()),
                    ]),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: const Color(0xFF2E7D32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المنتجات',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text('${widget.cart.length} صنف',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: widget.cart.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.cart[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isCarton
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(item.typeLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isCarton
                                        ? const Color(0xFF2E7D32)
                                        : Colors.blue)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                if (item.flavor != null &&
                                    item.flavor!.isNotEmpty)
                                  Text(item.flavor!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.purple,
                                          fontWeight:
                                          FontWeight.w500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('× ${item.quantity}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey)),
                              Text(formatPrice(item.totalPrice),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  border: Border(
                      top: BorderSide(
                          color: Color(0xFF2E7D32), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المجموع الكلي:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(formatPrice(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                            fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style:
                TextStyle(color: Colors.grey, fontSize: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('تأكيد الطلب',
                style:
                TextStyle(color: Colors.white, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  bool _validateInputs() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('الرجاء إدخال اسم ورقم الزبون', Colors.red);
      return false;
    }
    if (widget.cart.isEmpty) {
      _showSnackBar('السلة فارغة!', Colors.red);
      return false;
    }
    return true;
  }

  Future<void> _saveOrder({bool printThermal = false}) async {
    if (!_validateInputs()) return;

    if (printThermal) {
      if (!PrinterService.isConnected) {
        _showSnackBar('⚠️ الطابعة الحرارية غير متصلة', Colors.orange);
        return;
      }
    } else {
      final confirmed = await showConfirmDialog();
      if (!confirmed) return;
    }

    setState(() => isLoading = true);

    try {
      final date =
      DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now());
      final currentUser = await AuthService.getCurrentUser();
      final orderId =
      DateTime.now().millisecondsSinceEpoch.toString();

      final order = Order(
        id: orderId,
        customerName: nameController.text.trim(),
        customerPhone: phoneController.text.trim(),
        items: widget.cart
            .map((i) => {
          'productName': i.product.name,
          'quantity': i.quantity,
          // ✅ i.unitPrice يأخذ بالحسبان السعر المعدّل (overridePrice) إن وُجد
          'price': i.unitPrice,
          'unitPrice': i.unitPrice,
          'isCarton': i.isCarton,
          'typeLabel': i.typeLabel,
          'flavor': i.flavor ?? '',
          'priceOverridden': i.hasOverridePrice,
        })
            .toList(),
        total: total,
        isSpecialPrice: isSpecialPrice,
        date: date,
        userId: currentUser?.id ?? '',
        status: 'pending',
      );

      // ✅ إذا اختار الأدمن "طباعة وتأكيد": نطبع أولاً، وإذا فشلت الطباعة
      // نوقف العملية بالكامل ولا نحفظ أي شيء — الطباعة الناجحة هي التأكيد.
      if (printThermal) {
        double? paidForPrint;
        double? balanceForPrint;
        if (_selectedCustomer != null) {
          final paid = double.tryParse(
              amountPaidController.text.trim().replaceAll(',', '.')) ??
              total;
          final remaining = total - paid;
          paidForPrint = paid;
          balanceForPrint = _selectedCustomer!.balance +
              (remaining > 0 ? remaining : 0);
        }

        final printed = await PrinterService.printReceipt(
          order: order,
          customerName: nameController.text.trim(),
          customerPhone: phoneController.text.trim(),
          amountPaid: paidForPrint,
          customerDebtBalance: balanceForPrint,
        );

        if (!printed) {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showSnackBar(
              '❌ فشلت الطباعة — لم تُحفظ الطلبية، حاول مجددًا',
              Colors.red);
          return;
        }
      }

      await DataService.saveOrder(order);
      debugPrint('✅ الطلب محفوظ: $orderId');

      // ✅ تسجيل الدين إذا الطلبية مربوطة بزبون ومازال باقي مبلغ
      if (_selectedCustomer != null) {
        final paid = double.tryParse(
            amountPaidController.text.trim().replaceAll(',', '.')) ??
            total;
        final remaining = total - paid;
        if (remaining > 0) {
          await DataService.addDebtTransaction(
            customerId: _selectedCustomer!.id,
            type: 'charge',
            amount: remaining,
            note: 'Commande #$orderId',
          );
          debugPrint('💳 دين مسجّل: $remaining على ${_selectedCustomer!.name}');
        }
      }

      NotificationService.notifyAdminNewOrder(
        customerName: nameController.text.trim(),
        total: total,
        orderId: orderId,
      );

      _updateOrderLocationInBackground(orderId);

      widget.cart.clear();
      await CartService.clearCart();

      setState(() {
        _selectedCustomer = null;
        amountPaidController.clear();
      });

      if (!mounted) return;
      _showSnackBar(
          printThermal
              ? '✅ تمت الطباعة وتأكيد الطلبية بنجاح'
              : '✅ تم إرسال طلبك بنجاح',
          const Color(0xFF2E7D32));
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في _saveOrder: $e');
      if (!mounted) return;
      _showSnackBar('حدث خطأ، حاول مجدداً', Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _updateOrderLocationInBackground(String orderId) {
    Future(() async {
      try {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          final lat = position.latitude;
          final lng = position.longitude;
          final address =
          await LocationService.getAddressFromLatLng(lat, lng);
          await DataService.updateOrderLocation(
              orderId, lat, lng, address);
          debugPrint('📍 تم تحديث الموقع للطلب: $orderId');
        }
      } catch (e) {
        debugPrint('⚠️ خطأ في تحديث الموقع: $e');
      }
    });
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 11)),
    );
  }

  pw.Widget _dataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  Future<pw.Document> _buildPDF() async {
    final pdf = pw.Document();
    final date =
    DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now());

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      logoImage = null;
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration:
        const pw.BoxDecoration(color: PdfColors.green800),
        children: [
          _headerCell('Produit'),
          _headerCell('Goût'),
          _headerCell('Qte'),
          _headerCell('Type'),
          _headerCell('Prix/Unite'),
          _headerCell('Total'),
        ],
      ),
      ...widget.cart.asMap().entries.map((entry) {
        final item = entry.value;
        final index = entry.key;
        // ✅ يعكس السعر المعدّل (overridePrice) إن كان الأدمن قد بدّله
        final unitPrice = item.unitPrice;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: index % 2 == 0
                  ? PdfColors.white
                  : PdfColors.grey50),
          children: [
            _dataCell(item.product.name),
            _dataCell(item.flavor != null && item.flavor!.isNotEmpty
                ? item.flavor!
                : '-'),
            _dataCell('${item.quantity}'),
            _dataCell(item.isCarton ? 'Carton' : 'Unite'),
            _dataCell(formatPrice(unitPrice)),
            _dataCell(formatPrice(item.totalPrice)),
          ],
        );
      }),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Al Qanaa Grossiste',
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                    pw.Text('Facture de vente',
                        style: const pw.TextStyle(
                            fontSize: 14, color: PdfColors.grey)),
                    pw.Text(
                        'N°: ${DateTime.now().millisecondsSinceEpoch}',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                if (logoImage != null)
                  pw.Image(logoImage, width: 70, height: 70),
              ],
            ),
            pw.Divider(
                thickness: 2, color: PdfColors.green800),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.green800),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Merci pour votre confiance - Al Qanaa Grossiste',
                    style: const pw.TextStyle(
                        color: PdfColors.grey, fontSize: 10)),
                pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(
                        color: PdfColors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
        build: (pw.Context context) {
          final paid = double.tryParse(
              amountPaidController.text.trim().replaceAll(',', '.')) ??
              total;
          final remaining = total - paid;
          final previewBalance = _selectedCustomer == null
              ? 0.0
              : _selectedCustomer!.balance + (remaining > 0 ? remaining : 0);

          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Informations client',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                  pw.SizedBox(height: 8),
                  pw.Text('Nom: ${nameController.text.trim()}'),
                  pw.Text('Tel: ${phoneController.text.trim()}'),
                  pw.Text('Date: $date'),
                  pw.SizedBox(height: 4),
                  pw.Text('Statut: En attente',
                      style:
                      const pw.TextStyle(color: PdfColors.orange)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Produits',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(2),
              },
              children: tableRows,
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.green800),
                ),
                child: pw.Text(
                    'Total général: ${formatPrice(total)}',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ),
            ),
            if (_selectedCustomer != null) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.orange),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Client: ${_selectedCustomer!.name}',
                        style:
                        pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Paye: ${formatPrice(paid)}'),
                    if (remaining > 0)
                      pw.Text('Reste (facture): ${formatPrice(remaining)}',
                          style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Solde dette client: ${formatPrice(previewBalance)}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red)),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> printPDF() async {
    if (nameController.text.trim().isEmpty) {
      _showSnackBar('الرجاء إدخال اسم الزبون أولاً', Colors.red);
      return;
    }
    final pdf = await _buildPDF();
    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Facture_AlQanaa');
  }

  Future<String?> _showFlavorDialog(
      BuildContext context, List<FlavorModel> flavors) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.icecream, color: Colors.purple),
            SizedBox(width: 8),
            Text('اختر الطعم',
                style: TextStyle(color: Colors.purple)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: flavors.length,
            itemBuilder: (context, index) {
              final flavor = flavors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                      color: flavor.isAvailable
                          ? Colors.purple
                          : Colors.grey,
                      width: 0.5),
                ),
                child: ListTile(
                  enabled: flavor.isAvailable,
                  leading: Icon(Icons.circle,
                      color: flavor.isAvailable
                          ? Colors.purple
                          : Colors.grey,
                      size: 12),
                  title: Text(flavor.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: flavor.isAvailable
                              ? null
                              : Colors.grey)),
                  onTap: () =>
                      Navigator.pop(context, flavor.name),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor =
    isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (isDesktop) {
      return _buildDesktopLayout(isDark, bgColor, cardColor, textColor);
    }
    return _buildMobileLayout(isDark, bgColor, cardColor, textColor);
  }

  // ══════════════════════════════════
  //  Desktop Layout
  // ══════════════════════════════════
  Widget _buildDesktopLayout(
      bool isDark, Color bgColor, Color cardColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Row(
          children: [
            const Text('السلة',
                style: TextStyle(color: Colors.white)),
            if (widget.cart.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.cart.length} صنف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (!widget.isAdmin) CartService.saveCart(widget.cart);
            Navigator.pop(context);
          },
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: printPDF,
              tooltip: 'طباعة PDF',
            ),
          if (widget.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep,
                  color: Colors.white),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('تفريغ السلة'),
                  content:
                  const Text('هل تريد حذف جميع المنتجات؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء')),
                    TextButton(
                      onPressed: () async {
                        setState(() => widget.cart.clear());
                        await CartService.clearCart();
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('تفريغ',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              tooltip: 'تفريغ السلة',
            ),
        ],
      ),
      body: isLoading
          ? const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF2E7D32)))
          : widget.cart.isEmpty
          ? _buildEmptyCart(isDark)
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── العمود الأيسر: قائمة المنتجات ──
          Expanded(
            flex: 6,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.cart.length,
              itemBuilder: (context, index) =>
                  _buildCartItem(
                      index, isDark, cardColor, textColor),
            ),
          ),
          // ── العمود الأيمن: ملخص الطلب ──
          Container(
            width: 340,
            height: double.infinity,
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                      isDark ? 0.3 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: _buildDesktopSummary(
                isDark, cardColor, textColor),
          ),
        ],
      ),
    );
  }

  // ── ملخص الطلب للـ Desktop ──
  Widget _buildDesktopSummary(
      bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملخص الطلب',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${widget.cart.length} صنف',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // اسم الزبون
          _buildDesktopField(
            controller: nameController,
            hint: 'اسم الزبون',
            icon: Icons.person,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // رقم الهاتف
          _buildDesktopField(
            controller: phoneController,
            hint: 'رقم الهاتف',
            icon: Icons.phone,
            isDark: isDark,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          // ✅ ربط بزبون (اختياري - أدمن فقط)
          _buildCustomerLinkSection(isDark),

          // المجموع
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF2E7D32).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الكلي:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(formatPrice(total),
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // زر التأكيد
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final missingFlavor = widget.cart.any((item) =>
                item.product.hasFlavors &&
                    (item.flavor == null || item.flavor!.isEmpty));
                if (missingFlavor) {
                  _showSnackBar(
                      'يرجى اختيار الطعم لجميع المنتجات',
                      Colors.orange);
                  return;
                }
                _saveOrder();
              },
              icon: const Icon(Icons.check_circle,
                  color: Colors.white),
              label: const Text('تأكيد الطلبية',
                  style: TextStyle(
                      color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ✅ زر الطباعة الحرارية — يطبع الوصل ويؤكد الطلبية تلقائيًا (أدمن فقط)
          if (widget.isAdmin)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                  final missingFlavor = widget.cart.any((item) =>
                  item.product.hasFlavors &&
                      (item.flavor == null || item.flavor!.isEmpty));
                  if (missingFlavor) {
                    _showSnackBar(
                        'يرجى اختيار الطعم لجميع المنتجات',
                        Colors.orange);
                    return;
                  }
                  _saveOrder(printThermal: true);
                },
                icon: const Icon(Icons.print_rounded,
                    color: Colors.white),
                label: const Text('طباعة حرارية وتأكيد',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // زر الطباعة (Admin فقط)
          if (widget.isAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: printPDF,
                icon: const Icon(Icons.print,
                    color: Color(0xFF2E7D32)),
                label: const Text('طباعة PDF',
                    style: TextStyle(color: Color(0xFF2E7D32))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey),
        filled: true,
        fillColor:
        isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        prefixIcon: Icon(icon,
            color: isDark
                ? Colors.green.shade400
                : const Color(0xFF2E7D32)),
      ),
    );
  }

  // ══════════════════════════════════
  //  Mobile Layout
  // ══════════════════════════════════
  Widget _buildMobileLayout(
      bool isDark, Color bgColor, Color cardColor, Color textColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Row(
          children: [
            const Text('السلة',
                style: TextStyle(color: Colors.white)),
            if (widget.cart.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.cart.length} صنف',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (!widget.isAdmin) CartService.saveCart(widget.cart);
            Navigator.pop(context);
          },
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: printPDF,
              tooltip: 'طباعة PDF',
            ),
          if (widget.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep,
                  color: Colors.white),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('تفريغ السلة'),
                  content:
                  const Text('هل تريد حذف جميع المنتجات؟'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء')),
                    TextButton(
                      onPressed: () async {
                        setState(() => widget.cart.clear());
                        await CartService.clearCart();
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('تفريغ',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              tooltip: 'تفريغ السلة',
            ),
        ],
      ),
      bottomNavigationBar: widget.cart.isEmpty
          ? null
          : SafeArea(
        child: Container(
          color: cardColor,
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'اسم الزبون',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A3E)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.person,
                        color: isDark
                            ? Colors.green.shade400
                            : const Color(0xFF2E7D32)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'رقم الهاتف',
                    hintStyle: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A3E)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.phone,
                        color: isDark
                            ? Colors.green.shade400
                            : const Color(0xFF2E7D32)),
                  ),
                ),
                const SizedBox(height: 8),
                // ✅ ربط بزبون (اختياري - أدمن فقط)
                _buildCustomerLinkSection(isDark),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(formatPrice(total),
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final missingFlavor =
                      widget.cart.any((item) =>
                      item.product.hasFlavors &&
                          (item.flavor == null ||
                              item.flavor!.isEmpty));
                      if (missingFlavor) {
                        _showSnackBar(
                            'يرجى اختيار الطعم لجميع المنتجات',
                            Colors.orange);
                        return;
                      }
                      _saveOrder();
                    },
                    icon: const Icon(Icons.check_circle,
                        color: Colors.white),
                    label: const Text('تأكيد الطلبية',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // ✅ زر الطباعة الحرارية — يطبع الوصل ويؤكد الطلبية تلقائيًا (أدمن فقط)
                if (widget.isAdmin) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () {
                        final missingFlavor =
                        widget.cart.any((item) =>
                        item.product.hasFlavors &&
                            (item.flavor == null ||
                                item.flavor!.isEmpty));
                        if (missingFlavor) {
                          _showSnackBar(
                              'يرجى اختيار الطعم لجميع المنتجات',
                              Colors.orange);
                          return;
                        }
                        _saveOrder(printThermal: true);
                      },
                      icon: const Icon(Icons.print_rounded,
                          color: Colors.white),
                      label: const Text('طباعة حرارية وتأكيد',
                          style: TextStyle(
                              color: Colors.white, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        maintainBottomViewPadding: true,
        child: isLoading
            ? const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF2E7D32)))
            : widget.cart.isEmpty
            ? _buildEmptyCart(isDark)
            : ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: widget.cart.length,
          itemBuilder: (context, index) => _buildCartItem(
              index, isDark, cardColor, textColor),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Shared Widgets
  // ══════════════════════════════════
  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80,
              color: isDark ? Colors.grey.shade700 : Colors.grey),
          const SizedBox(height: 16),
          Text('السلة فارغة',
              style: TextStyle(
                  fontSize: 18,
                  color:
                  isDark ? Colors.grey.shade500 : Colors.grey)),
          const SizedBox(height: 8),
          Text('أضف منتجات للبدء',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.grey.shade600
                      : Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildCartItem(
      int index, bool isDark, Color cardColor, Color textColor) {
    final item = widget.cart[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isCarton
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFE3F2FD),
                              borderRadius:
                              BorderRadius.circular(4),
                            ),
                            child: Text(item.typeLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: item.isCarton
                                        ? const Color(0xFF2E7D32)
                                        : Colors.blue,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (item.product.hasFlavors) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () async {
                                final newFlavor =
                                await _showFlavorDialog(context,
                                    item.product.flavors);
                                if (newFlavor != null && mounted) {
                                  setState(() {
                                    final oldOverride =
                                        item.overridePrice;
                                    widget.cart[index] = CartItem(
                                      product: item.product,
                                      quantity: item.quantity,
                                      isSpecialPrice:
                                      item.isSpecialPrice,
                                      isCarton: item.isCarton,
                                      flavor: newFlavor,
                                      overridePrice: oldOverride,
                                    );
                                  });
                                  if (!widget.isAdmin) {
                                    await CartService.saveCart(
                                        widget.cart);
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple
                                      .withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Colors.purple
                                          .withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.icecream,
                                        size: 11,
                                        color: Colors.purple),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.flavor != null &&
                                          item.flavor!.isNotEmpty
                                          ? item.flavor!
                                          : 'اختر طعم',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.purple,
                                          fontWeight:
                                          FontWeight.bold),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.edit,
                                        size: 10,
                                        color: Colors.purple),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(formatPrice(item.totalPrice),
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                          '${formatPrice(item.unitPrice)} / ${item.typeLabel}',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey,
                              fontSize: 12)),
                      // ✅ زر تعديل السعر — يظهر للأدمن فقط
                      if (widget.isAdmin)
                        GestureDetector(
                          onTap: () => _showEditPriceDialog(index),
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32)
                                  .withOpacity(0.08),
                              borderRadius:
                              BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF2E7D32)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit,
                                    size: 11,
                                    color: Color(0xFF2E7D32)),
                                const SizedBox(width: 3),
                                const Text(
                                  'تعديل السعر',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle,
                      color: Color(0xFF2E7D32)),
                  onPressed: () async {
                    setState(() {
                      if (item.quantity > 1) {
                        item.quantity--;
                      } else {
                        widget.cart.removeAt(index);
                      }
                    });
                    if (!widget.isAdmin) {
                      await CartService.saveCart(widget.cart);
                    }
                  },
                ),
                Text('${item.quantity}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor)),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: Color(0xFF2E7D32)),
                  onPressed: () async {
                    setState(() => item.quantity++);
                    if (!widget.isAdmin) {
                      await CartService.saveCart(widget.cart);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    setState(() => widget.cart.removeAt(index));
                    if (!widget.isAdmin) {
                      await CartService.saveCart(widget.cart);
                    }
                  },
                ),
              ],
            ),
            if (item.product.hasFlavors &&
                (item.flavor == null || item.flavor!.isEmpty))
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 14, color: Colors.orange),
                    SizedBox(width: 6),
                    Text('يرجى اختيار الطعم',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}