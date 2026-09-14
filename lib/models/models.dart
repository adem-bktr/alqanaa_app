import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/converters.dart';

// ══════════════════════════════════════════════════════════
//   🔧 أدوات تحويل آمنة (تم النقل إلى converters.dart)
// ══════════════════════════════════════════════════════════
String _s(dynamic v) => toStr(v);
double _d(dynamic v) => toDouble(v);
int _i(dynamic v) => toInt(v);
bool _b(dynamic v, {bool def = false}) => toBool(v, def: def);
DateTime? _dt(dynamic v) => toDateTime(v);

String _p2(int n) => n.toString().padLeft(2, '0');

/// ✅ تنسيق يدوي بأرقام ASCII — مهم جداً للطابعة الحرارية
String fmtDate(DateTime d) =>
    '${_p2(d.day)}/${_p2(d.month)}/${d.year} - ${_p2(d.hour)}:${_p2(d.minute)}';

/// ✅ خريطة الأيقونات المسموح بها (لحل مشكلة Tree Shaking)
const Map<int, IconData> _allowedIcons = {
  0xe3c8: Icons.local_offer,
  0xe88a: Icons.home,
  0xe8cc: Icons.shopping_cart,
  0xe8b6: Icons.search,
  0xef6e: Icons.person,
  0xe5d2: Icons.menu,
  0xe145: Icons.add,
  0xe872: Icons.delete,
  0xe3b7: Icons.edit,
  0xe5ca: Icons.check,
  0xe5cd: Icons.close,
  0xe5c4: Icons.arrow_back,
  0xe5c8: Icons.arrow_forward,
  0xe0b0: Icons.phone,
  0xe0c9: Icons.message,
  0xe85d: Icons.event,
  0xe8d1: Icons.store,
  0xe551: Icons.restaurant,
  0xe52e: Icons.local_shipping,
  0xe227: Icons.attach_money,
  0xef44: Icons.category,
  0xe85e: Icons.favorite,
  0xe87d: Icons.favorite_border,
  0xe838: Icons.star,
  0xe83a: Icons.star_border,
};

IconData _iconFromCodePoint(int codePoint, String? fontFamily) {
  // البحث في الخريطة أولاً
  if (_allowedIcons.containsKey(codePoint)) {
    return _allowedIcons[codePoint]!;
  }
  
  // إذا لم توجد في الخريطة، نستخدم أيقونة افتراضية آمنة
  // هذا يمنع تعطل البناء (Build) لأننا نرجع قيمة ثابتة في كل الحالات
  return Icons.help_outline;
}

// ══════════════════════════════════════════════════════════
//   FlavorModel  (كما هو + copyWith)
// ══════════════════════════════════════════════════════════
class FlavorModel {
  final String name;
  final bool isAvailable;

  const FlavorModel({
    required this.name,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isAvailable': isAvailable,
  };

  factory FlavorModel.fromJson(dynamic json) {
    if (json is String) {
      return FlavorModel(name: json, isAvailable: true);
    }
    if (json is Map) {
      return FlavorModel(
        name: _s(json['name']),
        isAvailable: _b(json['isAvailable'], def: true),
      );
    }
    return FlavorModel(name: _s(json), isAvailable: true);
  }

  FlavorModel copyWith({String? name, bool? isAvailable}) => FlavorModel(
    name: name ?? this.name,
    isAvailable: isAvailable ?? this.isAvailable,
  );
}

// ══════════════════════════════════════════════════════════
//   Brand
// ══════════════════════════════════════════════════════════
class Brand {
  final String id;
  final String name;
  final String logoPath;
  final String categoryId;

