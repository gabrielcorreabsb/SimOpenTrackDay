# ARCHITECTURE.md — Architecture Map

> A dense code map for **developers** and **AI agents** who will modify the app.
> Use the project instructions for onboarding as needed; this document explains how the pieces fit together.

Scope: **LuaJIT 2.1 / Lua 5.1** app loaded by **CSP** as `apps/lua/SimOpenTrackDay/manifest.ini`. API compatibility is checked by the entry point; runtime behavior and in-game appearance are not validated by this map.
Entry point: `SimOpenTrackDay.lua`. `manifest.ini` registers these callbacks:

| Callback | Location | Role |
| --- | --- | --- |
| `MANIFEST__UPDATE(dt)` | `SimOpenTrackDay.lua` | **Per-frame core**: physics and decision-making for all cars |
| `MANIFEST__FUNCTION_MAIN(dt)` | `SimOpenTrackDay.lua` | Main window (ImGui) |
| `MANIFEST__FUNCTION_SETTINGS()` | `SimOpenTrackDay.lua` | Settings window |
| `MANIFEST__FUNCTION_ICON()` | `SimOpenTrackDay.lua` | Vector drawing of the OTD icon |
| `MANIFEST__TRANSPARENT(dt)` | `SimOpenTrackDay.lua` | World-space overlay (overhead text, car name) |

---

## 1. Overview

### 1.1 Per-frame flow (ASCII)

```
 manifest.ini [SIM_CALLBACKS] UPDATE
        │
        ▼
 script.MANIFEST__UPDATE(dt)              SimOpenTrackDay.lua
        │  shouldAppRun()? no → return
        │
        ├─ GameTimeManager.update(dt)
        │  sim.isPaused?   yes → return
        ├─ CarManager._currentFrameId += 1  ← invalidates lateral/frame cache
        ├─ SessionDetails.update(dt)
        ├─ CameraManager.getFocusedCarIndex()
        │     └─ RaceTrackManager.isSplinePositionInYellowZone(pos)
        │           └─ RaceFlagManager.set/removeRaceFlag(Caution)
        │
        ├─── carList = CarManager.cars_currentReusableList
        │        table.clear(carList)  ← reuse, no allocation
        │        for i, car in ac.iterateCars() do
        │             CarManager.ensureDefaults(car.index)
        │             CarManager.saveCarSpeed(car)  ← speed buffer
        │             CarStateMachine.setReasonWhyCantYield/Overtake(None)
        │        end
        │
        ├─ sortedCars = CarManager.sortCarListByTrackPosition(carList)
        │        └─ incremental insertion sort (see §2)
        │
        ├─ OnCarEventManager.processQueuedEvents()
        ├─ CarStateMachine.handleQueuedAccidents()
        ├─ HumanErrorManager.update(dt, sortedCars, storage_Behavior, t)
        │
        ├─ for i = 1, #sortedCars do
        │     CarManager.sortedCarList_carIndexToSortedIndex[carIndex] = i
        │     if car.isAIControlled then
        │         CarStateMachine.updateCar(carIndex, dt, sortedCars, i)
        │             └─ current state → states_transitionFunctions → states_updateFunctions
        │                    └─ (yield/overtake) → CarOperations.driveSafelyToSide(...)
        │                          └─ physics.setAISplineOffset(...)   // consumes the lateral offset
        │         CarOperations.setAITopSpeed(carIndex, min(requested, global))
        │     end
        │  end
        │
        ├─ RaceTrackManager.updateYellowFlagZones()
        └─ debug override (optional, storage_Debugging)
```

### 1.2 Subsystems (one-line responsibility)

**Core (modify behavior):**

