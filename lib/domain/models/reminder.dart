import 'package:flutter/foundation.dart';

/// A daily reminder: a time of day plus the weekdays it fires on
/// (1 = Monday ... 7 = Sunday).
@immutable
class Reminder {
  const Reminder({
    this.enabled = false,
    this.minutesOfDay = 9 * 60,
    this.weekdays = const <int>{1, 2, 3, 4, 5, 6, 7},
  });

  final bool enabled;

  /// Minutes after midnight, 0..1439 (09:00 = 540).
  final int minutesOfDay;
  final Set<int> weekdays;

  int get hour => minutesOfDay ~/ 60;
  int get minute => minutesOfDay % 60;

  /// `09:00` style label as shown in the form.
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Reminder copyWith({
    bool? enabled,
    int? minutesOfDay,
    Set<int>? weekdays,
  }) {
    return Reminder(
      enabled: enabled ?? this.enabled,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      weekdays: weekdays ?? this.weekdays,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'minutesOfDay': minutesOfDay,
        'weekdays': (weekdays.toList()..sort()),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final Object? rawDays = json['weekdays'];
    final Set<int> days = rawDays is List
        ? rawDays.whereType<num>().map((num n) => n.toInt()).toSet()
        : <int>{1, 2, 3, 4, 5, 6, 7};
    final int rawMinutes = (json['minutesOfDay'] as num?)?.toInt() ?? 9 * 60;
    return Reminder(
      enabled: json['enabled'] == true,
      minutesOfDay: rawMinutes < 0 || rawMinutes > 1439 ? 9 * 60 : rawMinutes,
      weekdays: days,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.enabled == enabled &&
      other.minutesOfDay == minutesOfDay &&
      setEquals(other.weekdays, weekdays);

  @override
  int get hashCode =>
      Object.hash(enabled, minutesOfDay, Object.hashAllUnordered(weekdays));
}
