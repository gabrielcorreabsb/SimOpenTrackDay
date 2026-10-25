local Logger = {}
local getFullMessage

-- OBS1-A is intentionally opt-in and process-local; it is not persisted.
Logger.OBS1_ENABLED = false
Logger.OBS1_FOCUS_CAR = -1
Logger.OBS3_ENABLED = false
Logger.OBS3_TARGET_CAR = -1
Logger.OBS3_PEER_CAR_1 = -1
Logger.OBS3_PEER_CAR_2 = -1

local OBS_CAPACITY, OBS_DETAIL_CAP, OBS_LINE_CAP = 256, 64, 160
local OBS_DETAIL_LINE_CAP, OBS_BYTE_CAP, OBS_LINE_BYTES, OBS_MARKER_RESERVE = 48, 61440, 384, 1152
local OBS_RING = {}
for i = 1, OBS_CAPACITY do OBS_RING[i] = {} end
local obsHead, obsCount, obsSeq = 1, 0, 0
local obsDetailCount, obsAttempts, obsDetailLines, obsBytes = 0, 0, 0, 0
local obsSinkReturned, obsSinkThrew, obsSinkUnavailable = 0, 0, 0
local obsFormatFailures, obsDetailAdmissionDrops, obsDetailOutputDrops, obsGlobalOutputDrops = 0, 0, 0, 0
local obsOverwrites, obsDrops, obsLossMarkers = 0, 0, 0
local obsSessionGeneration, obsCaptureSession = nil, 0
local obsSessionInitialized = false
local obsHeaderWritten = false
local obsDetailAdmissionMarker, obsDetailOutputMarker = false, false
local obsOutputSaturated, obsOutputMarkerWritten, obsOutputFormatterFailed = false, false, false
local rawget, type, pcall, tostring, format = rawget, type, pcall, tostring, string.format
local sub = string.sub
local min = math.min
local UNKNOWN = 'UNKNOWN'

-- OBS3 stores only configured cars in a fixed, session-bounded frame store.
local OBS3_WINDOWS, OBS3_FRAMES, OBS3_SLOTS, OBS3_TRIALS = 8, 200, 3, 64
local OBS3_STORE = {}
for i = 1, OBS3_WINDOWS * OBS3_FRAMES do
  local frame = { slots = {} }
  for j = 1, OBS3_SLOTS do frame.slots[j] = {} end
  OBS3_STORE[i] = frame
end
local obs3Frames, obs3Windows, obs3Trials, obs3WindowFrames, obs3WindowStart, obs3LastRateTime = 0, 0, 0, 0, nil, nil
local obs3Active, obs3Discontinuous, obs3Config = false, false, nil
local obs3ConfigTarget, obs3ConfigPeer1, obs3ConfigPeer2
local obs3Abandoned, obs3MissingTarget, obs3MissingPeers = 0, 0, 0
local obs3Generation
local obs3IdentityIndex, obs3IdentityGeneration = { nil, nil, nil }, { nil, nil, nil }
local obs3WindowDiscontinuities, obs3WindowMissingTarget, obs3WindowMissingPeers = 0, 0, 0
local OBS3_REASON_SHORT = { ['time-cap'] = 'time', ['frame-cap'] = 'frames', ['car-generation-changed'] = 'generation',
  ['target-missing'] = 'target-missing', ['target-read-fault'] = 'target-fault', ['peer-read-fault'] = 'peer-fault',
  ['disabled-or-OBS1-off'] = 'disabled', ['replay-or-not-started'] = 'replay', ['replay-disable-or-suspension'] = 'suspend',
  ['not-live'] = 'not-live', ['sim-unavailable'] = 'sim-fault', ['sim-context-unknown'] = 'sim-unknown',
  ['configuration-changed'] = 'config', ['invalid-target'] = 'bad-target', ['invalid-clock'] = 'bad-clock',
  ['clock-regressed'] = 'clock-back', ['lifecycle-invalidation'] = 'lifecycle', ['car-jump'] = 'jump', ['car-swap'] = 'swap' }

local function boundedScalar(value)
  if type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge then return value end
  if type(value) == 'string' then return sub(value, 1, 48) end
  return UNKNOWN
end

local function boundedIncrement(value)
  return min(value + 1, 2147483647)
end

local function boundedFlag(value)
  if type(value) == 'boolean' then return value end
  return UNKNOWN
