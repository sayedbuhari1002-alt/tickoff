import '../models/task.dart';
import '../models/task_activity.dart';

class TaskDayStats {
  const TaskDayStats({
    required this.total,
    required this.completed,
    required this.weightedScore,
    this.onTimeCompleted = 0,
    this.lateCompleted = 0,
    this.overdue = 0,
    this.scheduled = 0,
    this.subtasksCompleted = 0,
    this.subtasksIncomplete = 0,
    this.subtasksOverdue = 0,
  });

  final int total;
  final int completed;
  final double weightedScore;
  final int onTimeCompleted;
  final int lateCompleted;
  final int overdue;
  final int scheduled;
  final int subtasksCompleted;
  final int subtasksIncomplete;
  final int subtasksOverdue;
  int get incomplete => total - completed;
  double get completionRate => total == 0 ? 0 : completed / total;
  double get onTimeRate => completed == 0 ? 0 : onTimeCompleted / completed;
  bool get hasTasks => total > 0;
}

/// Task analytics. Daily history uses completion-event timestamps, never the
/// current isCompleted flag alone, so a late completion cannot rewrite an
/// earlier day as complete. Parent rows with children are excluded from the
/// denominator; each child is an independent analytics item.
class TaskAnalytics {
  const TaskAnalytics();

  /// Legacy/simple calculation retained for compatibility with existing tests.
  TaskDayStats forDay(List<TaskItem> tasks, DateTime day) {
    final DateTime date = DateTime(day.year, day.month, day.day);
    final List<TaskItem> eligible = tasks.where((TaskItem task) {
      if (task.isSubtask || task.isPaused) return false;
      return _sameDay(task.dueDate, date);
    }).toList();
    bool completedOnTime(TaskItem task) {
      if (!task.isCompleted) return false;
      final DateTime? completedAt = task.completedAt;
      if (completedAt == null) return true;
      return !completedAt.isAfter(_deadline(task));
    }
    final int completed = eligible.where(completedOnTime).length;
    final int totalWeight = eligible.fold<int>(0, (int sum, TaskItem task) => sum + task.priority.clamp(1, 4).toInt());
    final int completedWeight = eligible.where(completedOnTime).fold<int>(0, (int sum, TaskItem task) => sum + task.priority.clamp(1, 4).toInt());
    final int onTime = eligible.where(completedOnTime).length;
    final int late = eligible.where((TaskItem task) => task.isCompleted && !completedOnTime(task)).length;
    return TaskDayStats(total: eligible.length, completed: completed, weightedScore: totalWeight == 0 ? 0 : 10 * completedWeight / totalWeight, onTimeCompleted: onTime, lateCompleted: late, scheduled: eligible.length);
  }

