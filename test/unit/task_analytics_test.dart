import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/logic/task_analytics.dart';
import 'package:tickoff_replacement/domain/models/task.dart';

TaskItem task(String id, int priority, bool completed, DateTime due, {bool paused = false, String? parent}) => TaskItem(id: id, title: id, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1), dueDate: due, priority: priority, isCompleted: completed, isPaused: paused, parentId: parent);

void main() {
  const TaskAnalytics analytics = TaskAnalytics();
  final DateTime day = DateTime(2026, 10, 28);

  test('daily analytics calculates simple ratio and weighted score', () {
    final TaskDayStats stats = analytics.forDay(<TaskItem>[
      task('high-done', 4, true, day),
      task('low-open', 1, false, day),
      task('future', 4, false, DateTime(2026, 10, 29)),
      task('paused', 4, false, day, paused: true),
      task('subtask', 4, true, day, parent: 'parent'),
    ], day);
    expect(stats.total, 2);
    expect(stats.completed, 1);
    expect(stats.completionRate, 0.5);
    expect(stats.weightedScore, 8.0);
  });

  test('late completion remains incomplete in analytics for the original deadline', () {
    final TaskDayStats stats = analytics.forDay(<TaskItem>[
      TaskItem(id: 'late', title: 'Late', createdAt: day, updatedAt: day.add(const Duration(days: 1)), dueDate: day, priority: 4, isCompleted: true, completedAt: day.add(const Duration(days: 1))),
    ], day);
    expect(stats.total, 1);
    expect(stats.completed, 0);
    expect(stats.completionRate, 0);
  });

  test('zero-task day has no artificial score', () {
    final TaskDayStats stats = analytics.forDay(<TaskItem>[], day);
    expect(stats.hasTasks, isFalse);
    expect(stats.completionRate, 0);
    expect(stats.weightedScore, 0);
  });

  test('last 30 days includes end date and has 30 entries', () {
    final List<DateTime> days = analytics.lastDays(day);
    expect(days.length, 30);
    expect(days.first, DateTime(2026, 9, 29));
    expect(days.last, day);
  });
}
