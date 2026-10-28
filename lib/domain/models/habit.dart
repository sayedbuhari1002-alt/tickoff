import 'package:flutter/foundation.dart';

import '../../core/utils/ids.dart';
import 'checklist_item.dart';
import 'enums.dart';
import 'reminder.dart';
import 'schedule.dart';

/// A habit as configured in the Add/Edit Habit form.
///
/// Completion data is stored separately in `CompletionRecord`s so editing or
/// archiving a habit never rewrites its history.
@immutable
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description = '',
    this.iconKey = defaultIconKey,
    this.colorValue = defaultColorValue,
    this.type = HabitType.build,
    this.tracking = TrackingMethod.tick,
    this.schedule = const Schedule(),
    this.reminder = const Reminder(),
    this.categoryId,
    this.showStreaksOnTimeline = true,
    this.dailyGoal,
    this.unit = '',
    this.step = 1,
    this.checklist = const <ChecklistItem>[],
    this.archivedAt,
    this.sortOrder = 0,
  });

  /// Icon shown by default in the form (resolved by the icon catalogue, Stage 2).
  static const String defaultIconKey = 'medical_services';

  /// 0xFFE0F7FA, the pale cyan swatch selected by default in the form.
  static const int defaultColorValue = 0xFFE0F7FA;

  /// Creates a new habit with a fresh id and today's creation time.
  factory Habit.create({
    required String title,
    String description = '',
    String iconKey = defaultIconKey,
    int colorValue = defaultColorValue,
    HabitType type = HabitType.build,
    TrackingMethod tracking = TrackingMethod.tick,
    Schedule schedule = const Schedule(),
    Reminder reminder = const Reminder(),
    String? categoryId,
    bool showStreaksOnTimeline = true,
    double? dailyGoal,
    String unit = '',
    double step = 1,
    List<ChecklistItem> checklist = const <ChecklistItem>[],
    int sortOrder = 0,
    DateTime? now,
  }) {
    return Habit(
      id: newId(),
      title: title.trim(),
      description: description.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      type: type,
      tracking: tracking,
      schedule: schedule,
      reminder: reminder,
      categoryId: categoryId,
      showStreaksOnTimeline: showStreaksOnTimeline,
      dailyGoal: dailyGoal,
      unit: unit.trim(),
      step: step,
      checklist: checklist,
      sortOrder: sortOrder,
      createdAt: now ?? DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final int colorValue;
  final HabitType type;
  final TrackingMethod tracking;
  final Schedule schedule;
  final Reminder reminder;
  final String? categoryId;
  final bool showStreaksOnTimeline;

  /// Count habits: the amount that completes the day (null = no goal set).
  final double? dailyGoal;
  final String unit;

  /// Count habits: amount added by each tap.
  final double step;

  /// Checklist habits: the items to tick. The day is done when all are ticked.
  final List<ChecklistItem> checklist;

  final DateTime createdAt;
  final DateTime? archivedAt;
  final int sortOrder;

  bool get isArchived => archivedAt != null;

  /// Returns the first problem found, or null when the habit can be saved.
  String? validate() {
    if (title.trim().isEmpty) return 'Please enter a habit title.';
    final String? scheduleError = schedule.validate();
    if (scheduleError != null) return scheduleError;
    if (tracking == TrackingMethod.count) {
      if (dailyGoal != null && dailyGoal! <= 0) {
        return 'The daily goal must be greater than zero.';
      }
      if (step <= 0) return 'Each tap must add more than zero.';
    }
    if (tracking == TrackingMethod.checklist) {
      if (checklist.isEmpty) return 'Add at least one checklist item.';
      if (checklist.any((ChecklistItem i) => i.title.trim().isEmpty)) {
        return 'Checklist items need a title.';
      }
    }
    return null;
  }

  Habit copyWith({
    String? title,
    String? description,
    String? iconKey,
    int? colorValue,
    HabitType? type,
    TrackingMethod? tracking,
    Schedule? schedule,
    Reminder? reminder,
    String? categoryId,
    bool clearCategory = false,
    bool? showStreaksOnTimeline,
    double? dailyGoal,
    bool clearDailyGoal = false,
    String? unit,
    double? step,
    List<ChecklistItem>? checklist,
    DateTime? archivedAt,
    bool clearArchived = false,
    int? sortOrder,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      tracking: tracking ?? this.tracking,
      schedule: schedule ?? this.schedule,
      reminder: reminder ?? this.reminder,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      showStreaksOnTimeline:
          showStreaksOnTimeline ?? this.showStreaksOnTimeline,
      dailyGoal: clearDailyGoal ? null : (dailyGoal ?? this.dailyGoal),
      unit: unit ?? this.unit,
      step: step ?? this.step,
      checklist: checklist ?? this.checklist,
      createdAt: createdAt,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'type': type.name,
        'tracking': tracking.name,
        'schedule': schedule.toJson(),
        'reminder': reminder.toJson(),
        'categoryId': categoryId,
        'showStreaksOnTimeline': showStreaksOnTimeline,
        'dailyGoal': dailyGoal,
        'unit': unit,
        'step': step,
        'checklist': checklist.map((ChecklistItem i) => i.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final Object? rawSchedule = json['schedule'];
    final Object? rawReminder = json['reminder'];
    final Object? rawChecklist = json['checklist'];
    final String? rawArchived = json['archivedAt'] as String?;
    return Habit(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      iconKey: (json['iconKey'] as String?) ?? defaultIconKey,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? defaultColorValue,
      type: enumByName(HabitType.values, json['type'], HabitType.build),
      tracking:
          enumByName(TrackingMethod.values, json['tracking'], TrackingMethod.tick),
      schedule: rawSchedule is Map<String, dynamic>
          ? Schedule.fromJson(rawSchedule)
          : const Schedule(),
      reminder: rawReminder is Map<String, dynamic>
          ? Reminder.fromJson(rawReminder)
          : const Reminder(),
      categoryId: json['categoryId'] as String?,
      showStreaksOnTimeline: json['showStreaksOnTimeline'] != false,
      dailyGoal: (json['dailyGoal'] as num?)?.toDouble(),
      unit: (json['unit'] as String?) ?? '',
      step: (json['step'] as num?)?.toDouble() ?? 1,
      checklist: rawChecklist is List
          ? rawChecklist
              .whereType<Map<String, dynamic>>()
              .map(ChecklistItem.fromJson)
              .toList()
          : const <ChecklistItem>[],
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      archivedAt: rawArchived == null ? null : DateTime.tryParse(rawArchived),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.iconKey == iconKey &&
      other.colorValue == colorValue &&
      other.type == type &&
      other.tracking == tracking &&
      other.schedule == schedule &&
      other.reminder == reminder &&
      other.categoryId == categoryId &&
      other.showStreaksOnTimeline == showStreaksOnTimeline &&
      other.dailyGoal == dailyGoal &&
      other.unit == unit &&
      other.step == step &&
      listEquals(other.checklist, checklist) &&
      other.createdAt == createdAt &&
      other.archivedAt == archivedAt &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        title,
        description,
        iconKey,
        colorValue,
        type,
        tracking,
        schedule,
        reminder,
        categoryId,
        showStreaksOnTimeline,
        dailyGoal,
        unit,
        step,
        Object.hashAll(checklist),
        createdAt,
        archivedAt,
        sortOrder,
      ]);
}
