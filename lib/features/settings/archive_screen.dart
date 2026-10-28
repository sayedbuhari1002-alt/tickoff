import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/utils/habit_ui.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';

/// Archived habits: restore them or delete them for good.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppData? data = ref.watch(appDataProvider).valueOrNull;
    final List<Habit> archived = data?.archivedHabits ?? const <Habit>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : archived.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing archived',
                  message: 'Archived habits keep their history and can be '
                      'restored at any time.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  children: <Widget>[
                    for (final Habit h in archived)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                        child: SectionCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(h.icon, color: h.color),
                            title: Text(h.title),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Restore',
                                  icon: const Icon(Icons.unarchive_outlined),
                                  onPressed: () => guarded(
                                    context,
                                    () => ref
                                        .read(appDataProvider.notifier)
                                        .setArchived(h.id, false),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                  ),
                                  onPressed: () async {
                                    final bool sure = await showConfirmDialog(
                                      context,
                                      title: 'Delete habit?',
                                      message: 'This permanently deletes '
                                          '"${h.title}" with its history, '
                                          'achievements and notes.',
                                      confirmLabel: 'Delete',
                                      destructive: true,
                                    );
                                    if (!sure || !context.mounted) return;
                                    await guarded(
                                      context,
                                      () => ref
                                          .read(appDataProvider.notifier)
                                          .deleteHabit(h.id),
                                      message: 'Could not delete',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
