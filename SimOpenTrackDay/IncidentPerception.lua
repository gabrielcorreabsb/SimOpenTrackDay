-- F1-1 incident perception: observation only.
--
-- This module never writes physics, controls, zones, flags or lateral offsets. It reads indexed
-- car state, compares it with cached AI-spline geometry, and emits compact observation records
-- through Logger.observe. All steady-state work is O(cars) with numeric arrays and no allocations
-- except event-rate message formatting.
local IncidentPerception = {}

local ac = ac
local CarManager = CarManager
local Logger = Logger
local StorageManager = StorageManager
local band = bit.band

local finiteNumber = function(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local validIndex = function(value)
  return finiteNumber(value) and value >= 0 and value % 1 == 0
end

local wrap01 = function(value)
  value = value % 1
  if value < 0 then value = value + 1 end
  return value
end

-- Thresholds are intentionally plain numbers and will be tuned from logs.
local BUCKET_LENGTH_M = 8
local MAX_BUCKETS = 4096
local MAX_CARS = 512
local STOP_SPEED_KMH = 5
local STOP_ARM_SPEED_KMH = 5
local STOP_BASE_SECONDS = 2
local STOP_NEAR_SECONDS = 6
local STOP_ALONE_SECONDS = 8
local STOP_NEAR_METERS = 8
local OFF_TRACK_SUSTAIN_SECONDS = 0.5
local SPIN_SUSTAIN_SECONDS = 0.6
local SPIN_CHANGE_RAD = math.pi / 3      -- 60 degrees of heading change from the aligned baseline
local SPIN_ALIGNED_RAD = math.pi / 9     -- 20 degrees: refresh baseline while still aligned
local SPIN_MAX_FORWARD_KMH = 10
local ON_LINE_BAND_M = 1.5
local WRONG_WAY_DOT = -0.5
local WRONG_WAY_MIN_KMH = 10
local WRONG_WAY_SUSTAIN_SECONDS = 1
local CONTACT_DEPTH = 0.005
local CONTACT_MEASURE_SECONDS = 0.6
local CONTACT_DEBOUNCE_SECONDS = 1.5
local GROUP_WINDOW_SECONDS = 2
local GROUP_DISTANCE_M = 15
-- Normalized CSP track coordinate (ac.worldCoordinateToTrack().x): -1 left edge, +1 right edge.
local OFF_TRACK_NORMALIZED = 1.02
-- Flood guard: one record per car and kind every 10 s, at most 30 records per minute overall.
local EMIT_COOLDOWN_SECONDS = 10
local RATE_WINDOW_SECONDS = 60
local RATE_MAX_PER_WINDOW = 30
local TIME_EPSILON_S = 1e-9
local SPLINE_JUMP = 0.1
local DISCONTINUITY_DT = 0.75

local OTHER_TRACK = -1
local OTHER_UNKNOWN = -2

local UNKNOWN_WHEELS = 1
local UNKNOWN_SIDES = 2
local UNKNOWN_GEOMETRY = 3
local UNKNOWN_PIT = 4
local UNKNOWN_LOOK = 5
local UNKNOWN_DEPTH = 6
local UNKNOWN_COLLIDED = 7
local UNKNOWN_SPEED = 8
local UNKNOWN_SPLINE = 9
local UNKNOWN_CAR = 10
local UNKNOWN_TRACK_LENGTH = 11
local UNKNOWN_POOL = 12
local UNKNOWN_LINE = 13
local UNKNOWN_NAMES = {
  'wheelsOutside', 'trackLateral', 'trackGeometry', 'pitState', 'carLook',
  'collisionDepth', 'collidedWith', 'speedKmh', 'splinePosition', 'carFields',
  'trackLengthM', 'poolCapacity', 'lineBand',
}

-- Geometry is cached per spline bucket: AI-spline centre, planar tangent and a perpendicular vector.
-- It is used for heading (spin/wrong-way) and for the unsigned distance from the AI line (stopped
-- band). Off-track uses CSP's normalized track coordinate instead. Filled once per track/session.
local geometryX, geometryZ = {}, {}
local geometryTangentX, geometryTangentZ = {}, {}
local geometryRightX, geometryRightZ = {}, {}
local geometryCentreReady = {}
for i = 1, MAX_BUCKETS do
  geometryX[i], geometryZ[i] = 0, 0
  geometryTangentX[i], geometryTangentZ[i] = 0, 0
  geometryRightX[i], geometryRightZ[i] = 0, 0
  geometryCentreReady[i] = 0
end

-- Reusable stopped-car index/spline arrays. Sorted descending like CarManager.currentSortedCarsList.
local stoppedIndices, stoppedSplines = {}, {}
for i = 1, MAX_CARS do stoppedIndices[i], stoppedSplines[i] = 0, 0 end

-- Fixed group pool. Each contact joins a group only when the spline distance and time window match.
local GROUP_CAPACITY = 16
local groups = {}
for i = 1, GROUP_CAPACITY do
  groups[i] = { active = false, firstTime = 0, lastTime = 0, closeAt = 0,
    splineRef = 0, splineValid = false, carA = 0, carB = OTHER_UNKNOWN,
    carAGeneration = 0, carBGeneration = 0,
    contacts = 0, maxDrop = 0, dropKnown = false }
end

-- Fixed contact measurement pool. One sample per participant; the drop is start minus the minimum
-- speed observed during the 0.6 s window.
local SAMPLE_CAPACITY = 48
local samples = {}
for i = 1, SAMPLE_CAPACITY do
  samples[i] = { active = false, carIndex = 0, generation = 0, groupIndex = 0,
    startTime = 0, endTime = 0, startSpeed = 0, minSpeed = 0, speedValid = false,
    dropKnown = false, drop = 0, dataMissing = false, measured = false }
end

-- Fixed unordered-pair debounce pool. A numeric key collapses reciprocal AI views.
local PAIR_CAPACITY = 64
local pairPool = {}
for i = 1, PAIR_CAPACITY do pairPool[i] = { key = 0, untilTime = 0 } end

local unknownReported = {}
for i = 1, #UNKNOWN_NAMES do unknownReported[i] = false end

local scratchVec3 = nil
if vec3 ~= nil then
  local scratchOK, scratch = pcall(vec3, 0, 0, 0)
  if scratchOK then scratchVec3 = scratch end
end

local stateTime = 0
local featureEnabled = false
local lastSessionGeneration = nil
local lastTrackLengthM = nil
local trackLengthM = nil
local trackLengthValid = false
local bucketCount = 0
local geometryBuilt = false
local geometryAnyCentre = false
local stoppedCount = 0

local function clearCarPerception(carIndex)
  if not CarManager then return end
  CarManager.cars_perceptionGeneration[carIndex] = nil
  CarManager.cars_perceptionPrevSpline[carIndex] = nil
  CarManager.cars_perceptionPrevDepth[carIndex] = nil
  CarManager.cars_perceptionStopTime[carIndex] = nil
  CarManager.cars_perceptionStopArmed[carIndex] = nil
  CarManager.cars_perceptionStopReported[carIndex] = nil
  CarManager.cars_perceptionSourceBits[carIndex] = nil
  CarManager.cars_perceptionOffTime[carIndex] = nil
  CarManager.cars_perceptionOffReported[carIndex] = nil
  CarManager.cars_perceptionLateral[carIndex] = nil
  CarManager.cars_perceptionLateralValid[carIndex] = nil
  CarManager.cars_perceptionSpinBaseline[carIndex] = nil
  CarManager.cars_perceptionSpinBaselineValid[carIndex] = nil
  CarManager.cars_perceptionSpinTime[carIndex] = nil
  CarManager.cars_perceptionSpinReported[carIndex] = nil
  CarManager.cars_perceptionWrongTime[carIndex] = nil
  CarManager.cars_perceptionWrongReported[carIndex] = nil
end

-- Flood guard state. One cooldown table per kind (created once), indexed by car.
local emitCooldowns = {}
local rateWindowStart, rateCount, rateSuppressed = 0, 0, 0

local function flushSuppressed(now)
  if now - rateWindowStart < RATE_WINDOW_SECONDS then return end
  if rateSuppressed > 0 and Logger and type(Logger.observe) == 'function' then
    Logger.observe('incident-perception-suppressed', 0, 0, nil, nil,
      string.format('[F1-1] suppressed=%d window=%ds', rateSuppressed, RATE_WINDOW_SECONDS), nil, nil, nil, '[F1-1] car=0 s=na')
  end
  rateWindowStart, rateCount, rateSuppressed = now, 0, 0
end

local function resetFloodGuard()
  for _, perCar in pairs(emitCooldowns) do
    for carIndex in pairs(perCar) do perCar[carIndex] = nil end
  end
  rateWindowStart, rateCount, rateSuppressed = 0, 0, 0
end

local function resetPending()
  for i = 1, GROUP_CAPACITY do groups[i].active = false end
  for i = 1, PAIR_CAPACITY do pairPool[i].key, pairPool[i].untilTime = 0, 0 end
  for i = 1, SAMPLE_CAPACITY do samples[i].active = false end
end

local function resetAll(resetUnknownFlags)
  resetPending()
  if CarManager then
    for index in pairs(CarManager.cars_perceptionGeneration) do clearCarPerception(index) end
  end
  if resetUnknownFlags then
    for i = 1, #UNKNOWN_NAMES do unknownReported[i] = false end
  end
  resetFloodGuard()
  stateTime = 0
end

local function formatNumber(value)
  if finiteNumber(value) then return string.format('%.1f', value) end
  return 'unknown'
end

local function reportUnknown(reason, carIndex, spline)
  if unknownReported[reason] then return end
  unknownReported[reason] = true
  if not Logger or type(Logger.observe) ~= 'function' then return end
  local carRef = validIndex(carIndex) and carIndex or 0
  local splineRef = finiteNumber(spline) and string.format('%.3f', spline) or 'na'
  local detail = string.format('[F1-1] field=%s', UNKNOWN_NAMES[reason] or 'unknown')
  local resource = string.format('[F1-1] car=%d s=%s', carRef, splineRef)
  Logger.observe('incident-perception-unknown', carRef, 0, nil, nil, detail, nil, nil, nil, resource)
end

local function emitEvent(kind, carIndex, generation, spline, detail, extra)
  if not Logger or type(Logger.observe) ~= 'function' then return end
  local carRef = validIndex(carIndex) and carIndex or 0
  local perCar = emitCooldowns[kind]
  if perCar == nil then
    perCar = {}
    emitCooldowns[kind] = perCar
  end
  local last = perCar[carRef]
  if last ~= nil and stateTime - last < EMIT_COOLDOWN_SECONDS then
    rateSuppressed = rateSuppressed + 1
    return
  end
  flushSuppressed(stateTime)
  if rateCount >= RATE_MAX_PER_WINDOW then
    rateSuppressed = rateSuppressed + 1
    return
  end
  rateCount = rateCount + 1
  perCar[carRef] = stateTime
  local splineRef = finiteNumber(spline) and string.format('%.3f', spline) or 'na'
  local resource = string.format('[F1-1] car=%d s=%s', carRef, splineRef)
  Logger.observe(kind, carRef, generation or 0, nil, nil, detail, nil, nil, extra, resource)
end

local function wheelsStatus(sourceBits)
  if band(sourceBits, 2) ~= 0 then return 'off' end
  if band(sourceBits, 1) ~= 0 then return 'on' end
  return 'unknown'
end

local function lateralStatus(sourceBits)
  if band(sourceBits, 8) ~= 0 then return 'off' end
  if band(sourceBits, 4) ~= 0 then return 'on' end
  return 'unknown'
end

local function sourceExtra(sourceBits)
  return string.format('[F1-1] src=w:%s l:%s', wheelsStatus(sourceBits), lateralStatus(sourceBits))
end

local function bucketForSpline(spline)
  if not finiteNumber(spline) or bucketCount <= 0 then return 0 end
  local bucket = math.floor(wrap01(spline) * bucketCount) + 1
  if bucket < 1 then return 1 end
  if bucket > bucketCount then return bucketCount end
  return bucket
end

local function circularSplineDistanceM(splineA, splineB)
  if not finiteNumber(splineA) or not finiteNumber(splineB) or not trackLengthValid then return nil end
  local delta = wrap01(splineA) - wrap01(splineB)
  if delta < 0 then delta = -delta end
  if delta > 0.5 then delta = 1 - delta end
  return delta * trackLengthM
end

local function buildGeometry(trackLength)
  geometryBuilt = true
  geometryAnyCentre = false
  for i = 1, MAX_BUCKETS do
    geometryCentreReady[i] = 0
  end

  if finiteNumber(trackLength) and trackLength > 0 then
    trackLengthM, trackLengthValid = trackLength, true
    bucketCount = math.ceil(trackLength / BUCKET_LENGTH_M)
    if bucketCount < 16 then bucketCount = 16 end
    if bucketCount > MAX_BUCKETS then bucketCount = MAX_BUCKETS end
  else
    trackLengthM, trackLengthValid, bucketCount = nil, false, MAX_BUCKETS
    reportUnknown(UNKNOWN_TRACK_LENGTH, 0, nil)
  end

  local trackTo = ac and ac.trackProgressToWorldCoordinateTo
  if scratchVec3 == nil or trackTo == nil then
    reportUnknown(UNKNOWN_GEOMETRY, 0, nil)
    return
  end

  local delta = 1 / bucketCount
  for bucket = 1, bucketCount do
    local startProgress = (bucket - 0.5) / bucketCount
    if startProgress >= 1 then startProgress = startProgress - 1 end
    local nextProgress = startProgress + delta
    if nextProgress >= 1 then nextProgress = nextProgress - 1 end

    local firstOK = pcall(trackTo, startProgress, scratchVec3, false)
    local x1, z1 = scratchVec3.x, scratchVec3.z
    local secondOK = pcall(trackTo, nextProgress, scratchVec3, false)
    local x2, z2 = scratchVec3.x, scratchVec3.z

    if firstOK and secondOK and finiteNumber(x1) and finiteNumber(z1) and finiteNumber(x2) and finiteNumber(z2) then
      local tangentX, tangentZ = x2 - x1, z2 - z1
      local length = math.sqrt(tangentX * tangentX + tangentZ * tangentZ)
      if length > 1e-5 then
        tangentX, tangentZ = tangentX / length, tangentZ / length
        geometryX[bucket], geometryZ[bucket] = x1, z1
        geometryTangentX[bucket], geometryTangentZ[bucket] = tangentX, tangentZ
        -- Y-up world: right = up x forward = (tz, 0, -tx). Planar approximation.
        geometryRightX[bucket], geometryRightZ[bucket] = tangentZ, -tangentX
        geometryCentreReady[bucket] = 1
        geometryAnyCentre = true
      end
    end

  end

  if not geometryAnyCentre then reportUnknown(UNKNOWN_GEOMETRY, 0, nil) end
end

local function classifyOffTrack(car, spline, bucket)
  local carIndex = car.index
  local sourceBits = 0
  local wheelsKnown, wheelsSome, wheelsOff = false, false, false

  local wheelsOutside = car.wheelsOutside
  if finiteNumber(wheelsOutside) and wheelsOutside >= 0 then
    wheelsKnown = true
    sourceBits = sourceBits + 1
    wheelsSome = wheelsOutside >= 1
    if wheelsOutside >= 3 then
      wheelsOff = true
      sourceBits = sourceBits + 2
    end
  else
    reportUnknown(UNKNOWN_WHEELS, carIndex, spline)
  end

  -- Normalized lateral from CSP (cached per car per frame by CarManager; no extra allocation).
  local position = car.position
  local normalizedKnown, beyondEdge = false, false
  if position ~= nil then
    local ok, x = pcall(CarManager.getActualTrackLateralOffset, carIndex, position)
    if ok and finiteNumber(x) then
      normalizedKnown = true
      sourceBits = sourceBits + 4
      if x > OFF_TRACK_NORMALIZED or x < -OFF_TRACK_NORMALIZED then
        beyondEdge = true
        sourceBits = sourceBits + 8
      end
    end
  end
  if not normalizedKnown then reportUnknown(UNKNOWN_SIDES, carIndex, spline) end

  -- Unsigned planar distance from the AI spline, only for the stopped "on the line" band.
  local lineDistance, lineKnown = 0, false
  if bucket > 0 and geometryCentreReady[bucket] == 1 then
    if position ~= nil and finiteNumber(position.x) and finiteNumber(position.z) then
      local deltaX, deltaZ = position.x - geometryX[bucket], position.z - geometryZ[bucket]
      lineDistance = math.abs(deltaX * geometryRightX[bucket] + deltaZ * geometryRightZ[bucket])
      lineKnown = true
    else
      reportUnknown(UNKNOWN_CAR, carIndex, spline)
    end
  else
    reportUnknown(UNKNOWN_GEOMETRY, carIndex, spline)
  end

  -- Off needs the wheels: three or more outside, or the car beyond the edge with at least one
  -- wheel outside. The normalized coordinate alone never reports off-track. "On" needs both sources.
  local state = 0
  if wheelsOff or (beyondEdge and wheelsSome) then
    state = 2
  elseif wheelsKnown and normalizedKnown then
    state = 1
  end
  return state, sourceBits, lineDistance, lineKnown
end

local function headingRelative(car, bucket)
  local look = car.look
  if look == nil or not finiteNumber(look.x) or not finiteNumber(look.z) then
    reportUnknown(UNKNOWN_LOOK, car.index, car.splinePosition)
    return nil
  end
  local planarLength = math.sqrt(look.x * look.x + look.z * look.z)
  if planarLength < 1e-3 then
    reportUnknown(UNKNOWN_LOOK, car.index, car.splinePosition)
    return nil
  end
  if bucket <= 0 or geometryCentreReady[bucket] ~= 1 then
    reportUnknown(UNKNOWN_GEOMETRY, car.index, car.splinePosition)
    return nil
  end
  local lookAngle = math.atan2(look.z, look.x)
  local tangentAngle = math.atan2(geometryTangentZ[bucket], geometryTangentX[bucket])
  local relative = lookAngle - tangentAngle
  while relative > math.pi do relative = relative - 2 * math.pi end
  while relative < -math.pi do relative = relative + 2 * math.pi end
  return relative
end

local function projectedForwardKmh(car, speed, speedValid, relative, bucket)
  local velocity = car.velocity
  if velocity ~= nil and finiteNumber(velocity.x) and finiteNumber(velocity.z)
    and bucket > 0 and geometryCentreReady[bucket] == 1 then
    local forward = velocity.x * geometryTangentX[bucket] + velocity.z * geometryTangentZ[bucket]
    return math.abs(forward) * 3.6
  end
  if speedValid and relative ~= nil then
    return math.abs(speed * math.cos(relative))
  end
  return nil
end

local function wrapAngle(value)
  while value > math.pi do value = value - 2 * math.pi end
  while value < -math.pi do value = value + 2 * math.pi end
  return value
end

local function headingDot(car, bucket)
  local look = car.look
  if look == nil or not finiteNumber(look.x) or not finiteNumber(look.z) then
    reportUnknown(UNKNOWN_LOOK, car.index, car.splinePosition)
    return nil
  end
  local planarLength = math.sqrt(look.x * look.x + look.z * look.z)
  if planarLength < 1e-3 then
    reportUnknown(UNKNOWN_LOOK, car.index, car.splinePosition)
    return nil
  end
  if bucket <= 0 or geometryCentreReady[bucket] ~= 1 then
    reportUnknown(UNKNOWN_GEOMETRY, car.index, car.splinePosition)
    return nil
  end
  return (look.x * geometryTangentX[bucket] + look.z * geometryTangentZ[bucket]) / planarLength
end

local function getGeneration(carIndex)
  if CarManager and type(CarManager.getCarGeneration) == 'function' then
    local generation = CarManager.getCarGeneration(carIndex)
    if finiteNumber(generation) then return generation end
  end
  return 0
end

local function participantCarValid(carIndex)
  local car = ac and ac.getCar and ac.getCar(carIndex)
  if car == nil or car.index ~= carIndex then return false end
  if car.isActive ~= true then return false end
  if carIndex > 0 and car.isConnected ~= true then return false end
  return true
end

local function participantStillValid(carIndex, generation)
  return participantCarValid(carIndex) and getGeneration(carIndex) == generation
end

local function pairKey(carIndex, otherIndex)
  if otherIndex >= 0 and otherIndex ~= carIndex then
    local low, high = carIndex, otherIndex
    if low > high then low, high = high, low end
    return low * 65536 + high
  elseif otherIndex == OTHER_TRACK then
    return carIndex * 65536 + 65534
  end
  return carIndex * 65536 + 65535
end

local function pairAllowed(key, now)
  for i = 1, PAIR_CAPACITY do
    local entry = pairPool[i]
    if entry.key == key then
      if now < entry.untilTime then return false end
      entry.untilTime = now + CONTACT_DEBOUNCE_SECONDS
      return true
    end
  end

  local slot = nil
  for i = 1, PAIR_CAPACITY do
    local entry = pairPool[i]
    if entry.key == 0 or entry.untilTime <= now then
      slot = i
      break
    end
  end
  if slot == nil then
    reportUnknown(UNKNOWN_POOL, 0, nil)
    return false
  end
  pairPool[slot].key = key
  pairPool[slot].untilTime = now + CONTACT_DEBOUNCE_SECONDS
  return true
end

local function findGroup(spline, splineValid, now)
  for i = 1, GROUP_CAPACITY do
    local group = groups[i]
    if group.active and now - group.lastTime <= GROUP_WINDOW_SECONDS
      and splineValid and group.splineValid then
      local distance = circularSplineDistanceM(spline, group.splineRef)
      if distance ~= nil and distance <= GROUP_DISTANCE_M then return i end
    end
  end
  return nil
end

local function createGroup(carIndex, otherIndex, spline, splineValid, now)
  for i = 1, GROUP_CAPACITY do
    local group = groups[i]
    if not group.active then
      group.active = true
      group.firstTime, group.lastTime = now, now
      group.closeAt = now + GROUP_WINDOW_SECONDS
      group.splineRef, group.splineValid = spline or 0, splineValid
      group.carA, group.carB = carIndex, otherIndex
      group.carAGeneration = getGeneration(carIndex)
      group.carBGeneration = otherIndex >= 0 and getGeneration(otherIndex) or 0
      group.contacts = 1
      group.maxDrop, group.dropKnown = 0, false
      return i
    end
  end
  reportUnknown(UNKNOWN_POOL, carIndex, spline)
  return nil
end

local function freeSampleSlots()
  local free = 0
  for i = 1, SAMPLE_CAPACITY do
    if not samples[i].active then free = free + 1 end
  end
  return free
end

local function releaseGroupSamples(groupIndex)
  for i = 1, SAMPLE_CAPACITY do
    local sample = samples[i]
    if sample.active and sample.groupIndex == groupIndex then sample.active = false end
  end
end

local function startSample(carIndex, groupIndex, now)
  local generation = getGeneration(carIndex)
  for i = 1, SAMPLE_CAPACITY do
    local sample = samples[i]
    if not sample.active then
      sample.active = true
      sample.carIndex, sample.generation, sample.groupIndex = carIndex, generation, groupIndex
      sample.startTime, sample.endTime = now, now + CONTACT_MEASURE_SECONDS
      sample.speedValid, sample.dropKnown, sample.drop, sample.dataMissing = false, false, 0, false
      sample.startSpeed, sample.minSpeed = 0, 0
      sample.measured = false

      if participantStillValid(carIndex, generation) then
        local sampleCar = ac.getCar(carIndex)
        local speed = sampleCar and sampleCar.speedKmh
        if finiteNumber(speed) and speed >= 0 then
          sample.speedValid = true
          sample.startSpeed, sample.minSpeed = speed, speed
        else
          sample.dataMissing = true
        end
      else
        sample.dataMissing = true
      end
      return i
    end
  end
  reportUnknown(UNKNOWN_POOL, carIndex, nil)
  return nil
end

local function updateSamples(now)
  for i = 1, SAMPLE_CAPACITY do
    local sample = samples[i]
    if sample.active and not sample.measured then
      if participantStillValid(sample.carIndex, sample.generation) then
        local sampleCar = ac.getCar(sample.carIndex)
        local speed = sampleCar and sampleCar.speedKmh
        if finiteNumber(speed) and speed >= 0 then
          if sample.speedValid and speed < sample.minSpeed then sample.minSpeed = speed end
        else
          sample.dataMissing = true
        end
      else
        sample.dataMissing = true
      end

      if now >= sample.endTime - TIME_EPSILON_S then
        local group = groups[sample.groupIndex]
        local finalCar = participantStillValid(sample.carIndex, sample.generation) and ac.getCar(sample.carIndex) or nil
        local finalSpeed = finalCar and finalCar.speedKmh
        sample.dropKnown = sample.speedValid and not sample.dataMissing
          and participantStillValid(sample.carIndex, sample.generation)
          and finiteNumber(finalSpeed) and finalSpeed >= 0
        if sample.dropKnown then
          sample.drop = sample.startSpeed - sample.minSpeed
          if sample.drop < 0 then sample.drop = 0 end
        end

        if group ~= nil and group.active then
          if sample.dropKnown then
            if sample.drop > group.maxDrop then group.maxDrop = sample.drop end
            group.dropKnown = true
          end
        end
        -- Keep the slot active as a bounded identity reference until the group closes.
        sample.measured = true
      end
    end
  end
end

local function pendingParticipantsValid()
  for i = 1, GROUP_CAPACITY do
    local group = groups[i]
    if group.active then
      if not participantStillValid(group.carA, group.carAGeneration) then return false end
      if group.carB >= 0 and not participantStillValid(group.carB, group.carBGeneration) then return false end
    end
  end
  for i = 1, SAMPLE_CAPACITY do
    local sample = samples[i]
    if sample.active and not participantStillValid(sample.carIndex, sample.generation) then return false end
  end
  return true
end

local function finalizeGroups(now)
  for i = 1, GROUP_CAPACITY do
    local group = groups[i]
    if group.active and now >= group.closeAt - TIME_EPSILON_S then
      local primaryValid = participantStillValid(group.carA, group.carAGeneration)
      local otherValid = group.carB < 0 or participantStillValid(group.carB, group.carBGeneration)
      if not primaryValid or not otherValid then
        -- The incident context is no longer trustworthy; never log a stale group.
        releaseGroupSamples(i)
        group.active = false
      else
        local duration = group.closeAt - group.firstTime
        local dropText = group.dropKnown and formatNumber(group.maxDrop) or 'unknown'
        local detail = string.format('[F1-1] contact d=%.1fs drop=%s n=%d',
          duration, dropText, group.contacts)
        local otherText
        if group.carB == OTHER_TRACK then
          otherText = '[F1-1] o=track'
        elseif group.carB >= 0 then
          otherText = string.format('[F1-1] o=%d', group.carB)
        else
          otherText = '[F1-1] o=unknown'
        end
        emitEvent('incident-perception-contact', group.carA, group.carAGeneration,
          group.splineValid and group.splineRef or nil, detail, otherText)
        releaseGroupSamples(i)
        group.active = false
      end
    end
  end
end

local function processContact(car, carIndex, generation, spline, bucket, now)
  local depth = car.collisionDepth
  if not finiteNumber(depth) then
    reportUnknown(UNKNOWN_DEPTH, carIndex, spline)
    CarManager.cars_perceptionPrevDepth[carIndex] = nil
    return
  end
  if depth < 0 then depth = 0 end

  local previousDepth = CarManager.cars_perceptionPrevDepth[carIndex]
  if previousDepth == nil then
    CarManager.cars_perceptionPrevDepth[carIndex] = depth
    return
  end

  local rising = depth > CONTACT_DEPTH and previousDepth <= CONTACT_DEPTH
  CarManager.cars_perceptionPrevDepth[carIndex] = depth
  if not rising then return end

  local collidedWith = car.collidedWith
  local otherIndex
  if finiteNumber(collidedWith) and collidedWith % 1 == 0 then
    if collidedWith == 0 then
      otherIndex = OTHER_TRACK
    elseif collidedWith > 0 then
      otherIndex = collidedWith - 1
      if otherIndex == carIndex or not participantCarValid(otherIndex) then
        otherIndex = OTHER_UNKNOWN
        reportUnknown(UNKNOWN_COLLIDED, carIndex, spline)
      end
    else
      otherIndex = OTHER_UNKNOWN
      reportUnknown(UNKNOWN_COLLIDED, carIndex, spline)
    end
  else
    otherIndex = OTHER_UNKNOWN
    reportUnknown(UNKNOWN_COLLIDED, carIndex, spline)
  end

  local key = pairKey(carIndex, otherIndex)
  if not pairAllowed(key, now) then return end

  local splineValid = finiteNumber(spline)
  local requiredSamples = 1
  if otherIndex >= 0 and otherIndex ~= carIndex then requiredSamples = 2 end
  if freeSampleSlots() < requiredSamples then
    reportUnknown(UNKNOWN_POOL, carIndex, spline)
    return
  end

  local groupIndex = findGroup(spline, splineValid, now)
  local created = false
  if groupIndex == nil then
    groupIndex = createGroup(carIndex, otherIndex, spline, splineValid, now)
    if groupIndex == nil then return end
    created = true
  end

  local primarySlot = startSample(carIndex, groupIndex, now)
  local otherSlot = nil
  if otherIndex >= 0 and otherIndex ~= carIndex then
    otherSlot = startSample(otherIndex, groupIndex, now)
  end

  if primarySlot == nil or (otherIndex >= 0 and otherIndex ~= carIndex and otherSlot == nil) then
    -- Never accept a contact whose participants cannot all be tracked to group close.
    if primarySlot ~= nil then samples[primarySlot].active = false end
    if otherSlot ~= nil then samples[otherSlot].active = false end
    if created then groups[groupIndex].active = false end
    reportUnknown(UNKNOWN_POOL, carIndex, spline)
    return
  end

  if not created then
    local group = groups[groupIndex]
    group.lastTime = now
    group.closeAt = now + GROUP_WINDOW_SECONDS
    group.contacts = group.contacts + 1
  end
end

local function processSubject(car, carIndex, dt, now)
  local generation = getGeneration(carIndex)
  local storedGeneration = CarManager.cars_perceptionGeneration[carIndex]
  if storedGeneration ~= nil and storedGeneration ~= generation then
    -- Identity changed: never let pending groups, pairs or samples join across two cars.
    resetPending()
    clearCarPerception(carIndex)
  end
  CarManager.cars_perceptionGeneration[carIndex] = generation

  local speed = car.speedKmh
  local speedValid = finiteNumber(speed) and speed >= 0
  if not speedValid then reportUnknown(UNKNOWN_SPEED, carIndex, car.splinePosition) end

  local spline = car.splinePosition
  local splineValid = finiteNumber(spline)
  if not splineValid then reportUnknown(UNKNOWN_SPLINE, carIndex, spline) end

  local previousSpline = CarManager.cars_perceptionPrevSpline[carIndex]
  if splineValid and previousSpline ~= nil then
    local delta = wrap01(spline) - wrap01(previousSpline)
    if delta > 0.5 then delta = delta - 1 elseif delta < -0.5 then delta = delta + 1 end
    if delta < 0 then delta = -delta end
    if delta > SPLINE_JUMP then
      resetPending()
      clearCarPerception(carIndex)
      CarManager.cars_perceptionGeneration[carIndex] = generation
    end
  end
  if splineValid then CarManager.cars_perceptionPrevSpline[carIndex] = spline end

  local bucket = splineValid and bucketForSpline(spline) or 0
  local offTrackState, sourceBits, lateral, lateralKnown = classifyOffTrack(car, spline, bucket)
  CarManager.cars_perceptionLateral[carIndex] = lateralKnown and lateral or nil
  CarManager.cars_perceptionLateralValid[carIndex] = lateralKnown and 1 or 0

  local pitlane, isInPit = car.isInPitlane, car.isInPit
  local pitKnown = type(pitlane) == 'boolean' and type(isInPit) == 'boolean'
  local pitExcluded = pitlane == true or isInPit == true
  if not pitKnown then reportUnknown(UNKNOWN_PIT, carIndex, spline) end

  local stopArmed = CarManager.cars_perceptionStopArmed[carIndex] or 0
  if speedValid and speed >= STOP_ARM_SPEED_KMH then stopArmed = 1 end

  CarManager.cars_perceptionSourceBits[carIndex] = sourceBits

  local stopCandidate = speedValid and speed < STOP_SPEED_KMH and stopArmed == 1
    and offTrackState == 1 and pitKnown and not pitExcluded

  if stopCandidate then
    local stopTime = (CarManager.cars_perceptionStopTime[carIndex] or 0) + dt
    CarManager.cars_perceptionStopTime[carIndex] = stopTime
    if stoppedCount < MAX_CARS then
      stoppedCount = stoppedCount + 1
      stoppedIndices[stoppedCount] = carIndex
      stoppedSplines[stoppedCount] = splineValid and spline or -1
    end
  else
    CarManager.cars_perceptionStopTime[carIndex] = 0
    CarManager.cars_perceptionStopReported[carIndex] = 0
  end
  CarManager.cars_perceptionStopArmed[carIndex] = stopArmed

  if offTrackState == 2 then
    local offTime = (CarManager.cars_perceptionOffTime[carIndex] or 0) + dt
    CarManager.cars_perceptionOffTime[carIndex] = offTime
    if CarManager.cars_perceptionOffReported[carIndex] ~= 1
      and offTime >= OFF_TRACK_SUSTAIN_SECONDS - TIME_EPSILON_S then
      CarManager.cars_perceptionOffReported[carIndex] = 1
      local detail = string.format('[F1-1] off-track d=%.1fs', offTime)
      emitEvent('incident-perception-off-track', carIndex, generation, spline, detail, sourceExtra(sourceBits))
    end
  else
    CarManager.cars_perceptionOffTime[carIndex] = 0
    CarManager.cars_perceptionOffReported[carIndex] = 0
  end

  local relative = headingRelative(car, bucket)
  if relative == nil then
    CarManager.cars_perceptionSpinBaselineValid[carIndex] = 0
    CarManager.cars_perceptionSpinTime[carIndex] = 0
    CarManager.cars_perceptionSpinReported[carIndex] = 0
  else
    local baselineValid = CarManager.cars_perceptionSpinBaselineValid[carIndex] or 0
    if baselineValid ~= 1 then
      -- First valid observation only establishes the baseline: an initially sideways car
      -- is a pose, not a spin.
      CarManager.cars_perceptionSpinBaseline[carIndex] = relative
      CarManager.cars_perceptionSpinBaselineValid[carIndex] = 1
      CarManager.cars_perceptionSpinTime[carIndex] = 0
      CarManager.cars_perceptionSpinReported[carIndex] = 0
    else
      local baseline = CarManager.cars_perceptionSpinBaseline[carIndex] or 0
      local change = wrapAngle(relative - baseline)
      local forwardKmh = projectedForwardKmh(car, speed, speedValid, relative, bucket)
      if math.abs(change) > SPIN_CHANGE_RAD and forwardKmh ~= nil
        and forwardKmh <= SPIN_MAX_FORWARD_KMH then
        local spinTime = (CarManager.cars_perceptionSpinTime[carIndex] or 0) + dt
        CarManager.cars_perceptionSpinTime[carIndex] = spinTime
        if CarManager.cars_perceptionSpinReported[carIndex] ~= 1
          and spinTime >= SPIN_SUSTAIN_SECONDS - TIME_EPSILON_S then
          CarManager.cars_perceptionSpinReported[carIndex] = 1
          local changeDegrees = math.floor(math.abs(change) * 180 / math.pi + 0.5)
          local detail = string.format('[F1-1] spin d=%.1fs', spinTime)
          emitEvent('incident-perception-spin', carIndex, generation, spline, detail,
            string.format('[F1-1] chg=%d', changeDegrees))
        end
      else
        CarManager.cars_perceptionSpinTime[carIndex] = 0
        CarManager.cars_perceptionSpinReported[carIndex] = 0
        if math.abs(relative) <= SPIN_ALIGNED_RAD then
          CarManager.cars_perceptionSpinBaseline[carIndex] = relative
        end
      end
    end
  end

  local dot = headingDot(car, bucket)

  if dot ~= nil and speedValid and speed > WRONG_WAY_MIN_KMH and dot < WRONG_WAY_DOT then
    local wrongTime = (CarManager.cars_perceptionWrongTime[carIndex] or 0) + dt
    CarManager.cars_perceptionWrongTime[carIndex] = wrongTime
    if CarManager.cars_perceptionWrongReported[carIndex] ~= 1
      and wrongTime >= WRONG_WAY_SUSTAIN_SECONDS - TIME_EPSILON_S then
      CarManager.cars_perceptionWrongReported[carIndex] = 1
      local detail = string.format('[F1-1] wrong-way d=%.1fs', wrongTime)
      emitEvent('incident-perception-wrong-way', carIndex, generation, spline, detail, '[F1-1] hdg=back')
    end
  else
    CarManager.cars_perceptionWrongTime[carIndex] = 0
    CarManager.cars_perceptionWrongReported[carIndex] = 0
  end

  processContact(car, carIndex, generation, spline, bucket, now)
end

local function evaluateStopped(now)
  local count = stoppedCount
  -- Stopped list is already in descending spline order. Near means a circular distance of at most
  -- 8 m to the previous or next stopped entry. Otherwise a known on-line car (|lateral| <= 1.5 m)
  -- uses the 8 s alone window and a known off-line car uses the base 2 s window. If track length,
  -- spline or lateral status is unknown, emit unknown and make no stopped conclusion.
  for position = 1, count do
    local carIndex = stoppedIndices[position]
    local spline = stoppedSplines[position]
    local lateralValid = CarManager.cars_perceptionLateralValid[carIndex] == 1
    local lateral = CarManager.cars_perceptionLateral[carIndex] or 0
    local lineKnown = trackLengthValid and finiteNumber(spline) and spline >= 0 and lateralValid

    if lineKnown then
      local threshold, mode = STOP_BASE_SECONDS, 'line'
      if count > 1 then
        local previousPosition = position - 1
        if previousPosition < 1 then previousPosition = count end
        local nextPosition = position + 1
        if nextPosition > count then nextPosition = 1 end
        local previousSpline = stoppedSplines[previousPosition]
        local nextSpline = stoppedSplines[nextPosition]
        local previousDistance = previousSpline >= 0 and circularSplineDistanceM(spline, previousSpline) or nil
        local nextDistance = nextSpline >= 0 and circularSplineDistanceM(spline, nextSpline) or nil
        if previousDistance == nil or nextDistance == nil then
          lineKnown = false
        else
          local near = previousDistance <= STOP_NEAR_METERS or nextDistance <= STOP_NEAR_METERS
          if near then
            threshold, mode = STOP_NEAR_SECONDS, 'near'
          elseif math.abs(lateral) <= ON_LINE_BAND_M then
            threshold, mode = STOP_ALONE_SECONDS, 'alone'
          end
        end
      elseif math.abs(lateral) <= ON_LINE_BAND_M then
        threshold, mode = STOP_ALONE_SECONDS, 'alone'
      end

      if lineKnown then
        local stopTime = CarManager.cars_perceptionStopTime[carIndex] or 0
        if CarManager.cars_perceptionStopReported[carIndex] ~= 1 and stopTime >= threshold - TIME_EPSILON_S then
          CarManager.cars_perceptionStopReported[carIndex] = 1
          local detail = string.format('[F1-1] stopped d=%.1fs %s', stopTime, mode)
          local generation = CarManager.cars_perceptionGeneration[carIndex] or 0
          local sourceBits = CarManager.cars_perceptionSourceBits[carIndex] or 0
          emitEvent('incident-perception-stopped', carIndex, generation,
            spline >= 0 and spline or nil, detail, sourceExtra(sourceBits))
        end
      end
    end
    if not lineKnown then
      reportUnknown(UNKNOWN_LINE, carIndex, spline)
    end
  end
end

---Observation-only update. `sortedCars` is CarManager.currentSortedCarsList (descending spline).
---@param dt number
---@param sortedCars table
function IncidentPerception.update(dt, sortedCars)
  if not finiteNumber(dt) or dt <= 0 then return end

  local enabled = false
  if StorageManager then
    if type(StorageManager.getIncidentPerceptionEnabled) == 'function' then
      enabled = StorageManager.getIncidentPerceptionEnabled() == true
    elseif type(StorageManager.getStorage) == 'function' then
      local storage = StorageManager.getStorage()
      enabled = storage ~= nil and storage.incidentPerceptionEnabled == true
    end
  end
  if Logger and type(Logger.setIncidentPerceptionEnabled) == 'function' then
    Logger.setIncidentPerceptionEnabled(enabled)
  end

  if not enabled then
    if featureEnabled then resetAll(true) end
    featureEnabled = false
    return
  end

  if not featureEnabled then
    featureEnabled = true
    resetAll(true)
    geometryBuilt = false
  end

  if CarManager == nil or type(sortedCars) ~= 'table' then
    reportUnknown(UNKNOWN_CAR, 0, nil)
    return
  end

  if CarManager.runtimeLive == false or CarManager.runtimePaused == true then
    resetAll(false)
    return
  end

  if dt > DISCONTINUITY_DT then
    resetAll(false)
    return
  end

  local sessionGeneration = CarManager.sessionGeneration or 0
  if lastSessionGeneration == nil then
    lastSessionGeneration = sessionGeneration
    resetAll(true)
  elseif sessionGeneration ~= lastSessionGeneration then
    lastSessionGeneration = sessionGeneration
    resetAll(true)
    geometryBuilt = false
  end

  local sim = ac and ac.getSim and ac.getSim()
  local trackLength = sim and sim.trackLengthM
  if trackLength ~= lastTrackLengthM then
    lastTrackLengthM = trackLength
    geometryBuilt = false
  end
  if not geometryBuilt then buildGeometry(trackLength) end

  stateTime = stateTime + dt
  local now = stateTime
  stoppedCount = 0

  local totalCars = #sortedCars
  for i = 1, totalCars do
    local car = sortedCars[i]
    local carIndex = car and car.index
    if validIndex(carIndex) and carIndex > 0 then
      local isAI, isActive, isConnected = car.isAIControlled, car.isActive, car.isConnected
      if isAI == false or isActive == false or isConnected == false then
        -- Inactive/non-AI slots are not perception subjects.
      elseif isAI ~= true or isActive ~= true or isConnected ~= true then
        reportUnknown(UNKNOWN_CAR, carIndex, car.splinePosition)
      else
        processSubject(car, carIndex, dt, now)
      end
    end
  end

  if not pendingParticipantsValid() then resetPending() end

  updateSamples(now)
  evaluateStopped(now)
  finalizeGroups(now)
  flushSuppressed(now)
end

---Exposed for tests and future diagnostics; observations stay enabled only through storage.
---@return boolean
function IncidentPerception.isEnabled()
  return featureEnabled
end

return IncidentPerception
