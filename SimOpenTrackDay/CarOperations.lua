local CarOperations = {}

-- bindings
local ac = ac
local ac_getCar = ac.getCar
local ac_getCarMaxSpeedWithGear = ac.getCarMaxSpeedWithGear
local ac_getTrackAISplineSides = ac.getTrackAISplineSides
local ac_overrideCarControls = ac.overrideCarControls
local ac_setTargetCar = ac.setTargetCar
local ac_setTurningLights = ac.setTurningLights
local string = string
local string_format = string.format
local string_sub = string.sub
local pcall = pcall
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
local physics_setAISplineAbsoluteOffset = physics.setAISplineAbsoluteOffset
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
local Logger_observe = Logger.observe
local rawget = rawget
local Logger_error = Logger.error
local Logger_log = Logger.log
local Logger_warn = Logger.warn
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_getLateralOffsetSign = RaceTrackManager.getLateralOffsetSign
local RaceTrackManager_getOppositeSide = RaceTrackManager.getOppositeSide
local RaceTrackManager_getOvertakingSide = RaceTrackManager.getOvertakingSide
local RaceTrackManager_getYieldingSide = RaceTrackManager.getYieldingSide
local RaceTrackManager_getTrackLengthMeters = RaceTrackManager.getTrackLengthMeters
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
local trafficPedalOwnership, trafficLateralOwnership = {}, {}
local CONTROL_TRACE_KIND = {
  ['control-setter-attempt'] = 1, ['control-setter-returned'] = 2, ['control-setter-threw-uncertain'] = 3,
  ['control-handback-attempt'] = 4, ['control-handback-returned'] = 5, ['control-handback-threw-uncertain'] = 6
}
local CONTROL_TRACE_CARS, CONTROL_TRACE_RESOURCES, CONTROL_TRACE_KINDS = 256, 2, 6
local CONTROL_TRACE_OWNER, CONTROL_TRACE_VALUE = {}, {}
for i = 1, CONTROL_TRACE_CARS * CONTROL_TRACE_RESOURCES * CONTROL_TRACE_KINDS do
  CONTROL_TRACE_OWNER[i], CONTROL_TRACE_VALUE[i] = false, false
end
local function controlTraceOffset(carIndex, resource)
  if type(carIndex) ~= 'number' or carIndex < 0 or carIndex >= CONTROL_TRACE_CARS or carIndex % 1 ~= 0 then return nil end
  local resourceIndex = resource == 'setAITopSpeed' and 1 or resource == 'setAIThrottleLimit' and 2 or nil
  if not resourceIndex then return nil end
  return (carIndex * CONTROL_TRACE_RESOURCES + resourceIndex - 1) * CONTROL_TRACE_KINDS
end
local function resetControlTrace(carIndex, resource)
  if rawget(Logger, 'OBS1_ENABLED') ~= true then return end
  local offset = controlTraceOffset(carIndex, resource)
  if not offset then return end
  for i = 1, CONTROL_TRACE_KINDS do
    CONTROL_TRACE_OWNER[offset + i], CONTROL_TRACE_VALUE[offset + i] = false, false
  end
end

local function observeControlImpl(kind, carIndex, owner, value, resource)
  if rawget(Logger, 'OBS1_ENABLED') ~= true or type(Logger_observe) ~= 'function' then return end
  local kindSlot = CONTROL_TRACE_KIND[kind]
  local offset = kindSlot and controlTraceOffset(carIndex, resource) or nil
  if offset then
    local slot = offset + kindSlot
    if CONTROL_TRACE_OWNER[slot] == owner and CONTROL_TRACE_VALUE[slot] == value then return end
    CONTROL_TRACE_OWNER[slot], CONTROL_TRACE_VALUE[slot] = owner, value
  end
  local generation, session
  local manager = CarManager
  local generationGetter = rawget(manager, 'getCarGeneration')
  if type(generationGetter) == 'function' then
    local ok, result = pcall(generationGetter, carIndex)
    if ok then generation = result end
  end
  session = rawget(manager, 'sessionGeneration')
  Logger_observe(kind, carIndex, generation, nil, nil, value, owner, session, nil, resource)
end
local function observeControl(kind, carIndex, owner, value, resource)
  if rawget(Logger, 'OBS1_ENABLED') ~= true then return end
  pcall(observeControlImpl, kind, carIndex, owner, value, resource)
end

-- Ownership covers the AI top-speed, throttle-limit and caution APIs.
local CONTROL_LEASE_SECONDS = 1
local OWNER_PRIORITY = {
  INCIDENT_STOP = 100,
  ACCIDENT_NAVIGATION = 90,
  YELLOW_FLAG = 80,
  TRAFFIC_YIELD = 50,
  TRAFFIC_OVERTAKE = 50,
  NORMAL_TRAFFIC = 40,
  COMPAT = 10,
}
local OWNER_ORDER = {
  'INCIDENT_STOP', 'ACCIDENT_NAVIGATION', 'YELLOW_FLAG', 'TRAFFIC_YIELD', 'TRAFFIC_OVERTAKE', 'NORMAL_TRAFFIC', 'COMPAT',
}

-- F1-3 lateral avoidance tuning. All distances are metres unless stated otherwise.
local CAR_WIDTH_M = 1.8
local CAR_HALF_WIDTH_M = CAR_WIDTH_M * 0.5
local LATERAL_OBSTACLE_AHEAD_M = 120
local LATERAL_OBSTACLE_BAND = 0.6
local LATERAL_OBSTACLE_ON_TRACK = 1.0
local LATERAL_STOPPED_KMH = 24
local LATERAL_STOPPED_SECONDS = 2
local LATERAL_ENGAGE_SECONDS = 0.3
local LATERAL_SIDE_HOLD_SECONDS = 1.5
local LATERAL_RELEASE_BEHIND_M = 10
local LATERAL_CLEARANCE_M = CAR_WIDTH_M + 1.0
-- Lateral speed of the avoidance move in metres per second (independent of the edge distance;
-- run 5 used 0.8 x edge distance, about 1.2 m/s near an edge, far too slow).
local LATERAL_RAMP_MPS = 3.0
CarOperations._lateralAvoidance = CarOperations._lateralAvoidance or {}
CarOperations._topSpeedRequests = CarOperations._topSpeedRequests or {}
CarOperations._throttleRequests = CarOperations._throttleRequests or {}
CarOperations._cautionRequests = CarOperations._cautionRequests or {}
CarOperations._topSpeedApplied = CarOperations._topSpeedApplied or {}
CarOperations._throttleApplied = CarOperations._throttleApplied or {}
CarOperations._cautionApplied = CarOperations._cautionApplied or {}
CarOperations._topSpeedWinner = CarOperations._topSpeedWinner or {}
CarOperations._throttleWinner = CarOperations._throttleWinner or {}
CarOperations._cautionWinner = CarOperations._cautionWinner or {}
CarOperations._topSpeedAttempted = CarOperations._topSpeedAttempted or {}
CarOperations._throttleAttempted = CarOperations._throttleAttempted or {}
CarOperations._cautionAttempted = CarOperations._cautionAttempted or {}
-- Lateral offset arbitration. Unlike the pedal/caution controls, lateral values may be
-- negative (left of the AI line) and are expressed either in normalized spline units
-- or in metres from the AI line (absolute API).
CarOperations._lateralRequests = CarOperations._lateralRequests or {}
CarOperations._lateralWinner = CarOperations._lateralWinner or {}
CarOperations._lateralApplied = CarOperations._lateralApplied or {}
CarOperations._lateralAttempted = CarOperations._lateralAttempted or {}
CarOperations._resolutionId = 0

local function isCallable(value)
  local valueType = type(value)
  return valueType == 'function' or valueType == 'cdata'
end

local function controlResource(slots)
  if slots == CarOperations._topSpeedRequests then return 'setAITopSpeed' end
  if slots == CarOperations._throttleRequests then return 'setAIThrottleLimit' end
  return 'setAICaution'
end

local function controlWinners(slots)
  if slots == CarOperations._topSpeedRequests then return CarOperations._topSpeedWinner end
  if slots == CarOperations._throttleRequests then return CarOperations._throttleWinner end
  return CarOperations._cautionWinner
end

local function defaultAICaution()
  local ok, aiValues = pcall(StorageManager.getStorage_AICarValues)
  local value = ok and type(aiValues) == 'table' and aiValues.defaultAICaution or nil
  if type(value) ~= 'number' or value ~= value or value < 0 or value > 16 then return 3 end
  return value
end
local INCIDENT_STOP_SECONDS = 10
local INCIDENT_COUNTER_SECONDS = 1
local incidentEpisodes = {}
local incidentCompleted = {}
local incidentStateCompletion = {}
local getActiveGameTime

-- Temporary, non-persistent S2 trace. Keep disabled in shipped copies.
CarOperations.S2_DIAGNOSTICS_ENABLED = false
local s2DiagnosticSession, s2DiagnosticIncident
local s2DiagnosticOutcomes = {}
local s2DiagnosticEvents = {}
local s2DiagnosticCars = {}
local s2DiagnosticContext = {}
local function resetS2DiagnosticSession(session)
  s2DiagnosticSession, s2DiagnosticIncident = session, nil
  s2DiagnosticOutcomes, s2DiagnosticEvents, s2DiagnosticCars, s2DiagnosticContext = {}, {}, {}, {}
