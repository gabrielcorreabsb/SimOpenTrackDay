# Testing Guide — SimOpenTrackDay

This document describes how to validate the **SimOpenTrackDay** development source before and after a manual Assetto Corsa (AC) installation. It covers prerequisites, Lua syntax, headless mocks, and in-game scenarios. Documentation and source checks do not establish which files are installed. A limited manual UI-loading recovery was reported on 2026-10-18 (see section 6); broader CSP runtime and visual validation remain pending. This is not a published build or release.

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

The lateral-offset diagram has focused headless coverage in `tools/test_lateral_layout.lua` (native text measurement mock with wrapped-string/bounds checks, localized copy, one shared horizontal axis with independent targets, responsive text-only fallback, endpoint/center/equal/near-equal mapping, shape-matched legends, marker/text separation, disabled-marker outlines, read-only configured values, and all enable combinations). The panel uses the section's available content width, preserving the app/section insets rather than drawing to the physical window edge. Its test font metrics/wrapping and height ceiling are simulated, not CSP rendering or performance evidence. `tools/test_ui_manager.lua` also exercises the real widget through `UIManager` and checks that no empty column is created while the equal-side warning and Behavior guidance remain. Neither test establishes CSP font metrics, clipping, panel rendering, or in-game behavior. Manually review at 480/700/900 px in English, Brazilian Portuguese, and Spanish before treating visual validation as complete.

The focused native-controls checks are `tools/test_native_controls.lua`, `tools/test_settings_navigation.lua`, and `tools/test_main_window.lua`. These cover native-font measurement/layout contracts and combo item-width cleanup on UI errors, but mock font widths do not establish CSP rendering or clipping. Recheck translated controls and responsive widths in CSP before closing UI standardization.

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

Current blocker: `tools/fixtures/settings_baseline.lua` is absent from this checkout, so the default run fails during loading. This predates the `__dirname` bootstrap change; do not count this smoke test as passed.

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

An optional comparison may set `SOTD_BASELINE_SETTINGS` to a locally available source baseline before running `tools/test_ui_smoke.lua`. The versioned fixture is the default and remains unchanged. `SOTD_DUMP_BASELINE_FIXTURE=1` emits a candidate Lua fixture to stdout for inspection only; it does not save or regenerate the versioned fixture. Updating the fixture requires a separate deliberate, reviewed change. Do not include personal paths in documentation or issues.

### 2.6 Focused entry, manager, and diagnostics checks

Run `luajit tools/test_main_window.lua`, `luajit tools/test_ui_manager.lua`, and `luajit tools/test_no_diagnostics.lua` for isolated entry, Overview section/header, operational car-list, and static no-diagnostics contracts. These checks are bounded/headless; they do not validate CSP rendering or runtime behavior. `luajit tools/test_settings_model.lua` covers the settings model independently.

The MainWindow contract test uses a UIManager stub for the lane-section payload; it verifies that Section headings use native text/measurement rather than DirectWrite, localized grouping, operational/tab gating, header/tab font measurement and states, and that a failing section callback closes its group before MainWindow closes the child and rethrows. Header geometry assertions capture mock item coordinates and check shared insets, context containment, wide-row baselines, narrow stacking at 480/900/1200 px across three locales, and separator placement below independently advancing checkbox/combo/wrapped-text item bounds (including a multi-line status). Header typography mocks give Title/Main distinct metrics and assert matching scopes for app name, context, controls and tabs. Close tests cover native Cancel icon ID/tooltip/action, no-icon text fallback and scope cleanup on injected errors. It also asserts that the header and Section use the same flat surface fill with no gradient calls. These contracts do not establish CSP pixels, actual glyph rendering or clipping. The test also checks the explicit localized language label and stable hidden combo ID. It does not verify the actual offsets widget's drawing or values. The entry point source assertions check the retained `ui.drawRectFilledMultiColor` registration and require exactly one registration each for `ui.iconButton` and `ui.Icons.Cancel`. These are source contracts only, not evidence of availability or rendering in CSP runtime. `tools/test_settings_navigation.lua` checks the real SettingsWindow routing with mocks.

Run `luajit tools/test_ui_controls.lua` for shared control geometry, status-indicator contracts and the source payload-manifest entry. `tools/test_main_window.lua` and `tools/test_ui_manager.lua` cover mocked navigation/filter localization, stable IDs, shared button styles and selection behavior; the manager check also exercises translated filter counts, chip widths/wrapping, narrow combo fallback, native-measured responsive car-row composition and localized empty states over mocked widths/locales. Its cursor/text mocks advance item bounds and expose `itemRectMax`, wrapping long content to test ordering, alignment, containment and row bars, including longest localized state names, overtake/incident states and injected selectable/camera failures. These are headless geometry contracts only; they do not establish CSP fonts, pixels, clipping, wrapping, readability, runtime behavior or installation.

Run `luajit tools/test_native_controls.lua` to exercise the real project-owned `Toggle`, `Slider`, and `Style` modules with mocked CSP calls. It covers localized checkbox wrapping/IDs and checked/unchecked/external-disabled values, native-font measurement, slider ranges/format/default/tooltip/right-click reset, narrow/hidden-label fallback, and style/item-width restoration on widget errors. This does not call the real CSP controls and does not establish visual rendering or runtime compatibility. Combo controls remain native and unchanged in this phase slice.