end

local function emitOBSLine(message, isDetail, isMarker)
  if obsOutputSaturated then return false end
  if isDetail and obsDetailLines >= OBS_DETAIL_LINE_CAP then
    obsDetailOutputDrops = boundedIncrement(obsDetailOutputDrops)
    if not obsDetailOutputMarker then
      obsDetailOutputMarker = true
      obsLossMarkers = boundedIncrement(obsLossMarkers)
      emitOBSLine('[OBS1] selected-car detail output limit reached; global events continue', false, false)
    end
    return false
  end

  local ok, envelope = pcall(getFullMessage, message)
  if not ok or type(envelope) ~= 'string' then
    obsFormatFailures = boundedIncrement(obsFormatFailures)
    obsDrops = boundedIncrement(obsDrops)
    obsOutputFormatterFailed, obsOutputSaturated = true, true
    return false
  end
  if #envelope > OBS_LINE_BYTES then envelope = sub(envelope, 1, OBS_LINE_BYTES) end

  -- Only the final global truncation marker may spend the reserved attempt.
  local attemptLimit = isMarker and OBS_LINE_CAP or (OBS_LINE_CAP - 1)
  local byteLimit = isMarker and OBS_BYTE_CAP or (OBS_BYTE_CAP - OBS_MARKER_RESERVE)
  if obsAttempts >= attemptLimit or obsBytes + #envelope > byteLimit then
    if not isMarker then
      obsGlobalOutputDrops = boundedIncrement(obsGlobalOutputDrops)
      obsOutputSaturated = true
      if not obsOutputMarkerWritten then
        obsOutputMarkerWritten = true
        obsLossMarkers = boundedIncrement(obsLossMarkers)
        obsOutputSaturated = false
        emitOBSLine('[OBS1] global output truncated; ring continues, log absence is not event absence', false, true)
        obsOutputSaturated = true
      end
    else
      obsOutputSaturated = true
    end
    return false
  end

  -- Reserve the attempt and byte budget before calling the sink: it may throw after writing.
  obsAttempts = boundedIncrement(obsAttempts)
  obsBytes = obsBytes + #envelope
  if isDetail then obsDetailLines = boundedIncrement(obsDetailLines) end
  local acTable = rawget(_G, 'ac')
  local sink = type(acTable) == 'table' and rawget(acTable, 'log') or nil
  if type(sink) ~= 'function' then
    obsSinkUnavailable = boundedIncrement(obsSinkUnavailable)
  else
    local sinkOK = pcall(sink, envelope)
    if sinkOK then obsSinkReturned = boundedIncrement(obsSinkReturned)
    else obsSinkThrew = boundedIncrement(obsSinkThrew) end
  end
  return true
end

