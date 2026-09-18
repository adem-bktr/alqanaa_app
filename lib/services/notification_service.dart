import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await NotificationService.showLocalNotification(
    title: message.notification?.title ?? 'إشعار جديد',
    body: message.notification?.body ?? '',
  );
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ✅ معرف مشروعك في Firebase (تجده في Firebase Console → Project Settings)
  static const String _projectId = 'alqanaa-f16e4';

  // ✅ متغير لتخزين Access Token
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // ══════════════════════════════════
  //    Initialize
  // ══════════════════════════════════

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.denied) {
      debugPrint('⚠️ إشعارات مرفوضة');
      return;
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 ضغط: ${details.payload}');
      },
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
          '📬 رسالة: ${message.notification?.title}');
      showLocalNotification(
        title: message.notification?.title ?? 'إشعار',
        body: message.notification?.body ?? '',
        payload: message.data['type'],
      );
    });

    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveToken(user.uid);
      }
    });

    debugPrint('✅ NotificationService initialized');
  }

  // ══════════════════════════════════
  //    حفظ FCM Token
  // ══════════════════════════════════

  static Future<void> saveToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(
        {
          'fcmToken': token,
          'tokenUpdatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('✅ Token محفوظ');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ Token: $e');
    }
  }

  // ══════════════════════════════════
  //    إشعار محلي
  // ══════════════════════════════════

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alqanaa_channel',
          'القناعة',
          channelDescription: 'إشعارات تطبيق القناعة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ══════════════════════════════════
  //  ✅ الحصول على Access Token (HTTP v1)
  // ══════════════════════════════════

  static Future<String?> _getAccessToken() async {
    try {
      // ✅ إذا كان التوكن موجود ولم ينتهِ
      if (_accessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }

      // ✅ قراءة ملف Service Account
      final jsonString = await rootBundle
          .loadString('assets/service-account.json');
      final credentials =
      ServiceAccountCredentials.fromJson(jsonString);

      // ✅ الحصول على Access Token
      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      _accessToken = client.credentials.accessToken.data;
      _tokenExpiry = client.credentials.accessToken.expiry;

      client.close();

      debugPrint('✅ Access Token جاهز');
      return _accessToken;
    } catch (e) {
      debugPrint('❌ خطأ في الحصول على Access Token: $e');
      return null;
    }
  }

  // ══════════════════════════════════
  //  إشعار للأدمن - طلب جديد ✅
  // ══════════════════════════════════

  static Future<void> notifyAdminNewOrder({
    required String customerName,
    required double total,
    required String orderId,
  }) async {
    try {
      debugPrint('📤 إرسال إشعار للأدمن...');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ لا يوجد أدمن');
        return;
      }

      int sent = 0;
      for (final doc in snapshot.docs) {
        final token =
            (doc.data()['fcmToken'] as String?) ?? '';

        if (token.isEmpty) {
          debugPrint(
              '⚠️ أدمن بدون token: ${doc.id}');
          continue;
        }

        final success = await _sendFCMv1(
          token: token,
          title: '📦 طلب جديد!',
          body:
          '$customerName - ${total.toStringAsFixed(0)} DA',
          data: {
            'type': 'new_order',
            'orderId': orderId,
            'customerName': customerName,
            'total': total.toStringAsFixed(0),
          },
        );

        if (success) sent++;
      }

      debugPrint('✅ أُرسل لـ $sent أدمن');
    } catch (e) {
      debugPrint('❌ خطأ notifyAdminNewOrder: $e');
    }
  }

  // ══════════════════════════════════
  //  إشعار للزبون - تغيير حالة الطلب ✅
  // ══════════════════════════════════

  static Future<void> notifyUserOrderStatus({
    required String userId,
    required String status,
    required String customerName,
    required String orderId,
  }) async {
    try {
      debugPrint('📤 إرسال إشعار للزبون: $userId');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final token =
          (userDoc.data()?['fcmToken'] as String?) ?? '';
      if (token.isEmpty) return;

      String title;
      String body;

      switch (status) {
        case 'confirmed':
          title = '✅ تم تأكيد طلبك';
          body =
          'شكراً لك $customerName، طلبك رقم $orderId قيد التجهيز';
          break;
        case 'rejected':
          title = '❌ نعتذر، تم رفض الطلب';
          body =
          'نعتذر $customerName، لا يمكننا تلبية طلبك حالياً';
          break;
        default:
          title = '⏳ تحديث حالة الطلب';
          body =
          'تم تحديث حالة طلبك رقم $orderId';
      }

      await _sendFCMv1(
        token: token,
        title: title,
        body: body,
        data: {
          'type': 'order_status',
          'orderId': orderId,
          'status': status,
        },
      );

      debugPrint('✅ أُرسل الإشعار للزبون');
    } catch (e) {
      debugPrint('❌ خطأ notifyUserOrderStatus: $e');
    }
  }

  // ══════════════════════════════════
  //  ✅ الإرسال عبر HTTP v1 API (الجديدة)
  // ══════════════════════════════════

  static Future<bool> _sendFCMv1({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('❌ لا يوجد Access Token');
        return false;
      }

      final response = await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data ?? {},
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'alqanaa_channel',
                'sound': 'default',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                },
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM v1 sent!');
        return true;
      }

      debugPrint(
          '❌ FCM v1 Error ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ _sendFCMv1 error: $e');
      return false;
    }
  }

  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