  Brand({
    required this.id,
    required this.name,
    this.logoPath = '',
    this.categoryId = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logoPath': logoPath,
    'categoryId': categoryId,
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: _s(json['id']),
    name: _s(json['name']),
    logoPath: _s(json['logoPath']),
    categoryId: _s(json['categoryId']),
  );

  // ✅ يمنع خطأ "There should be exactly one item with [DropdownButton]'s value"
  @override
  bool operator ==(Object other) => other is Brand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   Category
// ══════════════════════════════════════════════════════════
class Category {
  final String id;
  final String name;
  final String icon;
  final int order;

  Category({
    required this.id,
    required this.name,
    this.icon = '📦',
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'order': order,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: _s(json['id']),
    name: _s(json['name']),
    icon: _s(json['icon']).isEmpty ? '📦' : _s(json['icon']),
    order: _i(json['order']),
  );

  // ✅ ضروري للـ Dropdown
  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   BannerModel
// ══════════════════════════════════════════════════════════
class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color color;
  final IconData icon;
  final bool isActive;
  final int order;

  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl = '',
    this.color = const Color(0xFF2E7D32),
    this.icon = Icons.local_offer,
    this.isActive = true,
    this.order = 0,
  });

  bool get hasImage => imageUrl.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    // ignore: deprecated_member_use
    'colorValue': color.value,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'isActive': isActive,
    'order': order,
  };

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    final code = _i(json['iconCodePoint']);
    return BannerModel(
      id: _s(json['id']),
      title: _s(json['title']),
      subtitle: _s(json['subtitle']),
      imageUrl: _s(json['imageUrl']),
      color: Color(
        json['colorValue'] == null ? 0xFF2E7D32 : _i(json['colorValue']),
      ),
      icon: code == 0
          ? Icons.local_offer
          : _iconFromCodePoint(code, _s(json['iconFontFamily']).isEmpty
          ? 'MaterialIcons'
          : _s(json['iconFontFamily'])),
      isActive: _b(json['isActive'], def: true),
      order: _i(json['order']),
    );
  }
}

// ══════════════════════════════════════════════════════════
//   SellType
// ══════════════════════════════════════════════════════════
enum SellType { cartonOnly, unitOnly, both }

// ══════════════════════════════════════════════════════════
//   Product
// ══════════════════════════════════════════════════════════
class Product {
  final String id;
  final String brandId;
  final String categoryId;
  final String name;
  final double priceCartonNormal;
  final double priceUnitNormal;
  final double priceCartonSpecial;
  final double priceUnitSpecial;
  final String imagePath;
  final bool isAvailable;
  final double discount;
  final SellType sellType;
  final int maxQtyNormal;
  final int maxQtySpecial;
  final List<FlavorModel> flavors;
  final bool isFeatured;

  Product({
    required this.id,
    required this.brandId,
    this.categoryId = '',
    required this.name,
    required this.priceCartonNormal,
    required this.priceUnitNormal,
    required this.priceCartonSpecial,
    required this.priceUnitSpecial,
    this.imagePath = '',
    this.isAvailable = true,
    this.discount = 0,
    this.sellType = SellType.cartonOnly,
    this.maxQtyNormal = 0,
    this.maxQtySpecial = 0,
    this.flavors = const [],
    this.isFeatured = false,
  });

  bool get hasFlavors => flavors.isNotEmpty;

  List<FlavorModel> get availableFlavors =>
      flavors.where((f) => f.isAvailable).toList();

  double discountedPrice(double price) {
    if (discount <= 0) return price;
    return price - (price * discount / 100);
  }

  bool get canSellCarton =>
      sellType == SellType.cartonOnly || sellType == SellType.both;

  bool get canSellUnit =>
      sellType == SellType.unitOnly || sellType == SellType.both;

