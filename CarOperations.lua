local CarOperations = {}

-- bindings
local ac = ac
local ac_getCar = ac.getCar
local ac_getCarMaxSpeedWithGear = ac.getCarMaxSpeedWithGear
local ac_overrideCarControls = ac.overrideCarControls
local ac_setTargetCar = ac.setTargetCar
local ac_setTurningLights = ac.setTurningLights
local string = string
local string_format = string.format
local math = math
local math_huge = math.huge
local math_abs = math.abs
local math_max = math.max
local physics = physics
local physics_disableCarCollisions = physics.disableCarCollisions
local physics_preventAIFromRetiring = physics.preventAIFromRetiring
local physics_setAIAggression = physics.setAIAggression
local physics_setAICaution = physics.setAICaution
local physics_setAILevel = physics.setAILevel
local physics_setAISplineOffset = physics.setAISplineOffset
local physics_setAIStopCounter = physics.setAIStopCounter
local physics_setExtraAIGrip = physics.setExtraAIGrip
local physics_setGentleStop = physics.setGentleStop
local MathHelpers_approach = MathHelpers.approach
local MathHelpers_vsub = MathHelpers.vsub
local MathHelpers_dot = MathHelpers.dot
local CarManager = CarManager
local CarManager_getActualTrackLateralOffset = CarManager.getActualTrackLateralOffset
local CarManager_getCalculatedTrackLateralOffset = CarManager.getCalculatedTrackLateralOffset
local CarManager_getDefaultAIAggression = CarManager.getDefaultAIAggression
local CarManager_getDefaultAIDifficultyLevel = CarManager.getDefaultAIDifficultyLevel
local CarManager_isCarMidCorner = CarManager.isCarMidCorner
local CarManager_isCarOffTrack = CarManager.isCarOffTrack
local CarManager_setCalculatedTrackLateralOffset = CarManager.setCalculatedTrackLateralOffset
local Logger = Logger
local Logger_error = Logger.error
local Logger_log = Logger.log
local Logger_warn = Logger.warn
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_getLateralOffsetSign = RaceTrackManager.getLateralOffsetSign
local RaceTrackManager_getOppositeSide = RaceTrackManager.getOppositeSide
local RaceTrackManager_getOvertakingSide = RaceTrackManager.getOvertakingSide
local RaceTrackManager_getYieldingSide = RaceTrackManager.getYieldingSide
local StorageManager = StorageManager
local StorageManager_getStorage = StorageManager.getStorage
local StorageManager_getStorage_Overtaking = StorageManager.getStorage_Overtaking
local StorageManager_getStorage_Yielding = StorageManager.getStorage_Yielding
local render = render
local render_createRay = render.createRay
local VecPool_getTempVec3 = VecPool.getTempVec3
local table_clear = table.clear
local GameTimeManager = GameTimeManager
local canWriteCar

-- Ownership is intentionally limited to the AI top-speed and throttle-limit APIs.
local CONTROL_LEASE_SECONDS = 1
local OWNER_PRIORITY = { INCIDENT_STOP = 100, ACCIDENT_NAVIGATION = 90, YELLOW_FLAG = 80, TRAFFIC_YIELD = 50, COMPAT = 10 }
local OWNER_ORDER = { 'INCIDENT_STOP', 'ACCIDENT_NAVIGATION', 'YELLOW_FLAG', 'TRAFFIC_YIELD', 'COMPAT' }
CarOperations._topSpeedRequests = CarOperations._topSpeedRequests or {}
CarOperations._throttleRequests = CarOperations._throttleRequests or {}
CarOperations._topSpeedApplied = CarOperations._topSpeedApplied or {}
CarOperations._throttleApplied = CarOperations._throttleApplied or {}
CarOperations._topSpeedWinner = CarOperations._topSpeedWinner or {}
CarOperations._throttleWinner = CarOperations._throttleWinner or {}
CarOperations._topSpeedAttempted = CarOperations._topSpeedAttempted or {}
CarOperations._throttleAttempted = CarOperations._throttleAttempted or {}
CarOperations._resolutionId = 0

local function getActiveGameTime()
  if not GameTimeManager or type(GameTimeManager.getPlayingGameTime) ~= 'function' then return nil end
  local ok, now = pcall(GameTimeManager.getPlayingGameTime)
  if not ok or type(now) ~= 'number' or now ~= now or now < 0 or now == math_huge then return nil end
  return now
end

local function getControlSlot(slots, carIndex)
  local slot = slots[carIndex]
  if slot then return slot end
  slot = { activeCount = 0, byOwner = {} }
  for i = 1, #OWNER_ORDER do
    local owner = OWNER_ORDER[i]
    slot.byOwner[owner] = { owner = owner, active = false }
  end
  slots[carIndex] = slot
  return slot
end

local function requestControl(slots, carIndex, value, owner, priority, maximum)
  local fixedPriority = type(owner) == 'string' and OWNER_PRIORITY[owner] or nil
  local now = getActiveGameTime()
  if not canWriteCar(carIndex) or not fixedPriority or (priority ~= nil and priority ~= fixedPriority)
    or type(value) ~= 'number' or value ~= value or value == -math_huge
    or value < 0 or value > maximum or now == nil then return false end
  local slot = getControlSlot(slots, carIndex)
  local item = slot.byOwner[owner]
  if not item.active then slot.activeCount = slot.activeCount + 1 end
  item.value, item.priority, item.expiresAt = value, fixedPriority, now + CONTROL_LEASE_SECONDS
  item.carGeneration, item.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
  item.active = true
  return true
end

function CarOperations.requestAITopSpeed(carIndex, value, owner, priority)
  return requestControl(CarOperations._topSpeedRequests, carIndex, value, owner, priority, 1000)
end
function CarOperations.requestAIThrottleLimit(carIndex, value, owner, priority)
  return requestControl(CarOperations._throttleRequests, carIndex, value, owner, priority, 1)
end
local function releaseControl(slots, carIndex, owner)
  local slot = slots[carIndex]
  local item = slot and slot.byOwner[owner]
  if not item or not item.active then return false end
  item.active = false
  slot.activeCount = slot.activeCount - 1
  local winners = slots == CarOperations._topSpeedRequests and CarOperations._topSpeedWinner or CarOperations._throttleWinner
  local winner = winners[carIndex]
  if winner and winner.active and winner.owner == owner then winner.active = false end
  return true
end
function CarOperations.releaseAITopSpeed(carIndex, owner) return releaseControl(CarOperations._topSpeedRequests, carIndex, owner) end
function CarOperations.releaseAIThrottleLimit(carIndex, owner) return releaseControl(CarOperations._throttleRequests, carIndex, owner) end

local function clearCarRequests(slots, carIndex)
  local slot = slots[carIndex]
  if not slot then return end
  for i = 1, #OWNER_ORDER do
    local item = slot.byOwner[OWNER_ORDER[i]]
    item.active = false
  end
  slot.activeCount = 0
end

function CarOperations.clearOwnedControlsForCar(carIndex)
  clearCarRequests(CarOperations._topSpeedRequests, carIndex)
  clearCarRequests(CarOperations._throttleRequests, carIndex)
  local topWinner = CarOperations._topSpeedWinner[carIndex]
  local throttleWinner = CarOperations._throttleWinner[carIndex]
  local topApplied = CarOperations._topSpeedApplied[carIndex]
  local throttleApplied = CarOperations._throttleApplied[carIndex]
  if topWinner then topWinner.active = false end
  if throttleWinner then throttleWinner.active = false end
  if topApplied then topApplied.active = false end
  if throttleApplied then throttleApplied.active = false end
end

