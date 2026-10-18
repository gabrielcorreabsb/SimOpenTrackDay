# AI Car State Machine (FSM) — SimOpenTrackDay

This document describes the **Finite State Machine (FSM)** that governs each AI car's behavior: its states, what they do, transitions, and how to add new states.

- **Central file:** `CarStateMachine/CarStateMachine.lua`
- **States:** `CarStateMachine/States/CarState_<Name>.lua`
- **Template:** `CarStateMachine/CarState_TEMPLATE.lua`
- **Enum:** `CarStateMachine.CarStateType` in `CarStateMachine/CarStateMachine.lua`

---

## 1. Overview

Each AI car is an **FSM** with three per-car state values:

| Data | Table | Contents |
| --- | --- | --- |
| Current state | `cars_state[carIndex]` | `CarStateType` enum value |
| Previous state | `CarStateMachine.cars_previousState[carIndex]` | The state we came from |
| Time in state | `CarManager.cars_timeInCurrentState[carIndex]` | Accumulated seconds |

### `CarStateType` enum (bitmask)

Each state is a **power of 2** (bitmask), but the FSM uses one value at a time.

| Value | State | Value | State |
| --- | --- | --- | --- |
| 1 | `DRIVING_NORMALLY` | 1024 | `EASING_IN_OVERTAKE` |
| 4 | `EASING_IN_YIELD` | 2048 | `STAYING_ON_OVERTAKING_LANE` |
| 8 | `STAYING_ON_YIELDING_LANE` | 4096 | `EASING_OUT_OVERTAKE` |
| 32 | `EASING_OUT_YIELD` | 8192 | `NAVIGATING_AROUND_ACCIDENT` |
| 64 | `WAITING_AFTER_ACCIDENT` (enum only) | 16384 | `DRIVING_IN_YELLOW_FLAG_ZONE` |
| 128 | `COLLIDED_WITH_TRACK` | 32768 | `AFTER_CUSTOMAIFLOOD_TELEPORT` |
| 256 | `COLLIDED_WITH_CAR` | 65536 | `DEFENDING_POSITION` |
| 512 | `ANOTHER_CAR_COLLIDED_INTO_ME` | | |

> `WAITING_AFTER_ACCIDENT` exists only in the enum; it has no file or functions (legacy).

### Four-function contract

Each state registers **4 functions** in **parallel tables** indexed by the state value:

| Table | Function | Role |
| --- | --- | --- |
| `states_entryFunctions` | `entry` | once, on entry |
| `states_updateFunctions` | `update` | every frame in the state |
| `states_transitionFunctions` | `transition` | chooses the next state (or `nil`) |
| `states_exitFunctions` | `exit` | cleanup on exit |

`states_minimumTimeInState[state]` defines the minimum time (s) before the state can be exited.

### `updateCar` dispatch

`CarStateMachine.updateCar(carIndex, dt, sortedCarsList, sortedCarsListIndex)`
(`CarStateMachine/CarStateMachine.lua`) runs each frame in this order:

1. **Queued transition:** if `queuedStatesToTransitionInto` exists, call `changeState` and run the new state's `entry`.
2. **Update:** call `states_updateFunctions[state]`.
3. **Increment** `cars_timeInCurrentState += dt`.
4. **Minimum time:** if `currentTimeInState < minimumTimeInState`, `return`.
5. **Transition:** call `states_transitionFunctions[state]`; if it returns a state, call the current `exit` and **queue** the transition.

In other words: `entry` runs in the frame after `transition`; `exit` is immediate when `transition` decides to change state.

---

## 2. Transition diagram (ASCII)

```
                          +---------------------+
                          |  DRIVING_NORMALLY   |  <- initial/default state
                          +----------+----------+
                                     |
        +----------------------------+----------------------------+
        |                    |                    |               |
   [car behind         [car ahead         [yellow flag       [accident
    requests yield]     to overtake]        ahead]             ahead]
        |                    |                    |               |
        v                    v                    v               |
+-------+---------+  +-------+----------+  +------+-------+       |
| EASING_IN_YIELD |  | EASING_IN_      |  | DRIVING_IN_  |       |
+-------+---------+  | OVERTAKE        |  | YELLOW_FLAG_ |       |
        |            +-------+---------+  | ZONE         |       |
        v                    v            +------+-------+       |
+-------+-----------+  +-----+-------------+     |               |
| STAYING_ON_       |  | STAYING_ON_       |     |               |
| YIELDING_LANE     |  | OVERTAKING_LANE   |     |               |
+-------+-----------+  +-----+-------------+     |               |
        |                    |                   |               |
        v                    v                   v               |
+-------+-----------+  +-----+-----------+  +----+----------------+--+
| EASING_OUT_YIELD  |  | EASING_OUT_     |  | NAVIGATING_AROUND_     |
+-------+-----------+  | OVERTAKE        |  | ACCIDENT               |
        |              +-----+-----------+  +----+----------------+--+
        +---------+----------+-------------------+
                  v
          +---------------------+
          |  DRIVING_NORMALLY   |
          +---------------------+
```

