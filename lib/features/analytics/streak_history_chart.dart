import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/analytics_engine.dart';
import '../../domain/models/habit.dart';

class StreakHistoryPoint {
  const StreakHistoryPoint({required this.day, required this.streak, required this.hasData});
  final DateTime day;
  final int streak;
  final bool hasData;
}

/// Daily running-streak history. Unscheduled days do not break the run.
class StreakHistoryChart extends StatelessWidget {
  const StreakHistoryChart({super.key, required this.points});
  final List<StreakHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || !points.any((StreakHistoryPoint p) => p.hasData)) {
      return const Text('No streak history in this date range yet.', style: TextStyle(color: AppColors.textSecondary));
    }
    final int maximum = points.fold<int>(1, (int value, StreakHistoryPoint p) => value > p.streak ? value : p.streak);
    final int middle = points.length ~/ 2;
    String label(DateTime d) => '${d.day}/${d.month}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((StreakHistoryPoint point) {
              final double height = point.streak / maximum;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Tooltip(
                    message: '${label(point.day)}: ${point.hasData ? '${point.streak} successful due days in current run' : 'No scheduled activity'}',
                    child: FractionallySizedBox(
                      heightFactor: point.hasData ? (height < 0.035 ? 0.035 : height) : 0.025,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: point.hasData ? AppColors.gold : AppColors.heatmapEmpty,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label(points.first.day), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(label(points[middle].day), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(label(points.last.day), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

List<StreakHistoryPoint> buildStreakHistory({
  required AnalyticsEngine analytics,
  required List<Habit> habits,
  required CompletionIndex records,
  required DateTime from,
  required DateTime today,
}) {
  final DateTime recent = today.subtract(const Duration(days: 29));
  final DateTime lowerBound = from.isAfter(recent) ? from : recent;
  final List<StreakHistoryPoint> points = <StreakHistoryPoint>[];
  int run = 0;
  for (DateTime day = DateTime(lowerBound.year, lowerBound.month, lowerBound.day); !day.isAfter(today); day = addDays(day, 1)) {
    final tally = analytics.tally(habits, records, day, day);
    if (!tally.hasData) {
      points.add(StreakHistoryPoint(day: day, streak: run, hasData: false));
    } else {
      run = tally.rate >= 1 ? run + 1 : 0;
      points.add(StreakHistoryPoint(day: day, streak: run, hasData: true));
    }
  }
  return points;
}
