import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';
import 'dashboard_providers.dart';
import 'habit_card.dart';
import 'today_tasks_panel.dart';

/// Dashboard: date heading, weekly date strip, category chips, All/Due filter,
/// habit score and the habit cards, all driven by the SQLite data.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = ref.watch(todayProvider);
    final DateTime selected = ref.watch(selectedDateProvider);
    final AsyncValue<AppData> async = ref.watch(appDataProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.gapSm,
                AppDimens.gapSm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${headerPrefix(selected, today)}, ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: dayMonthLabel(selected),
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share progress',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => context.push(AppRoutes.shareProgress),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gap),
            if (ref.watch(showDashboardCalendarProvider)) DateStrip(
              today: today,
              selected: selected,
              onSelected: (DateTime day) =>
                  ref.read(selectedDateProvider.notifier).select(day),
            ),
            const SizedBox(height: AppDimens.gap),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your habits',
                  message: '$error',
                ),
                data: (AppData data) => _DashboardBody(
                  data: data,
                  selected: selected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data, required this.selected});

  final AppData data;
  final DateTime selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HabitEngine engine = ref.watch(habitEngineProvider);
    final Map<String, HabitStats> stats = ref.watch(habitStatsProvider);
    final HabitListFilter filter = ref.watch(habitFilterProvider);
    final String? chosenCategory = ref.watch(selectedCategoryProvider);
    final double score = ref.watch(overallScoreProvider);

    final List<HabitCategory> categories = data.sortedCategories;
    final String? categoryId =
        categories.any((HabitCategory c) => c.id == chosenCategory)
            ? chosenCategory
            : null;

    final List<Habit> inCategory = data.activeHabits
        .where((Habit h) => categoryId == null || h.categoryId == categoryId)
        .toList();
    final List<Habit> due = inCategory
        .where((Habit h) => engine.isDueOn(h, selected, data.recordsFor(h.id)))
        .toList();
    final List<Habit> shown = filter == HabitListFilter.due ? due : inCategory;

    Widget list;
    if (data.activeHabits.isEmpty) {
      list = const EmptyState(
        icon: Icons.checklist_rounded,
        title: 'No habits yet',
        message: 'Tap + to add your first habit.',
      );
    } else if (shown.isEmpty) {
      list = EmptyState(
        icon: Icons.event_available_rounded,
        title: filter == HabitListFilter.due
            ? 'Nothing due on this day'
            : 'No habits in this category',
        message: filter == HabitListFilter.due
            ? 'Switch to All to see every habit.'
            : 'Pick another category or add a habit.',
      );
    } else {
      list = ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          0,
          AppDimens.pagePadding,
          AppDimens.gapLg,
        ),
        itemCount: shown.length,
        separatorBuilder: (BuildContext _, int index) =>
            const SizedBox(height: AppDimens.gap),
        itemBuilder: (BuildContext context, int index) {
          final Habit h = shown[index];
          return HabitCard(
            key: ValueKey<String>(h.id),
            habit: h,
            date: selected,
            engine: engine,
            stats: stats[h.id] ?? HabitStats.empty,
            records: data.recordsFor(h.id),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TodayTasksPanel(data: data, day: selected),
        const _SectionLabel('Categories'),
        const SizedBox(height: AppDimens.gapSm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Row(
            children: <Widget>[
              TickChip(
                label: 'All',
                icon: Icons.grid_view_rounded,
                selected: categoryId == null,
                onTap: () =>
                    ref.read(selectedCategoryProvider.notifier).select(null),
              ),
              for (final HabitCategory c in categories) ...<Widget>[
                const SizedBox(width: AppDimens.gapSm),
                TickChip(
                  label: c.name,
                  icon: Icons.label_outline_rounded,
                  selected: categoryId == c.id,
                  onTap: () =>
                      ref.read(selectedCategoryProvider.notifier).select(c.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapLg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Row(
            children: <Widget>[
              const Expanded(child: _SectionLabel('Filter', padded: false)),
              if (ref.watch(showDashboardScoreProvider)) const Text(
                'Habit Score',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapSm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: Row(
            children: <Widget>[
              TickChip(
                label: 'All (${inCategory.length})',
                selected: filter == HabitListFilter.all,
                onTap: () => ref
                    .read(habitFilterProvider.notifier)
                    .select(HabitListFilter.all),
              ),
              const SizedBox(width: AppDimens.gapSm),
              TickChip(
                label: 'Due (${due.length})',
                selected: filter == HabitListFilter.due,
                filledWhenSelected: true,
                onTap: () => ref
                    .read(habitFilterProvider.notifier)
                    .select(HabitListFilter.due),
              ),
              const Spacer(),
              if (ref.watch(showDashboardScoreProvider)) _ScorePill(
                score: score,
                onTap: () => context.push(AppRoutes.analytics),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gap),
        Expanded(child: list),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.padded = true});

  final String text;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final Widget label = Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
    if (!padded) return label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: label,
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.onTap});

  final double score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Habit score, open analytics',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.speed_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
