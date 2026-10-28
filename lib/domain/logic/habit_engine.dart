import 'dart:math' as math;

import '../../core/utils/date_utils.dart';
import '../models/models.dart';

/// Result of evaluating one habit on one calendar day.
enum DayOutcome {
  /// After today.
  future,

  /// Before the habit was created (or its first record).
  beforeStart,

  /// A day the habit is not due; never affects streaks or rates.
  notScheduled,

  /// Today, not completed yet. Neither breaks nor extends a streak.
  pending,

  /// Build: completed. Quit: slip-free.
  success,

  /// Build: due day that passed without completion. Quit: slipped.
  failure,
}

/// "Expected" vs "completed" units over some days. Regular habits expect 1 per
/// due day; "some days per period" habits expect target/period-length per day.
class Tally {
  const Tally({this.expected = 0, this.completed = 0});

  static const Tally zero = Tally();

  final double expected;
  final double completed;

  bool get hasData => expected > 0;

  /// completed / expected, limited to 0..1. Zero when nothing was expected.
  double get rate {
    if (expected <= 0) return 0;
    final double r = completed / expected;
    return r > 1 ? 1 : r;
  }

  Tally operator +(Tally other) => Tally(
        expected: expected + other.expected,
        completed: completed + other.completed,
      );
}

/// Everything shown about one habit's performance.
class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.score,
    required this.hasScoreData,
    required this.totalCompletions,
    required this.daysTracked,
    required this.completionRate,
  });

  static const HabitStats empty = HabitStats(
    currentStreak: 0,
    bestStreak: 0,
    score: 0,
    hasScoreData: false,
    totalCompletions: 0,
    daysTracked: 0,
    completionRate: 0,
  );

  /// Current run, in days.
  final int currentStreak;

  /// Longest run ever, in days.
  final int bestStreak;

  /// 0..1: completion rate over the last 30 days (see README).
  final double score;

  /// False when there were no due days in the score window.
  final bool hasScoreData;

  /// Days completed (Build) or slip-free (Quit) since the habit started.
  final int totalCompletions;

  /// Calendar days from the habit's start to today, inclusive.
  final int daysTracked;

  /// 0..1: completion rate since the habit started.
  final double completionRate;
}

class _Streaks {
  const _Streaks(this.current, this.best);
  final int current;
  final int best;
}

/// All streak, completion and score rules in one place so every screen uses
/// the same formulas. Pure Dart: no Flutter, no database.
///
/// [today] must be a date-only value in local time.
class HabitEngine {
  const HabitEngine({required this.today});

  final DateTime today;

  /// Score = completion rate over this many most recent days.
  static const int scoreWindowDays = 30;

  static const double _eps = 1e-9;

  // ---------------------------------------------------------------- one day

  /// Build habits: is the day complete according to the tracking method?
  bool isCompleted(Habit habit, CompletionRecord? record) {
    if (record == null) return false;
    switch (habit.tracking) {
      case TrackingMethod.tick:
        return record.done;
      case TrackingMethod.count:
        final double? goal = habit.dailyGoal;
        if (goal == null || goal <= 0) return record.count > _eps;
        return record.count >= goal - _eps;
      case TrackingMethod.checklist:
        if (habit.checklist.isEmpty) return false;
        return habit.checklist.every(
          (ChecklistItem i) => record.checkedItemIds.contains(i.id),
        );
    }
  }

  /// Quit habits: did the user slip? Tick = slip flag. Count = amount above the
  /// daily limit (limit defaults to 0). Checklist = any item marked.
  bool isSlipped(Habit habit, CompletionRecord? record) {
    if (record == null) return false;
    switch (habit.tracking) {
      case TrackingMethod.tick:
        return record.slipped;
      case TrackingMethod.count:
        return record.count > (habit.dailyGoal ?? 0) + _eps;
      case TrackingMethod.checklist:
        return habit.checklist.any(
          (ChecklistItem i) => record.checkedItemIds.contains(i.id),
        );
    }
  }

  /// Day-level success: Build = completed, Quit = not slipped.
  bool isSuccess(Habit habit, CompletionRecord? record) =>
      habit.type == HabitType.quit
          ? !isSlipped(habit, record)
          : isCompleted(habit, record);

  /// 0..1 progress for the progress ring on cards.
  double dayProgress(Habit habit, CompletionRecord? record) {
    if (habit.type == HabitType.quit) {
      return isSlipped(habit, record) ? 0 : 1;
    }
    if (record == null) return 0;
    switch (habit.tracking) {
      case TrackingMethod.tick:
        return record.done ? 1 : 0;
      case TrackingMethod.count:
        final double? goal = habit.dailyGoal;
        if (goal == null || goal <= 0) return record.count > _eps ? 1 : 0;
        return math.min(1.0, record.count / goal);
      case TrackingMethod.checklist:
        if (habit.checklist.isEmpty) return 0;
        final int done = habit.checklist
            .where((ChecklistItem i) => record.checkedItemIds.contains(i.id))
            .length;
        return done / habit.checklist.length;
    }
  }

