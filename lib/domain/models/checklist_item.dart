import 'package:flutter/foundation.dart';

import 'reminder.dart';

/// One item of a Checklist habit (the "Add Checklist" dialog has a title and
/// an optional reminder).
@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.reminder = const Reminder(),
  });

  final String id;
  final String title;
  final Reminder reminder;

  ChecklistItem copyWith({String? title, Reminder? reminder}) {
    return ChecklistItem(
      id: id,
      title: title ?? this.title,
      reminder: reminder ?? this.reminder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'reminder': reminder.toJson(),
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    final Object? rawReminder = json['reminder'];
    return ChecklistItem(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      reminder: rawReminder is Map<String, dynamic>
          ? Reminder.fromJson(rawReminder)
          : const Reminder(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem &&
      other.id == id &&
      other.title == title &&
      other.reminder == reminder;

  @override
  int get hashCode => Object.hash(id, title, reminder);
}