end
local function s2DiagnosticImpl(event, carIndex, episode, dedupeKey, field1, value1, field2, value2)
  if episode and (episode.session ~= CarManager.sessionGeneration
    or episode.generation ~= CarManager.getCarGeneration(carIndex)) then return end
  local session = episode and episode.session or CarManager.sessionGeneration
  if s2DiagnosticSession ~= session then
    resetS2DiagnosticSession(session)
  end
  if event == 'admitted' and not s2DiagnosticIncident then s2DiagnosticIncident = value1 end
  if not s2DiagnosticIncident then return end
  if event == 'admitted' and value1 ~= s2DiagnosticIncident then return end
  if episode and (episode.session ~= session or episode.generation ~= CarManager.getCarGeneration(carIndex)
    or not episode.incidents[s2DiagnosticIncident]) then return end
  local context = s2DiagnosticContext[carIndex]
  if context and (context.session ~= session or context.generation ~= CarManager.getCarGeneration(carIndex)) then return end
  if event == 'admitted' and not context then
    local participantCount = 0
    for _ in pairs(s2DiagnosticCars) do participantCount = participantCount + 1 end
    if participantCount < 2 then
      s2DiagnosticCars[carIndex] = true
      context = { generation = episode.generation, session = session, deadline = episode.deadline, incident = s2DiagnosticIncident }
      s2DiagnosticContext[carIndex] = context
    end
  end
  if not s2DiagnosticCars[carIndex] or not context then return end
  local perCarEvents = s2DiagnosticEvents[carIndex]
  if not perCarEvents then perCarEvents = { next = 1, count = 0 }; s2DiagnosticEvents[carIndex] = perCarEvents end
  local boundedKey = type(dedupeKey) == 'string' and string_sub(dedupeKey, 1, 48) or '-'
  local boundedEvent = type(event) == 'string' and string_sub(event, 1, 48) or 'unknown-event'
  for i = 1, perCarEvents.count do
    local entry = perCarEvents[i]
    if entry.key == boundedKey and entry.event == boundedEvent then return end
  end
  local eventSlot = perCarEvents.next
  local entry = perCarEvents[eventSlot]
  if not entry then entry = {}; perCarEvents[eventSlot] = entry; perCarEvents.count = math.min(perCarEvents.count + 1, 32) end
  entry.key, entry.event = boundedKey, boundedEvent
  perCarEvents.next = eventSlot % 32 + 1
  local detail = field1 ~= nil and value1 or field2 ~= nil and value2 or event
  Logger.observe('control-s2', carIndex, context.generation, context.incident, nil, detail, event, session, context.deadline)
end
local function s2Diagnostic(event, carIndex, episode, dedupeKey, field1, value1, field2, value2)
  if rawget(Logger, 'OBS1_ENABLED') ~= true then return end
  pcall(s2DiagnosticImpl, event, carIndex, episode, dedupeKey, field1, value1, field2, value2)
end
CarOperations._traceIncidentStop = s2Diagnostic
local function traceOutcomeImpl(episode, carIndex, operation, result)
  if not episode or not s2DiagnosticIncident or episode.session ~= CarManager.sessionGeneration
    or episode.session ~= s2DiagnosticSession or episode.generation ~= CarManager.getCarGeneration(carIndex)
    or not episode.incidents[s2DiagnosticIncident] or not s2DiagnosticCars[carIndex] then return end
  local context = s2DiagnosticContext[carIndex]
  if not context or context.session ~= episode.session or context.generation ~= episode.generation
    or context.incident ~= s2DiagnosticIncident then return end
  local outcomes = s2DiagnosticOutcomes[carIndex]
  if outcomes and outcomes[operation] == result then return end
  if not outcomes then outcomes = {}; s2DiagnosticOutcomes[carIndex] = outcomes end
  outcomes[operation] = result
  s2Diagnostic(result and 'setter-pcall-returned' or 'setter-failed-or-uncertain', carIndex, episode,
    operation, 'operation', operation)
end
local function traceOutcome(episode, carIndex, operation, result)
  if rawget(Logger, 'OBS1_ENABLED') == true then pcall(traceOutcomeImpl, episode, carIndex, operation, result) end
end
local function traceMissingAPIImpl(episode, carIndex, operation, api, key)
  if type(api) ~= 'function' then s2Diagnostic('api-unavailable', carIndex, episode, key, 'operation', operation) end
end
local function traceMissingAPI(episode, carIndex, operation, api, key)
  if rawget(Logger, 'OBS1_ENABLED') == true then pcall(traceMissingAPIImpl, episode, carIndex, operation, api, key) end
end

local function incidentParticipantRecord(carIndex, accidentIndex)
  if type(accidentIndex) ~= 'number' or accidentIndex ~= accidentIndex or accidentIndex < 1
    or accidentIndex % 1 ~= 0 or not AccidentManager or AccidentManager.accidents_resolved[accidentIndex] ~= false then return false end
  return AccidentManager.accidents_carIndex[accidentIndex] == carIndex
    or AccidentManager.accidents_collidedWithCarIndex[accidentIndex] == carIndex
end

function CarOperations.clearIncidentStopForCar(carIndex)
  incidentEpisodes[carIndex], incidentCompleted[carIndex], incidentStateCompletion[carIndex] = nil, nil, nil
end

function CarOperations.hasActiveIncidentStop(carIndex)
  local episode = incidentEpisodes[carIndex]
  return episode ~= nil and episode.generation == CarManager.getCarGeneration(carIndex)
    and episode.session == CarManager.sessionGeneration
end

function CarOperations.isIncidentStopCompleted(carIndex, accidentIndex)
  local completions = incidentCompleted[carIndex]
  local completion = completions and completions[accidentIndex]
  return completion ~= nil and completion.generation == CarManager.getCarGeneration(carIndex)
    and completion.session == CarManager.sessionGeneration
end

function CarOperations.hasCompletedIncidentStop(carIndex)
  local completion = incidentStateCompletion[carIndex]
  return completion ~= nil and completion.generation == CarManager.getCarGeneration(carIndex)
    and completion.session == CarManager.sessionGeneration
end

-- Retained for episodes admitted before a contact queue is consumed; queue contacts no longer admit S2 episodes.
function CarOperations.admitIncidentStop(carIndex, accidentIndex, generation, session)
  if session ~= CarManager.sessionGeneration or generation ~= CarManager.getCarGeneration(carIndex)
    or not canWriteCar(carIndex) or not incidentParticipantRecord(carIndex, accidentIndex)
    or CarOperations.isIncidentStopCompleted(carIndex, accidentIndex) then return false end
  local admissionCheck = AccidentManager and AccidentManager.shouldAdmitIncidentStop
  if type(admissionCheck) == 'function' then
    local checkOK, shouldAdmit = pcall(admissionCheck, accidentIndex)
    if checkOK and shouldAdmit == false then return false end
  end
  local now = getActiveGameTime()
  if now == nil or now > math.huge - INCIDENT_STOP_SECONDS then return false end
  local episode = incidentEpisodes[carIndex]
  if episode and (episode.generation ~= generation or episode.session ~= session) then
    -- Identity loss discards the stale episode only; it never adopts or restores its old physical shadow.
    incidentEpisodes[carIndex] = nil
    episode = nil
  end
  if not episode then
    episode = { generation = generation, session = session, deadline = now + INCIDENT_STOP_SECONDS,
      counterUntil = nil, gentleOwned = false, cautionOwned = false, releasing = false,
      incidents = {}, counterConfirmed = false, topConfirmed = false, throttleConfirmed = false,
      gentleConfirmed = false, cautionConfirmed = false }
    incidentEpisodes[carIndex] = episode
  end
  episode.incidents[accidentIndex] = true
  s2Diagnostic('admitted', carIndex, episode, 'admitted', 'incidentID', accidentIndex,
    'control', 'requested; physical evidence unavailable')
  return true
end

