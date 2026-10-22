--[====[
---@ext:verbose
--]====]
local CarStateMachine = {}

-- bindings
-- local ac = ac
local table = table
local table_clear = table.clear

-- local LOG_CAR_STATEMACHINE_IN_CSP_LOG = true
local LOG_CAR_STATEMACHINE_IN_CSP_LOG = false

---@type table<CarStateMachine.CarStateType,string>
CarStateMachine.CarStateTypeStrings = {}
---@type table<integer,number>
CarStateMachine.states_minimumTimeInState = { }

---@type table<integer,CarStateMachine.CarStateType>
local cars_state = {}

---@type table<integer,CarStateMachine.CarStateType>
CarStateMachine.cars_previousState = {}

---@enum CarStateMachine.CarStateType
CarStateMachine.CarStateType = {
  DRIVING_NORMALLY = 1, -- normal driving state, driving on the racing line
  EASING_IN_YIELD = 4, 
  STAYING_ON_YIELDING_LANE = 8,
  EASING_OUT_YIELD = 32,
  WAITING_AFTER_ACCIDENT = 64,
  COLLIDED_WITH_TRACK = 128,
  COLLIDED_WITH_CAR = 256,
  ANOTHER_CAR_COLLIDED_INTO_ME = 512,
  EASING_IN_OVERTAKE = 1024,
  STAYING_ON_OVERTAKING_LANE = 2048,
  EASING_OUT_OVERTAKE = 4096,
  NAVIGATING_AROUND_ACCIDENT = 8192,
  DRIVING_IN_YELLOW_FLAG_ZONE = 16384,
  AFTER_CUSTOMAIFLOOD_TELEPORT = 32768,
  DEFENDING_POSITION = 65536, -- holds the racing line while being pressured from behind before yielding
}

--[====[
CarStateMachine.CarStateType = const({
  DRIVING_NORMALLY = 1,
  EASING_IN_YIELD = 4, 
  STAYING_ON_YIELDING_LANE = 8,
  EASING_OUT_YIELD = 32,
  WAITING_AFTER_ACCIDENT = 64,
  COLLIDED_WITH_TRACK = 128,
  COLLIDED_WITH_CAR = 256,
  ANOTHER_CAR_COLLIDED_INTO_ME = 512,
  EASING_IN_OVERTAKE = 1024,
  STAYING_ON_OVERTAKING_LANE = 2048,
  EASING_OUT_OVERTAKE = 4096,
  NAVIGATING_AROUND_ACCIDENT = 8192,
  DRIVING_IN_YELLOW_FLAG_ZONE = 16384,
})

--]====]

local StateExitReason = Strings.StringNames[Strings.StringCategories.StateExitReason]

local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Overtaking = StorageManager.getStorage_Overtaking()
local storage = StorageManager.getStorage()

---Changes the state of the car to the new state
---@param carIndex integer
---@param newState CarStateMachine.CarStateType
local changeState = function(carIndex, newState)
    -- save a reference to the current state before changing it
    local currentState = CarStateMachine.getCurrentState(carIndex)
    local isFirstState = currentState == nil -- is this the first state we're setting for this car?
    -- if not isFirstState and currentState == newState then
        -- Logger.warn(string.format("Car %d: Tried to change to the same state: %s", carIndex, CarStateMachine.CarStateTypeStrings[newState]))
        -- return
    -- end

    if isFirstState then
      currentState = newState
    end

    CarStateMachine.cars_previousState[carIndex] = currentState

    -- reset the time in state counter
    CarManager.cars_timeInCurrentState[carIndex] = 0

    -- Logger.log(string.format("Car %d: Changing state (%d) from %s to %s", carIndex, currentState))

    -- change to the new state
    cars_state[carIndex] = newState
end

---Returns the current state of the car
---@param carIndex integer
---@return CarStateMachine.CarStateType
CarStateMachine.getCurrentState = function(carIndex)
    return cars_state[carIndex]
end

---Returns the previous state of the car
---@param carIndex integer
---@return CarStateMachine.CarStateType
CarStateMachine.getPreviousState = function(carIndex)
    return CarStateMachine.cars_previousState[carIndex]
end

---@type Strings.ReasonWhyCantYield
local ReasonWhyCantYieldStringNames = Strings.StringNames[Strings.StringCategories.ReasonWhyCantYield]
---@type Strings.ReasonWhyCantOvertake
local ReasonWhyCantOvertakeStringNames = Strings.StringNames[Strings.StringCategories.ReasonWhyCantOvertake]

