import '../../core/utils/date_utils.dart';
import '../../domain/models/models.dart';

/// `3` for whole numbers, `2.5` otherwise.
String formatNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  String s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// `1 day` / `5 days`.
String daysLabel(int n) => n == 1 ? '1 day' : '$n days';

/// `0%`, `67%`.
String percentLabel(double fraction) => '${(fraction * 100).round()}%';

/// Human-readable frequency of a habit (Habit Info, chips).
String frequencyLabel(Habit habit) {
  if (habit.type == HabitType.quit) return 'Everyday';
  final Schedule s = habit.schedule;
  switch (s.type) {
    case FrequencyType.everyday:
      return 'Everyday';
    case FrequencyType.daysOfWeek:
      return s.weekdays.length == 7 ? 'Everyday' : weekdayList(s.weekdays);
    case FrequencyType.daysOfMonth:
      final List<int> days = s.monthDays.toList()..sort();
      return 'Day ${days.join(', ')} of the month';
    case FrequencyType.somePerPeriod:
      return '${s.timesPerPeriod} ${s.timesPerPeriod == 1 ? 'day' : 'days'} per ${s.period.name}';
  }
}

/// `Simple` / `Count` / `Checklist` as shown in Habit Info.
String trackingLabel(Habit habit) {
  switch (habit.tracking) {
    case TrackingMethod.tick:
      return 'Simple';
    case TrackingMethod.count:
      return 'Count';
    case TrackingMethod.checklist:
      return 'Checklist';
  }
}

/// `3/8 glasses` for count habits.
String countLabel(Habit habit, double count) {
  final String unit = habit.unit.isEmpty ? '' : ' ${habit.unit}';
  final double? goal = habit.dailyGoal;
  return goal == null
      ? '${formatNumber(count)}$unit'
      : '${formatNumber(count)}/${formatNumber(goal)}$unit';
}
