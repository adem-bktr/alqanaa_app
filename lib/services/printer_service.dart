import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart'; // للطباعة على الويندوز والحاسوب
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class PrinterService {
  static String? _connectedAddress;
  static String? _connectedName;
  static bool _isConnected = false;

  static bool get isConnected =>
      _isConnected ||
          (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux));

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
  //  ✅ 3. Safe wrappers
  // ══════════════════════════════════════════════════════
  static List<int> _t(Generator g, Object? text, {PosStyles? styles}) {
    return g.text(_clean(text), styles: styles ?? const PosStyles());
  }

  static PosColumn _c(Object? text, int width, PosStyles styles) {
    return PosColumn(text: _clean(text), width: width, styles: styles);
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
      'Bienvenue chez nous',
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
    b += _t(g, 'Date   : $date', styles: _bigger);
    b += _t(
      g,
      'Client : ${name.isEmpty ? "-" : name}',
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    );
    b += _t(g, 'Tel    : ${phone.isEmpty ? "-" : phone}', styles: _bigger);
    b += _t(g, 'Order  : #$shortId', styles: _bigger);
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

  // ── Products — grouped by name ──
  static List<int> _buildItems(Generator g, List items) {
    List<int> b = [];
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final it in items) {
      final name = it['productName']?.toString() ?? 'Unknown product';
      if (grouped.containsKey(name)) {
        grouped[name]!['quantity'] =
            (grouped[name]!['quantity'] as num) + (it['quantity'] as num);
        grouped[name]!['total'] =
            (grouped[name]!['total'] as num) +
                ((it['price'] as num) * (it['quantity'] as num));
        final flavor = it['flavor']?.toString() ?? '';
        if (flavor.isNotEmpty) {
          final flavors = grouped[name]!['flavors'] as List<String>;
          flavors.add('$flavor (${it['quantity']})');
        }
      } else {
        final flavor = it['flavor']?.toString() ?? '';
        grouped[name] = {
          'productName': name,
          'quantity': it['quantity'] as num,
          'total': (it['price'] as num) * (it['quantity'] as num),
          'isCarton': it['isCarton'],
          'flavors': flavor.isNotEmpty
              ? ['$flavor (${it['quantity']})']
              : <String>[],
        };
      }
    }

    int idx = 1;
    grouped.forEach((name, data) {
      try {
        final qty = (data['quantity'] as num).toDouble();
        final total = (data['total'] as num).toDouble();
        final type = data['isCarton'] == true ? 'Crt' : 'Unt';
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
    b += _t(
      g,
      'AL QANAA GROSSISTE',
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
    // 1. إذا كان التطبيق يعمل على نظام الحاسوب (Windows/macOS/Linux)
    if (isDesktop) {
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
      if (!await checkConnection()) {
        debugPrint('⚠️ No connection');
        return false;
      }
      final profile = await CapabilityProfile.load();
      final g = Generator(PaperSize.mm58, profile);
      final date =
      DateFormat('dd/MM/yyyy - HH:mm', 'en_US').format(DateTime.now());
      debugPrint('🖨️ Starting print — ${order.items.length} products');
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
      bytes += _buildDebtInfo(
          g, orderTotal, amountPaid, null, order, customerDebtBalance);
      bytes += _buildFooter(g);

      debugPrint('📦 Receipt size: ${bytes.length} bytes');
      final ok = await _send(bytes);
      debugPrint(ok ? '✅ Print successful' : '❌ Print failed');
      return ok;
    } catch (e) {
      debugPrint('❌ PrintReceipt error: $e');
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

      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 4 * PdfPageFormat.mm,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.ltr, // اتجاه من اليسار لليمين
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  if (logoImage != null) ...[
                    pw.Center(child: pw.Image(logoImage, width: 90, height: 90)),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Center(
                    child: pw.Text(
                      'AL QANAA GROSSISTE',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Vente de produits alimentaires',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),

                  // ── Infos ──
                  pw.Text('Date   : $dateStr',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    'Order  : #${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                    style: const pw.TextStyle(fontSize: 8),
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

                  // ── Products Table ──
                  ...order.items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final it = entry.value;
                    final itemTotal =
                        (it['price'] as num) * (it['quantity'] as num);
                    final flavor = it['flavor']?.toString() ?? '';
                    final pName = _clean(it['productName'] ?? 'Produit');

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '$idx. $pName',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.Row(
                            mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '   Qte: ${it['quantity']} x ${_money(it['price'] as num)} DA',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                '${_money(itemTotal)} DA',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                          if (flavor.isNotEmpty)
                            pw.Text(
                              '   Arome: ${_clean(flavor)}',
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                        ],
                      ),
                    );
                  }).toList(),

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
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
        'Facture_${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Desktop USB Printing Error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  Printer test
  // ══════════════════════════════════════════════════════
  static Future<bool> printTest() async {
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
      debugPrint('❌ Test error: $e');
      return false;
    }
  }
}
