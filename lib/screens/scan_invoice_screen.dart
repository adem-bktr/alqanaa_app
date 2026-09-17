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
      if (mounted) setState(() => _isProcessing = false);
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

      List<List<TextLine>> rows = [];
      if (allLines.isNotEmpty) {
        List<TextLine> currentRow = [allLines[0]];
        for (int i = 1; i < allLines.length; i++) {
          if ((allLines[i].boundingBox.top - currentRow.last.boundingBox.top).abs() < 15) {
            currentRow.add(allLines[i]);
          } else {
            rows.add(List.from(currentRow));
            currentRow = [allLines[i]];
          }
        }
        rows.add(currentRow);
      }

      List<DetectedInvoiceItem> items = [];
      for (var row in rows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        String text = row.map((l) => l.text).join(' ');
        final nums = RegExp(r'\d+([.,]\d+)?').allMatches(text).map((m) => toDouble(m.group(0))).toList();
        
        if (nums.isNotEmpty) {
          String name = text.replaceAll(RegExp(r'\d+([.,]\d+)?'), '').replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ').trim();
          if (name.length > 2 || nums.length >= 2) {
            final mappedId = await DataService.getMappedProductId(name);
            Product? matched = mappedId != null ? await DataService.getProductById(mappedId) : null;

            double q = 0, p = 0, t = 0;
            bool math = false;
            if (nums.length >= 3) {
              for(int i=0; i<nums.length; i++) for(int j=0; j<nums.length; j++) if(i!=j) for(int k=0; k<nums.length; k++) if(k!=i && k!=j) {
                if ((nums[i]! * nums[j]! - nums[k]!).abs() < 2.0) {
                  q = nums[i]! < nums[j]! ? nums[i]! : nums[j]!;
                  p = nums[i]! < nums[j]! ? nums[j]! : nums[i]!;
                  t = nums[k]!; math = true; break;
                }
              }
            } else if (nums.length == 2) { q = nums[0]! < nums[1]! ? nums[0]! : nums[1]!; p = nums[0]! < nums[1]! ? nums[1]! : nums[0]!; }
            else { p = nums[0]!; }

            if (p > 100000 || q > 5000) continue;
            items.add(DetectedInvoiceItem(rawText: name.isEmpty ? "صنف مجهول" : name, quantity: q.toInt(), price: p, total: t, isMathValid: math, matchedProduct: matched));
          }
        }
      }
      if (!_isDisposed) setState(() { _detectedItems = items; _isProcessing = false; });
    } catch (e) {
      if (!_isDisposed) setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyUpdates() async {
    int count = 0;
    for (var item in _detectedItems) {
      if (item.matchedProduct != null && item.isSelected) {
        final p = item.matchedProduct!;
        double unitBuy = item.price / (p.unitsPerCarton > 0 ? p.unitsPerCarton : 1);
        final updated = Product(
          id: p.id, brandId: p.brandId, categoryId: p.categoryId, name: p.name,
          priceCartonNormal: p.priceCartonNormal, priceUnitNormal: p.priceUnitNormal,
          priceCartonSpecial: p.priceCartonSpecial, priceUnitSpecial: p.priceUnitSpecial,
          imagePath: p.imagePath, isAvailable: p.isAvailable, discount: p.discount, sellType: p.sellType,
          maxQtyNormal: p.maxQtyNormal, maxQtySpecial: p.maxQtySpecial, flavors: p.flavors, isFeatured: p.isFeatured,
          purchasePrice: unitBuy > 0 ? unitBuy : p.purchasePrice, stockQuantity: p.stockQuantity + (item.quantity * p.unitsPerCarton),
          unitsPerCarton: p.unitsPerCarton,
        );
        await DataService.updateProduct(updated);
        count++;
      }
    }
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم تحديث $count منتج'), backgroundColor: Colors.green)); Navigator.pop(context); }
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
          else Expanded(child: ListView.builder(itemCount: _detectedItems.length, itemBuilder: (context, i) => _buildRow(_detectedItems[i], i))),
          if (_detectedItems.isNotEmpty) Padding(padding: const EdgeInsets.all(15), child: ElevatedButton(onPressed: _applyUpdates, child: const Text('تحديث المخزن', style: TextStyle(color: Colors.white)))),
        ]
      ]),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF2E7D32))), const SizedBox(height: 5), Text(label)]));

  Widget _buildRow(DetectedInvoiceItem item, int i) => Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
    leading: Checkbox(value: item.isSelected, onChanged: (v) => setState(() => item.isSelected = v!)),
    title: Text(item.rawText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الكمية: ${item.quantity} كرتون | السعر: ${item.price} DA', style: const TextStyle(fontSize: 11)),
      if (item.matchedProduct != null) Text('✅ مرتبط بـ: ${item.matchedProduct!.name}', style: const TextStyle(color: Colors.green, fontSize: 11))
      else TextButton(onPressed: () => _showMatchDialog(item), child: const Text('ربط بمنتج من المخزن', style: TextStyle(color: Colors.red, fontSize: 11))),
    ]),
    trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditDialog(item)),
  ));

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
          return ListTile(title: Text(products[i].name), onTap: () async { await DataService.saveSupplierMapping(item.rawText, products[i].id); setState(() => item.matchedProduct = products[i]); Navigator.pop(context); });
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
      actions: [ElevatedButton(onPressed: () async { if(selBrand==null) return; final p = Product(id: DateTime.now().millisecondsSinceEpoch.toString(), brandId: selBrand!.id, categoryId: selCat?.id ?? '', name: nCtrl.text, priceCartonNormal: 0, priceUnitNormal: 0, priceCartonSpecial: 0, priceUnitSpecial: 0, purchasePrice: item.price, stockQuantity: 0); await DataService.saveProduct(p); await DataService.saveSupplierMapping(item.rawText, p.id); Navigator.pop(context, p); }, child: const Text('حفظ'))],
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
      actions: [ElevatedButton(onPressed: () { setState(() { item.quantity = int.tryParse(q.text) ?? item.quantity; item.price = double.tryParse(p.text) ?? item.price; }); Navigator.pop(context); }, child: const Text('حفظ'))],
    ));
  }
}

class DetectedInvoiceItem {
  String rawText; int quantity; double price; double total; bool isMathValid; Product? matchedProduct; bool isSelected;
  DetectedInvoiceItem({required this.rawText, required this.quantity, required this.price, this.total = 0, this.isMathValid = false, this.matchedProduct, this.isSelected = true});
}
