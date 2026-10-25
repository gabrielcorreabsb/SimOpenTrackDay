local root = ''
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

-- Reuse the established real-module incident fixture so the FSM and ownership APIs are exercised.
local scriptArg = arg[0]
arg[0] = 'tools/test_incident_release.lua'
dofile(root .. 'tools/test_incident_release.lua')
arg[0] = scriptArg

local carIndex = 8
local car = ac.getCar(carIndex)
assert(car and CarManager.isWritableAICar(carIndex), 'fixture provides a writable AI car')
car.isInPit, car.isInPitlane = false, false
CarStateMachine.updateCar(carIndex, .016, { [carIndex] = car }, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == CarStateMachine.CarStateType.DRIVING_NORMALLY,
  'fixture initializes through the real normal-state entry')

local trafficStates = {
  CarStateMachine.CarStateType.EASING_IN_YIELD,
  CarStateMachine.CarStateType.STAYING_ON_YIELDING_LANE,
  CarStateMachine.CarStateType.EASING_OUT_YIELD,
  CarStateMachine.CarStateType.EASING_IN_OVERTAKE,
  CarStateMachine.CarStateType.STAYING_ON_OVERTAKING_LANE,
  CarStateMachine.CarStateType.EASING_OUT_OVERTAKE,
}
for i = 1, #trafficStates do
  car.isInPitlane, car.isInPit = (i == 1), (i ~= 1)
  CarStateMachine.queueStateTransition(carIndex, trafficStates[i])
  CarStateMachine.updateCar(carIndex, .016, { [carIndex] = car }, carIndex)
  assert(CarStateMachine.getCurrentState(carIndex) == CarStateMachine.CarStateType.DRIVING_NORMALLY,
    'known pit prevents pending traffic state entry #' .. i)
end

local originalOperations = CarOperations
local throwAfterEffect = true
local controls = setmetatable({ gas = 1, clutch = 0 }, { __newindex = function(t, key, value)
  rawset(t, key, value)
  if throwAfterEffect then error('injected pedal setter failure after side effect') end
end })
ac.overrideCarControls = function() return controls end
CarOperations = dofile('CarOperations.lua')
assert(not CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Brake, .2, 'TRAFFIC_YIELD')
  and controls.brake == .2, 'post-effect pedal exception is retained as uncertain ownership')
throwAfterEffect = false
assert(CarOperations.releaseTrafficYieldControls(carIndex) and controls.brake == 0,
  'uncertain traffic-owned pedal handback is retried successfully')
assert(CarOperations.releaseTrafficYieldControls(carIndex) and controls.gas == 1,
  'repeated handback never neutralizes untouched pedals')
assert(CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Brake, .6, 'INCIDENT_STOP'))
assert(not CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Brake, .2, 'TRAFFIC_YIELD'),
  'traffic yield cannot overwrite an independent pedal owner')
assert(CarOperations.releaseTrafficYieldControls(carIndex) and controls.brake == .6,
  'pit handback preserves the independent pedal owner')
CarOperations = originalOperations

car.isInPit, car.isInPitlane = true, false
local beforePitLateral = CarManager.getCalculatedTrackLateralOffset(carIndex)
assert(CarOperations.driveSafelyToSide(carIndex, .016, car, -.5, 1, false, false, false, 'TRAFFIC_YIELD') == false,
  'traffic lateral writer refuses acquisition when only isInPit is true')
assert(CarManager.getCalculatedTrackLateralOffset(carIndex) == beforePitLateral,
  'pit backstop does not modify cached lateral offset')

car.isInPit, car.isInPitlane = false, false
local acceptedIncident = assert(AccidentManager.registerCollision(carIndex, { x = 0, y = 0, z = 0 }, carIndex + 1))
assert(CarOperations.admitIncidentStop(carIndex, acceptedIncident, CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration),
  'fixture explicitly admits a pre-existing S2 episode for pit-preservation coverage')
