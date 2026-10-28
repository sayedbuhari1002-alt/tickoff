import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/habit_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/format.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import 'category_picker.dart';
import 'checklist_dialog.dart';
import 'icon_picker_sheet.dart';

/// Add / Edit Habit. Pass [habitId] to edit an existing habit.
class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.habitId});

  final String? habitId;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _goal = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  final TextEditingController _step = TextEditingController(text: '1');

  bool _initialized = false;
  Habit? _editing;

  String _iconKey = Habit.defaultIconKey;
  int _colorValue = Habit.defaultColorValue;
  HabitType _type = HabitType.build;
  TrackingMethod _tracking = TrackingMethod.tick;
  FrequencyType _frequency = FrequencyType.everyday;
  Set<int> _weekdays = <int>{};
  Set<int> _monthDays = <int>{};
  int _timesPerPeriod = 1;
  PeriodUnit _period = PeriodUnit.week;
  Reminder _reminder = const Reminder();
  String? _categoryId;
  bool _showStreaks = true;
  List<ChecklistItem> _checklist = <ChecklistItem>[];

  String? _titleError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _goal.dispose();
    _unit.dispose();
    _step.dispose();
    super.dispose();
  }

  void _initialize(AppData data) {
    _initialized = true;
    final String? id = widget.habitId;
    if (id == null) return;
    final Habit? h = data.habitById(id);
    if (h == null) return;
    _editing = h;
    _title.text = h.title;
    _description.text = h.description;
    _iconKey = h.iconKey;
    _colorValue = h.colorValue;
    _type = h.type;
    _tracking = h.tracking;
    _frequency = h.schedule.type;
    _weekdays = Set<int>.of(h.schedule.weekdays);
    _monthDays = Set<int>.of(h.schedule.monthDays);
    _timesPerPeriod = h.schedule.timesPerPeriod;
    _period = h.schedule.period;
    _reminder = h.reminder;
    _categoryId = h.categoryId;
    _showStreaks = h.showStreaksOnTimeline;
    _checklist = List<ChecklistItem>.of(h.checklist);
    if (h.dailyGoal != null) _goal.text = formatNumber(h.dailyGoal!);
    _unit.text = h.unit;
    _step.text = formatNumber(h.step);
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _nudge(TextEditingController c, double delta, {double min = 0}) {
    final double current = _parse(c.text) ?? 0;
    final double next = current + delta;
    setState(() => c.text = formatNumber(next < min ? min : next));
  }

  Future<void> _save(AppData data) async {
    if (_saving) return;
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Please enter a habit title.');
      return;
    }

    double? goal;
    double step = 1;
    if (_tracking == TrackingMethod.count) {
      final String goalText = _goal.text.trim();
      if (goalText.isNotEmpty) {
        goal = _parse(goalText);
        if (goal == null || goal <= 0) {
          showMessage(context, 'The daily goal must be a number above zero.');
          return;
        }
      }
      final double? parsedStep = _parse(_step.text);
      if (parsedStep == null || parsedStep <= 0) {
        showMessage(context, 'Each tap must add a number above zero.');
        return;
      }
      step = parsedStep;
    }

    final Schedule schedule = _type == HabitType.quit
        ? const Schedule()
        : Schedule(
            type: _frequency,
            weekdays: _weekdays,
            monthDays: _monthDays,
            timesPerPeriod: _timesPerPeriod,
            period: _period,
          );

    if (_reminder.enabled && _reminder.weekdays.isEmpty) {
      showMessage(context, 'Pick at least one reminder day.');
      return;
    }

    final Habit base =
        _editing ?? Habit.create(title: title, sortOrder: data.nextSortOrder);
    final Habit habit = base.copyWith(
      title: title,
      description: _description.text.trim(),
      iconKey: _iconKey,
      colorValue: _colorValue,
      type: _type,
      tracking: _tracking,
      schedule: schedule,
      reminder: _reminder,
      categoryId: _categoryId,
      clearCategory: _categoryId == null,
      showStreaksOnTimeline: _showStreaks,
      dailyGoal: goal,
      clearDailyGoal: goal == null,
      unit: _unit.text.trim(),
      step: step,
      checklist: _checklist,
    );

    final String? problem = habit.validate();
    if (problem != null) {
      showMessage(context, problem);
      return;
    }

    setState(() => _saving = true);
    final bool ok = await guarded(
      context,
      () => ref.read(appDataProvider.notifier).saveHabit(habit),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppData? data = ref.watch(appDataProvider).valueOrNull;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_initialized) _initialize(data);
    if (widget.habitId != null && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Habit')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Habit not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final bool quit = _type == HabitType.quit;
    final HabitCategory? category = data.categoryById(_categoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? 'Add Habit' : 'Edit Habit'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : () => _save(data),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.check_rounded, color: AppColors.textPrimary),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          AppDimens.gapSm,
          AppDimens.pagePadding,
          32,
        ),
        children: <Widget>[
          TickTextField(
            hintText: 'Enter Habit Title',
            controller: _title,
            errorText: _titleError,
            textInputAction: TextInputAction.next,
            onChanged: (String _) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          const SizedBox(height: AppDimens.gap),
          TickTextField(
            hintText: 'Enter Description (optional)',
            controller: _description,
            maxLines: 3,
          ),
          const SizedBox(height: AppDimens.gap),
          Row(
            children: <Widget>[
              Expanded(
                child: _PickerTile(
                  label: 'Color',
                  leading: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Color(_colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.gap),
              Expanded(
                child: _PickerTile(
                  label: 'Icon',
                  leading: Icon(iconForKey(_iconKey), color: Colors.white),
                  onTap: () async {
                    final String? key =
                        await showIconPicker(context, selectedKey: _iconKey);
                    if (key != null) setState(() => _iconKey = key);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          ColorPalette(
            selectedValue: _colorValue,
            onSelected: (Color c) => setState(() => _colorValue = c.value),
          ),
          const SizedBox(height: AppDimens.gap),
          _typeCard(),
          const SizedBox(height: AppDimens.gap),
          _frequencyCard(quit),
          const SizedBox(height: AppDimens.gap),
          _trackingCard(quit),
          const SizedBox(height: AppDimens.gap),
          _reminderCard(),
          const SizedBox(height: AppDimens.gap),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: const Text(
                'Select Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: category == null ? null : Text(category.name),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
              onTap: () async {
                final CategoryChoice? choice = await showCategoryPicker(
                  context,
                  selectedId: _categoryId,
                );
                if (choice != null) setState(() => _categoryId = choice.id);
              },
            ),
          ),
          const SizedBox(height: AppDimens.gap),
          SwitchRow(
            label: 'Show Streaks on Timeline',
            value: _showStreaks,
            onChanged: (bool v) => setState(() => _showStreaks = v),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- cards

  Widget _typeCard() {
    return SectionCard(
      title: 'Type',
      child: Column(
        children: <Widget>[
          PillSelector<HabitType>(
            options: const <PillOption<HabitType>>[
              PillOption<HabitType>(
                value: HabitType.build,
                label: 'Build A Habit',
              ),
              PillOption<HabitType>(
                value: HabitType.quit,
                label: 'Quit A Habit',
              ),
            ],
            selected: _type,
            onChanged: (HabitType t) => setState(() {
              _type = t;
              if (t == HabitType.quit) _frequency = FrequencyType.everyday;
            }),
          ),
          const SizedBox(height: 10),
          _Caption(
            _type == HabitType.build
                ? 'Do it regularly. Tap to mark it done.'
                : 'Completed by default - only mark the days you slipped. '
                    'Streak is counted as slip free days.',
          ),
        ],
      ),
    );
  }

  Widget _frequencyCard(bool quit) {
    Widget option(FrequencyType type, String label, Widget? details) {
      final bool selected = _frequency == type;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RadioRow(
            label: label,
            selected: selected,
            enabled: !quit || type == FrequencyType.everyday,
            onTap: () => setState(() => _frequency = type),
          ),
          if (selected && details != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: details,
            ),
          ],
        ],
      );
    }

    return SectionCard(
      title: 'Frequency',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          option(FrequencyType.everyday, 'Everyday', null),
          option(
            FrequencyType.daysOfWeek,
            'Specific Days of Week',
            WeekdayChips(
              selected: _weekdays,
              onChanged: (Set<int> d) => setState(() => _weekdays = d),
            ),
          ),
          option(
            FrequencyType.daysOfMonth,
            'Specific Days of Month',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int d = 1; d <= 31; d++) _monthDayChip(d),
              ],
            ),
          ),
          option(
            FrequencyType.somePerPeriod,
            'Some Days Per Period',
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                _StepButton(
                  icon: Icons.remove,
                  onTap: () => setState(() {
                    if (_timesPerPeriod > 1) _timesPerPeriod--;
                  }),
                ),
                Text(
                  '$_timesPerPeriod',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _StepButton(
                  icon: Icons.add,
                  onTap: () => setState(() {
                    final int max = _period == PeriodUnit.week ? 7 : 31;
                    if (_timesPerPeriod < max) _timesPerPeriod++;
                  }),
                ),
                const Text('days per'),
                TickChip(
                  label: 'Week',
                  selected: _period == PeriodUnit.week,
                  onTap: () => setState(() {
                    _period = PeriodUnit.week;
                    if (_timesPerPeriod > 7) _timesPerPeriod = 7;
                  }),
                ),
                TickChip(
                  label: 'Month',
                  selected: _period == PeriodUnit.month,
                  onTap: () => setState(() => _period = PeriodUnit.month),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthDayChip(int day) {
    final bool on = _monthDays.contains(day);
    return GestureDetector(
      onTap: () => setState(() {
        if (!_monthDays.add(day)) _monthDays.remove(day);
        _monthDays = Set<int>.of(_monthDays);
      }),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.cyan : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: on ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _trackingCard(bool quit) {
    String caption;
    switch (_tracking) {
      case TrackingMethod.tick:
        caption = quit
            ? 'Tap the days you slipped.'
            : 'Tap once to mark the day done.';
      case TrackingMethod.count:
        caption = quit
            ? 'Set a daily limit and how much each tap adds'
            : 'Set a daily goal and how much each tap adds';
      case TrackingMethod.checklist:
        caption = quit
            ? 'Each item is clean by default - mark only the ones you slipped.'
            : 'The day is done when every item is ticked.';
    }

    return SectionCard(
      title: 'Tracking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PillSelector<TrackingMethod>(
            options: const <PillOption<TrackingMethod>>[
              PillOption<TrackingMethod>(
                value: TrackingMethod.tick,
                label: 'Tick',
              ),
              PillOption<TrackingMethod>(
                value: TrackingMethod.count,
                label: 'Count',
              ),
              PillOption<TrackingMethod>(
                value: TrackingMethod.checklist,
                label: 'Checklist',
              ),
            ],
            selected: _tracking,
            onChanged: (TrackingMethod t) => setState(() => _tracking = t),
          ),
          const SizedBox(height: 10),
          Center(child: _Caption(caption)),
          if (_tracking == TrackingMethod.count) ..._countFields(quit),
          if (_tracking == TrackingMethod.checklist) ..._checklistFields(),
        ],
      ),
    );
  }

  List<Widget> _countFields(bool quit) {
    return <Widget>[
      const SizedBox(height: 14),
      _FieldLabel(quit ? 'DAILY LIMIT (optional)' : 'DAILY GOAL (optional)'),
      Row(
        children: <Widget>[
          Expanded(
            child: TickTextField(
              hintText: '- / Day',
              controller: _goal,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove,
            onTap: () => _nudge(_goal, -_stepValue),
          ),
          const SizedBox(width: 8),
          _StepButton(icon: Icons.add, onTap: () => _nudge(_goal, _stepValue)),
        ],
      ),
      const SizedBox(height: 4),
      Center(
        child: _Caption(
          quit
              ? 'Going above this amount counts as a slip'
              : 'Reaching this amount completes the day',
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('UNIT (optional)'),
      TickTextField(hintText: 'km, pages, minutes...', controller: _unit),
      const SizedBox(height: 14),
      const _FieldLabel('EACH TAP ADDS'),
      Row(
        children: <Widget>[
          Expanded(
            child: TickTextField(
              hintText: '1',
              controller: _step,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove,
            onTap: () => _nudge(_step, -1, min: 1),
          ),
          const SizedBox(width: 8),
          _StepButton(icon: Icons.add, onTap: () => _nudge(_step, 1, min: 1)),
        ],
      ),
      const SizedBox(height: 4),
      const Center(child: _Caption('Long press opens the count editor')),
    ];
  }

  double get _stepValue {
    final double? v = _parse(_step.text);
    return (v == null || v <= 0) ? 1 : v;
  }

  List<Widget> _checklistFields() {
    return <Widget>[
      const SizedBox(height: 8),
      for (int i = 0; i < _checklist.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(
            Icons.check_box_outline_blank_rounded,
            color: AppColors.textSecondary,
          ),
          title: Text(_checklist[i].title),
          subtitle: _checklist[i].reminder.enabled
              ? Text('Reminder ${_checklist[i].reminder.timeLabel}')
              : null,
          trailing: IconButton(
            tooltip: 'Remove item',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() => _checklist.removeAt(i)),
          ),
          onTap: () async {
            final ChecklistItem? edited =
                await showChecklistDialog(context, initial: _checklist[i]);
            if (edited != null) setState(() => _checklist[i] = edited);
          },
        ),
      Center(
        child: TextButton.icon(
          onPressed: () async {
            final ChecklistItem? item = await showChecklistDialog(context);
            if (item != null) setState(() => _checklist.add(item));
          },
          icon: const Icon(Icons.add, color: AppColors.textPrimary),
          label: const Text(
            'Add Checklist',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
        ),
      ),
    ];
  }

  Widget _reminderCard() {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        6,
        AppDimens.pagePadding,
        AppDimens.pagePadding,
      ),
      child: Column(
        children: <Widget>[
          SwitchRow(
            label: 'Set Reminder',
            boxed: false,
            value: _reminder.enabled,
            onChanged: (bool v) =>
                setState(() => _reminder = _reminder.copyWith(enabled: v)),
          ),
          if (_reminder.enabled) ...<Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Time',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _reminder.hour,
                        minute: _reminder.minute,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _reminder = _reminder.copyWith(
                          minutesOfDay: picked.hour * 60 + picked.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
            Row(
              children: <Widget>[
                const Text(
                  'Day',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: WeekdayChips(
                    selected: _reminder.weekdays,
                    onChanged: (Set<int> d) =>
                        setState(() => _reminder = _reminder.copyWith(weekdays: d)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- small pieces

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.label, required this.leading, this.onTap});

  final String label;
  final Widget leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: leading,
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: enabled ? AppColors.textPrimary : AppColors.textHint,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: enabled ? AppColors.textPrimary : AppColors.textHint,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}
