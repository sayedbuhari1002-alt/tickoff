import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_repository.dart';
import '../support/test_helpers.dart';

/// A habit created yesterday and completed yesterday.
InMemoryAppRepository seeded() {
  final InMemoryAppRepository repo = InMemoryAppRepository()
    ..habits['h1'] = sampleHabit();
  final record = doneOn('h1', DateTime(2026, 10, 26));
  repo.records[record.key] = record;
  return repo;
}

Future<void> openDetail(WidgetTester tester, InMemoryAppRepository repo) async {
  await pumpApp(tester, repo: repo);
  await openHabitsTab(tester);
  await tester.tap(find.byKey(const ValueKey<String>('h1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows status, streaks and score from the stored history',
      (WidgetTester tester) async {
    await openDetail(tester, seeded());

    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Not Completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Task Started'), findsOneWidget);
    expect(find.text('Everyday'), findsOneWidget);
  });

  testWidgets('Done completes today and can be undone',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = seeded();
    await openDetail(tester, repo);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Mark not done'), findsOneWidget);
    expect(repo.records.length, 2);

    await tester.tap(find.text('Mark not done'));
    await tester.pumpAndSettle();
    expect(find.text('Not Completed'), findsOneWidget);
    expect(repo.records.length, 1);
  });

  testWidgets('achievements show locked milestones and progress',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = seeded();
    await openDetail(tester, repo);

    await tester.tap(find.byIcon(Icons.emoji_events_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('730 days'), findsOneWidget);
    // Best streak is 1 day: only the first milestone is unlocked.
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(8));
    expect(find.textContaining('next: 7 days'), findsOneWidget);
    expect(repo.achievements['h1']!.keys.toSet(), <int>{1});
  });

  testWidgets('the history calendar edits a day',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = seeded();
    await openDetail(tester, repo);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('October 2026'), findsWidgets); // also a timeline header

    await tester.tap(find.text('27'));
    await tester.pumpAndSettle();
    expect(repo.records.containsKey('h1|2026-10-27'), isTrue);

    await tester.tap(find.text('26'));
    await tester.pumpAndSettle();
    expect(repo.records.containsKey('h1|2026-10-26'), isFalse);
  });

  testWidgets('archive removes the habit from the dashboard but keeps data',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = seeded();
    await openDetail(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Share Progress'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(repo.habits['h1']!.isArchived, isTrue);
    expect(repo.records.length, 1);
    expect(find.text('No habits yet'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation and removes everything',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = seeded();
    await openDetail(tester, repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete habit?'), findsOneWidget);

    // Cancel keeps it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.habits.length, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repo.habits, isEmpty);
    expect(repo.records, isEmpty);
    expect(find.text('No habits yet'), findsOneWidget);
  });

  testWidgets('share progress builds a summary screen',
      (WidgetTester tester) async {
    await openDetail(tester, seeded());
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Copy summary'), findsOneWidget);
  });
}
