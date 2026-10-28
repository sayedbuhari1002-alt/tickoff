import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/sqlite_app_repository.dart';
import 'state/app_state.dart';
import 'state/task_state.dart';
import 'shared/utils/local_notifications.dart';
import 'state/preferences_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ThemeMode themeMode = ThemeMode.values.firstWhere((ThemeMode mode) => mode.name == prefs.getString('theme_mode'), orElse: () => ThemeMode.dark);
    try { await LocalNotifications.instance.initialize(); } catch (_) { /* app remains usable if notification setup is unavailable */ }
    final Database db = await AppDatabase.open();
    runApp(
      ProviderScope(
        overrides: <Override>[
          repositoryProvider.overrideWithValue(SqliteAppRepository(db)),
          taskDatabaseProvider.overrideWithValue(db),
          appThemeModeProvider.overrideWith((ref) => themeMode),
          compactLayoutProvider.overrideWith((ref) => prefs.getBool('compact_layout') ?? false),
          showDashboardScoreProvider.overrideWith((ref) => prefs.getBool('dashboard_score') ?? true),
          showDashboardCalendarProvider.overrideWith((ref) => prefs.getBool('dashboard_calendar') ?? true),
          confirmDeletesProvider.overrideWith((ref) => prefs.getBool('confirm_deletes') ?? true),
          hapticsProvider.overrideWith((ref) => prefs.getBool('haptics') ?? true),
        ],
        child: const TickOffApp(),
      ),
    );
  } catch (e) {
    runApp(StartupErrorApp(message: '$e'));
  }
}
