import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/ids.dart';
import '../../domain/models/models.dart';
import '../../shared/utils/guarded.dart';
import '../../shared/widgets/widgets.dart';
import '../../state/app_data.dart';
import '../../state/app_state.dart';
import '../habit_form/category_picker.dart';

/// Create, rename and delete categories. Deleting a category never deletes its
/// habits; they simply become uncategorised.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppData? data = ref.watch(appDataProvider).valueOrNull;
    final List<HabitCategory> categories =
        data?.sortedCategories ?? const <HabitCategory>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final String? name = await showNameDialog(
                context,
                title: 'New category',
                hint: 'Category name',
              );
              if (name == null || !context.mounted) return;
              await guarded(
                context,
                () => ref.read(appDataProvider.notifier).saveCategory(
                      HabitCategory(
                        id: newId(),
                        name: name,
                        sortOrder: categories.length,
                      ),
                    ),
              );
            },
          ),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  message: 'Tap + to create one, then assign it in a habit.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  children: <Widget>[
                    for (final HabitCategory c in categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
                        child: SectionCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.label_outline_rounded),
                            title: Text(c.name),
                            subtitle: Text(
                              '${data.habits.where((Habit h) => h.categoryId == c.id).length} habits',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () async {
                              final String? name = await showNameDialog(
                                context,
                                title: 'Rename category',
                                hint: 'Category name',
                                initial: c.name,
                              );
                              if (name == null || !context.mounted) return;
                              await guarded(
                                context,
                                () => ref
                                    .read(appDataProvider.notifier)
                                    .saveCategory(c.copyWith(name: name)),
                              );
                            },
                            trailing: IconButton(
                              tooltip: 'Delete category',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger,
                              ),
                              onPressed: () async {
                                final bool sure = await showConfirmDialog(
                                  context,
                                  title: 'Delete category?',
                                  message: 'Habits in "${c.name}" are kept '
                                      'and become uncategorised.',
                                  confirmLabel: 'Delete',
                                  destructive: true,
                                );
                                if (!sure || !context.mounted) return;
                                await guarded(
                                  context,
                                  () => ref
                                      .read(appDataProvider.notifier)
                                      .deleteCategory(c.id),
                                  message: 'Could not delete',
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