### Special states (outside the main flow)

```
+---------------------+------------------------------------------------------+
| DEFENDING_POSITION  | holds the racing line for defenseDuration_s under   |
|                     | pressure; when it expires -> EASING_IN_YIELD.       |
+---------------------+------------------------------------------------------+
| DRIVING_IN_YELLOW_  | enters an accident zone: reduces speed,             |
| FLAG_ZONE           | hazards on, collisions disabled.                    |
+---------------------+------------------------------------------------------+
| NAVIGATING_AROUND_  | avoids a stopped/crashed car via                    |
| ACCIDENT            | CollisionAvoidanceManager.computeDesiredLateralOffset|
+---------------------+------------------------------------------------------+
| COLLIDED_WITH_TRACK | stubs: only stop the car. No transition.            |
| COLLIDED_WITH_CAR   |                                                      |
| ANOTHER_CAR_COLLIDED| (this state has minimumTimeInState = 10s)           |
| _INTO_ME            |                                                      |
+---------------------+------------------------------------------------------+
| AFTER_CUSTOMAIFLOOD | after AI Flood respawn: resets fuel/RPM/gear and    |
| _TELEPORT           | reactivates the car. Empty transition (commented).  |
+---------------------+------------------------------------------------------+
```

---

## 3. Contract for each state

Format: file, `minimumTimeInState (min)`, `entry`, `update`, transitions, and `exit`.

### 3.1 DRIVING_NORMALLY
- **File:** `CarStateMachine/States/CarState_DrivingNormally.lua` — **min:** `0`
- **Entry:** synchronizes the calculated offset with the actual offset; target = `storage.defaultLateralOffset`; clears overtake/yield references; turning lights off; restores default aggression/difficulty/grip/caution; resets throttle.
- **Update:** `driveSafelyToSide(car, targetOffset, 1000, storage.overrideAiAwareness, true, false)`.
- **Transitions:** `handleYellowFlagZone` -> `DRIVING_IN_YELLOW_FLAG_ZONE` / `NAVIGATING_AROUND_ACCIDENT`; `handleShouldWeYieldToBehindCar` -> `EASING_IN_YIELD`; `handleShouldWeOvertakeFrontCar` -> `EASING_IN_OVERTAKE`.
- **Exit:** `ReasonWhyCantYield = None`. Ignored in the pits or during `storage.deferTimeAfterSessionStart`.

### 3.2 EASING_IN_YIELD
- **File:** `CarStateMachine/States/CarState_EasingInYield.lua` — **min:** `0`
- **Entry:** validates `cars_currentlyYieldingCarToIndex` (set by the previous state); calculated offset starts at the actual offset; signals the yielding side.
- **Update:** `yieldSafelyToSide(...)`; with no gap -> `setAIThrottleLimit(0.4)` + `setPedalPosition(Brake, 0.2)`.
- **Transitions:** pursuer clearly ahead (`clearAhead_meters`) -> `EASING_OUT_YIELD`; reached the yielding offset -> `STAYING_ON_YIELDING_LANE`.
- **Exit:** resets brake, throttle limit, and turning lights.

### 3.3 STAYING_ON_YIELDING_LANE
- **File:** `CarStateMachine/States/CarState_StayingOnYieldingLane.lua` — **min:** `0`
- **Entry:** validates the pursuing car; `ReasonWhyCantYield = None`.
- **Update:** `setAICaution(AICaution_Yielding)`; optional yielding aggression/difficulty; if the pursuer is nearby (`distanceToOvertakingCarToLimitSpeed`), limits throttle/top speed, otherwise resets them; `yieldSafelyToSide`.
- **Transitions (all -> `EASING_OUT_YIELD`):** pursuer does not exist, is clearly ahead, is clearly behind, we are faster (leeway `20` km/h), or it has left the overtaking lane.
- **Exit:** caution, default aggression/difficulty, top speed, pedals, throttle, and turning lights.