CarStateMachine.queueStateTransition(carIndex, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
CarStateMachine.handleQueuedAccidents()
CarStateMachine.updateCar(carIndex, .016, { [carIndex] = car }, carIndex)
assert(CarOperations.hasActiveIncidentStop(carIndex), 'accepted incident episode starts before pit entry')
car.isInPit = true
CarStateMachine.updateCar(carIndex, .016, { [carIndex] = car }, carIndex)
assert(CarOperations.hasActiveIncidentStop(carIndex)
  and (CarStateMachine.getCurrentState(carIndex) == CarStateMachine.CarStateType.COLLIDED_WITH_CAR
    or CarStateMachine.getCurrentState(carIndex) == CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME),
  'pit entry does not cancel an already accepted S2 incident stop (' .. tostring(acceptedIncident) .. ')')
assert(CarOperations.admitIncidentStop(carIndex, acceptedIncident, CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration),
  'without B filter stub, admission preserves the old contract even when a validated incident participant is in pit')
local shouldAdmit = AccidentManager.shouldAdmitIncidentStop
AccidentManager.shouldAdmitIncidentStop = function() return false end
assert(not CarOperations.admitIncidentStop(carIndex, acceptedIncident, CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration),
  'optional B admission predicate may reject a validated pit maneuver')
AccidentManager.shouldAdmitIncidentStop = shouldAdmit

-- Start a fresh real FSM/control module instance with a counted physical lateral setter.
local originalSplineSetter = physics.setAISplineOffset
local splineWrites, throwOnZero = {}, false
local simState = ac.getSim()
physics.setAISplineOffset = function(index, offset, override)
  splineWrites[#splineWrites + 1] = { index, offset, override }
  originalSplineSetter(index, offset, override)
  if throwOnZero and offset == 0 then error('injected lateral handback failure after effect') end
end
CarOperations = dofile('CarOperations.lua')
CarManager.resetSession()
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
CarStateMachine = dofile('CarStateMachine/CarStateMachine.lua')
dofile('CarStateMachine/States/CarState_DrivingNormally.lua')
local stateTypes = CarStateMachine.CarStateType
local sortedCars = { [carIndex] = car }
local stateStorage = StorageManager.getStorage()
CarStateMachine.states_transitionFunctions[stateTypes.DRIVING_NORMALLY] = function() return nil end

-- Confirm an actual normal-state lateral intervention is handed back once on pit entry.
car.isAIControlled, car.isConnected, car.isActive = true, true, true
car.isInPit, car.isInPitlane = false, false
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY and #splineWrites > 0,
  'real normal-state update acquires its lateral control on track')
local normalAcquiredWrites = #splineWrites
car.isInPit = true
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
  and #splineWrites == normalAcquiredWrites + 1 and splineWrites[#splineWrites][2] == 0,
  'pit gate releases normal-owned lateral bias exactly once without normal re-entry')
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == normalAcquiredWrites + 1, 'successful handback is not repeated on later pit ticks')

-- A post-effect handback exception remains owned and is retried from the normal pit state next tick.
car.isInPit = false
CarStateMachine.states_updateFunctions[stateTypes.DRIVING_NORMALLY](carIndex, .016, sortedCars, carIndex, stateStorage)
throwOnZero = true
car.isInPit = true
local beforeFailedHandback = #splineWrites
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == beforeFailedHandback + 1 and splineWrites[#splineWrites][2] == 0,
  'first uncertain lateral handback is attempted')
throwOnZero = false
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == beforeFailedHandback + 2 and splineWrites[#splineWrites][2] == 0,
  'uncertain lateral handback retries on the next known-pit tick')

local trafficStates = {
  stateTypes.EASING_IN_YIELD, stateTypes.STAYING_ON_YIELDING_LANE, stateTypes.EASING_OUT_YIELD,
  stateTypes.EASING_IN_OVERTAKE, stateTypes.STAYING_ON_OVERTAKING_LANE, stateTypes.EASING_OUT_OVERTAKE,
}
local entered = {}
for i = 1, #trafficStates do
  local state = trafficStates[i]
  CarStateMachine.states_entryFunctions[state] = function() entered[state] = (entered[state] or 0) + 1 end
  CarStateMachine.states_updateFunctions[state] = function() end
  CarStateMachine.states_transitionFunctions[state] = function() return nil end
  CarStateMachine.states_minimumTimeInState[state] = 0
  car.isInPit, car.isInPitlane = false, false
  CarStateMachine.queueStateTransition(carIndex, state)
  CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
  assert(CarStateMachine.getCurrentState(carIndex) == state, 'fixture enters traffic state ' .. i)
  local entryCount = entered[state]
  car.isInPitlane = true
  CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
  assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
    and entered[state] == entryCount, 'current traffic state aborts to normal in pit #' .. i)
