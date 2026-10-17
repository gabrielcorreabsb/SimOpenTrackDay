# UI redesign discovery — SimOpenTrackDay

This is an implementation inventory for UI corrections, not a redesign specification. Installation is manual; source documentation and local checks do not establish which files are currently installed or running. CSP runtime and in-game visual validation remain **PENDING**. This does not represent a published build or release. Keep the car-list/main-window experience and `UIManager` outside the redesign scope.

## Status vocabulary

- **DECIDED** — a constraint or direction has been established.
- **IMPLEMENTED** — present in the current source tree; not a statement that runtime behavior is correct.
- **VALIDATED** — verified by a named check (none implies in-game validation unless explicitly stated).
- **PENDING** — not completed or awaits designer/runtime confirmation.

## Manifest and windows

Source of truth: `manifest.ini`.

| ID | Name | Callback | Size | Icon metadata | Icon callback |
| --- | --- | --- | --- | --- | --- |
| `mainWindow` | `SimOpenTrackDay` | `MANIFEST__FUNCTION_MAIN` | 1024 × 768 | Removed | `MANIFEST__FUNCTION_ICON` |
| `settingsWindow` | `SimOpenTrackDay Settings` | `MANIFEST__FUNCTION_SETTINGS` | 1760 × 1210 | Removed | `MANIFEST__FUNCTION_ICON` |

