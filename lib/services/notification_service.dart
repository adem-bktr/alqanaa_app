import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // ══════════════════════════════════
  //    Initialize
  // ══════════════════════════════════

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('⚠️ إشعارات مرفوضة');
      return;
    }

    await _localNotifications.initialize(
      settings: const InitializationSettings(
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

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'alqanaa_channel',
          'القناعة',
          description: 'إشعارات تطبيق القناعة',
          importance: Importance.high,
          playSound: true,
        ),
      );
    }

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📬 رسالة: ${message.notification?.title}');
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
  //    طلب إذن الإشعارات وحفظ FCM Token
  // ══════════════════════════════════

  static Future<void> requestPermissionAndSaveToken(String userId) async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        debugPrint('🔔 نتيجة طلب إذن الإشعارات: $result');
      } else {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      await saveToken(userId);
    } catch (e) {
      debugPrint('⚠️ خطأ في طلب إذن الإشعارات: $e');
      await saveToken(userId);
    }
  }

  static Future<void> saveToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
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
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
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
  //  إشعار جماعي تذكيري للزبائن (إنشاء وثيقة في Firestore لتشغيل Cloud Function)
  // ══════════════════════════════════

  static Future<int> broadcastNotificationToCustomers({
    required String title,
    required String body,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ يجب أن تكون مسجلاً لإرسال إعلان');
        return 0;
      }

      debugPrint('📤 إرسال الإشعار الجماعي عبر مجموعة الإعلانات (announcements)...');

      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'message': body,
        'createdBy': currentUser.uid,
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ تم إرسال الإشعار الجماعي بنجاح');
      return 1;
    } catch (e) {
      debugPrint('❌ خطأ في broadcastNotificationToCustomers: $e');
      return 0;
    }
  }

  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
