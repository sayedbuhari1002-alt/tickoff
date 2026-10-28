import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';

/// How one day of a [MonthCalendar] is painted.
class DayDecoration {
  const DayDecoration({this.fill, this.textColor});

  /// Filled circle behind the number (null = none).
  final Color? fill;

  /// Number colour override.
  final Color? textColor;
}

/// Monday-first month grid with month navigation, matching the calendar sheet
/// in the reference (gold arrows, grey out-of-month days, ringed today).
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.today,
    required this.decorate,
    this.onDayTap,
    this.firstMonth,
    this.accent = AppColors.gold,
  });

  final DateTime today;

  /// Decoration for in-month days up to today.
  final DayDecoration Function(DateTime day) decorate;

  /// Called for tapped days that are not in the future.
  final ValueChanged<DateTime>? onDayTap;

  /// Earliest month the user may navigate to (null = unlimited).
  final DateTime? firstMonth;
  final Color accent;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = monthStart(widget.today);

  bool get _canGoForward => _month.isBefore(monthStart(widget.today));

  bool get _canGoBack {
    final DateTime? first = widget.firstMonth;
    return first == null || _month.isAfter(monthStart(first));
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime gridStart = weekStart(_month);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Previous month',
              icon: Icon(
                Icons.chevron_left_rounded,
                color: _canGoBack ? widget.accent : AppColors.textHint,
              ),
              onPressed: _canGoBack ? () => _shift(-1) : null,
            ),
            Expanded(
              child: Text(
                monthYear(_month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _canGoForward ? widget.accent : AppColors.textHint,
              ),
              onPressed: _canGoForward ? () => _shift(1) : null,
            ),
          ],
        ),
        Row(
          children: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map(
                (String d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        for (int row = 0; row < 6; row++)
          Row(
            children: <Widget>[
              for (int col = 0; col < 7; col++)
                Expanded(child: _cell(addDays(gridStart, row * 7 + col))),
            ],
          ),
      ],
    );
  }

  Widget _cell(DateTime day) {
    final bool inMonth = day.month == _month.month;
    final bool future = day.isAfter(widget.today);
    final bool isToday = isSameDay(day, widget.today);
    final DayDecoration deco = (inMonth && !future)
        ? widget.decorate(day)
        : const DayDecoration();

    Color textColor;
    if (!inMonth) {
      textColor = AppColors.textHint;
    } else if (future) {
      textColor = AppColors.textHint;
    } else {
      textColor = deco.textColor ?? AppColors.textPrimary;
    }

    final Widget circle = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: deco.fill,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: widget.accent, width: 2) : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: inMonth && !future ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
        ),
      ),
    );

    return SizedBox(
      height: 44,
      child: Center(
        child: (widget.onDayTap == null || future || !inMonth)
            ? circle
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onDayTap!(day),
                child: circle,
              ),
      ),
    );
  }
}
