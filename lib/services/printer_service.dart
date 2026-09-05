import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PrinterService {
  static String? _connectedAddress;
  static String? _connectedName;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;
  static String? get connectedDeviceName => _connectedName;
  static String? get connectedDeviceAddress => _connectedAddress;

  // ══════════════════════════════════════════════════════
  //  ✅ 1. تنسيق المبالغ يدوياً
  // ══════════════════════════════════════════════════════
  static String _money(num value) {
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

  // ══════════════════════════════════════════════════════
  //  ✅ 2. تنظيف أي نص → ASCII آمن
  // ══════════════════════════════════════════════════════
  static const Map<int, String> _map = {
    // ── مسافات خفية خطيرة ──
    0x00A0: ' ', 0x202F: ' ', 0x2007: ' ', 0x2009: ' ',
    0x2002: ' ', 0x2003: ' ', 0x2004: ' ', 0x2005: ' ',
    0x2006: ' ', 0x2008: ' ', 0x205F: ' ', 0x3000: ' ',
    // ── محارف اتجاه غير مرئية (حذف) ──
    0x200B: '', 0x200C: '', 0x200D: '', 0x200E: '', 0x200F: '',
    0x061C: '', 0xFEFF: '', 0x202A: '', 0x202B: '', 0x202C: '',
    // ── أرقام عربية ──
    0x0660: '0', 0x0661: '1', 0x0662: '2', 0x0663: '3', 0x0664: '4',
    0x0665: '5', 0x0666: '6', 0x0667: '7', 0x0668: '8', 0x0669: '9',
    0x06F0: '0', 0x06F1: '1', 0x06F2: '2', 0x06F3: '3', 0x06F4: '4',
    0x06F5: '5', 0x06F6: '6', 0x06F7: '7', 0x06F8: '8', 0x06F9: '9',
    // ── حروف عربية ──
    0x0627: 'a', 0x0623: 'a', 0x0625: 'i', 0x0622: 'a', 0x0671: 'a',
    0x0628: 'b', 0x062A: 't', 0x062B: 'th', 0x062C: 'j', 0x062D: 'h',
    0x062E: 'kh', 0x062F: 'd', 0x0630: 'dh', 0x0631: 'r', 0x0632: 'z',
    0x0633: 's', 0x0634: 'ch', 0x0635: 's', 0x0636: 'd', 0x0637: 't',
    0x0638: 'dh', 0x0639: 'a', 0x063A: 'gh', 0x0641: 'f', 0x0642: 'q',
    0x0643: 'k', 0x0644: 'l', 0x0645: 'm', 0x0646: 'n', 0x0647: 'h',
    0x0629: 'a', 0x0648: 'w', 0x0624: 'o', 0x064A: 'y', 0x0649: 'a',
    0x0626: 'i', 0x0621: '',
    // ── تشكيل (حذف) ──
    0x064B: '', 0x064C: '', 0x064D: '', 0x064E: '', 0x064F: '',
    0x0650: '', 0x0651: '', 0x0652: '', 0x0640: '',
    // ── فرنسية ──
    0x00E9: 'e', 0x00E8: 'e', 0x00EA: 'e', 0x00EB: 'e',
    0x00C9: 'E', 0x00C8: 'E', 0x00CA: 'E', 0x00CB: 'E',
    0x00E0: 'a', 0x00E2: 'a', 0x00E4: 'a', 0x00C0: 'A', 0x00C2: 'A',
    0x00F9: 'u', 0x00FB: 'u', 0x00FC: 'u', 0x00D9: 'U',
    0x00EE: 'i', 0x00EF: 'i', 0x00CE: 'I', 0x00CF: 'I',
    0x00F4: 'o', 0x00F6: 'o', 0x00D4: 'O', 0x00D6: 'O',
    0x00E7: 'c', 0x00C7: 'C', 0x00F1: 'n', 0x00D1: 'N',
    // ── رموز ──
    0x2019: "'", 0x2018: "'", 0x00B4: "'", 0x2032: "'",
    0x201C: '"', 0x201D: '"', 0x00AB: '"', 0x00BB: '"',
    0x2013: '-', 0x2014: '-', 0x2212: '-',
    0x2026: '...', 0x00B0: 'deg', 0x20AC: 'EUR', 0x00A3: 'GBP',
  };

  static String _clean(Object? input) {
    final s = input?.toString() ?? '';
    if (s.isEmpty) return '';

    final buf = StringBuffer();
    for (final r in s.runes) {
      if (_map.containsKey(r)) {
        buf.write(_map[r]);
      } else if (r >= 32 && r <= 126) {
        buf.write(String.fromCharCode(r));
      } else {
        buf.write(' ');
      }
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ══════════════════════════════════════════════════════
  //  ✅ 3. أغلفة آمنة
  // ══════════════════════════════════════════════════════
  static List<int> _t(Generator g, Object? text, {PosStyles? styles}) {
    return g.text(_clean(text), styles: styles ?? const PosStyles());
  }

  static PosColumn _c(Object? text, int width, PosStyles styles) {
    return PosColumn(text: _clean(text), width: width, styles: styles);
  }

  // ══════════════════════════════════════════════════════
  //  البلوتوث
  // ══════════════════════════════════════════════════════
  static String getDeviceName(dynamic d) {
    try {
      if (d is BluetoothInfo && d.name.trim().isNotEmpty) return d.name;
    } catch (_) {}
    return 'جهاز غير معروف';
  }

  static String getDeviceAddress(dynamic d) {
    try {
      if (d is BluetoothInfo && d.macAdress.trim().isNotEmpty) {
        return d.macAdress;
      }
    } catch (_) {}
    return '';
  }

  static Future<bool> requestPermissions() async {
    try {
      if (!Platform.isAndroid) return true;
      final scan = await Permission.bluetoothScan.request();
      final conn = await Permission.bluetoothConnect.request();
      if (scan.isGranted && conn.isGranted) return true;
      if (scan.isPermanentlyDenied || conn.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    } catch (e) {
      debugPrint('❌ أذونات: $e');
      return false;
    }
  }

  static Future<List<BluetoothInfo>> getAvailableDevices() async {
    try {
      if (!await requestPermissions()) return [];
      if (!await PrintBluetoothThermal.bluetoothEnabled) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('❌ الأجهزة: $e');
      return [];
    }
  }

  static void _reset() {
    _isConnected = false;
    _connectedAddress = null;
    _connectedName = null;
  }

  static Future<bool> connect(dynamic device) async {
    try {
      final addr = getDeviceAddress(device);
      if (addr.isEmpty) return false;

      try {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}

      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: addr);
      if (ok) {
        _connectedAddress = addr;
        _connectedName = getDeviceName(device);
        _isConnected = true;
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('✅ متصل بـ $_connectedName');
      } else {
        _reset();
      }
      return ok;
    } catch (e) {
      debugPrint('❌ الاتصال: $e');
      _reset();
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {} finally {
      _reset();
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final c = await PrintBluetoothThermal.connectionStatus;
      _isConnected = c;
      if (!c) _reset();
      return c;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  الإرسال
  // ══════════════════════════════════════════════════════
  static Future<bool> _send(List<int> bytes) async {
    debugPrint('📤 إرسال ${bytes.length} byte...');
    try {
      if (await PrintBluetoothThermal.writeBytes(bytes)) {
        debugPrint('✅ نجح الإرسال دفعة واحدة');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ فشل الإرسال الكامل: $e');
    }

    // خطة بديلة: تقسيم
    try {
      const size = 256;
      for (int i = 0; i < bytes.length; i += size) {
        final end = (i + size > bytes.length) ? bytes.length : i + size;
        if (!await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end))) {
          debugPrint('❌ فشل عند $i');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 60));
      }
      debugPrint('✅ نجح بالتقسيم');
      return true;
    } catch (e) {
      debugPrint('❌ فشل التقسيم: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  بناء الإيصال
  // ══════════════════════════════════════════════════════
  static const _line1 = '================================';
  static const _line2 = '--------------------------------';
  static const _dotLine = '  . . . . . . . . . . . . . . .';

  // ── الترويسة ──
  static List<int> _buildHeader(Generator g) {
    List<int> b = [];
    b += g.reset();
    b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
    b += _t(
      g,
      'AL QANAA GROSSISTE',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    b += _t(
      g,
      'Bienvenue chez nous',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
    b += g.feed(1);
    return b;
  }

  // ── معلومات الزبون ──
  static List<int> _buildCustomerInfo({
    required Generator g,
    required Order order,
    required String customerName,
    required String customerPhone,
    required String date,
  }) {
    List<int> b = [];
    final id = _clean(order.id);
    final shortId = id.length > 6 ? id.substring(id.length - 6) : id;
    final name = _clean(customerName);
    final phone = _clean(customerPhone);

    b += _t(g, 'Date   : $date');
    b += _t(
      g,
      'Client : ${name.isEmpty ? "-" : name}',
      styles: const PosStyles(bold: true),
    );
    b += _t(g, 'Tel    : ${phone.isEmpty ? "-" : phone}');
    b += _t(g, 'Order  : #$shortId');
    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    return b;
  }

  // ── رأس الجدول ──
  static List<int> _buildTableHeader(Generator g) {
    List<int> b = [];
    b += _t(
      g,
      ' # | Produit',
      styles: const PosStyles(bold: true, underline: true),
    );
    b += _t(
      g,
      '   Qte       Montant',
      styles: const PosStyles(bold: true, underline: true),
    );
    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    return b;
  }

  // ── ✅ المنتجات — كل منتج في سطرين ──
  static List<int> _buildItems(Generator g, List items) {
    List<int> b = [];
    for (int i = 0; i < items.length; i++) {
      try {
        final it = items[i];
        String name = _clean(it['productName']);
        if (name.isEmpty) name = 'Produit ${i + 1}';

        final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
        final price = (it['price'] as num?)?.toDouble() ?? 0;
        final total = qty * price;
        final type = it['isCarton'] == true ? 'Crt' : 'Unt';
        final flavor = _clean(it['flavor']);

        debugPrint('   ${i + 1}) $name x${qty.toInt()} = ${_money(total)}');

        // ✅ السطر الأول: رقم + اسم المنتج كاملاً + النوع
        b += _t(
          g,
          '${i + 1}. $name ($type)',
          styles: const PosStyles(bold: true),
        );

        // ✅ السطر الثاني: الكمية والمبلغ الإجمالي
        b += g.row([
          _c('   Qte: ${qty.toStringAsFixed(0)}', 6,
              const PosStyles(align: PosAlign.left)),
          _c('${_money(total)} DA', 6,
              const PosStyles(align: PosAlign.right, bold: true)),
        ]);

        // ✅ الطعم إن وُجد
        if (flavor.isNotEmpty) {
          b += _t(g, '   Gout: $flavor');
        }

        // ✅ فاصل خفيف بين كل منتج
        b += _t(g, _dotLine);
      } catch (e) {
        debugPrint('⚠️ تخطي المنتج ${i + 1}: $e');
        b += _t(g, '  [Erreur produit ${i + 1}]');
      }
    }
    return b;
  }

  // ── حساب الإجمالي ──
  static double _calcTotal(Order order) {
    if (order.total > 0) return order.total;
    double t = 0;
    for (final it in order.items) {
      final q = (it['quantity'] as num?)?.toDouble() ?? 0;
      final p = (it['price'] as num?)?.toDouble() ?? 0;
      t += q * p;
    }
    return t;
  }

  // ── الإجمالي ──
  static List<int> _buildTotal(Generator g, double total) {
    List<int> b = [];
    b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
    b += _t(
      g,
      'TOTAL A PAYER',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    b += _t(
      g,
      '${_money(total)} DA',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
    return b;
  }

  // ── معلومات الدين (تظهر فقط إذا الطلبية مربوطة بزبون من الدليل) ──
  static List<int> _buildDebtInfo(
      Generator g, double orderTotal, double? amountPaid, double? newBalance) {
    if (newBalance == null) return [];
    List<int> b = [];
    final paid = amountPaid ?? orderTotal;
    final remaining = orderTotal - paid;

    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    b += _t(g, 'Paye ce jour : ${_money(paid)} DA');
    if (remaining > 0) {
      b += _t(
        g,
        'Reste (facture) : ${_money(remaining)} DA',
        styles: const PosStyles(bold: true),
      );
    }
    b += _t(
      g,
      'Solde dette client : ${_money(newBalance)} DA',
      styles: const PosStyles(bold: true),
    );
    return b;
  }

  // ── التذييل ──
  static List<int> _buildFooter(Generator g) {
    List<int> b = [];
    b += g.feed(1);
    b += _t(
      g,
      'Merci pour votre confiance !',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    b += _t(
      g,
      'Tel: 0666629473',
      styles: const PosStyles(align: PosAlign.center),
    );
    b += _t(
      g,
      'AL QANAA GROSSISTE',
      styles: const PosStyles(align: PosAlign.center),
    );
    b += g.feed(3);
    b += g.cut();
    return b;
  }

  // ══════════════════════════════════════════════════════
  //  ✅ الطباعة الرئيسية
  // ══════════════════════════════════════════════════════
  static Future<bool> printReceipt({
    required Order order,
    required String customerName,
    required String customerPhone,
    double? amountPaid,
    double? customerDebtBalance,
  }) async {
    try {
      if (!await checkConnection()) {
        debugPrint('⚠️ لا يوجد اتصال');
        return false;
      }

      final profile = await CapabilityProfile.load();
      final g = Generator(PaperSize.mm58, profile);

      final date =
      DateFormat('dd/MM/yyyy - HH:mm', 'en_US').format(DateTime.now());

      debugPrint('🖨️ بدء الطباعة — ${order.items.length} منتج');

      final orderTotal = _calcTotal(order);

      List<int> bytes = [];
      bytes += _buildHeader(g);
      bytes += _buildCustomerInfo(
        g: g,
        order: order,
        customerName: customerName,
        customerPhone: customerPhone,
        date: date,
      );
      bytes += _buildTableHeader(g);
      bytes += _buildItems(g, order.items);
      bytes += _buildTotal(g, orderTotal);
      bytes += _buildDebtInfo(g, orderTotal, amountPaid, customerDebtBalance);
      bytes += _buildFooter(g);

      debugPrint('📦 حجم الإيصال: ${bytes.length} byte');
      final ok = await _send(bytes);
      debugPrint(ok ? '✅ تمت الطباعة' : '❌ فشلت الطباعة');
      return ok;
    } catch (e, st) {
      debugPrint('❌ خطأ في الطباعة: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  اختبار الطابعة
  // ══════════════════════════════════════════════════════
  static Future<bool> printTest() async {
    try {
      if (!await checkConnection()) return false;
      final profile = await CapabilityProfile.load();
      final g = Generator(PaperSize.mm58, profile);

      List<int> b = [];
      b += g.reset();
      b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
      b += _t(
        g,
        'AL QANAA TEST',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      b += _t(
        g,
        'Printer OK !',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      b += _t(
        g,
        '12 600 DA / 1 250 000 DA',
        styles: const PosStyles(align: PosAlign.center),
      );
      b += _t(
        g,
        DateFormat('dd/MM/yyyy - HH:mm', 'en_US').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );
      b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
      b += g.feed(3);
      b += g.cut();

      return await _send(b);
    } catch (e) {
      debugPrint('❌ خطأ في الاختبار: $e');
      return false;
    }
  }
}