  Map<String, dynamic> toJson() => {
    'id': id,
    'brandId': brandId,
    'categoryId': categoryId,
    'name': name,
    'priceCartonNormal': priceCartonNormal,
    'priceUnitNormal': priceUnitNormal,
    'priceCartonSpecial': priceCartonSpecial,
    'priceUnitSpecial': priceUnitSpecial,
    'imagePath': imagePath,
    'isAvailable': isAvailable,
    'discount': discount,
    'sellType': sellType.name,
    'maxQtyNormal': maxQtyNormal,
    'maxQtySpecial': maxQtySpecial,
    'flavors': flavors.map((f) => f.toJson()).toList(),
    'isFeatured': isFeatured,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    SellType type = SellType.cartonOnly;
    final s = _s(json['sellType']);
    if (s == 'unitOnly' || s == 'unit') type = SellType.unitOnly;
    if (s == 'both') type = SellType.both;

    // ✅ قراءة آمنة للأذواق
    final list = <FlavorModel>[];
    final raw = json['flavors'];
    if (raw is List) {
      for (final f in raw) {
        final fm = FlavorModel.fromJson(f);
        if (fm.name.isNotEmpty) list.add(fm);
      }
    }

    return Product(
      id: _s(json['id']),
      brandId: _s(json['brandId']),
      categoryId: _s(json['categoryId']),
      name: _s(json['name']),
      priceCartonNormal: _d(json['priceCartonNormal']),
      priceUnitNormal: _d(json['priceUnitNormal']),
      priceCartonSpecial: _d(json['priceCartonSpecial']),
      priceUnitSpecial: _d(json['priceUnitSpecial']),
      imagePath: _s(json['imagePath']),
      isAvailable: _b(json['isAvailable'], def: true),
      discount: _d(json['discount']),
      sellType: type,
      maxQtyNormal: _i(json['maxQtyNormal']),
      maxQtySpecial: _i(json['maxQtySpecial']),
      flavors: list,
      isFeatured: _b(json['isFeatured']),
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   CartItem
// ══════════════════════════════════════════════════════════
class CartItem {
  final Product product;
  int quantity;
  final bool isSpecialPrice;
  final bool isCarton;
  final String? flavor;

  /// ✅ سعر مخصّص لهذه الطلبية فقط (يحدده الأدمن من شاشة السلة).
  /// لا يغيّر سعر المنتج الأصلي في قاعدة البيانات — قيمة مؤقتة في الذاكرة.
  double? overridePrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isSpecialPrice = false,
    this.isCarton = true,
    this.flavor,
    this.overridePrice,
  });

  /// ✅ سعر الوحدة الأصلي (بدون أي تعديل) — يُستخدم لعرض المقارنة عند التعديل
  double get originalUnitPrice {
    if (isCarton) {
      return isSpecialPrice
          ? product.discountedPrice(product.priceCartonSpecial)
          : product.discountedPrice(product.priceCartonNormal);
    } else {
      return isSpecialPrice
          ? product.discountedPrice(product.priceUnitSpecial)
          : product.discountedPrice(product.priceUnitNormal);
    }
  }

  bool get hasOverridePrice => overridePrice != null;

  double get unitPrice {
    if (overridePrice != null) return overridePrice!;
    return originalUnitPrice;
  }

  double get totalPrice => unitPrice * quantity;
  String get typeLabel => isCarton ? 'كرتون' : 'حبة';

  /// ✅ للحفظ في الطلب — نفس المفاتيح المستخدمة في الطباعة والـ PDF
  Map<String, dynamic> toOrderItem() => {
    'productId': product.id,
    'productName': product.name,
    'quantity': quantity,
    'price': unitPrice,
    'unitPrice': unitPrice,
    'isCarton': isCarton,
    'typeLabel': typeLabel,
    'flavor': flavor ?? '',
  };
}

// ══════════════════════════════════════════════════════════
//   ✅ Order  — مُحدَّث
// ══════════════════════════════════════════════════════════
class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final List<Map<String, dynamic>> items;
  final double total;
  final bool isSpecialPrice;
  final String date;
  final String userId;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double paidAmount;      // ✅ التسديد
  final double remainingBalance; // ✅ الدين المتبقي