function CarOperations.updateIncidentStop(carIndex)
  local episode = incidentEpisodes[carIndex]
  if not canWriteCar(carIndex) then
    if episode then s2Diagnostic('episode-update-gated', carIndex, episode, 'update-gate', 'gate', 'denied; no extra permission probe') end
    return false
  end
  if not episode or episode.generation ~= CarManager.getCarGeneration(carIndex)
    or episode.session ~= CarManager.sessionGeneration then return false end
  local now = getActiveGameTime()
  if now == nil then
    s2Diagnostic('active-clock-unavailable', carIndex, episode, 'clock-unavailable', 'episode', 'retained; no physical write')
    return false
  end

  if now < episode.deadline then
    local throttleRequested = CarOperations.requestAIThrottleLimit(carIndex, 0, 'INCIDENT_STOP')
    local topRequested = CarOperations.requestAITopSpeed(carIndex, 0, 'INCIDENT_STOP')
    local cautionRequested = CarOperations.requestAICaution(carIndex, CarManager.AICautionValues.AFTER_ACCIDENT, 'INCIDENT_STOP')
    if rawget(Logger, 'OBS1_ENABLED') == true then
      s2Diagnostic('control-request', carIndex, episode, 'control-request', 'throttleRequested', throttleRequested,
        'topSpeedRequested', topRequested, 'cautionRequested', cautionRequested)
    end
    if not throttleRequested or not topRequested or not cautionRequested then return false end
    traceMissingAPI(episode, carIndex, 'setAIStopCounter', physics_setAIStopCounter, 'api-stop-counter')
    local counterOK = CarOperations.setAIStopCounter(carIndex, 1)
    traceOutcome(episode, carIndex, 'stopCounter', counterOK)
    if counterOK then episode.counterUntil, episode.counterConfirmed = now + INCIDENT_COUNTER_SECONDS, true end
    traceMissingAPI(episode, carIndex, 'setGentleStop', physics_setGentleStop, 'api-gentle-stop')
    local gentleOK = CarOperations.setGentleStop(carIndex, true)
    traceOutcome(episode, carIndex, 'gentleStop=true', gentleOK)
    if gentleOK then episode.gentleOwned, episode.gentleConfirmed = true, true end
    episode.cautionOwned = true
    traceMissingAPI(episode, carIndex, 'preventAIFromRetiring', physics_preventAIFromRetiring, 'api-prevent-retiring')
    local retireOK = CarOperations.preventAIFromRetiring(carIndex)
    traceOutcome(episode, carIndex, 'preventRetiring', retireOK)
    if not retireOK then episode.retirementConfirmed = false else episode.retirementConfirmed = true end
    return false
  end

  if not episode.releasing then
    s2Diagnostic('deadline-release-start', carIndex, episode, 'deadline-release', 'physicalEvidence', 'unavailable')
    CarOperations.releaseAIThrottleLimit(carIndex, 'INCIDENT_STOP')
    CarOperations.releaseAITopSpeed(carIndex, 'INCIDENT_STOP')
    CarOperations.releaseAICaution(carIndex, 'INCIDENT_STOP')
    episode.releasing = true
  end
  if episode.gentleOwned and not episode.gentleRestored then
    if CarOperations.setGentleStop(carIndex, false) then
      traceOutcome(episode, carIndex, 'gentleStop=false', true)
      episode.gentleOwned, episode.gentleRestored = false, true
    else traceOutcome(episode, carIndex, 'gentleStop=false', false) end
  end
  if not episode.gentleConfirmed or not episode.gentleRestored or not episode.cautionConfirmed
    or not episode.cautionHandedBack or not episode.counterConfirmed or not episode.topConfirmed
    or not episode.throttleConfirmed or not episode.topHandedBack or not episode.throttleHandedBack then return false end
  if not episode.counterUntil or now < episode.counterUntil then return false end
  local completed = incidentCompleted[carIndex] or {}
  incidentCompleted[carIndex] = completed
  for accidentIndex in pairs(episode.incidents) do
    completed[accidentIndex] = { generation = episode.generation, session = episode.session }
  end
  incidentStateCompletion[carIndex] = { generation = episode.generation, session = episode.session }
  s2Diagnostic('completed', carIndex, episode, 'completed', 'completion', 'logical; physical readback unavailable')
  incidentEpisodes[carIndex] = nil
  return true
end

getActiveGameTime = function()
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
  local resource = controlResource(slots)
  local changed = not item.active or item.value ~= value or item.sessionGeneration ~= CarManager.sessionGeneration
  if not item.active then slot.activeCount = slot.activeCount + 1 end
  item.value, item.priority, item.expiresAt = value, fixedPriority, now + CONTROL_LEASE_SECONDS
  item.carGeneration, item.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
  item.active = true
  if changed then
    resetControlTrace(carIndex, resource)
    observeControl('control-request', carIndex, owner, value, resource)
  end
  return true
end

function CarOperations.requestAITopSpeed(carIndex, value, owner, priority)
  return requestControl(CarOperations._topSpeedRequests, carIndex, value, owner, priority, 1000)
end
function CarOperations.requestAIThrottleLimit(carIndex, value, owner, priority)
  return requestControl(CarOperations._throttleRequests, carIndex, value, owner, priority, 1)
end
function CarOperations.requestAICaution(carIndex, value, owner, priority)
  return requestControl(CarOperations._cautionRequests, carIndex, value, owner, priority, 16)
end
local function releaseControl(slots, carIndex, owner)
  local slot = slots[carIndex]
  local item = slot and slot.byOwner[owner]
  if not item or not item.active then return false end
  item.active = false
  slot.activeCount = slot.activeCount - 1
  local resource = controlResource(slots)
  resetControlTrace(carIndex, resource)
  observeControl('control-request-released', carIndex, owner, item.value, resource)
  local winners = controlWinners(slots)
  local winner = winners[carIndex]
  if winner and winner.active and winner.owner == owner then winner.active = false end
  return true
end
function CarOperations.releaseAITopSpeed(carIndex, owner) return releaseControl(CarOperations._topSpeedRequests, carIndex, owner) end
function CarOperations.releaseAIThrottleLimit(carIndex, owner) return releaseControl(CarOperations._throttleRequests, carIndex, owner) end
function CarOperations.releaseAICaution(carIndex, owner) return releaseControl(CarOperations._cautionRequests, carIndex, owner) end

local function finiteNumber(value)
  return type(value) == 'number' and value == value and value ~= math_huge and value ~= -math_huge
end

-- Requests a lateral offset for the next resolution pass. `value` is metres from the AI
-- line when unit == 'absolute', otherwise normalized spline units (-1..1). `normalized`
-- is the fallback used when the absolute API is unavailable. `target` is the normalized
-- offset parked in CarManager.cars_targetSplineOffset for arrival checks.
local function requestLateralControl(carIndex, value, owner, unit, normalized, edgeMeters, override, target)
  local fixedPriority = type(owner) == 'string' and OWNER_PRIORITY[owner] or nil
  local now = getActiveGameTime()
  if not canWriteCar(carIndex) or not fixedPriority or not finiteNumber(value) or now == nil
    or math_abs(value) > 100 then return false end
  local slot = getControlSlot(CarOperations._lateralRequests, carIndex)
  local item = slot.byOwner[owner]
  if not item then return false end
  local changed = not item.active or item.value ~= value or item.unit ~= unit
    or item.sessionGeneration ~= CarManager.sessionGeneration
  if not item.active then slot.activeCount = slot.activeCount + 1 end
  item.value, item.priority, item.expiresAt = value, fixedPriority, now + CONTROL_LEASE_SECONDS
  item.unit = unit == 'absolute' and 'absolute' or 'normalized'
  item.normalized = finiteNumber(normalized) and normalized or value
  item.edgeMeters = finiteNumber(edgeMeters) and math_abs(edgeMeters) > 0.01 and edgeMeters or nil
  item.override = override == true
  item.target = finiteNumber(target) and target or item.normalized
  item.carGeneration, item.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
  item.active = true
  if changed then
    resetControlTrace(carIndex, 'lateralOffsets')
    observeControl('control-request', carIndex, owner, value, 'lateralOffsets')
  end
  return true
end

function CarOperations.requestLateralOffset(carIndex, value, owner, unit, normalized, edgeMeters, override, target)
  return requestLateralControl(carIndex, value, owner, unit, normalized, edgeMeters, override, target)
end

local function releaseLateralControl(carIndex, owner)
  local slot = CarOperations._lateralRequests[carIndex]
  local item = slot and slot.byOwner[owner]
  if not item or not item.active then return false end
  item.active = false
  slot.activeCount = slot.activeCount - 1
  resetControlTrace(carIndex, 'lateralOffsets')
  observeControl('control-request-released', carIndex, owner, item.value, 'lateralOffsets')
  local winner = CarOperations._lateralWinner[carIndex]
  if winner and winner.active and winner.owner == owner then winner.active = false end
  return true
end
function CarOperations.releaseLateralOffset(carIndex, owner) return releaseLateralControl(carIndex, owner) end

local function clearCarRequests(slots, carIndex, resource)
  local slot = slots[carIndex]
  if not slot then return end
  for i = 1, #OWNER_ORDER do
    local item = slot.byOwner[OWNER_ORDER[i]]
    if item.active then observeControl('control-request-cleared', carIndex, item.owner, item.value, resource) end
    item.active = false
  end
  slot.activeCount = 0
end

