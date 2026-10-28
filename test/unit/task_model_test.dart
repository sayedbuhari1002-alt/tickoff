import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/models/task.dart';

void main() {
  test('task round-trips through SQLite row representation', () {
    final DateTime now = DateTime(2026, 10, 28, 9, 30);
    final TaskItem task = TaskItem(
      id: 'task-1',
      title: 'Read a chapter',
      description: 'Read chapter two',
      category: 'Study',
      createdAt: now,
      updatedAt: now,
      dueDate: DateTime(2026, 10, 30),
      priority: 3,
      colorValue: 0xFF4CAF50,
      notes: 'Take notes after reading',
      photoPaths: const <String>['/local/photo.jpg'],
      audioPaths: const <String>['/local/audio.m4a'],
      isCompleted: true,
      completedAt: DateTime(2026, 10, 30, 10),
    );
    final TaskItem decoded = TaskItem.fromRow(task.toRow());
    expect(decoded.id, task.id);
    expect(decoded.title, task.title);
    expect(decoded.dueDate, DateTime(2026, 10, 30));
    expect(decoded.priority, 3);
    expect(decoded.photoPaths, task.photoPaths);
    expect(decoded.audioPaths, task.audioPaths);
    expect(decoded.completedAt, task.completedAt);
  });

  test('overdue tasks remain outstanding until completed or paused', () {
    final DateTime now = DateTime(2026, 10, 28);
    final TaskItem task = TaskItem(
      id: 'task-2',
      title: 'Overdue',
      createdAt: DateTime(2026, 10, 20),
      updatedAt: now,
      dueDate: DateTime(2026, 10, 27),
    );
    expect(task.isOverdue(now), isTrue);
    expect(task.copyWith(isCompleted: true).isOverdue(now), isFalse);
    expect(task.copyWith(isPaused: true).isOverdue(now), isFalse);
  });
}