--- TODO: This function should probably be moved to CarOperations
---@param carIndex number
---@param drivingToSide RaceTrackManager.TrackSide|integer
---@return boolean
-- local isSafeToDriveToTheSide = function(carIndex, drivingToSide)
CarStateMachine.isSafeToDriveToTheSide = function(carIndex, drivingToSide)
  -- check if there's a car on our side
    local isCarOnSide, carOnSideDirection, carOnSideDistance = CarOperations.checkIfCarIsBlockedByAnotherCarAndSaveSideBlockRays(carIndex, drivingToSide)
    if isCarOnSide then
        -- if the car on our side is on the same side as the side we're trying to yield to, then we cannot yield
        local trackSideOfBlockingCar = CarOperations.getTrackSideFromCarDirection(carOnSideDirection)
        local isSideCarOnTheSameSideAsYielding = drivingToSide == trackSideOfBlockingCar
        
        if isSideCarOnTheSameSideAsYielding then
          -- Logger.log(string.format("Car %d: Car on side detected: %s  distance=%.2f m", carIndex, CarOperations.CarDirectionsStrings[carOnSideDirection], carOnSideDistance or -1))
          -- TODO: get this setReasonWhyCantYield out of here!
          CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.TargetSideBlocked)
          return false
        end
    end

    --[====[
    -- Check car blind spot
    -- Andreas: I've never seen this code working yet...
    local distanceToNearestCarInBlindSpot_L, distanceToNearestCarInBlindSpot_R = ac.getCarBlindSpot(carIndex)
    local isSideBlocked_L = (not (distanceToNearestCarInBlindSpot_L == nil))-- and distanceToNearestCarInBlindSpot_L > 0
    local isSideBlocked_R = (not (distanceToNearestCarInBlindSpot_R == nil))-- and distanceToNearestCarInBlindSpot_R > 0

    if (isSideBlocked_L or isSideBlocked_R) then
        Logger.log(string.format("Car %d: Blindspot L=%.2f  R=%.2f", carIndex, distanceToNearestCarInBlindSpot_L or -1, distanceToNearestCarInBlindSpot_R or -1))
        -- TODO: get this setReasonWhyCantYield out of here!
        CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.CarInBlindSpot)
        return false
    end
    --]====]

    return true
end

---@type table<CarStateMachine.CarStateType,function>
CarStateMachine.states_entryFunctions = {}
---@type table<CarStateMachine.CarStateType,function>
CarStateMachine.states_updateFunctions = {}
---@type table<CarStateMachine.CarStateType,function>
CarStateMachine.states_transitionFunctions = {}
---@type table<CarStateMachine.CarStateType,function>
CarStateMachine.states_exitFunctions = {}

local queuedCollidedWithTrackAccidents = QueueManager.createQueue()
local queuedCollidedWithCarAccidents = QueueManager.createQueue()
local queuedCarCollidedWithMeAccidents = QueueManager.createQueue()
local queuedCulpritGenerations = QueueManager.createQueue()
local queuedVictimGenerations = QueueManager.createQueue()
local queuedCulpritVictimGenerations = QueueManager.createQueue()
local queuedVictimCulpritGenerations = QueueManager.createQueue()
local queuedCulpritSessions = QueueManager.createQueue()
local queuedVictimSessions = QueueManager.createQueue()
local queuedCulpritAccidentIndexes = QueueManager.createQueue()
local queuedVictimAccidentIndexes = QueueManager.createQueue()

-- Logger.log("[CarStateMachine] Initialized 3 queues: "..queuedCollidedWithTrackAccidents..", "..queuedCollidedWithCarAccidents..", "..queuedCarCollidedWithMeAccidents)

-- a dictionary which holds, if available, the state to transition to next in the upcoming frame
---@type table<integer,CarStateMachine.CarStateType>
local queuedStatesToTransitionInto = {}
local queuedStateGenerations = {}
local cars_defenseRemainingTime_s = {}
local FLOOD_STATE_REQUIRED_APIS = { 'setCarFuel', 'engageGear', 'setEngineRPM', 'setAIStopCounter',
  'setGentleStop', 'setAICaution', 'awakeCar', 'setAINoInput' }

CarStateMachine.setReasonWhyCantYield = function(carIndex, reason)
  StringsManager.setString(carIndex, Strings.StringCategories.ReasonWhyCantYield, reason)
end

--- Sets the reason why the car can't overtake
---@param carIndex integer
-- ---@param reason Strings.ReasonWhyCantOvertake
CarStateMachine.setReasonWhyCantOvertake = function(carIndex, reason)
  StringsManager.setString(carIndex, Strings.StringCategories.ReasonWhyCantOvertake, reason)
end

CarStateMachine.setStateExitReason = function(carIndex, reason)
  StringsManager.setString(carIndex, Strings.StringCategories.StateExitReason, reason)
end

CarStateMachine.initializeCarInStateMachine = function(carIndex)
    -- Logger.log(string.format("CarStateMachine: initializeCarInStateMachine() car %d in state machine, setting initial state to DRIVING_NORMALLY", carIndex))

    -- clear the car's states history since this is could be a recycled car
    CarStateMachine.cars_previousState[carIndex] = nil
    cars_state[carIndex] = nil
    CarManager.cars_timeInCurrentState[carIndex] = 0
    queuedStatesToTransitionInto[carIndex] = nil
    queuedStateGenerations[carIndex] = nil
    if cars_defenseRemainingTime_s then cars_defenseRemainingTime_s[carIndex] = nil end

    -- queue up the DRIVING_NORMALLY state for the car so that it will take effect in the next frame
    CarStateMachine.queueStateTransition(carIndex, CarStateMachine.CarStateType.DRIVING_NORMALLY)
    -- Logger.log(string.format("CarStateMachine: Car %d Just added normally state: %d", carIndex, queuedStatesToTransitionInto[carIndex]))
    --CarStateMachine.changeState(carIndex, CarStateMachine.CarStateType.DRIVING_NORMALLY)
end

CarStateMachine.queueStateTransition = function(carIndex, newState)
    queuedStatesToTransitionInto[carIndex] = newState
    queuedStateGenerations[carIndex] = CarManager.getCarGeneration(carIndex)
end

