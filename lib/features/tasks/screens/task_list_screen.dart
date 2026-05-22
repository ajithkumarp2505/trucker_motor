import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' hide Transition;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:trucker_motor/core/theme/app_theme.dart';
import 'package:trucker_motor/features/auth/controllers/auth_controller.dart';
import 'package:trucker_motor/features/tasks/bloc/task_bloc.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/bloc/task_state.dart';
import 'package:trucker_motor/features/tasks/models/task_filter.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Task list screen — the main app screen.
///
/// Renders entirely from BLoC states:
/// - Calls BLoC events for filter/sort/search
/// - Never computes filtered lists in the widget
/// - Shows undo SnackBar on delete with 5-second window
class TaskListScreen extends StatelessWidget {
  TaskListScreen({super.key});

  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildFilterChips(context),
          _buildSortRow(context),
          Expanded(child: _buildTaskList(context)),
        ],
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      title: const Text('My Tasks'),
      actions: [
        // Sync indicator
        BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoaded && state.isFromCache) {
              return Tooltip(
                message: 'Showing cached data',
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: AppTheme.warningColor),
                      SizedBox(width: 4),
                      Text('Offline', style: TextStyle(fontSize: 11, color: AppTheme.warningColor)),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () =>
              context.read<TaskBloc>().add(RefreshTasks()),
          tooltip: 'Refresh',
        ),
        // Logout button
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          color: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              Get.find<AuthController>().logout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded,
                      size: 20, color: AppTheme.errorColor),
                  const SizedBox(width: 12),
                  Text('Logout',
                      style: TextStyle(color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (query) {
          context.read<TaskBloc>().add(SearchTasks(query: query));
        },
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
          suffixIcon: BlocBuilder<TaskBloc, TaskState>(
            builder: (context, state) {
              if (state is TaskLoaded && state.searchQuery.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    context.read<TaskBloc>().add(const SearchTasks(query: ''));
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        final activeFilter =
            state is TaskLoaded ? state.activeFilter : TaskFilter.all;

        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: TaskFilter.values.map((filter) {
              final isActive = filter == activeFilter;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(filter.label),
                  selected: isActive,
                  onSelected: (_) {
                    context.read<TaskBloc>().add(FilterTasks(filter: filter));
                  },
                  backgroundColor: AppTheme.surfaceColor,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isActive
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : AppTheme.dividerColor,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSortRow(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        final activeSort =
            state is TaskLoaded ? state.activeSort : TaskSort.dueDate;
        final taskCount =
            state is TaskLoaded ? state.filteredTasks.length : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$taskCount task${taskCount != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TaskSort>(
                    value: activeSort,
                    isDense: true,
                    dropdownColor: AppTheme.surfaceColor,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    icon: const Icon(Icons.sort_rounded,
                        size: 16, color: AppTheme.textMuted),
                    items: TaskSort.values.map((sort) {
                      return DropdownMenuItem(
                        value: sort,
                        child: Text('Sort: ${sort.label}'),
                      );
                    }).toList(),
                    onChanged: (sort) {
                      if (sort != null) {
                        context.read<TaskBloc>().add(SortTasks(sort: sort));
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(BuildContext context) {
    return BlocConsumer<TaskBloc, TaskState>(
      listener: (context, state) {
        // Show undo SnackBar when a task is deleted
        if (state is TaskLoaded && state.lastDeleted != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Task "${state.lastDeleted!.title}" deleted',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              backgroundColor: AppTheme.surfaceColor,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppTheme.primaryColor,
                onPressed: () {
                  context.read<TaskBloc>().add(UndoDeleteTask());
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }

        if (state is TaskError) {
          return _buildErrorState(context, state);
        }

        if (state is TaskLoaded) {
          if (state.filteredTasks.isEmpty) {
            return _buildEmptyState(context, state);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TaskBloc>().add(RefreshTasks());
              // Wait for state change
              await context.read<TaskBloc>().stream.firstWhere(
                    (s) => s is TaskLoaded || s is TaskError,
                  );
            },
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: state.filteredTasks.length,
              itemBuilder: (context, index) {
                final task = state.filteredTasks[index];
                return _TaskCard(
                  task: task,
                  onTap: () => Get.toNamed('/task-detail', arguments: task),
                  onDelete: () {
                    context
                        .read<TaskBloc>()
                        .add(DeleteTask(taskId: task.id));
                  },
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorState(BuildContext context, TaskError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<TaskBloc>().add(LoadTasks()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TaskLoaded state) {
    final isFiltered = state.activeFilter != TaskFilter.all ||
        state.searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.filter_list_off_rounded : Icons.inbox_rounded,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No tasks match your filter' : 'No tasks yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try adjusting your filter or search query'
                  : 'Tap + to create your first task',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Get.toNamed('/add-task'),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add Task'),
      elevation: 4,
    );
  }
}

/// Individual task card widget.
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppTheme.getPriorityColor(task.priority);
    final statusColor = AppTheme.getStatusColor(task.status);
    final dateStr = DateFormat('MMM d, y').format(task.dueDate);
    final isOverdue = task.isOverdue || task.status == 'Overdue';

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.errorColor,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? AppTheme.errorColor.withValues(alpha: 0.3)
                  : AppTheme.dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + priority
              Row(
                children: [
                  // Priority indicator
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.status == 'Done'
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.status == 'Done'
                                    ? AppTheme.textMuted
                                    : AppTheme.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textMuted,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppTheme.textMuted),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row: due date, status, priority badges
              Row(
                children: [
                  // Due date
                  _buildChip(
                    icon: Icons.calendar_today_rounded,
                    label: dateStr,
                    color: isOverdue ? AppTheme.errorColor : AppTheme.textMuted,
                    bgColor: isOverdue
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : AppTheme.cardColor,
                  ),
                  const SizedBox(width: 8),
                  // Status
                  _buildChip(
                    icon: AppTheme.getStatusIcon(task.status),
                    label: task.status,
                    color: statusColor,
                    bgColor: statusColor.withValues(alpha: 0.1),
                  ),
                  const Spacer(),
                  // Priority
                  _buildChip(
                    icon: AppTheme.getPriorityIcon(task.priority),
                    label: task.priority,
                    color: priorityColor,
                    bgColor: priorityColor.withValues(alpha: 0.1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
