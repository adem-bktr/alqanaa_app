import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';

/// ترتيب عمودي الكمية والسعر في الفاتورة
enum _ColumnOrder { auto, qtyFirst, priceFirst }

class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({super.key});

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  File? _image;
  bool _isProcessing = false;
  bool _isSaving = false;          // ✅ يمنع الضغط المزدوج على التحديث
  bool _autoMode = false;          // ✅ الإدخال التلقائي بعد المسح
  _ColumnOrder _columnOrder = _ColumnOrder.auto;
  List<DetectedInvoiceItem> _detectedItems = [];
  List<Product> _products = [];    // كاش المنتجات للربط التلقائي
  String? _detectedDate;
  String? _detectedSeller;
  bool _isDisposed = false;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // حدود منطقية — أي رقم خارجها غالباً ليس كمية/سعر (هاتف، تاريخ، كود...)
  static const double _maxPlausiblePrice = 100000;
  static const double _maxPlausibleQty = 5000;
  static const double _maxPlausibleTotal = 10000000;
  static const double _maxPlausibleColisage = 1000;
  // أقصى خطأ نسبي بين (الكمية × السعر) والمجموع ليُعتبر مطابقاً
  static const double _mathTolerance = 0.05;
  // في الفاتورة الجدولية الحساب مطبوع بدقة، فنستعمل حداً أضيق
  static const double _tableTolerance = 0.005;
  // الربط التلقائي بالاسم فقط عند تطابق شبه تام
  static const double _autoMatchThreshold = 0.9;

  static const List<String> _sellerKeywords = [
    'Vendeur', 'Seller', 'Fournisseur', 'بائع', 'مورد', 'المحل', 'De:', 'From:', 'إلى:'
  ];

  @override
  void dispose() {
    _isDisposed = true;
    _textRecognizer.close();
    super.dispose();
  }

  // ══════════════════════════════════
  //  أدوات مساعدة
  // ══════════════════════════════════
  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String _normalizeDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        sb.write(a);
      } else if (p >= 0) {
        sb.write(p);
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

  // ══════════════════════════════════
  //  قراءة الأرقام (فواصل الآلاف والكسور)
  // ══════════════════════════════════
  static final RegExp _numberRe =
  RegExp(r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d+)?');
  // سطر كامل بصيغة "12 500,00" — مسافة كفاصل آلاف مع كسور
  static final RegExp _spaceThousandsRe =
  RegExp(r'^\d{1,3}(?: \d{3})+[.,]\d{1,2}$');

  static double? _parseNumberToken(String tok) {
    String s = tok;
    final hasDot = s.contains('.');
    final hasComma = s.contains(',');
    if (hasDot && hasComma) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      final decSep = lastDot > lastComma ? '.' : ',';
      final thouSep = decSep == '.' ? ',' : '.';
      s = s.replaceAll(thouSep, '').replaceAll(decSep, '.');
    } else if (hasDot || hasComma) {
      final sep = hasDot ? '.' : ',';
      final parts = s.split(sep);
      final isThousands = parts.length > 2 ||
          (parts[1].length == 3 && parts[0].length <= 3 && parts[0] != '0');
      s = isThousands ? parts.join('') : parts.join('.');
    }
    return double.tryParse(s);
  }

  static List<double> _extractNumbers(String raw) {
    final text = _normalizeDigits(raw).trim();
    if (_spaceThousandsRe.hasMatch(text)) {
      final v = _parseNumberToken(text.replaceAll(' ', ''));
      return v == null ? <double>[] : <double>[v];
    }
    final out = <double>[];
    for (final m in _numberRe.allMatches(text)) {
      final tok = m.group(0)!;
      // أرقام طويلة جداً (هواتف، أكواد) نتجاهلها
      if (tok.replaceAll(RegExp(r'\D'), '').length > 8) continue;
      final v = _parseNumberToken(tok);
      if (v != null) out.add(v);
    }
    return out;
  }

  // ══════════════════════════════════
  //  تشابه الأسماء (للربط التلقائي والاقتراحات)
  // ══════════════════════════════════
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _similarity(String a, String b) {
    final na = _norm(a), nb = _norm(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    final ta = na.split(' ').where((w) => w.length > 1).toSet();
    final tb = nb.split(' ').where((w) => w.length > 1).toSet();
    double jac = 0;
    if (ta.isNotEmpty && tb.isNotEmpty) {
      jac = ta.intersection(tb).length / ta.union(tb).length;
    }
    double contain = 0;
    if (na.length >= 4 && nb.length >= 4 && (na.contains(nb) || nb.contains(na))) {
      contain = 0.85;
    }
    return jac > contain ? jac : contain;
  }

  Future<_MatchResult> _findMatch(String name) async {
    if (name.trim().isEmpty) return _MatchResult(null, false);
    try {
      final mappedId = await DataService.getMappedProductId(name);
      if (mappedId != null) {
        final p = await DataService.getProductById(mappedId);
        if (p != null) return _MatchResult(p, false);
      }
    } catch (_) {}
    Product? best;
    double bestScore = 0;
    for (final p in _products) {
      final s = _similarity(name, p.name);
      if (s > bestScore) {
        bestScore = s;
        best = p;
      }
    }
    if (best != null && bestScore >= _autoMatchThreshold) {
      return _MatchResult(best, true);
    }
    return _MatchResult(null, false);
  }

  // ══════════════════════════════════
  //  اختيار الصورة ومعالجتها
  // ══════════════════════════════════
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,   // ✅ جودة أعلى لقراءة الخط الصغير
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        setState(() {
          _image = File(pickedFile.path);
          _detectedItems = [];
          _detectedDate = null;
          _detectedSeller = null;
          _isProcessing = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed) _processImage(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _snack('تعذر اختيار الصورة: $e');
      }
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _detectedItems = [];
      _detectedDate = null;
      _detectedSeller = null;
      _isProcessing = false;
    });
  }

  void _setColumnOrder(_ColumnOrder v) {
    if (_columnOrder == v) return;
    setState(() => _columnOrder = v);
    if (_image != null && !_isProcessing && !_isSaving) {
      setState(() => _isProcessing = true);
      _snack('أُعيدت قراءة الفاتورة بالترتيب الجديد');
      _processImage(_image!.path);
    }
  }

  /// ✅ إعادة ترميز الصورة إلى PNG عادي قبل تمريرها لقارئ النص.
  /// صور آيفون (من الألبوم أو الكاميرا) غالباً بصيغة HEIC، وقد يفشل
  /// قارئ النص الأصلي عند فتحها مباشرة على جهاز iOS حقيقي فيوقف التطبيق.
  /// نفك ترميزها بمحرك Flutter نفسه (بدون أي حزمة إضافية) ونحفظها PNG.
  Future<String> _ensureSafeImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (byteData == null) return path;
      final dir = Directory.systemTemp;
      final outPath =
          '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(byteData.buffer.asUint8List());
      return outPath;
    } catch (_) {
      // فشل التحويل: نرجع للمسار الأصلي كما كان سلوك الكود قبل هذا التعديل
      return path;
    }
  }

  Future<void> _processImage(String path) async {
    if (_isDisposed) return;
    try {
      if (_products.isEmpty) {
        try {
          _products = await DataService.getAllProducts();
        } catch (_) {}
      }

      final safePath = await _ensureSafeImage(path);
      if (_isDisposed) return;
      final inputImage = InputImage.fromFilePath(safePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      List<TextLine> allLines = [];
      for (TextBlock block in recognizedText.blocks) {
        allLines.addAll(block.lines);
      }
      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      List<DetectedInvoiceItem> items = [];
      String? detectedDate;
      String? detectedSeller;
      final dateRegex = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}');

      // ✅ الفاتورة الجدولية (Bon de vente): صفوفها مرتبطة بكلمة "Unité"
      final tableItems = await _parseTable(allLines);

      if (tableItems != null) {
        items = tableItems;
        for (final l in allLines) {
          final text = l.text;
          if (detectedDate == null && dateRegex.hasMatch(text)) {
            detectedDate = dateRegex.stringMatch(text);
            continue;
          }
          final lower = text.toLowerCase();
          final isSellerLine =
          _sellerKeywords.any((k) => lower.contains(k.toLowerCase()));
          if (detectedSeller == null && isSellerLine && _extractNumbers(text).length < 2) {
            final parts = text.split(RegExp(r'[:\-]'));
            detectedSeller = parts.length > 1
                ? parts.last.trim()
                : text
                .replaceAll(RegExp(_sellerKeywords.join('|'), caseSensitive: false), '')
                .trim();
          }
        }
      } else {
        // ─────────── المسار العام (فواتير بدون أعمدة واضحة) ───────────
        // تجميع الأسطر في صفوف بحد يتكيف مع حجم الخط في الصورة
        final rows = _groupIntoRows(allLines);

        for (var row in rows) {
          row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
          String text = row.map((l) => l.text).join(' ');

          // 1️⃣ فحص التواريخ
          if (dateRegex.hasMatch(text) && detectedDate == null) {
            detectedDate = dateRegex.stringMatch(text);
            continue;
          }

          // 2️⃣ فحص الوقت
          final timeRegex = RegExp(r'\d{1,2}:\d{2}');
          if (timeRegex.hasMatch(text) && !text.contains(RegExp(r'[a-zA-Z]'))) {
            continue;
          }

          // 3️⃣ الأرقام (بترتيب الأعمدة من اليسار لليمين) — سطر بسطر
          final nums = <double>[];
          for (final l in row) {
            nums.addAll(_extractNumbers(l.text));
          }

          // 4️⃣ اسم البائع / المورد
          bool isSellerLine =
          _sellerKeywords.any((k) => text.toLowerCase().contains(k.toLowerCase()));

          if (isSellerLine && nums.length < 2) {
            final parts = text.split(RegExp(r'[:\-]'));
            detectedSeller = parts.length > 1
                ? parts.last.trim()
                : text
                .replaceAll(RegExp(_sellerKeywords.join('|'), caseSensitive: false), '')
                .trim();
            continue;
          }

          if (nums.isEmpty) continue;

          String name = text
              .replaceAll(RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'), '')
              .replaceAll(RegExp(r'\d+([.,]\d+)?'), '')
              .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
              .trim();

          if (name.length <= 2 && nums.length < 2) continue;

          // ✅ مطابقة الكلمة كاملة (لا حذف لمنتج اسمه يحتوي "net" مثلاً)
          if (_isHeaderOrFooterRow(name)) continue;

          final parsed = _resolveQuantityPriceTotal(nums);
          if (parsed == null) continue;

          final match = await _findMatch(name);

          // لا نحدد الصف تلقائياً إلا إذا كنا واثقين منه
          final confident = parsed.isMathValid || nums.length == 2;
          final priceOk = parsed.price <= _maxPlausiblePrice;
          items.add(DetectedInvoiceItem(
            rawText: name.isEmpty ? "صنف مجهول" : name,
            quantity: parsed.quantity,
            price: parsed.price,
            total: parsed.total,
            isMathValid: parsed.isMathValid,
            matchedProduct: match.product,
            autoMatched: match.auto,
            isSelected: parsed.quantity > 0 && confident && priceOk,
            needsReview: !confident || parsed.quantity <= 0 || !priceOk,
          ));
        }
      }

      if (!mounted || _isDisposed) return;
      setState(() {
        _detectedItems = items;
        _detectedDate = detectedDate;
        _detectedSeller = detectedSeller;
        _isProcessing = false;
      });

      // ✅ الإدخال التلقائي: تجهيز الأصناف المؤكدة وعرض ملخص التأكيد مباشرة
      if (_autoMode && items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) _autoEnter();
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        if (mounted) setState(() => _isProcessing = false);
        _snack('تعذر قراءة الفاتورة: $e');
      }
    }
  }

  bool _isHeaderOrFooterRow(String name) {
    const keywords = {
      'total', 'tva', 'net', 'pagé', 'payé', 'page', 'facture', 'n', 'date',
      'ttc', 'ht', 'montant', 'timbre',
    };
    final tokens = _norm(name).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;
    if (keywords.contains(tokens.first)) return true;
    return tokens.every(keywords.contains);
  }

  // ══════════════════════════════════
  //  قراءة الفاتورة الجدولية
  //  الأعمدة: Référence | Désignation | Unité | Qte. | Colisage | Prix Unit. | MONTANT
  //  المبلغ = الكمية × Colisage × السعر
  // ══════════════════════════════════
  static bool _isUnitWord(String t) {
    final s = t.replaceAll(RegExp(r'[.,:;|]'), '');
    return RegExp(r'^un[il1|]t[eéèê]$', caseSensitive: false).hasMatch(s);
  }

  /// ميل النص المحلي (الصورة الملتقطة بالكاميرا تكون مائلة)
  double _localSlope(List<TextLine> lines, double y, double window) {
    final s = <double>[];
    for (final l in lines) {
      final cp = l.cornerPoints;
      if (cp.length < 4) continue;
      final dx = cp[1].x - cp[0].x;
      if (dx < 60) continue;
      if ((l.boundingBox.center.dy - y).abs() > window) continue;
      s.add((cp[1].y - cp[0].y) / dx);
    }
    if (s.length < 3) return 0;
    s.sort();
    return s[s.length ~/ 2];
  }

  /// يرجع null إذا لم توجد أي كلمة "Unité" (ليس جدولاً بهذا الشكل)
  Future<List<DetectedInvoiceItem>?> _parseTable(List<TextLine> lines) async {
    final words = <_Word>[];
    for (final l in lines) {
      for (final e in l.elements) {
        final t = _normalizeDigits(e.text).trim();
        if (t.isNotEmpty) words.add(_Word(t, e.boundingBox));
      }
    }

    final anchors = words.where((w) => _isUnitWord(w.text)).toList()
      ..sort((a, b) => a.cy.compareTo(b.cy));
    if (anchors.isEmpty) return null;

    // المسافة بين الصفوف
    double pitch = anchors.first.box.height * 1.8;
    if (anchors.length >= 2) {
      final gaps = <double>[];
      for (int i = 1; i < anchors.length; i++) {
        final g = anchors[i].cy - anchors[i - 1].cy;
        if (g > 4) gaps.add(g);
      }
      if (gaps.isNotEmpty) {
        gaps.sort();
        pitch = gaps[gaps.length ~/ 2];
      }
    }

    final slopes = anchors.map((a) => _localSlope(lines, a.cy, pitch * 3)).toList();

    // إسناد كل كلمة إلى أقرب صف مع تصحيح الميل
    final rows = List.generate(anchors.length, (_) => <_Word>[]);
    for (final w in words) {
      int best = -1;
      double bestD = pitch * 0.5;
      for (int i = 0; i < anchors.length; i++) {
        final a = anchors[i];
        final expected = a.cy + slopes[i] * (w.box.center.dx - a.box.center.dx);
        final d = (w.cy - expected).abs();
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      if (best >= 0) rows[best].add(w);
    }

    final items = <DetectedInvoiceItem>[];
    for (final row in rows) {
      row.sort((a, b) => a.box.left.compareTo(b.box.left));
      final ai = row.indexWhere((w) => _isUnitWord(w.text));
      if (ai < 0) continue;

      final left = row.sublist(0, ai);
      final right = row.sublist(ai + 1);

      // المرجع (Référence) هو أول رقم على اليسار — نحذفه من الاسم
      var designation = left;
      if (left.isNotEmpty && RegExp(r'^\d{3,8}$').hasMatch(left.first.text)) {
        designation = left.sublist(1);
      }
      final name = designation
          .map((w) => w.text)
          .join(' ')
          .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final nums = _tableNumbers(right);
      if (nums.isEmpty) continue; // صف العناوين أو صف فارغ
      if (name.isNotEmpty && _isHeaderOrFooterRow(name)) continue;

      final parsed = _solveTableRow(nums);
      final match = await _findMatch(name);
      final confident = parsed.isMathValid;
      final priceOk = parsed.price <= _maxPlausiblePrice;

      items.add(DetectedInvoiceItem(
        rawText: name.isEmpty ? 'صنف مجهول' : name,
        quantity: parsed.quantity,
        colisage: parsed.colisage,
        price: parsed.price,
        total: parsed.total,
        isMathValid: parsed.isMathValid,
        matchedProduct: match.product,
        autoMatched: match.auto,
        isCarton: false, // عمود الوحدة "Unité" — السعر للحبة
        isSelected: parsed.quantity > 0 && confident && priceOk,
        needsReview: !confident || parsed.quantity <= 0 || !priceOk,
      ));
    }
    return items;
  }

  /// أرقام ما بعد "Unité" مع دمج فواصل الآلاف (مثل "1" + "560.00")
  /// بالاعتماد على المسافة الأفقية الصغيرة بينهما
  List<_Num> _tableNumbers(List<_Word> right) {
    final toks = <_Word>[];
    for (final w in right) {
      final m = RegExp(r'\d[\d.,]*').firstMatch(w.text);
      if (m == null) continue; // علامة القلم (X) أو نص آخر
      final t = m.group(0)!.replaceAll(RegExp(r'[.,]+$'), '');
      if (t.isEmpty) continue;
      toks.add(_Word(t, w.box));
    }

    final out = <_Num>[];
    int i = 0;
    while (i < toks.length) {
      var cur = toks[i].text;
      var box = toks[i].box;
      while (i + 1 < toks.length &&
          RegExp(r'^\d{1,3}(?:\d{3})*$').hasMatch(cur) &&
          RegExp(r'^\d{3}(?:[.,]\d{1,2})?$').hasMatch(toks[i + 1].text) &&
          (toks[i + 1].box.left - box.right) <= box.height * 0.8) {
        cur += toks[i + 1].text;
        box = toks[i + 1].box;
        i++;
      }
      final v = _parseNumberToken(cur);
      if (v != null) out.add(_Num(v, RegExp(r'[.,]\d{1,2}$').hasMatch(cur)));
      i++;
    }
    return out;
  }

  /// [الكمية، (علامة)، Colisage، السعر، المبلغ] — نتحقق بالحساب لتحديد الأرقام الصحيحة
  _ParsedNumbers _solveTableRow(List<_Num> nums) {
    final v = nums.map((e) => e.v).toList();
    final n = v.length;

    if (n >= 3) {
      final total = v[n - 1];
      final price = v[n - 2];
      final pre = v.sublist(0, n - 2);

      if (total > 0 && price > 0) {
        double bestErr = double.infinity;
        double bestQ = 0, bestC = 1;
        int bestScore = -1;

        void consider(double q, double c, int score) {
          if (q <= 0 || c <= 0 || q > _maxPlausibleQty || c > _maxPlausibleColisage) return;
          final err = ((q * c * price) - total).abs() / total;
          if (err < bestErr - 1e-9 || ((err - bestErr).abs() <= 1e-9 && score > bestScore)) {
            bestErr = err;
            bestQ = q;
            bestC = c;
            bestScore = score;
          }
        }

        for (int i = 0; i < pre.length; i++) {
          consider(pre[i], 1, i == 0 ? 1 : 0);
          for (int j = i + 1; j < pre.length; j++) {
            // نفضّل: الكمية أول رقم، والـ Colisage آخر رقم (علامة القلم بينهما)
            consider(pre[i], pre[j], (i == 0 && j == pre.length - 1) ? 2 : 0);
          }
        }

        if (bestErr <= _tableTolerance) {
          return _ParsedNumbers(
              quantity: bestQ.round(),
              colisage: bestC.round(),
              price: price,
              total: total,
              isMathValid: true);
        }

        // الكمية أو Colisage غير مقروءة لكن السعر والمبلغ سليمان: عدد الحبات = المبلغ ÷ السعر
        if (nums[n - 1].dec && nums[n - 2].dec) {
          final m = total / price;
          if (m >= 1 && m <= 100000 && (m - m.round()).abs() < 0.01) {
            return _ParsedNumbers(
                quantity: m.round(), colisage: 1, price: price, total: total, isMathValid: true);
          }
        }
      }

      // لا تطابق: نأخذ أفضل تخمين ونطلب المراجعة
      final q = pre.first;
      final c = pre.length >= 2 ? pre.last : 1.0;
      return _ParsedNumbers(
          quantity: q <= _maxPlausibleQty ? q.round() : 0,
          colisage: (c >= 1 && c <= _maxPlausibleColisage) ? c.round() : 1,
          price: price,
          total: total,
          isMathValid: false);
    }

    if (n == 2) {
      return _ParsedNumbers(
          quantity: v[0] <= _maxPlausibleQty ? v[0].round() : 0,
          price: v[1],
          total: 0,
          isMathValid: false);
    }
    return _ParsedNumbers(quantity: 0, price: v.first, total: 0, isMathValid: false);
  }

  /// تجميع أسطر OCR في صفوف مرئية، بحد يتناسب مع الوسيط الحقيقي لارتفاع السطر
  List<List<TextLine>> _groupIntoRows(List<TextLine> allLines) {
    if (allLines.isEmpty) return [];

    final heights = allLines.map((l) => l.boundingBox.height).toList()..sort();
    final medianHeight = heights[heights.length ~/ 2];
    final threshold = (medianHeight > 0 ? medianHeight : 20) * 0.6;

    List<List<TextLine>> rows = [];
    List<TextLine> currentRow = [allLines[0]];
    for (int i = 1; i < allLines.length; i++) {
      final sameRow =
          (allLines[i].boundingBox.top - currentRow.last.boundingBox.top).abs() < threshold;
      if (sameRow) {
        currentRow.add(allLines[i]);
      } else {
        rows.add(List.from(currentRow));
        currentRow = [allLines[i]];
      }
    }
    rows.add(currentRow);
    return rows;
  }

  bool _firstIsQty(double a, double b) {
    switch (_columnOrder) {
      case _ColumnOrder.qtyFirst:
        return true;
      case _ColumnOrder.priceFirst:
        return false;
      case _ColumnOrder.auto:
        return a <= b; // الأصغر = الكمية
    }
  }

  /// أفضل تفسير للأرقام الموجودة في الصف. يرجع null إذا لا رقم منطقي.
  _ParsedNumbers? _resolveQuantityPriceTotal(List<double> nums) {
    final plausible = nums.where((n) => n >= 0 && n <= _maxPlausibleTotal).toList();
    if (plausible.isEmpty) return null;

    if (plausible.length >= 3) {
      // نجرب كل ثلاثية مرتبة (i<j<k) ونختار الأقل خطأ (ونفضّل المجموع الأبعد يميناً)
      double bestError = double.infinity;
      double bestQty = 0, bestPrice = 0, bestTotal = 0;
      int bestK = -1;

      for (int i = 0; i < plausible.length; i++) {
        for (int j = i + 1; j < plausible.length; j++) {
          final a = plausible[i], b = plausible[j];
          if (a <= 0 || b <= 0) continue;
          final firstQty = _firstIsQty(a, b);
          final qty = firstQty ? a : b;
          final price = firstQty ? b : a;
          if (qty > _maxPlausibleQty || price > _maxPlausiblePrice) continue;
          for (int k = j + 1; k < plausible.length; k++) {
            final total = plausible[k];
            if (total <= 0) continue;
            final relError = ((qty * price) - total).abs() / (total > 1 ? total : 1);
            final better = relError < bestError - 1e-9 ||
                ((relError - bestError).abs() <= 1e-9 && k > bestK);
            if (better) {
              bestError = relError;
              bestQty = qty;
              bestPrice = price;
              bestTotal = total;
              bestK = k;
            }
          }
        }
      }
      if (bestK >= 0 && bestError < _mathTolerance) {
        return _ParsedNumbers(
            quantity: bestQty.round(), price: bestPrice, total: bestTotal, isMathValid: true);
      }
      // لا ثلاثية متطابقة: نفترض أن الأخير هو المجموع ونأخذ الرقمين قبله (غير مؤكد)
      final a = plausible[plausible.length - 3];
      final b = plausible[plausible.length - 2];
      final firstQty = _firstIsQty(a, b);
      final qty = firstQty ? a : b;
      final price = firstQty ? b : a;
      if (qty <= _maxPlausibleQty) {
        return _ParsedNumbers(quantity: qty.round(), price: price, total: 0, isMathValid: false);
      }
      return _ParsedNumbers(quantity: 0, price: price, total: 0, isMathValid: false);
    } else if (plausible.length == 2) {
      final a = plausible[0], b = plausible[1];
      final firstQty = _firstIsQty(a, b);
      final qty = firstQty ? a : b;
      final price = firstQty ? b : a;
      if (qty > _maxPlausibleQty) {
        return _ParsedNumbers(quantity: 0, price: price, total: 0, isMathValid: false);
      }
      return _ParsedNumbers(quantity: qty.round(), price: price, total: 0, isMathValid: false);
    } else {
      // رقم واحد: لا نعرف إن كان كمية أو سعراً — يُترك للمراجعة اليدوية
      return _ParsedNumbers(quantity: 0, price: plausible.first, total: 0, isMathValid: false);
    }
  }

  // ══════════════════════════════════
  //  الإدخال التلقائي
  // ══════════════════════════════════
  void _autoEnter() {
    bool any = false;
    for (final it in _detectedItems) {
      if (it.applied) continue;
      final eligible = it.matchedProduct != null && !it.needsReview && it.quantity > 0;
      it.isSelected = eligible;
      if (eligible) any = true;
    }
    setState(() {});
    if (any) {
      _confirmAndApply();
    } else {
      _snack('لا توجد أصناف مؤكدة للإدخال التلقائي — اربط الأصناف أو راجعها يدوياً',
          color: Colors.orange);
    }
  }

  // ══════════════════════════════════
  //  خطة التحديث (دمج الأصناف المكررة + قراءة حديثة للمخزون)
  // ══════════════════════════════════
  Future<_ApplyPlan> _buildPlan() async {
    final Map<String, List<DetectedInvoiceItem>> byProduct = {};
    int skipped = 0;
    for (final item in _detectedItems) {
      if (!item.isSelected || item.applied) continue;
      if (item.matchedProduct == null || item.quantity <= 0) {
        skipped++;
        continue;
      }
      byProduct.putIfAbsent(item.matchedProduct!.id, () => []).add(item);
    }

    final lines = <_PlanLine>[];
    for (final entry in byProduct.entries) {
      final fresh = await DataService.getProductById(entry.key);
      if (fresh == null) {
        skipped += entry.value.length;
        continue;
      }
      final upc = fresh.unitsPerCarton > 0 ? fresh.unitsPerCarton : 1;
      int addUnits = 0;
      double valueSum = 0;
      for (final it in entry.value) {
        int units;
        double unitBuy;
        if (it.colisage > 1) {
          // الكمية × Colisage = عدد الحبات، والسعر المطبوع هو سعر الحبة
          units = it.quantity * it.colisage;
          unitBuy = it.price;
        } else {
          units = it.isCarton ? it.quantity * upc : it.quantity;
          unitBuy = it.isCarton ? it.price / upc : it.price;
        }
        addUnits += units;
        valueSum += unitBuy * units;
      }
      final avg = addUnits > 0 ? valueSum / addUnits : 0.0;
      lines.add(_PlanLine(
        product: fresh,
        addUnits: addUnits,
        newPurchase: avg > 0 ? avg : fresh.purchasePrice,
        sources: entry.value,
      ));
    }
    return _ApplyPlan(lines, skipped);
  }

  // ══════════════════════════════════
  //  منع تكرار نفس الفاتورة
  // ══════════════════════════════════
  static int _fnv(String s, int seed) {
    int h = seed;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  String _fingerprint(_ApplyPlan plan) {
    final parts = plan.lines
        .map((l) => '${l.product.id}:${l.addUnits}:${l.newPurchase.toStringAsFixed(2)}')
        .toList()
      ..sort();
    final raw = '${_detectedDate ?? ''}|${_norm(_detectedSeller ?? '')}|${parts.join(',')}';
    return '${_fnv(raw, 0x811c9dc5).toRadixString(16)}'
        '${_fnv(raw, 0x9747b28c).toRadixString(16)}${raw.length}';
  }

  Future<Map<String, dynamic>?> _findDuplicate(String fp) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scanned_invoices')
          .where('fingerprint', isEqualTo: fp)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _logInvoice(String fp, _ApplyPlan plan) async {
    try {
      await FirebaseFirestore.instance.collection('scanned_invoices').add({
        'fingerprint': fp,
        'seller': _detectedSeller ?? '',
        'invoiceDate': _detectedDate ?? '',
        'itemsCount': plan.lines.length,
        'totalValue': plan.totalValue,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ══════════════════════════════════
  //  التأكيد والتطبيق
  // ══════════════════════════════════
  Future<void> _confirmAndApply() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final plan = await _buildPlan();
      if (plan.lines.isEmpty) {
        _snack('لا توجد أصناف جاهزة للتحديث — اربط الأصناف وحدد كمياتها',
            color: Colors.orange);
        return;
      }
      final fingerprint = _fingerprint(plan);
      final duplicate = await _findDuplicate(fingerprint);
      if (!mounted) return;
      final ok = await _showConfirmDialog(plan, duplicate);
      if (ok != true) return;
      await _executePlan(plan, fingerprint);
    } catch (e) {
      _snack('حدث خطأ أثناء التحضير: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _warnBox(String text, Color color) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
  );

  Widget _planTile(_PlanLine l) {
    final oldStock = l.product.stockQuantity;
    final newStock = oldStock + l.addUnits;
    final purchaseChanged = (l.newPurchase - l.product.purchasePrice).abs() > 0.005;
    final auto = l.sources.any((s) => s.autoMatched);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        if (auto)
          const Text('ربط تلقائي بالاسم — تأكد أنه المنتج الصحيح',
              style: TextStyle(color: Colors.orange, fontSize: 10)),
        const SizedBox(height: 2),
        Text('المخزن: من $oldStock إلى $newStock حبة (+${l.addUnits})',
            style: const TextStyle(fontSize: 12)),
        if (purchaseChanged)
          Text('سعر الشراء للحبة: من ${_fmt(l.product.purchasePrice)} إلى ${_fmt(l.newPurchase)} DA',
              style: const TextStyle(fontSize: 12)),
        if (l.sources.length > 1)
          Text('مجمّع من ${l.sources.length} أسطر',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ]),
    );
  }

  Future<bool?> _showConfirmDialog(_ApplyPlan plan, Map<String, dynamic>? duplicate) {
    final excluded = _detectedItems.where((i) => !i.isSelected && !i.applied).length;
    String? dupWhen;
    if (duplicate != null) {
      final ts = duplicate['createdAt'];
      if (ts is Timestamp) dupWhen = fmtDate(ts.toDate());
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تحديث المخزن'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (duplicate != null)
                  _warnBox(
                    '⚠️ يبدو أن هذه الفاتورة أُدخلت من قبل'
                        '${dupWhen != null ? ' ($dupWhen)' : ''}. '
                        'التطبيق مرة أخرى سيضاعف المخزون.',
                    Colors.red,
                  ),
                if (excluded > 0 || plan.skipped > 0)
                  _warnBox(
                    '${excluded + plan.skipped} صنف غير مشمول (غير محدد أو غير مربوط أو يحتاج مراجعة)',
                    Colors.orange,
                  ),
                ...plan.lines.map(_planTile),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: duplicate != null ? Colors.red : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(duplicate != null ? 'تطبيق رغم التكرار' : 'تأكيد التحديث'),
          ),
        ],
      ),
    );
  }

  Product _withStock(Product p, int stock, double purchase) => Product(
    id: p.id, brandId: p.brandId, categoryId: p.categoryId, name: p.name,
    priceCartonNormal: p.priceCartonNormal, priceUnitNormal: p.priceUnitNormal,
    priceCartonSpecial: p.priceCartonSpecial, priceUnitSpecial: p.priceUnitSpecial,
    imagePath: p.imagePath, isAvailable: p.isAvailable, discount: p.discount, sellType: p.sellType,
    maxQtyNormal: p.maxQtyNormal, maxQtySpecial: p.maxQtySpecial, flavors: p.flavors, isFeatured: p.isFeatured,
    purchasePrice: purchase,
    stockQuantity: stock,
    unitsPerCarton: p.unitsPerCarton,
  );

  Future<void> _executePlan(_ApplyPlan plan, String fingerprint) async {
    final updatedNames = <String>[];
    final failed = <String>[];

    for (final line in plan.lines) {
      try {
        // قراءة حديثة قبل الكتابة لتفادي الكتابة فوق مخزون تغيّر
        final fresh = await DataService.getProductById(line.product.id) ?? line.product;
        final updated = _withStock(
          fresh,
          fresh.stockQuantity + line.addUnits,
          line.newPurchase > 0 ? line.newPurchase : fresh.purchasePrice,
        );
        await DataService.updateProduct(updated);
        updatedNames.add(fresh.name);
        for (final it in line.sources) {
          it.applied = true;
          it.isSelected = false;
          if (it.autoMatched) {
            try {
              await DataService.saveSupplierMapping(it.rawText, fresh.id);
            } catch (_) {}
            it.autoMatched = false;
          }
        }
      } catch (_) {
        failed.add(line.product.name);
      }
    }

    if (updatedNames.isNotEmpty) await _logInvoice(fingerprint, plan);
    if (!mounted) return;
    setState(() {});

    final remaining = _detectedItems.where((i) => !i.applied).length;
    if (failed.isEmpty) {
      final msg = plan.skipped > 0
          ? '✅ تم تحديث ${updatedNames.length} منتج — تم تجاوز ${plan.skipped} صنف يحتاج مراجعة يدوية'
          : '✅ تم تحديث ${updatedNames.length} منتج';
      _snack(msg, color: plan.skipped > 0 ? Colors.orange : Colors.green);
      // في الوضع التلقائي نبقى في الشاشة إذا بقيت أصناف لم تُدخل
      if (!(_autoMode && remaining > 0)) {
        Navigator.pop(context);
      }
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('اكتمل التحديث جزئياً'),
          content: Text(
            'تم تحديث ${updatedNames.length} منتج.\n'
                'تعذّر تحديث: ${failed.join('، ')}\n'
                'الأصناف التي تمّ تحديثها لن تُضاف مرة ثانية إذا أعدت المحاولة.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      );
    }
  }

  // ══════════════════════════════════
  //  الواجهة
  // ══════════════════════════════════
  int get _selectedCount =>
      _detectedItems.where((i) => i.isSelected && !i.applied).length;

  @override
  Widget build(BuildContext context) {
    final busy = _isProcessing || _isSaving;
    return Scaffold(
      appBar: AppBar(
        title: const Text('سكان فاتورة مورد'),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          if (_image != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'صورة أخرى',
              onPressed: busy ? null : _reset,
            ),
        ],
      ),
      body: Column(children: [
        _buildSettingsCard(busy),
        if (_image == null)
          Expanded(child: Center(child: _buildPicker()))
        else ...[
          Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          else if (_detectedItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('لم يتم التعرف على أي أصناف — حاول صورة أوضح'),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('صورة أخرى'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _showAddManualDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة صنف يدوياً'),
                    ),
                  ]),
                ]),
              ),
            )
          else ...[
              if (_detectedDate != null || _detectedSeller != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(children: [
                      if (_detectedSeller != null)
                        Row(children: [
                          const Icon(Icons.person, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('البائع المستخرج: $_detectedSeller',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      if (_detectedDate != null)
                        Row(children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('التاريخ المستخرج: $_detectedDate',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                    ]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'الأصناف المميزة بـ ⚠️ تحتاج مراجعتك قبل التحديث',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _showAddManualDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('صنف', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _detectedItems.length,
                  itemBuilder: (context, i) => _buildRow(_detectedItems[i], i),
                ),
              ),
            ],
          if (_detectedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(15),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: (_isSaving || _isProcessing) ? null : _confirmAndApply,
                child: _isSaving
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('تحديث المخزن ($_selectedCount)'),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _buildSettingsCard(bool busy) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('إدخال تلقائي بعد المسح',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text(
            'يجهّز الأصناف المؤكدة ويعرض ملخص التأكيد مباشرة',
            style: TextStyle(fontSize: 10),
          ),
          value: _autoMode,
          onChanged: busy ? null : (v) => setState(() => _autoMode = v),
        ),
        Row(children: [
          const Text('ترتيب الأعمدة:', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(spacing: 6, children: [
              _orderChip('تلقائي', _ColumnOrder.auto, busy),
              _orderChip('الكمية أولاً', _ColumnOrder.qtyFirst, busy),
              _orderChip('السعر أولاً', _ColumnOrder.priceFirst, busy),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _orderChip(String label, _ColumnOrder v, bool busy) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selected: _columnOrder == v,
    onSelected: busy ? null : (_) => _setColumnOrder(v),
    visualDensity: VisualDensity.compact,
  );

  Widget _buildPicker() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
    const SizedBox(height: 20),
    const Text('صوّر الفاتورة أو اخترها من الألبوم'),
    const SizedBox(height: 30),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _btn(Icons.camera_alt, 'كاميرا', () => _pickImage(ImageSource.camera)),
      const SizedBox(width: 30),
      _btn(Icons.photo_library, 'الألبوم', () => _pickImage(ImageSource.gallery)),
    ]),
  ]);

  Widget _btn(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF2E7D32)),
      ),
      const SizedBox(height: 5),
      Text(label),
    ]),
  );

  Widget _miniChip(String label, bool selected, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade400),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey.shade700)),
    ),
  );

  Widget _iconBtn(IconData icon, String tooltip, Color? color, VoidCallback? onTap) => IconButton(
    icon: Icon(icon, size: 18, color: color),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    onPressed: onTap,
  );

  Widget _buildRow(DetectedInvoiceItem item, int i) {
    final mismatch = item.total > 0 &&
        item.quantity > 0 &&
        (item.lineTotal - item.total).abs() / item.total > _mathTolerance;
    final locked = item.applied || _isSaving;
    return Opacity(
      opacity: item.applied ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: item.needsReview && !item.applied ? Colors.orange.withValues(alpha: 0.06) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: item.isSelected,
              onChanged: item.applied ? null : (v) => setState(() => item.isSelected = v ?? false),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    if (item.needsReview && !item.applied)
                      const Padding(padding: EdgeInsets.only(right: 4), child: Text('⚠️')),
                    Expanded(
                      child: Text(item.rawText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                ),
                const SizedBox(height: 2),
                Text(
                  'الكمية: ${item.quantity}'
                      '${item.colisage > 1 ? ' × ${item.colisage} حبة' : ' ${item.isCarton ? 'كرتون' : 'حبة'}'}'
                      ' | السعر: ${_fmt(item.price)} DA'
                      '${item.isMathValid ? ' ✓' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (item.total > 0)
                  Text(
                    'الإجمالي: ${_fmt(item.total)} DA'
                        '${mismatch ? ' — لا يطابق الكمية × السعر' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: mismatch ? Colors.orange : Colors.grey.shade600),
                  ),
                if (item.applied)
                  const Text('✔ تم التحديث',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))
                else if (item.needsReview)
                  const Text('تحتاج مراجعة يدوية قبل التحديث',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                if (item.matchedProduct != null)
                  Row(children: [
                    Expanded(
                      child: Text(
                        item.autoMatched
                            ? '🔗 ربط تلقائي: ${item.matchedProduct!.name} — تحقق'
                            : '✅ مرتبط بـ: ${item.matchedProduct!.name}',
                        style: TextStyle(
                            color: item.autoMatched ? Colors.orange : Colors.green, fontSize: 11),
                      ),
                    ),
                    if (!item.applied)
                      TextButton(
                        onPressed: locked ? null : () => _showMatchDialog(item),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 6)),
                        child: const Text('تغيير', style: TextStyle(fontSize: 11)),
                      ),
                  ])
                else
                  TextButton(
                    onPressed: locked ? null : () => _showMatchDialog(item),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerRight),
                    child: const Text('ربط بمنتج من المخزن',
                        style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                Row(children: [
                  if (item.colisage <= 1) ...[
                    _miniChip('كرتون', item.isCarton,
                        locked ? null : () => setState(() => item.isCarton = true)),
                    _miniChip('حبة', !item.isCarton,
                        locked ? null : () => setState(() => item.isCarton = false)),
                  ] else
                    Text('الكرتون = ${item.colisage} حبة (السعر للحبة)',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  const Spacer(),
                  _iconBtn(Icons.swap_horiz, 'تبديل الكمية والسعر', null,
                      locked ? null : () => _swapQtyPrice(item)),
                  _iconBtn(Icons.edit, 'تعديل', null, locked ? null : () => _showEditDialog(item)),
                  _iconBtn(Icons.delete_outline, 'حذف', Colors.red,
                      locked ? null : () => setState(() => _detectedItems.remove(item))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _swapQtyPrice(DetectedInvoiceItem item) {
    setState(() {
      final oldQty = item.quantity;
      item.quantity = item.price.round();
      item.price = oldQty.toDouble();
      item.total = item.lineTotal;
      item.needsReview = false;
      item.isSelected = item.quantity > 0;
    });
  }

  // ══════════════════════════════════
  //  ربط صنف بمنتج
  // ══════════════════════════════════
  Future<void> _showMatchDialog(DetectedInvoiceItem item) async {
    List<Product> products;
    List<Category> categories;
    List<Brand> brands;
    try {
      products = await DataService.getAllProducts();
      categories = await DataService.getCategories();
      brands = await DataService.getBrands();
    } catch (e) {
      _snack('تعذر تحميل المنتجات: $e', color: Colors.red);
      return;
    }
    if (!mounted) return;

    final scored = products
        .map((p) => MapEntry(p, _similarity(item.rawText, p.name)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String query = '';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setSt) {
        final q = query.trim();
        final visible = q.isEmpty
            ? scored
            : scored.where((e) => e.key.name.toLowerCase().contains(q)).toList();
        return AlertDialog(
          title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ربط صنف'),
            ElevatedButton(
              onPressed: () => _showQuickAdd(item, categories, brands, dialogContext),
              child: const Text('جديد'),
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: Column(children: [
              TextField(
                decoration: const InputDecoration(hintText: 'بحث...'),
                onChanged: (v) => setSt(() => query = v.toLowerCase()),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    // ✅ أقرب 3 منتجات بالاسم تظهر أولاً كاقتراحات
                    final suggested = q.isEmpty && i < 3 && e.value >= 0.3;
                    return ListTile(
                      dense: true,
                      title: Text(e.key.name),
                      trailing: suggested
                          ? const Text('مقترح',
                          style: TextStyle(color: Colors.green, fontSize: 11))
                          : null,
                      onTap: () async {
                        try {
                          await DataService.saveSupplierMapping(item.rawText, e.key.id);
                        } catch (_) {}
                        if (!mounted) return;
                        setState(() {
                          item.matchedProduct = e.key;
                          item.autoMatched = false;
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _showQuickAdd(DetectedInvoiceItem item, List<Category> cats,
      List<Brand> brs, BuildContext matchCtx) async {
    final nCtrl = TextEditingController(text: item.rawText);
    final upcCtrl = TextEditingController(text: item.colisage > 1 ? '${item.colisage}' : '1');
    Category? selCat;
    Brand? selBrand;
    String? error;

    final res = await showDialog<Product>(
      context: matchCtx,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('منتج جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
              DropdownButtonFormField<Brand>(
                decoration: const InputDecoration(labelText: 'العلامة التجارية'),
                items: brs.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                onChanged: (v) => setSt(() => selBrand = v),
              ),
              DropdownButtonFormField<Category>(
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (v) => setSt(() => selCat = v),
              ),
              TextField(
                controller: upcCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد الحبات في الكرتون'),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيُنشأ المنتج غير متوفر حتى تحدد أسعار البيع من الإدارة.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ]),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (selBrand == null) {
                  setSt(() => error = 'اختر العلامة التجارية أولاً');
                  return;
                }
                if (nCtrl.text.trim().isEmpty) {
                  setSt(() => error = 'أدخل اسم المنتج');
                  return;
                }
                final parsedUpc = int.tryParse(upcCtrl.text.trim()) ?? 1;
                final upc = parsedUpc > 0 ? parsedUpc : 1;
                // مع Colisage السعر المطبوع هو سعر الحبة أصلاً
                final unitBuy =
                (item.isCarton && item.colisage <= 1) ? item.price / upc : item.price;
                final p = Product(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  brandId: selBrand!.id,
                  categoryId: selCat?.id ?? '',
                  name: nCtrl.text.trim(),
                  priceCartonNormal: 0,
                  priceUnitNormal: 0,
                  priceCartonSpecial: 0,
                  priceUnitSpecial: 0,
                  isAvailable: false, // ✅ لا يظهر للبيع حتى تُحدَّد الأسعار
                  purchasePrice: unitBuy,
                  stockQuantity: 0,
                  unitsPerCarton: upc,
                );
                try {
                  await DataService.saveProduct(p);
                  await DataService.saveSupplierMapping(item.rawText, p.id);
                } catch (e) {
                  setSt(() => error = 'تعذر حفظ المنتج: $e');
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context, p);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (res != null) {
      if (!mounted) return;
      setState(() {
        item.matchedProduct = res;
        item.autoMatched = false;
        _products = [..._products, res];
      });
      if (matchCtx.mounted) Navigator.pop(matchCtx);
    }
  }

  // ══════════════════════════════════
  //  تعديل / إضافة يدوية
  // ══════════════════════════════════
  Future<void> _showEditDialog(DetectedInvoiceItem item) async {
    final q = TextEditingController(text: item.quantity.toString());
    final c = TextEditingController(text: item.colisage.toString());
    final p = TextEditingController(text: _fmt(item.price));
    bool isCarton = item.isCarton;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('تعديل'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: q,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية')),
              TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Colisage (عدد الحبات في الوحدة — 1 إن لم يوجد)')),
              TextField(
                  controller: p,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'السعر')),
              const SizedBox(height: 10),
              Row(children: [
                ChoiceChip(
                    label: const Text('كرتون'),
                    selected: isCarton,
                    onSelected: (_) => setSt(() => isCarton = true)),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('حبة'),
                    selected: !isCarton,
                    onSelected: (_) => setSt(() => isCarton = false)),
                const Spacer(),
                IconButton(
                  tooltip: 'تبديل الكمية والسعر',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    final qv = double.tryParse(q.text.trim().replaceAll(',', '.')) ?? 0;
                    final pv = double.tryParse(p.text.trim().replaceAll(',', '.')) ?? 0;
                    q.text = pv.round().toString();
                    p.text = _fmt(qv);
                  },
                ),
              ]),
            ]),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final newQty =
                (double.tryParse(q.text.trim().replaceAll(',', '.')) ?? item.quantity.toDouble())
                    .round();
                final newPrice =
                    double.tryParse(p.text.trim().replaceAll(',', '.')) ?? item.price;
                final newCol = int.tryParse(c.text.trim()) ?? item.colisage;
                setState(() {
                  item.quantity = newQty;
                  item.price = newPrice;
                  item.colisage = newCol < 1 ? 1 : newCol;
                  item.isCarton = isCarton;
                  item.total = item.lineTotal;
                  // بعد تأكيد المستخدم للأرقام لم تعد تخميناً
                  item.needsReview = false;
                  item.isSelected = item.quantity > 0;
                });
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddManualDialog() async {
    final n = TextEditingController();
    final q = TextEditingController(text: '1');
    final p = TextEditingController();
    bool isCarton = true;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('إضافة صنف يدوياً'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'اسم الصنف')),
              TextField(
                  controller: q,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية')),
              TextField(
                  controller: p,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'السعر')),
              const SizedBox(height: 10),
              Row(children: [
                ChoiceChip(
                    label: const Text('كرتون'),
                    selected: isCarton,
                    onSelected: (_) => setSt(() => isCarton = true)),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('حبة'),
                    selected: !isCarton,
                    onSelected: (_) => setSt(() => isCarton = false)),
              ]),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(q.text.trim().replaceAll(',', '.')) ?? 0;
                if (n.text.trim().isEmpty) {
                  setSt(() => error = 'أدخل اسم الصنف');
                  return;
                }
                if (qty <= 0) {
                  setSt(() => error = 'أدخل كمية أكبر من صفر');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final name = n.text.trim();
    final qty = (double.tryParse(q.text.trim().replaceAll(',', '.')) ?? 0).round();
    final price = double.tryParse(p.text.trim().replaceAll(',', '.')) ?? 0;
    final match = await _findMatch(name);
    if (!mounted) return;
    setState(() {
      _detectedItems.add(DetectedInvoiceItem(
        rawText: name,
        quantity: qty,
        price: price,
        total: qty * price,
        isMathValid: false,
        matchedProduct: match.product,
        autoMatched: match.auto,
        isCarton: isCarton,
        isSelected: qty > 0,
        needsReview: false,
      ));
    });
  }
}

// ══════════════════════════════════
//  نماذج مساعدة
// ══════════════════════════════════
class _MatchResult {
  final Product? product;
  final bool auto;
  _MatchResult(this.product, this.auto);
}

/// كلمة مقروءة من OCR مع موضعها
class _Word {
  final String text;
  final Rect box;
  _Word(this.text, this.box);
  double get cy => box.center.dy;
}

/// رقم مقروء مع معرفة هل يحمل كسوراً (مثل 560.00)
class _Num {
  final double v;
  final bool dec;
  _Num(this.v, this.dec);
}

class _PlanLine {
  final Product product;               // النسخة الحديثة من قاعدة البيانات
  final int addUnits;                  // الكمية المضافة بالحبات
  final double newPurchase;            // سعر الشراء الجديد للحبة
  final List<DetectedInvoiceItem> sources;
  _PlanLine({
    required this.product,
    required this.addUnits,
    required this.newPurchase,
    required this.sources,
  });
}

class _ApplyPlan {
  final List<_PlanLine> lines;
  final int skipped;
  _ApplyPlan(this.lines, this.skipped);

  double get totalValue => lines.fold(
      0.0,
          (sum, l) =>
      sum + l.sources.fold(0.0, (s, it) => s + it.lineTotal));
}

class _ParsedNumbers {
  final int quantity;
  final int colisage;
  final double price;
  final double total;
  final bool isMathValid;
  _ParsedNumbers({
    required this.quantity,
    this.colisage = 1,
    required this.price,
    required this.total,
    required this.isMathValid,
  });
}

class DetectedInvoiceItem {
  String rawText;
  int quantity;
  int colisage;       // ✅ عدد الحبات في الوحدة (عمود Colisage) — 1 إن لم يوجد
  double price;
  double total;
  bool isMathValid;
  Product? matchedProduct;
  bool isSelected;
  bool needsReview;
  bool isCarton;      // ✅ الكمية بالكرتون (true) أو بالحبة (false)
  bool autoMatched;   // ✅ رُبط تلقائياً بالاسم (يحتاج تحققاً)
  bool applied;       // ✅ تمّ تحديث المخزن به (لا يُطبَّق مرتين)
  DetectedInvoiceItem({
    required this.rawText,
    required this.quantity,
    this.colisage = 1,
    required this.price,
    this.total = 0,
    this.isMathValid = false,
    this.matchedProduct,
    this.isSelected = true,
    this.needsReview = false,
    this.isCarton = true,
    this.autoMatched = false,
    this.applied = false,
  });

  /// المبلغ = الكمية × Colisage × السعر
  double get lineTotal => quantity * (colisage > 1 ? colisage : 1) * price;
}