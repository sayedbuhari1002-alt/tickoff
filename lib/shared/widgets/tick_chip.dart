import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Small rounded chip used for the dashboard category and All/Due filters.
///
/// Unselected: dark with a thin border. Selected: either gold-filled
/// ([filledWhenSelected]) like the "Due" filter, or white-outlined like the
/// selected category chip.
class TickChip extends StatelessWidget {
  const TickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.filledWhenSelected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filledWhenSelected;

  @override
  Widget build(BuildContext context) {
    final bool filled = selected && filledWhenSelected;
    final Color foreground = filled
        ? Colors.black
        : (selected ? AppColors.textPrimary : AppColors.textSecondary);
    final Color background = filled ? AppColors.gold : AppColors.surface;
    final Color borderColor = filled
        ? AppColors.gold
        : (selected ? AppColors.textPrimary : AppColors.border);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