end
for i = 1, #trafficStates do
  local state = trafficStates[i]
  car.isInPit, car.isInPitlane = true, false
  local entryCount = entered[state] or 0
  CarStateMachine.queueStateTransition(carIndex, state)
  CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
  assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
    and (entered[state] or 0) == entryCount, 'pending traffic state is suppressed in pit #' .. i)
end

local navigationState = stateTypes.NAVIGATING_AROUND_ACCIDENT
local navigationEntries, navigationUpdates = 0, 0
CarStateMachine.states_entryFunctions[navigationState] = function() navigationEntries = navigationEntries + 1 end
CarStateMachine.states_updateFunctions[navigationState] = function() navigationUpdates = navigationUpdates + 1 end
CarStateMachine.states_transitionFunctions[navigationState] = function() return nil end
CarStateMachine.states_minimumTimeInState[navigationState] = 0
local yellowUpdates = 0
local yellowState = stateTypes.DRIVING_IN_YELLOW_FLAG_ZONE
CarStateMachine.states_entryFunctions[yellowState] = function() end
CarStateMachine.states_updateFunctions[yellowState] = function() yellowUpdates = yellowUpdates + 1 end
CarStateMachine.states_transitionFunctions[yellowState] = function() return nil end
CarStateMachine.states_minimumTimeInState[yellowState] = 0
car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, yellowState)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
local yellowCountBeforePitTraffic = yellowUpdates
car.isInPit = true
CarStateMachine.queueStateTransition(carIndex, trafficStates[1])
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == yellowState and yellowUpdates == yellowCountBeforePitTraffic + 1,
  'pit traffic request cannot replace an independent current yellow-flag owner')
car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DRIVING_NORMALLY)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
CarStateMachine.queueStateTransition(carIndex, trafficStates[1])
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
car.isInPit = true
CarStateMachine.queueStateTransition(carIndex, yellowState)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == yellowState,
  'pit exit from traffic preserves an already queued yellow-flag transition')

car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DRIVING_NORMALLY)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
local beforeFailedYellowRelease = #splineWrites
throwOnZero = true
car.isInPit = true
CarStateMachine.queueStateTransition(carIndex, yellowState)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == yellowState
  and #splineWrites == beforeFailedYellowRelease + 1 and splineWrites[#splineWrites][2] == 0,
  'normal-owned pit release is attempted before the pending yellow state executes')
throwOnZero = false
local beforeYellowRetry = #splineWrites
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == yellowState
  and #splineWrites == beforeYellowRetry + 1 and splineWrites[#splineWrites][2] == 0,
  'failed normal handback retries while already in the yellow state')
car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DRIVING_NORMALLY)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
local navUpdateBeforePending = navigationUpdates
local beforePendingNavigationRelease = #splineWrites
car.isInPit = true
CarStateMachine.queueStateTransition(carIndex, navigationState)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == navigationState
  and navigationUpdates == navUpdateBeforePending + 1
  and #splineWrites == beforePendingNavigationRelease + 1 and splineWrites[#splineWrites][2] == 0,
  'normal-owned pit handback occurs before a nonwriting pending navigation state executes')

car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DRIVING_NORMALLY)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
CarStateMachine.queueStateTransition(carIndex, trafficStates[1])
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarOperations.setAIThrottleLimit(carIndex, .4, 'TRAFFIC_YIELD'),
  'current yield state owns a throttle request before pit handoff')
assert(CarOperations.setAITopSpeed(carIndex, 0, 'TRAFFIC_YIELD'),
  'current yield state owns a top-speed request before pit handoff')
assert(CarOperations.driveSafelyToSide(carIndex, .016, car, -.25, 1, false, false, false, 'COMPAT'),
  'independent navigation owner establishes its lateral intervention')
local writesBeforeNavigationHandoff = #splineWrites
local entriesBeforeNavigationDispatch, updatesBeforeNavigationDispatch = navigationEntries, navigationUpdates
car.isInPit = true
CarStateMachine.queueStateTransition(carIndex, navigationState)
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == navigationState
  and navigationEntries == entriesBeforeNavigationDispatch + 1
  and navigationUpdates == updatesBeforeNavigationDispatch + 1,
  'current traffic state preserves and dispatches pending navigation state in pit')
assert(#splineWrites == writesBeforeNavigationHandoff,
  'pit traffic cleanup does not overwrite the independent navigation lateral owner')
