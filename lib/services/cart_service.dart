import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/models.dart';

class CartService {
  static const String _cartKey = 'saved_cart';

  /// ✅ المصدر الوحيد الموثوق لحالة السلة في كافة التطبيق
  static final ValueNotifier<List<CartItem>> cartNotifier =
      ValueNotifier<List<CartItem>>([]);

  /// ✅ إرجاع قائمة عناصر السلة الحالية
  static List<CartItem> get cart => cartNotifier.value;

  /// ✅ استعادة السلة المحفوظة عند بداية التشغيل
  static Future<List<CartItem>> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_cartKey);
      if (data == null) {
        cartNotifier.value = [];
        return [];
      }
      final List<dynamic> cartData = jsonDecode(data);
      final List<CartItem> loaded = cartData.map((item) {
        final product = Product.fromJson(
            item['productData'] as Map<String, dynamic>);
        return CartItem(
          product: product,
          quantity: toDouble(item['quantity']),
          isSpecialPrice: item['isSpecialPrice'] as bool,
          isCarton: item['isCarton'] as bool,
          flavor: (item['flavor'] as String).isNotEmpty
              ? item['flavor'] as String
              : null,
        );
      }).toList();

      cartNotifier.value = List.from(loaded);
      debugPrint('✅ تم تحميل السلة: ${loaded.length} منتج');
      return loaded;
    } catch (e) {
      debugPrint('⚠️ فشل استعادة السلة: $e');
      cartNotifier.value = [];
      return [];
    }
  }

  /// ✅ حفظ السلة محلياً وتحديث الحالة
  static Future<void> saveCart([List<CartItem>? newCart]) async {
    try {
      final List<CartItem> cartToSave = newCart ?? cartNotifier.value;
      cartNotifier.value = List.from(cartToSave);

      final prefs = await SharedPreferences.getInstance();
      final cartData = cartToSave
          .map((item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'productData': item.product.toJson(),
                'quantity': item.quantity,
                'isSpecialPrice': item.isSpecialPrice,
                'isCarton': item.isCarton,
                'flavor': item.flavor ?? '',
              })
          .toList();

      await prefs.setString(_cartKey, jsonEncode(cartData));
      debugPrint('✅ تم حفظ السلة: ${cartToSave.length} منتج');
    } catch (e) {
      debugPrint('⚠️ فشل حفظ السلة: $e');
    }
  }

  /// ✅ إضافة عنصر للسلة بشكل آمن ومزامن
  static Future<void> addItem(CartItem item, {bool save = true}) async {
    final List<CartItem> current = List.from(cartNotifier.value);
    final index = current.indexWhere((i) =>
        i.product.id == item.product.id &&
        i.isCarton == item.isCarton &&
        i.isSpecialPrice == item.isSpecialPrice &&
        i.flavor == item.flavor);

    if (index >= 0) {
      current[index].quantity += item.quantity;
    } else {
      current.add(item);
    }

    cartNotifier.value = current;
    if (save) await saveCart(current);
  }

  /// ✅ تحديث كمية عنصر في السلة
  static Future<void> updateQuantity(CartItem item, double quantity,
      {bool save = true}) async {
    final List<CartItem> current = List.from(cartNotifier.value);
    final index = current.indexWhere((i) =>
        i.product.id == item.product.id &&
        i.isCarton == item.isCarton &&
        i.isSpecialPrice == item.isSpecialPrice &&
        i.flavor == item.flavor);

    if (index >= 0) {
      if (quantity <= 0) {
        current.removeAt(index);
      } else {
        current[index].quantity = quantity;
      }
      cartNotifier.value = current;
      if (save) await saveCart(current);
    }
  }

  /// ✅ حذف عنصر محدد من السلة
  static Future<void> removeItem(CartItem item, {bool save = true}) async {
    final List<CartItem> current = List.from(cartNotifier.value);
    current.removeWhere((i) =>
        i.product.id == item.product.id &&
        i.isCarton == item.isCarton &&
        i.isSpecialPrice == item.isSpecialPrice &&
        i.flavor == item.flavor);

    cartNotifier.value = current;
    if (save) await saveCart(current);
  }

  /// ✅ مسح السلة المحفوظة بالكامل
  static Future<void> clearCart() async {
    try {
      cartNotifier.value = [];
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      debugPrint('✅ تم مسح السلة المحفوظة');
    } catch (e) {
      debugPrint('⚠️ فشل مسح السلة: $e');
    }
  }
}