- `SimOpenTrackDay.lua` — CSP bootstrap, bindings, callback registration, per-frame loop (`MANIFEST__UPDATE`), entry UI.
- `CarManager.lua` — DoD state by `carIndex`, defaults, speed sampling, lateral offset cache, incremental car-list sorting.
- `CarOperations.lua` — `physics.*` wrappers + drive/yield/overtake, blockage raycasts, anchor points, anti-drag-race, teleport.
- `CarStateMachine/CarStateMachine.lua` — central per-car FSM: `states_entryFunctions` / `states_transitionFunctions` / `states_updateFunctions` / `states_exitFunctions`.
- `CarStateMachine/States/*.lua` — implementation of each state (see `docs/STATE_MACHINE.md`).
- `StorageManager.lua` — options DoD (enum → collection → fillInDoDTables → storageTable → `ac.storage`) + behavior profiles.
- `SettingsWindow.lua` — settings UI (ImGui), slider sections (Global/Debugging/AI Car Values/Yielding/Overtaking/Behavior/Pathfinding).
- `UIManager.lua` — per-car debug table, overhead text, lateral-offset section (preview).
- `RaceTrackManager.lua` — track metadata (name/length/session), yielding/overtaking sides, yellow-zone buckets.
- `BehaviorPolish.lua` — **pure** helpers: phase blend (`lerp`), hesitation (`shouldReactNow`), and noisy look-ahead (`confidenceFromPaceObservations`). The module is loaded, but these helpers have no call sites in the current runtime flow.
- `HumanErrorManager.lua` — triggers `physics.setAIBrakeMistake` / `setAITractionMistake` probabilistically and with a cooldown.
- `RaceFlagManager.lua` — `setRaceFlag`/`removeRaceFlag` (caution flag via `physics.overrideRacingFlag`).
- `AccidentManager.lua` — accident registration + yellow zones + navigation around them; `simulateAccident*()`.

**Experimental / disabled:**

- `Pathfinding.lua` — lateral paths in blocked situations. **Required by the entry point**, but runs only with `Constants.PATHFINDING_DEBUGGING`. Does not affect production.
- `FrenetAvoid.lua` — minimal Frenet planner. `require` is **commented out**. Disabled.
- `CollisionAvoidanceManager.lua` — `computeDesiredLateralOffset` around an accident. `require` is **commented out**. Disabled.
- `CarSpeedLimiter.lua` — pedal-slew limiter (works around the `setAITopSpeed` limitation). `require` is commented out.
- `CustomAIFloodManager.lua` — AI Flood teleport/cycle. `require` is commented out.
- `Profiler.lua` — hierarchical profiler (begin/end, sampling). `require` is commented out; **never used in production**.

**Support (rarely the focus of AI changes):**

- `OnCarEventManager.lua` — `Collision`/`Jumped` event queue; enqueues and processes once per frame.
- `GameTimeManager.lua` — accumulated game time; basis for cooldowns (e.g. `HumanErrorManager`).
- `SessionDetails.lua` — time since the session started; used to defer yield/overtake.
- `CameraManager.lua` — car focused by the camera (used by yellow-flag logic).
- `Strings/` + `StringsManager.lua` — debug text (reason why cant yield/overtake, state exit reason).
- `DataStructures/` — `QueueManager`, `StackManager`, `DequeManager`, `CompletableIndexCollectionManager`.
- `VecPool.lua` — temporary `vec3` singleton (`getTempVec3`).
- `MathHelpers.lua` — allocation-free vector/scalar helpers.
- `ColorManager.lua`, `AppIconRenderer.lua`, `UIOperations.lua`, `UILateralOffsetsImageWidget.lua`, `UIAppNameVersionWidget.lua` — UI.
- `Constants.lua`, `Logger.lua`, `Enum.lua` — constants, logging, and bit-flag helpers.
- `lib/ac_apps/` — CSP SDK (vendor; do not edit as app code). `lib/AssettoCorsaCSPLuaCompatibilityManager/` is the compatibility submodule and should be updated deliberately. `lib/uilib/` is a project-owned library and should not be confused with vendor code.

### 1.3 `require` order (important!)

`SimOpenTrackDay.lua` loads modules in this order: `Constants` → `Logger` → `CSPCompatibilityManager` → `VecPool` → DataStructures → `GameTimeManager` → `AppIconRenderer` → `ColorManager` → `RaceTrackManager` → `StorageManager` → `MathHelpers` → `CarManager` → `CarOperations` → `CameraManager` → `Strings*` → `StringsManager` → `OnCarEventManager` → `CarStateMachine` → `States/*` → `AccidentManager` → `RaceFlagManager` → UI → `SessionDetails` → `Pathfinding` → `BehaviorPolish` → `HumanErrorManager` → `SettingsWindow`.

Reason: **several modules capture storage at load time**, e.g. `CarStateMachine/CarStateMachine.lua`:
```lua
local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Debugging = StorageManager.getStorage_Debugging()
```
Therefore `StorageManager` must be required before them. Do not reorder without checking load-time captures.

---

## 2. Hot paths (per frame)

Optimizations already applied — **preserve them** when making changes.

