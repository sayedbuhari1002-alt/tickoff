import '../../core/utils/date_utils.dart';
import '../models/models.dart';
import 'habit_engine.dart';

/// Date ranges offered by the analytics screen.
enum AnalyticsRange {
  week('7D', 7),
  month('30D', 30),
  quarter('90D', 90),
  year('1Y', 365),
  all('All', null);

  const AnalyticsRange(this.label, this.days);

  final String label;

  /// Number of days ending today, or null for "since the first habit".
  final int? days;
}

/// One bar of the trend chart.
class TrendPoint {
  const TrendPoint({
    required this.start,
    required this.end,
    required this.label,
    required this.tally,
  });

  final DateTime start;
  final DateTime end;
  final String label;
  final Tally tally;
}

/// A labelled period total (Today, This week, ...).
class PeriodSummary {
  const PeriodSummary({required this.label, required this.tally});

  final String label;
  final Tally tally;
}

typedef CompletionIndex = Map<String, Map<String, CompletionRecord>>;

/// Aggregations over many habits. Every number comes from the completion
/// records passed in; nothing is hard-coded.
class AnalyticsEngine {
  const AnalyticsEngine(this.engine);

  final HabitEngine engine;

  DateTime get today => engine.today;

  Map<String, CompletionRecord> _recs(CompletionIndex all, Habit h) =>
      all[h.id] ?? const <String, CompletionRecord>{};

  /// Earliest start date among [habits]; today when there are none.
  DateTime earliestStart(List<Habit> habits, CompletionIndex all) {
    DateTime earliest = today;
    for (final Habit h in habits) {
      final DateTime s = engine.startDate(h, _recs(all, h));
      if (s.isBefore(earliest)) earliest = s;
    }
    return earliest;
  }

  DateTime rangeStart(
    AnalyticsRange range,
    List<Habit> habits,
    CompletionIndex all,
  ) {
    final int? days = range.days;
    if (days != null) return addDays(today, -(days - 1));
    return earliestStart(habits, all);
  }

  /// Combined tally of [habits] over [from]..[to].
  Tally tally(
    List<Habit> habits,
    CompletionIndex all,
    DateTime from,
    DateTime to,
  ) {
    Tally total = Tally.zero;
    for (final Habit h in habits) {
      total += engine.tallyRange(h, _recs(all, h), from, to);
    }
    return total;
  }

  /// Bars for the chart: daily up to 31 days, weekly up to 120 days, monthly
  /// beyond that.
  List<TrendPoint> trend(
    List<Habit> habits,
    CompletionIndex all,
    DateTime from,
    DateTime to,
  ) {
    final DateTime first = dateOnly(from);
    final DateTime last = dateOnly(to);
    if (last.isBefore(first)) return const <TrendPoint>[];
    final int span = daysBetween(first, last) + 1;
    final List<TrendPoint> points = <TrendPoint>[];

    if (span <= 31) {
      for (DateTime d = first; !d.isAfter(last); d = addDays(d, 1)) {
        points.add(_point(habits, all, d, d, '${d.day}'));
      }
    } else if (span <= 120) {
      for (DateTime ws = weekStart(first); !ws.isAfter(last); ws = addDays(ws, 7)) {
        final DateTime s = ws.isBefore(first) ? first : ws;
        final DateTime e = addDays(ws, 6).isAfter(last) ? last : addDays(ws, 6);
        points.add(_point(habits, all, s, e, '${s.day} ${monthShort(s)}'));
      }
    } else {
      for (DateTime ms = monthStart(first); !ms.isAfter(last); ms = DateTime(ms.year, ms.month + 1, 1)) {
        final DateTime s = ms.isBefore(first) ? first : ms;
        final DateTime me = monthEnd(ms);
        final DateTime e = me.isAfter(last) ? last : me;
        points.add(_point(habits, all, s, e, monthShort(s)));
      }
    }
    return points;
  }

  TrendPoint _point(
    List<Habit> habits,
    CompletionIndex all,
    DateTime s,
    DateTime e,
    String label,
  ) {
    return TrendPoint(
      start: s,
      end: e,
      label: label,
      tally: tally(habits, all, s, e),
    );
  }

  /// Today / Yesterday / This week / Last week / This month / Last month.
  List<PeriodSummary> summaries(List<Habit> habits, CompletionIndex all) {
    final DateTime thisWeek = weekStart(today);
    final DateTime lastWeek = addDays(thisWeek, -7);
    final DateTime thisMonth = monthStart(today);
    final DateTime lastMonth = DateTime(today.year, today.month - 1, 1);
    final DateTime yesterday = addDays(today, -1);
    return <PeriodSummary>[
      PeriodSummary(label: 'Today', tally: tally(habits, all, today, today)),
      PeriodSummary(
        label: 'Yesterday',
        tally: tally(habits, all, yesterday, yesterday),
      ),
      PeriodSummary(
        label: 'This week',
        tally: tally(habits, all, thisWeek, today),
      ),
      PeriodSummary(
        label: 'Last week',
        tally: tally(habits, all, lastWeek, addDays(thisWeek, -1)),
      ),
      PeriodSummary(
        label: 'This month',
        tally: tally(habits, all, thisMonth, today),
      ),
      PeriodSummary(
        label: 'Last month',
        tally: tally(habits, all, lastMonth, monthEnd(lastMonth)),
      ),
    ];
  }
}
