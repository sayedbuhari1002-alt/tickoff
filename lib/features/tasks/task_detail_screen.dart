import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_activity.dart';
import '../../state/preferences_state.dart';
import '../../state/task_state.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> tasks = ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[];
    final TaskItem? task = tasks.where((TaskItem item) => item.id == taskId && !item.isSubtask).firstOrNull;
    if (task == null) {
      return Scaffold(appBar: AppBar(title: const Text('Task details')), body: const Center(child: Text('This task is no longer available.')));
    }
    final List<TaskItem> children = tasks.where((TaskItem item) => item.parentId == task.id).toList()..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder));
    final List<TaskActivity> activities = ref.watch(taskActivityProvider).valueOrNull ?? const <TaskActivity>[];
    final int completeChildren = children.where((TaskItem item) => item.isCompleted).length;
    final Color taskColor = Color(task.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Task options',
            onSelected: (String action) async {
              if (action == 'progress') {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskProgressScreen(taskId: task.id)));
              } else if (action == 'edit') {
                await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => TaskFormScreen(existing: task)));
              } else if (action == 'delete') {
                final bool confirmed = !ref.read(confirmDeletesProvider) || (await showDialog<bool>(context: context, builder: (BuildContext dialogContext) => AlertDialog(title: const Text('Delete task?'), content: Text('Delete “${task.title}” and its subtasks? Historical analytics will be retained.'), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))])) ?? false);
                if (confirmed) { await ref.read(taskListProvider.notifier).delete(task.id); if (context.mounted) Navigator.of(context).pop(); }
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'progress', child: ListTile(leading: Icon(Icons.insights_outlined), title: Text('Progress'))),
              PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
              PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[taskColor.withAlpha(50), AppColors.surface])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Container(width: 48, height: 48, decoration: BoxDecoration(color: taskColor.withAlpha(55), borderRadius: BorderRadius.circular(14)), child: Icon(IconData(task.iconCodePoint, fontFamily: 'MaterialIcons'), color: taskColor, size: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(task.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  if (task.category.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(task.category, style: const TextStyle(color: AppColors.textSecondary))),
                ])),
                Checkbox(value: task.isCompleted, onChanged: (_) => ref.read(taskListProvider.notifier).toggleTaskOrNextSubtask(task, tasks)),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                _statusPill(task.isCompleted ? 'Completed' : task.isPaused ? 'Paused' : task.isOverdue(DateTime.now()) ? 'Overdue' : 'Incomplete', task.isCompleted ? AppColors.gold : task.isOverdue(DateTime.now()) ? AppColors.danger : AppColors.textSecondary),
                _statusPill(_priority(task.priority), taskColor),
                if (task.repeatRule != 'none') _statusPill('Repeat: ${task.repeatRule}', AppColors.textSecondary),
              ]),
              if (task.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Text(task.description, style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          _infoCard('Schedule', Icons.calendar_month_outlined, <Widget>[
            _detailRow('Deadline', _dateTime(task.dueDate)),
            _detailRow('Reminder', task.reminderAt == null ? 'Not set' : _dateTime(task.reminderAt!)),
            _detailRow('Created', _dateTime(task.createdAt)),
            if (task.completedAt != null) _detailRow('Completed', _dateTime(task.completedAt!)),
          ]),
          if (children.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _infoCard('Subtasks · $completeChildren/${children.length}', Icons.checklist_rounded, <Widget>[
              LinearProgressIndicator(value: completeChildren / children.length, minHeight: 5, color: AppColors.gold, backgroundColor: AppColors.border),
              const SizedBox(height: 6),
              ...children.map((TaskItem child) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: child.isCompleted,
                onChanged: (_) => ref.read(taskListProvider.notifier).toggleSubtaskAndSyncParent(child),
                title: Text(child.title, style: TextStyle(decoration: child.isCompleted ? TextDecoration.lineThrough : null)),
                subtitle: Text('Due ${_dateTime(child.dueDate)}${child.isOverdue(DateTime.now()) ? ' · OVERDUE' : ''}'),
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ]),
          ],
          const SizedBox(height: 14),
          _infoCard('Notes and attachments', Icons.attach_file_rounded, <Widget>[
            if (task.notes.trim().isEmpty && task.photoPaths.isEmpty && task.audioPaths.isEmpty) const Text('No notes or attachments yet.', style: TextStyle(color: AppColors.textSecondary)),
            if (task.notes.trim().isNotEmpty) Text(task.notes, style: const TextStyle(height: 1.4)),
            ...task.photoPaths.map((String path) => _PhotoAttachment(path: path)),
            ...task.audioPaths.map((String path) => _AudioAttachment(path: path)),
          ]),
          const SizedBox(height: 14),
          _infoCard('History', Icons.history_rounded, <Widget>[
            if (activities.where((TaskActivity event) => event.taskId == task.id || children.any((TaskItem child) => child.id == event.taskId)).isEmpty) const Text('No completion history yet.', style: TextStyle(color: AppColors.textSecondary)),
            ...activities.where((TaskActivity event) => event.taskId == task.id || children.any((TaskItem child) => child.id == event.taskId)).toList().reversed.take(8).map((TaskActivity event) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(event.isCompletion ? Icons.check_circle_outline : Icons.undo_rounded, color: event.isCompletion ? AppColors.gold : AppColors.textSecondary), title: Text('${event.title} · ${event.activityType}'), subtitle: Text(_dateTime(event.occurredAt))))
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskProgressScreen(taskId: task.id))), icon: const Icon(Icons.insights_outlined), label: const Text('View task progress and analytics')),
        ],
      ),
    );
  }
}

