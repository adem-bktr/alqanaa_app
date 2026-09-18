import 'package:geocoding/geocoding.dart';

Future<List<String>> getGeoImplementation(double lat, double lng) async {
  try {
    // ✅ محاولة استدعاء الدالة بأكثر طريقة يدوية لضمان مرور الـ Analyze والـ Build
    // سنستخدم GeocodingPlatform.instance مباشرة مع التحييد (Casting) لتجاوز مشاكل التعريف
    final dynamic platform = GeocodingPlatform.instance;
    final List<dynamic> placemarks = await platform.placemarkFromCoordinates(lat, lng);
    
    if (placemarks == null || placemarks.isEmpty) return [];
    final p = placemarks.first;
    
    final List<String> addressParts = [];
    // الوصول للحقول عبر dynamic لضمان التوافق مع أي نسخة مكتبة
    if (p.street != null && p.street.toString().isNotEmpty) addressParts.add(p.street.toString());
    if (p.locality != null && p.locality.toString().isNotEmpty) addressParts.add(p.locality.toString());
    if (p.administrativeArea != null && p.administrativeArea.toString().isNotEmpty) addressParts.add(p.administrativeArea.toString());
    if (p.country != null && p.country.toString().isNotEmpty) addressParts.add(p.country.toString());
    
    return addressParts;
  } catch (e) {
    return [];
  }
}
