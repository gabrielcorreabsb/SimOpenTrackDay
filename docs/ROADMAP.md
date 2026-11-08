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

**CSP target:** the latest Custom Shaders Patch. The reference build today is **0.3.2-preview2 (build 4305)**. Older builds are not a design constraint. A minimum-build gate (F0) keeps the app inert on builds that lack the required APIs. The repo copy of the SDK in `sdk/ac_apps/` is taken from that build.

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
3. **Refresh `sdk/ac_apps/`** from the build 4305 SDK and add the minimum-build gate ([issue #1](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/1)): **observed in CSP** on 2026-11-08 (build 4305: `[F0-CSP-GATE] build=4305 min=4305 gate passed`, then `mode=live`). The forced-failure check (`MIN_CSP_BUILD` above the installed build) is still **pending**.
4. **Close the pending in-game checks** for M1a, M1b and S1–S7 using [IN_GAME_VALIDATION.md](guides/IN_GAME_VALIDATION.md).
5. **Release:** version set to `0.2` in `Constants.lua`/`manifest.ini` and `CHANGELOG.md` (branch `docs/close-v0.2`). Pending: the [v0.2 closing session](guides/IN_GAME_VALIDATION.md#v02-closing-session-minimum-set) in game, including install and rollback, then merge and tag `v0.2`.

F1 is the first phase for v0.3.

## F1 slices (v0.3)

Each slice has its own GitHub issue, using the ticket format below, and stays **Open** until that ticket is approved. Rules for every slice:
- Every new write goes through arbitration.
- Each slice has its own flag, off by default, declared in the `StorageManager` schema.
- No per-frame allocations.
- Logs go through `Logger.observe`.
- UI text uses msgids.

| Slice | Objective | Depends on | Absorbs | Status |
| --- | --- | --- | --- | --- |
| **F1-0** Conflict watch + AI toggle | Read back `aiLevel`/`aiAggression` after the app writes them and log when another writer changes them (observation only); evaluate `ac.onCarAIToggle` to clear a car's state when it switches between AI and human | — | F0 leftovers | **Open** ([#2](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/2)) |
| **F1-1** Incident perception | Observation only, per car: stopped timer, off-track (`wheelsOutside`, lateral vs `ac.getTrackAISplineSides`), spin and wrong-way (heading vs track tangent), contact on the rising edge of `collisionDepth` with the measured speed drop, and grouping of nearby contacts into one incident. Remove the per-frame table allocation in the lateral-offset cache | — | S7-3 (detection) | **Open** ([#3](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/3)) |
| **F1-2** Local zones + arbitrated caution | Single-car incidents (spun or stopped on track) also create zones; caution joins the owner/priority arbitration, which resolves the yellow 3 / navigate 0 / stop 16 conflict; decide the fate of the dormant incident stop and the `COLLIDED_*` states; bucket-based lookup for upcoming accidents | F1-1 | S7-1H, S8 | **Open** ([#4](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/4)) |
| **F1-3** Real lateral avoidance | Detect an obstruction before contact (slow car ahead in my lateral band for about 2 s), pick the free side from the track edges, and steer through a new lateral-offset arbitration (accident > yellow > traffic) with slew and a smooth transition, using `setAISplineAbsoluteOffset` (metres); return to the line once past by 10 m or more | F1-2 | S7-3, S7-4 | **Open** ([#5](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/5)) |
| **F1-4** Self-recovery without teleport | monitor → hold → wait for a gap → release → verify motion. A stuck car is held while traffic approaches and released when the gap is clear; it is handed back to AC after a timeout. Reversing off a wall is behind an experimental flag. Repositioning stays out of scope (a future opt-in) | F1-1, F1-2 | S2 (revised) | **Open** ([#6](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/6)) |
| **F1-5** Incident hotspots | A learned per-track map (about 24 m bins, upstream spreading, decay, cap) stored through `StorageManager`; near a hotspot it only raises caution, bounded, through the caution arbitration | F1-1, F1-2 | — | **Open** ([#7](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/7)) |
| **F1-6** Integration | Joint in-game validation, roadmap and changelog; closes F1 / v0.3 | all | S9 | **Open** ([#8](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/8)) |

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
