import 'package:geocoding/geocoding.dart';

Future<List<String>> getGeoImplementation(double lat, double lng) async {
  try {
    // ✅ استخدام الاستدعاء المباشر دون تعقيدات لضمان توافق سيرفرات البناء
    final placemarks = await placemarkFromCoordinates(lat, lng);
    
    if (placemarks.isEmpty) return [];
    final p = placemarks.first;
    
    final List<String> addressParts = [];
    if (p.street != null && p.street!.isNotEmpty) addressParts.add(p.street!);
    if (p.locality != null && p.locality!.isNotEmpty) addressParts.add(p.locality!);
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) addressParts.add(p.administrativeArea!);
    if (p.country != null && p.country!.isNotEmpty) addressParts.add(p.country!);
    
    return addressParts;
  } catch (e) {
    return [];
  }
}
