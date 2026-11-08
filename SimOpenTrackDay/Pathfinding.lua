-- Pathfinding.lua
-- Minimal, easy-to-read path sketcher.
-- It builds simple “fan” paths from the front of a car to target lateral offsets
-- normalized to the track width (configured below).
-- Lightweight collider check against other cars:
--   • Each sampled point along a path is checked against cars AHEAD from a sorted list you pass in.
--   • If any sample comes closer than a simple combined radius, the path is marked “blocked”.
-- Visualization reflects this state (green = clear, red = blocked).
--
-- NOTE: Keep this file intentionally simple and incremental as requested.

local Pathfinding = {}

local ac = ac
local ac_getCar = ac.getCar
local ac_worldCoordinateToTrack = ac.worldCoordinateToTrack
local ac_trackCoordinateToWorld = ac.trackCoordinateToWorld
local math = math
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_metersToSplineSpan = RaceTrackManager.metersToSplineSpan
local table = table
local table_insert = table.insert
local VecPool = VecPool
local VecPool_getTempVec3 = VecPool.getTempVec3
local GameTimeManager = GameTimeManager
local GameTimeManager_getPlayingGameTime = GameTimeManager.getPlayingGameTime


local storage_PathFinding = StorageManager.getStorage_PathFinding()

-- Tunables kept tiny on purpose. All distances are “roughly forward along the spline”.
-- local forwardDistanceMeters   = 60.0     -- how far forward the paths extend
-- local anchorAheadMeters       = 1.5      -- where the “fan” originates: a bit in front of the car
-- local numberOfPathSamples     = 12       -- samples per path for drawing
-- local maxAbsOffsetNormalized  = 1.0      -- clamp to track lateral limits for endpoints

-- Make paths split to the sides much earlier (for tight manoeuvres) without changing length:
-- We reach full lateral target by this forward distance (meters), with an ease-out power curve.
-- local splitReachMeters        = 12.0     -- distance at which lateral offset reaches 100%
-- local lateralSplitExponent    = 2.2      -- >1: earlier split; =1: linear; <1: later split

-- Very small and cheap collider model:
-- treat each car as a disc with this radius (meters), add a bit of margin.
-- local approxCarRadiusMeters   = 1.6
-- local safetyMarginMeters      = 0.5
-- local combinedCollisionRadius = (approxCarRadiusMeters * 2.0) + safetyMarginMeters
-- local combinedCollisionRadius2 = combinedCollisionRadius * combinedCollisionRadius

-- Helper: wrap track progress into [0..1].
local function wrap01(z)
  z = z % 1.0
  if z < 0.0 then z = z + 1.0 end
  return z
end

-- Minimal easing to split earlier: ease-out by power.
local function easeOutPow01(t, power)
  if power == 1.0 then return t end
  local inv = 1.0 - t
  return 1.0 - (inv ^ power)
end

-- Helper: meters → approximate progress fraction (fallback length).
-- local nominalTrackLengthMeters = RaceTrackManager.getTrackLengthMeters()
-- local function metersToProgress(meters)
  -- return meters / nominalTrackLengthMeters
-- end

-- =========================
-- Data-oriented containers
-- =========================

local PATHS_EDGE_OFFSET_N = 1.0  -- normalized offset for outermost paths
--local PATHS_EDGE_OFFSET_N = 0.9  -- normalized offset for outermost paths

-- PATHS ARE MODULE-WIDE (not per-car) so you can expand/reduce them without extra memory per car.
-- Modify this list to add/remove paths. All code below adapts automatically.
---@type table<integer,number>
-- local PATH_LATERAL_OFFSETS = { -PATHS_EDGE_OFFSET_N, -0.75, -0.5, 0.0, 0.5, 0.75, PATHS_EDGE_OFFSET_N }
local PATH_LATERAL_OFFSETS = { -0.75, -0.5, 0.0, 0.5, 0.75 }
-- local PATH_LATERAL_OFFSETS = {  -0.5, 0.0, 0.5 }
local TOTAL_PATH_LATERAL_OFFSETS = #PATH_LATERAL_OFFSETS

---@type table<integer,integer|nil>
local navigation_lastChosenPathIndex = {}

-- per-car array of counts per path
---@type table<integer,table<integer,integer>>
local navigation_pathsTotalSamples = {}

-- per-car array of blocked flags per path
---@type table<integer,table<integer,boolean>>
local navigation_pathsIsBlocked = {}

-- per-car array of hit sample indices per path
---@type table<integer,table<integer,integer>>
local navigation_pathsBlockedSampleIndex = {}