function CarStateMachine.clearPendingLifecycle()
  for index in pairs(queuedStatesToTransitionInto) do
    queuedStatesToTransitionInto[index], queuedStateGenerations[index] = nil, nil
  end
  while QueueManager.queueLength(queuedCollidedWithTrackAccidents) > 0 do QueueManager.dequeue(queuedCollidedWithTrackAccidents) end
  while QueueManager.queueLength(queuedCollidedWithCarAccidents) > 0 do QueueManager.dequeue(queuedCollidedWithCarAccidents) end
  while QueueManager.queueLength(queuedCarCollidedWithMeAccidents) > 0 do QueueManager.dequeue(queuedCarCollidedWithMeAccidents) end
  while QueueManager.queueLength(queuedCulpritGenerations) > 0 do QueueManager.dequeue(queuedCulpritGenerations) end
  while QueueManager.queueLength(queuedVictimGenerations) > 0 do QueueManager.dequeue(queuedVictimGenerations) end
  while QueueManager.queueLength(queuedCulpritVictimGenerations) > 0 do QueueManager.dequeue(queuedCulpritVictimGenerations) end
  while QueueManager.queueLength(queuedVictimCulpritGenerations) > 0 do QueueManager.dequeue(queuedVictimCulpritGenerations) end
  while QueueManager.queueLength(queuedCulpritSessions) > 0 do QueueManager.dequeue(queuedCulpritSessions) end
  while QueueManager.queueLength(queuedVictimSessions) > 0 do QueueManager.dequeue(queuedVictimSessions) end
  while QueueManager.queueLength(queuedCulpritAccidentIndexes) > 0 do QueueManager.dequeue(queuedCulpritAccidentIndexes) end
  while QueueManager.queueLength(queuedVictimAccidentIndexes) > 0 do QueueManager.dequeue(queuedVictimAccidentIndexes) end
end

function CarStateMachine.invalidateReferencesToCar(targetCarIndex)
  local invalidatedOwners = {}
  local function invalidateOwner(ownerIndex)
    if ownerIndex == targetCarIndex or invalidatedOwners[ownerIndex] then return end
    invalidatedOwners[ownerIndex] = true
    CarManager.cars_currentlyOvertakingCarIndex[ownerIndex] = nil
    CarManager.cars_currentlyYieldingCarToIndex[ownerIndex] = nil
    CarManager.cars_navigatingAroundCarIndex[ownerIndex] = nil
    CarManager.cars_navigatingAroundAccidentIndex[ownerIndex] = nil
    CarManager.bumpCarGeneration(ownerIndex)
    CarStateMachine.initializeCarInStateMachine(ownerIndex)
  end
  for ownerIndex, targetIndex in pairs(CarManager.cars_currentlyOvertakingCarIndex) do
    if ownerIndex ~= targetCarIndex and targetIndex == targetCarIndex then
      invalidateOwner(ownerIndex)
    end
  end
  for ownerIndex, targetIndex in pairs(CarManager.cars_currentlyYieldingCarToIndex) do
    if ownerIndex ~= targetCarIndex and targetIndex == targetCarIndex then
      invalidateOwner(ownerIndex)
    end
  end
  for ownerIndex, targetIndex in pairs(CarManager.cars_navigatingAroundCarIndex) do
    if ownerIndex ~= targetCarIndex and targetIndex == targetCarIndex then
      invalidateOwner(ownerIndex)
    end
  end
end