### 2.1 Actual lateral offset cache

`CarManager.getActualTrackLateralOffset(carIndex, carPosition)` (`CarManager.lua`):
```lua
local cached = CarManager.cars_lateralOffsetCacheByCar[carIndex]
if cached and cached.frameId == CarManager._currentFrameId then return cached.x end
-- only here call the expensive API:
local carTrackCoordinates = ac.worldCoordinateToTrack(carPosition)
CarManager.cars_lateralOffsetCacheByCar[carIndex] = {x = carTrackCoordinates.x, frameId = CarManager._currentFrameId}
```
- `CarManager._currentFrameId` is incremented **once** per `MANIFEST__UPDATE`.
- Rule: **call `ac.worldCoordinateToTrack` only on a cache miss.** Multiple call sites (`isCarDrivingOnSide`, side checks) depend on this.

### 2.2 Reusable car list

`SimOpenTrackDay.lua`:
```lua
local carList = CarManager.cars_currentReusableList
table.clear(carList)
```
- **Never** assign `carList = {}` per frame. `cars_currentReusableList` (declared in `CarManager.lua`) is reused; sorting is performed **in place**.

### 2.3 Incremental sort

`CarManager.sortCarListByTrackPosition(carList)` (`CarManager.lua`):
1. Count "dirty" cars by comparing `CarManager.cars_previousSplinePosition[car.index]` with the current position.
2. If `dirtyCarsCount > totalCars * 0.5` → full `table.sort` (fallback).
3. Otherwise → incremental **insertion sort** (O(n) with few changes), reordering only items that became out of order.
4. Cache current positions in `cars_previousSplinePosition` for the next frame.
- The result is stored in `CarManager.currentSortedCarsList` and the reverse index in `CarManager.sortedCarList_carIndexToSortedIndex[carIndex]`.
- Order is **descending** by `splinePosition` (the car furthest ahead comes first).

### 2.4 Allocation-free anchor points

`CarOperations.getSideAnchorPoints(pos, fwd, left, up, half, outTable)` (`CarOperations.lua`):
- Pool: `CarOperations._reusableSideAnchorTable` + **8 scratch vec3** (`_reusableVec3_center`, `...frontLeft`, `...centerLeft`, `...rearLeft`, `...frontRight`, `...centerRight`, `...rearRight`, `...right`).
- `outTable` defaults to the pool; `table_clear(outTable)` runs at the start; returns the table with `frontLeft/centerLeft/rearLeft/frontRight/centerRight/rearRight/center/forwardDirection/leftDirection/rightDirection/upDirection`.
- **Never allocate** `vec3()` in the hot path. `VecPool.getTempVec3` returns **a shared singleton** — do not retain a reference between calls.
- Note: `checkIfCarIsBlockedByAnotherCarAndSaveSideBlockRays` saves directions/ray data in `CarManager.cars_sideBlockRaysData[carIndex]`, which is cleared on every `CarStateMachine.updateCar` (`CarStateMachine/CarStateMachine.lua`).

### 2.5 Yellow zones with O(1) buckets

`RaceTrackManager.isSplinePositionInYellowZone(splinePos)` (`RaceTrackManager.lua`):
- `bucket = yellowFlagsZones_bucket[floor(splinePos / 0.05)]` (`YELLOW_ZONE_BUCKET_SIZE = 0.05`, `YELLOW_ZONE_BUCKET_COUNT = ceil(1/0.05)`).
- Each bucket stores the indices of active zones covering that segment.
- **Cyclic wrap**: a zone may cross 0.0/1.0; `forEachYellowZoneBucketIndex` populates **two bucket ranges** in that case. Preserve this symmetry in `addYellowFlagZoneToBuckets`/`removeYellowFlagZoneFromBuckets`.
- `getYellowZoneBucketIndex` clamps indices outside `[0, COUNT-1]`.

### 2.6 Car iteration

- `ac.iterateCars()` is **expensive** → call it **once per frame** in `MANIFEST__UPDATE` and iterate its result.
- `ac.getCar(index)` is used for occasional lookups; do not use it to iterate the fleet inside per-car loops.

### 2.7 Speed sampling

`CarManager.saveCarSpeed(car)` (`CarManager.lua`) maintains a circular buffer of `CAR_SPEEDS_BUFFER_SIZE`:
- `cars_speedBuffer`, `cars_speedBufferIndex`, `cars_speedBufferTotal`, `cars_speedSampleCount`, `cars_averageSpeedKmh`.
- Ignores stopped cars (`speedKmh < 1`); the average is `total / sampleCount`.

