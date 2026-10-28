import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';
import 'package:tickoff_replacement/domain/logic/habit_engine.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

// "Today" is Tuesday 27 October 2026. Mondays: Oct 5, 12, 19, 26.
final DateTime today = DateTime(2026, 10, 27);
final HabitEngine engine = HabitEngine(today: DateTime(2026, 10, 27));

DateTime oct(int day) => DateTime(2026, 10, day);

Habit habit({
  HabitType type = HabitType.build,
  TrackingMethod tracking = TrackingMethod.tick,
  Schedule schedule = const Schedule(),
  DateTime? created,
  double? goal,
  List<ChecklistItem> checklist = const <ChecklistItem>[],
}) {
  return Habit(
    id: 'h',
    title: 'T',
    createdAt: created ?? oct(20),
    type: type,
    tracking: tracking,
    schedule: schedule,
    dailyGoal: goal,
    checklist: checklist,
  );
}

CompletionRecord done(DateTime d) => CompletionRecord(
      habitId: 'h',
      dateKey: dateKey(d),
      updatedAt: d,
      done: true,
    );

CompletionRecord slip(DateTime d) => CompletionRecord(
      habitId: 'h',
      dateKey: dateKey(d),
      updatedAt: d,
      slipped: true,
    );

Map<String, CompletionRecord> recs(Iterable<CompletionRecord> list) =>
    <String, CompletionRecord>{
      for (final CompletionRecord r in list) r.dateKey: r,
    };

List<CompletionRecord> doneDays(Iterable<int> days) =>
    days.map((int d) => done(oct(d))).toList();

