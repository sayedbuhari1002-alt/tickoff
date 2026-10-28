import 'package:flutter/material.dart';

import '../../core/icons/habit_icons.dart';
import '../../domain/models/models.dart';

extension HabitUi on Habit {
  /// The habit's chosen colour.
  Color get color => Color(colorValue);

  /// The habit's chosen icon.
  IconData get icon => iconForKey(iconKey);
}
