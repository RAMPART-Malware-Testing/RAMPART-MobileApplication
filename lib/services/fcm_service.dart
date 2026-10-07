import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';

/// key เดียวกับที่หน้าตั้งค่าเขียน (ดู lib/screens/settings_screen.dart)
const String _notifEnabledKey = 'notif_enabled';

/// อ่านค่าที่ผู้ใช้ตั้งไว้ว่าต้องการรับการแจ้งเตือนหรือไม่
///
/// อ่านจาก storage ทุกครั้งแทนการจำไว้ในหน่วยความจำ เพราะฟังก์ชันนี้ถูกเรียกจาก
/// ทั้ง isolate หลักและ isolate เบื้องหลัง ซึ่งไม่แชร์หน่วยความจำกัน
/// ค่าเริ่มต้นคือเปิด เมื่ออ่านไม่ได้หรือยังไม่เคยตั้ง
Future<bool> notificationsAllowed() async {
  try {
    final stored = await const FlutterSecureStorage().read(
      key: _notifEnabledKey,
    );
    return stored != 'false';
  } catch (_) {
    return true;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'RAMPART';
  final body = message.notification?.body ?? '';
  print('[FCM] Background: $title — $body');
  await _ensureNotificationsInit();
  if (!await notificationsAllowed()) return;
  await _showLocalNotification(
    id: message.messageId.hashCode,
    title: title,
    body: body,
    payload: _encodePayload(message),
  );
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
bool _notificationsInited = false;

/// ปลายทางที่การแจ้งเตือนได้รับอนุญาตให้เปิด
///
/// route ที่ไม่อยู่ในลิสต์ต้องถูกเมิน ไม่ใช่ปล่อยให้ GetMaterialApp ตกไปที่
/// unknownRoute ซึ่งตั้งไว้เป็นหน้า login — ผู้ใช้ที่แตะแจ้งเตือนจะถูกเด้งออกจาก
/// session ที่ยังใช้งานได้
const Set<String> _pushRoutes = {
  '/home',
  '/analysis-progress',
  '/analysis-result',
  '/help',
};

/// สองหน้านี้รับ Get.arguments เป็น taskId ตรง ๆ ไม่ใช่ Map
const Set<String> _pushTaskRoutes = {'/analysis-progress', '/analysis-result'};

/// ห่อ route กับ taskId เป็น JSON เพื่อให้ปลายทางที่ต้องใช้ taskId เปิดได้
/// แจ้งเตือนที่ไม่มี taskId ยังส่ง route เดี่ยว ๆ เหมือนเดิม
String _encodePayload(RemoteMessage message) {
  final route = message.data['route'];
  if (route is! String || route.isEmpty) return '';
  final taskId = message.data['task_id'] ?? message.data['taskId'];
  if (taskId is String && taskId.isNotEmpty && _pushTaskRoutes.contains(route)) {
    return jsonEncode({'route': route, 'task_id': taskId});
  }
  return route;
}

/// งานเดิมที่หน้าของมัน (/analysis-progress หรือ /analysis-result) เปิดค้างอยู่
/// บนสุดของสแตกแล้ว — แตะแจ้งเตือนของงานเดียวกันซ้ำต้องไม่ push หน้าซ้อนกัน
/// ไม่งั้นกดย้อนกลับจะเจอหน้าเดิมซ้ำ ๆ เหมือนปุ่มย้อนพัง
bool shouldSkipTaskPushNavigation({
  required String currentRoute,
  required Object? currentArguments,
  required String taskId,
}) {
  final onTaskScreen =
      currentRoute == '/analysis-progress' ||
      currentRoute == '/analysis-result';
  return onTaskScreen && currentArguments?.toString() == taskId;
}

void _openFromPush(String? route, String? taskId) {
  if (route == null || route.isEmpty || !_pushRoutes.contains(route)) {
    debugPrint('[FCM] ไม่รู้จักปลายทางจากการแจ้งเตือน: $route');
    return;
  }
  // ยังไม่มี navigator (แอปยังไม่ขึ้นหน้าจอ) การเรียกตอนนี้จะถูกทิ้งเงียบ ๆ
  if (Get.key.currentState == null) {
    debugPrint('[FCM] navigator ยังไม่พร้อม ข้ามการเปิด $route');
    return;
  }
  if (_pushTaskRoutes.contains(route)) {
    if (taskId == null || taskId.isEmpty) return;
    if (shouldSkipTaskPushNavigation(
      currentRoute: Get.currentRoute,
      currentArguments: Get.arguments,
      taskId: taskId,
    )) {
      debugPrint('[FCM] งาน $taskId เปิดอยู่แล้ว ข้ามการ push $route ซ้ำ');
      return;
    }
    Get.toNamed(route, arguments: taskId);
    return;
  }
  Get.toNamed(route);
}

Future<void> _ensureNotificationsInit() async {
  if (_notificationsInited) return;
  _notificationsInited = true;

  // ต้องเป็น drawable (ไม่ใช่ mipmap) ไม่งั้น initialize จะโยน PlatformException(invalid_icon)
  const androidSettings = AndroidInitializationSettings('ic_notification');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  const androidChannel = AndroidNotificationChannel(
    'rampart_channel',
    'RAMPART Notifications',
    description: 'การแจ้งเตือนจาก RAMPART',
    importance: Importance.high,
  );
  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(androidChannel);
}

Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
  int id = 0,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'rampart_channel',
    'RAMPART Notifications',
    channelDescription: 'การแจ้งเตือนจาก RAMPART',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );
  await _localNotifications.show(id, title, body, details, payload: payload);
}

