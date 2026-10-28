import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/logic/task_analytics.dart';
import 'package:tickoff_replacement/domain/models/task.dart';
import 'package:tickoff_replacement/domain/models/task_activity.dart';

void main() {
  const TaskAnalytics analytics = TaskAnalytics();
  final DateTime created = DateTime(2026, 11, 1, 8);
  final DateTime deadline = DateTime(2026, 11, 3);

  test('late completion is attributed to actual completion day, not deadline day', () {
    final TaskItem task = TaskItem(id: 'late', title: 'Late', createdAt: created, updatedAt: DateTime(2026, 11, 5), dueDate: deadline, priority: 3, isCompleted: true, completedAt: DateTime(2026, 11, 5, 10));
    final List<TaskActivity> events = <TaskActivity>[
      TaskActivity(id: 'c', taskId: task.id, title: task.title, dueDate: deadline, priority: 3, activityType: 'created', occurredAt: created, createdAt: created),
      TaskActivity(id: 'done', taskId: task.id, title: task.title, dueDate: deadline, priority: 3, activityType: 'completed', occurredAt: DateTime(2026, 11, 5, 10), createdAt: created),
    ];
    final TaskDayStats deadlineStats = analytics.forDayWithActivity(tasks: <TaskItem>[task], activities: events, day: DateTime(2026, 11, 3));
    final TaskDayStats completionStats = analytics.forDayWithActivity(tasks: <TaskItem>[task], activities: events, day: DateTime(2026, 11, 5));
    expect(deadlineStats.completed, 0);
    expect(deadlineStats.incomplete, 1);
    expect(completionStats.completed, 1);
    expect(completionStats.lateCompleted, 1);
  });

  test('each subtask completion contributes on its own actual day without counting parent too', () {
    final TaskItem parent = TaskItem(id: 'p', title: 'Parent', createdAt: created, updatedAt: created, dueDate: deadline);
    final TaskItem a = TaskItem(id: 'a', title: 'First step', createdAt: created, updatedAt: created, dueDate: DateTime(2026, 11, 3), parentId: 'p', priority: 2, isCompleted: true, completedAt: DateTime(2026, 11, 3, 10));
    final TaskItem b = TaskItem(id: 'b', title: 'Second step', createdAt: DateTime(2026, 11, 4, 9), updatedAt: DateTime(2026, 11, 4), dueDate: DateTime(2026, 11, 4), parentId: 'p', priority: 2, isCompleted: true, completedAt: DateTime(2026, 11, 4, 10));
    final List<TaskActivity> events = <TaskActivity>[
      TaskActivity(id: 'a-done', taskId: 'a', title: a.title, dueDate: a.dueDate, priority: 2, activityType: 'completed', occurredAt: DateTime(2026, 11, 3, 10), parentId: 'p', createdAt: created),
      TaskActivity(id: 'b-done', taskId: 'b', title: b.title, dueDate: b.dueDate, priority: 2, activityType: 'completed', occurredAt: DateTime(2026, 11, 4, 10), parentId: 'p', createdAt: DateTime(2026, 11, 4, 9)),
    ];
    final TaskDayStats day3 = analytics.forDayWithActivity(tasks: <TaskItem>[parent, a, b], activities: events, day: DateTime(2026, 11, 3));
    final TaskDayStats day4 = analytics.forDayWithActivity(tasks: <TaskItem>[parent, a, b], activities: events, day: DateTime(2026, 11, 4));
    expect(day3.total, 1);
    expect(day3.subtasksCompleted, 1);
    expect(day4.subtasksCompleted, 1);
    expect(day4.total, 1);
  });
  test('deleted snapshot contributes through its deletion day, not afterward', () {
    final TaskItem deleted = TaskItem(
      id: 'deleted', title: 'Deleted task', createdAt: created,
      updatedAt: DateTime(2026, 11, 5), dueDate: deadline,
      deletedAt: DateTime(2026, 11, 5, 12),
    );
    final List<TaskActivity> events = <TaskActivity>[
      TaskActivity(id: 'created', taskId: deleted.id, title: deleted.title,
        dueDate: deadline, priority: 2, activityType: 'created',
        occurredAt: created, createdAt: created),
    ];
    final TaskDayStats beforeDelete = analytics.forDayWithActivity(
      tasks: <TaskItem>[deleted], activities: events,
      day: DateTime(2026, 11, 5),
    );
    final TaskDayStats afterDelete = analytics.forDayWithActivity(
      tasks: <TaskItem>[deleted], activities: events,
      day: DateTime(2026, 11, 6),
    );
    expect(beforeDelete.total, 1);
    expect(afterDelete.total, 0);
  });

}
