import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart';
import '../../state/app_state.dart';

/// The day shown on the dashboard (defaults to today and follows it when the
/// date rolls over).
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => ref.watch(todayProvider);

  void select(DateTime day) => state = dateOnly(day);
}

final NotifierProvider<SelectedDateNotifier, DateTime> selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// All / Due filter on the dashboard list.
enum HabitListFilter { all, due }

class HabitFilterNotifier extends Notifier<HabitListFilter> {
  @override
  HabitListFilter build() => HabitListFilter.due;

  void select(HabitListFilter filter) => state = filter;
}

final NotifierProvider<HabitFilterNotifier, HabitListFilter>
    habitFilterProvider =
    NotifierProvider<HabitFilterNotifier, HabitListFilter>(
  HabitFilterNotifier.new,
);

/// Selected category id; null means "All".
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? categoryId) => state = categoryId;
}

final NotifierProvider<SelectedCategoryNotifier, String?>
    selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
  SelectedCategoryNotifier.new,
);
