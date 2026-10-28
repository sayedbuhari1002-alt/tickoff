import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../shared/widgets/date_strip.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/app_data.dart';
import '../../state/preferences_state.dart';
import 'dashboard_providers.dart';
import 'today_tasks_panel.dart';

/// Dashboard prioritises the selected day's tasks and a separate habit summary.
/// Habit categories and habit-list filters are located in the Habits tab.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = ref.watch(todayProvider);
    final DateTime selected = ref.watch(selectedDateProvider);
    final AsyncValue<AppData> async = ref.watch(appDataProvider);
    return Scaffold(
      body: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Padding(padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, AppDimens.gapSm, AppDimens.gapSm, 0), child: Row(children: <Widget>[
          Expanded(child: Text.rich(TextSpan(children: <InlineSpan>[
            TextSpan(text: '${headerPrefix(selected, today)}, ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: dayMonthLabel(selected), style: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFE0E0E0))),
          ]), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, color: AppColors.textPrimary))),
          IconButton(tooltip: 'Task analytics', icon: const Icon(Icons.insights_outlined), onPressed: () => context.push(AppRoutes.taskAnalytics)),
          IconButton(tooltip: 'Share progress', icon: const Icon(Icons.share_outlined), onPressed: () => context.push(AppRoutes.shareProgress)),
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push(AppRoutes.settings)),
        ])),
        const SizedBox(height: AppDimens.gap),
        if (ref.watch(showDashboardCalendarProvider)) DateStrip(today: today, selected: selected, onSelected: (DateTime day) => ref.read(selectedDateProvider.notifier).select(day)),
        const SizedBox(height: AppDimens.gap),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load your data', message: '$error'),
          data: (AppData data) => ListView(padding: const EdgeInsets.only(bottom: 20), children: <Widget>[
            TodayTasksPanel(key: const ValueKey<String>('dashboard-today-overview'), data: data, day: selected),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: <Widget>[
              Expanded(child: _shortcut(context, icon: Icons.checklist_rounded, title: 'Habits', detail: '${data.activeHabits.length} active habits', onTap: () => context.go(AppRoutes.habits))),
              const SizedBox(width: 10),
              Expanded(child: _shortcut(context, icon: Icons.bar_chart_rounded, title: 'Habit analytics', detail: 'Streaks and trends', onTap: () => context.push(AppRoutes.analytics))),
            ])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _shortcut(context, icon: Icons.sticky_note_2_outlined, title: 'Notes', detail: 'Personal notes and reflections', onTap: () => context.go(AppRoutes.notes))),
          ]),
        )),
      ])),
    );
  }

  Widget _shortcut(BuildContext context, {required IconData icon, required String title, required String detail, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: <Widget>[
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.gold.withAlpha(35), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.gold)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
      const Icon(Icons.chevron_right, size: 18),
    ])),
  );
}
