// ignore_for_file: non_const_argument_for_const_parameter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/ids.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/logic/task_visibility.dart';
import '../../domain/models/models.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';
import '../../state/task_state.dart';
import '../../shared/utils/local_attachments.dart';
import 'task_form_screen.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TaskItem>> asyncTasks = ref.watch(taskListProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final DateTime selectedDay = ref.watch(taskSelectedDateProvider);
    final int? priorityFilter = ref.watch(taskPriorityFilterProvider);
    final String? requestedCategoryFilter = ref.watch(taskCategoryFilterProvider);
    final TaskSort sort = ref.watch(taskSortProvider);
    final AppData? habitData = ref.watch(appDataProvider).valueOrNull;
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final List<TaskItem> taskState = asyncTasks.valueOrNull ?? const <TaskItem>[];
    final List<TaskItem> roots = taskState.where((TaskItem task) => !task.isSubtask).toList();
    final List<String> categories = roots.map((TaskItem task) => task.category.trim()).where((String value) => value.isNotEmpty).toSet().toList()..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final String? categoryFilter = categories.contains(requestedCategoryFilter) ? requestedCategoryFilter : null;

    List<TaskItem> visible = roots.where((TaskItem task) {
      final bool matchesDate = switch (filter) {
        TaskFilter.all => true,
        TaskFilter.today => isTaskVisibleOnDate(task, selectedDay),
        TaskFilter.due => !task.isCompleted && isTaskVisibleOnDate(task, selectedDay),
      };
      final bool matchesPriority = priorityFilter == null || task.priority == priorityFilter;
      final bool matchesCategory = categoryFilter == null || task.category.trim() == categoryFilter;
      return matchesDate && matchesPriority && matchesCategory;
    }).toList();

    visible.sort((TaskItem a, TaskItem b) {
      if (sort == TaskSort.deadline) {
        final bool aOverdue = isTaskOverdueOnDate(a, filter == TaskFilter.all ? DateTime.now() : selectedDay);
        final bool bOverdue = isTaskOverdueOnDate(b, filter == TaskFilter.all ? DateTime.now() : selectedDay);
        if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
        final int due = a.dueDate.compareTo(b.dueDate);
        return due != 0 ? due : b.priority.compareTo(a.priority);
      }
      if (sort == TaskSort.priority) {
        final int result = b.priority.compareTo(a.priority);
        return result != 0 ? result : a.dueDate.compareTo(b.dueDate);
      }
      final int categoryComparison = a.category.toLowerCase().compareTo(b.category.toLowerCase());
      if (sort == TaskSort.categoryDescending) {
        return categoryComparison != 0 ? -categoryComparison : a.dueDate.compareTo(b.dueDate);
      }
      return categoryComparison != 0 ? categoryComparison : a.dueDate.compareTo(b.dueDate);
    });

    final int completed = visible.where((TaskItem task) => task.isCompleted && !task.isPaused).length;
    final int incomplete = visible.where((TaskItem task) => !task.isCompleted && !task.isPaused).length;
    final int overdue = visible.where((TaskItem task) => isTaskOverdueOnDate(task, filter == TaskFilter.all ? DateTime.now() : selectedDay)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: <Widget>[
          IconButton(tooltip: 'Task analytics', icon: const Icon(Icons.bar_chart_rounded), onPressed: () => context.push(AppRoutes.taskAnalytics)),
        ],
      ),
      body: asyncTasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(child: Text('Could not load tasks: $error')),
        data: (List<TaskItem> tasks) {
          final List<Habit> dueHabits = filter == TaskFilter.all || filter == TaskFilter.today
              ? _habitsForDate(habitData, engine, selectedDay)
              : <Habit>[];
          return Column(children: <Widget>[
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: Text(filter == TaskFilter.due ? '$incomplete incomplete · $overdue overdue' : '$completed completed · $incomplete incomplete', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Text('${visible.length}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: visible.isEmpty ? 0 : completed / visible.length, minHeight: 5, color: AppColors.gold, backgroundColor: AppColors.border),
              const SizedBox(height: 12),
              Wrap(spacing: 7, runSpacing: 7, children: <Widget>[
                ChoiceChip(label: const Text('All Tasks'), selected: filter == TaskFilter.all, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.all),
                ChoiceChip(label: const Text('Today'), selected: filter == TaskFilter.today, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.today),
                ChoiceChip(label: const Text('Due Tasks'), selected: filter == TaskFilter.due, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.due),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
                OutlinedButton.icon(onPressed: () => _browseDate(context, ref), icon: const Icon(Icons.calendar_month, size: 18), label: Text(filter == TaskFilter.all ? 'Browse ${_formatDate(selectedDay)}' : _formatDate(selectedDay))),
                _priorityDropdown(ref, priorityFilter),
                _categoryDropdown(ref, categoryFilter, categories),
                _sortDropdown(ref, sort),
              ]),
            ])),
            Expanded(child: visible.isEmpty && dueHabits.isEmpty
              ? Center(child: Text(filter == TaskFilter.today ? 'No tasks or habits visible on ${_formatDate(selectedDay)}.' : 'No tasks match these filters.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                  itemCount: visible.length + dueHabits.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (index >= visible.length) {
                      final Habit habit = dueHabits[index - visible.length];
                      final CompletionRecord? record = habitData?.recordsFor(habit.id)[dateKey(selectedDay)];
                      final bool done = habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record);
                      return Card(color: AppColors.surface, margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
                        leading: Checkbox(value: done, onChanged: (_) => _completeHabit(ref, habit, selectedDay, habitData!)),
                        title: Text(habit.title, style: TextStyle(fontSize: filter == TaskFilter.today ? 16 : 14, decoration: done ? TextDecoration.lineThrough : null)),
                        subtitle: Text('Habit · ${done ? 'Completed' : 'Due'}'),
                        trailing: const Icon(Icons.repeat_rounded, color: AppColors.textSecondary),
                        onTap: () => context.push(AppRoutes.habitDetail(habit.id)),
                      ));
                    }
                    final TaskItem task = visible[index];
                    final List<TaskItem> children = tasks.where((TaskItem item) => item.parentId == task.id).toList()..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder));
                    final TaskItem? next = children.where((TaskItem item) => !item.isCompleted).firstOrNull;
                    final bool overdueNow = isTaskOverdueOnDate(task, filter == TaskFilter.all ? DateTime.now() : selectedDay);
                    final String status = task.isCompleted ? 'COMPLETED' : task.isPaused ? 'PAUSED' : overdueNow ? 'OVERDUE' : (task.reminderAt != null && !_dayBefore(selectedDay, task.reminderAt) ? 'REMINDER ACTIVE' : 'INCOMPLETE');
                    final double titleSize = filter == TaskFilter.today ? 16 : 14;
                    return Card(color: Colors.transparent, margin: const EdgeInsets.symmetric(vertical: 4), clipBehavior: Clip.antiAlias, child: Container(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: <Color>[Color(task.colorValue).withAlpha(45), AppColors.surface])),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          Checkbox(value: task.isCompleted, onChanged: (_) async { if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick(); await ref.read(taskListProvider.notifier).toggleTaskOrNextSubtask(task, tasks); }),
                          // Resolve the stored icon code point at runtime.
                          Icon(IconData(task.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(task.colorValue)),
                        ]),
                        title: Text(next?.title ?? task.title, style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600, decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Text('${children.isNotEmpty ? '${task.title} · ' : ''}${status} · ${_priority(task.priority)} · Due ${_formatDate(task.dueDate)}${task.dueDate.hour == 0 && task.dueDate.minute == 0 ? '' : ' ${TimeOfDay.fromDateTime(task.dueDate).format(context)}'}', style: TextStyle(fontSize: filter == TaskFilter.today ? 12 : 11, color: overdueNow ? AppColors.danger : AppColors.textSecondary)),
                          if (children.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Subtasks ${children.where((TaskItem item) => item.isCompleted).length}/${children.length}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        ]),
                        isThreeLine: children.isNotEmpty,
                        onTap: () => context.push(AppRoutes.taskDetail(task.id)),
                        trailing: PopupMenuButton<String>(onSelected: (String value) => _taskAction(context, ref, task, tasks, value), itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem(value: 'details', child: Text('Details')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'pause', child: Text(task.isPaused ? 'Resume' : 'Pause')),
                          const PopupMenuItem(value: 'postpone_day', child: Text('Postpone 1 day')),
                          const PopupMenuItem(value: 'postpone_week', child: Text('Postpone 1 week')),
                          const PopupMenuItem(value: 'repeat', child: Text('Repeat tomorrow')),
                          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ]),
                      ),
                    ));
                  },
                )),
          ]);
        },
      ),
    );
  }

  Widget _priorityDropdown(WidgetRef ref, int? selected) => DropdownButton<int?>(value: selected, hint: const Text('Priority'), underline: const SizedBox.shrink(), items: const <DropdownMenuItem<int?>>[
    DropdownMenuItem<int?>(value: null, child: Text('All priorities')),
    DropdownMenuItem<int?>(value: 1, child: Text('Low')),
    DropdownMenuItem<int?>(value: 2, child: Text('Medium')),
    DropdownMenuItem<int?>(value: 3, child: Text('High')),
    DropdownMenuItem<int?>(value: 4, child: Text('Urgent')),
  ], onChanged: (int? value) => ref.read(taskPriorityFilterProvider.notifier).state = value);

  Widget _categoryDropdown(WidgetRef ref, String? selected, List<String> categories) => DropdownButton<String?>(value: selected, hint: const Text('Category'), underline: const SizedBox.shrink(), items: <DropdownMenuItem<String?>>[
    const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
    ...categories.map((String category) => DropdownMenuItem<String?>(value: category, child: Text(category, overflow: TextOverflow.ellipsis))),
  ], onChanged: (String? value) => ref.read(taskCategoryFilterProvider.notifier).state = value);

  Widget _sortDropdown(WidgetRef ref, TaskSort selected) => DropdownButton<TaskSort>(value: selected, underline: const SizedBox.shrink(), items: const <DropdownMenuItem<TaskSort>>[
    DropdownMenuItem(value: TaskSort.deadline, child: Text('Sort: Deadline')),
    DropdownMenuItem(value: TaskSort.priority, child: Text('Sort: Priority')),
    DropdownMenuItem(value: TaskSort.categoryAscending, child: Text('Category A–Z')),
    DropdownMenuItem(value: TaskSort.categoryDescending, child: Text('Category Z–A')),
  ], onChanged: (TaskSort? value) { if (value != null) ref.read(taskSortProvider.notifier).state = value; });

  Future<void> _browseDate(BuildContext context, WidgetRef ref) async {
    final DateTime initial = ref.read(taskSelectedDateProvider);
    final DateTime? selected = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (selected != null) {
      ref.read(taskSelectedDateProvider.notifier).state = DateTime(selected.year, selected.month, selected.day);
      ref.read(taskFilterProvider.notifier).state = TaskFilter.today;
    }
  }

  Future<void> _taskAction(BuildContext context, WidgetRef ref, TaskItem task, List<TaskItem> all, String action) async {
    final TaskListNotifier notifier = ref.read(taskListProvider.notifier);
    if (action == 'details') { context.push(AppRoutes.taskDetail(task.id)); return; }
    if (action == 'edit') { await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => TaskFormScreen(existing: task))); return; }
    if (action == 'pause') { await notifier.pause(task); return; }
    if (action == 'postpone_day' || action == 'postpone_week') {
      final int delta = action == 'postpone_day' ? 1 : 7;
      await notifier.save(task.copyWith(dueDate: task.dueDate.add(Duration(days: delta)), reminderAt: task.reminderAt?.add(Duration(days: delta)), updatedAt: DateTime.now()));
      return;
    }
    if (action == 'delete') {
      final bool confirmed = !ref.read(confirmDeletesProvider) || (await showDialog<bool>(context: context, builder: (BuildContext dialogContext) => AlertDialog(title: const Text('Delete task?'), content: Text('Delete “${task.title}” and its subtasks? Historical analytics will be retained.'), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))])) ?? false);
      if (confirmed) await notifier.delete(task.id);
      return;
    }
    if (action == 'repeat' || action == 'duplicate') {
      final DateTime now = DateTime.now();
      final DateTime newDue = action == 'repeat' ? task.dueDate.add(const Duration(days: 1)) : task.dueDate;
      final List<String> photos = <String>[];
      final List<String> audio = <String>[];
      for (final String path in task.photoPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) photos.add(copied); }
      for (final String path in task.audioPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) audio.add(copied); }
      final TaskItem copy = TaskItem(id: newId(), title: action == 'repeat' ? task.title : '${task.title} (copy)', description: task.description, category: task.category, notes: task.notes, photoPaths: photos, audioPaths: audio, createdAt: now, updatedAt: now, dueDate: newDue, priority: task.priority, colorValue: task.colorValue, iconCodePoint: task.iconCodePoint, reminderAt: null, repeatRule: task.repeatRule);
      await notifier.save(copy);
      final List<TaskItem> children = all.where((TaskItem item) => item.parentId == task.id).toList()..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder));
      for (final TaskItem child in children) {
        final List<String> childPhotos = <String>[];
        final List<String> childAudio = <String>[];
        for (final String path in child.photoPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) childPhotos.add(copied); }
        for (final String path in child.audioPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) childAudio.add(copied); }
        await notifier.save(TaskItem(id: newId(), title: child.title, description: child.description, category: child.category, notes: child.notes, photoPaths: childPhotos, audioPaths: childAudio, createdAt: now, updatedAt: now, dueDate: action == 'repeat' ? child.dueDate.add(const Duration(days: 1)) : child.dueDate, priority: copy.priority, colorValue: child.colorValue, iconCodePoint: child.iconCodePoint, parentId: copy.id, sortOrder: child.sortOrder));
      }
    }
  }

  List<Habit> _habitsForDate(AppData? data, HabitEngine engine, DateTime date) {
    if (data == null) return <Habit>[];
    final List<Habit> result = data.activeHabits.where((Habit habit) {
      if (date.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) return false;
      final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(date)];
      return engine.isDueOn(habit, date, data.recordsFor(habit.id)) || engine.isCompleted(habit, record) || engine.isSlipped(habit, record) || habit.schedule.isScheduledOn(date);
    }).toList();
    return result;
  }

  Future<void> _completeHabit(WidgetRef ref, Habit habit, DateTime day, AppData data) async {
    final AppDataNotifier notifier = ref.read(appDataProvider.notifier);
    switch (habit.tracking) {
      case TrackingMethod.tick:
        if (habit.type == HabitType.quit) { final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(day)]; if (record?.slipped ?? false) await notifier.toggleTick(habit, day); }
        else { await notifier.toggleTick(habit, day); }
        break;
      case TrackingMethod.count:
        await notifier.setCount(habit, day, habit.type == HabitType.quit ? 0 : (habit.dailyGoal ?? habit.step));
        break;
      case TrackingMethod.checklist:
        final Set<String> checked = data.recordsFor(habit.id)[dateKey(day)]?.checkedItemIds ?? <String>{};
        for (final ChecklistItem item in habit.checklist) { if (habit.type == HabitType.quit ? checked.contains(item.id) : !checked.contains(item.id)) await notifier.toggleChecklistItem(habit, day, item.id); }
        break;
    }
  }
}

bool _dayBefore(DateTime day, DateTime reminder) => DateTime(day.year, day.month, day.day).isBefore(DateTime(reminder.year, reminder.month, reminder.day));
String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _priority(int priority) => switch (priority) { 1 => 'Low', 2 => 'Medium', 3 => 'High', _ => 'Urgent' };
extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
