import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/printer_service.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class DesktopPosView extends StatefulWidget {
  final List<CartItem> cart;
  final VoidCallback onCartChanged;
  const DesktopPosView({super.key, required this.cart, required this.onCartChanged});

  @override
  State<DesktopPosView> createState() => _DesktopPosViewState();
}

class _DesktopPosViewState extends State<DesktopPosView> {
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<CustomerModel> allCustomers = [];
  final searchController = TextEditingController();
  bool isLoading = true;
  final formatter = NumberFormat('#,##0', 'en_US');
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
    searchController.addListener(_onSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final pData = await DataService.getAllProducts();
      final cData = await DataService.getCustomers();
      if (mounted) {
        setState(() {
          allProducts = pData;
          filteredProducts = pData;
          allCustomers = cData;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadData: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onSearch() {
    final q = searchController.text.toLowerCase().trim();
    setState(() {
      filteredProducts = allProducts.where((p) => p.name.toLowerCase().contains(q) || p.id.contains(q)).toList();
    });
  }

  Future<String?> _selectFlavorDialog(Product p) async {
    if (p.flavors.isEmpty) return null;
    final availableFlavors = p.flavors.where((f) => f.isAvailable).toList();
    if (availableFlavors.isEmpty) return null;

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر الذوق لـ ${p.name}'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableFlavors.length,
            itemBuilder: (context, i) {
              final flavor = availableFlavors[i];
              return ListTile(
                title: Text(flavor.name),
                leading: const Icon(Icons.restaurant_menu, color: Color(0xFF2E7D32)),
                onTap: () => Navigator.pop(context, flavor.name),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addToCart(Product p, bool isCarton) async {
    String? chosenFlavor;
    if (p.flavors.isNotEmpty) {
      chosenFlavor = await _selectFlavorDialog(p);
      if (chosenFlavor == null) {
        _searchFocusNode.requestFocus();
        return;
      }
    }

    final existing = widget.cart.firstWhere(
      (i) => i.product.id == p.id && i.isCarton == isCarton && i.flavor == chosenFlavor,
      orElse: () => CartItem(product: p, quantity: 0, isCarton: isCarton, flavor: chosenFlavor),
    );

    if (existing.quantity > 0) {
      setState(() => existing.quantity++);
    } else {
      setState(() => widget.cart.add(CartItem(product: p, quantity: 1, isCarton: isCarton, flavor: chosenFlavor)));
    }
    widget.onCartChanged();
    _searchFocusNode.requestFocus();
  }

  // نافذة إضافة زبون جديد فورياً
  Future<CustomerModel?> _showAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    return await showDialog<CustomerModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.person_add, color: Color(0xFF2E7D32)), SizedBox(width: 8), Text('إضافة زبون جديد')],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الزبون الكامل', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              final newCustomer = CustomerModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                balance: 0,
                createdAt: DateTime.now(),
              );
              await DataService.saveCustomer(newCustomer);
              if (context.mounted) Navigator.pop(context, newCustomer);
            },
            child: const Text('حفظ الزبون', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // دايالوج تأكيد الحساب مع اختيار الزبون الحقيقي من الدليل (بحث متقدم)
  void _showCheckoutDialog() async {
    if (widget.cart.isEmpty) return;

    CustomerModel? selectedCustomer;
    final customerNameController = TextEditingController();
    final customerPhoneController = TextEditingController();
    final paidController = TextEditingController();
    final customerSearchController = TextEditingController();
    
    final total = widget.cart.fold(0.0, (s, i) => s + i.totalPrice);
    paidController.text = total.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) {
          final filteredCustomers = allCustomers.where((c) {
            final q = customerSearchController.text.toLowerCase();
            return c.name.toLowerCase().contains(q) || c.phone.contains(q);
          }).toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.monetization_on, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text('إتمام البيع واختيار الزبون'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('إجمالي الفاتورة: ${formatter.format(total)} DA', 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    const Divider(height: 24),
                    
                    // البحث الذكي عن زبون
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: TextField(
                                    controller: customerSearchController,
                                    decoration: const InputDecoration(
                                      hintText: 'ابحث عن زبون (الاسم أو الهاتف)...',
                                      icon: Icon(Icons.person_search, color: Color(0xFF2E7D32)),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (v) => setSt(() {}),
                                  ),
                                ),
                                if (customerSearchController.text.isNotEmpty && selectedCustomer == null)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredCustomers.length,
                                      itemBuilder: (context, i) {
                                        final c = filteredCustomers[i];
                                        return ListTile(
                                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text(c.phone),
                                          trailing: Text('${formatter.format(c.balance)} DA', style: const TextStyle(color: Colors.red, fontSize: 11)),
                                          onTap: () {
                                            setSt(() {
                                              selectedCustomer = c;
                                              customerNameController.text = c.name;
                                              customerPhoneController.text = c.phone;
                                              customerSearchController.text = c.name;
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
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () async {
                            final newC = await _showAddCustomerDialog();
                            if (newC != null) {
                              setSt(() {
                                allCustomers.add(newC); // تحديث القائمة المحلية
                                selectedCustomer = newC;
                                customerNameController.text = newC.name;
                                customerPhoneController.text = newC.phone;
                                customerSearchController.text = newC.name;
                              });
                            }
                          },
                          icon: const Icon(Icons.person_add),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                          tooltip: 'إضافة زبون جديد',
                        ),
                      ],
                    ),
                    
                    if (selectedCustomer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text('تم اختيار: ${selectedCustomer!.name}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setSt(() {
                                selectedCustomer = null;
                                customerSearchController.clear();
                                customerNameController.clear();
                                customerPhoneController.clear();
                              }),
                              child: const Text('تغيير', style: TextStyle(color: Colors.red, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: customerNameController,
                      decoration: const InputDecoration(labelText: 'اسم الزبون (يدوي)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ المدفوع (كاش)', border: OutlineInputBorder(), suffixText: 'DA'),
                      onChanged: (v) => setSt(() {}),
                    ),
                    const SizedBox(height: 12),
                    
                    Builder(builder: (context) {
                      final paid = double.tryParse(paidController.text) ?? total;
                      final rest = total - paid;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: rest > 0 ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('حالة الحساب:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              rest > 0 ? 'باقي دين: ${formatter.format(rest)} DA' : 'خالص (مدفوع بالكامل)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: rest > 0 ? Colors.red : Colors.green),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                onPressed: () async {
                  Navigator.pop(context);
                  final paidAmount = double.tryParse(paidController.text) ?? total;
                  final remainingBalance = total - paidAmount;

                  final orderId = DateTime.now().millisecondsSinceEpoch.toString();
                  final order = Order(
                    id: orderId,
                    customerName: customerNameController.text.trim().isEmpty ? 'زبون عادي' : customerNameController.text.trim(),
                    customerPhone: customerPhoneController.text.trim(),
                    items: widget.cart.map((i) => {
                      'productName': i.product.name,
                      'quantity': i.quantity,
                      'price': i.unitPrice,
                      'unitPrice': i.unitPrice,
                      'isCarton': i.isCarton,
                      'typeLabel': i.typeLabel,
                      'flavor': i.flavor ?? '',
                    }).toList(),
                    total: total,
                    createdAt: DateTime.now(),
                    status: 'delivered',
                    isSpecialPrice: false,
                    date: DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now()),
                    paidAmount: paidAmount,
                    remainingBalance: remainingBalance > 0 ? remainingBalance : 0,
                  );

                  await DataService.saveOrder(order);
                  
                  if (selectedCustomer != null && remainingBalance > 0) {
                    await DataService.addDebtTransaction(
                      customerId: selectedCustomer!.id,
                      type: 'charge',
                      amount: remainingBalance,
                      note: 'دين متبقي من فاتورة بيع سريع رقم #${orderId.substring(orderId.length - 4)}',
                    );
                  }

                  await ReceiptPreviewDialog.show(
                    context,
                    order: order,
                    customerName: order.customerName,
                    customerPhone: order.customerPhone,
                    amountPaid: paidAmount,
                  );

                  setState(() => widget.cart.clear());
                  widget.onCartChanged();
                  _searchFocusNode.requestFocus();
                },
                child: const Text('إتمام وحفظ الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            _searchFocusNode.requestFocus();
          } else if (event.logicalKey == LogicalKeyboardKey.f10 || event.logicalKey == LogicalKeyboardKey.f5) {
            _showCheckoutDialog();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            FocusScope.of(context).unfocus();
          }
        }
      },
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'بحث عن منتج (الاسم أو الباركود)... [F1]',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: isLoading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, i) => _productRow(filteredProducts[i], isDark),
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              border: Border(right: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
            ),
            child: _buildCartSidebar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _productRow(Product p, bool isDark) {
    final showCarton = p.sellType == SellType.cartonOnly || p.sellType == SellType.both;
    final showUnit = p.sellType == SellType.unitOnly || p.sellType == SellType.both;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.2))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: p.imagePath.isNotEmpty 
                  ? CachedNetworkImage(imageUrl: p.imagePath, width: 55, height: 55, fit: BoxFit.cover)
                  : Container(width: 55, height: 55, color: Colors.grey.shade100, child: const Icon(Icons.fastfood, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (p.flavors.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: p.flavors.map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: f.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(f.name, style: TextStyle(fontSize: 10, color: f.isAvailable ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                      )).toList(),
                    )
                  else
                    Text('بدون أذواق فرعية', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showCarton) Text('${formatter.format(p.priceCartonNormal)} DA', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 14)),
                if (showUnit) Text('${formatter.format(p.priceUnitNormal)} DA / حبة', style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showCarton)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    onPressed: () => _addToCart(p, true),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('أضف كرتون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                if (showUnit)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    onPressed: () => _addToCart(p, false),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('أضف حبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSidebar(bool isDark) {
    final total = widget.cart.fold(0.0, (s, i) => s + i.totalPrice);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2E7D32),
          child: const Row(children: [Icon(Icons.shopping_cart, color: Colors.white), SizedBox(width: 8), Text('سلة البيع السريعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
        ),
        Expanded(
          child: widget.cart.isEmpty 
            ? const Center(child: Text('السلة فارغة، أضف سلعاً لبدء البيع')) 
            : ListView.builder(
                itemCount: widget.cart.length,
                itemBuilder: (context, i) {
                  final it = widget.cart[i];
                  return _CartItemTileWidget(
                    key: ValueKey('${it.product.id}_${it.isCarton}_${it.flavor}'),
                    item: it,
                    formatter: formatter,
                    onChanged: () {
                      setState(() {});
                      widget.onCartChanged();
                    },
                    onRemove: () {
                      setState(() {
                        widget.cart.removeAt(i);
                      });
                      widget.onCartChanged();
                    },
                  );
                },
              ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('${formatter.format(total)} DA', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, 
              height: 48, 
              child: ElevatedButton(
                onPressed: widget.cart.isEmpty ? null : _showCheckoutDialog, 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                child: const Text('إتمام وحفظ الفاتورة (F10)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
              )
            ),
          ]),
        ),
      ],
    );
  }
}

class _CartItemTileWidget extends StatefulWidget {
  final CartItem item;
  final NumberFormat formatter;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _CartItemTileWidget({
    super.key,
    required this.item,
    required this.formatter,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CartItemTileWidget> createState() => _CartItemTileWidgetState();
}

class _CartItemTileWidgetState extends State<_CartItemTileWidget> {
  late TextEditingController _qtyController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: widget.item.quantity.toString());
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (_qtyController.text.trim().isEmpty || (int.tryParse(_qtyController.text) ?? 0) <= 0) {
          widget.item.quantity = 1;
          _qtyController.text = '1';
          widget.onChanged();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CartItemTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      if (_qtyController.text != widget.item.quantity.toString()) {
        _qtyController.text = widget.item.quantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.item.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${widget.formatter.format(widget.item.totalPrice)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.item.typeLabel} ${widget.item.flavor != null ? "(${widget.item.flavor})" : ""}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 22),
                      onPressed: () {
                        if (widget.item.quantity > 1) {
                          widget.item.quantity--;
                          _qtyController.text = widget.item.quantity.toString();
                          widget.onChanged();
                        } else {
                          widget.onRemove();
                        }
                      },
                    ),
                    SizedBox(
                      width: 55,
                      height: 32,
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder()),
                        onChanged: (value) {
                          if (value.trim().isEmpty) {
                            return; // السماح بمسح الخانة بالكامل أثناء الكتابة
                          }
                          final newQty = int.tryParse(value);
                          if (newQty != null && newQty > 0) {
                            widget.item.quantity = newQty;
                            widget.onChanged();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 22),
                      onPressed: () {
                        widget.item.quantity++;
                        _qtyController.text = widget.item.quantity.toString();
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
