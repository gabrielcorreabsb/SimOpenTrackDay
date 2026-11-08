# M0 audit: CSP capabilities available to the Lua App

> English translation of the original M0 audit (Portuguese, 2026-10-21). Every fact, line locator and evidence reference is kept. The locators point to the **audit baseline**, not to current `main`; line numbers have since moved, and since v0.2 runtime files live under `SimOpenTrackDay/` and the `tools/` scripts mentioned below no longer exist.

## Status, scope and provenance

- **Date:** 2026-10-21. **Code baseline:** `10ed904d2c2178e5d3c5ec3298d474c37e34ecbd`.
- **Result:** the source audit is complete. Whether the app can actually act on these APIs in game is **still pending**. This audit does not certify support for any CSP version.
- The original investigation only read the project and ran the local checks listed below. It did not implement milestones or touch installation, manifest, tools, dependencies or OpenCode config.
- The [original roadmap](../archive/SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md) is kept as hypotheses and backlog. Current sequencing is in [ROADMAP.md](../ROADMAP.md); the detailed decision log is in [archive/DEVELOPMENT_PLAN.md](../archive/DEVELOPMENT_PLAN.md).

Internal sources were consulted as needed and checked against the implementation: [rules](../../AGENTS.md), [README](../../README.md), [architecture](ARCHITECTURE.md), [FSM](STATE_MACHINE.md), [testing](../guides/TESTING.md), [workflow](../guides/WORKFLOW.md). Where historical descriptions disagree with the inspected code, the code wins.

### Four independent classes of evidence

| Class | Establishes | Does not establish |
| --- | --- | --- |
| **S — SDK** | Signature, fields and documented contract in the consulted SDK | Availability or permission in the installed game, or the real physical effect |
| **E — external example** | Another project uses it, at the given commit | That it works in SimOpenTrackDay, a licence to copy, or universal support |
| **P — project** | The current code calls or reads it (active, partial or inactive) | That the call has ever succeeded in game |
| **R — runtime** | A result observed in an identified scenario, installation and build | Generalization to other modes, cars, tracks or builds |

**R for the audited AI capabilities: pending.** The historical confirmation of 2026-10-18 covers only the recovery of UI loading after old modules were removed from the AC root. It does not prove physics or AI behavior, all tabs, or the later bootstrap. See the [module-loading incident](../archive/MODULE_LOADING_HARDENING.md).

### SDK and context

The bundled aggregate [sdk/ac_apps/lib.lua](../../sdk/ac_apps/lib.lua) (at audit time `lib/ac_apps/lib.lua`) came from local commit `d87be0d2de7280109bda25a5daeaa711bea4d468` (2026-04-26), labelled `v0.3.0-preview361`. This **does not identify the user's installed SDK or CSP build**. The compatibility submodule was at `7007085f48ad12a0bcf35eaed028691111a83697`.

The [official Lua Apps entry point](https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/7cf60f5a406820ee4e39f3a62ed121fa36274001/ac_apps.lua) imports the physics/AI modules with `withPhysics=true` and the `luatools` permission. It does not import the unrestricted module automatically. The native C++ implementations are not part of these Lua declarations. The local aggregate also loses part of the original per-context split, so a lone section marker does not prove whether a function belongs to car scripts or apps.

When `physics.allowed()` returns false, only `raycastTrack` is available, as documented. Permissions and behavior must be checked in the installed context; the existence of a symbol is not enough. The unrestricted module's notes about track opt-in **do not prove** that every AI call from the app needs `ALLOW_DISPLAY`, and they do not authorize modifying tracks.

## Target build update (2026-11-08)

