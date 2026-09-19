import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // ✅ أضفنا هذا الاستيراد
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/printer_service.dart';
import '../utils/converters.dart';
import 'stats_screen.dart';

part 'admin_manage_tab.dart';
part 'admin_users_tab.dart';

class AdminScreen extends StatefulWidget {
  final int initialTab;
  const AdminScreen({super.key, this.initialTab = 0});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  double _d(dynamic v) => toDouble(v);
  int _i(dynamic v) => toInt(v);

  final brandNameController = TextEditingController();
  final productNameController = TextEditingController();
  final cartonNormalController = TextEditingController();
  final unitNormalController = TextEditingController();
  final cartonSpecialController = TextEditingController();
  final unitSpecialController = TextEditingController();
  final discountController = TextEditingController();
  final maxQtyNormalController = TextEditingController();
  final maxQtySpecialController = TextEditingController();
  final flavorController = TextEditingController();
  final announcementController = TextEditingController();
  final categoryNameController = TextEditingController();
  final categoryIconController = TextEditingController();
  final categoryOrderController = TextEditingController();
  final bannerTitleController = TextEditingController();
  final bannerSubtitleController = TextEditingController();
  final bannerOrderController = TextEditingController();
  final purchasePriceController = TextEditingController();
  final purchasePriceCartonController = TextEditingController(); // ✅ جديد
  final stockQuantityController = TextEditingController();
  final unitsPerCartonController = TextEditingController(text: '1'); // ✅ جديد

  List<Brand> brands = [];
  List<Product> products = [];
  List<UserModel> users = [];
  List<Category> categories = [];
  List<BannerModel> banners = [];
  List<Order> orders = [];

  Brand? selectedBrand;
  Brand? selectedBrandForProducts;
  Category? selectedCategoryForBrand;
  Category? selectedCategoryForProduct;

  String? brandLogoPath;
  String? productImagePath;
  String? bannerImagePath;

  SellType selectedSellType = SellType.cartonOnly;
  List<FlavorModel> newProductFlavors = [];

  final picker = ImagePicker();

  bool _isLoading = true;
  bool isLoadingBrand = false;
  bool isLoadingProduct = false;
  bool isLoadingBanner = false;
  bool isSpecialPrice = false;
  bool isLoadingOrders = false;

  late int _currentTab; // ✅ تغيير من const إلى late
  DateTime? _selectedFilterDate; // ✅
  String _selectedAnnType = 'general';

  Color _selectedBannerColor = const Color(0xFF2E7D32);
  IconData _selectedBannerIcon = Icons.local_offer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isDisposed = false;
  bool _isActive = true;

  // ✅ بوابة كلمة سر لوحة الإدارة
  bool _checkingPassword = true;
  bool _isUnlocked = false;
  bool _isSettingNewPassword = false;
  final _adminPasswordController = TextEditingController();
  final _adminPasswordConfirmController = TextEditingController();
  bool _obscureAdminPassword = true;
  String? _passwordError;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab; // ✅
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _checkAdminPassword();

    // ✅ مراقبة تغييرات الأسعار لحساب الربح والتحويل التلقائي
    purchasePriceCartonController.addListener(_onCartonPriceChanged);
    unitsPerCartonController.addListener(_onCartonPriceChanged);
    
