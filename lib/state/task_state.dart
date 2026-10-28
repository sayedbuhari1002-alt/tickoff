import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/utils/ids.dart';
import '../domain/models/task.dart';
import '../domain/models/task_activity.dart';
import '../shared/utils/local_notifications.dart';
import '../shared/utils/local_attachments.dart';

final taskDatabaseProvider = Provider<Database>((ref) => throw UnimplementedError('taskDatabaseProvider must be overridden'));
final taskServiceProvider = Provider<TaskService>((ref) => TaskService(ref.watch(taskDatabaseProvider)));

class TaskService {
  TaskService(this.db); final Database db;
  Future<List<TaskItem>> load() async {
    final rows = await db.query('tasks', orderBy: 'due_date ASC, priority DESC, sort_order ASC, created_at ASC');
    return rows.map(TaskItem.fromRow).toList();
  }
  Future<void> save(TaskItem task) async {
    await db.transaction((txn) async {
      final rows = await txn.query('tasks', columns:['id'], where:'id = ?', whereArgs:[task.id], limit:1);
      if (rows.isEmpty) { await txn.insert('tasks',task.toRow()); }
      else { await txn.update('tasks',task.toRow(),where:'id = ?',whereArgs:[task.id]); }
    });
  }
  Future<void> delete(String id) async {
    final List<Map<String, Object?>> rows = await db.query('tasks', where: 'id = ? OR parent_id = ?', whereArgs: <Object?>[id, id]);
    for (final Map<String, Object?> row in rows) {
      await db.insert('task_history', <String, Object?>{
        'id': row['id'], 'title': row['title'] ?? 'Deleted task',
        'due_date': row['due_date'], 'priority': row['priority'],
        'is_completed': row['is_completed'], 'completed_at': row['completed_at'],
        'created_at': row['created_at'], 'deleted_at': DateTime.now().toIso8601String(),
        'parent_id': row['parent_id'], 'category': row['category'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final String photos = row['photo_paths'] as String? ?? '';
      final String audio = row['audio_paths'] as String? ?? '';
      for (final String path in photos.split('\n').where((String p) => p.isNotEmpty)) { await LocalAttachments.deleteFile(path); }
      for (final String path in audio.split('\n').where((String p) => p.isNotEmpty)) { await LocalAttachments.deleteFile(path); }
      try { await LocalNotifications.instance.cancel(row['id'] as String); } catch (_) { /* persistence/deletion must work in offline or test environments */ }
    }
    await db.delete('tasks', where: 'id = ?', whereArgs: <Object?>[id]);
  }
  Future<void> cleanupExpired(DateTime now) async {
    final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final key = '${cutoff.year.toString().padLeft(4, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final List<Map<String, Object?>> expired = await db.query('tasks', where: 'parent_id IS NULL AND substr(due_date, 1, 10) <= ?', whereArgs: <Object?>[key]);
    for (final Map<String, Object?> row in expired) { await delete(row['id'] as String); }
    // Task rows still expire 30 days after deadline, but historical events
    // are retained for the one-year analytics range plus a small safety margin.
    final DateTime historyCutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 400));
    final String historyKey = '${historyCutoff.year.toString().padLeft(4, '0')}-${historyCutoff.month.toString().padLeft(2, '0')}-${historyCutoff.day.toString().padLeft(2, '0')}';
    await db.delete('task_history', where: 'substr(deleted_at, 1, 10) <= ?', whereArgs: <Object?>[historyKey]);
    await db.delete('task_activity', where: "substr(occurred_at, 1, 10) <= ?", whereArgs: <Object?>[historyKey]);
  }

  Future<void> logActivity(TaskItem task, String type, DateTime occurredAt) async {
    await db.insert('task_activity', <String, Object?>{
      'id': newId(), 'task_id': task.id, 'title': task.title,
      'due_date': task.dueDate.toIso8601String(), 'priority': task.priority,
      'activity_type': type, 'occurred_at': occurredAt.toIso8601String(),
      'parent_id': task.parentId, 'category': task.category,
      'created_at': task.createdAt.toIso8601String(),
      'reminder_at': task.reminderAt?.toIso8601String(), 'is_paused': task.isPaused ? 1 : 0,
    });
  }

  Future<List<TaskActivity>> loadActivities() async {
    final rows = await db.query('task_activity', orderBy: 'occurred_at ASC');
    return rows.map(TaskActivity.fromRow).toList();
  }

  Future<List<TaskItem>> loadHistory() async {
    final List<Map<String, Object?>> rows = await db.query('task_history', orderBy: 'due_date ASC');
    return rows.map((Map<String, Object?> row) => TaskItem(
      id: row['id'] as String, title: row['title'] as String? ?? 'Deleted task',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['deleted_at'] as String? ?? '') ?? DateTime.now(),
      deletedAt: DateTime.tryParse(row['deleted_at'] as String? ?? ''),
      dueDate: DateTime.tryParse(row['due_date'] as String? ?? '') ?? DateTime.now(),
      priority: row['priority'] as int? ?? 2,
      isCompleted: (row['is_completed'] as int? ?? 0) == 1,
      completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
      parentId: row['parent_id'] as String?, category: row['category'] as String? ?? '',
    )).toList();
  }
}

enum TaskFilter { all, today, due }
final taskSelectedDateProvider = StateProvider<DateTime>((ref) { final DateTime now = DateTime.now(); return DateTime(now.year, now.month, now.day); });
final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);

