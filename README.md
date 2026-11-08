# SimOpenTrackDay

SimOpenTrackDay is a Lua app for Assetto Corsa, running through Custom Shaders Patch (CSP). It helps AI-controlled cars yield and overtake during track-day sessions instead of staying on the racing line at all times.

The goal is a more realistic offline track day built on the CSP API: organic AI traffic, yielding, overtaking, context-aware caution and safe incident handling. See the [roadmap](docs/ROADMAP.md) for what is done and what is planned for v0.2.

This is an independent derivative project under development. Version `0.1` is a preview, not a certified or stable release. A limited manual UI-loading recovery was reported on 2026-10-18; broader runtime behavior and visual validation in CSP remain pending. See [troubleshooting](docs/guides/TESTING.md#6-operational-troubleshooting).

- [Manual installation](#manual-installation)
- [Package and installer guide](docs/guides/INSTALL.md)
- [Basic usage](#basic-usage)
- [Local checks](#local-checks)
- [Documentation index](docs/README.md) · [Roadmap](docs/ROADMAP.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)
- [Report an issue](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues)

## What the app provides

- Yield and overtake logic for AI cars, with configurable lateral offsets.
- Behavior profiles and driving options rendered through `SettingsWindow.lua` content.
- Track- and session-specific settings through `StorageManager`.
- One main window with five tabs: Overview, Behavior, Yielding, Overtaking, and Advanced; the operational car list is in Overview.
- UI presentation is localized in English, Brazilian Portuguese, and Spanish; see the [localization reference](docs/guides/LOCALIZATION.md).

Results depend on the track, session, and APIs available in the installed CSP version. Consult [Testing](docs/guides/TESTING.md) before experimenting; headless checks are not in-game validation.

## Requirements

- Assetto Corsa for PC.
- Custom Shaders Patch (CSP) installed with Lua Apps enabled.
- Offline sessions only; the app cannot run in online/multiplayer sessions.
- LuaJIT 2.1 is required for local checks; the app runs in CSP's Lua environment.

The entry point registers required CSP functions and checks compatibility. This README does not specify a minimum CSP version; consult app/CSP warnings and runtime results.

## Installation

Copy the repository's **`SimOpenTrackDay/`** folder into `<Assetto Corsa>\apps\lua\`. The result must be `<Assetto Corsa>\apps\lua\SimOpenTrackDay\SimOpenTrackDay.lua`. Back up an existing installation first; settings are kept. Full steps, rollback and troubleshooting: [installation guide](docs/guides/INSTALL.md).

**Never copy the modules directly into the Assetto Corsa root.** Old files there can shadow the app's modules and leave its tabs blank ([incident record](docs/archive/MODULE_LOADING_HARDENING.md)).

### Clone for development

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
```

The submodule `SimOpenTrackDay/lib/AssettoCorsaCSPLuaCompatibilityManager/` is part of the runtime; without it the app does not load (`git submodule update --init` fixes an existing clone).

## Basic usage

1. Install the app folder and enable SimOpenTrackDay among CSP Lua Apps.
2. Start an offline session with AI cars on a track with a compatible AI spline. The app does not run online/multiplayer.
3. Open the single app window from the Assetto Corsa sidebar. Overview contains the operational car list; Behavior groups lateral offsets first, then behavior profile/mode and general caution, aggression, and difficulty controls. Yielding and Overtaking contain maneuver-specific options, while Advanced is for technical settings such as accidents, pathfinding, and Other. Use the global enable control as needed.

The operational car list is part of the app UI; diagnostic options are not available. Interaction and simulation results must be confirmed in CSP.

## Project structure

```text
SimOpenTrackDay/            THE APP: copy this folder into apps\lua\
  SimOpenTrackDay.lua       entry point and manifest callbacks
  manifest.ini, LICENSE
  MainWindow.lua            single-window tabs and shared header
  SettingsWindow.lua        tab content; SettingsModel.lua, UIState.lua, UIStorage.lua
  StorageManager.lua        options, profiles, track/session storage
  CarManager.lua            AI car state/cache
  CarOperations.lua         yield/overtake operations and physics calls
  AccidentManager.lua       incidents and yellow zones
  UIManager.lua             operational car list
  CarStateMachine/          car behavior states
  Strings/ DataStructures/  reason codes and data structures
  lib/uilib/  lib/i18n/     project UI components and translations
  lib/AssettoCorsaCSPLuaCompatibilityManager/   compatibility submodule
experimental/               dormant modules not loaded by the app (kept for reference)
sdk/ac_apps/                CSP Lua SDK definitions, for editor autocomplete only (vendor)
docs/                       guides/, reference/, ROADMAP.md, BACKLOG.md, archive/
AGENTS.md, CLAUDE.md        shared agent rules (OpenCode / Claude Code)
```

See [Architecture](docs/reference/ARCHITECTURE.md) for module flow and [State machine](docs/reference/STATE_MACHINE.md) for documented states.

## Local checks

There is no automated test suite. Before installing, compile every file with LuaJIT 2.1 ([Testing §2](docs/guides/TESTING.md)); behavior is validated manually in game ([in-game checklist](docs/guides/IN_GAME_VALIDATION.md)).

## Credits and license

Current development is by **SnakeD**. SimOpenTrackDay is an independent derivative project based on the [original app](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday), created by [Andreas Grech (`dreasgrech`)](https://github.com/dreasgrech); he remains credited as the original author. The original project is distributed under the MIT license, copyright © 2025 Andreas Grech; see [`LICENSE`](LICENSE). Git history and original credits are preserved.

The [AssettoCorsaCSPLuaCompatibilityManager](https://github.com/dreasgrech/AssettoCorsaCSPLuaCompatibilityManager) submodule and CSP SDK have their own origins/licenses; keep their files and license notices intact.