    // مستمعين لتحديث واجهة الربح عند تغيير أسعار البيع
    cartonNormalController.addListener(refresh);
    unitNormalController.addListener(refresh);
    cartonSpecialController.addListener(refresh);
    unitSpecialController.addListener(refresh);
    purchasePriceController.addListener(refresh);
  }

  void _onCartonPriceChanged() {
    final pCarton = double.tryParse(purchasePriceCartonController.text.replaceAll(',', '.')) ?? 0;
    final units = double.tryParse(unitsPerCartonController.text) ?? 1;
    if (pCarton > 0 && units > 0) {
      final pUnit = pCarton / units;
      // تحديث سعر الحبة فقط إذا لم يكن المستخدم يكتب فيه حالياً (لتجنب الحلقات اللانهائية)
      if (purchasePriceController.text != pUnit.toStringAsFixed(2)) {
        purchasePriceController.text = pUnit.toStringAsFixed(2);
      }
    }
    refresh();
  }

  Future<void> _checkAdminPassword() async {
    final stored = await DataService.getAdminPassword();
    if (!mounted) return;
    setState(() {
      _isSettingNewPassword = stored == null || stored.isEmpty;
      _checkingPassword = false;
    });
  }

  Future<void> _submitAdminPassword() async {
    final entered = _adminPasswordController.text.trim();
    if (entered.isEmpty) {
      setState(() => _passwordError = 'أدخل كلمة السر');
      return;
    }

    if (_isSettingNewPassword) {
      final confirm = _adminPasswordConfirmController.text.trim();
      if (entered.length < 4) {
        setState(() =>
        _passwordError = 'كلمة السر قصيرة جدًا (4 أحرف على الأقل)');
        return;
      }
      if (entered != confirm) {
        setState(() => _passwordError = 'كلمتا السر غير متطابقتين');
        return;
      }
      await DataService.setAdminPassword(entered);
      if (!mounted) return;
      setState(() {
        _isUnlocked = true;
        _passwordError = null;
      });
      _loadAll();
      return;
    }

    final stored = await DataService.getAdminPassword();
    if (entered == stored) {
      if (!mounted) return;
      setState(() {
        _isUnlocked = true;
        _passwordError = null;
      });
      _loadAll();
    } else {
      setState(() => _passwordError = 'كلمة السر غير صحيحة');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isActive = false;
    } else if (state == AppLifecycleState.resumed) {
      _isActive = true;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
    brandNameController.dispose();
    productNameController.dispose();
    cartonNormalController.dispose();
    unitNormalController.dispose();
    cartonSpecialController.dispose();
    unitSpecialController.dispose();
    discountController.dispose();
    maxQtyNormalController.dispose();
    maxQtySpecialController.dispose();
    flavorController.dispose();
    announcementController.dispose();
    categoryNameController.dispose();
    categoryIconController.dispose();
    categoryOrderController.dispose();
    bannerTitleController.dispose();
    bannerSubtitleController.dispose();
    bannerOrderController.dispose();
    purchasePriceController.dispose();
    stockQuantityController.dispose();
    unitsPerCartonController.dispose();
    purchasePriceCartonController.dispose(); // ✅ جديد
    _adminPasswordController.dispose();
    _adminPasswordConfirmController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted || _isDisposed) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        loadCategories(),
        loadBrands(),
        loadPriceSettings(),
        loadUsers(),
        loadBanners(),
        loadOrders(),
      ]);
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('❌ _loadAll error: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
        _showSnackBar('حدث خطأ أثناء تحميل الإعدادات', Colors.red);
      }
    }
  }

  Future<void> loadPriceSettings() async {
    try {
      final special = await DataService.getIsSpecialPrice();
      if (mounted && !_isDisposed) setState(() => isSpecialPrice = special);
    } catch (_) {}
  }

  Future<void> loadCategories() async {
    try {
      final data = await DataService.getCategories();
      if (mounted && !_isDisposed) setState(() => categories = data);
    } catch (_) {
      if (mounted && !_isDisposed) setState(() => categories = []);
    }
  }

  Future<void> loadBrands() async {
    try {
      final data = await DataService.getBrands();
      if (!mounted || _isDisposed) return;
      setState(() {
        brands = data;
        if (brands.isNotEmpty) {
          selectedBrand ??= brands.first;
          selectedBrandForProducts ??= brands.first;
          if (!brands.any((b) => b.id == selectedBrand?.id)) {
            selectedBrand = brands.first;
          }
          if (!brands.any((b) => b.id == selectedBrandForProducts?.id)) {
            selectedBrandForProducts = brands.first;
          }
        } else {
          selectedBrand = null;
          selectedBrandForProducts = null;
          products = [];
        }
      });
      if (brands.isNotEmpty) {
        await loadProducts(
            selectedBrandForProducts?.id ?? brands.first.id);
      }
    } catch (_) {
      if (mounted && !_isDisposed) {
        setState(() {
          brands = [];
          products = [];
          selectedBrand = null;
          selectedBrandForProducts = null;
        });
      }
    }
  }

  Future<void> loadProducts(String brandId) async {
    try {
      if (brandId.isEmpty) {
        if (mounted && !_isDisposed) setState(() => products = []);
        return;
      }
      final data = await DataService.getProducts(brandId);
      if (mounted && !_isDisposed) setState(() => products = data);
    } catch (_) {
      if (mounted && !_isDisposed) setState(() => products = []);
    }
  }

  Future<void> loadUsers() async {
    try {
      final data = await AuthService.getAllUsers();
      if (mounted && !_isDisposed) setState(() => users = data);
    } catch (_) {
      if (mounted && !_isDisposed) setState(() => users = []);
    }
  }

  Future<void> loadBanners() async {
    try {
      final data = await DataService.getAllBanners();
      if (mounted && !_isDisposed) setState(() => banners = data);
    } catch (_) {
      if (mounted && !_isDisposed) setState(() => banners = []);
    }
  }

  Future<void> loadOrders() async {
    try {
      if (mounted && !_isDisposed) setState(() => isLoadingOrders = true);
      final data = await DataService.getAllOrders();
      if (mounted && !_isDisposed) {
        setState(() {
          orders = data;
          isLoadingOrders = false;
        });
      }
    } catch (e) {
      debugPrint('❌ loadOrders: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          orders = [];
          isLoadingOrders = false;
        });
      }
    }
  }

  Brand? _safeBrandValue(Brand? value) {
    if (value == null) return null;
    for (final b in brands) {
      if (b.id == value.id) return b;
    }
    return null;
  }

  Category? _safeCategoryValue(Category? value) {
    if (value == null) return null;
    for (final c in categories) {
      if (c.id == value.id) return c;
    }
    return null;
  }

  Category? _categoryById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
            const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _sellTypeLabel(SellType type) {
    switch (type) {
      case SellType.unitOnly:
        return 'حبة فقط';
      case SellType.both:
        return 'كرتون + حبة';
      default:
        return 'كرتون فقط';
    }
  }

  Future<double?> _showEditSinglePriceDialog(double currentPrice, String productName) async {
    final ctrl = TextEditingController(text: currentPrice.toStringAsFixed(0));
    return await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل سعر $productName'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'DA'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showSelectProductForOrder() async {
    final products = await DataService.getAllProducts();
    if (products.isEmpty) return null;

    String query = '';
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('اختر منتجاً لإضافته'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'بحث...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setSt(() => query = v.toLowerCase()),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final p = products[i];
                      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) return const SizedBox.shrink();
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.priceCartonNormal.toStringAsFixed(0)} DA'),
                        onTap: () {
                          Navigator.pop(context, {
                            'productId': p.id,
                            'productName': p.name,
                            'quantity': 1,
                            'price': p.priceCartonNormal,
                            'unitPrice': p.priceCartonNormal,
                            'isCarton': true,
                            'typeLabel': 'كرتون',
                            'flavor': '',
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showPrintDialog(Order order) async {
    if (!mounted) return;
    if (!PrinterService.isConnected) {
      _showSnackBar('⚠️ يرجى الاتصال بطابعة أولاً', Colors.orange);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.print, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'طباعة الطلب',
                style:
                TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الزبون: ${order.customerName}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الهاتف: ${order.customerPhone}'),
            Text('عدد المنتجات: ${order.items.length}'),
            const Divider(),
            Text(
              'الطابعة: ${PrinterService.connectedDeviceName ?? "غير معروف"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF2E7D32)),
                          SizedBox(height: 16),
                          Text('جاري الطباعة...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              final success = await PrinterService.printReceipt(
                order: order,
                customerName: order.customerName,
                customerPhone: order.customerPhone,
              );
              if (!mounted) return;
              Navigator.pop(context);
              if (success) {
                _showSnackBar(
                    '✅ تمت الطباعة بنجاح', const Color(0xFF2E7D32));
              } else {
                _showSnackBar('❌ فشلت الطباعة', Colors.red);
              }
            },
            icon: const Icon(Icons.print, color: Colors.white),
            label:
            const Text('طباعة', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickAndCropImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر مصدر الصورة',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'الكاميرا',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.camera),
                  ),
                  _imageSourceButton(
                    icon: Icons.photo_library,
                    label: 'المعرض',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
      if (source == null) return null;
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        requestFullMetadata: false, // ✅ لضمان عدم التعليق في iOS بسبب الخصوصية
      );
      if (picked == null) return null;

      // ✅ في الويب، نتجاوز عملية القص لضمان عمل الإضافة بدون تعليق
      if (kIsWeb) return picked.path;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'قص الصورة',
            toolbarColor: const Color(0xFF2E7D32),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF2E7D32),
          ),
          IOSUiSettings(
            title: 'قص الصورة',
            cancelButtonTitle: 'إلغاء',
            doneButtonTitle: 'تم',
          ),
        ],
      );
      return cropped?.path;
    } catch (e) {
      debugPrint('❌ pick image: $e');
      return null;
    }
  }

  Future<void> pickImage(bool isBrand) async {
    final path = await _pickAndCropImage();
    if (path == null || !mounted) return;
    setState(() {
      if (isBrand) {
        brandLogoPath = path;
      } else {
        productImagePath = path;
      }
    });
  }

  Future<void> pickBannerImage() async {
    final path = await _pickAndCropImage();
    if (path == null || !mounted) return;
    setState(() => bannerImagePath = path);
  }

  Future<void> addCategory() async {
    if (categoryNameController.text.trim().isEmpty) {
      _showSnackBar('أدخل اسم الفئة', Colors.red);
      return;
    }
    try {
      final category = Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: categoryNameController.text.trim(),
        icon: categoryIconController.text.trim().isNotEmpty
            ? categoryIconController.text.trim()
            : '📦',
        order: int.tryParse(categoryOrderController.text.trim()) ?? 0,
      );
      await DataService.saveCategory(category);
      categoryNameController.clear();
      categoryIconController.clear();
      categoryOrderController.clear();
      await loadCategories();
      _showSnackBar('✅ تم إضافة الفئة', const Color(0xFF2E7D32));
    } catch (e) {
      _showSnackBar('فشل إضافة الفئة: $e', Colors.red);
    }
  }

  Future<void> addBrand() async {
    if (brandNameController.text.isEmpty) {
      _showSnackBar('أدخل اسم العلامة التجارية', Colors.red);
      return;
    }
    setState(() => isLoadingBrand = true);
    try {
      debugPrint('🔨 بدء عملية إضافة العلامة: ${brandNameController.text}');
      final brand = Brand(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: brandNameController.text.trim(),
        logoPath: '',
        categoryId: selectedCategoryForBrand?.id ?? '',
      );
      
      debugPrint('📸 رفع الصورة للعلامة...');
      await DataService.saveBrand(brand, logoPath: brandLogoPath);
      
      debugPrint('✅ تم حفظ العلامة في Firestore');
      brandNameController.clear();
      setState(() {
        brandLogoPath = null;
        selectedCategoryForBrand = null;
        isLoadingBrand = false;
      });
      await loadBrands();
      _showSnackBar(
          '✅ ${brand.name} تم الإضافة', const Color(0xFF2E7D32));
    } catch (e) {
      debugPrint('❌ خطأ في addBrand: $e');
      if (mounted) setState(() => isLoadingBrand = false);
      _showSnackBar('فشل إضافة العلامة: $e', Colors.red);
    }
  }

  Future<void> addProduct() async {
    if (productNameController.text.isEmpty || selectedBrand == null) {
      _showSnackBar(
          'أدخل اسم المنتج واختر العلامة التجارية', Colors.red);
      return;
    }
    setState(() => isLoadingProduct = true);
    try {
      debugPrint('🔨 بدء عملية إضافة المنتج: ${productNameController.text}');
      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        brandId: selectedBrand!.id,
        categoryId: selectedCategoryForProduct?.id ?? '',
        name: productNameController.text.trim(),
        priceCartonNormal:
        double.tryParse(cartonNormalController.text) ?? 0,
        priceUnitNormal:
        double.tryParse(unitNormalController.text) ?? 0,
        priceCartonSpecial:
        double.tryParse(cartonSpecialController.text) ?? 0,
        priceUnitSpecial:
        double.tryParse(unitSpecialController.text) ?? 0,
        discount: double.tryParse(discountController.text) ?? 0,
        sellType: selectedSellType,
        maxQtyNormal:
        int.tryParse(maxQtyNormalController.text) ?? 0,
        maxQtySpecial:
        int.tryParse(maxQtySpecialController.text) ?? 0,
        flavors: newProductFlavors,
        purchasePrice: double.tryParse(purchasePriceController.text) ?? 0,
        stockQuantity: int.tryParse(stockQuantityController.text) ?? 0,
        unitsPerCarton: int.tryParse(unitsPerCartonController.text) ?? 1,
      );
      
      debugPrint('📸 رفع الصورة للمنتج...');
      await DataService.saveProduct(product, imagePath: productImagePath);
      
      debugPrint('✅ تم حفظ المنتج في Firestore');
      productNameController.clear();
      purchasePriceCartonController.clear(); // ✅ جديد
      cartonNormalController.clear();
      unitNormalController.clear();
      cartonSpecialController.clear();
      unitSpecialController.clear();
      discountController.clear();
      maxQtyNormalController.clear();
      maxQtySpecialController.clear();
      flavorController.clear();
      purchasePriceController.clear();
      stockQuantityController.clear();
      setState(() {
        productImagePath = null;
        selectedSellType = SellType.cartonOnly;
        selectedCategoryForProduct = null;
        newProductFlavors = [];
        isLoadingProduct = false;
      });
      if (selectedBrandForProducts != null) {
        await loadProducts(selectedBrandForProducts!.id);
      }
      _showSnackBar(
          '✅ ${product.name} تم الإضافة', const Color(0xFF2E7D32));
    } catch (e) {
      debugPrint('❌ خطأ في addProduct: $e');
      if (mounted) setState(() => isLoadingProduct = false);
      _showSnackBar('فشل إضافة المنتج: $e', Colors.red);
    }
  }

  Future<void> addAnnouncement() async {
    if (announcementController.text.trim().isEmpty) {
      _showSnackBar('أدخل نص الإعلان', Colors.red);
      return;
    }
    try {
      final announcement = AnnouncementModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: announcementController.text.trim(),
        type: _selectedAnnType,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await DataService.saveAnnouncement(announcement);
      announcementController.clear();
      _showSnackBar('✅ تم نشر الإعلان', const Color(0xFF2E7D32));
    } catch (e) {
      _showSnackBar('فشل نشر الإعلان: $e', Colors.red);
    }
  }

  Future<void> addBanner() async {
    if (bannerTitleController.text.trim().isEmpty) {
      _showSnackBar('أدخل عنوان البانر', Colors.red);
      return;
    }
    setState(() => isLoadingBanner = true);
    try {
      final banner = BannerModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: bannerTitleController.text.trim(),
        subtitle: bannerSubtitleController.text.trim(),
        color: _selectedBannerColor,
        icon: _selectedBannerIcon,
        isActive: true,
        order: int.tryParse(bannerOrderController.text.trim()) ?? 0,
      );
      await DataService.saveBanner(banner, imagePath: bannerImagePath);
      bannerTitleController.clear();
      bannerSubtitleController.clear();
      bannerOrderController.clear();
      setState(() {
        bannerImagePath = null;
        isLoadingBanner = false;
        _selectedBannerColor = const Color(0xFF2E7D32);
        _selectedBannerIcon = Icons.local_offer;
      });
      await loadBanners();
      _showSnackBar('✅ تم إضافة البانر', const Color(0xFF2E7D32));
    } catch (e) {
      if (mounted) setState(() => isLoadingBanner = false);
      _showSnackBar('فشل إضافة البانر: $e', Colors.red);
    }
  }

  Future<void> deleteCategory(Category category) async {
    final confirm = await _showConfirmDialog(
      title: 'حذف الفئة',
      content: 'هل تريد حذف ${category.name}؟',
    );
    if (confirm == true) {
      await DataService.deleteCategory(category.id);
      await loadCategories();
      await loadBrands();
      _showSnackBar('تم حذف الفئة', Colors.grey);
    }
  }

  Future<void> deleteBrand(Brand brand) async {
    final confirm = await _showConfirmDialog(
      title: 'حذف العلامة التجارية',
      content: 'هل تريد حذف ${brand.name} وجميع منتجاتها؟',
    );
    if (confirm == true) {
      await DataService.deleteBrand(brand.id);
      await loadBrands();
      _showSnackBar('${brand.name} تم الحذف', Colors.grey);
    }
  }

  Future<void> deleteProduct(Product product) async {
    final confirm = await _showConfirmDialog(
      title: 'حذف المنتج',
      content: 'هل تريد حذف ${product.name}؟',
    );
    if (confirm == true) {
      await DataService.deleteProduct(product.id);
      if (selectedBrandForProducts != null) {
        await loadProducts(selectedBrandForProducts!.id);
      }
      _showSnackBar('${product.name} تم الحذف', Colors.grey);
    }
  }

  Future<void> deleteBanner(BannerModel banner) async {
    final confirm = await _showConfirmDialog(
      title: 'حذف البانر',
      content: 'هل تريد حذف "${banner.title}"؟',
    );
    if (confirm == true) {
      await DataService.deleteBanner(banner.id);
      await loadBanners();
      _showSnackBar('تم حذف البانر', Colors.grey);
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    await DataService.deleteAnnouncement(id);
    _showSnackBar('تم حذف الإعلان', Colors.grey);
  }

  Future<void> _showEditCategoryDialog(Category category) async {
    final nameCtrl = TextEditingController(text: category.name);
    final iconCtrl = TextEditingController(text: category.icon);
    final orderCtrl =
    TextEditingController(text: category.order.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل الفئة',
            style: TextStyle(color: Color(0xFF2E7D32))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(nameCtrl, 'اسم الفئة'),
            const SizedBox(height: 10),
            _dialogField(iconCtrl, 'الأيقونة'),
            const SizedBox(height: 10),
            _dialogField(orderCtrl, 'الترتيب',
                type: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Category(
                id: category.id,
                name: nameCtrl.text.trim(),
                icon: iconCtrl.text.trim().isNotEmpty
                    ? iconCtrl.text.trim()
                    : '📦',
                order: int.tryParse(orderCtrl.text.trim()) ?? 0,
              );
              await DataService.saveCategory(updated);
              await loadCategories();
              if (!mounted) return;
              Navigator.pop(context);
              _showSnackBar(
                  '✅ تم تعديل الفئة', const Color(0xFF2E7D32));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBrandDialog(Brand brand) async {
    final nameCtrl = TextEditingController(text: brand.name);
    String? newLogoPath;
    Category? selectedCat = _categoryById(brand.categoryId);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل العلامة التجارية',
              style: TextStyle(color: Color(0xFF2E7D32))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final path = await _pickAndCropImage();
                    if (path != null) setSt(() => newLogoPath = path);
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF2E7D32)),
                    ),
                    child: newLogoPath != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(newLogoPath!, fit: BoxFit.cover)
                          : Image.file(File(newLogoPath!), fit: BoxFit.cover),
                    )
                        : const Icon(Icons.add_a_photo,
                        color: Color(0xFF2E7D32), size: 35),
                  ),
                ),
                const SizedBox(height: 12),
                _dialogField(nameCtrl, 'اسم العلامة التجارية'),
                const SizedBox(height: 10),
                DropdownButtonFormField<Category>(
                  value: _safeCategoryValue(selectedCat),
                  hint: const Text('اختر الفئة'),
                  style: const TextStyle(color: Colors.black87),
                  items: categories
                      .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.icon} ${c.name}',
                          style: const TextStyle(color: Colors.black87))))
                      .toList(),
                  onChanged: (v) => setSt(() => selectedCat = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = Brand(
                  id: brand.id,
                  name: nameCtrl.text,
                  logoPath: brand.logoPath,
                  categoryId: selectedCat?.id ?? '',
                );
                await DataService.updateBrand(updated,
                    logoPath: newLogoPath);
                await loadBrands();
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar(
                    '✅ تم تعديل العلامة', const Color(0xFF2E7D32));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('حفظ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProductDialog(Product product) async {
    final nameCtrl = TextEditingController(text: product.name);
    final cartonNCtrl = TextEditingController(
        text: product.priceCartonNormal.toString());
    final unitNCtrl = TextEditingController(
        text: product.priceUnitNormal.toString());
    final cartonSCtrl = TextEditingController(
        text: product.priceCartonSpecial.toString());
    final unitSCtrl = TextEditingController(
        text: product.priceUnitSpecial.toString());
    final discountCtrl =
    TextEditingController(text: product.discount.toString());
    final maxNCtrl =
    TextEditingController(text: product.maxQtyNormal.toString());
    final maxSCtrl =
    TextEditingController(text: product.maxQtySpecial.toString());
    final buyPriceCtrl = TextEditingController(text: product.purchasePrice.toString());
    final upcCtrl = TextEditingController(text: product.unitsPerCarton.toString()); 
    final buyPriceCartonCtrl = TextEditingController(text: (product.purchasePrice * product.unitsPerCarton).toStringAsFixed(0)); // ✅ جديد
    final stockCtrl = TextEditingController(text: product.stockQuantity.toString());

    // تحديث سعر الحبة تلقائياً عند تغيير سعر الكرتون في الدايالوج
    void onEditCartonPriceChanged() {
      final pC = double.tryParse(buyPriceCartonCtrl.text.replaceAll(',', '.')) ?? 0;
      final u = double.tryParse(upcCtrl.text) ?? 1;
      if (pC > 0 && u > 0) {
        buyPriceCtrl.text = (pC / u).toStringAsFixed(2);
      }
    }
    buyPriceCartonCtrl.addListener(onEditCartonPriceChanged);
    upcCtrl.addListener(onEditCartonPriceChanged);

    final editFlavorController = TextEditingController();
    String? newImagePath;
    SellType editSellType = product.sellType;
    List<FlavorModel> editFlavors =
    List<FlavorModel>.from(product.flavors);
    bool editIsFeatured = product.isFeatured;
    Category? editCategory = _categoryById(product.categoryId);
    
    // تحديث سعر الحبة تلقائياً عند تغيير سعر الكرتون في الدايالوج
    void onEditCartonPriceChanged() {
      final pC = double.tryParse(buyPriceCartonCtrl.text.replaceAll(',', '.')) ?? 0;
      final u = double.tryParse(upcCtrl.text) ?? 1;
      if (pC > 0 && u > 0) {
        buyPriceCtrl.text = (pC / u).toStringAsFixed(2);
      }
    }
    buyPriceCartonCtrl.addListener(onEditCartonPriceChanged);
    upcCtrl.addListener(onEditCartonPriceChanged);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) {
          // إضافة مستمعين لتحديث واجهة الربح في الدايالوج
          void onUpdate() { if (context.mounted) setSt(() {}); }
          buyPriceCtrl.removeListener(onUpdate); buyPriceCtrl.addListener(onUpdate);
          buyPriceCartonCtrl.removeListener(onUpdate); buyPriceCartonCtrl.addListener(onUpdate);
          upcCtrl.removeListener(onUpdate); upcCtrl.addListener(onUpdate);
          cartonNCtrl.removeListener(onUpdate); cartonNCtrl.addListener(onUpdate);
          unitNCtrl.removeListener(onUpdate); unitNCtrl.addListener(onUpdate);

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('تعديل المنتج',
                style: TextStyle(color: Color(0xFF2E7D32))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final path = await _pickAndCropImage();
                      if (path != null)
                        setSt(() => newImagePath = path);
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2E7D32)),
                      ),
                      child: newImagePath != null
                          ? ClipRRect(
                          borderRadius:
                          BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(newImagePath!, fit: BoxFit.cover)
                              : Image.file(File(newImagePath!), fit: BoxFit.cover))
                          : const Icon(Icons.add_a_photo,
                          color: Color(0xFF2E7D32), size: 35),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _dialogField(nameCtrl, 'اسم المنتج'),
                const SizedBox(height: 10),
                DropdownButtonFormField<Category>(
                  value: _safeCategoryValue(editCategory),
                  hint: const Text('اختر الفئة'),
                  style: const TextStyle(color: Colors.black87),
                  items: categories
                      .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.icon} ${c.name}',
                          style: const TextStyle(color: Colors.black87))))
                      .toList(),
                  onChanged: (v) => setSt(() => editCategory = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إدارة المخزن وتكلفة الشراء',
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _dialogField(
                                buyPriceCartonCtrl, 'سعر الكرتون',
                                type: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _dialogField(
                                upcCtrl, 'حبة/كرتون',
                                type: TextInputType.number)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _dialogField(
                                buyPriceCtrl, 'سعر الحبة',
                                type: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _dialogField(
                                stockCtrl, 'الكمية (حبة)',
                                type: TextInputType.number)),
                      ]),
                      _buildProfitIndicator(isDark,
                        pUnitCtrl: buyPriceCtrl,
                        upcCtrl: upcCtrl,
                        sellCCtrl: cartonNCtrl,
                        sellUCtrl: unitNCtrl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: const Color(0xFFE8F5E9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('نوع البيع',
                          style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _sellTypeSelector(editSellType,
                              (v) => setSt(() => editSellType = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: const Color(0xFFE8F5E9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('السعر العادي',
                          style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _dialogField(
                                cartonNCtrl, 'سعر الكرتون',
                                type: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _dialogField(
                                unitNCtrl, 'سعر الحبة',
                                type: TextInputType.number)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: const Color(0xFFFFF8E1),
                  border:
                  Border.all(color: const Color(0xFFFFC107)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('السعر الخاص',
                          style: TextStyle(
                              color: Color(0xFFF57F17),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _dialogField(
                                cartonSCtrl, 'سعر الكرتون',
                                type: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _dialogField(
                                unitSCtrl, 'سعر الحبة',
                                type: TextInputType.number)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: const Color(0xFFFFEBEE),
                  border: Border.all(color: Colors.red.shade200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الخصم (%)',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('0 = بدون خصم',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      const SizedBox(height: 8),
                      _dialogField(discountCtrl, '0',
                          type: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: const Color(0xFFFFF3E0),
                  border:
                  Border.all(color: Colors.orange.shade300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('حد الطلب الأقصى (اختياري)',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('0 = بدون حد',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text('زبون عادي',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight:
                                      FontWeight.bold)),
                              const SizedBox(height: 4),
                              _dialogField(maxNCtrl, '0',
                                  type: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text('زبون مميز',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber,
                                      fontWeight:
                                      FontWeight.bold)),
                              const SizedBox(height: 4),
                              _dialogField(maxSCtrl, '0',
                                  type: TextInputType.number),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildSection(
                  color: Colors.purple.shade50,
                  border:
                  Border.all(color: Colors.purple.shade200),
                  child: Row(children: [
                    const Icon(Icons.star, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('منتج مميز',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    Switch(
                      value: editIsFeatured,
                      activeColor: Colors.purple,
                      onChanged: (v) =>
                          setSt(() => editIsFeatured = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                _buildFlavorsManager(
                  flavors: editFlavors,
                  controller: editFlavorController,
                  onAdd: (f) => setSt(() => editFlavors
                      .add(FlavorModel(name: f, isAvailable: true))),
                  onRemove: (i) =>
                      setSt(() => editFlavors.removeAt(i)),
                  onToggle: (i) => setSt(() => editFlavors[i] =
                      editFlavors[i].copyWith(
                          isAvailable: !editFlavors[i].isAvailable)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = Product(
                  id: product.id,
                  brandId: product.brandId,
                  categoryId: editCategory?.id ?? '',
                  name: nameCtrl.text,
                  priceCartonNormal:
                  double.tryParse(cartonNCtrl.text) ?? 0,
                  priceUnitNormal:
                  double.tryParse(unitNCtrl.text) ?? 0,
                  priceCartonSpecial:
                  double.tryParse(cartonSCtrl.text) ?? 0,
                  priceUnitSpecial:
                  double.tryParse(unitSCtrl.text) ?? 0,
                  imagePath: product.imagePath,
                  isAvailable: product.isAvailable,
                  discount:
                  double.tryParse(discountCtrl.text) ?? 0,
                  sellType: editSellType,
                  maxQtyNormal:
                  int.tryParse(maxNCtrl.text) ?? 0,
                  maxQtySpecial:
                  int.tryParse(maxSCtrl.text) ?? 0,
                  flavors: editFlavors,
                  isFeatured: editIsFeatured,
                  purchasePrice: double.tryParse(buyPriceCtrl.text) ?? 0,
                  unitsPerCarton: int.tryParse(upcCtrl.text) ?? 1,
                  stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
                );
                await DataService.updateProduct(updated,
                    imagePath: newImagePath);
                if (selectedBrandForProducts != null) {
                  await loadProducts(
                      selectedBrandForProducts!.id);
                }
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar(
                    '✅ تم تعديل المنتج', const Color(0xFF2E7D32));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('حفظ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeRoleDialog(UserModel user) async {
    String selectedRole = user.role;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تغيير الدور',
                  style: TextStyle(color: Color(0xFF2E7D32))),
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roleOption(
                role: 'user_normal',
                label: 'زبون عادي',
                description: 'يرى السعر العادي',
                selectedRole: selectedRole,
                color: Colors.blue,
                onTap: () =>
                    setSt(() => selectedRole = 'user_normal'),
              ),
              const SizedBox(height: 8),
              _roleOption(
                role: 'user_special',
                label: 'زبون مميز',
                description: 'يرى السعر الخاص',
                selectedRole: selectedRole,
                color: Colors.amber.shade800,
                onTap: () =>
                    setSt(() => selectedRole = 'user_special'),
              ),
              const SizedBox(height: 8),
              _roleOption(
                role: 'admin',
                label: 'مدير',
                description: 'صلاحيات كاملة',
                selectedRole: selectedRole,
                color: const Color(0xFF2E7D32),
                onTap: () => setSt(() => selectedRole = 'admin'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthService.updateUserRole(
                    user.id, selectedRole);
                await loadUsers();
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar('✅ تم تغيير الدور بنجاح',
                    const Color(0xFF2E7D32));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('حفظ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //    ✅ BUILD
  // ══════════════════════════════════
  // ══════════════════════════════════
  //    ✅ بوابة كلمة سر لوحة الإدارة
  // ══════════════════════════════════
  Widget _buildPasswordGate(bool isDark) {
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('لوحة الإدارة',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Color(0xFF2E7D32), size: 34),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSettingNewPassword
                        ? 'تعيين كلمة سر الإدارة'
                        : 'كلمة سر الإدارة',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSettingNewPassword
                        ? 'هذه أول مرة — عيّن كلمة سر لحماية لوحة الإدارة'
                        : 'أدخل كلمة السر للدخول للإدارة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _adminPasswordController,
                    obscureText: _obscureAdminPassword,
                    autofocus: true,
                    style: TextStyle(color: textColor),
                    onSubmitted: (_) => _submitAdminPassword(),
                    decoration: InputDecoration(
                      hintText: _isSettingNewPassword
                          ? 'كلمة سر جديدة'
                          : 'كلمة السر',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.grey.shade500 : Colors.grey),
                      filled: true,
                      fillColor:
                      isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
                      prefixIcon: const Icon(Icons.key,
                          color: Color(0xFF2E7D32)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureAdminPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() =>
                        _obscureAdminPassword = !_obscureAdminPassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_isSettingNewPassword) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _adminPasswordConfirmController,
                      obscureText: _obscureAdminPassword,
                      style: TextStyle(color: textColor),
                      onSubmitted: (_) => _submitAdminPassword(),
                      decoration: InputDecoration(
                        hintText: 'تأكيد كلمة السر',
                        hintStyle: TextStyle(
                            color:
                            isDark ? Colors.grey.shade500 : Colors.grey),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A3E)
                            : const Color(0xFFF5F5F5),
                        prefixIcon: const Icon(Icons.key,
                            color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (_passwordError != null) ...[
                    const SizedBox(height: 10),
                    Text(_passwordError!,
                        style:
                        const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitAdminPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isSettingNewPassword ? 'حفظ ومتابعة' : 'دخول',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isDisposed) return const SizedBox.shrink();

    if (_checkingPassword) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      );
    }

    if (!_isUnlocked) {
      return _buildPasswordGate(isDark);
    }

    // ✅ حماية الشاشة من الخروج المفاجئ (الرجوع للخلف) المسبب للشاشة البيضاء
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // منطق إضافي للرجوع في الأدمين إذا لزم الأمر
      },
      child: isDesktop ? _buildDesktopLayout(isDark) : _buildMobileLayout(isDark),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return _isLoading
        ? _buildShimmerLoading(isDark)
        : FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          _buildDesktopSidebar(isDark),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(isDark),
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildAddTab(isDark),
                      _buildManageTab(isDark),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: _buildOrdersCard(isDark),
                      ),
                      const StatsScreen(),
                      _buildUsersTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('الإعدادات',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth, color: Colors.white),
            onPressed: _showPrinterStatus,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDark)
          : FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildAddTab(isDark),
            _buildManageTab(isDark),
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildOrdersCard(isDark),
            ),
            const StatsScreen(),
            _buildUsersTab(isDark),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'إضافة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_search_outlined),
            activeIcon: Icon(Icons.manage_search),
            label: 'إدارة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'إحصائيات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'مستخدمون',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //    Desktop Sidebar
  // ══════════════════════════════════
  Widget _buildDesktopSidebar(bool isDark) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final items = [
      {'icon': Icons.add_circle_rounded, 'label': 'إضافة', 'index': 0},
      {'icon': Icons.manage_search_rounded, 'label': 'إدارة المحتوى', 'index': 1},
      {'icon': Icons.receipt_long_rounded, 'label': 'سجل الطلبات', 'index': 2},
      {'icon': Icons.bar_chart_rounded, 'label': 'تقارير المبيعات', 'index': 3},
      {'icon': Icons.people_rounded, 'label': 'المستخدمون', 'index': 4},
    ];
    return Container(
      width: 220,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('الإعدادات',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const Text('لوحة الإدارة',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final idx = item['index'] as int;
                final isSelected = _currentTab == idx;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _currentTab = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2E7D32).withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                            color: const Color(0xFF2E7D32)
                                .withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? const Color(0xFF2E7D32)
                                : textColor.withOpacity(0.6),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? const Color(0xFF2E7D32)
                                  : textColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _sidebarAction(
                  Icons.bluetooth,
                  'حالة الطابعة',
                  _showPrinterStatus,
                  isDark,
                ),
                const SizedBox(height: 6),
                _sidebarAction(
                  Icons.refresh_rounded,
                  'تحديث البيانات',
                  _loadAll,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarAction(
      IconData icon, String label, VoidCallback onTap, bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(bool isDark) {
    final titles = [
      'إضافة محتوى',
      'إدارة المحتوى',
      'سجل الطلبات',
      'تقارير المبيعات',
      'إدارة المستخدمين'
    ];
    return Container(
      height: 56,
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            titles[_currentTab],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showPrinterStatus,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PrinterService.isConnected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PrinterService.isConnected
                          ? Icons.print_rounded
                          : Icons.print_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      PrinterService.isConnected
                          ? 'الطابعة متصلة'
                          : 'غير متصلة',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loadAll,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor =
    isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade200;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (i * 150)),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) {
              return Opacity(
                opacity: value * 0.6,
                child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: i == 0 ? 120 : 200,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 100,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 45,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (i != 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showPrinterStatus() {
    final isConnected = PrinterService.isConnected;
    final deviceName = PrinterService.connectedDeviceName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('حالة الطابعة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'متصل' : 'غير متصل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (deviceName != null) ...[
              const SizedBox(height: 12),
              Text('الجهاز: $deviceName'),
            ],
          ],
        ),
        actions: [
          if (isConnected)
            TextButton(
              onPressed: () async {
                await PrinterService.disconnect();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('قطع الاتصال',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  //    TAB: إضافة
  // ══════════════════════════════════
  Widget _buildAddTab(bool isDark) {
    final fillColor =
    isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);
    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _SectionAnimator(
                    delay: 0,
                    child: _buildCard(
                        isDark: isDark,
                        child: _buildCategoryForm(isDark, fillColor)),
                  ),
                  const SizedBox(height: 16),
                  _SectionAnimator(
                    delay: 100,
                    child: _buildCard(
                        isDark: isDark,
                        child: _buildBrandForm(isDark, fillColor)),
                  ),
                  const SizedBox(height: 16),
                  _SectionAnimator(
                    delay: 200,
                    child: _buildCard(
                        isDark: isDark,
                        child: _buildBannerForm(isDark, fillColor)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  _SectionAnimator(
                    delay: 150,
                    child: _buildCard(
                        isDark: isDark,
                        child: _buildProductForm(isDark, fillColor)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _SectionAnimator(
            delay: 0,
            child: _buildCard(
                isDark: isDark,
                child: _buildCategoryForm(isDark, fillColor)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 100,
            child: _buildCard(
                isDark: isDark,
                child: _buildBrandForm(isDark, fillColor)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 200,
            child: _buildCard(
                isDark: isDark,
                child: _buildProductForm(isDark, fillColor)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 300,
            child: _buildCard(
                isDark: isDark,
                child: _buildBannerForm(isDark, fillColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitIndicator(bool isDark, {
    TextEditingController? pUnitCtrl,
    TextEditingController? upcCtrl,
    TextEditingController? sellCCtrl,
    TextEditingController? sellUCtrl,
  }) {
    final pUnit = double.tryParse((pUnitCtrl ?? purchasePriceController).text.replaceAll(',', '.')) ?? 0;
    final units = double.tryParse((upcCtrl ?? unitsPerCartonController).text) ?? 1;
    final pCarton = pUnit * units;

    final sellC = double.tryParse((sellCCtrl ?? cartonNormalController).text.replaceAll(',', '.')) ?? 0;
    final sellU = double.tryParse((sellUCtrl ?? unitNormalController).text.replaceAll(',', '.')) ?? 0;


    if (pUnit <= 0) return const SizedBox.shrink();

    final profitC = sellC - pCarton;
    final profitU = sellU - pUnit;

    final percentC = pCarton > 0 ? (profitC / pCarton) * 100 : 0;
    final percentU = pUnit > 0 ? (profitU / pUnit) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _profitRow('💡 ربح الكرتون:', profitC, percentC),
          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, thickness: 0.5)),
          _profitRow('💡 ربح الحبة:', profitU, percentU),
        ],
      ),
    );
  }

  Widget _profitRow(String label, double profit, double percent) {
    final isLoss = profit < 0;
    final color = isLoss ? Colors.red : const Color(0xFF2E7D32);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${profit.toStringAsFixed(0)} DA', 
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('${percent.toStringAsFixed(1)}%', 
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryForm(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.category, 'إضافة فئة'),
        const SizedBox(height: 16),
        TextField(
          controller: categoryNameController,
          decoration: InputDecoration(
            hintText: 'اسم الفئة',
            prefixIcon: const Icon(Icons.label_outline,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: categoryIconController,
                decoration: InputDecoration(
                  hintText: 'أيقونة مثل 🍦',
                  prefixIcon: const Icon(Icons.emoji_emotions,
                      color: Color(0xFF2E7D32)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: categoryOrderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'الترتيب',
                  prefixIcon: const Icon(Icons.sort,
                      color: Color(0xFF2E7D32)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: addCategory,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('إضافة الفئة',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandForm(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.store, 'إضافة علامة تجارية'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => pickImage(true),
          child: _buildImagePicker(brandLogoPath),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: brandNameController,
          decoration: InputDecoration(
            hintText: 'اسم العلامة التجارية',
            prefixIcon: const Icon(Icons.label_outline,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<Category>(
          value: _safeCategoryValue(selectedCategoryForBrand),
          hint: const Text('اختر الفئة'),
          items: categories
              .map((c) => DropdownMenuItem(
              value: c, child: Text('${c.icon} ${c.name}')))
              .toList(),
          onChanged: (v) =>
              setState(() => selectedCategoryForBrand = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoadingBrand ? null : addBrand,
            icon: const Icon(Icons.add, color: Colors.white),
            label: isLoadingBrand
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('إضافة العلامة',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductForm(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.inventory_2, 'إضافة منتج'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => pickImage(false),
          child: _buildImagePicker(productImagePath),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: productNameController,
          decoration: InputDecoration(
            hintText: 'اسم المنتج',
            prefixIcon: const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        brands.isEmpty
            ? Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('أضف علامة تجارية أولاً',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        )
            : DropdownButtonFormField<Brand>(
          value: _safeBrandValue(selectedBrand),
          items: brands
              .map((b) => DropdownMenuItem(
              value: b, child: Text(b.name)))
              .toList(),
          onChanged: (v) => setState(() => selectedBrand = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<Category>(
          value: _safeCategoryValue(selectedCategoryForProduct),
          hint: const Text('اختر فئة المنتج'),
          items: categories
              .map((c) => DropdownMenuItem(
              value: c, child: Text('${c.icon} ${c.name}')))
              .toList(),
          onChanged: (v) =>
              setState(() => selectedCategoryForProduct = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إدارة المخزن وتكلفة الشراء',
                  style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: purchasePriceCartonController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'سعر شراء الكرتون',
                      hintText: '0.0',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitsPerCartonController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'قطع/كرتون',
                      hintText: '1',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: purchasePriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'سعر شراء الحبة',
                      hintText: '0.0',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: stockQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المخزون (حبة)',
                      hintText: '0',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ]),
              _buildProfitIndicator(isDark),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSection(
          color: const Color(0xFFE8F5E9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نوع البيع',
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _sellTypeSelector(selectedSellType,
                      (v) => setState(() => selectedSellType = v)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSection(
          color: isDark
              ? const Color(0xFF1A2E1A)
              : const Color(0xFFE8F5E9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('السعر العادي',
                  style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cartonNormalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'سعر الكرتون',
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A3E)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitNormalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'سعر الحبة',
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A3E)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSection(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFFC107)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('السعر الخاص',
                  style: TextStyle(
                      color: Color(0xFFF57F17),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      controller: cartonSpecialController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'سعر الكرتون',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      controller: unitSpecialController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'سعر الحبة',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSection(
          color: const Color(0xFFFFEBEE),
          border: Border.all(color: Colors.red.shade200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الخصم (%)',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('0 = بدون خصم',
                  style:
                  TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(color: Colors.black87),
                controller: discountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'مثال: 10 = خصم 10%',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon:
                  const Icon(Icons.discount, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSection(
          color: const Color(0xFFFFF3E0),
          border: Border.all(color: Colors.orange.shade300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('حد الطلب الأقصى (اختياري)',
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('0 = بدون حد',
                  style:
                  TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('زبون عادي',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          style: const TextStyle(color: Colors.black87),
                          controller: maxQtyNormalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('زبون مميز',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          style: const TextStyle(color: Colors.black87),
                          controller: maxQtySpecialController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StatefulBuilder(
          builder: (context, setLocal) => _buildFlavorsManager(
            flavors: newProductFlavors,
            controller: flavorController,
            onAdd: (f) => setLocal(() => newProductFlavors
                .add(FlavorModel(name: f, isAvailable: true))),
            onRemove: (i) =>
                setLocal(() => newProductFlavors.removeAt(i)),
            onToggle: (i) => setLocal(() => newProductFlavors[i] =
                newProductFlavors[i].copyWith(
                    isAvailable: !newProductFlavors[i].isAvailable)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoadingProduct ? null : addProduct,
            icon: const Icon(Icons.add, color: Colors.white),
            label: isLoadingProduct
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('إضافة المنتج',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerForm(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.view_carousel, 'إضافة بانر'),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: pickBannerImage,
          child: Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: _selectedBannerColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _selectedBannerColor),
            ),
            child: bannerImagePath != null
                ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: kIsWeb
                    ? Image.network(bannerImagePath!, fit: BoxFit.cover)
                    : Image.file(File(bannerImagePath!), fit: BoxFit.cover))
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate,
                    color: _selectedBannerColor, size: 36),
                Text('إضافة صورة',
                    style: TextStyle(
                        color: _selectedBannerColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bannerTitleController,
          decoration: InputDecoration(
            hintText: 'عنوان البانر',
            prefixIcon:
            const Icon(Icons.title, color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bannerSubtitleController,
          decoration: InputDecoration(
            hintText: 'النص الثانوي',
            prefixIcon: const Icon(Icons.subtitles,
                color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bannerOrderController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'الترتيب',
            prefixIcon:
            const Icon(Icons.sort, color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoadingBanner ? null : addBanner,
            icon: const Icon(Icons.add, color: Colors.white),
            label: isLoadingBanner
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('إضافة البانر',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════
  //    TAB: إدارة
  // ══════════════════════════════════
  //    Helper Widgets
  // ══════════════════════════════════
  Widget _buildFlavorsManager({
    required List<FlavorModel> flavors,
    required Function(String) onAdd,
    required Function(int) onRemove,
    required Function(int) onToggle,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('الأذواق',
                  style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              SizedBox(width: 8),
              Text('(اختياري)',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.black87),
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'مثال: شوكولا، فانيلا...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty &&
                      !flavors.any((f) => f.name == text)) {
                    onAdd(text);
                    controller.clear();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (flavors.isEmpty)
            const Center(
              child: Text('لا توجد أذواق - أضف ذوقاً جديداً',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12)),
            )
          else
            Column(
              children: flavors.asMap().entries.map((entry) {
                final index = entry.key;
                final flavor = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: flavor.isAvailable
                        ? Colors.blue.shade50
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: flavor.isAvailable
                            ? Colors.blue.shade200
                            : Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          flavor.name,
                          style: TextStyle(
                            color: flavor.isAvailable
                                ? Colors.blue.shade800
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: flavor.isAvailable
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      Text(
                        flavor.isAvailable ? 'متوفر' : 'غير متوفر',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: flavor.isAvailable
                              ? const Color(0xFF2E7D32)
                              : Colors.red,
                        ),
                      ),
                      Switch(
                        value: flavor.isAvailable,
                        activeColor: const Color(0xFF2E7D32),
                        onChanged: (_) => onToggle(index),
                      ),
                      GestureDetector(
                        onTap: () => onRemove(index),
                        child: Icon(Icons.close,
                            size: 18,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon,
                size: 40, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _sellTypeSelector(
      SellType current, Function(SellType) onChanged) {
    return Row(
      children: [
        Expanded(
          child: _sellTypeButton(
            label: 'كرتون',
            selected: current == SellType.cartonOnly,
            onTap: () => onChanged(SellType.cartonOnly),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _sellTypeButton(
            label: 'حبة',
            selected: current == SellType.unitOnly,
            onTap: () => onChanged(SellType.unitOnly),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _sellTypeButton(
            label: 'الاثنين',
            selected: current == SellType.both,
            onTap: () => onChanged(SellType.both),
          ),
        ),
      ],
    );
  }

  Widget _sellTypeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E7D32)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required Color color,
    Border? border,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: child,
    );
  }

  Widget _buildImagePicker(String? imagePath) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: const Color(0xFF2E7D32), width: 2),
      ),
      child: imagePath != null
          ? ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: kIsWeb
              ? Image.network(imagePath, fit: BoxFit.cover)
              : Image.file(File(imagePath), fit: BoxFit.cover))
          : const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo,
              color: Color(0xFF2E7D32), size: 30),
          SizedBox(height: 4),
          Text('صورة',
              style: TextStyle(
                  color: Color(0xFF2E7D32), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding:
      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor),
      ),
    );
  }

  Widget _roleOption({
    required String role,
    required String label,
    required String description,
    required String selectedRole,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedRole == role;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? color : Colors.grey,
                    width: 2),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                  color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//    SectionAnimator
// ══════════════════════════════════
class _SectionAnimator extends StatelessWidget {
  final int delay;
  final Widget child;

  const _SectionAnimator(
      {required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
                0, 30 * (1 - value.clamp(0.0, 1.0))),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}