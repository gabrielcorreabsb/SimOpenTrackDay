local AccidentManager = {}
local rawget, type, pcall = rawget, type, pcall
local ac_getCar = ac.getCar
local accidentCulpritGeneration, accidentVictimGeneration
-- Numeric sequence is correlation-only; query validity and identity gate freshness (LuaJIT loses integer precision above 2^53).
local decisionSequence = 0
local accidentDecision = { candidates = {}, reasons = {} }
local navigationDecision = { assignedIncident = nil }
local function finiteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end
local function forwardSplineDistance(from, to)
    if not finiteNumber(from) or not finiteNumber(to) or from < 0 or from > 1 or to < 0 or to > 1 then return nil end
    local delta = (to - from) % 1
    if delta > 0 and delta < 0.5 then return delta end
    return nil
end
local function readWorldPositionComponents(position) return position.x, position.y, position.z end
local function validWorldPosition(position)
    local ok, x, y, z = pcall(readWorldPositionComponents, position)
    return ok and finiteNumber(x) and finiteNumber(y) and finiteNumber(z)
end
for i = 1, 32 do accidentDecision.candidates[i], accidentDecision.reasons[i] = false, false end
local function recordAccidentDecisionProtected(carIndex, splinePosition, examined, candidateCount, chosenIncident, chosenCar)
    local session = CarManager.sessionGeneration
    local generation = CarManager.getCarGeneration(carIndex)
    decisionSequence = decisionSequence + 1
    accidentDecision.car = carIndex
    accidentDecision.session = session
    accidentDecision.generation = generation
    accidentDecision.spline = splinePosition
    accidentDecision.examined = examined
    accidentDecision.limited = examined > 32
    accidentDecision.candidateCount = candidateCount
    accidentDecision.chosenIncident = chosenIncident
    accidentDecision.chosenCar = chosenCar
    accidentDecision.sequence = decisionSequence
    accidentDecision.snapshotValid = true
end
local function recordNavigationDecisionProtected(carIndex, accidentIndex, carToNavigateAroundIndex)
    local generation = CarManager.getCarGeneration(carIndex)
    local session = CarManager.sessionGeneration
    navigationDecision.snapshotValid = false
    navigationDecision.car = carIndex
    navigationDecision.session = session
    navigationDecision.generation = generation
    navigationDecision.assignedIncident = accidentIndex
    navigationDecision.assignedCar = carToNavigateAroundIndex
    local identityValid = accidentDecision.car == carIndex
      and accidentDecision.session == CarManager.sessionGeneration
      and accidentDecision.generation == generation
    navigationDecision.comparedIncident = identityValid and accidentDecision.chosenIncident or nil
    navigationDecision.comparedCar = identityValid and accidentDecision.chosenCar or nil
    navigationDecision.assignmentOrigin = 'UNKNOWN'
    navigationDecision.matchesQuery = identityValid and accidentDecision.chosenIncident ~= nil
      and accidentIndex == accidentDecision.chosenIncident
      and carToNavigateAroundIndex == accidentDecision.chosenCar or false
    navigationDecision.querySequence = identityValid and accidentDecision.sequence or nil
    navigationDecision.snapshotValid = true
end
local function readCulpritGenerationProtected(accidentIndex)
    return accidentCulpritGeneration[accidentIndex]
end
local function observe(...)
    local lookupOK, logger = pcall(rawget, _G, 'Logger')
    if not lookupOK then return end
    local observeOK, fn = pcall(rawget, logger, 'observe')
    if not observeOK then return end
    if type(fn) == 'function' then pcall(fn, ...) end
end
local function observeIncidentCreatedProtected(accidentIndex, zoneIndex, stamp, detail)
    local referenceSession = type(stamp) == 'table' and stamp.session or nil
    local carIndex = AccidentManager.accidents_carIndex[accidentIndex]
    local generation = accidentCulpritGeneration[accidentIndex]
    observe('incident-created', carIndex, generation, accidentIndex, zoneIndex, detail or 'created', nil, referenceSession)
end
local function observeIncidentCreated(accidentIndex, zoneIndex, stamp, detail)
    pcall(observeIncidentCreatedProtected, accidentIndex, zoneIndex, stamp, detail)
end
local function observeIncidentResolvedProtected(accidentIndex, carIndex, generation, victimIndex, zoneIndex)
    local roles = victimIndex ~= nil and 'culprit-and-victim' or 'culprit'
    observe('incident-resolved', carIndex, generation, accidentIndex, zoneIndex, roles, nil, nil)
end
local function observeIncidentResolved(accidentIndex, carIndex, generation, victimIndex, zoneIndex)
    pcall(observeIncidentResolvedProtected, accidentIndex, carIndex, generation, victimIndex, zoneIndex)
end

-- G6: per-car decision reason trace. One line per real reason change, never per query.
local decisionLastReason = {}
local function observeDecisionChangeProtected(carIndex, reason)
    decisionLastReason[carIndex] = reason
    local generation
    local generationOK, value = pcall(CarManager.getCarGeneration, carIndex)
    if generationOK then generation = value end
    observe('decision-changed', carIndex, generation, nil, nil, reason)
end
local function observeDecisionChange(carIndex, reason)
    if type(carIndex) ~= 'number' or carIndex ~= carIndex or carIndex < 0
      or carIndex == math.huge or carIndex % 1 ~= 0 then return end
    if decisionLastReason[carIndex] == reason then return end
    pcall(observeDecisionChangeProtected, carIndex, reason)
end

-- local lastAccidentIndexCreated = 0
-- local firstNonResolvedAccidentIndex = 1

local accidentCompletableIndex = CompletableIndexCollectionManager.createNewIndex()
accidentCulpritGeneration = {}
accidentVictimGeneration = {}
local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- Contact severity thresholds. Module-local only: no settings, schema or UI exposure.
local SEVERITY_STOPPED_SPEED_KMH = 5
local SEVERITY_RELATIVE_SPEED_KMH = 20
-- Obstruction detection extends the zone END forward so a wreck that rolled past the band stays visible.
local OBSTRUCTION_FORWARD_TOLERANCE_METERS = 25

-- Recovery participant observation states.
local RECOVERY_ABSENT, RECOVERY_OBSTRUCTION, RECOVERY_INVALID = 1, 2, 3

local function readCollisionLocalPositionProtected(position)
    local x, y, z = position.x, position.y, position.z
    return x, y, z
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

