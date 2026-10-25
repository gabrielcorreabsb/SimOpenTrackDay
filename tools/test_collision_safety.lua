local root = (arg[0]:gsub('tools[\\/]test_collision_safety.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end

local Vec = {}
Vec.__unm = function(a) return setmetatable({ x = -a.x, y = -a.y, z = -a.z }, Vec) end
Vec.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, Vec) end
Vec.__mul = function(a, b)
  if type(a) == 'number' then a, b = b, a end
  return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, Vec)
end
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, Vec) end
local sim = { isLive = true, isReplayActive = false, isSessionStarted = true,
  isPaused = false, trackLengthM = 5000, raceSessionType = 1 }
local cars = {}
for i = 0, 5 do
  cars[i] = { index = i, isAIControlled = i ~= 0, isConnected = true, isActive = true,
    position = vec(i * 4, 0, 0), splinePosition = .4 + i * .01, speedKmh = 60,
    look = vec(0, 0, 1), side = vec(1, 0, 0), up = vec(0, 1, 0),
    wheels = { [0] = { surfaceValidTrack = true }, [1] = { surfaceValidTrack = true },
      [2] = { surfaceValidTrack = true }, [3] = { surfaceValidTrack = true } },
    isInPit = false, isInPitlane = false }
end
cars[0].isAIControlled = false
cars[1].position, cars[1].splinePosition = vec(0, 0, 0), .500
cars[2].position, cars[2].splinePosition = vec(4, 0, 0), .502
cars[3].position, cars[3].splinePosition = vec(8, 0, 0), .490
cars[1].speedKmh, cars[1].isInPit = 240, true
cars[2].speedKmh, cars[2].isInPit, cars[2].isInPitlane = nil, nil, nil
cars[4].position, cars[4].splinePosition = vec(10, 0, 0), .480

local calls = {}
physics = { allowed = function() return true end }
for _, name in ipairs({ 'disableCarCollisions', 'setAITopSpeed', 'setAIThrottleLimit', 'setAICaution',
  'setAIStopCounter', 'setGentleStop', 'preventAIFromRetiring', 'setAIAggression', 'setAILevel',
  'setExtraAIGrip', 'setAISplineOffset' }) do
  local capturedName = name
  physics[capturedName] = function(...) calls[#calls + 1] = { capturedName, ... } end
end

ac = { getCar = function(index) return cars[index] end, getSim = function() return sim end,
  getTrackName = function() return 'collision-safety-test' end,
  SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4,
    TimeAttack = 5, Drift = 6, Drag = 7 },
  TurningLights = { None = 0, Hazards = 3 }, setTargetCar = function() return true end,
  setTurningLights = function(lights) calls[#calls + 1] = { 'turningLights', lights } end,
  getCarMaxSpeedWithGear = function() return 300 end, overrideCarControls = function() return {} end,
  worldCoordinateToTrack = function() return { x = 0 } end }
ac.areCarsColliding = function() return false end
local ray = { cars = function() return -1 end, carCollider = function() return -1 end }
render = { createRay = function() return ray end }
VecPool = { getTempVec3 = function() return vec(0, 0, 0) end }
vec3 = function(x, y, z) local value = vec(x, y, z); value.set = function(self, a, b, c) self.x, self.y, self.z = a, b, c end; return value end
MathHelpers = { approach = function(value) return value end,
  vsub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
  dot = function() return 0 end,
  distanceBetweenVec3sSqr = function(a, b) local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z; return x*x+y*y+z*z end }
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
local storage = { defaultLateralOffset = 0, overrideAiAwareness = false, handleAccidents = true,
  deferTimeAfterSessionStart = 0, distanceFromAccidentToSeeYellowFlag_meters = 100,
  distanceToStartNavigatingAroundCarInAccident_meters = 1, yieldingLateralOffset = .5,
  overtakingLateralOffset = -.5, rampSpeed_mps = 2 }
StorageManager = {
  getStorage = function() return storage end,
  getStorage_Overtaking = function() return { handleOvertaking = false, overtakeRampSpeed_mps = 2 } end,
  getStorage_Yielding = function() return { handleYielding = false, rampSpeed_mps = 2 } end,
  getStorage_AICarValues = function() return { defaultAICaution = 1 } end,
  getStorage_Behavior = function() return { defenseDurationMin_s = 1, defenseDurationMax_s = 2 } end,
}
Strings = { StringNames = {
  [1] = { None = 0 }, [2] = { None = 0 },
  [3] = { NavigatingAroundAccident = 1, ExitedYellowFlagZone = 2, EnteringYellowFlagZone = 3,
    AccidentResolved = 4, NoAccidentIndexToNavigateAround = 5, CarToNavigateAroundNotFound = 6,
    AccidentIsFarBehindUs = 7, YieldingToCar = 8, ContinuingOvertakingNextCar = 9 },
}, StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2, StateExitReason = 3 } }
StringsManager = { setString = function() end }
Logger = { log = function() end, warn = function() end, error = function(message) error(message) end }
SessionDetails = { getTimeSinceSessionStarted = function() return 100 end }
local activeTime = 0
GameTimeManager = { getPlayingGameTime = function() return activeTime end }
local queueId = 0
QueueManager = {
  createQueue = function() queueId = queueId + 1; return { items = {}, first = 1, last = 0 } end,
  enqueue = function(q, item) q.last = q.last + 1; q.items[q.last] = item end,
  dequeue = function(q) if q.first > q.last then return nil end; local item = q.items[q.first]; q.items[q.first] = nil; q.first = q.first + 1; return item end,
  queueLength = function(q) return q.last - q.first + 1 end,
}

CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
CarManager = dofile(root .. 'CarManager.lua')
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
CarOperations = dofile(root .. 'CarOperations.lua')
CarStateMachine = dofile(root .. 'CarStateMachine/CarStateMachine.lua')
AccidentManager = dofile(root .. 'AccidentManager.lua')
for _, file in ipairs({ 'CarState_DrivingNormally.lua', 'CarState_DrivingInYellowFlagZone.lua',
  'CarState_CollidedWithCar.lua', 'CarState_AnotherCarCollidedIntoMe.lua', 'CarState_NavigatingAroundAccident.lua' }) do
  dofile(root .. 'CarStateMachine/States/' .. file)
end
for i = 1, 5 do
  CarManager.cars_sideBlockRaysData[i] = {}
  CarManager.cars_totalSideBlockRaysData[i] = 0
  CarManager.cars_HALF_AABSIZE[i] = { x = 1, y = 1, z = 2 }
  CarManager.cars_AABBSIZE[i] = { x = 2, y = 2, z = 4 }
end

local accident = assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 3))
assert(AccidentManager.accidents_carIndex[accident] == 1
  and AccidentManager.accidents_collidedWithCarIndex[accident] == 2
  and AccidentManager.accidents_resolved[accident] == false, 'real culprit/victim record retained')
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 3
local actualIncident, actualIncidentCar = AccidentManager.isCarComingUpToAccident(cars[3], 100)
local actualDecision = assert(AccidentManager.getAccidentDecisionReadOnly(3))
assert(actualDecision.query.source == 'actual-query' and actualDecision.query.examined == 1
  and actualDecision.query.chosenIncident == actualIncident and actualDecision.query.chosenCar == actualIncidentCar,
  'focused decision snapshot captures the real accident-query selection')
local candidateAlias = actualDecision.query.candidates[1]
if candidateAlias then candidateAlias.incident = -1 end
assert(AccidentManager.getAccidentDecisionReadOnly(3).query.candidates[1].incident == accident,
  'accident decision snapshots are detached copies')
