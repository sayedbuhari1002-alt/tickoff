import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../state/app_data.dart';
import 'format.dart';

/// Plain-text progress summary for all active habits.
String overallProgressText({
  required AppData data,
  required Map<String, HabitStats> stats,
  required double overallScorePercent,
  required DateTime today,
}) {
  final StringBuffer b = StringBuffer()
    ..writeln('TickOff progress - ${dayMonthLabel(today)} ${today.year}')
    ..writeln('Habit score: ${overallScorePercent.toStringAsFixed(1)}%');
  final List<Habit> habits = data.activeHabits;
  if (habits.isEmpty) {
    b.writeln('No habits yet.');
  }
  for (final Habit h in habits) {
    final HabitStats s = stats[h.id] ?? HabitStats.empty;
    b.writeln(
      '- ${h.title}: streak ${daysLabel(s.currentStreak)} '
      '(best ${daysLabel(s.bestStreak)}), score ${percentLabel(s.score)}',
    );
  }
  return b.toString().trimRight();
}

/// Plain-text progress summary for one habit.
String habitProgressText({
  required Habit habit,
  required HabitStats stats,
  required DateTime today,
}) {
  return (StringBuffer()
        ..writeln('${habit.title} - ${dayMonthLabel(today)} ${today.year}')
        ..writeln('Current streak: ${daysLabel(stats.currentStreak)}')
        ..writeln('Best streak: ${daysLabel(stats.bestStreak)}')
        ..writeln('Score: ${percentLabel(stats.score)}')
        ..writeln('Completed days: ${stats.totalCompletions}')
        ..write('Frequency: ${frequencyLabel(habit)}'))
      .toString();
}
