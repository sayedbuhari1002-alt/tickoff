# TickOff Replacement — Stage 5 enhancement candidate

Offline-first Flutter habit and task tracker based on the supplied TickOff
screenshots. Data stays on the device in SQLite. There is no login, ads,
subscription, cloud backup, sync or Firebase. All features are intended to be
available without a paywall.

**Verification status:** Stage 5 source changes are implemented, but this ZIP
is not a verified release. Flutter/Dart are unavailable in the editing
container, so formatting, static analysis, unit/widget/database tests, APK
compilation and device testing were not run here. The static checks and exact
limitations are listed at the end of this file. Use a separate Git branch and
review its GitHub Actions run before replacing your working version.

## Build the APK with GitHub (no local Flutter install)

1. Unzip this project and upload its contents to a **separate branch** of your
   existing repository (do not merge it into `main` automatically).
2. Commit and push the branch. The **Build Android APK** workflow is configured
   to run on pushes to any branch, or you can use **Run workflow** in Actions.
3. Inspect formatting, analysis, test and release-build steps. A failed test
   causes the workflow to end red even if APK compilation succeeded.
4. If the workflow succeeds, download the **tickoff-apk** artifact and install
   the APK on your phone. Test it before deciding whether to merge the branch.

The uploaded ZIP is the Dart/Flutter **source project**, not an APK. The
workflow creates the Android scaffold if needed, gets dependencies, runs the
checks and builds the release APK in GitHub Actions.

## Current feature map

- **Dashboard:** selected-day date strip, today's tasks and overdue tasks,
  scheduled habits, and separate task/habit completion percentages. Habit
  categories and All/Due filters are in the dedicated Habits destination.
- **Habits:** existing Add/Edit Habit flow, habit cards, category and Due
  filters, detail screen, streaks, score, analytics, progress/calendar views,
  achievements, notes, archive and local settings. The existing Habit Details
  layout and its Progress/Edit/Delete menu are preserved.
- **Unified add control:** the centre `+` opens Add Habit or Add Task. Habit
  creation keeps the existing full-screen form; Add/Edit Task is full-screen.
- **Tasks:** All Tasks, Today, Due Tasks, selected-date browsing, combined
  priority/category filters, deadline/priority/category sorts, overdue status,
  pause/resume, postpone, repeat, duplicate and delete.
- **Task Details:** tapping a task opens a detail page with status, schedule,
  priority/category, description, independent subtasks, notes, photo/audio
  attachments, history and Progress/Edit/Delete actions.
- **Subtasks:** ordered add/edit/reorder/remove workflow, inherited priority,
  per-subtask deadline/date/time, checklist progress and automatic parent
  completion-state synchronisation. Child deadlines are not shifted when the
  parent deadline is edited or postponed.
- **Task analytics:** day, week, month, 30-day, 90-day, one-year and custom
  ranges; completion bars and trend, on-time/late comparison, weighted score,
  streaks and day-level drill-down. Immutable activity snapshots allow late
  completion to be attributed to its actual completion day.
- **Local features:** SQLite storage/migrations, task and habit reminders,
  text/photo/audio notes, theme and layout settings. No native Android launcher
  widget is included; the Widgets setting controls in-app dashboard sections.

## Rules and formulas

All of this lives in `lib/domain/logic/habit_engine.dart` and is used by every
screen.

**Day outcome** (per habit and calendar day, from the habit's *start day*, its
creation day or the earliest day that has a record, up to today):

| Habit | Outcome |
|---|---|
| Build, due day, completed | success |
| Build, due day, not completed, before today | failure |
| Build, due day, not completed, today | pending (does not break or extend) |
| Build, day not due | not scheduled (ignored) |
| Quit (always everyday), no slip | success (today counts as clean so far) |
| Quit, slip recorded | failure |

**Completion by tracking method**

* Tick: the day is ticked.
* Count: count >= daily goal; with no goal, any count above zero.
* Checklist: every item is ticked (a checklist with no items is never done).
* Quit + Tick: the day is marked as a slip. Quit + Count: a slip when
  count > daily limit (limit defaults to 0). Quit + Checklist: a slip when any
  item is marked.

