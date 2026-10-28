import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';
import 'package:tickoff_replacement/domain/models/models.dart';
import 'package:tickoff_replacement/state/app_data.dart';
import 'package:tickoff_replacement/state/app_state.dart';

import '../support/in_memory_repository.dart';

final DateTime today = DateTime(2026, 10, 27);

Habit habit({
  String id = 'h',
  TrackingMethod tracking = TrackingMethod.tick,
  HabitType type = HabitType.build,
  double? goal,
  List<ChecklistItem> checklist = const <ChecklistItem>[],
  DateTime? created,
  String? categoryId,
}) {
  return Habit(
    id: id,
    title: 'Habit $id',
    createdAt: created ?? DateTime(2026, 10, 26),
    tracking: tracking,
    type: type,
    dailyGoal: goal,
    checklist: checklist,
    categoryId: categoryId,
  );
}

ProviderContainer containerFor(InMemoryAppRepository repo) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      repositoryProvider.overrideWithValue(repo),
      todayProvider.overrideWithValue(today),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<AppDataNotifier> load(ProviderContainer c) async {
  await c.read(appDataProvider.future);
  return c.read(appDataProvider.notifier);
}

AppData dataOf(ProviderContainer c) => c.read(appDataProvider).requireValue;

void main() {
  test('starts empty and loads what the repository holds', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    repo.habits['a'] = habit(id: 'a');
    final ProviderContainer c = containerFor(repo);
    await load(c);
    expect(dataOf(c).habits.length, 1);
  });

  test('saveHabit stores the habit and rejects invalid ones', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);

    await n.saveHabit(habit());
    expect(repo.habits.length, 1);
    expect(dataOf(c).activeHabits.length, 1);

    final Habit blank = habit(id: 'x').copyWith(title: '  ');
    expect(() => n.saveHabit(blank), throwsArgumentError);
    expect(repo.habits.containsKey('x'), isFalse);
  });

  test('editing a habit keeps its completion history', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit();
    await n.saveHabit(h);
    await n.toggleTick(h, today);
    await n.saveHabit(h.copyWith(title: 'Renamed'));
    expect(repo.habits['h']!.title, 'Renamed');
    expect(repo.records.length, 1);
  });

  test('toggleTick creates then removes the record; never duplicates', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit();
    await n.saveHabit(h);

    await n.toggleTick(h, today);
    expect(repo.records.length, 1);
    expect(repo.records.values.single.done, isTrue);

    await n.toggleTick(h, today);
    expect(repo.records, isEmpty);

    await n.toggleTick(h, today);
    await n.toggleTick(h, addDays(today, -1));
    expect(repo.records.length, 2);
  });

  test('quit habits toggle the slip flag instead', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit(type: HabitType.quit);
    await n.saveHabit(h);
    await n.toggleTick(h, today);
    expect(repo.records.values.single.slipped, isTrue);
    expect(repo.records.values.single.done, isFalse);
  });

  test('count: adds steps, completes at the goal, rejects negatives', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit(tracking: TrackingMethod.count, goal: 3);
    await n.saveHabit(h);

    await n.addCount(h, today, 1);
    await n.addCount(h, today, 1);
    expect(repo.records.values.single.count, 2);
    await n.addCount(h, today, 1);
    expect(repo.records.values.single.count, 3);
    expect(
      c.read(habitEngineProvider).isCompleted(h, repo.records.values.single),
      isTrue,
    );

    await n.setCount(h, today, 0);
    expect(repo.records, isEmpty);
    expect(() => n.setCount(h, today, -1), throwsArgumentError);
    await n.addCount(h, today, -5); // never below zero
    expect(repo.records, isEmpty);
  });

  test('checklist items toggle independently', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit(
      tracking: TrackingMethod.checklist,
      checklist: const <ChecklistItem>[
        ChecklistItem(id: 'a', title: 'A'),
        ChecklistItem(id: 'b', title: 'B'),
      ],
    );
    await n.saveHabit(h);
    await n.toggleChecklistItem(h, today, 'a');
    expect(repo.records.values.single.checkedItemIds, <String>{'a'});
    await n.toggleChecklistItem(h, today, 'b');
    await n.toggleChecklistItem(h, today, 'a');
    expect(repo.records.values.single.checkedItemIds, <String>{'b'});
    await n.toggleChecklistItem(h, today, 'b');
    expect(repo.records, isEmpty);
  });

  test('achievements unlock from history and are stored', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final Habit h = habit(created: DateTime(2026, 10, 20));
    repo.habits[h.id] = h;
    for (int d = 20; d <= 26; d++) {
      final CompletionRecord r = CompletionRecord(
        habitId: h.id,
        dateKey: dateKey(DateTime(2026, 10, d)),
        updatedAt: today,
        done: true,
      );
      repo.records[r.key] = r;
    }
    final ProviderContainer c = containerFor(repo);
    await load(c);
    expect(repo.achievements['h']!.keys.toSet(), <int>{1, 7});
    expect(dataOf(c).achievementsFor('h').keys.toSet(), <int>{1, 7});
    expect(c.read(habitStatsProvider)['h']!.bestStreak, 7);
  });

  test('completing a day can unlock the first achievement', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit();
    await n.saveHabit(h);
    expect(repo.achievements, isEmpty);
    await n.toggleTick(h, today);
    expect(repo.achievements['h']!.keys.toSet(), <int>{1});
  });

  test('archive, restore and delete', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    final Habit h = habit();
    await n.saveHabit(h);
    await n.toggleTick(h, today);
    await n.saveNote(
      Note(id: 'n1', habitId: 'h', createdAt: today, updatedAt: today, title: 'x'),
    );

    await n.setArchived('h', true);
    expect(dataOf(c).activeHabits, isEmpty);
    expect(dataOf(c).archivedHabits.length, 1);
    expect(repo.records.length, 1); // history kept

    await n.setArchived('h', false);
    expect(dataOf(c).activeHabits.length, 1);

    await n.deleteHabit('h');
    expect(dataOf(c).habits, isEmpty);
    expect(repo.records, isEmpty);
    expect(repo.notes, isEmpty);
    expect(repo.achievements, isEmpty);
  });

  test('deleting a category keeps its habits, uncategorised', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    await n.saveCategory(const HabitCategory(id: 'c1', name: 'Health'));
    await n.saveHabit(habit(categoryId: 'c1'));
    expect(dataOf(c).habitById('h')!.categoryId, 'c1');

    await n.deleteCategory('c1');
    expect(dataOf(c).categories, isEmpty);
    expect(dataOf(c).habitById('h')!.categoryId, isNull);
    expect(() => n.saveCategory(const HabitCategory(id: 'c2', name: ' ')), throwsArgumentError);
  });

  test('overall score is derived from the records', () async {
    final InMemoryAppRepository repo = InMemoryAppRepository();
    final ProviderContainer c = containerFor(repo);
    final AppDataNotifier n = await load(c);
    expect(c.read(overallScoreProvider), 0);

    final Habit h = habit(created: DateTime(2026, 10, 25));
    await n.saveHabit(h);
    await n.toggleTick(h, DateTime(2026, 10, 25)); // done
    // 25 done, 26 missed, today pending -> 1 of 2 = 50%
    expect(c.read(overallScoreProvider), closeTo(50, 1e-9));
  });
}
