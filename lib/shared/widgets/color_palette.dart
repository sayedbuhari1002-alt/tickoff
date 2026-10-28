import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Horizontally scrollable two-row colour swatch picker.
class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    this.colors = AppColors.habitPalette,
  });

  final List<Color> colors;

  /// ARGB value of the selected colour (see `Color.toARGB32`/`Habit.colorValue`).
  final int selectedValue;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final int half = (colors.length + 1) ~/ 2;
    final List<Color> top = colors.sublist(0, half);
    final List<Color> bottom = colors.sublist(half);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _row(top),
            const SizedBox(height: 8),
            _row(bottom),
          ],
        ),
      ),
    );
  }

  Widget _row(List<Color> rowColors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rowColors.map(_swatch).toList(),
    );
  }

  Widget _swatch(Color color) {
    final bool isSelected = color.value == selectedValue;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Colour',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(color),
        child: Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