**Current / best streak (regular schedules)**: walk the days from the start
to today, with a counter: success -> +1, failure -> reset to 0, anything else
(not scheduled, pending) -> unchanged. Best = the highest value the counter
reached; current = its value after today. Unscheduled days therefore never
break a streak. A completion on a day that is not due is recorded but does not
add to the streak, rates, or score.

**Some days per period** (e.g. 3 days per week; weeks start Monday, months are
calendar months): a period succeeds with at least N completed days. The streak
is the number of completed days inside consecutive successful periods; the
running period neither breaks nor ends the streak (its completed days so far
count); a first, partial period is never penalised; a failed period resets the
streak to 0.

**Habit score** (0-100%): over the last 30 days (or since the habit started if
shorter), `completed due days / due days`. Today counts only once completed
(Build) or as clean (Quit). For "some days per period" habits each day expects
`N / period length` of a completion. **Overall Habit Score** (dashboard pill)
= average score of active habits that have at least one due day; 0.0% when
there is no data.

**Completion rate** (analytics) = completed / due over the selected date range,
capped at 100%. "Completions" = completed units in the range.

**Achievements**: milestone reached when the *best streak* >= milestone.
Unlock dates are stored in SQLite the first time they are reached, and are
kept even if history is edited later.

## Data and storage

SQLite uses `sqflite` in `lib/data/`; the current schema version is **6**.
Existing habit tables and task records are retained with additive migrations:

- **v1:** `habits`, `categories`, `completions`, `notes`, `achievements`.
- **v2:** `tasks` plus due-date and parent/subtask indexes.
- **v3:** task `completed_at` plus `task_history` deletion snapshots.
- **v4:** immutable `task_activity` snapshots and best-available backfill for
  legacy task creation/completion dates.
- **v5:** richer task deletion snapshots, including title, parent and category.
- **v6:** reminder and pause state on activity snapshots.

Migrations do not drop or reset existing task or habit tables. Task activity
and deletion snapshots are retained for approximately 400 days to cover the
one-year analytics range with a small margin. Active tasks are removed after
the 30-day deadline retention window when the task service next runs; deletion
snapshots keep prior analytics from immediately disappearing.

## Validation and known limitations

Checks completed in the editing container:

- Dart source delimiter scan and relative-import existence scan across all 102
  Dart source/test files.
- YAML parsing of `pubspec.yaml`.
- `bash -n tool/prepare_android.sh`.

Checks **not run** because the Flutter/Dart SDK is not installed and external
network access was unavailable:

- `dart format .`
- `flutter analyze`
- `flutter test test/unit test/widget` and `flutter test test/data`
- `flutter build apk --release --no-tree-shake-icons`
- Real-device tests or visual comparisons.

The GitHub Actions workflow runs the unavailable checks when this branch is
pushed. The native Android launcher/home-screen widget is not implemented;
Widgets settings only toggle in-app dashboard sections. Notification and media
behaviour still requires Android permission/device verification. The release
APK uses the generated Android project's default debug signing setup and is
not configured for Play Store publication.

## Stage 4 implementation pass (in progress)

- Added SQLite schema migration v2 and a local task table with task metadata, priority, due date, colour/icon fields, reminder metadata, text/photo/audio path fields, and parent-task relationships.
- Added a Tasks bottom-navigation destination with task creation/editing, priorities, categories, colour selection, subtasks, completion, pause/resume, duplicate, delete, date picker, and a 30-day completion chart.
- Added task data service/state backed by the existing SQLite database.
- Corrected the habit Due-filter engine to exclude habits already completed for the selected date.
- This pass has not yet completed production notification scheduling, native photo/audio capture and playback, full task/habit two-way synchronisation, all settings screens, or comprehensive automated validation. Review and test these before treating Stage 4 as complete.

## Stage 4 implementation candidate

This branch adds a local task manager alongside the original habit tracker. It retains the existing SQLite habit tables, adds the `tasks` table through the v1-to-v2 migration, and adds completion timestamps plus a 30-day task-history snapshot table in v3.

