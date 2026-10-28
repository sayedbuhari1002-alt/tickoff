import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';

/// Notes tab: every note, newest first, saved in the local database.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  const Expanded(
                    child: Text(
                      'Notes',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New note',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => context.push(AppRoutes.noteNew()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load notes',
                  message: '$e',
                ),
                data: (AppData data) {
                  final List<Note> notes = data.sortedNotes;
                  if (notes.isEmpty) {
                    return const EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      title: 'No notes yet',
                      message: 'Notes you add to a habit will appear here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.pagePadding),
                    itemCount: notes.length,
                    separatorBuilder: (BuildContext _, int index) =>
                        const SizedBox(height: AppDimens.gapSm),
                    itemBuilder: (BuildContext context, int i) {
                      final Note n = notes[i];
                      final Habit? habit =
                          n.habitId == null ? null : data.habitById(n.habitId!);
                      final String title = n.title.trim().isNotEmpty
                          ? n.title.trim()
                          : n.body.trim().split('\n').first;
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push(AppRoutes.noteEdit(n.id)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  title.isEmpty ? 'Untitled note' : title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dayMonthLabel(n.updatedAt)} ${n.updatedAt.year}'
                                  '${habit == null ? '' : '  ·  ${habit.title}'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
