import '../models/task.dart';

class TaskDayStats {
  const TaskDayStats({required this.total, required this.completed, required this.weightedScore});
  final int total;
  final int completed;
  final double weightedScore;
  int get incomplete => total - completed;
  double get completionRate => total == 0 ? 0 : completed / total;
  bool get hasTasks => total > 0;
}

/// Pure task analytics. Only top-level, non-paused tasks are counted so a
/// parent with subtasks is not counted again as each child completes.
class TaskAnalytics {
  const TaskAnalytics();

  TaskDayStats forDay(List<TaskItem> tasks, DateTime day) {
    final DateTime date = DateTime(day.year, day.month, day.day);
    final List<TaskItem> eligible = tasks.where((TaskItem task) {
      if (task.isSubtask || task.isPaused) return false;
      return task.dueDate.year == date.year && task.dueDate.month == date.month && task.dueDate.day == date.day;
    }).toList();
    bool completedOnTime(TaskItem task) {
      if (!task.isCompleted) return false;
      final DateTime? completedAt = task.completedAt;
      if (completedAt == null) return true; // legacy records migrated without a completion timestamp
      final bool hasTime = task.dueDate.hour != 0 || task.dueDate.minute != 0;
      final DateTime deadline = hasTime ? task.dueDate : DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, 23, 59, 59, 999);
      return !completedAt.isAfter(deadline);
    }
    final int completed = eligible.where(completedOnTime).length;
    final int totalWeight = eligible.fold<int>(0, (int sum, TaskItem task) => sum + task.priority.clamp(1, 4).toInt());
    final int completedWeight = eligible.where(completedOnTime).fold<int>(0, (int sum, TaskItem task) => sum + task.priority.clamp(1, 4).toInt());
    return TaskDayStats(total: eligible.length, completed: completed, weightedScore: totalWeight == 0 ? 0 : 10 * completedWeight / totalWeight);
  }

  List<DateTime> lastDays(DateTime end, {int days = 30}) {
    final DateTime last = DateTime(end.year, end.month, end.day);
    return List<DateTime>.generate(days, (int index) => last.subtract(Duration(days: days - index - 1)));
  }
}