local function observeProtected(kind, carIndex, generation, incidentIndex, zoneIndex, detail, previousState, referenceSession, extra, resource)
  if rawget(Logger, 'OBS1_ENABLED') ~= true then return end
  local carManager = rawget(_G, 'CarManager')
  local sessionGeneration = type(carManager) == 'table' and carManager.sessionGeneration or nil
  if not obsSessionInitialized then
    obsSessionGeneration = sessionGeneration
    obsSessionInitialized = true
  elseif sessionGeneration ~= nil and sessionGeneration ~= obsSessionGeneration then
    obsSessionGeneration = sessionGeneration
    obsCaptureSession = boundedIncrement(obsCaptureSession)
    obsHead, obsCount, obsSeq = 1, 0, 0
    obsDetailCount, obsAttempts, obsDetailLines, obsBytes = 0, 0, 0, 0
    obsSinkReturned, obsSinkThrew, obsSinkUnavailable = 0, 0, 0
    obsFormatFailures, obsDetailAdmissionDrops, obsDetailOutputDrops, obsGlobalOutputDrops = 0, 0, 0, 0
    obsOverwrites, obsDrops, obsLossMarkers = 0, 0, 0
    obsHeaderWritten, obsDetailAdmissionMarker, obsDetailOutputMarker = false, false, false
    obsOutputSaturated, obsOutputMarkerWritten, obsOutputFormatterFailed = false, false, false
  end

  local isGlobal = type(kind) == 'string' and (sub(kind, 1, 9) == 'incident-' or sub(kind, 1, 6) == 'queue-'
    or sub(kind, 1, 5) == 'zone-' or sub(kind, 1, 8) == 'pending-' or sub(kind, 1, 10) == 'lifecycle-'
     or sub(kind, 1, 8) == 'session-' or sub(kind, 1, 9) == 'collision-' or sub(kind, 1, 9) == 'callback-'
     or sub(kind, 1, 8) == 'control-' or sub(kind, 1, 5) == 'obs3-'
    or sub(kind, -10) == '-essential')
  local isDetail = not isGlobal
  if isDetail and (type(carIndex) ~= 'number' or carIndex < 0 or carIndex ~= rawget(Logger, 'OBS1_FOCUS_CAR')) then return end
  if isDetail and obsDetailCount >= OBS_DETAIL_CAP then
    obsDetailAdmissionDrops = boundedIncrement(obsDetailAdmissionDrops)
    if not obsDetailAdmissionMarker then
      obsDetailAdmissionMarker = true
      obsLossMarkers = boundedIncrement(obsLossMarkers)
      emitOBSLine('[OBS1] selected-car detail admission limit reached; global events continue', false, false)
    end
    return
  end

  obsSeq = boundedIncrement(obsSeq)
  local slot
  if obsCount < OBS_CAPACITY then
    slot = (obsHead + obsCount - 1) % OBS_CAPACITY + 1
    obsCount = obsCount + 1
  else
    slot = obsHead
    obsHead = obsHead % OBS_CAPACITY + 1
    obsOverwrites = boundedIncrement(obsOverwrites)
  end
  local record = OBS_RING[slot]
  record.sequence, record.capture, record.session = obsSeq, obsCaptureSession, boundedScalar(sessionGeneration)
  record.referenceSession = boundedScalar(referenceSession)
  record.kind, record.car, record.generation = boundedScalar(kind), boundedScalar(carIndex), boundedScalar(generation)
  record.incident, record.zone, record.detail, record.previousState = boundedScalar(incidentIndex), boundedScalar(zoneIndex),
    boundedScalar(detail), boundedScalar(previousState)
  record.extra = boundedScalar(extra)
  record.resource = boundedScalar(resource)
  record.activeTime, record.activeTimeValid = nil, false
  record.wallTime, record.wallTimeValid = nil, false
  local contextManager = type(carManager) == 'table' and carManager or nil
  record.context = boundedScalar(contextManager and rawget(contextManager, 'runtimeSuspensionReason'))
  record.runtimeEnabled = boundedFlag(contextManager and rawget(contextManager, 'runtimeEnabled'))
  record.runtimePaused = boundedFlag(contextManager and rawget(contextManager, 'runtimePaused'))
  record.runtimeLive = boundedFlag(contextManager and rawget(contextManager, 'runtimeLive'))
  if record.context == UNKNOWN and record.runtimeLive == true then record.context = 'live' end
  local osLibrary = rawget(_G, 'os')
  local dateFunction = type(osLibrary) == 'table' and rawget(osLibrary, 'date') or nil
  if type(dateFunction) == 'function' then
    local wallOk, wallValue = pcall(dateFunction, '%H:%M:%S')
    if wallOk and type(wallValue) == 'string' then
      record.wallTime, record.wallTimeValid = sub(wallValue, 1, 24), true
    end
  end
  local gameTime = rawget(_G, 'GameTimeManager')
  if type(gameTime) == 'table' then
    local getter = rawget(gameTime, 'getPlayingGameTime')
    if type(getter) == 'function' then
      local ok, value = pcall(getter)
      if ok and type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge then
        record.activeTime, record.activeTimeValid = value, true
      end
    end
  end
  if isDetail then obsDetailCount = boundedIncrement(obsDetailCount) end
  if obsOutputSaturated then
    if isDetail then obsDetailOutputDrops = boundedIncrement(obsDetailOutputDrops)
    else obsGlobalOutputDrops = boundedIncrement(obsGlobalOutputDrops) end
    return true
  end
  if not obsHeaderWritten then
    obsHeaderWritten = true
    if emitOBSLine('[OBS1] capture=' .. tostring(obsCaptureSession) .. ' session=' .. tostring(sessionGeneration or 'UNKNOWN')
      .. ' refSession=per-record source=UNKNOWN installed=UNKNOWN csp=UNKNOWN track=UNKNOWN flood=UNKNOWN other-writers=UNKNOWN', false, false) then
    end
  end
  if obsOutputSaturated then
    if isDetail then obsDetailOutputDrops = boundedIncrement(obsDetailOutputDrops)
    else obsGlobalOutputDrops = boundedIncrement(obsGlobalOutputDrops) end
    return true
  end
  local active, wall, line = UNKNOWN, UNKNOWN, nil
  if record.activeTimeValid then
    local activeOK
    activeOK, active = pcall(format, '%.3f', record.activeTime)
    if not activeOK then
      obsFormatFailures = boundedIncrement(obsFormatFailures)
      obsOutputFormatterFailed, obsOutputSaturated = true, true
      return true
    end
  end
  if record.wallTimeValid then wall = record.wallTime end
  local formatOK
  formatOK, line = pcall(format, '[OBS1] seq=%d session=%s refSession=%s active=%s context=%s wall=%s kind=%s carRef=%s genRef=%s incident=%s zone=%s from=%s detail=%s extra=%s resource=%s',
    obsSeq, tostring(record.session or 'UNKNOWN'), tostring(record.referenceSession or 'UNKNOWN'), active, tostring(record.context), wall,
    tostring(record.kind or 'UNKNOWN'), tostring(record.car or 'UNKNOWN'), tostring(record.generation or 'UNKNOWN'),
     tostring(record.incident or 'UNKNOWN'), tostring(record.zone or 'UNKNOWN'), tostring(record.previousState or 'UNKNOWN'),
     tostring(record.detail or ''), tostring(record.extra or 'UNKNOWN'), tostring(record.resource or 'UNKNOWN'))
  if not formatOK then
    obsFormatFailures = boundedIncrement(obsFormatFailures)
    obsOutputFormatterFailed, obsOutputSaturated = true, true
    return true
  end
  emitOBSLine(line, isDetail, false)
  return true
