import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour tokens estimated from the supplied TickOff screenshots.
///
/// Two accent families are used on purpose, exactly as in the reference:
/// * [gold] on the dashboard and habit-detail screens;
/// * [cyan] on the Add/Edit Habit screens.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceRaised = Color(0xFF181818);
  static const Color field = Color(0xFF0E0E0E);
  static const Color sheet = Color(0xFF0A0A0A);
  static const Color border = Color(0xFF242424);
  static const Color divider = Color(0xFF1C1C1C);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color textHint = Color(0xFF5E5E5E);

  // Accents
  static const Color gold = Color(0xFFFFC62B);
  static const Color goldDim = Color(0xFF3A2F0C);
  static const Color cyan = Color(0xFFE0F7FA);
  static const Color selectedSegment = Color(0xFF3C4043);
  static const Color switchTrackOn = Color(0xFF6F7A7E);

  // Status
  static const Color danger = Color(0xFFE53935);
  static const Color heatmapEmpty = Color(0xFF1A1A1A);

  /// Default colour of a new habit (the pale cyan swatch in the form).
  static const Color defaultHabitColor = cyan;

  /// Habit colour palette: two rows of twelve swatches.
  static const List<Color> habitPalette = <Color>[
    Color(0xFFE0F7FA),
    Color(0xFFFFE0B2),
    Color(0xFFFFCC80),
    Color(0xFFFFA726),
    Color(0xFFFF7043),
    Color(0xFFE64A19),
    Color(0xFFD32F2F),
    Color(0xFFB71C1C),
    Color(0xFFE57373),
    Color(0xFFFFCDD2),
    Color(0xFFF48FB1),
    Color(0xFFEC407A),
    Color(0xFFD4A017),
    Color(0xFFFFB300),
    Color(0xFFFB8C00),
    Color(0xFFFF5722),
    Color(0xFFF44336),
    Color(0xFFA81818),
    Color(0xFFFF5252),
    Color(0xFFFF6E6E),
    Color(0xFFFF4081),
    Color(0xFFE91E63),
    Color(0xFFAB47BC),
    Color(0xFF7E57C2),
    // Expanded green and cool-tone palette for habit/task customization.
    Color(0xFF1B5E20),
    Color(0xFF2E7D32),
    Color(0xFF388E3C),
    Color(0xFF43A047),
    Color(0xFF4CAF50),
    Color(0xFF66BB6A),
    Color(0xFF81C784),
    Color(0xFFA5D6A7),
    Color(0xFFC8E6C9),
    Color(0xFF00C853),
    Color(0xFF00BFA5),
    Color(0xFF26A69A),
    Color(0xFF00897B),
    Color(0xFF80CBC4),
    Color(0xFF90CAF9),
    Color(0xFF64B5F6),
    Color(0xFF5C6BC0),
    Color(0xFF9575CD),
  ];
}

extension ColorFade on Color {
  /// Returns this colour with the given opacity (0.0 - 1.0).
  Color fade(double opacity) {
    final int alpha = math.max(0, math.min(255, (opacity * 255).round()));
    return withAlpha(alpha);
  }
}
