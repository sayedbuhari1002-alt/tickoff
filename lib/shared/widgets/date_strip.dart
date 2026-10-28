import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';

/// Horizontal weekly date selector. Today sits at the right edge and the
/// strip scrolls back through [dayCount] days of history (no future days).
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.today,
    required this.selected,
    required this.onSelected,
    this.dayCount = 730,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final int dayCount;

  static const double _height = 84;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemWidth = constraints.maxWidth / 7;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemExtent: itemWidth,
            itemCount: dayCount,
            itemBuilder: (BuildContext context, int index) {
              final DateTime day = addDays(today, -index);
              return _DayItem(
                day: day,
                selected: isSameDay(day, selected),
                onTap: () => onSelected(day),
              );
            },
          );
        },
      ),
    );
  }
}

class _DayItem extends StatelessWidget {
  const _DayItem({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${weekdayShort(day)} ${dayMonthLabel(day)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              weekdayShort(day),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : const Color(0xFF3A3A3A),
                  width: selected ? 2.5 : 1.5,
                ),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
