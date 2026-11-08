# Contributing

SimOpenTrackDay is an independent derivative project under development. Read the [README](README.md), [documentation index](docs/README.md), and [credits/license](README.md#credits-and-license) before changing or redistributing the project; preserve the original MIT notices and dependency credits.

## Prepare the checkout

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
cd SimOpenTrackDay
git submodule update --init --recursive
```

Everything that ships is inside `SimOpenTrackDay/`: that folder is copied as-is into `<Assetto Corsa>\apps\lua\` (see the [installation guide](docs/guides/INSTALL.md)); preserve existing installations and settings. `experimental/` holds dormant modules that are not installed, and `sdk/ac_apps/` holds the CSP SDK for editor autocomplete only. Adding a runtime module means placing it inside `SimOpenTrackDay/` and requiring it from the entry point; nothing else needs updating.

## Contribution workflow

- Keep changes focused; preserve storage contracts, compatibility behavior, and operational error reporting. Startup diagnostics were removed by explicit project authorization (18 Oct 2026); do not restore them or mask operational errors.
- Keep the `SimOpenTrackDay/lib/AssettoCorsaCSPLuaCompatibilityManager/` submodule and the SDK in `sdk/ac_apps/` consistent with their origins and licenses. The SDK is vendor code; do not edit it as app code.
- Follow the [development workflow](docs/guides/WORKFLOW.md): one milestone slice per branch, approved scope before editing, and [roadmap](docs/ROADMAP.md) / [in-game checklist](docs/guides/IN_GAME_VALIDATION.md) updates when status changes.
- Documentation is in English. Put how-to docs in `docs/guides/`, how-it-works docs in `docs/reference/`, and finished or superseded plans in `docs/archive/`. Link new docs from [docs/README.md](docs/README.md).
- Report project bugs in the [SimOpenTrackDay issue tracker](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues). The [upstream repository](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday) is an origin/credit reference; do not present upstream releases as this project's releases or submit upstream changes without separate authorization.

## Local checks

There is no automated test suite. Before sharing a change, run the LuaJIT compile check in [Testing §2](docs/guides/TESTING.md) and validate behavior in game using the [in-game checklist](docs/guides/IN_GAME_VALIDATION.md). Do not include personal paths in documentation or issues.

Before sharing a change, review the diff and report only checks actually run. Do not claim in-game validation without performing it. This workflow does not configure remotes, commit/push, install the app, or publish releases automatically.
