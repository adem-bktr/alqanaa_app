import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/models.dart';

/// نتيجة رسم الوصل كصورة PNG (للطباعة على الحاسوب عبر PDF)
class RenderedReceipt {
  final Uint8List png;
  final int width;
  final int height;
  const RenderedReceipt(this.png, this.width, this.height);
}

/// يرسم الوصل **بنفس تصميم نافذة المعاينة** (ReceiptPreviewDialog) كصورة،
/// فتُطبع الأسماء العربية كما هي بدل تحويلها لحروف لاتينية، ويتطابق الشكل المطبوع مع المعاينة.
class ReceiptRenderer {
  static String _money(num value) {
    final isNeg = value < 0;
    final digits = value.abs().round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return (isNeg ? '-' : '') + buf.toString();
  }

  // ══════════════════════════════════════════════════════
  //  الرسم
  // ══════════════════════════════════════════════════════
  static Future<ui.Image> _render({
    required Order order,
    required String customerName,
    required String customerPhone,
    required double total,
    required double paid,
    required double prevDebt,
    required int widthPx,
  }) async {
    final s = widthPx / 384; // مقياس العرض (384 نقطة = ورق 58mm)
    final k = s * 1.5; // مقياس الخط (أكبر قليلاً من المعاينة ليكون مقروءاً على الورق الحراري)
    final pad = 8.0 * s;
    final contentW = widthPx - 2 * pad;
    double y = pad;
    final ops = <void Function(Canvas)>[];

    TextPainter makePainter(
        String text,
        double size, {
          bool bold = true,
          bool italic = false,
          TextAlign align = TextAlign.left,
          double? maxW,
          bool fixedWidth = true,
        }) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: size * k,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      );
      final w = maxW ?? contentW;
      p.layout(minWidth: fixedWidth ? w : 0, maxWidth: w);
      return p;
    }

    void addText(String text, double size,
        {bool bold = true,
          bool italic = false,
          TextAlign align = TextAlign.left,
          double gap = 2}) {
      final p = makePainter(text, size,
          bold: bold, italic: italic, align: align);
      final y0 = y;
      ops.add((c) => p.paint(c, Offset(pad, y0)));
      y += p.height + gap * s;
    }

    void addRow(String left, String right, double lSize, double rSize,
        {bool lBold = false, bool rBold = true}) {
      final lp = makePainter(left, lSize,
          bold: lBold, fixedWidth: false, maxW: contentW * 0.62);
      final rp = makePainter(right, rSize,
          bold: rBold, fixedWidth: false, maxW: contentW * 0.62);
      final y0 = y;
      ops.add((c) {
        lp.paint(c, Offset(pad, y0));
        rp.paint(c, Offset(widthPx - pad - rp.width, y0));
      });
      y += math.max(lp.height, rp.height) + 2 * s;
    }

    void addDashed() {
      y += 4 * s;
      final y0 = y;
      ops.add((c) {
        final paint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.5 * s;
        double x = pad;
        while (x < widthPx - pad) {
          c.drawLine(Offset(x, y0),
              Offset(math.min(x + 6 * s, widthPx - pad), y0), paint);
          x += 10 * s;
        }
      });
      y += 6 * s;
    }

    final dateStr =
    DateFormat('dd/MM/yyyy - HH:mm', 'en_US').format(DateTime.now());
    final shortId = order.id.length > 6
        ? order.id.substring(order.id.length - 6)
        : order.id;
    final remaining = total - paid;

    // ── الترويسة ──
    addText('AL QANAA GROSSISTE', 15, align: TextAlign.center);
    addText('Vente de produits alimentaires', 10, align: TextAlign.center);
    addDashed();

    // ── معلومات الوصل والزبون ──
    addText('Date   : $dateStr', 11, bold: false);
    addText('Order  : #$shortId', 11, bold: false);
    addText('Client : ${customerName.trim().isEmpty ? "-" : customerName.trim()}', 12);
    if (customerPhone.trim().isNotEmpty) {
      addText('Tel    : ${customerPhone.trim()}', 11, bold: false);
    }
    addDashed();

    // ── المنتجات (مجمّعة حسب الاسم + النوع، تماماً كالمعاينة) ──
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final it in order.items) {
      final name = it['productName']?.toString() ?? 'Produit';
      final isCarton = it['isCarton'] == true;
      final key = '$name-$isCarton';
      final price = (it['price'] as num? ?? 0).toDouble();
      final qty = (it['quantity'] as num? ?? 0).toDouble();
      final flavor = it['flavor']?.toString() ?? '';

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
          'productName': name,
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
      final name = data['productName'] as String;
      final qty = data['quantity'] as double;
      final totalItem = data['total'] as double;
      final type = data['isCarton'] == true ? 'Crt' : 'Unt';
      final flavorsList = data['flavors'] as List<String>;

      addText('$idx. $name ($type)', 12, gap: 1);
      addRow('   Qte: ${qty.toStringAsFixed(0)}', '${_money(totalItem)} DA',
          11, 12);
      if (flavorsList.isNotEmpty) {
        addText('   Aromes: ${flavorsList.join(", ")}', 10,
            bold: false, italic: true);
      }
      y += 3 * s;
      idx++;
    }
    addDashed();

    // ── الحسابات ──
    addRow('TOTAL A PAYER :', '${_money(total)} DA', 13, 14, lBold: true);
    addRow('Montant Verse :', '${_money(paid)} DA', 11, 11, rBold: false);
    if (remaining > 0) {
      addRow('Reste Facture :', '${_money(remaining)} DA', 11, 12,
          lBold: true);
    }
    if (prevDebt > 0) {
      y += 4 * s;
      final boxTop = y;
      y += 4 * s;
      addRow('Ancien Solde :', '${_money(prevDebt)} DA', 11, 11,
          rBold: false);
      addRow('NOUVEAU SOLDE :',
          '${_money(prevDebt + (remaining > 0 ? remaining : 0))} DA', 12, 12,
          lBold: true);
      y += 2 * s;
      final boxBottom = y;
      ops.add((c) {
        c.drawRect(
          Rect.fromLTRB(2 * s, boxTop, widthPx - 2 * s, boxBottom),
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * s,
        );
      });
      y += 2 * s;
    }
    addDashed();

    // ── التذييل ──
    addText('Merci pour votre confiance !', 11, align: TextAlign.center);
    addText('Tel: 0666629473', 10, bold: false, align: TextAlign.center);
    y += pad;

    // ── التسجيل في صورة ──
    final height = y.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, widthPx.toDouble(), height.toDouble()));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthPx.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
    for (final op in ops) {
      op(canvas);
    }
    final picture = recorder.endRecording();
    return picture.toImage(widthPx, height);
  }

  // ══════════════════════════════════════════════════════
  //  ESC/POS Raster (للطباعة عبر البلوتوث)
  // ══════════════════════════════════════════════════════
  /// يرجع أوامر GS v 0 (صورة نقطية) جاهزة للإرسال للطابعة الحرارية.
  static Future<List<int>> buildRaster({
    required Order order,
    required String customerName,
    required String customerPhone,
    required double total,
    required double paid,
    required double prevDebt,
    int widthPx = 384,
  }) async {
    final img = await _render(
      order: order,
      customerName: customerName,
      customerPhone: customerPhone,
      total: total,
      paid: paid,
      prevDebt: prevDebt,
      widthPx: widthPx,
    );

    final w = img.width;
    final h = img.height;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw Exception('تعذر تحويل صورة الوصل');
    final px = data.buffer.asUint8List();

    final bytesPerRow = (w + 7) ~/ 8;
    const band = 128; // عدد الأسطر في كل أمر طباعة
    final out = <int>[];

    for (int y0 = 0; y0 < h; y0 += band) {
      final rows = math.min(band, h - y0);
      out.addAll([
        0x1D, 0x76, 0x30, 0x00, // GS v 0 m=0
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        rows & 0xFF, (rows >> 8) & 0xFF,
      ]);
      for (int r = 0; r < rows; r++) {
        for (int bx = 0; bx < bytesPerRow; bx++) {
          int b = 0;
          for (int bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            int v = 0; // 1 = نقطة سوداء
            if (x < w) {
              final i = ((y0 + r) * w + x) * 4;
              final lum =
                  0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
              if (lum < 160) v = 1;
            }
            b = (b << 1) | v;
          }
          out.add(b);
        }
      }
    }
    return out;
  }

  // ══════════════════════════════════════════════════════
  //  PNG (للطباعة على الحاسوب عبر PDF)
  // ══════════════════════════════════════════════════════
  static Future<RenderedReceipt> buildPng({
    required Order order,
    required String customerName,
    required String customerPhone,
    required double total,
    required double paid,
    required double prevDebt,
    int widthPx = 576,
  }) async {
    final img = await _render(
      order: order,
      customerName: customerName,
      customerPhone: customerPhone,
      total: total,
      paid: paid,
      prevDebt: prevDebt,
      widthPx: widthPx,
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('تعذر تحويل صورة الوصل');
    return RenderedReceipt(
        data.buffer.asUint8List(), img.width, img.height);
  }
}