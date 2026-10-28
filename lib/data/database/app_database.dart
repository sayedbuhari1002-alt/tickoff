import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the app's SQLite database and owns the versioned schema.
///
/// Schema version history:
/// * 1 - initial schema (categories, habits, completions, notes, achievements).
/// * 2 - local tasks and subtasks.
/// * 3 - task completion timestamps and deletion-history snapshots for 30-day analytics.
///
/// To change the schema, bump [version], add a step to [_migrations] that
/// upgrades from the previous version, and keep [_createV1] untouched.
class AppDatabase {
  AppDatabase._();

  static const int version = 3;
  static const String fileName = 'tickoff.db';

  /// Opens (creating if needed) the database. Pass [path] to use another file
  /// or `inMemoryDatabasePath` (tests).
  static Future<Database> open({String? path}) async {
    final String dbPath = path ?? p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (Database db) async {
        // Enforce relationships (cascade deletes, SET NULL on categories).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int newVersion) async {
        await _createV1(db);
        if (newVersion >= 2) await _createV2(db);
        if (newVersion >= 3) await _createV3(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        for (int v = oldVersion; v < newVersion; v++) {
          final Future<void> Function(Database db)? step = _migrations[v];
          if (step != null) await step(db);
        }
      },
    );
  }

  /// Upgrade steps keyed by the version they upgrade FROM (1 -> 2 is key 1).
  static final Map<int, Future<void> Function(Database db)> _migrations =
      <int, Future<void> Function(Database db)>{1: _createV2, 2: _createV3};

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, due_date TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 2, category TEXT NOT NULL DEFAULT '',
        color_value INTEGER NOT NULL DEFAULT 4294911531, icon_code_point INTEGER NOT NULL DEFAULT 57763,
        is_completed INTEGER NOT NULL DEFAULT 0, is_paused INTEGER NOT NULL DEFAULT 0,
        parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE, sort_order INTEGER NOT NULL DEFAULT 0,
        reminder_at TEXT, notes TEXT NOT NULL DEFAULT '', photo_paths TEXT NOT NULL DEFAULT '',
        audio_paths TEXT NOT NULL DEFAULT '', repeat_rule TEXT NOT NULL DEFAULT 'none'
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');
    await db.execute('CREATE INDEX idx_tasks_parent ON tasks(parent_id, sort_order)');
  }

  static Future<void> _createV3(Database db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN completed_at TEXT');
    // Best available migration fallback for tasks completed before Stage 4.
    await db.execute('UPDATE tasks SET completed_at = updated_at WHERE is_completed = 1 AND completed_at IS NULL');
    await db.execute('''
      CREATE TABLE task_history (
        id TEXT PRIMARY KEY,
        due_date TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 2,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        deleted_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_task_history_due ON task_history(due_date)');
  }

  static Future<void> _createV1(Database db) async {
    final Batch batch = db.batch();
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        icon_key TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL,
        tracking TEXT NOT NULL,
        schedule_json TEXT NOT NULL,
        reminder_json TEXT NOT NULL,
        category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
        show_streaks INTEGER NOT NULL DEFAULT 1,
        daily_goal REAL,
        unit TEXT NOT NULL DEFAULT '',
        step REAL NOT NULL DEFAULT 1,
        checklist_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        archived_at TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    // One row per habit and day: the composite primary key makes duplicate
    // completion records impossible.
    batch.execute('''
      CREATE TABLE completions (
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        date_key TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        count_value REAL NOT NULL DEFAULT 0,
        checked_ids_json TEXT NOT NULL DEFAULT '[]',
        slipped INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (habit_id, date_key)
      )''');
    batch.execute(
      'CREATE INDEX idx_completions_date ON completions(date_key)',
    );
    batch.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        habit_id TEXT REFERENCES habits(id) ON DELETE CASCADE,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        photos_json TEXT NOT NULL DEFAULT '[]',
        audio_json TEXT NOT NULL DEFAULT '[]'
      )''');
    batch.execute('CREATE INDEX idx_notes_habit ON notes(habit_id)');
    batch.execute('''
      CREATE TABLE achievements (
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        milestone INTEGER NOT NULL,
        unlocked_on TEXT NOT NULL,
        PRIMARY KEY (habit_id, milestone)
      )''');
    await batch.commit(noResult: true);
  }
}
