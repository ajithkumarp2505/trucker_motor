import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/tasks/bloc/task_bloc.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Task detail screen showing full task information.
///
/// Handles the notification deep link case: if the task
/// was deleted since the notification was sent, we show
/// an error snack bar and land on the task list.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get task from route arguments
    final task = Get.arguments as TaskModel?;

    if (task == null) {
      // Task not found → error + navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          'Task Not Found',
          'This task may have been deleted.',
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        Get.back();
      });
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final priorityColor = AppTheme.getPriorityColor(task.priority);
    final statusColor = AppTheme.getStatusColor(task.status);
    final isOverdue = task.isOverdue || task.status == 'Overdue';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Get.back(),
        ),
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Get.toNamed('/edit-task', arguments: task),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
            onPressed: () => _confirmDelete(context, task),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Status & Priority Header ────────────────────
            Row(
              children: [
                _buildStatusBadge(task.status, statusColor),
                const SizedBox(width: 12),
                _buildPriorityBadge(task.priority, priorityColor),
                if (isOverdue) ...[
                  const SizedBox(width: 12),
                  _buildOverdueBadge(),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // ─── Title ───────────────────────────────────────
            Text(
              task.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration:
                        task.status == 'Done' ? TextDecoration.lineThrough : null,
                  ),
            ),
            const SizedBox(height: 20),

            // ─── Description ─────────────────────────────────
            _buildInfoCard(
              context,
              icon: Icons.description_outlined,
              title: 'Description',
              child: Text(
                task.description.isNotEmpty
                    ? task.description
                    : 'No description provided',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: task.description.isNotEmpty
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Due Date ────────────────────────────────────
            _buildInfoCard(
              context,
              icon: Icons.calendar_today_rounded,
              title: 'Due Date',
              iconColor: isOverdue ? AppTheme.errorColor : AppTheme.accentColor,
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(task.dueDate),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(Overdue)',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Created Date ────────────────────────────────
            _buildInfoCard(
              context,
              icon: Icons.access_time_rounded,
              title: 'Created',
              child: Text(
                DateFormat('MMMM d, y \'at\' h:mm a').format(task.createdAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
            const SizedBox(height: 32),

            // ─── Quick Actions ───────────────────────────────
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context, task),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.getStatusIcon(status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.getPriorityIcon(priority), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$priority Priority',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.errorColor),
          SizedBox(width: 6),
          Text(
            'Overdue',
            style: TextStyle(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, TaskModel task) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (task.status != 'Done')
          _buildActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Mark Done',
            color: AppTheme.successColor,
            onTap: () {
              final updated = task.copyWith(status: 'Done');
              context.read<TaskBloc>().add(UpdateTask(task: updated));
              Get.back();
              Get.snackbar(
                'Task Completed',
                '${task.title} marked as done',
                backgroundColor: AppTheme.successColor.withValues(alpha: 0.9),
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            },
          ),
        if (task.status == 'Pending')
          _buildActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Start',
            color: AppTheme.accentColor,
            onTap: () {
              final updated = task.copyWith(status: 'In Progress');
              context.read<TaskBloc>().add(UpdateTask(task: updated));
              Get.back();
            },
          ),
        if (task.status == 'Done')
          _buildActionButton(
            icon: Icons.replay_rounded,
            label: 'Reopen',
            color: AppTheme.warningColor,
            onTap: () {
              final updated = task.copyWith(status: 'Pending');
              context.read<TaskBloc>().add(UpdateTask(task: updated));
              Get.back();
            },
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TaskBloc>().add(DeleteTask(taskId: task.id));
              Get.back();
            },
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
