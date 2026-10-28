import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/app.dart';
import 'package:tickoff_replacement/core/router/app_router.dart';
import 'package:tickoff_replacement/core/router/routes.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';
import 'package:tickoff_replacement/domain/models/models.dart';
import 'package:tickoff_replacement/domain/models/task.dart';
import 'package:tickoff_replacement/state/app_state.dart';
import 'package:tickoff_replacement/state/task_state.dart';

import 'in_memory_repository.dart';

class _EmptyTaskListNotifier extends TaskListNotifier {
  @override
  Future<List<TaskItem>> build() async => <TaskItem>[];
}

/// The fixed "today" used by all widget tests: Tuesday 27 Oct 2026.
final DateTime kToday = DateTime(2026, 10, 27);

/// A simple tick habit created on [created] (default: yesterday).
Habit sampleHabit({
  String id = 'h1',
  String title = 'Reading Books',
  DateTime? created,
  HabitType type = HabitType.build,
  TrackingMethod tracking = TrackingMethod.tick,
  double? goal,
  List<ChecklistItem> checklist = const <ChecklistItem>[],
  int sortOrder = 0,
  DateTime? archivedAt,
  String? categoryId,
  Schedule schedule = const Schedule(),
}) {
  return Habit(
    id: id,
    title: title,
    createdAt: created ?? DateTime(2026, 10, 26),
    type: type,
    tracking: tracking,
    dailyGoal: goal,
    checklist: checklist,
    sortOrder: sortOrder,
    archivedAt: archivedAt,
    categoryId: categoryId,
    schedule: schedule,
  );
}

CompletionRecord doneOn(String habitId, DateTime day) => CompletionRecord(
      habitId: habitId,
      dateKey: dateKey(day),
      updatedAt: day,
      done: true,
    );

/// Starts the full app on a tall virtual screen with [repo] as the database.
Future<InMemoryAppRepository> pumpApp(
  WidgetTester tester, {
  InMemoryAppRepository? repo,
  String location = AppRoutes.dashboard,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final InMemoryAppRepository r = repo ?? InMemoryAppRepository();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        repositoryProvider.overrideWithValue(r),
        todayProvider.overrideWithValue(kToday),
        appRouterProvider.overrideWithValue(
          buildRouter(initialLocation: location),
        ),
        taskListProvider.overrideWith(_EmptyTaskListNotifier.new),
      ],
      child: const TickOffApp(),
    ),
  );
  await tester.pumpAndSettle();
  return r;
}