void _onNotificationTap(NotificationResponse response) {
  final parsed = _parseNotificationPayload(response.payload);
  if (parsed == null) return;
  _openFromPush(parsed.$1, parsed.$2);
}

/// payload รุ่นใหม่เป็น JSON ที่พา taskId มาด้วย ส่วนรุ่นเก่าเป็น route เดี่ยว ๆ
/// คืน null เมื่ออ่านไม่ได้/ไม่มี payload
(String route, String? taskId)? _parseNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  if (!payload.startsWith('{')) return (payload, null);
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      final route = decoded['route'];
      final taskId = decoded['task_id'];
      if (route is String && route.isNotEmpty) {
        return (route, taskId is String ? taskId : null);
      }
    }
  } catch (_) {
    debugPrint('[FCM] payload ของการแจ้งเตือนอ่านไม่ได้');
  }
  return null;
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;

  /// เป็น observable เพราะตอนนี้ Firebase อาจเริ่มหลังจากผู้ใช้ล็อกอินเสร็จแล้ว
  /// หน้าจอที่ต้องการ token จึงต้องรอค่านี้ ไม่ใช่อ่านครั้งเดียวตอน initState
  final deviceToken = RxnString();

  String? _pendingRoute;
  String? _pendingTaskId;
  bool _initialized = false;

  FcmService._internal();

  /// เตรียมระบบ push คืน true เมื่อ Firebase พร้อมรับข้อความจริง
  ///
  /// คืน false เมื่อยังไม่มีเน็ตหรือ Firebase ติดตั้งไม่สำเร็จ — ผู้เรียกต้อง
  /// ไม่ navigate ต่อจาก [handlePendingInitialMessage] ในกรณีนั้น
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('[FCM] Firebase init ไม่สำเร็จ: $e');
      return false;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('[FCM] Authorization status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      deviceToken.value = await FirebaseMessaging.instance.getToken();
      print('[FCM] Device token: ${deviceToken.value}');
      _registerCurrentToken();

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        deviceToken.value = newToken;
        print('[FCM] Token refreshed: $newToken');
        _registerCurrentToken();
      });
    }

    await _ensureNotificationsInit();
    await _localNotifications.cancelAll();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final route = initialMessage.data['route'];
      final taskId = initialMessage.data['task_id'] ?? initialMessage.data['taskId'];
      _pendingRoute = route is String ? route : null;
      _pendingTaskId = taskId is String ? taskId : null;
    }

    // แอปถูกปิดอยู่แล้วผู้ใช้แตะ "การแจ้งเตือนที่แอปสร้างเอง" (background handler
    // ยิง local notification) — FCM ไม่มี initial message ให้ ต้องอ่านจาก launch
    // details ของ plugin ไม่งั้นแตะแล้วแอปเปิดเฉย ๆ ไม่พาไปหน้ารายงาน
    if (_pendingRoute == null) {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final parsed = _parseNotificationPayload(
          launchDetails?.notificationResponse?.payload,
        );
        if (parsed != null) {
          _pendingRoute = parsed.$1;
          _pendingTaskId = parsed.$2;
          print('[FCM] เปิดแอปจากการแตะแจ้งเตือน: ${parsed.$1}');
        }
      }
    }

    _initialized = true;
    return true;
  }

  void handlePendingInitialMessage() {
    final route = _pendingRoute;
    if (route == null) return;
    final taskId = _pendingTaskId;
    _pendingRoute = null;
    _pendingTaskId = null;
    _openFromPush(route, taskId);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('[FCM] Foreground message: ${message.messageId}');
    if (message.notification == null) return;
    print('[FCM] Title: ${message.notification!.title}');
    print('[FCM] Body: ${message.notification!.body}');
    if (!await notificationsAllowed()) return;
    await _showLocalNotification(
      id: message.messageId.hashCode,
      title: message.notification!.title ?? 'RAMPART',
      body: message.notification!.body ?? '',
      payload: _encodePayload(message),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    final taskId = message.data['task_id'] ?? message.data['taskId'];
    _openFromPush(
      route is String ? route : null,
      taskId is String ? taskId : null,
    );
  }

  /// ต้องเช็คสวิตช์ก่อน ไม่งั้นการเปิดแอปใหม่จะลงทะเบียนอุปกรณ์กลับเข้าไปทุกครั้ง
  /// แล้วลบล้างการที่ผู้ใช้ปิดแจ้งเตือนไว้
  Future<void> _registerCurrentToken() async {
    if (!await notificationsAllowed()) return;
    final token = deviceToken.value;
    if (token == null) return;
    try {
      await authService.registerFcmToken(token);
    } catch (e) {
      print('[FCM] Token registration error: $e');
    }
  }
}
