import 'package:geolocator/geolocator.dart';
import 'geo_helper.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
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
