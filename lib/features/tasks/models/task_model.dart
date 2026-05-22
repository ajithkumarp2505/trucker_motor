import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'task_model.g.dart';

/// Task model for the task management system.
///
/// Adapts jsonplaceholder /todos response into a full-featured
/// task model with priority, status, due date, and description.
@HiveType(typeId: 0)
class TaskModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime dueDate;

  @HiveField(4)
  final String priority; // Low, Medium, High

  @HiveField(5)
  final String status; // Pending, In Progress, Done, Overdue

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final int? remoteId; // ID from jsonplaceholder API

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.priority = 'Medium',
    this.status = 'Pending',
    required this.createdAt,
    this.remoteId,
  });

  /// Create from jsonplaceholder /todos response.
  ///
  /// Maps the simple {userId, id, title, completed} to our richer model.
  factory TaskModel.fromApiJson(Map<String, dynamic> json) {
    final completed = json['completed'] as bool? ?? false;
    return TaskModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Untitled Task',
      description: 'Task from API (User ${json['userId'] ?? 'unknown'})',
      dueDate: DateTime.now().add(Duration(days: (json['id'] as int? ?? 1) % 14)),
      priority: _mapPriority(json['id'] as int? ?? 1),
      status: completed ? 'Done' : 'Pending',
      createdAt: DateTime.now(),
      remoteId: json['id'] as int?,
    );
  }

  /// Create from local Hive JSON.
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      remoteId: json['remoteId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'remoteId': remoteId,
    };
  }

  /// Convert to jsonplaceholder-compatible format for POST/PUT.
  Map<String, dynamic> toApiJson() {
    return {
      'title': title,
      'completed': status == 'Done',
      'userId': 1,
      if (remoteId != null) 'id': remoteId,
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? status,
    DateTime? createdAt,
    int? remoteId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  /// Check if this task is overdue.
  bool get isOverdue =>
      DateTime.now().isAfter(dueDate) &&
      status != 'Done' &&
      status != 'Overdue';

  /// Check if this task is due today.
  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  /// Check if this task is due this week.
  bool get isDueThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return dueDate.isAfter(startOfWeek) && dueDate.isBefore(endOfWeek);
  }

  /// Map API id to priority for demo purposes.
  static String _mapPriority(int id) {
    final mod = id % 3;
    switch (mod) {
      case 0:
        return 'High';
      case 1:
        return 'Medium';
      default:
        return 'Low';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        dueDate,
        priority,
        status,
        createdAt,
        remoteId,
      ];
}
