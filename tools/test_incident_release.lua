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
local diagnosticLines = {}
local injectedObserverFault = false
Logger = { OBS1_ENABLED = false,
  observe = function(kind, car, generation, incident, zone, detail, previous, session, extra, resource)
    if injectedObserverFault then error('injected cached observer failure') end
    if Logger.OBS1_ENABLED ~= true then return false end
    diagnosticLines[#diagnosticLines + 1] = '[OBS1] kind=' .. tostring(kind) .. ' car=' .. tostring(car)
      .. ' gen=' .. tostring(generation) .. ' session=' .. tostring(session) .. ' incident=' .. tostring(incident)
      .. ' deadline=' .. tostring(extra) .. ' detail=' .. tostring(detail) .. ' previous=' .. tostring(previous)
      .. ' resource=' .. tostring(resource)
    return true
  end,
  log = function() end, warn = function() end, error = function() end }
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
local function carCalls(name, carIndex, value, from)
  local count = 0
  for i = from or 1, #writes do
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

-- Real collision registration and queue consumption, followed by explicit fixture-only admission of a pre-existing S2 episode.
local a1 = register(1, 2)
assert(CarOperations.admitIncidentStop(1, a1, CarManager.getCarGeneration(1), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(2, a1, CarManager.getCarGeneration(2), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(1, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(2, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
acceptedTick(.1)
assert(#diagnosticLines == 0, 'S2 diagnostics are silent while opt-in is disabled')
assert(CarStateMachine.getCurrentState(1) == CarStateMachine.CarStateType.COLLIDED_WITH_CAR
  and CarStateMachine.getCurrentState(2) == CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME,
  'fixture-admitted episode enters culprit and victim states')
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
assert(CarOperations.admitIncidentStop(23, gapIncident, CarManager.getCarGeneration(23), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(24, gapIncident, CarManager.getCarGeneration(24), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(23, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(24, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(1, aNew, CarManager.getCarGeneration(1), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(2, aNew, CarManager.getCarGeneration(2), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(1, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(2, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
acceptedTick(.1)
assert(aNew ~= a1 and CarOperations.hasActiveIncidentStop(1)
  and not CarOperations.admitIncidentStop(1, a1, CarManager.getCarGeneration(1), CarManager.sessionGeneration),
  'completed old ID cannot rearm while a newly accepted record starts a fresh episode')
tick(9.8)
tick(.2)
tick(1.1)
tick(.1)
assert(CarOperations.isIncidentStopCompleted(1, aNew), 'new incident ID completes independently')

-- A later registered contact is consumed separately; fixture-admitted episode keeps its deadline and ownership.
CarOperations.S2_DIAGNOSTICS_ENABLED, Logger.OBS1_ENABLED = true, true
local a2WritesStart = #writes + 1
local a2 = register(3, 4)
assert(CarOperations.admitIncidentStop(3, a2, CarManager.getCarGeneration(3), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(4, a2, CarManager.getCarGeneration(4), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(3, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(4, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
acceptedTick(.1)
local hasAdmission, hasDispatch, hasSetterReturn, hasPhysicalClaim = false, false, false, false
for i = 1, #diagnosticLines do
  local line = diagnosticLines[i]
  if line:find('admitted', 1, true) and line:find('car=3', 1, true) and line:find('incident=' .. tostring(a2), 1, true) then hasAdmission = true end
  if line:find('state-entry-dispatch', 1, true) and line:find('car=3', 1, true) then hasDispatch = true end
  if line:find('setter-pcall-returned', 1, true) and line:find('car=3', 1, true) then hasSetterReturn = true end
  if line:find('physicalEffect=', 1, true) then hasPhysicalClaim = true end
end
assert(hasAdmission and hasDispatch and hasSetterReturn and not hasPhysicalClaim,
  'control observations distinguish admission, real FSM dispatch and setter return without claiming physical effect')
local deadline2 = now + 10
tick(9.8)
tick(.2)
local releaseWrites = #writes
local savedDiagnosticObserve = Logger.observe
Logger.observe = function() error('injected diagnostic logger failure') end
CarOperations._traceIncidentStop('logger-failure-probe', 3,
  { generation = CarManager.getCarGeneration(3), session = CarManager.sessionGeneration,
    deadline = deadline2, incidents = { [a2] = true } }, 'logger-failure', 'probe', 'logger')
local a3 = register(5, 3) -- records car 3 as a new-contact victim; no fixture admission for this contact
acceptedTick(.1)
assert(CarOperations.hasActiveIncidentStop(3),
  'a new contact does not alter the previously admitted episode')
assert(not CarOperations.isIncidentStopCompleted(3, a2),
  'new contact is not automatically admitted or allowed to renew the existing episode')
tick(1.1)
assert(now >= deadline2 and CarOperations.isIncidentStopCompleted(3, a2)
  and not CarOperations.isIncidentStopCompleted(3, a3), 'existing episode completes at its original deadline; active='
  .. tostring(CarOperations.hasActiveIncidentStop(3)) .. ' a2=' .. tostring(CarOperations.isIncidentStopCompleted(3, a2))
  .. ' a3=' .. tostring(CarOperations.isIncidentStopCompleted(3, a3)) .. ' now=' .. tostring(now))
assert(#writes >= releaseWrites)
for _, name in ipairs({ 'setAITopSpeed', 'setAIThrottleLimit', 'setAIStopCounter', 'setGentleStop', 'setAICaution', 'preventAIFromRetiring' }) do
  assert(carCalls(name, 3, nil, a2WritesStart) == carCalls(name, 4, nil, a2WritesStart),
    'trace-on incident preserves per-participant physical call counts for ' .. name)
end
Logger.observe = savedDiagnosticObserve

-- S2 compatibility trace is reconciled into Logger; its dedupe cache is bounded, not a second log/ring.
CarManager.sessionGeneration = CarManager.sessionGeneration + 1
diagnosticLines = {}
local capEpisode = { generation = CarManager.getCarGeneration(3), session = CarManager.sessionGeneration,
  deadline = now + 1, incidents = { [a2] = true } }
CarOperations._traceIncidentStop('admitted', 3, capEpisode, 'cap-admission', 'incidentID', a2)
for i = 1, 60 do
  CarOperations._traceIncidentStop('bounded-event', 3,
    capEpisode, 'bounded-event-' .. i, 'event', i)
end
assert(#diagnosticLines <= 64, 'S2 events use the Logger observation callback without an independent S2 output stream')
local function upvalue(fn, target)
  for i = 1, 20 do local name, value = debug.getupvalue(fn, i); if name == target then return value end; if not name then break end end
end
local function keyCount(value)
  local count = 0
  for key, nested in pairs(value) do count = count + 1; if type(nested) == 'table' then count = count + keyCount(nested) end end
  return count
end
local diagnosticImpl = assert(upvalue(CarOperations._traceIncidentStop, 's2DiagnosticImpl'))
local diagnosticEvents = assert(upvalue(diagnosticImpl, 's2DiagnosticEvents'))
local eventKeysAtCap = diagnosticEvents[3].count
for i = 61, 80 do CarOperations._traceIncidentStop('bounded-event', 3, capEpisode, 'bounded-event-' .. i, 'event', i) end
assert(diagnosticEvents[3].count == eventKeysAtCap and eventKeysAtCap == 32,
  'S2 dedupe bookkeeping has a fixed 32-event per-car bound despite arbitrary diagnostic keys')
CarOperations.S2_DIAGNOSTICS_ENABLED, Logger.OBS1_ENABLED = false, false

-- Equal-valued lower owner inherits handback without rewriting the last-successful-setter audit owner.
local a4 = register(6, 7)
assert(CarOperations.admitIncidentStop(6, a4, CarManager.getCarGeneration(6), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(7, a4, CarManager.getCarGeneration(7), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(6, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(7, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(8, a5, CarManager.getCarGeneration(8), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(9, a5, CarManager.getCarGeneration(9), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(8, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(9, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
acceptedTick(.1)
CarStateMachine.queueStateTransition(8, CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT)
tick(.1)
assert(CarStateMachine.getCurrentState(8) == CarStateMachine.CarStateType.COLLIDED_WITH_CAR
  and CarOperations.hasActiveIncidentStop(8), 'pending navigation cannot bypass an admitted incident episode')

-- Resetting the other participant removes the record, but the surviving generation still receives handback.
local a6 = register(10, 11)
assert(CarOperations.admitIncidentStop(10, a6, CarManager.getCarGeneration(10), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(11, a6, CarManager.getCarGeneration(11), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(10, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(11, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(17, a9, CarManager.getCarGeneration(17), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(18, a9, CarManager.getCarGeneration(18), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(17, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(18, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(25, a11, CarManager.getCarGeneration(25), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(26, a11, CarManager.getCarGeneration(26), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(25, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(26, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(27, a12, CarManager.getCarGeneration(27), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(28, a12, CarManager.getCarGeneration(28), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(27, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(28, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(29, a14, CarManager.getCarGeneration(29), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(30, a14, CarManager.getCarGeneration(30), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(29, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(30, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(31, a13, CarManager.getCarGeneration(31), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(32, a13, CarManager.getCarGeneration(32), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(31, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(32, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(19, a10, CarManager.getCarGeneration(19), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(20, a10, CarManager.getCarGeneration(20), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(19, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(20, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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
assert(CarOperations.admitIncidentStop(19, missingSetterAccident, CarManager.getCarGeneration(19), CarManager.sessionGeneration))
assert(CarOperations.admitIncidentStop(20, missingSetterAccident, CarManager.getCarGeneration(20), CarManager.sessionGeneration))
CarStateMachine.queueStateTransition(19, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.queueStateTransition(20, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
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

-- Identical real-module scenario in isolated opt-in/failure contexts: compare every physical call and outcome.
local function runTraceComparison(mode, fault, reuseModules)
  for carIndex = 1, 32 do AccidentManager.informAboutCarReset(carIndex) end
  CarManager.invalidateSession()
  CarManager.bumpCarGeneration(1)
  CarManager.bumpCarGeneration(2)
  if not reuseModules then
    CarOperations = dofile(root .. 'CarOperations.lua')
    CarStateMachine = dofile(root .. 'CarStateMachine/CarStateMachine.lua')
    for _, file in ipairs({ 'CarState_CollidedWithCar.lua', 'CarState_AnotherCarCollidedIntoMe.lua',
      'CarState_DrivingNormally.lua' }) do dofile(root .. 'CarStateMachine/States/' .. file) end
  else
    CarStateMachine.clearPendingLifecycle()
    CarStateMachine.initializeCarInStateMachine(1)
    CarStateMachine.initializeCarInStateMachine(2)
  end
  CarOperations.S2_DIAGNOSTICS_ENABLED = mode ~= 'off' and mode ~= 'obs1-only'
  Logger.OBS1_ENABLED = mode ~= 'off'
  CarManager.runtimePaused = false
  now, writes, trackedCars, diagnosticLines = 0, {}, {}, {}
  local loggerThrows = mode == 'logger-throws'
  injectedObserverFault = loggerThrows
  Logger.observe = function(...)
    if loggerThrows then error('injected diagnostic logger failure') end
    return savedDiagnosticObserve(...)
  end
  for name in pairs(fail) do fail[name] = false end
  for name in pairs(failAfterSideEffect) do failAfterSideEffect[name] = false end
  local savedSetter = physics.setAITopSpeed
  if fault == 'missing-top-api' then physics.setAITopSpeed = nil end
  if fault == 'throw-after-gentle-side-effect' then failAfterSideEffect.setGentleStop = true end

  local incident = register(1, 2)
  assert(CarOperations.admitIncidentStop(1, incident, CarManager.getCarGeneration(1), CarManager.sessionGeneration))
  assert(CarOperations.admitIncidentStop(2, incident, CarManager.getCarGeneration(2), CarManager.sessionGeneration))
  CarStateMachine.queueStateTransition(1, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
  CarStateMachine.queueStateTransition(2, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
  local session, gen1, gen2 = CarManager.sessionGeneration, CarManager.getCarGeneration(1), CarManager.getCarGeneration(2)
  local traceFunction = CarOperations._traceIncidentStop
  if mode == 'helper-throws' then
    CarOperations._traceIncidentStop = function() error('injected helper failure') end
  end
  acceptedTick(.1)
  CarOperations._traceIncidentStop = traceFunction
  if mode == 'format-throws' then
    local badValue = setmetatable({}, { __tostring = function() error('injected diagnostic formatting failure') end })
    CarOperations._traceIncidentStop('format-failure-probe', 1, nil, 'format-probe', 'value', badValue)
  end
  for _ = 1, 112 do tick(.1) end

  local active1, active2 = CarOperations.hasActiveIncidentStop(1), CarOperations.hasActiveIncidentStop(2)
  local complete1, complete2 = CarOperations.isIncidentStopCompleted(1, incident), CarOperations.isIncidentStopCompleted(2, incident)
  local state1, state2 = CarStateMachine.getCurrentState(1), CarStateMachine.getCurrentState(2)
  local result = { writes = writes, logs = diagnosticLines, incident = incident, session = session,
    operationsModule = CarOperations, stateMachineModule = CarStateMachine,
    gen1 = gen1, gen2 = gen2, deadline = 10, now = now, active1 = active1, active2 = active2,
    complete1 = complete1, complete2 = complete2, state1 = state1, state2 = state2,
    topHandback1 = CarOperations._topSpeedApplied[1] and CarOperations._topSpeedApplied[1].active,
    throttleHandback1 = CarOperations._throttleApplied[1] and CarOperations._throttleApplied[1].active,
    topHandback2 = CarOperations._topSpeedApplied[2] and CarOperations._topSpeedApplied[2].active,
    throttleHandback2 = CarOperations._throttleApplied[2] and CarOperations._throttleApplied[2].active }
  physics.setAITopSpeed = savedSetter
  for name in pairs(failAfterSideEffect) do failAfterSideEffect[name] = false end
  return result
end
local function assertSameCommands(expected, actual, label)
  assert(#expected.writes == #actual.writes, label .. ': physical command count')
  for i = 1, #expected.writes do
    local left, right = expected.writes[i], actual.writes[i]
    assert(#left == #right, label .. ': argument count at command ' .. i)
    for j = 1, #left do assert(left[j] == right[j], label .. ': argument/order mismatch at command ' .. i .. '/' .. j) end
  end
  for _, key in ipairs({ 'deadline', 'now', 'active1', 'active2',
    'complete1', 'complete2', 'state1', 'state2', 'topHandback1', 'throttleHandback1',
    'topHandback2', 'throttleHandback2' }) do
    assert(expected[key] == actual[key], label .. ': outcome mismatch for ' .. key)
  end
end
local function assertTraceMilestones(result)
  for _, carIndex in ipairs({ 1, 2 }) do
    for _, event in ipairs({ 'admitted', 'state-entry-dispatch', 'deadline-release-start', 'handback-returned',
      'completed', 'state-exit-dispatch' }) do
      local found = false
      for i = 1, #result.logs do
        local line = result.logs[i]
        if line:find('previous=' .. event, 1, true) and line:find('car=' .. carIndex, 1, true)
          and line:find('gen=' .. (carIndex == 1 and result.gen1 or result.gen2), 1, true)
          and line:find('session=' .. result.session, 1, true)
          and line:find('incident=' .. result.incident, 1, true)
          and line:find('deadline=' .. result.deadline, 1, true) then found = true; break end
      end
      assert(found, 'trace milestone/identity missing: ' .. event .. ' car=' .. carIndex)
    end
  end
end

local comparisonBaseline = runTraceComparison('off')
assert(not comparisonBaseline.active1 and not comparisonBaseline.active2
  and comparisonBaseline.complete1 and comparisonBaseline.complete2
  and comparisonBaseline.state1 == CarStateMachine.CarStateType.DRIVING_NORMALLY
  and comparisonBaseline.state2 == CarStateMachine.CarStateType.DRIVING_NORMALLY,
  'baseline incident completes for both participants and exits terminal states')
local traceOn = runTraceComparison('on')
assertSameCommands(comparisonBaseline, traceOn, 'trace on')
assertTraceMilestones(traceOn)
local obs1Only = runTraceComparison('obs1-only')
assertSameCommands(comparisonBaseline, obs1Only, 'OBS1 with legacy S2 flag false')
assertTraceMilestones(obs1Only)
local sawTopResourceAndIdentity, sawThrottleResourceAndIdentity = false, false
local topAttempts, throttleAttempts = 0, 0
for i = 1, #obs1Only.logs do
  local line = obs1Only.logs[i]
  if line:find('kind=control-setter-attempt', 1, true) and line:find('resource=setAITopSpeed', 1, true) then topAttempts = topAttempts + 1 end
  if line:find('kind=control-setter-attempt', 1, true) and line:find('resource=setAIThrottleLimit', 1, true) then throttleAttempts = throttleAttempts + 1 end
  if line:find('kind=control-setter-returned', 1, true) and line:find('resource=setAITopSpeed', 1, true)
    and line:find('gen=' .. obs1Only.gen1, 1, true) and line:find('session=' .. obs1Only.session, 1, true) then
    sawTopResourceAndIdentity = true
  elseif line:find('kind=control-setter-returned', 1, true) and line:find('resource=setAIThrottleLimit', 1, true)
    and line:find('gen=' .. obs1Only.gen1, 1, true) and line:find('session=' .. obs1Only.session, 1, true) then
    sawThrottleResourceAndIdentity = true
  end
end
assert(sawTopResourceAndIdentity and sawThrottleResourceAndIdentity,
  'OBS1 alone records top-speed/throttle resources and known session/car generation')
assert(topAttempts == 2 and throttleAttempts == 2,
  'attempt milestones are emitted once per car/resource rather than once per update frame')
local loggerFailure = runTraceComparison('logger-throws')
assertSameCommands(comparisonBaseline, loggerFailure, 'throwing logger')
local formatFailure = runTraceComparison('format-throws')
assertSameCommands(comparisonBaseline, formatFailure, 'throwing diagnostic formatter')
local helperFailure = runTraceComparison('helper-throws')
assertSameCommands(comparisonBaseline, helperFailure, 'throwing diagnostic helper at FSM dispatch')
local sameInstanceFirst = runTraceComparison('on')
assertSameCommands(comparisonBaseline, sameInstanceFirst, 'same-instance first session')
assertTraceMilestones(sameInstanceFirst)
local nextSession = runTraceComparison('on', nil, true)
assert(nextSession.session ~= sameInstanceFirst.session and nextSession.gen1 ~= sameInstanceFirst.gen1
  and nextSession.gen2 ~= sameInstanceFirst.gen2,
  'next session refocuses the selected ID/participants with fresh generation and deadline context: '
    .. tostring(traceOn.session) .. '/' .. tostring(nextSession.session) .. ' gen '
    .. tostring(traceOn.gen1) .. '/' .. tostring(nextSession.gen1) .. ' '
    .. tostring(traceOn.gen2) .. '/' .. tostring(nextSession.gen2))
assertTraceMilestones(nextSession)
assert(nextSession.operationsModule == sameInstanceFirst.operationsModule
  and nextSession.stateMachineModule == sameInstanceFirst.stateMachineModule,
  'consecutive-session scenario reuses the same CarOperations and FSM instances')
assertSameCommands(comparisonBaseline, nextSession, 'same-instance next session')
local outcomeWrapper = assert(upvalue(CarOperations.updateIncidentStop, 'traceOutcome'))
local outcomeRecorder = assert(upvalue(outcomeWrapper, 'traceOutcomeImpl'))
local outcomes = assert(upvalue(outcomeRecorder, 's2DiagnosticOutcomes'))
outcomeWrapper({ generation = CarManager.getCarGeneration(3), session = CarManager.sessionGeneration,
  incidents = { [nextSession.incident] = true } }, 3, 'third-car-probe', false)
assert(outcomes[3] == nil, 'nonparticipant car cannot allocate an outcome record outside the trace focus')

for _, fault in ipairs({ 'missing-top-api', 'throw-after-gentle-side-effect' }) do
  local offFault = runTraceComparison('off', fault)
  local onFault = runTraceComparison('on', fault)
  assertSameCommands(offFault, onFault, 'trace with ' .. fault)
  assert(offFault.active1 == onFault.active1 and offFault.active2 == onFault.active2
    and offFault.complete1 == onFault.complete1 and offFault.complete2 == onFault.complete2,
    'trace preserves pending/completion semantics with ' .. fault)
  assert(offFault.active1 and offFault.active2 and not offFault.complete1 and not offFault.complete2,
    'uncertain/missing API remains pending in both trace modes: ' .. fault)
  if fault == 'missing-top-api' then
    local observedMissing = false
    for i = 1, #onFault.logs do if onFault.logs[i]:find('api-unavailable', 1, true) then observedMissing = true end end
    assert(observedMissing, 'missing top-speed API is diagnosed without speculative completion')
  else
    local observedUncertain = false
    for i = 1, #onFault.logs do if onFault.logs[i]:find('setter-failed-or-uncertain', 1, true) then observedUncertain = true end end
    assert(observedUncertain, 'throw-after-side-effect is reported as uncertain')
  end
end

assertNoCollisionEnable()
print('test_incident_release: PASS (incident release and unified OBS1 control trace comparisons)')
