# Contributing

SimOpenTrackDay is an independent derivative project under development. Read the [README](README.md), [documentation index](docs/README.md), and [credits/license](README.md#credits-and-license) before changing or redistributing the project; preserve the original MIT notices and dependency credits.

## Prepare the checkout

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
cd SimOpenTrackDay
git submodule update --init --recursive
```

The app payload is at the checkout root. `apps/lua/SimOpenTrackDay/` is the installation path, not a directory to create inside the repository. Copying to Assetto Corsa is manual; see [installation in the README](README.md#manual-installation) and preserve existing installations/settings.

## Contribution workflow

- Keep changes focused; preserve the nine `[RTD-DIAG-*]` records, storage contracts, and compatibility behavior unless there is evidence supporting a change.
- Keep the `lib/AssettoCorsaCSPLuaCompatibilityManager/` submodule and SDK in `lib/ac_apps/` consistent with their origins and licenses. The SDK is vendor code; do not edit it as app code.
- Report project bugs in the [SimOpenTrackDay issue tracker](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues). The [upstream repository](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday) is an origin/credit reference; do not present upstream releases as this project's releases or submit upstream changes without separate authorization.

## Local checks

With LuaJIT 2.1 available on `PATH`, run these commands from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
luajit tools/test_ui_smoke.lua
luajit tools/test_logo_smoke.lua
luajit tools/test_localization.lua
```

The checker accepts `-LuaJitPath` and `-Root`. UI/logo tests use headless mocks and do not validate runtime or CSP rendering. `test_localization.lua` checks catalogs and localization contracts; none of these checks validates the complete CSP UI, main callback, or in-game behavior. For an optional comparison, `RTD_BASELINE_SETTINGS` may point to a locally available source baseline before the UI smoke test; do not include personal paths in documentation or issues. The versioned fixture is the default and is not regenerated from current code.

Before sharing a change, review the diff and report only checks actually run. Do not claim in-game validation without performing it. This workflow does not configure remotes, commit/push, install the app, or publish releases automatically.
