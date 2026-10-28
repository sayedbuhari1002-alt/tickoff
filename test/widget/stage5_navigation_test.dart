import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/shared/widgets/tickoff_bottom_bar.dart';

import '../support/test_helpers.dart';

Finder _plusButton() => find.descendant(
  of: find.byType(TickoffBottomBar),
  matching: find.byIcon(Icons.add),
);

void main() {
  testWidgets('bottom navigation identifies all four destinations and keeps the icons',
      (WidgetTester tester) async {
    await pumpApp(tester);
    final Finder bar = find.byType(TickoffBottomBar);

    for (final String label in <String>['Dashboard', 'Habits', 'Tasks', 'Notes']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.dashboard_rounded)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.check_circle_outline_rounded)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.task_alt_rounded)), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.sticky_note_2_rounded)), findsOneWidget);
  });

  testWidgets('the shared plus offers Add Habit and Add Task',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(_plusButton());
    await tester.pumpAndSettle();

    expect(find.text('Create new'), findsOneWidget);
    expect(find.text('Add Habit'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);
  });

  testWidgets('Add Task opens a full-screen task form',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(_plusButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Deadline'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Subtasks'), findsNothing);
  });

  testWidgets('Add Habit opens the existing full-screen habit form',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(_plusButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Habit'));
    await tester.pumpAndSettle();

    expect(find.text('Add Habit'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Tracking'), findsOneWidget);
  });
}
