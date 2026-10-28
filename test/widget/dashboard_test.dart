import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

import '../support/in_memory_repository.dart';
import '../support/test_helpers.dart';

void main() {
  testWidgets('empty dashboard shows the heading, filters and empty state',
      (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Today, 27th Oct'), findsOneWidget);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    expect(find.text('Due (0)'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
  });

  testWidgets('stored habits appear with real counts and streaks',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit()
      ..habits['h2'] = sampleHabit(id: 'h2', title: '100 Salawath', sortOrder: 1);
    await pumpApp(tester, repo: repo);

    expect(find.text('Reading Books'), findsOneWidget);
    expect(find.text('100 Salawath'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Due (2)'), findsOneWidget);
    expect(find.text('Streak: 0 days'), findsNWidgets(2));
  });

  testWidgets('Due only lists habits scheduled for the selected day',
      (WidgetTester tester) async {
    // Monday-only habit; today is a Tuesday.
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit(
        created: DateTime(2026, 10, 19),
        schedule: const Schedule(
          type: FrequencyType.daysOfWeek,
          weekdays: <int>{1},
        ),
      );
    await pumpApp(tester, repo: repo);

    expect(find.text('Due (0)'), findsOneWidget);
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('Nothing due on this day'), findsOneWidget);

    await tester.tap(find.text('All (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Reading Books'), findsOneWidget);

    // Select Monday the 26th: now it is due.
    await tester.tap(find.text('26'));
    await tester.pumpAndSettle();
    expect(find.text('Mon, 26th Oct'), findsOneWidget);
    expect(find.text('Due (1)'), findsOneWidget);
  });

  testWidgets('a day before the habit existed is not due',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit();
    await pumpApp(tester, repo: repo);
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(find.text('Sun, 25th Oct'), findsOneWidget);
    expect(find.text('Due (0)'), findsOneWidget);
  });

  testWidgets('tapping the check completes today and survives a restart',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit();
    await pumpApp(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Streak: 1 day'), findsOneWidget);
    expect(repo.records.length, 1);
    expect(repo.records.values.single.done, isTrue);

    // "Restart": a brand-new app over the same stored data.
    await pumpApp(tester, repo: repo);
    expect(find.text('Streak: 1 day'), findsOneWidget);

    // Tapping again undoes it and removes the stored record.
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Streak: 0 days'), findsOneWidget);
    expect(repo.records, isEmpty);
  });

  testWidgets('count habits add one step per tap and show progress',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit(
        title: 'Water',
        tracking: TrackingMethod.count,
        goal: 2,
      );
    await pumpApp(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('2/2'), findsOneWidget);
    expect(find.text('Streak: 1 day  ·  2/2'), findsOneWidget);
    expect(repo.records.values.single.count, 2);
  });

  testWidgets('quit habits record a slip instead of a completion',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit(title: 'No sugar', type: HabitType.quit);
    await pumpApp(tester, repo: repo);

    // Slip-free by default: today already counts.
    expect(find.text('Streak: 2 days'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(repo.records.values.single.slipped, isTrue);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // Yesterday was clean (1) but the slip today resets the current streak.
    expect(find.text('Streak: 0 days'), findsOneWidget);
  });

  testWidgets('category chips filter the list and counts',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..categories['c1'] = const HabitCategory(id: 'c1', name: 'Health')
      ..habits['h1'] = sampleHabit(categoryId: 'c1')
      ..habits['h2'] = sampleHabit(id: 'h2', title: 'Guitar', sortOrder: 1);
    await pumpApp(tester, repo: repo);

    expect(find.text('All (2)'), findsOneWidget);
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('Reading Books'), findsOneWidget);
    expect(find.text('Guitar'), findsNothing);
  });

  testWidgets('the habit score pill reflects stored records',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit(created: DateTime(2026, 10, 25));
    final CompletionRecord r = doneOn('h1', DateTime(2026, 10, 25));
    repo.records[r.key] = r;
    await pumpApp(tester, repo: repo);
    // Oct 25 done, Oct 26 missed, today pending -> 50%.
    expect(find.text('50.0%'), findsOneWidget);
  });

  testWidgets('settings has no premium or cloud entries',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Rearrange'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.textContaining('Ultimate'), findsNothing);
    expect(find.textContaining('Cloud'), findsNothing);
  });
}
