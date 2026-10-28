import '../../domain/models/models.dart';

/// Everything the app persists. The only implementation shipped in the app is
/// `SqliteAppRepository`; tests also use an in-memory version of this
/// interface for fast widget tests.
abstract class AppRepository {
  // Habits
  Future<List<Habit>> loadHabits();

  /// Inserts or updates a habit (never replaces, so history is kept).
  Future<void> upsertHabit(Habit habit);

  /// Deletes a habit with its completions, achievements and notes.
  Future<void> deleteHabit(String habitId);

  // Categories
  Future<List<HabitCategory>> loadCategories();
  Future<void> upsertCategory(HabitCategory category);

  /// Deletes a category; habits in it become uncategorised.
  Future<void> deleteCategory(String categoryId);

  // Completions (one record per habit and day)
  Future<List<CompletionRecord>> loadCompletions();
  Future<void> upsertCompletion(CompletionRecord record);
  Future<void> deleteCompletion(String habitId, String dateKey);

  // Notes
  Future<List<Note>> loadNotes();
  Future<void> upsertNote(Note note);
  Future<void> deleteNote(String noteId);

  // Achievements: habitId -> milestone -> `yyyy-MM-dd` unlocked on
  Future<Map<String, Map<int, String>>> loadAchievements();
  Future<void> saveAchievement(String habitId, int milestone, String unlockedOn);
}
