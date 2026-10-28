import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tickoff_replacement/data/database/app_database.dart';
import 'package:tickoff_replacement/domain/models/task.dart';
import 'package:tickoff_replacement/state/task_state.dart';

void main() {
  late Database db;
  late TaskService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    service = TaskService(db);
  });

  tearDown(() async => db.close());

  test('schema v6 preserves completion timestamps and deletion analytics history', () async {
    final List<Map<String, Object?>> columns = await db.rawQuery('PRAGMA table_info(tasks)');
    expect(columns.any((Map<String, Object?> row) => row['name'] == 'completed_at'), isTrue);
    final List<Map<String, Object?>> historyTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('task_history', 'task_activity')");
    expect(historyTables, hasLength(2));
    final List<Map<String, Object?>> activityColumns = await db.rawQuery('PRAGMA table_info(task_activity)');
    expect(activityColumns.any((Map<String, Object?> row) => row['name'] == 'reminder_at'), isTrue);

    final DateTime due = DateTime(2026, 10, 28);
    final TaskItem item = TaskItem(id: 'task-history-test', title: 'Task', createdAt: due, updatedAt: due, dueDate: due, priority: 4, isCompleted: true, completedAt: due);
    await service.save(item);
    await service.delete(item.id);
    final List<TaskItem> history = await service.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.isCompleted, isTrue);
    expect(history.single.completedAt, due);
    expect(history.single.dueDate, due);
  });
}
