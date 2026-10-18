# Testing Guide — SimOpenTrackDay

This document describes how to validate the **SimOpenTrackDay** development source before and after a manual Assetto Corsa (AC) installation. It covers prerequisites, Lua syntax, headless mocks, and in-game scenarios. Documentation and source checks do not establish which files are installed; CSP runtime and in-game visual validation remain pending. This is not a published build or release.

> **Rule of thumb:** keep backups of the existing installation and user settings. Do not delete the current installation or clear settings to test this development version; prefer a parallel installation.

---

## 1. Environment prerequisites

### 1.1 LuaJIT

LuaJIT is required for the syntax checker and headless smoke tests. Use a LuaJIT 2.1-compatible installation; this guide does not specify a CSP version or recommend an installer.

To check the installed version:

```powershell
luajit -v
```

### 1.2 Syntax checker

The repository checker is `tools/check_lua_syntax.ps1`. It traverses `.lua` files, compiles each with LuaJIT, and reports syntax failures. Counts are dynamic and depend on discovered files. It excludes `lib/ac_apps/`, `lib/AssettoCorsaCSPLuaCompatibilityManager/`, and `*.bak`; it does not exclude `lib/uilib/`.

---

## 2. Local source checks

### 2.1 Check syntax (dynamic count)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
```

The script finds `luajit` on `PATH` by default. Optional `-LuaJitPath <path-to-luajit.exe>` and `-Root <project-root>` parameters select other paths. Final output reports the discovered count; the process fails if any file is invalid.

If it fails, inspect the reported `FAIL` block (file and line) before proceeding.

### 2.2 Obvious regression searches (optional)

These searches can catch errors that pass syntax validation, such as using an unavailable API.

```powershell
# Expected: no matches; use CarManager for the car list
findstr /N /C:"local carList = {}" *.lua

# Expected: no matches; use bit.band instead of native bitwise operators
findstr /N /C:"& " Enum.lua