function CarOperations.clearOwnedControlsForCar(carIndex)
  CarOperations.clearIncidentStopForCar(carIndex)
  trafficPedalOwnership[carIndex], trafficLateralOwnership[carIndex] = nil, nil
  clearCarRequests(CarOperations._topSpeedRequests, carIndex, 'setAITopSpeed')
  clearCarRequests(CarOperations._throttleRequests, carIndex, 'setAIThrottleLimit')
  clearCarRequests(CarOperations._cautionRequests, carIndex, 'setAICaution')
  clearCarRequests(CarOperations._lateralRequests, carIndex, 'lateralOffsets')
  CarOperations._lateralAvoidance[carIndex] = nil
  local topWinner = CarOperations._topSpeedWinner[carIndex]
  local throttleWinner = CarOperations._throttleWinner[carIndex]
  local cautionWinner = CarOperations._cautionWinner[carIndex]
  local lateralWinner = CarOperations._lateralWinner[carIndex]
  local topApplied = CarOperations._topSpeedApplied[carIndex]
  local throttleApplied = CarOperations._throttleApplied[carIndex]
  local cautionApplied = CarOperations._cautionApplied[carIndex]
  local lateralApplied = CarOperations._lateralApplied[carIndex]
  if topWinner then topWinner.active = false end
  if throttleWinner then throttleWinner.active = false end
  if cautionWinner then cautionWinner.active = false end
  if lateralWinner then lateralWinner.active = false end
  if topApplied then topApplied.active = false end
  if throttleApplied then throttleApplied.active = false end
  if cautionApplied then cautionApplied.active = false end
  if lateralApplied then lateralApplied.active = false end
end

-- A referenced car can disappear without changing this owner's identity. Cancel only
-- maneuver bookkeeping; incident-stop leases and their applied handback evidence belong
-- to the unchanged owner and must survive until the original episode completes.
function CarOperations.clearDependentReferenceControlsForCar(carIndex)
  trafficPedalOwnership[carIndex], trafficLateralOwnership[carIndex] = nil, nil
  CarOperations._currentAntiDragRaceTopSpeeds[carIndex] = nil
  local preserveIncident = incidentEpisodes[carIndex] ~= nil
  local function clearNonIncidentRequests(slots, resource)
    local slot = slots[carIndex]
    if not slot then return end
    for i = 1, #OWNER_ORDER do
      local item = slot.byOwner[OWNER_ORDER[i]]
      if item.active and item.owner ~= 'INCIDENT_STOP' then
        observeControl('control-request-cleared', carIndex, item.owner, item.value, resource)
        item.active = false
        slot.activeCount = slot.activeCount - 1
      elseif item.active then
        preserveIncident = true
      end
    end
  end
  clearNonIncidentRequests(CarOperations._topSpeedRequests, 'setAITopSpeed')
  clearNonIncidentRequests(CarOperations._throttleRequests, 'setAIThrottleLimit')
  clearNonIncidentRequests(CarOperations._cautionRequests, 'setAICaution')
  clearNonIncidentRequests(CarOperations._lateralRequests, 'lateralOffsets')
  CarOperations._lateralAvoidance[carIndex] = nil
  local lateralWinner = CarOperations._lateralWinner[carIndex]
  if lateralWinner then lateralWinner.active = false end
  -- Leave _lateralApplied active: the next resolution pass hands the offset back to 0.
  if not preserveIncident then
    local topWinner, throttleWinner = CarOperations._topSpeedWinner[carIndex], CarOperations._throttleWinner[carIndex]
    local cautionWinner = CarOperations._cautionWinner[carIndex]
    local topApplied, throttleApplied = CarOperations._topSpeedApplied[carIndex], CarOperations._throttleApplied[carIndex]
    local cautionApplied = CarOperations._cautionApplied[carIndex]
    if topWinner then topWinner.active = false end
    if throttleWinner then throttleWinner.active = false end
    if cautionWinner then cautionWinner.active = false end
    if topApplied then topApplied.active = false end
    if throttleApplied then throttleApplied.active = false end
    if cautionApplied then cautionApplied.active = false end
  end
end

function CarOperations.clearAllOwnedControls()
  for carIndex in pairs(incidentEpisodes) do CarOperations.clearIncidentStopForCar(carIndex) end
  for carIndex in pairs(trafficPedalOwnership) do trafficPedalOwnership[carIndex] = nil end
  for carIndex in pairs(trafficLateralOwnership) do trafficLateralOwnership[carIndex] = nil end
  for carIndex in pairs(CarOperations._topSpeedRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._throttleRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._cautionRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._topSpeedApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._throttleApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._cautionApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._lateralRequests) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._lateralApplied) do CarOperations.clearOwnedControlsForCar(carIndex) end
  for carIndex in pairs(CarOperations._lateralAvoidance) do CarOperations.clearOwnedControlsForCar(carIndex) end
end

local function resolveControl(carIndex, slots, winners, applied, attempted, setterName, neutral, cap, now, resolutionId)
  local requestSlot = slots[carIndex]
  local winner, winnerName
  if requestSlot then
    for i = 1, #OWNER_ORDER do
      local item = requestSlot.byOwner[OWNER_ORDER[i]]
      if item.active and (item.carGeneration ~= CarManager.getCarGeneration(carIndex)
        or item.sessionGeneration ~= CarManager.sessionGeneration or now >= item.expiresAt) then
        observeControl('control-request-expired', carIndex, item.owner, item.value, setterName)
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
  local winnerChanged = winnerSlot.active ~= (winner ~= nil)
    or (winner and (winnerSlot.owner ~= winnerName or winnerSlot.value ~= winner.value))
  winnerSlot.active = winner ~= nil
  if winner then winnerSlot.value, winnerSlot.owner, winnerSlot.priority = winner.value, winnerName, winner.priority end
  if winnerChanged then
    resetControlTrace(carIndex, setterName)
    observeControl('control-winner', carIndex, winnerName or 'none', winner and winner.value or 'none', setterName)
  end
  local previous = applied[carIndex]
  local episode = incidentEpisodes[carIndex]
  if episode and (episode.generation ~= CarManager.getCarGeneration(carIndex)
    or episode.session ~= CarManager.sessionGeneration) then episode = nil end
  local isTopSpeed = setterName == 'setAITopSpeed'
  local isThrottle = setterName == 'setAIThrottleLimit'
  local acquiredKey = isTopSpeed and 'topConfirmed' or (isThrottle and 'throttleConfirmed' or 'cautionConfirmed')
  local handedBackKey = isTopSpeed and 'topHandedBack' or (isThrottle and 'throttleHandedBack' or 'cautionHandedBack')
  if winner then
    local writable = CarManager.isWritableAICar(carIndex) == true
    local value = winner.value
    if cap ~= nil and cap > 0 then value = math.min(value, cap) end
    if writable and previous and previous.active and previous.carGeneration == CarManager.getCarGeneration(carIndex)
      and previous.sessionGeneration == CarManager.sessionGeneration and previous.value == value then
      -- A lower-priority owner can inherit an equal value without changing the last-setter audit shadow.
      previous.handbackOwner, previous.handbackPriority = winnerName, winner.priority
      if rawget(Logger, 'OBS1_ENABLED') == true and episode and (winnerName == 'INCIDENT_STOP' or episode.releasing) then
        local controlKey = setterName == 'setAITopSpeed' and 'equal-transfer-top'
          or (setterName == 'setAIThrottleLimit' and 'equal-transfer-throttle' or 'equal-transfer-caution')
        s2Diagnostic('logical-equal-transfer', carIndex, episode, controlKey, 'setter', setterName, 'owner', winnerName)
      end
      if episode then
        if winnerName == 'INCIDENT_STOP' then
          episode[acquiredKey], episode[handedBackKey] = true, false
        elseif episode.releasing and episode[acquiredKey] then episode[handedBackKey] = true end
      end
      return
    end
    local api = physics and physics[setterName]
    if episode and (winnerName == 'INCIDENT_STOP' or episode.releasing) and not isCallable(api) then
      local apiKey = setterName == 'setAITopSpeed' and 'api-top-speed'
        or (setterName == 'setAIThrottleLimit' and 'api-throttle' or 'api-caution')
      s2Diagnostic('api-unavailable', carIndex, episode, apiKey, 'operation', setterName)
    end
    if writable and isCallable(api) then
      if attempted[carIndex] == resolutionId then return end
      attempted[carIndex] = resolutionId
      observeControl('control-setter-attempt', carIndex, winnerName, value, setterName)
      if rawget(Logger, 'OBS1_ENABLED') == true and episode and (winnerName == 'INCIDENT_STOP' or episode.releasing) then
        local attemptKey = setterName == 'setAITopSpeed' and 'attempt-top-speed'
          or (setterName == 'setAIThrottleLimit' and 'attempt-throttle' or 'attempt-caution')
        s2Diagnostic('setter-attempt', carIndex, episode, attemptKey, 'operation', setterName, 'value', value)
      end
      local ok = pcall(api, carIndex, value)
      observeControl(ok and 'control-setter-returned' or 'control-setter-threw-uncertain', carIndex, winnerName, value, setterName)
      if rawget(Logger, 'OBS1_ENABLED') == true and episode and (winnerName == 'INCIDENT_STOP' or episode.releasing) then
        local resultKey = setterName == 'setAITopSpeed' and 'result-top-speed'
          or (setterName == 'setAIThrottleLimit' and 'result-throttle' or 'result-caution')
        s2Diagnostic(ok and 'setter-returned' or 'setter-threw-uncertain', carIndex, episode,
          resultKey, 'operation', setterName, 'value', value)
      end
      if ok then
        local appliedSlot = previous or {}
        applied[carIndex] = appliedSlot
        appliedSlot.active, appliedSlot.value, appliedSlot.owner, appliedSlot.priority = true, value, winnerName, winner.priority
        appliedSlot.handbackOwner, appliedSlot.handbackPriority = winnerName, winner.priority
        appliedSlot.carGeneration, appliedSlot.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
        if episode then
          if winnerName == 'INCIDENT_STOP' then
            episode[acquiredKey], episode[handedBackKey] = true, false
          elseif episode.releasing and episode[acquiredKey] then episode[handedBackKey] = true end
        end
      end
    end
  elseif previous and previous.active then
    if previous.carGeneration ~= CarManager.getCarGeneration(carIndex) or previous.sessionGeneration ~= CarManager.sessionGeneration then
      previous.active = false
      return
    end
    local handbackApi = physics and physics[setterName]
    if CarManager.isWritableAICar(carIndex) and isCallable(handbackApi) then
      if attempted[carIndex] == resolutionId then return end
        attempted[carIndex] = resolutionId
        observeControl('control-handback-attempt', carIndex, previous.owner or 'UNKNOWN', neutral, setterName)
       if rawget(Logger, 'OBS1_ENABLED') == true and episode and episode.releasing then
         local handbackKey = setterName == 'setAITopSpeed' and 'handback-attempt-top'
           or (setterName == 'setAIThrottleLimit' and 'handback-attempt-throttle' or 'handback-attempt-caution')
         s2Diagnostic('handback-attempt', carIndex, episode, handbackKey, 'operation', setterName, 'neutral', neutral)
       end
        local ok = pcall(handbackApi, carIndex, neutral)
        observeControl(ok and 'control-handback-returned' or 'control-handback-threw-uncertain', carIndex, previous.owner or 'UNKNOWN', neutral, setterName)
         if rawget(Logger, 'OBS1_ENABLED') == true and episode and episode.releasing then
          local handbackResultKey = setterName == 'setAITopSpeed' and 'handback-result-top'
            or (setterName == 'setAIThrottleLimit' and 'handback-result-throttle' or 'handback-result-caution')
          s2Diagnostic(ok and 'handback-returned' or 'handback-threw-uncertain', carIndex,
            episode, handbackResultKey, 'operation', setterName, 'neutral', neutral)
        end
       if ok then
         previous.active, previous.handbackOwner, previous.handbackPriority = false, nil, nil
         if episode and episode[acquiredKey] then episode[handedBackKey] = true end
       end
    end
  end
