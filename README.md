# Next Up

A native, local-first macOS app that helps you choose one useful thing to do with the time and energy you have.

## Use it

Requires macOS 14 or later. This first build is for Apple Silicon when built on an Apple Silicon Mac.

1. Open **Next Up**.
2. Add a few tasks with an area, rough time estimate, energy requirement, and optional deadline. Include a finish line and a specific next action.
3. Adjust the starting weekly targets in **This week** to match your actual available hours.
4. In **Right now**, choose a time window and energy level. Read the recommendation and its reasons, then start a session. Use **Something else** to skip a suggestion temporarily or the adjustment button to correct the task.
5. Pause as needed. Finish the session, correct the focused minutes if necessary, and record progress, completion, or a blocker. A blocked task stays excluded until you unblock it in **Tasks**.

The app starts empty. Optional example tasks are explicitly labeled; they are not your assignments or real deadlines. Command-N adds a task. The sidebar menu exports a JSON backup or opens the data folder.

## Build a Mac app

Requires Xcode or a compatible Swift 6 toolchain with the macOS SDK. There are no third-party dependencies.

```sh
bash scripts/build-app.sh
open "dist/Next Up.app"
```

The script creates an app bundle and icon, then applies a local ad-hoc signature. It is not a notarized distribution build. To install locally, copy `dist/Next Up.app` into `~/Applications`.

For development:

```sh
swift run NextUp
swift test
```

If running inside a restricted environment that cannot invoke SwiftPM's nested sandbox, pass `--disable-sandbox` to these commands or to the build script. This package contains no external plugins or dependencies.

## How recommendations work

The planner excludes completed, blocked, temporarily skipped, and higher-energy tasks. It scores remaining tasks using priority, deadline proximity, estimated work per day before a deadline, remaining weekly target, and fit within the available time. It returns an explanation rather than a hidden AI judgment.

Urgent deadlines receive a large boost. Weekly deficits help protect project time when obligations are less urgent. A task longer than the selected window gets a shorter session; its full-task finish line is still shown. Targets are editable starting suggestions, not a calendar or a guarantee of a balanced schedule. The app does not know your class schedule or sync assignments automatically.

Weeks start Monday in the Mac's local timezone. Only saved focus sessions contribute to totals. Completing a checkbox alone does not log time. Time left in a target does not carry forward. The app has no punitive streaks or expectation that every free moment needs work.

## Data and recovery

Normal data lives at `~/Library/Application Support/NextUp/data.json`, outside this repository. Tasks, targets, session history, and an active session are saved atomically after changes. A running session checkpoints every 30 seconds, pauses when the Mac sleeps or the app quits normally, and restores paused after relaunch. After a crash, up to 30 seconds since the last checkpoint can be lost. Time while the app is closed is not added on restore. The timer keeps tracking after the planned duration until paused or finished; review the logged minutes when wrapping up.

The app makes no network requests and needs no accounts, API keys, or model subscription. Data is a plain local JSON file, not an encrypted database. Export backups from the sidebar menu. To restore one, quit the app, keep a copy of your current data file, replace `data.json` with the exported backup, and reopen the app. Unreadable or unsupported data disables saving and reports an error instead of overwriting the original.

For isolated development or UI testing, launch the executable with a separate directory:

```sh
NEXTUP_DATA_DIR=/tmp/nextup-preview .build/debug/NextUp
```

## Layout and checks

- `Sources/NextUpCore`: data models, recommendation logic, weekly accounting, atomic persistence.
- `Sources/NextUp`: SwiftUI interface and session lifecycle.
- `Tests/NextUpCoreTests`: deadline priorities, protected project time, energy and blocker exclusions, session chunks, local date boundaries, pause/resume behavior, persistence round trips, and corrupt-data protection.
- `scripts`: reproducible app bundle and icon generation.

Generated bundles, build products, local data, credentials, and development logs do not belong in Git.
