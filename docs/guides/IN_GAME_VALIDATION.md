# In-game validation checklist

This page lists every check that has been implemented and verified locally (syntax and headless/mock tests) but **not yet accepted in CSP**. A box is ticked only after the scenario was actually run in game, with its evidence recorded. Mocks, logs of queued transitions or a setter returning without error do not count.

Install, rollback and every in-game action are manual and are done by the user. Follow [INSTALL.md](INSTALL.md) and [TESTING.md §3–7](TESTING.md). There is no automated test suite since v0.2, so this checklist is the main evidence of behavior.

## Record for every session

Before testing, write down:
- the installed revision, plus any relevant local diff;
- the hashes of the installed files;
- the exact CSP build;
- the track/layout;
- the cars and grid size;
- the session mode;
- whether AI Flood is on;
- any other mods or controllers active, and any exclusivity assumptions.

Keep `custom_shaders_patch.log` and a video where it helps, and note the active time of each scenario. A current hash check does not certify the bytes that were loaded in the past.

Report each item as **observed**, **limited** or **pending**. Never round "limited" up to "pass".

## App loading and UI

- [ ] **Module-path bootstrap.** The app loads from `apps/lua/SimOpenTrackDay/` with stray same-named modules present in the AC root, and the five tabs render. Source: `__dirname` bootstrap, [incident](../archive/MODULE_LOADING_HARDENING.md).
- [ ] **Smoke test.** [TESTING §4](TESTING.md): the app enables, the window opens, and the log shows no Lua error.
- [ ] **UI and localization.** All items in [TESTING §8](TESTING.md):
  - three locales, with persistence;
  - widths of 80–1760 px;
  - window edges and resize, the Close control, and reopening;
  - stable IDs.
- [ ] **UI standardization.** Header font hierarchy, tab typography, the compact car list (`car.row.<index>`), and the native `Toggle`/`Slider` wrappers in all three locales and target widths. The first visual check failed (overlapping glyphs in pt-BR at about 1024 px), and the fixes are not yet re-checked. Source: [archive/UI_STANDARDIZATION.md](../archive/UI_STANDARDIZATION.md).
- [ ] **Dev inspector.** Test the Overview panel with `ENABLE_DEVELOPMENT_DEBUG_PANEL` both `false` and `true` (test copy only, new session):
  - 480/700/900 px in all three locales;
  - selecting the player, an AI car and a human car;
  - an empty session;
  - gates during pause, replay and disable;
  - TTL frozen while paused;
  - winner vs last setter.

## v0.2 closing session (minimum set)

Run these in one session to close v0.2. Everything else on this page stays **limited** or **pending** in the roadmap and does not block the release.

- [x] The CSP log shows `Checking SimOpenTrackDay v0.2` and `[F0-CSP-GATE] ... gate passed`. **Observed** 2026-11-08 (two sessions, CSP 4305, Interlagos).
- [x] **M1a:** the player and autopilot cars are never written (watch your own car while yielding/overtaking AI pass around you). **Observed** by the maintainer; the app never acted on car 0.
- [x] **M1a:** pause and replay: no AI change while paused or in replay, and normal behavior on return. **Observed**: log `mode=pause`, `mode=replay`, then zones handled again in live.
- [x] **M1a:** ten enable/disable cycles from the header, with no leftover speed limit, offset or hazard lights on the AI. **Observed** (5 cycles, log `mode=disabled`; no leftovers reported).
- [x] **M1b:** after a yield ends, the AI returns to its normal speed (the applied limit is released). **Observed** by the maintainer.
- [ ] **S1:** a session reset (or a car reset) removes every yellow zone of that incident. **Limited**: no session restart with an active zone appears in the 2026-11-08 log.
- [x] **S7-1/2:** a light touch creates no zone; a real contact creates one, and it disappears about 3 s after the cars are clear. **Observed**: 4 zones created and removed 4–5 s later; zones stay while a car remains stopped in them (known limitation, see F1-2/F1-4).
- [ ] **Install and rollback:** copy the folder over a backup, then restore the backup; settings are kept.

## M1a — player isolation and lifecycle

- [ ] Callback order and victim/player reset.
- [ ] Swap, Flood and index recycle; switching between AI and human control.
- [ ] Pause and replay with **no** actuation.
- [ ] Ten enable/disable cycles, with residue observed per control.
- [ ] Player and autopilot are never written.

Partial evidence: the per-car state came back after the `physics.allowed` cdata fix (CSP v0.3.0-preview675, 2026-10-22).

## M1b — top speed and throttle ownership

- [ ] Arbitration: requested vs applied value, and expiry.
- [ ] The global cap is removed without contaminating the per-car request.
- [ ] Release returns only the app's own requests.

## S1 — stale incident cleanup

- [ ] Shared victim plus a reset: every associated zone is removed, and an independent zone stays.
- [ ] normal → yellow → navigate → normal, observed separately from the terminal participants.
- [ ] A car stopped in the pit box without contact vs an actual contact in the pit lane.
- [ ] Pause, replay, disable and their return; session reset; recycled index; player/human/autopilot; stale events rejected.

## S2 — bounded incident stop

> The automatic stop after contact was later removed (policy change on 2026-10-25); these checks apply only to episodes that are still admitted.

- [ ] A real AI pair: the deadline counts active time; both cars leave the terminal state; the app's orders are released; the cars actually move again without a reset.
- [ ] Repeat with overlapping incidents, pause and return, a reset of one participant, and an independent incident.
- [ ] Record damage/obstruction, remaining yellow zones and intangibility separately.

## S3 to S7 (merged from the incident lane)

- [ ] **S3:** no collision disabling for cars passing through a yellow zone, navigating, or participating. Car #24 was observed intangible at the pit exit, cause not established.
- [ ] **S5-A:** cyclic geometry and zone selection at the 0/1 wrap. A positive basic smoke test exists; geometric acceptance is only partial.
- [ ] **S6-A:** an invalid reference does not lose identity.
- [ ] **S7-1 and S7-2:**
  - low-severity contacts create no zone;
  - a zone is removed after 3 s with no obstruction;
  - log lines stay within budget.
- [ ] **S7-1G (flag stays yellow after an accident):** reported 2026-11-08: HUD and track stayed yellow after the zone was removed, cars not slowing. After an accident, check the log for `[S7-1G] engine flag clear observed` (fixed) or `still Caution ... giving up` / `engine reports Caution while this app owns no flag override` (cause is elsewhere), and confirm visually that the flag clears.
- [ ] **S7-1F:**
  - The global Caution flag is released, with partial evidence. Pending: the user visually confirms that the flag does not stay yellow.
  - Pending: the zone-edge tolerance on the flag path.

## Behavior scenarios (all pending)

[TESTING §5](TESTING.md), scenarios 1–7: the simulation keeps running, performance with 20–30 AI cars, the Casual/Realistic/Competitive profiles, Hybrid mode, and anti-drag-race.

## Integration (S9, still to do)

- [ ] A session with 20–30 AI cars. Record the scenario, its duration and any observable overhead. Do not claim a performance budget from a functional test.
