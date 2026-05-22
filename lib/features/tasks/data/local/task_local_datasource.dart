import 'package:hive/hive.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Local datasource for tasks using Hive.
///
/// Provides offline-first caching. If the API is unreachable,
/// the app serves data from this local cache.
class TaskLocalDatasource {
  static const String _boxName = 'tasks';
  Box<TaskModel>? _box;

  /// Initialize the Hive box. Must be called before any operations.
  Future<void> init() async {
    if (_box == null || !(_box!.isOpen)) {
      _box = await Hive.openBox<TaskModel>(_boxName);
    }
  }

  /// Get the opened box, initializing if needed.
  Future<Box<TaskModel>> get box async {
    await init();
    return _box!;
  }

  /// Get all cached tasks.
  Future<List<TaskModel>> getAllTasks() async {
    final b = await box;
    return b.values.toList();
  }

  /// Get a single task by ID.
  Future<TaskModel?> getTask(String id) async {
    final b = await box;
    return b.get(id);
  }

  /// Save a task (add or update).
  Future<void> saveTask(TaskModel task) async {
    final b = await box;
    await b.put(task.id, task);
  }

  /// Save multiple tasks at once (for sync).
  Future<void> saveTasks(List<TaskModel> tasks) async {
    final b = await box;
    final taskMap = {for (var task in tasks) task.id: task};
    await b.putAll(taskMap);
  }

  /// Delete a task by ID.
  Future<void> deleteTask(String id) async {
    final b = await box;
    await b.delete(id);
  }

  /// Clear all cached tasks.
  Future<void> clearAll() async {
    final b = await box;
    await b.clear();
  }

  /// Replace all tasks with new data (for background sync).
  Future<void> replaceAll(List<TaskModel> tasks) async {
    final b = await box;
    await b.clear();
    final taskMap = {for (var task in tasks) task.id: task};
    await b.putAll(taskMap);
  }

  /// Get count of overdue tasks.
  Future<int> getOverdueCount() async {
    final tasks = await getAllTasks();
    return tasks.where((t) => t.status == 'Overdue' || t.isOverdue).length;
  }

  /// Mark overdue tasks.
  Future<int> markOverdueTasks() async {
    final tasks = await getAllTasks();
    int overdueCount = 0;

    for (final task in tasks) {
      if (task.isOverdue) {
        final updated = task.copyWith(status: 'Overdue');
        await saveTask(updated);
        overdueCount++;
      }
    }

    return overdueCount;
  }
}