AccidentManager.accidents_pitManoeuvre = {}
AccidentManager.accidents_sessionGeneration = {}
AccidentManager.accidents_culpritIsInPitlane = {}
AccidentManager.accidents_victimIsInPitlane = {}
AccidentManager.accidents_culpritSpeedKmh = {}
AccidentManager.accidents_victimSpeedKmh = {}
local accidentsRecoveryElapsed, accidentsRecoveryPreviousValid = {}, {}
local recoveryLastClock

local function resetRecoveryContinuity()
    for accidentIndex = 1, CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex) do
        if AccidentManager.accidents_resolved[accidentIndex] == false then
            accidentsRecoveryElapsed[accidentIndex] = 0
            accidentsRecoveryPreviousValid[accidentIndex] = false
        end
    end
end

local function resetRecoveryForContact(culpritCarIndex, victimCarIndex)
    for accidentIndex = 1, CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex) do
        if AccidentManager.accidents_resolved[accidentIndex] == false then
            local recordedCulprit = AccidentManager.accidents_carIndex[accidentIndex]
            local recordedVictim = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
            if recordedCulprit == culpritCarIndex or recordedCulprit == victimCarIndex
              or recordedVictim == culpritCarIndex or recordedVictim == victimCarIndex then
                accidentsRecoveryElapsed[accidentIndex] = 0
                accidentsRecoveryPreviousValid[accidentIndex] = false
            end
        end
    end
end

function AccidentManager.shouldAdmitIncidentStop(accidentIndex)
    if type(accidentIndex) ~= 'number' or accidentIndex ~= accidentIndex
      or accidentIndex < 1 or accidentIndex == math.huge or accidentIndex % 1 ~= 0 then return true end
    return AccidentManager.accidents_pitManoeuvre[accidentIndex] ~= true
end

local function isPitManoeuvre(eventStamp)
    if type(eventStamp) ~= 'table' or eventStamp.culpritIsInPitlane ~= true
      or eventStamp.victimIsInPitlane ~= true then return false end
    local culpritSpeed, victimSpeed = eventStamp.culpritSpeedKmh, eventStamp.victimSpeedKmh
    return isFiniteNumber(culpritSpeed) and isFiniteNumber(victimSpeed)
      and culpritSpeed >= 0 and culpritSpeed <= 15 and victimSpeed >= 0 and victimSpeed <= 15
end

---Returns true when a car-car contact carries no actionable severity signal.
---Relative speed prefers the collision-time velocity vectors; player-victim contacts never suppress.
local function isLowSeverityContact(eventStamp, victimCarIndex)
    if type(eventStamp) ~= 'table' then return false end
    -- The local player is the protected asset: a contact touching it is always actionable.
    if victimCarIndex == 0 then return false end
    local culpritSpeed, victimSpeed = eventStamp.culpritSpeedKmh, eventStamp.victimSpeedKmh
    local stopped = (isFiniteNumber(culpritSpeed) and culpritSpeed <= SEVERITY_STOPPED_SPEED_KMH)
      or (isFiniteNumber(victimSpeed) and victimSpeed <= SEVERITY_STOPPED_SPEED_KMH)
    if stopped then return false end
    local relativeSpeedKmh
    local culpritVelocityX, culpritVelocityY, culpritVelocityZ =
        eventStamp.culpritVelocityX, eventStamp.culpritVelocityY, eventStamp.culpritVelocityZ
    local victimVelocityX, victimVelocityY, victimVelocityZ =
        eventStamp.victimVelocityX, eventStamp.victimVelocityY, eventStamp.victimVelocityZ
    if isFiniteNumber(culpritVelocityX) and isFiniteNumber(culpritVelocityY) and isFiniteNumber(culpritVelocityZ)
      and isFiniteNumber(victimVelocityX) and isFiniteNumber(victimVelocityY) and isFiniteNumber(victimVelocityZ) then
        local deltaX = culpritVelocityX - victimVelocityX
        local deltaY = culpritVelocityY - victimVelocityY
        local deltaZ = culpritVelocityZ - victimVelocityZ
        relativeSpeedKmh = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ) * 3.6
    elseif isFiniteNumber(culpritSpeed) and isFiniteNumber(victimSpeed) then
        relativeSpeedKmh = math.abs(culpritSpeed - victimSpeed)
    else
        -- No severity signal at all: never suppress on missing data.
        return false
    end
    return relativeSpeedKmh < SEVERITY_RELATIVE_SPEED_KMH
end

-- G3: repeated rejections of the same (kind, pair) print once, then every tenth occurrence.
local REJECTION_DETAIL_IDS = {
    ['invalid-culprit-index'] = 1, ['culprit-unavailable-or-ineligible'] = 2, ['invalid-collider'] = 3,
    ['invalid-local-collision-position'] = 4, ['stale-or-incomplete-track-contact'] = 5,
    ['track-collision-ignored'] = 6, ['victim-unavailable'] = 7, ['missing-event-position'] = 8,
    ['missing-victim-position'] = 9, ['stale-event-identity'] = 10,
    ['pit-pair-observation-already-recorded'] = 11, ['duplicate-contact-pair'] = 12,
    ['low-severity-contact-ignored'] = 13,
}
local rejectionCounts = {}
local function observeIncidentRejected(culpritCarIndex, victimCarIndex, incidentIndex, detail)
    if type(culpritCarIndex) ~= 'number' or culpritCarIndex ~= culpritCarIndex or culpritCarIndex < 0
      or culpritCarIndex == math.huge or culpritCarIndex % 1 ~= 0 then
        observe('incident-rejected', culpritCarIndex, nil, incidentIndex, nil, detail)
        return
    end
    local row = rejectionCounts[culpritCarIndex]
    if row == nil then row = {}; rejectionCounts[culpritCarIndex] = row end
    local victimKey = type(victimCarIndex) == 'number' and victimCarIndex >= 0
      and victimCarIndex % 1 == 0 and victimCarIndex or 9999
    local key = (REJECTION_DETAIL_IDS[detail] or 0) * 10000 + victimKey
    local count = (row[key] or 0) + 1
    row[key] = count
    if count == 1 or count % 10 == 0 then
        observe('incident-rejected', culpritCarIndex, nil, incidentIndex, nil, detail, nil, nil, 'count=' .. count)
    end
end