CarStateMachine.handleQueuedAccidents = function()
    -- while QueueManager.queueLength(queuedCollidedWithTrackAccidents) > 0 do
        -- local carIndex = QueueManager.dequeue(queuedCollidedWithTrackAccidents)
        
        -- Logger.log(string.format("CarStateMachine: Car %d collided with track, switching to COLLIDED_WITH_TRACK state", carIndex))
        -- CarStateMachine.changeState(carIndex, CarStateMachine.CarStateType.COLLIDED_WITH_TRACK)
    -- end

    while QueueManager.queueLength(queuedCollidedWithCarAccidents) > 0 do
        local accidentCarIndex = QueueManager.dequeue(queuedCollidedWithCarAccidents)
        local generation = QueueManager.dequeue(queuedCulpritGenerations)
        local victimGeneration = QueueManager.dequeue(queuedCulpritVictimGenerations)
        local sessionGeneration = QueueManager.dequeue(queuedCulpritSessions)
        local accidentIndex = QueueManager.dequeue(queuedCulpritAccidentIndexes)
        if sessionGeneration == CarManager.sessionGeneration
          and generation == CarManager.getCarGeneration(accidentCarIndex)
          and victimGeneration == CarManager.getCarGeneration(AccidentManager.accidents_collidedWithCarIndex[accidentIndex])
          and AccidentManager.accidents_resolved[accidentIndex] == false
          and AccidentManager.accidents_carIndex[accidentIndex] == accidentCarIndex
          and CarManager.isWritableAICar(accidentCarIndex) then
        Logger.log(string.format("CarStateMachine: #%d collided with another car, switching to COLLIDED_WITH_CAR state", accidentCarIndex))
        CarStateMachine.queueStateTransition(accidentCarIndex, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
        end
    end

    while QueueManager.queueLength(queuedCarCollidedWithMeAccidents) > 0 do
        local accidentCarIndex = QueueManager.dequeue(queuedCarCollidedWithMeAccidents)
        local generation = QueueManager.dequeue(queuedVictimGenerations)
        local culpritGeneration = QueueManager.dequeue(queuedVictimCulpritGenerations)
        local sessionGeneration = QueueManager.dequeue(queuedVictimSessions)
        local accidentIndex = QueueManager.dequeue(queuedVictimAccidentIndexes)
        if sessionGeneration == CarManager.sessionGeneration
          and generation == CarManager.getCarGeneration(accidentCarIndex)
          and culpritGeneration == CarManager.getCarGeneration(AccidentManager.accidents_carIndex[accidentIndex])
          and AccidentManager.accidents_resolved[accidentIndex] == false
          and AccidentManager.accidents_collidedWithCarIndex[accidentIndex] == accidentCarIndex
          and CarManager.isWritableAICar(accidentCarIndex) then

        Logger.log(string.format("CarStateMachine: #%d was collided into by another car, switching to ANOTHER_CAR_COLLIDED_INTO_ME state", accidentCarIndex))
        -- Logger.log(string.format("%d %d ", carIndex, QueueManager.queueLength(queuedCarCollidedWithMeAccidents)))
        -- Logger.log(string.format("%d", carIndex))
        CarStateMachine.queueStateTransition(accidentCarIndex, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
        end
    end
end

---comment
---@param carIndex integer
---@param dt number
---@param sortedCarList table<integer,ac.StateCar>
---@param sortedCarListIndex integer #1-based index of the car in sortedCarList
-- ---@param storage StorageTable
CarStateMachine.updateCar = function(carIndex, dt, sortedCarList, sortedCarListIndex)
    if type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge
      or not CarManager.isWritableAICar(carIndex) then return false end
    local carGeneration = CarManager.getCarGeneration(carIndex)
    local pendingState = queuedStatesToTransitionInto[carIndex]
    if pendingState and queuedStateGenerations[carIndex] ~= carGeneration then
      queuedStatesToTransitionInto[carIndex], queuedStateGenerations[carIndex] = nil, nil
      pendingState = nil
    end
    local currentState = CarStateMachine.getCurrentState(carIndex)
    local stateToExecute = pendingState or currentState or CarStateMachine.CarStateType.DRIVING_NORMALLY
    if stateToExecute == CarStateMachine.CarStateType.AFTER_CUSTOMAIFLOOD_TELEPORT then
      for i = 1, #FLOOD_STATE_REQUIRED_APIS do
        if not physics or type(physics[FLOOD_STATE_REQUIRED_APIS[i]]) ~= 'function' then return false end
      end
    end
    -- CarManager.cars_anchorPoints[carIndex] = nil -- clear the anchor points each frame, they will be recalculated if needed
    CarManager.cars_totalSideBlockRaysData[carIndex] = 0
    table_clear(CarManager.cars_sideBlockRaysData[carIndex])

    -- check if there's a new state we need to transition into
    local newStateToTransitionIntoThisFrame = pendingState
    if not newStateToTransitionIntoThisFrame and currentState == nil then
      newStateToTransitionIntoThisFrame = CarStateMachine.CarStateType.DRIVING_NORMALLY
    end
    -- local shouldTransitionIntoNewState = not (newStateToTransitionIntoThisFrame == nil)
    local shouldTransitionIntoNewState = newStateToTransitionIntoThisFrame --and newStateToTransitionIntoThisFrame > 0
    -- Logger.log(string.format("CarStateMachine: Car %d Checking queued: %d, shouldTransition: %s", carIndex, queuedStatesToTransitionInto[carIndex], tostring(shouldTransitionIntoNewState)))
    
    -- If there's a state we need to transition into, do it now
    if shouldTransitionIntoNewState then
      -- Logger.log(string.format("CarStateMachine: Transitioning car %d into new state: %s", carIndex, CarStateMachine.CarStateTypeStrings[newStateToTransitionIntoThisFrame]))
      -- clear the queued transition since we're now taking care of it
      queuedStatesToTransitionInto[carIndex] = nil
      queuedStateGenerations[carIndex] = nil

      -- change to the new state
      changeState(carIndex, newStateToTransitionIntoThisFrame)

      -- execute the state's entry function
      --[====[
      if not CarStateMachine.states_entryFunctions[newStateToTransitionIntoThisFrame] then
        Logger.error(string.format("CarStateMachine: #%d state %d has no entry function!", carIndex, newStateToTransitionIntoThisFrame))
        return
      end
      --]====]
      CarStateMachine.states_entryFunctions[newStateToTransitionIntoThisFrame](carIndex, dt, sortedCarList, sortedCarListIndex, storage)
    end

    local state = CarStateMachine.getCurrentState(carIndex)

    if state == nil then
      Logger.error(string.format("CarStateMachine: #%d stat is nil!", carIndex))
      return
    end

    -- run the state loop
    -- Logger.log(string.format("CarStateMachine: Car %d updateFunction of state %s: ", carIndex, CarStateMachine.CarStateTypeStrings[state]) .. tostring(CarStateMachine.states_updateFunctions[carIndex]))


    --[====[
    if not CarStateMachine.states_updateFunctions[state] then
      Logger.error(string.format("CarStateMachine: #%d state %d has no update function!", carIndex, state))
      return
    end
    --]====]
    CarStateMachine.states_updateFunctions[state](carIndex, dt, sortedCarList, sortedCarListIndex, storage)

    local currentTimeInState = CarManager.cars_timeInCurrentState[carIndex]

    -- increase the time spent in this state
    CarManager.cars_timeInCurrentState[carIndex] = currentTimeInState + dt

    -- make sure we have spent the minimum required time in this state before we can transition out of it
    local minimumTimeInState = CarStateMachine.states_minimumTimeInState[state]
    if currentTimeInState < minimumTimeInState then
      -- we haven't spent enough time in this state yet, so we cannot transition out of it
      return
    end

    -- check if we need to transition out of the state by executing the state's transition check function
    local newState = CarStateMachine.states_transitionFunctions[state](carIndex, dt, sortedCarList, sortedCarListIndex, storage)
    local shouldTransitionToNextState = newState
    if shouldTransitionToNextState then
      -- execute the state's exit function
      CarStateMachine.states_exitFunctions[state](carIndex, dt, sortedCarList, sortedCarListIndex, storage)

      CarStateMachine.queueStateTransition(carIndex, newState)
    end
end

CarStateMachine.informAboutAccident = function(accidentIndex)
  -- Logger.log(string.format("CarStateMachine: informAboutAccident accidentIndex=%d", accidentIndex))
    local collidedWithTrack = AccidentManager.accidents_collidedWithTrack[accidentIndex]
    local carIndex = AccidentManager.accidents_carIndex[accidentIndex]
    local collidedWithCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]

    if collidedWithTrack then
        QueueManager.enqueue(queuedCollidedWithTrackAccidents, carIndex)
    else
        -- if the car collided with another car, we need to inform both cars
        -- Logger.log(string.format("Enqueueing accident: car %d collided with car %d", carIndex, collidedWithCarIndex))
        QueueManager.enqueue(queuedCollidedWithCarAccidents, carIndex)
        QueueManager.enqueue(queuedCulpritGenerations, CarManager.getCarGeneration(carIndex))
        QueueManager.enqueue(queuedCulpritVictimGenerations, CarManager.getCarGeneration(collidedWithCarIndex))
        QueueManager.enqueue(queuedCulpritSessions, CarManager.sessionGeneration)
        QueueManager.enqueue(queuedCulpritAccidentIndexes, accidentIndex)
        QueueManager.enqueue(queuedCarCollidedWithMeAccidents, collidedWithCarIndex)
        QueueManager.enqueue(queuedVictimGenerations, CarManager.getCarGeneration(collidedWithCarIndex))
        QueueManager.enqueue(queuedVictimCulpritGenerations, CarManager.getCarGeneration(carIndex))
        QueueManager.enqueue(queuedVictimSessions, CarManager.sessionGeneration)
        QueueManager.enqueue(queuedVictimAccidentIndexes, accidentIndex)
    end
end

-- CarStateMachine.handleShouldWeStartNavigatingAroundAccident = function(carIndex, car)
CarStateMachine.handleYellowFlagZone = function(carIndex, car)
  -- return false
    local handleAccidents = storage.handleAccidents
    if not handleAccidents then
      return nil
    end

    local carSplinePosition = car.splinePosition
    local isInYellowFlagZone = RaceTrackManager.isSplinePositionInYellowZone(carSplinePosition)
    if isInYellowFlagZone then
      return CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE
    end

    --[====[
    -- todo: currently have a hardcoded value here!!!
    local isCarComingUpToAccidentIndex, accidentClosestCarIndex = AccidentManager.isCarComingUpToAccident(car, 100)
    if isCarComingUpToAccidentIndex then
      -- Logger.log(string.format("CarStateMachine: Car %d coming up to accident, switching to NAVIGATING_AROUND_ACCIDENT state", carIndex))
      AccidentManager.setCarNavigatingAroundAccident(carIndex, isCarComingUpToAccidentIndex, accidentClosestCarIndex)
      return CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT
    end
    --]====]
end

---Returns the STAYING_ON_YIELDING_LANE state if we can overtake the car in front of us while we're currently overtaking another car
---@param carIndex integer
---@param car ac.StateCar
---@param carFront ac.StateCar
---@param carBehind ac.StateCar
---@param currentlyOvertakingCarIndex integer
---@return CarStateMachine.CarStateType|nil
CarStateMachine.handleOvertakeNextCarWhileAlreadyOvertaking = function(carIndex, car, carFront, carBehind, currentlyOvertakingCarIndex)
    if not carFront then
      return
    end

    -- If there's a car in front of us, check if we can overtake it as well
    local carFrontIndex = carFront.index
    local isCarInFrontSameAsWeAreOvertaking = carFrontIndex == currentlyOvertakingCarIndex
    if not isCarInFrontSameAsWeAreOvertaking then
        local newStateDueToCarInFront = CarStateMachine.handleShouldWeOvertakeFrontCar(carIndex, car, carFront, carBehind)
        if newStateDueToCarInFront then
            CarStateMachine.setStateExitReason(carIndex, StateExitReason.ContinuingOvertakingNextCar)
            CarManager.cars_currentlyOvertakingCarIndex[carIndex] = carFrontIndex -- start overtaking the new car in front of us
            return CarStateMachine.CarStateType.STAYING_ON_OVERTAKING_LANE
        end
    end
end

---Returns the EASING_IN_OVERTAKE state if the car passes all the checks required to start overtaking a car behind it
---@param carIndex integer
---@param car ac.StateCar
---@param carBehind ac.StateCar
---@param carFront ac.StateCar
---@return CarStateMachine.CarStateType|nil
CarStateMachine.handleShouldWeOvertakeFrontCar = function(carIndex, car, carFront, carBehind)
  local handleOvertaking = storage_Overtaking.handleOvertaking
  if not handleOvertaking then
    return
  end

  -- if there's no car in front of us, do nothing
  if not carFront then
    return
  end

  local carFrontIndex = carFront.index

  if CarOperations.isCarInPits(carFront) then
    -- CarManager.cars_reasonWhyCantOvertake[carIndex] = 'Car in front is in pits so not overtaking'
    CarStateMachine.setReasonWhyCantOvertake(carIndex, ReasonWhyCantOvertakeStringNames.YieldingCarInPits)
    return
  end

  -- If we're not close to the front car, do nothing
  local carPosition = car.position
  local carFrontPosition = carFront.position
  -- local distanceToFrontCar = MathHelpers.vlen(MathHelpers.vsub(carFrontPosition, carPosition))
  -- if distanceToFrontCar > storage.distanceToFrontCarToOvertake then
  local detectCarAhead_meters = storage_Overtaking.detectCarAhead_meters 
  local detectCarAhead_metersSqr = detectCarAhead_meters * detectCarAhead_meters
  -- local distanceToFrontCar = MathHelpers.distanceBetweenVec3s(carFrontPosition, carPosition)
  local distanceToFrontCarSqr = MathHelpers.distanceBetweenVec3sSqr(carFrontPosition, carPosition)
  -- if distanceToFrontCar > storage.detectCarAhead_meters then
  if distanceToFrontCarSqr > detectCarAhead_metersSqr then
    -- CarManager.cars_reasonWhyCantOvertake[carIndex] = 'Too far from front car to consider overtaking: ' .. string.format('%.2f', distanceToFrontCar) .. 'm'
    CarStateMachine.setReasonWhyCantOvertake(carIndex, ReasonWhyCantOvertakeStringNames.YieldingCarTooFarAhead)
    return
  end

  -- If we're not faster than the car in front, do nothing
  local ourSpeedKmh = CarManager.cars_averageSpeedKmh[carIndex]
  local frontCarSpeedKmh = CarManager.cars_averageSpeedKmh[carFrontIndex]
  -- local areWeFasterThenTheCarInFront = CarOperations.isFirstCarCurrentlyFasterThanSecondCar(car, carFront, 5)
  local areWeFasterThenTheCarInFront = ourSpeedKmh > frontCarSpeedKmh
  if not areWeFasterThenTheCarInFront then
    -- CarManager.cars_reasonWhyCantOvertake[carIndex] = 'Car in front is faster so not overtaking'
    CarStateMachine.setReasonWhyCantOvertake(carIndex, ReasonWhyCantOvertakeStringNames.YieldingCarIsFaster)
    return
  end

  -- check if the car in front of us is on the yielding lane
  local requireYieldingCarToBeOnYieldingLane = storage_Overtaking.requireYieldingCarToBeOnYieldingLane
  if requireYieldingCarToBeOnYieldingLane then
    local carFrontDrivingOnYieldingLane = CarManager.isCarDrivingOnSide(carFrontIndex, RaceTrackManager.getYieldingSide())
    if not carFrontDrivingOnYieldingLane then
      -- CarManager.cars_reasonWhyCantOvertake[carIndex] = 'Car in front not on yielding lane so not overtaking'
      CarStateMachine.setReasonWhyCantOvertake(carIndex, ReasonWhyCantOvertakeStringNames.YieldingCarIsNotOnYieldingSide)
      return
    end
  end

  -- consider the car behind us
  if carBehind then
  -- if there's a car behind us, make sure it's not too close before we start overtaking
    -- local distanceFromCarBehindToUs = MathHelpers.vlen(MathHelpers.vsub(carBehind.position, carPosition))
    -- local distanceFromCarBehindToUs = MathHelpers.distanceBetweenVec3s(carBehind.position, carPosition)
    local distanceFromCarBehindToUsSqr = MathHelpers.distanceBetweenVec3sSqr(carBehind.position, carPosition)
    -- if distanceFromCarBehindToUs < 5.0 then
    if distanceFromCarBehindToUsSqr < 5*5 then
      -- CarManager.cars_reasonWhyCantOvertake[carIndex] = 'Car behind too close so not overtaking'
      CarStateMachine.setReasonWhyCantOvertake(carIndex, ReasonWhyCantOvertakeStringNames.AnotherCarBehindTooClose)
      return
    end
  end

  -- start driving to the side to initiate an overtake
  -- save a reference to the car we're overtaking because the next state needs it
  CarManager.cars_currentlyOvertakingCarIndex[carIndex] = carFrontIndex
  return CarStateMachine.CarStateType.EASING_IN_OVERTAKE
end

---@param car ac.StateCar
---@param carBehind ac.StateCar
---@return CarStateMachine.CarStateType|nil
local handleShouldWeYieldToBehindCar_singleCar = function(car, carBehind)
    local carIndex = car.index

    if CarOperations.isCarInPits(carBehind) then
      CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.OvertakingCarInPits)
      return
    end

    local carBehindIndex = carBehind.index

    -- If this car is not close to the overtaking car, do nothing
    local carPosition = car.position
    local carBehindPosition = carBehind.position
    local detectCarBehind_meters = storage_Yielding.detectCarBehind_meters
    local detectCarBehind_metersSqr = detectCarBehind_meters * detectCarBehind_meters
    -- local distanceFromOvertakingCarToYieldingCar = MathHelpers.distanceBetweenVec3s(carBehindPosition, carPosition)
    local distanceFromOvertakingCarToYieldingCarSqr = MathHelpers.distanceBetweenVec3sSqr(carBehindPosition, carPosition)
    --TODO: here we should use the full detection radius if the carBehind is directly behind us,
    --TODO: but if the car behind is in in between other cars behind us, then use a small radius since we can't see the car coming that much because there are other cars in the way
    -- local radius = storage.detectCarBehind_meters
    -- local isYieldingCarCloseToOvertakingCar = distanceFromOvertakingCarToYieldingCar <= radius
    local isYieldingCarCloseToOvertakingCar = distanceFromOvertakingCarToYieldingCarSqr <= detectCarBehind_metersSqr
    if not isYieldingCarCloseToOvertakingCar then
      CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.OvertakingCarTooFarBehind)
      return
    end

    -- Check if the overtaking car is behind the yielding car
    local isOvertakingCarBehindYieldingCar = CarOperations.isFirstCarBehindSecondCar(carBehind, car)
    if not isOvertakingCarBehindYieldingCar then
      CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.OvertakingCarNotBehind)
      return
    end

    -- local yieldingCarSpeedKmh = car.speedKmh
    -- local overtakingCarSpeedKmh = carBehind.speedKmh
    local yieldingCarSpeedKmh = CarManager.cars_averageSpeedKmh[carIndex]
    local overtakingCarSpeedKmh = CarManager.cars_averageSpeedKmh[carBehindIndex]

    -- Check if we're faster than the overtaking car
    -- TODO: HERE ALSO CHECK THE CLOSING SPEED AND IF THE CLOSING SPEED IS HIGH >5, THEN STILL YIELD EVEN IF THE AVERAGE SPEED IS LOWER
    -- TODO: HERE ALSO CHECK THE CLOSING SPEED AND IF THE CLOSING SPEED IS HIGH >5, THEN STILL YIELD EVEN IF THE AVERAGE SPEED IS LOWER
    -- TODO: HERE ALSO CHECK THE CLOSING SPEED AND IF THE CLOSING SPEED IS HIGH >5, THEN STILL YIELD EVEN IF THE AVERAGE SPEED IS LOWER
    -- TODO: HERE ALSO CHECK THE CLOSING SPEED AND IF THE CLOSING SPEED IS HIGH >5, THEN STILL YIELD EVEN IF THE AVERAGE SPEED IS LOWER
    local isYieldingCarSlowerThanOvertakingCar = yieldingCarSpeedKmh < overtakingCarSpeedKmh
    if not isYieldingCarSlowerThanOvertakingCar then
      CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.WeAreFasterThanOvertakingCar)
      return
    end

    -- check if the car overtaking car is actually driving on the overtaking lane
    local requireOvertakingCarToBeOnOvertakingLane = storage_Yielding.requireOvertakingCarToBeOnOvertakingLane
    if requireOvertakingCarToBeOnOvertakingLane then
      local overtakingSide = RaceTrackManager.getOvertakingSide()
      local isOvertakingCarOnOvertakingLane = CarManager.isCarDrivingOnSide(carBehindIndex, overtakingSide)
      if not isOvertakingCarOnOvertakingLane then
        CarStateMachine.setReasonWhyCantYield(carIndex, ReasonWhyCantYieldStringNames.OvertakingCarNotOnOvertakingSide)
        return
      end
    end

    -- TODO: also check if our car is a lot more powerful than the overtaking car, think twice before yielding

    -- CarManager.cars_reasonWhyCantYield[carIndex] = nil


    -- Logger.log(string.format("[%s] #%d yielding to #%d. OvertakingSide: %s, CarBehindPosition: %s, CarBehindLateralOffset: %.3f",
    -- ac.getSim().timestamp, 
    -- carIndex, 
    -- carBehindIndex,
    -- RaceTrackManager.TrackSideStrings[overtakingSide], 
    -- tostring(carBehindPosition),
    -- CarManager.getActualTrackLateralOffset(carBehindPosition)))

    -- Since all the checks have passed, the yielding car can now start to yield
    CarManager.cars_currentlyYieldingCarToIndex[carIndex] = carBehindIndex
    return CarStateMachine.CarStateType.EASING_IN_YIELD
