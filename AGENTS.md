# Repository instructions

## Reading and scope

- This file is the single auto-loaded rule set for both OpenCode and Claude Code (`CLAUDE.md` imports it). Use the [documentation index](docs/README.md) and read only references relevant to the task.
- [`docs/guides/WORKFLOW.md`](docs/guides/WORKFLOW.md) describes proportional task routing, branches/worktrees and handoff. Links do not auto-load referenced docs.
- Current status and next steps are in [`docs/ROADMAP.md`](docs/ROADMAP.md). Update it when a milestone or slice changes state.
- Live docs are written in English. `docs/archive/` is read-only history: do not edit it except to fix links, and do not treat it as current state or authorization.
- Treat plans and historical inventories as documentation; check the implementation before claiming current behavior.
- Keep edits focused on the explicitly authorized scope. Do not broaden a documentation task into runtime changes.

## Runtime boundaries

- Everything that ships lives in `SimOpenTrackDay/`, which is copied as-is into `apps/lua/`. Keep its internal layout (module names resolve relative to it via `__dirname`); never put dev-only files there. Dormant modules go in `experimental/`.
- Do not incidentally edit `sdk/ac_apps/` (vendor SDK, autocomplete only) or `SimOpenTrackDay/lib/AssettoCorsaCSPLuaCompatibilityManager/` (submodule). `SimOpenTrackDay/lib/uilib/` is project-owned.
- Runtime uses LuaJIT 2.1 / Lua 5.1. Use `bit.*`, never Lua 5.3 bitwise operators.
- Preserve top-level local bindings and avoid allocations in hot paths/per-frame work.
- Car state follows DoD in indexed tables; preserve indices and reusable structures.
- Verify CSP API compatibility through existing project registration/diagnostics when a runtime change is authorized; source registration alone is not runtime validation.
- Do not change `manifest.ini` callbacks or runtime paths as incidental cleanup.

## Storage, UI, and localization

- Use `StorageManager` getters and schemas for persistence. Declare new keys in the schema pipeline; `behavior.profile` is not a declared field.
- Do not describe partial profile inference as reliable for every settings combination.
- UI text localization uses the source English msgid and stable internal IDs; see [`docs/guides/LOCALIZATION.md`](docs/guides/LOCALIZATION.md).
- Keep simulation enums, keys, track/car data, logs, and reason strings distinct from translated presentation text.
- Plans must not imply that UI, AI, or profile changes have already been implemented.

## Compatibility and validation

- Startup diagnostics (the former `[RTD-DIAG-*]` records) were removed by an authorized change; do not reintroduce them. Preserve `CSPCompatibilityManager.ShowErrorModalDialog = false` and the `[F0-CSP-GATE]` minimum-build gate unless a separately authorized and validated change requires otherwise.
- Preserve manifest, callback IDs, and credits/licenses; do not change these contracts as incidental cleanup.
- Validation commands and limits are in [`docs/guides/TESTING.md`](docs/guides/TESTING.md). There is no automated test suite: runtime changes need the LuaJIT compile check plus in-game checks in [`docs/guides/IN_GAME_VALIDATION.md`](docs/guides/IN_GAME_VALIDATION.md). Documentation-only changes require link/diff review only.
- Report only checks actually run; mocks/headless checks do not establish CSP runtime or rendering.
- A passing compile check is not in-game evidence.
- Runtime installation and rollback are manual; preserve existing installations and user settings.

## Changes to tooling or configuration

- Do not create or edit OpenCode configuration, global instructions, prompts, plugins, models, or permissions without explicit approval naming the exact files.
- Do not add eager loading of documentation trees as a substitute for task-scoped links.
- Do not move modules, vendor code, submodules, or repository metadata as part of documentation organization.
- Do not alter runtime, tests, configuration, dependencies, or secrets during documentation work.