end

function CarOperations.getOwnedControlState(carIndex)
  local topRequests, throttleRequests = CarOperations._topSpeedRequests[carIndex], CarOperations._throttleRequests[carIndex]
  local cautionRequests = CarOperations._cautionRequests[carIndex]
  local topWinner, throttleWinner = CarOperations._topSpeedWinner[carIndex], CarOperations._throttleWinner[carIndex]
  local cautionWinner = CarOperations._cautionWinner[carIndex]
  local topApplied, throttleApplied = CarOperations._topSpeedApplied[carIndex], CarOperations._throttleApplied[carIndex]
  local cautionApplied = CarOperations._cautionApplied[carIndex]
  if topRequests and topRequests.activeCount == 0 then topRequests = nil end
  if throttleRequests and throttleRequests.activeCount == 0 then throttleRequests = nil end
  if cautionRequests and cautionRequests.activeCount == 0 then cautionRequests = nil end
  if topWinner and not topWinner.active then topWinner = nil end
  if throttleWinner and not throttleWinner.active then throttleWinner = nil end
  if cautionWinner and not cautionWinner.active then cautionWinner = nil end
  if topApplied and not topApplied.active then topApplied = nil end
  if throttleApplied and not throttleApplied.active then throttleApplied = nil end
  if cautionApplied and not cautionApplied.active then cautionApplied = nil end
  return topRequests, topWinner, topApplied, throttleRequests, throttleWinner, throttleApplied,
    cautionRequests, cautionWinner, cautionApplied
end

local function resolveLateralControl(carIndex, now, resolutionId)
  local requestSlot = CarOperations._lateralRequests[carIndex]
  local winner, winnerName
  if requestSlot then
    for i = 1, #OWNER_ORDER do
      local item = requestSlot.byOwner[OWNER_ORDER[i]]
      if item.active and (item.carGeneration ~= CarManager.getCarGeneration(carIndex)
        or item.sessionGeneration ~= CarManager.sessionGeneration or now >= item.expiresAt) then
        observeControl('control-request-expired', carIndex, item.owner, item.value, 'lateralOffsets')
        item.active = false
        requestSlot.activeCount = requestSlot.activeCount - 1
      end
      if item.active and (not winner or item.priority > winner.priority
        or (item.priority == winner.priority and item.owner < winnerName)) then
        winner, winnerName = item, item.owner
      end
    end
  end
  local winnerSlot = CarOperations._lateralWinner[carIndex]
  if not winnerSlot then winnerSlot = {}; CarOperations._lateralWinner[carIndex] = winnerSlot end
  local winnerChanged = winnerSlot.active ~= (winner ~= nil)
    or (winner and (winnerSlot.owner ~= winnerName or winnerSlot.value ~= winner.value))
  winnerSlot.active = winner ~= nil
  if winner then
    winnerSlot.value, winnerSlot.owner, winnerSlot.priority = winner.value, winnerName, winner.priority
  end
  if winnerChanged then
    resetControlTrace(carIndex, 'lateralOffsets')
    observeControl('control-winner', carIndex, winnerName or 'none', winner and winner.value or 'none', 'lateralOffsets')
  end

  local writable = CarManager.isWritableAICar(carIndex) == true
  local applied = CarOperations._lateralApplied[carIndex]
  local attempted = CarOperations._lateralAttempted
  if winner then
    if not writable then return end
    local useAbsolute = winner.unit == 'absolute' and isCallable(physics_setAISplineAbsoluteOffset)
    local api = useAbsolute and physics_setAISplineAbsoluteOffset or physics_setAISplineOffset
    if not isCallable(api) then return end
    local value = useAbsolute and winner.value or winner.normalized
    if attempted[carIndex] == resolutionId then return end
    attempted[carIndex] = resolutionId
    if not useAbsolute and applied and applied.active and applied.unit == 'absolute'
      and isCallable(physics_setAISplineAbsoluteOffset) then
      -- Leaving avoidance for a normalized traffic owner: zero the absolute offset first so the two
      -- CSP offsets never stack.
      pcall(physics_setAISplineAbsoluteOffset, carIndex, 0, false)
    end
    observeControl('control-setter-attempt', carIndex, winnerName, value, 'lateralOffsets')
    local ok = pcall(api, carIndex, value, useAbsolute and false or winner.override)
    observeControl(ok and 'control-setter-returned' or 'control-setter-threw-uncertain', carIndex, winnerName, value, 'lateralOffsets')
    if ok then
      local slot = applied or {}
      CarOperations._lateralApplied[carIndex] = slot
      slot.active, slot.value, slot.owner, slot.priority = true, value, winnerName, winner.priority
      slot.unit = useAbsolute and 'absolute' or 'normalized'
      slot.carGeneration, slot.sessionGeneration = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
      CarManager_setCalculatedTrackLateralOffset(carIndex, winner.normalized)
      CarManager.cars_targetSplineOffset[carIndex] = winner.target
    end
  elseif applied and applied.active then
    if applied.carGeneration ~= CarManager.getCarGeneration(carIndex)
      or applied.sessionGeneration ~= CarManager.sessionGeneration then
      applied.active = false
      return
    end
    if not writable then return end
    local useAbsolute = applied.unit == 'absolute' and isCallable(physics_setAISplineAbsoluteOffset)
    local api = useAbsolute and physics_setAISplineAbsoluteOffset or physics_setAISplineOffset
    if not isCallable(api) then return end
    if attempted[carIndex] == resolutionId then return end
    attempted[carIndex] = resolutionId
    observeControl('control-handback-attempt', carIndex, applied.owner or 'UNKNOWN', 0, 'lateralOffsets')
    local ok = pcall(api, carIndex, 0, false)
    observeControl(ok and 'control-handback-returned' or 'control-handback-threw-uncertain', carIndex, applied.owner or 'UNKNOWN', 0, 'lateralOffsets')
    if ok then
      applied.active = false
      CarManager_setCalculatedTrackLateralOffset(carIndex, 0)
      CarManager.cars_targetSplineOffset[carIndex] = 0
    end
  end
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
  local cautionNeutral = defaultAICaution()
  for carIndex, slot in pairs(CarOperations._cautionRequests) do
    if slot.activeCount > 0 or (CarOperations._cautionApplied[carIndex] and CarOperations._cautionApplied[carIndex].active)
      or (CarOperations._cautionWinner[carIndex] and CarOperations._cautionWinner[carIndex].active) then
      resolveControl(carIndex, CarOperations._cautionRequests, CarOperations._cautionWinner, CarOperations._cautionApplied,
        CarOperations._cautionAttempted, 'setAICaution', cautionNeutral, 16, now, resolutionId)
    end
  end
  for carIndex, slot in pairs(CarOperations._lateralRequests) do
    if slot.activeCount > 0 or (CarOperations._lateralApplied[carIndex] and CarOperations._lateralApplied[carIndex].active)
      or (CarOperations._lateralWinner[carIndex] and CarOperations._lateralWinner[carIndex].active) then
      resolveLateralControl(carIndex, now, resolutionId)
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

