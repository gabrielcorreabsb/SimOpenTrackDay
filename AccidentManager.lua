local AccidentManager = {}

-- local lastAccidentIndexCreated = 0
-- local firstNonResolvedAccidentIndex = 1

local accidentCompletableIndex = CompletableIndexCollectionManager.createNewIndex()
local accidentCulpritGeneration = {}
local accidentVictimGeneration = {}
local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@type table<integer,integer>
AccidentManager.accidents_carIndex = {}
---@type table<integer,vec3>
AccidentManager.accidents_worldPosition = {}
AccidentManager.accidents_victimWorldPosition = {}
AccidentManager.accidents_victimSplinePosition = {}
---@type table<integer,number>
AccidentManager.accidents_splinePosition = {}
---@type table<integer,boolean>
AccidentManager.accidents_collidedWithTrack = {}
---@type table<integer,integer>
AccidentManager.accidents_collidedWithCarIndex = {}
---@type table<integer,integer>
AccidentManager.accidents_yellowFlagZoneIndex = {}
---@type table<integer,boolean>
AccidentManager.accidents_resolved = {}

---@type table<integer,integer>
AccidentManager.cars_culpritInAccidentIndex = {}

---@type table<integer,integer>
AccidentManager.cars_victimInAccidentIndex = {}

---Marks the given accident as resolved and done
---@param accidentIndex integer
local setAccidentAsResolved = function(accidentIndex)
        local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
        local victimCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
        AccidentManager.accidents_carIndex[accidentIndex] = nil
        AccidentManager.accidents_worldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimWorldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimSplinePosition[accidentIndex] = nil
        AccidentManager.accidents_splinePosition[accidentIndex] = nil
        AccidentManager.accidents_collidedWithTrack[accidentIndex] = nil
        AccidentManager.accidents_collidedWithCarIndex[accidentIndex] = nil

        -- remove the yellow flag zone associated with this accident
        local yellowFlagZoneIndex = AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex]
        RaceTrackManager.removeYellowFlagZone(yellowFlagZoneIndex)
        AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex] = nil

        if culpritCarIndex ~= nil and AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex] == accidentIndex then
            AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex] = nil
        end
        if victimCarIndex ~= nil and AccidentManager.cars_victimInAccidentIndex[victimCarIndex] == accidentIndex then
            AccidentManager.cars_victimInAccidentIndex[victimCarIndex] = nil
        end
        accidentCulpritGeneration[accidentIndex] = nil
        accidentVictimGeneration[accidentIndex] = nil

        --[==[
        AccidentManager.accidents_resolved[accidentIndex] = true
        -- check the existing accidents and update the first non-resolved accident index so that loops iterating over accidents can start from there
        for i = firstNonResolvedAccidentIndex, lastAccidentIndexCreated do
            -- if not AccidentManager.accidents_resolved[i] then
            if AccidentManager.accidents_resolved[i] == false then
                Logger.log(string.format("AccidentManager: Updating firstNonResolvedAccidentIndex from %d to %d (last accident index: %d)", firstNonResolvedAccidentIndex, i, lastAccidentIndexCreated))
                firstNonResolvedAccidentIndex = i
                break
            end
        end
        --]==]

        AccidentManager.accidents_resolved[accidentIndex] = true
        CompletableIndexCollectionManager.updateFirstNonResolvedIndex(accidentCompletableIndex, AccidentManager.accidents_resolved)
end

---Returns a boolean value indicating whether the accident has been resolved
---@param carIndex integer @0-based car index
---@return boolean @true if the accident is resolved
AccidentManager.isAccidentResolved = function(carIndex)
    return AccidentManager.accidents_resolved[carIndex]
end

