import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../utils/page_transitions.dart';
import 'user_main_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const RegisterScreen({
    super.key,
    required this.onToggleDarkMode,
    required this.isDarkMode,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // ✅ طلب إذن الموقع مع رسالة توضيحية
  Future<Map<String, dynamic>> _requestLocation() async {
    double? lat;
    double? lng;
    String address = '';

    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        address = await LocationService.getAddressFromLatLng(lat, lng);
      }
    } catch (_) {}

    return {
      'latitude': lat,
      'longitude': lng,
      'address': address,
    };
  }

  Future<void> _showLocationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('تفعيل الموقع'),
          ],
        ),
        content: const Text(
          'نحتاج إلى موقعك لتحديد مكان التوصيل وإظهاره مع طلباتك.\n\nهذا يساعدنا على خدمتك بشكل أفضل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'تخطي',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'السماح',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        phoneController.text.isEmpty) {
      _showSnackBar('الرجاء تعبئة جميع الحقول', Colors.red);
      return;
    }

    if (!_isValidEmail(emailController.text.trim())) {
      _showSnackBar('❌ صيغة البريد الإلكتروني غير صحيحة', Colors.red);
      return;
    }

    if (phoneController.text.trim().length < 9) {
      _showSnackBar('❌ رقم الهاتف غير صحيح', Colors.red);
      return;
    }

    if (passwordController.text.length < 6) {
      _showSnackBar('كلمة المرور يجب أن تكون 6 أحرف على الأقل', Colors.red);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('❌ كلمتا المرور غير متطابقتان', Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ اطلب الموقع قبل التسجيل
      await _showLocationDialog();
      final locationData = await _requestLocation();

      final user = await AuthService.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        phone: phoneController.text.trim(),
        latitude: locationData['latitude'],
        longitude: locationData['longitude'],
        address: locationData['address'],
      );

      if (!mounted) return;

      if (user != null) {
        await NotificationService.saveToken(user.id);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          FadeScaleRoute(
            page: UserMainScreen(
              user: user,
              onToggleDarkMode: widget.onToggleDarkMode,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'حدث خطأ أثناء التسجيل';
      final err = e.toString();
      if (err.contains('email-already-in-use')) {
        errorMsg = '❌ البريد الإلكتروني مستخدم بالفعل';
      } else if (err.contains('invalid-email')) {
        errorMsg = '❌ البريد الإلكتروني غير صحيح';
      } else if (err.contains('weak-password')) {
        errorMsg = '❌ كلمة المرور ضعيفة جداً';
      } else if (err.contains('network-request-failed')) {
        errorMsg = '📶 تحقق من اتصالك بالإنترنت';
      }
      _showSnackBar(errorMsg, Colors.red);
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
              Color(0xFF388E3C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                            Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildField(
                          controller: nameController,
                          hint: 'الاسم الكامل',
                          icon: Icons.person_outline,
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: phoneController,
                          hint: 'رقم الهاتف',
                          icon: Icons.phone_outlined,
                          type: TextInputType.phone,
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: emailController,
                          hint: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'كلمة المرور (6 أحرف على الأقل)',
                            prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF2E7D32)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(
                                      () => obscurePassword = !obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => register(),
                          decoration: InputDecoration(
                            hintText: 'تأكيد كلمة المرور',
                            prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF2E7D32)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(
                                      () => obscureConfirm = !obscureConfirm),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                                : const Text(
                              'إنشاء الحساب',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'لديك حساب؟ سجّل دخولك',
                            style: TextStyle(color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      textInputAction: action,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
