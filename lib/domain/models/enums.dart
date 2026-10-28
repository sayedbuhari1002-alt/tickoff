/// Build a Habit = do it regularly. Quit a Habit = completed by default, the
/// user only marks the days they slipped (streak counts slip-free days).
enum HabitType { build, quit }

/// How a day is completed: single tap, numeric target, or checklist.
enum TrackingMethod { tick, count, checklist }

/// The four frequency options shown in the Add Habit form.
enum FrequencyType { everyday, daysOfWeek, daysOfMonth, somePerPeriod }

/// Period used by [FrequencyType.somePerPeriod] ("3 days per week").
enum PeriodUnit { week, month }

/// Looks up an enum value by [name], returning [fallback] when it is unknown.
/// Used when reading stored data so an unexpected value never crashes the app.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
