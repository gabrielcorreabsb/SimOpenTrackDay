# Repository instructions

## Reading and scope

- This file contains concise auto-loaded rules. Use the [documentation index](docs/README.md) and read only references relevant to the task. `docs/AGENT.md` is a detailed human guide, not mandatory before every file.
- `docs/WORKFLOW_OPENCODE.md` describes proportional task routing and handoff. Links do not auto-load referenced docs.
- Treat plans and historical inventories as documentation; check the implementation before claiming current behavior.
- Keep edits focused on the explicitly authorized scope. Do not broaden a documentation task into runtime changes.

## Runtime boundaries

- Runtime payload stays at repository root; do not move modules.
- Do not incidentally edit `lib/ac_apps/` (vendor SDK) or `lib/AssettoCorsaCSPLuaCompatibilityManager/` (submodule). `lib/uilib/` is project-owned.
- Runtime uses LuaJIT 2.1 / Lua 5.1. Use `bit.*`, never Lua 5.3 bitwise operators.
- Preserve top-level local bindings and avoid allocations in hot paths/per-frame work.
- Car state follows DoD in indexed tables; preserve indices and reusable structures.
- Verify CSP API compatibility through existing project registration/diagnostics when a runtime change is authorized; source registration alone is not runtime validation.
- Do not change `manifest.ini` callbacks or runtime paths as incidental cleanup.

## Storage, UI, and localization

- Use `StorageManager` getters and schemas for persistence. Declare new keys in the schema pipeline; `behavior.profile` is not a declared field.
- Do not describe partial profile inference as reliable for every settings combination.
- UI text localization uses the source English msgid and stable internal IDs; see [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md).
- Keep simulation enums, keys, track/car data, logs, and reason strings distinct from translated presentation text.
- Plans must not imply that UI, AI, or profile changes have already been implemented.

## Compatibility and validation

- Preserve the nine `[RTD-DIAG-*]` records and `CSPCompatibilityManager.ShowErrorModalDialog = false` unless a separately authorized and validated change requires otherwise.
- Preserve manifest, callback IDs, and credits/licenses; do not change these contracts as incidental cleanup.
- Validation commands and limits are in [`docs/TESTING.md`](docs/TESTING.md). Documentation-only changes require link/diff review, not Lua tests.
- Report only checks actually run; mocks/headless checks do not establish CSP runtime or rendering.
- Use syntax/UI/logo/localization checks as described in `docs/TESTING.md` when relevant; do not treat them as in-game evidence.
- Runtime installation and rollback are manual; preserve existing installations and user settings.

## Changes to tooling or configuration

- Do not create or edit OpenCode configuration, global instructions, prompts, plugins, models, or permissions without explicit approval naming the exact files.
- Do not add eager loading of documentation trees as a substitute for task-scoped links.
- Do not move modules, vendor code, submodules, or repository metadata as part of documentation organization.
- Do not alter runtime, tests, configuration, dependencies, or secrets during documentation work.
