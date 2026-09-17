// ✅ ملف الوسيط (Proxy) لحل مشكلة بناء الويب
import 'geo_helper_mobile.dart' 
  if (dart.library.html) 'geo_helper_web.dart'
  if (dart.library.js_util) 'geo_helper_web.dart';

abstract class GeoProxy {
  Future<List<String>> getAddress(double lat, double lng);
}

Future<List<String>> getAddressFromCoordinates(double lat, double lng) => 
    getGeoImplementation(lat, lng);
