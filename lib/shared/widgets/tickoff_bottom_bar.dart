import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Bottom navigation for Dashboard, Habits, Tasks and Notes, with one shared add button.
class TickoffBottomBar extends StatelessWidget {
  const TickoffBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
  });

  /// 0 = dashboard, 1 = habits, 2 = tasks, 3 = notes.
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomBarHeight,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavIcon(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
              ),
              Expanded(child: _NavIcon(icon: Icons.check_circle_outline_rounded, label: 'Habits', selected: currentIndex == 1, onTap: () => onSelect(1))),
              Semantics(
                button: true,
                label: 'Add task or habit',
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 30),
                  ),
                ),
              ),
              Expanded(child: _NavIcon(icon: Icons.task_alt_rounded, label: 'Tasks', selected: currentIndex == 2, onTap: () => onSelect(2))),
              Expanded(child: _NavIcon(icon: Icons.sticky_note_2_rounded, label: 'Notes', selected: currentIndex == 3, onTap: () => onSelect(3))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: selected ? AppColors.gold : AppColors.textHint,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.gold : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
