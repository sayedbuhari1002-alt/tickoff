import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/repositories/app_repository.dart';
import '../domain/logic/achievements.dart';
import '../domain/logic/habit_engine.dart';
import '../domain/models/models.dart';
import '../shared/utils/local_notifications.dart';
import '../shared/utils/local_attachments.dart';
import 'app_data.dart';

/// The persistence layer. `main.dart` overrides this with the SQLite
/// repository; tests override it with an in-memory one.
final Provider<AppRepository> repositoryProvider = Provider<AppRepository>(
  (Ref ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

/// The current calendar day. Refreshes itself just after midnight.
final Provider<DateTime> todayProvider = Provider<DateTime>((Ref ref) {
  final DateTime now = DateTime.now();
  final DateTime today = dateOnly(now);
  final Timer timer = Timer(
    addDays(today, 1).difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return today;
});

/// Streak / completion / score rules bound to today's date.
final Provider<HabitEngine> habitEngineProvider = Provider<HabitEngine>(
  (Ref ref) => HabitEngine(today: ref.watch(todayProvider)),
);

/// Loads everything from the repository and exposes all changes. Every write
/// goes to the database first and only then updates in-memory state, so what
/// is on screen is always what is stored.
class AppDataNotifier extends AsyncNotifier<AppData> {
  AppRepository get _repo => ref.read(repositoryProvider);

  HabitEngine get _engine => HabitEngine(today: ref.read(todayProvider));

  @override
  Future<AppData> build() async {
    final AppRepository repo = ref.watch(repositoryProvider);
    final List<Habit> habits = await repo.loadHabits();
    final List<HabitCategory> categories = await repo.loadCategories();
    final List<CompletionRecord> records = await repo.loadCompletions();
    final List<Note> notes = await repo.loadNotes();
    final Map<String, Map<int, String>> achievements =
        await repo.loadAchievements();

    final Map<String, Map<String, CompletionRecord>> index =
        <String, Map<String, CompletionRecord>>{};
    for (final CompletionRecord r in records) {
      index.putIfAbsent(r.habitId, () => <String, CompletionRecord>{})[r.dateKey] = r;
    }

    AppData data = AppData(
      habits: habits,
      categories: categories,
      completions: index,
      achievements: achievements,
      notes: notes,
    );
    // Restore scheduled reminders for existing habits after app restart.
    for (final Habit h in habits) {
      try {
        if (h.reminder.enabled && !h.isArchived) { await LocalNotifications.instance.scheduleHabit(id: h.id, title: h.title, hour: h.reminder.hour, minute: h.reminder.minute, weekdays: h.reminder.weekdays); } else { await LocalNotifications.instance.cancel(h.id); }
      } catch (_) { /* reminder restoration must not block the habit tracker */ }
    }
    // Back-fill achievements reached before this version stored them.
    for (final Habit h in habits.where((Habit h) => !h.isArchived)) {
      data = await _syncAchievements(data, h);
    }
    return data;
  }

  AppData get _current {
    final AppData? data = state.valueOrNull;
    if (data == null) throw StateError('App data is not loaded yet.');
    return data;
  }

  /// Re-reads everything from the database.
  Future<void> reload() async {
    state = const AsyncLoading<AppData>();
    state = await AsyncValue.guard(build);
  }

  // ------------------------------------------------------------- achievements

  Future<AppData> _syncAchievements(AppData data, Habit habit) async {
    final HabitStats stats = _engine.stats(habit, data.recordsFor(habit.id));
    final Map<int, String> existing = data.achievementsFor(habit.id);
    final List<int> reached = newlyReached(stats.bestStreak, existing.keys);
    if (reached.isEmpty) return data;
    final String today = dateKey(ref.read(todayProvider));
    final Map<int, String> updated = Map<int, String>.of(existing);
    for (final int m in reached) {
      await _repo.saveAchievement(habit.id, m, today);
      updated[m] = today;
    }
    final Map<String, Map<int, String>> all =
        Map<String, Map<int, String>>.of(data.achievements);
    all[habit.id] = updated;
    return data.copyWith(achievements: all);
  }

  // ------------------------------------------------------------------ habits

  /// Creates or updates a habit after validating it.
  Future<void> saveHabit(Habit habit) async {
    final String? problem = habit.validate();
    if (problem != null) throw ArgumentError(problem);
    await _repo.upsertHabit(habit);
    try {
      if (habit.reminder.enabled && !habit.isArchived) {
        await LocalNotifications.instance.scheduleHabit(id: habit.id, title: habit.title, hour: habit.reminder.hour, minute: habit.reminder.minute, weekdays: habit.reminder.weekdays);
      } else {
        await LocalNotifications.instance.cancel(habit.id);
      }
    } catch (_) { /* keep the habit save successful if notifications are unavailable */ }
    AppData data = _current;
    final List<Habit> habits = List<Habit>.of(data.habits);
    final int i = habits.indexWhere((Habit h) => h.id == habit.id);
    if (i >= 0) {
      habits[i] = habit;
    } else {
      habits.add(habit);
    }
    data = data.copyWith(habits: habits);
    data = await _syncAchievements(data, habit);
    state = AsyncData<AppData>(data);
  }

  Future<void> setArchived(String habitId, bool archived) async {
    final Habit? habit = _current.habitById(habitId);
    if (habit == null) return;
    await saveHabit(
      archived
          ? habit.copyWith(archivedAt: DateTime.now())
          : habit.copyWith(clearArchived: true),
    );
  }

  /// Permanently deletes a habit, its history, achievements and notes.
  Future<void> deleteHabit(String habitId) async {
    try { await LocalNotifications.instance.cancel(habitId); } catch (_) { /* deleting a habit must not depend on notification availability */ }
    for (final Note note in _current.notes.where((Note n) => n.habitId == habitId)) { for (final String path in note.photoPaths) { await LocalAttachments.deleteFile(path); } for (final String path in note.audioPaths) { await LocalAttachments.deleteFile(path); } }
    await _repo.deleteHabit(habitId);
    final AppData data = _current;
    final Map<String, Map<String, CompletionRecord>> completions =
        Map<String, Map<String, CompletionRecord>>.of(data.completions)
          ..remove(habitId);
    final Map<String, Map<int, String>> achievements =
        Map<String, Map<int, String>>.of(data.achievements)..remove(habitId);
    state = AsyncData<AppData>(
      data.copyWith(
        habits: data.habits.where((Habit h) => h.id != habitId).toList(),
        completions: completions,
        achievements: achievements,
        notes: data.notes.where((Note n) => n.habitId != habitId).toList(),
      ),
    );
  }

  // -------------------------------------------------------------- completions

  Future<void> _edit(
    Habit habit,
    DateTime date,
    CompletionRecord Function(CompletionRecord base) change,
  ) async {
    final AppData data = _current;
    final String key = dateKey(date);
    final DateTime now = DateTime.now();
    final CompletionRecord base =
        data.recordsFor(habit.id)[key] ??
        CompletionRecord(habitId: habit.id, dateKey: key, updatedAt: now);
    final CompletionRecord updated = change(base).copyWith(updatedAt: now);

    final Map<String, CompletionRecord> forHabit =
        Map<String, CompletionRecord>.of(data.recordsFor(habit.id));
    if (updated.isBlank) {
      await _repo.deleteCompletion(habit.id, key);
      forHabit.remove(key);
    } else {
      await _repo.upsertCompletion(updated);
      forHabit[key] = updated;
    }
    final Map<String, Map<String, CompletionRecord>> all =
        Map<String, Map<String, CompletionRecord>>.of(data.completions);
    all[habit.id] = forHabit;
    AppData next = data.copyWith(completions: all);
    next = await _syncAchievements(next, habit);
    state = AsyncData<AppData>(next);
  }

  /// Tick habits: toggles done (Build) or slipped (Quit).
  Future<void> toggleTick(Habit habit, DateTime date) {
    return _edit(habit, date, (CompletionRecord r) {
      return habit.type == HabitType.quit
          ? r.copyWith(slipped: !r.slipped)
          : r.copyWith(done: !r.done);
    });
  }

  /// Count habits: adds [delta] (may be negative); never below zero.
  Future<void> addCount(Habit habit, DateTime date, double delta) {
    return _edit(habit, date, (CompletionRecord r) {
      return r.copyWith(count: _clean(r.count + delta));
    });
  }

  Future<void> setCount(Habit habit, DateTime date, double value) {
    if (value.isNaN || value < 0) {
      throw ArgumentError('The count must be zero or more.');
    }
    return _edit(habit, date, (CompletionRecord r) {
      return r.copyWith(count: _clean(value));
    });
  }

  /// Checklist habits: ticks/unticks one item (Quit: marks/unmarks a slip).
  Future<void> toggleChecklistItem(Habit habit, DateTime date, String itemId) {
    return _edit(habit, date, (CompletionRecord r) {
      final Set<String> ids = Set<String>.of(r.checkedItemIds);
      if (!ids.add(itemId)) ids.remove(itemId);
      return r.copyWith(checkedItemIds: ids);
    });
  }

  static double _clean(double v) {
    final double rounded = (v * 10000).round() / 10000;
    return rounded < 0 ? 0 : rounded;
  }

  // -------------------------------------------------------------- categories

  Future<void> saveCategory(HabitCategory category) async {
    if (category.name.trim().isEmpty) {
      throw ArgumentError('Please enter a category name.');
    }
    await _repo.upsertCategory(category);
    final AppData data = _current;
    final List<HabitCategory> list = List<HabitCategory>.of(data.categories);
    final int i = list.indexWhere((HabitCategory c) => c.id == category.id);
    if (i >= 0) {
      list[i] = category;
    } else {
      list.add(category);
    }
    state = AsyncData<AppData>(data.copyWith(categories: list));
  }

  Future<void> deleteCategory(String categoryId) async {
    await _repo.deleteCategory(categoryId);
    final AppData data = _current;
    state = AsyncData<AppData>(
      data.copyWith(
        categories:
            data.categories.where((HabitCategory c) => c.id != categoryId).toList(),
        habits: data.habits
            .map((Habit h) =>
                h.categoryId == categoryId ? h.copyWith(clearCategory: true) : h)
            .toList(),
      ),
    );
  }

  // ------------------------------------------------------------------- notes

  Future<void> saveNote(Note note) async {
    await _repo.upsertNote(note);
    final AppData data = _current;
    final List<Note> list = List<Note>.of(data.notes);
    final int i = list.indexWhere((Note n) => n.id == note.id);
    if (i >= 0) {
      list[i] = note;
    } else {
      list.add(note);
    }
    state = AsyncData<AppData>(data.copyWith(notes: list));
  }

  Future<void> deleteNote(String noteId) async {
    await _repo.deleteNote(noteId);
    final AppData data = _current;
    state = AsyncData<AppData>(
      data.copyWith(notes: data.notes.where((Note n) => n.id != noteId).toList()),
    );
  }
}

final AsyncNotifierProvider<AppDataNotifier, AppData> appDataProvider =
    AsyncNotifierProvider<AppDataNotifier, AppData>(AppDataNotifier.new);

/// Stats for every habit, recomputed only when data or the date changes.
final Provider<Map<String, HabitStats>> habitStatsProvider =
    Provider<Map<String, HabitStats>>((Ref ref) {
  final AppData? data = ref.watch(appDataProvider).valueOrNull;
  if (data == null) return const <String, HabitStats>{};
  final HabitEngine engine = ref.watch(habitEngineProvider);
  return <String, HabitStats>{
    for (final Habit h in data.habits)
      h.id: engine.stats(h, data.recordsFor(h.id)),
  };
});

/// Overall Habit Score as a percentage (0..100).
final Provider<double> overallScoreProvider = Provider<double>((Ref ref) {
  final AppData? data = ref.watch(appDataProvider).valueOrNull;
  if (data == null) return 0;
  final Map<String, HabitStats> stats = ref.watch(habitStatsProvider);
  final HabitEngine engine = ref.watch(habitEngineProvider);
  final Iterable<HabitStats> active = data.activeHabits
      .map((Habit h) => stats[h.id])
      .whereType<HabitStats>();
  return engine.overallScore(active) * 100;
});