The project now targets the latest CSP. The reference build is **0.3.2-preview2 (build 4305)**, read from the user's installed `extension/config/data_manifest.ini`. Its SDK (`extension/internal/lua-sdk/ac_apps/`) was copied byte-for-byte into `sdk/ac_apps/` (F0, issue #1; `lib.lua` sha256 `e599f16c…`, `README.md` sha256 `bf6193c7…`). The baseline line numbers in the tables below refer to the older copy. The app now fails closed below `Constants.MIN_CSP_BUILD = 4305` (see `[F0-CSP-GATE]` in the CSP log).

- **New relative to the previous repo copy:** `physics.overrideAIRequestedFuel`, `ac.onCarAIToggle`, `physics.setSuspensionDamage`, `physics.exportRacingLineAsync` / `importRacingLineAsync`, `physics.Collider`, `physics.offsetFinalFFB`.
- **AI APIs in both SDKs that the app does not use yet:** `setAIPitStopRequest` (since 0.3.0-preview147, `false` also blocks pitting for a short time), `setAITimeToStart`, `setAILapsToComplete`, `setAIRainTyres`, `setAILookaheadBase`, `setAILookaheadGasBrake`, `setAISteerMultiplier`, `setAIDriverName`, `setAISplineAbsoluteOffset`, `setAITyresHint`.

Evidence class: **S only** (source: SDK of build 4305). **R pending** for all of them. The baseline tables below are unchanged.

## Capability inventory

`lib.lua:<line>` references locate code in the baseline; they are not calls executed by this audit. For every row: **installed build unknown, R pending**.

| Domain and functions/fields | S / documented context | E | P at baseline | Risk and proposed fallback |
| --- | --- | --- | --- | --- |
| `ac.getSim`, `ac.getCar`, `ac.iterateCars` | Lua App; sim and car state | RARE, ApexFlow, ConditionReports | Active in loop/collection | The index is not a persistent identity. Use generation-tagged snapshots and treat invalid data as unknown |
| `physics.setAITopSpeed`, `setAIThrottleLimit`, `setAIBrakeHint` | SDK physics/AI; `lib.lua:14729–14749` | RARE/ApexFlow show AI controls | Top speed and throttle active; the hint is also on an experimental pedal path | Not full control of the AI. Disable the domain if unproven; do not invent a baseline |
| `setAILevel`, `setAIAggression`, `setAICaution`, `setExtraAIGrip` | SDK physics/AI; `14653–14780` | RARE/ApexFlow | Active in operations, init and FSM | Ranges and native values differ from the stored ones. Do not add grip to simulate weather or tyres |
| `setAISplineOffset`, `setAISplineAbsoluteOffset` | Normalized and metres respectively; `14756–14768` | ApexFlow | Normalized offset active | Track limits and native decisions still apply; no promise of an overtaking veto |
| `setAIStopCounter`, `setGentleStop`, `preventAIFromRetiring` | SDK physics/AI; counter in seconds; prevent-retiring is temporary | AI control examples | Active, including after incidents | Renewing them can keep a car stopped. Needs priority, expiry and bounded recovery |
| `setAIBrakeMistake`, `setAITractionMistake` | SDK physics/AI; duration and severity; `14797+` | Not needed to prove presence | Active in `HumanErrorManager` | No AI/pit filter and no reset of its own. Do not expand until isolation is validated |
| `disableCarCollisions`, `overrideRacingFlag` | SDK physics; `14508+`, `14588+` | Not needed to prove presence | Active in incidents/zones and the camera flag | Disabled collisions are not a general solution. `ac.FlagType.None` hands control back to native; it does not clear a native flag |
| `ac.setTargetCar`, lights, `ac.overrideCarControls` | SDK; the implicit target and controls can also reach the player | Examples do not prove isolation | Target and lights active; pedal overrides present | Define reach and ownership. Cross-script effects not demonstrated |
| `physics.setAIPitStopRequest` | SDK AI `14782–14785`; `false` suppresses going to the pit for a short time | RARE gates on patch code `>=2278` | No active pit integration | An external gate is not a universal minimum. Use a separate opt-in probe with timeout and observational fallback |
| `setAITyres`, `setCarFuel`, `setAILapsToComplete` | 0-based compound index, litres, laps; `14787–14795`, `14393+` | RARE/ApexFlow for tyres and fuel | No active service; fuel appears in the experimental AfterCustomFlood state; laps unused | Changing tyres also resets damage; setting fuel invalidates the lap. Never drain the tank or teleport as a fallback |
| `isInPitlane`, `isInPit`, `isAIGoingToPits`, `isRequestingPitStop`, `pitTransform` | `StateCar`, `4760–4850`; pit lane is an area, pit is the car's own box | RARE/ApexFlow read these states | Partial; no full lifecycle observer | Request, entry, box, service and exit must be separate events |
| `wheels[0..3]`, temperatures, `tyreWear`, pressure, damage, fuel | `StateWheel`/`StateCar`, `4652–5038`; physical availability varies | RARE/ApexFlow interpret wear; semantics not universal | Fuel, pedals and state partly consumed; no full monitor | Nil/NaN/missing sensors must not become zero. Pressure units and wear polarity need confirmation |
| `rainIntensity`, `rainWetness`, `rainWater`, temperatures, `roadGrip`, wind | `StateSim`, `5148+`; environment reading | ConditionReports | No integrated environment adaptation | Visual rain does not prove physical grip. Read neutrally when unavailable |
| `ac.ConditionsSet`, `ac.setConditionsSet2` | WeatherFX controller example; `setConditionsSet2` missing from the local App SDK | Official base controller | Absent | Do not offer weather generation from the app; that is a separate project/context if ever authorized |
| Physical mechanical failure and MRF channels | Car physics script and per-car contract, not a universal grid API | MRF publishes versioned channels | No MRF bridge | A virtual score must be labelled as such. Integrate only through a supported contract, without modifying cars |
| `ac.storage`, `ac.log/warn/error` | Persistence/debounce and logs in the SDK | No new backend needed | StorageManager and logs present | New keys go through the schema. Logs bounded/opt-in; no IO, cloud or per-frame output assumed |

