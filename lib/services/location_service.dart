import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'geo_helper.dart';
import 'dart:io';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    // ✅ تعطيل تحديد الموقع على الويندوز لتجنب أخطاء البناء والـ Nuget
    if (Platform.isWindows) return null;
    
    try {
      bool serviceEnabled = await GeolocatorPlatform.instance.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await GeolocatorPlatform.instance.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await GeolocatorPlatform.instance.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await GeolocatorPlatform.instance.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      // ✅ نستخدم الوسيط (Proxy) الذي يفصل كود الهاتف عن كود الويب
      final List<String> addressParts = await getAddressFromCoordinates(lat, lng);
      
      if (addressParts.isEmpty) return '';
      return addressParts.join(', ');
    } catch (_) {
      return '';
    }
  }
}
