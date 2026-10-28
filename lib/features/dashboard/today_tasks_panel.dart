// ignore_for_file: non_const_argument_for_const_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/logic/task_visibility.dart';
import '../../domain/models/models.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';
import '../../state/task_state.dart';

/// Dashboard snapshot of date-visible tasks and habits due on that date. The
/// two completion percentages deliberately remain separate.
class TodayTasksPanel extends ConsumerWidget {
  const TodayTasksPanel({super.key, required this.data, required this.day});
  final AppData data;
  final DateTime day;

  bool _habitDone(Habit habit, HabitEngine engine, CompletionRecord? record) =>
      habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> allTasks = ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[];
    final TaskSort sort = ref.watch(taskSortProvider);
    final List<TaskItem> tasks = allTasks.where((TaskItem task) => isTaskVisibleOnDate(task, day)).toList()
      ..sort((TaskItem a, TaskItem b) {
        if (sort == TaskSort.deadline) {
          final bool ao = isTaskOverdueOnDate(a, day);
          final bool bo = isTaskOverdueOnDate(b, day);
          if (ao != bo) return ao ? -1 : 1;
          final int deadline = a.dueDate.compareTo(b.dueDate);
          return deadline != 0 ? deadline : b.priority.compareTo(a.priority);
        }
        if (sort == TaskSort.priority) {
          final int priority = b.priority.compareTo(a.priority);
          return priority != 0 ? priority : a.dueDate.compareTo(b.dueDate);
        }
        final int category = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        if (sort == TaskSort.categoryDescending) return category != 0 ? -category : a.dueDate.compareTo(b.dueDate);
        return category != 0 ? category : a.dueDate.compareTo(b.dueDate);
      });
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final DateTime selected = DateTime(day.year, day.month, day.day);
    final List<Habit> scheduledHabits = data.activeHabits.where((Habit habit) {
      if (selected.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) return false;
      final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(selected)];
      return engine.isDueOn(habit, selected, data.recordsFor(habit.id)) ||
          engine.isCompleted(habit, record) || engine.isSlipped(habit, record) || habit.schedule.isScheduledOn(selected);
    }).toList();
    final int taskCompleted = tasks.where((TaskItem task) => task.isCompleted).length;
    final int habitCompleted = scheduledHabits.where((Habit habit) => _habitDone(habit, engine, data.recordsFor(habit.id)[dateKey(selected)])).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          const Expanded(child: Text("Today's overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Text('${_dateLabel(selected)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          IconButton(tooltip: 'Open tasks', visualDensity: VisualDensity.compact, onPressed: () => context.push(AppRoutes.tasks), icon: const Icon(Icons.arrow_forward, size: 18)),
        ]),
        Row(children: <Widget>[
          Expanded(child: _progressBlock(title: 'Tasks', completed: taskCompleted, total: tasks.length, color: AppColors.gold, action: () => context.push(AppRoutes.tasks))),
          const SizedBox(width: 12),
          Expanded(child: _progressBlock(title: 'Habits', completed: habitCompleted, total: scheduledHabits.length, color: const Color(0xFF73D6D0), action: () => context.go(AppRoutes.habits))),
        ]),
        const SizedBox(height: 10),
        if (tasks.isEmpty && scheduledHabits.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing scheduled or due for this day.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ...tasks.take(3).map((TaskItem task) => _taskEntry(context, ref, task, allTasks, day)),
        ...scheduledHabits.take(3).map((Habit habit) => _habitEntry(context, ref, habit, selected)),
        if (tasks.length + scheduledHabits.length > 6)
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push(AppRoutes.tasks), child: Text('See all ${tasks.length + scheduledHabits.length} items'))),
      ]),
    );
  }

  Widget _progressBlock({required String title, required int completed, required int total, required Color color, required VoidCallback action}) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(12),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$completed/$total · ${total == 0 ? 0 : (completed * 100 / total).round()}%', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: total == 0 ? 0 : completed / total, minHeight: 5, color: color, backgroundColor: AppColors.border),
    ])),
  );

  Widget _taskEntry(BuildContext context, WidgetRef ref, TaskItem task, List<TaskItem> allTasks, DateTime selectedDay) {
    final DateTime effectiveDay = sameTaskDay(selectedDay, DateTime.now()) ? DateTime.now() : selectedDay;
    final bool overdue = isTaskOverdueOnDate(task, effectiveDay);
    return InkWell(
      onTap: () => context.push(AppRoutes.taskDetail(task.id)),
      child: SizedBox(height: 42, child: Row(children: <Widget>[
        Checkbox(value: task.isCompleted, visualDensity: VisualDensity.compact, onChanged: (_) async {
          if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick();
          await ref.read(taskListProvider.notifier).toggleTaskOrNextSubtask(task, allTasks);
        }),
        // Resolve the stored icon code point at runtime.
        Icon(IconData(task.iconCodePoint, fontFamily: 'MaterialIcons'), size: 17, color: Color(task.colorValue)),
        const SizedBox(width: 8),
        Expanded(child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, decoration: task.isCompleted ? TextDecoration.lineThrough : null))),
        Text(
          task.isCompleted ? 'DONE' : task.isPaused ? 'PAUSED' : overdue ? 'OVERDUE' : 'INCOMPLETE',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: task.isCompleted ? AppColors.gold : overdue ? AppColors.danger : AppColors.textSecondary),
        ),
      ])),
    );
  }

  Widget _habitEntry(BuildContext context, WidgetRef ref, Habit habit, DateTime date) {
    final HabitEngine engine = ref.read(habitEngineProvider);
    final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(date)];
    final bool done = _habitDone(habit, engine, record);
    return InkWell(
      onTap: () => context.push(AppRoutes.habitDetail(habit.id)),
      child: SizedBox(height: 42, child: Row(children: <Widget>[
        Checkbox(value: done, visualDensity: VisualDensity.compact, onChanged: (_) async {
          if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick();
          await _completeHabit(ref, habit, date);
        }),
        const Icon(Icons.repeat_rounded, size: 17, color: Color(0xFF73D6D0)),
        const SizedBox(width: 8),
        Expanded(child: Text(habit.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, decoration: done ? TextDecoration.lineThrough : null))),
        const Text('HABIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ])),
    );
  }

  Future<void> _completeHabit(WidgetRef ref, Habit habit, DateTime date) async {
    final AppDataNotifier notifier = ref.read(appDataProvider.notifier);
    switch (habit.tracking) {
      case TrackingMethod.tick:
        if (habit.type == HabitType.quit) { final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(date)]; if (record?.slipped ?? false) await notifier.toggleTick(habit, date); }
        else { await notifier.toggleTick(habit, date); }
        break;
      case TrackingMethod.count:
        await notifier.setCount(habit, date, habit.type == HabitType.quit ? 0 : (habit.dailyGoal ?? habit.step));
        break;
      case TrackingMethod.checklist:
        final Set<String> checked = data.recordsFor(habit.id)[dateKey(date)]?.checkedItemIds ?? <String>{};
        for (final ChecklistItem item in habit.checklist) {
          if (habit.type == HabitType.quit ? checked.contains(item.id) : !checked.contains(item.id)) await notifier.toggleChecklistItem(habit, date, item.id);
        }
        break;
    }
  }
}

String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
