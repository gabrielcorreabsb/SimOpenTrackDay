# Testing guide

How to check SimOpenTrackDay before and after a manual installation. The repository has **no automated test suite**: the headless `tools/test_*.lua` tests, the syntax-check script and the installer were removed in v0.2 (they remain in git history). Validation is therefore a quick local compile check plus manual in-game scenarios. None of this proves which files are installed; CSP runtime and visual validation are tracked in [IN_GAME_VALIDATION.md](IN_GAME_VALIDATION.md).

> **Rule of thumb:** keep backups of the existing installation and user settings. Do not delete the current installation or clear settings to test a development version; prefer a parallel installation.

---

## 1. Prerequisites

[LuaJIT 2.1](https://luajit.org/) on `PATH` for the compile check (`luajit -v`). The app itself runs in CSP's LuaJIT.

## 2. Local source checks

### 2.1 Compile every runtime file

From the repository root:

```powershell
Get-ChildItem SimOpenTrackDay, experimental -Recurse -Filter *.lua |
  ForEach-Object { luajit -bl $_.FullName > $null; if ($LASTEXITCODE) { "FAIL $($_.FullName)" } }
```

No output means every file compiles. This catches syntax errors only (for example Lua 5.3 operators such as `&`, which LuaJIT rejects); it does not execute code or prove CSP behavior.

### 2.2 Obvious regression searches (optional)

```powershell
# Expected: no matches; use CarManager.cars_currentReusableList for the car list
Select-String -Path SimOpenTrackDay\*.lua -SimpleMatch 'local carList = {}'
# Expected: no matches; physics.removeAITopSpeed does not exist (use CarOperations.removeAITopSpeed)
Select-String -Path SimOpenTrackDay\*.lua -SimpleMatch 'physics.removeAITopSpeed'
```

## 3. Before installing in AC

### 3.1 Back up the existing version and settings

```powershell
$acLuaApps = "<Assetto Corsa>\apps\lua"
$backupRoot = "<backup-location>\SimOpenTrackDay-backup"
Copy-Item -LiteralPath (Join-Path $acLuaApps "SimOpenTrackDay") -Destination (Join-Path $backupRoot "SimOpenTrackDay") -Recurse
```

Replace `<...>` with your own paths. Preserve user settings; do not reset or remove configuration directories during tests.

### 3.2 Copy the new version

Copy the repository's `SimOpenTrackDay/` folder to `<Assetto Corsa>\apps\lua\` (see [INSTALL.md](INSTALL.md)). The installed entry point must be `apps\lua\SimOpenTrackDay\SimOpenTrackDay.lua`. Never copy modules into the AC root.

---

---

## 4. AC smoke test (load the app)

This is a minimal manual smoke test to run after installing a test copy. The incident recovery recorded in section 6 does not complete the broader scenarios below; do not assume installed files correspond to a specific source revision.

1. Open Assetto Corsa and enable `SimOpenTrackDay` among CSP Lua Apps.
2. Start an offline session with AI cars on a track with an AI spline.
3. Open the single `SimOpenTrackDay` window in-game; check CSP logs if an error occurs.

### If required CSP APIs are missing

If CSP functions are missing, inspect operational compatibility messages and CSP logs. Startup diagnostics were removed by an authorized project change; do not expect them. `CSPCompatibilityManager.ShowErrorModalDialog = false` intentionally disables the compatibility error modal; do not rely on a modal to detect failure. The app requires CSP build `Constants.MIN_CSP_BUILD` (4305, CSP 0.3.2-preview2) or newer; below it, or when the build cannot be read, it stays inert and logs one `[F0-CSP-GATE]` line.

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

After identified root-level project files were backed up and removed with authorization, the user confirmed that the UI worked again. This is a limited manual result for that installation, not confirmation of every tab, locale, AI scenario or performance target. No permanent runtime loader change was applied. See the [evidence and prevention plan](../archive/MODULE_LOADING_HARDENING.md).

For a similar failure:

1. Preserve `%USERPROFILE%\Documents\Assetto Corsa\logs\custom_shaders_patch.log` (use the actual Documents location if redirected). Compare the error, app identity and module origin with the installed files; an up-to-date app folder alone does not prove those modules were loaded.
2. With the game and launcher closed, inspect the AC root for loose project modules such as `Constants.lua` or `SettingsWindow.lua`. Do not delete all `.lua` files or folders: a matching filename is not proof that a file belongs to this project.
3. If necessary, use a temporary instrumented test copy to record build markers, `package.path`, `package.loaded` and module origins before/after `require`. Check environment `LUA_PATH` without changing the global environment. Such probes are not a shipped diagnostic interface.
4. Confirm ownership/content, inventory and back up any conflicting files before an explicitly authorized, targeted removal. Preserve user storage, game files, other mods and unrelated root folders. Do not use cache/settings deletion as the default remedy.
5. Start a fresh game session with only the intended copy enabled, check the logs, and exercise the five tabs. Record what was actually observed; do not infer simulation correctness from visible controls.

Install the app folder only into `apps/lua/SimOpenTrackDay/`, never directly into the AC root. The source bootstrap now prioritizes its directory through `__dirname`; its CSP validation remains pending and it does not replace entries already in `package.loaded`. Nothing detects root-level module collisions automatically. Follow the [current installation guide](INSTALL.md) for path and backup requirements.

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
| Compile check | §2.1 one-liner | No `FAIL` lines |
| Regression searches | §2.2 | No matches |
| Backup | Copy existing installation/settings | Backup preserved |
| Install | Copy `SimOpenTrackDay/` into `apps/lua/` | Backup kept |
| Smoke test | Enable Lua App and AI Flood | Pending CSP execution |
| Scenarios | 1 → 7 | Planned checks, not confirmed results |
| Rollback | Disable test/restore backup | Installations/settings preserved |

## 8. Manual UI and localization scenarios (pending)

After installing a test copy in CSP, verify each locale and layout. These are proposed manual checks, not results:

- Switch among English, Português (Brasil), and Español; confirm the selection persists after closing/reopening the app window and after restarting the app.
- Verify enabled/disabled state and that disabled controls behave as expected; do not equate “enabled” with “can run.”
- Expand/collapse advanced behavior controls and confirm their visibility and values; this open/closed UI state is local, not persisted.
- Confirm the single window has Overview, Behavior, Yielding, Overtaking, and Advanced tabs; the header remains visible while content scrolls; gradients are subtle and primary typography is white. These are pending manual checks, not confirmed CSP results. The layout that shipped came from the now-archived [Restructuring plan](../archive/RESTRUCTURING_PLAN.md). The consolidated pending list is in [IN_GAME_VALIDATION.md](IN_GAME_VALIDATION.md).
- Inspect narrow layouts around 80, 480, 700, 900, 1200, and 1760 px where practical, plus a wide layout; check overflow and navigation. Mocked width coverage is not a CSP visual guarantee.
- With native title/background removed and `PADDING = 8, 8`, confirm in CSP that the app fill reaches all window edges without transparent bands while content remains inset, empty header space still moves the window, window edges still resize it, the top-right Close control closes it, and the app can be reopened from the apps bar. Check narrow and normal viewports; the wordmark may be hidden where its measured rectangle cannot fit, and narrow Close may use `X` with a localized tooltip. Headless clip-stack/geometry/manifest mocks do not prove CSP clipping, hit-testing or rendering.
- Confirm translated labels keep stable ImGui IDs and no untranslated presentation strings are obvious. Simulation data, enums, and logs are not expected to be translated.
