import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
      // ✅ استخدام الكلاس المباشر من مكتبة geocoding لضمان الوصول للدالة
      final List<Placemark> pms = await GeocodingPlatform.instance.placemarkFromCoordinates(lat, lng);
      if (pms.isEmpty) return '';
      final p = pms.first;
      
      final List<String> addressParts = [];
      if (p.street != null && p.street!.isNotEmpty) addressParts.add(p.street!);
      if (p.locality != null && p.locality!.isNotEmpty) addressParts.add(p.locality!);
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) addressParts.add(p.administrativeArea!);
      if (p.country != null && p.country!.isNotEmpty) addressParts.add(p.country!);

      return addressParts.join(', ');
    } catch (_) {
      return '';
    }
  }
}
