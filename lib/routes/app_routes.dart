import 'package:get/get.dart';
import 'package:trucker_motor/features/auth/middlewares/auth_middleware.dart';
import 'package:trucker_motor/features/auth/screens/login_screen.dart';
import 'package:trucker_motor/features/auth/screens/register_screen.dart';
import 'package:trucker_motor/features/auth/screens/splash_screen.dart';
import 'package:trucker_motor/features/tasks/screens/add_edit_task_screen.dart';
import 'package:trucker_motor/features/tasks/screens/task_detail_screen.dart';
import 'package:trucker_motor/features/tasks/screens/task_list_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String taskDetail = '/task-detail';
  static const String addTask = '/add-task';
  static const String editTask = '/edit-task';

  static List<GetPage> get routes => [
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: login,
      page: () => LoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: register,
      page: () => RegisterScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    // ─── Protected Routes ────────────────────────────────
    GetPage(
      name: home,
      page: () => TaskListScreen(),
      middlewares: [AuthMiddleware()],
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: taskDetail,
      page: () => const TaskDetailScreen(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: addTask,
      page: () => const AddEditTaskScreen(),
      middlewares: [AuthMiddleware()],
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: editTask,
      page: () => const AddEditTaskScreen(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