class TaskProgressScreen extends ConsumerWidget {
  const TaskProgressScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TaskItem> tasks = ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[];
    final TaskItem? task = tasks.where((TaskItem item) => item.id == taskId).firstOrNull;
    final List<TaskActivity> activities = ref.watch(taskActivityProvider).valueOrNull ?? const <TaskActivity>[];
    final List<TaskActivity> related = activities.where((TaskActivity event) => event.taskId == taskId || event.parentId == taskId).toList()..sort((TaskActivity a, TaskActivity b) => b.occurredAt.compareTo(a.occurredAt));
    final List<TaskItem> children = tasks.where((TaskItem item) => item.parentId == taskId).toList();
    return Scaffold(appBar: AppBar(title: const Text('Task progress')), body: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Text(task?.title ?? 'Task progress', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _infoCard('Current status', Icons.insights_outlined, <Widget>[
        _detailRow('Status', task == null ? 'Deleted task' : task.isCompleted ? 'Completed' : task.isPaused ? 'Paused' : task.isOverdue(DateTime.now()) ? 'Overdue' : 'Incomplete'),
        _detailRow('Priority', task == null ? '—' : _priority(task.priority)),
        _detailRow('Deadline', task == null ? '—' : _dateTime(task.dueDate)),
        if (children.isNotEmpty) _detailRow('Subtasks', '${children.where((TaskItem item) => item.isCompleted).length}/${children.length} completed'),
        _detailRow('Recorded completions', '${related.where((TaskActivity event) => event.isCompletion).length}'),
      ]),
      const SizedBox(height: 14),
      _infoCard('Activity timeline', Icons.timeline_rounded, <Widget>[
        if (related.isEmpty) const Text('No activity recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
        ...related.map((TaskActivity event) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(event.isCompletion ? Icons.check_circle : Icons.undo, color: event.isCompletion ? AppColors.gold : AppColors.textSecondary), title: Text('${event.title} · ${event.activityType}'), subtitle: Text('${_dateTime(event.occurredAt)} · deadline ${_dateTime(event.dueDate)}'))),
      ]),
    ]));
  }
}

class _PhotoAttachment extends StatelessWidget {
  const _PhotoAttachment({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: File(path).existsSync() ? Image.file(File(path), height: 200, fit: BoxFit.cover) : ListTile(leading: const Icon(Icons.broken_image_outlined), title: Text(path.split('/').last))));
}

class _AudioAttachment extends StatefulWidget {
  const _AudioAttachment({required this.path});
  final String path;
  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}
class _AudioAttachmentState extends State<_AudioAttachment> {
  final AudioPlayer _player = AudioPlayer();
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.audio_file_outlined), title: Text(widget.path.split('/').last), trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _player.play(DeviceFileSource(widget.path))));
}

Widget _infoCard(String title, IconData icon, List<Widget> children) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Row(children: <Widget>[Icon(icon, color: AppColors.gold), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))]), const SizedBox(height: 10), ...children]));
Widget _detailRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))), Expanded(child: Text(value))]));
Widget _statusPill(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withAlpha(34), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)));
String _priority(int value) => switch (value) { 1 => 'Low priority', 2 => 'Medium priority', 3 => 'High priority', _ => 'Urgent priority' };
String _dateTime(DateTime value) {
  final int hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final String minute = value.minute.toString().padLeft(2, '0');
  final String ampm = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · $hour:$minute $ampm';
}
extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