assert(AccidentManager.getAccidentDecisionReadOnly(4) == nil, 'wrong-car query snapshot is unavailable')
local successfulGenerationGetter = CarManager.getCarGeneration
CarManager.getCarGeneration = function(index)
  if index == 3 then error('injected finalization identity error') end
  return successfulGenerationGetter(index)
end
local failedCaptureResult = AccidentManager.isCarComingUpToAccident(cars[3], 100)
CarManager.getCarGeneration = successfulGenerationGetter
assert(failedCaptureResult == actualIncident and AccidentManager.getAccidentDecisionReadOnly(3) == nil,
  'candidate capture finalization failure preserves the operational choice and hides mixed snapshot data')
actualIncident, actualIncidentCar = AccidentManager.isCarComingUpToAccident(cars[3], 100)
assert(AccidentManager.getAccidentDecisionReadOnly(3).query.chosenIncident == actualIncident,
  'a complete subsequent query republishes a valid accident snapshot')
Logger.OBS1_FOCUS_CAR = 1
AccidentManager.isCarComingUpToAccident(cars[1], 100)
local participantDecision = assert(AccidentManager.getAccidentDecisionReadOnly(1)).query
assert(participantDecision.examined == 1 and participantDecision.candidates[1].reason == 'query-car-participant',
  'focused candidate capture includes the query car as an incident participant')
Logger.OBS1_FOCUS_CAR = 3
CarStateMachine.handleQueuedAccidents()
assert(not CarOperations.S2_DIAGNOSTICS_ENABLED, 'legacy S2 diagnostics remain disabled in this OBS1 test')
cars[2].speedKmh = 60
for _, index in ipairs({ 1, 2 }) do CarStateMachine.updateCar(index, .016, cars, index, storage) end
local function disableCount(carIndex)
  local count = 0
  for i = 1, #calls do
    local call = calls[i]
    if call[1] == 'disableCarCollisions' and call[2] == carIndex then count = count + 1 end
  end
  return count
end
for _, index in ipairs({ 1, 2 }) do
  assert(disableCount(index) == 0, 'participant registration and real state updater issue no collision call')
  assert(not CarOperations.hasActiveIncidentStop(index)
    and CarStateMachine.getCurrentState(index) == CarStateMachine.CarStateType.DRIVING_NORMALLY,
    'valid registered contact does not admit S2 or dispatch collision states')
end
for i = 1, #calls do
  assert(calls[i][1] ~= 'setAIStopCounter' and calls[i][1] ~= 'setGentleStop'
    and not ((calls[i][1] == 'setAITopSpeed' or calls[i][1] == 'setAIThrottleLimit') and calls[i][3] == 0),
    'registered collision contact issues no S2 stop writes')
end

assert(RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition), 'pass-through AI is in real accident zone')
local yellowDecisionState = CarStateMachine.handleYellowFlagZone(3, cars[3])
local yellowDecision = assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3))
assert(yellowDecision.matched and yellowDecision.chosenZone == AccidentManager.accidents_yellowFlagZoneIndex[accident]
  and yellowDecision.consumer == 'fsm-handle-yellow' and yellowDecision.stateReturned == yellowDecisionState,
  'focused yellow-zone snapshot captures real matching zone and FSM consumption')
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(4) == nil, 'yellow decision snapshot rejects a different car')
local capturedQuery = RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3)
assert(capturedQuery, 'focused direct query captures a matching zone')
local mutableYellowSnapshot = assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3))
local trueChosenZone = mutableYellowSnapshot.chosenZone
mutableYellowSnapshot.chosenZone = -77
if mutableYellowSnapshot.candidates[1] then mutableYellowSnapshot.candidates[1].zone = -77 end
RaceTrackManager.markYellowZoneConsumption(3, yellowDecisionState)
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).chosenZone == trueChosenZone,
  'mutating a read-only decision copy before consumption cannot alter captured choice')
RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3)
Logger.OBS1_ENABLED = false
RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3)
RaceTrackManager.markYellowZoneConsumption(3, yellowDecisionState)
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).consumer == nil,
  'focus-off query invalidates consumption from an earlier captured decision')
Logger.OBS1_ENABLED = true
local generationGetter = CarManager.getCarGeneration
CarManager.getCarGeneration = function() error('injected capture identity error') end
local operationalMatch = RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3)
CarManager.getCarGeneration = generationGetter
assert(operationalMatch and RaceTrackManager.getYellowZoneDecisionReadOnly(3) == nil,
  'capture identity failure preserves the operational result and hides mixed yellow snapshot data')
local consumedState = CarStateMachine.handleYellowFlagZone(3, cars[3])
local consumedSnapshot = assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3))
assert(consumedSnapshot.consumer == 'fsm-handle-yellow' and consumedSnapshot.stateReturned == consumedState
  and consumedSnapshot.epoch ~= nil and consumedSnapshot.revision ~= nil,
  'consumption records only the handler return, with captured zone revision identity')
assert(AccidentManager.accidents_carIndex[accident] ~= 3 and AccidentManager.accidents_collidedWithCarIndex[accident] ~= 3,
  'yellow-zone pass-through is not an incident participant')
local yellow = CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE
CarStateMachine.queueStateTransition(3, yellow)
local yellowExit = CarStateMachine.states_exitFunctions[yellow]
local disablesBeforeYellow = #calls
for _ = 1, 3 do CarStateMachine.updateCar(3, .016, cars, 3, storage) end
assert(CarManager.cars_currentlyOvertakingCarIndex[3] == nil)
local yellowRequest = CarOperations._topSpeedRequests[3].byOwner.YELLOW_FLAG
assert(yellowRequest.active and yellowRequest.value == 50, 'yellow updater keeps the YELLOW_FLAG 50 km/h request; writable='
  .. tostring(CarManager.isWritableAICar(3)) .. ' state=' .. tostring(CarStateMachine.getCurrentState(3))
  .. ' request=' .. tostring(yellowRequest.active) .. '/' .. tostring(yellowRequest.value))
CarOperations.resolveOwnedAIControls(150)
local appliedYellowCap = false
for i = 1, #calls do
  if calls[i][1] == 'setAITopSpeed' and calls[i][2] == 3 and calls[i][3] == 50 then appliedYellowCap = true end
end
assert(appliedYellowCap, 'existing resolver applies yellow cap request')
local sawHazards = false
for i = 1, #calls do if calls[i][1] == 'turningLights' and calls[i][2] == ac.TurningLights.Hazards then sawHazards = true end end
assert(sawHazards, 'yellow updater keeps hazards')
yellowExit(3, .016, cars, 3, storage)
CarOperations.resolveOwnedAIControls(150)
assert(not yellowRequest.active, 'yellow exit releases its own top-speed request')
local yellowEndCalls = #calls
local sawLightsOff = false
for i = 1, #calls do if calls[i][1] == 'turningLights' and calls[i][2] == ac.TurningLights.None then sawLightsOff = true end end
assert(sawLightsOff, 'yellow exit turns hazards off')
for i = disablesBeforeYellow + 1, yellowEndCalls do
  assert(calls[i][1] ~= 'disableCarCollisions', 'yellow-zone pass-through does not acquire collision disable')
end

-- S3-B: a valid nonparticipant navigator finds the real accident but no longer requests a collision disable.
storage.distanceToStartNavigatingAroundCarInAccident_meters = 100
CarManager.cars_navigatingAroundAccidentIndex[4] = accident
local navDisablesBefore = disableCount(4)
CarStateMachine.queueStateTransition(4, CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT)
CarStateMachine.updateCar(4, .016, cars, 4, storage)
assert(disableCount(4) == navDisablesBefore, 'valid nonparticipant navigation does not acquire collision disable')
local sawRetirementPrevention = false
for i = 1, #calls do if calls[i][1] == 'preventAIFromRetiring' and calls[i][2] == 4 then sawRetirementPrevention = true end end
assert(sawRetirementPrevention, 'navigation fixture passed accident lookup and reached end-of-update controls')
local navigationRequest = CarOperations._topSpeedRequests[4].byOwner.ACCIDENT_NAVIGATION
assert(navigationRequest.active and navigationRequest.value == 30 and CarManager.cars_aiCaution[4] == 0,
  'navigation retains its existing top-speed and caution commands')
