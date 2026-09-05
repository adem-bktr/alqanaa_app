import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/models.dart';

class CartService {
  static const String _cartKey = 'saved_cart';

  // ✅ حفظ السلة محلياً
  static Future<void> saveCart(List<CartItem> cart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = cart.map((item) => {
        'productId': item.product.id,
        'productName': item.product.name,
        'productData': item.product.toJson(),
        'quantity': item.quantity,
        'isSpecialPrice': item.isSpecialPrice,
        'isCarton': item.isCarton,
        'flavor': item.flavor ?? '',
      }).toList();
      await prefs.setString(_cartKey, jsonEncode(cartData));
      debugPrint('✅ تم حفظ السلة: ${cart.length} منتج');
    } catch (e) {
      debugPrint('⚠️ فشل حفظ السلة: $e');
    }
  }

  // ✅ استعادة السلة المحفوظة
  static Future<List<CartItem>> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_cartKey);
      if (data == null) return [];
      final List<dynamic> cartData = jsonDecode(data);
      return cartData.map((item) {
        final product = Product.fromJson(
            item['productData'] as Map<String, dynamic>);
        return CartItem(
          product: product,
          quantity: item['quantity'] as int,
          isSpecialPrice: item['isSpecialPrice'] as bool,
          isCarton: item['isCarton'] as bool,
          flavor: (item['flavor'] as String).isNotEmpty
              ? item['flavor'] as String
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ فشل استعادة السلة: $e');
      return [];
    }
  }

  // ✅ مسح السلة المحفوظة
  static Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      debugPrint('✅ تم مسح السلة المحفوظة');
    } catch (e) {
      debugPrint('⚠️ فشل مسح السلة: $e');
    }
  }
}