---Resolve any accident the given car is a culprit in
---@param carIndex number
AccidentManager.informAboutCarReset = function(carIndex)
    local accidentIndexAsCulprit = AccidentManager.cars_culpritInAccidentIndex[carIndex]
    -- Logger.log(string.format("[AccidentManager] informAboutCarReset called for car #%d. culpritInAccident #%d.  Total accidents: %d", carIndex, accidentIndexAsCulprit, #AccidentManager.accidents_carIndex))
    if accidentIndexAsCulprit and accidentIndexAsCulprit > 0 then
        -- Logger.log(string.format("AccidentManager: Car #%d has reset, clearing it from accident #%d", carIndex, accidentIndexAsCulprit))
        Logger.log(string.format("[AccidentManager] Car #%d has reset, clearing accident #%d", carIndex, accidentIndexAsCulprit))

        setAccidentAsResolved(accidentIndexAsCulprit)
    end
    local victimAccident = AccidentManager.cars_victimInAccidentIndex[carIndex]
    if victimAccident and victimAccident > 0 and victimAccident ~= accidentIndexAsCulprit then
        setAccidentAsResolved(victimAccident)
    end
end

---Registers a collision accident for the given culprit car index
---@param culpritCarIndex integer
---@param collisionLocalPosition vec3 @position of the collision in local car space
---@param collidedWith integer @0 = track, 1+ = car collider index
---@return integer? accidentIndex
-- AccidentManager.registerCollision = function(culpritCarIndex)
AccidentManager.registerCollision = function(culpritCarIndex, collisionLocalPosition, collidedWith, eventStamp)

    -- TODO: need to handle what happens when a player car is the culprit car
    -- TODO: need to handle what happens when a player car is the culprit car
    -- TODO: need to handle what happens when a player car is the culprit car
    -- TODO: need to handle what happens when a player car is the culprit car


    if type(culpritCarIndex) ~= 'number' or culpritCarIndex ~= culpritCarIndex or culpritCarIndex < 1 or culpritCarIndex % 1 ~= 0 then
        -- Logger.log("AccidentManager.registerCollision called with culpritCarIndex 0 local player, ignoring")
        return
    end

    local culpritCar = ac.getCar(culpritCarIndex)
    if not culpritCar or culpritCar.index ~= culpritCarIndex or not CarManager.isWritableAICar(culpritCarIndex) then return end
    if type(collidedWith) ~= 'number' or collidedWith ~= collidedWith or collidedWith < 0 or collidedWith % 1 ~= 0 then return end

    -- if the culprit car is already a culprit in another accident, ignore this collision
    local culpritCarAsCulpritInAnotherAccidentIndex = AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex]
    if culpritCarAsCulpritInAnotherAccidentIndex and culpritCarAsCulpritInAnotherAccidentIndex > 0 then
        -- Logger.log(string.format("#%d is already a culprit in accident #%d, ignoring new collision", culpritCarIndex, CarManager.cars_culpritInAccident[culpritCarIndex]))
        return
    end

    -- Ignore the accident if the culprit car is already navigating around an accident
    -- Andreas: The physics.disableCarCollisions doesn't seem to always work for cars in AI flood as of the current csp so 
    -- Andreas: here I'm ignoring new collisions for cars that are already navigating around an accident to prevent a pile up
    local culpritCarState = CarStateMachine.getCurrentState(culpritCarIndex)
    if culpritCarState == CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT then
        Logger.log(string.format("#%d is already navigating around an accident, ignoring new collision", culpritCarIndex))
        return
    end

    -- car.collisionDepth
    -- local collisionLocalPosition = culpritCar.collisionPosition
    -- local collidedWith = culpritCar.collidedWith
    local collidedWithTrack = collidedWith == 0

    -- CURRENTLY IGNORING TRACK COLLISIONS WHILE WORKING ON CAR-TO-CAR COLLISIONS
    -- CURRENTLY IGNORING TRACK COLLISIONS WHILE WORKING ON CAR-TO-CAR COLLISIONS
    -- CURRENTLY IGNORING TRACK COLLISIONS WHILE WORKING ON CAR-TO-CAR COLLISIONS
    -- CURRENTLY IGNORING TRACK COLLISIONS WHILE WORKING ON CAR-TO-CAR COLLISIONS
    if collidedWithTrack then
        --Logger.warn(string.format("#%d collided with the track but ignoring track collisions for now", culpritCarIndex))
        return
    end

    -- we need to subtract 1 from the index to get the actual car index since colliderWidth 0 is track
    collidedWith = collidedWith - 1
    local victimCar = not collidedWithTrack and ac.getCar(collidedWith) or nil
    if not collidedWithTrack and (not victimCar or victimCar.index ~= collidedWith) then return end
    if eventStamp then
        if not isFiniteNumber(eventStamp.positionX) or not isFiniteNumber(eventStamp.positionY)
          or not isFiniteNumber(eventStamp.positionZ) or not isFiniteNumber(eventStamp.splinePosition) then return end
        if not collidedWithTrack and (not isFiniteNumber(eventStamp.victimPositionX)
          or not isFiniteNumber(eventStamp.victimPositionY) or not isFiniteNumber(eventStamp.victimPositionZ)
          or not isFiniteNumber(eventStamp.victimSplinePosition)) then return end
    end

    -- ac.areCarsColliding
    -- physics.setCarBodyDamage(carIndex, bodyDamage)

    local collidedWithAnotherCar = not collidedWithTrack
    if collidedWithAnotherCar then
        -- if the victim car the culprit car collided with is already in an accident with the culprit car, ignore this collision
        local victimCarCulpritInAnotherAccidentIndex = AccidentManager.cars_culpritInAccidentIndex[collidedWith]
        if victimCarCulpritInAnotherAccidentIndex and victimCarCulpritInAnotherAccidentIndex > 0 then
            local victimCulpritAccidentCollidedWithCarIndex = AccidentManager.accidents_collidedWithCarIndex[victimCarCulpritInAnotherAccidentIndex]
            if victimCulpritAccidentCollidedWithCarIndex and victimCulpritAccidentCollidedWithCarIndex == culpritCarIndex then
                -- Logger.log(string.format(
                -- "#%d collided with car #%d but that victim car is already involved in accident #%d with culprit car, ignoring new collision",
                -- culpritCarIndex,
                -- collidedWith,
                -- victimCarCulpritInAnotherAccidentIndex))
                return
            end
        end
    end

    -- register a new accident
    local accidentIndex = CompletableIndexCollectionManager.incrementLastIndexCreated(accidentCompletableIndex)

    local carSplinePosition = eventStamp and eventStamp.splinePosition or culpritCar.splinePosition

    AccidentManager.accidents_carIndex[accidentIndex] = culpritCarIndex
    AccidentManager.accidents_worldPosition[accidentIndex] = eventStamp and vec3(eventStamp.positionX, eventStamp.positionY, eventStamp.positionZ) or culpritCar.position
    if eventStamp and eventStamp.victimPositionX ~= nil then
        AccidentManager.accidents_victimWorldPosition[accidentIndex] = vec3(eventStamp.victimPositionX, eventStamp.victimPositionY, eventStamp.victimPositionZ)
    elseif victimCar then
        AccidentManager.accidents_victimWorldPosition[accidentIndex] = victimCar.position
    end
    AccidentManager.accidents_victimSplinePosition[accidentIndex] = eventStamp and eventStamp.victimSplinePosition or (victimCar and victimCar.splinePosition)
    AccidentManager.accidents_splinePosition[accidentIndex] = carSplinePosition
    AccidentManager.accidents_collidedWithTrack[accidentIndex] = collidedWithTrack
    AccidentManager.accidents_collidedWithCarIndex[accidentIndex] = collidedWith
    AccidentManager.accidents_resolved[accidentIndex] = false

    -- mark the culprit car as being in an accident
    AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex] = accidentIndex
    accidentCulpritGeneration[accidentIndex] = eventStamp and eventStamp.culpritGeneration or CarManager.getCarGeneration(culpritCarIndex)

    -- mark the victim car as being in an accident if the culprit collided with another car
    if collidedWithAnotherCar then
        AccidentManager.cars_victimInAccidentIndex[collidedWith] = accidentIndex
        accidentVictimGeneration[accidentIndex] = eventStamp and eventStamp.victimGeneration or CarManager.getCarGeneration(collidedWith)
    end

    -- create a yellow flag zone for this accident
    local yellowFlagZoneIndex = RaceTrackManager.declareYellowFlagZone(accidentIndex)
    AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex] = yellowFlagZoneIndex

    -----------------------------
    -- Disabling car collisions for culprit and victim cars while working on accident navigation
    CarOperations.toggleCarCollisions(culpritCarIndex, false)
    if collidedWithAnotherCar then
        CarOperations.toggleCarCollisions(collidedWith, false)
    end
    -----------------------------

    Logger.log(string.format("Car #%02d COLLISION at (%.1f, %.1f, %.1f) with %s.  Total accidents: %d", 
        culpritCarIndex, 
        collisionLocalPosition.x or 0,
        collisionLocalPosition.y or 0,
        collisionLocalPosition.z or 0,
        collidedWithTrack and "track" or ("car #" .. tostring(collidedWith)), 
        accidentIndex, 
        #AccidentManager.accidents_carIndex))

    -- Inform the Car State Machine about the new accident so that it puts the cars in their new states
    CarStateMachine.informAboutAccident(accidentIndex)

    return accidentIndex
end

---Sets that the given car is navigating around the given accident and car
---@param carIndex integer
---@param accidentIndex integer?
---@param carToNavigateAroundIndex integer?
AccidentManager.setCarNavigatingAroundAccident = function(carIndex, accidentIndex, carToNavigateAroundIndex)
    CarManager.cars_navigatingAroundAccidentIndex[carIndex] = accidentIndex
    CarManager.cars_navigatingAroundCarIndex[carIndex] = carToNavigateAroundIndex
end

function AccidentManager.resetSession()
    for accidentIndex = 1, CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex) do
        if AccidentManager.accidents_resolved[accidentIndex] == false then setAccidentAsResolved(accidentIndex) end
        AccidentManager.accidents_resolved[accidentIndex] = nil
        AccidentManager.accidents_carIndex[accidentIndex] = nil
        AccidentManager.accidents_worldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimWorldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimSplinePosition[accidentIndex] = nil
        AccidentManager.accidents_splinePosition[accidentIndex] = nil
        AccidentManager.accidents_collidedWithTrack[accidentIndex] = nil
        AccidentManager.accidents_collidedWithCarIndex[accidentIndex] = nil
        AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex] = nil
    end
    for index in pairs(AccidentManager.cars_culpritInAccidentIndex) do AccidentManager.cars_culpritInAccidentIndex[index] = nil end
    for index in pairs(AccidentManager.cars_victimInAccidentIndex) do AccidentManager.cars_victimInAccidentIndex[index] = nil end
    CompletableIndexCollectionManager.reset(accidentCompletableIndex)
    RaceTrackManager.resetOwnedYellowFlagZones()
