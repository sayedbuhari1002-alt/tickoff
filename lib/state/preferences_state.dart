import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final StateProvider<ThemeMode> appThemeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final StateProvider<bool> compactLayoutProvider = StateProvider<bool>((ref) => false);
final StateProvider<bool> showDashboardScoreProvider = StateProvider<bool>((ref) => true);
final StateProvider<bool> showDashboardCalendarProvider = StateProvider<bool>((ref) => true);
final StateProvider<bool> confirmDeletesProvider = StateProvider<bool>((ref) => true);
final StateProvider<bool> hapticsProvider = StateProvider<bool>((ref) => true);
