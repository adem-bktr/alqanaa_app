import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:http/http.dart' as http;

import '../models/models.dart' as app_models;
import '../utils/converters.dart';

class DataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // ══════════════════════════════════════════════════════
  //   🔧 أدوات مساعدة
  // ══════════════════════════════════════════════════════
  static int _colorValue(Color c) {
    // ignore: deprecated_member_use
    return c.value;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// تحويل مستند Firestore إلى Map مع id
  static Map<String, dynamic> _doc(DocumentSnapshot<Map<String, dynamic>> d) {
    return {...(d.data() ?? {}), 'id': d.id};
  }

  static Map<String, dynamic> _qDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    return {...d.data(), 'id': d.id};
  }

  // ══════════════════════════════════════════════════════
  //   📷 الصور
  // ══════════════════════════════════════════════════════
  static Future<String> uploadImage(String filePath, String folder) async {
    if (filePath.isEmpty) return '';
    try {
      debugPrint('🚀 بدء رفع الصورة: $filePath في مجلد $folder');
      final name = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref().child('$folder/$name.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        debugPrint('🌐 استخدام وضع الويب للرفع...');
        Uint8List? bytes;
        try {
          final xFile = XFile(filePath);
          bytes = await xFile.readAsBytes();
          debugPrint('✅ تم قراءة البيانات باستخدام XFile (${bytes.length} bytes)');
        } catch (e) {
          debugPrint('⚠️ XFile failed: $e. Trying fetch/http...');
          try {
            final response = await http.get(Uri.parse(filePath));
            bytes = response.bodyBytes;
            debugPrint('✅ تم قراءة البيانات باستخدام http.get (${bytes.length} bytes)');
          } catch (e2) {
            debugPrint('❌ فشل كلي في قراءة بيانات الصورة على الويب: $e2');
            return '';
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          final uploadTask = ref.putData(bytes, metadata);
          final snapshot = await uploadTask;
          final url = await snapshot.ref.getDownloadURL();
          debugPrint('📤 تم الرفع بنجاح (ويب): $url');
          return url;
        } else {
          debugPrint('❌ بيانات الصورة فارغة');
          return '';
        }
      } else {
        debugPrint('📱 استخدام وضع الهاتف للرفع...');
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('⚠️ الملف غير موجود محلياً: $filePath');
          return '';
        }
        final uploadTask = ref.putFile(file, metadata);
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        debugPrint('📤 تم الرفع بنجاح (هاتف): $url');
        return url;
      }
    } catch (e) {
      debugPrint('❌ خطأ حرج في uploadImage: $e');
      return '';
    }
  }

  static Future<void> deleteImageFromStorage(String imageUrl) async {
    if (imageUrl.trim().isEmpty) return;
    if (!imageUrl.startsWith('http')) return;
    try {
      await _storage.refFromURL(imageUrl).delete();
      debugPrint('🗑️ تم حذف الصورة');
    } catch (e) {
      debugPrint('⚠️ deleteImage: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //   🗂️ الفئات
  // ══════════════════════════════════════════════════════
  static Future<List<app_models.Category>> getCategories() async {
    try {
      final snap = await _db.collection('categories').get();
      final list = snap.docs
          .map((d) => app_models.Category.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) {
        final c = a.order.compareTo(b.order);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
      return list;
    } catch (e) {
      debugPrint('❌ getCategories: $e');
      return [];
    }
  }

  static Stream<List<app_models.Category>> getCategoriesStream() {
    return _db.collection('categories').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => app_models.Category.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  static Future<void> saveCategory(app_models.Category category) async {
    await _db.collection('categories').doc(category.id).set({
      'name': category.name,
      'icon': category.icon,
      'order': category.order,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ فئة محفوظة: ${category.name}');
  }

  static Future<void> deleteCategory(String categoryId) async {
    try {
      final batch = _db.batch();

      // فكّ ارتباط العلامات
      final brands = await _db
          .collection('brands')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      for (final d in brands.docs) {
        batch.update(d.reference, {'categoryId': ''});
      }

      // فكّ ارتباط المنتجات
      final products = await _db
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      for (final d in products.docs) {
        batch.update(d.reference, {'categoryId': ''});
      }

      batch.delete(_db.collection('categories').doc(categoryId));
      await batch.commit();
      debugPrint('🗑️ تم حذف الفئة: $categoryId');
    } catch (e) {
      debugPrint('❌ deleteCategory: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════
  //   🏪 العلامات التجارية
  // ══════════════════════════════════════════════════════
  static Future<List<app_models.Brand>> getBrands() async {
    try {
      final snap = await _db.collection('brands').get();
      final list =
      snap.docs.map((d) => app_models.Brand.fromJson(_qDoc(d))).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getBrands: $e');
      return [];
    }
  }

  static Future<List<app_models.Brand>> getBrandsByCategory(
      String categoryId) async {
    try {
      if (categoryId.isEmpty) return getBrands();
      final snap = await _db
          .collection('brands')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      final list =
      snap.docs.map((d) => app_models.Brand.fromJson(_qDoc(d))).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getBrandsByCategory: $e');
      return [];
    }
  }

  static Future<app_models.Brand?> getBrandById(String brandId) async {
    try {
      if (brandId.isEmpty) return null;
      final doc = await _db.collection('brands').doc(brandId).get();
      if (!doc.exists) return null;
      return app_models.Brand.fromJson(_doc(doc));
    } catch (e) {
      debugPrint('❌ getBrandById: $e');
      return null;
    }
  }

  static Future<void> saveBrand(app_models.Brand brand,
      {String? logoPath}) async {
    String logoUrl = brand.logoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      final url = await uploadImage(logoPath, 'brands');
      if (url.isNotEmpty) logoUrl = url;
    }
    await _db.collection('brands').doc(brand.id).set({
      'name': brand.name,
      'logoPath': logoUrl,
      'categoryId': brand.categoryId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ علامة محفوظة: ${brand.name}');
  }

  static Future<void> updateBrand(app_models.Brand brand,
      {String? logoPath}) async {
    String logoUrl = brand.logoPath;

    if (logoPath != null && logoPath.isNotEmpty) {
      final url = await uploadImage(logoPath, 'brands');
      if (url.isNotEmpty) {
        // حذف الشعار القديم
        if (brand.logoPath.isNotEmpty && brand.logoPath != url) {
          await deleteImageFromStorage(brand.logoPath);
        }
        logoUrl = url;
      }
    }

    await _db.collection('brands').doc(brand.id).set({
      'name': brand.name,
      'logoPath': logoUrl,
      'categoryId': brand.categoryId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✏️ تم تعديل العلامة: ${brand.name}');
  }

  static Future<void> deleteBrand(String brandId) async {
    try {
      // 1) حذف شعار العلامة
      final brandDoc = await _db.collection('brands').doc(brandId).get();
      await deleteImageFromStorage(brandDoc.data()?['logoPath'] ?? '');

      // 2) حذف المنتجات وصورها
      final products = await _db
          .collection('products')
          .where('brandId', isEqualTo: brandId)
          .get();

      final batch = _db.batch();
      for (final d in products.docs) {
        await deleteImageFromStorage(d.data()['imagePath'] ?? '');
        batch.delete(d.reference);
      }

      batch.delete(_db.collection('brands').doc(brandId));
      await batch.commit();
      debugPrint('🗑️ تم حذف العلامة و ${products.docs.length} منتج');
    } catch (e) {
      debugPrint('❌ deleteBrand: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════
  //   📦 المنتجات
  // ══════════════════════════════════════════════════════
  static Future<List<app_models.Product>> getProducts(String brandId) async {
    try {
      if (brandId.isEmpty) return [];
      final snap = await _db
          .collection('products')
          .where('brandId', isEqualTo: brandId)
          .get();
      final list =
      snap.docs.map((d) => app_models.Product.fromJson(_qDoc(d))).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getProducts: $e');
      return [];
    }
  }

  static Future<List<app_models.Product>> getAllProducts() async {
    try {
      final snap = await _db.collection('products').get();
      final list =
      snap.docs.map((d) => app_models.Product.fromJson(_qDoc(d))).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getAllProducts: $e');
      return [];
    }
  }

  static Future<List<app_models.Product>> getProductsByCategory(
      String categoryId) async {
    try {
      if (categoryId.isEmpty) return getAllProducts();
      final snap = await _db
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      final list =
      snap.docs.map((d) => app_models.Product.fromJson(_qDoc(d))).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getProductsByCategory: $e');
      return [];
    }
  }

  static Future<List<app_models.Product>> getFeaturedProducts(
      {int limit = 10}) async {
    try {
      final snap = await _db
          .collection('products')
          .where('isFeatured', isEqualTo: true)
          .limit(limit)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => app_models.Product.fromJson(_qDoc(d)))
            .toList();
      }

      // لا يوجد مميز → أعد أول منتجات
      final all = await _db.collection('products').limit(limit).get();
      return all.docs
          .map((d) => app_models.Product.fromJson(_qDoc(d)))
          .toList();
    } catch (e) {
      debugPrint('❌ getFeaturedProducts: $e');
      return [];
    }
  }

  static Future<app_models.Product?> getProductById(String id) async {
    try {
      if (id.isEmpty) return null;
      final doc = await _db.collection('products').doc(id).get();
      if (!doc.exists) return null;
      return app_models.Product.fromJson(_doc(doc));
    } catch (e) {
      debugPrint('❌ getProductById: $e');
      return null;
    }
  }

  /// بحث في كل المنتجات (client-side)
  static Future<List<app_models.Product>> searchProducts(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final all = await getAllProducts();
    return all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  static Map<String, dynamic> _productMap(app_models.Product p, String url) => {
    'brandId': p.brandId,
    'categoryId': p.categoryId,
    'name': p.name,
    'priceCartonNormal': p.priceCartonNormal,
    'priceUnitNormal': p.priceUnitNormal,
    'priceCartonSpecial': p.priceCartonSpecial,
    'priceUnitSpecial': p.priceUnitSpecial,
    'imagePath': url,
    'isAvailable': p.isAvailable,
    'discount': p.discount,
    'sellType': p.sellType.name,
    'maxQtyNormal': p.maxQtyNormal,
    'maxQtySpecial': p.maxQtySpecial,
    'flavors': p.flavors.map((f) => f.toJson()).toList(),
    'isFeatured': p.isFeatured,
    'purchasePrice': p.purchasePrice,
    'stockQuantity': p.stockQuantity,
    'unitsPerCarton': p.unitsPerCarton, // ✅ إصلاح 1: كان غير محفوظ
  };

  static Future<void> saveProduct(app_models.Product product,
      {String? imagePath}) async {
    String url = product.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      final u = await uploadImage(imagePath, 'products');
      if (u.isNotEmpty) url = u;
    }
    await _db.collection('products').doc(product.id).set({
      ..._productMap(product, url),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ منتج محفوظ: ${product.name}');
  }

  static Future<void> updateProduct(app_models.Product product,
      {String? imagePath}) async {
    String url = product.imagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      final u = await uploadImage(imagePath, 'products');
      if (u.isNotEmpty) {
        if (product.imagePath.isNotEmpty && product.imagePath != u) {
          await deleteImageFromStorage(product.imagePath);
        }
        url = u;
      }
    }

    await _db.collection('products').doc(product.id).set({
      ..._productMap(product, url),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✏️ تم تعديل المنتج: ${product.name}');
  }

  static Future<void> updateProductAvailability(
      String productId, bool isAvailable) async {
    await _db.collection('products').doc(productId).update({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateProductFeatured(
      String productId, bool isFeatured) async {
    await _db.collection('products').doc(productId).update({
      'isFeatured': isFeatured,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تحديث توفر ذوق معيّن
  static Future<void> updateFlavorAvailability(
      String productId,
      String flavorName,
      bool isAvailable,
      ) async {
    try {
      final ref = _db.collection('products').doc(productId);
      final doc = await ref.get();
      if (!doc.exists) return;

      final raw = doc.data()?['flavors'];
      if (raw is! List) return;

      final updated = raw.map((f) {
        final fm = app_models.FlavorModel.fromJson(f);
        if (fm.name == flavorName) {
          return fm.copyWith(isAvailable: isAvailable).toJson();
        }
        return fm.toJson();
      }).toList();

      await ref.update({'flavors': updated});
      debugPrint('✅ تحديث الذوق $flavorName → $isAvailable');
    } catch (e) {
      debugPrint('❌ updateFlavorAvailability: $e');
    }
  }

  static Future<void> deleteProduct(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      await deleteImageFromStorage(doc.data()?['imagePath'] ?? '');
      await _db.collection('products').doc(productId).delete();
      debugPrint('🗑️ تم حذف المنتج: $productId');
    } catch (e) {
      debugPrint('❌ deleteProduct: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════
  //   🧾 الطلبات
  // ══════════════════════════════════════════════════════
  /// ✅ ترتيب من جهة العميل — يضمن ظهور الطلبات القديمة
  /// التي لا تحتوي على حقل createdAt (orderBy يستبعدها!)
  static int _cmpOrders(app_models.Order a, app_models.Order b) {
    final da = a.createdAt ?? a.dateTime;
    final db = b.createdAt ?? b.dateTime;
    if (da != null && db != null) return db.compareTo(da);
    if (da != null) return -1;
    if (db != null) return 1;
    return b.id.compareTo(a.id);
  }

  static Stream<List<app_models.Order>> getOrdersStream({int? limit}) {
    Query<Map<String, dynamic>> q = _db.collection('orders');
    if (limit != null) q = q.limit(limit);

    return q.snapshots().map((snap) {
      final list =
      snap.docs.map((d) => app_models.Order.fromJson(_qDoc(d))).toList();
      list.sort(_cmpOrders);
      return list;
    }).handleError((e) {
      debugPrint('❌ getOrdersStream: $e');
    });
  }

  static Future<List<app_models.Order>> getAllOrders() async {
    try {
      final snap = await _db.collection('orders').get();
      final list =
      snap.docs.map((d) => app_models.Order.fromJson(_qDoc(d))).toList();
      list.sort(_cmpOrders);
      return list;
    } catch (e) {
      debugPrint('❌ getAllOrders: $e');
      return [];
    }
  }

  static Future<List<app_models.Order>> getUserOrders(String userId) async {
    try {
      if (userId.isEmpty) return [];
      // بدون orderBy → لا يحتاج فهرس مركّب
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      final list =
      snap.docs.map((d) => app_models.Order.fromJson(_qDoc(d))).toList();
      list.sort(_cmpOrders);
      return list;
    } catch (e) {
      debugPrint('❌ getUserOrders: $e');
      return [];
    }
  }

  static Stream<List<app_models.Order>> getUserOrdersStream(String userId) {
    if (userId.isEmpty) return Stream.value(<app_models.Order>[]);
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list =
      snap.docs.map((d) => app_models.Order.fromJson(_qDoc(d))).toList();
      list.sort(_cmpOrders);
      return list;
    });
  }

  static Future<app_models.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return app_models.Order.fromJson(_doc(doc));
    } catch (e) {
      debugPrint('❌ getOrderById: $e');
      return null;
    }
  }

  /// ✅ يحفظ كل الحقول + خصم المخزن
  static Future<void> saveOrder(app_models.Order order) async {
    final batch = _db.batch();

    // 1) حفظ الطلب
    batch.set(_db.collection('orders').doc(order.id), {
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'items': order.items,
      'total': order.total,
      'isSpecialPrice': order.isSpecialPrice,
      'date': order.date,
      'userId': order.userId,
      'status': order.status,
      'paidAmount': order.paidAmount,
      'remainingBalance': order.remainingBalance,
      if (order.latitude != null) 'latitude': order.latitude,
      if (order.longitude != null) 'longitude': order.longitude,
      if (order.address != null && order.address!.isNotEmpty)
        'address': order.address,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) خصم المخزن لكل منتج في الطلبية
    for (final it in order.items) {
      final pid = it['productId']?.toString() ?? '';
      if (pid.isNotEmpty) {
        final qtySold = toInt(it['quantity']);
        final isCarton = it['isCarton'] == true;

        // جلب بيانات المنتج لمعرفة عدد الحبات في الكرتون
        final pDoc = await _db.collection('products').doc(pid).get();
        if (pDoc.exists) {
          final upc = toInt(pDoc.data()?['unitsPerCarton'] ?? 1);
          final piecesToSubtract = isCarton ? (qtySold * upc) : qtySold;

          batch.update(_db.collection('products').doc(pid), {
            'stockQuantity': FieldValue.increment(-piecesToSubtract),
          });
        }
      }
    }

    await batch.commit();
    debugPrint('✅ الطلب محفوظ وتم تحديث المخزن: ${order.id}');
  }

  /// ✅ إصلاح 3: دالة مساعدة لإرجاع/خصم المخزن ضمن batch
  /// restore = true  → إرجاع الكميات للمخزن
  /// restore = false → خصم الكميات من المخزن
  static Future<void> _applyStockChange(
      WriteBatch batch,
      List items, {
        required bool restore,
      }) async {
    for (final it in items) {
      if (it is! Map) continue;
      final pid = it['productId']?.toString() ?? '';
      if (pid.isEmpty) continue;

      final qty = toInt(it['quantity']);
      final isCarton = it['isCarton'] == true;

      final pRef = _db.collection('products').doc(pid);
      final pDoc = await pRef.get();
      if (!pDoc.exists) continue;

      final upc = toInt(pDoc.data()?['unitsPerCarton'] ?? 1);
      final pieces = isCarton ? (qty * (upc > 0 ? upc : 1)) : qty;

      batch.update(pRef, {
        'stockQuantity': FieldValue.increment(restore ? pieces : -pieces),
      });
    }
  }

  /// ✅ إصلاح 3: عند الرفض يُرجع المخزن، وعند التراجع عن الرفض يُخصم من جديد
  static Future<void> updateOrderStatus(String orderId, String status) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final doc = await orderRef.get();
    final data = doc.data();
    final oldStatus = (data?['status'] ?? 'pending').toString();
    final items = (data?['items'] is List) ? data!['items'] as List : const [];

    final batch = _db.batch();

    if (oldStatus != 'rejected' && status == 'rejected') {
      // رُفض الآن → أرجع المخزن
      await _applyStockChange(batch, items, restore: true);
    } else if (oldStatus == 'rejected' && status != 'rejected') {
      // تراجع عن الرفض → اخصم المخزن مجدداً
      await _applyStockChange(batch, items, restore: false);
    }

    batch.update(orderRef, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('🔄 حالة الطلب $orderId → $status');
  }

  /// ✅ إصلاح 4: تعديل الطلب بشكل ذرّي
  /// نحسب الفرق الصافي لكل منتج (القديم − الجديد) ونطبّقه مع حفظ الطلب في batch واحدة،
  /// فإما ينجح كل شيء أو لا يتغير شيء. الطلب المرفوض لا يُحتسب (مخزونه أُرجع مسبقاً).
  static Future<void> updateFullOrder(app_models.Order order) async {
    final orderRef = _db.collection('orders').doc(order.id);
    final oldDoc = await orderRef.get();

    List oldItems = const [];
    bool oldCounted = false;
    if (oldDoc.exists) {
      final oldData = oldDoc.data();
      oldItems = (oldData?['items'] is List) ? oldData!['items'] as List : const [];
      oldCounted = (oldData?['status'] ?? 'pending').toString() != 'rejected';
    }
    final newCounted = order.status != 'rejected';

    // 1) جمع معرفات المنتجات المعنية
    final pids = <String>{};
    void collect(List items) {
      for (final it in items) {
        if (it is! Map) continue;
        final pid = it['productId']?.toString() ?? '';
        if (pid.isNotEmpty) pids.add(pid);
      }
    }
    if (oldCounted) collect(oldItems);
    if (newCounted) collect(order.items);

    // 2) جلب عدد الحبات في الكرتون لكل منتج (مرة واحدة)
    final upcMap = <String, int>{};
    for (final pid in pids) {
      final pDoc = await _db.collection('products').doc(pid).get();
      if (pDoc.exists) {
        final upc = toInt(pDoc.data()?['unitsPerCarton'] ?? 1);
        upcMap[pid] = upc > 0 ? upc : 1;
      }
    }

    // 3) حساب الفرق الصافي لكل منتج (+ إرجاع، − خصم)
    final net = <String, int>{};
    void accumulate(List items, int sign) {
      for (final it in items) {
        if (it is! Map) continue;
        final pid = it['productId']?.toString() ?? '';
        if (!upcMap.containsKey(pid)) continue;
        final qty = toInt(it['quantity']);
        final isCarton = it['isCarton'] == true;
        final pieces = isCarton ? qty * upcMap[pid]! : qty;
        net[pid] = (net[pid] ?? 0) + sign * pieces;
      }
    }
    if (oldCounted) accumulate(oldItems, 1);
    if (newCounted) accumulate(order.items, -1);

    // 4) حفظ الطلب + تحديث المخزن في batch واحدة
    final batch = _db.batch();
    batch.set(
      orderRef,
      {...order.toJson(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    net.forEach((pid, delta) {
      if (delta != 0) {
        batch.update(_db.collection('products').doc(pid), {
          'stockQuantity': FieldValue.increment(delta),
        });
      }
    });
    await batch.commit();

    debugPrint('📝 تم تحديث الطلب والمخزن بشكل ذرّي: ${order.id}');
  }

  static Future<void> updateOrderLocation(
      String orderId,
      double lat,
      double lng,
      String address,
      ) async {
    await _db.collection('orders').doc(orderId).update({
      'latitude': lat,
      'longitude': lng,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('📍 تم تحديث موقع الطلب: $orderId');
  }

  /// ✅ إصلاح 3: عند الحذف يُرجع المخزن (إلا إذا كان الطلب مرفوضاً لأنه أُرجع سابقاً)
  static Future<void> deleteOrder(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final doc = await orderRef.get();

    final batch = _db.batch();

    if (doc.exists) {
      final data = doc.data();
      final oldStatus = (data?['status'] ?? 'pending').toString();
      final items =
      (data?['items'] is List) ? data!['items'] as List : const [];

      if (oldStatus != 'rejected') {
        await _applyStockChange(batch, items, restore: true);
      }
    }

    batch.delete(orderRef);
    await batch.commit();
    debugPrint('🗑️ تم حذف الطلب وإرجاع المخزن: $orderId');
  }

  static Stream<int> getPendingOrdersCount() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((e) => debugPrint('❌ pendingCount: $e'));
  }

  /// 🔧 إصلاح الطلبات القديمة التي بلا createdAt
  /// (شغّلها مرة واحدة من زر مؤقت في شاشة الأدمن)
  static Future<int> migrateOrdersCreatedAt() async {
    int fixed = 0;
    try {
      final snap = await _db.collection('orders').get();
      for (final d in snap.docs) {
        if (d.data()['createdAt'] != null) continue;

        final o = app_models.Order.fromJson(_qDoc(d));
        final dt = o.dateTime ??
            DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(o.id) ?? DateTime.now().millisecondsSinceEpoch,
            );

        await d.reference.update({'createdAt': Timestamp.fromDate(dt)});
        fixed++;
      }
      debugPrint('🔧 تم إصلاح $fixed طلب');
    } catch (e) {
      debugPrint('❌ migrateOrders: $e');
    }
    return fixed;
  }

  // ══════════════════════════════════════════════════════
  //   ⚙️ الإعدادات
  // ══════════════════════════════════════════════════════
  static Future<bool> getIsSpecialPrice() async {
    try {
      final doc = await _db.collection('settings').doc('pricing').get();
      final v = doc.data()?['isSpecialPrice'];
      if (v is bool) return v;
      return false;
    } catch (e) {
      debugPrint('⚠️ getIsSpecialPrice (offline): $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool('isSpecialPrice') ?? false;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<void> setIsSpecialPrice(bool value) async {
    try {
      await _db.collection('settings').doc('pricing').set(
        {'isSpecialPrice': value, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('⚠️ setIsSpecialPrice: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSpecialPrice', value);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final doc = await _db.collection('settings').doc('general').get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint('❌ getSettings: $e');
      return {};
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> data) async {
    await _db.collection('settings').doc('general').set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ══════════════════════════════════════════════════════
  //   🔒 كلمة سر لوحة الإدارة
  // ══════════════════════════════════════════════════════
  static Future<String?> getAdminPassword() async {
    try {
      final doc = await _db.collection('settings').doc('security').get();
      final v = doc.data()?['adminPassword'];
      return v is String && v.isNotEmpty ? v : null;
    } catch (e) {
      debugPrint('❌ getAdminPassword: $e');
      return null;
    }
  }

  static Future<void> setAdminPassword(String password) async {
    await _db.collection('settings').doc('security').set(
      {
        'adminPassword': password,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('🔒 تم تحديث كلمة سر الإدارة');
  }

  // ══════════════════════════════════════════════════════
  //   📊 الإحصائيات - مُحدَّثة للجرد وصافي الربح
  // ══════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getStats({DateTime? specificDate}) async {
    try {
      // ✅ إصلاح 2: الطلبات المرفوضة لا تُحتسب في المبيعات والأرباح
      final allOrders = await getAllOrders();
      final orders = allOrders.where((o) => !o.isRejected).toList();
      final productsList = await getAllProducts();

      // خريطة أسعار الشراء (للحبة) لتسهيل الحساب
      final Map<String, double> buyPrices = {
        for (var p in productsList) p.id: p.purchasePrice
      };

      // ✅ إصلاح 2: خريطة عدد الحبات في الكرتون
      final Map<String, int> unitsPerCartonMap = {
        for (var p in productsList) p.id: p.unitsPerCarton
      };

      final now = DateTime.now();
      final targetDate = specificDate ?? now;

      bool sameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;

      final todayOrdersList = <app_models.Order>[];
      final week = <app_models.Order>[];
      final month = <app_models.Order>[];
      final targetDayOrders = <app_models.Order>[];

      for (final o in orders) {
        final d = o.createdAt ?? o.dateTime;
        if (d == null) continue;

        if (sameDay(d, now)) todayOrdersList.add(o);
        if (sameDay(d, targetDate)) targetDayOrders.add(o);

        if (now.difference(d).inDays <= 7) week.add(o);
        if (d.year == now.year && d.month == now.month) month.add(o);
      }

      // حساب صافي الربح لليوم المختار
      double targetDayProfit = 0;
      // ✅ الكرتون والحبة يُجمَّعان منفصلين (مفتاح = اسم المنتج + النوع)
      final Map<String, Map<String, dynamic>> targetDayItems = {};

      for (final o in targetDayOrders) {
        for (final it in o.items) {
          final pid = it['productId']?.toString() ?? '';
          final name = it['productName']?.toString() ?? 'منتج';
          final sellPrice = toDouble(it['price']);
          final qty = toInt(it['quantity']);

          final isCartonItem = it['isCarton'] == true;
          final entry = targetDayItems.putIfAbsent(
            '$name|${isCartonItem ? 'c' : 'u'}',
                () => <String, dynamic>{
              'name': name,
              'type': isCartonItem ? 'كرتون' : 'حبة',
              'quantity': 0,
              'revenue': 0.0,
            },
          );
          entry['quantity'] = (entry['quantity'] as int) + qty;
          entry['revenue'] = (entry['revenue'] as double) + (sellPrice * qty);

          if (pid.isNotEmpty && buyPrices.containsKey(pid)) {
            final buyPrice = buyPrices[pid]!;
            if (buyPrice > 0) {
              // ✅ إصلاح 2: تكلفة الكرتون = سعر الحبة × عدد الحبات في الكرتون
              final isCarton = it['isCarton'] == true;
              final upc = unitsPerCartonMap[pid] ?? 1;
              final unitCost = isCarton ? (buyPrice * upc) : buyPrice;
              targetDayProfit += (sellPrice - unitCost) * qty;
            }
          }
        }
      }

      final targetDayProducts = targetDayItems.values.toList();

      // أكثر المنتجات مبيعاً (تاريخي)
      final Map<String, int> salesCount = {};
      // ✅ الكرتون والحبة منفصلان (لا يُجمعان معاً لأن وحدتيهما مختلفتان)
      final Map<String, int> cartonSales = {};
      final Map<String, int> unitSales = {};
      for (final o in orders) {
        for (final it in o.items) {
          final name = (it['productName'] ?? '').toString();
          if (name.isEmpty) continue;
          final q = toInt(it['quantity']);
          salesCount[name] = (salesCount[name] ?? 0) + q;
          if (it['isCarton'] == true) {
            cartonSales[name] = (cartonSales[name] ?? 0) + q;
          } else {
            unitSales[name] = (unitSales[name] ?? 0) + q;
          }
        }
      }

      List<Map<String, dynamic>> topOf(Map<String, int> m, String type) {
        final list = m.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return list
            .take(5)
            .map((e) => <String, dynamic>{
          'name': e.key,
          'type': type,
          'quantity': e.value,
        })
            .toList();
      }

      final topCartonProducts = topOf(cartonSales, 'كرتون');
      final topUnitProducts = topOf(unitSales, 'حبة');

      final sorted = salesCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topProducts = sorted.take(5).map((e) => {
        'name': e.key,
        'quantity': e.value,
      }).toList();

      double sum(List<app_models.Order> l) =>
          l.fold(0.0, (s, o) => s + o.total);

      return {
        'totalOrders': orders.length,
        'todayOrders': todayOrdersList.length,
        'weekOrders': week.length,
        'monthOrders': month.length,
        'totalSales': sum(orders),
        'todaySales': sum(todayOrdersList),
        'weekSales': sum(week),
        'monthSales': sum(month),
        'topProducts': topProducts,
        'topCartonProducts': topCartonProducts,
        'topUnitProducts': topUnitProducts,

        // بيانات اليوم المختار (للبحث التاريخي)
        'targetDaySales': sum(targetDayOrders),
        'targetDayOrdersCount': targetDayOrders.length,
        'targetDayProfit': targetDayProfit,
        'targetDayProducts': targetDayProducts,
      };
    } catch (e) {
      debugPrint('❌ getStats: $e');
      return {
        'totalOrders': 0, 'todayOrders': 0, 'totalSales': 0.0,
        'targetDayProfit': 0.0, 'targetDayProducts': [],
      };
    }
  }

  // ══════════════════════════════════════════════════════
  //   📢 الإعلانات
  // ══════════════════════════════════════════════════════
  static Future<void> saveAnnouncement(
      app_models.AnnouncementModel a) async {
    await _db.collection('announcements').doc(a.id).set({
      'message': a.message,
      'type': a.type,
      'isActive': a.isActive,
      // ✅ Timestamp موحّد (وليس String) — يمنع أخطاء الترتيب
      'createdAt': Timestamp.fromDate(a.createdAt),
    });
    debugPrint('✅ إعلان محفوظ: ${a.id}');
  }

  /// ✅ بدون orderBy على السيرفر → لا يحتاج فهرس مركّب
  static Stream<List<app_models.AnnouncementModel>>
  getAnnouncementsStream() {
    return _db
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => app_models.AnnouncementModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((e) {
      debugPrint('❌ announcementsStream: $e');
    });
  }

  static Future<List<app_models.AnnouncementModel>>
  getAnnouncements() async {
    try {
      final snap = await _db
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) => app_models.AnnouncementModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('❌ getAnnouncements: $e');
      return [];
    }
  }

  static Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
    debugPrint('🗑️ تم حذف الإعلان: $id');
  }

  static Future<void> toggleAnnouncementStatus(
      String id, bool isActive) async {
    await _db
        .collection('announcements')
        .doc(id)
        .update({'isActive': isActive});
  }

  static Future<void> cleanupOldAnnouncements() async {
    try {
      final snap = await _db
          .collection('announcements')
          .where('isActive', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      debugPrint('🧹 تم تنظيف ${snap.docs.length} إعلان');
    } catch (e) {
      debugPrint('❌ cleanup: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //   🖼️ البانرات
  // ══════════════════════════════════════════════════════
  static Future<List<app_models.BannerModel>> getBanners() async {
    try {
      final snap = await _db
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) => app_models.BannerModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    } catch (e) {
      debugPrint('❌ getBanners: $e');
      return [];
    }
  }

  static Future<List<app_models.BannerModel>> getAllBanners() async {
    try {
      final snap = await _db.collection('banners').get();
      final list = snap.docs
          .map((d) => app_models.BannerModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    } catch (e) {
      debugPrint('❌ getAllBanners: $e');
      return [];
    }
  }

  static Stream<List<app_models.BannerModel>> getBannersStream() {
    return _db
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => app_models.BannerModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    }).handleError((e) {
      debugPrint('❌ bannersStream: $e');
    });
  }

  static Future<void> saveBanner(app_models.BannerModel banner,
      {String? imagePath}) async {
    String url = banner.imageUrl;
    if (imagePath != null && imagePath.isNotEmpty) {
      final u = await uploadImage(imagePath, 'banners');
      if (u.isNotEmpty) url = u;
    }

    await _db.collection('banners').doc(banner.id).set({
      'title': banner.title,
      'subtitle': banner.subtitle,
      'imageUrl': url,
      'colorValue': _colorValue(banner.color),
      'iconCodePoint': banner.icon.codePoint,
      'iconFontFamily': banner.icon.fontFamily ?? 'MaterialIcons',
      'isActive': banner.isActive,
      'order': banner.order,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ بانر محفوظ: ${banner.title}');
  }

  static Future<void> updateBannerStatus(
      String bannerId, bool isActive) async {
    await _db
        .collection('banners')
        .doc(bannerId)
        .update({'isActive': isActive});
  }

  static Future<void> deleteBanner(String bannerId) async {
    try {
      final doc = await _db.collection('banners').doc(bannerId).get();
      await deleteImageFromStorage(doc.data()?['imageUrl'] ?? '');
      await _db.collection('banners').doc(bannerId).delete();
      debugPrint('🗑️ تم حذف البانر: $bannerId');
    } catch (e) {
      debugPrint('❌ deleteBanner: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════
  //   👥 الزبائن والديون
  // ══════════════════════════════════════════════════════
  static Future<List<app_models.CustomerModel>> getCustomers() async {
    try {
      final snap = await _db.collection('customers').get();
      final list = snap.docs
          .map((d) => app_models.CustomerModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getCustomers: $e');
      return [];
    }
  }

  static Stream<List<app_models.CustomerModel>> getCustomersStream() {
    return _db.collection('customers').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => app_models.CustomerModel.fromJson(_qDoc(d)))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }).handleError((e) {
      debugPrint('❌ customersStream: $e');
    });
  }

  static Stream<app_models.CustomerModel?> getCustomerStream(
      String customerId) {
    return _db
        .collection('customers')
        .doc(customerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return app_models.CustomerModel.fromJson(_doc(doc));
    }).handleError((e) {
      debugPrint('❌ customerStream: $e');
    });
  }

  static Future<app_models.CustomerModel?> getCustomerById(
      String customerId) async {
    try {
      if (customerId.isEmpty) return null;
      final doc = await _db.collection('customers').doc(customerId).get();
      if (!doc.exists) return null;
      return app_models.CustomerModel.fromJson(_doc(doc));
    } catch (e) {
      debugPrint('❌ getCustomerById: $e');
      return null;
    }
  }

  static Future<void> saveCustomer(app_models.CustomerModel customer) async {
    await _db.collection('customers').doc(customer.id).set({
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address ?? '',
      'balance': customer.balance,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ زبون محفوظ: ${customer.name}');
  }

  static Future<void> updateCustomerInfo(
      app_models.CustomerModel customer) async {
    await _db.collection('customers').doc(customer.id).set({
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✏️ تم تعديل بيانات الزبون: ${customer.name}');
  }

  static Future<void> deleteCustomer(String customerId) async {
    try {
      final batch = _db.batch();
      final txns = await _db
          .collection('debt_transactions')
          .where('customerId', isEqualTo: customerId)
          .get();
      for (final d in txns.docs) {
        batch.delete(d.reference);
      }
      batch.delete(_db.collection('customers').doc(customerId));
      await batch.commit();
      debugPrint('🗑️ تم حذف الزبون وسجل ديونه: $customerId');
    } catch (e) {
      debugPrint('❌ deleteCustomer: $e');
      rethrow;
    }
  }

  /// ✅ إضافة دين أو تسديد — يحدّث رصيد الزبون بشكل ذرّي (atomic)
  /// عبر معاملة Firestore، ويسجّل الحركة في سجل منفصل
  static Future<void> addDebtTransaction({
    required String customerId,
    required String type, // 'charge' (إضافة دين) أو 'payment' (تسديد)
    required double amount,
    String note = '',
    String? orderId, // ✅ إصلاح 4: ربط الحركة بالطلبية
  }) async {
    final txnId = DateTime.now().millisecondsSinceEpoch.toString();
    final customerRef = _db.collection('customers').doc(customerId);
    final txnRef = _db.collection('debt_transactions').doc(txnId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(customerRef);
      final currentBalance = _d(snap.data()?['balance']);
      final delta = type == 'payment' ? -amount : amount;
      final newBalance = currentBalance + delta;

      transaction.set(txnRef, {
        'customerId': customerId,
        'type': type,
        'amount': amount,
        'note': note,
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(customerRef, {
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    debugPrint('✅ معاملة دين مسجّلة: $type $amount للزبون $customerId');
  }

  /// ✅ إصلاح 4: مزامنة دين الزبون عند تعديل الطلبية.
  /// تقارن الدين المسجّل فعلاً لهذه الطلبية في سجل الحركات بالدين الجديد
  /// وتسجّل الفرق فقط (إضافة دين أو تسديد). آمنة عند التكرار (لا تُسجّل شيئاً إن لم يتغير الدين).
  /// ترجع رصيد الزبون بعد المزامنة، أو null إذا لم تكن الطلبية مسجّلة على زبون.
  static Future<double?> syncOrderDebt({
    required String orderId,
    required double newRemaining,
  }) async {
    try {
      final snap = await _db
          .collection('debt_transactions')
          .where('orderId', isEqualTo: orderId)
          .get();
      if (snap.docs.isEmpty) return null;

      String customerId = '';
      double recorded = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final cid = data['customerId']?.toString() ?? '';
        if (cid.isNotEmpty) customerId = cid;
        final amount = _d(data['amount']);
        recorded += data['type'] == 'payment' ? -amount : amount;
      }
      if (customerId.isEmpty) return null;

      final delta = newRemaining - recorded;
      if (delta.abs() > 0.05) {
        await addDebtTransaction(
          customerId: customerId,
          type: delta > 0 ? 'charge' : 'payment',
          amount: delta.abs(),
          note: 'تعديل فاتورة رقم #$orderId',
          orderId: orderId,
        );
      }

      final customer = await getCustomerById(customerId);
      return customer?.balance;
    } catch (e) {
      debugPrint('❌ syncOrderDebt: $e');
      rethrow;
    }
  }

  static Future<List<app_models.DebtTransactionModel>>
  getCustomerTransactions(String customerId) async {
    try {
      final snap = await _db
          .collection('debt_transactions')
          .where('customerId', isEqualTo: customerId)
          .get();
      final list = snap.docs
          .map((d) => app_models.DebtTransactionModel.fromJson(_qDoc(d)))
          .toList();
      list.sort(_cmpTransactions);
      return list;
    } catch (e) {
      debugPrint('❌ getCustomerTransactions: $e');
      return [];
    }
  }

  static Stream<List<app_models.DebtTransactionModel>>
  getCustomerTransactionsStream(String customerId) {
    return _db
        .collection('debt_transactions')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => app_models.DebtTransactionModel.fromJson(_qDoc(d)))
          .toList();
      list.sort(_cmpTransactions);
      return list;
    }).handleError((e) {
      debugPrint('❌ customerTransactionsStream: $e');
    });
  }

  static int _cmpTransactions(
      app_models.DebtTransactionModel a, app_models.DebtTransactionModel b) {
    final da = a.createdAt;
    final db = b.createdAt;
    if (da != null && db != null) return db.compareTo(da);
    if (da != null) return -1;
    if (db != null) return 1;
    return b.id.compareTo(a.id);
  }

  static Future<double> getTotalDebt() async {
    try {
      final customers = await getCustomers();
      return customers.fold<double>(0.0, (sum, c) => sum + c.balance);
    } catch (e) {
      debugPrint('❌ getTotalDebt: $e');
      return 0;
    }
  }

  // 🧠 الربط الذكي للموردين (OCR)
  static Future<String?> getMappedProductId(String supplierText) async {
    try {
      final snap = await _db.collection('supplier_mappings').doc(supplierText).get();
      return snap.data()?['productId'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSupplierMapping(String supplierText, String productId) async {
    await _db.collection('supplier_mappings').doc(supplierText).set({
      'productId': productId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}