local function writePedalInput(carInput, field, value)
  carInput[field] = value
end

local function controlIdentityMatches(record, carIndex)
  return record and record.generation == CarManager.getCarGeneration(carIndex)
    and record.session == CarManager.sessionGeneration
end
local function isTrafficControlOwner(owner)
  return owner == 'TRAFFIC_YIELD' or owner == 'TRAFFIC_OVERTAKE'
end
local function isAppLateralOwner(owner)
  return owner == 'NORMAL_TRAFFIC' or isTrafficControlOwner(owner)
end
local function controlsMayBeReleased(carIndex)
  if not canWriteCar(carIndex) then return false end
  local simOK, sim = pcall(ac.getSim)
  return simOK and sim ~= nil and sim.isPaused ~= true and sim.isReplayActive ~= true
end

---Value from 0 to 1. Final value will be the maximum of original and this.
---(For clutch: 1 is for clutch pedal fully depressed, 0 for pressed).
---@param carIndex integer
---@param carPedal CarOperations.CarPedals
---@param pedalPosition number
CarOperations.setPedalPosition = function(carIndex, carPedal, pedalPosition, owner)
  if not canWriteCar(carIndex) or type(pedalPosition) ~= 'number' or pedalPosition ~= pedalPosition
    or type(ac_overrideCarControls) ~= 'function' then return false end
  if carPedal ~= CarOperations.CarPedals.Gas and carPedal ~= CarOperations.CarPedals.Brake
    and carPedal ~= CarOperations.CarPedals.Clutch then return false end
  local ok, carInput = pcall(ac_overrideCarControls, carIndex)
  if not ok or not carInput then return false end
  local field = carPedal == CarOperations.CarPedals.Gas and 'gas'
    or carPedal == CarOperations.CarPedals.Brake and 'brake' or 'clutch'
  local record = trafficPedalOwnership[carIndex]
  if not record then record = {}; trafficPedalOwnership[carIndex] = record end
  local previous = record[carPedal]
  if not controlIdentityMatches(previous, carIndex) then previous = nil end
  if owner == 'TRAFFIC_YIELD' and previous and previous.owner ~= 'TRAFFIC_YIELD' then return false end
  local ownership = previous
  if not ownership then ownership = {}; record[carPedal] = ownership end
  ownership.owner, ownership.generation, ownership.session = owner or 'COMPAT',
    CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
  ownership.confirmed, ownership.uncertain = false, false
  record[carPedal] = ownership
  local setOK = pcall(writePedalInput, carInput, field, pedalPosition)
  if setOK then ownership.confirmed = true else ownership.uncertain = true end
  return setOK
end

---Resets the specified pedal to the original value
---@param carIndex integer
---@param carPedal CarOperations.CarPedals
CarOperations.resetPedalPosition = function(carIndex, carPedal, owner)
  if not canWriteCar(carIndex) or type(ac_overrideCarControls) ~= 'function' then return false end
  local record = trafficPedalOwnership[carIndex]
  local ownership = record and record[carPedal]
  if owner == 'TRAFFIC_YIELD' and (not controlIdentityMatches(ownership, carIndex)
    or ownership.owner ~= 'TRAFFIC_YIELD') then return false end
  local ok, carInput = pcall(ac_overrideCarControls, carIndex)
  if not ok or not carInput then return false end
  local field = carPedal == CarOperations.CarPedals.Gas and 'gas'
    or carPedal == CarOperations.CarPedals.Brake and 'brake' or 'clutch'
  local value = carPedal == CarOperations.CarPedals.Clutch and 1 or 0
  local setOK = pcall(writePedalInput, carInput, field, value)
  if setOK and record then record[carPedal] = nil end
  if not setOK and ownership then ownership.uncertain = true end
  return setOK
end

function CarOperations.releaseTrafficYieldControls(carIndex)
  if not controlsMayBeReleased(carIndex) then return false end
  local generation, session = CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
  local success = true
  local pedals = trafficPedalOwnership[carIndex]
  if pedals then
    for pedal, ownership in pairs(pedals) do
      if ownership.generation == generation and ownership.session == session and ownership.owner == 'TRAFFIC_YIELD' then
        local ok = CarOperations.resetPedalPosition(carIndex, pedal, 'TRAFFIC_YIELD')
        if not ok then success = false end
      end
    end
  end
  local lateral = trafficLateralOwnership[carIndex]
  if lateral and lateral.generation == generation and lateral.session == session and isAppLateralOwner(lateral.owner) then
    -- Releasing the request schedules the handback through the lateral arbitration,
    -- which writes the app's own zero offset once on the next resolution pass.
    CarOperations.releaseLateralOffset(carIndex, 'NORMAL_TRAFFIC')
    CarOperations.releaseLateralOffset(carIndex, 'TRAFFIC_YIELD')
    CarOperations.releaseLateralOffset(carIndex, 'TRAFFIC_OVERTAKE')
    trafficLateralOwnership[carIndex] = nil
  end
  return success
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
    if not canWriteCar(carIndex) or type(caution) ~= 'number' or caution ~= caution or caution == math.huge
      or caution == -math.huge or caution < 0 or caution > 16 or not isCallable(physics_setAICaution) then return false end
    local ok = pcall(physics_setAICaution, carIndex, caution)
    if not ok then return false end
    CarManager.cars_aiCaution[carIndex] = caution
    return true
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
    local ok = pcall(physics_setAIStopCounter, carIndex, time)
    if not ok then return false end
    CarManager.cars_aiStopCounter[carIndex] = time
    return true
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
    local ok = pcall(physics_setGentleStop, carIndex, stop)
    if not ok then return false end
    CarManager.cars_gentleStop[carIndex] = stop
    return true
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
    CarOperations.requestAICaution(carIndex, CarManager.AICautionValues.AFTER_ACCIDENT, 'INCIDENT_STOP') -- be very cautious

    CarOperations.preventAIFromRetiring(carIndex)
    return true
end

---Prevent an AI from retiring for some time. 
---If not moving, they will still retire some time after this function is called, unless you’ll keep calling it.
---@param carIndex integer @0-based car index.
function CarOperations.preventAIFromRetiring(carIndex)
    if not canWriteCar(carIndex) or type(physics_preventAIFromRetiring) ~= 'function' then return false end
    local ok = pcall(physics_preventAIFromRetiring, carIndex)
    return ok
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
function CarOperations.driveSafelyToSide(carIndex, dt, car, targetLateralOffset, rampSpeed_mps, overrideAiAwareness, sideCheck, useIndicatorLights, controlOwner)
    if not canWriteCar(carIndex) or type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then return false end
    if isAppLateralOwner(controlOwner) and car and (car.isInPitlane == true or car.isInPit == true) then
      CarOperations.releaseTrafficYieldControls(carIndex)
      return false
    end
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

      -- Request the offset through the lateral arbitration. The single writer resolves
      -- all owners once per frame and performs the physics write.
      if type(physics_setAISplineOffset) ~= 'function' then return false end
      local accepted = CarOperations.requestLateralOffset(carIndex, currentSplineOffset,
        controlOwner or 'COMPAT', 'normalized', currentSplineOffset, nil, overrideAiAwareness, targetSplineOffset)
      local ownership = trafficLateralOwnership[carIndex]
      if not ownership then ownership = {}; trafficLateralOwnership[carIndex] = ownership end
      ownership.owner, ownership.generation, ownership.session = controlOwner or 'COMPAT',
        CarManager.getCarGeneration(carIndex), CarManager.sessionGeneration
      ownership.confirmed, ownership.uncertain = accepted, not accepted
      if not accepted then return false end
      -- Preserve the previous same-frame decision shadow: the writer applies the same
      -- normalized value later in the frame.
      CarManager_setCalculatedTrackLateralOffset(carIndex, currentSplineOffset)

      -- keep the turning lights on while driving to the side
      if useIndicatorLights then
        local drivingToTheLeft = sideForIndicatorLights == RaceTrackManager.TrackSide.LEFT
        local turningLights = drivingToTheLeft and ac.TurningLights.Left or ac.TurningLights.Right
        CarOperations.toggleTurningLights(carIndex, turningLights)
      end

      -- Decision shadow for the arrival checks in the easing states. The applied
      -- spline offset is written by resolveLateralControl.
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
    return CarOperations.driveSafelyToSide(carIndex, dt, car, targetOffset, rampSpeed_mps, overrideAiAwareness, handleSideCheckingWhenOvertaking, useIndicatorLights, 'TRAFFIC_OVERTAKE')
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
      return CarOperations.driveSafelyToSide(carIndex, dt, car, targetOffset, rampSpeed_mps, overrideAiAwareness, handleSideCheckingWhenYielding, useIndicatorLights, 'TRAFFIC_YIELD')
end

