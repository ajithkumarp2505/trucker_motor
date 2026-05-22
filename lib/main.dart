import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:trucker_motor/core/network/api_client.dart';
import 'package:trucker_motor/core/services/background_service.dart';
import 'package:trucker_motor/core/services/notification_service.dart';
import 'package:trucker_motor/core/services/storage_service.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';
import 'package:trucker_motor/features/auth/repositories/auth_repository.dart';
import 'package:trucker_motor/features/auth/repositories/auth_repository_impl.dart';
import 'package:trucker_motor/features/notifications/notification_navigation_service.dart';
import 'package:trucker_motor/features/tasks/bloc/task_bloc.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/data/local/task_local_datasource.dart';
import 'package:trucker_motor/features/tasks/data/repositories/task_repository.dart';
import 'package:trucker_motor/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';
import 'package:trucker_motor/routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Hive.initFlutter();
  Hive.registerAdapter(TaskModelAdapter());

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[Main] Firebase initialization skipped: $e');
  }

  final storageService = StorageService();
  final apiClient = ApiClient(storageService: storageService);
  final taskLocalDatasource = TaskLocalDatasource();
  await taskLocalDatasource.init();

  final authRepository = AuthRepositoryImpl(
    dio: apiClient.dio,
    storageService: storageService,
  );

  final taskRepository = TaskRepositoryImpl(
    dio: apiClient.dio,
    localDatasource: taskLocalDatasource,
  );

  Get.put<StorageService>(storageService, permanent: true);
  Get.put<AuthRepository>(authRepository, permanent: true);
  Get.put<TaskRepository>(taskRepository, permanent: true);
  Get.put<AuthController>(
    AuthController(authRepository: authRepository),
    permanent: true,
  );

  try {
    await BackgroundSyncService.initialize();
  } catch (e) {
    debugPrint('[Main] Background service initialization skipped: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('[Main] Notification initialization skipped: $e');
  }

  runApp(TaskManagerApp(taskRepository: taskRepository));
}

class TaskManagerApp extends StatelessWidget {
  final TaskRepository taskRepository;

  const TaskManagerApp({super.key, required this.taskRepository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TaskBloc(taskRepository: taskRepository)..add(LoadTasks()),
      child: GetMaterialApp(
        title: 'Task Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.splash,
        getPages: AppRoutes.routes,
        defaultTransition: Transition.fadeIn,
        builder: (context, child) {
          _listenForBackgroundSync(context);
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }

  void _listenForBackgroundSync(BuildContext context) {
    BackgroundSyncService.onSyncComplete.listen((data) {
      if (data != null) {
        debugPrint(
          '[Sync] Complete: ${data['totalTasks']} tasks, ${data['overdueCount']} overdue',
        );

        NotificationNavigationService.processPendingIntent();
      }
    });
  }
}
