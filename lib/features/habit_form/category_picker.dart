import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/ids.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';

/// Result of the category sheet: [id] is null when "No category" was chosen.
class CategoryChoice {
  const CategoryChoice(this.id);
  final String? id;
}

/// Lets the user pick a category or create a new one. Resolves to null when
/// dismissed without choosing.
Future<CategoryChoice?> showCategoryPicker(
  BuildContext context, {
  required String? selectedId,
}) {
  return showTickSheet<CategoryChoice>(
    context: context,
    title: 'Select Category',
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final AppData? data = ref.watch(appDataProvider).valueOrNull;
        final List<HabitCategory> categories =
            data?.sortedCategories ?? const <HabitCategory>[];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppDimens.gap),
          children: <Widget>[
            _tile(
              context,
              label: 'No category',
              selected: selectedId == null,
              onTap: () => Navigator.of(context).pop(const CategoryChoice(null)),
            ),
            for (final HabitCategory c in categories)
              _tile(
                context,
                label: c.name,
                selected: selectedId == c.id,
                onTap: () => Navigator.of(context).pop(CategoryChoice(c.id)),
              ),
            _tile(
              context,
              label: 'New category',
              icon: Icons.add_rounded,
              selected: false,
              onTap: () => _createCategory(context, ref, categories.length),
            ),
          ],
        );
      },
    ),
  );
}

Widget _tile(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
  IconData? icon,
}) {
  return ListTile(
    leading: Icon(
      icon ?? Icons.label_outline_rounded,
      color: AppColors.textSecondary,
    ),
    title: Text(label),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.cyan)
        : null,
    onTap: onTap,
  );
}

Future<void> _createCategory(
  BuildContext context,
  WidgetRef ref,
  int existingCount,
) async {
  final String? name = await showNameDialog(
    context,
    title: 'New category',
    hint: 'Category name',
  );
  if (name == null || !context.mounted) return;
  final HabitCategory category = HabitCategory(
    id: newId(),
    name: name,
    sortOrder: existingCount,
  );
  final bool ok = await guarded(
    context,
    () => ref.read(appDataProvider.notifier).saveCategory(category),
  );
  if (ok && context.mounted) {
    Navigator.of(context).pop(CategoryChoice(category.id));
  }
}

/// Small dialog asking for a non-empty name. Resolves to the trimmed name.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _NameDialog(title: title, hint: hint, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.initial,
  });

  final String title;
  final String hint;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: TickTextField(
        hintText: widget.hint,
        controller: _controller,
        autofocus: true,
        errorText: _error,
        onChanged: (String _) => setState(() => _error = null),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
