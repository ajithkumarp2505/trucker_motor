import 'dart:math';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:trucker_motor/core/constants/api_constants.dart';
import 'package:trucker_motor/core/error/failures.dart';
import 'package:trucker_motor/features/tasks/data/local/task_local_datasource.dart';
import 'package:trucker_motor/features/tasks/data/repositories/task_repository.dart';
import 'package:trucker_motor/features/tasks/models/task_model.dart';
import 'package:uuid/uuid.dart';

class TaskRepositoryImpl implements TaskRepository {
  final Dio _dio;
  final TaskLocalDatasource _localDatasource;
  final Uuid _uuid = const Uuid();

  TaskRepositoryImpl({
    required Dio dio,
    required TaskLocalDatasource localDatasource,
  }) : _dio = dio,
       _localDatasource = localDatasource;

  @override
  Future<Either<Failure, List<TaskModel>>> getTasks() async {
    try {
      final response = await _retryRequest(
        () => _dio.get(
          '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}',
          queryParameters: {'_limit': 20}, // Limit for demo
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        final remoteTasks = jsonList
            .map((json) => TaskModel.fromApiJson(json as Map<String, dynamic>))
            .toList();

        // Cache locally (merges new remote tasks)
        await _localDatasource.saveTasks(remoteTasks);

        // Return all tasks (including locally created ones)
        final allTasks = await _localDatasource.getAllTasks();
        return Right(allTasks);
      }

      return Left(
        ServerFailure('Failed to load tasks', statusCode: response.statusCode),
      );
    } on DioException catch (e) {
      // Offline → return cached data
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return _getCachedTasks();
      }

      if (e.response?.statusCode == 401) {
        return const Left(UnauthorizedFailure());
      }

      return Left(
        ServerFailure(
          e.response?.statusMessage ?? 'Server error',
          statusCode: e.response?.statusCode,
        ),
      );
    } catch (e) {
      // Try cache on any error
      return _getCachedTasks();
    }
  }

  @override
  Future<Either<Failure, TaskModel>> getTaskById(String id) async {
    try {
      // Try local first
      final localTask = await _localDatasource.getTask(id);
      if (localTask != null) {
        return Right(localTask);
      }

      // Try remote
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}/$id',
      );

      if (response.statusCode == 200) {
        final task = TaskModel.fromApiJson(
          response.data as Map<String, dynamic>,
        );
        await _localDatasource.saveTask(task);
        return Right(task);
      }

      return const Left(ServerFailure('Task not found'));
    } catch (e) {
      // Try local cache
      final localTask = await _localDatasource.getTask(id);
      if (localTask != null) {
        return Right(localTask);
      }
      return Left(UnknownFailure('Failed to get task: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TaskModel>> createTask(TaskModel task) async {
    try {
      final newTask = task.copyWith(id: _uuid.v4(), createdAt: DateTime.now());

      // POST to API (jsonplaceholder returns the created item)
      final response = await _retryRequest(
        () => _dio.post(
          '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}',
          data: newTask.toApiJson(),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Save locally with our full model
        await _localDatasource.saveTask(newTask);
        return Right(newTask);
      }

      // Even if API fails, save locally
      await _localDatasource.saveTask(newTask);
      return Right(newTask);
    } on DioException catch (_) {
      // Save locally even if offline
      final newTask = task.copyWith(id: _uuid.v4(), createdAt: DateTime.now());
      await _localDatasource.saveTask(newTask);
      return Right(newTask);
    } catch (e) {
      return Left(UnknownFailure('Failed to create task: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TaskModel>> updateTask(TaskModel task) async {
    try {
      // PUT to API
      if (task.remoteId != null) {
        await _retryRequest(
          () => _dio.put(
            '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}/${task.remoteId}',
            data: task.toApiJson(),
          ),
        );
      }

      // Update locally
      await _localDatasource.saveTask(task);
      return Right(task);
    } on DioException catch (_) {
      // Update locally even if offline
      await _localDatasource.saveTask(task);
      return Right(task);
    } catch (e) {
      return Left(UnknownFailure('Failed to update task: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTask(String taskId) async {
    try {
      // Get task to check for remote ID
      final task = await _localDatasource.getTask(taskId);

      if (task?.remoteId != null) {
        await _retryRequest(
          () => _dio.delete(
            '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}/${task!.remoteId}',
          ),
        );
      }

      await _localDatasource.deleteTask(taskId);
      return const Right(null);
    } on DioException catch (_) {
      // Delete locally even if offline
      await _localDatasource.deleteTask(taskId);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to delete task: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<TaskModel>>> syncTasks() async {
    try {
      final response = await _retryRequest(
        () => _dio.get(
          '${ApiConstants.baseUrl}${ApiConstants.todosEndpoint}',
          queryParameters: {'_limit': 20},
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        final tasks = jsonList
            .map((json) => TaskModel.fromApiJson(json as Map<String, dynamic>))
            .toList();

        // Merge and save fresh data without wiping local tasks
        await _localDatasource.saveTasks(tasks);

        // Mark overdue tasks
        await _localDatasource.markOverdueTasks();

        // Get updated list
        final updatedTasks = await _localDatasource.getAllTasks();
        return Right(updatedTasks);
      }

      return const Left(ServerFailure('Sync failed'));
    } catch (e) {
      return Left(UnknownFailure('Sync failed: ${e.toString()}'));
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────

  /// Get tasks from local cache.
  Future<Either<Failure, List<TaskModel>>> _getCachedTasks() async {
    try {
      final cachedTasks = await _localDatasource.getAllTasks();
      if (cachedTasks.isNotEmpty) {
        return Right(cachedTasks);
      }
      return const Left(
        NetworkFailure('No internet and no cached data available.'),
      );
    } catch (e) {
      return const Left(CacheFailure());
    }
  }

  /// Retry request with exponential backoff.
  ///
  /// On NetworkFailure, retries up to [ApiConstants.maxRetries] times
  /// with 2-second exponential backoff (2s, 4s).
  Future<Response> _retryRequest(Future<Response> Function() requestFn) async {
    int attempt = 0;
    while (true) {
      try {
        return await requestFn();
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          attempt++;
          if (attempt > ApiConstants.maxRetries) {
            rethrow;
          }
          // Exponential backoff: 2s, 4s
          final delay = ApiConstants.retryBaseDelay * pow(2, attempt - 1);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }
}
