import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/core/services/storage_service.dart';
import 'package:trucker_motor/features/notifications/notification_navigation_service.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _requestPermission();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_notifications',
        'Task Notifications',
        description: 'Notifications for task reminders and updates',
        importance: Importance.high,
      ),
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleTerminatedMessage(initialMessage);
    }

    await _saveFcmToken();
    _fcm.onTokenRefresh.listen(_onTokenRefresh);
  }

  static Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }

    final settings = await _fcm.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }
  }

  static Future<void> _saveFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Device token: $token');
      }
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

  /// Handle token refresh.
  static void _onTokenRefresh(String token) {
    debugPrint('[FCM] Token refreshed: $token');
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_notifications',
          'Task Notifications',
          channelDescription: 'Notifications for task reminders and updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'local_notification',
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'force_logout') {
      _handleForceLogout();
      return;
    }

    if (type == 'sync_complete') {
      if (Get.context != null) {
        Get.snackbar(
          'Tasks Synced',
          'Your tasks have been synced successfully',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Task Manager',
      body: message.notification?.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_notifications',
          'Task Notifications',
          channelDescription: 'Notifications for task reminders and updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '${data['type'] ?? ''}|${data['taskId'] ?? ''}',
    );
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final taskId = data['taskId'] ?? '';

    NotificationNavigationService.handleNotificationTap(
      type: type,
      taskId: taskId,
    );
  }

  static void _handleTerminatedMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    final taskId = data['taskId'] ?? '';

    NotificationNavigationService.queueNavigationIntent(
      type: type,
      taskId: taskId,
    );
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    final parts = payload.split('|');
    final type = parts.isNotEmpty ? parts[0] : '';
    final taskId = parts.length > 1 ? parts[1] : '';

    NotificationNavigationService.handleNotificationTap(
      type: type,
      taskId: taskId,
    );
  }

  static Future<void> _handleForceLogout() async {
    final storageService = StorageService();
    await storageService.clearAll();
    Get.offAllNamed('/login');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'] ?? '';

  if (type == 'force_logout') {
    final storageService = StorageService();
    await storageService.clearAll();
  }
}
