local RaceTrackManager = {}
local rawget, type, pcall = rawget, type, pcall
local function observe(...)
    local lookupOK, logger = pcall(rawget, _G, 'Logger')
    if not lookupOK then return end
    local observeOK, fn = pcall(rawget, logger, 'observe')
    if not observeOK then return end
    if type(fn) == 'function' then pcall(fn, ...) end
end

---The names of the different session types
--- @type table<ac.SessionType, string>
local SESSION_TYPE_NAMES = {
    [ac.SessionType.Undefined] = "Undefined",
    [ac.SessionType.Practice] = "Practice",
    [ac.SessionType.Qualify] = "Qualify",
    [ac.SessionType.Race] = "Race",
    [ac.SessionType.Hotlap] = "Hotlap",
    [ac.SessionType.TimeAttack] = "TimeAttack",
    [ac.SessionType.Drift] = "Drift",
    [ac.SessionType.Drag] = "Drag",
}

local yellowZonesCompletableIndex = CompletableIndexCollectionManager.createNewIndex()

---Size (as a fraction of the track's spline span) of each bucket used to index active yellow flag zones
local YELLOW_ZONE_BUCKET_SIZE = 0.05
---Number of buckets needed to cover the whole spline (0.0 to 1.0)
local YELLOW_ZONE_BUCKET_COUNT = math.ceil(1.0 / YELLOW_ZONE_BUCKET_SIZE)

local yellowZones_startSplinePosition = {}
local yellowZones_endSplinePosition = {}
local yellowZones_accidentIndex = {}
local yellowZones_resolved = {}
local getYellowZoneBucketIndex
local yellowZoneEpoch, yellowZoneRevision = 1, 0
local yellowDecisionBuffer = { candidates = {} }
-- Numeric sequence is correlation-only (integer precision ends at 2^53); freshness uses validity, identity and zone revision/epoch.
local zoneDecisionSequence = 0
for i = 1, 32 do
    yellowDecisionBuffer.candidates[i] = {}
end
local function bumpZoneRevision() yellowZoneRevision = yellowZoneRevision + 1 end
local function recordYellowDecisionProtected(carIndex, splinePosition, examined, candidateCount, chosen)
    local session = CarManager and CarManager.sessionGeneration
    local generation = CarManager and CarManager.getCarGeneration(carIndex)
    zoneDecisionSequence = zoneDecisionSequence + 1
    yellowDecisionBuffer.car = carIndex
    yellowDecisionBuffer.session = session
    yellowDecisionBuffer.generation = generation
    yellowDecisionBuffer.spline = splinePosition
    yellowDecisionBuffer.examined = examined
    yellowDecisionBuffer.limited = examined > 32
    yellowDecisionBuffer.chosenZone = chosen
    yellowDecisionBuffer.matched = chosen ~= nil
    yellowDecisionBuffer.sequence = zoneDecisionSequence
    yellowDecisionBuffer.consumer, yellowDecisionBuffer.stateReturned = nil, nil
    yellowDecisionBuffer.candidateCount = math.min(candidateCount, 32)
    yellowDecisionBuffer.epoch, yellowDecisionBuffer.revision = yellowZoneEpoch, yellowZoneRevision
    yellowDecisionBuffer.queryValid = true
    yellowDecisionBuffer.snapshotValid = true
end
local function readZoneAccidentIndexProtected(zoneIndex)
    return yellowZones_accidentIndex[zoneIndex]
end
local function getYellowZoneReadOnlyProtected(zoneID)
    if type(zoneID) ~= 'number' or zoneID ~= zoneID or zoneID <= 0
      or zoneID >= math.huge or zoneID % 1 ~= 0 then return nil end
    local startSplinePosition = yellowZones_startSplinePosition[zoneID]
    local resolved = yellowZones_resolved[zoneID]
    if startSplinePosition == nil and resolved ~= true then return nil end
    return { zone = zoneID, incident = yellowZones_accidentIndex[zoneID],
      startSplinePosition = startSplinePosition, endSplinePosition = yellowZones_endSplinePosition[zoneID],
      resolved = resolved }
end

function RaceTrackManager.getYellowZoneReadOnly(zoneID)
    local ok, result = pcall(getYellowZoneReadOnlyProtected, zoneID)
    if ok then return result end
    return nil
end

local function validCarIndex(carIndex)
    return type(carIndex) == 'number' and carIndex == carIndex and carIndex >= 0
      and carIndex < math.huge and carIndex % 1 == 0
end

function RaceTrackManager.getYellowZoneInventoryReadOnly(cursor, epoch, revision)
    local ok, result = pcall(function()
        local last = CompletableIndexCollectionManager.getLastIndexCreated(yellowZonesCompletableIndex)
        local restarted = false
        if cursor == nil then cursor = 1 end
        if type(cursor) ~= 'number' or cursor ~= cursor or cursor < 1 or cursor % 1 ~= 0 then cursor = 1; restarted = true end
        if (epoch ~= nil and epoch ~= yellowZoneEpoch) or (revision ~= nil and revision ~= yellowZoneRevision) then
            cursor, restarted = 1, true
        end
        local zones, count, scanned = {}, 0, 0
        local id = cursor
        while id <= last and scanned < 32 do
            scanned = scanned + 1
            local start = yellowZones_startSplinePosition[id]
            if start ~= nil or yellowZones_resolved[id] == true then
                count = count + 1
                zones[count] = { zone = id, incident = yellowZones_accidentIndex[id],
                    startSplinePosition = start, endSplinePosition = yellowZones_endSplinePosition[id],
                    resolved = yellowZones_resolved[id] }
            end
            id = id + 1
        end
        return { zones = zones, cursor = cursor, nextCursor = id <= last and id or nil,
            scanned = scanned, complete = id > last, epoch = yellowZoneEpoch,
            revision = yellowZoneRevision, session = CarManager and CarManager.sessionGeneration,
            restarted = restarted }
    end)
    if ok then return result end
    return nil
end

function RaceTrackManager.getYellowZoneCoverageReadOnly(splinePosition)
    local ok, result = pcall(function()
        if type(splinePosition) ~= 'number' or splinePosition ~= splinePosition
          or splinePosition == math.huge or splinePosition == -math.huge then return nil end
        local bucket = RaceTrackManager.yellowFlagsZones_bucket[getYellowZoneBucketIndex(splinePosition)]
        local zones, candidates, count, candidateCount, scanned = {}, {}, 0, 0, 0
        local total = bucket and #bucket or 0
        local limit = math.min(total, 32)
        for i = 1, limit do
            scanned = scanned + 1
            local id = bucket[i]
            local start, finish = yellowZones_startSplinePosition[id], yellowZones_endSplinePosition[id]
            local resolved = yellowZones_resolved[id]
            local match = false
            if resolved == false and start ~= nil and finish ~= nil then
                if start < finish then match = splinePosition >= start and splinePosition <= finish
                else match = (splinePosition >= start and splinePosition <= 1.0) or (splinePosition >= 0.0 and splinePosition <= finish) end
            end
            if start ~= nil or resolved == true then
                count = count + 1
                zones[count] = { zone = id, incident = yellowZones_accidentIndex[id], startSplinePosition = start,
                    endSplinePosition = finish, resolved = resolved }
            end
            if match then
                candidateCount = candidateCount + 1
                candidates[candidateCount] = { zone = id, incident = yellowZones_accidentIndex[id],
                    startSplinePosition = start, endSplinePosition = finish, resolved = false }
            end
        end
        local limited = total > limit
        local covered
        if candidateCount > 0 then covered = true elseif not limited then covered = false end
        return { zones = zones, candidates = candidates, scanned = scanned, total = total,
            limited = limited, covered = covered, epoch = yellowZoneEpoch, revision = yellowZoneRevision,
            session = CarManager and CarManager.sessionGeneration }
    end)
    if ok then return result end
    return nil
end

function RaceTrackManager.getYellowZoneDecisionReadOnly(carIndex)
    local ok, result = pcall(function()
        if not validCarIndex(carIndex) then return nil end
        local b = yellowDecisionBuffer
        if not b.snapshotValid or b.car == nil or b.car ~= carIndex then return nil end
        local snapshot = { car = b.car, session = b.session, generation = b.generation, spline = b.spline,
            candidates = {}, examined = b.examined, limited = b.limited, chosenZone = b.chosenZone,
            matched = b.matched, sequence = b.sequence, consumer = b.consumer, stateReturned = b.stateReturned,
            epoch = b.epoch, revision = b.revision }
        for i = 1, math.min(b.candidateCount or 0, 32) do
            local source = b.candidates[i]
            snapshot.candidates[i] = { zone = source.zone, incident = source.incident }
        end
        return snapshot
    end)
    if ok then return result end
    return nil
end

local function isYellowCaptureFocusedProtected(carIndex)
    local logger = rawget(_G, 'Logger')
    return type(logger) == 'table' and rawget(logger, 'OBS1_ENABLED') == true
        and rawget(logger, 'OBS1_FOCUS_CAR') == carIndex
end

local function markYellowZoneConsumptionProtected(carIndex, state)
    local b = yellowDecisionBuffer
    if not b.queryValid then return end
    b.queryValid = false
    if b.car ~= carIndex or not b.matched
      or b.epoch ~= yellowZoneEpoch or b.revision ~= yellowZoneRevision
      or not isYellowCaptureFocusedProtected(carIndex) then return end
    local session = CarManager and CarManager.sessionGeneration
    local generation = CarManager and CarManager.getCarGeneration(carIndex)
    if session == nil or generation == nil or session ~= b.session or generation ~= b.generation then return end
    b.consumer, b.stateReturned = 'fsm-handle-yellow', state
end

function RaceTrackManager.markYellowZoneConsumption(carIndex, state)
    pcall(markYellowZoneConsumptionProtected, carIndex, state)
end

---Bucket index -> list of active yellow flag zone indices covering that bucket's spline span.
---Used to look up active yellow flag zones in O(1) + O(zones per bucket) instead of O(active zones).
RaceTrackManager.yellowFlagsZones_bucket = {}

---@enum RaceTrackManager.TrackSide 
RaceTrackManager.TrackSide = {
    LEFT = 1,
    RIGHT = 2,
}

RaceTrackManager.TrackSideStrings = {
    [RaceTrackManager.TrackSide.LEFT] = "Left",
    [RaceTrackManager.TrackSide.RIGHT] = "Right",
}

--- Mapping of TrackSide to lateral offset sign
--- Used in RaceTrackManager.getLateralOffsetSign 
local lateralOffsetSigns = {
    [RaceTrackManager.TrackSide.LEFT] = -1,
    [RaceTrackManager.TrackSide.RIGHT] = 1,
}

local sim = ac.getSim()
local TRACK_NAME = ac.getTrackName()
local TRACK_LENGTH_METERS = sim.trackLengthM
local SESSION_TYPE = sim.raceSessionType
local SESSION_TYPE_NAME = SESSION_TYPE_NAMES[SESSION_TYPE] or "Unknown"

--- Returns the total track length in meters
---@return number trackLength_meters
RaceTrackManager.getTrackLengthMeters = function()
    return TRACK_LENGTH_METERS
end


RaceTrackManager.getTrackName = function()
    return TRACK_NAME
end

RaceTrackManager.getSessionTypeName = function()
    return SESSION_TYPE_NAME
end

--- Converts a spline span value representing a fraction of the track length (0..1) to meters
--- Example: 0.5 = half the track length, 0.25 = quarter of the track length
---@param splineValue number
---@return number
RaceTrackManager.splineSpanToMeters = function(splineValue)
    return splineValue * TRACK_LENGTH_METERS
end

---Converts a distance in meters to a spline span value representing a fraction of the track length (0..1)
---Example: 200m on a 1000m track = 0.2
---@param meters number
---@return number
RaceTrackManager.metersToSplineSpan = function(meters)
    return meters / TRACK_LENGTH_METERS
end

--- Returns RIGHT if given LEFT and vice versa
---@param side RaceTrackManager.TrackSide
---@return RaceTrackManager.TrackSide
RaceTrackManager.getOppositeSide = function(side)
    if side == RaceTrackManager.TrackSide.LEFT then
        return RaceTrackManager.TrackSide.RIGHT
    end

    return RaceTrackManager.TrackSide.LEFT
end

---Returns the yielding side as configured in the settings
---@return RaceTrackManager.TrackSide yieldSide
RaceTrackManager.getYieldingSide = function()
    local storage = StorageManager.getStorage()
    -- local yieldSide = storage.yieldSide
    local yieldingLateralOffset = storage.yieldingLateralOffset
    local yieldSide = RaceTrackManager.getSideFromLateralOffset(yieldingLateralOffset)
    return yieldSide
end

---Returns the overtaking side as configured in the settings
---@return RaceTrackManager.TrackSide overtakingSide
RaceTrackManager.getOvertakingSide = function()
    -- local yieldSide = RaceTrackManager.getYieldingSide()
    -- local overtakingSide = RaceTrackManager.getOppositeSide(yieldSide)
    local storage = StorageManager.getStorage()
    local overtakingLateralOffset = storage.overtakingLateralOffset
    local overtakingSide = RaceTrackManager.getSideFromLateralOffset(overtakingLateralOffset)
    return overtakingSide
end

---Returns the default driving side as configured in the settings
---@return RaceTrackManager.TrackSide defaultDrivingSide
RaceTrackManager.getDefaultDrivingSide = function()
    local storage = StorageManager.getStorage()
    local defaultDrivingLateralOffset = storage.defaultLateralOffset
    local defaultDrivingSide = RaceTrackManager.getSideFromLateralOffset(defaultDrivingLateralOffset)
    return defaultDrivingSide
end

---Returns the side of the track based on the lateral offset
---@param lateralOffset number
---@return RaceTrackManager.TrackSide
RaceTrackManager.getSideFromLateralOffset = function(lateralOffset)
    return lateralOffset < 0 and RaceTrackManager.TrackSide.LEFT or RaceTrackManager.TrackSide.RIGHT
end

---@param side RaceTrackManager.TrackSide
---@return integer
RaceTrackManager.getLateralOffsetSign = function(side)
    return lateralOffsetSigns[side]
end

-- local calculateYellowFlagZoneStartSplinePosition = function(yellowZoneEndSplinePosition)
    -- -- todo : this function is not good
    -- local storage = StorageManager.getStorage()
    -- local yellowZoneSizeMeters = storage.distanceFromAccidentToSeeYellowFlag_meters
    -- local yellowZoneSizeNormalized = yellowZoneSizeMeters / trackLength_meters

    -- local yellowZoneStartSplinePosition = yellowZoneEndSplinePosition - yellowZoneSizeNormalized
    -- if yellowZoneStartSplinePosition < 0 then
        -- yellowZoneStartSplinePosition = yellowZoneStartSplinePosition + 1.0
    -- end

    -- return yellowZoneStartSplinePosition
-- end

local getYellowZoneSizeNormalized = function()
    local storage = StorageManager.getStorage()
    local yellowZoneSizeMeters = storage.distanceFromAccidentToSeeYellowFlag_meters
    local yellowZoneSizeNormalized = yellowZoneSizeMeters / TRACK_LENGTH_METERS
    return yellowZoneSizeNormalized
end

local calculateYellowFlagZoneStartEndPositions = function(accidentIndex, yellowZoneSizeNormalized)
    local closestSplinePosition
    local furthestSplinePosition

    -- Use the event-time culprit observation first; it is immutable across dequeue.
    closestSplinePosition = AccidentManager.accidents_splinePosition[accidentIndex]
    furthestSplinePosition = closestSplinePosition

    -- if there's a collided-with car, check its spline position too and use the furthest one of the two
    local collidedWithCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
    if collidedWithCarIndex then
        local collidedWithCarSplinePosition = AccidentManager.accidents_victimSplinePosition[accidentIndex]
        if collidedWithCarSplinePosition ~= nil then
            if collidedWithCarSplinePosition > furthestSplinePosition then
                furthestSplinePosition = collidedWithCarSplinePosition
            else 
                closestSplinePosition = collidedWithCarSplinePosition
            end
        end
    end

    local yellowZoneStartSplinePosition = closestSplinePosition - yellowZoneSizeNormalized
    local yellowZoneEndSplinePosition = furthestSplinePosition

    if yellowZoneStartSplinePosition < 0 then
        yellowZoneStartSplinePosition = yellowZoneStartSplinePosition + 1.0
    end

    return yellowZoneStartSplinePosition, yellowZoneEndSplinePosition
end

---Returns the bucket index for the given (cyclic 0.0..1.0) spline position
---@param splinePosition number
---@return integer
getYellowZoneBucketIndex = function(splinePosition)
    local bucketIndex = math.floor(splinePosition / YELLOW_ZONE_BUCKET_SIZE)
    if bucketIndex < 0 then
        bucketIndex = 0
    elseif bucketIndex >= YELLOW_ZONE_BUCKET_COUNT then
        -- the spline position wraps around: 1.0 is the same point as 0.0
        bucketIndex = YELLOW_ZONE_BUCKET_COUNT - 1
    end
    return bucketIndex
end

---Calls the given callback for every bucket index covered by a yellow flag zone's span.
---Handles zones that wrap around the 0.0/1.0 spline point.
---@param yellowZoneStartSplinePosition number
---@param yellowZoneEndSplinePosition number
---@param callback fun(bucketIndex: integer)
local forEachYellowZoneBucketIndex = function(yellowZoneStartSplinePosition, yellowZoneEndSplinePosition, callback)
    local startBucketIndex = getYellowZoneBucketIndex(yellowZoneStartSplinePosition)
    local endBucketIndex = getYellowZoneBucketIndex(yellowZoneEndSplinePosition)

    if yellowZoneStartSplinePosition <= yellowZoneEndSplinePosition then
        -- normal case, zone does not wrap around the 0.0/1.0 point
        for bucketIndex = startBucketIndex, endBucketIndex do
            callback(bucketIndex)
        end
    else
        -- zone wraps around the 0.0/1.0 point, populate both ranges of buckets
        for bucketIndex = startBucketIndex, YELLOW_ZONE_BUCKET_COUNT - 1 do
            callback(bucketIndex)
        end
        for bucketIndex = 0, endBucketIndex do
            callback(bucketIndex)
        end
    end
end

---Adds the given yellow flag zone to every bucket covered by its span
---@param yellowFlagZoneIndex number
---@param yellowZoneStartSplinePosition number
---@param yellowZoneEndSplinePosition number
local addYellowFlagZoneToBuckets = function(yellowFlagZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition)
    forEachYellowZoneBucketIndex(yellowZoneStartSplinePosition, yellowZoneEndSplinePosition, function(bucketIndex)
        local bucket = RaceTrackManager.yellowFlagsZones_bucket[bucketIndex]
        if bucket == nil then
            bucket = {}
            RaceTrackManager.yellowFlagsZones_bucket[bucketIndex] = bucket
        end
        bucket[#bucket + 1] = yellowFlagZoneIndex
    end)
end

---Removes the given yellow flag zone from every bucket covered by its span
---@param yellowFlagZoneIndex number
---@param yellowZoneStartSplinePosition number
---@param yellowZoneEndSplinePosition number
local removeYellowFlagZoneFromBuckets = function(yellowFlagZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition)
    forEachYellowZoneBucketIndex(yellowZoneStartSplinePosition, yellowZoneEndSplinePosition, function(bucketIndex)
        local bucket = RaceTrackManager.yellowFlagsZones_bucket[bucketIndex]
        if bucket ~= nil then
            for i = #bucket, 1, -1 do
                if bucket[i] == yellowFlagZoneIndex then
                    table.remove(bucket, i)
                end
            end
            if #bucket == 0 then
                RaceTrackManager.yellowFlagsZones_bucket[bucketIndex] = nil
            end
        end
    end)
end

---Creates a new yellow flag zone ending at the given spline position and extending backwards by the configured distance
---@param accidentIndex number
---@return number yellowFlagZoneIndex
-- RaceTrackManager.declareYellowFlagZone = function(yellowZoneEndSplinePosition, accidentIndex)
RaceTrackManager.declareYellowFlagZone = function(accidentIndex)

    -- Calculate the start and end spline positions based on the accident's cars' positions
    local yellowZoneSizeNormalized = getYellowZoneSizeNormalized()
    local yellowZoneStartSplinePosition, yellowZoneEndSplinePosition = calculateYellowFlagZoneStartEndPositions(accidentIndex, yellowZoneSizeNormalized)

    local yellowFlagZoneIndex = CompletableIndexCollectionManager.incrementLastIndexCreated(yellowZonesCompletableIndex)
    yellowZones_startSplinePosition[yellowFlagZoneIndex] = yellowZoneStartSplinePosition
    yellowZones_endSplinePosition[yellowFlagZoneIndex] = yellowZoneEndSplinePosition
    yellowZones_accidentIndex[yellowFlagZoneIndex] = accidentIndex
    yellowZones_resolved[yellowFlagZoneIndex] = false
    bumpZoneRevision()

    addYellowFlagZoneToBuckets(yellowFlagZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition)
    observe('zone-created', nil, nil, accidentIndex, yellowFlagZoneIndex, 'registered')

    Logger.log(string.format("[RaceTrackManager] Declared yellow flag zone #%d: start %.3f end %.3f", yellowFlagZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition))

    return yellowFlagZoneIndex
end

-- TODO: THIS METHOD STILL NEEDS TO BE TESTED AND THEN USED, for example in updateYellowFlagZones()
RaceTrackManager.isSplinePosition1FurtherThanSplinePosition2 = function(splinePosition1, splinePosition2)
    -- splinePositions are normalized 0.0-1.0 values
    -- this function also needs to handle the case where the spline positions wrap around the 0.0/1.0 point

    if splinePosition1 >= splinePosition2 then
        return (splinePosition1 - splinePosition2) < 0.5
    else
        return (splinePosition2 - splinePosition1) > 0.5
    end
end

RaceTrackManager.updateYellowFlagZones = function()
    local lastYellowZoneIndexCreated = CompletableIndexCollectionManager.getLastIndexCreated(yellowZonesCompletableIndex)
    if lastYellowZoneIndexCreated == 0 then
        return false
    end

    local yellowZoneSizeNormalized = getYellowZoneSizeNormalized()

    -- go through all non-resolved yellow zones and update their end spline position based on the furthest spline position of the accident cars
    local firstNonResolvedYellowZoneIndex = CompletableIndexCollectionManager.getFirstNonResolvedIndex(yellowZonesCompletableIndex)
    for yellowZoneIndex = firstNonResolvedYellowZoneIndex, lastYellowZoneIndexCreated do
        local yellowZoneResolved = yellowZones_resolved[yellowZoneIndex]
        if yellowZoneResolved == false then
            local accidentIndex = yellowZones_accidentIndex[yellowZoneIndex]

            local previousStartSplinePosition = yellowZones_startSplinePosition[yellowZoneIndex]
            local previousEndSplinePosition = yellowZones_endSplinePosition[yellowZoneIndex]

            -- recalculate start and end spline positions
            local yellowZoneStartSplinePosition, yellowZoneEndSplinePosition = calculateYellowFlagZoneStartEndPositions(accidentIndex, yellowZoneSizeNormalized)

            -- re-index the zone's buckets since its span changed
            removeYellowFlagZoneFromBuckets(yellowZoneIndex, previousStartSplinePosition, previousEndSplinePosition)
            addYellowFlagZoneToBuckets(yellowZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition)

            yellowZones_startSplinePosition[yellowZoneIndex] = yellowZoneStartSplinePosition
            yellowZones_endSplinePosition[yellowZoneIndex] = yellowZoneEndSplinePosition
            if previousStartSplinePosition ~= yellowZoneStartSplinePosition
              or previousEndSplinePosition ~= yellowZoneEndSplinePosition then bumpZoneRevision() end
        end
    end
end
--- Removes a yellow flag zone
---@param yellowFlagZoneIndex number
RaceTrackManager.removeYellowFlagZone = function(yellowFlagZoneIndex)
    if yellowFlagZoneIndex == nil or yellowZones_startSplinePosition[yellowFlagZoneIndex] == nil then return false end
    local contextOK, accidentIndex = pcall(readZoneAccidentIndexProtected, yellowFlagZoneIndex)
    if not contextOK then accidentIndex = nil end
    removeYellowFlagZoneFromBuckets(yellowFlagZoneIndex, yellowZones_startSplinePosition[yellowFlagZoneIndex], yellowZones_endSplinePosition[yellowFlagZoneIndex])

    yellowZones_startSplinePosition[yellowFlagZoneIndex] = nil
    yellowZones_endSplinePosition[yellowFlagZoneIndex] = nil
    yellowZones_accidentIndex[yellowFlagZoneIndex] = nil

    yellowZones_resolved[yellowFlagZoneIndex] = true
    bumpZoneRevision()
    CompletableIndexCollectionManager.updateFirstNonResolvedIndex(yellowZonesCompletableIndex, yellowZones_resolved)
    observe('zone-removed', nil, nil, accidentIndex, yellowFlagZoneIndex, 'removed')
    return true
end

function RaceTrackManager.resetOwnedYellowFlagZones()
    observe('zone-reset', nil, nil, nil, nil, 'owned-zones-reset-requested')
    for zoneIndex = 1, CompletableIndexCollectionManager.getLastIndexCreated(yellowZonesCompletableIndex) do
        if yellowZones_resolved[zoneIndex] == false then RaceTrackManager.removeYellowFlagZone(zoneIndex) end
    end
    CompletableIndexCollectionManager.reset(yellowZonesCompletableIndex)
    yellowZoneEpoch = yellowZoneEpoch + 1
    bumpZoneRevision()
end

---Returns a boolean value indicating whether the given spline position is inside any active yellow flag zone.
---O(1) bucket lookup plus a check against the few zones registered in that bucket
---@param splinePosition number
---@return boolean
RaceTrackManager.isSplinePositionInYellowZone = function(splinePosition, optionalCarIndex)
    yellowDecisionBuffer.queryValid = false
    local bucket = RaceTrackManager.yellowFlagsZones_bucket[getYellowZoneBucketIndex(splinePosition)]
    local capture = false
    local lookupOK, logger = pcall(rawget, _G, 'Logger')
    if lookupOK and type(logger) == 'table' then
        local enabledOK, enabled = pcall(rawget, logger, 'OBS1_ENABLED')
        local focusOK, focus = pcall(rawget, logger, 'OBS1_FOCUS_CAR')
        capture = enabledOK and focusOK and enabled == true and optionalCarIndex ~= nil and focus == optionalCarIndex
    end
    if capture then yellowDecisionBuffer.snapshotValid = false end
    local capturedCount, examined, chosen = 0, 0, nil
    local limit = bucket and #bucket or 0
    for i = 1, limit do
        examined = examined + 1
        local yellowFlagZoneIndex = bucket[i]
        local yellowZoneResolved = yellowZones_resolved[yellowFlagZoneIndex]
        if capture and capturedCount < 32 then
            capturedCount = capturedCount + 1
            local candidate = yellowDecisionBuffer.candidates[capturedCount]
            candidate.zone = yellowFlagZoneIndex
            candidate.incident = yellowZones_accidentIndex[yellowFlagZoneIndex]
        end
        if yellowZoneResolved == false then
            local yellowZoneStartSplinePosition = yellowZones_startSplinePosition[yellowFlagZoneIndex]
            local yellowZoneEndSplinePosition = yellowZones_endSplinePosition[yellowFlagZoneIndex]

            if yellowZoneStartSplinePosition < yellowZoneEndSplinePosition then
                -- normal case, zone does not wrap around the 0.0/1.0 point
                if splinePosition >= yellowZoneStartSplinePosition and splinePosition <= yellowZoneEndSplinePosition then
                    chosen = yellowFlagZoneIndex
                    if capture then break end
                    return true
                end
            else
                -- zone wraps around the 0.0/1.0 point
                if (splinePosition >= yellowZoneStartSplinePosition and splinePosition <= 1.0) or (splinePosition >= 0.0 and splinePosition <= yellowZoneEndSplinePosition) then
                    chosen = yellowFlagZoneIndex
                    if capture then break end
                    return true
                end
            end
        end
    end
    if capture then
        pcall(recordYellowDecisionProtected, optionalCarIndex, splinePosition, examined, capturedCount, chosen)
    end
    return chosen ~= nil
end

return RaceTrackManager
