local root = (arg[0]:gsub('tools[\\/]test_session_lifecycle.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
local ffi = require('ffi')
local ffiAllowTrue = ffi.cast('bool (*)()', function() return true end)
local ffiAllowFalse = ffi.cast('bool (*)()', function() return false end)
table.clear = table.clear or function(value) for key in pairs(value) do value[key] = nil end end

local executed = {}
local lifecycleCars = {
  [0] = { index = 0, isAIControlled = true, isConnected = true, isActive = true, aiAggression = .5, aiLevel = 1 },
  [1] = { index = 1, isAIControlled = true, isConnected = true, isActive = true, aiAggression = .4, aiLevel = 1 },
}
local sdkCarReads = 0
local function assertValidSDKCarIndex(index)
  assert(type(index) == 'number' and index == index and index >= 0
    and index < math.huge and index % 1 == 0, 'SDK getCar received an invalid index: ' .. tostring(index))
  sdkCarReads = sdkCarReads + 1
end
local lifecycleSim = { isLive = true, isReplayActive = false, isSessionStarted = true,
  trackLengthM = 5000, raceSessionType = 1 }
ac = { getCar = function(index) assertValidSDKCarIndex(index); return lifecycleCars[index] end,
  getSim = function() return lifecycleSim end,
  getTrackName = function() return 'test-track' end, SessionType = { Undefined = 0, Practice = 1,
    Qualify = 2, Race = 3, Hotlap = 4, TimeAttack = 5, Drift = 6, Drag = 7 } }
local physicalWrites = {}
local physicalAllowed = true
local function recordPhysicalWrite(index, ...)
  physicalWrites[#physicalWrites + 1] = { index, ... }
end
physics = { allowed = function() return physicalAllowed end,
  disableCarCollisions = recordPhysicalWrite, setAITopSpeed = recordPhysicalWrite,
  setAIThrottleLimit = recordPhysicalWrite, setAICaution = recordPhysicalWrite,
  setAIAggression = recordPhysicalWrite, setAILevel = recordPhysicalWrite,
  setAIStopCounter = recordPhysicalWrite, setExtraAIGrip = recordPhysicalWrite,
  setGentleStop = recordPhysicalWrite, preventAIFromRetiring = recordPhysicalWrite,
  setAISplineOffset = recordPhysicalWrite }
Strings = { StringNames = { [1] = { None = 0 }, [2] = { None = 0 }, [3] = { None = 0 } },
  StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2, StateExitReason = 3 } }
CarStateMachine = { initializeCarInStateMachine = function() end }
AccidentManager = { setCarNavigatingAroundAccident = function() end, informAboutCarReset = function() end }
HumanErrorManager = { resetCar = function() end }
StorageManager = { getStorage = function() return {} end, getStorage_Overtaking = function() return {} end,
  getStorage_Yielding = function() return {} end, getStorage_AICarValues = function() return {} end,
  getStorage_Behavior = function() return {} end }
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
MathHelpers = { approach = function(value) return value end }
Logger = { log = function() end, warn = function() end, error = function() end }
render = { createRay = function() end }
VecPool = { getTempVec3 = function() end }
vec3 = function() return { set = function() end } end
CarOperations = nil
CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
CarManager = dofile(root .. 'CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
CarOperations = dofile(root .. 'CarOperations.lua')
local OnCarEventManager = dofile(root .. 'OnCarEventManager.lua')
local E = OnCarEventManager.OnCarEventType
OnCarEventManager.OnCarEventExecutions[E.Collision] = function(index, event)
  executed[#executed + 1] = { 'collision', index, event.collidedWith, event.x, event.positionX }
end
OnCarEventManager.OnCarEventExecutions[E.Jumped] = function(index) executed[#executed + 1] = { 'jump', index } end

local mutablePosition = { x = 2, y = 3, z = 4 }
local car = { position = { x = 10, y = 11, z = 12 }, splinePosition = .25 }
OnCarEventManager.enqueueOnCarEvent(E.Collision, 1, mutablePosition, 3, car)
mutablePosition.x, car.position.x, car.splinePosition = 99, 99, .99
OnCarEventManager.enqueueOnCarEvent(E.Jumped, 1)
OnCarEventManager.enqueueOnCarEvent(E.Collision, 1, { x = 7, y = 8, z = 9 }, 3,
  { position = { x = 20, y = 21, z = 22 }, splinePosition = .5 })
OnCarEventManager.processQueuedEvents()
assert(#executed == 2, 'old collision must drop while newer collision survives jump')
assert(executed[1][1] == 'jump' and executed[2][1] == 'collision')
assert(executed[2][4] == 7 and executed[2][5] == 20)

-- A victim generation change invalidates the collision even if its culprit is unchanged.
executed = {}
OnCarEventManager.enqueueOnCarEvent(E.Collision, 1, { x = 1, y = 2, z = 3 }, 1)
CarManager.bumpCarGeneration(0)
OnCarEventManager.processQueuedEvents()
assert(#executed == 0, 'collision involving reset player victim must be discarded')

-- Session invalidation makes pending records stale; clear also purges queued records.
OnCarEventManager.enqueueOnCarEvent(E.Collision, 1, { x = 1, y = 2, z = 3 }, 0)
CarManager.sessionGeneration = CarManager.sessionGeneration + 1
OnCarEventManager.processQueuedEvents()
assert(#executed == 0, 'old session collision must be discarded')
OnCarEventManager.enqueueOnCarEvent(E.Jumped, 1)
OnCarEventManager.clear()
OnCarEventManager.processQueuedEvents()
assert(#executed == 0, 'clear must purge queued callbacks')

-- Exercise the real AccidentManager with a recorder-backed collision writer:
-- collidedWith=1 encodes victim index 0, which must never receive a car write.
local accidentCars = {
  [0] = { index = 0, isAIControlled = true, isConnected = true, isActive = true, position = {}, splinePosition = .1 },
  [1] = { index = 1, isAIControlled = true, isConnected = true, isActive = true, position = {}, splinePosition = .2 },
}
ac.getCar = function(index) assertValidSDKCarIndex(index); return accidentCars[index] end
StorageManager.getStorage = function() return { distanceFromAccidentToSeeYellowFlag_meters = 100 } end
CarManager.cars_navigatingAroundAccidentIndex, CarManager.cars_navigatingAroundCarIndex = {}, {}
StorageManager.getStorage = function() return { distanceFromAccidentToSeeYellowFlag_meters = 100 } end
CarStateMachine = { CarStateType = { NAVIGATING_AROUND_ACCIDENT = 8192 },
  getCurrentState = function() end, informAboutAccident = function() end }
Logger = { log = function() end, warn = function() end }
vec3 = function(x, y, z) return { x = x, y = y, z = z } end
AccidentManager = dofile(root .. 'AccidentManager.lua')
local accident = AccidentManager.registerCollision(1, { x = 1, y = 2, z = 3 }, 1, {
  culpritGeneration = CarManager.getCarGeneration(1), victimGeneration = CarManager.getCarGeneration(0),
  positionX = 4, positionY = 5, positionZ = 6, splinePosition = .2,
  victimPositionX = 7, victimPositionY = 8, victimPositionZ = 9, victimSplinePosition = .1,
})
assert(accident and physicalWrites[1][1] == 1 and #physicalWrites == 1,
  'real CarOperations gate must write culprit 1 but reject victim player 0')
assert(AccidentManager.accidents_collidedWithCarIndex[accident] == 0)
assert(AccidentManager.cars_victimInAccidentIndex[0] == accident)
assert(RaceTrackManager.isSplinePositionInYellowZone(.15), 'real RaceTrackManager records collision zone')
AccidentManager.informAboutCarReset(0)
assert(AccidentManager.accidents_resolved[accident] == true)
assert(AccidentManager.cars_culpritInAccidentIndex[1] == nil)
assert(AccidentManager.cars_victimInAccidentIndex[0] == nil)
assert(AccidentManager.accidents_victimWorldPosition[accident] == nil
  and AccidentManager.accidents_victimSplinePosition[accident] == nil, 'resolve clears victim snapshots')
assert(not RaceTrackManager.isSplinePositionInYellowZone(.15), 'resolve removes the registered zone')

-- The real FSM is the dispatch boundary: rejected player writes never reach a state updater.
Strings = { StringNames = { [1] = { None = 0 }, [2] = { None = 0 }, [3] = { YieldingToCar = 0 } },
  StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2, StateExitReason = 3 } }
StringsManager = { setString = function() end }
StorageManager = { getStorage_Yielding = function() return {} end,
  getStorage_Overtaking = function() return {} end, getStorage = function() return {} end,
  getStorage_AICarValues = function() return {} end }
QueueManager = {
  createQueue = function() return {} end,
  enqueue = function(queue, value) queue[#queue + 1] = value end,
  dequeue = function(queue) return table.remove(queue, 1) end,
  queueLength = function(queue) return #queue end,
}
CarManager.cars_timeInCurrentState = {}
CarManager.cars_totalSideBlockRaysData, CarManager.cars_sideBlockRaysData = {}, {}
CarManager.cars_sideBlockRaysData[1] = {}
CarStateMachine = dofile(root .. 'CarStateMachine/CarStateMachine.lua')
local fsmWrites = 0
local driving = CarStateMachine.CarStateType.DRIVING_NORMALLY
CarStateMachine.states_updateFunctions[driving] = function() fsmWrites = fsmWrites + 1 end
CarStateMachine.states_entryFunctions[driving] = function() end
CarStateMachine.states_minimumTimeInState[driving] = 100
CarStateMachine.states_transitionFunctions[driving] = function() end
CarStateMachine.states_exitFunctions[driving] = function() end
CarStateMachine.queueStateTransition(0, driving)
CarStateMachine.updateCar(0, 1, {}, 1)
assert(fsmWrites == 0, 'player must be rejected at central FSM dispatch')
CarStateMachine.queueStateTransition(1, driving)
CarStateMachine.updateCar(1, 1, {}, 1)
assert(fsmWrites == 1, 'eligible AI state updater should run')

CarManager.cars_currentlyOvertakingCarIndex[20] = 1
CarManager.cars_currentlyYieldingCarToIndex[21] = 1
CarManager.cars_navigatingAroundCarIndex[22] = 1
CarManager.cars_navigatingAroundAccidentIndex[22] = 70
for _, owner in ipairs({ 20, 21, 22 }) do
  CarManager.carGeneration[owner] = 0
  CarManager.cars_initialized[owner] = true
end
CarManager.clearCarMemory(1)
assert(CarManager.cars_currentlyOvertakingCarIndex[20] == nil
  and CarManager.cars_currentlyYieldingCarToIndex[21] == nil
  and CarManager.cars_navigatingAroundCarIndex[22] == nil
  and CarManager.cars_navigatingAroundAccidentIndex[22] == nil,
  'reset target clears incoming dependent references without recursion')
assert(CarManager.getCarGeneration(20) == 1 and CarManager.getCarGeneration(21) == 1
  and CarManager.getCarGeneration(22) == 1
  and CarManager.cars_initialized[20] and CarManager.cars_initialized[21] and CarManager.cars_initialized[22],
  'dependent owners are lifecycle-invalidated without clearing their observed identity')

-- A pending accident is invalidated if either participant jumps before dequeue.
AccidentManager.accidents_carIndex[50] = 1
AccidentManager.accidents_collidedWithCarIndex[50] = 2
AccidentManager.accidents_collidedWithTrack[50] = false
AccidentManager.accidents_resolved[50] = false
CarStateMachine.informAboutAccident(50)
CarManager.bumpCarGeneration(2)
CarStateMachine.handleQueuedAccidents()
CarStateMachine.updateCar(1, 1, {}, 1)
assert(CarStateMachine.getCurrentState(1) == driving, 'jumped victim invalidates culprit pending transition')

-- A missing direct API in the legacy flood state blocks dispatch before entry/update calls.
local writesBeforeMissingFloodAPI = fsmWrites
physics = { allowed = function() return true end }
CarStateMachine.queueStateTransition(1, CarStateMachine.CarStateType.AFTER_CUSTOMAIFLOOD_TELEPORT)
CarStateMachine.updateCar(1, 1, {}, 1)
assert(fsmWrites == writesBeforeMissingFloodAPI, 'missing flood-state APIs must fail closed')

-- Invalid dt cannot advance human-error simulation or touch mistake APIs.
local mistakes = 0
physics = { allowed = function() return true end,
  setAIBrakeMistake = function() mistakes = mistakes + 1 end,
  setAITractionMistake = function() mistakes = mistakes + 1 end }
local HumanErrorManager = dofile(root .. 'HumanErrorManager.lua')
local sorted = { { index = 1, brake = 1, gas = 1 } }
for _, dt in ipairs({ 0, -1, math.huge }) do
  HumanErrorManager.update(dt, sorted, { humanErrorEnabled = true, humanLockupProbability = 1,
    humanTractionMistakeProbability = 1 }, 1)
end
HumanErrorManager.update(0/0, sorted, { humanErrorEnabled = true, humanLockupProbability = 1,
  humanTractionMistakeProbability = 1 }, 1)
assert(mistakes == 0)
HumanErrorManager.lastEventTimeByCar[1] = 123
HumanErrorManager.resetCar(1)
assert(HumanErrorManager.lastEventTimeByCar[1] == nil)

-- Load the actual entry point with UI/SDK boundary mocks while retaining the real lifecycle modules.
local runtimeStorage = { enabled = true, handleAccidents = true, globalTopSpeedLimitKmh = 0,
  distanceFromAccidentToSeeYellowFlag_meters = 100 }
StorageManager.getStorage = function() return runtimeStorage end
StorageManager.getStorage_Global = function() return { appRanFirstTime = true } end
StorageManager.getStorage_Behavior = function() return { humanErrorEnabled = false } end
local entryCars = {
  { index = 0, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 75,
    splinePosition = .1, brake = 0, gas = 0, position = { x = 0, y = 0, z = 0 },
    collisionPosition = { x = 1, y = 2, z = 3 }, collidedWith = 0, aiAggression = .5, aiLevel = 1 },
  { index = 1, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 90,
    splinePosition = .2, brake = 0, gas = 0, position = { x = 1, y = 0, z = 1 },
    collisionPosition = { x = 1, y = 2, z = 3 }, collidedWith = 3, aiAggression = .4, aiLevel = 1 },
  { index = 2, isAIControlled = false, isConnected = true, isActive = true, speedKmh = 80,
    splinePosition = .3, brake = 0, gas = 0, position = { x = 2, y = 0, z = 2 } },
  { index = 3, isAIControlled = true, isConnected = true, isActive = false, speedKmh = 70,
    splinePosition = .4, brake = 0, gas = 0, position = { x = 3, y = 0, z = 3 } },
}
local entryCarPresent = { true, true, true, true }
local callbacks = {}
ac.getCar = function(index)
  assertValidSDKCarIndex(index)
  for i = 1, #entryCars do if entryCars[i].index == index then return entryCars[i] end end
end
ac.getSim = function() return lifecycleSim end
ac.iterateCars = function()
  local i, cursor = 0, 0
  return function()
    while true do
      cursor = cursor + 1
      if not entryCars[cursor] then return end
      if entryCarPresent[cursor] then
        i = i + 1
        return i, entryCars[cursor]
      end
    end
  end
end
ac.onCarCollision = function(_, callback) callbacks.collision = callback end
ac.onCarJumped = function(_, callback) callbacks.jump = callback end
ac.onCarSwap = function(_, callback) callbacks.swap = callback end
ac.onSessionStart = function(callback) callbacks.session = callback end
ac.log, ac.warn, ac.error = function() end, function() end, function() end
ac.FlagType = { None = 0, Caution = 1 }
local flagWrites = {}
physics.allowed = function() return physicalAllowed end
local flagPermissionAtWrite = {}
physics.overrideRacingFlag = function(flag)
  flagWrites[#flagWrites + 1] = flag
  flagPermissionAtWrite[#flagPermissionAtWrite + 1] = physicalAllowed
end
local gateDiagnosticLogs = {}
Logger.log = function(message) gateDiagnosticLogs[#gateDiagnosticLogs + 1] = message end
local function countGateDiagnosticLogs(fragment)
  local count = 0
  for i = 1, #gateDiagnosticLogs do
    if string.find(gateDiagnosticLogs[i], fragment, 1, true) then count = count + 1 end
  end
  return count
end
local uiNoop = function() end
ui = setmetatable({ Icons = { Cancel = 1 }, Font = { Title = 1, Main = 2 } },
  { __index = function() return uiNoop end })
rgbm = function() return {} end
script = {}
local compatibilityRegistrations = {}
local compatibility = { addFunction = function(_, name) compatibilityRegistrations[name] = true end,
  addSimStateFunction = function() end,
  checkForMissingElements = function() return true end, getLastGeneratedErrorMessage = function() return '' end,
  freeMemory = function() end }
local constants = { CAN_APP_RUN = true, IS_ONLINE = false, APP_NAME = 'test', APP_VERSION = '1' }
local clockUpdates = 0
local gameTime = { update = function() clockUpdates = clockUpdates + 1 end, getPlayingGameTime = function() return clockUpdates end }
CameraManager = { getFocusedCarIndex = function() return 0 end }
local sessionUpdates = 0
SessionDetails = { update = function() sessionUpdates = sessionUpdates + 1 end, informSessionInitiated = function() end }
RaceFlagManager = { setRaceFlag = function(flag) physics.overrideRacingFlag(flag) end,
  removeRaceFlag = function() physics.overrideRacingFlag(ac.FlagType.None) end }
local noopModule = {}
local loaded = {
  Constants = constants, Logger = Logger,
  ['lib.AssettoCorsaCSPLuaCompatibilityManager.CSPCompatibilityManager'] = compatibility,
  VecPool = VecPool, DequeManager = noopModule, StackManager = noopModule,
  ['DataStructures.DequeManager'] = noopModule, ['DataStructures.StackManager'] = noopModule,
  ['DataStructures.QueueManager'] = QueueManager,
  ['DataStructures.CompletableIndexCollectionManager'] = CompletableIndexCollectionManager,
  GameTimeManager = gameTime, AppIconRenderer = noopModule, ColorManager = ColorManager,
  RaceTrackManager = RaceTrackManager, StorageManager = StorageManager, MathHelpers = MathHelpers,
  CarManager = CarManager, CarOperations = CarOperations, CameraManager = CameraManager,
  ['Strings.Strings'] = Strings, ['Strings.Strings_ReasonWhyCantYield'] = true,
  ['Strings.Strings_ReasonWhyCantOvertake'] = true, ['Strings.Strings_StateExitReason'] = true,
  StringsManager = StringsManager, OnCarEventManager = OnCarEventManager,
  ['CarStateMachine.CarStateMachine'] = CarStateMachine,
  AccidentManager = AccidentManager, RaceFlagManager = RaceFlagManager,
  UILateralOffsetsImageWidget = noopModule, UIAppNameVersionWidget = noopModule,
  UIOperations = noopModule, UIManager = { openMainWindow = function() end },
  ['lib/uilib/Logo'] = noopModule, SessionDetails = SessionDetails,
  Pathfinding = noopModule, BehaviorPolish = noopModule, HumanErrorManager = HumanErrorManager,
  SettingsWindow = noopModule, MainWindow = { draw = function() end },
}
for name, value in pairs(loaded) do package.loaded[name] = value end
for _, name in ipairs({ 'CarStateMachine.States.CarState_DrivingNormally',
  'CarStateMachine.States.CarState_EasingInYield', 'CarStateMachine.States.CarState_StayingOnYieldingLane',
  'CarStateMachine.States.CarState_EasingOutYield', 'CarStateMachine.States.CarState_CollidedWithCar',
  'CarStateMachine.States.CarState_CollidedWithTrack', 'CarStateMachine.States.CarState_AnotherCarCollidedIntoMe',
  'CarStateMachine.States.CarState_EasingInOvertake', 'CarStateMachine.States.CarState_StayingOnOvertakingLane',
  'CarStateMachine.States.CarState_EasingOutOvertake', 'CarStateMachine.States.CarState_NavigatingAroundAccident',
  'CarStateMachine.States.CarState_DrivingInYellowFlagZone', 'CarStateMachine.States.CarState_AfterCustomAIFloodTeleport' }) do
  package.loaded[name] = true
end
local oldDir = __dirname
__dirname = root:gsub('[\\/]+$', '')
if __dirname == '' then __dirname = '.' end
assert(loadfile(root .. 'SimOpenTrackDay.lua'))()
__dirname = oldDir
assert(compatibilityRegistrations['physics.allowed'] and compatibilityRegistrations['physics.setAILevel']
  and compatibilityRegistrations['ac.onCarSwap'], 'new critical APIs are registered with CSP compatibility checks')
for _, state in pairs(CarStateMachine.CarStateType) do
  if type(state) == 'number' then
    CarStateMachine.states_entryFunctions[state] = function() end
    CarStateMachine.states_updateFunctions[state] = function() end
    CarStateMachine.states_minimumTimeInState[state] = 1000
    CarStateMachine.states_transitionFunctions[state] = function() end
    CarStateMachine.states_exitFunctions[state] = function() end
  end
end
assert(CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .4, 'entry awake captures eligible AI baseline')
local physicalWritesBeforeFirstEntryUpdate = #physicalWrites
script.MANIFEST__UPDATE(1)
assert(CarManager.cars_speedSampleCount[0] == 1 and CarManager.cars_speedSampleCount[2] == 1,
  'real entry update initializes player/human buffers before speed sampling')
assert(CarManager.isWritableAICar(1) and not CarManager.isWritableAICar(0)
  and not CarManager.isWritableAICar(3), 'entry gate uses live SDK properties, player and inactive exclusions')
assert(countGateDiagnosticLogs('[M1a-GATE] TEMP diagnostic active') == 1
  and countGateDiagnosticLogs('[M1a-GATE] sample car=1 result=eligible') == 1,
  'real entry emits installation marker and positive sample once')
assert(countGateDiagnosticLogs('physicsAllowedType=function physicsAllowedValue=function:') == 1,
  'diagnostic records the permission API representation without calling it again')
assert(#physicalWrites == physicalWritesBeforeFirstEntryUpdate,
  'diagnostic marker and positive sampling add no car actuation')
local allowedApiBeforeFFIControl = physics.allowed
local requestedTopSpeedBeforeFFIControl = CarManager.cars_aiTopSpeed[1]
local writesBeforeFFIControl = #physicalWrites
physics.allowed = ffiAllowTrue
physicalAllowed = true
assert(CarManager.hasPhysicsPermission() and CarManager.isWritableAICar(1),
  'real entry-loaded gate accepts callable cdata returning true')
CarOperations.setAITopSpeed(1, 100)
assert(#physicalWrites == writesBeforeFFIControl + 1
  and physicalWrites[#physicalWrites][1] == 1,
  'real entry harness permits the positive AI control with cdata permission')
CarManager.cars_aiTopSpeed[1] = requestedTopSpeedBeforeFFIControl
physics.allowed = allowedApiBeforeFFIControl
physicalAllowed = false
local physicalWritesBeforeDenial = #physicalWrites
local savedAllowed = physics.allowed
physics.allowed = ffiAllowFalse
script.MANIFEST__UPDATE(1)
script.MANIFEST__UPDATE(1)
assert(countGateDiagnosticLogs('result=physics-denied') == 1
  and countGateDiagnosticLogs('physicsCheck=false') == 1,
  'gate denial is deduplicated and reports the permission result')
assert(countGateDiagnosticLogs('physicsAllowedType=cdata physicsAllowedValue=cdata') == 1,
  'raw diagnostic identifies the callable cdata permission representation')
assert(#physicalWrites == physicalWritesBeforeDenial, 'denied diagnostic samples add no car actuation')
physics.allowed = function() error('diagnostic permission error') end
script.MANIFEST__UPDATE(1)
script.MANIFEST__UPDATE(1)
assert(countGateDiagnosticLogs('result=physics-allowed-error') == 1,
  'pcall error has a distinct deduplicated gate reason')
physics.allowed = nil
local savedTopSpeedForDiagnostic = physics.setAITopSpeed
physics.setAITopSpeed = function() error('diagnostic must not invoke an AI setter') end
script.MANIFEST__UPDATE(1)
assert(countGateDiagnosticLogs('result=physics-allowed-missing') == 1,
  'missing permission API has a distinct diagnostic reason')
assert(countGateDiagnosticLogs('physicsCheck=unavailable') == 1,
  'missing permission is reported as unavailable, not an unperformed early gate check')
assert(countGateDiagnosticLogs('physicsAllowedType=nil physicsAllowedValue=nil physicsTopSpeedType=function') == 1,
  'diagnostic distinguishes a missing permission API from available AI setters')
physics.setAITopSpeed = savedTopSpeedForDiagnostic
physics.allowed = savedAllowed
physicalAllowed = true

local readsBeforeInvalidCollision = sdkCarReads
local writesBeforeInvalidCollision = #physicalWrites
local accidentsBeforeInvalidCollision = CompletableIndexCollectionManager.getLastIndexCreated(1)
for _, invalidIndex in ipairs({ 0/0, 1.5, math.huge }) do callbacks.collision(invalidIndex) end
callbacks.collision(nil)
assert(sdkCarReads == readsBeforeInvalidCollision
  and #physicalWrites == writesBeforeInvalidCollision,
  'invalid culprit indices return before SDK lookup or physical writer')
for _, invalidCollider in ipairs({ 0/0, 1.5, math.huge, -1 }) do
  entryCars[2].collidedWith = invalidCollider
  local readsBeforeCollider = sdkCarReads
  callbacks.collision(1)
  assert(sdkCarReads == readsBeforeCollider + 2,
    'invalid collidedWith must not be passed to ac.getCar (only gate and culprit lookups occur)')
end
entryCars[2].collidedWith = 3
script.MANIFEST__UPDATE(1)
assert(CompletableIndexCollectionManager.getLastIndexCreated(1) == accidentsBeforeInvalidCollision
  and #physicalWrites == writesBeforeInvalidCollision,
  'invalid collision callbacks enqueue no accident and cause no physical actuation')

local identityGeneration = CarManager.getCarGeneration(1)
entryCars[2].isAIControlled = false
script.MANIFEST__UPDATE(1)
assert(CarManager.getCarGeneration(1) == identityGeneration + 1
  and not CarManager.isWritableAICar(1)
  and CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == nil,
  'AI-to-human identity change invalidates AI baseline and closes writer gate')
entryCars[2].isAIControlled = true
script.MANIFEST__UPDATE(1)
assert(CarManager.isWritableAICar(1) and CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .4,
  'human-to-AI transition recaptures current baseline')
identityGeneration = CarManager.getCarGeneration(1)
entryCarPresent[2] = false
script.MANIFEST__UPDATE(1)
assert(CarManager.getCarGeneration(1) == identityGeneration + 1
  and CarManager.cars_initialized[1] == nil
  and CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == nil,
  'disappearing car invalidates its identity memory and baseline')
entryCarPresent[2] = true
script.MANIFEST__UPDATE(1)
assert(CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .4,
  'reappearing car recaptures baseline rather than inheriting stale memory')

-- Keep the real vulnerable overtake transition and normal-driving entry closures in this integration case.
ac.TurningLights = { None = 0 }
ac.setTargetCar = function() return true end
ac.setTurningLights = function() end
ac.worldCoordinateToTrack = function() return { x = 0 } end
dofile(root .. 'CarStateMachine/States/CarState_StayingOnOvertakingLane.lua')
dofile(root .. 'CarStateMachine/States/CarState_DrivingNormally.lua')
local staying = CarStateMachine.CarStateType.STAYING_ON_OVERTAKING_LANE
local realStayingTransition = CarStateMachine.states_transitionFunctions[staying]
local realStayingEntry = CarStateMachine.states_entryFunctions[staying]
local realStayingUpdate = CarStateMachine.states_updateFunctions[staying]
local realDrivingEntry = CarStateMachine.states_entryFunctions[driving]
CarStateMachine.states_entryFunctions[staying] = function() end
CarStateMachine.states_updateFunctions[staying] = function() end
CarStateMachine.states_transitionFunctions[staying] = function() end
CarStateMachine.queueStateTransition(1, staying)
CarStateMachine.updateCar(1, 1, { entryCars[2] }, 1)
assert(CarStateMachine.getCurrentState(1) == staying)
CarStateMachine.states_transitionFunctions[staying] = realStayingTransition
CarStateMachine.states_entryFunctions[driving] = realDrivingEntry
CarManager.cars_currentlyOvertakingCarIndex[1] = 0
CarManager.cars_currentlyYieldingCarToIndex[1] = 2
CarManager.cars_navigatingAroundCarIndex[1] = 0
CarManager.cars_navigatingAroundAccidentIndex[1] = 91
CarManager.cars_initialized[1] = true
CarManager.cars_ORIGINAL_AI_AGGRESSION[1] = .43
CarManager.cars_ORIGINAL_AI_DIFFICULTY_LEVEL[1] = 1
CarManager.cars_AABBSIZE[1] = { x = 2, y = 3, z = 4 }
CarManager.cars_HALF_AABSIZE[1] = { x = 1, y = 1.5, z = 2 }
local dependentGeneration = CarManager.getCarGeneration(1)
local writesBeforeSwap = #physicalWrites
callbacks.swap(0)
assert(#physicalWrites == writesBeforeSwap, 'swap invalidation is memory-only')
assert(CarStateMachine.getCurrentState(1) == nil
  and CarManager.cars_currentlyOvertakingCarIndex[1] == nil
  and CarManager.cars_currentlyYieldingCarToIndex[1] == nil
  and CarManager.cars_navigatingAroundCarIndex[1] == nil
  and CarManager.cars_navigatingAroundAccidentIndex[1] == nil,
  'A swap durably invalidates B maneuver state before queue purge')
assert(CarManager.getCarGeneration(1) == dependentGeneration + 1
  and CarManager.cars_initialized[1]
  and CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .43
  and CarManager.cars_ORIGINAL_AI_DIFFICULTY_LEVEL[1] == 1
  and CarManager.cars_AABBSIZE[1].z == 4 and CarManager.cars_HALF_AABSIZE[1].z == 2,
  'B identity, baselines and dimensions survive A swap invalidation')
assert(CarStateMachine.states_transitionFunctions[staying] == realStayingTransition,
  'the real staying-on-overtake transition remains installed')
CarStateMachine.states_updateFunctions[driving] = function() end
CarStateMachine.states_transitionFunctions[driving] = function() end
local errorsBeforeRecovery = 0
local loggerError = Logger.error
Logger.error = function() errorsBeforeRecovery = errorsBeforeRecovery + 1 end
CarStateMachine.updateCar(1, 1, { entryCars[2] }, 1)
Logger.error = loggerError
assert(CarStateMachine.getCurrentState(1) == driving
  and CarStateMachine.states_entryFunctions[driving] == realDrivingEntry
  and errorsBeforeRecovery == 0,
  'cleared state recovers through the real DrivingNormally entry without stale nil lookup')

local initialCarGeneration = CarManager.getCarGeneration(1)
callbacks.swap(1)
assert(CarManager.getCarGeneration(1) == initialCarGeneration + 1
  and CarManager.cars_initialized[1] == nil, 'onCarSwap invalidates memory and generation')
entryCars[2].aiAggression, entryCars[2].aiLevel = .7, 2
entryCars[2].aabbSize = setmetatable({ x = 2, y = 1, z = 4 }, {
  __mul = function(value, scalar) return setmetatable({ x = value.x * scalar, y = value.y * scalar,
    z = value.z * scalar }, getmetatable(value)) end })
script.MANIFEST__UPDATE(1)
assert(CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .7 and CarManager.cars_HALF_AABSIZE[1].z == 2,
  'post-swap observation recaptures baseline and dimensions before dispatch')

local beforeAccidents = CompletableIndexCollectionManager.getLastIndexCreated(1)
callbacks.collision(1)
callbacks.jump(1)
entryCars[2].collisionPosition = { x = 4, y = 5, z = 6 }
callbacks.collision(1)
script.MANIFEST__UPDATE(1)
local afterAccidents = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(afterAccidents == beforeAccidents + 1, 'Collision->Jumped->Collision discards only the stale collision')

local frozenTime = CarManager.cars_timeInCurrentState[1]
local frozenBaseline = CarManager.cars_ORIGINAL_AI_AGGRESSION[1]
HumanErrorManager.lastEventTimeByCar[1] = 321
local gameTimeBeforePause, flagCount = clockUpdates, #flagWrites
local allowedApiBeforeFlagPause = physics.allowed
physics.allowed = ffiAllowTrue
physicalAllowed = true
lifecycleSim.isLive = false
lifecycleSim.isPaused = true
script.MANIFEST__UPDATE(10)
callbacks.collision(1)
script.MANIFEST__UPDATE(10)
assert(clockUpdates == gameTimeBeforePause and CarManager.cars_timeInCurrentState[1] == frozenTime
  and CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == frozenBaseline
  and HumanErrorManager.lastEventTimeByCar[1] == 321,
  'pause freezes simulation time, FSM state, cooldown and baseline')
assert(#flagWrites == flagCount + 1 and flagWrites[#flagWrites] == ac.FlagType.None,
  'pause boundary releases only the owned global flag once')
assert(countGateDiagnosticLogs('[M1a-GATE] mode=pause') == 1,
  'pause reason is logged before the update early return')
local pausedAccidentCount = CompletableIndexCollectionManager.getLastIndexCreated(1)
lifecycleSim.isLive, lifecycleSim.isPaused = true, false
script.MANIFEST__UPDATE(1)
assert(CompletableIndexCollectionManager.getLastIndexCreated(1) == pausedAccidentCount,
  'collision callbacks during pause are not replayed after resume')
physics.allowed = allowedApiBeforeFlagPause

local flagCountBeforeDeniedRelease = #flagWrites
runtimeStorage.enabled = false
physics.allowed = ffiAllowFalse
physicalAllowed = false
script.MANIFEST__UPDATE(1)
assert(#flagWrites == flagCountBeforeDeniedRelease,
  'false callable cdata permission never releases a flag')
runtimeStorage.enabled = true
physics.allowed = allowedApiBeforeFlagPause
physicalAllowed = true
script.MANIFEST__UPDATE(1)

-- An allowed=false dispatch can leave initialization pending; pause purges it, then nil state recovers.
CarStateMachine.initializeCarInStateMachine(1)
physicalAllowed = false
local errorsBeforeDeniedResume = 0
loggerError = Logger.error
Logger.error = function() errorsBeforeDeniedResume = errorsBeforeDeniedResume + 1 end
script.MANIFEST__UPDATE(1)
assert(CarStateMachine.getCurrentState(1) == nil, 'denied dispatch cannot transition or update; state='
  .. tostring(CarStateMachine.getCurrentState(1)) .. ' allowed=' .. tostring(physicalAllowed)
  .. ' gate=' .. tostring(CarManager.isWritableAICar(1)))
lifecycleSim.isLive, lifecycleSim.isPaused = false, true
script.MANIFEST__UPDATE(1)
assert(CarStateMachine.getCurrentState(1) == nil, 'pause purges queued initialization')
physicalAllowed = true
lifecycleSim.isLive, lifecycleSim.isPaused = true, false
script.MANIFEST__UPDATE(1)
assert(CarStateMachine.getCurrentState(1) == driving, 'resume falls back to DrivingNormally after stale queue purge')
script.MANIFEST__UPDATE(1)
Logger.error = loggerError
assert(errorsBeforeDeniedResume == 0, 'denied/pause/resume does not repeat nil-state diagnostics')

-- A current valid request wins over nil-state fallback; a stale request is discarded before fallback.
CarStateMachine.initializeCarInStateMachine(1)
CarStateMachine.states_entryFunctions[staying] = function() end
CarStateMachine.states_updateFunctions[staying] = function() end
CarStateMachine.states_transitionFunctions[staying] = function() end
CarStateMachine.queueStateTransition(1, staying)
CarStateMachine.updateCar(1, 1, { entryCars[2] }, 1)
assert(CarStateMachine.getCurrentState(1) == staying, 'valid pending state has priority over normal fallback')
CarStateMachine.initializeCarInStateMachine(1)
CarManager.bumpCarGeneration(1)
CarStateMachine.updateCar(1, 1, { entryCars[2] }, 1)
assert(CarStateMachine.getCurrentState(1) == driving, 'stale pending state is discarded before nil-state fallback')
CarStateMachine.states_entryFunctions[staying] = realStayingEntry
CarStateMachine.states_updateFunctions[staying] = realStayingUpdate
CarStateMachine.states_transitionFunctions[staying] = realStayingTransition

-- Repeated integrated disable/replay edges purge callbacks and remain physically write-free.
local lifecycleFlagCount = #flagWrites
for _ = 1, 10 do
  runtimeStorage.enabled = false
  physicalAllowed = true
  local writesBeforeDisabledEdge = #physicalWrites
  script.MANIFEST__UPDATE(1)
  local disabledAccidentCount = CompletableIndexCollectionManager.getLastIndexCreated(1)
  callbacks.collision(1)
  assert(#physicalWrites == writesBeforeDisabledEdge, 'disabled edge/callback performs no car writes')
  assert(HumanErrorManager.lastEventTimeByCar[1] == nil, 'disable clears cooldown state')
  runtimeStorage.enabled = true
  lifecycleSim.isLive, lifecycleSim.isReplayActive = true, false
  script.MANIFEST__UPDATE(1)
  assert(CompletableIndexCollectionManager.getLastIndexCreated(1) == disabledAccidentCount,
    'disabled collision is not delivered after resume')

  physicalAllowed = true
  lifecycleSim.isLive, lifecycleSim.isReplayActive = false, true
  HumanErrorManager.lastEventTimeByCar[1] = 777
  local writesBeforeReplayEdge = #physicalWrites
  script.MANIFEST__UPDATE(1)
  local replayAccidentCount = CompletableIndexCollectionManager.getLastIndexCreated(1)
  callbacks.collision(1)
  assert(#physicalWrites == writesBeforeReplayEdge, 'replay edge/callback performs no car writes')
  assert(HumanErrorManager.lastEventTimeByCar[1] == nil, 'replay clears cooldown state')
  lifecycleSim.isReplayActive, lifecycleSim.isLive = false, true
  physicalAllowed = true
  script.MANIFEST__UPDATE(1)
  assert(CompletableIndexCollectionManager.getLastIndexCreated(1) == replayAccidentCount
    and not RaceTrackManager.isSplinePositionInYellowZone(.15),
    'replay collision/zones are not inherited after resume')
end
for i = lifecycleFlagCount + 1, #flagWrites do
  assert(flagWrites[i] == ac.FlagType.None and flagPermissionAtWrite[i] == true,
    'flag cleanup is None-only and occurs only while physics permission is available')
end
assert(countGateDiagnosticLogs('[M1a-GATE] mode=disabled') == 1
  and countGateDiagnosticLogs('[M1a-GATE] mode=replay') == 1,
  'disable and replay suspension reasons are logged once despite ten repeated cycles')

runtimeStorage.enabled = false
local sessionGenerationBefore = CarManager.sessionGeneration
callbacks.session()
assert(CarManager.sessionGeneration == sessionGenerationBefore + 1,
  'session start invalidates lifecycle even while disabled')
local eligibleLogsBeforeNewSession = countGateDiagnosticLogs('result=eligible')
runtimeStorage.enabled = true
physicalAllowed = true
lifecycleSim.isLive, lifecycleSim.isReplayActive, lifecycleSim.isSessionStarted = true, false, true
script.MANIFEST__UPDATE(1)
assert(countGateDiagnosticLogs('result=eligible') == eligibleLogsBeforeNewSession + 1,
  'session generation resets per-reason log deduplication')
entryCars[2].isAIControlled, entryCars[4].isAIControlled = false, false
script.MANIFEST__UPDATE(1)
script.MANIFEST__UPDATE(1)
assert(countGateDiagnosticLogs('no non-player AI sample available') == 1,
  'no-AI sample fact is logged once per session')
print('test_entry_lifecycle: PASS')
print('test_session_lifecycle: PASS')
