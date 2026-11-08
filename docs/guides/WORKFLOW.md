# Development workflow (Claude Code + OpenCode)

The project is developed with two agent tools: **Claude Code** and **OpenCode** (with the oh-my-opencode-slim plugin). Both follow the same rules.

- [`AGENTS.md`](../../AGENTS.md) is the **single rule set**. OpenCode loads it directly; Claude Code loads it through [`CLAUDE.md`](../../CLAUDE.md), which imports it and adds only Claude-specific notes.
- Neither tool auto-loads other docs. Read what the task needs, starting from the [documentation index](../README.md).
- Current state and next steps live in [`docs/ROADMAP.md`](../ROADMAP.md). Do not infer progress from archived plans.

## Where to start

| Task | Start with |
| --- | --- |
| Orientation | [README](../../README.md), [index](../README.md), [roadmap](../ROADMAP.md) |
| AI behavior / modules | [architecture](../reference/ARCHITECTURE.md), [state machine](../reference/STATE_MACHINE.md) |
| New CSP API usage | [CSP capability audit](../reference/CSP_CAPABILITY_AUDIT.md), [architecture §8](../reference/ARCHITECTURE.md) |
| UI / localization | [localization](LOCALIZATION.md), [testing](TESTING.md) |
| Install / packaging | [install](INSTALL.md), [testing §3–7](TESTING.md) |
| In-game checks | [in-game validation](IN_GAME_VALIDATION.md) |

## Short cycle

1. Define the request, scope, constraints and observable acceptance. Clarify material ambiguity before editing.
2. Inspect the smallest useful set of files and verify claims against source, not against docs.
3. Make the change. Small changes need no delegation.
4. Run the checks that apply ([TESTING.md](TESTING.md)) and report only those actually run. Headless/mock checks are not CSP runtime evidence.
5. Update [ROADMAP.md](../ROADMAP.md), [IN_GAME_VALIDATION.md](IN_GAME_VALIDATION.md) and [CHANGELOG.md](../../CHANGELOG.md) when the change affects them.

> Handoff: objective, decisions, files, checks run, limits, next step.

## Branches and worktrees

- One milestone step per branch. Branch from `main`; never commit directly to `main`.
- OpenCode slim lanes use `omos/<slug>` branches with worktrees under `.slim/worktrees/`, tracked in `.slim/worktrees.json`. `.slim/` is local state and gitignored; do not edit it by hand.
- Claude Code uses plain branches (for example `feat/<milestone>-<topic>`, `chore/<topic>`) or its own worktrees. Do not commit into a branch that has a live `.slim` worktree checked out.
- Two writers must not edit the same files in parallel. Integrate one branch at a time and rerun the checks on `main`.
- Delete merged branches and remove their worktrees only after explicit confirmation.

## Delegation (OpenCode slim)

Delegate only when it reduces context: designer for design, fixer for implementation, explorer for repository research, librarian for external API/docs, documentation-writer for docs. Code-reviewer reviews without editing; oracle supports decisions and risk; git-release handles Git actions only after explicit confirmation. These custom agents exist in this local environment, not in every OpenCode install.

## Configuration

Do not create or change OpenCode or Claude Code configuration, prompts, plugins, models or permissions without explicit approval naming the exact files. Config changes may require a restart. References: [OpenCode instructions](https://opencode.ai/v2/docs/instructions/), [OpenCode config](https://opencode.ai/v2/docs/config), [slim local customization](https://github.com/alvinunreal/oh-my-opencode-slim/blob/master/docs/project-local-customization.md).
