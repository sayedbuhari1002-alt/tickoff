import '../models/task.dart';

DateTime taskDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool sameTaskDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whether a task belongs in a date's task list. A reminder activates the task
/// on its reminder day and keeps it visible through its deadline. If the task
/// remains incomplete after the deadline it stays visible as overdue. Without
/// a reminder, the original due-date visibility rules apply.
bool isTaskVisibleOnDate(TaskItem task, DateTime selectedDay) {
  if (task.isSubtask || task.isPaused) return false;
  final DateTime selected = taskDateOnly(selectedDay);
  final DateTime due = taskDateOnly(task.dueDate);
  final DateTime? completed = task.completedAt == null
      ? null
      : taskDateOnly(task.completedAt!);

  if (task.isCompleted) {
    return sameTaskDay(due, selected) ||
        (completed != null && sameTaskDay(completed, selected));
  }

  if (task.reminderAt != null) {
    final DateTime reminder = taskDateOnly(task.reminderAt!);
    return !selected.isBefore(reminder);
  }
  return !selected.isBefore(due);
}

bool isTaskOverdueOnDate(TaskItem task, DateTime selectedDay) {
  if (task.isCompleted || task.isPaused || task.isSubtask) return false;
  final DateTime selected = taskDateOnly(selectedDay);
  final DateTime due = taskDateOnly(task.dueDate);
  if (selected.isAfter(due)) return true;
  if (!sameTaskDay(selected, due) ||
      (task.dueDate.hour == 0 && task.dueDate.minute == 0)) {
    return false;
  }

  // For today's list use the actual clock; for a historical date treat the
  // selected day as closed, and don't flag future due dates as overdue early.
  final DateTime today = taskDateOnly(DateTime.now());
  if (sameTaskDay(selected, today)) return task.dueDate.isBefore(DateTime.now());
  return selected.isBefore(today);
}