### 2.7 Version and license metadata

Run `luajit tools/test_version.lua` to check runtime/manifest name, version and author metadata and preservation of the existing MIT license notice. It does not validate CSP or product behavior.

### 2.8 Package/installer checks

`tools/test_package.ps1`, `tools/test_installer.ps1` and `tools/test_distribution.ps1` exercise package, installer and real-source integration under a sandbox under `%LOCALAPPDATA%\Temp\opencode`. They do not establish CSP compatibility or safe behavior in a real Assetto Corsa installation. When launching `install.bat` or `installer.ps1` in Preview or Rollback, the console window closes immediately after printing — that is normal PowerShell behavior, not an error. Run it from an open terminal or capture the output (e.g. `*> "D:\preview.txt"`) so you can read the plan.

---

### 2.9 Module-path bootstrap (Windows, LuaJIT)

```powershell
luajit tools/test_module_path.lua
```

Run from the repository root. This test exercises the actual entry-point bootstrap using a disposable sandbox under `%LOCALAPPDATA%\Temp\opencode`, without touching the game installation. It checks app-local modules winning over external namesakes, a renamed folder with spaces, `?.lua` and `?/init.lua`, trailing separators, preservation of prior search paths, rejection of unavailable/invalid `__dirname`, and the fact that `package.loaded` entries are not replaced. It does not establish CSP preprocessing, module loading or rendering behavior; confirm those manually after installing a test copy.

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

This is a minimal manual smoke test to run after installing a test copy. The incident recovery recorded in section 6 does not complete the broader scenarios below; do not assume installed files correspond to a specific source revision.

1. Open Assetto Corsa and enable `SimOpenTrackDay` among CSP Lua Apps.
2. Start an offline session with AI cars on a track with an AI spline.
3. Open the single `SimOpenTrackDay` window in-game; check CSP logs if an error occurs.

### If required CSP APIs are missing

If CSP functions are missing, inspect operational compatibility messages and CSP logs. Startup diagnostics were removed by an authorized project change; do not expect them. `CSPCompatibilityManager.ShowErrorModalDialog = false` intentionally disables the compatibility error modal; do not rely on a modal to detect failure. Use a CSP version that provides the APIs required by the app; this guide does not specify a minimum version.

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

### Blank tabs and mixed Lua module versions

On 2026-10-18, CSP logged `attempt to call field 'drawContent' (a nil value)` in `MainWindow.lua`. The entrypoint/main window were current, but the loaded settings module came from `.\SettingsWindow.lua` and exposed the old `draw` interface. `Constants` reported `RealisticTrackday 0.9.8`. Old project files in the AC root were winning module resolution because relative/external paths preceded the app directory in the observed `package.path`.

After identified root-level project files were backed up and removed with authorization, the user confirmed that the UI worked again. This is a limited manual result for that installation, not confirmation of every tab, locale, AI scenario or performance target. No permanent runtime loader change was applied. See the [evidence and prevention plan](plans/MODULE_LOADING_HARDENING.md).

For a similar failure:

1. Preserve `%USERPROFILE%\Documents\Assetto Corsa\logs\custom_shaders_patch.log` (use the actual Documents location if redirected). Compare the error, app identity and module origin with the installed files; an up-to-date app folder alone does not prove those modules were loaded.
2. With the game and launcher closed, inspect the AC root for loose project modules such as `Constants.lua` or `SettingsWindow.lua`. Do not delete all `.lua` files or folders: a matching filename is not proof that a file belongs to this project.
3. If necessary, use a temporary instrumented test copy to record build markers, `package.path`, `package.loaded` and module origins before/after `require`. Check environment `LUA_PATH` without changing the global environment. Such probes are not a shipped diagnostic interface.
4. Confirm ownership/content, inventory and back up any conflicting files before an explicitly authorized, targeted removal. Preserve user storage, game files, other mods and unrelated root folders. Do not use cache/settings deletion as the default remedy.
5. Start a fresh game session with only the intended copy enabled, check the logs, and exercise the five tabs. Record what was actually observed; do not infer simulation correctness from visible controls.

Install payload only into `apps/lua/SimOpenTrackDay/`, never directly into the AC root. The source bootstrap now prioritizes its directory through `__dirname`; its CSP validation remains pending and it does not replace entries already in `package.loaded`. The current installer does not automatically detect root-level module collisions; an installer preflight was **not approved or implemented**. Follow the [current installation guide](INSTALL.md) for path and backup requirements.

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
- With native title/background removed and `PADDING = 8, 8`, confirm in CSP that the app fill reaches all window edges without transparent bands while content remains inset, empty header space still moves the window, window edges still resize it, the top-right Close control closes it, and the app can be reopened from the apps bar. Check narrow and normal viewports; the wordmark may be hidden where its measured rectangle cannot fit, and narrow Close may use `X` with a localized tooltip. Headless clip-stack/geometry/manifest mocks do not prove CSP clipping, hit-testing or rendering.
- Confirm translated labels keep stable ImGui IDs and no untranslated presentation strings are obvious. Simulation data, enums, and logs are not expected to be translated.