function CarOperations.clearAllOwnedControls()
  for carIndex in pairs(CarOperations._topSpeedRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._throttleRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._topSpeedApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._throttleApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
end

local function resolveControl(carIndex, slots, winners, applied, attempted, setterName, neutral, cap, now, resolutionId)
  local requestSlot = slots[carIndex]
  local winner, winnerName
  if requestSlot then
    for i = 1, #OWNER_ORDER do
      local item = requestSlot.byOwner[OWNER_ORDER[i]]
      if item.active and (item.carGeneration ~= CarManager.getCarGeneration(carIndex)
        or item.sessionGeneration ~= CarManager.sessionGeneration or now >= item.expiresAt) then
        item.active = false
        requestSlot.activeCount = requestSlot.activeCount - 1
      end
      if item.active and (not winner or item.priority > winner.priority
        or (item.priority == winner.priority and item.owner < winnerName)) then
        winner, winnerName = item, item.owner
      end
    end
  end
  local winnerSlot = winners[carIndex]
  if not winnerSlot then winnerSlot = {}; winners[carIndex] = winnerSlot end
  winnerSlot.active = winner ~= nil
  if winner then winnerSlot.value, winnerSlot.owner, winnerSlot.priority = winner.value, winnerName, winner.priority end
  local previous = applied[carIndex]
  if winner then
    local value = winner.value
    if cap ~= nil and cap > 0 then value = math.min(value, cap) end
    if previous and previous.active and previous.carGeneration == CarManager.getCarGeneration(carIndex)
      and previous.sessionGeneration == CarManager.sessionGeneration and previous.value == value then return end
    local writable = CarManager.isWritableAICar(carIndex)
    local api = physics and physics[setterName]
    if writable and type(api) == 'function' then
      if attempted[carIndex] == resolutionId then return end
      attempted[carIndex] = resolutionId
      local ok = pcall(api, carIndex, value)
      if ok then
        local appliedSlot = previous or {}
        applied[carIndex] = appliedSlot
        appliedSlot.active, appliedSlot.value, appliedSlot.owner, appliedSlot.priority = true, value, winnerName, winner.priority
        appliedSlot.carGeneration, appliedSlot.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
      end
    end
  elseif previous and previous.active then
    if previous.carGeneration ~= CarManager.getCarGeneration(carIndex) or previous.sessionGeneration ~= CarManager.sessionGeneration then
      previous.active = false
      return
    end
    if CarManager.isWritableAICar(carIndex) and physics and type(physics[setterName]) == 'function' then
      if attempted[carIndex] == resolutionId then return end
      attempted[carIndex] = resolutionId
      local ok = pcall(physics[setterName], carIndex, neutral)
      if ok then previous.active = false end
    end
  end
end

function CarOperations.getOwnedControlState(carIndex)
  local topRequests, throttleRequests = CarOperations._topSpeedRequests[carIndex], CarOperations._throttleRequests[carIndex]
  local topWinner, throttleWinner = CarOperations._topSpeedWinner[carIndex], CarOperations._throttleWinner[carIndex]
  local topApplied, throttleApplied = CarOperations._topSpeedApplied[carIndex], CarOperations._throttleApplied[carIndex]
  if topRequests and topRequests.activeCount == 0 then topRequests = nil end
  if throttleRequests and throttleRequests.activeCount == 0 then throttleRequests = nil end
  if topWinner and not topWinner.active then topWinner = nil end
  if throttleWinner and not throttleWinner.active then throttleWinner = nil end
  if topApplied and not topApplied.active then topApplied = nil end
  if throttleApplied and not throttleApplied.active then throttleApplied = nil end
  return topRequests, topWinner, topApplied, throttleRequests, throttleWinner, throttleApplied
end

function CarOperations.resolveOwnedAIControls(topSpeedCapKmh)
  if type(topSpeedCapKmh) ~= 'number' or topSpeedCapKmh ~= topSpeedCapKmh or topSpeedCapKmh < 0 or topSpeedCapKmh > 1000 then return false end
  local now = getActiveGameTime()
  if now == nil then return false end
  CarOperations._resolutionId = CarOperations._resolutionId + 1
  local resolutionId = CarOperations._resolutionId
  for carIndex, slot in pairs(CarOperations._topSpeedRequests) do
    if slot.activeCount > 0 or (CarOperations._topSpeedApplied[carIndex] and CarOperations._topSpeedApplied[carIndex].active)
      or (CarOperations._topSpeedWinner[carIndex] and CarOperations._topSpeedWinner[carIndex].active) then
      resolveControl(carIndex, CarOperations._topSpeedRequests, CarOperations._topSpeedWinner, CarOperations._topSpeedApplied,
        CarOperations._topSpeedAttempted, 'setAITopSpeed', math_huge, topSpeedCapKmh, now, resolutionId)
    end
  end
  for carIndex, slot in pairs(CarOperations._throttleRequests) do
    if slot.activeCount > 0 or (CarOperations._throttleApplied[carIndex] and CarOperations._throttleApplied[carIndex].active)
      or (CarOperations._throttleWinner[carIndex] and CarOperations._throttleWinner[carIndex].active) then
      resolveControl(carIndex, CarOperations._throttleRequests, CarOperations._throttleWinner, CarOperations._throttleApplied,
        CarOperations._throttleAttempted, 'setAIThrottleLimit', 1, nil, now, resolutionId)
    end
  end
  return true
end

canWriteCar = function(carIndex)
  return CarManager and CarManager.isWritableAICar and CarManager.isWritableAICar(carIndex) == true
end

-- Reusable scratch objects for getSideAnchorPoints to avoid per-call allocations.
-- NOTE: these are distinct vec3 instances (VecPool.getTempVec3 returns a single shared singleton).
CarOperations._reusableSideAnchorTable = CarOperations._reusableSideAnchorTable or {}
CarOperations._reusableVec3_center      = CarOperations._reusableVec3_center      or vec3(0, 0, 0)
CarOperations._reusableVec3_frontLeft   = CarOperations._reusableVec3_frontLeft   or vec3(0, 0, 0)
CarOperations._reusableVec3_centerLeft  = CarOperations._reusableVec3_centerLeft  or vec3(0, 0, 0)
CarOperations._reusableVec3_rearLeft    = CarOperations._reusableVec3_rearLeft    or vec3(0, 0, 0)
CarOperations._reusableVec3_frontRight  = CarOperations._reusableVec3_frontRight  or vec3(0, 0, 0)
CarOperations._reusableVec3_centerRight = CarOperations._reusableVec3_centerRight or vec3(0, 0, 0)
CarOperations._reusableVec3_rearRight   = CarOperations._reusableVec3_rearRight   or vec3(0, 0, 0)
CarOperations._reusableVec3_right       = CarOperations._reusableVec3_right       or vec3(0, 0, 0)

---@enum CarOperations.CarDirections
CarOperations.CarDirections = {
  None = 0,
  FrontLeft = 1,
  CenterLeft = 2,
  RearLeft = 3,
  FrontRight = 4,
  CenterRight = 5,
  RearRight = 6,
  FrontLeftAngled = 7,
  RearLeftAngled = 8,
  FrontRightAngled = 9,
  RearRightAngled = 10,
}

--[====[
---@alias CarOperations.CarDirections 
---| `CarOperations.CarDirections.None` @Value: 0.
---| `CarOperations.CarDirections.FrontLeft` @Value: 1.
---| `CarOperations.CarDirections.CenterLeft` @Value: 2.
---| `CarOperations.CarDirections.RearLeft` @Value: 3.
---| `CarOperations.CarDirections.FrontRight` @Value: 4.
---| `CarOperations.CarDirections.CenterRight` @Value: 5.
---| `CarOperations.CarDirections.RearRight` @Value: 6.
---| `CarOperations.CarDirections.FrontLeftAngled` @Value: 7.
---| `CarOperations.CarDirections.RearLeftAngled` @Value: 8.
---| `CarOperations.CarDirections.FrontRightAngled` @Value: 9.
---| `CarOperations.CarDirections.RearRightAngled` @Value: 10.
--]====]

CarOperations.CarDirectionsStrings = {
  [CarOperations.CarDirections.None] = "None",
  [CarOperations.CarDirections.FrontLeft] = "FrontLeft",
  [CarOperations.CarDirections.CenterLeft] = "CenterLeft",
  [CarOperations.CarDirections.RearLeft] = "RearLeft",
  [CarOperations.CarDirections.FrontRight] = "FrontRight",
  [CarOperations.CarDirections.CenterRight] = "CenterRight",
  [CarOperations.CarDirections.RearRight] = "RearRight",
  [CarOperations.CarDirections.FrontLeftAngled] = "FrontLeftAngled",
  [CarOperations.CarDirections.RearLeftAngled] = "RearLeftAngled",
  [CarOperations.CarDirections.FrontRightAngled] = "FrontRightAngled",
  [CarOperations.CarDirections.RearRightAngled] = "RearRightAngled",
}

-- local SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING = 3.0
-- local BACKFACE_CULLING_FOR_BLOCKING = 1 -- set to 0 to disable backface culling, or to -1 to hit backfaces only. Default value: 1.

local INV_SQRT2 = 0.7071067811865476 -- 1/sqrt(2) for exact 45° blend

-- local RENDER_CAR_BLOCK_CHECK_RAYS_LEFT_COLOR = rgbm(0,0,1,1) -- blue
-- local RENDER_CAR_BLOCK_CHECK_RAYS_RIGHT_COLOR = rgbm(1,0,0,1) -- red
local RENDER_CAR_BLOCK_CHECK_RAYS_NON_HIT_COLOR = ColorManager.RGBM_Colors.Red
local RENDER_CAR_BLOCK_CHECK_RAYS_HIT_COLOR = ColorManager.RGBM_Colors.SeaGreen

local DISTANCE_TO_UPCOMING_CORNER_TO_INCREASE_AICAUTION = 25 -- if an upcoming corner is closer than this, increase the caution level

local storage = StorageManager_getStorage()
local storage_Overtaking = StorageManager_getStorage_Overtaking()
local storage_Yielding = StorageManager_getStorage_Yielding()
local storage_AICarBehavior = StorageManager.getStorage_AICarValues()

--[===[
https://discord.com/channels/453595061788344330/962668819933982720/1423344738576109741

* Caution affects how hard they're trying to avoid other cars front to back
* Aggression affects how hard they're trying to avoid other cars left to right
* Difficulty (level) affects how fast they drive through corners as well as how hard they press the throttle
--]===]

---@enum CarOperations.CarPedals
CarOperations.CarPedals = {
  Gas = 1,
  Brake = 2,
  Clutch = 3,
}

---Value from 0 to 1. Final value will be the maximum of original and this.
---(For clutch: 1 is for clutch pedal fully depressed, 0 for pressed).
---@param carIndex integer
---@param carPedal CarOperations.CarPedals
---@param pedalPosition number
CarOperations.setPedalPosition = function(carIndex, carPedal, pedalPosition)
  if not canWriteCar(carIndex) or type(pedalPosition) ~= 'number' or pedalPosition ~= pedalPosition
    or type(ac_overrideCarControls) ~= 'function' then return false end
  local carInput = ac_overrideCarControls(carIndex)
  if not carInput then return end

  if carPedal == CarOperations.CarPedals.Gas then
    carInput.gas = pedalPosition
  elseif carPedal == CarOperations.CarPedals.Brake then
    carInput.brake = pedalPosition
  elseif carPedal == CarOperations.CarPedals.Clutch then
    carInput.clutch = pedalPosition
  end
end

---Resets the specified pedal to the original value
---@param carIndex integer
---@param carPedal CarOperations.CarPedals
CarOperations.resetPedalPosition = function(carIndex, carPedal)
  if not canWriteCar(carIndex) or type(ac_overrideCarControls) ~= 'function' then return false end
  local carInput = ac_overrideCarControls(carIndex)
  if not carInput then return end

  if carPedal == CarOperations.CarPedals.Gas then
    carInput.gas = 0
  elseif carPedal == CarOperations.CarPedals.Brake then
    carInput.brake = 0
  elseif carPedal == CarOperations.CarPedals.Clutch then
    carInput.clutch = 1 -- For clutch: 1 is for clutch pedal fully depressed, 0 for pressed
  end
end

-- local ARRIVED_AT_TARGET_SPLINE_OFFSET_EPSILON = 0.02 -- in lateral spline offset units
local ARRIVED_AT_TARGET_SPLINE_OFFSET_EPSILON = 0.1 -- in lateral spline offset units

---Returns a boolean value indicating whether the car has arrived at its target spline offset
---@param carIndex integer
---@param drivingToSide RaceTrackManager.TrackSide
---@return boolean
CarOperations.hasArrivedAtTargetSplineOffset = function(carIndex, drivingToSide)
    -- local currentSplineOffset = CarManager.getCalculatedTrackLateralOffset(carIndex)
    local currentSplineOffset = CarManager_getActualTrackLateralOffset(carIndex, ac_getCar(carIndex).position)
    local targetSplineOffset = CarManager.cars_targetSplineOffset[carIndex]
      if drivingToSide == RaceTrackManager.TrackSide.LEFT then
        return currentSplineOffset - ARRIVED_AT_TARGET_SPLINE_OFFSET_EPSILON <= targetSplineOffset
      end

      return currentSplineOffset + ARRIVED_AT_TARGET_SPLINE_OFFSET_EPSILON >= targetSplineOffset
end

---Limits AI throttle pedal.
---Andreas: I don't think physics.setAIThrottleLimit works as intended because it doesn't seem to have any effect on the car speed.
---Andreas: Or maybe it touches the pedal values?
---@param carIndex integer @0-based car index.
---@param limit number @0 for limit gas pedal to 0, 1 to remove limitation.
CarOperations.setAIThrottleLimit = function(carIndex, limit, owner)
    return CarOperations.requestAIThrottleLimit(carIndex, limit, owner or 'COMPAT')
end

CarOperations.resetAIThrottleLimit = function(carIndex, owner)
  return CarOperations.releaseAIThrottleLimit(carIndex, owner or 'COMPAT')
end

---Limits AI top speed. Use `math.huge` (or just 1e9) to remove limitation.
---Andreas: I don't think physics.setAITopSpeed works as intended because it doesn't seem to have any effect on the car speed.
---@param carIndex integer @0-based car index.
---@param limit number @Speed in km/h.
CarOperations.setAITopSpeed = function(carIndex, limit, owner)
    return CarOperations.requestAITopSpeed(carIndex, limit, owner or 'COMPAT')
end

---Removes the AI top speed limit.
---@param carIndex integer
CarOperations.removeAITopSpeed = function(carIndex, owner)
  return CarOperations.releaseAITopSpeed(carIndex, owner or 'COMPAT')
end

---Anti-drag-race: enquanto um carro está em yielding, ele não pode acelerar deliberadamente
---para segurar o carro que está ultrapassando. Força setAITopSpeed para 95% da velocidade
---do carro que está ultrapassando. Idempotente: chamar várias vezes no mesmo frame é OK.
---@param yieldingCarIndex integer
---@param overtakingCarIndex integer
CarOperations.applyAntiDragRaceLimit = function(yieldingCarIndex, overtakingCarIndex)
  if not canWriteCar(yieldingCarIndex) or not yieldingCarIndex or not overtakingCarIndex then return end
  local overtakingCar = ac_getCar(overtakingCarIndex)
  if not overtakingCar or overtakingCar.speedKmh < 5 then
    CarOperations.removeAntiDragRaceLimit(yieldingCarIndex)
    return
  end
  local safeOvertakingSpeedKmh = overtakingCar.speedKmh * 0.95
  local currentTopSpeedLimit = CarOperations._currentAntiDragRaceTopSpeeds[yieldingCarIndex]
  if currentTopSpeedLimit ~= safeOvertakingSpeedKmh then
    if not CarOperations.requestAITopSpeed(yieldingCarIndex, safeOvertakingSpeedKmh, 'TRAFFIC_YIELD') then return end
    CarOperations._currentAntiDragRaceTopSpeeds[yieldingCarIndex] = safeOvertakingSpeedKmh
  end
end

---Remove o top speed limit imposto pelo anti-drag-race.
---@param yieldingCarIndex integer
CarOperations.removeAntiDragRaceLimit = function(yieldingCarIndex)
  if CarOperations._currentAntiDragRaceTopSpeeds[yieldingCarIndex] then
    CarOperations.releaseAITopSpeed(yieldingCarIndex, 'TRAFFIC_YIELD')
    CarOperations._currentAntiDragRaceTopSpeeds[yieldingCarIndex] = nil
  end
end

---@type table<integer, number>
CarOperations._currentAntiDragRaceTopSpeeds = CarOperations._currentAntiDragRaceTopSpeeds or {}

---Changes AI caution, altering the distance it keeps from the car in front of it. Default value: `1`. Experimental.
---@param carIndex integer @0-based car index.
---@param caution number @AI caution from 0 to 16.
CarOperations.setAICaution = function(carIndex, caution)
    if not canWriteCar(carIndex) or type(caution) ~= 'number' or caution ~= caution or type(physics_setAICaution) ~= 'function' then return false end
    physics_setAICaution(carIndex, caution)
    CarManager.cars_aiCaution[carIndex] = caution
end

---Removes any AI caution and sets it back to the default value.
---@param carIndex integer
CarOperations.removeAICaution = function(carIndex)
  CarOperations.setAICaution(carIndex, storage_AICarBehavior.defaultAICaution)
end

---Changes AI aggression.
---@param carIndex integer @0-based car index.
---@param aggression number @AI aggression from 0 to 1. Note: aggression level set in a launcher will be multiplied by 0.95, so to set 100% aggression here, pass 0.95.
CarOperations.setAIAggression = function(carIndex, aggression)
    if not canWriteCar(carIndex) or type(aggression) ~= 'number' or aggression ~= aggression or type(physics_setAIAggression) ~= 'function' then return false end
    physics_setAIAggression(carIndex, aggression)
    CarManager.cars_aiAggression[carIndex] = aggression
end

---Removes any AI aggression and sets it back to the default value.
---@param carIndex integer @0-based car index.
CarOperations.setDefaultAIAggression = function(carIndex)
  local aiAggression = CarManager_getDefaultAIAggression(carIndex)
  CarOperations.setAIAggression(carIndex, aiAggression)
end

---Sets the AI difficulty level.
---@param carIndex integer @0-based car index.
---@param aiDifficultyLevel integer @AI difficulty level from 0 to 2.
CarOperations.setAIDifficultyLevel = function(carIndex, aiDifficultyLevel)
    if not canWriteCar(carIndex) or type(aiDifficultyLevel) ~= 'number' or aiDifficultyLevel ~= aiDifficultyLevel or type(physics_setAILevel) ~= 'function' then return false end
    physics_setAILevel(carIndex, aiDifficultyLevel)
    CarManager.cars_aiDifficultyLevel[carIndex] = aiDifficultyLevel
end

---Removes any AI difficulty levels and sets it back to the default value.
---@param carIndex integer @0-based car index.
CarOperations.setDefaultAIDifficultyLevel = function(carIndex)
  local aiDifficultyLevel = CarManager_getDefaultAIDifficultyLevel(carIndex)
  CarOperations.setAIDifficultyLevel(carIndex, aiDifficultyLevel)
end

---Forces AI to brake for a specified amount of time. Originally, this mechanism is used to get AIs to brake after an incident.
---Subsequent calls overwrite current waiting, pass 0 to get cars to move.
---@param carIndex integer @0-based car index.
---@param time number @Time in seconds.
CarOperations.setAIStopCounter = function(carIndex, time)
    if not canWriteCar(carIndex) or type(time) ~= 'number' or time ~= time or type(physics_setAIStopCounter) ~= 'function' then return false end
    physics_setAIStopCounter(carIndex, time)
    CarManager.cars_aiStopCounter[carIndex] = time
end

---
---@param carIndex integer
---@param grip number @grip value
CarOperations.setGrip = function(carIndex, grip)
    if not canWriteCar(carIndex) or type(grip) ~= 'number' or grip ~= grip or type(physics_setExtraAIGrip) ~= 'function' then return false end
    physics_setExtraAIGrip(carIndex, grip)

    CarManager.cars_grip[carIndex] = grip
end

---Sets the AI grip back to the default value.
---@param carIndex integer
CarOperations.setDefaultAIGrip = function(carIndex)
  CarOperations.setGrip(carIndex, CarManager.GripValues.NORMAL)
end

---Toggles a car's colliders
---@param carIndex integer
---@param collisionsEnabled boolean
CarOperations.toggleCarCollisions = function(carIndex, collisionsEnabled)
  if not canWriteCar(carIndex) or type(collisionsEnabled) ~= 'boolean' or type(physics_disableCarCollisions) ~= 'function' then return false end
  physics_disableCarCollisions(carIndex, not collisionsEnabled, true)
end

---Activates or deactivates gentle stopping.
---@param carIndex integer @0-based car index.
---@param stop boolean? @Default value: `true`.
CarOperations.setGentleStop = function(carIndex, stop)
    if not canWriteCar(carIndex) or type(stop) ~= 'boolean' or type(physics_setGentleStop) ~= 'function' then return false end
    physics_setGentleStop(carIndex, stop)
    CarManager.cars_gentleStop[carIndex] = stop
end

---Returns a boolean value indicating whether the first car is behind the second car.
---@param firstCar ac.StateCar
---@param secondCar ac.StateCar
---@return boolean
function CarOperations.isFirstCarBehindSecondCar(firstCar, secondCar)
  return firstCar.splinePosition < secondCar.splinePosition

    -- local aiCarFwd = aiCar.look or aiCar.forward or vec3(0,0,1)
    -- local rel = MathHelpers.vsub(playerCar.position, aiCar.position)
    -- return MathHelpers.dot(aiCarFwd, rel) < 0
end

-- ---Returns a boolean value indicating whether the first car is currently faster than the second car.
-- ---@param firstCar ac.StateCar
-- ---@param secondCar ac.StateCar
-- ---@param firstCarSpeedLeeway number @The extra speed that's allowed to the second car to still be considered "faster".
-- ---@return boolean
-- function CarOperations.isFirstCarCurrentlyFasterThanSecondCar(firstCar, secondCar, firstCarSpeedLeeway)
  -- return firstCar.speedKmh > secondCar.speedKmh + firstCarSpeedLeeway
-- end

---Returns a boolean value indicating whether the first car is faster than the second car.
---@param firstCarIndex integer
---@param secondCarIndex integer
---@param secondCarSpeedExtra number @The extra speed that's allowed to the second car to still be considered "faster".
---@return boolean
function CarOperations.isFirstCarFasterThanSecondCar(firstCarIndex, secondCarIndex, secondCarSpeedExtra)
  local firstCarSpeedKmh = CarManager.cars_averageSpeedKmh[firstCarIndex]
  local secondCarSpeedKmh = CarManager.cars_averageSpeedKmh[secondCarIndex]
  return firstCarSpeedKmh > secondCarSpeedKmh + secondCarSpeedExtra
end

---Returns a boolean value indicating whether the second car is clearly ahead of the first car.
---@param firstCar ac.StateCar
---@param secondCar ac.StateCar?
---@param meters number
---@return boolean
function CarOperations.isSecondCarClearlyAhead(firstCar, secondCar, meters)
    if not secondCar then
      return false
    end

    local fwd = firstCar.look
    local rel = MathHelpers_vsub(secondCar.position, firstCar.position)
    return MathHelpers_dot(fwd, rel) > meters
end

---Returns a boolean value indicating whether the second car is clearly behind the first car.
---@param firstCar ac.StateCar
---@param secondCar ac.StateCar
---@param meters number
---@return boolean
function CarOperations.isSecondCarClearlyBehindFirstCar(firstCar, secondCar, meters)
    local fwd = firstCar.look
    local rel = MathHelpers_vsub(secondCar.position, firstCar.position)
    return MathHelpers_dot(fwd, rel) < -meters
end

---limits the ramp up speed of the spline offset when the car is driving at high speed
---@param carSpeedKmh number
---@param rampSpeed number
---@return number rampSpeed
function CarOperations.limitSplineOffsetRampUpSpeed(carSpeedKmh, rampSpeed)
  if carSpeedKmh > 300 then
    return rampSpeed * 0.1
  elseif carSpeedKmh > 200 then
    return rampSpeed * 0.25
  elseif carSpeedKmh > 100 then
    return rampSpeed * 0.8
  end
  return rampSpeed
end

---
---@param car ac.StateCar
---@return boolean
function CarOperations.isCarInPits(car)
  return car.isInPit or car.isInPitlane
end

---Applies a bunch of values to stop the car
---@param carIndex integer
function CarOperations.stopCarAfterAccident(carIndex)
    if not canWriteCar(carIndex) then return false end
    -- stop the car
    CarOperations.requestAIThrottleLimit(carIndex, 0, 'INCIDENT_STOP')
    CarOperations.requestAITopSpeed(carIndex, 0, 'INCIDENT_STOP')
    CarOperations.setAIStopCounter(carIndex, 1)
    CarOperations.setGentleStop(carIndex, true)
    CarOperations.setAICaution(carIndex, CarManager.AICautionValues.AFTER_ACCIDENT) -- be very cautious

    CarOperations.preventAIFromRetiring(carIndex)
end

---Prevent an AI from retiring for some time. 
---If not moving, they will still retire some time after this function is called, unless you’ll keep calling it.
---@param carIndex integer @0-based car index.
function CarOperations.preventAIFromRetiring(carIndex)
    if not canWriteCar(carIndex) or type(physics_preventAIFromRetiring) ~= 'function' then return false end
    physics_preventAIFromRetiring(carIndex)
end

---Teleports the car to the specified world position.
---@param carIndex integer
---@param worldPosition vec3
---@param worldDirection vec3|nil
---@param doNotResetCarAfterTeleport boolean @If true, the car will not be reset after teleporting.
CarOperations.teleportCarToWorldPosition = function(carIndex, worldPosition, worldDirection, doNotResetCarAfterTeleport)
    if not canWriteCar(carIndex) or not physics or type(physics.setCarPosition) ~= 'function' then return false end
    physics.setCarPosition(carIndex, worldPosition, worldDirection)

    if doNotResetCarAfterTeleport then
      CarManager.cars_doNoResetAfterNextCarJump[carIndex] = true
    end
end

---@param turningLights ac.TurningLights
function CarOperations.toggleTurningLights(carIndex, turningLights)
    if not canWriteCar(carIndex) or type(ac_setTargetCar) ~= 'function' or type(ac_setTurningLights) ~= 'function' then return false end
    -- local c = ac.getCar(carIndex)
    -- if not c.hasTurningLights then
        -- Logger.warn(string.format("CarOperations.toggleTurningLights: Car %d has no turning lights", carIndex))
        -- return
    -- end

    if ac_setTargetCar(carIndex) then
        ac_setTurningLights(turningLights)
    else
      Logger_warn(string_format("CarOperations.toggleTurningLights: Could not set target car to %d", carIndex))
    end

    -- TODO: we don't need all of these
    -- CarManager.cars_currentTurningLights[carIndex] = turningLights
    -- CarManager.cars_indLeft[carIndex] = car.turningLeftLights
    -- CarManager.cars_indRight[carIndex] = car.turningRightLights
    -- CarManager.cars_indPhase[carIndex] = car.turningLightsActivePhase
    -- CarManager.cars_hasTL[carIndex] = car.hasTurningLights
end

--[======[
---Tries to limit the top speed of the car by adjusting the gas and brake pedals.
---Andreas: I wrote this function because physics.setAITopSpeed doesn't seem to work on ai cars right now
---Andreas: Update: I can't do proper pedal modulation because the api doesn't allow me to set absolute pedal values and always chooses the maximum of my value and the original ai value.
---@param carIndex number
---@param maxSpeedKmh number
CarOperations.limitTopSpeed = function(carIndex, maxSpeedKmh)
    local car = ac.getCar(carIndex)
    if not car then return end

    --[===[
    -- determine the amount of brake we need to apply to keep the car at or below the max speed
    local brakeAmount = math.min(math.max((car.speedKmh - maxSpeedKmh) / 50, 0), 1)

    if car.speedKmh > maxSpeedKmh then
        CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Brake, brakeAmount)
        CarOperations.setPedalPosition(carIndex, CarOperations.CarPedals.Gas, 0)
    else
        CarOperations.resetPedalPosition(carIndex, CarOperations.CarPedals.Brake)
        CarOperations.resetPedalPosition(carIndex, CarOperations.CarPedals.Gas)
    end
    --]===]


    --[===[
    local sim = ac.getSim()
    local dt = sim.dt
    CarSpeedLimiter.limitTopSpeed(carIndex, maxSpeedKmh, dt)
    --]===]
end
--]======]