  bool _isFlexible(Habit habit) =>
      habit.type == HabitType.build && habit.schedule.isFlexible;

  /// First day that counts for [habit]: its creation day, or an earlier day
  /// that already has a record (so back-filled history is never ignored).
  DateTime startDate(Habit habit, Map<String, CompletionRecord> records) {
    // A habit cannot have meaningful history before it existed. Legacy records
    // dated earlier than creation are ignored rather than extending its graph.
    return dateOnly(habit.createdAt);
  }

  /// Outcome of [habit] on [date]. [start] comes from [startDate].
  DayOutcome outcomeOn(
    Habit habit,
    DateTime date,
    Map<String, CompletionRecord> records,
    DateTime start,
  ) {
    final DateTime day = dateOnly(date);
    if (day.isAfter(today)) return DayOutcome.future;
    if (day.isBefore(start)) return DayOutcome.beforeStart;
    final CompletionRecord? record = records[dateKey(day)];

    if (habit.type == HabitType.quit) {
      // Quit habits are always "everyday": clean unless a slip was recorded.
      return isSlipped(habit, record) ? DayOutcome.failure : DayOutcome.success;
    }
    if (_isFlexible(habit)) {
      // Days are optional; only a completed day is shown.
      return isCompleted(habit, record)
          ? DayOutcome.success
          : DayOutcome.notScheduled;
    }
    if (!habit.schedule.isScheduledOn(day)) return DayOutcome.notScheduled;
    if (isCompleted(habit, record)) return DayOutcome.success;
    return isSameDay(day, today) ? DayOutcome.pending : DayOutcome.failure;
  }

  /// Whether the habit should appear under the dashboard "Due" filter on
  /// [date].
  bool isDueOn(
    Habit habit,
    DateTime date,
    Map<String, CompletionRecord> records,
  ) {
    final DateTime day = dateOnly(date);
    final DateTime start = startDate(habit, records);
    if (day.isAfter(today) || day.isBefore(start)) return false;
    // Due means still incomplete for this date. For Quit habits, a slip is
    // the failed outcome; a slip-free day is already successful by definition.
    final CompletionRecord? dayRecord = records[dateKey(day)];
    if (habit.type == HabitType.quit) return isSlipped(habit, dayRecord);
    if (isCompleted(habit, dayRecord)) return false;
    if (_isFlexible(habit)) {
      return _completedInPeriodBefore(habit, day, records) <
          habit.schedule.timesPerPeriod;
    }
    return habit.schedule.isScheduledOn(day);
  }

  int _completedInPeriodBefore(
    Habit habit,
    DateTime day,
    Map<String, CompletionRecord> records,
  ) {
    final DateTime ps = _periodStart(habit, day);
    int count = 0;
    for (DateTime d = ps; d.isBefore(day); d = addDays(d, 1)) {
      if (isCompleted(habit, records[dateKey(d)])) count++;
    }
    return count;
  }

  // ----------------------------------------------------------------- periods

  bool _weekly(Habit habit) => habit.schedule.period == PeriodUnit.week;

  DateTime _periodStart(Habit habit, DateTime d) =>
      _weekly(habit) ? weekStart(d) : monthStart(d);

  DateTime _periodEnd(Habit habit, DateTime ps) =>
      _weekly(habit) ? addDays(ps, 6) : monthEnd(ps);

  DateTime _nextPeriod(Habit habit, DateTime ps) => _weekly(habit)
      ? addDays(ps, 7)
      : DateTime(ps.year, ps.month + 1, 1);

  /// Expected completions per day for a "some days per period" habit.
  double _flexRate(Habit habit, DateTime day) {
    final int length = _weekly(habit) ? 7 : daysInMonth(day.year, day.month);
    return math.min(1.0, habit.schedule.timesPerPeriod / length);
  }

  // ------------------------------------------------------------------ tallies

  /// Expected/completed units for one day.
  Tally tallyDay(
    Habit habit,
    DateTime date,
    Map<String, CompletionRecord> records,
    DateTime start,
  ) {
    final DateTime day = dateOnly(date);
    if (day.isAfter(today) || day.isBefore(start)) return Tally.zero;
    if (_isFlexible(habit)) {
      final bool done = isCompleted(habit, records[dateKey(day)]);
      if (isSameDay(day, today) && !done) return Tally.zero;
      return Tally(expected: _flexRate(habit, day), completed: done ? 1 : 0);
    }
    switch (outcomeOn(habit, day, records, start)) {
      case DayOutcome.success:
        return const Tally(expected: 1, completed: 1);
      case DayOutcome.failure:
        return const Tally(expected: 1, completed: 0);
      case DayOutcome.future:
      case DayOutcome.beforeStart:
      case DayOutcome.notScheduled:
      case DayOutcome.pending:
        return Tally.zero;
    }
  }

