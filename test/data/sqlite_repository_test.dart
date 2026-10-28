import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';
import 'package:tickoff_replacement/data/database/app_database.dart';
import 'package:tickoff_replacement/data/repositories/sqlite_app_repository.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

/// These tests run the real SQLite schema and repository through
/// sqflite_common_ffi (SQLite on the build machine), not on a phone.

Habit makeHabit({String id = 'h1', String? categoryId}) {
  return Habit(
    id: id,
    title: 'Reading Books',
    description: 'Read every day',
    createdAt: DateTime(2026, 10, 26, 8, 30),
    iconKey: 'menu_book',
    colorValue: 0xFFFFC62B,
    type: HabitType.build,
    tracking: TrackingMethod.checklist,
    schedule: const Schedule(
      type: FrequencyType.daysOfWeek,
      weekdays: <int>{1, 3, 5},
    ),
    reminder: const Reminder(enabled: true, minutesOfDay: 21 * 60),
    categoryId: categoryId,
    showStreaksOnTimeline: false,
    dailyGoal: 2.5,
    unit: 'pages',
    step: 0.5,
    checklist: const <ChecklistItem>[
      ChecklistItem(id: 'c1', title: 'Chapter'),
      ChecklistItem(
        id: 'c2',
        title: 'Notes',
        reminder: Reminder(enabled: true, minutesOfDay: 600),
      ),
    ],
    sortOrder: 3,
  );
}

CompletionRecord record(String habitId, String key, {double count = 0}) {
  return CompletionRecord(
    habitId: habitId,
    dateKey: key,
    updatedAt: DateTime(2026, 10, 27),
    done: true,
    count: count,
    checkedItemIds: const <String>{'c1'},
  );
}

