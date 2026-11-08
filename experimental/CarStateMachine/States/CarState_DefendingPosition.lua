-- bindings
local ac = ac
local string = string
local string_format = string.format
local math = math
local Logger = Logger
local Logger_error = Logger.error
local CarManager = CarManager
local CarOperations = CarOperations
local CarOperations_driveSafelyToSide = CarOperations.driveSafelyToSide
local CarStateMachine = CarStateMachine
local CarStateMachine_setStateExitReason = CarStateMachine.setStateExitReason
local MathHelpers = MathHelpers
local MathHelpers_distanceBetweenVec3sSqr = MathHelpers.distanceBetweenVec3sSqr
local StorageManager = StorageManager
local Strings = Strings


local STATE = CarStateMachine.CarStateType.DEFENDING_POSITION

CarStateMachine.CarStateTypeStrings[STATE] = "DefendingPosition"
CarStateMachine.states_minimumTimeInState[STATE] = 0

---@type Strings.StateExitReason
local StateExitReason = Strings.StringNames[Strings.StringCategories.StateExitReason]

local storage_Behavior = StorageManager.getStorage_Behavior()

-- How long (in seconds) the car will defend a position, keeping its racing line while being pressured from behind before it starts yielding
-- lazily initialized on first use inside the entry function
---@type table<integer,number>
local cars_defenseRemainingTime_s

-- Distance (meters) within which the car behind is still considered to be pressuring us
local PRESSURE_DISTANCE_m = 30
-- Minimum relative closing speed (km/h) for the car behind to be considered still pressuring us
local PRESSURE_RELATIVE_SPEED_kmh = 5
-- High ramp speed so the car keeps to its racing line as much as possible while defending
local RACING_LINE_RAMP_SPEED_mps = 1000

-- ENTRY FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_entryFunctions[STATE] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  -- lazily initialize the shared defense timers table
  cars_defenseRemainingTime_s = cars_defenseRemainingTime_s or {}

  local defenseDurationMin_s = storage_Behavior.defenseDurationMin_s or 1.0
  local defenseDurationMax_s = storage_Behavior.defenseDurationMax_s or 3.0

  -- pick a random defense duration within the configured range
  local defenseDuration_s = defenseDurationMin_s + math.random() * (defenseDurationMax_s - defenseDurationMin_s)
  cars_defenseRemainingTime_s[carIndex] = defenseDuration_s

  -- NOTE: there is no dedicated StateExitReason for this state and Strings_StateExitReason.lua is out of scope,
  -- so we reuse YieldingToCar as the closest existing reason.
  CarStateMachine_setStateExitReason(carIndex, StateExitReason.YieldingToCar)
end

-- UPDATE FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_updateFunctions[STATE] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  cars_defenseRemainingTime_s = cars_defenseRemainingTime_s or {}
  -- count down the remaining defense time
  cars_defenseRemainingTime_s[carIndex] = (cars_defenseRemainingTime_s[carIndex] or 0) - dt

  -- keep the car on its racing line while it defends the position
  local car = sortedCarsList[sortedCarsListIndex]
  local targetOffset = storage.defaultLateralOffset
  CarOperations_driveSafelyToSide(carIndex, dt, car, targetOffset, RACING_LINE_RAMP_SPEED_mps, true, false, false)
end

-- TRANSITION FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_transitionFunctions[STATE] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  local car = sortedCarsList[sortedCarsListIndex]

  -- if the defense timer has run out, we now yield to the car behind
  local defenseRemainingTime_s = cars_defenseRemainingTime_s and cars_defenseRemainingTime_s[carIndex] or 0
  if defenseRemainingTime_s <= 0 then
    CarStateMachine_setStateExitReason(carIndex, StateExitReason.YieldingToCar)
    return CarStateMachine.CarStateType.EASING_IN_YIELD
  end

  -- if the car behind is no longer pressuring us, we can go back to driving normally
  local carBehind = sortedCarsList[sortedCarsListIndex + 1]
  local isCarBehindStillPressing = false
  if carBehind then
    local carBehindIndex = carBehind.index
    local distanceToCarBehindSqr = MathHelpers_distanceBetweenVec3sSqr(carBehind.position, car.position)
    local pressureDistanceSqr = PRESSURE_DISTANCE_m * PRESSURE_DISTANCE_m

    local ourSpeedKmh = CarManager.cars_averageSpeedKmh[carIndex] or 0
    local carBehindSpeedKmh = CarManager.cars_averageSpeedKmh[carBehindIndex] or 0
    local relativeSpeedKmh = carBehindSpeedKmh - ourSpeedKmh

    isCarBehindStillPressing = distanceToCarBehindSqr <= pressureDistanceSqr
      and relativeSpeedKmh >= PRESSURE_RELATIVE_SPEED_kmh
  end

  if not isCarBehindStillPressing then
    CarStateMachine_setStateExitReason(carIndex, StateExitReason.YieldingToCar)
    return CarStateMachine.CarStateType.DRIVING_NORMALLY
  end
end

-- EXIT FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_exitFunctions[STATE] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  if cars_defenseRemainingTime_s then
    cars_defenseRemainingTime_s[carIndex] = nil
  end
end
