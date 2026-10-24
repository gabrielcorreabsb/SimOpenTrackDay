local root = (arg[0]:gsub('tools[\\/]test_incident_release.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end

local now, writes, fail, failAfterSideEffect = 0, {}, {}, {}
GameTimeManager = { getPlayingGameTime = function() return now end }
local Vector = {}
Vector.__index = Vector
Vector.__add = function(a, b) return setmetatable({ x = a.x+b.x, y = a.y+b.y, z = a.z+b.z }, Vector) end
Vector.__sub = function(a, b) return setmetatable({ x = a.x-b.x, y = a.y-b.y, z = a.z-b.z }, Vector) end
Vector.__unm = function(a) return setmetatable({ x = -a.x, y = -a.y, z = -a.z }, Vector) end
Vector.__mul = function(a, b)
  if type(a) == 'number' then a, b = b, a end
  return setmetatable({ x = a.x*b, y = a.y*b, z = a.z*b }, Vector)
end
local function vector(x, y, z) return setmetatable({ x = x, y = y, z = z }, Vector) end
local sim = { isLive = true, isReplayActive = false, isSessionStarted = true,
  isPaused = false, trackLengthM = 5000, raceSessionType = 1 }
local cars = {}
for i = 0, 32 do
  cars[i] = { index = i, isAIControlled = i ~= 0, isConnected = true, isActive = true,
    position = vector(i * 20, 0, 0), splinePosition = i / 20,
    look = vector(0, 0, 1), side = vector(1, 0, 0), up = vector(0, 1, 0),
    wheels = { [0] = { surfaceValidTrack = true }, [1] = { surfaceValidTrack = true },
      [2] = { surfaceValidTrack = true }, [3] = { surfaceValidTrack = true } },
    speedKmh = 60, aiAggression = .5, aiLevel = 1, brake = 0, gas = 0, isInPit = false, isInPitlane = false }
end
local function physical(name, ...)
  if failAfterSideEffect[name] then
    writes[#writes + 1] = { name, ... }
    error('injected post-side-effect ' .. name .. ' failure')
  end
  local shouldFail = fail[name]
  if type(shouldFail) == 'function' then shouldFail = shouldFail(...) end
  if shouldFail then error('injected ' .. name .. ' failure') end
  writes[#writes + 1] = { name, ... }
end
cars[21].isAIControlled = false
physics = { allowed = function() return true end }
for _, name in ipairs({ 'setAITopSpeed', 'setAIThrottleLimit', 'setAICaution', 'setAIStopCounter',
  'setGentleStop', 'preventAIFromRetiring', 'disableCarCollisions', 'setAIAggression', 'setAILevel',
  'setExtraAIGrip', 'setAISplineOffset' }) do
  local setterName = name
  physics[setterName] = function(...) return physical(setterName, ...) end
end
ac = { getCar = function(i) return cars[i] end, getSim = function() return sim end,
  getTrackName = function() return 'incident-test' end,
  SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4,
    TimeAttack = 5, Drift = 6, Drag = 7 }, TurningLights = { None = 0 },
  setTargetCar = function() return true end, setTurningLights = function() end,
  worldCoordinateToTrack = function() return { x = 0 } end,
  overrideCarControls = function() return {} end }
ac.areCarsColliding = function() return false end
local ray = { cars = function() return -1 end, carCollider = function() return -1 end }
render = { createRay = function() return ray end }
VecPool = { getTempVec3 = function() return {} end }
vec3 = function(x, y, z) local v = vector(x, y, z); v.set = function(self, a, b, c) self.x, self.y, self.z = a, b, c end; return v end
MathHelpers = {
  approach = function(v) return v end, vsub = function(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end,
  dot = function() return 0 end,
  distanceBetweenVec3sSqr = function(a, b) local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z; return x*x+y*y+z*z end,
}
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
Logger = { log = function() end, warn = function() end, error = function() end }
StorageManager = {
  getStorage = function() return { defaultLateralOffset = 0, overrideAiAwareness = false, handleAccidents = false,
    deferTimeAfterSessionStart = 0,
    distanceFromAccidentToSeeYellowFlag_meters = 100 } end,
  getStorage_Overtaking = function() return { handleOvertaking = false } end,
  getStorage_Yielding = function() return { handleYielding = false } end,
  getStorage_AICarValues = function() return { defaultAICaution = 1 } end,
}
Strings = { StringNames = {
  [1] = { None = 0 }, [2] = { None = 0 }, [3] = { YieldingToCar = 1, ContinuingOvertakingNextCar = 2 },
}, StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2, StateExitReason = 3 } }
StringsManager = { setString = function() end }
SessionDetails = { getTimeSinceSessionStarted = function() return 100 end }
local queueIndex = 0
QueueManager = {
  createQueue = function() queueIndex = queueIndex + 1; return { values = {}, first = 1, last = 0 } end,
  enqueue = function(q, v) q.last = q.last + 1; q.values[q.last] = v end,
  dequeue = function(q) if q.first > q.last then return nil end; local v = q.values[q.first]; q.values[q.first] = nil; q.first = q.first + 1; return v end,
  queueLength = function(q) return q.last - q.first + 1 end,
}
CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
CarManager = dofile(root .. 'CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
CarOperations = dofile(root .. 'CarOperations.lua')
CarStateMachine = dofile(root .. 'CarStateMachine/CarStateMachine.lua')
AccidentManager = dofile(root .. 'AccidentManager.lua')
for _, file in ipairs({ 'CarState_CollidedWithCar.lua', 'CarState_AnotherCarCollidedIntoMe.lua',
  'CarState_DrivingNormally.lua' }) do dofile(root .. 'CarStateMachine/States/' .. file) end
for i = 1, 32 do
  CarManager.cars_sideBlockRaysData[i] = {}
  CarManager.cars_totalSideBlockRaysData[i] = 0
  CarManager.cars_HALF_AABSIZE[i] = { x = 1, y = 1, z = 2 }
  CarManager.cars_AABBSIZE[i] = { x = 2, y = 2, z = 4 }
end

local trackedCars = {}
local function register(culprit, victim)
  trackedCars[culprit], trackedCars[victim] = true, true
  return assert(AccidentManager.registerCollision(culprit, { x = 0, y = 0, z = 0 }, victim + 1))
end
local function acceptedTick(dt)
  CarStateMachine.handleQueuedAccidents()
  for i in pairs(trackedCars) do
    CarStateMachine.updateCar(i, dt, cars, i)
    if not CarOperations.hasActiveIncidentStop(i)
      and CarStateMachine.getCurrentState(i) == CarStateMachine.CarStateType.DRIVING_NORMALLY then trackedCars[i] = nil end
  end
  CarOperations.resolveOwnedAIControls(1000)
end
local function tick(dt)
  if not CarManager.runtimePaused then now = now + dt end
  acceptedTick(dt)
end
local function calls(name, value, from)
  local count = 0
  for i = from or 1, #writes do
    if writes[i][1] == name and (value == nil or writes[i][3] == value) then count = count + 1 end
  end
  return count
end
local function carCalls(name, carIndex, value)
  local count = 0
  for i = 1, #writes do
    if writes[i][1] == name and writes[i][2] == carIndex
      and (value == nil or writes[i][3] == value) then count = count + 1 end
  end
  return count
end
local function assertNoCollisionEnable()
  for i = 1, #writes do
    if writes[i][1] == 'disableCarCollisions' then assert(writes[i][3] == true, 'collision enable must never be issued') end
  end
end

-- Real collision registration -> accepted queues -> both real collision states -> owned-control resolver.
local a1 = register(1, 2)
acceptedTick(.1)
assert(CarStateMachine.getCurrentState(1) == CarStateMachine.CarStateType.COLLIDED_WITH_CAR
  and CarStateMachine.getCurrentState(2) == CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME,
  'real queue dispatch enters culprit and victim states')
assert(CarOperations.hasActiveIncidentStop(1) and CarOperations.hasActiveIncidentStop(2))
local zeroRenewalStart = #writes + 1
tick(9.8)
local deadline = now + .2
tick(.2)
assert(now >= deadline and CarOperations._topSpeedRequests[1].byOwner.INCIDENT_STOP.active == false,
  'incident stop requests are released at the fixed ten-second game-time deadline')
local zeroWritesAtDeadline = calls('setAITopSpeed', 0, zeroRenewalStart) + calls('setAIThrottleLimit', 0, zeroRenewalStart)
tick(.9)
assert(calls('setAITopSpeed', 0, zeroRenewalStart) + calls('setAIThrottleLimit', 0, zeroRenewalStart) == zeroWritesAtDeadline,
  'no stop renewal is written after the deadline')
tick(.2)
assert(not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(2)
  and CarOperations.isIncidentStopCompleted(1, a1) and CarOperations.isIncidentStopCompleted(2, a1),
  'both roles complete only after handback and successful one-second counter grace')
tick(.1)
assert(CarStateMachine.getCurrentState(1) == CarStateMachine.CarStateType.DRIVING_NORMALLY
  and CarStateMachine.getCurrentState(2) == CarStateMachine.CarStateType.DRIVING_NORMALLY,
  'both real terminal states return to normal after completion')

-- M1b acquisitions at t=0 remain authoritative across a service gap to t=10, then handback is observed at t=12.
local gapIncident = register(23, 24)
CarStateMachine.handleQueuedAccidents()
for _, i in ipairs({ 23, 24 }) do CarStateMachine.updateCar(i, .016, cars, i) end
CarOperations.resolveOwnedAIControls(1000)
now = now + 10
acceptedTick(.016)
assert(CarOperations.hasActiveIncidentStop(23) and not CarOperations.isIncidentStopCompleted(23, gapIncident))
now = now + 2
acceptedTick(.016)
assert(CarOperations.isIncidentStopCompleted(23, gapIncident)
  and CarOperations.isIncidentStopCompleted(24, gapIncident),
  'resolved t=0 controls and t=10 handbacks survive until FSM service at t=12')
CarStateMachine.informAboutAccident(a1)
CarStateMachine.handleQueuedAccidents()
assert(not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(2),
  'requeued completed record is rejected for both still-current participants')
AccidentManager.informAboutCarReset(1)
local aNew = register(1, 2)
acceptedTick(.1)
assert(aNew ~= a1 and CarOperations.hasActiveIncidentStop(1)
  and not CarOperations.admitIncidentStop(1, a1, CarManager.getCarGeneration(1), CarManager.sessionGeneration),
  'completed old ID cannot rearm while a newly accepted record starts a fresh episode')
tick(9.8)
tick(.2)
tick(1.1)
tick(.1)
assert(CarOperations.isIncidentStopCompleted(1, aNew), 'new incident ID completes independently')

-- Late accepted overlapping ID joins an episode already releasing; does not extend its deadline or lose ownership.
local a2 = register(3, 4)
acceptedTick(.1)
local deadline2 = now + 10
tick(9.8)
tick(.2)
local releaseWrites = #writes
local a3 = register(5, 3) -- car 3 is already in the active episode, now as victim
acceptedTick(.1)
assert(CarOperations.hasActiveIncidentStop(3),
  'late incident joins the single episode already releasing')
assert(not CarOperations.isIncidentStopCompleted(3, a2) and not CarOperations.isIncidentStopCompleted(3, a3))
tick(1.1)
assert(now >= deadline2 and CarOperations.isIncidentStopCompleted(3, a2)
  and CarOperations.isIncidentStopCompleted(3, a3), 'all joined IDs complete together at the original deadline; active='
  .. tostring(CarOperations.hasActiveIncidentStop(3)) .. ' a2=' .. tostring(CarOperations.isIncidentStopCompleted(3, a2))
  .. ' a3=' .. tostring(CarOperations.isIncidentStopCompleted(3, a3)) .. ' now=' .. tostring(now))
assert(#writes >= releaseWrites)

-- Equal-valued lower owner inherits handback without rewriting the last-successful-setter audit owner.
local a4 = register(6, 7)
acceptedTick(.1)
tick(9.9)
local topApplied = CarOperations._topSpeedApplied[6]
assert(topApplied and topApplied.owner == 'INCIDENT_STOP')
local function refreshYellow()
  assert(CarOperations.requestAITopSpeed(6, 0, 'YELLOW_FLAG'))
  assert(CarOperations.requestAIThrottleLimit(6, 0, 'YELLOW_FLAG'))
end
refreshYellow()
tick(.2)
assert(topApplied.owner == 'INCIDENT_STOP' and topApplied.handbackOwner == 'YELLOW_FLAG',
  'equal-value handback records logical lower owner without falsifying last setter')
refreshYellow()
tick(.5)
refreshYellow()
tick(.5)
assert(CarOperations.isIncidentStopCompleted(6, a4), 'equal-value lower control survives completed handback')
assert(CarOperations._topSpeedRequests[6].byOwner.YELLOW_FLAG.active
  and CarOperations._topSpeedRequests[6].byOwner.YELLOW_FLAG.value == 0
  and topApplied.owner == 'INCIDENT_STOP' and topApplied.handbackOwner == 'YELLOW_FLAG',
  'lower owner remains active/effective while last-successful-setter shadow remains truthful')

-- Current local pending state is guarded; it cannot replace the actual dispatch/state/service path.
local a5 = register(8, 9)
acceptedTick(.1)
CarStateMachine.queueStateTransition(8, CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT)
tick(.1)
assert(CarStateMachine.getCurrentState(8) == CarStateMachine.CarStateType.COLLIDED_WITH_CAR
  and CarOperations.hasActiveIncidentStop(8), 'pending navigation cannot bypass an admitted incident episode')

-- Resetting the other participant removes the record, but the surviving generation still receives handback.
local a6 = register(10, 11)
acceptedTick(.1)
tick(9.9)
local survivorGeneration = CarManager.getCarGeneration(10)
CarManager.clearCarMemory(11)
trackedCars[11] = nil
assert(AccidentManager.accidents_resolved[a6] == true)
tick(.2)
assert(CarManager.getCarGeneration(10) == survivorGeneration and CarOperations.hasActiveIncidentStop(10),
  'surviving participant episode persists after other participant reset resolves record')
tick(1)
assert(CarOperations.isIncidentStopCompleted(10, a6), 'survivor hands back without active accident maps')

-- Self-query excludes the whole incident; unrelated active records remain candidates.
local a7 = register(13, 14)
local a8 = register(15, 16)
local query1, query2 = AccidentManager.isCarComingUpToAccident(cars[13], 500), AccidentManager.isCarComingUpToAccident(cars[14], 500)
assert(query1 == a8 and query2 == a8, 'both roles skip their whole own incident and still see unrelated hazard')

-- Setter failures are caught, retried before deadline, and cannot create a completion without successful ownership.
local a9 = register(17, 18)
fail.setGentleStop, fail.setAICaution, fail.setAIStopCounter = true, true, true
fail.setAITopSpeed, fail.setAIThrottleLimit = true, true
acceptedTick(.1)
assert(CarOperations.hasActiveIncidentStop(17) and not CarOperations.isIncidentStopCompleted(17, a9),
  'throwing setup setters do not complete or abort the accepted episode')
fail.setGentleStop, fail.setAICaution, fail.setAIStopCounter = false, false, false
fail.setAITopSpeed, fail.setAIThrottleLimit = false, false
tick(.1)
assert(CarOperations.hasActiveIncidentStop(17))
fail.setGentleStop = function(_, stop) return stop == false end
tick(9.8)
tick(.2)
local cautionRestoresBeforeRetry = carCalls('setAICaution', 17, 1)
tick(1)
assert(not CarOperations.isIncidentStopCompleted(17, a9) and CarManager.cars_aiCaution[17] == 1
  and cautionRestoresBeforeRetry == 1, 'gentle failure does not block successful caution restoration')
fail.setGentleStop = false
tick(.1)
assert(CarOperations.isIncidentStopCompleted(17, a9) and carCalls('setAICaution', 17, 1) == cautionRestoresBeforeRetry,
  'gentle retry completes without repeating successful caution restoration')

-- Reverse independent restoration order: gentle succeeds once while caution restoration fails and retries.
local a11 = register(25, 26)
acceptedTick(.1)
tick(9.8)
fail.setAICaution = function(_, value) return value == 1 end
tick(.2)
tick(1)
local gentleRestores = carCalls('setGentleStop', 25, false)
assert(gentleRestores == 1 and carCalls('setAICaution', 25, 1) == 0
  and not CarOperations.isIncidentStopCompleted(25, a11), 'caution failure does not block successful gentle restoration')
fail.setAICaution = false
tick(.1)
assert(CarOperations.isIncidentStopCompleted(25, a11) and carCalls('setGentleStop', 25, false) == gentleRestores,
  'caution retries without repeating successful gentle restoration')

-- M1b top/throttle neutral failures are retried independently after the deadline, never replaced by stop renewals.
local a12 = register(27, 28)
acceptedTick(.1)
tick(9.8)
fail.setAITopSpeed = function(_, value) return value == math.huge end
local controlWritesAtDeadline = #writes
tick(.2)
local zerosAfterDeadline = calls('setAITopSpeed', 0, controlWritesAtDeadline + 1)
  + calls('setAIThrottleLimit', 0, controlWritesAtDeadline + 1)
tick(1)
assert(not CarOperations.isIncidentStopCompleted(27, a12)
  and CarOperations._throttleApplied[27].active == false
  and calls('setAITopSpeed', 0, controlWritesAtDeadline + 1) + calls('setAIThrottleLimit', 0, controlWritesAtDeadline + 1) == zerosAfterDeadline,
  'failed top handback waits while successful throttle handback is preserved without post-deadline zero writes')
fail.setAITopSpeed = false
tick(.1)
tick(.1)
assert(CarOperations.isIncidentStopCompleted(27, a12), 'top neutral retries complete without repeating throttle handback')

local a14 = register(29, 30)
acceptedTick(.1)
tick(9.8)
fail.setAIThrottleLimit = function(_, value) return value == 1 end
tick(.2)
tick(1)
local successfulTopNeutral = carCalls('setAITopSpeed', 29, math.huge)
assert(not CarOperations.isIncidentStopCompleted(29, a14) and successfulTopNeutral == 1
  and CarOperations._topSpeedApplied[29].active == false,
  'failed throttle handback waits while successful top-speed handback is preserved')
fail.setAIThrottleLimit = false
tick(.1)
tick(.1)
assert(CarOperations.isIncidentStopCompleted(29, a14)
  and carCalls('setAITopSpeed', 29, math.huge) == successfulTopNeutral,
  'throttle neutral retries without repeating successful top-speed handback')

-- An API with a possible side effect followed by an exception is uncertain: do not issue an inverse for unowned gentle stop.
local a13 = register(31, 32)
failAfterSideEffect.setGentleStop = true
acceptedTick(.1)
assert(carCalls('setGentleStop', 31, true) == 1)
tick(9.8)
tick(.2)
failAfterSideEffect.setGentleStop = false
tick(1.1)
assert(not CarOperations.isIncidentStopCompleted(31, a13)
  and carCalls('setGentleStop', 31, false) == 0
  and carCalls('setAICaution', 31, 1) == 1,
  'uncertain gentle acquisition remains pending without suppressing owned caution restoration; completed='
  .. tostring(CarOperations.isIncidentStopCompleted(31, a13)) .. ' gentle=' .. tostring(carCalls('setGentleStop', 31, false))
  .. ' caution=' .. tostring(carCalls('setAICaution', 31, 1)) .. ' active=' .. tostring(CarOperations.hasActiveIncidentStop(31)))

-- Same-generation pause freezes the deadline and is write-free; invalid permission forms and non-AI targets are write-free.
local a10 = register(19, 20)
acceptedTick(.1)
tick(4)
local writesBeforePause, pausedAt = #writes, now
CarManager.runtimePaused = true
tick(50)
assert(#writes == writesBeforePause and now == pausedAt, 'pause produces no writes and freezes active time')
CarManager.runtimePaused = false
tick(6)
assert(CarOperations.hasActiveIncidentStop(19), 'same identity resumes at the frozen episode deadline')
for _, permission in ipairs({ false, 'unknown', 'throw' }) do
  local before = #writes
  physics.allowed = permission == 'throw' and function() error('permission failure') end or function() return permission end
  CarOperations.updateIncidentStop(19)
  assert(#writes == before, 'false/unknown/throwing permission gate writes nothing')
end
physics.allowed = function() return true end
local validClock = GameTimeManager.getPlayingGameTime
GameTimeManager.getPlayingGameTime = function() return 0/0 end
local writesBeforeInvalidTime = #writes
CarOperations.updateIncidentStop(19)
assert(#writes == writesBeforeInvalidTime, 'invalid active-game time cannot cause speculative episode writes')
GameTimeManager.getPlayingGameTime = validClock
assert(not CarOperations.admitIncidentStop(0, a10, 0, CarManager.sessionGeneration)
  and not CarOperations.admitIncidentStop(21, a10, CarManager.getCarGeneration(21), CarManager.sessionGeneration)
  and not CarOperations.updateIncidentStop(0) and not CarManager.isWritableAICar(21),
  'player/human/invalid membership admission is rejected')

-- Session invalidation and reused-index generation changes discard memory only; no stale release or adoption.
local beforeInvalidate = #writes
CarManager.invalidateSession()
assert(#writes == beforeInvalidate and not CarOperations.hasActiveIncidentStop(19), 'session invalidation is memory-only')
local beforeGeneration = #writes
CarManager.bumpCarGeneration(19)
assert(#writes == beforeGeneration and not CarOperations.hasActiveIncidentStop(19), 'index generation invalidation performs no stale release')

-- A missing top-speed API stays fail-closed; the real accepted queue cannot falsely complete.
AccidentManager.informAboutCarReset(19)
local savedTopSetter = physics.setAITopSpeed
local gentleRestoresBeforeMissingTop = carCalls('setGentleStop', 19, false)
local cautionRestoresBeforeMissingTop = carCalls('setAICaution', 19, 1)
physics.setAITopSpeed = nil
CarOperations = dofile(root .. 'CarOperations.lua')
local missingSetterAccident = register(19, 20)
acceptedTick(.1)
tick(9.8)
tick(.2)
tick(1.2)
assert(CarOperations.hasActiveIncidentStop(19)
  and not CarOperations.isIncidentStopCompleted(19, missingSetterAccident),
  'missing top-speed API never yields speculative handback/completion')
assert(carCalls('setGentleStop', 19, false) == gentleRestoresBeforeMissingTop + 1
  and carCalls('setAICaution', 19, 1) == cautionRestoresBeforeMissingTop + 1,
  'missing top-speed acquisition still releases independently owned gentle stop and caution')
physics.setAITopSpeed = savedTopSetter

assertNoCollisionEnable()
print('test_incident_release: PASS (17 integration scenario groups)')