end

-- Returns true when the observation was accepted into the bounded ring; it never means the sink delivered it.
function Logger.observe(kind, carIndex, generation, incidentIndex, zoneIndex, detail, previousState, referenceSession, extra, resource)
  if rawget(Logger, 'OBS1_ENABLED') ~= true then return false end
  local ok, recorded = pcall(observeProtected, kind, carIndex, generation, incidentIndex, zoneIndex, detail, previousState, referenceSession, extra, resource)
  return ok and recorded == true
end

local function finiteNumber(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function obs3UnknownSlot(slot, index)
  slot.carIndex = finiteNumber(index) and index >= 0 and index % 1 == 0 and index or UNKNOWN
  slot.valid, slot.generation = false, UNKNOWN
  slot.positionX, slot.positionY, slot.positionZ = UNKNOWN, UNKNOWN, UNKNOWN
  slot.speedKmh, slot.splinePosition = UNKNOWN, UNKNOWN
  slot.isInPitlane, slot.isInPit = UNKNOWN, UNKNOWN
  slot.collisionDepth, slot.collidedWith = UNKNOWN, UNKNOWN
  slot.state, slot.ownTopSpeed, slot.ownTopSpeedOwner, slot.ownThrottle, slot.ownThrottleOwner = UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN
end

local function obs3Summary(reason, abandoned)
  if not obs3Active then return end
  obs3Active = false
  if abandoned then obs3Abandoned = boundedIncrement(obs3Abandoned) end
  if obs3Trials >= OBS3_TRIALS then return end
  obs3Trials = obs3Trials + 1
  local shortReason = OBS3_REASON_SHORT[reason] or 'other'
  local ok, detail = pcall(format, 'w%d f%d %s mt%d mp%d d%d', obs3Windows,
    obs3WindowFrames, shortReason, obs3WindowMissingTarget, obs3WindowMissingPeers, obs3WindowDiscontinuities)
  Logger.observe('obs3-window-summary', obs3ConfigTarget, nil, nil, nil,
    ok and detail or 'summary-format-failed')
end

local function obs3Abandon(reason)
  if obs3Active then
    obs3Discontinuous = true
    obs3Summary(reason, true)
  end
end

local function obs3ReadCar(index, slot)
  slot.carIndex = index
  local acTable = rawget(_G, 'ac')
  local getter = type(acTable) == 'table' and acTable.getCar or nil
  local getOK, car = pcall(getter, index)
  if not getOK then return false, true end
  if car == nil or car.index ~= index then
    obs3UnknownSlot(slot, index)
    return false, false
  end
  slot.valid = true
  local position = car.position
  slot.positionX = position and finiteNumber(position.x) and position.x or UNKNOWN
  slot.positionY = position and finiteNumber(position.y) and position.y or UNKNOWN
  slot.positionZ = position and finiteNumber(position.z) and position.z or UNKNOWN
  local speed, spline = car.speedKmh, car.splinePosition
  slot.speedKmh = finiteNumber(speed) and speed or UNKNOWN
  slot.splinePosition = finiteNumber(spline) and spline or UNKNOWN
  local pitlane, pit = car.isInPitlane, car.isInPit
  slot.isInPitlane = boundedFlag(pitlane)
  slot.isInPit = boundedFlag(pit)
  local depth, collided = car.collisionDepth, car.collidedWith
  slot.collisionDepth = finiteNumber(depth) and depth or UNKNOWN
  slot.collidedWith = finiteNumber(collided) and collided or UNKNOWN
  local manager = rawget(_G, 'CarManager')
  local generationGetter = type(manager) == 'table' and rawget(manager, 'getCarGeneration') or nil
  if type(generationGetter) == 'function' then
    local ok, generation = pcall(generationGetter, index)
    slot.generation = ok and finiteNumber(generation) and generation or UNKNOWN
  else slot.generation = UNKNOWN end
  local stateMachine = rawget(_G, 'CarStateMachine')
  local stateGetter = type(stateMachine) == 'table' and rawget(stateMachine, 'getCurrentState') or nil
  if type(stateGetter) == 'function' then
    local ok, state = pcall(stateGetter, index)
    slot.state = ok and boundedScalar(state) or UNKNOWN
  else slot.state = UNKNOWN end
  local operations = rawget(_G, 'CarOperations')
  if type(operations) == 'table' then
    local topApplied = rawget(operations, '_topSpeedApplied')
    local throttleApplied = rawget(operations, '_throttleApplied')
    local top = type(topApplied) == 'table' and rawget(topApplied, index) or nil
    local throttle = type(throttleApplied) == 'table' and rawget(throttleApplied, index) or nil
    if type(top) == 'table' and rawget(top, 'active') == true then
      slot.ownTopSpeed, slot.ownTopSpeedOwner = boundedScalar(rawget(top, 'value')), boundedScalar(rawget(top, 'owner'))
    else slot.ownTopSpeed, slot.ownTopSpeedOwner = UNKNOWN, UNKNOWN end
    if type(throttle) == 'table' and rawget(throttle, 'active') == true then
      slot.ownThrottle, slot.ownThrottleOwner = boundedScalar(rawget(throttle, 'value')), boundedScalar(rawget(throttle, 'owner'))
    else slot.ownThrottle, slot.ownThrottleOwner = UNKNOWN, UNKNOWN end
  else
    slot.ownTopSpeed, slot.ownTopSpeedOwner, slot.ownThrottle, slot.ownThrottleOwner = UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN
  end
  return true
end

local function obs3Car(index, slot)
  local ok, valid, fault = pcall(obs3ReadCar, index, slot)
  if not ok then obs3UnknownSlot(slot, index); return false, true end
  return valid, fault
end

local function readSimContext(sim)
  return sim.isPaused, sim.isReplayActive, sim.isSessionStarted, sim.isLive
end

local function obs3TickProtected(dt)
  local manager = rawget(_G, 'CarManager')
  local generation = type(manager) == 'table' and rawget(manager, 'sessionGeneration') or nil
  if obs3Generation == nil then obs3Generation = generation
  elseif generation ~= nil and generation ~= obs3Generation then
    obs3Generation = generation
    obs3Frames, obs3Windows, obs3Trials, obs3WindowFrames, obs3WindowStart, obs3LastRateTime = 0, 0, 0, 0, nil, nil
    obs3Active, obs3Discontinuous, obs3Config = false, false, nil
    obs3Abandoned, obs3MissingTarget, obs3MissingPeers = 0, 0, 0
    obs3WindowDiscontinuities, obs3WindowMissingTarget, obs3WindowMissingPeers = 0, 0, 0
    for i = 1, OBS3_SLOTS do obs3IdentityIndex[i], obs3IdentityGeneration[i] = nil, nil end
  end
  local enabled = rawget(Logger, 'OBS3_ENABLED') == true and rawget(Logger, 'OBS1_ENABLED') == true
  if not enabled then obs3Abandon('disabled-or-OBS1-off'); return end
  local target, peer1, peer2 = rawget(Logger, 'OBS3_TARGET_CAR'), rawget(Logger, 'OBS3_PEER_CAR_1'), rawget(Logger, 'OBS3_PEER_CAR_2')
  if target ~= obs3ConfigTarget or peer1 ~= obs3ConfigPeer1 or peer2 ~= obs3ConfigPeer2 then
    obs3Abandon('configuration-changed')
    obs3Discontinuous = true
    obs3ConfigTarget, obs3ConfigPeer1, obs3ConfigPeer2 = target, peer1, peer2
    obs3Config = true
    for i = 1, OBS3_SLOTS do obs3IdentityIndex[i], obs3IdentityGeneration[i] = nil, nil end
  end
  if type(manager) ~= 'table' or rawget(manager, 'runtimeEnabled') ~= true then
    obs3Abandon('replay-disable-or-suspension'); return
  end
  local acTable = rawget(_G, 'ac')
  local simGetter = type(acTable) == 'table' and rawget(acTable, 'getSim') or nil
  if type(simGetter) ~= 'function' then obs3Abandon('sim-unavailable'); return end
  local simOK, sim = pcall(simGetter)
  if not simOK or sim == nil then obs3Abandon('sim-unavailable'); return end
  local fieldsOK, paused, replay, started, live = pcall(readSimContext, sim)
  if not fieldsOK or type(paused) ~= 'boolean' or type(replay) ~= 'boolean'
    or type(started) ~= 'boolean' or type(live) ~= 'boolean' then
    obs3Abandon('sim-context-unknown'); return
  end
  if replay or not started then obs3Abandon('replay-or-not-started'); return end
  if paused or rawget(manager, 'runtimePaused') == true then obs3Discontinuous = true; return end
  if not live or rawget(manager, 'runtimeLive') ~= true then
    obs3Abandon('not-live'); return
  end
  if not finiteNumber(target) or target < 0 or target % 1 ~= 0 then
    obs3Abandon('invalid-target'); return
  end
  local gameTime = rawget(_G, 'GameTimeManager')
  local getter = type(gameTime) == 'table' and rawget(gameTime, 'getPlayingGameTime') or nil
  local clockOK, now
  if type(getter) == 'function' then clockOK, now = pcall(getter) end
  if not clockOK or not finiteNumber(now) or now < 0 then
    obs3Abandon('invalid-clock'); return
  end
  if obs3LastRateTime and now < obs3LastRateTime then
    obs3Abandon('clock-regressed')
    obs3LastRateTime = nil
  end
  if obs3Active and now - obs3WindowStart >= 10 then
    obs3Summary('time-cap', false)
    obs3Discontinuous = true
  end
  if obs3LastRateTime and now - obs3LastRateTime < 0.05 then return end
  obs3LastRateTime = now
  if not obs3Active then
    if obs3Windows >= OBS3_WINDOWS then return end
    if obs3Frames >= OBS3_WINDOWS * OBS3_FRAMES then return end
    obs3Windows = obs3Windows + 1
    obs3WindowFrames, obs3WindowStart = 0, now
    obs3WindowDiscontinuities, obs3WindowMissingTarget, obs3WindowMissingPeers = 0, 0, 0
    obs3Active = true
    if obs3Trials < OBS3_TRIALS then
      obs3Trials = obs3Trials + 1
      Logger.observe('obs3-window-start', target, nil, nil, nil, 'configured-target-and-peers-only')
    end
  end
  if obs3WindowFrames >= OBS3_FRAMES or obs3Frames >= OBS3_WINDOWS * OBS3_FRAMES then
    obs3Abandon('frame-cap'); return
  end
  local frame = OBS3_STORE[obs3Frames + 1]
  frame.time, frame.discontinuity = now, obs3Discontinuous
  frame.window = obs3Windows
  local okTarget, targetFault = obs3Car(target, frame.slots[1])
  if targetFault then obs3Abandon('target-read-fault'); return end
  if not okTarget then
    obs3MissingTarget = boundedIncrement(obs3MissingTarget)
    obs3WindowMissingTarget = boundedIncrement(obs3WindowMissingTarget)
    obs3Abandon('target-missing'); return
  end
  local okPeer1, okPeer2 = false, false
  local peer1Fault, peer2Fault = false, false
  if type(peer1) == 'number' and finiteNumber(peer1) and peer1 >= 0 and peer1 % 1 == 0 then okPeer1, peer1Fault = obs3Car(peer1, frame.slots[2])
  else obs3UnknownSlot(frame.slots[2], peer1) end
  if type(peer2) == 'number' and finiteNumber(peer2) and peer2 >= 0 and peer2 % 1 == 0 then okPeer2, peer2Fault = obs3Car(peer2, frame.slots[3])
  else obs3UnknownSlot(frame.slots[3], peer2) end
  if peer1Fault or peer2Fault then obs3Abandon('peer-read-fault'); return end
  if type(peer1) == 'number' and finiteNumber(peer1) and peer1 >= 0 and not okPeer1 then
    obs3MissingPeers, obs3WindowMissingPeers = boundedIncrement(obs3MissingPeers), boundedIncrement(obs3WindowMissingPeers)
  end
  if type(peer2) == 'number' and finiteNumber(peer2) and peer2 >= 0 and not okPeer2 then
    obs3MissingPeers, obs3WindowMissingPeers = boundedIncrement(obs3MissingPeers), boundedIncrement(obs3WindowMissingPeers)
  end
  local generationChanged = false
  for i = 1, OBS3_SLOTS do
    local slot = frame.slots[i]
    local carIndex = i == 1 and target or (i == 2 and peer1 or peer2)
    if obs3IdentityIndex[i] == carIndex and slot.generation ~= UNKNOWN
      and obs3IdentityGeneration[i] ~= nil and obs3IdentityGeneration[i] ~= UNKNOWN
      and slot.generation ~= obs3IdentityGeneration[i] then generationChanged = true end
  end
  for i = 1, OBS3_SLOTS do
    local carIndex = i == 1 and target or (i == 2 and peer1 or peer2)
    obs3IdentityIndex[i], obs3IdentityGeneration[i] = carIndex, frame.slots[i].generation
  end
  if generationChanged then
    obs3Abandon('car-generation-changed')
    obs3Discontinuous = true
    return
  end
  if obs3Discontinuous then obs3WindowDiscontinuities = boundedIncrement(obs3WindowDiscontinuities) end
  obs3Discontinuous = false
  obs3Frames, obs3WindowFrames = obs3Frames + 1, obs3WindowFrames + 1
  if obs3WindowFrames >= OBS3_FRAMES then obs3Summary('frame-cap', false) end
end

function Logger.tickOBS3(dt)
  pcall(obs3TickProtected, dt)
end

function Logger.invalidateOBS3(reason)
  pcall(function()
    obs3Abandon(type(reason) == 'string' and reason or 'lifecycle-invalidation')
    obs3Discontinuous = true
  end)
end

function Logger.getOBS3Stats()
  local ok, result = pcall(function()
    return { frames = obs3Frames, windowsStarted = obs3Windows, attempts = obs3Trials,
      active = obs3Active, abandoned = obs3Abandoned, missingTarget = obs3MissingTarget,
      missingPeers = obs3MissingPeers, enabled = rawget(Logger, 'OBS3_ENABLED') == true,
      windowLimit = OBS3_WINDOWS, framesPerWindow = OBS3_FRAMES,
      totalFrameLimit = OBS3_WINDOWS * OBS3_FRAMES, attemptLimit = OBS3_TRIALS,
      sampleHzLimit = 20, activeWindowSeconds = 10 }
  end)
  return ok and result or nil
end

function Logger.getOBS3Frame(index)
  local ok, result = pcall(function()
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > obs3Frames then return nil end
    local source = OBS3_STORE[index]
    local copy = { time = source.time, window = source.window, discontinuity = source.discontinuity, slots = {} }
    for i = 1, OBS3_SLOTS do
      local slot = source.slots[i]
      local output = {}
      for key, value in pairs(slot) do output[key] = value end
      copy.slots[i] = output
    end
    return copy
  end)
  return ok and result or nil
end

function Logger.getOBS1Stats()
  local ok, result = pcall(function()
    return { count = obsCount, details = obsDetailCount, attempts = obsAttempts,
      sinkReturned = obsSinkReturned, sinkThrewUncertain = obsSinkThrew, sinkUnavailable = obsSinkUnavailable,
      detailLines = obsDetailLines, detailAdmissionDrops = obsDetailAdmissionDrops,
      detailOutputDrops = obsDetailOutputDrops, globalOutputDrops = obsGlobalOutputDrops,
      formatFailures = obsFormatFailures, bytesAttempted = obsBytes, overwrites = obsOverwrites, drops = obsDrops,
      lossMarkers = obsLossMarkers, detailAdmissionLimited = obsDetailAdmissionMarker,
      detailOutputLimited = obsDetailOutputMarker, outputSaturated = obsOutputSaturated,
      outputFormatterFailed = obsOutputFormatterFailed, capture = obsCaptureSession }
  end)
  if ok then return result end
  return nil
end

local function copyOBS1Record(source)
  return { sequence = source.sequence, capture = source.capture, session = source.session,
    kind = source.kind, car = source.car, generation = source.generation, referenceSession = source.referenceSession,
    incident = source.incident, zone = source.zone, detail = source.detail, previousState = source.previousState,
    extra = source.extra, resource = source.resource,
    activeTime = source.activeTime, activeTimeValid = source.activeTimeValid,
    wallTime = source.wallTime, wallTimeValid = source.wallTimeValid,
    context = source.context, runtimeEnabled = source.runtimeEnabled,
    runtimePaused = source.runtimePaused, runtimeLive = source.runtimeLive }
end

function Logger.getOBS1Record(index)
  local ok, result = pcall(function()
    if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > obsCount then return nil end
    local source = OBS_RING[(obsHead + index - 2) % OBS_CAPACITY + 1]
    return copyOBS1Record(source)
  end)
  if ok then return result end
  return nil
end

local function recentForCarProtected(carIndex)
  if type(carIndex) ~= 'number' or carIndex ~= carIndex or carIndex < 0
    or carIndex >= math.huge or carIndex % 1 ~= 0 then return nil end

  local scanned, matchingCount = obsCount, 0
  local slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8
  for i = 1, scanned do
    local slot = (obsHead + i - 2) % OBS_CAPACITY + 1
    if OBS_RING[slot].car == carIndex then
      matchingCount = matchingCount + 1
      if matchingCount == 1 then slot1 = slot
      elseif matchingCount == 2 then slot2 = slot
      elseif matchingCount == 3 then slot3 = slot
      elseif matchingCount == 4 then slot4 = slot
      elseif matchingCount == 5 then slot5 = slot
      elseif matchingCount == 6 then slot6 = slot
      elseif matchingCount == 7 then slot7 = slot
      elseif matchingCount == 8 then slot8 = slot
      else
        slot1, slot2, slot3, slot4, slot5, slot6, slot7 = slot2, slot3, slot4, slot5, slot6, slot7, slot8
        slot8 = slot
      end
    end
  end

  local retained = math.min(matchingCount, 8)
  local records = {}
  for i = 1, retained do
    local slot
    if i == 1 then slot = slot1 elseif i == 2 then slot = slot2 elseif i == 3 then slot = slot3
    elseif i == 4 then slot = slot4 elseif i == 5 then slot = slot5 elseif i == 6 then slot = slot6
    elseif i == 7 then slot = slot7 else slot = slot8 end
    records[i] = copyOBS1Record(OBS_RING[slot])
  end
  local stats = Logger.getOBS1Stats()
  if type(stats) ~= 'table' then return nil end
  return { car = carIndex, records = records, stats = stats, matchingCount = matchingCount,
    scanned = scanned, limited = matchingCount > 8 }
end

function Logger.getOBS1RecentForCar(carIndex)
  local ok, result = pcall(recentForCarProtected, carIndex)
  if ok then return result end
  return nil
end

-- CSP log file at 'Documents\Assetto Corsa\logs\custom_shaders_patch.log'

local APP_NAME_STRING = string.format("[%s]", Constants.APP_NAME)

local getTimestampString = function()
  -- return os.date("%Y-%m-%d %H:%M:%S")
  return string.format("[%s]", os.date("%H:%M:%S"))
end

getFullMessage = function(msg)
  return string.format("%s %s %s", getTimestampString(), APP_NAME_STRING, msg)
end

---Logs the message to the CSP log
---@param msg string
function Logger.log(msg)
  ac.log(getFullMessage(msg))
end

---Logs the message as a warning to the CSP log
---@param msg string
function Logger.warn(msg)
  ac.warn(getFullMessage(msg))
end

---Logs the message as an error to the CSP log
---@param msg string
function Logger.error(msg)
  ac.error(getFullMessage(msg))
end

return Logger