### 2.8 Hot-path summary

| Hot spot | File | Rule |
| --- | --- | --- |
| `_currentFrameId += 1` | `SimOpenTrackDay.lua` | Once per frame; invalidates cache |
| `table.clear(carList)` | `SimOpenTrackDay.lua` | Never use `{}` per frame |
| `ac.iterateCars()` | `SimOpenTrackDay.lua` | Once per frame |
| `sortCarListByTrackPosition` | `CarManager.lua` | Preserve incremental sort + 50% fallback |
| `getActualTrackLateralOffset` | `CarManager.lua` | Cache hit avoids `worldCoordinateToTrack` |
| `getSideAnchorPoints` | `CarOperations.lua` | Pool + scratch; zero allocation |
| `isSplinePositionInYellowZone` | `RaceTrackManager.lua` | O(1) buckets; correct wrap handling |
| `VecPool.getTempVec3` | `VecPool.lua` | Singleton — temporary use only |

---

## 3. Coupling (who calls whom)

### 3.1 Main call chain (arrows)

```
 manifest.ini UPDATE
        │
        ▼
 script.MANIFEST__UPDATE
        │
        ├─→ GameTimeManager.update ──► (time for HumanErrorManager)
        ├─→ SessionDetails.update
        ├─→ CameraManager.getFocusedCarIndex ──► RaceTrackManager.isSplinePositionInYellowZone ──► RaceFlagManager.set/removeRaceFlag
        │
        ├─→ CarManager.ensureDefaults ──► (CarStateMachine.initializeCarInStateMachine, AccidentManager.setCarNavigatingAroundAccident, CarOperations.*)
        ├─→ CarManager.saveCarSpeed
        ├─→ CarManager.sortCarListByTrackPosition
        ├─→ OnCarEventManager.processQueuedEvents ──► OnCarEventExecutions[Collision|Jumped]
        ├─→ CarStateMachine.handleQueuedAccidents
        ├─→ HumanErrorManager.update ──► physics.setAIBrakeMistake / setAITractionMistake
        │
        └─(per car)─→ CarStateMachine.updateCar
                            └─→ CarStateMachine.states_{entry,transition,update,exit}Functions[state]
                                    └─→ CarOperations.driveSafelyToSide / overtakeSafelyToSide / yieldSafelyToSide
                                            └─→ physics.setAISplineOffset / setAITopSpeed / setAIThrottleLimit /
                                                setAICaution / setAIAggression / setExtraAIGrip / raycasts
                                    └─→ CarManager.getActualTrackLateralOffset
                                    └─→ CarManager.isCarOffTrack / getClosingSpeed
                                    └─→ AccidentManager.*
                                    └─→ RaceTrackManager.getYieldingSide/getOvertakingSide
```

### 3.2 Imports / imported by

| Module | Imports from | Imported by |
| --- | --- | --- |
| `SimOpenTrackDay.lua` | nearly all (root) | — (entry point) |
| `CarManager` | `StorageManager`, `RaceTrackManager`, `CarStateMachine`, `AccidentManager`, `CarOperations`, `Strings`, `VecPool` | entry point, `CarOperations`, `CarStateMachine`, states, UI |
| `CarOperations` | `CarManager`, `RaceTrackManager`, `StorageManager`, `VecPool`, `MathHelpers` | states, `CarStateMachine`, entry point, `AccidentManager` |
| `CarStateMachine` | `StorageManager`, `Strings*`, `CarManager`, `CarOperations`, `RaceTrackManager`, `AccidentManager`, `QueueManager` | entry point, states, `CarManager` |
| `States/*` | `CarStateMachine`, `CarManager`, `CarOperations`, `RaceTrackManager`, `StorageManager`, `Strings*` | entry point (`require`; registers functions) |
| `StorageManager` | `ac`, `Constants` | nearly all (captured at load time) |
| `SettingsWindow` | `StorageManager`, `UIOperations`, `RaceTrackManager`, `Logger` | entry point (`MANIFEST__FUNCTION_SETTINGS`) |
| `UIManager` | `CarManager`, `CarStateMachine`, `StorageManager`, `RaceTrackManager`, `Strings`, widgets | entry point |
| `RaceTrackManager` | `ac`, `CompletableIndexCollectionManager`, `Logger` | `CarManager`, `CarOperations`, `CarStateMachine`, UI, `AccidentManager` |
| `BehaviorPolish` | **nothing** (pure) | loaded by the entry point; no current runtime consumers |
| `HumanErrorManager` | `physics`, `GameTimeManager` (via argument) | entry point (`MANIFEST__UPDATE`) |
| `RaceFlagManager` | `physics.overrideRacingFlag` | entry point |
| `AccidentManager` | `CarManager` (via API), `RaceTrackManager`, `QueueManager` | entry point, `CarStateMachine`, states |
| `OnCarEventManager` | `QueueManager` | entry point |
| `Pathfinding` | `CarManager`, `VecPool`, `MathHelpers`, `Render` | entry point (`require`; gated) |
| `FrenetAvoid`/`CollisionAvoidanceManager`/`CarSpeedLimiter`/`CustomAIFloodManager`/`Profiler` | various | none (`require` commented out) |

