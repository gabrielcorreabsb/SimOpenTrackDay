# Roadmap

This file is the single source for **where the project stands and what comes next**. It is a plan, not a description of shipped behavior. Anything not marked done here is not implemented or not accepted.

**Vision:** a living, offline track day. AI drivers behave like people sharing a track: each has a personality, they warm up, push and cool down, yield and overtake with intent, slow for incidents and recover from their own mistakes, and come in and out of the pits in stints. It is built on the CSP Lua API, and the native AI keeps its own driving decisions. We take the best ideas from current AC AI projects (see [prior art](reference/PRIOR_ART.md)), re-implement them clean-room and adapt them to a track day rather than a race.

**Non-goals:**
- races, sporting penalties or blame systems;
- mandatory point-by;
- a universal ban on overtaking;
- pit service on every track;
- universal physical mechanical failures;
- teleporting cars by default.

**CSP target:** the latest Custom Shaders Patch. The reference build today is **0.3.2-preview2 (build 4305)**. Older builds are not a design constraint. A minimum-build gate (F0) keeps the app inert on builds that lack the required APIs. The repo copy of the SDK in `sdk/ac_apps/` predates this build, and refreshing it is an F0 ticket.

**Status vocabulary**
- **Done:** delivered, reviewed and accepted in CSP.
- **Local:** implemented and verified locally (syntax, headless/mock tests); runtime/CSP acceptance pending. Mocks do not prove CSP behavior.
- **Lane:** work in progress on a branch/worktree, not yet on `main`.
- **Open:** not started.

Last reconciled: 2026-11-08. This replaces the M0–M9 / S1–S9 plan with vision-first phases. The old IDs are mapped below so that the history and evidence stay traceable.

## Cross-cutting rules

- Observe before you actuate. Fail closed when an API or data is missing.
- Every new behavior is off by default until it is accepted in CSP.
- Never invent physics: no grip added to fake weather or tyres, no fuel drain, no teleport by default.
- No allocations in per-frame paths. Car state stays in indexed DoD tables.
- Each domain has a coexistence mode (`Disabled` / `MonitorOnly` / `Control`) so the app can run alongside other AI mods without fighting over the same parameters.
- No code is copied from projects whose licence does not allow it (see [prior art](reference/PRIOR_ART.md)).

## Phases

| Phase | Vision (what the player sees) | Main scope | Absorbs | Status |
| --- | --- | --- | --- | --- |
| **F0** Validate the base | The current app is safe, observable and runs cleanly on the target CSP | Refresh the SDK to build 4305; minimum-build gate; close the pending in-game checks; read-back watchdog for values another mod overwrites; evaluate `ac.onCarAIToggle` for player/autopilot isolation; v0.2 release | M0, M1a, M1b, S1–S7 (Local), S2-D, S3, OBS1–3, S4, S5-A, S6-A, S7-1/2/1F/1G | **Local**, CSP acceptance pending |
| **F1** Safe incident | A crash slows the cars behind locally, they go around it, and the crashed car gets going again on its own | Obstruction detection before contact; real lateral avoidance (`setAISplineAbsoluteOffset`); local yellow only (zones + speed cap, no global flag); spin and wrong-way detection; contact grouping; self-recovery without teleport (back off walls, wait for a gap to rejoin); learned per-track incident hotspots that feed caution only | S7-1H, S7-3, S7-4, S8, S9 | **Open** |
| **F2** Traffic and pace | Traffic feels organic: out lap, warm-up, push laps and cool-down; faster classes come through cleanly | Gap/TTC with history and hysteresis; per-car driving phases; car class detection for mixed grids; cold-tyre and dirty-air behavior through existing AI parameters only; slow lap-to-lap pace drift | M2, M4 | **Open** |
| **F3** Personalities | Every driver is different: the careful novice, the consistent regular, the impatient hotshot | Seeded per session and identity; attributes (skill, consistency, awareness, patience, aggression); mistakes scaled to pace on top of `HumanErrorManager`; presets such as Mixed Trackday; optional driver names (`setAIDriverName`); real consumers for `BehaviorPolish` | M3 | **Open** |
| **F4** Pit and session | Cars run stints, come in, sit in the box and leave at staggered times | Pit observer with separate request / entry / box / service / exit events; stints via `setAILapsToComplete` / `overrideAIRequestedFuel`; staggered pit exits via `setAITimeToStart`; `setAIPitStopRequest` as an opt-in probe; a "Session" view | M5, M6 | **Open** |
| **F5** Conditions and logbook | Rain makes drivers more careful; the session ends with a debrief | Rain adapter (`rainWetness`) with hysteresis that adjusts caution and `setAIRainTyres` only, never grip twice; tyre reading that stays neutral on nil/NaN; session logbook; hotspot map view; v1.0 consolidation (support matrix, benchmark, packaging) | M7, M8, M9 | **Open** |

The global Caution flag stays disabled (`ENABLE_GLOBAL_CAUTION_FLAG = false`). In CSP, `physics.overrideRacingFlag(Caution)` left `sim.raceFlagType` stuck on Caution. It is not retried without a new approach and an in-game test.

Feature ideas behind each phase are in [BACKLOG.md](BACKLOG.md).

## v0.2 = closing F0

v0.2 is complete when the existing AI behavior is safe and observable on the target CSP. New realism systems are not part of it.

1. ~~Integrate the incident lane~~: done (`04b2bd7`).
2. ~~Repository layout~~: done. The copied folder was smoke-tested in game on 2026-11-08 (app loads and works).
3. **Refresh `sdk/ac_apps/`** from the build 4305 SDK (a vendor update with its own ticket) and add the minimum-build gate.
4. **Close the pending in-game checks** for M1a, M1b and S1–S7 using [IN_GAME_VALIDATION.md](guides/IN_GAME_VALIDATION.md).
5. **Release:** bump the `Constants.lua`/`manifest.ini` version to `0.2`, update `CHANGELOG.md`, and do a manual install and rollback test.

F1 is the first phase for v0.3.

## Rules for every phase slice

Each slice gets a short ticket that the user approves before any edit. The ticket states:

1. The objective and the observable behavior, the relevant baseline, and the risks it reduces.
2. The **exact list of files** it may touch, including new files, tests and docs.
3. Exclusions: physics values, UI, persistence, callbacks, vendor code and installation unless they are listed.
4. Local and CSP acceptance criteria, who owns each piece of evidence, and the fallback when an API or data is missing.
5. A proportional validation plan and the known failures.
6. The branch/worktree and which Git operations are allowed. A commit or push for one step does not authorize the next.

Report every result with these labels: **executed**, **observed in CSP**, **limited**, **pending**. A phase is done only when its required CSP evidence is recorded. Until then the status is "implemented and verified locally; runtime pending".

## History

Before 2026-11-08 the plan used milestones M0–M9 and the Incident & Safety slices S1–S9. The mapping is in the table above. The last state of that plan: M0, M1a, M1b, S1, S2 and the S2-D…S7-1F slices were **Local** and merged into `main` (`04b2bd7`, then S7-1G `3bdf7bc`); S7-1H, S7-3, S7-4, S8, S9 and M2–M9 were **Open**.

The detailed Portuguese decision log through S7-1F (2026-10-29), including the per-ticket allowlists, evidence and CSP log excerpts, is kept in [archive/DEVELOPMENT_PLAN.md](archive/DEVELOPMENT_PLAN.md), with the observability plan in [archive/AI_OBSERVABILITY_PLAN.md](archive/AI_OBSERVABILITY_PLAN.md). File paths and `tools/` tests mentioned there predate the v0.2 layout. The original long-form roadmap is in [archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md](archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md).
