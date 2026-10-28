import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/ids.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/widgets.dart';

/// "Add Checklist" dialog: a title and an optional reminder. Resolves to the
/// new/edited item, or null when cancelled.
Future<ChecklistItem?> showChecklistDialog(
  BuildContext context, {
  ChecklistItem? initial,
}) {
  return showDialog<ChecklistItem>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ChecklistDialog(initial: initial),
  );
}

class _ChecklistDialog extends StatefulWidget {
  const _ChecklistDialog({this.initial});

  final ChecklistItem? initial;

  @override
  State<_ChecklistDialog> createState() => _ChecklistDialogState();
}

class _ChecklistDialogState extends State<_ChecklistDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late Reminder _reminder = widget.initial?.reminder ?? const Reminder();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (picked != null) {
      setState(() {
        _reminder = _reminder.copyWith(
          minutesOfDay: picked.hour * 60 + picked.minute,
        );
      });
    }
  }

  void _submit() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a checklist title.');
      return;
    }
    if (_reminder.enabled && _reminder.weekdays.isEmpty) {
      setState(() => _error = 'Pick at least one reminder day.');
      return;
    }
    Navigator.of(context).pop(
      ChecklistItem(
        id: widget.initial?.id ?? newId(),
        title: title,
        reminder: _reminder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.initial == null ? 'Add Checklist' : 'Edit Checklist',
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TickTextField(
              hintText: 'Enter Checklist Title',
              controller: _title,
              autofocus: true,
              errorText: _error,
              onChanged: (String _) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            SwitchRow(
              label: 'Set Reminder',
              value: _reminder.enabled,
              onChanged: (bool v) =>
                  setState(() => _reminder = _reminder.copyWith(enabled: v)),
            ),
            if (_reminder.enabled) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Time')),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _reminder.timeLabel,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WeekdayChips(
                selected: _reminder.weekdays,
                onChanged: (Set<int> days) => setState(() {
                  _reminder = _reminder.copyWith(weekdays: days);
                  _error = null;
                }),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.black,
          ),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
