import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:trucker_motor/core/constants/api_constants.dart';
import 'package:trucker_motor/features/tasks/bloc/task_event.dart';
import 'package:trucker_motor/features/tasks/bloc/task_state.dart';
import 'package:trucker_motor/features/tasks/data/repositories/task_repository.dart';
import 'package:trucker_motor/features/tasks/models/task_filter.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';
import 'package:trucker_motor/core/services/notification_service.dart';

/// Task BLoC — the brain of the task management system.
///
/// All filtering, sorting, and searching happens here — NEVER in the widget.
///
/// Undo Delete Logic:
/// - On [DeleteTask]: remove from list, store in [lastDeleted], start 5s timer.
/// - On [UndoDeleteTask] within 5s: restore task, cancel timer.
/// - After 5s: call DELETE API, clear [lastDeleted].
///
/// Second Delete While Timer Running:
/// - If a second delete occurs while undo timer is active:
///   1. Permanently delete the first task (confirm the first delete).
///   2. Start a new undo window for the second task.
///   This ensures the user can always undo the MOST RECENT delete.
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _taskRepository;
  Timer? _undoTimer;

  TaskBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<RefreshTasks>(_onRefreshTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<UndoDeleteTask>(_onUndoDeleteTask);
    on<ConfirmDelete>(_onConfirmDelete);
    on<FilterTasks>(_onFilterTasks);
    on<SortTasks>(_onSortTasks);
    on<SyncCompleted>(_onSyncCompleted);

    // Debounce search events at 300ms using RxDart transformer
    on<SearchTasks>(
      _onSearchTasks,
      transformer: (events, mapper) => events
          .debounceTime(ApiConstants.searchDebounce)
          .asyncExpand(mapper),
    );
  }

  // ─── Event Handlers ─────────────────────────────────────────────

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());

    final result = await _taskRepository.getTasks();

    result.fold(
      (failure) => emit(TaskError(message: failure.message)),
      (tasks) {
        final sorted = _sortTasks(tasks, TaskSort.creationDate);
        emit(TaskLoaded(
          allTasks: sorted,
          filteredTasks: sorted,
          activeSort: TaskSort.creationDate,
        ));
      },
    );
  }

  Future<void> _onRefreshTasks(
      RefreshTasks event, Emitter<TaskState> emit) async {
    final currentState = state;
    final currentFilter =
        currentState is TaskLoaded ? currentState.activeFilter : TaskFilter.all;
    final currentSort =
        currentState is TaskLoaded ? currentState.activeSort : TaskSort.creationDate;
    final currentQuery =
        currentState is TaskLoaded ? currentState.searchQuery : '';

    final result = await _taskRepository.getTasks();

    result.fold(
      (failure) {
        if (currentState is TaskLoaded) {
          // Keep showing current data with error indication
          emit(currentState.copyWith(isFromCache: true));
        } else {
          emit(TaskError(message: failure.message));
        }
      },
      (tasks) {
        final filtered =
            _applyFiltersAndSort(tasks, currentFilter, currentSort, currentQuery);
        emit(TaskLoaded(
          allTasks: tasks,
          filteredTasks: filtered,
          activeFilter: currentFilter,
          activeSort: currentSort,
          searchQuery: currentQuery,
        ));
      },
    );
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    final result = await _taskRepository.createTask(event.task);

    result.fold(
      (failure) => emit(TaskError(
        message: failure.message,
        cachedTasks: currentState.allTasks,
      )),
      (newTask) {
        final updatedTasks = [...currentState.allTasks, newTask];
        final filtered = _applyFiltersAndSort(
          updatedTasks,
          currentState.activeFilter,
          currentState.activeSort,
          currentState.searchQuery,
        );

        // Show local notification for the new task
        try {
          NotificationService.showNotification(
            title: 'New Task Added',
            body: 'Task "${newTask.title}" has been added successfully.',
          );
        } catch (e) {
          // ignore notification error
        }

        emit(currentState.copyWith(
          allTasks: updatedTasks,
          filteredTasks: filtered,
        ));
      },
    );
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    final result = await _taskRepository.updateTask(event.task);

    result.fold(
      (failure) => emit(TaskError(
        message: failure.message,
        cachedTasks: currentState.allTasks,
      )),
      (updatedTask) {
        final updatedTasks = currentState.allTasks
            .map((t) => t.id == updatedTask.id ? updatedTask : t)
            .toList();
        final filtered = _applyFiltersAndSort(
          updatedTasks,
          currentState.activeFilter,
          currentState.activeSort,
          currentState.searchQuery,
        );
        emit(currentState.copyWith(
          allTasks: updatedTasks,
          filteredTasks: filtered,
        ));
      },
    );
  }

  /// Handle delete with undo logic.
  ///
  /// If a second delete fires while the first undo timer is running:
  /// 1. Permanently delete the first task (confirm it immediately).
  /// 2. Set up undo for the second task.
  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    // If there's a pending delete, confirm it first
    if (currentState.lastDeleted != null) {
      _undoTimer?.cancel();
      // Permanently delete the previous task
      await _taskRepository.deleteTask(currentState.lastDeleted!.id);
    }

    // Find the task being deleted
    final taskToDelete = currentState.allTasks.firstWhere(
      (t) => t.id == event.taskId,
      orElse: () => throw StateError('Task not found'),
    );

    // Remove from lists but keep reference in lastDeleted
    final updatedTasks =
        currentState.allTasks.where((t) => t.id != event.taskId).toList();
    final filtered = _applyFiltersAndSort(
      updatedTasks,
      currentState.activeFilter,
      currentState.activeSort,
      currentState.searchQuery,
    );

    emit(currentState.copyWith(
      allTasks: updatedTasks,
      filteredTasks: filtered,
      lastDeleted: taskToDelete,
    ));

    // Start 5-second countdown
    _undoTimer?.cancel();
    _undoTimer = Timer(
      ApiConstants.undoDeleteDuration,
      () => add(ConfirmDelete(taskId: event.taskId)),
    );
  }

  /// Undo the last delete.
  Future<void> _onUndoDeleteTask(
      UndoDeleteTask event, Emitter<TaskState> emit) async {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    if (currentState.lastDeleted == null) return;

    // Cancel the countdown
    _undoTimer?.cancel();

    // Restore the task
    final restoredTask = currentState.lastDeleted!;
    final updatedTasks = [...currentState.allTasks, restoredTask];
    final filtered = _applyFiltersAndSort(
      updatedTasks,
      currentState.activeFilter,
      currentState.activeSort,
      currentState.searchQuery,
    );

    emit(currentState.copyWith(
      allTasks: updatedTasks,
      filteredTasks: filtered,
      clearLastDeleted: true,
    ));
  }

  /// Confirm delete after undo timer expires.
  Future<void> _onConfirmDelete(
      ConfirmDelete event, Emitter<TaskState> emit) async {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    // Permanently delete from API and cache
    await _taskRepository.deleteTask(event.taskId);

    emit(currentState.copyWith(clearLastDeleted: true));
  }

  /// Apply filter — all computation in the BLoC, not the widget.
  void _onFilterTasks(FilterTasks event, Emitter<TaskState> emit) {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    final filtered = _applyFiltersAndSort(
      currentState.allTasks,
      event.filter,
      currentState.activeSort,
      currentState.searchQuery,
    );

    emit(currentState.copyWith(
      filteredTasks: filtered,
      activeFilter: event.filter,
    ));
  }

  /// Apply sort.
  void _onSortTasks(SortTasks event, Emitter<TaskState> emit) {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    final filtered = _applyFiltersAndSort(
      currentState.allTasks,
      currentState.activeFilter,
      event.sort,
      currentState.searchQuery,
    );

    emit(currentState.copyWith(
      filteredTasks: filtered,
      activeSort: event.sort,
    ));
  }

  /// Search with 300ms debounce (applied via RxDart transformer).
  void _onSearchTasks(SearchTasks event, Emitter<TaskState> emit) {
    if (state is! TaskLoaded) return;
    final currentState = state as TaskLoaded;

    final filtered = _applyFiltersAndSort(
      currentState.allTasks,
      currentState.activeFilter,
      currentState.activeSort,
      event.query,
    );

    emit(currentState.copyWith(
      filteredTasks: filtered,
      searchQuery: event.query,
    ));
  }

  /// Handle sync completion from background service.
  void _onSyncCompleted(SyncCompleted event, Emitter<TaskState> emit) {
    final currentState = state;
    final currentFilter =
        currentState is TaskLoaded ? currentState.activeFilter : TaskFilter.all;
    final currentSort =
        currentState is TaskLoaded ? currentState.activeSort : TaskSort.creationDate;
    final currentQuery =
        currentState is TaskLoaded ? currentState.searchQuery : '';

    final filtered = _applyFiltersAndSort(
      event.tasks,
      currentFilter,
      currentSort,
      currentQuery,
    );

    emit(TaskLoaded(
      allTasks: event.tasks,
      filteredTasks: filtered,
      activeFilter: currentFilter,
      activeSort: currentSort,
      searchQuery: currentQuery,
    ));
  }

  // ─── Private Computation Methods ───────────────────────────────

  /// Apply filter, search, and sort to the task list.
  ///
  /// All filtering logic lives here in the BLoC — the widget
  /// only calls events and renders states.
  List<TaskModel> _applyFiltersAndSort(
    List<TaskModel> tasks,
    TaskFilter filter,
    TaskSort sort,
    String searchQuery,
  ) {
    var result = List<TaskModel>.from(tasks);

    // 1. Apply search
    if (searchQuery.isNotEmpty) {
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    // 2. Apply filter
    result = _filterTasks(result, filter);

    // 3. Apply sort
    result = _sortTasks(result, sort);

    return result;
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks, TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.today:
        return tasks.where((t) => t.isDueToday).toList();
      case TaskFilter.thisWeek:
        return tasks.where((t) => t.isDueThisWeek).toList();
      case TaskFilter.overdue:
        return tasks
            .where((t) => t.isOverdue || t.status == 'Overdue')
            .toList();
      case TaskFilter.pending:
        return tasks.where((t) => t.status == 'Pending').toList();
      case TaskFilter.inProgress:
        return tasks.where((t) => t.status == 'In Progress').toList();
      case TaskFilter.done:
        return tasks.where((t) => t.status == 'Done').toList();
      case TaskFilter.highPriority:
        return tasks.where((t) => t.priority == 'High').toList();
      case TaskFilter.mediumPriority:
        return tasks.where((t) => t.priority == 'Medium').toList();
      case TaskFilter.lowPriority:
        return tasks.where((t) => t.priority == 'Low').toList();
    }
  }

  List<TaskModel> _sortTasks(List<TaskModel> tasks, TaskSort sort) {
    final sorted = List<TaskModel>.from(tasks);
    switch (sort) {
      case TaskSort.dueDate:
        sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSort.priority:
        sorted.sort((a, b) {
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          return (order[a.priority] ?? 2).compareTo(order[b.priority] ?? 2);
        });
        break;
      case TaskSort.creationDate:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  // ─── Cleanup ───────────────────────────────────────────────────

  @override
  Future<void> close() {
    _undoTimer?.cancel();
    return super.close();
  }
}
