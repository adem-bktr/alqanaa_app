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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  double _d(dynamic v) => toDouble(v);
  int _i(dynamic v) => toInt(v);

  final searchController = TextEditingController();
  final NumberFormat formatter = NumberFormat('#,##0', 'en_US');
  String selectedFilter = 'all';

  bool _isDisposed = false;
  bool _isActive = true;

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onPause: () => _isActive = false,
      onResume: () => _isActive = true,
    ));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    searchController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed || !_isActive) return;
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
        if (o.createdAt == null) return false;
        if (selectedFilter == 'today') {
          return o.createdAt!.year == now.year &&
              o.createdAt!.month == now.month &&
              o.createdAt!.day == now.day;
        } else if (selectedFilter == 'week') {
          return now.difference(o.createdAt!).inDays <= 7;
        } else if (selectedFilter == 'month') {
          return now.difference(o.createdAt!).inDays <= 30;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri,
          mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الخريطة'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _printThermal(Order order) async {
    if (!mounted) return;
    if (!PrinterService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ الطابعة غير متصلة'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    color: Color(0xFF2E7D32)),
                SizedBox(height: 16),
                Text('جاري الطباعة...'),
              ],
            ),
          ),
        ),
      ),
    );
    final success = await PrinterService.printReceipt(
      order: order,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            success ? '✅ تمت الطباعة بنجاح' : '❌ فشلت الطباعة'),
        backgroundColor:
        success ? const Color(0xFF2E7D32) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<pw.Document> _buildOrderPDF(Order order) async {
    final pdf = pw.Document();
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoImage =
          pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      logoImage = null;
    }

    pw.Widget headerCell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10)),
    );

    pw.Widget dataCell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 9)),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Al Qanaa Grossiste',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                    pw.Text('Facture de vente',
                        style: const pw.TextStyle(
                            fontSize: 13,
                            color: PdfColors.grey)),
                    pw.Text('N°: ${order.id}',
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey)),
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
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.green800),
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Merci pour votre confiance - Al Qanaa',
                    style: const pw.TextStyle(
                        color: PdfColors.grey, fontSize: 9)),
                pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(
                        color: PdfColors.grey, fontSize: 9)),
              ],
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Informations client',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
                pw.SizedBox(height: 8),
                pw.Text('Nom: ${order.customerName}'),
                pw.Text('Tel: ${order.customerPhone}'),
                pw.Text(
                    'Date: ${_formatOrderDate(order)}'),
                if (order.address != null &&
                    order.address!.isNotEmpty)
                  pw.Text('Adresse: ${order.address}'),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Statut: ${_getPdfStatus(order.status)}',
                  style: pw.TextStyle(
                    color: order.status == 'confirmed'
                        ? PdfColors.green800
                        : order.status == 'rejected'
                        ? PdfColors.red
                        : PdfColors.orange,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Produits',
              style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          pw.SizedBox(height: 8),
          pw.Table(
            border:
            pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.8),
              5: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColors.green800),
                children: [
                  headerCell('Produit'),
                  headerCell('Gout'),
                  headerCell('Qte'),
                  headerCell('Type'),
                  headerCell('Prix/Unite'),
                  headerCell('Total'),
                ],
              ),
              ...order.items.asMap().entries.map((entry) {
                final i = entry.value;
                final index = entry.key;
                final price =
                    (i['price'] as num?)?.toDouble() ?? 0;
                final qty =
                    (i['quantity'] as num?)?.toInt() ?? 0;
                final isCarton =
                    (i['isCarton'] as bool?) ?? true;
                final type =
                isCarton ? 'Carton' : 'Unite';
                final unitPriceDisplay =
                    (i['unitPrice'] as num?)?.toDouble() ??
                        price;
                final totalItem = price * qty;
                final flavor =
                    (i['flavor'] as String?) ?? '';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: index % 2 == 0
                          ? PdfColors.white
                          : PdfColors.grey50),
                  children: [
                    dataCell(
                        i['productName']?.toString() ?? ''),
                    dataCell(flavor.isNotEmpty ? flavor : '-'),
                    dataCell('$qty'),
                    dataCell(type),
                    dataCell(
                        '${formatter.format(unitPriceDisplay)} DA'),
                    dataCell(
                        '${formatter.format(totalItem)} DA'),
                  ],
                );
              }),
            ],
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
                border:
                pw.Border.all(color: PdfColors.green800),
              ),
              child: pw.Text(
                'Total: ${formatter.format(order.total)} DA',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800),
              ),
            ),
          ),
        ],
      ),
    );
    return pdf;
  }

  String _getPdfStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirme';
      case 'rejected':
        return 'Rejete';
      default:
        return 'En attente';
    }
  }

  Future<void> _printOrderPDF(Order order) async {
    try {
      final pdf = await _buildOrderPDF(order);
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Facture_${order.customerName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _changeOrderStatus(
      Order order, String newStatus) async {
    try {
      await DataService.updateOrderStatus(
          order.id, newStatus);
      await NotificationService.notifyUserOrderStatus(
        userId: order.userId,
        status: newStatus,
        customerName: order.customerName,
        orderId: order.id,
      );
      if (mounted) {
        String msg;
        Color color;
        switch (newStatus) {
          case 'confirmed':
            msg = '✅ تم تأكيد الطلب وإشعار الزبون';
            color = Colors.green;
            break;
          case 'rejected':
            msg = '❌ تم رفض الطلب وإشعار الزبون';
            color = Colors.red;
            break;
          default:
            msg = '⏳ الطلب قيد المراجعة';
            color = Colors.orange;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ خطأ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الطلب'),
        content:
        Text('هل تريد حذف طلب ${order.customerName}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DataService.deleteOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف الطلب'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ══════════════════════════════════
  //  ✅ تعديل الطلبية (جديد)
  // ══════════════════════════════════
  Future<void> _showEditOrderDialog(Order order) async {
    // نسخة محلية للتعديل
    List<Map<String, dynamic>> editedItems = List.from(
        order.items.map((it) => Map<String, dynamic>.from(it)));
    
    double calculateNewTotal() {
      return editedItems.fold(0.0, (sum, it) {
        final price = _d(it['price']);
        final qty = _i(it['quantity']);
        return sum + (price * qty);
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل طلب ${order.customerName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: editedItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final item = editedItems[i];
                      final name = item['productName'] ?? 'منتج';
                      final qty = _i(item['quantity']);
                      final price = _d(item['price']);
                      final type = item['typeLabel'] ?? 'كرتون';

                      return ListTile(
                        title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('السعر: ${formatter.format(price)} DA'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setSt(() {
                                  if (qty > 1) {
                                    item['quantity'] = qty - 1;
                                  } else {
                                    editedItems.removeAt(i);
                                  }
                                });
                              },
                            ),
                            Text('$qty $type', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () {
                                setSt(() {
                                  item['quantity'] = qty + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الجديد:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${formatter.format(calculateNewTotal())} DA',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final newTotal = calculateNewTotal();
        final updatedOrder = order.copyWith(
          items: editedItems,
          total: newTotal,
        );
        await DataService.updateFullOrder(updatedOrder);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم تحديث الطلب بنجاح'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ فشل التحديث: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _resendWhatsApp(Order order) async {
    final itemsText = order.items.map((i) {
      final price = (i['price'] as num?)?.toDouble() ?? 0;
      final qty = (i['quantity'] as num?)?.toInt() ?? 0;
      final type = i['typeLabel'] ?? 'كرتون';
      final flavor = (i['flavor'] as String?) ?? '';
      final flavorText =
      flavor.isNotEmpty ? ' ($flavor)' : '';
      return '• ${i['productName']}$flavorText x $qty $type = ${formatter.format(price * qty)} DA';
    }).join('\n');

    final message = 'Commande - Al Qanaa Grossiste\n\n'
        'Client: ${order.customerName}\n'
        'Tel: ${order.customerPhone}\n'
        'Date: ${_formatOrderDate(order)}\n\n'
        'Produits:\n'
        '$itemsText\n\n'
        'Total: ${formatter.format(order.total)} DA\n\n'
        'Merci pour votre commande!';

    String phone = order.customerPhone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('+', '');
    if (phone.startsWith('0')) {
      phone = '213${phone.substring(1)}';
    } else if (!phone.startsWith('213')) {
      phone = '213$phone';
    }

    final url = Uri.parse(
        'https://wa.me/+$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url,
          mode: LaunchMode.externalApplication);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return '✅ مؤكد';
      case 'rejected':
        return '❌ مرفوض';
      default:
        return '⏳ قيد المراجعة';
    }
  }

  String _formatOrderDate(Order order) {
    if (order.createdAt != null) {
      return DateFormat('dd/MM/yyyy - HH:mm')
          .format(order.createdAt!);
    }
    return order.date;
  }

  Widget _buildOrderItem(
      Map<String, dynamic> i, Color textColor) {
    final price = (i['price'] as num?)?.toDouble() ?? 0;
    final qty = (i['quantity'] as num?)?.toInt() ?? 0;
    final type = i['typeLabel'] ?? 'كرتون';
    final flavor = (i['flavor'] as String?) ?? '';
    final productName = i['productName']?.toString() ?? '';
    final total = price * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$productName x $qty $type',
                    style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w500)),
                if (flavor.isNotEmpty)
                  Text(flavor,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.purple,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('${formatter.format(total)} DA',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold)),
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

    if (_isDisposed) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop
          ? null
          : AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('سجل الطلبات',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              PrinterService.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: Colors.white,
            ),
            onPressed: _showPrinterStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Order>>(
          stream: DataService.getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark
                      ? Colors.green.shade400
                      : const Color(0xFF2E7D32),
                ),
              );
            }

            if (!snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(
                child: Text('لا توجد طلبات',
                    style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey,
                        fontSize: 16)),
              );
            }

            final orders = snapshot.data!;
            final filteredOrders = _filterOrders(orders);
            final totalAmount = filteredOrders.fold(
                0.0, (sum, o) => sum + o.total);

            if (isDesktop) {
              return _buildDesktopBody(
                  isDark, cardColor, textColor,
                  filteredOrders, totalAmount);
            }

            return _buildMobileBody(isDark, cardColor,
                textColor, filteredOrders, totalAmount);
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Desktop Body
  // ══════════════════════════════════
  Widget _buildDesktopBody(
      bool isDark,
      Color cardColor,
      Color textColor,
      List<Order> filteredOrders,
      double totalAmount,
      ) {
    return Row(
      children: [
        // ── العمود الأيسر: فلاتر + بحث + إحصائيات ──
        Container(
          width: 280,
          height: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // رأس الشريط الجانبي
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سجل الطلبات',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // إحصائيات
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                              Colors.white.withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${filteredOrders.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                      FontWeight.bold,
                                      fontSize: 20),
                                ),
                                const Text('طلب',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                              Colors.white.withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${formatter.format(totalAmount)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                      FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const Text('DA',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // حالة الطابعة
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showPrinterStatus,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PrinterService.isConnected
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: PrinterService.isConnected
                              ? const Color(0xFF2E7D32)
                              : Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PrinterService.isConnected
                              ? Icons.print_rounded
                              : Icons.print_outlined,
                          color: PrinterService.isConnected
                              ? const Color(0xFF2E7D32)
                              : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            PrinterService.isConnected
                                ? 'الطابعة متصلة'
                                : 'الطابعة غير متصلة',
                            style: TextStyle(
                              color: PrinterService.isConnected
                                  ? const Color(0xFF2E7D32)
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // البحث
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => _safeSetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A3E)
                        : const Color(0xFFF5F5F5),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF2E7D32), size: 20),
                    border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // الفلاتر
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _filterChipDesktop(
                        'الكل', 'all', isDark),
                    const SizedBox(height: 6),
                    _filterChipDesktop(
                        'اليوم', 'today', isDark),
                    const SizedBox(height: 6),
                    _filterChipDesktop(
                        'الأسبوع', 'week', isDark),
                    const SizedBox(height: 6),
                    _filterChipDesktop(
                        'الشهر', 'month', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── العمود الأيمن: قائمة الطلبات ──
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
              child: Text('لا توجد طلبات مطابقة',
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey,
                      fontSize: 16)))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              return _buildOrderCard(
                  order, isDark, cardColor, textColor);
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════
  //  Mobile Body
  // ══════════════════════════════════
  Widget _buildMobileBody(
      bool isDark,
      Color cardColor,
      Color textColor,
      List<Order> filteredOrders,
      double totalAmount,
      ) {
    return Column(
      children: [
        // إحصائيات
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${filteredOrders.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                  const Text('الطلبات',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Column(
                children: [
                  Text('${formatter.format(totalAmount)} DA',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Text('الاجمالي',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        // البحث
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: searchController,
            onChanged: (_) => _safeSetState(() {}),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'بحث باسم الزبون او الهاتف...',
              hintStyle: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey),
              filled: true,
              fillColor: cardColor,
              prefixIcon: Icon(Icons.search,
                  color: isDark
                      ? Colors.green.shade400
                      : const Color(0xFF2E7D32)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // الفلاتر
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _filterChip('الكل', 'all', isDark),
              const SizedBox(width: 8),
              _filterChip('اليوم', 'today', isDark),
              const SizedBox(width: 8),
              _filterChip('الاسبوع', 'week', isDark),
              const SizedBox(width: 8),
              _filterChip('الشهر', 'month', isDark),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // قائمة الطلبات
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
              child: Text('لا توجد طلبات مطابقة',
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey,
                      fontSize: 16)))
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              return _buildOrderCard(
                  order, isDark, cardColor, textColor);
            },
          ),
        ),
      ],
    );
  }

  void _showPrinterStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('حالة الطابعة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PrinterService.isConnected
                      ? Icons.check_circle
                      : Icons.error,
                  color: PrinterService.isConnected
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  PrinterService.isConnected
                      ? 'متصل'
                      : 'غير متصل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: PrinterService.isConnected
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            if (PrinterService.connectedDeviceName != null) ...[
              const SizedBox(height: 12),
              Text(
                  'الجهاز: ${PrinterService.connectedDeviceName}'),
            ],
            const SizedBox(height: 8),
            const Text(
              'للاتصال بالطابعة، اذهب إلى الإعدادات',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //  بطاقة الطلب
  // ══════════════════════════════════
  Widget _buildOrderCard(
      Order order,
      bool isDark,
      Color cardColor,
      Color textColor,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32),
          child: Text(
            order.customerName.isNotEmpty
                ? order.customerName[0].toUpperCase()
                : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(order.customerName,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatOrderDate(order),
                style: TextStyle(
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey,
                    fontSize: 11)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(order.status)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_statusText(order.status),
                  style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
          ],
        ),
        trailing: Text('${formatter.format(order.total)} DA',
            style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold)),
        children: [
          _buildOrderDetails(order, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
      Order order,
      bool isDark,
      Color textColor,
      ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text(order.customerPhone,
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey)),
            ],
          ),
          if (order.address != null &&
              order.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(order.address!,
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          Row(
            children: [
              const Icon(Icons.inventory_2,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text('المنتجات (${order.items.length} صنف)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ...order.items
              .map((i) => _buildOrderItem(i, textColor)),
          Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatter.format(order.total)} DA',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              _buildActionButtons(order),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Order order) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.print,
              color: PrinterService.isConnected
                  ? const Color(0xFF2E7D32)
                  : Colors.grey),
          onPressed: () => _printThermal(order),
          tooltip: 'طباعة حرارية',
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf,
              color: Colors.red),
          onPressed: () => _printOrderPDF(order),
          tooltip: 'طباعة PDF',
        ),
        IconButton(
          icon: Icon(Icons.location_on,
              color: order.latitude != null &&
                  order.longitude != null
                  ? Colors.red
                  : Colors.grey),
          onPressed: order.latitude != null &&
              order.longitude != null
              ? () => _openMap(
              order.latitude!, order.longitude!)
              : null,
          tooltip: 'موقع الزبون',
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              color: _statusColor(order.status)),
          tooltip: 'خيارات إضافية',
          onSelected: (value) {
            if (value == 'edit') {
              _showEditOrderDialog(order);
            } else {
              _changeOrderStatus(order, value);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit,
                      color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text('تعديل الطلب'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'confirmed',
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('تأكيد'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rejected',
              child: Row(
                children: [
                  Icon(Icons.cancel,
                      color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('رفض'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pending',
              child: Row(
                children: [
                  Icon(Icons.pending,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('قيد المراجعة'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.send,
              color: Color(0xFF25D366)),
          onPressed: () => _resendWhatsApp(order),
          tooltip: 'WhatsApp',
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteOrder(order),
          tooltip: 'حذف',
        ),
      ],
    );
  }

  // ── فلتر Desktop ──
  Widget _filterChipDesktop(
      String label, String value, bool isDark) {
    final isSelected = selectedFilter == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            _safeSetState(() => selectedFilter = value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark
                  ? Colors.grey.shade300
                  : Colors.grey.shade700),
              fontWeight: isSelected
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ── فلتر Mobile ──
  Widget _filterChip(
      String label, String value, bool isDark) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () =>
          _safeSetState(() => selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2E7D32)
              : (isDark
              ? const Color(0xFF1E1E2E)
              : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF2E7D32)),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }
}

// ══════════════════════════════════
//  مراقب دورة حياة التطبيق
// ══════════════════════════════════
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onPause;
  final VoidCallback onResume;

  _AppLifecycleObserver(
      {required this.onPause, required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onPause();
    } else if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}