final taskListProvider = AsyncNotifierProvider<TaskListNotifier,List<TaskItem>>(TaskListNotifier.new);
final taskHistoryProvider = FutureProvider<List<TaskItem>>((ref) => ref.read(taskServiceProvider).loadHistory());
final taskActivityProvider = FutureProvider<List<TaskActivity>>((ref) => ref.read(taskServiceProvider).loadActivities());

enum TaskSort { deadline, priority, categoryAscending, categoryDescending }
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.deadline);
final taskPriorityFilterProvider = StateProvider<int?>((ref) => null);
final taskCategoryFilterProvider = StateProvider<String?>((ref) => null);
class TaskListNotifier extends AsyncNotifier<List<TaskItem>> {
  TaskService get service=>ref.read(taskServiceProvider);
  Timer? _cleanupTimer;
  @override Future<List<TaskItem>> build() async {
    _cleanupTimer?.cancel();
    ref.onDispose(() => _cleanupTimer?.cancel());
    await service.cleanupExpired(DateTime.now());
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (_) async { try { await service.cleanupExpired(DateTime.now()); ref.invalidate(taskHistoryProvider); ref.invalidate(taskActivityProvider); state = AsyncData(await service.load()); } catch (_) { /* next cleanup cycle retries */ } });
    final List<TaskItem> items = await service.load();
    for (final TaskItem task in items.where((TaskItem t) => !t.isSubtask)) { try { if (task.reminderAt != null && !task.isCompleted && !task.isPaused) { await LocalNotifications.instance.scheduleTask(id: task.id, title: task.title, when: task.reminderAt!); } else { await LocalNotifications.instance.cancel(task.id); } } catch (_) { /* app remains usable if notifications are unavailable */ } }
    return items;
  }
  Future<void> save(TaskItem task) async {
    final List<TaskItem> before = await service.load();
    final TaskItem? previous = before.where((TaskItem item) => item.id == task.id).firstOrNull;
    await service.save(task);
    if (previous == null) {
      await service.logActivity(task, 'created', DateTime.now());
      ref.invalidate(taskActivityProvider);
    } else if (previous.title != task.title || previous.dueDate != task.dueDate || previous.reminderAt != task.reminderAt || previous.priority != task.priority || previous.category != task.category || previous.isPaused != task.isPaused || previous.parentId != task.parentId) {
      await service.logActivity(task, 'updated', DateTime.now());
      ref.invalidate(taskActivityProvider);
    }
    // Subtask deadlines/reminders are independent; a parent deadline edit never rewrites them.
    try {
      if (task.reminderAt != null && !task.isCompleted && !task.isPaused) {
        await LocalNotifications.instance.scheduleTask(id: task.id, title: task.title, when: task.reminderAt!);
      } else {
        await LocalNotifications.instance.cancel(task.id);
      }
    } catch (_) { /* a notification failure must not lose a saved task */ }
    state = AsyncData(await service.load());
  }
  Future<void> delete(String id) async { try { await LocalNotifications.instance.cancel(id); } catch (_) { /* continue with deletion if notifications are unavailable */ } await service.delete(id); ref.invalidate(taskHistoryProvider); ref.invalidate(taskActivityProvider); state = AsyncData(await service.load()); }
  Future<void> toggle(TaskItem task) async {
    final bool completing = !task.isCompleted;
    final DateTime stamp = DateTime.now();
    await service.logActivity(task, completing ? 'completed' : 'reopened', stamp);
    await save(task.copyWith(isCompleted: completing, completedAt: completing ? stamp : null, clearCompletedAt: !completing));
    ref.invalidate(taskActivityProvider);
  }
  Future<void> toggleTaskOrNextSubtask(TaskItem task, List<TaskItem> all) async {
    final children = all.where((t) => t.parentId == task.id).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
    if (children.isEmpty) { await toggle(task); return; }
    final next = children.where((t)=>!t.isCompleted).firstOrNull;
    if (next != null) { await toggle(next); }
    else if (children.isNotEmpty && task.isCompleted) { await toggle(children.last); }
    final refreshed = await service.load();
    final updatedChildren = refreshed.where((t)=>t.parentId==task.id);
    if (updatedChildren.isNotEmpty && updatedChildren.every((t)=>t.isCompleted)) { await save(task.copyWith(isCompleted:true, completedAt: DateTime.now(), clearCompletedAt: false)); }
    else if (task.isCompleted) { await save(task.copyWith(isCompleted:false, clearCompletedAt: true)); }
  }

  /// Toggle a particular checklist step and recalculate its parent without
  /// generating a second completion event for the aggregate parent row.
  Future<void> toggleSubtaskAndSyncParent(TaskItem child) async {
    await toggle(child);
    if (child.parentId == null) return;
    final List<TaskItem> refreshed = await service.load();
    final TaskItem? parent = refreshed.where((TaskItem item) => item.id == child.parentId).firstOrNull;
    if (parent == null) return;
    final List<TaskItem> siblings = refreshed.where((TaskItem item) => item.parentId == parent.id).toList();
    if (siblings.isEmpty) return;
    final bool allComplete = siblings.every((TaskItem item) => item.isCompleted);
    if (allComplete && !parent.isCompleted) {
      await save(parent.copyWith(isCompleted: true, completedAt: DateTime.now()));
    } else if (!allComplete && parent.isCompleted) {
      await save(parent.copyWith(isCompleted: false, clearCompletedAt: true));
    }
  }
  Future<void> pause(TaskItem task) async { await save(task.copyWith(isPaused:!task.isPaused)); }
}

extension _TaskFirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
