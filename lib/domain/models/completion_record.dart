import 'package:flutter/foundation.dart';

/// What happened to one habit on one calendar day.
///
/// There is at most one record per (habitId, dateKey); [key] is the natural
/// primary key, which makes duplicate records for a habit/day impossible.
///
/// * Tick (Build): [done] is true when the day is ticked.
/// * Count: [count] holds the running total; the day is complete when it
///   reaches the habit's daily goal.
/// * Checklist: [checkedItemIds] holds the ticked items.
/// * Quit: [slipped] is true on days the user marked a slip. A missing record
///   means the day was slip-free.
@immutable
class CompletionRecord {
  const CompletionRecord({
    required this.habitId,
    required this.dateKey,
    required this.updatedAt,
    this.done = false,
    this.count = 0,
    this.checkedItemIds = const <String>{},
    this.slipped = false,
  });

  final String habitId;

  /// Calendar day in `yyyy-MM-dd` form (see `dateKey` in date_utils.dart).
  final String dateKey;
  final DateTime updatedAt;
  final bool done;
  final double count;
  final Set<String> checkedItemIds;
  final bool slipped;

  /// Unique identity of the record.
  String get key => '$habitId|$dateKey';

  /// True when the record carries no information (nothing ticked, no count, no
  /// checked items, no slip). Blank records are deleted instead of stored.
  bool get isBlank =>
      !done && count <= 0 && checkedItemIds.isEmpty && !slipped;

  CompletionRecord copyWith({
    DateTime? updatedAt,
    bool? done,
    double? count,
    Set<String>? checkedItemIds,
    bool? slipped,
  }) {
    return CompletionRecord(
      habitId: habitId,
      dateKey: dateKey,
      updatedAt: updatedAt ?? this.updatedAt,
      done: done ?? this.done,
      count: count ?? this.count,
      checkedItemIds: checkedItemIds ?? this.checkedItemIds,
      slipped: slipped ?? this.slipped,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'habitId': habitId,
        'dateKey': dateKey,
        'updatedAt': updatedAt.toIso8601String(),
        'done': done,
        'count': count,
        'checkedItemIds': (checkedItemIds.toList()..sort()),
        'slipped': slipped,
      };

  factory CompletionRecord.fromJson(Map<String, dynamic> json) {
    final Object? rawIds = json['checkedItemIds'];
    return CompletionRecord(
      habitId: json['habitId'] as String,
      dateKey: json['dateKey'] as String,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      done: json['done'] == true,
      count: (json['count'] as num?)?.toDouble() ?? 0,
      checkedItemIds: rawIds is List
          ? rawIds.whereType<String>().toSet()
          : const <String>{},
      slipped: json['slipped'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionRecord &&
      other.habitId == habitId &&
      other.dateKey == dateKey &&
      other.updatedAt == updatedAt &&
      other.done == done &&
      other.count == count &&
      setEquals(other.checkedItemIds, checkedItemIds) &&
      other.slipped == slipped;

  @override
  int get hashCode => Object.hash(
        habitId,
        dateKey,
        updatedAt,
        done,
        count,
        Object.hashAllUnordered(checkedItemIds),
        slipped,
      );
}
