# Stage 4 implementation candidate — change summary

## Added
- Task model, SQLite-backed task service/state, task navigation tab, task form/list, ordered subtasks, priorities, category, icon, colour, deadline date/time, reminders, text/photo/audio notes, pause/resume, postpone, repeat, duplicate, and delete actions.
- Main-dashboard task summary integrating manual tasks with incomplete habit-generated items. Completing a habit-generated item calls the existing habit completion actions, and the task representation is derived from the same stored habit completion record.
- Monthly date picker that displays tasks and scheduled habits for a selected date.
- Local notification scheduler for one-off task reminders and weekday/time habit reminders.
- Local photo/audio attachment helper, including private-file copies, recording, and playback.
- Task analytics engine and tests for completion ratios, weighted priority score, empty days, and 30-day range.
- Habit streak-history chart in addition to the existing habit analytics.
- Functional local settings screens for theme, compact layout, dashboard section visibility, general preferences, and habit reordering.
- Expanded habit colour palette and task colour/icon selection.

## Changed
- SQLite schema version is 3; v1→v2 creates tasks, and v2→v3 adds completion timestamps and task-history snapshots without dropping habit tables. Manual deletion preserves a minimal task snapshot for the 30-day analytics window; expired snapshots are then purged.
- Task deadline values preserve optional time while old date-only records remain parseable. Retention queries compare the date prefix.
- Count habits can decrement by the configured step, edit an exact count, reset today's count with confirmation, and exceed the goal while never going below zero.
- Habit Due filtering excludes completed Build habits and treats a slip-free Quit habit day as complete.
- Habit analytics start at the habit's creation date instead of pulling the start date earlier from stale records.
- Android scaffold script adds notification/camera/microphone permissions, sets minSdk 23, and configures core-library desugaring for notification plugins.

## CI log follow-up fixes
- Escaped apostrophes in the count-reset confirmation strings so the habit detail source parses.
- Imported the `Tally` definition into the streak-history chart.
- Imported the `HabitUi` extension used by the settings reorder list.
- Updated Android scaffold preparation to add `desugar_jdk_libs` even when the generated Flutter Kotlin Gradle template has no existing `dependencies` block.
- Changed the GitHub Actions formatting step to run `dart format .` before analysis, tests, and the APK build.

## Important verification gaps
- Flutter/Dart SDK was unavailable in the editing environment, so `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk` could not be run.
- The latest supplied GitHub Actions log reported 97 passing tests and five widget-test files that failed to load because of shared source compilation errors. This revision patches the logged causes, but the workflow has not yet been rerun to verify the fix.
- A native Android launcher home-screen widget is not implemented; the Widgets settings screen currently configures in-app dashboard sections.
- Task/ habit synchronization has been implemented through shared habit completion state for the dashboard/task actions, but still requires full integration tests on GitHub Actions and a real device.

This ZIP is a development candidate, not a verified release APK source. Do not overwrite the working project until GitHub Actions and device checks pass.
