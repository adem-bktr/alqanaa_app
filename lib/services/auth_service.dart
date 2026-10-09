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

  /// ✅ تحديث النسخة المحلية (والذاكرة) بدل مسحها، حتى يبقى الدخول ممكناً بدون إنترنت
  static Future<void> _patchLocalUser(String userId,
      {String? role, String? name, String? phone}) async {
    final local = await _getLocalUser();
    if (local != null && local.id == userId) {
      final patched = local.copyWith(role: role, name: name, phone: phone);
      _cachedUser = patched;
      await _saveUserLocally(patched);
    } else if (_cachedUser?.id == userId) {
      _cachedUser = _cachedUser!.copyWith(role: role, name: name, phone: phone);
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

  /// ✅ تحديث بيانات المستخدم من السيرفر في الخلفية (بدون انتظار ولا تعطيل)
  static Future<void> _refreshUserInBackground(String uid) async {
    try {
      final user = await getUser(uid).timeout(const Duration(seconds: 8));
      if (user != null) {
        _cachedUser = user;
        await _saveUserLocally(user);
      }
    } catch (e) {
      debugPrint('ℹ️ تعذّر تحديث المستخدم في الخلفية (لا بأس): $e');
    }
  }

  // ══════════════════════════════════
  // ✅ المستخدم الحالي — النسخة المحلية أولاً (يعمل بدون إنترنت وبسرعة)
  // ══════════════════════════════════
  static Future<UserModel?> getCurrentUser({bool forceRefresh = false}) async {
    final firebaseUser = _auth.currentUser;

    // لا يوجد مستخدم في Firebase Auth
    if (firebaseUser == null) {
      _cachedUser = null;
      await _clearLocalUser();
      return null;
    }

    // 1 — الذاكرة
    if (_cachedUser != null && !forceRefresh) {
      return _cachedUser;
    }

    // 2 — النسخة المحلية على الجهاز: نعيدها فوراً دون انتظار الشبكة، ونحدّثها في الخلفية
    if (!forceRefresh) {
      final local = await _getLocalUser();
      if (local != null && local.id == firebaseUser.uid) {
        _cachedUser = local;
        debugPrint('✅ دخول من البيانات المحلية: ${local.name}');
        _refreshUserInBackground(firebaseUser.uid); // بدون await
        return local;
      }
    }

    // 3 — من Firestore (أول دخول على هذا الجهاز أو تحديث قسري) مع مهلة بدل الانتظار الطويل
    for (int i = 0; i < 2; i++) {
      try {
        final user = await getUser(firebaseUser.uid)
            .timeout(const Duration(seconds: 8));
        if (user != null) {
          _cachedUser = user;
          await _saveUserLocally(user);
          return _cachedUser;
        }
      } catch (e) {
        debugPrint('⚠️ getCurrentUser attempt ${i + 1} failed: $e');
      }
      if (i < 1) await Future.delayed(const Duration(milliseconds: 600));
    }

    // 4 — التخزين المحلي الخاص بـ Firestore (إن كان مستند المستخدم محفوظاً فيه)
    try {
      final doc = await _db
          .collection('users')
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists) {
        final user = UserModel.fromJson({...doc.data()!, 'id': doc.id});
        _cachedUser = user;
        await _saveUserLocally(user);
        return user;
      }
    } catch (_) {}

    // 5 — آخر محاولة: النسخة المحلية (حالة forceRefresh الفاشل)
    final localUser = await _getLocalUser();
    if (localUser != null && localUser.id == firebaseUser.uid) {
      _cachedUser = localUser;
      debugPrint('✅ تم استخدام البيانات المحلية للمستخدم: ${localUser.name}');
      return _cachedUser;
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
    await _queuedWrite(_db.collection('users').doc(userId).update({'role': role}));
    await _patchLocalUser(userId, role: role);
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
      await _queuedWrite(_db.collection('users').doc(userId).update(updates));
      await _patchLocalUser(userId, name: name, phone: phone);
    }
  }

  // ══════════════════════════════════
  //    حذف مستخدم
  // ══════════════════════════════════
  static Future<void> deleteUser(String userId) async {
    await _queuedWrite(_db.collection('users').doc(userId).delete());
    if (_cachedUser?.id == userId) {
      _cachedUser = null;
      await _clearLocalUser();
    }
  }

  /// كتابة تُحفظ محلياً وتُزامَن لاحقاً: لا ننتظر تأكيد السيرفر أكثر من لحظات (حتى لا يتجمّد بلا إنترنت)
  static Future<void> _queuedWrite(Future<void> write) async {
    write.catchError((e) {
      debugPrint('❌ فشلت كتابة مؤجّلة: $e');
    });
    await write.timeout(const Duration(seconds: 4), onTimeout: () {
      debugPrint('📴 الكتابة محفوظة محلياً وستُزامَن عند عودة الاتصال');
    });
  }
}