import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../utils/converters.dart';

class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({super.key});

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  File? _image;
  bool _isProcessing = false;
  List<DetectedInvoiceItem> _detectedItems = [];
  bool _isDisposed = false;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Sanity bounds — reject numbers that are almost certainly not
  // quantity/price/total (phone numbers, dates, random codes on the invoice).
  static const double _maxPlausiblePrice = 100000;
  static const double _maxPlausibleQty = 5000;
  // How close qty * price must be to total (relative error) to be
  // trusted automatically.
  static const double _mathTolerance = 0.05;

  @override
  void dispose() {
    _isDisposed = true;
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _detectedItems = [];
          _isProcessing = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isDisposed) _processImage(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصورة: $e')),
        );
      }
    }
  }

  Future<void> _processImage(String path) async {
    if (_isDisposed) return;
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      List<TextLine> allLines = [];
      for (TextBlock block in recognizedText.blocks) {
        allLines.addAll(block.lines);
      }
      allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      // Group lines into rows using a threshold that adapts to the actual
      // text size in this image, instead of a fixed pixel value. A fixed
      // threshold breaks across different phones/zoom levels/photo angles.
      final rows = _groupIntoRows(allLines);

      List<DetectedInvoiceItem> items = [];
      for (var row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        String text = row.map((l) => l.text).join(' ');
        final nums = RegExp(r'\d+([.,]\d+)?')
            .allMatches(text)
            .map((m) => toDouble(m.group(0)))
            .whereType<double>()
            .toList();

        if (nums.isEmpty) continue;

        String name = text
            .replaceAll(RegExp(r'\d+([.,]\d+)?'), '')
            .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
            .trim();
        if (name.length <= 2 && nums.length < 2) continue;

        final mappedId = await DataService.getMappedProductId(name);
        Product? matched =
        mappedId != null ? await DataService.getProductById(mappedId) : null;

        final parsed = _resolveQuantityPriceTotal(nums);
        if (parsed == null) continue; // every number failed sanity bounds

        items.add(DetectedInvoiceItem(
          rawText: name.isEmpty ? "صنف مجهول" : name,
          quantity: parsed.quantity,
          price: parsed.price,
          total: parsed.total,
          isMathValid: parsed.isMathValid,
          matchedProduct: matched,
          // Only pre-select rows we're reasonably confident about. A row
          // with quantity <= 0, or a single ambiguous number, needs a human
          // to look at it before it touches stock — it should never be
          // silently applied.
          isSelected: parsed.quantity > 0 && (parsed.isMathValid || nums.length >= 2),
          needsReview: !(parsed.isMathValid || nums.length >= 2) || parsed.quantity <= 0,
        ));
      }
      if (!_isDisposed) setState(() { _detectedItems = items; _isProcessing = false; });
    } catch (e) {
      if (!_isDisposed) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر قراءة الفاتورة: $e')),
          );
        }
      }
    }
  }

  /// Groups OCR lines into visual rows. Threshold scales with the median
  /// line height detected in the image rather than a fixed pixel count.
  List<List<TextLine>> _groupIntoRows(List<TextLine> allLines) {
    if (allLines.isEmpty) return [];

    final heights = allLines.map((l) => l.boundingBox.height).toList()..sort();
    final medianHeight = heights[heights.length ~/ 2];
    // Rows are grouped if their vertical centers are within ~60% of a
    // typical line's height — tight enough to separate real rows, loose
    // enough to tolerate slight photo skew.
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

  /// Picks the best interpretation of the numbers found on a row.
  /// Returns null if nothing on the row passes basic sanity checks.
  _ParsedNumbers? _resolveQuantityPriceTotal(List<double> nums) {
    final plausible = nums
        .where((n) => n <= _maxPlausiblePrice && n >= 0)
        .toList();
    if (plausible.isEmpty) return null;

    if (plausible.length >= 3) {
      // Try every ordered triple (qty, price, total) and keep the one with
      // the smallest relative error — instead of the first coincidental
      // match, which was the old (buggy) behavior.
      double bestError = double.infinity;
      double bestQty = 0, bestPrice = 0, bestTotal = 0;
      bool foundValid = false;

      for (int i = 0; i < plausible.length; i++) {
        for (int j = 0; j < plausible.length; j++) {
          if (i == j) continue;
          final a = plausible[i], b = plausible[j];
          final qty = a < b ? a : b;
          final price = a < b ? b : a;
          if (qty > _maxPlausibleQty) continue;
          for (int k = 0; k < plausible.length; k++) {
            if (k == i || k == j) continue;
            final total = plausible[k];
            final expected = qty * price;
            final denom = total.abs() > 1 ? total.abs() : 1;
            final relError = (expected - total).abs() / denom;
            if (relError < bestError) {
              bestError = relError;
              bestQty = qty;
              bestPrice = price;
              bestTotal = total;
            }
          }
        }
      }
      foundValid = bestError < _mathTolerance;
      if (foundValid) {
        return _ParsedNumbers(
            quantity: bestQty.toInt(), price: bestPrice, total: bestTotal, isMathValid: true);
      }
      // No triple lined up — fall back to treating the two largest as
      // qty/price like the 2-number case, flagged as unconfirmed.
      final sorted = List<double>.from(plausible)..sort();
      final price = sorted.last;
      final qty = sorted[sorted.length - 2];
      if (qty <= _maxPlausibleQty) {
        return _ParsedNumbers(quantity: qty.toInt(), price: price, total: 0, isMathValid: false);
      }
      return _ParsedNumbers(quantity: 0, price: price, total: 0, isMathValid: false);
    } else if (plausible.length == 2) {
      final a = plausible[0], b = plausible[1];
      final qty = a < b ? a : b;
      final price = a < b ? b : a;
      if (qty > _maxPlausibleQty) {
        return _ParsedNumbers(quantity: 0, price: price, total: 0, isMathValid: false);
      }
      return _ParsedNumbers(quantity: qty.toInt(), price: price, total: 0, isMathValid: false);
    } else {
      // Single number on the row — we genuinely don't know if it's a
      // quantity or a price. Surface it for manual review rather than
      // guessing quantity = 0 (which used to silently update purchase
      // price without ever touching stock).
      return _ParsedNumbers(quantity: 0, price: plausible.first, total: 0, isMathValid: false);
    }
  }

  Future<void> _applyUpdates() async {
    int updated = 0;
    int skipped = 0;
    for (var item in _detectedItems) {
      if (!item.isSelected) continue;
      if (item.matchedProduct == null) { skipped++; continue; }
      if (item.quantity <= 0) { skipped++; continue; }

      final p = item.matchedProduct!;
      double unitBuy = item.price / (p.unitsPerCarton > 0 ? p.unitsPerCarton : 1);
      final updatedProduct = Product(
        id: p.id, brandId: p.brandId, categoryId: p.categoryId, name: p.name,
        priceCartonNormal: p.priceCartonNormal, priceUnitNormal: p.priceUnitNormal,
        priceCartonSpecial: p.priceCartonSpecial, priceUnitSpecial: p.priceUnitSpecial,
        imagePath: p.imagePath, isAvailable: p.isAvailable, discount: p.discount, sellType: p.sellType,
        maxQtyNormal: p.maxQtyNormal, maxQtySpecial: p.maxQtySpecial, flavors: p.flavors, isFeatured: p.isFeatured,
        purchasePriceCarton: item.price > 0 ? item.price : p.purchasePriceCarton,
        purchasePriceUnit: unitBuy > 0 ? unitBuy : p.purchasePriceUnit,
        stockQuantity: p.stockQuantity + (item.quantity * p.unitsPerCarton),
        unitsPerCarton: p.unitsPerCarton,
      );
      await DataService.updateProduct(updatedProduct);
      updated++;
    }
    if (mounted) {
      final message = skipped > 0
          ? '✅ تم تحديث $updated منتج — تم تجاوز $skipped صنف يحتاج مراجعة يدوية'
          : '✅ تم تحديث $updated منتج';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: skipped > 0 ? Colors.orange : Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سكان فاتورة مورد'), backgroundColor: const Color(0xFF2E7D32)),
      body: Column(children: [
        if (_image == null) Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('صوّر الفاتورة أو اخترها من الألبوم'),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _btn(Icons.camera_alt, 'كاميرا', () => _pickImage(ImageSource.camera)),
            const SizedBox(width: 30),
            _btn(Icons.photo_library, 'الألبوم', () => _pickImage(ImageSource.gallery)),
          ])
        ]))) else ...[
          Container(height: 150, width: double.infinity, margin: const EdgeInsets.all(10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover))),
          if (_isProcessing) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          else if (_detectedItems.isEmpty) const Expanded(child: Center(child: Text('لم يتم التعرف على أي أصناف — حاول صورة أوضح')))
          else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 5),
                  Expanded(child: Text(
                    'الأصناف المميزة بـ ⚠️ تحتاج مراجعتك قبل التحديث',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  )),
                ]),
              ),
              Expanded(child: ListView.builder(itemCount: _detectedItems.length, itemBuilder: (context, i) => _buildRow(_detectedItems[i], i))),
            ],
          if (_detectedItems.isNotEmpty) Padding(padding: const EdgeInsets.all(15), child: ElevatedButton(onPressed: _applyUpdates, child: const Text('تحديث المخزن', style: TextStyle(color: Colors.white)))),
        ]
      ]),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF2E7D32))), const SizedBox(height: 5), Text(label)]));

  Widget _buildRow(DetectedInvoiceItem item, int i) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    color: item.needsReview ? Colors.orange.withOpacity(0.06) : null,
    child: ListTile(
      leading: Checkbox(value: item.isSelected, onChanged: (v) => setState(() => item.isSelected = v!)),
      title: Row(children: [
        if (item.needsReview) const Padding(padding: EdgeInsets.only(right: 4), child: Text('⚠️')),
        Expanded(child: Text(item.rawText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'الكمية: ${item.quantity} كرتون | السعر: ${item.price} DA'
              '${item.isMathValid ? ' ✓' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        if (item.needsReview)
          const Text('تحتاج مراجعة يدوية قبل التحديث', style: TextStyle(color: Colors.orange, fontSize: 11)),
        if (item.matchedProduct != null) Text('✅ مرتبط بـ: ${item.matchedProduct!.name}', style: const TextStyle(color: Colors.green, fontSize: 11))
        else TextButton(onPressed: () => _showMatchDialog(item), child: const Text('ربط بمنتج من المخزن', style: TextStyle(color: Colors.red, fontSize: 11))),
      ]),
      trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditDialog(item)),
    ),
  );

  Future<void> _showMatchDialog(DetectedInvoiceItem item) async {
    final products = await DataService.getAllProducts();
    final categories = await DataService.getCategories();
    final brands = await DataService.getBrands();
    String query = '';
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setSt) => AlertDialog(
      title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ربط صنف'), ElevatedButton(onPressed: () => _showQuickAdd(item, categories, brands), child: const Text('جديد'))]),
      content: SizedBox(width: double.maxFinite, height: 300, child: Column(children: [
        TextField(decoration: const InputDecoration(hintText: 'بحث...'), onChanged: (v) => setSt(() => query = v.toLowerCase())),
        Expanded(child: ListView.builder(itemCount: products.length, itemBuilder: (context, i) {
          if (query.isNotEmpty && !products[i].name.toLowerCase().contains(query)) return const SizedBox.shrink();
          return ListTile(title: Text(products[i].name), onTap: () async { await DataService.saveSupplierMapping(item.rawText, products[i].id); setState(() { item.matchedProduct = products[i]; }); Navigator.pop(context); });
        }))
      ])),
    )));
  }

  Future<void> _showQuickAdd(DetectedInvoiceItem item, List<Category> cats, List<Brand> brs) async {
    final nCtrl = TextEditingController(text: item.rawText);
    Category? selCat; Brand? selBrand;
    final res = await showDialog<Product>(context: context, builder: (context) => StatefulBuilder(builder: (context, setSt) => AlertDialog(
      title: const Text('منتج جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
        DropdownButtonFormField<Brand>(items: brs.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(), onChanged: (v) => setSt(() => selBrand = v)),
        DropdownButtonFormField<Category>(items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(), onChanged: (v) => setSt(() => selCat = v)),
      ]),
      actions: [ElevatedButton(onPressed: () async {
        if (selBrand == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العلامة التجارية أولاً')));
          return;
        }
        if (nCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم المنتج')));
          return;
        }
        final p = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(), 
          brandId: selBrand!.id, 
          categoryId: selCat?.id ?? '', 
          name: nCtrl.text.trim(), 
          priceCartonNormal: 0, priceUnitNormal: 0, 
          priceCartonSpecial: 0, priceUnitSpecial: 0, 
          purchasePriceCarton: item.price,
          purchasePriceUnit: item.price / 1,
          stockQuantity: 0
        );
        await DataService.saveProduct(p);
        await DataService.saveSupplierMapping(item.rawText, p.id);
        Navigator.pop(context, p);
      }, child: const Text('حفظ'))],
    )));
    if (res != null) { setState(() => item.matchedProduct = res); Navigator.pop(context); }
  }

  Future<void> _showEditDialog(DetectedInvoiceItem item) async {
    final q = TextEditingController(text: item.quantity.toString());
    final p = TextEditingController(text: item.price.toString());
    await showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('تعديل'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
        TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
      ]),
      actions: [ElevatedButton(onPressed: () {
        setState(() {
          item.quantity = int.tryParse(q.text) ?? item.quantity;
          item.price = double.tryParse(p.text) ?? item.price;
          // Once the user manually confirms the numbers, it's no longer
          // an unreviewed guess — safe to auto-select if a quantity exists.
          item.needsReview = false;
          item.isSelected = item.quantity > 0;
        });
        Navigator.pop(context);
      }, child: const Text('حفظ'))],
    ));
  }
}

class _ParsedNumbers {
  final int quantity;
  final double price;
  final double total;
  final bool isMathValid;
  _ParsedNumbers({required this.quantity, required this.price, required this.total, required this.isMathValid});
}

class DetectedInvoiceItem {
  String rawText;
  int quantity;
  double price;
  double total;
  bool isMathValid;
  Product? matchedProduct;
  bool isSelected;
  bool needsReview;
  DetectedInvoiceItem({
    required this.rawText,
    required this.quantity,
    required this.price,
    this.total = 0,
    this.isMathValid = false,
    this.matchedProduct,
    this.isSelected = true,
    this.needsReview = false,
  });
}