CarOperations.resolveOwnedAIControls(150)
local appliedNavigationCap = false
for i = 1, #calls do
  if calls[i][1] == 'setAITopSpeed' and calls[i][2] == 4 and calls[i][3] == 30 then appliedNavigationCap = true end
end
assert(appliedNavigationCap, 'existing resolver applies navigation top-speed request')
assert(CarStateMachine.getCurrentState(4) == CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT,
  'navigator-as-victim fixture starts from the actual navigation state')

-- A second independent navigator exercises the existing exit/release without consuming car 4's NAV role.
CarManager.cars_navigatingAroundAccidentIndex[5] = accident
local navDisablesBeforeSecond = disableCount(5)
CarStateMachine.queueStateTransition(5, CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT)
CarStateMachine.updateCar(5, .016, cars, 5, storage)
assert(disableCount(5) == navDisablesBeforeSecond, 'second valid navigation update also issues no collision call')
local secondNavigationRequest = CarOperations._topSpeedRequests[5].byOwner.ACCIDENT_NAVIGATION
assert(secondNavigationRequest.active and secondNavigationRequest.value == 30
  and CarManager.cars_aiCaution[5] == 0, 'second navigator reaches the same existing command path')
CarOperations.resolveOwnedAIControls(150)
local navExit = CarStateMachine.states_exitFunctions[CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT]
navExit(5, .016, cars, 5, storage)
CarOperations.resolveOwnedAIControls(150)
assert(not secondNavigationRequest.active and disableCount(5) == navDisablesBeforeSecond,
  'navigation exit releases its top-speed request without collision writes')

-- The former pass-through becomes a new culprit; an existing NAV car is accepted as its victim.
assert(CarStateMachine.getCurrentState(3) == CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE
  and AccidentManager.accidents_carIndex[accident] ~= 3 and AccidentManager.accidents_collidedWithCarIndex[accident] ~= 3,
  'pass-through is still unassociated before the new contact')
local navigationVictimIncident = assert(AccidentManager.registerCollision(3, vec(0, 0, 0), 5))
assert(AccidentManager.accidents_carIndex[navigationVictimIncident] == 3
  and AccidentManager.accidents_collidedWithCarIndex[navigationVictimIncident] == 4
  and AccidentManager.accidents_resolved[navigationVictimIncident] == false,
  'real collision record accepts a former pass-through and NAV victim')
assert(CarStateMachine.getCurrentState(4) == CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT,
  'NAV victim guard did not discard or rewrite its current state before queue consumption')
CarStateMachine.handleQueuedAccidents()
CarStateMachine.updateCar(3, .016, cars, 3, storage)
CarStateMachine.updateCar(4, .016, cars, 4, storage)
assert(not CarOperations.hasActiveIncidentStop(3) and not CarOperations.hasActiveIncidentStop(4)
  and CarStateMachine.getCurrentState(3) == CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE
  and CarStateMachine.getCurrentState(4) == CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT,
  'new contact is consumed without S2 and preserves existing yellow/navigation states')
local navCulpritIncident = assert(AccidentManager.registerCollision(4, vec(0, 0, 0), 3))
assert(AccidentManager.accidents_carIndex[navCulpritIncident] == 4
  and AccidentManager.accidents_collidedWithCarIndex[navCulpritIncident] == 2,
  'a fresh validated contact is admitted when its culprit is already navigating another incident')
