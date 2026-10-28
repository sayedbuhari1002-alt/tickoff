import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/format.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/utils/habit_ui.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../dashboard/day_actions.dart';
import 'habit_sheets.dart';

/// Habit detail: status, streaks, score, quick actions, history and timeline.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppData? data = ref.watch(appDataProvider).valueOrNull;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final Habit? habit = data.habitById(habitId);
    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Habit not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final DateTime today = ref.watch(todayProvider);
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final HabitStats stats =
        ref.watch(habitStatsProvider)[habit.id] ?? HabitStats.empty;
    final CompletionRecord? record = data.recordsFor(habit.id)[dateKey(today)];
    final Color color = habit.color;
    final bool quit = habit.type == HabitType.quit;
    final bool slipped = quit && engine.isSlipped(habit, record);
    final bool complete = quit ? !slipped : engine.isCompleted(habit, record);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[color.withAlpha(70), Colors.black],
            stops: const <double>[0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Options',
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showOptions(context, ref, habit),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    0,
                    AppDimens.pagePadding,
                    AppDimens.gapLg,
                  ),
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(habit.icon, color: Colors.black, size: 40),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      habit.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: _StatusChip(
                        color: slipped ? AppColors.danger : color,
                        label: _statusLabel(habit, complete, slipped, record),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),
                    Row(
                      children: <Widget>[
                        _InfoChip(
                          label: frequencyLabel(habit),
                          onTap: () => showHabitInfoSheet(context, habit),
                        ),
                        const Spacer(),
                        _IconAction(
                          icon: Icons.emoji_events_outlined,
                          tooltip: 'Achievements',
                          onTap: () => showAchievementsSheet(context, habit.id),
                        ),
                        const SizedBox(width: 8),
                        _IconAction(
                          icon: Icons.bar_chart_rounded,
                          tooltip: 'Analytics',
                          onTap: () =>
                              context.push(AppRoutes.habitAnalytics(habit.id)),
                        ),
                        const SizedBox(width: 8),
                        _IconAction(
                          icon: Icons.calendar_month_outlined,
                          tooltip: 'History',
                          onTap: () => showHistorySheet(context, habit.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gap),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: StatTile(
                            value: '${stats.currentStreak}',
                            label: 'Current Streak',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: '${stats.bestStreak}',
                            label: 'Best Streak',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: percentLabel(stats.score),
                            label: 'Score',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gap),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.note_add_outlined,
                            label: 'Note',
                            color: color,
                            onTap: () => context
                                .push(AppRoutes.noteNew(habitId: habit.id)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.photo_camera_outlined,
                            label: 'Photo',
                            color: color,
                            onTap: () => context.push(AppRoutes.noteNew(habitId: habit.id)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.mic_none_rounded,
                            label: 'Audio',
                            color: color,
                            onTap: () => context.push(AppRoutes.noteNew(habitId: habit.id)),
                          ),
                        ),
                      ],
                    ),
                    if (habit.tracking == TrackingMethod.count) ...<Widget>[
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.remove_circle_outline),
                              label: Text('Remove ${formatNumber(habit.step)}'),
                              onPressed: (record?.count ?? 0) <= 0
                                  ? null
                                  : () => ref.read(appDataProvider.notifier).addCount(
                                        habit, today, -habit.step),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset today'),
                              onPressed: (record?.count ?? 0) <= 0
                                  ? null
                                  : () async {
                                      final bool? confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext dialogContext) => AlertDialog(
                                          title: const Text("Reset today's count?"),
                                          content: const Text("This resets only today's count to zero."),
                                          actions: <Widget>[
                                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reset')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(appDataProvider.notifier).setCount(habit, today, 0);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => tapDay(context, ref, habit, today),
                      onLongPress: () =>
                          longPressDay(context, ref, habit, today),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: slipped
                              ? AppColors.danger.withAlpha(120)
                              : color.withAlpha(complete ? 200 : 90),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              slipped
                                  ? Icons.close_rounded
                                  : Icons.check_circle_rounded,
                              color: complete && !slipped
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _doneLabel(habit, complete, slipped),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: complete && !slipped
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),
                    _Timeline(habit: habit, data: data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(
    Habit habit,
    bool complete,
    bool slipped,
    CompletionRecord? record,
  ) {
    if (habit.type == HabitType.quit) {
      return slipped ? 'Slipped today' : 'Slip-free today';
    }
    if (complete) return 'Completed';
    if (habit.tracking == TrackingMethod.count) {
      return 'Not Completed - ${countLabel(habit, record?.count ?? 0)}';
    }
    return 'Not Completed';
  }

  String _doneLabel(Habit habit, bool complete, bool slipped) {
    if (habit.type == HabitType.quit) {
      switch (habit.tracking) {
        case TrackingMethod.tick:
          return slipped ? 'Undo slip' : 'I slipped';
        case TrackingMethod.count:
          return 'Add ${formatNumber(habit.step)} (slip)';
        case TrackingMethod.checklist:
          return 'Mark slips';
      }
    }
    switch (habit.tracking) {
      case TrackingMethod.tick:
        return complete ? 'Mark not done' : 'Done';
      case TrackingMethod.count:
        final String unit = habit.unit.isEmpty ? '' : ' ${habit.unit}';
        return 'Add ${formatNumber(habit.step)}$unit';
      case TrackingMethod.checklist:
        return 'Open checklist';
    }
  }

  Future<void> _showOptions(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) {
    return showTickSheet<void>(
      context: context,
      title: 'Options',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SheetOptionTile(
              icon: Icons.ios_share_rounded,
              label: 'Share Progress',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.shareProgressFor(habit.id));
              },
            ),
            SheetOptionTile(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.habitEdit(habit.id));
              },
            ),
            SheetOptionTile(
              icon: habit.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: habit.isArchived ? 'Restore' : 'Archive',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool ok = await guarded(
                  context,
                  () => ref
                      .read(appDataProvider.notifier)
                      .setArchived(habit.id, !habit.isArchived),
                );
                if (!ok || !context.mounted) return;
                showMessage(
                  context,
                  habit.isArchived ? 'Habit restored.' : 'Habit archived.',
                );
                if (!habit.isArchived) context.pop();
              },
            ),
            SheetOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.danger,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool sure = await showConfirmDialog(
                  context,
                  title: 'Delete habit?',
                  message: 'This permanently deletes "${habit.title}" with its '
                      'history, achievements and notes.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!sure || !context.mounted) return;
                final bool ok = await guarded(
                  context,
                  () => ref.read(appDataProvider.notifier).deleteHabit(habit.id),
                  message: 'Could not delete',
                );
                if (ok && context.mounted) context.pop();
              },
            ),
            const SizedBox(height: AppDimens.gapSm),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: color.withAlpha(60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- timeline

class _TimelineEvent {
  const _TimelineEvent({
    required this.date,
    required this.icon,
    required this.label,
    this.noteId,
  });

  final DateTime date;
  final IconData icon;
  final String label;
  final String? noteId;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.habit, required this.data});

  final Habit habit;
  final AppData data;

  List<_TimelineEvent> _events() {
    final List<_TimelineEvent> events = <_TimelineEvent>[
      _TimelineEvent(
        date: dateOnly(habit.createdAt),
        icon: Icons.flag_rounded,
        label: 'Task Started',
      ),
    ];
    if (habit.showStreaksOnTimeline) {
      data.achievementsFor(habit.id).forEach((int milestone, String key) {
        final DateTime? d = parseDateKey(key);
        if (d != null) {
          events.add(
            _TimelineEvent(
              date: d,
              icon: Icons.local_fire_department_rounded,
              label: '${daysLabel(milestone)} streak',
            ),
          );
        }
      });
    }
    for (final Note n in data.notes.where((Note n) => n.habitId == habit.id)) {
      final String firstLine = n.body.trim().split('\n').first;
      final String text = n.title.trim().isNotEmpty ? n.title.trim() : firstLine;
      events.add(
        _TimelineEvent(
          date: dateOnly(n.createdAt),
          icon: Icons.sticky_note_2_outlined,
          label: text.isEmpty ? 'Note' : 'Note: $text',
          noteId: n.id,
        ),
      );
    }
    events.sort((_TimelineEvent a, _TimelineEvent b) => b.date.compareTo(a.date));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final List<_TimelineEvent> events = _events();
    final List<Widget> children = <Widget>[];
    String? currentMonth;
    for (final _TimelineEvent e in events) {
      final String month = monthYear(e.date);
      if (month != currentMonth) {
        currentMonth = month;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Center(
              child: Text(
                month,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: habit.color, width: 2),
                ),
                child: Icon(habit.icon, size: 20, color: habit.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: e.noteId == null
                      ? null
                      : () => context.push(AppRoutes.noteEdit(e.noteId!)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(e.icon, size: 18, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${e.date.day} ${monthShort(e.date)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: children);
  }
}
