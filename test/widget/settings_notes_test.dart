import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

import '../support/in_memory_repository.dart';
import '../support/test_helpers.dart';

Future<void> openSettingsItem(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('Archive', () {
    testWidgets('lists archived habits and restores them',
        (WidgetTester tester) async {
      final InMemoryAppRepository repo = InMemoryAppRepository()
        ..habits['h1'] = sampleHabit(
          title: 'Old Habit',
          archivedAt: DateTime(2026, 10, 1),
        );
      await pumpApp(tester, repo: repo);
      expect(find.text('Old Habit'), findsNothing); // not on the dashboard

      await openSettingsItem(tester, 'Archive');
      expect(find.text('Old Habit'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.unarchive_outlined));
      await tester.pumpAndSettle();
      expect(repo.habits['h1']!.isArchived, isFalse);
      expect(find.text('Nothing archived'), findsOneWidget);
    });

    testWidgets('permanently deletes after confirmation',
        (WidgetTester tester) async {
      final InMemoryAppRepository repo = InMemoryAppRepository()
        ..habits['h1'] = sampleHabit(
          title: 'Old Habit',
          archivedAt: DateTime(2026, 10, 1),
        );
      await pumpApp(tester, repo: repo);
      await openSettingsItem(tester, 'Archive');

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.habits, isEmpty);
    });
  });

  group('Categories', () {
    testWidgets('create, rename and delete', (WidgetTester tester) async {
      final InMemoryAppRepository repo = await pumpApp(tester);
      await openSettingsItem(tester, 'Categories');
      expect(find.text('No categories yet'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Health');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Health'), findsOneWidget);
      expect(repo.categories.values.single.name, 'Health');

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wellness');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Wellness'), findsOneWidget);
      expect(repo.categories.values.single.name, 'Wellness');

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.categories, isEmpty);
    });

    testWidgets('an empty category name is rejected',
        (WidgetTester tester) async {
      final InMemoryAppRepository repo = await pumpApp(tester);
      await openSettingsItem(tester, 'Categories');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a name.'), findsOneWidget);
      expect(repo.categories, isEmpty);
    });
  });

  group('Notes', () {
    testWidgets('a note typed on a habit is saved and listed',
        (WidgetTester tester) async {
      final InMemoryAppRepository repo = InMemoryAppRepository()
        ..habits['h1'] = sampleHabit();
      await pumpApp(tester, repo: repo);

      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Idea');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(repo.notes.length, 1);
      expect(repo.notes.values.single.title, 'Idea');
      expect(repo.notes.values.single.habitId, 'h1');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Idea'), findsOneWidget);
      expect(repo.notes.length, 1);
    });

    testWidgets('leaving an empty note stores nothing',
        (WidgetTester tester) async {
      final InMemoryAppRepository repo = InMemoryAppRepository()
        ..habits['h1'] = sampleHabit();
      await pumpApp(tester, repo: repo);
      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(repo.notes, isEmpty);
    });

    testWidgets('notes can be deleted', (WidgetTester tester) async {
      final InMemoryAppRepository repo = InMemoryAppRepository()
        ..habits['h1'] = sampleHabit()
        ..notes['n1'] = Note(
          id: 'n1',
          habitId: 'h1',
          title: 'Keep me?',
          createdAt: DateTime(2026, 10, 26),
          updatedAt: DateTime(2026, 10, 26),
        );
      await pumpApp(tester, repo: repo);
      await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep me?'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.notes, isEmpty);
    });
  });
}