  /// Sum of [tallyDay] over [from]..[to] (inclusive), clipped to the habit's
  /// lifetime.
  Tally tallyRange(
    Habit habit,
    Map<String, CompletionRecord> records,
    DateTime from,
    DateTime to, {
    DateTime? start,
  }) {
    final DateTime s = start ?? startDate(habit, records);
    DateTime first = dateOnly(from);
    DateTime last = dateOnly(to);
    if (first.isBefore(s)) first = s;
    if (last.isAfter(today)) last = today;
    Tally total = Tally.zero;
    for (DateTime d = first; !d.isAfter(last); d = addDays(d, 1)) {
      total += tallyDay(habit, d, records, s);
    }
    return total;
  }

  // ----------------------------------------------------------------- streaks

  _Streaks _regularStreaks(
    Habit habit,
    Map<String, CompletionRecord> records,
    DateTime start,
  ) {
    int run = 0;
    int best = 0;
    for (DateTime d = start; !d.isAfter(today); d = addDays(d, 1)) {
      switch (outcomeOn(habit, d, records, start)) {
        case DayOutcome.success:
          run++;
          if (run > best) best = run;
        case DayOutcome.failure:
          run = 0;
        case DayOutcome.future:
        case DayOutcome.beforeStart:
        case DayOutcome.notScheduled:
        case DayOutcome.pending:
          break;
      }
    }
    return _Streaks(run, best);
  }

  /// "Some days per period": a period (week or month) succeeds when it has at
  /// least `timesPerPeriod` completed days. The streak is the number of
  /// completed days inside consecutive successful periods. The period that is
  /// still running neither breaks nor ends the streak; a first, partial period
  /// is never penalised.
  _Streaks _flexibleStreaks(
    Habit habit,
    Map<String, CompletionRecord> records,
    DateTime start,
  ) {
    final int target = habit.schedule.timesPerPeriod;
    int run = 0;
    int best = 0;
    int inProgress = 0;
    for (DateTime ps = _periodStart(habit, start);
        !ps.isAfter(today);
        ps = _nextPeriod(habit, ps)) {
      final DateTime pe = _periodEnd(habit, ps);
      int completed = 0;
      for (DateTime d = ps; !d.isAfter(pe) && !d.isAfter(today); d = addDays(d, 1)) {
        if (d.isBefore(start)) continue;
        if (isCompleted(habit, records[dateKey(d)])) completed++;
      }
      final bool closed = pe.isBefore(today);
      final bool partialFirst = start.isAfter(ps);
      if (completed >= target) {
        run += completed;
        if (run > best) best = run;
      } else if (!closed) {
        inProgress = completed;
        if (run + completed > best) best = run + completed;
      } else if (partialFirst) {
        run += completed;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return _Streaks(run + inProgress, best);
  }

  // ------------------------------------------------------------------- stats

  HabitStats stats(Habit habit, Map<String, CompletionRecord> records) {
    final DateTime start = startDate(habit, records);
    if (start.isAfter(today)) return HabitStats.empty;

    final _Streaks streaks = _isFlexible(habit)
        ? _flexibleStreaks(habit, records, start)
        : _regularStreaks(habit, records, start);

    DateTime windowStart = addDays(today, -(scoreWindowDays - 1));
    if (windowStart.isBefore(start)) windowStart = start;
    final Tally window =
        tallyRange(habit, records, windowStart, today, start: start);
    final Tally lifetime = tallyRange(habit, records, start, today, start: start);

    int completions = 0;
    for (DateTime d = start; !d.isAfter(today); d = addDays(d, 1)) {
      final CompletionRecord? r = records[dateKey(d)];
      if (habit.type == HabitType.quit) {
        if (!isSlipped(habit, r)) completions++;
      } else if (isCompleted(habit, r)) {
        completions++;
      }
    }

    return HabitStats(
      currentStreak: streaks.current,
      bestStreak: streaks.best,
      score: window.rate,
      hasScoreData: window.hasData,
      totalCompletions: completions,
      daysTracked: daysBetween(start, today) + 1,
      completionRate: lifetime.rate,
    );
  }

  /// Overall Habit Score (0..1): the mean score of habits that have data.
  double overallScore(Iterable<HabitStats> all) {
    double sum = 0;
    int n = 0;
    for (final HabitStats s in all) {
      if (s.hasScoreData) {
        sum += s.score;
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }
}