CarStateMachine.handleQueuedAccidents()
for _, index in ipairs({ 2, 4 }) do CarStateMachine.updateCar(index, .016, cars, index, storage) end
assert(not CarOperations.hasActiveIncidentStop(2) and not CarOperations.hasActiveIncidentStop(4)
  and CarStateMachine.getCurrentState(4) == CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT,
  'both consumed roles remain S2-free and preserve the existing NAV maneuver')
AccidentManager.informAboutCarReset(1)
AccidentManager.informAboutCarReset(3)
AccidentManager.informAboutCarReset(4)
assert(AccidentManager.accidents_resolved[accident] == true
  and AccidentManager.accidents_resolved[navigationVictimIncident] == true
  and AccidentManager.accidents_resolved[navCulpritIncident] == true,
  'logical resets resolve both records without issuing collision enables')
for i = 1, #calls do
  if calls[i][1] == 'disableCarCollisions' then
    error('no flow in this S3-C matrix may write collision disable or enable')
  end
end

CarStateMachine.queueStateTransition(5, CarStateMachine.CarStateType.DRIVING_NORMALLY)
local pendingSnapshot = assert(CarStateMachine.getPendingReadOnly(5))
assert(pendingSnapshot.pending == CarStateMachine.CarStateType.DRIVING_NORMALLY and pendingSnapshot.valid,
  'pending snapshot reports the current-generation pending request')
CarManager.bumpCarGeneration(5)
local stalePendingSnapshot = assert(CarStateMachine.getPendingReadOnly(5))
assert(stalePendingSnapshot.pending == pendingSnapshot.pending and not stalePendingSnapshot.valid,
  'pending getter reports stale generation without clearing or operationally resolving it')
CarStateMachine.queueStateTransition(5, CarStateMachine.CarStateType.DRIVING_NORMALLY)
local currentGenerationGetter = CarManager.getCarGeneration
CarManager.getCarGeneration = function() return nil end
local unknownIdentityPending = assert(CarStateMachine.getPendingReadOnly(5))
assert(not unknownIdentityPending.valid, 'pending identity with unknown generations is never marked valid')
CarManager.getCarGeneration = currentGenerationGetter

-- An assignment without a focused proximity query is observable but has no inferred source.
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 4
AccidentManager.setCarNavigatingAroundAccident(4, 9001, 2)
local assignmentOnly = assert(AccidentManager.getAccidentDecisionReadOnly(4))
assert(assignmentOnly.query == nil and assignmentOnly.navigation.assignmentOrigin == 'UNKNOWN'
  and assignmentOnly.navigation.comparedIncident == nil and not assignmentOnly.navigation.matchesQuery,
  'navigation assignment snapshot remains available without inventing a query source')
local oldAssignment = assignmentOnly.navigation.assignedIncident
CarManager.getCarGeneration = function() error('injected navigation identity error') end
AccidentManager.setCarNavigatingAroundAccident(4, 9002, 1)
CarManager.getCarGeneration = currentGenerationGetter
assert(AccidentManager.getAccidentDecisionReadOnly(4).navigation.assignedIncident == oldAssignment,
  'failed navigation capture cannot partially overwrite its published snapshot')

-- Generation/session mismatch and zone epoch changes reject consumption after a query.
Logger.OBS1_FOCUS_CAR = 3
local finalIncident = assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 4))
local originalGeneration = CarManager.getCarGeneration(3)
CarManager.getCarGeneration = function(index)
  if index == 3 then return originalGeneration + 1 end
  return currentGenerationGetter(index)
end
assert(RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3))
CarManager.getCarGeneration = currentGenerationGetter
RaceTrackManager.markYellowZoneConsumption(3, consumedState)
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).consumer == nil,
  'generation mismatch rejects stale yellow consumption')

