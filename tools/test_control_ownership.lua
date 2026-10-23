local root = (arg[0]:gsub('tools[\\/]test_control_ownership.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
local allowed = true
local sim = { isLive = true, isReplayActive = false, isSessionStarted = true, isPaused = false }
local car = { index = 1, isAIControlled = true, isConnected = true, isActive = true, position = {}, speedKmh = 80 }
local referenceCar = { index = 0, isAIControlled = true, isConnected = true, isActive = true, position = {}, speedKmh = 50 }
local writes = {}
local function setter(kind)
  return function(index, value)
    writes[#writes + 1] = { kind, index, value }
    if _G.failSetter then error('setter failure') end
  end
end
ac = { getSim = function() return sim end,
  getCar = function(index) if index == 1 then return car elseif index == 0 then return referenceCar end end }
physics = { allowed = function() return allowed end, setAITopSpeed = setter('speed'), setAIThrottleLimit = setter('throttle') }
GameTimeManager = dofile(root .. 'GameTimeManager.lua')
local getPlayingGameTime = GameTimeManager.getPlayingGameTime
MathHelpers = { approach = function(v) return v end, vsub = function() end, dot = function() end }
StorageManager = { getStorage = function() return {} end, getStorage_Overtaking = function() return {} end,
  getStorage_Yielding = function() return {} end, getStorage_AICarValues = function() return {} end }
RaceTrackManager = { TrackSide = { LEFT = 1, RIGHT = 2 } }
RaceTrackManager.getYieldingSide = function() return RaceTrackManager.TrackSide.LEFT end
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
Logger = { error = function() end, log = function() end, warn = function() end }
render = { createRay = function() end }
VecPool = { getTempVec3 = function() end }
vec3 = function() return { set = function() end } end
CarManager = dofile(root .. 'CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
local CarOperations = dofile(root .. 'CarOperations.lua')
_G.CarOperations = CarOperations
local function drain() assert(CarOperations.resolveOwnedAIControls(0) == true) end
local function last(kind) for i = #writes, 1, -1 do if writes[i][1] == kind then return writes[i] end end end

assert(CarOperations.requestAITopSpeed(1, 150, 'TRAFFIC_YIELD'))
assert(CarOperations.requestAITopSpeed(1, 120, 'YELLOW_FLAG'))
drain(); assert(last('speed')[3] == 120, 'yellow priority wins')
local requests, winner, applied = CarOperations.getOwnedControlState(1)
assert(requests.byOwner.TRAFFIC_YIELD.value == 150 and winner.owner == 'YELLOW_FLAG' and applied.value == 120)
local requestSlot, winnerSlot, appliedSlot = requests, winner, applied
assert(CarOperations.requestAITopSpeed(1, 0, 'INCIDENT_STOP'))
drain(); assert(last('speed')[3] == 0, 'incident stop has highest priority')
assert(CarOperations._topSpeedRequests[1] == requestSlot and CarOperations._topSpeedWinner[1] == winnerSlot
  and CarOperations._topSpeedApplied[1] == appliedSlot, 'request/winner/applied records are reused across value changes')
CarOperations.releaseAITopSpeed(1, 'YELLOW_FLAG')
drain(); assert(last('speed')[3] == 0 and CarOperations._topSpeedWinner[1].owner == 'INCIDENT_STOP', 'clearing another owner preserves winner')
CarOperations.releaseAITopSpeed(1, 'INCIDENT_STOP'); drain()
assert(last('speed')[3] == 150, 'lower-priority request survives winner clear')

CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD'); drain()
assert(last('speed')[3] == math.huge, 'only our applied control is neutralized')
local neutralWrites = #writes
drain(); assert(#writes == neutralWrites, 'neutral is written once')

CarOperations.requestAITopSpeed(1, 150, 'TRAFFIC_YIELD'); drain()
assert(last('speed')[3] == 150)
CarOperations.resolveOwnedAIControls(100); assert(last('speed')[3] == 100, 'global cap applies after arbitration')
CarOperations.resolveOwnedAIControls(0); assert(last('speed')[3] == 150, 'removing cap restores preserved request')

CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD'); drain()
local countBeforeNoRequest = #writes
CarOperations.resolveOwnedAIControls(80)
assert(#writes == countBeforeNoRequest, 'global cap does not write an AI with no managed request')

assert(CarOperations.requestAITopSpeed(1, 44, 'TRAFFIC_YIELD')); drain()
local appliedOwnerBeforeSameValue = CarOperations._topSpeedApplied[1].owner
local writesBeforeSameValueOwnerChange = #writes
assert(CarOperations.requestAITopSpeed(1, 44, 'YELLOW_FLAG')); drain()
assert(CarOperations._topSpeedWinner[1].owner == 'YELLOW_FLAG'
  and CarOperations._topSpeedApplied[1].owner == appliedOwnerBeforeSameValue
  and #writes == writesBeforeSameValueOwnerChange,
  'winner can change without a write; applied owner remains the last successful setter owner')
CarOperations.releaseAITopSpeed(1, 'YELLOW_FLAG')
CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD'); drain()

assert(CarOperations.requestAIThrottleLimit(1, .4, 'TRAFFIC_YIELD'))
drain(); assert(last('throttle')[3] == .4)
GameTimeManager.update(.9); assert(CarOperations.requestAIThrottleLimit(1, .3, 'TRAFFIC_YIELD'))
GameTimeManager.update(.9); drain(); assert(last('throttle')[3] == .3, 'refresh renews one-second active-time lease')
sim.isPaused = true; GameTimeManager.update(10); drain()
assert(last('throttle')[3] == .3, 'paused simulation time freezes the lease')
sim.isPaused = false; GameTimeManager.update(.05); drain(); assert(last('throttle')[3] == .3, 'less than one active second remains leased')
GameTimeManager.update(.06); drain(); assert(last('throttle')[3] == 1, 'expiry uses active simulation time')
local afterExpiry = #writes; drain(); assert(#writes == afterExpiry)
local beforeInvalid = #writes
assert(not CarOperations.requestAIThrottleLimit(1, 1.1, 'TRAFFIC_YIELD'))
assert(not CarOperations.requestAITopSpeed(1, 0/0, 'TRAFFIC_YIELD'))
CarOperations.resolveOwnedAIControls(-1); assert(#writes == beforeInvalid, 'invalid requests/cap cause no writes')
assert(CarOperations.requestAIThrottleLimit(1, .2, 'TRAFFIC_YIELD'))
drain(); local beforeInvalidCap = #writes
assert(CarOperations.resolveOwnedAIControls(1001) == false and #writes == beforeInvalidCap,
  'invalid global cap blocks all control writes, including throttle')
GameTimeManager.getPlayingGameTime = function() return 0/0 end
assert(not CarOperations.requestAITopSpeed(1, 20, 'YELLOW_FLAG')
  and CarOperations.resolveOwnedAIControls(0) == false, 'invalid active clock fails closed')
GameTimeManager.getPlayingGameTime = getPlayingGameTime
CarOperations.releaseAIThrottleLimit(1, 'TRAFFIC_YIELD'); drain()

assert(CarOperations.requestAITopSpeed(1, 80, 'TRAFFIC_YIELD'))
local beforeDenied = #writes
allowed = false; drain(); assert(#writes == beforeDenied, 'denied permission does not invoke setter')
allowed = true; drain(); assert(last('speed')[3] == 80, 'same-identity pending request retries on permission recovery')
failSetter = true; CarOperations.requestAITopSpeed(1, 70, 'TRAFFIC_YIELD'); drain()
failSetter = false; drain(); assert(last('speed')[3] == 70, 'setter error leaves request retryable')

CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD')
allowed = false
local beforeNeutralDenied = #writes
drain(); assert(#writes == beforeNeutralDenied and select(3, CarOperations.getOwnedControlState(1)).active,
  'clear under denied permission retains only the applied shadow for retry')
physics.setAITopSpeed = nil
allowed = true
local beforeNeutralMissingAPI = #writes
drain(); assert(#writes == beforeNeutralMissingAPI, 'missing setter leaves neutralization pending')
physics.setAITopSpeed = setter('speed')
failSetter = true
local beforeNeutralError = #writes
drain(); assert(#writes == beforeNeutralError + 1, 'failed neutral setter is attempted once per resolve')
failSetter = false
local beforeNeutralSuccess = #writes
drain(); assert(#writes == beforeNeutralSuccess + 1 and last('speed')[3] == math.huge,
  'pending neutral retries once and succeeds after permission/API recovery')
local afterNeutralSuccess = #writes
drain(); assert(#writes == afterNeutralSuccess, 'successful neutral is not repeated')

local oldGeneration = CarManager.getCarGeneration(1)
assert(CarOperations.requestAITopSpeed(1, 55, 'TRAFFIC_YIELD'))
drain()
local writesBeforeGenerationClear = #writes
CarManager.bumpCarGeneration(1)
assert(CarOperations.getOwnedControlState(1) == nil and #writes == writesBeforeGenerationClear,
  'generation bump immediately clears request/winner/applied without a write')
local beforeStale = #writes; drain(); assert(#writes == beforeStale, 'old generation is discarded without neutral write')
assert(CarManager.getCarGeneration(1) == oldGeneration + 1)
local writesBeforeUnappliedRelease = #writes
failSetter = true
assert(CarOperations.requestAITopSpeed(1, 45, 'TRAFFIC_YIELD'))
drain()
assert(#writes == writesBeforeUnappliedRelease + 1 and not CarOperations._topSpeedApplied[1].active,
  'setter error must not create an applied shadow')
CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD')
local writesBeforeOrphanCleanup = #writes
drain()
assert(#writes == writesBeforeOrphanCleanup and CarOperations.getOwnedControlState(1) == nil,
  'release cleans failed-request winner without a neutral or orphaned state')
failSetter = false

for _, index in ipairs({ 0, 2, -1, 1.5, math.huge }) do
  assert(not CarOperations.requestAITopSpeed(index, 10, 'YELLOW_FLAG'))
end
car.isAIControlled = false; assert(not CarOperations.requestAITopSpeed(1, 10, 'YELLOW_FLAG')); car.isAIControlled = true
car.isConnected = false; assert(not CarOperations.requestAITopSpeed(1, 10, 'YELLOW_FLAG')); car.isConnected = true
CarManager.runtimePaused = true; assert(not CarOperations.requestAITopSpeed(1, 10, 'YELLOW_FLAG')); CarManager.runtimePaused = false
assert(not CarOperations.requestAITopSpeed(1, 10, 'YELLOW_FLAG', 100))
assert(not CarOperations.requestAITopSpeed(1, 10, 'UNAUTHORIZED', 100))

-- Fixed distinct priorities remain deterministic regardless of insertion order.
assert(CarOperations.requestAITopSpeed(1, 40, 'TRAFFIC_YIELD'))
assert(CarOperations.requestAITopSpeed(1, 30, 'INCIDENT_STOP'))
drain(); assert(CarOperations._topSpeedWinner[1].owner == 'INCIDENT_STOP' and last('speed')[3] == 30)
CarOperations.releaseAITopSpeed(1, 'INCIDENT_STOP'); drain()
assert(CarOperations._topSpeedWinner[1].owner == 'TRAFFIC_YIELD' and last('speed')[3] == 40)
CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD'); drain()

assert(CarOperations.requestAITopSpeed(1, 40, 'TRAFFIC_YIELD'))
local requestsBeforeSessionReset = CarOperations._topSpeedRequests[1]
local requestOwnerRecordBeforeSessionReset = requestsBeforeSessionReset.byOwner.TRAFFIC_YIELD
local sessionGeneration = CarManager.sessionGeneration
CarManager.invalidateSession()
local writesBeforeOldSession = #writes
assert(CarOperations.getOwnedControlState(1) == nil, 'session invalidation immediately clears ownership state')
drain(); assert(#writes == writesBeforeOldSession and CarManager.sessionGeneration == sessionGeneration + 1,
  'old session request/applied shadow is discarded without a write')
assert(CarOperations._topSpeedRequests[1] == requestsBeforeSessionReset, 'per-car storage is reused after session reset')
assert(CarOperations._topSpeedRequests[1].byOwner.TRAFFIC_YIELD == requestOwnerRecordBeforeSessionReset,
  'per-owner request record is reused after session reset')

for _ = 1, 10 do
  assert(CarOperations.requestAITopSpeed(1, 30, 'TRAFFIC_YIELD'))
  CarManager.runtimePaused = true
  local beforePause = #writes
  drain(); assert(#writes == beforePause, 'pause suspends owner writes')
  CarManager.runtimePaused = false
  CarOperations.releaseAITopSpeed(1, 'TRAFFIC_YIELD'); drain()
end

-- Exercise each real authorized state callback, including both requests and owner-specific clears.
local yieldingStorage = { UseIndicatorLightsWhenEasingInYield = false, distanceToOvertakingCarToLimitSpeed = 10,
  throttlePedalLimitWhenYieldingToOvertakingCar = .35, speedLimitValueToOvertakingCar = .5,
  minimumSpeedLimitKmhToLimitToOvertakingCar = 20, UseIndicatorLightsWhenDrivingOnYieldingLane = false,
  handleSideCheckingWhenYielding = false, UseIndicatorLightsWhenEasingOutYield = false,
  rampRelease_mps = 1, handleSideCheckingWhenYielding = false }
local behaviorStorage = { AICaution_Yielding = 1, overrideOriginalAIAggression_yielding = false,
  overrideOriginalAIDifficultyLevel_yielding = false }
StorageManager.getStorage_Yielding = function() return yieldingStorage end
StorageManager.getStorage_AICarValues = function() return behaviorStorage end
MathHelpers.distanceBetweenVec3sSqr = function() return 0 end
CarOperations.yieldSafelyToSide = function() return false end
CarOperations.driveSafelyToSide = function() return false end
CarOperations.isSecondCarClearlyAhead = function() return false end
CarOperations.isSecondCarClearlyBehindFirstCar = function() return false end
CarOperations.isFirstCarFasterThanSecondCar = function() return false end
ac.worldCoordinateToTrack = function() return { x = 0 } end
CarStateMachine = {
  CarStateType = { DRIVING_NORMALLY = 1, EASING_IN_YIELD = 2, STAYING_ON_YIELDING_LANE = 3,
    EASING_OUT_YIELD = 4, DRIVING_IN_YELLOW_FLAG_ZONE = 8, NAVIGATING_AROUND_ACCIDENT = 9 },
  CarStateTypeStrings = {}, states_minimumTimeInState = {}, states_entryFunctions = {},
  states_updateFunctions = {}, states_transitionFunctions = {}, states_exitFunctions = {},
  setStateExitReason = function() end, setReasonWhyCantYield = function() end,
  initializeCarInStateMachine = function() end,
}
Strings = { StringNames = { [1] = { None = 0 }, [2] = { None = 0 }, [3] = { None = 0 } },
  StringCategories = { StateExitReason = 1, ReasonWhyCantYield = 2, ReasonWhyCantOvertake = 3 } }
CarManager.cars_navigatingAroundAccidentIndex[1] = 1
CarManager.cars_currentlyYieldingCarToIndex[1] = 0
CarManager.cars_targetSplineOffset[1] = 0
ac.TurningLights = { Hazards = 3, None = 0, Left = 1, Right = 2 }
AccidentManager = {
  isCarComingUpToAccident = function() return nil end,
  setCarNavigatingAroundAccident = function() end,
  isAccidentResolved = function() return false end,
}
dofile(root .. 'CarStateMachine/States/CarState_DrivingNormally.lua')
dofile(root .. 'CarStateMachine/States/CarState_EasingInYield.lua')
dofile(root .. 'CarStateMachine/States/CarState_StayingOnYieldingLane.lua')
dofile(root .. 'CarStateMachine/States/CarState_EasingOutYield.lua')
dofile(root .. 'CarStateMachine/States/CarState_DrivingInYellowFlagZone.lua')
dofile(root .. 'CarStateMachine/States/CarState_NavigatingAroundAccident.lua')
assert(CarOperations.requestAIThrottleLimit(1, .8, 'TRAFFIC_YIELD'))
CarStateMachine.states_entryFunctions[1](1, .016, { car }, 1, { defaultLateralOffset = 0 })
drain()
assert(not CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.active, 'real normal-driving entry clears traffic throttle')
CarStateMachine.states_updateFunctions[2](1, .016, { car }, 1, {})
assert(CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.active
  and CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.value == .4, 'real easing-in updater requests traffic throttle')
CarManager.cars_currentlyYieldingCarToIndex[1] = 0
CarStateMachine.states_updateFunctions[3](1, .016, { car }, 1, {})
assert(CarOperations._topSpeedRequests[1].byOwner.TRAFFIC_YIELD.active
  and CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.active
  and CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.value == .35, 'real staying-yield updater requests both controls')
assert(CarOperations.requestAITopSpeed(1, 77, 'TRAFFIC_YIELD'))
CarStateMachine.states_entryFunctions[4](1, .016, { car }, 1, { defaultLateralOffset = 0, overrideAiAwareness = false })
assert(not CarOperations._topSpeedRequests[1].byOwner.TRAFFIC_YIELD.active
  and not CarOperations._throttleRequests[1].byOwner.TRAFFIC_YIELD.active, 'real easing-out entry clears only traffic owner')
CarStateMachine.states_updateFunctions[8](1, .016, { car }, 1, {})
assert(CarOperations._topSpeedRequests[1].byOwner.YELLOW_FLAG.active
  and CarOperations._topSpeedRequests[1].byOwner.YELLOW_FLAG.value == 50, 'real yellow updater requests its owner')
CarStateMachine.states_updateFunctions[9](1, .016, { car }, 1, { distanceToStartNavigatingAroundCarInAccident_meters = 100 })
assert(CarOperations._topSpeedRequests[1].byOwner.ACCIDENT_NAVIGATION.active
  and CarOperations._topSpeedRequests[1].byOwner.ACCIDENT_NAVIGATION.value == 30, 'real accident updater requests its owner')
drain()

local memoryRequests, memoryWinner, memoryApplied = CarOperations.getOwnedControlState(1)
assert(memoryRequests and memoryWinner and memoryApplied)
local writesBeforeMemoryReset = #writes
CarManager.clearCarMemory(1)
assert(CarOperations.getOwnedControlState(1) == nil and #writes == writesBeforeMemoryReset,
  'clearCarMemory immediately clears all ownership memory without physical writes')
local reusedTopSlot = CarOperations._topSpeedRequests[1]
CarOperations.requestAITopSpeed(1, 10, 'TRAFFIC_YIELD')
assert(CarOperations._topSpeedRequests[1] == reusedTopSlot, 'per-car request structures are reused after clear')

print('test_control_ownership: PASS')