-- Per-car role maps are compatibility hints, not a complete incident index.
local function findActivePairIncident(firstCarIndex, secondCarIndex)
    local currentSession = CarManager.sessionGeneration
    local last = CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex)
    local pitIncident
    for accidentIndex = last, 1, -1 do
        if AccidentManager.accidents_resolved[accidentIndex] == false
          and AccidentManager.accidents_sessionGeneration[accidentIndex] == currentSession then
            local recordedCulprit = AccidentManager.accidents_carIndex[accidentIndex]
            local recordedVictim = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
            if recordedVictim ~= nil
              and ((recordedCulprit == firstCarIndex and recordedVictim == secondCarIndex)
                or (recordedCulprit == secondCarIndex and recordedVictim == firstCarIndex))
              and accidentCulpritGeneration[accidentIndex] == CarManager.getCarGeneration(recordedCulprit)
              and accidentVictimGeneration[accidentIndex] == CarManager.getCarGeneration(recordedVictim) then
                if AccidentManager.accidents_pitManoeuvre[accidentIndex] == true then
                    pitIncident = pitIncident or accidentIndex
                else
                    return accidentIndex
                end
            end
        end
    end
    return pitIncident
end

local function promotePitIncident(accidentIndex, culpritCarIndex, victimCarIndex, culpritCar, victimCar, eventStamp)
    local recordedCulprit = AccidentManager.accidents_carIndex[accidentIndex]
    local recordedVictim = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
    local reversed = recordedCulprit ~= culpritCarIndex
    local recordedCulpritPosition, recordedVictimPosition
    local recordedCulpritSpline, recordedVictimSpline
    if eventStamp then
        if reversed then
            recordedCulpritPosition = vec3(eventStamp.victimPositionX, eventStamp.victimPositionY, eventStamp.victimPositionZ)
            recordedVictimPosition = vec3(eventStamp.positionX, eventStamp.positionY, eventStamp.positionZ)
            recordedCulpritSpline, recordedVictimSpline = eventStamp.victimSplinePosition, eventStamp.splinePosition
        else
            recordedCulpritPosition = vec3(eventStamp.positionX, eventStamp.positionY, eventStamp.positionZ)
            recordedVictimPosition = vec3(eventStamp.victimPositionX, eventStamp.victimPositionY, eventStamp.victimPositionZ)
            recordedCulpritSpline, recordedVictimSpline = eventStamp.splinePosition, eventStamp.victimSplinePosition
        end
    elseif reversed then
        recordedCulpritPosition, recordedVictimPosition = victimCar.position, culpritCar.position
        recordedCulpritSpline, recordedVictimSpline = victimCar.splinePosition, culpritCar.splinePosition
    else
        recordedCulpritPosition, recordedVictimPosition = culpritCar.position, victimCar.position
        recordedCulpritSpline, recordedVictimSpline = culpritCar.splinePosition, victimCar.splinePosition
    end
    AccidentManager.accidents_worldPosition[accidentIndex] = recordedCulpritPosition
    AccidentManager.accidents_victimWorldPosition[accidentIndex] = recordedVictimPosition
    AccidentManager.accidents_splinePosition[accidentIndex] = recordedCulpritSpline
    AccidentManager.accidents_victimSplinePosition[accidentIndex] = recordedVictimSpline
    AccidentManager.accidents_pitManoeuvre[accidentIndex] = false
    accidentCulpritGeneration[accidentIndex] = CarManager.getCarGeneration(recordedCulprit)
    accidentVictimGeneration[accidentIndex] = CarManager.getCarGeneration(recordedVictim)
    AccidentManager.accidents_sessionGeneration[accidentIndex] = CarManager.sessionGeneration
    AccidentManager.cars_culpritInAccidentIndex[recordedCulprit] = accidentIndex
    AccidentManager.cars_victimInAccidentIndex[recordedVictim] = accidentIndex
    accidentsRecoveryElapsed[accidentIndex] = 0
    accidentsRecoveryPreviousValid[accidentIndex] = false
    local zoneIndex = RaceTrackManager.declareYellowFlagZone(accidentIndex)
    AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex] = zoneIndex
    observeIncidentCreated(accidentIndex, zoneIndex, eventStamp, 'pit-record-promoted-by-normal-contact')
    CarStateMachine.informAboutAccident(accidentIndex)
    return accidentIndex
end

local function canPromotePitIncident(accidentIndex)
    local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
    local victimCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
    local culpritOwner = AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex]
    local victimOwner = AccidentManager.cars_victimInAccidentIndex[victimCarIndex]
    return (culpritOwner == nil or culpritOwner == accidentIndex)
      and (victimOwner == nil or victimOwner == accidentIndex)
end

---Marks the given accident as resolved and done
---@param accidentIndex integer
local setAccidentAsResolved = function(accidentIndex)
        if AccidentManager.accidents_resolved[accidentIndex] == true then return false end
        local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
        local victimCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
        local generationOK, culpritGeneration = pcall(readCulpritGenerationProtected, accidentIndex)
        if not generationOK then culpritGeneration = nil end
        local yellowFlagZoneIndex = AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex]
        AccidentManager.accidents_carIndex[accidentIndex] = nil
        AccidentManager.accidents_worldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimWorldPosition[accidentIndex] = nil
        AccidentManager.accidents_victimSplinePosition[accidentIndex] = nil
        AccidentManager.accidents_splinePosition[accidentIndex] = nil
        AccidentManager.accidents_collidedWithTrack[accidentIndex] = nil
        AccidentManager.accidents_collidedWithCarIndex[accidentIndex] = nil
        AccidentManager.accidents_pitManoeuvre[accidentIndex] = nil
        AccidentManager.accidents_sessionGeneration[accidentIndex] = nil
        AccidentManager.accidents_culpritIsInPitlane[accidentIndex] = nil
        AccidentManager.accidents_victimIsInPitlane[accidentIndex] = nil
        AccidentManager.accidents_culpritSpeedKmh[accidentIndex] = nil
        AccidentManager.accidents_victimSpeedKmh[accidentIndex] = nil
        accidentsRecoveryElapsed[accidentIndex] = nil
        accidentsRecoveryPreviousValid[accidentIndex] = nil

        -- remove the yellow flag zone associated with this accident
        -- G5: mirror the declaration plain log so zone removals are visible in the plain log.
        local removedZoneStartSplinePosition, removedZoneEndSplinePosition
        if yellowFlagZoneIndex ~= nil then
            local zoneSnapshotOK, zoneSnapshot = pcall(RaceTrackManager.getYellowZoneReadOnly, yellowFlagZoneIndex)
            if zoneSnapshotOK and type(zoneSnapshot) == 'table' then
                removedZoneStartSplinePosition = zoneSnapshot.startSplinePosition
                removedZoneEndSplinePosition = zoneSnapshot.endSplinePosition
            end
        end
        local zoneRemoved = RaceTrackManager.removeYellowFlagZone(yellowFlagZoneIndex)
        if zoneRemoved == true and yellowFlagZoneIndex ~= nil then
            Logger.log(string.format("[RaceTrackManager] Removed yellow flag zone #%d: start %.3f end %.3f (incident #%d)",
                yellowFlagZoneIndex, removedZoneStartSplinePosition or -1, removedZoneEndSplinePosition or -1, accidentIndex))
        end
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
        observeIncidentResolved(accidentIndex, culpritCarIndex, culpritGeneration, victimCarIndex, yellowFlagZoneIndex)