### Contracts that shape the design

- **Top speed and throttle.** Top speed is in km/h; per the SDK, `math.huge` or `1e9` removes the limit. Throttle `1` removes its limit. Neither restores a limit set by another mod.
- **Brake hint.** This is an `ai.ini` hint, not an absolute pedal position. The file value can serve as a reference but is not a readback of current overrides.
- **AI level and aggression.** `setAILevel` accepts `0..2`, while `car.aiLevel` documents `0..1` or `-1`. Aggression accepts `0..1`, with the launcher adjustment described in the SDK. Do not confuse read and write ranges without checking.
- **Caution and grip.** Caution is experimental (`0..16`, documented default `1`). Extra grip documents `1` as normal grip and 120% by default. So **writing `1` does not prove the native baseline is restored**.
- **No getters for current overrides.** None were found for top speed, throttle, caution, grip, brake hint or offsets. Shadow state records only what this app wrote; it cannot reliably detect another mod or recover unknown native values.
- **Pit and tyre calls.**
  - `preventAIFromRetiring` is temporary and must be repeated.
  - `setAIPitStopRequest(false)` is not a permanent cancel.
  - `setAITyres` also resets damage.
  - A call without an error does not prove the tyres were actually changed or that service completed.
- **Player protection.** `isAIControlled` includes autopilot, so policy must protect the player explicitly (including index 0) instead of relying on that flag alone.
- **Uncertain fields.**
  - `isRefueling`, `isChangingTyres` and `isRepairing` are typed `string` in the aggregate; their type and validity need checking.
  - `fuelPerLap` depends on physics, and `getCarPhysics().isAvailable` matters.
  - A brake temperature of zero may mean the value is unavailable.
