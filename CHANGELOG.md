# Changelog

Entries describe source changes. Unless an entry says otherwise, in-game (CSP) acceptance is still pending; see [docs/guides/IN_GAME_VALIDATION.md](docs/guides/IN_GAME_VALIDATION.md).

## Unreleased (0.2)

Theme: a safe track-day foundation. Scope and status are in [docs/ROADMAP.md](docs/ROADMAP.md).

### Added
- Windows installer (`tools/install.bat` + `tools/installer.ps1`) with an explicit payload list (`tools/payload.manifest`) and log files under `%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs`.
- Read-only development inspector for gates, lifecycle and control ownership in the Overview tab. It is off by default (`ENABLE_DEVELOPMENT_DEBUG_PANEL = false`).
- Focused headless tests: player guard, session lifecycle, control ownership, incident cleanup and incident release.

### Changed
- UI: a responsive borderless window, a compact car list, native control wrappers, a shared lane-target design, and a polished header and close button.
- **M1a:** per-car writes are blocked for the player, autopilot, humans and invalid indices, and nothing actuates while paused, in replay, disabled or without physics permission. `physics.allowed` is accepted as a Lua function or a callable `cdata`. Identity is tracked by generation, and stale events are discarded.
- **M1b:** top speed and throttle go through arbitration, which tracks owners, priority, expiry and the requested vs applied value.
- **S1:** a reset or identity change resolves every incident involving the car, along with its zones.
- **S2:** the incident stop is bounded to 10 s of active time, then only the app's own controls are released.
- Module bootstrap: the app directory (`__dirname`) is placed first in `package.path`, which prevents stale modules in the AC root from shadowing the app's own.

### Docs and repository
- Documentation reorganized into `docs/guides`, `docs/reference` and `docs/archive`, with a single index, roadmap and backlog, all in English.
- `CLAUDE.md` added; it imports the shared `AGENTS.md`.
- `.gitignore` trimmed to project entries; local agent state (`.slim/`, generated `codemap.md`) is ignored.

### Known issues
- `tools/test_ui_smoke.lua` fails because the fixture `tools/fixtures/settings_baseline.lua` is missing.

## 0.1 — 2026-10-18

- SimOpenTrackDay identity and preview version `0.1`.
- UI consolidated into one window with five tabs, an operational car list, global language/enable controls, and white text on subtle gradients.
- Diagnostic instrumentation removed. Operational errors and compatibility checks are preserved.
- CSP/in-game rendering not validated. This version does not claim profile-behavior fixes and does not include a package or installer.