end

-- ---Returns the EASING_IN_YIELD state if the car passes all the checks required to start yielding to a car behind it
-- ---@param carIndex integer
-- ---@param car ac.StateCar
-- ---@param carBehind ac.StateCar
-- ---@param carFront ac.StateCar
-- ---@param storage StorageTable
-- ---@return CarStateMachine.CarStateType|nil
-- CarStateMachine.handleShouldWeYieldToBehindCar = function(carIndex, car, carBehind, carFront, storage)

---Returns the EASING_IN_YIELD state if the car passes all the checks required to start yielding to a car behind it
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer #1-based index of the car in sortedCarList
---@return CarStateMachine.CarStateType|nil
CarStateMachine.handleShouldWeYieldToBehindCar = function(sortedCarsList, sortedCarsListIndex)
  local handleYielding = storage_Yielding.handleYielding
  if not handleYielding then
    return
  end

    local car = sortedCarsList[sortedCarsListIndex]

    --Check all the cars behind us within our detection radius to see if we need to yield to any of them
    local detectedCarBehind_meters = storage_Yielding.detectCarBehind_meters
    local detectedCarBehind_metersSqr = detectedCarBehind_meters * detectedCarBehind_meters
    -- for loop through all the cars behind us within our detection radius
    local totalCarsBehindUs = #sortedCarsList - sortedCarsListIndex
    for i = 1, totalCarsBehindUs do
      local carBehind = sortedCarsList[sortedCarsListIndex + i]
      -- todo: there must be a better way of checking the distance between the cars
      -- local distanceFromCarBehindToUs = MathHelpers.distanceBetweenVec3s(carBehind.position, car.position)
      -- local isCarBehindWithinRadius = distanceFromCarBehindToUs <= detectedCarBehind_meters
      local distanceFromCarBehindToUsSqr = MathHelpers.distanceBetweenVec3sSqr(carBehind.position, car.position)
      local isCarBehindWithinRadius = distanceFromCarBehindToUsSqr <= detectedCarBehind_metersSqr
      if isCarBehindWithinRadius then
        local stateDueToYield = handleShouldWeYieldToBehindCar_singleCar(car, carBehind)
        if stateDueToYield then
          return stateDueToYield
        end
      else 
        -- if the car is outside our detection radius, we can stop checking further cars behind us
        break
      end
    end

    -- old way (checking only the car directly behind us):
    -- local carBehind = sortedCarsList[sortedCarsListIndex + 1]
    -- return handleShouldWeYieldToBehindCar_singleCar(car, carBehind, storage)
