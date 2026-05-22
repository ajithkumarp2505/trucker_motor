/// Enum for task filtering options.
enum TaskFilter {
  all,
  today,
  thisWeek,
  overdue,
  pending,
  inProgress,
  done,
  highPriority,
  mediumPriority,
  lowPriority,
}

/// Enum for task sorting options.
enum TaskSort {
  dueDate,
  priority,
  creationDate,
}

/// Extension to get display labels for filters.
extension TaskFilterExtension on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.today:
        return 'Today';
      case TaskFilter.thisWeek:
        return 'This Week';
      case TaskFilter.overdue:
        return 'Overdue';
      case TaskFilter.pending:
        return 'Pending';
      case TaskFilter.inProgress:
        return 'In Progress';
      case TaskFilter.done:
        return 'Done';
      case TaskFilter.highPriority:
        return 'High Priority';
      case TaskFilter.mediumPriority:
        return 'Medium Priority';
      case TaskFilter.lowPriority:
        return 'Low Priority';
    }
  }
}

extension TaskSortExtension on TaskSort {
  String get label {
    switch (this) {
      case TaskSort.dueDate:
        return 'Due Date';
      case TaskSort.priority:
        return 'Priority';
      case TaskSort.creationDate:
        return 'Created';
    }
  }
}
