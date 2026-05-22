import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:trucker_motor/core/constants/api_constants.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';


class BackgroundSyncService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const androidChannel = AndroidNotificationChannel(
      'task_sync_channel',
      'Task Sync Service',
      description: 'Background task synchronization',
      importance: Importance.low,
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'task_sync_channel',
        initialNotificationTitle: 'Task Manager',
        initialNotificationContent: 'Syncing tasks in background',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Stream<Map<String, dynamic>?> get onSyncComplete {
    final service = FlutterBackgroundService();
    return service.on('syncComplete');
  }
}


@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskModelAdapter());
  }

  final taskBox = await Hive.openBox<TaskModel>('tasks');
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
  ));

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  int previousOverdueCount = taskBox.values
      .where((t) => t.status == 'Overdue' || t.isOverdue)
      .length;

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('requestSync').listen((event) async {
    await _syncTasks(taskBox, dio, notifications, service, previousOverdueCount);
  });

  Timer.periodic(ApiConstants.syncInterval, (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        timer.cancel();
        return;
      }
    }

    previousOverdueCount = await _syncTasks(
      taskBox,
      dio,
      notifications,
      service,
      previousOverdueCount,
    );
  });

  previousOverdueCount = await _syncTasks(
    taskBox,
    dio,
    notifications,
    service,
    previousOverdueCount,
  );
}

Future<int> _syncTasks(
  Box<TaskModel> taskBox,
  Dio dio,
  FlutterLocalNotificationsPlugin notifications,
  ServiceInstance service,
  int previousOverdueCount,
) async {
  try {
    final response = await dio.get(
      '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}',
      queryParameters: {'_limit': 20},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data;
      final tasks = jsonList
          .map((json) => TaskModel.fromApiJson(json as Map<String, dynamic>))
          .toList();

      final taskMap = {for (var task in tasks) task.id: task};
      await taskBox.putAll(taskMap);

      int currentOverdueCount = 0;
      for (final task in taskBox.values) {
        if (task.isOverdue) {
          final updated = task.copyWith(status: 'Overdue');
          await taskBox.put(task.id, updated);
          currentOverdueCount++;
        } else if (task.status == 'Overdue') {
          currentOverdueCount++;
        }
      }

      if (currentOverdueCount > previousOverdueCount) {
        final newOverdue = currentOverdueCount - previousOverdueCount;
        await notifications.show(
          id: 1001,
          title: 'Overdue Tasks',
          body: '$newOverdue task${newOverdue > 1 ? 's' : ''} are now overdue!',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_overdue_channel',
              'Task Reminders',
              channelDescription: 'Notifications for overdue tasks',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }

      service.invoke('syncComplete', {
        'overdueCount': currentOverdueCount,
        'totalTasks': tasks.length,
        'lastSync': DateTime.now().toIso8601String(),
      });

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Task Manager',
          content:
              'Synced ${tasks.length} tasks • $currentOverdueCount overdue',
        );
      }

      return currentOverdueCount;
    }
  } catch (e) {
    debugPrint('[BackgroundSync] Sync failed: $e');
  }

  return previousOverdueCount;
}
