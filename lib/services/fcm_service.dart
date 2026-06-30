import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'RAMPART';
  final body = message.notification?.body ?? '';
  print('[FCM] Background: $title — $body');
  await _ensureNotificationsInit();
  await _showLocalNotification(
    id: message.messageId.hashCode,
    title: title,
    body: body,
    payload: message.data['route'],
  );
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
bool _notificationsInited = false;

Future<void> _ensureNotificationsInit() async {
  if (_notificationsInited) return;
  _notificationsInited = true;

  const androidSettings = AndroidInitializationSettings('ic_launcher');
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
  final route = response.payload;
  if (route != null && route.isNotEmpty) {
    Get.toNamed(route);
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;

  String? _deviceToken;
  String? get deviceToken => _deviceToken;

  String? _pendingRoute;

  FcmService._internal();

  Future<void> initialize() async {
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
      _deviceToken = await FirebaseMessaging.instance.getToken();
      print('[FCM] Device token: $_deviceToken');

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _deviceToken = newToken;
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
      _pendingRoute = initialMessage.data['route'];
    }
  }

  void handlePendingInitialMessage() {
    if (_pendingRoute != null) {
      Get.toNamed(_pendingRoute!);
      _pendingRoute = null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('[FCM] Foreground message: ${message.messageId}');
    if (message.notification != null) {
      print('[FCM] Title: ${message.notification!.title}');
      print('[FCM] Body: ${message.notification!.body}');
      _showLocalNotification(
        id: message.messageId.hashCode,
        title: message.notification!.title ?? 'RAMPART',
        body: message.notification!.body ?? '',
        payload: message.data['route'],
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('[FCM] Notification tapped: ${message.messageId}');
    String? route = message.data['route'];
    if (route != null && route.isNotEmpty) {
      Get.toNamed(route);
    }
  }

  Future<void> _registerCurrentToken() async {
    if (_deviceToken == null) return;
    try {
      await authService.registerFcmToken(_deviceToken!);
    } catch (e) {
      print('[FCM] Token registration error: $e');
    }
  }
}