void main() {
  group('Build streaks (everyday)', () {
    test('7 completed days with today still pending = streak of 7', () {
      final HabitStats s = engine.stats(habit(), recs(doneDays(<int>[20, 21, 22, 23, 24, 25, 26])));
      expect(s.currentStreak, 7);
      expect(s.bestStreak, 7);
    });

    test('completing today extends the streak', () {
      final HabitStats s = engine.stats(
        habit(),
        recs(doneDays(<int>[20, 21, 22, 23, 24, 25, 26, 27])),
      );
      expect(s.currentStreak, 8);
    });

    test('a missed day resets the current streak but keeps the best', () {
      final HabitStats s = engine.stats(
        habit(),
        recs(doneDays(<int>[20, 21, 22, 23, 25, 26])), // missed the 24th
      );
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 4);
    });

    test('no completions gives a zero streak', () {
      final HabitStats s = engine.stats(habit(), const <String, CompletionRecord>{});
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 0);
    });

    test('totals and days tracked', () {
      final HabitStats s = engine.stats(habit(), recs(doneDays(<int>[20, 21, 23])));
      expect(s.totalCompletions, 3);
      expect(s.daysTracked, 8); // Oct 20..27 inclusive
    });

    test('history before the creation date is excluded', () {
      final Habit h = habit(created: oct(25));
      final Map<String, CompletionRecord> r = recs(doneDays(<int>[20, 21]));
      expect(engine.startDate(h, r), oct(25));
    });
  });

  group('Scheduled-day handling', () {
    // Mon Oct 19, Wed 21, Fri 23, Mon 26 are due. Tue 20, Thu 22, Sat 24,
    // Sun 25 and today (Tue 27) are not.
    const Schedule monWedFri = Schedule(
      type: FrequencyType.daysOfWeek,
      weekdays: <int>{1, 3, 5},
    );

    test('unscheduled days never break the streak', () {
      final HabitStats s = engine.stats(
        habit(schedule: monWedFri, created: oct(19)),
        recs(doneDays(<int>[19, 21, 23, 26])),
      );
      expect(s.currentStreak, 4);
      expect(s.bestStreak, 4);
    });

    test('a missed scheduled day does break it', () {
      final HabitStats s = engine.stats(
        habit(schedule: monWedFri, created: oct(19)),
        recs(doneDays(<int>[19, 23, 26])), // missed Wed 21
      );
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 2);
    });

    test('a bonus completion on an unscheduled day does not change the streak', () {
      const Schedule monOnly =
          Schedule(type: FrequencyType.daysOfWeek, weekdays: <int>{1});
      final HabitStats s = engine.stats(
        habit(schedule: monOnly, created: oct(19)),
        recs(doneDays(<int>[19, 21, 26])), // 21st is a Wednesday
      );
      expect(s.currentStreak, 2);
    });

    test('outcomeOn labels each kind of day', () {
      final Habit h = habit(schedule: monWedFri, created: oct(19));
      final Map<String, CompletionRecord> r = recs(doneDays(<int>[19]));
      final DateTime start = engine.startDate(h, r);
      expect(engine.outcomeOn(h, oct(18), r, start), DayOutcome.beforeStart);
      expect(engine.outcomeOn(h, oct(19), r, start), DayOutcome.success);
      expect(engine.outcomeOn(h, oct(20), r, start), DayOutcome.notScheduled);
      expect(engine.outcomeOn(h, oct(21), r, start), DayOutcome.failure);
      expect(engine.outcomeOn(h, oct(28), r, start), DayOutcome.future);
    });

    test('today is pending, not a failure, when due and incomplete', () {
      final Habit h = habit(created: oct(26));
      final DateTime start = engine.startDate(h, const <String, CompletionRecord>{});
      expect(
        engine.outcomeOn(h, today, const <String, CompletionRecord>{}, start),
        DayOutcome.pending,
      );
    });

    test('isDueOn follows the schedule and the start date', () {
      final Habit h = habit(schedule: monWedFri, created: oct(19));
      const Map<String, CompletionRecord> none = <String, CompletionRecord>{};
      expect(engine.isDueOn(h, oct(26), none), isTrue); // Monday
      expect(engine.isDueOn(h, oct(27), none), isFalse); // Tuesday
      expect(engine.isDueOn(h, oct(18), none), isFalse); // before start
      expect(engine.isDueOn(h, oct(28), none), isFalse); // future
    });
  });

  group('Quit habits (slip-free streak)', () {
    test('Due filter treats a slip-free day as complete and a recorded slip as incomplete', () {
      final Habit h = habit(type: HabitType.quit, created: oct(19));
      expect(engine.isDueOn(h, oct(27), const <String, CompletionRecord>{}), isFalse);
      expect(engine.isDueOn(h, oct(27), recs(<CompletionRecord>[slip(oct(27))])), isTrue);
    });

    test('every day is clean unless a slip is recorded, including today', () {
      final HabitStats s = engine.stats(
        habit(type: HabitType.quit),
        recs(<CompletionRecord>[slip(oct(25))]),
      );
      // Clean Oct 20-24 (5 days), slip on 25, clean 26 and 27.
      expect(s.bestStreak, 5);
      expect(s.currentStreak, 2);
    });

    test('no slips: the streak is every day since the start', () {
      final HabitStats s = engine.stats(
        habit(type: HabitType.quit),
        const <String, CompletionRecord>{},
      );
      expect(s.currentStreak, 8);
      expect(s.totalCompletions, 8);
    });

    test('a slip today resets the streak to zero', () {
      final HabitStats s = engine.stats(
        habit(type: HabitType.quit),
        recs(<CompletionRecord>[slip(today)]),
      );
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 7);
    });

    test('quit habits are always everyday, whatever the stored schedule', () {
      final Habit h = habit(
        type: HabitType.quit,
        schedule: const Schedule(
          type: FrequencyType.daysOfWeek,
          weekdays: <int>{1},
        ),
      );
      final HabitStats s = engine.stats(h, const <String, CompletionRecord>{});
      expect(s.currentStreak, 8);
    });

    test('count limit: above the limit is a slip', () {
      final Habit h = habit(
        type: HabitType.quit,
        tracking: TrackingMethod.count,
        goal: 2,
      );
      CompletionRecord withCount(double c) => CompletionRecord(
            habitId: 'h',
            dateKey: dateKey(today),
            updatedAt: today,
            count: c,
          );
      expect(engine.isSlipped(h, withCount(2)), isFalse);
      expect(engine.isSlipped(h, withCount(3)), isTrue);
    });

    test('checklist: any marked item is a slip', () {
      final Habit h = habit(
        type: HabitType.quit,
        tracking: TrackingMethod.checklist,
        checklist: const <ChecklistItem>[
          ChecklistItem(id: 'a', title: 'A'),
          ChecklistItem(id: 'b', title: 'B'),
        ],
      );
      CompletionRecord withChecked(Set<String> ids) => CompletionRecord(
            habitId: 'h',
            dateKey: dateKey(today),
            updatedAt: today,
            checkedItemIds: ids,
          );
      expect(engine.isSlipped(h, withChecked(<String>{})), isFalse);
      expect(engine.isSlipped(h, withChecked(<String>{'b'})), isTrue);
    });
  });

  group('Completion rules', () {
    CompletionRecord count(double c) => CompletionRecord(
          habitId: 'h',
          dateKey: dateKey(today),
          updatedAt: today,
          count: c,
        );

    test('count with a goal completes only when the goal is reached', () {
      final Habit h = habit(tracking: TrackingMethod.count, goal: 8);
      expect(engine.isCompleted(h, count(7)), isFalse);
      expect(engine.isCompleted(h, count(7.9)), isFalse);
      expect(engine.isCompleted(h, count(8)), isTrue);
      expect(engine.isCompleted(h, count(12)), isTrue);
      expect(engine.dayProgress(h, count(4)), closeTo(0.5, 1e-9));
      expect(engine.dayProgress(h, count(20)), 1);
    });

    test('count without a goal completes with any amount', () {
      final Habit h = habit(tracking: TrackingMethod.count);
      expect(engine.isCompleted(h, count(0)), isFalse);
      expect(engine.isCompleted(h, count(0.5)), isTrue);
    });

    test('checklist completes only when every item is ticked', () {
      final Habit h = habit(
        tracking: TrackingMethod.checklist,
        checklist: const <ChecklistItem>[
          ChecklistItem(id: 'a', title: 'A'),
          ChecklistItem(id: 'b', title: 'B'),
        ],
      );
      CompletionRecord withChecked(Set<String> ids) => CompletionRecord(
            habitId: 'h',
            dateKey: dateKey(today),
            updatedAt: today,
            checkedItemIds: ids,
          );
      expect(engine.isCompleted(h, withChecked(<String>{'a'})), isFalse);
      expect(engine.isCompleted(h, withChecked(<String>{'a', 'b'})), isTrue);
      expect(engine.isCompleted(h, withChecked(<String>{'a', 'zzz'})), isFalse);
      expect(engine.dayProgress(h, withChecked(<String>{'a'})), 0.5);
    });

    test('a checklist habit with no items is never complete', () {
      final Habit h = habit(tracking: TrackingMethod.checklist);
      expect(engine.isCompleted(h, done(today)), isFalse);
    });

    test('a missing record is never complete', () {
      expect(engine.isCompleted(habit(), null), isFalse);
      expect(engine.dayProgress(habit(), null), 0);
    });
  });

  group('Some days per period', () {
    const Schedule threePerWeek = Schedule(
      type: FrequencyType.somePerPeriod,
      timesPerPeriod: 3,
    );

    test('streak counts completed days in consecutive successful weeks', () {
      // Weeks start on Monday. Created Mon Sep 28.
      // Sep 28 week: 3 days -> ok. Oct 5 week: 3 days -> ok.
      // Oct 12 week: only 2 days -> fails, streak resets.
      // Oct 19 week: 3 days -> ok. Oct 26 week (current): 1 day so far.
      final List<CompletionRecord> list = <CompletionRecord>[
        done(DateTime(2026, 9, 28)),
        done(DateTime(2026, 9, 29)),
        done(DateTime(2026, 9, 30)),
        done(oct(5)),
        done(oct(6)),
        done(oct(7)),
        done(oct(12)),
        done(oct(13)),
        done(oct(19)),
        done(oct(20)),
        done(oct(21)),
        done(oct(26)),
      ];
      final HabitStats s = engine.stats(
        habit(schedule: threePerWeek, created: DateTime(2026, 9, 28)),
        recs(list),
      );
      expect(s.bestStreak, 6);
      expect(s.currentStreak, 4); // 3 from the Oct 19 week + 1 so far
    });

    test('the first, partial period is never penalised', () {
      // Created Thu Oct 22; only 2 days possible before the week ends.
      final HabitStats s = engine.stats(
        habit(schedule: threePerWeek, created: oct(22)),
        recs(<CompletionRecord>[done(oct(22)), done(oct(23)), done(oct(26))]),
      );
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
    });

    test('due until the period target is met', () {
      final Habit h = habit(
        schedule: const Schedule(
          type: FrequencyType.somePerPeriod,
          timesPerPeriod: 1,
        ),
        created: oct(19),
      );
      final Map<String, CompletionRecord> onlyMonday =
          recs(<CompletionRecord>[done(oct(26))]);
      expect(engine.isDueOn(h, oct(26), onlyMonday), isFalse); // completed day is not due
      expect(engine.isDueOn(h, oct(27), onlyMonday), isFalse); // target met
      expect(
        engine.isDueOn(h, oct(27), const <String, CompletionRecord>{}),
        isTrue,
      );
    });

    test('expected units per day are target / period length', () {
      final Habit h = habit(schedule: threePerWeek, created: oct(19));
      final Tally t = engine.tallyDay(
        h,
        oct(21),
        const <String, CompletionRecord>{},
        oct(19),
      );
      expect(t.expected, closeTo(3 / 7, 1e-9));
      expect(t.completed, 0);
    });
  });

  group('Score and completion rate', () {
    test('score is completed / due over the recent window', () {
      // Due Oct 20..26 (7 days; today is pending and excluded). 5 completed.
      final HabitStats s =
          engine.stats(habit(), recs(doneDays(<int>[20, 21, 22, 23, 24])));
      expect(s.hasScoreData, isTrue);
      expect(s.score, closeTo(5 / 7, 1e-9));
      expect(s.completionRate, closeTo(5 / 7, 1e-9));
    });

    test('a perfect record scores 100%', () {
      final HabitStats s = engine.stats(
        habit(),
        recs(doneDays(<int>[20, 21, 22, 23, 24, 25, 26])),
      );
      expect(s.score, 1);
    });

    test('a habit created today has no score data yet', () {
      final HabitStats s = engine.stats(
        habit(created: today),
        const <String, CompletionRecord>{},
      );
      expect(s.hasScoreData, isFalse);
      expect(s.score, 0);
    });

    test('score window only looks at the last 30 days', () {
      // Created 100 days ago, perfect for the last 30 days, nothing before.
      final DateTime created = addDays(today, -99);
      final List<CompletionRecord> list = <CompletionRecord>[
        for (int i = 1; i <= 30; i++) done(addDays(today, -i)),
      ];
      final HabitStats s = engine.stats(habit(created: created), recs(list));
      expect(s.score, 1);
      expect(s.completionRate, lessThan(0.5));
    });

    test('overall score is the mean of habits that have data', () {
      const HabitStats a = HabitStats(
        currentStreak: 0,
        bestStreak: 0,
        score: 1,
        hasScoreData: true,
        totalCompletions: 0,
        daysTracked: 0,
        completionRate: 1,
      );
      const HabitStats b = HabitStats(
        currentStreak: 0,
        bestStreak: 0,
        score: 0.5,
        hasScoreData: true,
        totalCompletions: 0,
        daysTracked: 0,
        completionRate: 0.5,
      );
      expect(engine.overallScore(<HabitStats>[a, b, HabitStats.empty]), 0.75);
      expect(engine.overallScore(<HabitStats>[HabitStats.empty]), 0);
      expect(engine.overallScore(const <HabitStats>[]), 0);
    });
  });
}
