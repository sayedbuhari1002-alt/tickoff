import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/analytics_engine.dart';
import '../../shared/utils/format.dart';

/// Bar chart of completion rate per bucket (day, week or month). Bars are
/// scaled 0-100%; buckets without any due habit show a thin placeholder.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  /// `Daily`, `Weekly` or `Monthly`, depending on how the buckets were cut.
  static String caption(List<TrendPoint> points) {
    if (points.isEmpty) return 'Completion rate';
    final int span = daysBetween(points.first.start, points.first.end) + 1;
    if (points.length == 1 || span <= 1) return 'Daily completion rate';
    return span <= 7 ? 'Weekly completion rate' : 'Monthly completion rate';
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final String middle = points[points.length ~/ 2].label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final TrendPoint p in points)
                Expanded(
                  child: Tooltip(
                    message: p.tally.hasData
                        ? '${p.label}: ${percentLabel(p.tally.rate)}'
                        : '${p.label}: nothing due',
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: points.length > 40 ? 0.5 : 1.5,
                      ),
                      child: FractionallySizedBox(
                        heightFactor: p.tally.hasData
                            ? math.max(p.tally.rate, 0.03)
                            : 0.03,
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.tally.hasData
                                ? AppColors.gold
                                : AppColors.heatmapEmpty,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _label(points.first.label),
            _label(middle),
            _label(points.last.label),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
}
