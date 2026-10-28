import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/ids.dart';
import '../../domain/models/task.dart';
import '../../shared/utils/local_attachments.dart';
import '../../state/task_state.dart';

/// Full-screen, offline Add/Edit Task workflow.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.existing});
  final TaskItem? existing;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _notes;
  late DateTime _deadline;
  late bool _hasDeadlineTime;
  DateTime? _reminder;
  late int _priority;
  late int _color;
  late int _icon;
  late String _repeat;
  late bool _completed;
  late bool _paused;
  late List<String> _photos;
  late List<String> _audio;
  List<TaskItem> _subtasks = <TaskItem>[];
  final LocalAudioRecorder _recorder = LocalAudioRecorder();
  final LocalAudioPlayback _playback = LocalAudioPlayback();
  bool _recording = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final TaskItem? task = widget.existing;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _category = TextEditingController(text: task?.category ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _deadline = task?.dueDate ?? DateTime.now();
    _hasDeadlineTime = task != null && (task.dueDate.hour != 0 || task.dueDate.minute != 0);
    _reminder = task?.reminderAt;
    _priority = task?.priority ?? 2;
    _color = task?.colorValue ?? 0xFFFFC62B;
    _icon = task?.iconCodePoint ?? Icons.task_alt.codePoint;
    _repeat = task?.repeatRule ?? 'none';
    _completed = task?.isCompleted ?? false;
    _paused = task?.isPaused ?? false;
    _photos = List<String>.of(task?.photoPaths ?? const <String>[]);
    _audio = List<String>.of(task?.audioPaths ?? const <String>[]);
    if (task != null) {
      _subtasks = (ref.read(taskListProvider).valueOrNull ?? const <TaskItem>[])
          .where((TaskItem item) => item.parentId == task.id)
          .toList()
        ..sort((TaskItem a, TaskItem b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _notes.dispose();
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Task' : 'Edit Task'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              _section('Task details', Icons.task_alt_rounded),
              TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Task title', hintText: 'What needs to get done?')),
              const SizedBox(height: 10),
              TextField(controller: _description, textCapitalization: TextCapitalization.sentences, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              TextField(controller: _category, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category', hintText: 'Study, Work, Personal…')),
              const SizedBox(height: 18),
              _section('Schedule', Icons.event_available_outlined),
              _dateTile(title: 'Deadline', date: _deadline, time: _hasDeadlineTime, onTap: _chooseDeadline, trailing: _hasDeadlineTime ? IconButton(tooltip: 'Clear deadline time', onPressed: () => setState(() { _hasDeadlineTime = false; _deadline = DateTime(_deadline.year, _deadline.month, _deadline.day); }), icon: const Icon(Icons.close)) : null),
              _dateTile(title: 'Reminder', date: _reminder, time: _reminder != null, onTap: _chooseReminder, trailing: _reminder == null ? null : IconButton(tooltip: 'Remove reminder', onPressed: () => setState(() => _reminder = null), icon: const Icon(Icons.close))),
              DropdownButtonFormField<String>(value: _repeat, decoration: const InputDecoration(labelText: 'Repeat'), items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
                DropdownMenuItem(value: 'daily', child: Text('Every day')),
                DropdownMenuItem(value: 'weekdays', child: Text('Weekdays')),
                DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                DropdownMenuItem(value: 'monthly', child: Text('Every month')),
              ], onChanged: (String? value) => setState(() => _repeat = value ?? 'none')),
              const SizedBox(height: 18),
              _section('Priority and appearance', Icons.tune_rounded),
              DropdownButtonFormField<int>(value: _priority, decoration: const InputDecoration(labelText: 'Priority'), items: const <DropdownMenuItem<int>>[
                DropdownMenuItem(value: 1, child: Text('Low')),
                DropdownMenuItem(value: 2, child: Text('Medium')),
                DropdownMenuItem(value: 3, child: Text('High')),
                DropdownMenuItem(value: 4, child: Text('Urgent')),
              ], onChanged: (int? value) => setState(() => _priority = value ?? 2)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(value: _icon, decoration: const InputDecoration(labelText: 'Icon'), items: <DropdownMenuItem<int>>[
                DropdownMenuItem(value: Icons.task_alt.codePoint, child: const Text('Task')),
                DropdownMenuItem(value: Icons.menu_book.codePoint, child: const Text('Study')),
                DropdownMenuItem(value: Icons.work_outline.codePoint, child: const Text('Work')),
                DropdownMenuItem(value: Icons.fitness_center.codePoint, child: const Text('Fitness')),
                DropdownMenuItem(value: Icons.home_outlined.codePoint, child: const Text('Home')),
                DropdownMenuItem(value: Icons.shopping_bag_outlined.codePoint, child: const Text('Shopping')),
                DropdownMenuItem(value: Icons.flag_outlined.codePoint, child: const Text('Goal')),
              ], onChanged: (int? value) => setState(() => _icon = value ?? Icons.task_alt.codePoint)),
              const SizedBox(height: 14),
              const Text('Colour', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 8, children: <int>[
                0xFFFFC62B, 0xFF4CAF50, 0xFF2196F3, 0xFF9C27B0, 0xFFE91E63,
                0xFFFF5722, 0xFF00BCD4, 0xFF8BC34A, 0xFF795548, 0xFF1B5E20,
                0xFF66BB6A, 0xFF9575CD, 0xFF607D8B, 0xFF009688,
              ].map((int value) => InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => setState(() => _color = value),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(value), shape: BoxShape.circle, border: Border.all(color: _color == value ? Colors.white : Colors.transparent, width: 3)), child: _color == value ? const Icon(Icons.check, size: 17, color: Colors.black) : null),
              )).toList()),
              const SizedBox(height: 18),
              _section('Subtasks', Icons.checklist_rounded),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(children: <Widget>[
                  ListTile(
                    title: Text(_subtasks.isEmpty ? 'Add an ordered checklist' : '${_subtasks.where((TaskItem t) => t.isCompleted).length} of ${_subtasks.length} complete'),
                    subtitle: const Text('Each subtask may have its own deadline.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openSubtaskEditor,
                  ),
                  if (_subtasks.isNotEmpty) ..._subtasks.map((TaskItem task) => ListTile(
                    dense: true,
                    leading: Icon(task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: task.isCompleted ? AppColors.gold : AppColors.textSecondary),
                    title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Due ${_dateLabel(task.dueDate)}${task.dueDate.hour == 0 && task.dueDate.minute == 0 ? '' : ' · ${TimeOfDay.fromDateTime(task.dueDate).format(context)}'}'),
                  )),
                ]),
              ),
              const SizedBox(height: 18),
              _section('Notes and attachments', Icons.attach_file_rounded),
              TextField(controller: _notes, textCapitalization: TextCapitalization.sentences, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Text notes', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                OutlinedButton.icon(onPressed: () => _addPhoto(camera: true), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
                OutlinedButton.icon(onPressed: () => _addPhoto(), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
                FilledButton.tonalIcon(onPressed: _toggleRecording, icon: Icon(_recording ? Icons.stop : Icons.mic_none), label: Text(_recording ? 'Stop recording' : 'Record audio')),
              ]),
              if (_photos.isNotEmpty) ..._photos.map((String path) => ListTile(dense: true, leading: const Icon(Icons.image_outlined), title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: () => setState(() => _photos.remove(path)), icon: const Icon(Icons.close)))),
              if (_audio.isNotEmpty) ..._audio.map((String path) => ListTile(dense: true, leading: const Icon(Icons.audio_file_outlined), title: Text(path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Wrap(children: <Widget>[IconButton(onPressed: () => _playback.play(path), icon: const Icon(Icons.play_arrow)), IconButton(onPressed: () => setState(() => _audio.remove(path)), icon: const Icon(Icons.close))]))),
              if (widget.existing != null) ...<Widget>[
                const SizedBox(height: 18),
                SwitchListTile(title: const Text('Paused'), value: _paused, onChanged: (bool value) => setState(() => _paused = value)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(widget.existing == null ? 'Create task' : 'Save changes'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: <Widget>[Icon(icon, color: AppColors.gold, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
      );

  Widget _dateTile({required String title, required DateTime? date, required bool time, required VoidCallback onTap, Widget? trailing}) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(date == null ? 'Not set' : '${_dateLabel(date)}${time ? ' · ${TimeOfDay.fromDateTime(date).format(context)}' : ''}'),
    leading: Icon(title == 'Reminder' ? Icons.notifications_active_outlined : Icons.calendar_month_outlined, color: AppColors.gold),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[if (trailing != null) trailing, IconButton(onPressed: onTap, icon: const Icon(Icons.edit_calendar_outlined))]),
    onTap: onTap,
  );

  Future<void> _chooseDeadline() async {
    final DateTime? date = await showDatePicker(context: context, initialDate: _deadline, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    setState(() => _deadline = DateTime(date.year, date.month, date.day, _hasDeadlineTime ? _deadline.hour : 0, _hasDeadlineTime ? _deadline.minute : 0));
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: _hasDeadlineTime ? TimeOfDay.fromDateTime(_deadline) : const TimeOfDay(hour: 17, minute: 0));
    if (time != null && mounted) setState(() { _deadline = DateTime(_deadline.year, _deadline.month, _deadline.day, time.hour, time.minute); _hasDeadlineTime = true; });
  }

  Future<void> _chooseReminder() async {
    final DateTime initial = _reminder ?? _deadline;
    final DateTime? date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: _reminder == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(_reminder!));
    if (time != null && mounted) setState(() => _reminder = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _addPhoto({bool camera = false}) async {
    try { final String? path = await LocalAttachments.pickPhoto(camera: camera); if (path != null && mounted) setState(() => _photos.add(path)); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not attach photo: $error'))); }
  }

  Future<void> _toggleRecording() async {
    try {
      if (!_recording) {
        final bool ok = await _recorder.start();
        if (mounted && ok) setState(() => _recording = true);
        if (mounted && !ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission was not granted.')));
      } else {
        final String? path = await _recorder.stop();
        if (mounted) setState(() { _recording = false; if (path != null) _audio.add(path); });
      }
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording failed: $error'))); }
  }

  Future<void> _openSubtaskEditor() async {
    final List<TaskItem>? updated = await Navigator.of(context).push<List<TaskItem>>(
      MaterialPageRoute<List<TaskItem>>(fullscreenDialog: true, builder: (_) => SubtaskEditorScreen(initial: List<TaskItem>.of(_subtasks), defaultDeadline: _deadline, inheritedPriority: _priority)),
    );
    if (updated != null && mounted) setState(() => _subtasks = updated);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a task title first.')));
      return;
    }
    setState(() => _saving = true);
    final DateTime now = DateTime.now();
    final TaskItem? existing = widget.existing;
    final TaskItem task = TaskItem(
      id: existing?.id ?? newId(), title: _title.text.trim(),
      description: _description.text.trim(), category: _category.text.trim(),
      notes: _notes.text.trim(), photoPaths: List<String>.of(_photos), audioPaths: List<String>.of(_audio),
      createdAt: existing?.createdAt ?? now, updatedAt: now, dueDate: _deadline,
      reminderAt: _reminder, priority: _priority, colorValue: _color, iconCodePoint: _icon,
      isCompleted: _completed, completedAt: existing == null ? null : existing.completedAt,
      isPaused: _paused, sortOrder: existing?.sortOrder ?? 0, repeatRule: _repeat,
    );
    try {
      final TaskListNotifier notifier = ref.read(taskListProvider.notifier);
      await notifier.save(task);
      if (existing != null) {
        for (final String path in existing.photoPaths.where((String path) => !_photos.contains(path))) { await LocalAttachments.deleteFile(path); }
        for (final String path in existing.audioPaths.where((String path) => !_audio.contains(path))) { await LocalAttachments.deleteFile(path); }
      }
      final List<TaskItem> beforeChildren = (ref.read(taskListProvider).valueOrNull ?? const <TaskItem>[]).where((TaskItem item) => item.parentId == task.id).toList();
      final Set<String> retained = _subtasks.map((TaskItem item) => item.id).toSet();
      for (final TaskItem child in beforeChildren.where((TaskItem item) => !retained.contains(item.id))) { await notifier.delete(child.id); }
      for (int index = 0; index < _subtasks.length; index++) {
        final TaskItem child = _subtasks[index];
        await notifier.save(child.copyWith(parentId: task.id, priority: _priority, sortOrder: index, updatedAt: now));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Dedicated full-screen editor for ordered subtasks. Deadlines are stored on
/// each subtask and are not overwritten when the parent task changes.
class SubtaskEditorScreen extends StatefulWidget {
  const SubtaskEditorScreen({super.key, required this.initial, required this.defaultDeadline, required this.inheritedPriority});
  final List<TaskItem> initial;
  final DateTime defaultDeadline;
  final int inheritedPriority;

  @override
  State<SubtaskEditorScreen> createState() => _SubtaskEditorScreenState();
}

class _SubtaskEditorScreenState extends State<SubtaskEditorScreen> {
  late List<TaskItem> _items;

  @override
  void initState() { super.initState(); _items = List<TaskItem>.of(widget.initial); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subtask editor'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, _items), child: const Text('Done'))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add subtask')),
    body: _items.isEmpty
      ? const Center(child: Text('Add subtasks to create an ordered checklist.'))
      : Column(children: <Widget>[
          Padding(padding: const EdgeInsets.all(16), child: Row(children: <Widget>[Expanded(child: Text('${_items.where((TaskItem item) => item.isCompleted).length}/${_items.length} completed', style: const TextStyle(fontWeight: FontWeight.w700))), Text('Priority inherited', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
          LinearProgressIndicator(value: _items.isEmpty ? 0 : _items.where((TaskItem item) => item.isCompleted).length / _items.length, color: AppColors.gold),
          Expanded(child: ReorderableListView.builder(padding: const EdgeInsets.only(bottom: 90), itemCount: _items.length, onReorder: (int oldIndex, int newIndex) { setState(() { if (newIndex > oldIndex) newIndex--; final TaskItem value = _items.removeAt(oldIndex); _items.insert(newIndex, value); }); }, itemBuilder: (BuildContext context, int index) {
            final TaskItem item = _items[index];
            return Card(key: ValueKey<String>(item.id), margin: const EdgeInsets.fromLTRB(12, 5, 12, 5), child: ListTile(leading: Icon(item.isCompleted ? Icons.check_circle : Icons.drag_handle_rounded, color: item.isCompleted ? AppColors.gold : AppColors.textSecondary), title: Text(item.title), subtitle: Text('Due ${_dateLabel(item.dueDate)}${item.dueDate.hour == 0 && item.dueDate.minute == 0 ? '' : ' · ${TimeOfDay.fromDateTime(item.dueDate).format(context)}'}${item.isCompleted ? ' · Completed' : item.isOverdue(DateTime.now()) ? ' · Overdue' : ''}'), onTap: () => _edit(index), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _items.removeAt(index)))));
          }))
        ]),
  );

  Future<void> _add() async { await _edit(null); }

  Future<void> _edit(int? index) async {
    final TaskItem? prior = index == null ? null : _items[index];
    final TextEditingController title = TextEditingController(text: prior?.title ?? '');
    DateTime due = prior?.dueDate ?? widget.defaultDeadline;
    bool hasTime = due.hour != 0 || due.minute != 0;
    final TaskItem? result = await showDialog<TaskItem>(context: context, builder: (BuildContext dialogContext) => StatefulBuilder(builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
      title: Text(prior == null ? 'Add subtask' : 'Edit subtask'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        TextField(controller: title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Subtask name')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline'), subtitle: Text('${_dateLabel(due)}${hasTime ? ' · ${TimeOfDay.fromDateTime(due).format(context)}' : ''}'), trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async { final DateTime? date = await showDatePicker(context: context, initialDate: due, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (date != null) setLocal(() => due = DateTime(date.year, date.month, date.day, hasTime ? due.hour : 0, hasTime ? due.minute : 0)); })),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Deadline time (optional)'), subtitle: Text(hasTime ? TimeOfDay.fromDateTime(due).format(context) : 'No specific time'), trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async { final TimeOfDay? time = await showTimePicker(context: context, initialTime: hasTime ? TimeOfDay.fromDateTime(due) : const TimeOfDay(hour: 17, minute: 0)); if (time != null) setLocal(() { due = DateTime(due.year, due.month, due.day, time.hour, time.minute); hasTime = true; }); })),
      ])), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { if (title.text.trim().isEmpty) return; final DateTime now = DateTime.now(); Navigator.pop(dialogContext, TaskItem(id: prior?.id ?? newId(), title: title.text.trim(), createdAt: prior?.createdAt ?? now, updatedAt: now, dueDate: due, priority: widget.inheritedPriority, parentId: prior?.parentId, sortOrder: index ?? _items.length, isCompleted: prior?.isCompleted ?? false, completedAt: prior?.completedAt)); }, child: const Text('Save'))])));
    title.dispose();
    if (result == null || !mounted) return;
    setState(() { if (index == null) { _items.add(result); } else { _items[index] = result; } });
  }
}

String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