end

---Andreas: this function is O(n) where n is the total number of accidents
---@param car ac.StateCar?
---@return integer? accidentIndex, integer closestCarIndex
AccidentManager.isCarComingUpToAccident = function(car, distanceToDetectAccident)
    local lastAccidentIndexCreated = CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex)
    if lastAccidentIndexCreated == 0 then
        return nil, -1
    end

    if not car then return nil, -1 end

    local carSplinePosition = car.splinePosition
    local carWorldPosition = car.position

    --[====[
    * For all accidents that are not yet resolved
        * Check which car (culprit or victim) is closest to our car
        * Compare the distance of the closest car of this accident with our saved closest car of previous accidents we iterated
        * If this closest car is closer than our previously saved closest car, then
            * Save this accident index as the closest accident and the closest car index
        * else ignore this accident

    --]====]

    -- TODO: Are you sure there's isn't a better way of doing this?  Such as using the sortedCarList and find the next car that is in an accident??

    local currentClosestAccidentIndex = nil
    local currentClosestAccidentClosestCarIndex = -1
    local currentClosestAccidentClosestCarSplinePosition = nil

    local distanceToDetectAccidentSqr = distanceToDetectAccident * distanceToDetectAccident

     -- for i = 1, lastAccidentIndexCreated do
    local firstNonResolvedAccidentIndex = CompletableIndexCollectionManager.getFirstNonResolvedIndex(accidentCompletableIndex)
    for accidentIndex = firstNonResolvedAccidentIndex, lastAccidentIndexCreated do
        if not AccidentManager.accidents_resolved[accidentIndex] then
            local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
            local victimCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
            local culpritGenerationIsCurrent = accidentCulpritGeneration[accidentIndex] == CarManager.getCarGeneration(culpritCarIndex)
            local victimGenerationIsCurrent = victimCarIndex == nil or accidentVictimGeneration[accidentIndex] == CarManager.getCarGeneration(victimCarIndex)
            if not culpritGenerationIsCurrent or not victimGenerationIsCurrent then
                setAccidentAsResolved(accidentIndex)
            else
            local culpritCar = ac.getCar(culpritCarIndex)
            local victimCar = ac.getCar(victimCarIndex)

            local closestCarSplineDistance = math.huge
            local closestCar = nil

            if culpritCar then
                -- make sure the culprit car is ahead of us
                local culpritCarSplinePosition = culpritCar.splinePosition
                local culpritCarAheadOfUs = culpritCarSplinePosition > carSplinePosition
                if culpritCarAheadOfUs then
                    -- make sure the culprit car is within the distance to detect an accident
                    local culpritCarWorldPosition = culpritCar.position
                    -- local distanceFromOurCarToCulpritCar = (culpritCarWorldPosition - carWorldPosition):length()
                    -- local distanceFromOurCarToCulpritCar = MathHelpers.distanceBetweenVec3s(carWorldPosition, culpritCarWorldPosition)
                    local distanceFromOurCarToCulpritCarSqr = MathHelpers.distanceBetweenVec3sSqr(carWorldPosition, culpritCarWorldPosition)
                    -- if distanceFromOurCarToCulpritCar < distanceToDetectAccident then
                    if distanceFromOurCarToCulpritCarSqr < distanceToDetectAccidentSqr then
                        closestCarSplineDistance = math.abs(carSplinePosition - culpritCarSplinePosition)
                        closestCar = culpritCar
                    end
                end
            end

            if victimCar then
                -- make sure the victim car is ahead of us
                local victimCarSplinePosition = victimCar.splinePosition
                local victimCarAheadOfUs = victimCarSplinePosition > carSplinePosition
                if victimCarAheadOfUs then
                    -- make sure the victim car is within the distance to detect an accident
                    local victimCarWorldPosition = victimCar.position
                    -- local distanceFromOurCarToVictimCar = MathHelpers.distanceBetweenVec3s(carWorldPosition, victimCarWorldPosition)
                    local distanceFromOurCarToVictimCarSqr = MathHelpers.distanceBetweenVec3sSqr(carWorldPosition, victimCarWorldPosition)
                    -- if distanceFromOurCarToVictimCar < distanceToDetectAccident then
                    if distanceFromOurCarToVictimCarSqr < distanceToDetectAccidentSqr then
                        -- if the victim car is closer than the culprit car, use the victim car as the closest car
                        local victimCarSplineDistance = math.abs(carSplinePosition - victimCarSplinePosition)
                        if victimCarSplineDistance < closestCarSplineDistance then
                            closestCarSplineDistance = victimCarSplineDistance
                            closestCar = victimCar
                        end
                    end

                end
            end

            -- if from this accident we found the closest car to us, check if closest car of this accident is closer than the closest car of previous accidents we iterated
            if closestCar then
                -- if we haven't yet saved a closest accident, use this accident as the closest accident
                if not currentClosestAccidentIndex then
                    currentClosestAccidentIndex = accidentIndex
                    currentClosestAccidentClosestCarIndex = closestCar.index
                    currentClosestAccidentClosestCarSplinePosition = closestCar.splinePosition
                else
                    if closestCarSplineDistance < currentClosestAccidentClosestCarSplinePosition then
                        currentClosestAccidentIndex = accidentIndex
                        currentClosestAccidentClosestCarIndex = closestCar.index
                        currentClosestAccidentClosestCarSplinePosition = closestCar.splinePosition
                    end
                end
            end
            end
        end
    end

    return currentClosestAccidentIndex, currentClosestAccidentClosestCarIndex
end

return AccidentManager
