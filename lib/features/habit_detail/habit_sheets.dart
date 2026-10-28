import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/achievements.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/format.dart';
import '../../shared/utils/habit_ui.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../dashboard/day_actions.dart';
import '../dashboard/habit_heatmap.dart';

/// "Habit Info" sheet: type, creation date, schedule and reminder.
Future<void> showHabitInfoSheet(BuildContext context, Habit habit) {
  return showTickSheet<void>(
    context: context,
    title: 'Habit Info',
    builder: (BuildContext sheetContext) {
      final Reminder r = habit.reminder;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          0,
          AppDimens.pagePadding,
          AppDimens.gapLg,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: habit.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(habit.icon, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  habit.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gap),
          SectionCard(
            title: 'Habit Info',
            child: Column(
              children: <Widget>[
                _InfoRow('Type', trackingLabel(habit)),
                _InfoRow(
                  'Habit',
                  habit.type == HabitType.build ? 'Build' : 'Quit',
                ),
                _InfoRow(
                  'Created',
                  '${ordinal(habit.createdAt.day)} ${monthYear(habit.createdAt)}',
                ),
                _InfoRow(
                  'Show Streaks on Timeline',
                  habit.showStreaksOnTimeline ? 'Yes' : 'No',
                ),
                if (habit.description.isNotEmpty)
                  _InfoRow('Description', habit.description),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.gap),
          SectionCard(
            title: 'Schedule',
            child: Column(
              children: <Widget>[
                _InfoRow('Frequency', frequencyLabel(habit)),
                _InfoRow(
                  'Reminder',
                  r.enabled
                      ? '${r.timeLabel}  ${r.weekdays.length == 7 ? 'Everyday' : weekdayList(r.weekdays)}'
                      : 'Off',
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievements sheet: locked/unlocked milestones and progress to the next.
Future<void> showAchievementsSheet(BuildContext context, String habitId) {
  return showTickSheet<void>(
    context: context,
    title: 'Achievements',
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final AppData? data = ref.watch(appDataProvider).valueOrNull;
        final Map<String, HabitStats> stats = ref.watch(habitStatsProvider);
        if (data == null || data.habitById(habitId) == null) {
          return const SizedBox(height: 120);
        }
        final int best = stats[habitId]?.bestStreak ?? 0;
        final AchievementSummary summary = summarizeAchievements(
          bestStreak: best,
          unlockedOn: data.achievementsFor(habitId),
        );
        return AchievementsGrid(summary: summary);
      },
    ),
  );
}

/// Badges plus the progress bar; shared by the sheet and tests.
class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key, required this.summary});

  final AchievementSummary summary;

  @override
  Widget build(BuildContext context) {
    final int? next = summary.nextMilestone;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.gapLg,
      ),
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 16,
          children: <Widget>[
            for (final AchievementStatus s in summary.statuses) _Badge(s),
          ],
        ),
        const SizedBox(height: AppDimens.gapLg),
        Text(
          next == null
              ? 'All achievements unlocked!'
              : 'Best streak ${daysLabel(summary.bestStreak)} - next: ${daysLabel(next)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: summary.progressToNext,
            minHeight: 8,
            color: AppColors.gold,
            backgroundColor: AppColors.surfaceRaised,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.status);

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final bool on = status.unlocked;
    return SizedBox(
      width: 64,
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.gold : AppColors.surfaceRaised,
            ),
            child: on
                ? Text(
                    '${status.milestone}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  )
                : const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            status.milestone == 1 ? '1 day' : '${status.milestone} days',
            style: TextStyle(
              fontSize: 12,
              color: on ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendar sheet: month grid of the habit's history. Tap a day to change it.
Future<void> showHistorySheet(BuildContext context, String habitId) {
  return showTickSheet<void>(
    context: context,
    title: 'History',
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final AppData? data = ref.watch(appDataProvider).valueOrNull;
        final Habit? habit = data?.habitById(habitId);
        if (data == null || habit == null) return const SizedBox(height: 120);
        final HabitEngine engine = ref.watch(habitEngineProvider);
        final Map<String, CompletionRecord> records = data.recordsFor(habitId);
        final DateTime start = engine.startDate(habit, records);

        DayDecoration decorate(DateTime day) {
          switch (heatCellFor(engine, habit, day, records, start)) {
            case HeatCell.done:
            case HeatCell.clean:
              return DayDecoration(fill: habit.color, textColor: Colors.black);
            case HeatCell.slipped:
              return const DayDecoration(
                fill: AppColors.danger,
                textColor: Colors.white,
              );
            case HeatCell.missed:
              return DayDecoration(fill: AppColors.danger.withAlpha(60));
            case HeatCell.empty:
            case HeatCell.hidden:
              return const DayDecoration();
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            0,
            AppDimens.pagePadding,
            AppDimens.gapLg,
          ),
          child: Column(
            children: <Widget>[
              MonthCalendar(
                today: engine.today,
                firstMonth: start,
                decorate: decorate,
                onDayTap: (DateTime day) => tapDay(context, ref, habit, day),
              ),
              const SizedBox(height: 8),
              Text(
                habit.type == HabitType.quit
                    ? 'Tap a day to mark or clear a slip.'
                    : 'Tap a day to change its completion.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
