# Documentation index

Browse by intent. Documents describe source; they do not prove installation or CSP runtime behavior.

## Start here
- [Project README](../README.md) — overview, manual installation, quick checks.
- [Contributing](../CONTRIBUTING.md) — checkout and contribution conventions.
- [OpenCode workflow](WORKFLOW_OPENCODE.md) — task-scoped reading and handoff.
- [Detailed project guide](AGENT.md) — technical context; consult as needed.

## Reference
- [Architecture](ARCHITECTURE.md) · [State machine](STATE_MACHINE.md)
- [Localization](LOCALIZATION.md) · [Testing](TESTING.md)

## Workflow and plans
- [CSP capability audit (M0)](plans/CSP_CAPABILITY_AUDIT.md) — source evidence, risks, local checks and pending in-game verification.
- [Incremental development plan](plans/DEVELOPMENT_PLAN.md) — revised milestones, acceptance gates and proposed OpenCode/worktree workflow; implementation requires separate approval.
- [Incident & Safety handoff prompt](plans/INCIDENT_SAFETY_HANDOFF_PROMPT.md) — current lane, S1/S2 checkpoint and local S2-D/S3 changes; resume with inspection and an exact-scope approval gate, not blanket runtime permission.
- [AI observability plan](plans/AI_OBSERVABILITY_PLAN.md) — proposed event logs, selected-AI diagnostics, distinct yellow-zone IDs and bounded investigation of suspected pass-through; no authoritative tangibility readback or implementation approval.
- [Original track-day roadmap](plans/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md) — preserved hypotheses and backlog; consult the audit and revised plan before execution.
- [Restructuring plan](RESTRUCTURING_PLAN.md) — current phased plan and acceptance gates.
- [Project organization](plans/PROJECT_ORGANIZATION.md) — proposed documentation/context steps.
- [UI identity](plans/UI_IDENTITY.md) — proposed direction and phases.
- [UI standardization](plans/UI_STANDARDIZATION.md) — shared UI control tokens and phased validation plan.
- [Lua module loading](plans/MODULE_LOADING_HARDENING.md) — resolved blank-UI incident, bootstrap implemented in source (CSP validation pending), and unapproved installer proposal.

## Historical inventory
- [UI redesign discovery](UI_REDESIGN_DISCOVERY.md) — earlier inventory and status addendum; not a standalone redesign specification.

Reference documents remain at their current paths. Any future restructuring should be evaluated and all affected links updated.