-- TODO: I'm thinking maybe the side parameter should be removed and we instead feed an absolute driveToSideMaxOffset which is [-1..1] 
-- TODO: and then determining the side from it since the value will be [-1..0]
--- Drives the car to the specified side while making sure there are no cars blocking the side we're trying to drive to.
---@param carIndex number @0-based car index.
---@param dt number @Delta time in seconds.
---@param car ac.StateCar @The ac.StateCar table of the car.
-- ---@param side RaceTrackManager.TrackSide @The side to drive to.
-- ---@param driveToSideMaxOffset number @The maximum lateral offset to drive to on the specified side.
---@param targetLateralOffset number @The maximum lateral offset to drive to on the specified side.
---@param rampSpeed_mps number @The speed at which to ramp up the lateral offset.
---@param overrideAiAwareness boolean @Whether to override AI awareness.
---@param sideCheck boolean @Whether to check if the side is safe to drive to.
---@param useIndicatorLights boolean @Whether to use indicator lights while driving to the side.
---@return boolean
-- function CarOperations.driveSafelyToSide(carIndex, dt, car, side, driveToSideMaxOffset, rampSpeed_mps, overrideAiAwareness, sideCheck)
function CarOperations.driveSafelyToSide(carIndex, dt, car, targetLateralOffset, rampSpeed_mps, overrideAiAwareness, sideCheck, useIndicatorLights)
    if not canWriteCar(carIndex) or type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then return false end
    -- calculate the side we're driving to based on the car's current lateral offset and the target lateral offset
    local carPosition = car.position
    local currentActualTrackLateralOffset = CarManager_getActualTrackLateralOffset(carIndex, carPosition)
    local side = targetLateralOffset < currentActualTrackLateralOffset and RaceTrackManager.TrackSide.LEFT or RaceTrackManager.TrackSide.RIGHT

    -- save a copy of the original side for indicator lights because we may change the side variable later
    local sideForIndicatorLights = side

    -- make sure there isn't any car on the side we're trying to drive to so we don't crash into it
    if sideCheck then
      local isSideSafeToDrive = CarStateMachine.isSafeToDriveToTheSide(carIndex, side)
      local isCarOffTrack = CarManager_isCarOffTrack(car, side)
      local sideNotSafe = not isSideSafeToDrive
      -- if not isSideSafeToDrive then
      if sideNotSafe or isCarOffTrack then
          -- return false since we can't drive to the side safely
          -- return false
          -- drive to the other side to avoid colliding with the car on this side
          side = RaceTrackManager_getOppositeSide(side) -- if the side is not safe, drive to the other side temporarily

          -- do another side check on the other side since we're driving to the other side now
          local isOtherSideSafeToDrive = CarStateMachine.isSafeToDriveToTheSide(carIndex, side)
          if not isOtherSideSafeToDrive then
            -- both sides are blocked, so we can't drive to either side safely
            return false
          end

          -- driveToSideMaxOffset = driveToSideMaxOffset * 0.5 -- drive to the other side but not fully
          -- targetLateralOffset = targetLateralOffset * 0.5 -- drive to the other side but not fully
          targetLateralOffset = -targetLateralOffset * 0.5 -- drive to the other side but not fully
          rampSpeed_mps = rampSpeed_mps * 0.5 -- drive more slowly to the other side
          -- useIndicatorLights = false -- don't use indicator lights when driving to the other side temporarily
      end
    end

      -- todo: should these operations be here?
      -- todo: should these operations be here?
      -- todo: should these operations be here?
      -- todo: should these operations be here?
      -- CarOperations.resetPedalPosition(carIndex, CarOperations.CarPedals.Brake)
      -- CarOperations.resetAIThrottleLimit(carIndex) -- remove any speed limit we may have applied while waiting for a gap
      CarOperations.setGrip(carIndex, CarManager.GripValues.DRIVING_TO_THE_SIDE) -- increase grip while driving to the side

      -- if we are driving at high speed, we need to decrease the ramp speed so that our car doesn't jolt out of control
      -- local splineOffsetTransitionSpeed = CarOperations.limitSplitOffsetRampUpSpeed(car.speedKmh, storage.rampSpeed_mps)
      local splineOffsetTransitionSpeed = CarOperations.limitSplineOffsetRampUpSpeed(car.speedKmh, rampSpeed_mps)

      -- local sideSign = drivingToTheLeft and -1 or 1

      -- TODO: Are you sure we shouldn't be using the actual track lateral offset here?
      local currentSplineOffset = CarManager_getCalculatedTrackLateralOffset(carIndex)
      -- local currentSplineOffset = currentActualTrackLateralOffset -- the problem with this one is that if the increase in offset is too low, the ai can override it and still go the other direction

      -- local targetSplineOffset = storage.maxLateralOffset_normalized * sideSign
      -- TODO: limit the target offset when we are approaching a corner or in mid corner!
      -- TODO: https://github.com/dreasgrech/AssettoCorsaRealisticTrackday/issues/41

      -- local targetSplineOffset = driveToSideMaxOffset * sideSign
      local targetSplineOffset = targetLateralOffset

      local step = splineOffsetTransitionSpeed * dt
      currentSplineOffset = MathHelpers_approach(currentSplineOffset, targetSplineOffset, step)

      -- set the spline offset on the ai car
      -- local overrideAiAwareness = storage.overrideAiAwareness -- TODO: check what this does
      if type(physics_setAISplineOffset) ~= 'function' then return false end
      physics_setAISplineOffset(carIndex, currentSplineOffset, overrideAiAwareness)

      -- keep the turning lights on while driving to the side
      if useIndicatorLights then
        local drivingToTheLeft = sideForIndicatorLights == RaceTrackManager.TrackSide.LEFT
        local turningLights = drivingToTheLeft and ac.TurningLights.Left or ac.TurningLights.Right
        CarOperations.toggleTurningLights(carIndex, turningLights)
      end

      CarManager_setCalculatedTrackLateralOffset(carIndex, currentSplineOffset)
      CarManager.cars_targetSplineOffset[carIndex] = targetSplineOffset

      return true
