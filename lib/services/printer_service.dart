import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart'; // للطباعة على الويندوز والحاسوب
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'receipt_renderer.dart';

class PrinterService {
  static String? _connectedAddress;
  static String? _connectedName;
  static bool _isConnected = false;

  // ✅ هل توجد طابعة محفوظة/مستخدمة سابقاً (لإعادة الاتصال بها تلقائياً عند الطباعة)
  static bool _hasSavedPrinter = false;

  // ✅ سبب آخر فشل في الطباعة/الاتصال (لعرضه للمستخدم)
  static String? lastError;

  // ⚠️ طباعة وصل البلوتوث كصورة (لدعم العربية بنفس شكل المعاينة).
  // معطّلة افتراضياً: بعض الطابعات تطبع رموزاً مشوّشة مع الصور. فعّلها فقط بعد تجربة ناجحة.
  static bool useImageReceipt = false;

  static bool get isConnected =>
      _isConnected ||
          (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux));

  /// ✅ يمكن محاولة الطباعة: إما متصلة الآن، أو توجد طابعة محفوظة سنعيد الاتصال بها تلقائياً
  static bool get canPrint => isConnected || _hasSavedPrinter;

  static String? get connectedDeviceName =>
      _connectedName ??
          (!kIsWeb && Platform.isWindows ? 'Imprimante système' : null);

  static String? get connectedDeviceAddress => _connectedAddress;

  // التحقق هل نحن على الحاسوب
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // ══════════════════════════════════════════════════════
  //  ✅ Auto-connect
  // ══════════════════════════════════════════════════════
  static Future<void> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAddr = prefs.getString('last_printer_address');
      final lastName = prefs.getString('last_printer_name');
      if (lastAddr != null && lastAddr.isNotEmpty) {
        _hasSavedPrinter = true;
        debugPrint('⏳ Attempting auto-connect to $lastName...');
        final ok = await PrintBluetoothThermal.connect(macPrinterAddress: lastAddr);
        if (ok) {
          _connectedAddress = lastAddr;
          _connectedName = lastName ?? 'Saved printer';
          _isConnected = true;
          debugPrint('✅ Auto-connect successful');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Auto-connect failed: $e');
    }
  }

  static Future<void> _saveLastPrinter(String address, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_printer_address', address);
      await prefs.setString('last_printer_name', name);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  //  ✅ 1. Manual amount formatting
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
  //  ✅ 2. Sanitize any text → safe ASCII
  // ══════════════════════════════════════════════════════
  static const Map<int, String> _map = {
    // ── Dangerous invisible spaces ──
    0x00A0: ' ', 0x202F: ' ', 0x2007: ' ', 0x2009: ' ',
    0x2002: ' ', 0x2003: ' ', 0x2004: ' ', 0x2005: ' ',
    0x2006: ' ', 0x2008: ' ', 0x205F: ' ', 0x3000: ' ',
    // ── Invisible direction characters (remove) ──
    0x200B: '', 0x200C: '', 0x200D: '', 0x200E: '', 0x200F: '',
    0x061C: '', 0xFEFF: '', 0x202A: '', 0x202B: '', 0x202C: '',
    // ── Arabic-Indic digits ──
    0x0660: '0', 0x0661: '1', 0x0662: '2', 0x0663: '3', 0x0664: '4',
    0x0665: '5', 0x0666: '6', 0x0667: '7', 0x0668: '8', 0x0669: '9',
    0x06F0: '0', 0x06F1: '1', 0x06F2: '2', 0x06F3: '3', 0x06F4: '4',
    0x06F5: '5', 0x06F6: '6', 0x06F7: '7', 0x06F8: '8', 0x06F9: '9',
    // ── Arabic letters (Transliteration) ──
    0x0627: 'a', 0x0623: 'a', 0x0625: 'i', 0x0622: 'a', 0x0671: 'a',
    0x0628: 'b', 0x062A: 't', 0x062B: 'th', 0x062C: 'j', 0x062D: 'h',
    0x062E: 'kh', 0x062F: 'd', 0x0630: 'dh', 0x0631: 'r', 0x0632: 'z',
    0x0633: 's', 0x0634: 'ch', 0x0635: 's', 0x0636: 'd', 0x0637: 't',
    0x0638: 'dh', 0x0639: 'a', 0x063A: 'gh', 0x0641: 'f', 0x0642: 'q',
    0x0643: 'k', 0x0644: 'l', 0x0645: 'm', 0x0646: 'n', 0x0647: 'h',
    0x0629: 'a', 0x0648: 'w', 0x0624: 'o', 0x064A: 'y', 0x0649: 'a',
    0x0626: 'i', 0x0621: '',
    // ── Diacritics (remove) ──
    0x064B: '', 0x064C: '', 0x064D: '', 0x064E: '', 0x064F: '',
    0x0650: '', 0x0651: '', 0x0652: '', 0x0640: '',
    // ── French ──
    0x00E9: 'e', 0x00E8: 'e', 0x00EA: 'e', 0x00EB: 'e',
    0x00C9: 'E', 0x00C8: 'E', 0x00CA: 'E', 0x00CB: 'E',
    0x00E0: 'a', 0x00E2: 'a', 0x00E4: 'a', 0x00C0: 'A', 0x00C2: 'A',
    0x00F9: 'u', 0x00FB: 'u', 0x00FC: 'u', 0x00D9: 'U',
    0x00EE: 'i', 0x00EF: 'i', 0x00CE: 'I', 0x00CF: 'I',
    0x00F4: 'o', 0x00F6: 'o', 0x00D4: 'O', 0x00D6: 'O',
    0x00E7: 'c', 0x00C7: 'C', 0x00F1: 'n', 0x00D1: 'N',
    // ── Symbols ──
    0x2019: "'", 0x2018: "'", 0x00B4: "'", 0x2032: "'",
    0x201C: '"', 0x201D: '"', 0x00AB: '"', 0x00BB: '"',
    0x2013: '-', 0x2014: '-', 0x2212: '-',
    0x2026: '...', 0x00B0: 'deg', 0x20AC: 'EUR', 0x00A3: 'GBP',
  };

  /// ✅ تحويل الأحرف إلى ASCII آمن **مع الحفاظ على المسافات** (لتنسيق أسطر الوصل)
  static String _ascii(Object? input) {
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
    return buf.toString();
  }

  /// تنظيف **بيانات** (اسم زبون/منتج/ذوق...): ASCII + ضغط المسافات المتتالية + قص الأطراف
  static String _clean(Object? input) {
    return _ascii(input).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ══════════════════════════════════════════════════════
  //  ✅ 3. Safe wrappers
  //  (لا نضغط المسافات هنا حتى لا يضيع تنسيق الأسطر؛ البيانات تُنظَّف بـ _clean قبل إدخالها)
  // ══════════════════════════════════════════════════════
  static List<int> _t(Generator g, Object? text, {PosStyles? styles}) {
    return g.text(_ascii(text), styles: styles ?? const PosStyles());
  }

  static PosColumn _c(Object? text, int width, PosStyles styles) {
    return PosColumn(text: _ascii(text), width: width, styles: styles);
  }

  // ══════════════════════════════════════════════════════
  //  Bluetooth
  // ══════════════════════════════════════════════════════
  static String getDeviceName(dynamic d) {
    try {
      if (d is BluetoothInfo && d.name.trim().isNotEmpty) return d.name;
    } catch (_) {}
    return 'Unknown device';
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
    return true;
  }

  static Future<List<BluetoothInfo>> getAvailableDevices() async {
    try {
      if (!await requestPermissions()) return [];
      if (!await PrintBluetoothThermal.bluetoothEnabled) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('❌ Devices: $e');
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
        _hasSavedPrinter = true;
        await _saveLastPrinter(_connectedAddress!, _connectedName!);
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('✅ Connected to $_connectedName');
      } else {
        _reset();
      }
      return ok;
    } catch (e) {
      debugPrint('❌ Connection: $e');
      _reset();
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {} finally {
      _reset();
      _hasSavedPrinter = false; // قطع يدوي: لا نعيد الاتصال تلقائياً حتى يختار المستخدم طابعة
    }
  }

  /// ✅ يفحص حالة الاتصال فقط. لا يمسح العنوان المحفوظ حتى نستطيع إعادة الاتصال به.
  static Future<bool> checkConnection() async {
    try {
      final c = await PrintBluetoothThermal.connectionStatus;
      _isConnected = c;
      return c;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  ✅ إعادة الاتصال التلقائي (بعد خمول الطابعة أو انقطاع الاتصال)
  // ══════════════════════════════════════════════════════
  static Future<String?> _savedAddress() async {
    if (_connectedAddress != null && _connectedAddress!.isNotEmpty) {
      return _connectedAddress;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = prefs.getString('last_printer_address');
      if (a != null && a.isNotEmpty) return a;
    } catch (_) {}
    return null;
  }

  static Future<bool> _reconnect() async {
    final addr = await _savedAddress();
    if (addr == null) {
      lastError = 'لم يتم اختيار طابعة بعد. اربط الطابعة من إعدادات الطابعة.';
      return false;
    }

    try {
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        lastError = 'البلوتوث مغلق في الهاتف.';
        return false;
      }
    } catch (_) {}

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        debugPrint('🔄 Reconnect attempt $attempt → $addr');
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 400));
        final ok = await PrintBluetoothThermal.connect(macPrinterAddress: addr);
        if (ok) {
          _connectedAddress = addr;
          _connectedName ??= await _savedName();
          _isConnected = true;
          _hasSavedPrinter = true;
          await Future.delayed(const Duration(milliseconds: 500));
          debugPrint('✅ Reconnected');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Reconnect error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    _isConnected = false;
    lastError = 'تعذر الاتصال بالطابعة. تأكد أنها مشغّلة وقريبة من الهاتف.';
    return false;
  }

  static Future<String?> _savedName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_printer_name');
    } catch (_) {
      return null;
    }
  }

  /// ✅ يتأكد من الاتصال، وإن كان مقطوعاً يحاول إعادة الاتصال بآخر طابعة تلقائياً.
  static Future<bool> ensureConnected() async {
    if (await checkConnection()) return true;
    return _reconnect();
  }

  // ══════════════════════════════════════════════════════
  //  Sending
  // ══════════════════════════════════════════════════════
  static Future<bool> _send(List<int> bytes) async {
    debugPrint('📤 Sending ${bytes.length} bytes...');
    try {
      if (await PrintBluetoothThermal.writeBytes(bytes)) {
        debugPrint('✅ Sent successfully in one shot');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Full send failed: $e');
    }

    // Fallback: chunked send
    try {
      const size = 256;
      for (int i = 0; i < bytes.length; i += size) {
        final end = (i + size > bytes.length) ? bytes.length : i + size;
        if (!await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end))) {
          debugPrint('❌ Failed at $i');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 60));
      }
      debugPrint('✅ Chunked send succeeded');
      return true;
    } catch (e) {
      debugPrint('❌ Chunked send failed: $e');
      return false;
    }
  }

  /// إرسال مجزّأ (للصور الكبيرة): دفعات صغيرة مع تأخير بسيط حتى لا تفيض ذاكرة الطابعة
  static Future<bool> _sendChunked(List<int> bytes,
      {int size = 1024, int delayMs = 90}) async {
    debugPrint('📤 Sending ${bytes.length} bytes in chunks...');
    try {
      for (int i = 0; i < bytes.length; i += size) {
        final end = (i + size > bytes.length) ? bytes.length : i + size;
        if (!await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end))) {
          debugPrint('❌ Chunk failed at $i');
          return false;
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      return true;
    } catch (e) {
      debugPrint('❌ Chunked send failed: $e');
      return false;
    }
  }

  /// ✅ إرسال مع إعادة محاولة: إذا فشل الإرسال (اتصال ميّت بعد خمول) نعيد الاتصال ونرسل مرة ثانية
  static Future<bool> _sendWithRetry(List<int> bytes,
      {bool chunked = false}) async {
    Future<bool> doSend() => chunked ? _sendChunked(bytes) : _send(bytes);
    var ok = await doSend();
    if (!ok) {
      debugPrint('⚠️ Send failed → reconnect + resend');
      if (await _reconnect()) {
        ok = await doSend();
      }
    }
    if (!ok) {
      lastError ??= 'تعذر إرسال البيانات للطابعة.';
    }
    return ok;
  }

  // ══════════════════════════════════════════════════════
  //  Building the receipt (Bluetooth ESC/POS)
  // ══════════════════════════════════════════════════════
  static const _line1 = '================================';
  static const _line2 = '--------------------------------';
  static const _dotLine = '  . . . . . . . . . . . . . . .';
  static const _bigger = PosStyles(height: PosTextSize.size2);

  // ── Header ──
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
      'Vente de produits alimentaires',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    b += _t(g, _line1, styles: const PosStyles(align: PosAlign.center));
    b += g.feed(1);
    return b;
  }

  // ── Customer info ──
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
    b += _t(g, 'Date   : $date', styles: const PosStyles(bold: true));
    b += _t(
      g,
      'Client : ${name.isEmpty ? "-" : name}',
      styles: const PosStyles(bold: true),
    );
    if (phone.isNotEmpty) {
      b += _t(g, 'Tel    : $phone', styles: const PosStyles(bold: true));
    }
    b += _t(g, 'Order  : #$shortId', styles: const PosStyles(bold: true));
    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    return b;
  }

  // ── Table header ──
  static List<int> _buildTableHeader(Generator g) {
    List<int> b = [];
    b += _t(
      g,
      ' # | Produit',
      styles: const PosStyles(
          bold: true, underline: true, height: PosTextSize.size2),
    );
    b += _t(
      g,
      '   Qte       Montant',
      styles: const PosStyles(
          bold: true, underline: true, height: PosTextSize.size2),
    );
    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    return b;
  }

  // ── Products — grouped by name & carton type ──
  static List<int> _buildItems(Generator g, List items) {
    List<int> b = [];
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final it in items) {
      final rawName = it['productName']?.toString() ?? 'Unknown product';
      final isCarton = it['isCarton'] == true;
      final key = '$rawName-$isCarton';
      final price = (it['price'] as num? ?? 0).toDouble();
      final qty = (it['quantity'] as num? ?? 0).toDouble();
      final flavor = _clean(it['flavor']);

      if (grouped.containsKey(key)) {
        grouped[key]!['quantity'] = (grouped[key]!['quantity'] as double) + qty;
        grouped[key]!['total'] = (grouped[key]!['total'] as double) + (qty * price);
        if (flavor.isNotEmpty) {
          final flavors = grouped[key]!['flavors'] as List<String>;
          flavors.add('$flavor (${qty.toStringAsFixed(0)})');
        }
      } else {
        grouped[key] = {
          'productName': _clean(rawName),
          'quantity': qty,
          'total': qty * price,
          'isCarton': isCarton,
          'flavors': flavor.isNotEmpty
              ? ['$flavor (${qty.toStringAsFixed(0)})']
              : <String>[],
        };
      }
    }

    int idx = 1;
    grouped.forEach((key, data) {
      try {
        final name = data['productName'] as String;
        final qty = (data['quantity'] as num).toDouble();
        final total = (data['total'] as num).toDouble();
        final isCarton = data['isCarton'] == true;
        final type = isCarton ? 'Crt' : 'Unt';
        final flavorsList = data['flavors'] as List<String>;

        b += _t(
          g,
          '$idx. $name ($type)',
          styles: const PosStyles(
              bold: true, align: PosAlign.left, height: PosTextSize.size2),
        );
        b += g.row([
          _c('   Qte: ${qty.toStringAsFixed(0)}', 6,
              const PosStyles(align: PosAlign.left, height: PosTextSize.size2)),
          _c('${_money(total)} DA', 6,
              const PosStyles(
                  align: PosAlign.right, bold: true, height: PosTextSize.size2)),
        ]);
        if (flavorsList.isNotEmpty) {
          b += _t(
            g,
            '   Aromes: ${flavorsList.join(", ")}',
            styles: const PosStyles(
                fontType: PosFontType.fontB, height: PosTextSize.size2),
          );
        }
        b += _t(g, _dotLine);
        idx++;
      } catch (e) {
        debugPrint('⚠️ Error printing grouped product: $e');
      }
    });
    return b;
  }

  // ══════════════════════════════════════════════════════
  //  ✅ الوصل النصي بنفس تصميم نافذة المعاينة
  //  (نفس الترتيب والعناوين: ترويسة ← معلومات ← أصناف ← إجماليات ← تذييل)
  // ══════════════════════════════════════════════════════
  static const _dash = '--------------------------------';

  /// سطر بعمودين: نص يسار + مبلغ يمين
  static List<int> _lr(Generator g, String left, String right,
      {bool bold = false, bool big = false}) {
    final h = big ? PosTextSize.size2 : PosTextSize.size1;
    return g.row([
      PosColumn(
        text: _ascii(left),
        width: 7,
        styles: PosStyles(bold: bold, height: h, align: PosAlign.left),
      ),
      PosColumn(
        text: _ascii(right),
        width: 5,
        styles: PosStyles(bold: bold, height: h, align: PosAlign.right),
      ),
    ]);
  }

  static List<int> _buildPreviewStyleReceipt({
    required Generator g,
    required Order order,
    required String customerName,
    required String customerPhone,
    required double total,
    required double paid,
    required double prevDebt,
  }) {
    List<int> b = [];
    final date =
    DateFormat('dd/MM/yyyy - HH:mm', 'en_US').format(DateTime.now());
    final id = _clean(order.id);
    final shortId = id.length > 6 ? id.substring(id.length - 6) : id;
    final name = _clean(customerName);
    final phone = _clean(customerPhone);
    final remaining = total - paid;
    const centerBold = PosStyles(align: PosAlign.center, bold: true);

    b += g.reset();

    // ── الترويسة ──
    b += _t(
      g,
      'AL QANAA GROSSISTE',
      styles: const PosStyles(
          align: PosAlign.center, bold: true, height: PosTextSize.size2),
    );
    b += _t(g, 'Vente de produits alimentaires', styles: centerBold);
    b += _t(g, _dash);

    // ── معلومات الوصل والزبون ──
    b += _t(g, 'Date   : $date');
    b += _t(g, 'Order  : #$shortId');
    b += _t(g, 'Client : ${name.isEmpty ? "-" : name}',
        styles: const PosStyles(bold: true));
    if (phone.isNotEmpty) b += _t(g, 'Tel    : $phone');
    b += _t(g, _dash);

    // ── الأصناف (مجمّعة حسب الاسم + النوع) ──
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final it in order.items) {
      final rawName = it['productName']?.toString() ?? 'Produit';
      final isCarton = it['isCarton'] == true;
      final key = '$rawName-$isCarton';
      final price = (it['price'] as num? ?? 0).toDouble();
      final qty = (it['quantity'] as num? ?? 0).toDouble();
      final flavor = _clean(it['flavor']);

      if (grouped.containsKey(key)) {
        grouped[key]!['quantity'] = (grouped[key]!['quantity'] as double) + qty;
        grouped[key]!['total'] =
            (grouped[key]!['total'] as double) + (qty * price);
        if (flavor.isNotEmpty) {
          (grouped[key]!['flavors'] as List<String>)
              .add('$flavor (${qty.toStringAsFixed(0)})');
        }
      } else {
        grouped[key] = {
          'productName': _clean(rawName),
          'quantity': qty,
          'total': qty * price,
          'isCarton': isCarton,
          'flavors': flavor.isNotEmpty
              ? <String>['$flavor (${qty.toStringAsFixed(0)})']
              : <String>[],
        };
      }
    }

    int idx = 1;
    for (final data in grouped.values) {
      final nm = data['productName'] as String;
      final qty = data['quantity'] as double;
      final totalItem = data['total'] as double;
      final type = data['isCarton'] == true ? 'Crt' : 'Unt';
      final flavorsList = data['flavors'] as List<String>;

      b += _t(g, '$idx. $nm ($type)', styles: const PosStyles(bold: true));
      b += g.row([
        PosColumn(
          text: _ascii('   Qte: ${qty.toStringAsFixed(0)}'),
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _ascii('${_money(totalItem)} DA'),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      if (flavorsList.isNotEmpty) {
        b += _t(
          g,
          '   Aromes: ${flavorsList.join(", ")}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
      idx++;
    }
    b += _t(g, _dash);

    // ── الحسابات ──
    b += _lr(g, 'TOTAL A PAYER :', '${_money(total)} DA',
        bold: true, big: true);
    b += _lr(g, 'Montant Verse :', '${_money(paid)} DA');
    if (remaining > 0) {
      b += _lr(g, 'Reste Facture :', '${_money(remaining)} DA', bold: true);
    }
    if (prevDebt > 0) {
      b += _t(g, _dash);
      b += _lr(g, 'Ancien Solde :', '${_money(prevDebt)} DA');
      b += _lr(g, 'NOUVEAU SOLDE :',
          '${_money(prevDebt + (remaining > 0 ? remaining : 0))} DA',
          bold: true);
    }
    b += _t(g, _dash);

    // ── التذييل ──
    b += _t(g, 'Merci pour votre confiance !', styles: centerBold);
    b += _t(g, 'Tel: 0666629473',
        styles: const PosStyles(align: PosAlign.center));
    b += g.feed(3);
    b += g.cut();
    return b;
  }

  // ── Total calculation ──
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

  // ── Total ──
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

  // ── Debt info ──
  static List<int> _buildDebtInfo(
      Generator g,
      double orderTotal,
      double? amountPaid,
      double? newBalance,
      Order order,
      double? customerDebtBalance,
      ) {
    List<int> b = [];
    final paid = amountPaid ?? order.paidAmount;
    final remaining = orderTotal - paid;
    final prevDebt = customerDebtBalance ?? 0;

    b += _t(g, _line2, styles: const PosStyles(align: PosAlign.center));
    b += _t(
      g,
      'Total Facture : ${_money(orderTotal)} DA',
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    );
    b += _t(g, 'Montant Verse : ${_money(paid)} DA', styles: _bigger);
    if (remaining > 0) {
      b += _t(
        g,
        'Reste Facture : ${_money(remaining)} DA',
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      );
    } else {
      b += _t(g, 'Facture Payee (Solder)', styles: _bigger);
    }
    if (prevDebt > 0) {
      b += _t(g, 'Ancien Solde  : ${_money(prevDebt)} DA', styles: _bigger);
      final totalDebt = prevDebt + (remaining > 0 ? remaining : 0);
      b += _t(
        g,
        'NOUVEAU SOLDE : ${_money(totalDebt)} DA',
        styles: const PosStyles(
            bold: true, underline: true, height: PosTextSize.size2),
      );
    }
    return b;
  }

  // ── Footer ──
  static List<int> _buildFooter(Generator g) {
    List<int> b = [];
    b += g.feed(1);
    b += _t(
      g,
      'Merci pour votre confiance !',
      styles: const PosStyles(
          align: PosAlign.center, bold: true, height: PosTextSize.size2),
    );
    b += _t(
      g,
      'Tel: 0666629473',
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    b += g.feed(3);
    b += g.cut();
    return b;
  }

  // ══════════════════════════════════════════════════════
  //  ✅ Main print function
  // ══════════════════════════════════════════════════════
  static Future<bool> printReceipt({
    required Order order,
    required String customerName,
    required String customerPhone,
    double? amountPaid,
    double? customerDebtBalance,
  }) async {
    lastError = null;

    // 1. إذا كان التطبيق يعمل على نظام الحاسوب (Windows/macOS/Linux)
    if (isDesktop) {
      // ✅ نفس تصميم المعاينة (صورة داخل PDF)، وإن فشل الرسم نرجع للطريقة القديمة
      RenderedReceipt? rendered;
      try {
        rendered = await ReceiptRenderer.buildPng(
          order: order,
          customerName: customerName,
          customerPhone: customerPhone,
          total: _calcTotal(order),
          paid: amountPaid ?? order.paidAmount,
          prevDebt: customerDebtBalance ?? 0,
          widthPx: 576,
        );
      } catch (e) {
        debugPrint('⚠️ Receipt render failed (desktop): $e');
      }
      if (rendered != null) {
        return await _printDesktopFromImage(rendered, order);
      }
      return await _printDesktop(
        order,
        customerName,
        customerPhone,
        amountPaid,
        customerDebtBalance,
      );
    }

    // 2. إذا كان على الهاتف المحمول (Android/iOS) عبر طابعة البلوتوث
    try {
      // ✅ إن كان الاتصال مقطوعاً (مثلاً بعد فترة خمول) نعيد الاتصال تلقائياً
      if (!await ensureConnected()) {
        debugPrint('⚠️ No connection (reconnect failed)');
        lastError ??= 'الطابعة غير متصلة.';
        return false;
      }
      final profile = await CapabilityProfile.load();
      final g = Generator(PaperSize.mm58, profile);
      debugPrint('🖨️ Starting print — ${order.items.length} products');
      final orderTotal = _calcTotal(order);

      List<int> bytes = [];
      bool asImage = false;
      try {
        if (!useImageReceipt) {
          throw const FormatException('image receipt disabled');
        }
        // ✅ الوصل يُرسم كصورة بنفس تصميم المعاينة (والعربية تُطبع كما هي)
        final raster = await ReceiptRenderer.buildRaster(
          order: order,
          customerName: customerName,
          customerPhone: customerPhone,
          total: orderTotal,
          paid: amountPaid ?? order.paidAmount,
          prevDebt: customerDebtBalance ?? 0,
          widthPx: 384,
        );
        bytes = [...g.reset(), ...raster, ...g.feed(3), ...g.cut()];
        asImage = true;
      } catch (e) {
        debugPrint('ℹ️ Using text receipt ($e)');
      }

      if (!asImage) {
        // ✅ الوصل النصي بنفس ترتيب وتصميم المعاينة
        bytes += _buildPreviewStyleReceipt(
          g: g,
          order: order,
          customerName: customerName,
          customerPhone: customerPhone,
          total: orderTotal,
          paid: amountPaid ?? order.paidAmount,
          prevDebt: customerDebtBalance ?? 0,
        );
      }

      debugPrint('📦 Receipt size: ${bytes.length} bytes (image: $asImage)');
      final ok = await _sendWithRetry(bytes, chunked: asImage);
      debugPrint(ok ? '✅ Print successful' : '❌ Print failed');
      return ok;
    } catch (e) {
      debugPrint('❌ PrintReceipt error: $e');
      lastError ??= 'خطأ أثناء الطباعة.';
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  🖥️ الطباعة على الحاسوب من صورة الوصل (نفس تصميم المعاينة)
  // ══════════════════════════════════════════════════════
  static Future<bool> _printDesktopFromImage(
      RenderedReceipt r, Order order) async {
    try {
      final pdf = pw.Document();
      const margin = 1.5 * PdfPageFormat.mm;
      const pageW = 80 * PdfPageFormat.mm;
      final imgW = pageW - 2 * margin;
      final imgH = imgW * r.height / r.width;
      final image = pw.MemoryImage(r.png);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageW, imgH + 2 * margin, marginAll: margin),
          build: (pw.Context context) =>
              pw.Image(image, width: imgW, height: imgH, fit: pw.BoxFit.contain),
        ),
      );

      final printed = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
        'Facture_${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id}',
      );
      if (!printed) lastError = 'تم إلغاء الطباعة.';
      return printed;
    } catch (e) {
      debugPrint('❌ Desktop image printing error: $e');
      lastError = 'خطأ أثناء الطباعة على الحاسوب.';
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  🖥️ دالة الطباعة للحاسوب (LTR بالفرنسية عبر PDF و USB)
  // ══════════════════════════════════════════════════════
  static Future<bool> _printDesktop(
      Order order,
      String name,
      String phone,
      double? amountPaid,
      double? customerDebtBalance,
      ) async {
    try {
      final pdf = pw.Document();
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final total = _calcTotal(order);
      final paid = amountPaid ?? order.paidAmount;
      final remaining = total - paid;
      final prevDebt = customerDebtBalance ?? 0;

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 1.5 * PdfPageFormat.mm, // هوامش ضيقة جداً لتفادي القص من اليمين واليسار
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.ltr, // اتجاه من اليسار لليمين
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Header (بدون لوغو وأسود فاقع للطباعة الحرارية) ──
                  pw.Center(
                    child: pw.Text(
                      'AL QANAA GROSSISTE',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Vente de produits alimentaires',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // ── Infos ──
                  pw.Text('Date   : $dateStr',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  pw.Text(
                    'Order  : #${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.Text(
                    'Client : ${name.isEmpty ? "-" : _clean(name)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    pw.Text('Tel    : $phone',
                        style: const pw.TextStyle(fontSize: 8)),

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // ── Products Table (Grouped) ──
                  ...(() {
                    final Map<String, Map<String, dynamic>> grouped = {};
                    for (final it in order.items) {
                      final pName = _clean(it['productName'] ?? 'Produit');
                      final isCarton = it['isCarton'] == true;
                      final key = '$pName-$isCarton';
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
                          'productName': pName,
                          'quantity': qty,
                          'total': qty * price,
                          'isCarton': isCarton,
                          'flavors': flavor.isNotEmpty
                              ? ['$flavor (${qty.toStringAsFixed(0)})']
                              : <String>[],
                        };
                      }
                    }

                    int idx = 1;
                    return grouped.values.map((data) {
                      final name = data['productName'] as String;
                      final qty = data['quantity'] as double;
                      final totalItem = data['total'] as double;
                      final isCarton = data['isCarton'] == true;
                      final type = isCarton ? 'Crt' : 'Unt';
                      final flavorsList = data['flavors'] as List<String>;
                      final currentIdx = idx++;

                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '$currentIdx. $name ($type)',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9.5,
                              ),
                            ),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  '   Qte: ${qty.toStringAsFixed(0)}',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9.5,
                                  ),
                                ),
                                pw.Text(
                                  '${_money(totalItem)} DA',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                            if (flavorsList.isNotEmpty)
                              pw.Text(
                                '   Aromes: ${flavorsList.join(", ")}',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                          ],
                        ),
                      );
                    }).toList();
                  }()),

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // ── Totals ──
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL A PAYER :',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        '${_money(total)} DA',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Montant Verse :',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('${_money(paid)} DA',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (remaining > 0)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Reste Facture :',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                        pw.Text(
                          '${_money(remaining)} DA',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  if (prevDebt > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Ancien Solde  :',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('${_money(prevDebt)} DA',
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'NOUVEAU SOLDE :',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                        pw.Text(
                          '${_money(prevDebt + (remaining > 0 ? remaining : 0))} DA',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],

                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // ── Footer ──
                  pw.Center(
                    child: pw.Text(
                      'Merci pour votre confiance !',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Tel: 0666629473',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // إرسال الطباعة إلى طابعة النظام الافتراضية
      // ✅ إصلاح 1: نرجع نتيجة نافذة الطباعة الحقيقية (false عند الإلغاء) بدل true دائماً
      final printed = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
        'Facture_${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id}',
      );
      if (!printed) lastError = 'تم إلغاء الطباعة.';
      return printed;
    } catch (e) {
      debugPrint('❌ Desktop USB Printing Error: $e');
      lastError = 'خطأ أثناء الطباعة على الحاسوب.';
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  Printer test
  // ══════════════════════════════════════════════════════
  static Future<bool> printTest() async {
    lastError = null;
    if (isDesktop) {
      try {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(
              80 * PdfPageFormat.mm,
              double.infinity,
              marginAll: 5 * PdfPageFormat.mm,
            ),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'AL QANAA - TEST D\'IMPRESSION',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    pw.Text(
                      'Imprimante USB connectee avec succes !',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  ],
                ),
              );
            },
          ),
        );
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Test_Imprimante_AlQanaa',
        );
        return true;
      } catch (e) {
        debugPrint('❌ Desktop Test error: $e');
        return false;
      }
    }

    try {
      if (!await ensureConnected()) return false;
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
      return await _sendWithRetry(b);
    } catch (e) {
      debugPrint('❌ Test error: $e');
      return false;
    }
  }
}