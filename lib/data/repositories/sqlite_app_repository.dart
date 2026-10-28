import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/models.dart';
import 'app_repository.dart';

/// SQLite-backed [AppRepository].
class SqliteAppRepository implements AppRepository {
  SqliteAppRepository(this._db);

  final Database _db;

  /// Update-then-insert. Deliberately not `INSERT OR REPLACE`: replacing a
  /// parent row would fire ON DELETE CASCADE and wipe the habit's history.
  Future<void> _upsert(
    DatabaseExecutor executor,
    String table,
    Map<String, Object?> row,
  ) async {
    final int updated = await executor.update(
      table,
      row,
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    if (updated == 0) await executor.insert(table, row);
  }

  // ------------------------------------------------------------------ habits

  @override
  Future<List<Habit>> loadHabits() async {
    final List<Map<String, Object?>> rows = await _db.query('habits');
    final List<Habit> habits = <Habit>[];
    for (final Map<String, Object?> row in rows) {
      try {
        habits.add(_habitFromRow(row));
      } catch (e) {
        debugPrint('Skipping unreadable habit row: $e');
      }
    }
    return habits;
  }

  @override
  Future<void> upsertHabit(Habit habit) async {
    await _db.transaction((Transaction txn) async {
      await _upsert(txn, 'habits', _habitToRow(habit));
    });
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _db.delete('habits', where: 'id = ?', whereArgs: <Object?>[habitId]);
  }

  Map<String, Object?> _habitToRow(Habit h) {
    final Map<String, dynamic> j = h.toJson();
    return <String, Object?>{
      'id': h.id,
      'title': h.title,
      'description': h.description,
      'icon_key': h.iconKey,
      'color': h.colorValue,
      'type': h.type.name,
      'tracking': h.tracking.name,
      'schedule_json': jsonEncode(j['schedule']),
      'reminder_json': jsonEncode(j['reminder']),
      'category_id': h.categoryId,
      'show_streaks': h.showStreaksOnTimeline ? 1 : 0,
      'daily_goal': h.dailyGoal,
      'unit': h.unit,
      'step': h.step,
      'checklist_json': jsonEncode(j['checklist']),
      'created_at': h.createdAt.toIso8601String(),
      'archived_at': h.archivedAt?.toIso8601String(),
      'sort_order': h.sortOrder,
    };
  }

  Habit _habitFromRow(Map<String, Object?> r) {
    return Habit.fromJson(<String, dynamic>{
      'id': r['id'],
      'title': r['title'],
      'description': r['description'],
      'iconKey': r['icon_key'],
      'colorValue': r['color'],
      'type': r['type'],
      'tracking': r['tracking'],
      'schedule': jsonDecode(r['schedule_json'] as String),
      'reminder': jsonDecode(r['reminder_json'] as String),
      'categoryId': r['category_id'],
      'showStreaksOnTimeline': (r['show_streaks'] as int? ?? 1) != 0,
      'dailyGoal': r['daily_goal'],
      'unit': r['unit'],
      'step': r['step'],
      'checklist': jsonDecode(r['checklist_json'] as String),
      'createdAt': r['created_at'],
      'archivedAt': r['archived_at'],
      'sortOrder': r['sort_order'],
    });
  }

  // -------------------------------------------------------------- categories

  @override
  Future<List<HabitCategory>> loadCategories() async {
    final List<Map<String, Object?>> rows = await _db.query('categories');
    return rows
        .map(
          (Map<String, Object?> r) => HabitCategory(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '',
            iconKey: r['icon_key'] as String?,
            sortOrder: (r['sort_order'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertCategory(HabitCategory c) async {
    await _db.transaction((Transaction txn) async {
      await _upsert(txn, 'categories', <String, Object?>{
        'id': c.id,
        'name': c.name,
        'icon_key': c.iconKey,
        'sort_order': c.sortOrder,
      });
    });
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: <Object?>[categoryId],
    );
  }

  // ------------------------------------------------------------- completions

  @override
  Future<List<CompletionRecord>> loadCompletions() async {
    final List<Map<String, Object?>> rows = await _db.query('completions');
    final List<CompletionRecord> records = <CompletionRecord>[];
    for (final Map<String, Object?> r in rows) {
      try {
        records.add(
          CompletionRecord.fromJson(<String, dynamic>{
            'habitId': r['habit_id'],
            'dateKey': r['date_key'],
            'done': (r['done'] as int? ?? 0) != 0,
            'count': r['count_value'],
            'checkedItemIds': jsonDecode(r['checked_ids_json'] as String),
            'slipped': (r['slipped'] as int? ?? 0) != 0,
            'updatedAt': r['updated_at'],
          }),
        );
      } catch (e) {
        debugPrint('Skipping unreadable completion row: $e');
      }
    }
    return records;
  }

  @override
  Future<void> upsertCompletion(CompletionRecord r) async {
    // Safe to REPLACE: completions are leaf rows and (habit_id, date_key) is
    // the primary key, so there can never be two records for one habit/day.
    await _db.insert(
      'completions',
      <String, Object?>{
        'habit_id': r.habitId,
        'date_key': r.dateKey,
        'done': r.done ? 1 : 0,
        'count_value': r.count,
        'checked_ids_json': jsonEncode(r.checkedItemIds.toList()..sort()),
        'slipped': r.slipped ? 1 : 0,
        'updated_at': r.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteCompletion(String habitId, String dateKey) async {
    await _db.delete(
      'completions',
      where: 'habit_id = ? AND date_key = ?',
      whereArgs: <Object?>[habitId, dateKey],
    );
  }

  // ------------------------------------------------------------------- notes

  @override
  Future<List<Note>> loadNotes() async {
    final List<Map<String, Object?>> rows = await _db.query('notes');
    final List<Note> notes = <Note>[];
    for (final Map<String, Object?> r in rows) {
      try {
        notes.add(
          Note.fromJson(<String, dynamic>{
            'id': r['id'],
            'habitId': r['habit_id'],
            'title': r['title'],
            'body': r['body'],
            'createdAt': r['created_at'],
            'updatedAt': r['updated_at'],
            'photoPaths': jsonDecode(r['photos_json'] as String),
            'audioPaths': jsonDecode(r['audio_json'] as String),
          }),
        );
      } catch (e) {
        debugPrint('Skipping unreadable note row: $e');
      }
    }
    return notes;
  }

  @override
  Future<void> upsertNote(Note n) async {
    await _db.transaction((Transaction txn) async {
      await _upsert(txn, 'notes', <String, Object?>{
        'id': n.id,
        'habit_id': n.habitId,
        'title': n.title,
        'body': n.body,
        'created_at': n.createdAt.toIso8601String(),
        'updated_at': n.updatedAt.toIso8601String(),
        'photos_json': jsonEncode(n.photoPaths),
        'audio_json': jsonEncode(n.audioPaths),
      });
    });
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await _db.delete('notes', where: 'id = ?', whereArgs: <Object?>[noteId]);
  }

  // ------------------------------------------------------------ achievements

  @override
  Future<Map<String, Map<int, String>>> loadAchievements() async {
    final List<Map<String, Object?>> rows = await _db.query('achievements');
    final Map<String, Map<int, String>> result = <String, Map<int, String>>{};
    for (final Map<String, Object?> r in rows) {
      final String habitId = r['habit_id'] as String;
      result.putIfAbsent(habitId, () => <int, String>{})[r['milestone'] as int] =
          r['unlocked_on'] as String;
    }
    return result;
  }

  @override
  Future<void> saveAchievement(
    String habitId,
    int milestone,
    String unlockedOn,
  ) async {
    await _db.insert(
      'achievements',
      <String, Object?>{
        'habit_id': habitId,
        'milestone': milestone,
        'unlocked_on': unlockedOn,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