---Reads `ac.getTrackAISplineSides` into metres from the AI line to each track edge.
---Returns nil when the API is unavailable or returns non-finite distances.
local function readSplineSidesComponents(sides) return sides.x, sides.y end
local function readSplineSides(splinePosition)
  if not isCallable(ac_getTrackAISplineSides) or not finiteNumber(splinePosition) then return nil end
  local ok, sides = pcall(ac_getTrackAISplineSides, splinePosition)
  if not ok or sides == nil then return nil end
  local componentsOK, left, right = pcall(readSplineSidesComponents, sides)
  if not componentsOK or not finiteNumber(left) or not finiteNumber(right)
    or left <= 0.01 or right <= 0.01 then return nil end
  return left, right
end

---Converts CSP's normalized track coordinate (-1 left edge, 0 track middle, +1 right edge) to
---metres from the AI line, which is what the absolute offset API and the spline sides use.
---The AI line is generally not the track middle, so map linearly across the full width.
local function lateralMeters(lateral, leftDistance, rightDistance)
  return (lateral + 1) * 0.5 * (leftDistance + rightDistance) - leftDistance
end

---Inverse of lateralMeters: metres from the AI line back to CSP's normalized track coordinate,
---the scale setAISplineOffset uses (the same one the yield/overtake lanes use successfully).
local function metersToNormalized(meters, leftDistance, rightDistance)
  return 2 * (meters + leftDistance) / (leftDistance + rightDistance) - 1
end

local function isLateralObstacleCandidate(carIndex, car, myLat, mySpline, obstacle, trackLength)
  if obstacle == nil or obstacle.index == carIndex then return false end
  if obstacle.isInPit == true or obstacle.isInPitlane == true then return false end
  local obstacleSpline, obstacleSpeed = obstacle.splinePosition, obstacle.speedKmh
  if not finiteNumber(obstacleSpline) or obstacleSpline < 0 or obstacleSpline > 1 then return false end
  if not finiteNumber(obstacleSpeed) then return false end
  -- No heading filter: a spun car facing backwards is exactly the obstacle to avoid.
  -- Cheap spline-distance test first, then the cached lateral lookup.
  local aheadFraction = (obstacleSpline - mySpline) % 1
  if aheadFraction <= 0 or aheadFraction > 0.5 then return false end
  local distance = aheadFraction * trackLength
  if distance <= 0 or distance > LATERAL_OBSTACLE_AHEAD_M then return false end
  local obstacleLateral = CarManager_getActualTrackLateralOffset(obstacle.index, obstacle.position)
  if not finiteNumber(obstacleLateral) or math_abs(obstacleLateral) > LATERAL_OBSTACLE_ON_TRACK then return false end
  if math_abs(obstacleLateral - myLat) >= LATERAL_OBSTACLE_BAND then return false end
  return true, obstacleLateral, distance
end

-- Per-car slow timer for every car on track (player included), advanced once per frame for the
-- whole list. Run 5 timed obstacles only while a follower was within range, so the 2 s started
-- when a follower arrived and avoidance engaged 1-17 m before the obstacle.
local obstacleSlowTime = {}
local obstacleTimersFrame = nil
local function refreshObstacleSlowTimers(sortedCarsList, dt)
  local frame = CarManager._currentFrameId or 0
  if obstacleTimersFrame == frame then return end
  local gap = obstacleTimersFrame ~= frame - 1
  obstacleTimersFrame = frame
  local count = sortedCarsList and #sortedCarsList or 0
  for i = 1, count do
    local other = sortedCarsList[i]
    local otherIndex = other and other.index
    if otherIndex ~= nil then
      local speed = other.speedKmh
      if finiteNumber(speed) and speed < LATERAL_STOPPED_KMH then
        obstacleSlowTime[otherIndex] = (gap and 0 or (obstacleSlowTime[otherIndex] or 0)) + dt
      else
        obstacleSlowTime[otherIndex] = 0
      end
    end
  end
end

---Finds the nearest valid obstacle ahead, preferring the car the caller is already tracking.
local function findLateralObstacle(carIndex, car, myLat, mySpline, sortedCarsList, trackLength, preferredIndex)
  local bestIndex, bestLateral, bestDistance
  local count = sortedCarsList and #sortedCarsList or 0
  for i = 1, count do
    local obstacle = sortedCarsList[i]
    local valid, obstacleLateral, distance = isLateralObstacleCandidate(carIndex, car, myLat, mySpline, obstacle, trackLength)
    if valid then
      if obstacle.index == preferredIndex then return obstacle, obstacleLateral, distance end
      if bestDistance == nil or distance < bestDistance then
        bestIndex, bestLateral, bestDistance = obstacle, obstacleLateral, distance
      end
    end
  end
  return bestIndex, bestLateral, bestDistance
end

---Chooses the passing side and target offset in metres from the AI line.
---Returns target metres, edge distance, side sign (-1 left, +1 right), left and right edge
---distances, and the no-room flag.
local function computeLateralAvoidanceTarget(obstacle, obstacleLateral, record, now, myLat)
  local leftDistance, rightDistance = readSplineSides(obstacle.splinePosition)
  if not leftDistance then return nil, nil, 0, nil, nil, true end
  local obstacleMeters = lateralMeters(obstacleLateral, leftDistance, rightDistance)
  local roomLeft = leftDistance + obstacleMeters
  local roomRight = rightDistance - obstacleMeters
  local leftTarget = obstacleMeters - LATERAL_CLEARANCE_M
  local rightTarget = obstacleMeters + LATERAL_CLEARANCE_M
  local leftOK = roomLeft >= LATERAL_CLEARANCE_M and leftTarget >= -(leftDistance - CAR_HALF_WIDTH_M)
  local rightOK = roomRight >= LATERAL_CLEARANCE_M and rightTarget <= rightDistance - CAR_HALF_WIDTH_M
  local side = 0
  local holding = record.engaged and finiteNumber(record.sideHoldUntil) and now < record.sideHoldUntil
  if holding and record.side == -1 then
    side = leftOK and -1 or (rightOK and 1 or 0)
  elseif holding and record.side == 1 then
    side = rightOK and 1 or (leftOK and -1 or 0)
  elseif leftOK and rightOK then
    -- Pass on the side the follower is already on; never cut across in front of the obstacle.
    -- Run 7 picked the roomier side and asked cars already clear on the left to cross over.
    local myMeters = finiteNumber(myLat) and lateralMeters(myLat, leftDistance, rightDistance) or nil
    if myMeters ~= nil then
      side = myMeters <= obstacleMeters and -1 or 1
    else
      side = roomLeft >= roomRight and -1 or 1
    end
  elseif leftOK then
    side = -1
  elseif rightOK then
    side = 1
  else
    side = 0
  end
  if side == 0 then return nil, nil, 0, leftDistance, rightDistance, true end
  return (side < 0 and leftTarget or rightTarget), (side < 0 and leftDistance or rightDistance),
    side, leftDistance, rightDistance, false
end

---Quintic with zero acceleration at both ends, copied from experimental/FrenetAvoid.lua so
---the runtime does not depend on the experimental module. Coefficients are stored on the
---per-car record; no closure is created in the per-frame path.
local function startLateralQuintic(record, now, startMeters, targetMeters, rampMps)
  local delta = targetMeters - startMeters
  local duration = 1.0
  if rampMps > 0.01 then
    local needed = 1.875 * math_abs(delta) / rampMps
    if needed > duration then duration = needed end
  end
  local t2, t3, t4, t5 = duration * duration, duration * duration * duration,
    duration * duration * duration * duration, duration * duration * duration * duration * duration
  record.a0, record.a1, record.a2 = startMeters, 0, 0
  record.a3 = (10 * delta) / t3
  record.a4 = (-15 * delta) / t4
  record.a5 = (6 * delta) / t5
  record.quinticDuration, record.quinticStart, record.targetMeters = duration, now, targetMeters
  record.rampMps, record.lastMeters = rampMps, startMeters
end

local function evaluateLateralQuintic(record, now)
  local t = now - record.quinticStart
  if t <= 0 then return record.a0 end
  if t >= record.quinticDuration then return record.targetMeters end
  local t2 = t * t
  return record.a0 + record.a1 * t + record.a2 * t2 + record.a3 * t2 * t
    + record.a4 * t2 * t2 + record.a5 * t2 * t2 * t
end