> There are **runtime circular dependencies** (`CarManager ↔ CarStateMachine ↔ CarOperations`).
> They work only because modules are **global** and functions are called at runtime, not at load time.
> Avoid adding module calls at **load time** inside a cycle.

---

## 4. DoD (Data-Oriented Design) conventions

**Golden rule:** car state is `CarManager.cars_*[carIndex]` — parallel tables, **1 entry per index**.
**Do not** create a table/object per car instance, or a nested `table` per car beyond existing cases.

### 4.1 Initialization

- `CarManager.ensureDefaults(carIndex)` → if `cars_initialized[carIndex]` is not set, calls `setInitializedDefaults(carIndex)`.
- `setInitializedDefaults` performs a full reset (offsets, FSM, AI limits, collisions) and is also called by `onCarJumped`.
- Lazy initialization: **declare the table when it is used** if it is not in `setInitializedDefaults` — do not assume every `cars_*` table exists for every index.

### 4.2 Canonical examples

| Table | File | Purpose |
| --- | --- | --- |
| `cars_lateralOffsetCacheByCar` | `CarManager.lua` | actual lateral offset cache per frame |
| `cars_previousSplinePosition` | `CarManager.lua` | detect changes for incremental sorting |
| `cars_speedBuffer` / `cars_speedSampleCount` | `CarManager.lua` | circular speed buffer |
| `cars_defenseRemainingTime_s` | `CarManager` / `CarState_DefendingPosition` | time remaining while defending position |
| `cars_currentReusableList` | `CarManager.lua` | list reused every frame |
| `cars_state` (local) | `CarStateMachine/CarStateMachine.lua` | current FSM state per car |
| `cars_sideBlockRaysData` | `CarManager` | lateral raycast data, cleared each frame |
| `sortedCarList_carIndexToSortedIndex` | `CarManager.lua` | reverse index from `carIndex` to sort position |
| `HumanErrorManager.lastEventTimeByCar` / `errorCountByCar` | `HumanErrorManager.lua` | per-car cooldown/count |

### 4.3 Cautions

- Do not retain references to **reused** tables/objects (pools) across frames.
- When iterating cars, use `car.index` as the DoD key; car indices may be **recycled** by AI Flood (which is why `onCarJumped` resets them).
- Prefer integer-indexed numeric tables; avoid string keys in the hot path.

---

## 5. Storage (options DoD)

Pipeline in `StorageManager.lua`:

1. **Enum** — integer IDs per category, notation `StorageManager.Options_X`:
   ```lua
   StorageManager.Options_Behavior = { entryBlendTime = 1, exitBlendTime = 2, ..., ErrorCooldown_s = 16 }
   ```
2. **Collection** — `optionsCollection_X_beforeDoD` (ordered list with metadata):
   ```lua
   local optionsCollection_Behavior_beforeDoD = {
     { name = StorageManager.Options_Behavior.entryBlendTime, default = 1.5, min = 0, max = 5 },
     { name = StorageManager.Options_Behavior.mode, default = StorageManager.BehaviorMode.HybridAdaptive, min = nil, max = nil },
     ...
   }
   ```
3. **DoD tables** — `fillInDoDTables(collection, default, min, max)` populates:
   `StorageManager.options_X_default`, `..._min`, `..._max` (indexed by the **enum ID**).
   The collection is then cleared: `optionsCollection_X_beforeDoD = nil -- free memory`.