### 3.4 EASING_OUT_YIELD
- **File:** `CarStateMachine/States/CarState_EasingOutYield.lua` — **min:** `0`
- **Entry:** sets the calculated offset; resets throttle/top speed/caution; signals the opposite direction (returning to center).
- **Update:** `driveSafelyToSide(..., storage_Yielding.rampRelease_mps, ...)`.
- **Transitions:** `handleShouldWeYieldToBehindCar` -> `EASING_IN_YIELD` (new car); reached the normal offset (overtaking side) -> clears `cars_currentlyYieldingCarToIndex` and enters `DRIVING_NORMALLY`.
- **Exit:** turning lights.

### 3.5 EASING_IN_OVERTAKE
- **File:** `CarStateMachine/States/CarState_EasingInOvertake.lua` — **min:** `0`
- **Entry:** validates `cars_currentlyOvertakingCarIndex`; sets the calculated offset.
- **Update:** `calculateAICautionAggressionDifficultyWhileOvertaking` (applies caution/aggression/difficulty) and `overtakeSafelyToSide(...)`.
- **Transitions:** invalid target -> `EASING_OUT_OVERTAKE`; a car behind (≠ target) requests yield -> `EASING_IN_YIELD`; reached the offset -> `STAYING_ON_OVERTAKING_LANE`.
- **Exit:** caution, default aggression/difficulty, turning lights.

### 3.6 STAYING_ON_OVERTAKING_LANE
- **File:** `CarStateMachine/States/CarState_StayingOnOvertakingLane.lua` — **min:** `0`
- **Entry:** empty.
- **Update:** recalculates overtake caution/aggression/difficulty and calls `overtakeSafelyToSide` to remain in the lane.
- **Transitions:** invalid target -> `EASING_OUT_OVERTAKE`; `handleOvertakeNextCarWhileAlreadyOvertaking` -> remain; clearly ahead of the target -> `EASING_OUT_OVERTAKE`; target clearly ahead (`clearAhead_meters + 40`) -> `EASING_OUT_OVERTAKE`; a car behind (≠ target) requests yield -> `EASING_IN_YIELD`.
- **Exit:** caution, default difficulty/aggression, turning lights.

### 3.7 EASING_OUT_OVERTAKE
- **File:** `CarStateMachine/States/CarState_EasingOutOvertake.lua` — **min:** `0`
- **Entry:** validates `cars_currentlyOvertakingCarIndex`; sets the calculated offset.
- **Update:** `driveSafelyToSide(..., storage_Overtaking.overtakeRampRelease_mps, ...)`.
- **Transitions:** invalid target -> `DRIVING_NORMALLY`; a car behind (≠ target) requests yield -> `EASING_IN_YIELD`; `handleOvertakeNextCarWhileAlreadyOvertaking` -> `EASING_IN_OVERTAKE`; reached the normal offset (yielding side) -> clears the reference and enters `DRIVING_NORMALLY`.
- **Exit:** turning lights.

### 3.8 DEFENDING_POSITION
- **Active implementation:** inline in `CarStateMachine/CarStateMachine.lua` — **min:** `0`.
  `CarStateMachine/States/CarState_DefendingPosition.lua` also exists, but is not required by the current entry point.
- **Entry:** randomly selects `defenseDuration_s` in `[defenseDurationMin_s, defenseDurationMax_s]` (default `1.0`–`3.0` s from `getStorage_Behavior`); `StateExitReason.YieldingToCar`.
- **Update:** decrements the timer and calls `driveSafelyToSide(car, storage.defaultLateralOffset, 1000, true, false, false)`.
- **Transitions:** timer `<= 0` -> `EASING_IN_YIELD`; if the car behind no longer applies pressure -> `DRIVING_NORMALLY`. Pressure = distance `<= 30 m` **and** relative speed `carBehind - our >= 5 km/h`.
- **Exit:** clears `cars_defenseRemainingTime_s[carIndex]`.
- **Note:** defined, but **there is still no transition into it** from other states; ready to be connected.

### 3.9 DRIVING_IN_YELLOW_FLAG_ZONE
- **File:** `CarStateMachine/States/CarState_DrivingInYellowFlagZone.lua` — **min:** `0`
- **Entry:** empty.
- **Update:** `setAITopSpeed(50)`, `toggleTurningLights(Hazards)`, `toggleCarCollisions(false)`.
- **Transitions:** `isCarComingUpToAccident` within `distanceToStartNavigatingAroundCarInAccident_meters` -> `NAVIGATING_AROUND_ACCIDENT`; left the zone -> `DRIVING_NORMALLY`.
- **Exit:** top speed and turning lights.

