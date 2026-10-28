# Changes from Stage 1 to Stages 2+3

Added: 39, modified: 16, moved: 2, removed: 1, unchanged: 30

## Removed
- test/widget_test.dart

## Moved (content unchanged)
- test/date_utils_test.dart  ->  test/unit/date_utils_test.dart
- test/models_test.dart  ->  test/unit/models_test.dart

## Modified
- .github/workflows/build_apk.yml
- README.md
- lib/app.dart
- lib/core/router/app_router.dart
- lib/core/router/routes.dart
- lib/core/utils/date_utils.dart
- lib/domain/models/completion_record.dart
- lib/features/analytics/analytics_screen.dart
- lib/features/dashboard/dashboard_providers.dart
- lib/features/dashboard/dashboard_screen.dart
- lib/features/habit_detail/habit_detail_screen.dart
- lib/features/habit_form/habit_form_screen.dart
- lib/features/notes/notes_screen.dart
- lib/main.dart
- lib/shared/widgets/widgets.dart
- pubspec.yaml

## Added
- lib/core/icons/habit_icons.dart
- lib/data/database/app_database.dart
- lib/data/repositories/app_repository.dart
- lib/data/repositories/sqlite_app_repository.dart
- lib/domain/logic/achievements.dart
- lib/domain/logic/analytics_engine.dart
- lib/domain/logic/habit_engine.dart
- lib/features/analytics/trend_chart.dart
- lib/features/dashboard/day_actions.dart
- lib/features/dashboard/habit_card.dart
- lib/features/dashboard/habit_heatmap.dart
- lib/features/habit_detail/habit_sheets.dart
- lib/features/habit_form/category_picker.dart
- lib/features/habit_form/checklist_dialog.dart
- lib/features/habit_form/icon_picker_sheet.dart
- lib/features/notes/note_editor_screen.dart
- lib/features/settings/archive_screen.dart
- lib/features/settings/categories_screen.dart
- lib/features/share/share_progress_screen.dart
- lib/shared/utils/format.dart
- lib/shared/utils/guarded.dart
- lib/shared/utils/habit_ui.dart
- lib/shared/utils/share_text.dart
- lib/shared/widgets/month_calendar.dart
- lib/shared/widgets/weekday_chips.dart
- lib/state/app_data.dart
- lib/state/app_state.dart
- test/data/sqlite_repository_test.dart
- test/support/in_memory_repository.dart
- test/support/test_helpers.dart
- test/unit/achievements_test.dart
- test/unit/analytics_engine_test.dart
- test/unit/app_state_test.dart
- test/unit/habit_engine_test.dart
- test/widget/analytics_test.dart
- test/widget/dashboard_test.dart
- test/widget/habit_detail_test.dart
- test/widget/habit_form_test.dart
- test/widget/settings_notes_test.dart

## Unchanged
- .gitignore
- analysis_options.yaml
- lib/core/theme/app_colors.dart
- lib/core/theme/app_dimens.dart
- lib/core/theme/app_theme.dart
- lib/core/utils/ids.dart
- lib/domain/models/checklist_item.dart
- lib/domain/models/enums.dart
- lib/domain/models/habit.dart
- lib/domain/models/habit_category.dart
- lib/domain/models/models.dart
- lib/domain/models/note.dart
- lib/domain/models/reminder.dart
- lib/domain/models/schedule.dart
- lib/features/settings/settings_screen.dart
- lib/features/shell/app_shell.dart
- lib/shared/widgets/color_palette.dart
- lib/shared/widgets/confirm_dialog.dart
- lib/shared/widgets/date_strip.dart
- lib/shared/widgets/empty_state.dart
- lib/shared/widgets/pill_selector.dart
- lib/shared/widgets/section_card.dart
- lib/shared/widgets/stage_placeholder.dart
- lib/shared/widgets/stat_tile.dart
- lib/shared/widgets/switch_row.dart
- lib/shared/widgets/tick_chip.dart
- lib/shared/widgets/tick_sheet.dart
- lib/shared/widgets/tick_text_field.dart
- lib/shared/widgets/tickoff_bottom_bar.dart
- tool/prepare_android.sh