end

--- Drives the car to the overtaking lane while making sure there are no cars blocking the side.
---@param carIndex integer
---@param dt number
---@param car ac.StateCar
---@param storage StorageTable
---@param useIndicatorLights boolean
---@return boolean
function CarOperations.overtakeSafelyToSide(carIndex, dt, car, storage, useIndicatorLights)
    local driveToSide = RaceTrackManager_getOvertakingSide()
    -- local targetOffset = storage.maxLateralOffset_normalized
    -- local targetOffset = storage.maxLateralOffset_normalized * RaceTrackManager.getLateralOffsetSign(driveToSide)
    local targetOffset = storage.overtakingLateralOffset
    local rampSpeed_mps = storage_Overtaking.overtakeRampSpeed_mps
    local overrideAiAwareness = storage.overrideAiAwareness

    -- return CarOperations.driveSafelyToSide(carIndex, dt, car, driveToSide, targetOffset, rampSpeed_mps, overrideAiAwareness, true)
    local handleSideCheckingWhenOvertaking = storage_Overtaking.handleSideCheckingWhenOvertaking
    return CarOperations.driveSafelyToSide(carIndex, dt, car, targetOffset, rampSpeed_mps, overrideAiAwareness, handleSideCheckingWhenOvertaking, useIndicatorLights)
