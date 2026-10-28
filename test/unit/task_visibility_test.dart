import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/logic/task_visibility.dart';
import 'package:tickoff_replacement/domain/models/task.dart';

TaskItem makeTask({DateTime? reminder, DateTime? deadline, bool complete = false}) {
  final DateTime created = DateTime(2026, 11, 1);
  return TaskItem(
    id: 'test-task', title: 'Reminder example', createdAt: created,
    updatedAt: created, dueDate: deadline ?? DateTime(2026, 11, 4),
    reminderAt: reminder, isCompleted: complete,
    completedAt: complete ? DateTime(2026, 11, 4, 10) : null,
  );
}

void main() {
  test('reminder makes task visible from reminder day through deadline and overdue days', () {
    final TaskItem task = makeTask(reminder: DateTime(2026, 11, 3, 9));
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 2)), isFalse);
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 3)), isTrue);
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 4)), isTrue);
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 5)), isTrue);
    expect(isTaskOverdueOnDate(task, DateTime(2026, 11, 5)), isTrue);
  });

  test('no reminder preserves due-date visibility', () {
    final TaskItem task = makeTask();
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 3)), isFalse);
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 4)), isTrue);
    expect(isTaskVisibleOnDate(task, DateTime(2026, 11, 5)), isTrue);
  });

  test('a completed task is not shown as overdue after completion', () {
    final TaskItem task = makeTask(reminder: DateTime(2026, 11, 3), complete: true);
    expect(isTaskOverdueOnDate(task, DateTime(2026, 11, 5)), isFalse);
  });
}