4. **`storageTable_X`** — camelCase table with defaults applied, e.g. `storageTable_Behavior` and `storageTable` (main).
5. **Actual storage** — `ac.storage(storageTable, key)`:
   ```lua
   local fullTrackID = ac.getTrackFullID("_")
   local perTrackPerModeStorageKey = getStorageKeyForTrackAndMode(nil, fullTrackID, raceSessionType)
   local storage_PerTrackPerMode = ac.storage(storageTable, perTrackPerModeStorageKey)
   local storage_Behavior = ac.storage(storageTable_Behavior, getStorageKeyForTrackAndMode("behavior", fullTrackID, raceSessionType))
   ```
   Key = `"<storageID>_<trackID>_<sessionType>"`.
6. **Getter** — `StorageManager.getStorage_X() → storage_X`.

**Existing storage tables:** `getStorage` (main), `_Global`, `_UI`, `_Debugging`, `_Yielding`, `_Overtaking`, `_AICarValues`, `_PathFinding`, `_Behavior`.

### 5.1 Declared storage schema

`ac.storage` is initialized from each declared storage table; its keys must be present in that schema. Unknown keys are rejected at runtime (for example, `profile` previously caused an `Unknown key profile` error). Do not document or use arbitrary keys as persisted storage.

In `SettingsWindow.lua`, the profile dropdown is inferred from persisted `storage_Behavior` values. It is not stored as `storage_Behavior.profile`: the UI compares selected profile values against the saved `mode`, `humanErrorEnabled`, and `entryBlendTime_s`, and falls back to `Realistic` when no match is found. Choosing a profile applies its values to the declared behavior fields. The `advancedBehaviorOpen` UI toggle is a local variable and is not persisted; `showBehaviorAdvanced` is not read or written by the UI.

`getStorage_UI()` delegates to the shared `UIStorage.lua` schema and lazy singleton, providing app-wide language preferences in the `ui` namespace, with `uiLanguage = ''` marking first use. `Localization` uses the same shared storage when a legacy manager lacks that getter. It migrates a valid legacy `global.uiLanguage` only when UI storage is empty; subsequent language changes persist only in UI storage, independent of track and session mode. The legacy global field remains declared for compatibility. See [`docs/LOCALIZATION.md`](LOCALIZATION.md) for localization details.

### 5.2 Behavior profiles

`StorageManager.BehaviorProfiles`: `Casual`, `Realistic`, `Competitive` → `applyBehaviorProfile(profileIndex)` copies the fields into `storage_Behavior`. It is called by the UI, **not automatically**.

---

## 6. Bitwise (CRITICAL REMINDER)

- **LuaJIT 2.1 does not have the `&`, `|`, `~`, `<<`, `>>` operators** — those are **Lua 5.3**.
- Use the `bit.*` library:
  ```lua
  bit.band(a, b)     -- AND
  bit.bor(a, b)      -- OR
  bit.bnot(a)        -- NOT
  bit.bxor(a, b)     -- XOR
  bit.lshift / bit.rshift
  ```
- `Enum.lua` was fixed to use `bit.*` (`hasFlag`, `add`, `remove`). FSM states are **bit flags** (`DRIVING_NORMALLY = 1`, `EASING_IN_YIELD = 4`, ... `DEFENDING_POSITION = 65536`).
- **Do not introduce** `&`, `|`, `~` anywhere in Lua code — the app will fail in the LuaJIT parser.

---

## 7. Common pitfalls

1. **Lazy initialization of `cars_*`.** Declare the table when it is used (or add it to `setInitializedDefaults`). Do not assume every table exists for every `carIndex`.
2. **Use `bit.*` instead of `&`/`|`/`~`** (§6). Always.
3. **Reusable tables.** Use pools (`cars_currentReusableList`, `_reusableSideAnchorTable`, `VecPool`) instead of creating `{}`/`vec3()` in the hot path. Beware the `VecPool` singleton.
4. **`physics.setAITopSpeed` has no `physics.removeAITopSpeed`.** Use `CarOperations.removeAITopSpeed(carIndex)` (`CarOperations.lua`), which provides the equivalent behavior via `math.huge`.
5. **`physics.setAINoInput(carIndex, true)`** to actually park the car (the car receives no input). Used in `CarState_AfterCustomAIFloodTeleport.lua`.
6. **`ac.iterateCars()` is expensive** — call it **once per frame** and iterate its result (§2.6).
7. **`physics.setAITopSpeed`/`setAIThrottleLimit` do not work on AC AI Flood** — the historical reason for `CarSpeedLimiter`. Do not rely on them to limit speed reliably; `applyAntiDragRaceLimit` is idempotent and handles the yield case.
8. **`cars_sideBlockRaysData` is cleared on every `updateCar`.** If you populate this table outside the car cycle, the data disappears next frame.
9. **`ac.worldCoordinateToTrack` is expensive** — call it only on a cache miss (`getActualTrackLateralOffset`).
10. **FSM states use bit flags**, but the `carIndex`-to-state mapping is stored as a value in `cars_state`; transitions go through `queueStateTransition` and are applied only at the start of the next `updateCar`.
11. **`CAR_SPEEDS_BUFFER_SIZE`** — the speed buffer is circular; never access `cars_speedBuffer[carIndex]` directly without handling the index/`nil` (newly teleported cars have a cleared buffer).
12. **`RaceTrackManager` is captured at load time** by `CarManager`/states; `getTrackFullID`/session are fixed at load.