- **Tyre wear.** The SDK describes `tyreWear` as `0..1` without defining its polarity. Comments and thresholds in other mods are not a substitute for per-build/per-car calibration.
- **Pit path.** `hasTrackSpline`, coordinates/progress and track sides do not prove a drivable `pit_lane.ai` or a valid box. `setAISpline` replaces the spline, so it is **not** a safe way to inspect the pit path. No documented API was found that is sufficient to certify the pit path.

## External evidence and licences

These sources were read, **not executed in CSP**. No code was incorporated. A build gate or comments in another mod are not universal SDK contracts.

| Pinned source | Evidence and limits |
| --- | --- |
| [RARE: ai.lua, 68cfc1c](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements/blob/68cfc1c1005090b16c7d3df5722d5ce6427c079e/RARE/src/controllers/ai.lua) | AGPL-3.0 (verified).<ul><li>The pit request is gated on `>=2278`.</li><li>On older builds the fallback reduces fuel to `0.1`; this practice was not adopted.</li><li>It marks pit state when the request is sent, without proving entry or the full cycle.</li></ul> |
| [ApexFlow: race_strategy.lua, e57bc4a](https://github.com/Silxyst/ApexFlow/blob/e57bc4ade9b9e5f7e449013541b2345dd4254ef6/src/race_strategy.lua) | MIT (verified).<ul><li>The strategy forces a pit stop through fuel; it does not demonstrate `setAIPitStopRequest`.</li><li>"Pit lane OR pit" does not prove a stationary box.</li><li>Tyre use also depends on a gate/build.</li></ul> |
| [ConditionReports, 138ab68](https://github.com/otherchriso/AC_ConditionReports/tree/138ab680973e6f2f73d1182cc96e7edc5000e8e0) | An example of reading conditions, including `rainWetness`. It does not prove the app can write weather. |
| [MRF, 62a19c8](https://github.com/cvr-admin/gec_feature_script/tree/62a19c863eff6d088dc96c5d46cd74ad2d968a5b) | MIT (verified).<ul><li>The car script publishes contracts such as `cvr.pitCrew.tyres.v1`, `roadside.v1`, `status.v2`, `fuelStatus.v1` and `serviceStatus.v4`, keyed by car index.</li><li>This is not universal mechanical support; do not interpret CPHYS channels arbitrarily.</li></ul> |
| [Base weather controller, 3cfd56f](https://github.com/ac-custom-shaders-patch/acc-extension-config/blob/3cfd56f97cb60075594aca8b19653ddb197478fd/weather-controllers/base/controller.lua) | Shows conditions being set in the weather-controller context, which is separate from the Lua App. |

Keep the project's [MIT licence](../../LICENSE) and Andreas Grech's copyright.
- Full Send (GPL) and RARE (AGPL) need a compatibility decision before any reuse.
- Public sources, or licences claimed in the roadmap, do not automatically authorize copying.

## Findings in the code (at baseline)

These priorities are for planning; they do not authorize fixes. Locators refer to the baseline, and **residual physical effects were not measured in game**. Short state names refer to the `CarState_*.lua` files in [CarStateMachine/States](../../SimOpenTrackDay/CarStateMachine/States/). Findings A01–A05 were later addressed in M1a/M1b/S1/S2 (see [ROADMAP.md](../ROADMAP.md)), with CSP acceptance pending.

| ID / priority | Evidence in code | Risk / next step |
| --- | --- | --- |
| A01 — high | <ul><li>`SimOpenTrackDay.lua:272,458–462` initializes before the AI filter.</li><li>`CarManager.lua:159–225` writes controls.</li><li>`HumanErrorManager.lua:16–30` does not filter AI/pit.</li><li>`AccidentManager.lua:193–195` can reach victim 0.</li></ul> | Player protection is incomplete. M1a must cover init, callbacks, incidents and errors, not just the FSM. |
| A02 — high | `SimOpenTrackDay.lua:303–309,409–415`:<ul><li>disable returns without a central cleanup;</li><li>there is no replay gate;</li><li>pause runs before the queue is drained, while callbacks at `360–375` keep enqueuing.</li></ul> | Writes are not explicitly released on disable, and their real duration depends on each API. Avoid stale queues and define a pause/replay policy. |
| A03 — high | <ul><li>Session start (`377–381`) only notifies the timer.</li><li>Baselines (`286–296`) are captured once.</li><li>Jumped (`337–357`) does not clear HumanError state.</li><li>Caches are keyed by index.</li></ul> | A recycled index can inherit state. Needs generations per session and car, rejection of stale events, and a baseline captured before writing when available. |
| A04 — high | <ul><li>`CollidedWithCar` and `AnotherCarCollidedIntoMe` have empty transitions.</li><li>`CarOperations.lua:429–437` repeats zero throttle/top speed, stop, gentle stop and caution.</li><li>The Yellow exit only resets speed and lights.</li><li>The Navigate exit does not restore collisions.</li></ul> | Some paths have no explicit recovery or cleanup. Stabilize incidents early, once the lifecycle and ownership base exists. Do not assume that blindly enabling collisions is safe with Flood or other mods. |
| A05 — high | `SimOpenTrackDay.lua:507–509` caps speed, and `CarOperations.lua:215–224` stores the applied value in `cars_aiTopSpeed`. | Sticky feedback: the global cap of 100 can persist in the per-car value after the cap is removed. Separate requested from applied (M1b). |
| A06 — medium/high | `CarState_DrivingNormally.lua:96` calls `driveSafelyToSide`. `CarOperations.lua:571` applies `DRIVING_TO_THE_SIDE=1.3` if that path proceeds. | Extra grip already exists in normal driving. Do not present the baseline as neutral physics, and do not add another multiplier for cold tyres or rain. |
| A07 — high | <ul><li>The compatibility manager checks symbols.</li><li>`SimOpenTrackDay.lua:142–149` logs an error, but the blocking return is commented out.</li><li>`setAILevel` is active without a matching registration.</li><li>`physics.allowed` is not consulted.</li></ul> | Registration or existence is not a functional gate. Keep the modal false. Plan per-domain capabilities, where a missing capability leads to safe mode. |
| A08 — medium | HumanError uses `probability * dt`, a cooldown and per-index timers, with no dt validation, no pit/player filter and no reset of its own. | It already approximates dt dependence; it is not wholly un-normalized. Test invalid dt, 30/60/120 Hz, cooldown and generations, without adding more artificial errors. |
| A09 — medium | <ul><li>`BehaviorPolish` is loaded but its helpers have no consumers.</li><li>Inline defence has no entry transition.</li><li>The custom Flood `require` is disabled, and AfterCustomFlood depends on that path.</li><li>The anti-drag helper has no caller.</li></ul> | Existing settings and modules do not demonstrate integrated behavior. Integrate only after the base exists, and do not promise that the 95% anti-drag is active. |
| A10 — medium | Storage is captured at load. `StorageManager.lua:650–663,725–786` uses track/mode and partial profile inference. | Re-evaluate identity and storage when the session changes. Do not use the nonexistent `behavior.profile` or claim reliable inference for every combination. |

### Interpretation corrections

- **Lateral avoidance is not integrated.** Steering via `CollisionAvoidanceManager`/`driveSafelyToSide` in `CarState_NavigatingAroundAccident.lua:123–144` is **commented out**. There is no basis for reporting an active nil crash in that code, or for claiming lateral avoidance is integrated.
- **Pathfinding is loaded but unused.** It has no effective caller, and the `PATHFINDING_DEBUGGING` flag described in the architecture doc does not exist at baseline. Do not re-enable experimental modules to match documentation.
- **Diagnostics.** The startup `[RTD-DIAG-*]` records were removed (`fb96a16`); `AGENTS.md` was aligned on 2026-11-08. **Do not reintroduce diagnostics**. `ShowErrorModalDialog = false` remains intact.
- **Profiles.** BehaviorPolish fields and manual profile application do not mean every parameter is consumed. Partial profile inference does not guarantee equivalent settings.
- **Target car.** `ac.setTargetCar` changes the implicit target and may not be restored in its own context. Global interference between scripts was not demonstrated.

## Checks run during M0

These are historical results at the baseline above:

| Check | Result | Limit |
| --- | --- | --- |
| `tools/check_lua_syntax.ps1`, LuaJIT `2.1.1720049189` | PASS, 85 files | Compiles without executing. Excludes SDK, submodule and backups; includes `lib/uilib` |
| `test_lateral_layout`, `test_localization`, `test_logo_smoke`, `test_main_window`, `test_native_controls`, `test_no_diagnostics`, `test_settings_model`, `test_settings_navigation`, `test_ui_controls`, `test_ui_manager`, `test_version` | 11 PASS | Contract, mock and static checks of the exercised paths. They do not prove AI, rendering or physics |
| `tools/test_ui_smoke.lua` | FAIL while loading, at line 10 | The fixture `tools/fixtures/settings_baseline.lua` is missing; it was not created or fixed |
| `tools/test_module_path.lua` | Not run in M0; code inspected | Creates a temporary sandbox; historical evidence from another stage is not counted |
| Package/installer/distribution PowerShell | Not run in M0 | No installation, rollback or package test |
| CSP / in-game | Not run in M0 | No audited call reached R status through mocks or reading |

## Future runtime verification protocol

Every result must identify:
- the installed revision;
- the exact CSP build/patch code;
- the Lua App context;
- the track/layout;
- the cars and their count;
- the session mode;
- Flood;
- the weather controller;
- any other active mods.

Record separately: symbol available, permission, call, observed effect, duration and release. **A call without an error does not mean functional support.**

1. Take a baseline with no new actuation: queues, contacts per 100 car-km, stops, fraction unknown, mean/p95 CPU and GC. Do not promise numeric targets before this is measured.
2. Compare Track Day with Practice/Race, a track with and without a known pit path, reset/Flood, and index changes. A car index is not a persistent identity.
3. Check that the player is protected, replay, and ten enable/disable cycles. Record residue per control, including controls with no readback, and do not claim full cleanup without observing it.
4. **Pit:**
   - Distinguish intent, request, entry, box, sustained immobility, service and exit.
   - Confirm the states, a valid `pitTransform` when available, and sensor changes.
   - On timeout, fall back to a safe/observational state; never drain fuel or teleport.
5. **Tyres and weather:**
   - Confirm compound, wear and an actual tyre change per build and car, without turning NaN or missing values into zero.
   - For weather, validate the reported data without doubling grip effects and without modifying Pure/Sol.
6. Preserve the installation and settings. Test copies and rollback are manual and need authorization. Logs must be bounded, relevant to the scenario, and must not publish personal data.

## Feasibility answers

- **Pit and tyres.** The pit request and the tyre change have an SDK contract and examples. Track Day support, full service and a build matrix are still pending.
- **Top speed, throttle and hints.** These have several writers in the project, and their effectiveness per mode and with Flood is not guaranteed.
- **Sensors.** They allow observation with explicit data quality, not universal wear semantics.
- **Pit box and pit path.** A stopped box needs combined evidence, and a found API is not enough to certify the pit path safely.
- **Baselines and other mods.** Unknown baselines rule out generic restoration. A coexisting mod may require **MonitorOnly** rather than invented conflict detection.

At the time of M0:
- BehaviorPolish was not integrated.
- HumanError approximated dt but had incomplete isolation and reset.
- Lifecycle, cache and storage needed per-generation identity.
- Do not duplicate native tyre or rain physics, and do not assume MRF on cars without a contract.
- The local suite was not fully green and did not cover in-game AI behavior.
