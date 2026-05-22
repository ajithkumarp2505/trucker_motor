import 'package:dartz/dartz.dart';
import 'package:trucker_motor/core/error/failures.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';

/// Abstract task repository — defines the contract.
///
/// Both the BLoC and the background service depend on this
/// interface, never on the concrete implementation.
abstract class TaskRepository {
  /// Get all tasks (from API, with local cache fallback).
  Future<Either<Failure, List<TaskModel>>> getTasks();

  /// Get a single task by ID.
  Future<Either<Failure, TaskModel>> getTaskById(String id);

  /// Create a new task.
  Future<Either<Failure, TaskModel>> createTask(TaskModel task);

  /// Update an existing task.
  Future<Either<Failure, TaskModel>> updateTask(TaskModel task);

  /// Delete a task by ID.
  Future<Either<Failure, void>> deleteTask(String taskId);

  /// Sync tasks from API to local cache (for background service).
  Future<Either<Failure, List<TaskModel>>> syncTasks();
}
