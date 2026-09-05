import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart' as app_models;

class UserOrdersScreen extends StatefulWidget {
  final String userId;
  const UserOrdersScreen({super.key, required this.userId});

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen>
    with TickerProviderStateMixin {
  final formatter = NumberFormat('#,##0.00', 'fr_FR');

  late Stream<List<app_models.Order>> _ordersStream;
  StreamSubscription? _notificationSub;
  late AnimationController _listController;

  // ✅ Scroll + Keyboard
  final ScrollController _scrollController = ScrollController();
  final FocusNode        _keyboardFocus    = FocusNode();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _initStream();
    _listenNotifications();
    _listController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _listController.dispose();
    _scrollController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  // ✅ Keyboard Scroll Handler
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (!_scrollController.hasClients) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
      );
    }
  }

  void _initStream() {
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => app_models.Order.fromJson({...doc.data(), 'id': doc.id}))
        .toList());
  }

  void _listenNotifications() {
    _notificationSub = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'order_status' && mounted) {
        _showStatusBar(message.data['status'] ?? '');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'order_status' && mounted) {
        _showStatusBar(message.data['status'] ?? '');
      }
    });
  }

  void _showStatusBar(String status) {
    String msg; Color color; IconData icon;
    switch (status) {
      case 'confirmed': msg = 'تم تأكيد طلبك!'; color = Colors.green; icon = Icons.check_circle; break;
      case 'rejected':  msg = 'للأسف تم رفض طلبك'; color = Colors.red; icon = Icons.cancel; break;
      default:          msg = 'تم تحديث حالة طلبك'; color = Colors.orange; icon = Icons.info;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(msg)]),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color    _statusColor(String s) => s == 'confirmed' ? Colors.green : s == 'rejected' ? Colors.red : Colors.orange;
  String   _statusText(String s)  => s == 'confirmed' ? 'تم التأكيد' : s == 'rejected' ? 'مرفوض' : 'قيد المراجعة';
  IconData _statusIcon(String s)  => s == 'confirmed' ? Icons.check_circle : s == 'rejected' ? Icons.cancel : Icons.pending;

  Widget _buildItem(Map<String, dynamic> i, Color textColor, bool isDark) {
    final price  = (i['price'] as num?)?.toDouble() ?? 0;
    final qty    = (i['quantity'] as num?)?.toInt() ?? 0;
    final type   = i['typeLabel'] ?? 'كرتون';
    final flavor = (i['flavor'] as String?) ?? '';
    final name   = i['productName']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: type == 'كرتون' ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold,
              color: type == 'كرتون' ? const Color(0xFF2E7D32) : Colors.blue,
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name x $qty',
                  style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
              if (flavor.isNotEmpty)
                Text(flavor, style: const TextStyle(
                    fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600)),
            ]),
          ),
          Text('${formatter.format(price * qty)} DA',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard(app_models.Order order, Color cardColor, Color textColor, bool isDark, int index) {
    final statusColor = _statusColor(order.status);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 30 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ExpansionTile(
              leading: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(_statusIcon(order.status), color: statusColor, size: 26),
              ),
              title: Text(order.date,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(order.status), size: 11, color: statusColor),
                    const SizedBox(width: 4),
                    Text(_statusText(order.status),
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 3),
                Text('${order.items.length} صنف',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
              ]),
              trailing: Text('${formatter.format(order.total)} DA',
                  style: const TextStyle(
                      color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161626) : const Color(0xFFFAFAFA),
                    border: Border(top: BorderSide(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.inventory_2, size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Text('المنتجات',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    ...order.items.map((i) => _buildItem(i, textColor, isDark)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الكلي:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${formatter.format(order.total)} DA',
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Container(
        color: bgColor,
        child: Column(children: [
          // ✅ العنوان (بدون تغيير)
          Container(
            width: double.infinity,
            color: const Color(0xFF2E7D32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('طلباتي',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<app_models.Order>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading(isDark);
                }
                if (snapshot.hasError) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('حدث خطأ', style: TextStyle(color: textColor)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                        textAlign: TextAlign.center),
                  ]));
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (_, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(offset: Offset(0, 30 * (1 - value)), child: child),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.7, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (_, value, child) => Transform.scale(scale: value, child: child),
                          child: Icon(Icons.receipt_long_rounded, size: 80,
                              color: isDark ? Colors.grey.shade700 : Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Text('لا توجد طلبات بعد',
                            style: TextStyle(
                                fontSize: 18, color: isDark ? Colors.grey.shade500 : Colors.grey)),
                        const SizedBox(height: 8),
                        Text('ابدأ بتصفح المنتجات',
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500)),
                      ]),
                    ),
                  );
                }

                // ✅ Desktop: عرض أوسع مع Scrollbar
                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: isDesktop,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(isDesktop ? 20 : 10),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final card = _buildCard(orders[index], cardColor, textColor, isDark, index);
                      // ✅ Desktop: بطاقات أضيق في المنتصف
                      if (isDesktop) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: card,
                          ),
                        );
                      }
                      return card;
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 4,
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + (index * 100)),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => Opacity(
          opacity: value * 0.6,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 90,
          decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12))),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 120, height: 12,
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 10,
                        decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6))),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(width: 60, height: 14,
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6))),
            ),
          ]),
        ),
      ),
    );
  }
}