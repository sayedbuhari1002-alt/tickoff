import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';

/// Mo Tu We Th Fr Sa Su toggles. Weekday numbers follow DateTime.weekday
/// (1 = Monday ... 7 = Sunday). Selected chips use the pale cyan accent.
class WeekdayChips extends StatelessWidget {
  const WeekdayChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _chip(i + 1, weekdayChipLabels[i]),
            ),
          ),
      ],
    );
  }

  Widget _chip(int weekday, String label) {
    final bool on = selected.contains(weekday);
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final Set<int> next = Set<int>.of(selected);
          if (!next.add(weekday)) next.remove(weekday);
          onChanged(next);
        },
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.cyan : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
