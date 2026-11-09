# Changelog

Entries describe source changes. Unless an entry says otherwise, in-game (CSP) acceptance is still pending; see [docs/guides/IN_GAME_VALIDATION.md](docs/guides/IN_GAME_VALIDATION.md).

## Unreleased

### Added
- **Defaults D1+D3** ([#9](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/9), branch lane): normal driving follows the AI racing line instead of the track middle; optional "Keep a fixed lane in normal driving"; `overrideAiAwareness` defaults to off. In-game A/B pending.
- **F1-1 incident perception** ([#3](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/3), branch lane): observation-only stopped, off-track, spin, wrong-way and grouped-contact records through `Logger.observe`, marked `[F1-1]`. The schema-backed `incidentPerceptionEnabled` flag is off by default and does not enable unrelated OBS1 diagnostics. One settings checkbox, localized in English, Spanish and Brazilian Portuguese, enables log-only observation independently of accident handling. No physics writes, zones or accident decisions are added. CSP acceptance is pending; see the [F1-1 checklist](docs/guides/IN_GAME_VALIDATION.md#f1-1--incident-perception-branch-lane-pending). Off-track uses CSP's normalized track coordinate together with `wheelsOutside` (after in-game run 1 found a planar lateral false positive), with a per-car/per-kind 10 s cooldown and a 30 records/minute cap.
- **F1-2 local single-car zones and arbitrated caution** ([#4](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/4), branch lane): a car that is stopped or spun on track, within 3 m of the AI line and outside the pit lane declares a local yellow zone through the existing zone buckets and 3 s clear rule; a car in gravel/run-off or on a track-limit excursion never does. The feature is behind the schema-backed `singleCarZonesEnabled` flag, off by default, with one localized Advanced -> Accidents checkbox, and logs `[F1-2]` declared/cleared/declined records. Caution now joins top speed and throttle ownership in `CarOperations`: request, priority, 1 s lease, requested vs applied, and handback to the app's default caution 3 when no owner remains; `YELLOW_FLAG`, `ACCIDENT_NAVIGATION` and the dormant `INCIDENT_STOP` no longer write caution directly. `isCarComingUpToAccident` reads candidate incidents from the zone buckets instead of scanning every incident per car. Removed the never-entered `COLLIDED_WITH_TRACK`, `COLLIDED_WITH_CAR` and `ANOTHER_CAR_COLLIDED_INTO_ME` states and their queues. No global Caution flag, lateral avoidance or recovery holds are included. CSP acceptance is pending; see the [F1-2 checklist](docs/guides/IN_GAME_VALIDATION.md#f1-2--local-single-car-zones-and-arbitrated-caution-branch-lane-pending).
- **F1-3 real lateral avoidance** ([#5](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/5), branch lane): spline offsets now join the `CarOperations` ownership model with priorities `ACCIDENT_NAVIGATION` (90) over `YELLOW_FLAG` (80) over traffic owners (50) and normal driving (40); `driveSafelyToSide` and the traffic release path only request or release, and one writer applies the winner with a 1 s lease. A stopped or limping car ahead on the racing line is detected from revalidated perception and direct car state (80 m, lateral band, on track, pit excluded, below 24 km/h for 2 s or 50 km/h closing), the freer side is chosen from `ac.getTrackAISplineSides` with one car width plus 1 m of margin, and the offset is requested in metres through `physics.setAISplineAbsoluteOffset` with a normalized fallback. Actuation uses a slew limit and the quintic transition; avoidance engages after 0.3 s, holds the side for 1.5 s and releases after 10 m. Runs in `NAVIGATING_AROUND_ACCIDENT` and as a lightweight check in normal driving, behind the schema-backed `lateralAvoidanceEnabled` flag, off by default, with one localized Advanced -> Accidents checkbox and `[F1-3]` engaged/released/no-room records. Yielding, overtaking, collisions and the global flags are unchanged. CSP acceptance is pending; see the [F1-3 checklist](docs/guides/IN_GAME_VALIDATION.md#f1-3--real-lateral-avoidance-branch-lane-pending).

### Changed
- Lateral-offset caching uses reusable indexed numeric fields instead of allocating a per-car table every frame; its public getter is unchanged.

## 0.2 — 2026-11-08

Theme: a safe track-day foundation. Scope and status are in [docs/ROADMAP.md](docs/ROADMAP.md).

### Added
- **F0 minimum CSP build gate:** below `Constants.MIN_CSP_BUILD` (4305, CSP 0.3.2-preview2), or when `ac.getPatchVersionCode` cannot be read, the app stays inert and logs one `[F0-CSP-GATE]` line; the reason is also shown through the existing CSP-compatibility message in the main window. On 4305 or newer the gate logs `gate passed` and behavior is unchanged. `ac.getPatchVersionCode` is accepted as a function or a callable `cdata`. Observed in CSP 4305 (gate passed, app live); the forced-failure path is pending.
- `sdk/ac_apps/` refreshed from the CSP build 4305 SDK (autocomplete only).
- Read-only development inspector for gates, lifecycle and control ownership in the Overview tab. It is off by default (`ENABLE_DEVELOPMENT_DEBUG_PANEL = false`).

### Changed
- Version set to `0.2` in `Constants.lua` and `manifest.ini`.
- Docs aligned with the code: incident states in `STATE_MACHINE.md` (no collision disabling, no lateral avoidance, dormant `COLLIDED_*` states), the removed `[RTD-DIAG-*]` rule in `AGENTS.md`, the minimum CSP build in `TESTING.md`, and a v0.2 closing session in `IN_GAME_VALIDATION.md`.
- UI: a responsive borderless window, a compact car list, native control wrappers, a shared lane-target design, and a polished header and close button.
- **M1a:** per-car writes are blocked for the player, autopilot, humans and invalid indices, and nothing actuates while paused, in replay, disabled or without physics permission. `physics.allowed` is accepted as a Lua function or a callable `cdata`. Identity is tracked by generation, and stale events are discarded.
- **M1b:** top speed and throttle go through arbitration, which tracks owners, priority, expiry and the requested vs applied value.
- **S1:** a reset or identity change resolves every incident involving the car, along with its zones.
- **S2:** the incident stop is bounded to 10 s of active time, then only the app's own controls are released.
- Module bootstrap: the app directory (`__dirname`) is placed first in `package.path`, which prevents stale modules in the AC root from shadowing the app's own.

### Repository layout
- **Copy-paste install:** all runtime files now live in `SimOpenTrackDay/`; installing is copying that folder into `apps\lua\`. Module names are unchanged.
- Dormant modules (`CarSpeedLimiter`, `CollisionAvoidanceManager`, `CustomAIFloodManager`, `FrenetAvoid`, `Profiler`, `Enum`, `lib/easing`, the state template and the unloaded `DefendingPosition` state) moved to `experimental/`; the CSP SDK moved to `sdk/ac_apps/`.
- Removed `tools/`: the installer, payload list, syntax-check script and all headless tests. Last run before removal: 22/23 tests PASS (`test_ui_smoke` blocked by a missing fixture).

### Incident lane (merged)
- **S7-1G (fix, CSP pending):** the HUD/track flag stayed yellow after the zone was removed even though the app wrote `None`. After releasing its own Caution override the app now checks `sim.raceFlagType`, re-issues `None` up to 3 times (0.5 s apart) and logs what the engine reports (`[S7-1G]` lines). **Observed in CSP (2026-11-08):** the retry did not clear the flag; with the app's global Caution override disabled (`ENABLE_GLOBAL_CAUTION_FLAG = false`) `sim.raceFlagType` stayed `None` across 5 incidents. The override is now off by default; the in-game yellow flag is therefore disabled until a safe write/release is found.
- S2-D, S3-A/B/C (no automatic collision disabling), OBS1–3 bounded observability, S4 pair deduplication, S5-A cyclic zone geometry, S6-A invalid references, S7-1 severity gate and zone resolution by absence of obstruction, S7-2 log budget, S7-1F global Caution flag release. CSP acceptance partial/pending.

### Docs and repository
- Documentation reorganized into `docs/guides`, `docs/reference` and `docs/archive`, with a single index, roadmap and backlog, all in English.
- `CLAUDE.md` added; it imports the shared `AGENTS.md`.
- `.gitignore` trimmed to project entries; local agent state (`.slim/`, generated `codemap.md`) is ignored.

## 0.1 — 2026-10-18

- SimOpenTrackDay identity and preview version `0.1`.
- UI consolidated into one window with five tabs, an operational car list, global language/enable controls, and white text on subtle gradients.
- Diagnostic instrumentation removed. Operational errors and compatibility checks are preserved.
- CSP/in-game rendering not validated. This version does not claim profile-behavior fixes and does not include a package or installer.
