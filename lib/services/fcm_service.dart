import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';
import 'package:rampart/services/notification_service.dart';

const String _notifEnabledKey = 'notif_enabled';

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

const Set<String> _pushRoutes = {
  '/home',
  '/analysis-progress',
  '/analysis-result',
  '/help',
};

const Set<String> _pushTaskRoutes = {'/analysis-progress', '/analysis-result'};

String _encodePayload(RemoteMessage message) {
  final route = message.data['route'];
  if (route is! String || route.isEmpty) return '';
  final taskId = message.data['task_id'] ?? message.data['taskId'];
  if (taskId is String && taskId.isNotEmpty && _pushTaskRoutes.contains(route)) {
    return jsonEncode({'route': route, 'task_id': taskId});
  }
  return route;
}

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
  bool incrementCount = false,
}) async {
  if (incrementCount && Get.isRegistered<NotificationService>()) {
    Get.find<NotificationService>().inc();
  }
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

  final deviceToken = RxnString();

  String? _pendingRoute;
  String? _pendingTaskId;
  bool _initialized = false;

  FcmService._internal();

  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('[FCM] Firebase init ไม่สำเร็จ: $e');
      // Fallback: แสดง notification ท้องถิมเมื่อ FCM ล้มเหลื่อน
      await _ensureNotificationsInit();
      await _showLocalNotification(
        id: 0,
        title: 'ระบบแจ้งเตือนยังไม่พร้อมใช้งาน',
        body:
            'ไม่สามารถเชื่อมต่อบริการแจ้งเตือนของ RAMPART ได้ '
            'กรุณาตรวจสอบอินเทอร์เน็ตแล้วเปิดแอปใหม่',
        incrementCount: true,
      );
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
      incrementCount: true,
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