The simulation update callback is `MANIFEST__UPDATE`; transparent rendering uses `MANIFEST__TRANSPARENT`. The legacy Assetto Corsa Realistic Trackday PNG and its `ICON` manifest metadata were removed for SimOpenTrackDay; no PNG fallback is claimed. `FUNCTION_ICON` uses the official CSP icon callback for both windows and draws the OTD mark with supported vector line calls; `ui.drawPath` is absent from the SDK and is not used. See the [CSP Lua apps documentation](https://github.com/ac-custom-shaders-patch/acc-lua-sdk/wiki/Lua-apps). Window-title/taskbar icon precedence and in-game callback coordinates remain **PENDING** runtime confirmation.

## Settings baseline order

Preserve this functional sequence as the baseline while correcting presentation:

1. Icon/header/enabled control.
2. Default, yielding, and overtaking lateral offsets.
3. AI Caution, Aggression, and Difficulty in three columns with proportional widths. The designer has closed the layout decision and the reviewer accepted preserving this baseline; in-game visual validation remains pending.
4. Behavior profile and 14 advanced options (advanced options disabled until enabled).
5. Yielding and overtaking.
6. Accidents and pathfinding.
7. Other settings.
8. Debug settings.
9. Footer.

Settings branding currently comes from UI string literals. `Strings/*` is for AI/debug reasons and does not contain product branding; a repository search found no branding strings there. Do not move branding into those AI/debug reason strings.

## Drawing API inventory and compatibility

The current Settings modules use the CSP `ui` API directly and through `lib/uilib/`. The table covers drawing/layout/widget APIs currently used by `SettingsWindow.lua` and `lib/uilib/*.lua`, plus requested drawing/text functions. “Registered” means the entry point calls `CSPCompatibilityManager.addFunction` for the function/enum; it does not claim runtime validation.

| API | Current use / status |
| --- | --- |
| `ui.drawRectFilled` | Used; registered in entry point. |
| `ui.drawRect` | Used; registered in entry point. |
| `ui.drawLine` | Used by `lib/uilib/Logo.lua`; registered in entry point. |
| `ui.pushStyleColor` | Used; registered in entry point. |
| `ui.popStyleColor` | Used; registered in entry point. |
| `ui.measureDWriteText` | Registered in entry point; used indirectly in the footer by `UIAppNameVersionWidget.lua`. |
| `ui.dwriteDrawText` | Registered in entry point; used indirectly by `UILateralOffsetsImageWidget.lua` for lateral-offset diagram captions. |
| `ui.drawPath` | Absent from the SDK; not supported and not used. The logo uses `ui.drawLine` instead. |
| `ui.StyleColor` | Enum used by Settings; registered in entry point. |
| `ui.styleColor` | Registered as a legacy compatibility/API requirement for other callers; not used by the current Settings UI. |
| `ui.combo`, `ui.ComboFlags` | Used; registered in entry point. |
| `ui.availableSpaceX`, `ui.beginGroup`, `ui.endGroup`, `ui.getCursor`, `ui.setCursor`, `ui.dummy` | Used in project-owned UI modules; current APIs are registered in the entry point. |
| `ui.availableSpaceY` | Used by `MANIFEST__FUNCTION_ICON` in the entry point to bound the vector icon; registered in the entry point. |
| `ui.button`, `ui.checkbox`, `ui.columns`, `ui.newLine`, `ui.nextColumn`, `ui.setColumnWidth`, `ui.text`, `ui.textColored`, `ui.separator`, `ui.slider` | Used in Settings; registered in entry point. |
| `ui.dwriteText`, `ui.pushDWriteFont`, `ui.popDWriteFont` | Used in Settings/Sections; registered in entry point. |
| `ui.itemHovered`, `ui.setTooltip`, `ui.pushDisabled`, `ui.popDisabled`, `ui.pushItemWidth`, `ui.popItemWidth`, `ui.mouseClicked`, `ui.MouseButton` | Used in Settings/widgets; registered in entry point. |
| `ui.itemRectMin`, `ui.itemRectMax` | Used in `lib/uilib/Section.lua`; registered in entry point. |
| `ui.setCursorScreenPos`, `ui.windowPos`, `ui.windowSize`, `ui.windowWidth`, `ui.dwriteDrawText`, `ui.drawTextClipped`, `ui.invisibleButton`, `ui.columnSortingHeader`, `ui.pushColumnsBackground`, `ui.popColumnsBackground`, `ui.pushID`, `ui.popID`, `ui.selectable`, `ui.itemClicked`, `ui.sameLine`, `ui.getScrollMaxY`, `ui.getScrollX`, `ui.getScrollY`, `ui.textLineHeightWithSpacing`, `ui.cursorScreenPos`, `ui.setItemAllowOverlap`, `ui.drawImage` | Registered by the entry point; whether all remain necessary for current Settings UI is **PENDING** cleanup/inventory. |
| `ui.addSettings`, `ui.Icons` | The apparent `ui.addSettings({ icon = ui.Icons.Settings, ... })` block in `SettingsWindow.lua` is commented out. These are inactive and not required by the current runtime path. |

The registration inventory should be revisited as the UI settles, so APIs used by final UI code are covered by compatibility checks. Keep all existing diagnostics and do not claim runtime compatibility from registration alone.

## Palette

Exact current palette values:

| Token | Hex |
| --- | --- |
| Background | `#0E1014` |
| Surface | `#171A20` |
| Divider | `#262A33` |
| Text | `#E8EAED` |
| Muted | `#8A8F99` |
| Accent | `#E63946` |
| Accent soft | `#2A1418` |

Treat these as the recorded baseline, not an assertion that final contrast or accessibility has been validated.

## Baseline style behavior

The original Settings baseline applied `ui.styleColor(ui.StyleColor.SliderGrab, 0)` at load time, set the enabled label color to `LimeGreen`/`Red`, and used `DarkKhaki` for caution styling. The current Settings code uses the `Theme` palette (red accent/slate-muted text), `ui.StyleColor` for scoped style pushes, and no load-time `ui.styleColor` call. The legacy `ui.styleColor` API registration remains for compatibility/other callers; the enum and function should not be conflated.

## Strings identifiers preserved

`SettingsWindow.lua` uses inline display strings and literals; branding is not sourced from these `Strings` maps. The category/name maps retain 35 numeric identifiers:

Category IDs in `Strings.StringCategories` remain `None=0`, `ReasonWhyCantYield=1`, `ReasonWhyCantOvertake=2`, and `StateExitReason=3`.

```text
ReasonWhyCantYield (10): None=0, TargetSideBlocked=1, CarInBlindSpot=2, OvertakingCarInPits=3, OvertakingCarTooFarBehind=4, OvertakingCarNotBehind=5, OvertakingCarBelowMinimumSpeed=6, YieldingCarBelowMinimumSpeed=7, WeAreFasterThanOvertakingCar=8, OvertakingCarNotOnOvertakingSide=9
ReasonWhyCantOvertake (6): None=0, YieldingCarInPits=1, YieldingCarTooFarAhead=2, YieldingCarIsFaster=3, YieldingCarIsNotOnYieldingSide=4, AnotherCarBehindTooClose=5
StateExitReason (19): None=0, YieldingToCar=1, OvertakingCar=2, OvertakingCarNoLongerExists=3, ArrivedAtOvertakingLane=4, OvertakingCarIsClearlyAhead=5, ArrivedAtYieldingLane=6, ArrivedToNormal=7, ContinuingOvertakingNextCar=8, ClearlyAheadOfYieldingCar=9, OvertakingCarIsClearlyBehind=10, YieldingCarIsFasterThenOvertakingCar=11, OvertakingCarNotOnOvertakingSide=12, NavigatingAroundAccident=13, NoAccidentIndexToNavigateAround=14, FoundCloserAccidentToNavigateAround=15, AccidentIsFarBehindUs=16, EnteringYellowFlagZone=17, ExitedYellowFlagZone=18
```

These are IDs in `Strings.StringNames` under the corresponding `STRING_CATEGORY` values, not a source of UI branding or a claim that all map values are rendered in Settings.

## Diagnostics and compatibility safeguards

The entry point retains nine `[RTD-DIAG-*]` log statements: five suffixed tags (`-0`, `-0a`, `-0b`, `-0c`, `-1`) and four generic `[RTD-DIAG]` statements. Do not remove or rename them as incidental cleanup. `CSPCompatibilityManager.ShowErrorModalDialog = false` is intentional; it disables showing the compatibility error modal during the relevant flow, while the `ui.modalDialog` availability check remains separately present. Preserve that behavior unless a separately validated compatibility change requires otherwise.

## Current state

- **IMPLEMENTED:** manifest IDs, window labels/sizes, and `MANIFEST__FUNCTION_ICON` on both windows are present in `manifest.ini`; the legacy PNG file and `ICON` metadata entries are removed.
- **IMPLEMENTED:** the line-based OTD vector logo is used by the main-window icon renderer and the manifest icon callback; no PNG is drawn by that renderer. `Constants.APP_ICON_SIZE` remains 128 for the main renderer; Settings draws the logo at 52.
- **DECIDED:** preserve module locations and root payload; preserve the main window/UIManager outside redesign; keep compatibility submodule/vendor distinctions intact.
- **VALIDATED (local source checks):** the last recorded results are Lua syntax 66 PASS, portable UI mock 542 PASS, `luajit tools/test_logo_smoke.lua` 21 PASS (including absence of legacy `ICON` metadata), and optional `RTD_BASELINE_SETTINGS` mock 607 PASS. A local payload audit recorded 70/70 matching runtime paths, zero mismatches, directory/entry agreement, and nine diagnostic lines identical to the protected baseline; it is historical evidence and does not establish which files are currently installed or running. The negative-scroll regression probe is also historical. The new icon callback was source-mock tested, not validated in CSP runtime.
- **PENDING:** CSP runtime and in-game visual validation. A manual CSP smoke test remains a follow-up after manual installation; no build or release is published by this verification.