### 3.10 NAVIGATING_AROUND_ACCIDENT
- **File:** `CarStateMachine/States/CarState_NavigatingAroundAccident.lua` — **min:** `0`
- **Entry:** empty.
- **Update:** `setAICaution(0)`, `setAITopSpeed(30)`; recalculates the nearest accident; offset via `CollisionAvoidanceManager.computeDesiredLateralOffset`; `driveSafelyToSide(..., 5, true, false)`; `preventAIFromRetiring`; `toggleCarCollisions(false)`.
- **Transitions:** no accident index, accident resolved, car not found, or we have passed it and are `> 10 m` away -> `DRIVING_NORMALLY`; nearest accident detected -> remain.
- **Exit:** caution, top speed, pedals, and `cars_navigatingAroundAccidentIndex = 0`.

### 3.11 COLLIDED_WITH_TRACK
- **File:** `CarStateMachine/States/CarState_CollidedWithTrack.lua` — **min:** `0`
- **Entry/Exit:** empty. **Update:** `stopCarAfterAccident(carIndex)`.
- **Transition:** empty — **terminal state**.

### 3.12 COLLIDED_WITH_CAR
- **File:** `CarStateMachine/States/CarState_CollidedWithCar.lua` — **min:** `0`
- **Entry/Exit:** empty. **Update:** `stopCarAfterAccident(carIndex)` + `toggleCarCollisions(false)`.
- **Transition:** empty — **terminal state**.

### 3.13 ANOTHER_CAR_COLLIDED_INTO_ME
- **File:** `CarStateMachine/States/CarState_AnotherCarCollidedIntoMe.lua` — **min:** `10`
- **Entry:** `ac.overrideCarControls` (horn commented out).
- **Update:** `stopCarAfterAccident(carIndex)` + `toggleCarCollisions(false)`.
- **Transition:** empty — **terminal state** (the 10 s minimum does not lead anywhere). **Exit:** empty.

### 3.14 AFTER_CUSTOMAIFLOOD_TELEPORT
- **File:** `CarStateMachine/States/CarState_AfterCustomAIFloodTeleport.lua` — **min:** `0`
- **Entry:** `setCarFuel(100)`, `engageGear(3)`, `setEngineRPM(5000)`, `setAIStopCounter(0)`.
- **Update:** `setGentleStop(false)`, `setAICaution(0)`, `awakeCar`, `setAINoInput(false, false)`, `setAIStopCounter(0)`.
- **Transition:** empty (conditions commented out) — remains. **Exit:** `setAICaution(1)`, reset gas, `cars_doNoResetAfterNextCarJump = false`.

### 3.15 TEMPLATE
- **File:** `CarStateMachine/CarState_TEMPLATE.lua`
- Model for new states: defines `STATE`, string, minimum time, and the 4 empty functions. Do not register it in the enum — it is only a starting point.

---

## 4. Important transitions (rules)

Yield/overtake decisions are handled by `CarStateMachine.handleShouldWeYieldToBehindCar` and `CarStateMachine.handleShouldWeOvertakeFrontCar` in `CarStateMachine/CarStateMachine.lua`.

### 4.1 `handleShouldWeYieldToBehindCar`

Iterates over cars behind within `detectCarBehind_meters` and returns `EASING_IN_YIELD` only when **all** conditions pass:

- the car behind is not in the pits;
- it is within `detectCarBehind_meters`;
- it is actually behind (`isFirstCarBehindSecondCar`);
- we are slower than it (`yieldingCarSpeed < overtakingCarSpeed`);
- if `requireOvertakingCarToBeOnOvertakingLane`, it is in the overtaking lane.

Otherwise, records a `ReasonWhyCantYield` (e.g. `TargetSideBlocked`, `OvertakingCarTooFarBehind`, `WeAreFasterThanOvertakingCar`) and returns `nil`.

### 4.2 `handleShouldWeOvertakeFrontCar`

Returns `EASING_IN_OVERTAKE` when:

- there is a car ahead and it is not in the pits;
- distance `<= detectCarAhead_meters`;
- we are faster (compared using `averageSpeedKmh`);
- if `requireYieldingCarToBeOnYieldingLane`, it is in the yielding lane;
- the car behind (if any) is not within 5 m.

