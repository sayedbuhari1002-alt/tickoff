import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/logic/habit_engine.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/utils/share_text.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';

/// Builds a progress summary from the real data and copies it to the
/// clipboard. (The Android share sheet needs the share_plus plugin, which is
/// planned for Stage 4; copying works fully offline today.)
class ShareProgressScreen extends ConsumerWidget {
  const ShareProgressScreen({super.key, this.habitId});

  final String? habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppData? data = ref.watch(appDataProvider).valueOrNull;
    final DateTime today = ref.watch(todayProvider);
    final Map<String, HabitStats> stats = ref.watch(habitStatsProvider);
    final double score = ref.watch(overallScoreProvider);

    String? text;
    if (data != null) {
      final Habit? habit = habitId == null ? null : data.habitById(habitId!);
      text = habit != null
          ? habitProgressText(
              habit: habit,
              stats: stats[habit.id] ?? HabitStats.empty,
              today: today,
            )
          : overallProgressText(
              data: data,
              stats: stats,
              overallScorePercent: score,
              today: today,
            );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Share Progress')),
      body: text == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              children: <Widget>[
                SectionCard(child: SelectableText(text)),
                const SizedBox(height: AppDimens.gap),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy summary'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text!));
                    if (context.mounted) {
                      showMessage(context, 'Progress summary copied.');
                    }
                  },
                ),
              ],
            ),
    );
  }
}
