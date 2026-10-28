import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/router/routes.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

import '../support/in_memory_repository.dart';
import '../support/test_helpers.dart';

/// Starts the app and opens the Add Habit form the way a user does.
Future<InMemoryAppRepository> openNewForm(WidgetTester tester) async {
  final InMemoryAppRepository repo = await pumpApp(tester);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('saving without a title shows a validation message',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add Habit'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a habit title.'), findsOneWidget);
    expect(repo.habits, isEmpty);
  });

  testWidgets('a new habit is saved to the database and listed',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Meditate');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.habits.length, 1);
    final Habit saved = repo.habits.values.single;
    expect(saved.title, 'Meditate');
    expect(saved.type, HabitType.build);
    expect(saved.tracking, TrackingMethod.tick);
    expect(saved.schedule.type, FrequencyType.everyday);

    // Back on the dashboard.
    await tester.tap(find.textContaining('All ('));
    await tester.pumpAndSettle();
    expect(find.text('Meditate'), findsOneWidget);
  });

  testWidgets('Quit disables the other frequencies and explains the rule',
      (WidgetTester tester) async {
    await openNewForm(tester);

    await tester.tap(find.text('Quit A Habit'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Completed by default'), findsOneWidget);
    final Text weekdays =
        tester.widget<Text>(find.text('Specific Days of Week'));
    expect(weekdays.style?.decoration, TextDecoration.lineThrough);
    final Text everyday = tester.widget<Text>(find.text('Everyday'));
    expect(everyday.style?.decoration, isNull);
  });

  testWidgets('Count tracking saves goal, unit and step',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);

    await tester.enterText(find.byType(TextField).first, 'Water');
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('UNIT (optional)'), findsOneWidget);
    expect(find.text('EACH TAP ADDS'), findsOneWidget);

    // Order: title, description, goal, unit, step.
    await tester.enterText(find.byType(TextField).at(2), '8');
    await tester.enterText(find.byType(TextField).at(3), 'glasses');
    await tester.enterText(find.byType(TextField).at(4), '2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final Habit saved = repo.habits.values.single;
    expect(saved.tracking, TrackingMethod.count);
    expect(saved.dailyGoal, 8);
    expect(saved.unit, 'glasses');
    expect(saved.step, 2);
  });

  testWidgets('an invalid count goal is rejected', (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Water');
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'lots');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('The daily goal must be a number above zero.'),
      findsOneWidget,
    );
    expect(repo.habits, isEmpty);
  });

  testWidgets('a checklist habit needs at least one item, then saves its items',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Morning routine');
    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one checklist item.'), findsOneWidget);
    expect(repo.habits, isEmpty);

    await tester.tap(find.text('Add Checklist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Stretch');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final Habit saved = repo.habits.values.single;
    expect(saved.tracking, TrackingMethod.checklist);
    expect(saved.checklist.map((ChecklistItem i) => i.title), <String>['Stretch']);
  });

  testWidgets('weekday scheduling requires a chosen day',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Gym');
    await tester.tap(find.text('Specific Days of Week'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Select at least one weekday.'), findsOneWidget);

    await tester.tap(find.text('Mo'));
    await tester.tap(find.text('Th'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final Habit saved = repo.habits.values.single;
    expect(saved.schedule.type, FrequencyType.daysOfWeek);
    expect(saved.schedule.weekdays, <int>{1, 4});
  });

  testWidgets('the icon picker searches and applies the chosen icon',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Swim');

    await tester.tap(find.text('Icon'));
    await tester.pumpAndSettle();
    expect(find.text('Search icons'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'swim');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pool));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.habits.values.single.iconKey, 'pool');
  });

  testWidgets('a category can be created and selected from the form',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = await openNewForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Run');

    await tester.tap(find.text('Select Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Fitness');
    await tester.tap(find.text('Save').last); // the dialog's button
    await tester.pumpAndSettle();

    expect(repo.categories.values.single.name, 'Fitness');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.habits.values.single.categoryId, repo.categories.keys.single);
  });

  testWidgets('editing keeps the id and creation date',
      (WidgetTester tester) async {
    final InMemoryAppRepository repo = InMemoryAppRepository()
      ..habits['h1'] = sampleHabit();
    await pumpApp(tester, repo: repo, location: AppRoutes.habitEdit('h1'));

    expect(find.text('Edit Habit'), findsOneWidget);
    expect(find.text('Reading Books'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Reading More');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final Habit saved = repo.habits['h1']!;
    expect(saved.title, 'Reading More');
    expect(saved.createdAt, DateTime(2026, 10, 26));
    expect(repo.habits.length, 1);
  });
}