end

--- Drives the car to the yielding lane while making sure there are no cars blocking the side.
---@param carIndex integer
---@param dt number
---@param car ac.StateCar
---@param storage StorageTable
---@param useIndicatorLights boolean
---@return boolean
function CarOperations.yieldSafelyToSide(carIndex, dt, car, storage, useIndicatorLights)
      local driveToSide = RaceTrackManager_getYieldingSide()
      -- local targetOffset = storage.maxLateralOffset_normalized
      -- local targetOffset = storage.maxLateralOffset_normalized * RaceTrackManager.getLateralOffsetSign(driveToSide)
      local targetOffset = storage.yieldingLateralOffset
      local rampSpeed_mps = storage_Yielding.rampSpeed_mps
      local overrideAiAwareness = storage.overrideAiAwareness

      -- return CarOperations.driveSafelyToSide(carIndex, dt, car, driveToSide, targetOffset, rampSpeed_mps, overrideAiAwareness, true)
      local handleSideCheckingWhenYielding = storage_Yielding.handleSideCheckingWhenYielding
      return CarOperations.driveSafelyToSide(carIndex, dt, car, targetOffset, rampSpeed_mps, overrideAiAwareness, handleSideCheckingWhenYielding, useIndicatorLights)
end

---Calculated the overtaking car's ai caution value while overtaking another car.
---@param overtakingCar ac.StateCar
---@param yieldingCar ac.StateCar?
---@return number aiCaution
---@return number aiAggression 
---@return number aiDifficultyLevel
CarOperations.calculateAICautionAggressionDifficultyWhileOvertaking = function(overtakingCar, yieldingCar)
    local overtakingCarTrackLateralOffset = CarManager_getActualTrackLateralOffset(overtakingCar.index, overtakingCar.position)

    -- by default we use the lowerered ai caution while overtaking so that the cars speed up a bit
    -- local aiCaution = CarManager.AICautionValues.OVERTAKING_WITH_OBSTACLE_INFRONT
    local aiCaution = storage_AICarBehavior.AICaution_OvertakingWithObstacleInFront
    local aiAggression = storage_AICarBehavior.AIAggression_OvertakingWithObstacleInFront
    local aiDifficultyLevel = storage_AICarBehavior.AIDifficultyLevel_OvertakingWithObstacleInFront

    -- Check if it's safe in front of us to drop the caution to 0 so that we can really step on it
    if yieldingCar then
        -- if the car in front of us is not in front of us, we can drop the caution to 0 to speed up overtaking
        local yieldingCarTrackLateralOffset = CarManager_getActualTrackLateralOffset(yieldingCar.index, yieldingCar.position)
        local lateralOffsetsDelta = math_abs(overtakingCarTrackLateralOffset - yieldingCarTrackLateralOffset)
        if lateralOffsetsDelta > 0.4 then -- if the lateral offset is more than half a lane apart, we can consider it safe
            -- aiCaution = CarManager.AICautionValues.OVERTAKING_WITH_NO_OBSTACLE_INFRONT
            aiCaution = storage_AICarBehavior.AICaution_OvertakingWithNoObstacleInFront
            aiAggression = storage_AICarBehavior.AIAggression_OvertakingWithNoObstacleInFront
            aiDifficultyLevel = storage_AICarBehavior.AIDifficultyLevel_OvertakingWithNoObstacleInFront
        end
    end

    -- If an upcoming corner is coming , increase the caution a bit so that we don't go flying off the track
    local overtakingCarIndex = overtakingCar.index
    local isMidCorner, distanceToUpcomingTurn = CarManager_isCarMidCorner(overtakingCarIndex)
    if isMidCorner or distanceToUpcomingTurn < DISTANCE_TO_UPCOMING_CORNER_TO_INCREASE_AICAUTION then
        aiCaution = storage_AICarBehavior.AICaution_OvertakingWhileInCorner
        aiAggression = storage_AICarBehavior.AIAggression_WhileInCorner
        aiDifficultyLevel = storage_AICarBehavior.AIDifficultyLevel_WhileInCorner
    end

    return aiCaution, aiAggression, aiDifficultyLevel
