import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/format.dart';
import '../../shared/utils/habit_ui.dart';
import '../../state/preferences_state.dart';
import 'day_actions.dart';
import 'habit_heatmap.dart';

/// One habit on the dashboard: icon, title, streak, note and completion
/// buttons, and the progress grid.
class HabitCard extends ConsumerWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.date,
    required this.engine,
    required this.stats,
    required this.records,
  });

  final Habit habit;

  /// The day selected in the date strip; the buttons act on this day.
  final DateTime date;
  final HabitEngine engine;
  final HabitStats stats;
  final Map<String, CompletionRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color = habit.color;
    final bool compact = ref.watch(compactLayoutProvider);
    final CompletionRecord? record = records[dateKey(date)];
    final bool quit = habit.type == HabitType.quit;
    final bool slipped = quit && engine.isSlipped(habit, record);
    final double progress = engine.dayProgress(habit, record);
    final bool complete = quit ? !slipped : engine.isCompleted(habit, record);

    final List<String> subtitle = <String>[
      'Streak: ${daysLabel(stats.currentStreak)}',
    ];
    if (habit.tracking == TrackingMethod.count) {
      subtitle.add(countLabel(habit, record?.count ?? 0));
    } else if (habit.tracking == TrackingMethod.checklist &&
        habit.checklist.isNotEmpty) {
      final int ticked = habit.checklist
          .where((ChecklistItem i) =>
              record?.checkedItemIds.contains(i.id) ?? false)
          .length;
      subtitle.add('$ticked/${habit.checklist.length}');
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(AppRoutes.habitDetail(habit.id)),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(habit.icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SquareButton(
                    tooltip: 'Add note',
                    onTap: () =>
                        context.push(AppRoutes.noteNew(habitId: habit.id)),
                    child: const Icon(
                      Icons.note_add_outlined,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CheckButton(
                    habit: habit,
                    color: color,
                    progress: progress,
                    complete: complete,
                    slipped: slipped,
                    onTap: () => tapDay(context, ref, habit, date),
                    onLongPress: () => longPressDay(context, ref, habit, date),
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 12),
              HabitHeatmap(habit: habit, engine: engine, records: records),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.habit,
    required this.color,
    required this.progress,
    required this.complete,
    required this.slipped,
    required this.onTap,
    required this.onLongPress,
  });

  final Habit habit;
  final Color color;
  final double progress;
  final bool complete;
  final bool slipped;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool quit = habit.type == HabitType.quit;
    final bool showRing = !quit &&
        habit.tracking != TrackingMethod.tick &&
        !complete &&
        progress > 0;

    Color background = AppColors.surfaceRaised;
    Color iconColor = AppColors.textPrimary;
    IconData icon = Icons.check_rounded;
    if (slipped) {
      background = AppColors.danger;
      iconColor = Colors.white;
      icon = Icons.close_rounded;
    } else if (complete) {
      background = color;
      iconColor = Colors.black;
    }

    return Semantics(
      button: true,
      label: quit ? 'Mark slip' : 'Mark done',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (showRing)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    color: color,
                    backgroundColor: AppColors.border,
                  ),
                ),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
