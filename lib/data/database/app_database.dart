import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the app's SQLite database and owns the versioned schema.
///
/// Schema version history:
/// * 1 - initial schema (categories, habits, completions, notes, achievements).
/// * 2 - local tasks and subtasks.
/// * 3 - task completion timestamps and deletion-history snapshots.
/// * 4 - immutable task/subtask completion activity snapshots for historical analytics.
/// * 5 - richer deletion snapshots so deleted subtasks remain in analytics.
/// * 6 - reminder/pause state snapshots in the activity log.
///
/// To change the schema, bump [version], add a step to [_migrations] that
/// upgrades from the previous version, and keep [_createV1] untouched.
class AppDatabase {
  AppDatabase._();

  static const int version = 6;
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
        if (newVersion >= 4) await _createV4(db);
        if (newVersion >= 5) await _createV5(db);
        if (newVersion >= 6) await _createV6(db);
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
      <int, Future<void> Function(Database db)>{1: _createV2, 2: _createV3, 3: _createV4, 4: _createV5, 5: _createV6};

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

  static Future<void> _createV6(Database db) async {
    await db.execute('ALTER TABLE task_activity ADD COLUMN reminder_at TEXT');
    await db.execute('ALTER TABLE task_activity ADD COLUMN is_paused INTEGER NOT NULL DEFAULT 0');
    // Recover reminder and pause state for active Stage 4 task snapshots.
    await db.execute('''
      UPDATE task_activity
      SET reminder_at = (SELECT reminder_at FROM tasks WHERE tasks.id = task_activity.task_id),
          is_paused = COALESCE((SELECT is_paused FROM tasks WHERE tasks.id = task_activity.task_id), 0)
      WHERE task_id IN (SELECT id FROM tasks)
    ''');
  }

  static Future<void> _createV5(Database db) async {
    await db.execute("ALTER TABLE task_history ADD COLUMN title TEXT NOT NULL DEFAULT 'Deleted task'");
    await db.execute('ALTER TABLE task_history ADD COLUMN parent_id TEXT');
    await db.execute("ALTER TABLE task_history ADD COLUMN category TEXT NOT NULL DEFAULT ''");
    await db.execute('CREATE INDEX idx_task_history_deleted ON task_history(deleted_at)');
  }

  static Future<void> _createV4(Database db) async {
    await db.execute('''
      CREATE TABLE task_activity (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        due_date TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 2,
        activity_type TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        parent_id TEXT,
        category TEXT NOT NULL DEFAULT '',
        created_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_task_activity_occurred ON task_activity(occurred_at)');
    await db.execute('CREATE INDEX idx_task_activity_task ON task_activity(task_id, occurred_at)');
    await db.execute('CREATE INDEX idx_task_activity_due ON task_activity(due_date)');
    // Backfill immutable snapshots for Stage 4 tasks before future edits can
    // change their current deadline/title. Existing completion timestamps are
    // used as the best available historical completion dates.
    await db.execute('''
      INSERT OR IGNORE INTO task_activity
        (id, task_id, title, due_date, priority, activity_type, occurred_at, parent_id, category, created_at)
      SELECT 'legacy-created-' || id, id, title, due_date, priority, 'created', created_at, parent_id, category, created_at
      FROM tasks
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO task_activity
        (id, task_id, title, due_date, priority, activity_type, occurred_at, parent_id, category, created_at)
      SELECT 'legacy-completed-' || id, id, title, due_date, priority, 'completed', completed_at, parent_id, category, created_at
      FROM tasks WHERE is_completed = 1 AND completed_at IS NOT NULL
    ''');
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