end

-- Returns the six lateral anchor points plus some helpers
---@param outTable table|nil Reusable output table (optional; falls back to module scratch table)
---@return table
-- local getSideAnchorPoints = function(carPosition, carForward, carLeft, carUp, halfAABBSize)
CarOperations.getSideAnchorPoints = function(carPosition, carForward, carLeft, carUp, halfAABBSize, outTable)
  -- local carForward, carLeft, carUp = car.look, car.side, car.up  -- all normalized

  outTable = outTable or CarOperations._reusableSideAnchorTable
  table_clear(outTable)

  -- Half-extents from AABB (x=width, y=height, z=length)
  local carHalfWidth = halfAABBSize.x
  local carHalfHeight = halfAABBSize.y
  local carHalfLength = halfAABBSize.z

  -- Reused scratch vec3s (no allocation per call)
  local carCenterWorldPosition   = CarOperations._reusableVec3_center
  local frontLeftWorldPosition   = CarOperations._reusableVec3_frontLeft
  local centerLeftWorldPosition  = CarOperations._reusableVec3_centerLeft
  local rearLeftWorldPosition    = CarOperations._reusableVec3_rearLeft
  local frontRightWorldPosition  = CarOperations._reusableVec3_frontRight
  local centerRightWorldPosition = CarOperations._reusableVec3_centerRight
  local rearRightWorldPosition   = CarOperations._reusableVec3_rearRight
  local carRight                 = CarOperations._reusableVec3_right

  carRight:set(-carLeft.x, -carLeft.y, -carLeft.z)

  -- Center at mid-height
  local centerX = carPosition.x + carUp.x * carHalfHeight
  local centerY = carPosition.y + carUp.y * carHalfHeight
  local centerZ = carPosition.z + carUp.z * carHalfHeight
  carCenterWorldPosition:set(centerX, centerY, centerZ)

  -- Half-length and half-width direction components
  local forwardX = carForward.x * carHalfLength
  local forwardY = carForward.y * carHalfLength
  local forwardZ = carForward.z * carHalfLength
  local leftX = carLeft.x * carHalfWidth
  local leftY = carLeft.y * carHalfWidth
  local leftZ = carLeft.z * carHalfWidth
  local rightX = -leftX
  local rightY = -leftY
  local rightZ = -leftZ

  frontLeftWorldPosition:set(
    centerX + forwardX + leftX,
    centerY + forwardY + leftY,
    centerZ + forwardZ + leftZ)
  centerLeftWorldPosition:set(
    centerX + leftX,
    centerY + leftY,
    centerZ + leftZ)
  rearLeftWorldPosition:set(
    centerX - forwardX + leftX,
    centerY - forwardY + leftY,
    centerZ - forwardZ + leftZ)

  frontRightWorldPosition:set(
    centerX + forwardX + rightX,
    centerY + forwardY + rightY,
    centerZ + forwardZ + rightZ)
  centerRightWorldPosition:set(
    centerX + rightX,
    centerY + rightY,
    centerZ + rightZ)
  rearRightWorldPosition:set(
    centerX - forwardX + rightX,
    centerY - forwardY + rightY,
    centerZ - forwardZ + rightZ)

  outTable.frontLeft = frontLeftWorldPosition
  outTable.centerLeft = centerLeftWorldPosition
  outTable.rearLeft = rearLeftWorldPosition
  outTable.frontRight = frontRightWorldPosition
  outTable.centerRight = centerRightWorldPosition
  outTable.rearRight = rearRightWorldPosition
  outTable.center = carCenterWorldPosition
  outTable.forwardDirection = carForward
  outTable.leftDirection = carLeft
  outTable.rightDirection = carRight
  outTable.upDirection = carUp
  return outTable