  /// Historically accurate daily calculation over current rows, deletion
  /// snapshots and immutable activity events. Pending overdue items remain in
  /// daily totals until the day on which they are actually completed.
  TaskDayStats forDayWithActivity({
    required List<TaskItem> tasks,
    required List<TaskActivity> activities,
    required DateTime day,
  }) {
    final DateTime date = DateTime(day.year, day.month, day.day);
    final DateTime endOfDay = date.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    final Map<String, TaskItem> byId = <String, TaskItem>{};
    for (final TaskItem item in tasks) {
      // Deleted snapshots contribute through the day they were removed but do
      // not continue inflating overdue totals on every day afterwards.
      if (item.deletedAt != null && date.isAfter(_dayOnly(item.deletedAt!))) continue;
      // A task created after the selected historical day did not exist yet.
      final bool completedThatDay = activities.any((TaskActivity event) => event.taskId == item.id && event.isCompletion && _sameDay(event.occurredAt, date));
      if (item.createdAt.isAfter(endOfDay) && !completedThatDay) continue;
      TaskActivity? scheduleSnapshot;
      for (final TaskActivity event in activities) {
        if (event.taskId != item.id || (event.activityType != 'created' && event.activityType != 'updated') || event.occurredAt.isAfter(endOfDay)) continue;
        if (scheduleSnapshot == null || event.occurredAt.isAfter(scheduleSnapshot.occurredAt)) scheduleSnapshot = event;
      }
      final TaskItem effective = scheduleSnapshot == null ? item : item.copyWith(
        title: scheduleSnapshot.title,
        dueDate: scheduleSnapshot.dueDate,
        priority: scheduleSnapshot.priority,
        category: scheduleSnapshot.category,
        reminderAt: scheduleSnapshot.reminderAt,
        clearReminder: scheduleSnapshot.reminderAt == null,
        isPaused: scheduleSnapshot.isPaused,
        updatedAt: scheduleSnapshot.occurredAt,
      );
      // Active rows take precedence over deletion snapshots with the same ID.
      byId.putIfAbsent(item.id, () => effective);
    }
    final Set<String> parentsWithChildren = byId.values.where((TaskItem item) => item.parentId != null).map((TaskItem item) => item.parentId!).toSet();
    final Map<String, List<TaskActivity>> eventByTask = <String, List<TaskActivity>>{};
    for (final TaskActivity event in activities) {
      eventByTask.putIfAbsent(event.taskId, () => <TaskActivity>[]).add(event);
    }
    for (final List<TaskActivity> events in eventByTask.values) {
      events.sort((TaskActivity a, TaskActivity b) => a.occurredAt.compareTo(b.occurredAt));
    }

    bool completedAsOf(TaskItem item) {
      final List<TaskActivity> events = eventByTask[item.id] ?? const <TaskActivity>[];
      TaskActivity? latest;
      for (final TaskActivity event in events) {
        if (event.occurredAt.isAfter(endOfDay)) break;
        if (event.activityType == 'completed' || event.activityType == 'reopened') latest = event;
      }
      if (latest != null) return latest.isCompletion;
      if (!item.isCompleted) return false;
      final DateTime? completedAt = item.completedAt;
      return completedAt == null || !completedAt.isAfter(endOfDay);
    }

    bool completionOccurredOnDay(TaskItem item) => (eventByTask[item.id] ?? const <TaskActivity>[]).any((TaskActivity event) => event.isCompletion && _sameDay(event.occurredAt, date));

    final List<TaskItem> eligible = <TaskItem>[];
    for (final TaskItem item in byId.values) {
      if (item.isPaused) continue;
      // Do not double-count a task parent and its individual checklist steps.
      if (!item.isSubtask && parentsWithChildren.contains(item.id)) continue;
      final DateTime due = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
      final DateTime? reminder = item.reminderAt == null ? null : DateTime(item.reminderAt!.year, item.reminderAt!.month, item.reminderAt!.day);
      final bool withinReminderWindow = reminder != null && !date.isBefore(reminder) && !date.isAfter(due);
      final bool dueOrOverdue = !date.isBefore(due);
      final bool completionToday = completionOccurredOnDay(item) || (item.completedAt != null && _sameDay(item.completedAt!, date));
      final bool complete = completedAsOf(item);
      // Once completed, an item leaves future daily pending totals, but remains
      // on its due day and on the actual day of completion.
      final bool eligibleForDay = withinReminderWindow || (dueOrOverdue && !complete) || _sameDay(due, date) || completionToday;
      if (eligibleForDay) eligible.add(item);
    }

    int completed = 0;
    int onTime = 0;
    int late = 0;
    int overdue = 0;
    int totalWeight = 0;
    int completedWeight = 0;
    int scheduled = 0;
    int subtaskCompleted = 0;
    int subtaskIncomplete = 0;
    int subtaskOverdue = 0;
    for (final TaskItem item in eligible) {
      final bool done = completedAsOf(item);
      totalWeight += item.priority.clamp(1, 4).toInt();
      final DateTime due = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
      if (_sameDay(due, date) || (item.reminderAt != null && !_dayOnly(item.reminderAt!).isAfter(date) && !date.isAfter(due))) scheduled++;
      if (done) {
        completed++;
        completedWeight += item.priority.clamp(1, 4).toInt();
        DateTime? completionTime;
        final List<TaskActivity> events = eventByTask[item.id] ?? const <TaskActivity>[];
        for (final TaskActivity event in events) {
          if (event.occurredAt.isAfter(endOfDay)) break;
          if (event.isCompletion) completionTime = event.occurredAt;
          if (event.activityType == 'reopened') completionTime = null;
        }
        completionTime ??= item.completedAt;
        final bool lateCompletion = completionTime != null && completionTime.isAfter(_deadline(item));
        if (lateCompletion) { late++; } else { onTime++; }
        if (item.isSubtask) subtaskCompleted++;
      } else {
        if (date.isAfter(due) || (_sameDay(date, due) && (item.dueDate.hour != 0 || item.dueDate.minute != 0) && item.dueDate.isBefore(endOfDay))) overdue++;
        if (item.isSubtask) { subtaskIncomplete++; if (date.isAfter(due) || (_sameDay(date, due) && item.dueDate.isBefore(endOfDay) && (item.dueDate.hour != 0 || item.dueDate.minute != 0))) subtaskOverdue++; }
      }
    }
    return TaskDayStats(
      total: eligible.length,
      completed: completed,
      weightedScore: totalWeight == 0 ? 0 : 10 * completedWeight / totalWeight,
      onTimeCompleted: onTime,
      lateCompleted: late,
      overdue: overdue,
      scheduled: scheduled,
      subtasksCompleted: subtaskCompleted,
      subtasksIncomplete: subtaskIncomplete,
      subtasksOverdue: subtaskOverdue,
    );
  }

  List<DateTime> lastDays(DateTime end, {int days = 30}) {
    final DateTime last = DateTime(end.year, end.month, end.day);
    return List<DateTime>.generate(days, (int index) => last.subtract(Duration(days: days - index - 1)));
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static DateTime _dayOnly(DateTime value) => DateTime(value.year, value.month, value.day);
  static DateTime _deadline(TaskItem task) => task.dueDate.hour == 0 && task.dueDate.minute == 0
      ? DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, 23, 59, 59, 999)
      : task.dueDate;
}
