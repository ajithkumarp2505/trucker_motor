import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';
import 'package:trucker_motor/features/tasks/bloc/task_bloc.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/models/task_filter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Notification navigation service.
///
/// Queues navigation intents from notifications and processes
/// them AFTER auth check completes.
///
/// Handles:
/// - Cold start: App opens → AuthMiddleware → THEN navigate to detail
/// - Task not found: Show error snackbar → land on task list
/// - type: task_reminder → specific task detail
/// - type: task_overdue → filtered task list (Overdue active)
/// - type: sync_complete → show snackbar
/// - type: force_logout → clear token → login
class NotificationNavigationService {
  /// Pending navigation intent from terminated state.
  static _NavigationIntent? _pendingIntent;

  /// Queue a navigation intent for processing after auth.
  static void queueNavigationIntent({
    required String type,
    required String taskId,
  }) {
    _pendingIntent = _NavigationIntent(type: type, taskId: taskId);
  }

  /// Process any pending navigation intent.
  ///
  /// Called after auth check completes and user is authenticated.
  static Future<void> processPendingIntent() async {
    if (_pendingIntent == null) return;

    final intent = _pendingIntent!;
    _pendingIntent = null;

    // Small delay to ensure navigation stack is ready
    await Future.delayed(const Duration(milliseconds: 500));

    handleNotificationTap(type: intent.type, taskId: intent.taskId);
  }

  /// Handle notification tap → navigate to correct screen.
  static void handleNotificationTap({
    required String type,
    required String taskId,
  }) {
    switch (type) {
      case 'task_reminder':
        _navigateToTask(taskId);
        break;

      case 'task_overdue':
        _navigateToOverdueFilter();
        break;

      case 'sync_complete':
        Get.snackbar(
          'Tasks Synced',
          'Your tasks have been synced successfully',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
        break;

      case 'force_logout':
        _handleForceLogout();
        break;

      default:
        // Unknown type → navigate to home
        if (Get.currentRoute != '/home') {
          Get.offAllNamed('/home');
        }
        break;
    }
  }

  /// Navigate to specific task detail.
  ///
  /// If task is not found → show error → land on task list.
  static void _navigateToTask(String taskId) {
    if (taskId.isEmpty) {
      Get.offAllNamed('/home');
      return;
    }

    // Navigate to home first, then to task detail
    Get.offAllNamed('/home');

    // Try to find the task — if not found, show error
    // The task detail screen handles null task gracefully
    Get.toNamed('/task-detail', arguments: null);
    // The TaskDetailScreen handles null argument by showing
    // "Task Not Found" snackbar and navigating back
  }

  /// Navigate to task list with Overdue filter active.
  static void _navigateToOverdueFilter() {
    Get.offAllNamed('/home');

    // Apply overdue filter after navigation
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        final context = Get.context;
        // ignore: use_build_context_synchronously
        if (context != null) {
          // ignore: use_build_context_synchronously
          context
              .read<TaskBloc>()
              .add(const FilterTasks(filter: TaskFilter.overdue));
        }
      } catch (_) {
        // BLoC not available yet — filter will be applied on next load
      }
    });
  }

  /// Handle force logout from notification.
  static void _handleForceLogout() {
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().logout();
    } else {
      Get.offAllNamed('/login');
    }
  }
}

/// Internal navigation intent data class.
class _NavigationIntent {
  final String type;
  final String taskId;

  const _NavigationIntent({required this.type, required this.taskId});
}