end

local checkForOtherCars = function(carIndex, worldPosition, direction, distance)
  --  Maybe using physics.raycastTrack(...) could be faster
  --  Andreas: it seems like physics.raycastTrack does not hit cars, only the track
  -- local raycastHitDistance = physics.raycastTrack(worldPosition, direction, distance) 
  local carRay = render_createRay(worldPosition,  direction, distance)
  --[===[]
  local raycastHitDistance = carRay:cars(BACKFACE_CULLING_FOR_BLOCKING)
  local rayHit = not (raycastHitDistance == -1)
  return rayHit, raycastHitDistance
  --]===]

  -- TODO: Optimize this because we certainly do not need to check all cars every time
  -- TODO: Optimize this because we certainly do not need to check all cars every time
  -- TODO: Optimize this because we certainly do not need to check all cars every time
  local sortedCarsList = CarManager.currentSortedCarsList
  for i = 1, #sortedCarsList do
    local car = sortedCarsList[i]
    local otherCarIndex = car.index
    if otherCarIndex ~= carIndex then
      local raycastHitDistance = carRay:carCollider(otherCarIndex)
      local rayHit = not (raycastHitDistance == -1)
      if rayHit then
        return rayHit, raycastHitDistance
      end
    end
  end
end

--[=====[
---comment
---@param carIndex any
---@return boolean
---@return CarOperations.CarDirections
---@return number
CarOperations.isTargetSideBlocked = function(carIndex)
  local car = ac.getCar(carIndex)
  if not car then return false, CarOperations.CarDirections.None, 0 end

  -- local storage = StorageManager.getStorage()

  -- local carAnchorPoints = CarOperations.getSideAnchorPoints(carIndex,car)
  local carAnchorPoints = CarManager.cars_anchorPoints[carIndex]
  if not carAnchorPoints then
    Logger.log(string.format("CarOperations.isTargetSideBlocked: Car %d has no anchor points calculated", carIndex))
    return false, CarOperations.CarDirections.None, 0
  end
  -- CarOperations.logCarAnchorPoints(carIndex, carAnchorPoints)

  -- TODO: we can probably reduce the number of rays and do a sort of criss cross on the side instead of the rays shooting directly straight

  -- TODO: another idea could be sphere casting if the api provides it instead of many line rays

  local hitCar, hitDistance = checkForOtherCars(carAnchorPoints.frontLeft, carAnchorPoints.leftDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.FrontLeft, hitDistance
  end

  local hitCar, hitDistance = checkForOtherCars(carAnchorPoints.centerLeft, carAnchorPoints.leftDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.CenterLeft, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.rearLeft, carAnchorPoints.leftDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.RearLeft, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.frontRight, carAnchorPoints.rightDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.FrontRight, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.centerRight, carAnchorPoints.rightDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.CenterRight, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.rearRight, carAnchorPoints.rightDirection, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.RearRight, hitDistance
  end

  -- Angled left rays (front: 45° toward forward, rear: 45° toward BACK)
  local leftAngledDirFront = carAnchorPoints.leftDirection * INV_SQRT2 + carAnchorPoints.forwardDirection * INV_SQRT2
  local leftAngledDirRear  = carAnchorPoints.leftDirection * INV_SQRT2 - carAnchorPoints.forwardDirection * INV_SQRT2

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.frontLeft, leftAngledDirFront, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.FrontLeftAngled, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.rearLeft, leftAngledDirRear, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.RearLeftAngled, hitDistance
  end

  -- Angled right rays (front: 45° toward forward, rear: 45° toward BACK)
  local rightAngledDirFront = carAnchorPoints.rightDirection * INV_SQRT2 + carAnchorPoints.forwardDirection * INV_SQRT2
  local rightAngledDirRear  = carAnchorPoints.rightDirection * INV_SQRT2 - carAnchorPoints.forwardDirection * INV_SQRT2

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.frontRight, rightAngledDirFront, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.FrontRightAngled, hitDistance
  end

  hitCar, hitDistance = checkForOtherCars(carAnchorPoints.rearRight, rightAngledDirRear, SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING)
  if hitCar then
    return true, CarOperations.CarDirections.RearRightAngled, hitDistance
  end

  return false, CarOperations.CarDirections.None, 0
end
--]=====]

---comment
---@param carIndex any
---@param sideToCheck RaceTrackManager.TrackSide
---@return boolean
---@return integer
---@return integer
CarOperations.checkIfCarIsBlockedByAnotherCarAndSaveSideBlockRays = function(carIndex, sideToCheck)
    local car = ac_getCar(carIndex)
    if not car then return false, CarOperations.CarDirections.None, -1 end

    -- local carIndex = car.index
    local carPosition = car.position
    local carForward  = car.look
    local carLeftDirection     = car.side
    local carUp       = car.up
    local halfAABBSize = CarManager.cars_HALF_AABSIZE[carIndex]
    if not halfAABBSize.z then
      Logger_error(string_format("CarOperations.checkIfCarIsBlockedByAnotherCarAndSaveSideBlockRays_NEWDoDAPPROACH: Car %d has no halfAABBSize.z calculated", carIndex))
    end

    -- TODO: remove use of CarOperations.getSideAnchorPoints here and only calculate what we need
    local p = CarOperations.getSideAnchorPoints(carPosition, carForward, carLeftDirection, carUp, halfAABBSize, CarOperations._reusableSideAnchorTable)  -- returns left/right dirs too
    -- local pLeftDirection = p.leftDirection
    -- local pRightDirection = p.rightDirection
    local sideGap = 1

    --[====[
    CarManager.cars_totalSideBlockRaysData[carIndex] = 2

    local pLeftDirection = carLeftDirection
    local pRearLeft  = p.rearLeft
    local leftOffset  = pLeftDirection  * sideGap
    local ray1_pos  = pRearLeft + leftOffset
    local ray1_dir  = carForward
    local ray1_len  = (halfAABBSize.z * 2)-- + 6
    -- todo: cache array here instead of calling carmanager.cars_sideBlockRaysData[carIndex] multiple times
    CarManager.cars_sideBlockRaysData[carIndex][0] = ray1_pos
    CarManager.cars_sideBlockRaysData[carIndex][1] = ray1_dir
    CarManager.cars_sideBlockRaysData[carIndex][2] = ray1_len

    local pRightDirection = -carLeftDirection
    local pRearRight = p.rearRight
    local rightOffset = pRightDirection * sideGap
    local ray2_pos  = pRearRight + rightOffset
    local ray2_dir  = carForward
    local ray2_len  = (halfAABBSize.z * 2)-- + 3
    CarManager.cars_sideBlockRaysData[carIndex][3] = ray2_pos
    CarManager.cars_sideBlockRaysData[carIndex][4] = ray2_dir
    CarManager.cars_sideBlockRaysData[carIndex][5] = ray2_len


    local rightHitCar, rightHitCarDistance = checkForOtherCars(ray2_pos, ray2_dir, ray2_len)
    if rightHitCar then
      -- TODO: can we be more specific with the direction here?
      return true, CarOperations.CarDirections.CenterRight, rightHitCarDistance
    end

    local leftHitCar, leftHitCarDistance = checkForOtherCars(ray1_pos, ray1_dir, ray1_len)
    if leftHitCar then
      -- TODO: can we be more specific with the direction here?
      return true, CarOperations.CarDirections.CenterLeft, leftHitCarDistance
    end
    --]====]

    ---------------------------------
    CarManager.cars_totalSideBlockRaysData[carIndex] = 1
    local pDirection, pRearPosition, hitDirection
    if sideToCheck == RaceTrackManager.TrackSide.LEFT then
      pDirection = carLeftDirection
      pRearPosition = p.rearLeft
      hitDirection = CarOperations.CarDirections.CenterLeft
    else
      pDirection = -carLeftDirection
      pRearPosition = p.rearRight
      hitDirection = CarOperations.CarDirections.CenterRight
    end
      
    local offset = pDirection * sideGap

    local ray_pos = (pRearPosition + offset) + (-carForward * (halfAABBSize.z))
    local ray_dir = carForward
    -- local ray_len = (halfAABBSize.z * 2)
    local ray_len = (halfAABBSize.z * 4)
    local hitCar, hitCarDistance = checkForOtherCars(carIndex, ray_pos, ray_dir, ray_len)

    CarManager.cars_sideBlockRaysData[carIndex][0] = ray_pos
    CarManager.cars_sideBlockRaysData[carIndex][1] = ray_dir
    CarManager.cars_sideBlockRaysData[carIndex][2] = ray_len
    CarManager.cars_sideBlockRaysData[carIndex][3] = hitCar

    return hitCar, hitDirection, hitCarDistance
    -- if hitCar then
      -- return true, hitDirection, hitCarDistance
    -- end
    ---------------------------------

    -- return false, CarOperations.CarDirections.None, 0
  end

--[=====[
---comment
---@param carIndex number
---@return boolean
---@return CarOperations.CarDirections|integer
---@return number|nil
CarOperations.checkIfCarIsBlockedByAnotherCarAndSaveAnchorPoints = function(carIndex)
    local car = ac.getCar(carIndex)
    if not car then return false, CarOperations.CarDirections.None, -1 end

    local carPosition = car.position
    local carForward = car.look
    local carLeft = car.side
    local carUp = car.up
    local halfAABBSize = CarManager.cars_HALF_AABSIZE[carIndex]

    local carAnchorPoints = CarOperations.getSideAnchorPoints(carPosition, carForward, carLeft, carUp, halfAABBSize, CarOperations._reusableSideAnchorTable)
    CarManager.cars_anchorPoints[carIndex] = carAnchorPoints

    local isCarOnSide, carOnSideDirection, carOnSideDistance = CarOperations.isTargetSideBlocked(carIndex)
    return isCarOnSide, carOnSideDirection, carOnSideDistance
end
--]=====]

---comment
---@param carDirection CarOperations.CarDirections
CarOperations.getTrackSideFromCarDirection = function(carDirection)
  if carDirection == CarOperations.CarDirections.FrontLeft
  or carDirection == CarOperations.CarDirections.CenterLeft
  or carDirection == CarOperations.CarDirections.RearLeft
  or carDirection == CarOperations.CarDirections.FrontLeftAngled
  or carDirection == CarOperations.CarDirections.RearLeftAngled then
    return RaceTrackManager.TrackSide.LEFT
  elseif carDirection == CarOperations.CarDirections.FrontRight
  or carDirection == CarOperations.CarDirections.CenterRight
  or carDirection == CarOperations.CarDirections.RearRight
  or carDirection == CarOperations.CarDirections.FrontRightAngled
  or carDirection == CarOperations.CarDirections.RearRightAngled then
    return RaceTrackManager.TrackSide.RIGHT
  end

  return nil
end

--- Calculates the maximum top speed of the car by checking all gears.
--- Andreas: This is a bit pointless because family cars were returning higher speeds than gt3 cars with this
---@param carIndex integer
---@return number
CarOperations.calculateMaxTopSpeed = function(carIndex)
  local car = ac_getCar(carIndex)
  if not car then return 0 end

  -- todo: could you just use highest gear available instead of checking all gears?
  local maxSpeed = 0
  local gearCount = car.gearCount
  for gearIndex = 1, gearCount do
    maxSpeed = math_max(maxSpeed, ac_getCarMaxSpeedWithGear(carIndex, gearIndex))
  end
  return maxSpeed
end

return CarOperations