end

---Returns a boolean value indicating whether the accident has been resolved
---@param carIndex integer @0-based car index
---@return boolean @true if the accident is resolved
AccidentManager.isAccidentResolved = function(carIndex)
    return AccidentManager.accidents_resolved[carIndex]
end

---Resolve every active accident involving the given car as culprit or victim
---@param carIndex number
AccidentManager.informAboutCarReset = function(carIndex)
    if not isFiniteNumber(carIndex) or carIndex < 0 or carIndex % 1 ~= 0 then return end

    local lastAccidentIndex = CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex)
    for accidentIndex = 1, lastAccidentIndex do
        if AccidentManager.accidents_resolved[accidentIndex] == false
          and (AccidentManager.accidents_carIndex[accidentIndex] == carIndex
            or AccidentManager.accidents_collidedWithCarIndex[accidentIndex] == carIndex) then
            Logger.log(string.format("[AccidentManager] Car #%d has reset, clearing accident #%d", carIndex, accidentIndex))
            setAccidentAsResolved(accidentIndex)
        end
    end
end

local function readRecoveryCarProtected(carIndex)
    local car = ac_getCar(carIndex)
    if not car or car.index ~= carIndex then return false end
    local position = car.position
    if not position then return true end
    return true, car.isConnected, car.isActive, position.x, position.y, position.z,
        car.speedKmh, car.collisionDepth, car.splinePosition
end

local function readRecoveryIdentityProtected(carIndex)
    local operations = rawget(_G, 'CarOperations')
    local hasActive = type(operations) == 'table' and rawget(operations, 'hasActiveIncidentStop')
    if type(hasActive) ~= 'function' then return nil end
    return CarManager.sessionGeneration, CarManager.getCarGeneration(carIndex), hasActive(carIndex)
end

local function readRecoveryClockProtected()
    local manager = rawget(_G, 'GameTimeManager')
    local getTime = type(manager) == 'table' and rawget(manager, 'getPlayingGameTime')
    if type(getTime) ~= 'function' then return nil end
    return getTime()
end

local function clearAccidentRecovery(accidentIndex)
    accidentsRecoveryElapsed[accidentIndex] = 0
    accidentsRecoveryPreviousValid[accidentIndex] = false
end

---Classifies one incident participant against its own zone for recovery purposes.
---Absent covers missing/disconnected/inactive/moving/far participants; invalid covers unreadable data.
local function classifyRecoveryParticipant(ok, present, connected, active, x, y, z, speed, depth, spline, zoneIndex)
    if not ok then return RECOVERY_INVALID end
    if present ~= true then return RECOVERY_ABSENT end
    -- Unknown connectivity/activity is not absence: only an explicit false proves the participant left.
    if type(connected) ~= 'boolean' or type(active) ~= 'boolean' then return RECOVERY_INVALID end
    if connected == false or active == false then return RECOVERY_ABSENT end
    if not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then return RECOVERY_INVALID end
    if not isFiniteNumber(depth) then return RECOVERY_INVALID end
    if depth > 0 then return RECOVERY_OBSTRUCTION end
    if not isFiniteNumber(speed) then return RECOVERY_INVALID end
    if not isFiniteNumber(spline) or spline < 0 or spline > 1 then return RECOVERY_INVALID end
    local zoneOK, insideZone = pcall(RaceTrackManager.isSplinePositionInZone, zoneIndex, spline,
        OBSTRUCTION_FORWARD_TOLERANCE_METERS)
    if not zoneOK then return RECOVERY_INVALID end
    if insideZone == true and speed <= SEVERITY_STOPPED_SPEED_KMH then return RECOVERY_OBSTRUCTION end
    return RECOVERY_ABSENT
end

local function readCarsCountProtected()
    local sim = ac.getSim()
    if sim == nil then return nil end
    return sim.carsCount
end

---Returns true when any connected, active, non-pit car is stopped inside the zone band.
---nil means the scan was invalid (keep the zone). Unreadable third cars are skipped on purpose:
---a permanently unreadable car must not freeze every zone forever (participants stay strict).
local function hasStoppedCarInZoneProtected(zoneIndex)
    local countOK, carsCount = pcall(readCarsCountProtected)
    if not countOK or not isFiniteNumber(carsCount) or carsCount < 1 or carsCount % 1 ~= 0 then return nil end
    for carIndex = 0, carsCount - 1 do
        local carOK, car = pcall(ac_getCar, carIndex)
        if carOK and car ~= nil and car.index == carIndex then
            local connected, active = car.isConnected, car.isActive
            if connected == true and active == true
              and car.isInPitlane ~= true and car.isInPit ~= true then
                local speedKmh, splinePosition = car.speedKmh, car.splinePosition
                if isFiniteNumber(speedKmh) and isFiniteNumber(splinePosition)
                  and speedKmh <= SEVERITY_STOPPED_SPEED_KMH then
                    local zoneOK, insideZone = pcall(RaceTrackManager.isSplinePositionInZone,
                        zoneIndex, splinePosition, OBSTRUCTION_FORWARD_TOLERANCE_METERS)
                    if not zoneOK then return nil end
                    if insideZone == true then return true end
                end
            end
        end
    end
    return false
end

