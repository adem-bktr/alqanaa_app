import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/models.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static UserModel? _cachedUser;

  // ✅ مفتاح حفظ بيانات المستخدم محلياً
  static const String _userCacheKey = 'cached_user_data';

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════
  //    ✅ حفظ المستخدم محلياً
  // ══════════════════════════════════
  static Future<void> _saveUserLocally(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userCacheKey, jsonEncode(user.toJson()));
      debugPrint('✅ تم حفظ بيانات المستخدم محلياً');
    } catch (e) {
      debugPrint('⚠️ فشل حفظ المستخدم محلياً: $e');
    }
  }

  // ✅ جلب المستخدم المحفوظ محلياً
  static Future<UserModel?> _getLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_userCacheKey);
      if (data == null) return null;
      final map = jsonDecode(data) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (e) {
      debugPrint('⚠️ فشل قراءة المستخدم المحلي: $e');
      return null;
    }
  }

  // ✅ مسح البيانات المحلية
  static Future<void> _clearLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userCacheKey);
    } catch (e) {
      debugPrint('⚠️ فشل مسح المستخدم المحلي: $e');
    }
  }

  // ══════════════════════════════════
  //    تسجيل الدخول
  // ══════════════════════════════════
  static Future<UserModel?> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (cred.user == null) return null;
    _cachedUser = null;
    final user = await getCurrentUser(forceRefresh: true);
    return user;
  }

  // ══════════════════════════════════
  //    تسجيل مستخدم جديد
  // ══════════════════════════════════
  static Future<UserModel?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (cred.user == null) return null;

    final user = UserModel(
      id: cred.user!.uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: 'user_normal',
      createdAt: DateTime.now().toIso8601String(),
      latitude: latitude,
      longitude: longitude,
      address: address,
    );

    await _db.collection('users').doc(user.id).set(user.toJson());
    _cachedUser = user;
    // ✅ احفظ محلياً عند التسجيل
    await _saveUserLocally(user);
    return user;
  }

  // ══════════════════════════════════
  //    جلب بيانات مستخدم من Firestore
  // ══════════════════════════════════
  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  // ══════════════════════════════════
  // ✅ المستخدم الحالي — مع حفظ محلي
  // ══════════════════════════════════
  static Future<UserModel?> getCurrentUser({bool forceRefresh = false}) async {
    final firebaseUser = _auth.currentUser;

    // لا يوجد مستخدم في Firebase Auth
    if (firebaseUser == null) {
      _cachedUser = null;
      await _clearLocalUser();
      return null;
    }

    // ✅ 1 — استخدم الـ Cache في الذاكرة إذا موجود
    if (_cachedUser != null && !forceRefresh) {
      return _cachedUser;
    }

    // ✅ 2 — جرب جلب من Firestore مع retry تلقائي
    for (int i = 0; i < 3; i++) {
      try {
        final user = await getUser(firebaseUser.uid);
        if (user != null) {
          _cachedUser = user;
          // ✅ احفظ محلياً في كل مرة تنجح
          await _saveUserLocally(user);
          return _cachedUser;
        }
      } catch (e) {
        debugPrint('⚠️ getCurrentUser attempt ${i + 1} failed: $e');
      }
      if (i < 2) await Future.delayed(const Duration(seconds: 1));
    }

    // ✅ 3 — Firestore فشل — استخدم البيانات المحفوظة محلياً
    debugPrint('⚠️ Firestore فشل — جاري استخدام البيانات المحلية');
    final localUser = await _getLocalUser();
    if (localUser != null) {
      // تحقق أن البيانات المحلية هي لنفس المستخدم
      if (localUser.id == firebaseUser.uid) {
        _cachedUser = localUser;
        debugPrint('✅ تم استخدام البيانات المحلية للمستخدم: ${localUser.name}');
        return _cachedUser;
      }
    }

    return null;
  }

  // ══════════════════════════════════
  //    تسجيل الخروج
  // ══════════════════════════════════
  static Future<void> logout() async {
    _cachedUser = null;
    await _clearLocalUser();
    await _auth.signOut();
  }

  // ══════════════════════════════════
  //    إعادة تعيين كلمة المرور
  // ══════════════════════════════════
  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ══════════════════════════════════
  //    جلب كل المستخدمين
  // ══════════════════════════════════
  static Future<List<UserModel>> getAllUsers() async {
    final snap = await _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // ══════════════════════════════════
  //    تغيير الدور
  // ══════════════════════════════════
  static Future<void> updateUserRole(String userId, String role) async {
    await _db.collection('users').doc(userId).update({'role': role});
    if (_cachedUser?.id == userId) {
      _cachedUser = null;
      await _clearLocalUser();
    }
  }

  // ══════════════════════════════════
  //    تحديث بيانات المستخدم
  // ══════════════════════════════════
  static Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (updates.isNotEmpty) {
      await _db.collection('users').doc(userId).update(updates);
      _cachedUser = null;
      await _clearLocalUser();
    }
  }

  // ══════════════════════════════════
  //    حذف مستخدم
  // ══════════════════════════════════
  static Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
    if (_cachedUser?.id == userId) {
      _cachedUser = null;
      await _clearLocalUser();
    }
  }
}