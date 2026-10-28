import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';
import 'package:tickoff_replacement/domain/logic/analytics_engine.dart';
import 'package:tickoff_replacement/domain/logic/habit_engine.dart';
import 'package:tickoff_replacement/domain/models/models.dart';

final HabitEngine engine = HabitEngine(today: DateTime(2026, 10, 27));
final AnalyticsEngine analytics = AnalyticsEngine(engine);

DateTime oct(int day) => DateTime(2026, 10, day);

Habit habit(String id) => Habit(id: id, title: id, createdAt: oct(20));

CompletionRecord done(String id, DateTime d) => CompletionRecord(
      habitId: id,
      dateKey: dateKey(d),
      updatedAt: d,
      done: true,
    );

// Habit A: done Oct 20..26. Habit B: done Oct 20..22 only.
final Habit a = habit('A');
final Habit b = habit('B');
final CompletionIndex index = <String, Map<String, CompletionRecord>>{
  'A': <String, CompletionRecord>{
    for (int d = 20; d <= 26; d++) dateKey(oct(d)): done('A', oct(d)),
  },
  'B': <String, CompletionRecord>{
    for (int d = 20; d <= 22; d++) dateKey(oct(d)): done('B', oct(d)),
  },
};

void main() {
  test('combined tally over a range', () {
    final Tally t = analytics.tally(<Habit>[a, b], index, oct(20), oct(27));
    expect(t.expected, 14); // 7 due days each; today is still pending
    expect(t.completed, 10);
    expect(t.rate, closeTo(10 / 14, 1e-9));
  });

  test('habit-specific tally', () {
    expect(analytics.tally(<Habit>[a], index, oct(20), oct(27)).rate, 1);
    expect(
      analytics.tally(<Habit>[b], index, oct(20), oct(27)).rate,
      closeTo(3 / 7, 1e-9),
    );
  });

  test('nothing is expected before the habits existed', () {
    final Tally t = analytics.tally(
      <Habit>[a, b],
      index,
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
    );
    expect(t.hasData, isFalse);
    expect(t.rate, 0);
  });

  test('no habits means no data', () {
    final Tally t = analytics.tally(
      const <Habit>[],
      const <String, Map<String, CompletionRecord>>{},
      oct(1),
      oct(27),
    );
    expect(t.hasData, isFalse);
  });

  group('trend buckets', () {
    test('up to 31 days: one bar per day', () {
      final List<TrendPoint> points =
          analytics.trend(<Habit>[a, b], index, oct(20), oct(27));
      expect(points.length, 8);
      expect(points.first.tally.rate, 1); // Oct 20: both done
      expect(points[3].tally.rate, closeTo(0.5, 1e-9)); // Oct 23: only A
      expect(points.last.tally.hasData, isFalse); // today is pending
    });

    test('up to 120 days: one bar per week, clipped to the range', () {
      final List<TrendPoint> points = analytics.trend(
        <Habit>[a, b],
        index,
        DateTime(2026, 9, 1),
        oct(27),
      );
      expect(points.length, 9);
      expect(points.first.start, DateTime(2026, 9, 1));
      expect(points.last.start, oct(26));
      final double expected = points.fold<double>(
        0,
        (double sum, TrendPoint p) => sum + p.tally.expected,
      );
      expect(expected, 14); // buckets add up to the whole range
    });

    test('longer ranges: one bar per month', () {
      final List<TrendPoint> points = analytics.trend(
        <Habit>[a, b],
        index,
        DateTime(2026, 1, 1),
        oct(27),
      );
      expect(points.length, 10);
      expect(points.first.label, 'Jan');
      expect(points.last.label, 'Oct');
    });

    test('an inverted range gives no points', () {
      expect(
        analytics.trend(<Habit>[a], index, oct(27), oct(20)),
        isEmpty,
      );
    });
  });

  test('period summaries', () {
    final List<PeriodSummary> s = analytics.summaries(<Habit>[a, b], index);
    PeriodSummary byLabel(String l) =>
        s.firstWhere((PeriodSummary x) => x.label == l);

    expect(byLabel('Today').tally.hasData, isFalse);
    expect(byLabel('Yesterday').tally.expected, 2);
    expect(byLabel('Yesterday').tally.completed, 1); // only A on Oct 26
    expect(byLabel('This week').tally.completed, 1);
    expect(byLabel('Last week').tally.expected, 12); // Oct 20..25 x 2 habits
    expect(byLabel('Last week').tally.completed, 9);
    expect(byLabel('This month').tally.expected, 14);
    expect(byLabel('Last month').tally.hasData, isFalse);
  });

  test('range start', () {
    expect(analytics.rangeStart(AnalyticsRange.week, <Habit>[a], index), oct(21));
    expect(analytics.rangeStart(AnalyticsRange.all, <Habit>[a], index), oct(20));
    expect(analytics.earliestStart(const <Habit>[], index), oct(27));
  });
}
