import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/logic/task_analytics.dart';
import '../../domain/logic/task_visibility.dart';
import '../../domain/models/task.dart';
import '../../domain/models/task_activity.dart';
import '../../state/task_state.dart';

/// Selectable historical task analytics with day-level drill-down.
class TaskAnalyticsScreen extends ConsumerStatefulWidget {
  const TaskAnalyticsScreen({super.key});
  @override
  ConsumerState<TaskAnalyticsScreen> createState() => _TaskAnalyticsScreenState();
}

enum _Range { day, week, month, days30, days90, year, custom }

class _TaskAnalyticsScreenState extends ConsumerState<TaskAnalyticsScreen> {
  _Range _range = _Range.days30;
  DateTime _selectedDay = DateTime.now();
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Widget build(BuildContext context) {
    final List<TaskItem> tasks = <TaskItem>[
      ...(ref.watch(taskListProvider).valueOrNull ?? const <TaskItem>[]),
      ...(ref.watch(taskHistoryProvider).valueOrNull ?? const <TaskItem>[]),
    ];
    final List<TaskActivity> activities = ref.watch(taskActivityProvider).valueOrNull ?? const <TaskActivity>[];
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime end = switch (_range) {
      _Range.day => _dateOnly(_selectedDay),
      _Range.week => _dateOnly(_selectedDay),
      _Range.month => _dateOnly(_selectedDay),
      _Range.days30 => today,
      _Range.days90 => today,
      _Range.year => today,
      _Range.custom => _customEnd == null ? today : _dateOnly(_customEnd!),
    };
    final DateTime start = switch (_range) {
      _Range.day => end,
      _Range.week => end.subtract(const Duration(days: 6)),
      _Range.month => DateTime(end.year, end.month, 1),
      _Range.days30 => end.subtract(const Duration(days: 29)),
      _Range.days90 => end.subtract(const Duration(days: 89)),
      _Range.year => end.subtract(const Duration(days: 364)),
      _Range.custom => _customStart == null ? end.subtract(const Duration(days: 29)) : _dateOnly(_customStart!),
    };
    final List<DateTime> days = _dates(start, end);
    const TaskAnalytics engine = TaskAnalytics();
    final List<TaskDayStats> daily = days.map((DateTime day) => engine.forDayWithActivity(tasks: tasks, activities: activities, day: day)).toList();
    final TaskDayStats selectedStats = engine.forDayWithActivity(tasks: tasks, activities: activities, day: _selectedDay);
    final int total = daily.fold<int>(0, (int sum, TaskDayStats stats) => sum + stats.total);
    final int completed = daily.fold<int>(0, (int sum, TaskDayStats stats) => sum + stats.completed);
    final int overdue = daily.fold<int>(0, (int sum, TaskDayStats stats) => sum + stats.overdue);
    final int onTime = daily.fold<int>(0, (int sum, TaskDayStats stats) => sum + stats.onTimeCompleted);
    final int late = daily.fold<int>(0, (int sum, TaskDayStats stats) => sum + stats.lateCompleted);
    final List<TaskDayStats> activeDays = daily.where((TaskDayStats stats) => stats.hasTasks).toList();
    final double score = activeDays.isEmpty ? 0 : activeDays.fold<double>(0, (double sum, TaskDayStats stats) => sum + stats.weightedScore) / activeDays.length;
    final int streak = _currentStreak(daily);
    final int best = _bestStreak(daily);

    return Scaffold(
      appBar: AppBar(title: const Text('Task analytics')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: <Widget>[
        Wrap(spacing: 7, runSpacing: 7, children: <Widget>[
          _rangeChip('Day', _Range.day), _rangeChip('Week', _Range.week), _rangeChip('Month', _Range.month),
          _rangeChip('30 days', _Range.days30), _rangeChip('90 days', _Range.days90), _rangeChip('1 year', _Range.year), _rangeChip('Custom', _Range.custom),
        ]),
        if (_range == _Range.day || _range == _Range.week || _range == _Range.month) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _pickAnchor, icon: const Icon(Icons.calendar_month), label: Text('Anchor date: ${_dateLabel(_selectedDay)}')),
        ],
        if (_range == _Range.custom) ...<Widget>[
          const SizedBox(height: 12),
          Row(children: <Widget>[
            Expanded(child: OutlinedButton(onPressed: () => _pickCustom(startDate: true), child: Text('From ${_customStart == null ? 'date' : _dateLabel(_customStart!)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _pickCustom(startDate: false), child: Text('To ${_customEnd == null ? 'today' : _dateLabel(_customEnd!)}'))),
          ]),
        ],
        const SizedBox(height: 10),
        Text('${_dateLabel(start)} — ${_dateLabel(end)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.75, children: <Widget>[
          _metric('Items tracked', '$total', Icons.checklist_rounded),
          _metric('Completed', '$completed', Icons.check_circle_outline),
          _metric('Incomplete', '${total - completed}', Icons.radio_button_unchecked),
          _metric('Overdue days/items', '$overdue', Icons.warning_amber_rounded),
          _metric('Completion', total == 0 ? '—' : '${(completed * 100 / total).round()}%', Icons.percent_rounded),
          _metric('On time', completed == 0 ? '—' : '${(onTime * 100 / completed).round()}%', Icons.schedule_rounded),
          _metric('Weighted score', '${score.toStringAsFixed(1)}/10', Icons.stars_rounded),
          _metric('Current / best streak', '$streak / $best', Icons.local_fire_department_rounded),
        ]),
        const SizedBox(height: 22),
        const Text('Daily completion', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Tap a day to inspect its scheduled, pending and completed items.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        SizedBox(height: 185, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: days.length, separatorBuilder: (_, __) => const SizedBox(width: 5), itemBuilder: (BuildContext context, int index) {
          final TaskDayStats stats = daily[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () { setState(() => _selectedDay = days[index]); _inspectDay(context, days[index], tasks, activities, stats); },
            child: SizedBox(width: _range == _Range.year || _range == _Range.days90 ? 9 : 22, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
              Expanded(child: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: double.infinity, height: 132, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Stack(alignment: Alignment.bottomCenter, children: <Widget>[
                Container(color: AppColors.surfaceRaised),
                if (stats.total > 0) FractionallySizedBox(heightFactor: stats.completionRate.clamp(0.03, 1.0).toDouble(), alignment: Alignment.bottomCenter, child: Container(color: AppColors.gold)),
              ]))))),
              if (_range != _Range.year && _range != _Range.days90) Padding(padding: const EdgeInsets.only(top: 5), child: Text('${days[index].day}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
            ])),
          );
        })),
        const SizedBox(height: 10),
        const Text('Completion trend', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(height: 76, width: double.infinity, child: CustomPaint(painter: _TrendLinePainter(daily.map((TaskDayStats stats) => stats.completionRate).toList()))),
        const SizedBox(height: 12),
        _infoCard('Completed vs incomplete', <Widget>[
          _comparison('Completed', completed, total == 0 ? 0 : completed / total, AppColors.gold),
          _comparison('Incomplete', total - completed, total == 0 ? 0 : (total - completed) / total, AppColors.border),
          _comparison('On time', onTime, completed == 0 ? 0 : onTime / completed, const Color(0xFF4CAF50)),
          _comparison('Late', late, completed == 0 ? 0 : late / completed, AppColors.danger),
        ]),
        const SizedBox(height: 16),
        _infoCard('Selected day · ${_dateLabel(_selectedDay)}', <Widget>[
          _row('Scheduled for this day', '${selectedStats.scheduled}'),
          _row('Incomplete / overdue', '${selectedStats.incomplete} / ${selectedStats.overdue}'),
          _row('Completed on this day', '${selectedStats.completed}'),
          _row('Completed on time / late', '${selectedStats.onTimeCompleted} / ${selectedStats.lateCompleted}'),
          _row('Subtasks completed on day', '${selectedStats.subtasksCompleted}'),
          _row('Subtasks incomplete / overdue', '${selectedStats.subtasksIncomplete} / ${selectedStats.subtasksOverdue}'),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _inspectDay(context, _selectedDay, tasks, activities, selectedStats), icon: const Icon(Icons.open_in_new), label: const Text('Inspect this day'))),
        ]),
      ]),
    );
  }

  Widget _rangeChip(String label, _Range value) => ChoiceChip(label: Text(label), selected: _range == value, onSelected: (_) => setState(() { _range = value; if (_range == _Range.day) _selectedDay = _dateOnly(_selectedDay); }));

  Widget _metric(String label, String value, IconData icon) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[Icon(icon, color: AppColors.gold, size: 19), Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]));
  Widget _infoCard(String title, List<Widget> children) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), ...children]));
  Widget _comparison(String label, int number, double fraction, Color color) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: <Widget>[Row(children: <Widget>[Expanded(child: Text(label)), Text('$number')]), const SizedBox(height: 4), LinearProgressIndicator(value: fraction.clamp(0.0, 1.0).toDouble(), color: color, backgroundColor: AppColors.border, minHeight: 5)]));
  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: <Widget>[Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]));

  Future<void> _pickAnchor() async {
    final DateTime? chosen = await showDatePicker(context: context, initialDate: _selectedDay, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (chosen != null && mounted) setState(() => _selectedDay = _dateOnly(chosen));
  }

  Future<void> _pickCustom({required bool startDate}) async {
    final DateTime now = _dateOnly(DateTime.now());
    final DateTime initial = startDate ? (_customStart ?? now.subtract(const Duration(days: 29))) : (_customEnd ?? now);
    final DateTime? chosen = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (chosen == null || !mounted) return;
    setState(() {
      if (startDate) { _customStart = _dateOnly(chosen); if (_customEnd != null && _customEnd!.isBefore(_customStart!)) _customEnd = _customStart; }
      else { _customEnd = _dateOnly(chosen); if (_customStart != null && _customStart!.isAfter(_customEnd!)) _customStart = _customEnd; }
    });
  }

  Future<void> _inspectDay(BuildContext context, DateTime day, List<TaskItem> tasks, List<TaskActivity> activities, TaskDayStats stats) async {
    final DateTime selected = _dateOnly(day);
    final List<TaskItem> visible = tasks.where((TaskItem item) {
      if (item.isPaused || !item.createdAt.isBefore(selected.add(const Duration(days: 1)))) return false;
      if (item.deletedAt != null && selected.isAfter(_dateOnly(item.deletedAt!))) return false;
      if (!item.isSubtask) {
        final bool hasChildren = tasks.any((TaskItem child) => child.parentId == item.id && child.createdAt.isBefore(selected.add(const Duration(days: 1))));
        if (hasChildren) return false;
      }
      return _relevantForHistoricalDay(item, selected, activities);
    }).toList()..sort((TaskItem a, TaskItem b) => a.dueDate.compareTo(b.dueDate));
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, builder: (BuildContext sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(_dateLabel(selected), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('${stats.completed}/${stats.total} completed · ${stats.overdue} overdue', style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No items scheduled or pending for this day.')),
      ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: ListView(shrinkWrap: true, children: visible.map((TaskItem item) {
        final bool completedOnDay = activities.any((TaskActivity event) => event.taskId == item.id && event.isCompletion && _sameDay(event.occurredAt, selected));
        final DateTime endOfDay = selected.add(const Duration(days: 1));
        final List<TaskActivity> stateEvents = activities.where((TaskActivity event) => event.taskId == item.id && (event.activityType == 'completed' || event.activityType == 'reopened') && event.occurredAt.isBefore(endOfDay)).toList()..sort((TaskActivity a, TaskActivity b) => a.occurredAt.compareTo(b.occurredAt));
        final bool completeAsOf = stateEvents.isNotEmpty ? stateEvents.last.isCompletion : item.isCompleted && (item.completedAt == null || item.completedAt!.isBefore(endOfDay));
        final bool overdueOnDay = !completeAsOf && _dateOnly(selected).isAfter(_dateOnly(item.dueDate));
        final String status = completedOnDay ? 'Completed on this day' : completeAsOf ? 'Completed' : overdueOnDay ? 'Overdue / incomplete' : 'Incomplete';
        return ListTile(leading: Icon(completedOnDay || completeAsOf ? Icons.check_circle : Icons.radio_button_unchecked, color: completedOnDay || completeAsOf ? AppColors.gold : AppColors.textSecondary), title: Text(item.title), subtitle: Text('$status · due ${_dateLabel(item.dueDate)}${item.isSubtask ? ' · subtask' : ''}'));
      }).toList())),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Close'))),
    ]))));
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final Paint grid = Paint()..color = AppColors.border..strokeWidth = 1;
    final Paint line = Paint()..color = AppColors.gold..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    for (int i = 0; i < 4; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length == 1) {
      canvas.drawCircle(Offset(size.width / 2, size.height * (1 - values.first.clamp(0.0, 1.0))), 3, Paint()..color = AppColors.gold);
      return;
    }
    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double y = size.height * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, line);
  }
  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) => oldDelegate.values != values;
}

