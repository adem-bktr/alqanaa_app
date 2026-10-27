part of 'admin_screen.dart';

// ══════════════════════════════════
//    تبويب: المستخدمون
// ══════════════════════════════════
extension AdminUsersTabX on _AdminScreenState {
  Widget _buildUsersTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      child: _SectionAnimator(
        delay: 0,
        child: _buildCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader(Icons.people,
                        'المستخدمون (${users.length})'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Color(0xFF2E7D32)),
                    onPressed: loadUsers,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              users.isEmpty
                  ? Center(
                child: Text('لا يوجد مستخدمون',
                    style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey)),
              )
                  : isDesktop
                  ? GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                        milliseconds:
                        300 + (index * 60)),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) =>
                        Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset:
                            Offset(20 * (1 - value), 0),
                            child: child,
                          ),
                        ),
                    child: _buildUserCard(user, isDark),
                  );
                },
              )
                  : ListView.separated(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => Divider(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                        milliseconds:
                        300 + (index * 80)),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) =>
                        Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset:
                            Offset(20 * (1 - value), 0),
                            child: child,
                          ),
                        ),
                    child: _buildUserListTile(user),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
        isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isAdmin
              ? const Color(0xFF2E7D32).withOpacity(0.3)
              : user.isSpecial
              ? Colors.amber.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.isAdmin
                ? const Color(0xFF2E7D32)
                : user.isSpecial
                ? Colors.amber.shade700
                : Colors.blue,
            child: Text(
              user.name.isNotEmpty
                  ? user.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showChangeRoleDialog(user),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: user.isAdmin
                    ? const Color(0xFFE8F5E9)
                    : user.isSpecial
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: user.isAdmin
                      ? const Color(0xFF2E7D32)
                      : user.isSpecial
                      ? Colors.amber
                      : Colors.blue,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: user.isAdmin
                          ? const Color(0xFF2E7D32)
                          : user.isSpecial
                          ? Colors.amber.shade800
                          : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 11,
                    color: user.isAdmin
                        ? const Color(0xFF2E7D32)
                        : user.isSpecial
                        ? Colors.amber.shade800
                        : Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTile(UserModel user) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: user.isAdmin
            ? const Color(0xFF2E7D32)
            : user.isSpecial
            ? Colors.amber.shade700
            : Colors.blue,
        child: Text(
          user.name.isNotEmpty
              ? user.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(user.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email,
              style: const TextStyle(fontSize: 12)),
          Text(user.phone,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: GestureDetector(
        onTap: () => _showChangeRoleDialog(user),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: user.isAdmin
                ? const Color(0xFFE8F5E9)
                : user.isSpecial
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: user.isAdmin
                  ? const Color(0xFF2E7D32)
                  : user.isSpecial
                  ? Colors.amber
                  : Colors.blue,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.roleLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: user.isAdmin
                      ? const Color(0xFF2E7D32)
                      : user.isSpecial
                      ? Colors.amber.shade800
                      : Colors.blue,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 12,
                color: user.isAdmin
                    ? const Color(0xFF2E7D32)
                    : user.isSpecial
                    ? Colors.amber.shade800
                    : Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

// ══════════════════════════════════
//    تبويب: برنامج الأيام لزبائن الأدمن (CustomerModel)
// ══════════════════════════════════
  Widget _buildDaysScheduleTab(bool isDark) {
    return StreamBuilder<List<CustomerModel>>(
      stream: DataService.getCustomersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
          );
        }

        final customers = snapshot.data ?? [];
        final weekDays = [
          'الكل',
          'السبت',
          'الأحد',
          'الإثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'غير محدد'
        ];

        // تصفية زبائن الأدمن
        final query = _scheduleSearchController.text.trim().toLowerCase();
        final filteredCustomers = customers.where((c) {
          bool matchesDay;
          if (_selectedScheduleDay == 'الكل') {
            matchesDay = true;
          } else if (_selectedScheduleDay == 'غير محدد') {
            matchesDay = c.visitDays.isEmpty;
          } else {
            matchesDay = c.visitDays.contains(_selectedScheduleDay);
          }

          if (!matchesDay) return false;
          if (query.isEmpty) return true;

          return c.name.toLowerCase().contains(query) ||
              c.phone.contains(query) ||
              (c.address?.toLowerCase().contains(query) ?? false);
        }).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 20 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة العنوان والبحث
              _buildCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'برنامج زبائن الأدمن بالأيام',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'تحديد وتصفية خط سير التوزيع اليومي لدليل زبائن الأدمن',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // حقل البحث السريع
                    TextField(
                      controller: _scheduleSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الزبون، الهاتف، أو العنوان...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _scheduleSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _scheduleSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // شريط تصفية الأيام الأفقي
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: weekDays.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final day = weekDays[index];
                          final isSelected = _selectedScheduleDay == day;

                          int count = 0;
                          if (day == 'الكل') {
                            count = customers.length;
                          } else if (day == 'غير محدد') {
                            count = customers.where((c) => c.visitDays.isEmpty).length;
                          } else {
                            count = customers.where((c) => c.visitDays.contains(day)).length;
                          }

                          return ChoiceChip(
                            label: Text('$day ($count)'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedScheduleDay = day);
                              }
                            },
                            selectedColor: const Color(0xFF2E7D32),
                            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // عدد الزبائن المصفين
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'زبائن الأدمن المسجلون: ${filteredCustomers.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                  if (_selectedScheduleDay != 'الكل')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'يوم: $_selectedScheduleDay',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // قائمة بطاقات زبائن الأدمن
              filteredCustomers.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا يوجد زبائن مخصصون لهذا اليوم في الأدمن',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'يمكنك تخصيص الأيام لزبائن الأدمن بالضغط على زر الأيام بجانب أي زبون',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return _buildScheduleCustomerCard(customer, isDark);
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleCustomerCard(CustomerModel customer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: customer.visitDays.contains(_selectedScheduleDay)
              ? const Color(0xFF2E7D32).withOpacity(0.4)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف الأول: معلومات الزبون والدين
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF2E7D32),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (customer.phone.isNotEmpty)
                      Text(
                        customer.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (customer.hasDebt)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'الدين: ${_trimNum(customer.balance)} د.ع',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),

          if (customer.address != null && customer.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    customer.address!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // شارات الأيام المحددة للزبون
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.event, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Expanded(
                child: customer.visitDays.isEmpty
                    ? Text(
                        'لم يتم تحديد أيام توزيع لهذا الزبون',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: customer.visitDays.map((day) {
                          final isCurrentDay = day == _selectedScheduleDay;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrentDay
                                  ? const Color(0xFF2E7D32)
                                  : (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCurrentDay
                                    ? Colors.white
                                    : (isDark ? Colors.grey.shade300 : Colors.black87),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),

          const Divider(height: 18),

          // أزرار الإجراءات السريعة
          Row(
            children: [
              // 📞 زر الاتصال
              Expanded(
                child: InkWell(
                  onTap: () => _makePhoneCall(customer.phone),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'اتصال',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 📍 زر فتح الخريطة/العنوان
              Expanded(
                child: InkWell(
                  onTap: () => _openCustomerLocationOnMap(customer),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'الموقع',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ✏️ زر تعديل أيام الزيارة
              Expanded(
                child: InkWell(
                  onTap: () => _showEditCustomerVisitDaysSheet(customer),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_calendar, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Text(
                          'الأيام',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📍 فتح الموقع للزبون
  Future<void> _openCustomerLocationOnMap(CustomerModel customer) async {
    if (customer.address == null || customer.address!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد عنوان مسجل لهذا الزبون')),
      );
      return;
    }

    final encoded = Uri.encodeComponent(customer.address!);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الخرائط')),
        );
      }
    }
  }

  // ✏️ النافذة السفلية لتعديل أيام التوزيع لزبون الأدمن
  void _showEditCustomerVisitDaysSheet(CustomerModel customer) {
    final allDays = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    List<String> tempSelected = List.from(customer.visitDays);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_calendar, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أيام التوزيع: ${customer.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'اختر الأيام التي يتم فيها توزيع/تزويد هذا الزبون:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  ...allDays.map((day) {
                    final isChecked = tempSelected.contains(day);
                    return CheckboxListTile(
                      activeColor: const Color(0xFF2E7D32),
                      title: Text(
                        day,
                        style: TextStyle(
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (val) {
                        setSheetState(() {
                          if (val == true) {
                            if (!tempSelected.contains(day)) tempSelected.add(day);
                          } else {
                            tempSelected.remove(day);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'حفظ التغيرات',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await DataService.updateCustomerVisitDays(customer.id, tempSelected);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تحديث أيام التوزيع للزبون ${customer.name} بنجاح'),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ أثناء الحفظ: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// ══════════════════════════════════
}

// ══════════════════════════════════
}