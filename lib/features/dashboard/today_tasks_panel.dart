import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../domain/models/task.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/task_state.dart';
import '../../state/preferences_state.dart';

/// Compact, combined task/habit summary on the main dashboard. Habit-generated
/// entries always follow manual tasks and use the existing habit completion
/// record as their source of truth.
class TodayTasksPanel extends ConsumerWidget {
  const TodayTasksPanel({super.key, required this.data, required this.day});
  final AppData data;
  final DateTime day;

  bool _habitDone(Habit habit, HabitEngine engine, CompletionRecord? record) =>
      habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> tasks = ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[];
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final DateTime today = DateTime(day.year, day.month, day.day);
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final List<TaskItem> dueManual = tasks.where((TaskItem task) {
      if (task.isSubtask || task.isPaused) return false;
      final bool dueToday = sameDay(task.dueDate, today);
      final bool overdueOutstanding = !task.isCompleted && DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isBefore(today);
      return dueToday || overdueOutstanding;
    }).toList()
      ..sort((TaskItem a, TaskItem b) {
        final bool ao = a.isOverdue(DateTime.now()), bo = b.isOverdue(DateTime.now());
        if (ao != bo) return ao ? -1 : 1;
        final int priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.dueDate.compareTo(b.dueDate);
      });

    final List<Habit> scheduled = data.activeHabits.where((Habit habit) {
      if (today.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) return false;
      final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(today)];
      return engine.isDueOn(habit, today, data.recordsFor(habit.id)) ||
          engine.isCompleted(habit, record) || engine.isSlipped(habit, record) || habit.schedule.isScheduledOn(today);
    }).toList();
    final List<Habit> dueHabits = scheduled.where((Habit habit) => !_habitDone(habit, engine, data.recordsFor(habit.id)[dateKey(today)])).toList();
    final int completedManualToday = tasks.where((TaskItem task) => !task.isSubtask && !task.isPaused && sameDay(task.dueDate, today) && task.isCompleted).length;
    final int completedHabits = scheduled.where((Habit habit) => _habitDone(habit, engine, data.recordsFor(habit.id)[dateKey(today)])).length;
    final int total = dueManual.length + scheduled.length;
    final int completed = completedManualToday + completedHabits;
    final List<_Entry> entries = <_Entry>[
      ...dueManual.where((TaskItem task) => !task.isCompleted).map((TaskItem task) => _Entry.task(task)),
      ...dueHabits.map((Habit habit) => _Entry.habit(habit)),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(sameDay(day, DateTime.now()) ? "Today's Tasks" : 'Tasks · ${day.day}/${day.month}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Text('$completed/$total · ${total == 0 ? 0 : (completed * 100 / total).round()}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          IconButton(tooltip: 'Open tasks', visualDensity: VisualDensity.compact, onPressed: () => context.push(AppRoutes.tasks), icon: const Icon(Icons.arrow_forward, size: 18)),
        ]),
        LinearProgressIndicator(value: total == 0 ? 0 : (completed / total).clamp(0.0, 1.0).toDouble(), minHeight: 4, color: AppColors.gold, backgroundColor: AppColors.border),
        if (entries.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No incomplete tasks or habits due today.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ...entries.take(2).map(( _Entry entry) => SizedBox(height: 36, child: Row(children: <Widget>[
          Checkbox(value: false, visualDensity: VisualDensity.compact, onChanged: (_) async {
            if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick();
            if (entry.task != null) {
              final List<TaskItem> all = ref.read(taskListProvider).valueOrNull ?? const <TaskItem>[];
              await ref.read(taskListProvider.notifier).toggleTaskOrNextSubtask(entry.task!, all);
            } else if (entry.habit != null) {
              await _completeHabit(ref, entry.habit!, today, data);
            }
          }),
          if (entry.task != null) Icon(IconData(entry.task!.iconCodePoint, fontFamily: 'MaterialIcons'), size: 16, color: Color(entry.task!.colorValue)) else const Icon(Icons.repeat, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(entry.task?.title ?? entry.habit!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          if (entry.task != null && entry.task!.isOverdue(DateTime.now())) const Text('OVERDUE', style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.bold)),
        ]))),
        if (entries.length > 2) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push(AppRoutes.tasks), child: Text('+${entries.length - 2} more'))),
      ]),
    );
  }

  Future<void> _completeHabit(WidgetRef ref, Habit habit, DateTime date, AppData data) async {
    final AppDataNotifier notifier = ref.read(appDataProvider.notifier);
    switch (habit.tracking) {
      case TrackingMethod.tick:
        if (habit.type == HabitType.quit) {
          final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(date)];
          if (record?.slipped ?? false) await notifier.toggleTick(habit, date);
        } else { await notifier.toggleTick(habit, date); }
        break;
      case TrackingMethod.count:
        final double goal = habit.type == HabitType.quit ? 0 : (habit.dailyGoal ?? habit.step);
        await notifier.setCount(habit, date, goal);
        break;
      case TrackingMethod.checklist:
        final Set<String> checked = data.recordsFor(habit.id)[dateKey(date)]?.checkedItemIds ?? <String>{};
        if (habit.type == HabitType.quit) { for (final ChecklistItem item in habit.checklist) { if (checked.contains(item.id)) await notifier.toggleChecklistItem(habit, date, item.id); } }
        else { for (final ChecklistItem item in habit.checklist) { if (!checked.contains(item.id)) await notifier.toggleChecklistItem(habit, date, item.id); } }
        break;
    }
  }
}

class _Entry {
  const _Entry._({this.task, this.habit});
  final TaskItem? task;
  final Habit? habit;
  factory _Entry.task(TaskItem task) => _Entry._(task: task);
  factory _Entry.habit(Habit habit) => _Entry._(habit: habit);
}
