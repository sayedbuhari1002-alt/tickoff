import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/ids.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/logic/task_analytics.dart';
import '../../domain/models/models.dart';
import '../../domain/models/task.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/task_state.dart';
import '../../state/preferences_state.dart';
import '../../shared/utils/local_attachments.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TaskItem>> asyncTasks = ref.watch(taskListProvider);
    final TaskFilter filter = ref.watch(taskFilterProvider);
    final AppData? habitData = ref.watch(appDataProvider).valueOrNull;
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Task analytics',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              builder: (_) => const _TaskAnalytics(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editTask(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncTasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: Text('Could not load tasks: $error'),
        ),
        data: (List<TaskItem> tasks) {
          final List<TaskItem> allTasks = tasks
              .where((TaskItem t) => !t.isSubtask)
              .toList();
          final List<TaskItem> visibleTasks = switch (filter) {
            TaskFilter.all => allTasks,
            TaskFilter.today => allTasks.where((TaskItem task) => !task.isPaused && (_sameDay(task.dueDate, today) || (!task.isCompleted && DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isBefore(today)))).toList(),
            TaskFilter.due => allTasks.where((TaskItem task) => !task.isCompleted && !task.isPaused && !DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isAfter(today)).toList(),
          };
          visibleTasks.sort((TaskItem a, TaskItem b) {
            final bool aOverdue = a.isOverdue(now);
            final bool bOverdue = b.isOverdue(now);
            if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
            final int priority = b.priority.compareTo(a.priority);
            return priority != 0 ? priority : a.dueDate.compareTo(b.dueDate);
          });
          final int manualDone = visibleTasks.where((TaskItem task) => task.isCompleted && !task.isPaused).length;
          final List<Habit> scheduledHabits = filter != TaskFilter.due ? (habitData?.activeHabits.where((Habit habit) { if (today.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) return false; final CompletionRecord? record = habitData!.recordsFor(habit.id)[dateKey(today)]; return engine.isDueOn(habit, today, habitData!.recordsFor(habit.id)) || engine.isCompleted(habit, record) || engine.isSlipped(habit, record); }).toList() ?? <Habit>[]) : <Habit>[];
          final List<Habit> dueHabits = scheduledHabits.where((Habit habit) { final CompletionRecord? record = habitData!.recordsFor(habit.id)[dateKey(today)]; final bool complete = habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record); return !complete; }).toList();
          final int completedHabits = scheduledHabits.where((Habit habit) { final CompletionRecord? record = habitData!.recordsFor(habit.id)[dateKey(today)]; return habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record); }).length;
          final int done = manualDone + completedHabits;
          final int total = visibleTasks.where((TaskItem task) => !task.isPaused).length + (filter != TaskFilter.due ? scheduledHabits.length : 0);

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      filter == TaskFilter.due ? '${visibleTasks.length} incomplete tasks due' : '$done of $total tasks completed',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        ChoiceChip(label: const Text('All tasks'), selected: filter == TaskFilter.all, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.all),
                        ChoiceChip(label: const Text('Today'), selected: filter == TaskFilter.today, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.today),
                        ChoiceChip(label: const Text('Due tasks'), selected: filter == TaskFilter.due, onSelected: (_) => ref.read(taskFilterProvider.notifier).state = TaskFilter.due),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CalendarJump(tasks: tasks, habitData: habitData, engine: engine),
                  ],
                ),
              ),
              Expanded(
                child: visibleTasks.isEmpty && dueHabits.isEmpty
                    ? const Center(
                        child: Text('No tasks here. Tap + to add a task.'),
                      )
                    : ListView.builder(
                        itemCount: visibleTasks.length + dueHabits.length,
                        itemBuilder: (BuildContext context, int index) {
                          if (index >= visibleTasks.length) {
                            final Habit habit =
                                dueHabits[index - visibleTasks.length];
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: Checkbox(
                                  value: false,
                                  onChanged: (_) {
                                    if (habitData != null) {
                                      _completeHabitFromTask(
                                        ref, habit, today, habitData);
                                    }
                                  },
                                ),
                                title: Text(habit.title),
                                subtitle: const Text('Habit · lower priority'),
                                trailing: const Icon(Icons.repeat_rounded,
                                    color: AppColors.textSecondary),
                              ),
                            );
                          }

                          final TaskItem task = visibleTasks[index];
                          final List<TaskItem> children = tasks
                              .where((TaskItem item) =>
                                  item.parentId == task.id)
                              .toList()
                            ..sort((TaskItem a, TaskItem b) =>
                                a.sortOrder.compareTo(b.sortOrder));
                          final TaskItem? next = children
                              .where((TaskItem item) => !item.isCompleted)
                              .firstOrNull;
                          return Card(
                            color: Colors.transparent,
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            clipBehavior: Clip.antiAlias,
                            child: Container(
                              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: <Color>[Color(task.colorValue).withAlpha(45), AppColors.surface])),
                              child: ListTile(
                              leading: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                                Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) async { if (ref.read(hapticsProvider)) await HapticFeedback.selectionClick(); await ref.read(taskListProvider.notifier).toggleTaskOrNextSubtask(task, tasks); },
                                ),
                                Icon(IconData(task.iconCodePoint, fontFamily: 'MaterialIcons'), color: Color(task.colorValue)),
                              ]),
                              title: Text(
                                next?.title ?? task.title,
                                style: TextStyle(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                '${children.isNotEmpty ? '${task.title} · ' : ''}'
                                '${task.isPaused ? 'PAUSED · ' : (task.isOverdue(now) ? 'OVERDUE · ' : '')}'
                                '${_priority(task.priority)} · Due ${_formatDate(task.dueDate)}'
                                '${children.isNotEmpty ? ' · ${children.where((TaskItem item) => item.isCompleted).length}/${children.length} subtasks' : ''}',
                              ),
                              isThreeLine: children.isNotEmpty,
                              onTap: () =>
                                  _editTask(context, ref, existing: task),
                              trailing: PopupMenuButton<String>(
                                onSelected: (String value) async {
                                  final TaskListNotifier notifier =
                                      ref.read(taskListProvider.notifier);
                                  if (value == 'pause') notifier.pause(task);
                                  if (value == 'delete') {
                                    bool allowDelete = !ref.read(confirmDeletesProvider);
                                    if (!allowDelete) {
                                      allowDelete = await showDialog<bool>(context: context, builder: (BuildContext dialogContext) => AlertDialog(title: const Text('Delete task?'), content: Text('Delete “${task.title}” immediately?'), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))])) ?? false;
                                    }
                                    if (allowDelete) await notifier.delete(task.id);
                                  }
                                  if (value == 'postpone_day') notifier.save(task.copyWith(dueDate: task.dueDate.add(const Duration(days: 1)), reminderAt: task.reminderAt == null ? null : task.reminderAt!.add(const Duration(days: 1))));
                                  if (value == 'postpone_week') notifier.save(task.copyWith(dueDate: task.dueDate.add(const Duration(days: 7)), reminderAt: task.reminderAt == null ? null : task.reminderAt!.add(const Duration(days: 7))));
                                  if (value == 'duplicate' || value == 'repeat') {
                                    final DateTime stamp = DateTime.now();
                                    final List<String> copiedPhotos = <String>[];
                                    final List<String> copiedAudio = <String>[];
                                    for (final String path in task.photoPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) copiedPhotos.add(copied); }
                                    for (final String path in task.audioPaths) { final String? copied = await LocalAttachments.duplicateFile(path); if (copied != null) copiedAudio.add(copied); }
                                    final TaskItem copy = TaskItem(id: newId(), title: value == 'repeat' ? task.title : '${task.title} (copy)', description: task.description, category: task.category, notes: task.notes, photoPaths: copiedPhotos, audioPaths: copiedAudio, createdAt: stamp, updatedAt: stamp, dueDate: value == 'repeat' ? task.dueDate.add(const Duration(days: 1)) : task.dueDate, priority: task.priority, colorValue: task.colorValue, iconCodePoint: task.iconCodePoint, reminderAt: null);
                                    await notifier.save(copy);
                                    final List<TaskItem> childrenToCopy = tasks.where((TaskItem t) => t.parentId == task.id).toList()..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder));
                                    for (final TaskItem child in childrenToCopy) { await notifier.save(TaskItem(id: newId(), title: child.title, description: child.description, category: child.category, createdAt: stamp, updatedAt: stamp, dueDate: copy.dueDate, priority: child.priority, colorValue: child.colorValue, iconCodePoint: child.iconCodePoint, parentId: copy.id, sortOrder: child.sortOrder)); }
                                  }
                                  if (value == 'edit') { _editTask(context, ref, existing: task); }
                                },
                                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'pause', child: Text('Pause / resume')),
                                  PopupMenuItem(value: 'postpone_day', child: Text('Postpone 1 day')),
                                  PopupMenuItem(value: 'postpone_week', child: Text('Postpone 1 week')),
                                  PopupMenuItem(value: 'repeat', child: Text('Repeat tomorrow')),
                                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _completeHabitFromTask(
  WidgetRef ref, Habit habit, DateTime day, AppData data) async {
  final AppDataNotifier notifier = ref.read(appDataProvider.notifier);
  switch (habit.tracking) {
    case TrackingMethod.tick:
      if (habit.type == HabitType.quit) {
        final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(day)];
        if (record?.slipped ?? false) await notifier.toggleTick(habit, day);
      } else { await notifier.toggleTick(habit, day); }
      break;
    case TrackingMethod.count:
      if (habit.type == HabitType.quit) {
        await notifier.setCount(habit, day, 0);
      } else {
        final double goal = habit.dailyGoal ?? habit.step;
        await notifier.setCount(habit, day, goal);
      }
      break;
    case TrackingMethod.checklist:
      final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(day)];
      final Set<String> checked = record?.checkedItemIds ?? <String>{};
      for (final ChecklistItem item in habit.checklist) {
        if (habit.type == HabitType.quit ? checked.contains(item.id) : !checked.contains(item.id)) {
          await notifier.toggleChecklistItem(habit, day, item.id);
        }
      }
      break;
  }
}