### Tasks
- Standalone tasks and parent tasks with ordered subtasks. The daily list presents the first incomplete subtask as the active step.
- Priorities, deadlines with optional time, category, icon, colour, text notes, local photo/audio attachments, optional reminder, pause/resume, postpone, repeat, duplicate, and delete actions.
- Overdue tasks remain visible and receive a sorting boost. Paused tasks remain accessible in All Tasks and are excluded from Due Tasks and completion analytics.
- The monthly date picker shows tasks and scheduled habits for the selected date.
- A compact combined task/habit panel is included on the main dashboard. Habit-generated items use the existing completion records rather than a separate task completion record.
- Tasks are removed after the 30-day deadline retention window when the task service next runs. Stage 5 supersedes the earlier parent-postpone behavior: child deadlines and reminders remain independent when the parent is postponed. Manual deletion removes the task immediately.

### Reminders and notes
- Task reminders use local Android notifications. Habit reminders are restored from the existing reminder settings and scheduled by selected weekday/time.
- Photo notes use the camera/gallery picker and copy files into app-private documents. Audio notes use the microphone recorder and local playback. Attachment paths are stored with their parent note/task.
- Notification and media operations can still be affected by Android permissions, device battery restrictions, and plugin/platform behaviour.

### Analytics and settings
- Task analytics shows a rolling 30-day completion bar chart, simple completion counts/percentage, and a priority-weighted score out of 10.
- Habit analytics retains its existing completion-rate chart and adds a running streak-history chart.
- Theme, compact layout, dashboard section visibility, general preferences, and habit rearrangement have local settings screens.
- The Widgets settings currently controls in-app dashboard sections. A native Android launcher home-screen widget is not included in this candidate.

### Validation status
This project was edited in an environment without the Flutter/Dart SDK and without network access to install it. A source delimiter scan, relative-import existence scan, YAML parsing, and shell syntax check were performed. Flutter formatting, static analysis, the complete Flutter test suite, Android APK compilation, and real-device verification have **not** been run here. Use the GitHub Actions workflow to perform those checks before installing this candidate as an upgrade. Treat any compile/test failures as unresolved until their logs are reviewed.


## Stage 5 enhancement pass (newest changes in this ZIP)

- Added a dedicated Habits bottom-navigation section. The Dashboard now focuses on the selected day and displays task progress and habit progress separately.
- The single centre add control opens **Add Habit** or **Add Task**. Add Task and Edit Task are full-screen forms; tapping a task opens a full-screen Task Details page with Progress, Edit and Delete actions.
- Added combined priority/category filtering, deadline/priority/category sorting, reminder-aware Today/Due visibility, date browsing, and larger Today-list text with explicit status.
- Added a full-screen ordered Subtask Editor with add/edit/reorder/remove and independent stored deadlines. Parent deadline/postpone changes do not rewrite child deadlines.
- Expanded task analytics to day, week, month, 30-day, 90-day, one-year and custom ranges; daily bar/trend visualisations; on-time/late comparisons; weighted scores; streaks; and day-level drill-down.
- SQLite schema version 6 adds immutable task activity snapshots, preserves deleted subtask snapshots, backfills best-available activity for Stage 4 data, and keeps analytics records for approximately 400 days. It uses additive migrations and does not drop existing habit/task tables.
- Task visibility follows reminder dates: a task with a reminder appears starting on its reminder date, remains visible through its deadline, and remains overdue after its deadline until completed. Tasks without reminders continue to appear from their deadline.

### Validation status for this enhancement pass

The uploaded project was edited in an environment without Flutter/Dart installed and with network access unavailable. Relative-import and delimiter scans passed across 102 Dart source/test files; `pubspec.yaml` parsing and `bash -n tool/prepare_android.sh` passed. `dart format`, `flutter analyze`, `flutter test`, `flutter build apk`, and real-device validation **were not run**. Push the ZIP contents to a separate branch and inspect GitHub Actions before replacing your working branch. This is source code, not a verified APK build.