# Expected: no matches; physics.removeAITopSpeed does not exist
findstr /N /C:"physics.removeAITopSpeed" *.lua
```

Notes:

- `local carList = {}` → use `CarManager.cars_currentReusableList`.
- Native `&` → use `bit.band` (LuaJIT 2.1 does not support Lua 5.3 native bitwise operators).
- `physics.removeAITopSpeed` → use `CarOperations.removeAITopSpeed`.

### 2.3 UI mock smoke test (limited evidence)

Run the headless contract smoke test:

```powershell
luajit tools/test_ui_smoke.lua
```

The test uses mocks and the versioned `tools/fixtures/settings_baseline.lua` fixture; it covers only exercised contracts and paths. Its mock checks localization/IDs, disabled-control behavior, and selected width/column cases (including 80, 480, 700, 900, 1200, and 1760 px). It does not validate CSP rendering/interaction or replace the in-game scenarios below. It is not a complete main-callback or full UI validation.

### 2.4 Logo and icon-callback mock smoke test

```powershell
luajit tools/test_logo_smoke.lua
```

This test compiles only the icon callback extracted from the entry point and tests `Logo`/renderer using a mocked UI. It does not validate actual CSP rendering.

### 2.5 Localization contract test

```powershell
luajit tools/test_localization.lua
```

This test checks locale/catalog parity, placeholders, stable UI IDs, strict storage access, and selected source call sites. It does not validate CSP rendering. Mock coverage of widths/layout is bounded and does not establish the complete CSP UI or main callback.

An optional comparison may set `RTD_BASELINE_SETTINGS` to a locally available source baseline before running `tools/test_ui_smoke.lua`. The versioned fixture remains the default and is not regenerated automatically; do not include personal paths in documentation or issues.

### 2.6 Focused entry, manager, and diagnostics checks

Run `luajit tools/test_main_window.lua`, `luajit tools/test_ui_manager.lua`, and `luajit tools/test_no_diagnostics.lua` for isolated entry, operational car-list, and static no-diagnostics contracts. These checks are bounded/headless; they do not validate CSP rendering or runtime behavior. `luajit tools/test_settings_model.lua` covers the settings model independently.

---

## 3. Before installing in AC

### 3.1 Back up the existing version and settings

```powershell
$acLuaApps = "<Assetto Corsa>\apps\lua"
$backupRoot = "<backup-location>\SimOpenTrackDay-test-backup"
Copy-Item -LiteralPath (Join-Path $acLuaApps "<existing-app-directory>") -Destination (Join-Path $backupRoot "existing-app") -Recurse
```

Replace `<...>` values with your own paths. Preserve user settings; do not reset or remove configuration directories during these tests.

### 3.2 Copy the new version

Manually copy the runtime files at the root and the `CarStateMachine/`, `DataStructures/`, `Strings/`, and `lib/` directories to a parallel `<Assetto Corsa>/apps/lua/SimOpenTrackDay/` directory. Include `SimOpenTrackDay.lua`, `manifest.ini`, and other required runtime files. Do not copy `.git/`, `tools/`, `docs/`, `artifacts/`, or `*.bak` files. Do not copy the repository wholesale. The installed entry point must be `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua`; do not create `apps/lua/` inside the clone. Keep existing installations and user settings intact.

---

## 4. AC smoke test (load the app)

This is a minimal manual smoke test to run after installing a test copy. CSP runtime and visual validation remain pending; do not assume installed files correspond to a specific source revision.

1. Open Assetto Corsa and enable `SimOpenTrackDay` among CSP Lua Apps.
2. Start an offline session with AI cars on a track with an AI spline.
3. Open the single `SimOpenTrackDay` window in-game; check CSP logs if an error occurs.

### If required CSP APIs are missing

If CSP functions are missing, inspect operational compatibility messages and CSP logs. Diagnostic probes and `[RTD-DIAG-*]` records were removed by an authorized project change; do not expect them. `CSPCompatibilityManager.ShowErrorModalDialog = false` intentionally disables the compatibility error modal; do not rely on a modal to detect failure. Use a CSP version that provides the APIs required by the app; this guide does not specify a minimum version.

- If required APIs are unavailable, update CSP through a trusted channel or disable the app in Lua Apps until compatibility is resolved.

---

## 5. In-game validation scenarios (pending for this fork)

Use these scenarios to validate features after manually installing a test copy. They are planned checks, not results already observed in this fork. The operational car list is visible while the app is running and shows each car's ID, state, speed, and lane offset; there are no diagnostic controls or flags to enable it.

### Scenario 1: Track 1 — simulation resumes

- Drive five laps at Nordschleife.
- **Expected:** AI cars keep moving (do not “freeze”).
- **Expected:** the operational car list shows car state, speed, and lane offset.
- **Bug if:** AI cars stop moving or become inert NPCs.

### Scenario 2: Track 2 — performance

- Drive with 20–30 AI cars on track.
- **Expected:** stable frame rate (above 60 fps on most setups).
- **Bug if:** frame rate falls below 30 fps with a moderate AI count.

### Scenario 3: Casual profile

1. Select `SettingsWindow → Behavior & Mode → "Casual"`.
2. Drive at Nordschleife.

- **Inspect configured values:** after applying the profile, `pointBySpeedDeltaKmh` is 25 and `entryBlendTime_s` is 0.5 s. These are stored/UI values only; point-by speed threshold and blend-time behavior are not integrated into the current runtime, so do not expect those effects or report their absence as a CSP regression.
- **Expected runtime behavior:** no position defense and no human errors (lock-up/traction) for this profile.

### Scenario 4: Realistic profile

1. Select `SettingsWindow → Behavior & Mode → "Realistic"` (default).
2. Drive at Nordschleife.

- **Inspect configured values:** after applying the profile, `pointBySpeedDeltaKmh` is 15, `entryBlendTime_s` is 1.5 s, and `aiReactionDelay_s` is 0.4 s. These values can be inspected in settings/storage; the point-by threshold, blend-time, and reaction helper are not integrated into the current runtime. Do not expect threshold-based yielding, those transition/reaction timings, or treat their absence as a CSP regression.
- **Expected runtime behavior:** no position defense and no human errors for this profile.

### Scenario 5: Competitive profile

1. Select `SettingsWindow → Behavior & Mode → "Competitive"`.
2. Drive at Nordschleife.

- **Inspect configured values:** defense duration is configured between 1.5 and 3.5 s. `pointBySpeedDeltaKmh` is 10, but that threshold is not integrated into current runtime behavior; do not infer a required yield-speed difference or treat its absence as a CSP regression.
- **Runtime limitation:** `DEFENDING_POSITION` is defined but has no incoming transition in the current FSM; the configured duration range does not establish observable position defense. Human errors are enabled, so lock-up/traction-mistake behavior may occur; do not treat a specific event or frequency as guaranteed by this scenario.

### Scenario 6: Hybrid mode (adaptive behavior pending)

1. Select a profile and inspect the displayed `Current Mode`; the mode is not directly editable.

- **Current limitation:** the UI calls `applyBehaviorProfile` when a profile is selected; it is not automatic. Casual and Realistic configure `Track Day`; Competitive configures `Race`. `Hybrid (Auto)` has no implemented detection/adaptation, so do not expect automatic mode changes.

### Scenario 7: Anti-drag-race

1. Select **Competitive**.
2. Drive behind a slower AI on a long straight.

- **Expected:** when the anti-drag-race limiter applies, the car ahead's target speed is capped at 95% of the approaching car's speed.

---

## 6. Operational troubleshooting

Use compatibility messages and CSP logs for operational errors. Diagnostic probes, overlays, traces, and development actions are not available; legacy debug storage schemas may remain inert. Preserve error reports when sharing a problem, but do not expect a diagnostic modal or debug flags.

---

## 7. Rollback (preserve installations and settings)

If a version causes problems:

1. Stop Assetto Corsa.
2. Disable the test copy in CSP Lua Apps. Do not remove it until comparison is complete.
3. Restore the known installation and settings from backup if needed:
   ```powershell
   Copy-Item -Path "<backup-location>\existing-app\*" -Destination "<Assetto Corsa>\apps\lua\<existing-app-directory>" -Recurse
   ```
4. Reopen Assetto Corsa.

---

## Quick reference

| Step | Command / action | Expected |
| --- | --- | --- |
| Syntax | `tools/check_lua_syntax.ps1` | Dynamic count; no failures |
| Regression searches | `findstr` (3 patterns) | No matches for each |
| Backup | Copy existing installation/settings | Backup preserved |
| Install | Copy to `apps/lua/SimOpenTrackDay/` | Parallel copy; existing install untouched |
| Smoke test | Enable Lua App and AI Flood | Pending CSP execution |
| Scenarios | 1 → 7 | Planned checks, not confirmed results |
| Rollback | Disable test/restore backup | Installations/settings preserved |

## 8. Manual UI and localization scenarios (pending)

After installing a test copy in CSP, verify each locale and layout. These are proposed manual checks, not results:

- Switch among English, Português (Brasil), and Español; confirm the selection persists after closing/reopening the app window and after restarting the app.
- Verify enabled/disabled state and that disabled controls behave as expected; do not equate “enabled” with “can run.”
- Expand/collapse advanced behavior controls and confirm their visibility and values; this open/closed UI state is local, not persisted.
- Confirm the single window has Overview, Behavior, Yielding, Overtaking, and Advanced tabs; the header remains visible while content scrolls; gradients are subtle and primary typography is white. These are pending manual checks, not confirmed CSP results. The current direction is in the [Restructuring plan](RESTRUCTURING_PLAN.md), not historical UI proposals.
- Inspect narrow layouts around 80, 480, 700, 900, 1200, and 1760 px where practical, plus a wide layout; check overflow and navigation. Mocked width coverage is not a CSP visual guarantee.
- Confirm translated labels keep stable ImGui IDs and no untranslated presentation strings are obvious. Simulation data, enums, and logs are not expected to be translated.
