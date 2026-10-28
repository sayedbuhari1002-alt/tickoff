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

## Important verification gaps
- Flutter/Dart SDK was unavailable in the editing environment, so `dart format`, `flutter analyze`, `flutter test`, and `flutter build apk` could not be run.
- The 13 previously failing Stage 2+3 tests could not be diagnosed because the original failure logs were not provided and the Flutter test runner is unavailable here.
- A native Android launcher home-screen widget is not implemented; the Widgets settings screen currently configures in-app dashboard sections.
- Task/ habit synchronization has been implemented through shared habit completion state for the dashboard/task actions, but still requires full integration tests on GitHub Actions and a real device.

This ZIP is a development candidate, not a verified release APK source. Do not overwrite the working project until GitHub Actions and device checks pass.


## Stage 5 enhancement pass (latest)

- Separated the Dashboard and Habits destination; added a unified Add Task/Add Habit launcher choice without replacing existing navigation icons.
- Added full-screen task creation/editing and Task Details/Task Progress pages. The task row tap no longer opens the editor.
- Added composable task priority/category filters, four sort modes, selectable date browsing, status labels and reminder-aware visibility.
- Added a full-screen ordered subtask editor with individual deadlines, reorder/edit/remove and inherited parent priority. Parent date changes no longer shift child deadlines.
- Reworked task analytics into selectable day/week/month/30-day/90-day/year/custom ranges with actual-day completion events, trend visualization, detailed completion statuses and subtask contributions.
- Advanced SQLite schema to v6 using additive migration steps; completion/reopen/schedule snapshots and deleted child snapshots are retained for analytics, and records are pruned after roughly 400 days.
- Validation performed: source delimiters and relative imports, YAML parse, and Android prep shell syntax. Flutter format/analyze/tests/build and device validation remain unrun because Flutter/Dart is not available in this environment.