local querySession = CarManager.sessionGeneration
assert(RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3))
AccidentManager.accidents_splinePosition[finalIncident] = .51
AccidentManager.accidents_victimSplinePosition[finalIncident] = .49
RaceTrackManager.updateYellowFlagZones()
RaceTrackManager.markYellowZoneConsumption(3, consumedState)
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).consumer == nil,
  'bounds revision change rejects consumption from the preceding geometric query')
assert(RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3))
CarManager.sessionGeneration = querySession + 1
RaceTrackManager.markYellowZoneConsumption(3, consumedState)
CarManager.sessionGeneration = querySession
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).consumer == nil,
  'session mismatch rejects stale yellow consumption')
assert(RaceTrackManager.isSplinePositionInYellowZone(cars[3].splinePosition, 3))
RaceTrackManager.resetOwnedYellowFlagZones()
RaceTrackManager.markYellowZoneConsumption(3, consumedState)
assert(RaceTrackManager.getYellowZoneDecisionReadOnly(3).consumer == nil,
  'zone epoch change rejects stale yellow consumption')

Logger.OBS1_FOCUS_CAR = 5
local originalGetGeneration = CarManager.getCarGeneration
CarManager.getCarGeneration = function(index)
  if index == 1 then return originalGetGeneration(index) + 10 end
  return originalGetGeneration(index)
end
AccidentManager.isCarComingUpToAccident(cars[5], 100)
CarManager.getCarGeneration = originalGetGeneration
local staleCandidate = assert(AccidentManager.getAccidentDecisionReadOnly(5)).query
assert(staleCandidate.candidates[1].incident == finalIncident
  and staleCandidate.candidates[1].reason == 'stale-generation',
  'focused candidate capture includes stale-generation entries and their reason')
local staleQueuedIncident = assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 5))
CarManager.bumpCarGeneration(1)
local staleQueueWrites = #calls
CarStateMachine.handleQueuedAccidents()
assert(not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(4)
  and CarStateMachine.getCurrentState(1) ~= CarStateMachine.CarStateType.COLLIDED_WITH_CAR
  and #calls == staleQueueWrites and AccidentManager.accidents_resolved[staleQueuedIncident] == false,
  'stale participant identities consume both queue roles without S2 or stop writes')

-- Valid, identity-stamped contacts cover normal/pit-speed combinations without queue-driven S2 dispatch.
local contactMatrix = {
  { 'normal', false, false, false, false, 65, 62 },
  { 'both-pit-fast', true, true, true, true, 55, 48 },
  { 'both-pit-slow', true, true, true, true, 8, 12 },
  { 'mixed-pit', true, false, true, false, 10, 70 },
  { 'unknown-pit', nil, nil, nil, nil, 40, 42 },
}
local function assertNoContactStopWrites(from, label)
  for i = from, #calls do
    local call = calls[i]
    assert(call[1] ~= 'setAIStopCounter' and call[1] ~= 'setGentleStop'
      and not ((call[1] == 'setAITopSpeed' or call[1] == 'setAIThrottleLimit') and call[3] == 0),
      label .. ' writes no incident-stop controls')
  end
