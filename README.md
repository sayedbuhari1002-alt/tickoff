# TickOff Replacement

Offline Android habit tracker modelled on the supplied TickOff screenshots.
All data stays on the device in a SQLite database. There is no login, ads,
subscription, cloud backup or sync. Analytics and achievements are free.

**Status: Stages 1-3 written (foundation, habit management, SQLite storage,
streak engine, analytics, achievements).**
The code has been written and statically sanity-checked, but it has NOT been
compiled, tested or built by the author (no Dart/Flutter toolchain was
available). Treat every claim of "works" as unverified until the GitHub
Actions run is green and you have tried the APK on your phone.

## Build the APK with GitHub (no local install)

1. Open your existing repository on github.com.
2. Replace its files with the contents of this project (see "Updating your
   existing repository" below).
3. Open the **Actions** tab. "Build Android APK" starts on every push to
   `main` (or press **Run workflow**).
4. When it finishes, open the run and download **tickoff-apk** from the
   **Artifacts** section. Unzip it to get `app-release.apk`.
5. Install it on your phone. Android keeps your data when an APK is installed
   over the previous version signed with the same key (all builds here use the
   same debug key), so your Stage 1 install can be updated in place.

The workflow runs the tests but still builds the APK if a test fails, then
marks the run red so you notice. If the *build* step itself fails, open that
step in the log and send me the error.

### Updating your existing repository

Easiest way (browser only):

1. Unzip this project on your computer.
2. In the repository, delete the old `lib/` and `test/` folders: open each
   folder, use the "..." menu -> **Delete directory**, and commit.
3. Click **Add file -> Upload files** and drag in the new `lib`, `test`,
   `tool` and `.github` folders plus `pubspec.yaml`, `analysis_options.yaml`,
   `README.md`, `CHANGES_STAGE2_3.md`, `.gitignore`. (If the browser skips the
   hidden `.github` folder, open `.github/workflows/build_apk.yml` in the
   repository, click the pencil icon and paste in the new contents.)
4. Commit to `main`. Do not delete `android/` if it exists in your repo.

If you uploaded `android/` earlier, leave it. If it does not exist the build
generates it.

## What the app does

* **Dashboard**: weekly date strip (scrolls back 2 years), category chips,
  All / Due filters with live counts, Habit Score pill, habit cards with
  progress grid and completion buttons. Tap a card for details; tap the score
  pill for analytics.
* **Add / Edit Habit**: title, description, colour, searchable icon picker
  (about 120 icons), Build or Quit, frequency (everyday, weekdays, days of the
  month, N days per week/month), tracking (Tick, Count with goal / unit /
  step, Checklist), reminder settings, category, "Show Streaks on Timeline".
* **Habit detail**: status, streaks, score, calendar history (tap a day to
  edit it), achievements, analytics, notes, timeline, options (share, edit,
  archive/restore, delete).
* **Analytics (free)**: per-habit or all habits; 7D / 30D / 90D / 1Y / All
  ranges; stat tiles, completion trend chart, daily/weekly/monthly summaries,
  streak table, calendar heat map.
* **Achievements (free)**: 1, 7, 14, 30, 50, 100, 200, 365 and 730 days.
* **Notes**: create/edit/delete, optionally linked to a habit.
* **Settings**: Categories and Archive are functional. Theme, Layout,
  Widgets, General and Rearrange are placeholders for Stage 4.

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

SQLite via `sqflite` (`lib/data/`). Schema version 1:

* `habits`, `categories`, `completions`, `notes`, `achievements`.
* `completions` has the primary key `(habit_id, date_key)`, so a habit can
  never have two records for one day.
* Foreign keys are enforced: deleting a habit removes its completions,
  achievements and notes; deleting a category leaves habits uncategorised.
* Schedule, reminder and checklist are stored as JSON columns.
* Migrations: bump `AppDatabase.version` and add a step to `_migrations`.

## Known limitations (deliberate, honest)

* **Not compiled or tested yet** by the author, see the status note above.
* **Photo and audio notes** are not implemented: they need the camera and
  microphone plugins plus Android permissions (planned for Stage 4). The
  Photo and Audio buttons say so. The note model and database already have
  fields for attachment paths.
* **Sharing** copies a text summary to the clipboard. The Android share sheet
  needs the `share_plus` plugin (Stage 4).
* **Reminders** are configured and saved but no notification is scheduled yet
  (Stage 4: `flutter_local_notifications`).
* The Quit + Count/Checklist behaviour, the weekly/monthly streak rule and the
  Analytics layout are my interpretation; the supplied screenshots do not
  show them.
* The font is Flutter's default, not TickOff's.
* Release builds use Flutter's default debug signing: fine for your own phone,
  not for the Play Store.

## Tests

* `test/unit`: dates, models, streak/score engine, achievements, analytics,
  state notifier (with an in-memory repository).
* `test/widget`: dashboard, habit form, habit detail, analytics, settings,
  notes.
* `test/data`: the real SQLite schema and repository, through
  `sqflite_common_ffi` (needs `libsqlite3`, installed by the workflow).

Run locally with `flutter test` once Flutter is installed.


## Stage 4 implementation candidate

This branch adds a local task manager alongside the original habit tracker. It retains the existing SQLite habit tables, adds the `tasks` table through the v1-to-v2 migration, and adds completion timestamps plus a 30-day task-history snapshot table in v3.

### Tasks
- Standalone tasks and parent tasks with ordered subtasks. The daily list presents the first incomplete subtask as the active step.
- Priorities, deadlines with optional time, category, icon, colour, text notes, local photo/audio attachments, optional reminder, pause/resume, postpone, repeat, duplicate, and delete actions.
- Overdue tasks remain visible and receive a sorting boost. Paused tasks remain accessible in All Tasks and are excluded from Due Tasks and completion analytics.
- The monthly date picker shows tasks and scheduled habits for the selected date.
- A compact combined task/habit panel is included on the main dashboard. Habit-generated items use the existing completion records rather than a separate task completion record.
- Tasks are removed after the 30-day deadline retention window when the task service next runs. Postponing a parent task moves its subtasks and their reminders by the same day offset. Manual deletion removes the task immediately.

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
This project was edited in an environment without the Flutter/Dart SDK, so Flutter formatting, static analysis, the complete Flutter test suite, Android APK compilation, and real-device verification cannot be run locally here. Static source/import checks, YAML parsing, shell syntax checks, and ZIP integrity checks are available, but they are not substitutes for a real Flutter build.

The first GitHub Actions run (`Build Android APK #4`, Flutter 3.47.8) reported three source-level issues: a malformed string in the habit detail screen, a missing import for `Tally` in streak history, and a missing habit UI extension import in settings. Those shared compile errors caused five widget test files to fail loading; 97 tests passed. The APK build separately failed because the generated Kotlin Gradle file did not receive the required `desugar_jdk_libs` dependency even though core-library desugaring was enabled. This revision patches those findings and makes the workflow format Dart sources before analysis/tests. **The fixes still require a fresh GitHub Actions run; they are not yet verified.**

A native Android launcher home-screen widget is not included. Use a separate GitHub branch for this candidate and preserve the last working project/APK until the new workflow and device checks pass.
