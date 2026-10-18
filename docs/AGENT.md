# AGENT.md — Project Guide

> Detailed context for **AI agents** and **human developers** who need to understand the project.
> This is a human-maintained reference, not an auto-loaded instruction file; read relevant sections as needed.

---

## 1. Project overview

**SimOpenTrackDay** is an independent derivative project under development, based on **Assetto Corsa Realistic Trackday**: a **Lua** app for **Assetto Corsa**, loaded through **Custom Shaders Patch (CSP)**. The original project is by Andreas Grech; see [credits and license](../README.md#credits-and-license) in the README.

It changes **AI** car behavior to act more like humans during a *track day* instead of bots following the *racing line* with “blinders.” Main behaviors:

- **Yield:** a slower car moves off the racing line to a fixed side (left or right according to the rule) and lets the faster car pass.
- **Overtake:** the faster car passes on the side opposite the yield side.
- **Return to racing line:** after the maneuver, the car smoothly returns when safe.
- **Human errors:** accidents, lockups, and traction mistakes may occur and are signaled; behavior is not deterministic.

The inspiration is the real **Nordschleife Touristenfahrten** experience, where overtaking is permitted only on the left and yielding cars move right.

---

## 2. Technical stack

| Item | Value |
| --- | --- |
| **Engine** | **LuaJIT 2.1** (compatible with **Lua 5.1**), the engine used internally by CSP |
| **CSP** | Required to load Lua Apps; the app checks compatibility for APIs it uses. No minimum version is declared here. |
| **Manifest** | `manifest.ini` with `[CORE] LAZY = NONE` |
| **Callbacks** | `MANIFEST__UPDATE`, `MANIFEST__FUNCTION_MAIN`, `MANIFEST__FUNCTION_SETTINGS`, `MANIFEST__FUNCTION_ICON`, `MANIFEST__TRANSPARENT` |
| **SDK/submodules** | `lib/ac_apps/` (CSP SDK) and `lib/AssettoCorsaCSPLuaCompatibilityManager/` (compatibility submodule); do not edit as app code; update the submodule deliberately |
| **Project library** | `lib/uilib/` — project code, distinct from vendor SDK and compatibility submodule |

The CSP functions `physics.setAIBrakeMistake` and `physics.setAITractionMistake` are registered through `CSPCompatibilityManager.addFunction(...)` near the top of the entry point. `physics.setAILapsToComplete` exists in the distributed SDK but is neither registered nor used by the current app.

> **Important:** repository payload is at the root. When installed, the entry point is `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua`. Installation is manual. Do not move modules into a new repository hierarchy; preserve existing installations and settings.

---

## 3. High-level directory layout

```
SimOpenTrackDay/ (payload at repository root)
├─ SimOpenTrackDay.lua                 # ENTRY POINT (manifest callbacks)
├─ CarManager.lua                      # car state (DoD) and position helpers
├─ CarOperations.lua                   # yield/overtake operations
├─ StorageManager.lua                  # settings and per-track/per-mode storage
├─ SettingsWindow.lua                  # settings UI (ImGui)
├─ UIManager.lua / UIOperations.lua    # HUD and overlays
├─ HumanErrorManager.lua               # lockups / traction mistakes
├─ AccidentManager.lua                 # accident detection/navigation
├─ CollisionAvoidanceManager.lua       # collision avoidance
├─ RaceTrackManager.lua                # spline, racing line, offsets
├─ BehaviorPolish.lua                  # pure behavior helpers
├─ Enum.lua / Constants.lua            # enums and global constants
├─ Logger.lua / Profiler.lua           # logging and profiling
│
├─ CarStateMachine/
│  ├─ CarStateMachine.lua              # FSM central: entry/update/transition/exit
│  ├─ CarState_TEMPLATE.lua            # template for new states
│  └─ States/
│     ├─ CarState_DrivingNormally.lua
│     ├─ CarState_EasingInYield.lua
│     ├─ CarState_StayingOnYieldingLane.lua
│     ├─ CarState_EasingOutYield.lua
│     ├─ CarState_EasingInOvertake.lua
│     ├─ CarState_StayingOnOvertakingLane.lua
│     ├─ CarState_EasingOutOvertake.lua
│     ├─ CarState_DefendingPosition.lua
│     ├─ CarState_NavigatingAroundAccident.lua
│     ├─ CarState_DrivingInYellowFlagZone.lua
│     ├─ CarState_CollidedWithTrack.lua
│     ├─ CarState_CollidedWithCar.lua
│     ├─ CarState_AnotherCarCollidedIntoMe.lua
│     └─ CarState_AfterCustomAIFloodTeleport.lua
│
├─ Strings/                            # debug reason/exit-reason text
│  ├─ Strings.lua
│  ├─ Strings_StateExitReason.lua
│  ├─ Strings_ReasonWhyCantYield.lua
│  └─ Strings_ReasonWhyCantOvertake.lua
│
├─ DataStructures/                     # reusable data structures
│  ├─ QueueManager.lua
│  ├─ StackManager.lua
│  ├─ DequeManager.lua
│  └─ CompletableIndexCollectionManager.lua
│
├─ lib/ac_apps/                        # CSP SDK (vendor)
├─ lib/AssettoCorsaCSPLuaCompatibilityManager/ # compatibility submodule
├─ lib/uilib/                          # project-owned library
│
└─ docs/                               # project documentation
```

Other root `*.lua` files (e.g. `CameraManager`, `GameTimeManager`, `SessionDetails`, `VecPool`, `Pathfinding`, `FrenetAvoid`) are primary modules loaded by the entry point.

---

## 4. Entry points by task

Use this table to locate a starting point for a task:

| Task | Start at |
| --- | --- |
| **Understand main flow** | `SimOpenTrackDay.lua` → `script.MANIFEST__UPDATE` |
| **Understand one car's decisions** | `CarManager.lua` → `getActualTrackLateralOffset` and states in `CarStateMachine/States/` |
| **Change main-window UI** | `SimOpenTrackDay.lua` → `MANIFEST__FUNCTION_MAIN` |
| **Change settings UI** | `SettingsWindow.lua` → `MANIFEST__FUNCTION_SETTINGS` |
| **Change settings/persistence** | `StorageManager.lua` (see section 5) |
| **Add a feature** | Section 6 |

**`MANIFEST__UPDATE` summary:** update global state (session time, track, flags) → rebuild sorted car list → run each car's FSM → apply operations (yield/overtake) → update UI/HUD.

### FSM states (quick reference)

Each state is a **bit flag** in `CarStateMachine.CarStateType`. Car states are tested/combined with `bit.band`/`bit.bor`.

| State | Bit | Role |
| --- | --- | --- |
| `DRIVING_NORMALLY` | 1 | Follows the racing line by default |
| `EASING_IN_YIELD` | 4 | Smooth transition to the yielding lane |
| `STAYING_ON_YIELDING_LANE` | 8 | Holds off the racing line to yield |
| `EASING_OUT_YIELD` | 32 | Returns to the racing line after yielding |
| `DEFENDING_POSITION` | 65536 | Holds the racing line under pressure before yielding |
| `EASING_IN_OVERTAKE` | 1024 | Transitions to the overtaking lane |
| `STAYING_ON_OVERTAKING_LANE` | 2048 | Holds the overtaking lane |
| `EASING_OUT_OVERTAKE` | 4096 | Returns to the racing line after overtaking |
| `NAVIGATING_AROUND_ACCIDENT` | 8192 | Avoids an accident on track |
| `DRIVING_IN_YELLOW_FLAG_ZONE` | 16384 | Behavior in a yellow-flag zone |
| `COLLIDED_WITH_TRACK` | 128 | Recovers after leaving the track |
| `COLLIDED_WITH_CAR` | 256 | Recovers after colliding with another car |
| `ANOTHER_CAR_COLLIDED_INTO_ME` | 512 | Reacts to being hit |
| `WAITING_AFTER_ACCIDENT` | 64 | Waits after an accident |
| `AFTER_CUSTOMAIFLOOD_TELEPORT` | 32768 | Reintegrates after CustomAIFlood teleport |

> `CarState_TEMPLATE.lua` shows each state's contract: `states_entryFunctions`, `states_updateFunctions`, `states_transitionFunctions`, and `states_exitFunctions`, all with signature `(carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)`.

---

## 5. Code conventions

### Naming
- Use `snake_case` for functions and local variables.
- Use `CamelCase` with the module name for **main tables** and **enums** (`CarManager`, `StorageManager.BehaviorProfiles`, `StorageManager.Options_Behavior`, `CarStateMachine.CarStateType`).

### Top-level local bindings
Each file binds the APIs it uses to locals near the top:

```lua
local ac_getCar            = ac.getCar
local physics_setAITopSpeed = physics.setAITopSpeed
local CarManager_getActualTrackLateralOffset = CarManager.getActualTrackLateralOffset
```

**Use these locals** inside functions; **do not call `ac.getCar(...)` directly**. This avoids repeated table lookups in hot paths and keeps a single coupling point.

### Bitwise
Use LuaJIT's **`bit.*`** library: `bit.band`, `bit.bor`, `bit.bnot`, `bit.bxor`, `bit.lshift`, `bit.rshift`.

> **Do not use `&`, `|`, `~`, `<<`, `>>`** — these are **Lua 5.3** operators and **do not exist in LuaJIT 2.1**.

FSM states are **bit flags** (`DRIVING_NORMALLY = 1`, `EASING_IN_YIELD = 4`, `STAYING_ON_YIELDING_LANE = 8`, `EASING_OUT_YIELD = 32`, ...); use `bit.band`/`bit.bor` masks to test or transition states.

### Car state (Data-Oriented Design)
State does **not** live in car instances. It lives in DoD tables indexed by car index:
- `CarManager.cars_*Index` (indices)
- `CarManager.cars_*` (data)

Always access state through these tables and keep indices consistent.

### Per-track/per-mode storage
Settings are saved **per track and game mode** (Practice, Qualify, Race, Hotlap, TimeAttack, Drift, Drag). Do not create ad hoc storage; use `StorageManager.getStorage*()`:

```lua
StorageManager.getStorage()
StorageManager.getStorage_Global()
StorageManager.getStorage_Debugging()
StorageManager.getStorage_Yielding()
StorageManager.getStorage_Overtaking()
StorageManager.getStorage_AICarValues()
StorageManager.getStorage_PathFinding()
StorageManager.getStorage_Behavior()
```

### Errors are intentional
`HumanErrorManager` may intentionally call `physics.setAIBrakeMistake` / `physics.setAITractionMistake`. Behavior that is “too perfect” is **wrong** for the app's goals; errors should be signaled to the player.

---

## 6. Adding a feature (typical workflow)

1. **Choose mode and profile**
    If the feature affects AI behavior, add or extend an entry in `StorageManager.BehaviorProfiles`.

2. **New option**
   - Add an ID to the relevant enum (e.g. `StorageManager.Options_Behavior`).
   - Add an entry to the `*_beforeDoD` collection (e.g. `optionsCollection_Behavior_beforeDoD`).
   - Add a field to `storageTable_*` (e.g. `storageTable_Behavior`).
   - Defaults/min/max flow through `fillInDoDTables(collection, default, min, max)`.

3. **UI control**
    For behavior options, edit the Behavior section in `SettingsWindow.lua`. New categories get an analogous section.

4. **AI logic**
    - **New state?** Extend the FSM in `CarStateMachine/CarStateMachine.lua` (add the bit flag to `CarStateType` and update `states_*Functions`) and create `CarState_<Name>.lua` in `CarStateMachine/States/` using `CarStateMachine/CarState_TEMPLATE.lua`.
    - **Logic only?** Extend the relevant manager (`CarOperations`, `CollisionAvoidanceManager`, etc.).

5. **Wiring**
    Call from `MANIFEST__UPDATE` in the entry point for per-frame work. Window icons use the manifest's `MANIFEST__FUNCTION_ICON`. For events, use `ac.onCarJumped` / `ac.onCarCollision` handlers registered in the entry point.

6. **Validate**
    Run the syntax checker (section 7); the count is determined dynamically from discovered files.

---

## 7. Useful commands

### Check Lua syntax
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
```
The checker uses `luajit` from `PATH` by default; optionally pass `-LuaJitPath <path>` and `-Root <project-root>`. Output reports the discovered count. It excludes `lib/ac_apps/` and `lib/AssettoCorsaCSPLuaCompatibilityManager/`, but not `lib/uilib/`.

### Find a function
```powershell
Select-String -Path '*.lua' -Pattern 'getActualTrackLateralOffset'
```

### List call sites for a function
```powershell
Select-String -Path '*.lua' -Pattern 'setAITopSpeed' | Select-Object -ExpandProperty FileName
```

### List all `.lua` files (excluding vendor)
```powershell
Get-ChildItem -Recurse -Filter *.lua | Where-Object { $_.FullName -notmatch '\\lib\\(ac_apps|AssettoCorsaCSPLuaCompatibilityManager)\\' }
```

---

## 8. Documentation links

| Document | Content |
| --- | --- |
| [Documentation index](README.md) | Task-oriented index and references |
| [OpenCode workflow](WORKFLOW_OPENCODE.md) | Task-scoped reading and handoff |
| [Architecture](ARCHITECTURE.md) | Code map, module coupling, hot paths |
| [Testing](TESTING.md) | Checks and in-game validation scenarios |
| [Localization](LOCALIZATION.md) | Locale, IDs, persistence, test contract |
| [UI redesign discovery](UI_REDESIGN_DISCOVERY.md) | Historical inventory and current status addendum |
| [UI identity plan](plans/UI_IDENTITY.md) | Proposed future UI direction |
| [Contributing](../CONTRIBUTING.md) | Contribution workflow |
| [Project README](../README.md) | Overview, manual installation, usage, credits |

---

## 9. Important cautions

- ⛔ **Do not use `&`, `|`, `~`** as operators. They are Lua 5.3 only; use `bit.band` / `bit.bor` / `bit.bnot`.
- ⛔ **Do not edit `lib/ac_apps/` as project code** (vendor SDK); update the compatibility submodule deliberately. `lib/uilib/` is project-owned, not vendor.
- ⛔ **Do not modify `manifest.ini`** for local testing. CSP loads the app from `apps/lua/<directory>/manifest.ini`.
- ⚠️ **Avoid allocations in hot paths.** Use reusable tables (e.g. `cars_currentReusableList`, `_reusableSideAnchorTable`) and pools such as `VecPool`.
- ⚠️ **The entry point checks CSP compatibility.** `physics.setAIBrakeMistake` and `physics.setAITractionMistake` are registered through `CSPCompatibilityManager.addFunction`; consult app diagnostics for missing APIs.
- ⚠️ **Respect DoD:** car state belongs in indexed tables, not instances.
- ⚠️ **Reuse existing structures:** check for tables/classes/storage/enums before creating new logic.
- ⚠️ **Intentional errors exist:** do not “fix” `HumanErrorManager` under the assumption that they are bugs.

---

## 10. Optional onboarding path

1. Skim this guide or the [documentation index](README.md) for the task at hand.
2. For main flow, locate `MANIFEST__UPDATE` in `SimOpenTrackDay.lua`.
3. For car behavior, inspect `CarStateMachine/CarStateMachine.lua` and a relevant state under `CarStateMachine/States/`.
4. For persistence, inspect `StorageManager.lua` schemas and `getStorage*()` getters.
5. Run relevant checks from [Testing](TESTING.md); a syntax check is not a substitute for UI or CSP validation.
