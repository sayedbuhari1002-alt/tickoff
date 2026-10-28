import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';

/// What one square of the heatmap shows.
enum HeatCell { hidden, empty, done, missed, clean, slipped }

/// Maps a day's engine outcome to a heatmap square.
HeatCell heatCellFor(
  HabitEngine engine,
  Habit habit,
  DateTime day,
  Map<String, CompletionRecord> records,
  DateTime start,
) {
  final bool quit = habit.type == HabitType.quit;
  switch (engine.outcomeOn(habit, day, records, start)) {
    case DayOutcome.future:
      return HeatCell.hidden;
    case DayOutcome.beforeStart:
    case DayOutcome.pending:
      return HeatCell.empty;
    case DayOutcome.success:
      return quit ? HeatCell.clean : HeatCell.done;
    case DayOutcome.failure:
      return quit ? HeatCell.slipped : HeatCell.missed;
    case DayOutcome.notScheduled:
      // A day completed although not due still shows as done.
      return (!quit && engine.isCompleted(habit, records[dateKey(day)]))
          ? HeatCell.done
          : HeatCell.empty;
  }
}

/// GitHub-style progress grid: one column per week, one row per weekday
/// (Monday at the top), ending with the current week.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.engine,
    required this.records,
  });

  final Habit habit;
  final HabitEngine engine;
  final Map<String, CompletionRecord> records;

  static const double _cell = 11;
  static const double _gap = 3;
  static const double height = 7 * _cell + 6 * _gap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(habit.colorValue);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int fit =
            ((constraints.maxWidth + _gap) / (_cell + _gap)).floor();
        final int columns = math.max(1, math.min(60, fit));
        final DateTime lastWeek = weekStart(engine.today);
        final DateTime firstWeek = addDays(lastWeek, -7 * (columns - 1));
        final DateTime start = engine.startDate(habit, records);
        final List<HeatCell> cells = <HeatCell>[
          for (int c = 0; c < columns; c++)
            for (int r = 0; r < 7; r++)
              heatCellFor(
                engine,
                habit,
                addDays(firstWeek, c * 7 + r),
                records,
                start,
              ),
        ];
        return SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _HeatPainter(cells: cells, columns: columns, color: color),
          ),
        );
      },
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.cells,
    required this.columns,
    required this.color,
  });

  final List<HeatCell> cells;
  final int columns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < 7; r++) {
        final HeatCell cell = cells[c * 7 + r];
        if (cell == HeatCell.hidden) continue;
        switch (cell) {
          case HeatCell.done:
            paint.color = color;
          case HeatCell.clean:
            paint.color = color.withAlpha(120);
          case HeatCell.missed:
            paint.color = color.withAlpha(40);
          case HeatCell.slipped:
            paint.color = AppColors.danger;
          case HeatCell.empty:
          case HeatCell.hidden:
            paint.color = AppColors.heatmapEmpty;
        }
        final Rect rect = Rect.fromLTWH(
          c * (HabitHeatmap._cell + HabitHeatmap._gap),
          r * (HabitHeatmap._cell + HabitHeatmap._gap),
          HabitHeatmap._cell,
          HabitHeatmap._cell,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.color != color || old.columns != columns || old.cells != cells;
}
