import 'package:flutter/foundation.dart';

/// A user-defined category used by the dashboard filter chips.
@immutable
class HabitCategory {
  const HabitCategory({
    required this.id,
    required this.name,
    this.iconKey,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? iconKey;
  final int sortOrder;

  HabitCategory copyWith({String? name, String? iconKey, int? sortOrder}) {
    return HabitCategory(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'sortOrder': sortOrder,
      };

  factory HabitCategory.fromJson(Map<String, dynamic> json) {
    return HabitCategory(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      iconKey: json['iconKey'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HabitCategory &&
      other.id == id &&
      other.name == name &&
      other.iconKey == iconKey &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, iconKey, sortOrder);
}