Future<int> countRows(Database db, String table) async {
  final List<Map<String, Object?>> rows =
      await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return Sqflite.firstIntValue(rows) ?? -1;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteAppRepository repo;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = SqliteAppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('schema is created at the current version', () async {
    expect(await db.getVersion(), AppDatabase.version);
    final List<Map<String, Object?>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final Set<String> names =
        tables.map((Map<String, Object?> r) => r['name'] as String).toSet();
    expect(
      names,
      containsAll(<String>[
        'habits',
        'categories',
        'completions',
        'notes',
        'achievements',
      ]),
    );
  });

  test('a habit round-trips with every configuration field', () async {
    await repo.upsertCategory(const HabitCategory(id: 'cat', name: 'Mind'));
    final Habit h = makeHabit(categoryId: 'cat');
    await repo.upsertHabit(h);
    final List<Habit> loaded = await repo.loadHabits();
    expect(loaded.length, 1);
    expect(loaded.single, h);
  });

  test('updating a habit keeps its history (no cascade wipe)', () async {
    final Habit h = makeHabit();
    await repo.upsertHabit(h);
    await repo.upsertCompletion(record(h.id, '2026-10-26'));
    await repo.saveAchievement(h.id, 1, '2026-10-26');
    await repo.upsertNote(
      Note(
        id: 'n1',
        habitId: h.id,
        createdAt: DateTime(2026, 10, 26),
        updatedAt: DateTime(2026, 10, 26),
      ),
    );

    await repo.upsertHabit(h.copyWith(title: 'Renamed'));

    expect((await repo.loadHabits()).single.title, 'Renamed');
    expect(await countRows(db, 'habits'), 1);
    expect(await countRows(db, 'completions'), 1);
    expect(await countRows(db, 'achievements'), 1);
    expect(await countRows(db, 'notes'), 1);
  });

  test('there is never more than one completion per habit and day', () async {
    await repo.upsertHabit(makeHabit());
    await repo.upsertCompletion(record('h1', '2026-10-27', count: 1));
    await repo.upsertCompletion(record('h1', '2026-10-27', count: 5));
    expect(await countRows(db, 'completions'), 1);
    final List<CompletionRecord> all = await repo.loadCompletions();
    expect(all.single.count, 5);
    expect(all.single.checkedItemIds, <String>{'c1'});

    await repo.upsertCompletion(record('h1', '2026-10-28'));
    expect(await countRows(db, 'completions'), 2);

    await repo.deleteCompletion('h1', '2026-10-27');
    expect(await countRows(db, 'completions'), 1);
  });

  test('completion fields survive a round trip', () async {
    await repo.upsertHabit(makeHabit());
    final CompletionRecord r = CompletionRecord(
      habitId: 'h1',
      dateKey: '2026-10-27',
      updatedAt: DateTime(2026, 10, 27, 19, 3),
      done: true,
      count: 4.5,
      checkedItemIds: const <String>{'c1', 'c2'},
      slipped: true,
    );
    await repo.upsertCompletion(r);
    expect((await repo.loadCompletions()).single, r);
  });

  test('deleting a habit removes its completions, achievements and notes',
      () async {
    await repo.upsertHabit(makeHabit(id: 'a'));
    await repo.upsertHabit(makeHabit(id: 'b'));
    for (final String id in <String>['a', 'b']) {
      await repo.upsertCompletion(record(id, '2026-10-27'));
      await repo.saveAchievement(id, 1, '2026-10-27');
      await repo.upsertNote(
        Note(
          id: 'note-$id',
          habitId: id,
          createdAt: DateTime(2026, 10, 27),
          updatedAt: DateTime(2026, 10, 27),
        ),
      );
    }
    await repo.deleteHabit('a');
    expect(await countRows(db, 'habits'), 1);
    expect(await countRows(db, 'completions'), 1);
    expect(await countRows(db, 'achievements'), 1);
    expect(await countRows(db, 'notes'), 1);
    expect((await repo.loadCompletions()).single.habitId, 'b');
  });

  test('deleting a category keeps habits and clears their category', () async {
    await repo.upsertCategory(const HabitCategory(id: 'cat', name: 'Mind'));
    await repo.upsertHabit(makeHabit(categoryId: 'cat'));
    await repo.deleteCategory('cat');
    expect(await countRows(db, 'categories'), 0);
    final Habit h = (await repo.loadHabits()).single;
    expect(h.categoryId, isNull);
  });

  test('relationships are enforced: no completion for an unknown habit',
      () async {
    expect(
      () => repo.upsertCompletion(record('ghost', '2026-10-27')),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('achievements are stored once; the first unlock date wins', () async {
    await repo.upsertHabit(makeHabit());
    await repo.saveAchievement('h1', 7, '2026-10-01');
    await repo.saveAchievement('h1', 7, '2026-10-20');
    await repo.saveAchievement('h1', 14, '2026-10-20');
    final Map<String, Map<int, String>> all = await repo.loadAchievements();
    expect(all['h1'], <int, String>{7: '2026-10-01', 14: '2026-10-20'});
  });

  test('notes round-trip including attachment references', () async {
    await repo.upsertHabit(makeHabit());
    final Note n = Note(
      id: 'n1',
      habitId: 'h1',
      title: 'Idea',
      body: 'Line 1\nLine 2',
      createdAt: DateTime(2026, 10, 26, 9),
      updatedAt: DateTime(2026, 10, 27, 10),
      photoPaths: const <String>['/data/p1.jpg'],
      audioPaths: const <String>['/data/a1.m4a', '/data/a2.m4a'],
    );
    await repo.upsertNote(n);
    expect((await repo.loadNotes()).single, n);

    await repo.upsertNote(n.copyWith(title: 'Edited'));
    expect(await countRows(db, 'notes'), 1);
    expect((await repo.loadNotes()).single.title, 'Edited');

    await repo.deleteNote('n1');
    expect(await repo.loadNotes(), isEmpty);
  });

  test('a standalone note (no habit) is allowed', () async {
    final Note n = Note(
      id: 'free',
      title: 'Loose thought',
      createdAt: DateTime(2026, 10, 27),
      updatedAt: DateTime(2026, 10, 27),
    );
    await repo.upsertNote(n);
    expect((await repo.loadNotes()).single.habitId, isNull);
  });

  test('data survives closing and reopening the database file', () async {
    final Directory dir = Directory.systemTemp.createTempSync('tickoff_db_');
    final String path = p.join(dir.path, 'restart.db');
    try {
      Database first = await AppDatabase.open(path: path);
      SqliteAppRepository r1 = SqliteAppRepository(first);
      await r1.upsertCategory(const HabitCategory(id: 'cat', name: 'Mind'));
      await r1.upsertHabit(makeHabit(categoryId: 'cat'));
      await r1.upsertCompletion(record('h1', dateKey(DateTime(2026, 10, 27))));
      await r1.saveAchievement('h1', 1, '2026-10-27');
      await first.close();

      final Database second = await AppDatabase.open(path: path);
      final SqliteAppRepository r2 = SqliteAppRepository(second);
      expect((await r2.loadHabits()).single.title, 'Reading Books');
      expect((await r2.loadCategories()).single.name, 'Mind');
      expect((await r2.loadCompletions()).single.dateKey, '2026-10-27');
      expect((await r2.loadAchievements())['h1'], <int, String>{1: '2026-10-27'});
      await second.close();
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
