import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/router/routes.dart';
import 'package:tickoff_replacement/shared/widgets/widgets.dart';

import '../support/in_memory_repository.dart';
import '../support/test_helpers.dart';

/// Habit A done Oct 20-26; habit B done Oct 20-22 (both created Oct 20).
InMemoryAppRepository seededTwo() {
  final InMemoryAppRepository repo = InMemoryAppRepository()
    ..habits['a'] = sampleHabit(id: 'a', title: 'Alpha', created: DateTime(2026, 10, 20))
    ..habits['b'] = sampleHabit(
      id: 'b',
      title: 'Bravo',
      created: DateTime(2026, 10, 20),
      sortOrder: 1,
    );
  for (int d = 20; d <= 26; d++) {
    final r = doneOn('a', DateTime(2026, 10, d));
    repo.records[r.key] = r;
  }
  for (int d = 20; d <= 22; d++) {
    final r = doneOn('b', DateTime(2026, 10, d));
    repo.records[r.key] = r;
  }
  return repo;
}

String tileValue(WidgetTester tester, String label) =>
    tester.widget<StatTile>(find.widgetWithText(StatTile, label)).value;

void main() {
  testWidgets('new users see a helpful empty state, not fake numbers',
      (WidgetTester tester) async {
    await pumpApp(tester, location: AppRoutes.analytics);
    expect(find.text('No data to analyse yet'), findsOneWidget);
    expect(find.byType(StatTile), findsNothing);
  });

  testWidgets('figures come from the stored records', (WidgetTester tester) async {
    await pumpApp(tester, repo: seededTwo(), location: AppRoutes.analytics);

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Daily completion rate'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Streaks'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    // Alpha: streak 7. Bravo: 3 of 7 due days (its streak is 0 now).
    expect(tileValue(tester, 'Current Streak'), '7');
    expect(tileValue(tester, 'Best Streak'), '7');
    expect(tileValue(tester, 'Completions'), '10');
    // 10 completed of 14 due.
    expect(tileValue(tester, 'Completion Rate'), '71%');
    expect(tileValue(tester, 'Days Tracked'), '8');
  });

  testWidgets('date-range filter changes the figures',
      (WidgetTester tester) async {
    await pumpApp(tester, repo: seededTwo(), location: AppRoutes.analytics);

    await tester.tap(find.text('7D')); // Oct 21..27
    await tester.pumpAndSettle();
    // Alpha 21-26 = 6 done; Bravo 21,22 = 2 done.
    expect(tileValue(tester, 'Completions'), '8');
    expect(tileValue(tester, 'Days Tracked'), '7');
  });

  testWidgets('a single habit can be analysed on its own',
      (WidgetTester tester) async {
    await pumpApp(tester, repo: seededTwo(), location: AppRoutes.analytics);

    await tester.tap(find.text('Bravo').first); // the chip
    await tester.pumpAndSettle();

    expect(find.text('Streaks'), findsNothing);
    expect(find.text('Achievements'), findsOneWidget);
    expect(tileValue(tester, 'Completions'), '3');
    expect(tileValue(tester, 'Completion Rate'), '43%');
  });

  testWidgets('the detail screen opens analytics for that habit',
      (WidgetTester tester) async {
    await pumpApp(tester, repo: seededTwo());
    await openHabitsTab(tester);
    await tester.tap(find.byKey(const ValueKey<String>('a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Analytics'));
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Streaks'), findsNothing);
    expect(tileValue(tester, 'Completions'), '7');
    expect(tileValue(tester, 'Completion Rate'), '100%');
  });

  testWidgets('the score pill on the dashboard opens analytics',
      (WidgetTester tester) async {
    await pumpApp(tester, repo: seededTwo());
    await tester.tap(find.text('Habit analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Analytics'), findsOneWidget);
  });
}
