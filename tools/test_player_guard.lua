local root = (arg[0]:gsub('tools[\\/]test_player_guard.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
local ffi = require('ffi')
local ffiAllowTrue = ffi.cast('bool (*)()', function() return true end)
local ffiAllowFalse = ffi.cast('bool (*)()', function() return false end)
table.clear = table.clear or function(value) for key in pairs(value) do value[key] = nil end end

local writes = {}
local cars = {
  [0] = { index = 0, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 80 },
  [1] = { index = 1, isAIControlled = true, isConnected = true, isActive = true, aiAggression = .4, aiLevel = 1 },
  [2] = { index = 2, isAIControlled = false, isConnected = true, isActive = true, speedKmh = 90 },
  [3] = { index = 3, isAIControlled = true, isConnected = false, isActive = true },
  [4] = { index = 5, isAIControlled = true, isConnected = true, isActive = true },
  [5] = { index = 5, isAIControlled = true, isConnected = true, isActive = false },
}
local sim = { isLive = true, isReplayActive = false, isSessionStarted = true }
local allowed = true
local function record(name) return function(index) writes[#writes + 1] = { name, index } end end
ac = { getCar = function(i)
    assert(type(i) == 'number' and i == i and i >= 0 and i < math.huge and i % 1 == 0,
      'SDK getCar received invalid index: ' .. tostring(i))
    return cars[i]
  end, getSim = function() return sim end,
  overrideCarControls = function(i) writes[#writes + 1] = { 'controls', i }; return {} end,
  setTargetCar = function(i) writes[#writes + 1] = { 'target', i }; return true end,
  setTurningLights = function() writes[#writes + 1] = { 'lights' } end,
  TurningLights = { None = 0, Left = 1, Right = 2 } }
physics = { allowed = function() return allowed end,
  setAITopSpeed = record('speed'), setAIThrottleLimit = record('throttle'),
  setAICaution = record('caution'), setAIAggression = record('aggression'),
  setAILevel = record('level'), setAIStopCounter = record('stop'),
  setExtraAIGrip = record('grip'), disableCarCollisions = record('collision'),
  setGentleStop = record('gentle'), preventAIFromRetiring = record('retire'),
  setAISplineOffset = record('spline'), setAIBrakeMistake = record('brakeMistake'),
  setAITractionMistake = record('tractionMistake') }
Strings = { StringNames = { [1] = { None = 0 }, [2] = { None = 0 } },
  StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2 } }
AccidentManager = { setCarNavigatingAroundAccident = function() end, informAboutCarReset = function() end }
CarStateMachine = { initializeCarInStateMachine = function() end }
HumanErrorManager = { resetCar = function() end }
StorageManager = {
  getStorage = function() return {} end,
  getStorage_Overtaking = function() return {} end,
  getStorage_Yielding = function() return {} end,
  getStorage_AICarValues = function() return { defaultAICaution = 1 } end,
}
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
MathHelpers = { approach = function(a) return a end, vsub = function() end, dot = function() end }
RaceTrackManager = { TrackSide = { LEFT = 1, RIGHT = 2 } }
Logger = { error = function() end, log = function() end, warn = function() end }
render = { createRay = function() end }
VecPool = { getTempVec3 = function() end }
vec3 = function() return { set = function() end } end

CarManager = dofile(root .. 'CarManager.lua')
local CarOperations = dofile(root .. 'CarOperations.lua')
local function assertNoWrites(label)
  assert(#writes == 0, label .. ': observed ' .. #writes .. ' writes')
end

assert(CarManager.isWritableAICar(1))
local writable, returnedCar, gateReason = CarManager.isWritableAICar(1)
assert(writable == true and returnedCar == cars[1] and gateReason == 'eligible',
  'successful gate preserves true, car second return and adds stable success reason')
local function assertGateReason(index, expectedReason)
  local accepted, car, reason = CarManager.isWritableAICar(index)
  assert(accepted == false and car == nil and reason == expectedReason,
    'expected gate reason ' .. expectedReason .. ', got ' .. tostring(reason))
end
assertGateReason(nil, 'invalid-index')
CarManager.runtimeEnabled = false; assertGateReason(1, 'runtime-disabled'); CarManager.runtimeEnabled = true
CarManager.runtimePaused = true; assertGateReason(1, 'runtime-paused'); CarManager.runtimePaused = false
CarManager.runtimeLive = false; assertGateReason(1, 'runtime-not-live'); CarManager.runtimeLive = true
local originalGetSim = ac.getSim
ac.getSim = function() return nil end; assertGateReason(1, 'sim-missing'); ac.getSim = originalGetSim
sim.isLive = false; assertGateReason(1, 'sim-not-live'); sim.isLive = true
sim.isReplayActive = true; assertGateReason(1, 'sim-replay-active'); sim.isReplayActive = nil
assertGateReason(1, 'sim-replay-state-unknown'); sim.isReplayActive = false
sim.isSessionStarted = false; assertGateReason(1, 'sim-session-not-started'); sim.isSessionStarted = true
local originalPhysics = physics
physics = nil; assertGateReason(1, 'physics-missing'); physics = originalPhysics
local originalAllowed = physics.allowed
physics.allowed = false; assertGateReason(1, 'physics-allowed-not-callable')
physics.allowed = function() error('permission probe failed') end
assertGateReason(1, 'physics-allowed-error')
physics.allowed = function() return false end; assertGateReason(1, 'physics-denied')
physics.allowed = function() return nil end; assertGateReason(1, 'physics-allowed-not-true')
physics.allowed = function() return 1 end; assertGateReason(1, 'physics-allowed-not-true')
physics.allowed = function() return 'true' end; assertGateReason(1, 'physics-allowed-not-true')
physics.allowed = true; assertGateReason(1, 'physics-allowed-not-callable')
physics.allowed = 'true'; assertGateReason(1, 'physics-allowed-not-callable')
physics.allowed = {}; assertGateReason(1, 'physics-allowed-not-callable')
physics.allowed = ffi.new('int', 1); assertGateReason(1, 'physics-allowed-error')
physics.allowed = ffiAllowTrue
local hasPermission, permissionReason = CarManager.hasPhysicsPermission()
assert(hasPermission == true and permissionReason == 'physics-allowed' and CarManager.isWritableAICar(1),
  'callable cdata permission returning boolean true is accepted')
local writesBeforeFFIControl = #writes
CarOperations.setAITopSpeed(1, 90)
assert(#writes == writesBeforeFFIControl + 1, 'cdata true permission allows the positive AI writer control')
physics.allowed = ffiAllowFalse
hasPermission, permissionReason = CarManager.hasPhysicsPermission()
assert(hasPermission == false and permissionReason == 'physics-denied')
assertGateReason(1, 'physics-denied')
local writesBeforeFFIDenial = #writes
CarOperations.setAITopSpeed(1, 90)
assert(#writes == writesBeforeFFIDenial, 'cdata false permission remains fail-closed')
writes = {}
physics.allowed = originalAllowed
local originalGetCar = ac.getCar
ac.getCar = function() return nil end; assertGateReason(1, 'car-missing')
ac.getCar = function() return { index = 2 } end; assertGateReason(1, 'car-index-mismatch')
ac.getCar = originalGetCar
cars[1].isAIControlled = false; assertGateReason(1, 'car-not-ai'); cars[1].isAIControlled = true
cars[1].isConnected = false; assertGateReason(1, 'car-not-connected'); cars[1].isConnected = true
cars[1].isActive = false; assertGateReason(1, 'car-not-active'); cars[1].isActive = true
assert(CarManager.isWritableAICar(1), 'gate setup restored after reason matrix')
CarOperations.setAITopSpeed(1, 100)
assert(#writes == 1 and writes[1][2] == 1)
writes = {}
for _, index in ipairs({ 0, 2, 3, 4, 5, -1, 1.5, 999, 0/0, math.huge }) do
  CarOperations.setAITopSpeed(index, 50)
  CarOperations.setPedalPosition(index, CarOperations.CarPedals.Brake, 1)
  CarOperations.toggleTurningLights(index, ac.TurningLights.Left)
  CarOperations.toggleCarCollisions(index, false)
end
assertNoWrites('player/human/disconnected/invalid index')
assert(CarManager.ensureDefaults(0) and CarManager.ensureDefaults(2))
assert(CarManager.saveCarSpeed(cars[0]) and CarManager.saveCarSpeed(cars[2]))
assert(CarManager.cars_speedSampleCount[0] == 1 and CarManager.cars_speedSampleCount[2] == 1,
  'player and human speed buffers must initialize observationally')
assertNoWrites('player/human observational initialization')
assert(CarManager.ensureDefaults(1))
assert(CarManager.cars_ORIGINAL_AI_AGGRESSION[1] == .4 and CarManager.cars_ORIGINAL_AI_DIFFICULTY_LEVEL[1] == 1)
assertNoWrites('awake/default initialization is memory-only')

local basicWriters = {
  function(i) CarOperations.setPedalPosition(i, CarOperations.CarPedals.Brake, 1) end,
  function(i) CarOperations.setAITopSpeed(i, 80) end,
  function(i) CarOperations.setAIThrottleLimit(i, .5) end,
  function(i) CarOperations.setAICaution(i, 1) end,
  function(i) CarOperations.setAIAggression(i, .5) end,
  function(i) CarOperations.setAIDifficultyLevel(i, 1) end,
  function(i) CarOperations.setAIStopCounter(i, 1) end,
  function(i) CarOperations.setGrip(i, 1) end,
  function(i) CarOperations.toggleCarCollisions(i, false) end,
  function(i) CarOperations.setGentleStop(i, true) end,
  function(i) CarOperations.preventAIFromRetiring(i, true) end,
  function(i) CarOperations.toggleTurningLights(i, ac.TurningLights.Left) end,
}
for _, index in ipairs({ 0, 2, 3, 5, -1, 1.5, 999, 0/0, math.huge }) do
  for _, writer in ipairs(basicWriters) do writer(index) end
end
assert(not CarManager.isWritableAICar(nil))
for _, writer in ipairs(basicWriters) do writer(nil) end
assertNoWrites('basic writer matrix rejects player, human, disconnected, inactive and invalid indices')
physics.setAILevel = nil
local CarOperationsWithoutAILevel = dofile(root .. 'CarOperations.lua')
CarOperationsWithoutAILevel.setAIDifficultyLevel(1, 1)
assertNoWrites('missing difficulty writer fails closed')
physics.setAILevel = record('level')
assert(CarManager.isWritableAICar(1))
CarOperations.setAIDifficultyLevel(1, 1)
assert(#writes == 1 and writes[1][1] == 'level' and writes[1][2] == 1,
  'positive control uses the real eligible AI writer')
writes = {}
sim.isLive = false; CarOperations.setAIThrottleLimit(1, .5); assertNoWrites('paused/non-live')
sim.isLive = true; sim.isReplayActive = true; CarOperations.setAIThrottleLimit(1, .5); assertNoWrites('replay')
sim.isReplayActive = false; allowed = false; CarOperations.setAIThrottleLimit(1, .5); assertNoWrites('physics denied')
allowed = true

-- awake/reset memory must not apply defaults or any physical value.
CarManager.clearCarMemory(1)
assertNoWrites('memory-only reset')

-- Missing writer APIs and missing permission API are fail-closed.
physics.setAITopSpeed = nil
local CarOperationsWithoutSpeed = dofile(root .. 'CarOperations.lua')
CarOperationsWithoutSpeed.setAITopSpeed(1, 80)
assertNoWrites('missing setter')
physics.allowed = nil
assertGateReason(1, 'physics-allowed-missing')
assertNoWrites('missing permission')

-- Ten repeated disable/replay/pause cycles remain write-free on every suspended edge.
physics.allowed = function() return allowed end
for _ = 1, 10 do
  for _, suspended in ipairs({ 'disabled', 'replay', 'pause' }) do
    CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
    sim.isLive, sim.isReplayActive = true, false
    if suspended == 'disabled' then CarManager.runtimeEnabled = false
    elseif suspended == 'replay' then sim.isReplayActive = true
    else sim.isLive = false end
    CarOperations.setAITopSpeed(1, 70)
    assertNoWrites('suspended lifecycle cycle: ' .. suspended)
  end
end
print('test_player_guard: PASS')
