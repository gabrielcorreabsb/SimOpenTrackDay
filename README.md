# SimOpenTrackDay

SimOpenTrackDay is a Lua app for Assetto Corsa, running through Custom Shaders Patch (CSP). It helps AI-controlled cars yield and overtake during track-day sessions instead of staying on the racing line at all times.

This is an independent derivative project under development. Version `0.1` is a preview, not a certified or stable release. Runtime behavior and visual presentation in CSP have not been validated in-game.

- [Manual installation](#manual-installation)
- [Basic usage](#basic-usage)
- [Local checks](#local-checks)
- [Documentation index](docs/README.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md) · [Detailed testing](docs/TESTING.md) · [Onboarding](docs/AGENT.md) · [Plans](docs/plans/PROJECT_ORGANIZATION.md)
- [Report an issue](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues)

## What the app provides

- Yield and overtake logic for AI cars, with configurable lateral offsets.
- Behavior profiles and driving options rendered through `SettingsWindow.lua` content.
- Track- and session-specific settings through `StorageManager`.
- One main window with five tabs: Overview, Behavior, Yielding, Overtaking, and Advanced; the operational car list is in Overview.
- UI presentation is localized in English, Brazilian Portuguese, and Spanish; see the [localization reference](docs/LOCALIZATION.md).

Results depend on the track, session, and APIs available in the installed CSP version. Consult [Testing](docs/TESTING.md) before experimenting; headless checks are not in-game validation.

## Requirements

- Assetto Corsa for PC.
- Custom Shaders Patch (CSP) installed with Lua Apps enabled.
- Offline sessions only; the app cannot run in online/multiplayer sessions.
- LuaJIT 2.1 is required for local checks; the app runs in CSP's Lua environment.

The entry point registers required CSP functions and checks compatibility. This README does not specify a minimum CSP version; consult app/CSP warnings and runtime results.

## Manual installation

The source repository keeps runtime payload at its root; the app installation path is `apps/lua/SimOpenTrackDay/`. Manually copy the runtime payload:

- Runtime `.lua` files at the root, including `SimOpenTrackDay.lua`;
- `manifest.ini` and `LICENSE`;
- `CarStateMachine/`, `DataStructures/`, `Strings/`, and `lib/` directories.

The installation must contain `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua`; the directory and entry-point names must match. Do not copy Git metadata (`.git/` directories or `.git` files), `tools/`, `docs/`, `artifacts/`, or `*.bak` files. The compatibility submodule at `lib/AssettoCorsaCSPLuaCompatibilityManager/` is part of runtime; do not copy the submodule's Git metadata.

Preserve existing installations and settings. Use a separate app directory for testing; do not remove or replace old directories or reset user data during installation or rollback.

### Clone for development

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
cd SimOpenTrackDay
git submodule update --init --recursive
```

The recursive clone obtains the compatibility submodule. The CSP SDK is in `lib/ac_apps/`; it is vendor code and must not be edited as app code.

## Basic usage

1. Manually install the runtime files and enable SimOpenTrackDay among CSP Lua Apps.
2. Start an offline session with AI cars on a track with a compatible AI spline. The app does not run online/multiplayer.
3. Open the single app window from the Assetto Corsa sidebar. Use the global enable control and internal tabs to adjust available options.

The operational car list is part of the app UI; diagnostic options are not available. Interaction and results must be confirmed in CSP; this guide does not claim visual validation.

## Project structure

```text
SimOpenTrackDay.lua       entry point and manifest callbacks
SettingsWindow.lua        settings interface
MainWindow.lua            single-window tabs and shared header
SettingsModel.lua         settings queries and actions
UIState.lua               transient UI selections/expansions
UIStorage.lua             shared UI preference schema
StorageManager.lua        options, profiles, track/session storage
CarManager.lua            AI car state/cache
CarOperations.lua         yield/overtake operations and physics calls
CarStateMachine/          car behavior states
UIManager.lua              operational car list
lib/uilib/                 project-owned UI components
lib/ac_apps/               distributed CSP SDK
lib/AssettoCorsaCSPLuaCompatibilityManager/
                            compatibility submodule
Strings/ DataStructures/  text support and data structures
tools/ docs/               checks and documentation
```

See [Architecture](docs/ARCHITECTURE.md) for module flow and [State machine](docs/STATE_MACHINE.md) for documented states.

## Local checks

From the repository root, with LuaJIT on `PATH`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
luajit tools/test_ui_smoke.lua
luajit tools/test_logo_smoke.lua
luajit tools/test_localization.lua
luajit tools/test_version.lua
```

The checker accepts optional `-LuaJitPath` and `-Root` arguments. Smoke tests use mocks and cover only exercised paths; they do not load Assetto Corsa/CSP or validate real rendering. An original-baseline comparison is optional: set `SOTD_BASELINE_SETTINGS` to a locally available baseline source file before running `test_ui_smoke.lua`. By default, the versioned fixture remains unchanged. `SOTD_DUMP_BASELINE_FIXTURE=1` only emits a candidate Lua fixture to stdout for inspection; it does not save or regenerate the versioned fixture. Updating that fixture requires a separate deliberate, reviewed change.

The localization command is included above. See [Testing](docs/TESTING.md) for command scope and limitations. CSP runtime and visual validation remain pending.

## Credits and license

SimOpenTrackDay is an independent derivative project based on the [original app](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday), created by [Andreas Grech (`dreasgrech`)](https://github.com/dreasgrech). The original project is distributed under the MIT license, copyright © 2025 Andreas Grech; see [`LICENSE`](LICENSE). Git history and original credits are preserved.

The [AssettoCorsaCSPLuaCompatibilityManager](https://github.com/dreasgrech/AssettoCorsaCSPLuaCompatibilityManager) submodule and CSP SDK have their own origins/licenses; keep their files and license notices intact.