---Lightweight obstacle-driven lateral avoidance (F1-3). Reads other cars but only writes
---its own car; the player car (index 0) can be an obstacle and is never written.
---@param carIndex integer
---@param dt number
---@param car ac.StateCar
---@param sortedCarsList table<integer,ac.StateCar>
---@param storage StorageTable
---@param preferredObstacleIndex integer|nil
---@return boolean engaged
CarOperations.updateLateralAvoidance = function(carIndex, dt, car, sortedCarsList, storage, preferredObstacleIndex)
  local enabled = storage ~= nil and storage.lateralAvoidanceEnabled == true
  if Logger ~= nil and type(Logger.setF1_3Enabled) == 'function' then Logger.setF1_3Enabled(enabled) end
  local record = CarOperations._lateralAvoidance[carIndex]
  if not enabled then
    if record and record.engaged then
      CarOperations.releaseLateralOffset(carIndex, 'ACCIDENT_NAVIGATION')
      Logger_observe('f1-3-avoid-released', carIndex, CarManager.getCarGeneration(carIndex),
        nil, nil, '[F1-3] released reason=disabled', nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
      record.engaged, record.obstacleIndex, record.side = nil, nil, nil
    end
    return false
  end
  if not canWriteCar(carIndex) or car == nil or not finiteNumber(dt) or dt <= 0 or dt == math_huge then return false end
  if car.isInPit == true or car.isInPitlane == true then
    local pitRecord = CarOperations._lateralAvoidance[carIndex]
    if pitRecord and pitRecord.engaged then
      CarOperations.releaseLateralOffset(carIndex, 'ACCIDENT_NAVIGATION')
      Logger_observe('f1-3-avoid-released', carIndex, CarManager.getCarGeneration(carIndex),
        nil, nil, '[F1-3] released reason=pit', nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
      pitRecord.engaged, pitRecord.obstacleIndex, pitRecord.side = nil, nil, nil
    end
    return false
  end
  local trackLength = RaceTrackManager_getTrackLengthMeters()
  if not finiteNumber(trackLength) or trackLength <= 0 then return false end
  local now = getActiveGameTime()
  if now == nil then return false end
  local myLat = CarManager_getActualTrackLateralOffset(carIndex, car.position)
  local mySpline = car.splinePosition
  if not finiteNumber(myLat) or not finiteNumber(mySpline) then return false end
  if not record then record = {}; CarOperations._lateralAvoidance[carIndex] = record end

  if record.engaged then
    local obstacle = record.obstacleIndex and ac_getCar(record.obstacleIndex)
    local keep, releaseReason = false, 'no-obstacle'
    if obstacle and obstacle.index ~= carIndex
      and obstacle.isInPit ~= true and obstacle.isInPitlane ~= true then
      local obstacleSpline = obstacle.splinePosition
      if finiteNumber(obstacleSpline) then
        local behindFraction = (mySpline - obstacleSpline) % 1
        local aheadFraction = (obstacleSpline - mySpline) % 1
        if behindFraction > 0 and behindFraction < 0.5 then
          if behindFraction * trackLength > LATERAL_RELEASE_BEHIND_M then
            releaseReason = 'passed'
          else
            keep = true
          end
        elseif aheadFraction >= 0 and aheadFraction <= 0.5 then
          if aheadFraction * trackLength <= LATERAL_OBSTACLE_AHEAD_M then
            -- No heading test: a spun car facing backwards is still the obstacle.
            local obstacleLateral = CarManager_getActualTrackLateralOffset(obstacle.index, obstacle.position)
            if finiteNumber(obstacleLateral)
              and math_abs(obstacleLateral) <= LATERAL_OBSTACLE_ON_TRACK then
              keep = true
            else
              releaseReason = 'obstacle-gone'
            end
          else
            releaseReason = 'obstacle-gone'
          end
        end
      end
    end
    if not keep then
      CarOperations.releaseLateralOffset(carIndex, 'ACCIDENT_NAVIGATION')
      Logger_observe('f1-3-avoid-released', carIndex, CarManager.getCarGeneration(carIndex),
        nil, nil, string_format('[F1-3] released reason=%s obstacle=%s', releaseReason,
          tostring(record.obstacleIndex or 'none')), nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
      record.engaged, record.obstacleIndex, record.side = nil, nil, nil
      record.confirmTime, record.slowTime, record.slowCandidate = 0, 0, nil
      return false
    end
    local obstacleLateral = CarManager_getActualTrackLateralOffset(obstacle.index, obstacle.position)
    local targetMeters, edgeMeters, side, keepLeft, keepRight = computeLateralAvoidanceTarget(obstacle, obstacleLateral, record, now, myLat)
    if keepLeft then record.sideLeft, record.sideRight = keepLeft, keepRight end
    if not targetMeters then
      CarOperations.releaseLateralOffset(carIndex, 'ACCIDENT_NAVIGATION')
      Logger_observe('f1-3-avoid-released', carIndex, CarManager.getCarGeneration(carIndex),
        nil, nil, string_format('[F1-3] released reason=no-room obstacle=%d', obstacle.index),
        nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
      record.engaged, record.obstacleIndex, record.side = nil, nil, nil
      return false
    end
    if side ~= record.side then
      startLateralQuintic(record, now, record.lastMeters or 0, targetMeters, LATERAL_RAMP_MPS)
      record.side = side
    end
    local currentMeters = evaluateLateralQuintic(record, now)
    local maxStep = record.rampMps * dt
    local previousMeters = record.lastMeters or currentMeters
    if currentMeters > previousMeters + maxStep then currentMeters = previousMeters + maxStep end
    if currentMeters < previousMeters - maxStep then currentMeters = previousMeters - maxStep end
    record.lastMeters = currentMeters
    -- Diagnostic: once, about 1.5 s after engaging, compare the requested offset with where the car
    -- actually is (metres from the AI line), to tell a late/too-small request from an ignored one.
    if record.progressLogged ~= true and record.engagedAt ~= nil and now - record.engagedAt >= 1.5 then
      record.progressLogged = true
      local myLeft, myRight = readSplineSides(mySpline)
      if myLeft then
        Logger_observe('f1-3-avoid-progress', carIndex, CarManager.getCarGeneration(carIndex), nil, nil,
          string_format('[F1-3] chk req=%.1f act=%.1f o=%d', currentMeters,
            lateralMeters(myLat, myLeft, myRight), obstacle.index),
          nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
      end
    end
    local currentNormalized = metersToNormalized(currentMeters, record.sideLeft, record.sideRight)
    local targetNormalized = metersToNormalized(targetMeters, record.sideLeft, record.sideRight)
    CarOperations.requestLateralOffset(carIndex, currentNormalized, 'ACCIDENT_NAVIGATION', 'normalized',
      currentNormalized, edgeMeters, false, targetNormalized)
    return true
  end

  refreshObstacleSlowTimers(sortedCarsList, dt)
  local obstacle, obstacleLateral, distance = findLateralObstacle(carIndex, car, myLat, mySpline,
    sortedCarsList, trackLength, preferredObstacleIndex)
  if not obstacle then
    record.confirmTime, record.slowTime, record.slowCandidate, record.candidateIndex = 0, 0, nil, nil
    return false
  end

  -- Only a car that has itself been slow for LATERAL_STOPPED_SECONDS is an obstacle. The timer
  -- belongs to the obstacle (shared by all followers), not to the follower: a fast follower crosses
  -- the 80 m window in about 1.5 s. The closing-speed rule was removed after run 3: it fired in
  -- every braking zone and pushed AI into the walls.
  local closeEnough = (obstacleSlowTime[obstacle.index] or 0) >= LATERAL_STOPPED_SECONDS
  if not closeEnough then
    record.confirmTime, record.candidateIndex = 0, nil
    return false
  end
  if record.candidateIndex == obstacle.index then
    record.confirmTime = record.confirmTime + dt
  else
    record.candidateIndex, record.confirmTime = obstacle.index, dt
  end
  if record.confirmTime < LATERAL_ENGAGE_SECONDS then return false end

  local targetMeters, edgeMeters, side, leftDistance, rightDistance = computeLateralAvoidanceTarget(obstacle, obstacleLateral, record, now, myLat)
  if not targetMeters then
    if record.noRoomLogged ~= obstacle.index then
      record.noRoomLogged = obstacle.index
      Logger_observe('f1-3-avoid-no-room', carIndex, CarManager.getCarGeneration(carIndex),
        nil, nil, string_format('[F1-3] no room obstacle=%d spline=%.4f lateral=%.2f left=%.1f right=%.1f',
          obstacle.index, obstacle.splinePosition, obstacleLateral, leftDistance or -1, rightDistance or -1),
        nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
    end
    record.confirmTime = 0
    return false
  end

  record.engaged = true
  record.obstacleIndex = obstacle.index
  record.side = side
  record.sideHoldUntil = now + LATERAL_SIDE_HOLD_SECONDS
  record.engagedAt, record.progressLogged = now, false
  record.sideLeft, record.sideRight = leftDistance, rightDistance
  record.noRoomLogged = nil
  record.confirmTime, record.slowTime, record.slowCandidate, record.candidateIndex = 0, 0, nil, nil
  local startMeters = lateralMeters(myLat, leftDistance, rightDistance)
  startLateralQuintic(record, now, startMeters, targetMeters, LATERAL_RAMP_MPS)
  Logger_observe('f1-3-avoid-engaged', carIndex, CarManager.getCarGeneration(carIndex),
    nil, nil, -- Logger keeps 48 characters per field: keep the numbers inside that budget.
    string_format('[F1-3] eng o=%d %s %.1fm d=%.0f e=%.1f',
      obstacle.index, side < 0 and 'L' or 'R', targetMeters, distance or -1, edgeMeters or -1),
    nil, CarManager.sessionGeneration, nil, 'lateralAvoidance')
  local currentMeters = record.lastMeters
  local currentNormalized = metersToNormalized(currentMeters, leftDistance, rightDistance)
  local targetNormalized = metersToNormalized(targetMeters, leftDistance, rightDistance)
  CarOperations.requestLateralOffset(carIndex, currentNormalized, 'ACCIDENT_NAVIGATION', 'normalized',
    currentNormalized, edgeMeters, false, targetNormalized)
  return true
end


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