end


--[============[ DEFENDING_POSITION state ]============]
-- While defending, the car keeps following its racing line (the default lateral offset)
-- and only starts yielding once the defense timer runs out, even under pressure from behind.
local DEFENDING_POSITION = CarStateMachine.CarStateType.DEFENDING_POSITION

CarStateMachine.CarStateTypeStrings[DEFENDING_POSITION] = "DefendingPosition"
CarStateMachine.states_minimumTimeInState[DEFENDING_POSITION] = 0

-- How long (in seconds) the car will defend a position, keeping its racing line while being pressured from behind before it starts yielding
-- lazily initialized on first use inside the entry function
---@type table<integer,number>

-- Distance (meters) within which the car behind is still considered to be pressuring us
local DEFENDING_POSITION_PRESSURE_DISTANCE_m = 30
-- Minimum relative closing speed (km/h) for the car behind to be considered still pressuring us
local DEFENDING_POSITION_PRESSURE_RELATIVE_SPEED_kmh = 5

-- ENTRY FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_entryFunctions[DEFENDING_POSITION] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  -- lazily initialize the shared defense timers table
  cars_defenseRemainingTime_s = cars_defenseRemainingTime_s or {}

  local storage_Behavior = StorageManager.getStorage_Behavior()
  local defenseDurationMin_s = storage_Behavior.defenseDurationMin_s or 1.0
  local defenseDurationMax_s = storage_Behavior.defenseDurationMax_s or 3.0

  -- pick a random defense duration within the configured range
  local defenseDuration_s = defenseDurationMin_s + math.random() * (defenseDurationMax_s - defenseDurationMin_s)
  cars_defenseRemainingTime_s[carIndex] = defenseDuration_s

  -- NOTE: there is no dedicated StateExitReason for this state and Strings_StateExitReason.lua is out of scope,
  -- so we reuse YieldingToCar as the closest existing reason.
  CarStateMachine.setStateExitReason(carIndex, StateExitReason.YieldingToCar)
