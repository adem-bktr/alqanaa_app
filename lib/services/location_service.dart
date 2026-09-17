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
      // ✅ الاستدعاء المباشر بدون أي prefix لضمان أعلى توافق
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      
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
