import 'package:flutter_test/flutter_test.dart';
import 'package:alqanaa_app/models/models.dart';

void main() {
  group('Product Model Tests', () {
    final sampleProductJson = {
      'id': 'p1',
      'brandId': 'b1',
      'name': 'زيت زيتون 1 لتر',
      'priceCartonNormal': 5000.0,
      'priceUnitNormal': 500.0,
      'priceCartonSpecial': 4500.0,
      'priceUnitSpecial': 450.0,
      'purchasePrice': 400.0,
      'stockQuantity': 50.0,
      'unitsPerCarton': 10,
      'maxQtyNormal': 5,
      'maxQtySpecial': 10,
      'sellType': 'both',
      'isAvailable': true,
      'hasFlavors': false,
      'flavors': [],
    };

    test('Product.fromJson parses correctly', () {
      final product = Product.fromJson(sampleProductJson);
      expect(product.id, 'p1');
      expect(product.name, 'زيت زيتون 1 لتر');
      expect(product.priceCartonNormal, 5000.0);
      expect(product.unitsPerCarton, 10);
      expect(product.sellType, SellType.both);
      expect(product.canSellCarton, true);
      expect(product.canSellUnit, true);
    });

    test('Product.toJson produces correct Map', () {
      final product = Product.fromJson(sampleProductJson);
      final json = product.toJson();
      expect(json['name'], 'زيت زيتون 1 لتر');
      expect(json['priceCartonNormal'], 5000.0);
      expect(json['unitsPerCarton'], 10);
    });

    test('discountedPrice calculates discount correctly', () {
      final product = Product.fromJson({
        ...sampleProductJson,
        'discount': 10.0,
      });
      final price = product.discountedPrice(100.0);
      expect(price, 90.0);
    });
  });

  group('CartItem Model Tests', () {
    final product = Product(
      id: 'p1',
      brandId: 'b1',
      name: 'عصير برتقال',
      priceCartonNormal: 1200.0,
      priceUnitNormal: 100.0,
      priceCartonSpecial: 1000.0,
      priceUnitSpecial: 90.0,
      purchasePrice: 80.0,
      unitsPerCarton: 12,
    );

    test('CartItem price and total calculations (Carton Normal)', () {
      final item = CartItem(
        product: product,
        quantity: 2,
        isCarton: true,
        isSpecialPrice: false,
      );

      expect(item.unitPrice, 1200.0);
      expect(item.totalPrice, 2400.0);
      expect(item.typeLabel, 'كرتون');
    });

    test('CartItem price and total calculations (Unit Special)', () {
      final item = CartItem(
        product: product,
        quantity: 5,
        isCarton: false,
        isSpecialPrice: true,
      );

      expect(item.unitPrice, 90.0);
      expect(item.totalPrice, 450.0);
      expect(item.typeLabel, 'حبة');
    });

    test('CartItem override price', () {
      final item = CartItem(
        product: product,
        quantity: 3,
        isCarton: true,
        isSpecialPrice: false,
        overridePrice: 1100.0,
      );

      expect(item.unitPrice, 1100.0);
      expect(item.totalPrice, 3300.0);
    });

    test('Weighed Product CartItem toOrderItem includes isWeighed flag', () {
      final weighedProduct = Product(
        id: 'pw1',
        brandId: 'b1',
        name: 'تفاح ميزان',
        priceCartonNormal: 0.0,
        priceUnitNormal: 300.0,
        priceCartonSpecial: 0.0,
        priceUnitSpecial: 300.0,
        purchasePrice: 200.0,
        isWeighed: true,
      );

      final item = CartItem(
        product: weighedProduct,
        quantity: 2.75,
        isCarton: false,
      );

      final orderItem = item.toOrderItem();
      expect(orderItem['isWeighed'], true);
      expect(orderItem['quantity'], 2.75);
      expect(orderItem['typeLabel'], 'KG');
    });
  });

  group('UserModel Tests', () {
    test('UserModel JSON roundtrip', () {
      final user = UserModel(
        id: 'u123',
        name: 'محمد علي',
        email: 'mohamed@example.com',
        phone: '0555123456',
        role: 'user_normal',
        createdAt: '2025-01-01T00:00:00.000',
      );

      final json = user.toJson();
      final parsed = UserModel.fromJson({...json, 'id': 'u123'});

      expect(parsed.id, 'u123');
      expect(parsed.name, 'محمد علي');
      expect(parsed.email, 'mohamed@example.com');
      expect(parsed.role, 'user_normal');
      expect(parsed.isAdmin, false);
      expect(parsed.isSpecial, false);
    });
  });

  group('Mandatory Test Example: Purchase, Sell, and Profit Precision', () {
    test('Carton purchase 1250 DA with 45 units and carton sell 1450 DA yields exactly 200 DA carton profit', () {
      final purchaseCarton = 1250.0;
      final units = 45;
      final purchaseUnit = purchaseCarton / units; // 27.777777...
      final sellCarton = 1450.0;

      final product = Product(
        id: 'p_exam',
        brandId: 'b1',
        name: 'منتج اختبار الأرباح',
        priceCartonNormal: sellCarton,
        priceUnitNormal: 35.0,
        priceCartonSpecial: 1400.0,
        priceUnitSpecial: 32.0,
        purchasePrice: purchaseUnit,
        unitsPerCarton: units,
      );

      final calculatedCartonCost = product.purchasePrice * product.unitsPerCarton;
      expect(calculatedCartonCost, 1250.0);

      final cartonProfit = product.priceCartonNormal - calculatedCartonCost;
      expect(cartonProfit, 200.0);
    });
  });

  group('Converters formatQuantity Tests', () {
    test('formatQuantity formats decimal stock accurately with dot separator', () {
      expect(formatQuantity(10.0), '10');
      expect(formatQuantity(-4.5), '-4.5');
      expect(formatQuantity(-4.25), '-4.25');
      expect(formatQuantity(-4.75), '-4.75');
      expect(formatQuantity(0.25), '0.25');
      expect(formatQuantity(0.5), '0.5');
      expect(formatQuantity(0.75), '0.75');
      expect(formatQuantity(1.25), '1.25');
      expect(formatQuantity(1.75), '1.75');
      expect(formatQuantity(2.35), '2.35');
    });
  });
}