end

-- UPDATE FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_updateFunctions[DEFENDING_POSITION] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  cars_defenseRemainingTime_s = cars_defenseRemainingTime_s or {}
  cars_defenseRemainingTime_s[carIndex] = (cars_defenseRemainingTime_s[carIndex] or 0) - dt

  -- keep the car on its racing line while it defends the position
  local car = sortedCarsList[sortedCarsListIndex]
  local targetOffset = storage.defaultLateralOffset
  CarOperations.driveSafelyToSide(carIndex, dt, car, targetOffset, 1000, true, false, false)
end

-- TRANSITION FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_transitionFunctions[DEFENDING_POSITION] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  local car = sortedCarsList[sortedCarsListIndex]

  -- if the defense timer has run out, we now yield to the car behind
  local defenseRemainingTime_s = cars_defenseRemainingTime_s and cars_defenseRemainingTime_s[carIndex] or 0
  if defenseRemainingTime_s <= 0 then
    CarStateMachine.setStateExitReason(carIndex, StateExitReason.YieldingToCar)
    return CarStateMachine.CarStateType.EASING_IN_YIELD
  end

  -- if the car behind is no longer pressuring us, we can go back to driving normally
  local carBehind = sortedCarsList[sortedCarsListIndex + 1]
  local isCarBehindStillPressing = false
  if carBehind then
    local carBehindIndex = carBehind.index
    local distanceToCarBehindSqr = MathHelpers.distanceBetweenVec3sSqr(carBehind.position, car.position)
    local pressureDistanceSqr = DEFENDING_POSITION_PRESSURE_DISTANCE_m * DEFENDING_POSITION_PRESSURE_DISTANCE_m

    local ourSpeedKmh = CarManager.cars_averageSpeedKmh[carIndex] or 0
    local carBehindSpeedKmh = CarManager.cars_averageSpeedKmh[carBehindIndex] or 0
    local relativeSpeedKmh = carBehindSpeedKmh - ourSpeedKmh

    isCarBehindStillPressing = distanceToCarBehindSqr <= pressureDistanceSqr
      and relativeSpeedKmh >= DEFENDING_POSITION_PRESSURE_RELATIVE_SPEED_kmh
  end

  if not isCarBehindStillPressing then
    CarStateMachine.setStateExitReason(carIndex, StateExitReason.YieldingToCar)
    return CarStateMachine.CarStateType.DRIVING_NORMALLY
  end
end

-- EXIT FUNCTION
---@param carIndex integer
---@param dt number
---@param sortedCarsList table<integer,ac.StateCar>
---@param sortedCarsListIndex integer
---@param storage StorageTable
CarStateMachine.states_exitFunctions[DEFENDING_POSITION] = function (carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)
  if cars_defenseRemainingTime_s then
    cars_defenseRemainingTime_s[carIndex] = nil
  end
end
--]============[ DEFENDING_POSITION state ]============]


return CarStateMachine