end
for i = 1, #contactMatrix do
  local row = contactMatrix[i]
  AccidentManager.informAboutCarReset(1)
  AccidentManager.informAboutCarReset(2)
  CarStateMachine.initializeCarInStateMachine(1)
  CarStateMachine.initializeCarInStateMachine(2)
  cars[1].isInPit, cars[2].isInPit = row[2], row[3]
  cars[1].isInPitlane, cars[2].isInPitlane = row[4], row[5]
  cars[1].speedKmh, cars[2].speedKmh = row[6], row[7]
  local eventStamp = {
    index = 1, generation = CarManager.getCarGeneration(1), culpritGeneration = CarManager.getCarGeneration(1),
    victimIndex = 2, victimGeneration = CarManager.getCarGeneration(2), session = CarManager.sessionGeneration,
    positionX = cars[1].position.x, positionY = cars[1].position.y, positionZ = cars[1].position.z,
    splinePosition = cars[1].splinePosition, victimPositionX = cars[2].position.x,
    victimPositionY = cars[2].position.y, victimPositionZ = cars[2].position.z,
    victimSplinePosition = cars[2].splinePosition, culpritIsInPitlane = row[4], victimIsInPitlane = row[5],
    culpritSpeedKmh = row[6], victimSpeedKmh = row[7],
  }
  local contact = assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 3, eventStamp), row[1] .. ' contact accepted')
  local softPit = row[1] == 'both-pit-slow'
  assert(AccidentManager.accidents_pitManoeuvre[contact] == softPit
    and (AccidentManager.accidents_yellowFlagZoneIndex[contact] == nil) == softPit,
    row[1] .. ' preserves PF2 soft-observation versus yellow-zone classification')
  local writesBeforeDrain = #calls
  CarStateMachine.handleQueuedAccidents()
  CarStateMachine.handleQueuedAccidents()
  for _, index in ipairs({ 1, 2 }) do CarStateMachine.updateCar(index, .016, cars, index, storage) end
  assert(not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(2)
    and CarStateMachine.getCurrentState(1) ~= CarStateMachine.CarStateType.COLLIDED_WITH_CAR
    and CarStateMachine.getCurrentState(2) ~= CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME,
    row[1] .. ' drains both roles without S2 admission or collision-state transitions')
  assertNoContactStopWrites(writesBeforeDrain + 1, row[1])
end

-- LC1 still resolves an ordinary contact after 13 valid game-clock ticks, independently of S2 admission.
AccidentManager.informAboutCarReset(1)
AccidentManager.informAboutCarReset(2)
CarStateMachine.initializeCarInStateMachine(1)
CarStateMachine.initializeCarInStateMachine(2)
cars[1].isInPit, cars[2].isInPit = false, false
cars[1].isInPitlane, cars[2].isInPitlane = false, false
cars[1].speedKmh, cars[2].speedKmh = 40, 42
cars[1].collisionDepth, cars[2].collisionDepth = 0, 0
local lc1Stamp = {
  index = 1, generation = CarManager.getCarGeneration(1), culpritGeneration = CarManager.getCarGeneration(1),
  victimIndex = 2, victimGeneration = CarManager.getCarGeneration(2), session = CarManager.sessionGeneration,
  positionX = cars[1].position.x, positionY = cars[1].position.y, positionZ = cars[1].position.z,
  splinePosition = cars[1].splinePosition, victimPositionX = cars[2].position.x,
  victimPositionY = cars[2].position.y, victimPositionZ = cars[2].position.z,
  victimSplinePosition = cars[2].splinePosition, culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 40, victimSpeedKmh = 42,
}
local lc1Incident = assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 3, lc1Stamp))
local lc1WritesBefore = #calls
CarStateMachine.handleQueuedAccidents()
for _, index in ipairs({ 1, 2 }) do CarStateMachine.updateCar(index, .016, cars, index, storage) end
assert(AccidentManager.accidents_yellowFlagZoneIndex[lc1Incident] ~= nil
  and not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(2),
  'LC1 contact retains its zone without automatically admitting S2')
activeTime = activeTime + 1
AccidentManager.updateRecovery(.25)
for _ = 1, 13 do
  activeTime = activeTime + .25
  AccidentManager.updateRecovery(.25)
end
assert(AccidentManager.accidents_resolved[lc1Incident] == true
  and not CarOperations.hasActiveIncidentStop(1) and not CarOperations.hasActiveIncidentStop(2),
  'LC1 resolves after 13 valid 0.25-second game-clock ticks without S2 admission')
assertNoContactStopWrites(lc1WritesBefore + 1, 'LC1 recovery')
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = false, -1

print('test_collision_safety: PASS (yellow, participants, NAV victim, exits and logical resets issue no collision writes)')