bool _relevantForHistoricalDay(TaskItem item, DateTime day, List<TaskActivity> activities) {
  final DateTime selected = _dateOnly(day);
  if (item.deletedAt != null && selected.isAfter(_dateOnly(item.deletedAt!))) return false;
  final DateTime endOfDay = selected.add(const Duration(days: 1));
  final List<TaskActivity> events = activities.where((TaskActivity event) => event.taskId == item.id && (event.activityType == 'completed' || event.activityType == 'reopened') && event.occurredAt.isBefore(endOfDay)).toList()..sort((TaskActivity a, TaskActivity b) => a.occurredAt.compareTo(b.occurredAt));
  final bool done = events.isNotEmpty ? events.last.isCompletion : item.isCompleted && (item.completedAt == null || item.completedAt!.isBefore(endOfDay));
  final bool completedToday = activities.any((TaskActivity event) => event.taskId == item.id && event.isCompletion && _sameDay(event.occurredAt, selected));
  final DateTime due = _dateOnly(item.dueDate);
  final DateTime? reminder = item.reminderAt == null ? null : _dateOnly(item.reminderAt!);
  final bool reminderWindow = reminder != null && !selected.isBefore(reminder) && !selected.isAfter(due);
  return _sameDay(due, selected) || completedToday || reminderWindow || (selected.isAfter(due) && !done);
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
List<DateTime> _dates(DateTime start, DateTime end) {
  if (end.isBefore(start)) return <DateTime>[start];
  final int count = end.difference(start).inDays + 1;
  // Keep the chart usable on a phone while range totals use the same selected span.
  if (count > 366) start = end.subtract(const Duration(days: 365));
  return List<DateTime>.generate(end.difference(start).inDays + 1, (int index) => start.add(Duration(days: index)));
}
int _currentStreak(List<TaskDayStats> stats) {
  int streak = 0;
  for (final TaskDayStats day in stats.reversed) {
    if (!day.hasTasks) continue;
    if (day.completionRate >= 1) { streak++; } else { break; }
  }
  return streak;
}
int _bestStreak(List<TaskDayStats> stats) {
  int best = 0, current = 0;
  for (final TaskDayStats day in stats) {
    if (!day.hasTasks) continue;
    if (day.completionRate >= 1) { current++; if (current > best) best = current; } else { current = 0; }
  }
  return best;
}
