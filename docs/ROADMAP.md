# Roadmap

This file is the single source for **where the project stands and what comes next**. It is a plan, not a description of shipped behavior. Anything not marked done here is not implemented or not accepted.

**Product goal:** an offline track day with organic AI traffic. AI cars should yield, overtake and show context-aware caution, built on the CSP API, while the native AI keeps its own decisions. Non-goals:
- mandatory point-by;
- a universal ban on overtaking;
- pit service on every track;
- universal physical mechanical failures.

**Status vocabulary**
- **Done:** delivered, reviewed and accepted in CSP.
- **Local:** implemented and verified locally (syntax, headless/mock tests); runtime/CSP acceptance pending. Mocks do not prove CSP behavior.
- **Lane:** work in progress on a branch/worktree, not yet on `main`.
- **Open:** not started.

Last reconciled: 2026-11-08, from `main` (`6a9fd6e`) and the active lane `omos/incident-s2-validation`.

## Milestones

| Milestone | Scope | Status | Evidence |
| --- | --- | --- | --- |
| **M0** CSP capability audit | Compare SDK, external examples and current code; inventory risks | **Local:** sources done, runtime checks pending | `a45ab3b`, [audit](reference/CSP_CAPABILITY_AUDIT.md) |
| **M1a** Player isolation and lifecycle | No per-car writes to player/autopilot/human/invalid indices; no actuation while paused, in replay, disabled or without physics permission; generation-based identity and stale-event rejection | **Local**, partial CSP evidence (states restored after the `physics.allowed` cdata fix) | `ef2562c` |
| **M1b** Narrow control ownership | Arbitration for top speed and throttle: requests, priorities, expiry, requested vs applied; read-only dev inspector (`ENABLE_DEVELOPMENT_DEBUG_PANEL = false`) | **Local**, limited CSP evidence | `9ce6f47` |
| **S1** Stale incident cleanup | A reset or identity change resolves *every* active incident that mentions the car, plus its zones | **Local** | `6a9fd6e` |
| **S2** Bounded incident stop | One stop episode per car/generation, 10 s of active time, then release only the app's own controls | **Local** on `main`; later revised on the lane (no automatic stop after contact) | `6a9fd6e`, lane |
| **S2-D, S3-A/B/C, OBS1–3, S4 (partial), S5-A, S6-A, S7-1, S7-2, S7-1F** | <ul><li>Diagnostics</li><li>No automatic collision disabling for passers, navigation or participants</li><li>Bounded opt-in observability log and inspector panel</li><li>Pair deduplication and queue overload</li><li>Cyclic geometry</li><li>Invalid references</li><li>Severity gate and zone resolution when no obstruction remains</li><li>Log readability</li><li>Release of the global Caution flag</li></ul> | **Lane:** `4dd0e85` is pushed, but **17 files are still uncommitted** in `.slim/worktrees/incident-s2-validation`. Last local run: 96 syntax PASS, 22/23 tests (UI fixture). Partial CSP evidence for S5-A and S7-1F | lane plan `docs/plans/DEVELOPMENT_PLAN.md` |
| **S7-1H, S7-3, S7-4, S8, S9** | <ul><li>Exit effects of the yellow state</li><li>Obstruction detection before contact</li><li>Real lateral avoidance (none exists today; that code is commented out)</li><li>Yellow-flag separation</li><li>Integration and final validation</li></ul> | **Open** | — |
| **M2** Per-car driving phases | Observational phases (sighting / warm-up / free running / cool-down); no physical writes at first | **Open** | — |
| **M3** Driver personalities | Seeded per session/identity, slow bounded variation; give `BehaviorPolish` real consumers | **Open** | — |
| **M4** Traffic and smoothing | Gap/TTC, history, hysteresis, abort/cooldown | **Open** | — |
| **M5** Pit observer and probe | Separate pit events (request/entry/box/service/exit); probe off by default | **Open** | — |
| **M6** Opt-in pit service | Only after M5 is proven in game for explicit combinations | **Open** | — |
| **M7** Conditions and sensors | Weather/track/tyre reading; neutral on nil/NaN; no double grip penalty | **Open** | — |
| **M8** Advanced observability / opt-in recovery | Full logbook; no default teleport | **Open** | — |
| **M9** Consolidation (v1.0) | Real support matrix, benchmark, packaging | **Open** | — |

Incident & Safety (S1–S9) comes **before** M2. New flags and sporting penalties are out of scope for that phase. The longer-term feature ideas are in [BACKLOG.md](BACKLOG.md).

## v0.2 — "Safe track day foundation"

v0.2 is complete when the existing AI behavior is safe and observable in CSP. New realism systems are not part of it. Proposed scope:

1. **Integrate the active lane.** Commit the uncommitted lane work, review it and merge it into `main`. This needs explicit approval; see "Integrating the lane" below.
2. **Finish Incident & Safety:** S7-1H → S7-3 → S7-4 → S8 → S9, each with its own approved ticket.
3. **Close the pending in-game checks** for M1a, M1b, S1–S7 using [IN_GAME_VALIDATION.md](guides/IN_GAME_VALIDATION.md).
4. **Fix the known test gap:** `tools/test_ui_smoke.lua` fails because `tools/fixtures/settings_baseline.lua` is missing. Do this as a deliberate change; do not create a substitute fixture.
5. **Release:** bump `Constants.lua`/`manifest.ini` version to `0.2`, update `CHANGELOG.md`, and do a manual install and rollback test.

M2 (driving phases) is the first candidate for v0.3.

## Rules for every milestone

Each milestone or slice gets a short ticket that the user approves before any edit. The ticket states:

1. The objective and the observable behavior, the relevant baseline, and the risks it reduces.
2. The **exact list of files** it may touch, including new files, tests and docs.
3. Exclusions: physics values, UI, persistence, callbacks, vendor code and installation unless they are listed.
4. Local and CSP acceptance criteria, who owns each piece of evidence, and the fallback when an API or data is missing.
5. A proportional validation plan and the known failures.
6. The branch/worktree and which Git operations are allowed. A commit or push for one step does not authorize the next.

Report every result with these labels: **executed**, **observed in CSP**, **limited**, **pending**. A milestone is done only when its required CSP evidence is recorded. Until then the status is "implemented and verified locally; runtime pending".

## Integrating the lane

The lane (`omos/incident-s2-validation`) still edits the old doc paths: `docs/plans/DEVELOPMENT_PLAN.md`, `docs/plans/INCIDENT_SAFETY_HANDOFF_PROMPT.md` and the new `docs/plans/AI_OBSERVABILITY_PLAN.md`. When it merges after this reorganization:

- Apply its `DEVELOPMENT_PLAN.md` and handoff changes to `docs/archive/`. Git rename detection usually does this on its own.
- Move `AI_OBSERVABILITY_PLAN.md` to `docs/archive/`.
- Update the milestone table above from its handoff section.
- Do not recreate `docs/plans/`.

## History

The detailed Portuguese decision log, including the per-ticket allowlists, evidence and CSP log excerpts, is kept unchanged in [archive/DEVELOPMENT_PLAN.md](archive/DEVELOPMENT_PLAN.md). The original long-form roadmap is in [archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md](archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md).