---

## 8. Missing or unstable CSP API caveats

| API | Status | Notes |
| --- | --- | --- |
| `physics.setAICaution` | experimental/documented | `StorageManager.lua` configures a maximum of 16, following the API documentation; this is not runtime validation |
| `physics.setAITopSpeed` / `setAIThrottleLimit` | **do not work on AC AI Flood** | reason for `CarSpeedLimiter.lua` (disabled) and anti-drag-race |
| `physics.setAIBrakeMistake` / `setAITractionMistake` | checked by the entry point | used by `HumanErrorManager`; this document does not specify a minimum CSP version |
| `physics.setAILapsToComplete` | available in the distributed SDK | not registered or used by the current app |
| `physics.Collider.TrackWalls()` / `TrackGround()` | **preview649** | collider API; not used directly today |
| `physics.preventAIFromRetiring` | **call repeatedly** | every frame while the condition lasts (`CarOperations.preventAIFromRetiring`) |
| `physics.overrideRacingFlag` | stable | basis for `RaceFlagManager` |
| `ac.storage` | stable | uses the declared storage schema; unknown keys are rejected (see §5.1) |

CSP APIs used and registered by the app go through `CSPCompatibilityManager.addFunction(...)` and are checked by `CSPCompatibilityManager.checkForMissingElements(...)`. The SDK also contains APIs not used by the app — for example, `physics.setAILapsToComplete` — that are not registered. When adding a new API to the app, **register it in the entry point** to receive missing-API diagnostics.

---

## 9. Quick file map (index)

```
SimOpenTrackDay.lua   entry point / MANIFEST__UPDATE
├─ CarManager.lua                   DoD by carIndex; sorting; lateral cache
├─ CarOperations.lua                physics wrappers + yield/overtake; anchors; raycasts
├─ CarStateMachine/
│  ├─ CarStateMachine.lua           central FSM (`updateCar`)
│  ├─ CarState_TEMPLATE.lua         new-state contract
│  └─ States/*.lua                  states (see docs/STATE_MACHINE.md)
├─ StorageManager.lua               enum→collection→DoD→storage→getters
├─ SettingsWindow.lua               settings UI (`draw`)
├─ UIManager.lua                    car list / overhead / offsets preview
├─ RaceTrackManager.lua             track metadata + sides + yellow-zone buckets
├─ BehaviorPolish.lua               pure functions (lerp / hesitation / look-ahead)
├─ HumanErrorManager.lua            brake/traction mistakes with cooldown
├─ RaceFlagManager.lua              caution flag
├─ AccidentManager.lua              accidents + yellow zones
├─ OnCarEventManager.lua            Collision/Jumped queue
├─ GameTimeManager.lua              game time (cooldowns)
├─ SessionDetails.lua               time since session start
├─ (disabled) Pathfinding / FrenetAvoid / CollisionAvoidanceManager /
│              CarSpeedLimiter / CustomAIFloodManager / Profiler
├─ Strings/  DataStructures/  VecPool / MathHelpers / ColorManager / Logger / Enum
├─ lib/ac_apps/                     CSP SDK (vendor)
├─ lib/AssettoCorsaCSPLuaCompatibilityManager/ compatibility submodule
└─ lib/uilib/                       project-owned library
```

Related documents: `docs/AGENT.md` (onboarding), `docs/STATE_MACHINE.md` (FSM), `docs/TESTING.md` (validation), `README.md` (product).
