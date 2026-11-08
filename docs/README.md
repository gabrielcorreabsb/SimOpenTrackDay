# Documentation index

This is the only index. Documents describe source code and plans; they do not prove installation or CSP runtime behavior. Live docs are in English; `archive/` is read-only history.

## Start here

- [Project README](../README.md): what the app is, requirements, installation, credits.
- [Roadmap](ROADMAP.md): **current status**, v0.2 scope, milestone rules.
- [Workflow](guides/WORKFLOW.md): how Claude Code and OpenCode work on this repo; branches and worktrees.
- [Contributing](../CONTRIBUTING.md) · [Changelog](../CHANGELOG.md).

## Guides (how to)

- [Install](guides/INSTALL.md): copy the app folder, update, rollback.
- [Testing](guides/TESTING.md): local checks, smoke tests, troubleshooting, rollback.
- [In-game validation](guides/IN_GAME_VALIDATION.md): every check still pending in CSP.
- [Localization](guides/LOCALIZATION.md): msgids, locales, IDs.

## Reference (how it works)

- [Architecture](reference/ARCHITECTURE.md): callbacks, per-frame flow, hot paths, coupling, DoD, storage, conventions.
- [State machine](reference/STATE_MACHINE.md): AI car states and transitions.
- [CSP capability audit](reference/CSP_CAPABILITY_AUDIT.md): which CSP APIs exist, how they are used, risks.

## Planning

- [Roadmap](ROADMAP.md): milestones M0–M9 and Incident & Safety S1–S9.
- [Backlog](BACKLOG.md): track-day realism ideas (personalities, pit lifecycle, session phases, tyres/wear, weather, logbook).

## Archive

- [Archive index](archive/README.md): finished plans, the original PT roadmap and decision log, historical UI docs.

Generated `codemap.md` files (from `.slim/codemap.json`) may exist locally for agents. They are not tracked; [Architecture](reference/ARCHITECTURE.md) is the maintained reference.
