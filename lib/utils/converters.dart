import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ تحويل آمن إلى Double
double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

/// ✅ تحويل آمن إلى Int
int toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// ✅ تحويل آمن إلى String
String toStr(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is DateTime) return v.toIso8601String();
  return v.toString();
}

/// ✅ تحويل آمن إلى Boolean
bool toBool(dynamic v, {bool def = false}) {
  if (v == null) return def;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return def;
}

/// ✅ تحويل آمن إلى DateTime
DateTime? toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}