  // ✅ جديد
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.total,
    required this.isSpecialPrice,
    required this.date,
    this.userId = '',
    this.status = 'pending',
    this.latitude,
    this.longitude,
    this.address,
    this.paidAmount = 0,
    this.remainingBalance = 0,
    this.createdAt,
    this.updatedAt,
  });

  // ✅ إنشاء طلب جديد بسهولة
  factory Order.create({
    required String userId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required double total,
    bool isSpecialPrice = false,
    double? latitude,
    double? longitude,
    String? address,
    double paidAmount = 0,
    double remainingBalance = 0,
  }) {
    final now = DateTime.now();
    return Order(
      id: now.millisecondsSinceEpoch.toString(),
      userId: userId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      total: total,
      isSpecialPrice: isSpecialPrice,
      date: fmtDate(now),
      status: 'pending',
      latitude: latitude,
      longitude: longitude,
      address: address,
      paidAmount: paidAmount,
      remainingBalance: remainingBalance,
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'items': items,
    'total': total,
    'isSpecialPrice': isSpecialPrice,
    'date': date,
    'userId': userId,
    'status': status,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'paidAmount': paidAmount,
    'remainingBalance': remainingBalance,
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    // ✅ قراءة آمنة للعناصر
    final list = <Map<String, dynamic>>[];
    final raw = json['items'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) list.add(Map<String, dynamic>.from(e));
      }
    }

    final created = _dt(json['createdAt']);

    // ✅ لو date فارغ نولّده من createdAt
    String date = _s(json['date']);
    if (date.trim().isEmpty && created != null) date = fmtDate(created);

    // ✅ لو total = 0 نحسبه من العناصر
    double total = _d(json['total']);
    if (total <= 0 && list.isNotEmpty) {
      for (final it in list) {
        total += _d(it['price']) * _d(it['quantity']);
      }
    }

    return Order(
      id: _s(json['id']),
      customerName: _s(json['customerName']),
      customerPhone: _s(json['customerPhone']),
      items: list,
      total: total,
      isSpecialPrice: _b(json['isSpecialPrice']),
      date: date,
      userId: _s(json['userId']),
      status: _s(json['status']).isEmpty ? 'pending' : _s(json['status']),
      latitude: json['latitude'] == null ? null : _d(json['latitude']),
      longitude: json['longitude'] == null ? null : _d(json['longitude']),
      address: json['address'] == null ? null : _s(json['address']),
      paidAmount: _d(json['paidAmount']),
      remainingBalance: _d(json['remainingBalance']),
      createdAt: created,
      updatedAt: _dt(json['updatedAt']),
    );
  }

  Order copyWith({
    String? status,
    double? latitude,
    double? longitude,
    String? address,
    double? total,
    List<Map<String, dynamic>>? items,
    double? paidAmount,
    double? remainingBalance,
  }) =>
      Order(
        id: id,
        customerName: customerName,
        customerPhone: customerPhone,
        items: items ?? this.items,
        total: total ?? this.total,
        isSpecialPrice: isSpecialPrice,
        date: date,
        userId: userId,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        paidAmount: paidAmount ?? this.paidAmount,
        remainingBalance: remainingBalance ?? this.remainingBalance,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  // ── مساعدات ──
  String get shortId => id.length > 6 ? id.substring(id.length - 6) : id;

  int get itemsCount => items.length;

  int get totalQuantity => items.fold(0, (s, it) => s + _i(it['quantity']));

  bool get hasLocation => latitude != null && longitude != null;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';

  String get statusLabel => switch (status) {
    'confirmed' => '✅ مؤكد',
    'rejected' => '❌ مرفوض',
    _ => '⏳ قيد المراجعة',
  };

  /// ✅ تاريخ الطلب كـ DateTime (createdAt أولاً ثم فكّ نص date)
  DateTime? get dateTime {
    if (createdAt != null) return createdAt;
    try {
      final parts = date.split(' - ');
      final dp = parts[0].split('/');
      if (dp.length < 3) return null;
      int h = 0, m = 0;
      if (parts.length > 1) {
        final tp = parts[1].split(':');
        h = int.tryParse(tp[0]) ?? 0;
        if (tp.length > 1) m = int.tryParse(tp[1]) ?? 0;
      }
      return DateTime(
        int.parse(dp[2]),
        int.parse(dp[1]),
        int.parse(dp[0]),
        h,
        m,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) => other is Order && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   UserModel
// ══════════════════════════════════════════════════════════
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String createdAt;
  final String fcmToken;
  final double? latitude;
  final double? longitude;
  final String? address;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.fcmToken = '',
    this.latitude,
    this.longitude,
    this.address,
  });

  bool get isAdmin => role == 'admin';
  bool get isSpecial => role == 'user_special';
  bool get isNormal => role == 'user_normal';

  /// المدير يرى الأسعار الخاصة أيضاً
  bool get seesSpecialPrice => isAdmin || isSpecial;

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'user_special':
        return 'مميز';
      default:
        return 'عادي';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'createdAt': createdAt,
    'fcmToken': fcmToken,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: _s(json['id']),
    name: _s(json['name']),
    email: _s(json['email']),
    phone: _s(json['phone']),
    role: _s(json['role']).isEmpty ? 'user_normal' : _s(json['role']),
    createdAt: _s(json['createdAt']), // ✅ آمن من Timestamp
    fcmToken: _s(json['fcmToken']),
    latitude: json['latitude'] == null ? null : _d(json['latitude']),
    longitude: json['longitude'] == null ? null : _d(json['longitude']),
    address: json['address'] == null ? null : _s(json['address']),
  );

  UserModel copyWith({String? role, String? name, String? phone}) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        createdAt: createdAt,
        fcmToken: fcmToken,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   AnnouncementModel
