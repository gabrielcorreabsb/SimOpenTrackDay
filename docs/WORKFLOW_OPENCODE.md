# OpenCode workflow

Use context on demand. [`AGENTS.md`](../AGENTS.md) contains concise rules; it does not replace this human guide or automatically load other documents. See [official instructions documentation](https://opencode.ai/v2/docs/instructions/).

| Task | Start with |
| --- | --- |
| Orientation | [README](../README.md), [index](README.md) |
| UI/localization | [UI plan](plans/UI_IDENTITY.md), [localization](LOCALIZATION.md), [testing](TESTING.md) |
| Behavior/modules | [architecture](ARCHITECTURE.md), [states](STATE_MACHINE.md) as needed |
| Organization | [organization plan](plans/PROJECT_ORGANIZATION.md) |

## Short cycle

1. Define request, scope, constraints, and observable acceptance; clarify material ambiguity.
2. Inspect the smallest useful set of files and verify claims against source.
3. Delegate only when it reduces context: designer for design, fixer for implementation, explorer for repository research, librarian for external API/docs, documentation-writer for docs. Code-reviewer reviews without editing; oracle supports decisions/risk; git-release handles Git actions only after explicit confirmation. These custom agents are available in this environment, not universal OpenCode slim agents.
4. Small changes need no delegation. Parallelize only disjoint writing scopes; avoid concurrent writers on shared files. Reuse sessions when useful and reconcile conclusions against artifacts.
5. Review diff and evidence; report only checks run and remaining limits.

> Short handoff: objective, decisions, files, checks run, limits, next step. No need to read the whole repository/catalogs or apply a bureaucratic workflow by default.

`docs/AGENT.md` is a singular manual reference; its links do not load documents. Do not create global routing instructions/config without specific need and approval. Config/plugin/prompt changes may require a new run or restart; this workflow does not install or tune oh-my-opencode slim. References: [OpenCode config](https://opencode.ai/v2/docs/config), [references](https://opencode.ai/v2/docs/references/), [slim local customization](https://github.com/alvinunreal/oh-my-opencode-slim/blob/master/docs/project-local-customization.md).
