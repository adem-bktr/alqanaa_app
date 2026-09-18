Future<List<String>> getGeoImplementation(double lat, double lng) async {
  // ✅ الويب لا يدعم مكتبة geocoding، لذا نرجع نصاً ثابتاً لتجنب فشل البناء
  return ['موقع من الويب (Geocoding not supported)'];
}