-- per-car array of hit other cars indices per path
---@type table<integer,table<integer,integer>>
local navigation_pathsBlockedOtherCarIndex = {}

-- per-car array of hit world positions per path
---@type table<integer,table<integer,vec3>>
local navigation_pathsBlockedSampleWorldPosition = {}

---@type table<integer,table<integer,integer>>
local navigation_pathsBlockedTimeSeconds = {}

-- per-car array of lists of sampled points per path
---@type table<integer,table<integer,table<integer,vec3>>>
local navigation_pathsSamplesWorldPositions = {}

-- Ensure per-car arrays exist and match the number of configured paths.
local function ensureCarArrays(carIndex)
  local pathsTotalSamples = navigation_pathsTotalSamples[carIndex]
  if not pathsTotalSamples or #pathsTotalSamples ~= TOTAL_PATH_LATERAL_OFFSETS then
    pathsTotalSamples = {}
    local blocked, hitIdx, hitOpp, hitPos, points, times = {}, {}, {}, {}, {}, {}
    for i = 1, TOTAL_PATH_LATERAL_OFFSETS do
      pathsTotalSamples[i] = 0
      blocked[i] = false
      hitIdx[i] = nil
      hitOpp[i] = nil
      hitPos[i] = nil
      points[i] = {}
      times[i] = nil
    end
    navigation_pathsTotalSamples[carIndex] = pathsTotalSamples
    navigation_pathsIsBlocked[carIndex] = blocked
    navigation_pathsBlockedSampleIndex[carIndex] = hitIdx
    navigation_pathsBlockedOtherCarIndex[carIndex] = hitOpp
    navigation_pathsBlockedSampleWorldPosition[carIndex] = hitPos
    navigation_pathsSamplesWorldPositions[carIndex] = points
    navigation_pathsBlockedTimeSeconds[carIndex] = times
  end

  -- TODO: Andreas: investigate why we need this part:
  -- keep sticky index if present; if it exceeds path count after a config change, drop it
  local lastChosenPathIndex = navigation_lastChosenPathIndex[carIndex]
  if lastChosenPathIndex and (lastChosenPathIndex < 1 or lastChosenPathIndex > TOTAL_PATH_LATERAL_OFFSETS) then
    navigation_lastChosenPathIndex[carIndex] = nil
  end
end

local isIntersectingSphere = function(carPosition, otherCarPosition, combinedCollisionRadius2)
  local dx = otherCarPosition.x - carPosition.x
  local dy = otherCarPosition.y - carPosition.y
  local dz = otherCarPosition.z - carPosition.z
  local d2 = dx*dx + dy*dy + dz*dz
  
  -- check if this sample is colliding with the other car
  local intersecting = d2 <= combinedCollisionRadius2
  return intersecting
end

---@param carPosition vec3
---@param otherCarPosition vec3
---@param otherCarAABBSize vec3
---@param otherCarForward vec3
---@param otherCarLeft vec3
---@param otherCarUp vec3
---@return boolean
local isIntersectingAABB = function(carPosition, otherCarPosition, otherCarAABBSize, otherCarForward, otherCarLeft, otherCarUp)
  -- Treat the other car as an oriented bounding box using its forward/left/up directions.
  -- Center at mid-height (same convention as CarOperations.getSideAnchorPoints).
  local safetyMarginMeters = storage_PathFinding.safetyMarginMeters
  local halfSizeX = (otherCarAABBSize.x * 0.5) + safetyMarginMeters
  local halfSizeY = (otherCarAABBSize.y * 0.5)-- + safetyMarginMeters
  local halfSizeZ = (otherCarAABBSize.z * 0.5) + safetyMarginMeters

  local centerX = otherCarPosition.x + otherCarUp.x * halfSizeY
  local centerY = otherCarPosition.y + otherCarUp.y * halfSizeY
  local centerZ = otherCarPosition.z + otherCarUp.z * halfSizeY

  local dx = carPosition.x - centerX
  local dy = carPosition.y - centerY
  local dz = carPosition.z - centerZ

  -- Project into the other car's local space.
  local localX = dx * otherCarLeft.x     + dy * otherCarLeft.y     + dz * otherCarLeft.z -- left/right
  local localY = dx * otherCarUp.x       + dy * otherCarUp.y       + dz * otherCarUp.z   -- up/down
  local localZ = dx * otherCarForward.x  + dy * otherCarForward.y  + dz * otherCarForward.z -- front/back

  local insideX = math_abs(localX) <= halfSizeX
  local insideY = math_abs(localY) <= halfSizeY
  local insideZ = math_abs(localZ) <= halfSizeZ

  local intersecting = insideX and insideY and insideZ
  return intersecting
