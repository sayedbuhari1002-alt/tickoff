import 'package:flutter/foundation.dart';

/// A note, optionally linked to a habit, with optional local photo and audio
/// attachments (file paths inside the app's private storage).
@immutable
class Note {
  const Note({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.habitId,
    this.title = '',
    this.body = '',
    this.photoPaths = const <String>[],
    this.audioPaths = const <String>[],
  });

  final String id;
  final String? habitId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> photoPaths;
  final List<String> audioPaths;

  /// A note with no text and no attachments is not worth saving.
  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      photoPaths.isEmpty &&
      audioPaths.isEmpty;

  Note copyWith({
    String? habitId,
    bool clearHabit = false,
    String? title,
    String? body,
    DateTime? updatedAt,
    List<String>? photoPaths,
    List<String>? audioPaths,
  }) {
    return Note(
      id: id,
      habitId: clearHabit ? null : (habitId ?? this.habitId),
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPaths: photoPaths ?? this.photoPaths,
      audioPaths: audioPaths ?? this.audioPaths,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'habitId': habitId,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'photoPaths': photoPaths,
        'audioPaths': audioPaths,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) =>
        raw is List ? raw.whereType<String>().toList() : const <String>[];
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime created =
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? epoch;
    return Note(
      id: json['id'] as String,
      habitId: json['habitId'] as String?,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? created,
      photoPaths: strings(json['photoPaths']),
      audioPaths: strings(json['audioPaths']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.habitId == habitId &&
      other.title == title &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      listEquals(other.photoPaths, photoPaths) &&
      listEquals(other.audioPaths, audioPaths);

  @override
  int get hashCode => Object.hash(
        id,
        habitId,
        title,
        body,
        createdAt,
        updatedAt,
        Object.hashAll(photoPaths),
        Object.hashAll(audioPaths),
      );
}
