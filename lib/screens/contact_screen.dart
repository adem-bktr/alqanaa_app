import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final String phoneNumber = '0666629473';
  final String whatsappNumber = '213666629473';
  final double locationLat = 35.9510639;
  final double locationLng = 5.0252799;
  final String locationName =
      'القناعة Grossiste - رأس الوادي';

  // ══════════════════════════════════
  //  Responsive
  // ══════════════════════════════════
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnackBar('تعذر إجراء الاتصال', Colors.red);
    }
  }

  Future<void> _openWhatsApp() async {
    final Uri url =
    Uri.parse('https://wa.me/$whatsappNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url,
          mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('تعذر فتح واتساب', Colors.red);
    }
  }

  Future<void> _copyPhone() async {
    await Clipboard.setData(
        ClipboardData(text: phoneNumber));
    _showSnackBar(
        '✅ تم نسخ رقم الهاتف', const Color(0xFF2E7D32));
  }

  Future<void> _openGoogleMaps() async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$locationLat,$locationLng',
    );
    final Uri googleMapsApp = Uri.parse(
      'geo:$locationLat,$locationLng?q=$locationLat,$locationLng($locationName)',
    );
    if (await canLaunchUrl(googleMapsApp)) {
      await launchUrl(googleMapsApp,
          mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl,
          mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('تعذر فتح الخريطة', Colors.red);
    }
  }

  // ══════════════════════════════════
  //  BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
    isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F2F5);
    final cardColor =
    isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor =
    isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    if (isDesktop) {
      return _buildDesktopLayout(
          isDark, bgColor, cardColor, textColor, subColor);
    }
    return _buildMobileLayout(
        isDark, bgColor, cardColor, textColor, subColor);
  }

  // ══════════════════════════════════
  //  Desktop Layout
  // ══════════════════════════════════
  Widget _buildDesktopLayout(bool isDark, Color bgColor,
      Color cardColor, Color textColor, Color subColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('تواصل معنا',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── العمود الأيسر: معلومات الاتصال ──
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // لوغو
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration:
                      const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (_, value, child) =>
                          Transform.scale(
                              scale: value, child: child),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1B5E20),
                              Color(0xFF2E7D32),
                              Color(0xFF43A047)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32)
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const Icon(Icons.store_rounded,
                                color: Colors.white,
                                size: 50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('القناعة',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                    const SizedBox(height: 6),
                    Text('Grossiste',
                        style: TextStyle(
                            fontSize: 14,
                            color: subColor,
                            letterSpacing: 3)),
                    const SizedBox(height: 6),
                    Text('نحن هنا لخدمتكم في أي وقت',
                        style: TextStyle(
                            fontSize: 14, color: subColor)),
                    const SizedBox(height: 30),

                    // رقم الهاتف
                    _buildPhoneCard(
                        isDark, cardColor, textColor),
                    const SizedBox(height: 16),

                    // زر الاتصال الكبير
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _makeCall,
                        icon: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: Colors.white,
                            size: 24),
                        label: const Text('اتصل بنا الآن',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── العمود الأيمن: الموقع + ساعات العمل + معلومات ──
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildLocationCard(
                        isDark, cardColor, textColor, subColor),
                    const SizedBox(height: 16),
                    _buildWorkingHoursCard(
                        isDark, cardColor, textColor, subColor),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                        isDark, cardColor, textColor, subColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Mobile Layout
  // ══════════════════════════════════
  Widget _buildMobileLayout(bool isDark, Color bgColor,
      Color cardColor, Color textColor, Color subColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('تواصل معنا',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (_, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B5E20),
                          Color(0xFF2E7D32),
                          Color(0xFF43A047)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32)
                              .withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.store_rounded,
                              color: Colors.white, size: 50)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('القناعة',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                const SizedBox(height: 6),
                Text('Grossiste',
                    style: TextStyle(
                        fontSize: 14,
                        color: subColor,
                        letterSpacing: 3)),
                const SizedBox(height: 6),
                Text('نحن هنا لخدمتكم في أي وقت',
                    style:
                    TextStyle(fontSize: 14, color: subColor)),
                const SizedBox(height: 30),
                _buildPhoneCard(isDark, cardColor, textColor),
                const SizedBox(height: 16),
                _buildLocationCard(
                    isDark, cardColor, textColor, subColor),
                const SizedBox(height: 16),
                _buildWorkingHoursCard(
                    isDark, cardColor, textColor, subColor),
                const SizedBox(height: 16),
                _buildInfoCard(
                    isDark, cardColor, textColor, subColor),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _makeCall,
                    icon: const Icon(Icons.phone_in_talk_rounded,
                        color: Colors.white, size: 24),
                    label: const Text('اتصل بنا الآن',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: const Color(0xFF2E7D32)
                          .withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  //  Shared Card Widgets
  // ══════════════════════════════════
  Widget _buildPhoneCard(
      bool isDark, Color cardColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.phone_rounded,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text('رقم الهاتف',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                  const Color(0xFF2E7D32).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  phoneNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _copyPhone,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        color: Color(0xFF2E7D32), size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ContactButton(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'اتصال',
                  color: const Color(0xFF2E7D32),
                  onTap: _makeCall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactButton(
                  icon: Icons.chat_rounded,
                  label: 'واتساب',
                  color: const Color(0xFF25D366),
                  onTap: _openWhatsApp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool isDark, Color cardColor,
      Color textColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.07),
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
              const Icon(Icons.location_on_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('موقعنا',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.red, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text('رأس الوادي',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      Text('برج بوعريريج',
                          style: TextStyle(
                              fontSize: 13, color: subColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ContactButton(
            icon: Icons.map_rounded,
            label: 'فتح على الخريطة',
            color: Colors.blue.shade700,
            onTap: _openGoogleMaps,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursCard(bool isDark, Color cardColor,
      Color textColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.07),
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
              const Icon(Icons.access_time_rounded,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text('ساعات العمل',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 16),
          _WorkingHourRow(
            day: 'السبت — الخميس',
            hours: '08:00 ص — 08:00 م',
            isOpen: true,
            textColor: textColor,
            subColor: subColor,
          ),
          const Divider(height: 20),
          _WorkingHourRow(
            day: 'الجمعة',
            hours: 'مغلق',
            isOpen: false,
            textColor: textColor,
            subColor: subColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, Color cardColor,
      Color textColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.location_on_rounded,
            iconColor: Colors.red,
            title: 'الموقع',
            subtitle: 'رأس الوادي',
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
          ),
          const Divider(height: 24),
          _InfoTile(
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF2E7D32),
            title: 'التوصيل',
            subtitle: 'رأس الوادي وضواحيها',
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
          ),
          const Divider(height: 24),
          _InfoTile(
            icon: Icons.inventory_2_rounded,
            iconColor: Colors.blue,
            title: 'البيع',
            subtitle: 'بالجملة والتجزئة',
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════
//  زر التواصل
// ══════════════════════════════════
class _ContactButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<_ContactButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()
          ..scale(_pressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: _pressed ? 4 : 10,
              offset: Offset(0, _pressed ? 2 : 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════
//  صف ساعات العمل
// ══════════════════════════════════
class _WorkingHourRow extends StatelessWidget {
  final String day;
  final String hours;
  final bool isOpen;
  final Color textColor;
  final Color subColor;

  const _WorkingHourRow({
    required this.day,
    required this.hours,
    required this.isOpen,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen
                ? const Color(0xFF2E7D32).withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isOpen ? 'مفتوح' : 'مغلق',
            style: TextStyle(
              color: isOpen
                  ? const Color(0xFF2E7D32)
                  : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(day,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
            Text(hours,
                style:
                TextStyle(fontSize: 12, color: subColor)),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════
//  بطاقة معلومة
// ══════════════════════════════════
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subColor;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            Text(subtitle,
                style:
                TextStyle(fontSize: 13, color: subColor)),
          ],
        ),
      ],
    );
  }
}