# Archive

These documents are **read-only history**. They are kept in their original language (mostly Portuguese) and content; only their relative links were updated when they moved here. They mention `tools/` scripts and root-level module paths that no longer exist since the v0.2 layout (`SimOpenTrackDay/`, `experimental/`, `sdk/`). Do not treat them as current state or as authorization for anything. The current sources are listed in the [documentation index](../README.md).

| Document | What it was | Why archived / replaced by |
| --- | --- | --- |
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | Detailed PT decision log for M0–M1b, S1–S2: tickets, allowlists, evidence, CSP log excerpts | Status and sequence moved to [ROADMAP.md](../ROADMAP.md). Includes the lane log through S7-1F (2026-10-29) |
| [INCIDENT_SAFETY_HANDOFF_PROMPT.md](INCIDENT_SAFETY_HANDOFF_PROMPT.md) | Copy-paste prompt for resuming S2–S9 in a new OpenCode context | Near-duplicate of the plan; [ROADMAP.md](../ROADMAP.md) and [WORKFLOW.md](../guides/WORKFLOW.md) |
| [SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md](SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md) | Original master technical roadmap (1,193 lines, PT): vision, feasibility, feature designs, M0–M9 | Hypotheses distilled into [BACKLOG.md](../BACKLOG.md); sequencing replaced by the roadmap |
| [RESTRUCTURING_PLAN.md](RESTRUCTURING_PLAN.md) | P0–P3 plan for the single tabbed window | Done; shipped in 0.1 |
| [UI_STANDARDIZATION.md](UI_STANDARDIZATION.md) | Phased UI control standardization (tokens, fonts, compact list, native wrappers) | Phases implemented in source; pending CSP checks moved to [IN_GAME_VALIDATION.md](../guides/IN_GAME_VALIDATION.md) |
| [UI_REDESIGN_DISCOVERY.md](UI_REDESIGN_DISCOVERY.md) | Earlier UI inventory | Historical inventory |
| [UI_IDENTITY.md](UI_IDENTITY.md) | Pit-wall dashboard/sidebar proposal | Not adopted |
| [MODULE_LOADING_HARDENING.md](MODULE_LOADING_HARDENING.md) | 2026-10-18 module-collision incident (blank tabs), `__dirname` bootstrap, unapproved installer preflight | Fix implemented; CSP check in [IN_GAME_VALIDATION.md](../guides/IN_GAME_VALIDATION.md), troubleshooting in [TESTING.md §6](../guides/TESTING.md) |
| [AI_OBSERVABILITY_PLAN.md](AI_OBSERVABILITY_PLAN.md) | OBS1–OBS4 observability plan for AI, incidents and zones (PT) | Delivered locally (OBS1–3); status in [ROADMAP.md](../ROADMAP.md) |
| [PROJECT_ORGANIZATION.md](PROJECT_ORGANIZATION.md) | Documentation-organization plan | Superseded by the v0.2 reorganization |