function AccidentManager.updateRecovery(dt)
    if not isFiniteNumber(dt) or dt <= 0 or dt > 0.25 then
        resetRecoveryContinuity()
        recoveryLastClock = nil
        return
    end
    local clockOK, now = pcall(readRecoveryClockProtected)
    if not clockOK or not isFiniteNumber(now) then
        resetRecoveryContinuity()
        recoveryLastClock = nil
        return
    end
    local activeDelta
    if recoveryLastClock ~= nil then
        activeDelta = now - recoveryLastClock
    end
    if activeDelta ~= nil and (activeDelta < 0 or activeDelta > 0.25
      or activeDelta > dt + 0.001) then
        resetRecoveryContinuity()
        recoveryLastClock = now
        return
    end
    recoveryLastClock = now

    local last = CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex)
    for accidentIndex = 1, last do
        if AccidentManager.accidents_resolved[accidentIndex] == false then
            local culpritIndex = AccidentManager.accidents_carIndex[accidentIndex]
            local victimIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
            local valid = victimIndex ~= nil
              and AccidentManager.accidents_sessionGeneration[accidentIndex] == CarManager.sessionGeneration
              and accidentCulpritGeneration[accidentIndex] ~= nil
              and accidentVictimGeneration[accidentIndex] ~= nil
            if valid then
                local culpritIdentityOK, culpritSession, culpritGeneration, culpritStop = pcall(readRecoveryIdentityProtected, culpritIndex)
                local victimIdentityOK, victimSession, victimGeneration, victimStop = pcall(readRecoveryIdentityProtected, victimIndex)
                valid = culpritIdentityOK and victimIdentityOK
                  and culpritSession == CarManager.sessionGeneration and victimSession == CarManager.sessionGeneration
                  and culpritGeneration == accidentCulpritGeneration[accidentIndex]
                  and victimGeneration == accidentVictimGeneration[accidentIndex]
                  and type(culpritStop) == 'boolean' and type(victimStop) == 'boolean'
                  and not culpritStop and not victimStop
            end
            if valid then
                local zoneIndex = AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex]
                if zoneIndex == nil then
                    -- Incidents without a zone (pit observation records) keep their historical speed criterion.
                    local culpritOK, culpritPresent, culpritConnected, culpritActive, cx, cy, cz, cs, cd =
                        pcall(readRecoveryCarProtected, culpritIndex)
                    local victimOK, victimPresent, victimConnected, victimActive, vx, vy, vz, vs, vd =
                        pcall(readRecoveryCarProtected, victimIndex)
                    local minimumSpeed = AccidentManager.accidents_pitManoeuvre[accidentIndex] == true and 5 or 20
                    valid = culpritOK and victimOK and culpritConnected == true and victimConnected == true
                      and culpritActive == true and victimActive == true
                      and isFiniteNumber(cx) and isFiniteNumber(cy) and isFiniteNumber(cz)
                      and isFiniteNumber(vx) and isFiniteNumber(vy) and isFiniteNumber(vz)
                      and isFiniteNumber(cs) and isFiniteNumber(vs)
                      and isFiniteNumber(cd) and isFiniteNumber(vd) and cd <= 0 and vd <= 0
                      and cs >= minimumSpeed and vs >= minimumSpeed
                else
                    -- Zoned incidents resolve only when neither participant obstructs its own zone band.
                    local culpritOK, culpritPresent, culpritConnected, culpritActive, cx, cy, cz, cs, cd, csp =
                        pcall(readRecoveryCarProtected, culpritIndex)
                    local victimOK, victimPresent, victimConnected, victimActive, vx, vy, vz, vs, vd, vsp =
                        pcall(readRecoveryCarProtected, victimIndex)
                    local culpritState = classifyRecoveryParticipant(culpritOK, culpritPresent, culpritConnected,
                        culpritActive, cx, cy, cz, cs, cd, csp, zoneIndex)
                    local victimState = classifyRecoveryParticipant(victimOK, victimPresent, victimConnected,
                        victimActive, vx, vy, vz, vs, vd, vsp, zoneIndex)
                    valid = culpritState == RECOVERY_ABSENT and victimState == RECOVERY_ABSENT
                    if valid then
                        -- The zone also stays while any other stopped car obstructs the band.
                        valid = hasStoppedCarInZoneProtected(zoneIndex) == false
                    end
                end
            end
            if valid then
                if accidentsRecoveryPreviousValid[accidentIndex] then
                    if activeDelta and activeDelta > 0 then
                        accidentsRecoveryElapsed[accidentIndex] = (accidentsRecoveryElapsed[accidentIndex] or 0) + activeDelta
                    end
                else
                    accidentsRecoveryElapsed[accidentIndex] = 0
                end
                accidentsRecoveryPreviousValid[accidentIndex] = true
                if accidentsRecoveryElapsed[accidentIndex] >= 3 then setAccidentAsResolved(accidentIndex) end
            else
                clearAccidentRecovery(accidentIndex)
            end
        end
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
        observeIncidentRejected(culpritCarIndex, nil, nil, 'invalid-culprit-index')
        -- Logger.log("AccidentManager.registerCollision called with culpritCarIndex 0 local player, ignoring")
        return
    end

    local culpritCar = ac.getCar(culpritCarIndex)
    if not culpritCar or culpritCar.index ~= culpritCarIndex or not CarManager.isWritableAICar(culpritCarIndex) then
        observeIncidentRejected(culpritCarIndex, nil, nil, 'culprit-unavailable-or-ineligible'); return
    end
    if type(collidedWith) ~= 'number' or collidedWith ~= collidedWith or collidedWith < 0 or collidedWith % 1 ~= 0 then
        observeIncidentRejected(culpritCarIndex, nil, nil, 'invalid-collider'); return
    end
    local positionType = type(collisionLocalPosition)
    if positionType ~= 'table' and positionType ~= 'cdata' then
        observeIncidentRejected(culpritCarIndex, nil, nil, 'invalid-local-collision-position'); return
    end
    local positionOK, collisionLocalX, collisionLocalY, collisionLocalZ =
        pcall(readCollisionLocalPositionProtected, collisionLocalPosition)
    if not positionOK or not isFiniteNumber(collisionLocalX)
      or not isFiniteNumber(collisionLocalY) or not isFiniteNumber(collisionLocalZ) then
        observeIncidentRejected(culpritCarIndex, nil, nil, 'invalid-local-collision-position'); return
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
        if eventStamp then
            if not isFiniteNumber(eventStamp.positionX) or not isFiniteNumber(eventStamp.positionY)
              or not isFiniteNumber(eventStamp.positionZ) or not isFiniteNumber(eventStamp.splinePosition)
              or eventStamp.index ~= culpritCarIndex
              or eventStamp.session ~= CarManager.sessionGeneration
              or eventStamp.generation ~= CarManager.getCarGeneration(culpritCarIndex)
              or eventStamp.culpritGeneration ~= CarManager.getCarGeneration(culpritCarIndex) then
                observeIncidentRejected(culpritCarIndex, nil, nil, 'stale-or-incomplete-track-contact'); return
            end
        end
        resetRecoveryForContact(culpritCarIndex, nil)
        observeIncidentRejected(culpritCarIndex, nil, nil, 'track-collision-ignored')
        --Logger.warn(string.format("#%d collided with the track but ignoring track collisions for now", culpritCarIndex))
        return
    end

    -- we need to subtract 1 from the index to get the actual car index since colliderWidth 0 is track
    collidedWith = collidedWith - 1
    local victimCar = not collidedWithTrack and ac.getCar(collidedWith) or nil
    if not collidedWithTrack and (not victimCar or victimCar.index ~= collidedWith) then
        observeIncidentRejected(culpritCarIndex, collidedWith, nil, 'victim-unavailable'); return
    end
    if eventStamp then
        if not isFiniteNumber(eventStamp.positionX) or not isFiniteNumber(eventStamp.positionY)
          or not isFiniteNumber(eventStamp.positionZ) or not isFiniteNumber(eventStamp.splinePosition) then
            observeIncidentRejected(culpritCarIndex, collidedWith, nil, 'missing-event-position'); return
        end
        if not collidedWithTrack and (not isFiniteNumber(eventStamp.victimPositionX)
          or not isFiniteNumber(eventStamp.victimPositionY) or not isFiniteNumber(eventStamp.victimPositionZ)
          or not isFiniteNumber(eventStamp.victimSplinePosition)) then
            observeIncidentRejected(culpritCarIndex, collidedWith, nil, 'missing-victim-position'); return
        end
        if eventStamp.index ~= culpritCarIndex
          or eventStamp.session ~= CarManager.sessionGeneration
          or eventStamp.generation ~= CarManager.getCarGeneration(culpritCarIndex)
          or eventStamp.culpritGeneration ~= CarManager.getCarGeneration(culpritCarIndex)
          or (not collidedWithTrack and (eventStamp.victimIndex ~= collidedWith
            or eventStamp.victimGeneration ~= CarManager.getCarGeneration(collidedWith))) then
            observeIncidentRejected(culpritCarIndex, collidedWith, nil, 'stale-event-identity'); return
        end
    end

    local pitManoeuvre = isPitManoeuvre(eventStamp)

    -- A validated fresh callback breaks every recovery window involving either participant,
    -- even if the existing duplicate policy below rejects the registration.
    resetRecoveryForContact(culpritCarIndex, collidedWithTrack and nil or collidedWith)

    local collidedWithAnotherCar = not collidedWithTrack
    if collidedWithAnotherCar then
        local existingPair = findActivePairIncident(culpritCarIndex, collidedWith)
        if existingPair then
            local isPitRecord = AccidentManager.accidents_pitManoeuvre[existingPair] == true
            if isPitRecord then
                if pitManoeuvre then
                    observeIncidentRejected(culpritCarIndex, collidedWith, existingPair, 'pit-pair-observation-already-recorded')
                    return existingPair
                end
                if canPromotePitIncident(existingPair) then
                    return promotePitIncident(existingPair, culpritCarIndex, collidedWith, culpritCar, victimCar, eventStamp)
                end
                -- Promotion would overwrite another active role owner. Preserve the historical
                -- fallback by recording a normal actionable incident without changing that owner.
            else
                observeIncidentRejected(culpritCarIndex, collidedWith, existingPair, 'duplicate-contact-pair')
                return
            end
        end
    end

    -- Severity gate: a trivial car-car contact is observation-only.
    -- The rule applies uniformly to this new-incident path and to the pit-record fall-through that
    -- reaches this point (pit promotion above keeps priority). A trivial contact creates no record
    -- in the fall-through path; unknown data never suppresses (conservative).
    if collidedWithAnotherCar and not pitManoeuvre and isLowSeverityContact(eventStamp, collidedWith) then
        observeIncidentRejected(culpritCarIndex, collidedWith, nil, 'low-severity-contact-ignored')
        return
    end

    -- register a new accident
    -- G4: creation prints once, as incident-created (with zone), never also as incident-accepted.
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
    AccidentManager.accidents_pitManoeuvre[accidentIndex] = pitManoeuvre
    AccidentManager.accidents_sessionGeneration[accidentIndex] = eventStamp and eventStamp.session or CarManager.sessionGeneration
    AccidentManager.accidents_culpritIsInPitlane[accidentIndex] = eventStamp and eventStamp.culpritIsInPitlane
    AccidentManager.accidents_victimIsInPitlane[accidentIndex] = eventStamp and eventStamp.victimIsInPitlane
    AccidentManager.accidents_culpritSpeedKmh[accidentIndex] = eventStamp and eventStamp.culpritSpeedKmh
    AccidentManager.accidents_victimSpeedKmh[accidentIndex] = eventStamp and eventStamp.victimSpeedKmh
    accidentsRecoveryElapsed[accidentIndex] = 0
    accidentsRecoveryPreviousValid[accidentIndex] = false

    -- mark the culprit car as being in an accident
    accidentCulpritGeneration[accidentIndex] = eventStamp and eventStamp.culpritGeneration or CarManager.getCarGeneration(culpritCarIndex)

    -- mark the victim car as being in an accident if the culprit collided with another car
    if collidedWithAnotherCar then
        accidentVictimGeneration[accidentIndex] = eventStamp and eventStamp.victimGeneration or CarManager.getCarGeneration(collidedWith)
    end

    if not pitManoeuvre then
        AccidentManager.cars_culpritInAccidentIndex[culpritCarIndex] = accidentIndex
        if collidedWithAnotherCar then AccidentManager.cars_victimInAccidentIndex[collidedWith] = accidentIndex end
        -- create a yellow flag zone for this accident
        local yellowFlagZoneIndex = RaceTrackManager.declareYellowFlagZone(accidentIndex)
        AccidentManager.accidents_yellowFlagZoneIndex[accidentIndex] = yellowFlagZoneIndex
        observeIncidentCreated(accidentIndex, yellowFlagZoneIndex, eventStamp, 'registered')
    else
        observeIncidentCreated(accidentIndex, nil, eventStamp, 'pit-manoeuvre-observed-no-zone-or-stop')
    end

    Logger.log(string.format("Car #%02d COLLISION at (%.1f, %.1f, %.1f) with %s.  Total accidents: %d", 
        culpritCarIndex, 
        collisionLocalX,
        collisionLocalY,
        collisionLocalZ,
        collidedWithTrack and "track" or ("car #" .. tostring(collidedWith)), 
        accidentIndex, 
        #AccidentManager.accidents_carIndex))

    -- Pit manoeuvre observations never enter the operational participant queue.
    if not pitManoeuvre then CarStateMachine.informAboutAccident(accidentIndex) end

    return accidentIndex
end

---Sets that the given car is navigating around the given accident and car
---@param carIndex integer
---@param accidentIndex integer?
---@param carToNavigateAroundIndex integer?
AccidentManager.setCarNavigatingAroundAccident = function(carIndex, accidentIndex, carToNavigateAroundIndex)
    CarManager.cars_navigatingAroundAccidentIndex[carIndex] = accidentIndex
    CarManager.cars_navigatingAroundCarIndex[carIndex] = carToNavigateAroundIndex
    local capture = false
    local loggerOK, logger = pcall(rawget, _G, 'Logger')
    if loggerOK and type(logger) == 'table' then
        local enabledOK, enabled = pcall(rawget, logger, 'OBS1_ENABLED')
        local focusOK, focus = pcall(rawget, logger, 'OBS1_FOCUS_CAR')
        capture = enabledOK and focusOK and enabled == true and focus == carIndex
    end
    if capture then
        pcall(recordNavigationDecisionProtected, carIndex, accidentIndex, carToNavigateAroundIndex)
    end
end

function AccidentManager.getAccidentDecisionReadOnly(carIndex)
    local ok, result = pcall(function()
        if type(carIndex) ~= 'number' or carIndex ~= carIndex or carIndex < 0
          or carIndex == math.huge or carIndex % 1 ~= 0 then return nil end
        local b = accidentDecision
        local query
        if b.snapshotValid and b.car == carIndex then
            query = { car = b.car, session = b.session, generation = b.generation, spline = b.spline,
                candidates = {}, examined = b.examined, limited = b.limited, chosenIncident = b.chosenIncident,
                chosenCar = b.chosenCar, sequence = b.sequence, source = 'actual-query' }
            for i = 1, math.min(b.candidateCount or 0, 32) do
                query.candidates[i] = { incident = b.candidates[i], reason = b.reasons[i] }
            end
        end
        local navigation
        if navigationDecision.snapshotValid and navigationDecision.car == carIndex then
            navigation = { session = navigationDecision.session, generation = navigationDecision.generation,
                assignedIncident = navigationDecision.assignedIncident, assignedCar = navigationDecision.assignedCar,
                comparedIncident = navigationDecision.comparedIncident, comparedCar = navigationDecision.comparedCar,
                assignmentOrigin = navigationDecision.assignmentOrigin, matchesQuery = navigationDecision.matchesQuery,
                querySequence = navigationDecision.querySequence }
        end
        if query == nil and navigation == nil then return nil end
        local identity = query or navigation
        return { car = carIndex, session = identity and identity.session,
            generation = identity and identity.generation,
            query = query, navigation = navigation }
    end)
    if ok then return result end
    return nil
end

function AccidentManager.resetSession()
    recoveryLastClock = nil
    for index in pairs(decisionLastReason) do decisionLastReason[index] = nil end
    for index in pairs(rejectionCounts) do rejectionCounts[index] = nil end
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
        AccidentManager.accidents_pitManoeuvre[accidentIndex] = nil
        AccidentManager.accidents_sessionGeneration[accidentIndex] = nil
        AccidentManager.accidents_culpritIsInPitlane[accidentIndex] = nil
        AccidentManager.accidents_victimIsInPitlane[accidentIndex] = nil
        AccidentManager.accidents_culpritSpeedKmh[accidentIndex] = nil
        AccidentManager.accidents_victimSpeedKmh[accidentIndex] = nil
        accidentsRecoveryElapsed[accidentIndex] = nil
        accidentsRecoveryPreviousValid[accidentIndex] = nil
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
    accidentDecision.snapshotValid = false
    if not car then return nil, -1 end
    local queriedCarIndex = car.index
    local carSplinePosition = car.splinePosition
    local carWorldPosition = car.position
    if not finiteNumber(queriedCarIndex) or queriedCarIndex < 0 or queriedCarIndex % 1 ~= 0
      or not finiteNumber(carSplinePosition) or carSplinePosition < 0 or carSplinePosition > 1
      or not validWorldPosition(carWorldPosition) or not finiteNumber(distanceToDetectAccident)
      or distanceToDetectAccident < 0 then
        observeDecisionChange(queriedCarIndex, 'invalid-query')
        return nil, -1
    end
    local distanceToDetectAccidentSqr = distanceToDetectAccident * distanceToDetectAccident
    if not finiteNumber(distanceToDetectAccidentSqr) then
        observeDecisionChange(queriedCarIndex, 'invalid-query')
        return nil, -1
    end
    local trackLength = RaceTrackManager.getTrackLengthMeters()
    if not finiteNumber(trackLength) or trackLength <= 0 then
        observeDecisionChange(queriedCarIndex, 'invalid-query')
        return nil, -1
    end
    local lastAccidentIndexCreated = CompletableIndexCollectionManager.getLastIndexCreated(accidentCompletableIndex)
    if lastAccidentIndexCreated == 0 then
        observeDecisionChange(queriedCarIndex, 'no-incidents')
        if car and type(car.index) == 'number' then
            local lookupOK, logger = pcall(rawget, _G, 'Logger')
            if lookupOK and type(logger) == 'table' then
                local enabledOK, enabled = pcall(rawget, logger, 'OBS1_ENABLED')
                local focusOK, focus = pcall(rawget, logger, 'OBS1_FOCUS_CAR')
                if enabledOK and focusOK and enabled == true and focus == car.index then
                    accidentDecision.snapshotValid = false
                    pcall(recordAccidentDecisionProtected, car.index, car.splinePosition, 0, 0, nil, -1)
                end
            end
        end
        return nil, -1
    end

    local capture = false
    local captureCarIndex = queriedCarIndex
    local loggerOK, logger = pcall(rawget, _G, 'Logger')
    if loggerOK and type(logger) == 'table' then
        local enabledOK, enabled = pcall(rawget, logger, 'OBS1_ENABLED')
        local focusOK, focus = pcall(rawget, logger, 'OBS1_FOCUS_CAR')
        capture = enabledOK and focusOK and enabled == true and focus == captureCarIndex
    end
    if capture then accidentDecision.snapshotValid = false end
    local examined, capturedCount = 0, 0

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
    local currentClosestAccidentClosestCarSplineDistance = math.huge
    local currentClosestAccidentReason, lastExaminedReason

     -- for i = 1, lastAccidentIndexCreated do
    local firstNonResolvedAccidentIndex = CompletableIndexCollectionManager.getFirstNonResolvedIndex(accidentCompletableIndex)
    for accidentIndex = firstNonResolvedAccidentIndex, lastAccidentIndexCreated do
        if not AccidentManager.accidents_resolved[accidentIndex]
          and AccidentManager.accidents_pitManoeuvre[accidentIndex] ~= true then
            examined = examined + 1
            local candidateReason = 'not-selected'
            local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
            local victimCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
            local queriedCarIndex = car.index
            local culpritGenerationIsCurrent = accidentCulpritGeneration[accidentIndex] == CarManager.getCarGeneration(culpritCarIndex)
            local victimGenerationIsCurrent = victimCarIndex == nil or accidentVictimGeneration[accidentIndex] == CarManager.getCarGeneration(victimCarIndex)
            if not culpritGenerationIsCurrent or not victimGenerationIsCurrent then
                candidateReason = 'stale-generation'
                setAccidentAsResolved(accidentIndex)
            elseif culpritCarIndex ~= queriedCarIndex and victimCarIndex ~= queriedCarIndex then
            local culpritCar = ac.getCar(culpritCarIndex)
            local victimCar = ac.getCar(victimCarIndex)

                local closestCarSplineDistance = math.huge
                local closestCar = nil
                candidateReason = 'no-eligible-car'

                if culpritCar and culpritCarIndex ~= queriedCarIndex then
                -- make sure the culprit car is ahead of us
                local culpritCarSplinePosition = culpritCar.splinePosition
                    local culpritForward = forwardSplineDistance(carSplinePosition, culpritCarSplinePosition)
                    if culpritForward then
                    -- make sure the culprit car is within the distance to detect an accident
                    local culpritCarWorldPosition = culpritCar.position
                    -- local distanceFromOurCarToCulpritCar = (culpritCarWorldPosition - carWorldPosition):length()
                    -- local distanceFromOurCarToCulpritCar = MathHelpers.distanceBetweenVec3s(carWorldPosition, culpritCarWorldPosition)
                    local distanceOK, distanceFromOurCarToCulpritCarSqr = pcall(MathHelpers.distanceBetweenVec3sSqr, carWorldPosition, culpritCarWorldPosition)
                    -- if distanceFromOurCarToCulpritCar < distanceToDetectAccident then
                        if distanceOK and distanceFromOurCarToCulpritCarSqr and distanceFromOurCarToCulpritCarSqr == distanceFromOurCarToCulpritCarSqr
                          and distanceFromOurCarToCulpritCarSqr >= 0 and distanceFromOurCarToCulpritCarSqr < distanceToDetectAccidentSqr then
                            closestCarSplineDistance = culpritForward * trackLength
                            closestCar = culpritCar
                            candidateReason = 'culprit-eligible'
                        else
                            candidateReason = 'culprit-outside-radius'
                        end
                    else
                        candidateReason = 'culprit-not-ahead'
                    end
                end

            if victimCar and victimCarIndex ~= queriedCarIndex then
                -- make sure the victim car is ahead of us
                local victimCarSplinePosition = victimCar.splinePosition
                local victimForward = forwardSplineDistance(carSplinePosition, victimCarSplinePosition)
                if victimForward then
                    -- make sure the victim car is within the distance to detect an accident
                    local victimCarWorldPosition = victimCar.position
                    -- local distanceFromOurCarToVictimCar = MathHelpers.distanceBetweenVec3s(carWorldPosition, victimCarWorldPosition)
                    local distanceOK, distanceFromOurCarToVictimCarSqr = pcall(MathHelpers.distanceBetweenVec3sSqr, carWorldPosition, victimCarWorldPosition)
                    -- if distanceFromOurCarToVictimCar < distanceToDetectAccident then
                    if distanceOK and distanceFromOurCarToVictimCarSqr and distanceFromOurCarToVictimCarSqr == distanceFromOurCarToVictimCarSqr
                      and distanceFromOurCarToVictimCarSqr >= 0 and distanceFromOurCarToVictimCarSqr < distanceToDetectAccidentSqr then
                        -- if the victim car is closer than the culprit car, use the victim car as the closest car
                        local victimCarSplineDistance = victimForward * trackLength
                        if victimCarSplineDistance < closestCarSplineDistance then
                            closestCarSplineDistance = victimCarSplineDistance
                            closestCar = victimCar
                            candidateReason = 'victim-eligible'
                        end
                    else
                        candidateReason = 'victim-outside-radius'
                    end
                else
                    candidateReason = 'victim-not-ahead'
                end
            end

            -- if from this accident we found the closest car to us, check if closest car of this accident is closer than the closest car of previous accidents we iterated
            if closestCar then
                candidateReason = 'eligible'
                -- if we haven't yet saved a closest accident, use this accident as the closest accident
                if not currentClosestAccidentIndex then
                    currentClosestAccidentIndex = accidentIndex
                    currentClosestAccidentClosestCarIndex = closestCar.index
                    currentClosestAccidentClosestCarSplineDistance = closestCarSplineDistance
                    currentClosestAccidentReason = candidateReason
                else
                    if closestCarSplineDistance < currentClosestAccidentClosestCarSplineDistance then
                        currentClosestAccidentIndex = accidentIndex
                        currentClosestAccidentClosestCarIndex = closestCar.index
                        currentClosestAccidentClosestCarSplineDistance = closestCarSplineDistance
                        currentClosestAccidentReason = candidateReason
                    end
                end
            end
            end
            if culpritCarIndex == queriedCarIndex or victimCarIndex == queriedCarIndex then
                candidateReason = 'query-car-participant'
            end
            lastExaminedReason = candidateReason
            if capture and capturedCount < 32 then
                capturedCount = capturedCount + 1
                accidentDecision.candidates[capturedCount] = accidentIndex
                accidentDecision.reasons[capturedCount] = candidateReason
            end
        end
    end

    local decisionReason
    if currentClosestAccidentIndex ~= nil then
        decisionReason = currentClosestAccidentReason or 'eligible'
    elseif examined > 0 then
        decisionReason = lastExaminedReason or 'no-eligible-car'
    else
        decisionReason = 'no-incidents'
    end
    observeDecisionChange(queriedCarIndex, decisionReason)

    if capture then
        pcall(recordAccidentDecisionProtected, captureCarIndex, carSplinePosition, examined, capturedCount,
            currentClosestAccidentIndex, currentClosestAccidentClosestCarIndex)
    end

    return currentClosestAccidentIndex, currentClosestAccidentClosestCarIndex
end

return AccidentManager
