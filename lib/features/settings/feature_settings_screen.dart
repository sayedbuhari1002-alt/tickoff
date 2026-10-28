import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/models.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';

class FeatureSettingsScreen extends ConsumerWidget {
  const FeatureSettingsScreen({super.key, required this.kind});
  final String kind;

  Future<void> _save(String key, Object value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (kind) {
      case 'theme':
        final ThemeMode mode = ref.watch(appThemeModeProvider);
        return Scaffold(appBar: AppBar(title: const Text('Theme')), body: ListView(children: <Widget>[
          for (final ThemeMode item in ThemeMode.values) RadioListTile<ThemeMode>(title: Text(switch (item) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' }), value: item, groupValue: mode, onChanged: (ThemeMode? value) async { if (value == null) return; ref.read(appThemeModeProvider.notifier).state = value; await _save('theme_mode', value.name); }),
          const Padding(padding: EdgeInsets.all(16), child: Text('Your selected theme is saved on this device.')),
        ]));
      case 'layout':
        final bool compact = ref.watch(compactLayoutProvider);
        return Scaffold(appBar: AppBar(title: const Text('Layout')), body: SwitchListTile(title: const Text('Compact habit and task cards'), subtitle: const Text('Reduce spacing in lists'), value: compact, onChanged: (bool value) async { ref.read(compactLayoutProvider.notifier).state = value; await _save('compact_layout', value); }));
      case 'widgets':
        final bool score = ref.watch(showDashboardScoreProvider);
        final bool calendar = ref.watch(showDashboardCalendarProvider);
        return Scaffold(appBar: AppBar(title: const Text('Dashboard widgets')), body: ListView(children: <Widget>[
          SwitchListTile(title: const Text('Show habit score'), subtitle: const Text('Show the existing habit score card on the dashboard'), value: score, onChanged: (bool value) async { ref.read(showDashboardScoreProvider.notifier).state = value; await _save('dashboard_score', value); }),
          SwitchListTile(title: const Text('Show calendar strip'), subtitle: const Text('Show date navigation on the dashboard'), value: calendar, onChanged: (bool value) async { ref.read(showDashboardCalendarProvider.notifier).state = value; await _save('dashboard_calendar', value); }),
          const Padding(padding: EdgeInsets.all(16), child: Text('These controls configure dashboard sections inside TickOff. Android home-screen widgets require a separate platform widget implementation.')),
        ]));
      case 'general':
        final bool confirm = ref.watch(confirmDeletesProvider);
        final bool haptics = ref.watch(hapticsProvider);
        return Scaffold(appBar: AppBar(title: const Text('General')), body: ListView(children: <Widget>[
          SwitchListTile(title: const Text('Confirm destructive actions'), subtitle: const Text('Ask before deleting items'), value: confirm, onChanged: (bool value) async { ref.read(confirmDeletesProvider.notifier).state = value; await _save('confirm_deletes', value); }),
          SwitchListTile(title: const Text('Haptic feedback preference'), subtitle: const Text('Save the preference for supported interactions'), value: haptics, onChanged: (bool value) async { ref.read(hapticsProvider.notifier).state = value; await _save('haptics', value); }),
          const ListTile(title: Text('Storage'), subtitle: Text('Your habits, tasks, notes, and attachments are stored locally on this device.')),
        ]));
      case 'rearrange':
        final AppData? data = ref.watch(appDataProvider).valueOrNull;
        final List<Habit> habits = data?.activeHabits ?? <Habit>[];
        return Scaffold(appBar: AppBar(title: const Text('Rearrange habits')), body: data == null ? const Center(child: CircularProgressIndicator()) : habits.isEmpty ? const Center(child: Text('No habits to rearrange.')) : ReorderableListView.builder(padding: const EdgeInsets.all(12), itemCount: habits.length, onReorder: (int oldIndex, int newIndex) async { if (newIndex > oldIndex) newIndex--; final List<Habit> reordered = List<Habit>.of(habits); final Habit moved = reordered.removeAt(oldIndex); reordered.insert(newIndex, moved); for (int i = 0; i < reordered.length; i++) { await ref.read(appDataProvider.notifier).saveHabit(reordered[i].copyWith(sortOrder: i)); } }, itemBuilder: (BuildContext context, int index) { final Habit habit = habits[index]; return Card(key: ValueKey<String>(habit.id), color: AppColors.surface, child: ListTile(leading: Icon(habit.icon, color: habit.color), title: Text(habit.title), trailing: const Icon(Icons.drag_handle))); }));
      default:
        return Scaffold(appBar: AppBar(title: const Text('Settings')), body: const Center(child: Text('Unknown setting.')));
    }
  }
}