class _CalendarJump extends StatelessWidget {
  const _CalendarJump({required this.tasks, required this.habitData, required this.engine});
  final List<TaskItem> tasks;
  final AppData? habitData;
  final HabitEngine engine;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          const Icon(Icons.calendar_month, color: AppColors.gold),
          const SizedBox(width: 8),
          const Text('Browse date:'),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final DateTime? selected = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected == null || !context.mounted) return;
              final DateTime selectedDay = DateTime(selected.year, selected.month, selected.day);
              final List<TaskItem> items = tasks.where((TaskItem task) => !task.isSubtask && (_sameDay(task.dueDate, selectedDay) || (!task.isCompleted && DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isBefore(selectedDay)))).toList()
                ..sort((TaskItem a, TaskItem b) { if (a.isOverdue(DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59)) != b.isOverdue(DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59))) return a.isOverdue(DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59)) ? -1 : 1; final int priority = b.priority.compareTo(a.priority); return priority != 0 ? priority : a.dueDate.compareTo(b.dueDate); });
              final List<Habit> dayHabits = (habitData?.activeHabits ?? <Habit>[]).where((Habit habit) { if (selectedDay.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day))) return false; final CompletionRecord? record = habitData!.recordsFor(habit.id)[dateKey(selectedDay)]; return habit.schedule.isScheduledOn(selectedDay) || engine.isCompleted(habit, record) || engine.isSlipped(habit, record); }).toList();
              await showDialog<void>(
                context: context,
                builder: (BuildContext dialogContext) => AlertDialog(
                  title: Text(_formatDate(selected)),
                  content: SizedBox(
                    width: 320,
                    child: items.isEmpty && dayHabits.isEmpty
                        ? const Text('No tasks or scheduled habits for this date.')
                        : ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: SingleChildScrollView(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ...items.map((TaskItem task) => ListTile(leading: Icon(task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: task.isCompleted ? AppColors.gold : AppColors.textSecondary), title: Text(task.title), subtitle: Text('${task.isCompleted ? 'Completed' : (task.isOverdue(selectedDay) ? 'Overdue' : 'Incomplete')} · ${_priority(task.priority)} · Due ${_formatDate(task.dueDate)}'))),
                              ...dayHabits.map((Habit habit) { final CompletionRecord? record = habitData!.recordsFor(habit.id)[dateKey(selectedDay)]; final bool completed = habit.type == HabitType.quit ? !engine.isSlipped(habit, record) : engine.isCompleted(habit, record); return ListTile(leading: Icon(completed ? Icons.check_circle : Icons.repeat, color: completed ? AppColors.gold : AppColors.textSecondary), title: Text(habit.title), subtitle: Text(completed ? 'Habit · Completed' : 'Habit · Incomplete')); }),
                            ],
                          ))),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Select date'),
          ),
        ],
      );
}