local trafficThrottle = CarOperations._throttleRequests[carIndex]
assert(not trafficThrottle or not trafficThrottle.byOwner.TRAFFIC_YIELD.active,
  'current traffic control request is released while the pending navigation transition is preserved')
local trafficTopSpeed = CarOperations._topSpeedRequests[carIndex]
assert(not trafficTopSpeed or not trafficTopSpeed.byOwner.TRAFFIC_YIELD.active,
  'current yield top-speed cap is released with pending navigation preserved')

-- A COMPAT/other-owner lateral write replaces the app owner tag and is not neutralized by the pit gate.
car.isInPit, car.isInPitlane = false, false
assert(CarOperations.driveSafelyToSide(carIndex, .016, car, -.25, 1, false, false, false, 'COMPAT'))
local beforeOtherOwnerPit = #splineWrites
car.isInPit = true
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == beforeOtherOwnerPit, 'pit release preserves a lateral intervention owned by another subsystem')

-- A navigation COMPAT writer must not lock out a legitimate normal writer; once normal owns the latest write,
-- pit cleanup releases that normal bias once.
car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DRIVING_NORMALLY)
local beforeNormalAfterCompat = #splineWrites
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
  and #splineWrites > beforeNormalAfterCompat, 'normal lateral writer succeeds after navigation COMPAT attribution')
local beforeNormalPitRelease = #splineWrites
car.isInPit = true
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == beforeNormalPitRelease + 1 and splineWrites[#splineWrites][2] == 0,
  'normal-owned lateral bias is released exactly once after the normal state enters pit')

-- The real defending state writes COMPAT lateral control, exits to NORMAL, and must not block normal reacquisition.
local originalBehaviorStorage = StorageManager.getStorage_Behavior
StorageManager.getStorage_Behavior = function() return { defenseDurationMin_s = 1, defenseDurationMax_s = 1 } end
dofile('CarStateMachine/States/CarState_DefendingPosition.lua')
StorageManager.getStorage_Behavior = originalBehaviorStorage
car.isInPit, car.isInPitlane = false, false
CarStateMachine.queueStateTransition(carIndex, stateTypes.DEFENDING_POSITION)
local beforeDefense = #splineWrites
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DEFENDING_POSITION
  and #splineWrites == beforeDefense + 1,
  'real defending update performs its COMPAT lateral write')
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
  and #splineWrites > beforeDefense + 1,
  'real defending exit to normal permits normal lateral reacquisition without ownership clearing')
local beforeDefensePitRelease = #splineWrites
car.isInPit = true
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(#splineWrites == beforeDefensePitRelease + 1 and splineWrites[#splineWrites][2] == 0,
  'normal control reacquired after defending is handed back once on pit entry')

-- Unknown pit fields remain permissive; both explicit known-pit flags above were independently exercised.
car.isInPit, car.isInPitlane = nil, nil
local beforeUnknownPit = #splineWrites
CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
  and #splineWrites > beforeUnknownPit, 'unknown pit state does not blanket-suppress normal driving')

-- Exercise the real easing-out writers and real staying-yield exit cleanup, not state-function stubs.
local originalYieldStorage, originalOvertakingStorage = StorageManager.getStorage_Yielding, StorageManager.getStorage_Overtaking
StorageManager.getStorage_Yielding = function()
  local value = originalYieldStorage()
  value.rampRelease_mps, value.handleSideCheckingWhenYielding = 1, false
  value.UseIndicatorLightsWhenEasingOutYield = false
  return value
end
StorageManager.getStorage_Overtaking = function()
  local value = originalOvertakingStorage()
  value.overtakeRampRelease_mps, value.handleSideCheckingWhenOvertaking = 1, false
  value.UseIndicatorLightsWhenEasingOutOvertaking = false
  return value
end
dofile('CarStateMachine/States/CarState_EasingOutYield.lua')
dofile('CarStateMachine/States/CarState_EasingOutOvertake.lua')
dofile('CarStateMachine/States/CarState_StayingOnYieldingLane.lua')
StorageManager.getStorage_Yielding, StorageManager.getStorage_Overtaking = originalYieldStorage, originalOvertakingStorage