// ══════════════════════════════════════════════════════════
class AnnouncementModel {
  final String id;
  final String message;
  final String type;
  final bool isActive;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.message,
    required this.type,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'type': type,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: _s(json['id']),
        message: _s(json['message']),
        type: _s(json['type']).isEmpty ? 'general' : _s(json['type']),
        isActive: _b(json['isActive'], def: true),
        // ✅ لا ينهار مع Timestamp
        createdAt: _dt(json['createdAt']) ?? DateTime.now(),
      );

  String get emoji => switch (type) {
    'offer' => '🎉',
    'warning' => '⚠️',
    'info' => 'ℹ️',
    _ => '📢',
  };

  Color get color => switch (type) {
    'offer' => const Color(0xFF43A047),
    'warning' => Colors.orange,
    'info' => Colors.blue,
    _ => const Color(0xFF2E7D32),
  };

  @override
  bool operator ==(Object other) =>
      other is AnnouncementModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   ✅ CustomerModel — دليل الزبائن (لأغراض الديون)
// ══════════════════════════════════════════════════════════
class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final double balance; // إجمالي الدين الحالي (موجب = عليه دين للمحل)
  final DateTime? createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.balance = 0,
    this.createdAt,
  });

  bool get hasDebt => balance > 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address ?? '',
    'balance': balance,
  };

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: _s(json['id']),
    name: _s(json['name']),
    phone: _s(json['phone']),
    address: _s(json['address']).isEmpty ? null : _s(json['address']),
    balance: _d(json['balance']),
    createdAt: _dt(json['createdAt']),
  );

  CustomerModel copyWith({
    String? name,
    String? phone,
    String? address,
    double? balance,
  }) =>
      CustomerModel(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        balance: balance ?? this.balance,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is CustomerModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════
//   ✅ DebtTransactionModel — سجل حركات الدين (إضافة / تسديد)
// ══════════════════════════════════════════════════════════
class DebtTransactionModel {
  final String id;
  final String customerId;
  final String type; // 'charge' (إضافة دين) أو 'payment' (تسديد)
  final double amount;
  final String note;
  final DateTime? createdAt;

  DebtTransactionModel({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    this.note = '',
    this.createdAt,
  });

  bool get isCharge => type == 'charge';
  bool get isPayment => type == 'payment';

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'type': type,
    'amount': amount,
    'note': note,
  };

  factory DebtTransactionModel.fromJson(Map<String, dynamic> json) =>
      DebtTransactionModel(
        id: _s(json['id']),
        customerId: _s(json['customerId']),
        type: _s(json['type']).isEmpty ? 'charge' : _s(json['type']),
        amount: _d(json['amount']),
        note: _s(json['note']),
        createdAt: _dt(json['createdAt']),
      );

  @override
  bool operator ==(Object other) =>
      other is DebtTransactionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}