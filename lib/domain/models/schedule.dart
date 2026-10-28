import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart';
import 'enums.dart';

/// When a habit is due.
///
/// Weekdays use [DateTime.weekday] numbering: 1 = Monday ... 7 = Sunday.
@immutable
class Schedule {
  const Schedule({
    this.type = FrequencyType.everyday,
    this.weekdays = const <int>{},
    this.monthDays = const <int>{},
    this.timesPerPeriod = 1,
    this.period = PeriodUnit.week,
  });

  const Schedule.everyday() : this();

  final FrequencyType type;
  final Set<int> weekdays;
  final Set<int> monthDays;
  final int timesPerPeriod;
  final PeriodUnit period;

  /// "Some days per period" habits can be done on any day; they are due until
  /// the period's target is reached (evaluated by the streak engine, Stage 3).
  bool get isFlexible => type == FrequencyType.somePerPeriod;

  /// Whether [date] is a day on which this habit is due.
  ///
  /// Day-of-month schedules that include a day beyond the end of a short month
  /// (e.g. the 31st in February) fall on the month's last day instead.
  bool isScheduledOn(DateTime date) {
    switch (type) {
      case FrequencyType.everyday:
        return true;
      case FrequencyType.daysOfWeek:
        return weekdays.contains(date.weekday);
      case FrequencyType.daysOfMonth:
        if (monthDays.contains(date.day)) return true;
        final int last = daysInMonth(date.year, date.month);
        return date.day == last && monthDays.any((int d) => d > last);
      case FrequencyType.somePerPeriod:
        return true;
    }
  }

  /// Returns a human-readable problem, or null when the schedule is valid.
  String? validate() {
    switch (type) {
      case FrequencyType.everyday:
        return null;
      case FrequencyType.daysOfWeek:
        if (weekdays.isEmpty) return 'Select at least one weekday.';
        if (weekdays.any((int d) => d < 1 || d > 7)) {
          return 'Weekdays must be between Monday and Sunday.';
        }
        return null;
      case FrequencyType.daysOfMonth:
        if (monthDays.isEmpty) return 'Select at least one day of the month.';
        if (monthDays.any((int d) => d < 1 || d > 31)) {
          return 'Days of the month must be between 1 and 31.';
        }
        return null;
      case FrequencyType.somePerPeriod:
        final int max = period == PeriodUnit.week ? 7 : 31;
        if (timesPerPeriod < 1 || timesPerPeriod > max) {
          return 'Choose between 1 and $max days per ${period.name}.';
        }
        return null;
    }
  }

  Schedule copyWith({
    FrequencyType? type,
    Set<int>? weekdays,
    Set<int>? monthDays,
    int? timesPerPeriod,
    PeriodUnit? period,
  }) {
    return Schedule(
      type: type ?? this.type,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
      timesPerPeriod: timesPerPeriod ?? this.timesPerPeriod,
      period: period ?? this.period,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'weekdays': (weekdays.toList()..sort()),
        'monthDays': (monthDays.toList()..sort()),
        'timesPerPeriod': timesPerPeriod,
        'period': period.name,
      };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      type: enumByName(FrequencyType.values, json['type'], FrequencyType.everyday),
      weekdays: _intSet(json['weekdays']),
      monthDays: _intSet(json['monthDays']),
      timesPerPeriod: (json['timesPerPeriod'] as num?)?.toInt() ?? 1,
      period: enumByName(PeriodUnit.values, json['period'], PeriodUnit.week),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Schedule &&
      other.type == type &&
      setEquals(other.weekdays, weekdays) &&
      setEquals(other.monthDays, monthDays) &&
      other.timesPerPeriod == timesPerPeriod &&
      other.period == period;

  @override
  int get hashCode => Object.hash(
        type,
        Object.hashAllUnordered(weekdays),
        Object.hashAllUnordered(monthDays),
        timesPerPeriod,
        period,
      );
}

Set<int> _intSet(Object? raw) {
  if (raw is! List) return <int>{};
  return raw.whereType<num>().map((num n) => n.toInt()).toSet();
}