for _, state in ipairs({ stateTypes.EASING_OUT_YIELD, stateTypes.EASING_OUT_OVERTAKE }) do
  CarStateMachine.states_entryFunctions[state] = function() end
  CarStateMachine.states_transitionFunctions[state] = function() return nil end
  car.isInPit, car.isInPitlane = false, false
  CarStateMachine.queueStateTransition(carIndex, state)
  local writesBeforeEasing = #splineWrites
  CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
  assert(#splineWrites > writesBeforeEasing, 'real easing-out state acquires lateral control on track: ' .. state)
  local writesBeforePit = #splineWrites
  car.isInPit = true
  CarStateMachine.updateCar(carIndex, .016, sortedCars, carIndex)
  assert(CarStateMachine.getCurrentState(carIndex) == stateTypes.DRIVING_NORMALLY
    and #splineWrites == writesBeforePit + 1 and splineWrites[#splineWrites][2] == 0,
    'real easing-out lateral owner is handed back on pit entry: ' .. state)
end

local pedalValues, pedalWrites = { gas = .85, brake = .35, clutch = .1 }, {}
rawset(controls, 'gas', nil)
rawset(controls, 'brake', nil)
rawset(controls, 'clutch', nil)
setmetatable(controls, {
  __index = function(_, key) return pedalValues[key] end,
  __newindex = function(_, key, value)
    pedalWrites[#pedalWrites + 1] = { key, value }
    pedalValues[key] = value
  end,
})
local stayingYieldExit = CarStateMachine.states_exitFunctions[stateTypes.STAYING_ON_YIELDING_LANE]
assert(type(stayingYieldExit) == 'function', 'real staying-yield exit function is loaded')
stayingYieldExit(carIndex, .016, sortedCars, carIndex, stateStorage)
assert(#pedalWrites == 0 and pedalValues.gas == .85 and pedalValues.brake == .35,
  'real staying-yield exit never resets untouched gas or brake')
assert(CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Brake, .2, 'TRAFFIC_YIELD'))
stayingYieldExit(carIndex, .016, sortedCars, carIndex, stateStorage)
local gasResetWrites, brakeResetWrites = 0, 0
for i = 1, #pedalWrites do
  if pedalWrites[i][1] == 'gas' then gasResetWrites = gasResetWrites + 1 end
  if pedalWrites[i][1] == 'brake' and pedalWrites[i][2] == 0 then brakeResetWrites = brakeResetWrites + 1 end
end
assert(gasResetWrites == 0 and brakeResetWrites == 1 and pedalValues.gas == .85 and pedalValues.brake == 0,
  'real staying-yield exit resets only its app-owned brake, not untouched gas')

-- Permission/lifecycle gates never perform a handback write; invalidation clears bookkeeping without restoring stale state.
local function acquireNormalLateral()
  car.isAIControlled, car.isInPit, car.isInPitlane = true, false, false
  CarStateMachine.states_updateFunctions[stateTypes.DRIVING_NORMALLY](carIndex, .016, sortedCars, carIndex, stateStorage)
end
local function assertNoReleaseWrite(label, setBlocked)
  acquireNormalLateral()
  car.isInPit = true
  setBlocked(true)
  local before = #splineWrites
  CarOperations.releaseTrafficYieldControls(carIndex)
  assert(#splineWrites == before, label .. ' performs no physical handback while blocked')
  setBlocked(false)
end
assertNoReleaseWrite('paused', function(value) simState.isPaused = value end)
assertNoReleaseWrite('runtime paused', function(value) CarManager.runtimePaused = value end)
assertNoReleaseWrite('replay', function(value) simState.isReplayActive = value end)
assertNoReleaseWrite('disabled', function(value) CarManager.runtimeEnabled = not value end)
assertNoReleaseWrite('permission denied', function(value) physics.allowed = function() return not value end end)
acquireNormalLateral()
car.isInPit, car.isAIControlled = true, false
local beforeHuman = #splineWrites
assert(not CarOperations.releaseTrafficYieldControls(carIndex) and #splineWrites == beforeHuman,
  'human/unwritable car never receives a handback write')
local beforePlayer = #splineWrites
assert(not CarOperations.releaseTrafficYieldControls(0) and #splineWrites == beforePlayer,
  'player index is never written during pit handback')
car.isAIControlled = true
acquireNormalLateral()
CarManager.invalidateCarLifecycle(carIndex)
car.isInPit = true
local beforeStale = #splineWrites
CarOperations.releaseTrafficYieldControls(carIndex)
assert(#splineWrites == beforeStale, 'lifecycle invalidation clears ownership without stale restoration')

print('test_pit_controls: PASS (current/pending traffic gates, owned lateral release/retry, permission and identity safety)')