end


-- Build simple paths radiating from the front of the car to lateral targets.
-- Each path starts at the anchor point and smoothly interpolates current offset → target offset.
---@param sortedCarsList SortedCarsList @The list of cars sorted by track position (furthest ahead first)
---@param sortedCarsListIndex integer @The SortedCarsList index of the car to calculate the path for
local calculatePath = function(sortedCarsList, sortedCarsListIndex)
  local car = sortedCarsList[sortedCarsListIndex]
  if not car then return end

  local carIndex = car.index
  ensureCarArrays(carIndex)

  local carTrackCoordinates = ac_worldCoordinateToTrack(car.position)
  local currentProgressZ  = wrap01(carTrackCoordinates.z)
  local maxAbsOffsetNormalized = storage_PathFinding.maxAbsOffsetNormalized
  local currentOffsetN    = math_max(-maxAbsOffsetNormalized, math_min(maxAbsOffsetNormalized, carTrackCoordinates.x))

  -- Where paths originate: a small step ahead along the spline at the *current* lateral offset.
  -- Using the spline keeps the fan aligned with the road.
  local anchorAheadMeters = storage_PathFinding.anchorAheadMeters
  local anchorZ = wrap01(currentProgressZ + RaceTrackManager_metersToSplineSpan(anchorAheadMeters))
  -- local anchorWorldPosition = ac_trackCoordinateToWorld(VecPool_getTempVec3(currentOffsetN, 0.0, anchorZ))
  local anchorWorldPosition = car.position + (car.look * anchorAheadMeters)

  -- Precompute step sizes.
  local forwardDistanceMeters = storage_PathFinding.forwardDistanceMeters
  local totalForwardProgress = RaceTrackManager_metersToSplineSpan(forwardDistanceMeters)
  local numberOfPathSamples = math_max(2, storage_PathFinding.numberOfPathSamples)
  local stepZ = totalForwardProgress / (numberOfPathSamples - 1) -- the increment per step along Z

  -- Precompute inverse of progress needed to reach full lateral offset by splitReachMeters.
  local splitReachMeters = storage_PathFinding.splitReachMeters
  local splitReachProgress = RaceTrackManager_metersToSplineSpan(splitReachMeters)
  local invSplitReachProgress = (splitReachProgress > 0.0) and (1.0 / splitReachProgress) or 1e9

  -- Generate paths (count adapts to navigation_pathOffsetN length).
  local pathsTotalSamples  = navigation_pathsTotalSamples[carIndex]
  local pathsIsBlocked = navigation_pathsIsBlocked[carIndex]
  local pathsBlockedSampleIndex  = navigation_pathsBlockedSampleIndex[carIndex]
  local pathsBlockedOtherCarIndex  = navigation_pathsBlockedOtherCarIndex[carIndex]
  local pathsBlockedSampleWorldPosition  = navigation_pathsBlockedSampleWorldPosition[carIndex]
  local pathsBlockedTimeSeconds  = navigation_pathsBlockedTimeSeconds[carIndex]
  local pathsSamplesWorldPositions  = navigation_pathsSamplesWorldPositions[carIndex]

  -- For minimal work, only consider cars AHEAD of the current one in the sorted list.
  -- (sortedCarsListIndex-1 down to 1). Cars behind can’t block our forward samples.
  local firstAheadSortedCarListIndex = (sortedCarsListIndex or 2) - 1

  --[===[
  local approxCarRadiusMeters   = storage_PathFinding.approxCarRadiusMeters
  local safetyMarginMeters      = storage_PathFinding.safetyMarginMeters
  local combinedCollisionRadius = (approxCarRadiusMeters * 2.0) + safetyMarginMeters
  local combinedCollisionRadius2 = combinedCollisionRadius * combinedCollisionRadius
  --]===]

  local lateralSplitExponent = storage_PathFinding.lateralSplitExponent

  local timeToLeavePathBlockedAfterSampleHitSeconds = storage_PathFinding.timeToLeavePathBlockedAfterSampleHitSeconds 

  local playingGameTimeSeconds = GameTimeManager_getPlayingGameTime()

  -- For each path lateral target offset, build each path's samples and check for collisions after creating the samples
  for pathIndex = 1, TOTAL_PATH_LATERAL_OFFSETS do
    local targetOffsetN = math_max(-maxAbsOffsetNormalized, math_min(maxAbsOffsetNormalized, PATH_LATERAL_OFFSETS[pathIndex]))

    local leavePathBlocked = false
    local isPathCurrentlyBlocked = pathsIsBlocked[pathIndex]
    -- Determine if we should keep the path marked as blocked based on time since last hit
    if isPathCurrentlyBlocked then
      local pathBlockedTimeSeconds = pathsBlockedTimeSeconds[pathIndex] or 0.0
      local timeSinceBlockedSeconds = playingGameTimeSeconds - pathBlockedTimeSeconds
      -- if timeSinceBlockedSeconds < timeToLeavePathBlockedAfterSampleHitSeconds or sim.isPaused then
      if timeSinceBlockedSeconds < timeToLeavePathBlockedAfterSampleHitSeconds then
        leavePathBlocked = true

      end
    end

    -- Clear previous samples/meta (reuse tables).
    local pathSamplesWorldPositions = pathsSamplesWorldPositions[pathIndex]
    for i = 1, #pathSamplesWorldPositions do
      pathSamplesWorldPositions[i] = nil
    end
    pathsTotalSamples[pathIndex] = 0

    -- Only clear the blocked state if we are not leaving it blocked
    if not leavePathBlocked then
      pathsIsBlocked[pathIndex] = false
      pathsBlockedSampleIndex[pathIndex] = nil
      pathsBlockedSampleWorldPosition[pathIndex] = nil
      pathsBlockedOtherCarIndex[pathIndex] = nil
      pathsBlockedTimeSeconds[pathIndex] = nil
    end

    -- Sample along the road: linearly progress forward, but move laterally so that we hit
    -- the target offset by `splitReachMeters` (using an ease-out curve).

    -- Initialize the sample count (first sample is the anchor).
    pathsTotalSamples[pathIndex] = 1

    -- First sample is always the anchor.
    pathSamplesWorldPositions[1] = anchorWorldPosition

    -- NEW: keep track of previous sample position for segment midpoint checks.
    local lastSampleWorldPosition = anchorWorldPosition

    -- for each step along the path, create a sample point and check for collisions.
    for currentSampleIndex = 2, numberOfPathSamples do
      local stepSize = stepZ
      if currentSampleIndex == 2 then
        -- stepSize = stepZ * 0.1  -- half-step for the first sample after the anchor
      end

      local progressDelta = (currentSampleIndex - 1) * stepSize
      local tLatLinear = math_min(1.0, progressDelta * invSplitReachProgress)
      local tLat = easeOutPow01(tLatLinear, lateralSplitExponent)

      local sampleZ = wrap01(anchorZ + (currentSampleIndex - 1) * stepSize)
      local sampleN = currentOffsetN + (targetOffsetN - currentOffsetN) * tLat
      local sampleWorldPosition = ac_trackCoordinateToWorld(VecPool_getTempVec3(sampleN, 0.0, sampleZ))

      -- increase the sample count since we have a new sample
      pathsTotalSamples[pathIndex] = pathsTotalSamples[pathIndex] + 1
      
      -- save the sample world position
      pathSamplesWorldPositions[pathsTotalSamples[pathIndex]] = sampleWorldPosition

      -- --- Minimal collider detection (only what’s needed) -------------------
      if not pathsIsBlocked[pathIndex] and firstAheadSortedCarListIndex >= 1 then
        -- Check cars in front only; early-exit on first hit.
        for otherCarSortedCarsListIndex = firstAheadSortedCarListIndex, 1, -1 do
          local otherCar = sortedCarsList[otherCarSortedCarsListIndex]
          
          -- TODO: Andreas: theoratically this index check is not needed since we only check cars ahead
          if otherCar and otherCar.index ~= carIndex then
            -- check if this sample is colliding with the other car
            -- local intersecting = isIntersectingSphere(sampleWorldPosition, otherCar.position, combinedCollisionRadius2)
            local intersecting = isIntersectingAABB(sampleWorldPosition, otherCar.position, otherCar.aabbSize, otherCar.look, otherCar.side, otherCar.up)

            -- EXTRA “BETWEEN SAMPLES” CHECK:
            -- If endpoint is not inside, also test midpoint of the segment between last and current samples.
            if not intersecting then
              local midX = (lastSampleWorldPosition.x + sampleWorldPosition.x) * 0.5
              local midY = (lastSampleWorldPosition.y + sampleWorldPosition.y) * 0.5
              local midZ = (lastSampleWorldPosition.z + sampleWorldPosition.z) * 0.5
              local midPoint = VecPool_getTempVec3(midX, midY, midZ)
              intersecting = isIntersectingAABB(midPoint, otherCar.position, otherCar.aabbSize, otherCar.look, otherCar.side, otherCar.up)
            end

            if intersecting then
              -- mark the path as blocked
              pathsIsBlocked[pathIndex] = true
              pathsBlockedSampleIndex[pathIndex] = currentSampleIndex
              pathsBlockedSampleWorldPosition[pathIndex] = sampleWorldPosition
              pathsBlockedOtherCarIndex[pathIndex] = otherCar.index
              pathsBlockedTimeSeconds[pathIndex] = playingGameTimeSeconds
              break -- break out of the for loop over other cars since we found a blocked hit for this path
            end
          end
        end -- end of other cars loop
      end
      -- ----------------------------------------------------------------------

      -- update previous sample position for the next segment
      lastSampleWorldPosition = sampleWorldPosition
    end -- end of samples loop


  end -- end of paths loop
