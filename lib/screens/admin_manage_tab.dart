part of 'admin_screen.dart';

// ══════════════════════════════════
//    تبويب: إدارة (الطلبات، الإعلانات، التعديل/الحذف)
// ══════════════════════════════════
extension AdminManageTabX on _AdminScreenState {
  // ✅ بطاقة دخول سريع لشاشة الإحصائيات (بعد نقلها جوا "إدارة")
  Widget _buildStatsEntryCard(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StatsScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإحصائيات',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 2),
                    Text('المبيعات، أكثر المنتجات مبيعًا، التقارير',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildManageTab(bool isDark) {
    final fillColor =
    isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _SectionAnimator(
            delay: 50,
            child: _buildStatsEntryCard(isDark),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 100,
            child: _buildCard(
                isDark: isDark,
                child:
                _buildAnnouncementsSection(isDark, fillColor)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 150,
            child: _buildCard(
                isDark: isDark, child: _buildPriceToggle()),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 200,
            child: _buildCard(
                isDark: isDark,
                child: _buildCategoriesSection(isDark)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 250,
            child: _buildCard(
                isDark: isDark, child: _buildBannersSection(isDark)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 300,
            child: _buildCard(
                isDark: isDark,
                child: _buildBrandsSection(isDark, fillColor)),
          ),
          const SizedBox(height: 12),
          _SectionAnimator(
            delay: 400,
            child: _buildCard(
                isDark: isDark,
                child: _buildProductsSection(isDark, fillColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.campaign, 'إدارة الإعلانات'),
        const SizedBox(height: 16),
        TextField(
          controller: announcementController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'اكتب إعلاناً للزبائن...',
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedAnnType,
                decoration: InputDecoration(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'general', child: Text('📢 عام')),
                  DropdownMenuItem(
                      value: 'offer', child: Text('🎉 عرض')),
                  DropdownMenuItem(
                      value: 'warning', child: Text('⚠️ تنبيه')),
                  DropdownMenuItem(
                      value: 'info', child: Text('ℹ️ معلومة')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedAnnType = v!),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: addAnnouncement,
                icon: const Icon(Icons.send,
                    color: Colors.white, size: 18),
                label: const Text('نشر',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 30),
        const Text('الإعلانات الحالية:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<AnnouncementModel>>(
          stream: DataService.getAnnouncementsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator());
            }
            final list = snapshot.data!;
            if (list.isEmpty) {
              return const Text('لا توجد إعلانات حالية',
                  style: TextStyle(color: Colors.grey));
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.message,
                      style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () => deleteAnnouncement(item.id),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ✅ الإصلاح الرئيسي هنا
  Widget _buildPriceToggle() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ✅ Expanded يحل مشكلة unbounded width
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'نوع السعر الافتراضي',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                isSpecialPrice
                    ? 'يعرض السعر الخاص (المميز)'
                    : 'يعرض السعر العادي (العادي)',
                style: TextStyle(
                  color: isSpecialPrice
                      ? const Color(0xFFF57F17)
                      : const Color(0xFF2E7D32),
                  fontSize: 12,
                ),
              ),
              const Text(
                'خاص بحساب الأدمن فقط',
                style:
                TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(
          value: isSpecialPrice,
          activeColor: const Color(0xFF2E7D32),
          onChanged: (value) async {
            await DataService.setIsSpecialPrice(value);
            setState(() => isSpecialPrice = value);
          },
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            Icons.category, 'الفئات (${categories.length})'),
        const SizedBox(height: 12),
        categories.isEmpty
            ? Center(
          child: Text('لا توجد فئات',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey)),
        )
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(
                  milliseconds: 300 + (index * 80)),
              curve: Curves.easeOutCubic,
              builder: (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Text(cat.icon),
                ),
                title: Text(cat.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                subtitle: Text('الترتيب: ${cat.order}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.purple),
                      onPressed: () =>
                          _showEditCategoryDialog(cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () => deleteCategory(cat),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBannersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionHeader(Icons.view_carousel,
                  'البانرات (${banners.length})'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Color(0xFF2E7D32)),
              onPressed: loadBanners,
            ),
          ],
        ),
        const SizedBox(height: 12),
        banners.isEmpty
            ? const Text('لا توجد بانرات',
            style: TextStyle(color: Colors.grey))
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: banners.length,
          separatorBuilder: (_, __) => Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          itemBuilder: (context, index) {
            final banner = banners[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: banner.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(banner.icon, color: Colors.white),
              ),
              title: Text(banner.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold)),
              subtitle: Text(banner.subtitle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: banner.isActive,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (v) async {
                      await DataService.updateBannerStatus(
                          banner.id, v);
                      await loadBanners();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    onPressed: () => deleteBanner(banner),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBrandsSection(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            Icons.store, 'العلامات التجارية (${brands.length})'),
        const SizedBox(height: 12),
        brands.isEmpty
            ? Center(
          child: Text('لا توجد علامات تجارية',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey)),
        )
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: brands.length,
          separatorBuilder: (_, __) => Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          itemBuilder: (context, index) {
            final brand = brands[index];
            final cat = _categoryById(brand.categoryId);
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(
                  milliseconds: 300 + (index * 80)),
              curve: Curves.easeOutCubic,
              builder: (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      cat?.icon ?? '🏪',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                title: Text(brand.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                subtitle: Text(cat?.name ?? 'بدون فئة'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF2E7D32)),
                      onPressed: () =>
                          _showEditBrandDialog(brand),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () => deleteBrand(brand),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductsSection(bool isDark, Color fillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            Icons.inventory_2, 'المنتجات (${products.length})'),
        const SizedBox(height: 12),
        brands.isEmpty
            ? const Text('لا توجد علامات تجارية')
            : DropdownButtonFormField<Brand>(
          value: _safeBrandValue(selectedBrandForProducts),
          items: brands
              .map((b) => DropdownMenuItem(
              value: b, child: Text(b.name)))
              .toList(),
          onChanged: (v) {
            setState(() => selectedBrandForProducts = v);
            if (v != null) loadProducts(v.id);
          },
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
        const SizedBox(height: 12),
        products.isEmpty
            ? Center(
          child: Text('لا توجد منتجات',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey)),
        )
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => Divider(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200),
          itemBuilder: (context, index) {
            final product = products[index];
            
            // ✅ حساب المخزن المفهوم (كرتون + حبة)
            String stockLabel = 'المخزن: ';
            if (product.unitsPerCarton > 1) {
              int crt = product.stockQuantity ~/ product.unitsPerCarton;
              int pcs = product.stockQuantity % product.unitsPerCarton;
              stockLabel += '$crt كرتون و $pcs حبة';
            } else {
              stockLabel += '${product.stockQuantity} قطعة';
            }

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(
                  milliseconds: 300 + (index * 80)),
              curve: Curves.easeOutCubic,
              builder: (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: product.isFeatured
                        ? Colors.amber.shade100
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    product.isFeatured
                        ? Icons.star
                        : Icons.inventory_2,
                    color: product.isFeatured
                        ? Colors.amber
                        : const Color(0xFF2E7D32),
                  ),
                ),
                title: Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.priceCartonNormal.toStringAsFixed(0)} DA | ${_sellTypeLabel(product.sellType)}',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 12),
                    ),
                    Text(
                      stockLabel,
                      style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (product.hasFlavors)
                          _badge(
                            '${product.flavors.length} نكهة',
                            Colors.blue.shade50,
                            Colors.blue.shade700,
                          ),
                        if (product.discount > 0)
                          _badge(
                            'خصم ${product.discount.toInt()}%',
                            Colors.red.shade50,
                            Colors.red,
                          ),
                        GestureDetector(
                          onTap: () async {
                            await DataService
                                .updateProductAvailability(
                              product.id,
                              !product.isAvailable,
                            );
                            if (selectedBrandForProducts !=
                                null) {
                              await loadProducts(
                                  selectedBrandForProducts!
                                      .id);
                            }
                          },
                          child: _badge(
                            product.isAvailable
                                ? 'متوفر'
                                : 'غير متوفر',
                            product.isAvailable
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            product.isAvailable
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF2E7D32)),
                      onPressed: () =>
                          _showEditProductDialog(product),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () => deleteProduct(product),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrdersCard(bool isDark) {
    List<Order> displayOrders = orders;
    if (_selectedFilterDate != null) {
      displayOrders = orders.where((o) {
        final d = o.createdAt ?? o.dateTime;
        if (d == null) return false;
        return d.year == _selectedFilterDate!.year &&
            d.month == _selectedFilterDate!.month &&
            d.day == _selectedFilterDate!.day;
      }).toList();
    }

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSectionHeader(Icons.receipt_long,
                    'سجل الطلبات (${displayOrders.length})'),
              ),
              // ✅ زر التقويم
              IconButton(
                icon: Icon(Icons.calendar_month,
                    color: _selectedFilterDate != null ? Colors.red : const Color(0xFF2E7D32)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedFilterDate ?? DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                  );
                  setState(() => _selectedFilterDate = picked);
                },
                tooltip: 'تصفية بالتاريخ',
              ),
              if (_selectedFilterDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => setState(() => _selectedFilterDate = null),
                ),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: Color(0xFF2E7D32)),
                onPressed: loadOrders,
              ),
            ],
          ),
          if (_selectedFilterDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'عرض طلبات تاريخ: ${DateFormat('yyyy/MM/dd').format(_selectedFilterDate!)}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          if (PrinterService.isConnected)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطابعة: ${PrinterService.connectedDeviceName ?? "متصل"}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الطابعة غير متصلة - اضغط على أيقونة البلوتوث',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (isLoadingOrders)
            const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      color: Color(0xFF2E7D32)),
                ))
          else if (displayOrders.isEmpty)
            const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا توجد طلبات',
                      style: TextStyle(color: Colors.grey)),
                ))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
              displayOrders.length > 50 ? 50 : displayOrders.length,
              separatorBuilder: (_, __) => Divider(
                  color: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200),
              itemBuilder: (context, index) {
                final order = displayOrders[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(
                      milliseconds: 300 + (index * 60)),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(20 * (1 - value), 0),
                      child: child,
                    ),
                  ),
                  child: _buildOrderTile(order, isDark),
                );
              },
            ),
          if (displayOrders.length > 50)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('يتم عرض آخر 50 طلباً فقط، استخدم البحث أو التاريخ للوصول للبقية',
                    style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Order order, bool isDark) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getOrderStatusColor(order.status),
        child: Icon(_getOrderStatusIcon(order.status),
            color: Colors.white, size: 18),
      ),
      title: Text(order.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.customerPhone,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          Text(
            '${order.items.length} منتج | ${_formatDate(order.createdAt ?? DateTime.now())}',
            style:
            const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${order.total.toStringAsFixed(0)} DA',
            style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showOrderDetails(order),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('عرض',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showEditOrderDialogFromManage(order),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit,
                          color: Colors.white, size: 11),
                      SizedBox(width: 2),
                      Text('تعديل',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showPrintDialog(order),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print,
                          color: Colors.white, size: 11),
                      SizedBox(width: 2),
                      Text('طباعة',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('تفاصيل الطلب',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
              const SizedBox(height: 16),
              _detailRow('الزبون', order.customerName),
              _detailRow('الهاتف', order.customerPhone),
              _detailRow('التاريخ',
                  _formatDate(order.createdAt ?? DateTime.now())),
              _detailRow('الحالة', _getStatusText(order.status)),
              const Divider(height: 24),
              const Text('المنتجات:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: order.items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                        const Color(0xFFE8F5E9),
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                          item['productName']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${item['quantity']} × ${(item['price'] ?? 0).toString()} DA'),
                      trailing: Text(
                        '${((item['quantity'] ?? 0) * (item['price'] ?? 0)).toStringAsFixed(0)} DA',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المجموع:',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('${order.total.toStringAsFixed(0)} DA',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPrintDialog(order);
                  },
                  icon: const Icon(Icons.print,
                      color: Colors.white),
                  label: const Text('طباعة الفاتورة',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  // ══════════════════════════════════
  //  ✅ تعديل الطلبية من تبويب الإدارة
  // ══════════════════════════════════
  Future<void> _showEditOrderDialogFromManage(Order order) async {
    List<Map<String, dynamic>> editedItems = List.from(
        order.items.map((it) => Map<String, dynamic>.from(it)));
    
    final paidCtrl = TextEditingController(text: order.paidAmount.toStringAsFixed(0));

    double calculateNewTotal() {
      return editedItems.fold(0.0, (sum, it) {
        final price = _d(it['price']);
        final qty = _i(it['quantity']);
        return sum + (price * qty);
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('تعديل طلب ${order.customerName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                // زر إضافة منتج جديد
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final newItem = await _showSelectProductForOrder();
                      if (newItem != null) {
                        setSt(() => editedItems.add(newItem));
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('إضافة منتج جديد للطلبية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: editedItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final item = editedItems[i];
                      final name = item['productName'] ?? 'منتج';
                      final qty = _i(item['quantity']);
                      final price = _d(item['price']);
                      final type = item['typeLabel'] ?? 'كرتون';

                      return ListTile(
                        title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: InkWell(
                          onTap: () async {
                            final newPrice = await _showEditSinglePriceDialog(price, name);
                            if (newPrice != null) {
                              setSt(() => item['price'] = newPrice);
                            }
                          },
                          child: Row(
                            children: [
                              Text('السعر: ${price.toStringAsFixed(0)} DA', 
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 12, color: Colors.blue),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setSt(() {
                                  if (qty > 1) {
                                    item['quantity'] = qty - 1;
                                  } else {
                                    editedItems.removeAt(i);
                                  }
                                });
                              },
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () {
                                setSt(() {
                                  item['quantity'] = qty + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                // ✅ تعديل المبلغ المسدد
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: paidCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المسدد الآن',
                      suffixText: 'DA',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الجديد:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${calculateNewTotal().toStringAsFixed(0)} DA',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final newTotal = calculateNewTotal();
        final newPaid = double.tryParse(paidCtrl.text) ?? order.paidAmount;
        final updatedOrder = order.copyWith(
          items: editedItems,
          total: newTotal,
          paidAmount: newPaid,
        );
        await DataService.updateFullOrder(updatedOrder);
        await loadOrders();
        _showSnackBar('✅ تم تحديث الطلب', Colors.green);
      } catch (e) {
        _showSnackBar('❌ خطأ: $e', Colors.red);
      }
    }
  }

// ══════════════════════════════════
//    TAB: المستخدمون
// ══════════════════════════════════
}