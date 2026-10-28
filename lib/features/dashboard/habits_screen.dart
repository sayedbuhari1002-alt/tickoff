import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/date_strip.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/tick_chip.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../../state/preferences_state.dart';
import 'dashboard_providers.dart';
import 'habit_card.dart';

/// Dedicated habit-management destination. Habit filters/categories no longer
/// consume space on the Dashboard.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = ref.watch(todayProvider);
    final DateTime selected = ref.watch(selectedDateProvider);
    final AsyncValue<AppData> async = ref.watch(appDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habits'), actions: <Widget>[
        IconButton(tooltip: 'Habit analytics', onPressed: () => context.push(AppRoutes.analytics), icon: const Icon(Icons.bar_chart_rounded)),
        IconButton(tooltip: 'Categories', onPressed: () => context.push(AppRoutes.categories), icon: const Icon(Icons.label_outline_rounded)),
      ]),
      body: SafeArea(child: Column(children: <Widget>[
        Padding(padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, AppDimens.gapSm, AppDimens.pagePadding, AppDimens.gapSm), child: DateStrip(today: today, selected: selected, onSelected: (DateTime day) => ref.read(selectedDateProvider.notifier).select(day))),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load habits', message: '$error'),
          data: (AppData data) => _HabitList(data: data, selected: selected),
        )),
      ])),
    );
  }
}

class _HabitList extends ConsumerWidget {
  const _HabitList({required this.data, required this.selected});
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
    final String? categoryId = categories.any((HabitCategory c) => c.id == chosenCategory) ? chosenCategory : null;
    final List<Habit> inCategory = data.activeHabits.where((Habit habit) => categoryId == null || habit.categoryId == categoryId).toList();
    final List<Habit> due = inCategory.where((Habit habit) => engine.isDueOn(habit, selected, data.recordsFor(habit.id))).toList();
    final List<Habit> shown = filter == HabitListFilter.due ? due : inCategory;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Padding(padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding), child: Row(children: <Widget>[
        const Expanded(child: Text('Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        if (ref.watch(showDashboardScoreProvider)) Text('Habit score ${score.round()}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ])),
      const SizedBox(height: AppDimens.gapSm),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding), child: Row(children: <Widget>[
        TickChip(label: 'All', icon: Icons.grid_view_rounded, selected: categoryId == null, onTap: () => ref.read(selectedCategoryProvider.notifier).select(null)),
        for (final HabitCategory category in categories) ...<Widget>[
          const SizedBox(width: AppDimens.gapSm),
          TickChip(label: category.name, icon: Icons.label_outline_rounded, selected: categoryId == category.id, onTap: () => ref.read(selectedCategoryProvider.notifier).select(category.id)),
        ],
      ])),
      const SizedBox(height: AppDimens.gap),
      Padding(padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding), child: Row(children: <Widget>[
        TickChip(label: 'All (${inCategory.length})', selected: filter == HabitListFilter.all, onTap: () => ref.read(habitFilterProvider.notifier).select(HabitListFilter.all)),
        const SizedBox(width: AppDimens.gapSm),
        TickChip(label: 'Due (${due.length})', selected: filter == HabitListFilter.due, filledWhenSelected: true, onTap: () => ref.read(habitFilterProvider.notifier).select(HabitListFilter.due)),
      ])),
      const SizedBox(height: AppDimens.gapSm),
      Expanded(child: data.activeHabits.isEmpty
        ? const EmptyState(icon: Icons.checklist_rounded, title: 'No habits yet', message: 'Use + to add your first habit.')
        : shown.isEmpty
          ? EmptyState(icon: Icons.event_available_rounded, title: filter == HabitListFilter.due ? 'Nothing due on this day' : 'No habits in this category', message: 'Choose another filter or category.')
          : ListView.separated(padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0, AppDimens.pagePadding, AppDimens.gapLg), itemCount: shown.length, separatorBuilder: (_, __) => const SizedBox(height: AppDimens.gap), itemBuilder: (BuildContext context, int index) {
              final Habit habit = shown[index];
              return HabitCard(key: ValueKey<String>(habit.id), habit: habit, date: selected, engine: engine, stats: stats[habit.id] ?? HabitStats.empty, records: data.recordsFor(habit.id));
            })),
    ]);
  }
}
