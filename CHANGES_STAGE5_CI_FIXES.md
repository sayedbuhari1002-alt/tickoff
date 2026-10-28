# Stage 5 — CI diagnostic fixes

This update follows the GitHub Actions run for the Stage 5 pull request.

## What the run established

- The Android release APK compiled and the `tickoff-apk` artifact uploaded successfully.
- All SQLite/database tests passed (13/13).
- The red workflow status came from 13 widget-test failures. Most were stale tests still treating Dashboard as the habit-list screen, while the Stage 5 design moves category chips and habit filtering into the Habits tab. Several tests also selected an ambiguous habit title that appears both in the Dashboard's today overview and in the habit list.

## Source updates in this patch

- Added visible labels under the existing bottom-navigation icons. The original icons and centre plus are retained, but Dashboard, Habits, Tasks and Notes are now easier to distinguish.
- Added a stable key to the Dashboard's Today overview for scoped widget assertions.
- Updated habit widget tests to navigate to the Habits tab and target habit cards by their stable keys, rather than relying on ambiguous duplicate text.
- Updated Dashboard expectations to verify its new Today overview and separate Tasks/Habits progress blocks.
- Added navigation smoke tests for all four destinations and the shared Add Habit/Add Task menu, including the full-screen task and habit forms.
- Removed stale unused imports where confirmed in the current source and documented runtime-resolved icon-codepoint lint handling.

## Validation status

This patch has not been executed with Flutter/Dart in the current environment. The GitHub Actions run should be repeated after these source changes are committed. Do not treat the tests as passed until that new run completes successfully.
