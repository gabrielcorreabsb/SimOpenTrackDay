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
- [ ] **Install and rollback:** copy the folder over a backup, then restore the backup; settings are kept. Install **observed** (v0.2 loaded over the previous copy); rollback **not run**: skipped by the maintainer's decision on 2026-11-08.

## F1-1 — incident perception (branch lane, pending)

**Run 1 (2026-11-08, CSP 4305, Interlagos, ~20 AI): failed.** 394 of 395 off-track records showed `src=w:on l:off` for every AI car: the planar lateral check against `getTrackAISplineSides` was wrong, and the flood truncated the logger. Fixed in the lane:
- Off-track now uses CSP's normalized track coordinate (`ac.worldCoordinateToTrack().x`, cached per frame by `CarManager.getActualTrackLateralOffset`). Off = `wheelsOutside >= 3`, or `|x| > 1.02` with at least one wheel outside; the coordinate alone never reports off-track. In records, `l:off` now means beyond the edge.
- The planar bucket geometry is kept only for heading (spin/wrong-way) and the unsigned distance from the AI line (stopped band).
- Flood guard: at most one record per car and kind every 10 s, and 30 records per minute overall. The excess is reported as `kind=incident-perception-suppressed` with `suppressed=N`.
Contacts (3), one wrong-way and no false stopped in the pits were also seen in run 1; they need re-checking in run 2.

Contract: [issue #3](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues/3). This slice only observes; existing accident decisions remain unchanged. No F1-2 zones, caution or recovery behavior is added. The maintainer owns installation and every CSP check below; local compilation and mocks cannot check these boxes.

### Enable and read the logs

In the settings window's accidents section, select **Incident perception (log only)** next to **Handle accidents**. Clear the checkbox to disable observation again. The checkbox is available whether or not **Handle accidents** is enabled; it does not enable accident handling or OBS1.

The declared flag is `StorageManager.Options.IncidentPerceptionEnabled`; its stored field is `incidentPerceptionEnabled`, default `false`. The checkbox persists through the existing storage schema for the current track/session mode; no Lua command or manual INI edit is needed. The normal app enable/live gates still apply. Do not clear other settings.

Search the CSP log for `[F1-1]` and these exact kind fields:

- `kind=incident-perception-stopped`
- `kind=incident-perception-off-track`
- `kind=incident-perception-spin`
- `kind=incident-perception-wrong-way`
- `kind=incident-perception-contact`
- `kind=incident-perception-unknown`
- `kind=incident-perception-suppressed` (flood-guard summary)

The existing logger envelope still says `[OBS1]`; this does not mean OBS1 was enabled. `carRef`/`genRef` identify the subject, `resource=[F1-1] car=… s=…` gives spline progress, and `detail` carries the event duration. Contacts include `drop=…` (km/h), `n=…` (accepted touches) and the first other party in `extra`. Unknown records identify an unavailable field; absence of an event is not proof of safety. The shared logger has bounded output and can truncate a busy session.

### Maintainer scenarios

- [ ] **Toggle and flag off:** check the checkbox in English, Spanish and Brazilian Portuguese, with **Handle accidents** both off and on. Verify persistence for the current track/session mode. With perception off, normal app behavior and no F1-1 perception records.
- [ ] **Spin/off-track/stopped:** an AI incident produces an episode record with the car, spline position and duration; sustained conditions do not log every frame. A static sideways pose is not a spin: compare a greater-than-60-degree heading change, projected forward speed at most 10 km/h, sustained for 0.6 s, including near-zero-speed rotation. Off-track evidence sustains for 0.5 s.
- [ ] **Stopped thresholds:** below 5 km/h on track, compare the 2 s off-line base threshold, 8 s alone on the line (`|lateral| <= 1.5 m`) and 6 s with another stopped subject within 8 m. A distant stopped car must not shorten an isolated on-line car's timer. Cars arm only after reaching 5 km/h since reset. Verify the spline-distance filter on parallel sections and hairpins.
- [ ] **Wrong-way:** heading dot product below -0.5 for 1 s above 10 km/h produces one episode record; resuming forward travel rearms it.
- [ ] **Contact:** a contact between two AI produces one grouped incident record with measured speed drop over 0.6 s. Reciprocal observations are deduplicated; repeat touches within 1.5 s for the same pair are suppressed. Compare contacts within 15 m and 2 s, separated contacts, and contacts across the spline wrap.
- [ ] **Ten normal-driving minutes:** no false stopped record in the pit lane, pit box or at session start. Include cars that have not yet moved.
- [ ] **Missing data:** unavailable wheels/track-lateral/heading/contact data produces `unknown`, never a safe verdict; retain the corresponding logs. One known on-track source plus one unknown source must not start a stopped timer; positive off-track evidence can still report an episode.
- [ ] **Lifecycle:** pause/replay, app disable, session restart, jump and recycled indices do not finish stale timers or contacts. No perception writes to physics or controls occur.
- [ ] **Load:** 20–30 AI cars with the flag enabled; record frame-time impact separately from functional acceptance. Geometry initialization remains synchronous: up to 4096 buckets are sampled in a single update on first enable, re-enable or a session/track-length change. Record any initialization hitch separately from steady-state frame times, especially on long tracks. This cost has not been measured in CSP.

All items are **pending**. Thresholds are initial guesses. Geometry uses cached approximately 8 m spline buckets (maximum 4096), planar tangents and lateral distances; banking/elevation and tight corners need particular scrutiny. Spin history is initialized at the first valid heading sample and refreshed near alignment (within 20 degrees); initially sideways cars cannot establish that a spin happened before observation began. Contact groups compare circular spline distance with the first contact, so chains drifting beyond 15 m form separate groups. Groups report the maximum available participant speed drop, not individual impact severity. Player index 0 is not an observation subject, only a possible contact party. Fixed pools bound work (16 groups, 48 participant samples, 64 debounced pairs); exhaustion reports `field=poolCapacity` and can lose observations. These limits and actual CSP field behavior require in-game validation before acceptance.

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