Future<void> _editTask(BuildContext context, WidgetRef ref,
    {TaskItem? existing}) async {
  final TextEditingController title =
      TextEditingController(text: existing?.title ?? '');
  final TextEditingController description =
      TextEditingController(text: existing?.description ?? '');
  final TextEditingController category =
      TextEditingController(text: existing?.category ?? '');
  final TextEditingController notes =
      TextEditingController(text: existing?.notes ?? '');
  final TextEditingController subtask = TextEditingController();
  final List<TaskItem> subtasks = <TaskItem>[];
  final List<String> photoPaths = List<String>.of(existing?.photoPaths ?? const <String>[]);
  final List<String> audioPaths = List<String>.of(existing?.audioPaths ?? const <String>[]);
  final LocalAudioRecorder recorder = LocalAudioRecorder();
  final LocalAudioPlayback playback = LocalAudioPlayback();
  bool recording = false;
  if (existing != null) {
    subtasks.addAll((ref.read(taskListProvider).valueOrNull ?? const <TaskItem>[])
        .where((TaskItem t) => t.parentId == existing.id).toList()
      ..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder)));
  }
  DateTime due = existing?.dueDate ?? DateTime.now();
  bool hasDueTime = existing != null && (existing.dueDate.hour != 0 || existing.dueDate.minute != 0);
  DateTime? reminderAt = existing?.reminderAt;
  int priority = existing?.priority ?? 2;
  int color = existing?.colorValue ?? 0xFFFFC62B;
  int iconCodePoint = existing?.iconCodePoint ?? Icons.task_alt.codePoint;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
        title: Text(existing == null ? 'New task' : 'Edit task'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Task title')),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Text notes')),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  OutlinedButton.icon(icon: const Icon(Icons.photo_camera_outlined), label: const Text('Photo'), onPressed: () async { final String? path = await LocalAttachments.pickPhoto(camera: true); if (path != null) setLocal(() => photoPaths.add(path)); }),
                  OutlinedButton.icon(icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'), onPressed: () async { final String? path = await LocalAttachments.pickPhoto(); if (path != null) setLocal(() => photoPaths.add(path)); }),
                  FilledButton.tonalIcon(icon: Icon(recording ? Icons.stop : Icons.mic), label: Text(recording ? 'Stop audio' : 'Record audio'), onPressed: () async { try { if (!recording) { final bool ok = await recorder.start(); if (ok) setLocal(() => recording = true); else if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission was not granted.'))); } else { final String? path = await recorder.stop(); setLocal(() { recording = false; if (path != null) audioPaths.add(path); }); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording failed: $e'))); } }),
                ]),
                if (photoPaths.isNotEmpty) ...photoPaths.map((String path) => ListTile(dense: true, leading: const Icon(Icons.image_outlined), title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setLocal(() => photoPaths.remove(path))))),
                if (audioPaths.isNotEmpty) ...audioPaths.map((String path) => ListTile(dense: true, leading: const Icon(Icons.audio_file_outlined), title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Wrap(children: <Widget>[IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => playback.play(path)), IconButton(icon: const Icon(Icons.close), onPressed: () => setLocal(() => audioPaths.remove(path)))]))),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reminder (optional)'),
                  subtitle: Text(reminderAt == null ? 'Not set' : _formatDate(reminderAt!)),
                  trailing: IconButton(
                    icon: const Icon(Icons.notifications_active_outlined),
                    onPressed: () async {
                      final DateTime? date = await showDatePicker(
                        context: context,
                        initialDate: reminderAt ?? due,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date == null) return;
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(reminderAt ?? DateTime.now()),
                      );
                      if (time != null) {
                        setLocal(() => reminderAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      }
                    },
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline'),
                  subtitle: Text(_formatDate(due)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final DateTime? date = await showDatePicker(
                        context: context,
                        initialDate: due,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setLocal(() => due = DateTime(date.year, date.month, date.day, hasDueTime ? due.hour : 0, hasDueTime ? due.minute : 0));
                    },
                  ),
                ),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline time (optional)'), subtitle: Text(hasDueTime ? TimeOfDay.fromDateTime(due).format(context) : 'No specific time'), trailing: Wrap(children: <Widget>[IconButton(tooltip: 'Set time', icon: const Icon(Icons.access_time), onPressed: () async { final TimeOfDay? time = await showTimePicker(context: context, initialTime: hasDueTime ? TimeOfDay.fromDateTime(due) : const TimeOfDay(hour: 17, minute: 0)); if (time != null) setLocal(() { due = DateTime(due.year, due.month, due.day, time.hour, time.minute); hasDueTime = true; }); }), if (hasDueTime) IconButton(tooltip: 'Clear time', icon: const Icon(Icons.close), onPressed: () => setLocal(() { due = DateTime(due.year, due.month, due.day); hasDueTime = false; }))])),
                DropdownButtonFormField<int>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem(value: 1, child: Text('Low')),
                    DropdownMenuItem(value: 2, child: Text('Medium')),
                    DropdownMenuItem(value: 3, child: Text('High')),
                    DropdownMenuItem(value: 4, child: Text('Urgent')),
                  ],
                  onChanged: (int? value) => setLocal(() => priority = value ?? 2),
                ),
                DropdownButtonFormField<int>(value: iconCodePoint, decoration: const InputDecoration(labelText: 'Icon'), items: <DropdownMenuItem<int>>[DropdownMenuItem(value: Icons.task_alt.codePoint, child: const Text('Task')), DropdownMenuItem(value: Icons.menu_book.codePoint, child: const Text('Study')), DropdownMenuItem(value: Icons.work_outline.codePoint, child: const Text('Work')), DropdownMenuItem(value: Icons.fitness_center.codePoint, child: const Text('Fitness')), DropdownMenuItem(value: Icons.home_outlined.codePoint, child: const Text('Home')), DropdownMenuItem(value: Icons.shopping_bag_outlined.codePoint, child: const Text('Shopping')), DropdownMenuItem(value: Icons.flag_outlined.codePoint, child: const Text('Goal'))], onChanged: (int? value) => setLocal(() => iconCodePoint = value ?? Icons.task_alt.codePoint)),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Colour')),
                Wrap(
                  spacing: 8,
                  children: <int>[
                    0xFFFFC62B, 0xFF4CAF50, 0xFF2196F3, 0xFF9C27B0,
                    0xFFE91E63, 0xFFFF5722, 0xFF00BCD4, 0xFF8BC34A,
                    0xFF795548, 0xFF1B5E20, 0xFF66BB6A, 0xFF9575CD,
                  ].map((int value) => InkWell(
                    onTap: () => setLocal(() => color = value),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(color: color == value ? Colors.white : Colors.transparent, width: 2),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtask,
                  decoration: InputDecoration(
                    labelText: 'Add subtask',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (subtask.text.trim().isNotEmpty) {
                          final DateTime stamp = DateTime.now();
                          setLocal(() => subtasks.add(TaskItem(id: newId(), title: subtask.text.trim(), createdAt: stamp, updatedAt: stamp, dueDate: due, priority: priority, parentId: existing?.id, sortOrder: subtasks.length)));
                          subtask.clear();
                        }
                      },
                    ),
                  ),
                ),
                ...subtasks.asMap().entries.map((MapEntry<int, TaskItem> entry) => ListTile(
                  dense: true,
                  title: Text('${entry.key + 1}. ${entry.value.title}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setLocal(() => subtasks.removeAt(entry.key)),
                  ),
                )),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () async { await recorder.dispose(); await playback.dispose(); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final DateTime now = DateTime.now();
              final TaskItem task = TaskItem(
                id: existing?.id ?? newId(),
                title: title.text.trim(),
                description: description.text.trim(),
                category: category.text.trim(),
                notes: notes.text.trim(),
                photoPaths: List<String>.of(photoPaths),
                audioPaths: List<String>.of(audioPaths),
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
                dueDate: due,
                reminderAt: reminderAt,
                priority: priority,
                colorValue: color,
                iconCodePoint: iconCodePoint,
                isCompleted: existing?.isCompleted ?? false,
                completedAt: existing?.completedAt,
                isPaused: existing?.isPaused ?? false,
                sortOrder: existing?.sortOrder ?? 0,
              );
              await ref.read(taskListProvider.notifier).save(task);
              if (existing != null) { for (final String path in existing.photoPaths.where((String p) => !photoPaths.contains(p))) { await LocalAttachments.deleteFile(path); } for (final String path in existing.audioPaths.where((String p) => !audioPaths.contains(p))) { await LocalAttachments.deleteFile(path); } }
              final TaskListNotifier taskNotifier = ref.read(taskListProvider.notifier);
              final Set<String> retainedIds = subtasks.map((TaskItem t) => t.id).toSet();
              final List<TaskItem> previousChildren = (ref.read(taskListProvider).valueOrNull ?? const <TaskItem>[]).where((TaskItem t) => t.parentId == task.id).toList();
              for (final TaskItem oldChild in previousChildren.where((TaskItem t) => !retainedIds.contains(t.id))) { await taskNotifier.delete(oldChild.id); }
              for (int i = 0; i < subtasks.length; i++) {
                final TaskItem child = subtasks[i];
                await taskNotifier.save(child.copyWith(parentId: task.id, dueDate: due, priority: priority, sortOrder: i, updatedAt: now));
              }
              await recorder.dispose();
              await playback.dispose();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _TaskAnalytics extends ConsumerWidget {
  const _TaskAnalytics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> activeTasks = ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[];
    final List<TaskItem> history = ref.watch(taskHistoryProvider).valueOrNull ?? const <TaskItem>[];
    final List<TaskItem> tasks = <TaskItem>[...activeTasks, ...history];
    final DateTime now = DateTime.now();
    const TaskAnalytics analytics = TaskAnalytics();
    final List<DateTime> days = analytics.lastDays(now);
    final List<TaskDayStats> daily = days.map((DateTime day) => analytics.forDay(tasks, day)).toList();
    final TaskDayStats today = analytics.forDay(tasks, now);
    final int total = daily.fold<int>(0, (int sum, TaskDayStats s) => sum + s.total);
    final int completed = daily.fold<int>(0, (int sum, TaskDayStats s) => sum + s.completed);
    final List<TaskDayStats> daysWithTasks = daily.where((TaskDayStats s) => s.hasTasks).toList();
    final double averageScore = daysWithTasks.isEmpty ? 0 : daysWithTasks.fold<double>(0, (double sum, TaskDayStats s) => sum + s.weightedScore) / daysWithTasks.length;
    int bestStreak = 0;
    int runningStreak = 0;
    for (final TaskDayStats stats in daily) {
      if (!stats.hasTasks) continue;
      if (stats.completionRate >= 1) { runningStreak++; if (runningStreak > bestStreak) bestStreak = runningStreak; } else { runningStreak = 0; }
    }
    int currentStreak = 0;
    for (final TaskDayStats stats in daily.reversed) {
      if (!stats.hasTasks) continue;
      if (stats.completionRate >= 1) { currentStreak++; } else { break; }
    }
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('Task analytics · last 30 days', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: <Widget>[
              Expanded(child: _metric('Completed', '$completed/$total')),
              const SizedBox(width: 8),
              Expanded(child: _metric('Completion', total == 0 ? '—' : '${(completed * 100 / total).round()}%')),
              const SizedBox(width: 8),
              Expanded(child: _metric('Avg. score', daysWithTasks.isEmpty ? '—' : '${averageScore.toStringAsFixed(1)}/10')),
            ]),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              Expanded(child: _metric('Current streak', '$currentStreak days')),
              const SizedBox(width: 8),
              Expanded(child: _metric('Best streak', '$bestStreak days')),
            ]),
            const SizedBox(height: 20),
            const Text('Daily completion · gold = completed, dark = incomplete'),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(days.length, (int index) {
                  final TaskDayStats stats = daily[index];
                  final Widget bar = SizedBox(
                    height: 140,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: stats.hasTasks ? AppColors.border : AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        if (stats.hasTasks)
                          FractionallySizedBox(
                            heightFactor: stats.completionRate.clamp(0.03, 1.0).toDouble(),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message: '${_formatDate(days[index])}: ${stats.hasTasks ? '${stats.completed} completed, ${stats.incomplete} incomplete (${(stats.completionRate * 100).round()}%)' : 'No tasks scheduled'}',
                        child: bar,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[Text(_formatDate(days.first), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), Text(_formatDate(days[days.length ~/ 2]), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), Text(_formatDate(days.last), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
            const SizedBox(height: 16),
            Text(today.hasTasks ? 'Today: ${today.completed}/${today.total} completed · ${(today.completionRate * 100).round()}% · weighted score ${today.weightedScore.toStringAsFixed(1)}/10' : 'Today: No tasks scheduled'),
            const SizedBox(height: 8),
            const Text('The simple completion percentage treats eligible tasks equally. The weighted score gives higher-priority tasks more weight. Paused tasks and subtasks are not double-counted.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]));
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _priority(int priority) => switch (priority) { 1 => 'Low', 2 => 'Medium', 3 => 'High', _ => 'Urgent' };
extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
