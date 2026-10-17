local RaceTrackManager = {}

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

    -- start by using the culprit car's spline position
    local culpritCarIndex = AccidentManager.accidents_carIndex[accidentIndex]
    local culpritCar = ac.getCar(culpritCarIndex)
    if culpritCar then
        local culpritCarSplinePosition = culpritCar.splinePosition
        closestSplinePosition = culpritCarSplinePosition
        furthestSplinePosition = culpritCarSplinePosition
    end

    -- if there's a collided-with car, check its spline position too and use the furthest one of the two
    local collidedWithCarIndex = AccidentManager.accidents_collidedWithCarIndex[accidentIndex]
    if collidedWithCarIndex then
        local collidedWithCar = ac.getCar(collidedWithCarIndex)
        if collidedWithCar then
            local collidedWithCarSplinePosition = collidedWithCar.splinePosition
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
local getYellowZoneBucketIndex = function(splinePosition)
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

    addYellowFlagZoneToBuckets(yellowFlagZoneIndex, yellowZoneStartSplinePosition, yellowZoneEndSplinePosition)

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
        end
    end
end
--- Removes a yellow flag zone
---@param yellowFlagZoneIndex number
RaceTrackManager.removeYellowFlagZone = function(yellowFlagZoneIndex)
    removeYellowFlagZoneFromBuckets(yellowFlagZoneIndex, yellowZones_startSplinePosition[yellowFlagZoneIndex], yellowZones_endSplinePosition[yellowFlagZoneIndex])

    yellowZones_startSplinePosition[yellowFlagZoneIndex] = nil
    yellowZones_endSplinePosition[yellowFlagZoneIndex] = nil
    yellowZones_accidentIndex[yellowFlagZoneIndex] = nil

    yellowZones_resolved[yellowFlagZoneIndex] = true
    CompletableIndexCollectionManager.updateFirstNonResolvedIndex(yellowZonesCompletableIndex, yellowZones_resolved)
end

---Returns a boolean value indicating whether the given spline position is inside any active yellow flag zone.
---O(1) bucket lookup plus a check against the few zones registered in that bucket
---@param splinePosition number
---@return boolean
RaceTrackManager.isSplinePositionInYellowZone = function(splinePosition)
    local bucket = RaceTrackManager.yellowFlagsZones_bucket[getYellowZoneBucketIndex(splinePosition)]
    if bucket == nil then
        return false
    end

    for i = 1, #bucket do
        local yellowFlagZoneIndex = bucket[i]
        local yellowZoneResolved = yellowZones_resolved[yellowFlagZoneIndex]
        if yellowZoneResolved == false then
            local yellowZoneStartSplinePosition = yellowZones_startSplinePosition[yellowFlagZoneIndex]
            local yellowZoneEndSplinePosition = yellowZones_endSplinePosition[yellowFlagZoneIndex]

            if yellowZoneStartSplinePosition < yellowZoneEndSplinePosition then
                -- normal case, zone does not wrap around the 0.0/1.0 point
                if splinePosition >= yellowZoneStartSplinePosition and splinePosition <= yellowZoneEndSplinePosition then
                    return true
                end
            else
                -- zone wraps around the 0.0/1.0 point
                if (splinePosition >= yellowZoneStartSplinePosition and splinePosition <= 1.0) or (splinePosition >= 0.0 and splinePosition <= yellowZoneEndSplinePosition) then
                    return true
                end
            end
        end
    end

    return false
end

return RaceTrackManager