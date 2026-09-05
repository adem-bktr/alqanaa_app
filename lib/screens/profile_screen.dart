import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  bool isLoading = false;
  bool isEditing = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ✅ Scroll + Keyboard
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocus = FocusNode();

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    phoneController = TextEditingController(text: widget.user.phone);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    _animController.dispose();
    _scrollController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  // ✅ Keyboard Scroll Handler
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (!_scrollController.hasClients) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 80).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollController.animateTo(
        (_scrollController.offset + 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollController.animateTo(
        (_scrollController.offset - 400).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == const Color(0xFF2E7D32) ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showSnackBar('الرجاء ملء جميع الحقول', Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService.updateUserProfile(
        userId: widget.user.id,
        name: name,
        phone: phone,
      );

      if (!mounted) return;
      setState(() { isLoading = false; isEditing = false; });
      _showSnackBar('✅ تم تحديث الملف الشخصي', const Color(0xFF2E7D32));
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('حدث خطأ، حاول مجدداً', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5);
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);

    return KeyboardListener(
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: bgColor,

        // ══════════════════════════════════
        //  Desktop: بدون AppBar عادي
        // ══════════════════════════════════
        appBar: isDesktop ? null : AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          title: const Text('الملف الشخصي',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: [
            if (!isEditing)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () => setState(() => isEditing = true),
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  label: const Text('تعديل', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),

        // ══════════════════════════════════
        //  Desktop: Top Bar
        // ══════════════════════════════════
        body: isDesktop
            ? Column(
          children: [
            // Desktop Top Bar
            Container(
              height: 60,
              color: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  const Text('الملف الشخصي',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Spacer(),
                  if (!isEditing)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextButton.icon(
                        onPressed: () => setState(() => isEditing = true),
                        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                        label: const Text('تعديل', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(30),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _buildContent(
                              bgColor, cardColor, textColor, fillColor, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        )

        // ══════════════════════════════════
        //  Mobile: بدون تغيير
        // ══════════════════════════════════
            : FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(bgColor, cardColor, textColor, fillColor, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color bgColor, Color cardColor, Color textColor,
      Color fillColor, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 10),

        // ── Avatar ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // الاسم
        Text(
          widget.user.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),

        // الدور
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.user.isSpecial
                ? Colors.amber.withOpacity(0.15)
                : const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.user.isSpecial
                  ? Colors.amber.withOpacity(0.5)
                  : const Color(0xFF2E7D32).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.user.isSpecial ? Icons.star_rounded : Icons.person_rounded,
                size: 16,
                color: widget.user.isSpecial ? Colors.amber : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 6),
              Text(
                widget.user.isSpecial ? 'زبون مميز' : 'زبون',
                style: TextStyle(
                  color: widget.user.isSpecial ? Colors.amber.shade800 : const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // ── بطاقة المعلومات ──
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                  Text('المعلومات الشخصية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      )),
                ],
              ),
              const SizedBox(height: 20),

              // الاسم
              _buildField(
                label: 'الاسم الكامل',
                controller: nameController,
                icon: Icons.person_rounded,
                enabled: isEditing,
                fillColor: fillColor,
                textColor: textColor,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // الهاتف
              _buildField(
                label: 'رقم الهاتف',
                controller: phoneController,
                icon: Icons.phone_rounded,
                enabled: isEditing,
                fillColor: fillColor,
                textColor: textColor,
                isDark: isDark,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              // البريد (غير قابل للتعديل)
              _buildReadOnlyField(
                label: 'البريد الإلكتروني',
                value: widget.user.email,
                icon: Icons.email_rounded,
                fillColor: fillColor,
                textColor: textColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── بطاقة معلومات الحساب ──
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle_rounded,
                      color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                  Text('معلومات الحساب',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      )),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow(
                icon: Icons.calendar_today_rounded,
                label: 'تاريخ التسجيل',
                value: widget.user.createdAt.isNotEmpty
                    ? widget.user.createdAt.substring(0, 10)
                    : 'غير محدد',
                textColor: textColor,
                isDark: isDark,
              ),
              const Divider(height: 20),
              _infoRow(
                icon: Icons.fingerprint_rounded,
                label: 'رقم الحساب',
                value: widget.user.id.length > 10
                    ? '...${widget.user.id.substring(widget.user.id.length - 8)}'
                    : widget.user.id,
                textColor: textColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── أزرار ──
        if (isEditing) ...[
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        isEditing = false;
                        nameController.text = widget.user.name;
                        phoneController.text = widget.user.phone;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _saveProfile,
                    icon: isLoading
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, color: Colors.white),
                    label: Text(
                      isLoading ? 'جاري الحفظ...' : 'حفظ التغييرات',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    required Color fillColor,
    required Color textColor,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textAlign: TextAlign.right,
          style: TextStyle(color: textColor, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                color: enabled ? const Color(0xFF2E7D32) : Colors.grey, size: 20),
            filled: true,
            fillColor: enabled
                ? (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F8F0))
                : fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required Color fillColor,
    required Color textColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('غير قابل للتعديل',
                    style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  )),
              Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}