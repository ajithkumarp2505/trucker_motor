import 'package:equatable/equatable.dart';
import 'package:trucker_motor/features/tasks/models/task_filter.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Task BLoC states.
///
/// The widget tree ONLY renders based on these states.
/// Filtering, sorting, and searching are all computed
/// inside the BLoC — never in the widget.
abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded.
class TaskInitial extends TaskState {}

/// Loading state (API call in progress).
class TaskLoading extends TaskState {}

/// Successfully loaded task data.
///
/// Contains both the full task list and the computed filtered list.
/// [lastDeleted] holds the task being "soft deleted" during the
/// 5-second undo window.
class TaskLoaded extends TaskState {
  final List<TaskModel> allTasks;
  final List<TaskModel> filteredTasks;
  final TaskFilter activeFilter;
  final TaskSort activeSort;
  final String searchQuery;
  final TaskModel? lastDeleted;
  final bool isFromCache;

  const TaskLoaded({
    required this.allTasks,
    required this.filteredTasks,
    this.activeFilter = TaskFilter.all,
    this.activeSort = TaskSort.dueDate,
    this.searchQuery = '',
    this.lastDeleted,
    this.isFromCache = false,
  });

  /// Create a copy with updated fields.
  /// Re-computes filteredTasks based on active filter/sort/search.
  TaskLoaded copyWith({
    List<TaskModel>? allTasks,
    List<TaskModel>? filteredTasks,
    TaskFilter? activeFilter,
    TaskSort? activeSort,
    String? searchQuery,
    TaskModel? lastDeleted,
    bool clearLastDeleted = false,
    bool? isFromCache,
  }) {
    return TaskLoaded(
      allTasks: allTasks ?? this.allTasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      activeFilter: activeFilter ?? this.activeFilter,
      activeSort: activeSort ?? this.activeSort,
      searchQuery: searchQuery ?? this.searchQuery,
      lastDeleted: clearLastDeleted ? null : (lastDeleted ?? this.lastDeleted),
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  List<Object?> get props => [
        allTasks,
        filteredTasks,
        activeFilter,
        activeSort,
        searchQuery,
        lastDeleted,
        isFromCache,
      ];
}

/// Error state with message.
class TaskError extends TaskState {
  final String message;
  final List<TaskModel>? cachedTasks; // Show cached data on error

  const TaskError({
    required this.message,
    this.cachedTasks,
  });

  @override
  List<Object?> get props => [message, cachedTasks];
}
