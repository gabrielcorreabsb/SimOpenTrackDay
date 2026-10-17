# Contributing

SimOpenTrackDay is an in-development fork of [Assetto Corsa Realistic Trackday](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday). Keep upstream attribution and its MIT license notices intact. Do not present upstream releases as releases of this fork.

## Local workflow

1. Clone the project with submodules: `git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git SimOpenTrackDay`, then run `git submodule update --init --recursive` if needed.
2. Keep the app payload in the repository root. Do not reorganize modules into an `apps/lua` tree; that is the installed location, not the repository layout.
3. Make focused changes and preserve existing diagnostic tags and compatibility handling.
4. Run the Lua syntax checker: `powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"`. It finds `luajit` on `PATH`, or accepts optional `-LuaJitPath` and `-Root` arguments.
5. Run the headless mock-contract smoke test with `luajit tools/test_ui_smoke.lua`. It uses `tools/fixtures/settings_baseline.lua`; this checks only the mocked contracts/paths exercised, not CSP rendering or runtime behavior. Manual CSP/Assetto Corsa validation is a separate check and has not yet been established for this fork.
6. Run the vector-logo/icon callback smoke test with `luajit tools/test_logo_smoke.lua`. It compiles the callback extracted from the entry point and tests mocked drawing behavior; it does not validate CSP rendering or in-game runtime behavior.
7. Optionally compare against a separately available original SettingsWindow source by setting `RTD_BASELINE_SETTINGS` to its path before running `tools/test_ui_smoke.lua`. The committed fixture remains the portable default and is never regenerated from current code automatically.
8. Before sharing, review the diff and describe which checks actually ran. Do not claim an in-game test unless it was performed and recorded.

Keep the upstream Git remote separate from the fork's own remote when configuring remotes; repository remotes are a local user decision. No commits, pushes, deployments, or releases are performed automatically by this project workflow. Do not delete existing app installations or user configuration when testing; back them up and use a separate installation where practical.
