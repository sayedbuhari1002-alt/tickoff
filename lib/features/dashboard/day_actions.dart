import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/format.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';

/// Primary tap on a habit/day (dashboard check button, detail "Done" button,
/// calendar day): ticks, adds one step, or opens the checklist.
Future<void> tapDay(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime date,
) async {
  if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick();
  final AppDataNotifier notifier = ref.read(appDataProvider.notifier);
  switch (habit.tracking) {
    case TrackingMethod.tick:
      await guarded(context, () => notifier.toggleTick(habit, date));
    case TrackingMethod.count:
      await guarded(context, () => notifier.addCount(habit, date, habit.step));
    case TrackingMethod.checklist:
      await showChecklistSheet(context, habit: habit, date: date);
  }
}

/// Long press: opens the count editor for count habits.
Future<void> longPressDay(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime date,
) async {
  if (habit.tracking != TrackingMethod.count) return;
  final AppData? data = ref.read(appDataProvider).valueOrNull;
  final double current =
      data?.recordsFor(habit.id)[dateKey(date)]?.count ?? 0;
  final double? value =
      await showCountEditor(context, habit: habit, initial: current);
  if (value == null || !context.mounted) return;
  await guarded(
    context,
    () => ref.read(appDataProvider.notifier).setCount(habit, date, value),
  );
}

/// Dialog to type an exact count or nudge it up and down.
Future<double?> showCountEditor(
  BuildContext context, {
  required Habit habit,
  required double initial,
}) {
  return showDialog<double>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _CountEditorDialog(habit: habit, initial: initial),
  );
}

class _CountEditorDialog extends StatefulWidget {
  const _CountEditorDialog({required this.habit, required this.initial});

  final Habit habit;
  final double initial;

  @override
  State<_CountEditorDialog> createState() => _CountEditorDialogState();
}

class _CountEditorDialogState extends State<_CountEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: formatNumber(widget.initial));
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse() => double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  void _nudge(double delta) {
    final double current = _parse() ?? 0;
    final double next = current + delta;
    setState(() {
      _controller.text = formatNumber(next < 0 ? 0 : next);
      _error = null;
    });
  }

  void _save() {
    final double? value = _parse();
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a number that is zero or more.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final String unit = widget.habit.unit;
    return AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.habit.title),
      content: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Decrease',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _nudge(-widget.habit.step),
          ),
          Expanded(
            child: TickTextField(
              hintText: unit.isEmpty ? 'Amount' : unit,
              controller: _controller,
              errorText: _error,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (String _) => setState(() => _error = null),
            ),
          ),
          IconButton(
            tooltip: 'Increase',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _nudge(widget.habit.step),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'Save',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet listing a checklist habit's items for [date]. Build habits tick
/// items done; Quit habits mark the items they slipped on.
Future<void> showChecklistSheet(
  BuildContext context, {
  required Habit habit,
  required DateTime date,
}) {
  return showTickSheet<void>(
    context: context,
    title: habit.title,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AppData? data = ref.watch(appDataProvider).valueOrNull;
          final Habit current = data?.habitById(habit.id) ?? habit;
          final CompletionRecord? record =
              data?.recordsFor(habit.id)[dateKey(date)];
          final Set<String> checked =
              record?.checkedItemIds ?? const <String>{};
          final bool quit = current.type == HabitType.quit;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  quit
                      ? 'Tick the items you slipped on.'
                      : 'The day is done when every item is ticked.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final ChecklistItem item in current.checklist)
                CheckboxListTile(
                  value: checked.contains(item.id),
                  activeColor: quit ? AppColors.danger : AppColors.gold,
                  checkColor: Colors.black,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.title),
                  onChanged: (bool? _) => guarded(
                    context,
                    () => ref
                        .read(appDataProvider.notifier)
                        .toggleChecklistItem(current, date, item.id),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