end

-- Public: return the lateral offset (normalized) associated with the “best” path for a car.
-- “Best” here = first clear path by preference (center-most first, then bias to right on ties).
-- Sticky behavior: if previously chosen path is still clear, keep it to avoid wobbling.
-- If all paths are blocked, returns the one that gets the furthest before the first hit.
local function getBestLateralOffset(carIndex)
  -- If the last chosen path is still clear, reuse it (sticky behavior).
  local lastChosenPathIndex = navigation_lastChosenPathIndex[carIndex]
  local pathsIsBlocked = navigation_pathsIsBlocked[carIndex]
  if lastChosenPathIndex ~= nil then
    local lastChosenPathStillAvailable = not pathsIsBlocked[lastChosenPathIndex]
    if lastChosenPathStillAvailable then
      return PATH_LATERAL_OFFSETS[lastChosenPathIndex]
    end
  end

  local pathsBlockedSampleIndex = navigation_pathsBlockedSampleIndex[carIndex]
  local pathsBlockedSampleWorldPosition = navigation_pathsBlockedSampleWorldPosition[carIndex]
  local pathsSamplesWorldPositions = navigation_pathsSamplesWorldPositions[carIndex]

  local blockedPathIndexes = {}
  for i = 1, TOTAL_PATH_LATERAL_OFFSETS do
    if pathsIsBlocked[i] then
      table_insert(blockedPathIndexes, i)
    end
  end

  local bestPathIndex = 0
  local bestPathBlockedSampleIndex = 0
  local bestPathDistanceToBlockedSamples = 0

  --[====[
  for i = 1, TOTAL_PATH_LATERAL_OFFSETS do
    local pathSamplesWorldPositions = pathsSamplesWorldPositions[i]
    local totalDistancesToBlockedSamples = 0.0
    for j = 1, #blockedPathIndexes do
      local blockedPathIndex = blockedPathIndexes[j]
      local pathBlockedSampleWorldPosition = pathsBlockedSampleWorldPosition[blockedPathIndex]
      local pathBlockedSampleIndex = pathsBlockedSampleIndex[blockedPathIndex]
      
      local distanceBetweenSamples = MathHelpers.distanceBetweenVec3s(
        pathSamplesWorldPositions[pathBlockedSampleIndex],
        pathBlockedSampleWorldPosition
      )

      totalDistancesToBlockedSamples = totalDistancesToBlockedSamples + distanceBetweenSamples
    end
    if totalDistancesToBlockedSamples > bestPathDistanceToBlockedSamples then
      bestPathDistanceToBlockedSamples = totalDistancesToBlockedSamples
      bestPathIndex = i
    end
  end
  --]====]

  -- this one picks the best path depending on which blocked path goes the furthest based on the highest blocked sample index
  for i = 1, TOTAL_PATH_LATERAL_OFFSETS do
    local pathBlockedSampleIndex = math.huge
    if pathsIsBlocked[i] then
      pathBlockedSampleIndex = pathsBlockedSampleIndex[i]
    end

    -- if this path's blocked sample index is greater than the best found so far, update best
    if pathBlockedSampleIndex > bestPathBlockedSampleIndex then
      bestPathBlockedSampleIndex = pathBlockedSampleIndex
      bestPathIndex = i
    end
  end

  navigation_lastChosenPathIndex[carIndex] = bestPathIndex
  return PATH_LATERAL_OFFSETS[bestPathIndex]







end

-- Convenience: build paths and immediately choose the best lateral offset in one call.
-- This avoids calling two public functions from the caller each frame and keeps state consistent.
-- Returns normalized lateral offset or nil if data is not ready.
function Pathfinding.calculatePathAndGetBestLateralOffset(sortedCarsList, sortedCarsListIndex)
  local car = sortedCarsList[sortedCarsListIndex]
  if not car then return nil end

  calculatePath(sortedCarsList, sortedCarsListIndex)
  return getBestLateralOffset(car.index)
end

return Pathfinding
