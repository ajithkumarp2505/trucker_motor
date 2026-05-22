import 'package:equatable/equatable.dart';
import 'package:trucker_motor/features/tasks/models/task_filter.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Task BLoC events.
///
/// Every user action that affects tasks is modeled as an event.
/// The BLoC processes these events and emits new states.
abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

/// Load tasks from the repository.
class LoadTasks extends TaskEvent {}

/// Add a new task.
class AddTask extends TaskEvent {
  final TaskModel task;
  const AddTask({required this.task});

  @override
  List<Object?> get props => [task];
}

/// Update an existing task.
class UpdateTask extends TaskEvent {
  final TaskModel task;
  const UpdateTask({required this.task});

  @override
  List<Object?> get props => [task];
}

/// Delete a task (soft delete — starts undo timer).
class DeleteTask extends TaskEvent {
  final String taskId;
  const DeleteTask({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

/// Undo the last delete within the 5-second window.
class UndoDeleteTask extends TaskEvent {}

/// Confirm delete after undo timer expires.
class ConfirmDelete extends TaskEvent {
  final String taskId;
  const ConfirmDelete({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

/// Apply a filter to the task list.
class FilterTasks extends TaskEvent {
  final TaskFilter filter;
  const FilterTasks({required this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Sort tasks by a given criterion.
class SortTasks extends TaskEvent {
  final TaskSort sort;
  const SortTasks({required this.sort});

  @override
  List<Object?> get props => [sort];
}

/// Search tasks by title (debounced in the BLoC).
class SearchTasks extends TaskEvent {
  final String query;
  const SearchTasks({required this.query});

  @override
  List<Object?> get props => [query];
}

/// Refresh tasks from the API.
class RefreshTasks extends TaskEvent {}

/// Sync completed (from background service).
class SyncCompleted extends TaskEvent {
  final List<TaskModel> tasks;
  const SyncCompleted({required this.tasks});

  @override
  List<Object?> get props => [tasks];
}