Otherwise, records a `ReasonWhyCantOvertake` (e.g. `YieldingCarIsFaster`, `YieldingCarTooFarAhead`, `AnotherCarBehindTooClose`) and returns `nil`.

### 4.3 Summary by situation

- **In `DRIVING_NORMALLY`:** clearly faster car behind -> `EASING_IN_YIELD`; slower, eligible car ahead -> `EASING_IN_OVERTAKE`; yellow zone / accident -> corresponding states.
- **Yield in progress:** any sign that the pursuing car no longer needs the lane (ahead, too far behind, we are faster, or it is out of lane) -> `EASING_OUT_YIELD`.
- **Overtake in progress:** overtake completed or target moves ahead again -> `EASING_OUT_OVERTAKE`; eligible new car ahead -> continue overtaking (`handleOvertakeNextCarWhileAlreadyOvertaking`).
- **`DEFENDING_POSITION`:** while the timer has not expired and pressure remains -> hold the line; timer expires -> `EASING_IN_YIELD`; pressure ends -> `DRIVING_NORMALLY`.

---

## 5. How to add a new state (workflow)

1. Add a **bit flag** to the `CarStateType` enum in `CarStateMachine/CarStateMachine.lua`, using the next available power of 2 (e.g. `MY_STATE = 131072`).
2. Add a **string** in `CarStateTypeStrings[MY_STATE] = "MyState"`.
3. **Minimum time:** `states_minimumTimeInState[MY_STATE] = 0` (use `0` unless there is a strong reason not to).
4. **Register the 4 functions:** `states_entryFunctions`, `states_updateFunctions`, `states_transitionFunctions`, and `states_exitFunctions`.
5. **Create** `CarStateMachine/States/CarState_<Name>.lua` based on `CarStateMachine/CarState_TEMPLATE.lua` and add it to the entry-point load sequence.
6. Keep one active implementation per state; `DEFENDING_POSITION` is currently implemented inline in the central module, and its separate file is not loaded.
7. **Add transitions to/from** this state in the `transition` functions of relevant states.
8. **Expose it in debug/UI** if needed (a readable name is already provided by step 2).

---

## 6. Cautions

- **A long minimum time can trap the AI.** Use `minimumTimeInState = 0` in most cases; `10` is the largest value used (`ANOTHER_CAR_COLLIDED_INTO_ME`).
- **Circular dependencies need an escape.** If A transitions to B and B to A, ensure an exit timer/condition (e.g. the `DEFENDING_POSITION` timer).
- **Terminal states are intentional** (`COLLIDED_*`): an empty transition keeps the car stopped. Do not add transitions without reviewing `AccidentManager`.
- **References saved by the previous state.** `EASING_IN_YIELD` and `EASING_IN_OVERTAKE` depend on `cars_currentlyYieldingCarToIndex` / `cars_currentlyOvertakingCarIndex` being set before entry.
- **`changeState` resets `cars_timeInCurrentState`** — do not rely on the previous time after a transition.
- **Transitions are queued:** `entry` runs at the start of the next `updateCar`, not in the frame that made the decision.
- **Without a registered `entry`**, `updateCar` logs an error and aborts that car's update (`CarStateMachine/CarStateMachine.lua`).

---

## 7. Cross-cutting layers (not states)

```
+-------- BehaviorPolish (loaded helper module; no current call sites) --------+
| defines phase-blend, hesitation, and look-ahead helper functions             |
| these helpers are not integrated into the current FSM/runtime flow           |
+----------------------------------------------------------------------------+

+-------- HumanErrorManager (cross-cutting, not a state) ---------------------+
| triggers physics.setAIBrakeMistake / setAITractionMistake with a cooldown    |
| default 7 s (errorCooldown_s)                                               |
+----------------------------------------------------------------------------+
```

- **BehaviorPolish** (`BehaviorPolish.lua`): loaded pure module defining `lerp` (phase blending), `shouldReactNow` (hesitation), and `confidenceFromPaceObservations` (noisy look-ahead, ~5%). These helpers have no call sites in the current FSM/runtime flow and therefore do not currently blend phases, delay transitions, or influence look-ahead. The module does not use `ac.*`/`physics.*`.
- **HumanErrorManager** (`HumanErrorManager.lua`): updated each frame (`HumanErrorManager.update(dt, sortedCars, storage_Behavior, gameTime_s)`); injects human braking/traction errors with a cooldown (`errorCooldown_s`, default `7.0`).
