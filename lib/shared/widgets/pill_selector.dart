import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// One option of a [PillSelector].
class PillOption<T> {
  const PillOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Equal-width segmented selector used for Build/Quit and Tick/Count/Checklist.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      final PillOption<T> option = options[i];
      final bool isSelected = option.value == selected;
      if (i > 0) children.add(const SizedBox(width: AppDimens.gapSm));
      children.add(
        Expanded(
          child: Semantics(
            button: true,
            selected: isSelected,
            label: option.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(option.value),
              child: Container(
                height: AppDimens.segmentHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.selectedSegment
                      : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: children);
  }
}
