local root = (arg[0]:gsub('tools[\\/]test_observability.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
Constants = { APP_NAME = 'OBS1-Observability-Capture-Envelope-Boundary' }
local output, writes = {}, {}
local simState = { isLive = true, isReplayActive = false, isSessionStarted = true, isPaused = false,
  trackLengthM = 5000, raceSessionType = 1 }
ac = { log = function(line) output[#output + 1] = line end,
  getSim = function() return simState end,
  getTrackName = function() return 'obs-test' end,
  getCar = function(index) return cars[index] end,
  SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4, TimeAttack = 5, Drift = 6, Drag = 7 },
  overrideCarControls = function() return {} end, TurningLights = { None = 0, Hazards = 3 },
  setTurningLights = function() end,
  setTargetCar = function() return true end, worldCoordinateToTrack = function() return { x = 0 } end }
Logger = dofile(root .. 'Logger.lua')
local now = 12.5
GameTimeManager = { getPlayingGameTime = function() return now end }
GameTimeManager.update = function(dt) now = now + dt end
local vectorMeta
vectorMeta = {
  __add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, vectorMeta) end,
  __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta) end,
  __unm = function(a) return setmetatable({ x = -a.x, y = -a.y, z = -a.z }, vectorMeta) end,
  __mul = function(a, b)
    if type(a) == 'number' then a, b = b, a end
    return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, vectorMeta)
  end
}
local function vec(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMeta) end
cars = {}
for i = 0, 30 do
  cars[i] = { index = i, isAIControlled = i > 0, isConnected = true, isActive = true,
    position = vec(i * 5, 0, 0), splinePosition = .2 + i * .005, speedKmh = 50,
    look = vec(0, 0, 1), side = vec(1, 0, 0), up = vec(0, 1, 0),
    wheels = { [0] = { surfaceValidTrack = true }, [1] = { surfaceValidTrack = true },
      [2] = { surfaceValidTrack = true }, [3] = { surfaceValidTrack = true } },
    isInPit = false, isInPitlane = false }
end
cars[0].isAIControlled = false
physics = { allowed = function() return true end }
for _, name in ipairs({ 'setAITopSpeed', 'setAIThrottleLimit', 'setAICaution', 'setAIStopCounter',
  'setGentleStop', 'preventAIFromRetiring', 'setAIAggression', 'setAILevel', 'setExtraAIGrip', 'setAISplineOffset' }) do
  local physicalName = name
  physics[physicalName] = function(...)
    local call = { physicalName, select('#', ...), ... }
    call.time = now
    writes[#writes + 1] = call
  end
end
ac.areCarsColliding = function() return false end
local ray = { cars = function() return -1 end, carCollider = function() return -1 end }
render = { createRay = function() return ray end }
VecPool = { getTempVec3 = function() return vec(0, 0, 0) end }
vec3 = function(x, y, z) local value = vec(x, y, z); value.set = function(self, a, b, c) self.x, self.y, self.z = a, b, c end; return value end
MathHelpers = { approach = function(v) return v end, dot = function() return 0 end,
  vsub = function(a, b) return vec(a.x-b.x, a.y-b.y, a.z-b.z) end,
  distanceBetweenVec3sSqr = function(a, b) local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z; return x*x+y*y+z*z end }
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
local storage = { defaultLateralOffset = 0, overrideAiAwareness = false, handleAccidents = true,
  deferTimeAfterSessionStart = 0, distanceFromAccidentToSeeYellowFlag_meters = 100,
  yieldingLateralOffset = .5, overtakingLateralOffset = -.5 }
StorageManager = { getStorage = function() return storage end,
  getStorage_Overtaking = function() return { handleOvertaking = false } end,
  getStorage_Yielding = function() return { handleYielding = false } end,
  getStorage_AICarValues = function() return { defaultAICaution = 1 } end,
  getStorage_Behavior = function() return { defenseDurationMin_s = 1, defenseDurationMax_s = 2 } end }
Strings = { StringNames = { [1] = { None = 0 }, [2] = { None = 0 }, [3] = { AccidentResolved = 1 } },
  StringCategories = { ReasonWhyCantYield = 1, ReasonWhyCantOvertake = 2, StateExitReason = 3 } }
StringsManager = { setString = function() end }
SessionDetails = { getTimeSinceSessionStarted = function() return 100 end, update = function() end }
local queueId = 0
QueueManager = {
  createQueue = function() queueId = queueId + 1; return { data = {}, first = 1, last = 0 } end,
  enqueue = function(q, v) q.last=q.last+1; q.data[q.last]=v end,
  dequeue = function(q) if q.first>q.last then return nil end; local v=q.data[q.first]; q.data[q.first]=nil; q.first=q.first+1; return v end,
  queueLength = function(q) return q.last-q.first+1 end,
}
CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
CarManager = dofile(root .. 'CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
CarOperations = dofile(root .. 'CarOperations.lua')
CarStateMachine = dofile(root .. 'CarStateMachine/CarStateMachine.lua')
AccidentManager = dofile(root .. 'AccidentManager.lua')
OnCarEventManager = dofile(root .. 'OnCarEventManager.lua')
for _, stateFile in ipairs({ 'CarState_DrivingNormally.lua', 'CarState_DrivingInYellowFlagZone.lua',
  'CarState_CollidedWithCar.lua', 'CarState_AnotherCarCollidedIntoMe.lua', 'CarState_NavigatingAroundAccident.lua' }) do
  dofile(root .. 'CarStateMachine/States/' .. stateFile)
end
for i = 1, 30 do
  CarManager.cars_sideBlockRaysData[i] = {}
  CarManager.cars_totalSideBlockRaysData[i] = 0
  CarManager.cars_HALF_AABSIZE[i] = vec(1, 1, 1)
end
local function snapshot()
  local stats = Logger.getOBS1Stats()
  stats.records = {}
  for i = 1, stats.count do stats.records[i] = Logger.getOBS1Record(i) end
  return stats
end
local recordFields = { 'sequence', 'capture', 'session', 'kind', 'car', 'generation', 'referenceSession',
  'incident', 'zone', 'detail', 'previousState', 'activeTime', 'activeTimeValid', 'wallTime', 'wallTimeValid',
  'context', 'runtimeEnabled', 'runtimePaused', 'runtimeLive', 'extra', 'resource' }
local function loggerState()
  return { stats = Logger.getOBS1Stats(), records = snapshot().records,
    enabled = Logger.OBS1_ENABLED, focus = Logger.OBS1_FOCUS_CAR }
end
local function assertLoggerStateUnchanged(before, label)
  local after = loggerState()
  for key, value in pairs(before.stats) do assert(after.stats[key] == value, label .. ': stat ' .. key .. ' changed') end
  for key, value in pairs(after.stats) do assert(before.stats[key] == value, label .. ': stat ' .. key .. ' appeared') end
  assert(after.enabled == before.enabled and after.focus == before.focus
    and #after.records == #before.records, label .. ': flags or ring count changed')
  for i = 1, #before.records do
    for _, field in ipairs(recordFields) do
      assert(after.records[i][field] == before.records[i][field], label .. ': record #' .. i .. ' field ' .. field .. ' changed')
    end
  end
end

assert(Logger.OBS1_ENABLED == false and Logger.OBS1_FOCUS_CAR == -1)
assert(Logger.observe('off-path', 24) == false and #output == 0)
local hostileStamp = setmetatable({}, { __index = function(_, key)
  if key == 'culpritGeneration' then error('diagnostic-only stamp field must not be read') end
end })
assert(AccidentManager.registerCollision(24, vec(0, 0, 0), 0, hostileStamp) == nil,
  'observation-disabled ignored track contact does not evaluate diagnostic stamp fields')
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 24
assert(AccidentManager.registerCollision(24, vec(0, 0, 0), 0, hostileStamp) == nil,
  'observation-enabled ignored track contact isolates diagnostic stamp preparation')
CarManager.resetSession()
table.clear(output)
assert(Logger.observe('focus-baseline', 24, 7, nil, nil, 'no-incident'))
local initial = snapshot()
assert(initial.count == 1 and initial.records[1].car == 24 and initial.records[1].generation == 7
  and initial.records[1].activeTimeValid and initial.records[1].activeTime == now
  and initial.records[1].wallTimeValid, 'focus works without an incident and records valid times')
assert(type(Logger.getOBS1RecentForCar) == 'function', 'OBS2-A exposes the bounded read-only per-car snapshot API')
local initialRecent = Logger.getOBS1RecentForCar(24)
assert(initialRecent and initialRecent.car == 24 and initialRecent.matchingCount == 1 and initialRecent.scanned == 1
  and initialRecent.limited == false and #initialRecent.records == 1
  and initialRecent.stats.capture == initial.capture, 'query snapshots a selected car without incident association')
for _, field in ipairs(recordFields) do
  assert(initialRecent.records[1][field] == initial.records[1][field], 'query record copies legacy field ' .. field)
end
local beforeEnabledQuery = loggerState()
assert(Logger.getOBS1RecentForCar(24) ~= nil, 'enabled query returns a snapshot')
assertLoggerStateUnchanged(beforeEnabledQuery, 'enabled query')
local beforeQueryMutation = Logger.getOBS1Record(1)
initialRecent.records[1].car, initialRecent.records[1].context = 999, 'mutated-copy'
initialRecent.records[1].detail = 'mutated-copy'
initialRecent.stats.count = -1
initialRecent.car, initialRecent.matchingCount = -1, -1
local afterQueryMutation = Logger.getOBS1RecentForCar(24)
assert(afterQueryMutation.car == 24 and afterQueryMutation.records[1].car == beforeQueryMutation.car
  and afterQueryMutation.records[1].context == beforeQueryMutation.context
  and afterQueryMutation.records[1].detail == beforeQueryMutation.detail
  and afterQueryMutation.stats.count == initial.count, 'snapshot/list/stats mutation cannot alias Logger internals')
for _, invalidCarIndex in ipairs({ -1, 1.5, 0 / 0, math.huge, -math.huge, '24', true, {} }) do
  assert(Logger.getOBS1RecentForCar(invalidCarIndex) == nil, 'invalid query car index is rejected safely')
end
assert(Logger.getOBS1RecentForCar(nil) == nil, 'nil query car index is rejected safely')
Logger.OBS1_ENABLED = false
local beforeReadOnlyQueries = loggerState()
assert(Logger.getOBS1RecentForCar(24) ~= nil, 'query may read retained records while OBS is disabled')
assertLoggerStateUnchanged(beforeReadOnlyQueries, 'disabled query')
Logger.OBS1_ENABLED = true
local beforeFailedQuery = loggerState()
local savedStatsGetter = Logger.getOBS1Stats
Logger.getOBS1Stats = function() error('injected snapshot stats failure') end
assert(Logger.getOBS1RecentForCar(24) == nil, 'query internal failure returns nil')
Logger.getOBS1Stats = savedStatsGetter
assertLoggerStateUnchanged(beforeFailedQuery, 'failed query')
assert(#output == 2 and #output[1] <= 384 and #output[2] <= 384 and output[1]:find('[OBS1]', 1, true),
  'real Logger writes actual enveloped CSP lines under byte cap: lines=' .. #output
  .. ' sizes=' .. tostring(output[1] and #output[1]) .. '/' .. tostring(output[2] and #output[2]))
local longScalar = string.rep('X', 48)
assert(Logger.observe('incident-' .. string.rep('K', 39), longScalar, longScalar, longScalar,
  longScalar, longScalar, longScalar, longScalar), 'maximal scalar envelope is accepted into the ring')
local sawExactEnvelopeCap = false
for i = 1, #output do if #output[i] == 384 then sawExactEnvelopeCap = true end end
assert(sawExactEnvelopeCap, 'nontrivial APP_NAME plus bounded scalar payload reaches the 384-byte full-envelope cap')
Logger.OBS1_ENABLED = false
assert(CarOperations.setAICaution(27, 3))
local offWrite = writes[#writes]
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 27
assert(Logger.observe('command-equivalence', 27, CarManager.getCarGeneration(27)))
assert(CarOperations.setAICaution(27, 3))
local onWrite = writes[#writes]
assert(offWrite[1] == onWrite[1] and offWrite[2] == onWrite[2] and offWrite[3] == onWrite[3]
  and offWrite[4] == onWrite[4] and CarManager.cars_aiCaution[27] == 3,
  'diagnostic off/on preserves real writer name, argument count, arguments and resulting state')

-- Isolated IA x IA episode runs exercise both participants through confirmed release and normal-state dispatch.
local position = vec(0, 0, 0)
local function findUpvalue(fn, wanted)
  for i = 1, 80 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
end
local function hasEvent(kind, car)
  local snap = snapshot()
  for i = 1, snap.count do
    local record = snap.records[i]
    if record.kind == kind and (car == nil or record.car == car) then return true end
  end
  return false
end
local function countContactQueueEvents(snap, kind, session, incident)
  local count, culprit, victim = 0, false, false
  for i = 1, snap.count do
    local record = snap.records[i]
    if record.kind == kind and record.referenceSession == session and record.incident == incident then
      count = count + 1
      if record.car == 1 then culprit = true elseif record.car == 2 then victim = true end
    end
  end
  return count, culprit, victim
end
local callbackCalls = 0
local registeredIncident
OnCarEventManager.OnCarEventExecutions[OnCarEventManager.OnCarEventType.Collision] = function(index, event)
  callbackCalls = callbackCalls + 1
  registeredIncident = assert(AccidentManager.registerCollision(index, event.collisionPosition, event.collidedWith, event))
end
local counterDuration = findUpvalue(CarOperations.updateIncidentStop, 'INCIDENT_COUNTER_SECONDS')
assert(type(counterDuration) == 'number', 'test reads existing incident-counter grace duration')
local function clearEpisodeFixture()
  Logger.OBS1_ENABLED = false
  CarManager.resetSession()
  OnCarEventManager.clear()
  CarStateMachine.clearPendingLifecycle()
  AccidentManager.resetSession()
  RaceTrackManager.resetOwnedYellowFlagZones()
  CarStateMachine.initializeCarInStateMachine(1)
  CarStateMachine.initializeCarInStateMachine(2)
  now = 12.5
end
local function runEpisode(mode)
  clearEpisodeFixture()
  Logger.OBS1_FOCUS_CAR = 1
  local savedObserve, savedFormat, savedSink = Logger.observe, string.format, ac.log
  local helperCalls, formatCalls, sinkThrows = 0, 0, 0
  if mode == 'helper-throw' then
    Logger.observe = function() helperCalls = helperCalls + 1; error('OBS helper injection') end
  elseif mode == 'format-throw' then
    string.format = function(formatString, ...)
      local message = select(3, ...)
      if formatString == '%s %s %s' and type(message) == 'string' and message:find('[OBS1]', 1, true) then
        formatCalls = formatCalls + 1
        error('OBS-only formatter injection')
      end
      return savedFormat(formatString, ...)
    end
  elseif mode == 'sink-throw' then
    ac.log = function(line)
      if type(line) == 'string' and line:find('[OBS1]', 1, true) then
        sinkThrows = sinkThrows + 1
        output[#output + 1] = line
        error('OBS-only sink injection after side effect')
      end
      return savedSink(line)
    end
  end
  Logger.OBS1_ENABLED = mode ~= 'off'
  local startWrite, startOutput = #writes, #output
  local queueEventBaseline = snapshot()
  local queueEventSession = CarManager.sessionGeneration
  Logger.log('legacy-episode-probe')
  assert(OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Collision,
    1, position, 3, cars[1], cars[2]))
  OnCarEventManager.processQueuedEvents()
  CarStateMachine.handleQueuedAccidents()
  local incident = registeredIncident
  local beforeQueueCount = countContactQueueEvents(queueEventBaseline, 'queue-consumed', queueEventSession, incident)
  local queueEventCount, observedCulprit, observedVictim = countContactQueueEvents(
    snapshot(), 'queue-consumed', queueEventSession, incident)
  if mode == 'off' or mode == 'helper-throw' then
    assert(queueEventCount == beforeQueueCount,
      'disabled or throwing observation helper adds no queue-consumed event in ' .. mode)
  else
    assert(queueEventCount - beforeQueueCount == 2 and observedCulprit and observedVictim,
      'both current-session participant queue records are newly observed as consumed, not S2-admitted in ' .. mode)
  end
  assert(CarOperations.admitIncidentStop(1, incident,
    CarManager.getCarGeneration(1), CarManager.sessionGeneration)
    and CarOperations.admitIncidentStop(2, incident,
      CarManager.getCarGeneration(2), CarManager.sessionGeneration),
    'fixture explicitly admits episodes for S2 trace comparison in ' .. mode)
  CarStateMachine.queueStateTransition(1, CarStateMachine.CarStateType.COLLIDED_WITH_CAR)
  CarStateMachine.queueStateTransition(2, CarStateMachine.CarStateType.ANOTHER_CAR_COLLIDED_INTO_ME)
  local episodeTable = findUpvalue(CarOperations.admitIncidentStop, 'incidentEpisodes')
  local deadlines, counterExpiry, firstHandback, completionTimes, normalTimes = {}, {}, {}, {}, {}
  for _, carIndex in ipairs({ 1, 2 }) do
    assert(episodeTable[carIndex], 'fixture-admitted culprit and victim receive a real episode in ' .. mode)
    deadlines[carIndex] = episodeTable[carIndex].deadline
    assert(deadlines[carIndex] == 12.5 + 10, 'measured episode deadline uses admission clock in ' .. mode)
  end
  local transitions = {}
  local step, ticks = .5, 0
  while ticks < 100 do
    ticks = ticks + 1
    now = 12.5 + ticks * step
    for _, carIndex in ipairs({ 1, 2 }) do
      local before = CarStateMachine.getCurrentState(carIndex)
      CarStateMachine.updateCar(carIndex, step, cars, carIndex)
      local after = CarStateMachine.getCurrentState(carIndex)
      if before ~= after then transitions[#transitions + 1] = { car = carIndex, time = now, state = after } end
      if after == CarStateMachine.CarStateType.DRIVING_NORMALLY and not normalTimes[carIndex] then normalTimes[carIndex] = now end
      if CarOperations.hasCompletedIncidentStop(carIndex) and not completionTimes[carIndex] then completionTimes[carIndex] = now end
      local episode = episodeTable[carIndex]
      if episode then counterExpiry[carIndex] = episode.counterUntil end
    end
    CarOperations.resolveOwnedAIControls(150)
    for i = startWrite + 1, #writes do
      local call = writes[i]
      if call[1] == 'setAIStopCounter' then
        local carIndex = call[3]
        assert(call.time < deadlines[carIndex], 'stop counter is never renewed at/after deadline in ' .. mode)
        local counterList = counterExpiry._history or {}
        counterExpiry._history = counterList
        counterList[carIndex] = counterList[carIndex] or {}
        counterList[carIndex][#counterList[carIndex] + 1] = call.time
      elseif (call[1] == 'setAITopSpeed' or call[1] == 'setAIThrottleLimit') then
        local carIndex = call[3]
        if call.time >= deadlines[carIndex] and not firstHandback[carIndex] then firstHandback[carIndex] = call.time end
      end
      if not completionTimes[1] and CarOperations.hasCompletedIncidentStop(1) then completionTimes[1] = now end
      if not completionTimes[2] and CarOperations.hasCompletedIncidentStop(2) then completionTimes[2] = now end
    end
    if normalTimes[1] and normalTimes[2] and completionTimes[1] and completionTimes[2] then break end
  end
  local calls, lastCounterTimes, legacyMessages = {}, {}, {}
  for i = startWrite + 1, #writes do
    local source, copy = writes[i], {}
    for j = 1, source[2] + 2 do copy[j] = source[j] end
    copy.time = source.time
    calls[#calls + 1] = copy
    if source[1] == 'setAIStopCounter' then lastCounterTimes[source[3]] = source.time end
  end
  local legacyMarker = '] [' .. Constants.APP_NAME .. '] '
  for i = startOutput + 1, #output do
    local line = output[i]
    if not line:find('[OBS1]', 1, true) then
      local markerAt = line:find(legacyMarker, 1, true)
      legacyMessages[#legacyMessages + 1] = markerAt and line:sub(markerAt + #legacyMarker) or line
    end
  end
  for _, carIndex in ipairs({ 1, 2 }) do
    assert(normalTimes[carIndex] and CarStateMachine.getCurrentState(carIndex) == CarStateMachine.CarStateType.DRIVING_NORMALLY,
      'both participants actually dispatch to DRIVING_NORMALLY in ' .. mode)
    assert(completionTimes[carIndex] and CarOperations.hasCompletedIncidentStop(carIndex)
      and not CarOperations._topSpeedRequests[carIndex].byOwner.INCIDENT_STOP.active
      and not CarOperations._throttleRequests[carIndex].byOwner.INCIDENT_STOP.active,
      'both participants complete handback and release requests in ' .. mode)
    assert(lastCounterTimes[carIndex] and lastCounterTimes[carIndex] < deadlines[carIndex]
      and counterExpiry[carIndex] == lastCounterTimes[carIndex] + counterDuration,
      'actual last stop-counter write and captured grace expiry agree in ' .. mode)
    assert(firstHandback[carIndex] and firstHandback[carIndex] >= deadlines[carIndex],
      'first actual handback follows measured deadline in ' .. mode)
  end
  if mode == 'helper-throw' then assert(helperCalls > 0, 'helper-failure injection executes during full episode') end
  if mode == 'format-throw' then assert(formatCalls > 0 and Logger.getOBS1Stats().formatFailures > 0,
    'OBS-only formatter injection executes during full episode') end
  if mode == 'sink-throw' then assert(sinkThrows > 0 and Logger.getOBS1Stats().sinkThrewUncertain > 0,
    'OBS-only sink injection executes during full episode') end
  Logger.observe, string.format, ac.log = savedObserve, savedFormat, savedSink
  return { calls = calls, deadlines = deadlines, counterExpiry = counterExpiry, lastCounterTimes = lastCounterTimes,
    firstHandback = firstHandback, completionTimes = completionTimes, normalTimes = normalTimes,
    transitions = transitions, legacyMessages = legacyMessages, records = snapshot() }
end
local function compareEpisode(expected, actual, mode)
  assert(#expected.calls == #actual.calls, mode .. ': physical command count unchanged')
  for i = 1, #expected.calls do
    local a, b = expected.calls[i], actual.calls[i]
    assert(a[1] == b[1] and a[2] == b[2] and a.time == b.time,
      mode .. ': command name/nargs/time/order at call #' .. i)
    for argIndex = 1, a[2] do
      assert(a[argIndex + 2] == b[argIndex + 2], mode .. ': explicit argument including nil at call #' .. i .. '/' .. argIndex)
    end
  end
  for _, carIndex in ipairs({ 1, 2 }) do
    assert(expected.deadlines[carIndex] == actual.deadlines[carIndex]
      and expected.counterExpiry[carIndex] == actual.counterExpiry[carIndex]
      and expected.lastCounterTimes[carIndex] == actual.lastCounterTimes[carIndex]
      and expected.firstHandback[carIndex] == actual.firstHandback[carIndex]
      and expected.completionTimes[carIndex] == actual.completionTimes[carIndex]
      and expected.normalTimes[carIndex] == actual.normalTimes[carIndex],
      mode .. ': deadline, counter grace, handback, completion and normal exit match for car ' .. carIndex)
  end
  assert(#expected.transitions == #actual.transitions and #expected.legacyMessages == #actual.legacyMessages,
    mode .. ': state transitions and legacy log calls match')
  for i = 1, #expected.transitions do
    local a, b = expected.transitions[i], actual.transitions[i]
    assert(a.car == b.car and a.time == b.time and a.state == b.state, mode .. ': state transition at #' .. i)
  end
  for i = 1, #expected.legacyMessages do
    assert(expected.legacyMessages[i] == actual.legacyMessages[i], mode .. ': legacy Logger.log unchanged at #' .. i)
  end
end
local baselineEpisode = runEpisode('on')
local function findRecord(stats, kind, car)
  for i = 1, stats.count do
    local record = stats.records[i]
    if record.kind == kind and (car == nil or record.car == car) then return record end
  end
end
local acceptedRecord, createdRecord = findRecord(baselineEpisode.records, 'incident-accepted', 1),
  findRecord(baselineEpisode.records, 'incident-created', 1)
assert(acceptedRecord and createdRecord and acceptedRecord.sequence < createdRecord.sequence
  and findRecord(baselineEpisode.records, 'fsm-entry-returned-essential', 1),
  'actual IA x IA episode records acceptance, creation and returned entry in order')
local offEpisode = runEpisode('off')
compareEpisode(offEpisode, baselineEpisode, 'OBS enabled')
for _, mode in ipairs({ 'helper-throw', 'format-throw', 'sink-throw' }) do
  local failureEpisode = runEpisode(mode)
  compareEpisode(offEpisode, failureEpisode, mode)
end
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 24

Logger.OBS1_FOCUS_CAR = 26
local replacedState, winningState = CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT,
  CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE
CarStateMachine.queueStateTransition(26, replacedState)
CarStateMachine.queueStateTransition(26, winningState)
storage.distanceToStartNavigatingAroundCarInAccident_meters = 1
CarStateMachine.updateCar(26, .016, cars, 26)
local sawReplacedRequest, sawWinningRequest, sawReplacedDispatch, sawWinningDispatch, sawWinningEntry = false, false, false, false, false
local replacedName = 'fsm-dispatched-essential'
local snapRequests = snapshot()
for i = 1, snapRequests.count do
  local record = snapRequests.records[i]
  if record.car == 26 and record.kind == 'fsm-requested-essential' and record.detail == replacedState then sawReplacedRequest = true end
  if record.car == 26 and record.kind == 'fsm-requested-essential' and record.detail == winningState then sawWinningRequest = true end
  if record.car == 26 and record.kind == replacedName and record.detail == replacedState then sawReplacedDispatch = true end
  if record.car == 26 and record.kind == replacedName and record.detail == winningState then sawWinningDispatch = true end
  if record.car == 26 and record.kind == 'fsm-entry-returned-essential' and record.detail == winningState then sawWinningEntry = true end
end
assert(sawReplacedRequest and sawWinningRequest and not sawReplacedDispatch and sawWinningDispatch and sawWinningEntry,
  'replacement keeps both requests but dispatches/completes only the winning state: '
  .. tostring(sawReplacedRequest) .. '/' .. tostring(sawWinningRequest) .. '/' .. tostring(sawReplacedDispatch)
  .. '/' .. tostring(sawWinningDispatch) .. '/' .. tostring(sawWinningEntry))
Logger.observe('unicode-check', 26, 1, nil, nil, string.rep('é', 24))
local sawUnicodeLine = false
for i = 1, #output do
  if output[i]:find(string.rep('é', 2), 1, true) then sawUnicodeLine = true end
  assert(#output[i] <= 384, 'UTF-8 envelope length is counted in bytes')
end
assert(sawUnicodeLine, 'real enveloped output preserves bounded UTF-8 detail')
now = math.huge
assert(Logger.observe('nonfinite-time-check', 26, 1, nil, nil, string.rep('🙂', 1000)))
now = 12.5
local sawInvalidActiveClock, sawHugeUtf8 = false, false
local utf8Snapshot = snapshot()
for i = 1, utf8Snapshot.count do
  local record = utf8Snapshot.records[i]
  if record.kind == 'nonfinite-time-check' then
    sawInvalidActiveClock = not record.activeTimeValid
    sawHugeUtf8 = #record.detail <= 48
  end
end
assert(sawInvalidActiveClock and sawHugeUtf8,
  'nonfinite clocks become UNKNOWN and huge UTF-8 scalar storage stays byte-bounded')
for i = 1, #output do assert(#output[i] <= 384, 'huge UTF-8 physical envelope respects byte cap') end

-- A thrown entry remains a runtime error and is never marked returned.
local sentinel = {}
local transitionState = CarStateMachine.CarStateType.NAVIGATING_AROUND_ACCIDENT
CarStateMachine.states_entryFunctions[transitionState] = function() error(sentinel) end
CarStateMachine.queueStateTransition(24, transitionState)
local ok, err = pcall(CarStateMachine.updateCar, 24, .016, cars, 24)
assert(not ok and err == sentinel and not hasEvent('fsm-entry-returned-essential', 24),
  'entry exception propagates unchanged and has no fabricated completion')
CarStateMachine.states_entryFunctions[transitionState] = function() end

-- Inject both lookup failure and real envelope-format failure; operational event lifecycle remains intact.
local oldObserve = Logger.observe
Logger.observe = function() error('injected observer failure') end
local failureIncident = assert(AccidentManager.registerCollision(15, vec(0, 0, 0), 17))
local failureZone = assert(AccidentManager.accidents_yellowFlagZoneIndex[failureIncident])
assert(RaceTrackManager.removeYellowFlagZone(failureZone) == true,
  'throwing observer cannot block real incident/zone creation or zone removal')
storage.distanceToStartNavigatingAroundCarInAccident_meters = 100
CarStateMachine.queueStateTransition(25, CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE)
assert(CarStateMachine.updateCar(25, .016, cars, 25) == nil
  and CarStateMachine.getCurrentState(25) == CarStateMachine.CarStateType.DRIVING_IN_YELLOW_FLAG_ZONE,
  'throwing Logger observer cannot alter real state dispatch/update path')
Logger.observe = oldObserve

-- Invoke the real root entrypoint in an isolated headless environment and exercise its registered callbacks.
local rootCallbacks, rootEnv = {}, {}
local rootConstants = { APP_NAME = 'OBS1-root-test', APP_VERSION = 'test', CAN_APP_RUN = true,
  ENABLE_DEVELOPMENT_DEBUG_PANEL = false, IS_ONLINE = false }
local rootCompatibility = { addFunction = function() end, addSimStateFunction = function() end,
  checkForMissingElements = function() return true end, getLastGeneratedErrorMessage = function() return '' end,
  freeMemory = function() end }
local rootModules = {
  Constants = rootConstants, Logger = Logger, CSPCompatibilityManager = rootCompatibility,
  ['lib.AssettoCorsaCSPLuaCompatibilityManager.CSPCompatibilityManager'] = rootCompatibility,
  VecPool = VecPool, DequeManager = {}, StackManager = {}, QueueManager = QueueManager,
  CompletableIndexCollectionManager = CompletableIndexCollectionManager,
  GameTimeManager = GameTimeManager, AppIconRenderer = {}, ColorManager = ColorManager,
  RaceTrackManager = RaceTrackManager, StorageManager = StorageManager, MathHelpers = MathHelpers,
  CarManager = CarManager, CarOperations = CarOperations, CameraManager = { getFocusedCarIndex = function() return nil end },
  ['Strings.Strings'] = Strings, ['Strings.Strings_ReasonWhyCantYield'] = {},
  ['Strings.Strings_ReasonWhyCantOvertake'] = {}, ['Strings.Strings_StateExitReason'] = {},
  StringsManager = StringsManager, OnCarEventManager = OnCarEventManager,
  ['CarStateMachine.CarStateMachine'] = CarStateMachine,
  ['CarStateMachine.States.CarState_DrivingNormally'] = {},
  ['CarStateMachine.States.CarState_EasingInYield'] = {},
  ['CarStateMachine.States.CarState_StayingOnYieldingLane'] = {},
  ['CarStateMachine.States.CarState_EasingOutYield'] = {},
  ['CarStateMachine.States.CarState_CollidedWithCar'] = {},
  ['CarStateMachine.States.CarState_CollidedWithTrack'] = {},
  ['CarStateMachine.States.CarState_AnotherCarCollidedIntoMe'] = {},
  ['CarStateMachine.States.CarState_EasingInOvertake'] = {},
  ['CarStateMachine.States.CarState_StayingOnOvertakingLane'] = {},
  ['CarStateMachine.States.CarState_EasingOutOvertake'] = {},
  ['CarStateMachine.States.CarState_NavigatingAroundAccident'] = {},
  ['CarStateMachine.States.CarState_DrivingInYellowFlagZone'] = {},
  ['CarStateMachine.States.CarState_AfterCustomAIFloodTeleport'] = {},
  AccidentManager = AccidentManager, RaceFlagManager = {}, UILateralOffsetsImageWidget = {},
  UIAppNameVersionWidget = {}, UIOperations = {}, UIManager = {}, ['lib/uilib/Logo'] = {},
  SessionDetails = { informSessionInitiated = function() end, update = function() end }, Pathfinding = {}, BehaviorPolish = {},
  HumanErrorManager = { resetAll = function() end, update = function() end },
  SettingsWindow = {}, MainWindow = {}, ControlDebugPanel = {}
}
local savedAcMethods = { onCarCollision = ac.onCarCollision, onCarJumped = ac.onCarJumped,
  onCarSwap = ac.onCarSwap, onSessionStart = ac.onSessionStart, iterateCars = ac.iterateCars }
local originalPackagePath = package.path
ac.onCarCollision = function(_, callback) rootCallbacks.collision = callback end
ac.onCarJumped = function(_, callback) rootCallbacks.jumped = callback end
ac.onCarSwap = function(_, callback) rootCallbacks.swap = callback end
ac.onSessionStart = function(callback) rootCallbacks.session = callback end
ac.iterateCars = function() return function() return nil end end
local oldGlobalStorage = StorageManager.getStorage_Global
StorageManager.getStorage_Global = function() return { appRanFirstTime = true } end
storage.enabled = true
rootEnv.__dirname = root ~= '' and root or '.'
rootEnv.require = function(name) return rootModules[name] or {} end
rootEnv.package, rootEnv.script, rootEnv.rgbm = package, {}, function(...) return { ... } end
rootEnv.ui = { Icons = { Cancel = 0 }, Font = { Title = 0, Main = 0 } }
setmetatable(rootEnv, { __index = _G })
local rootChunk = assert(loadfile(root .. 'SimOpenTrackDay.lua'))
setfenv(rootChunk, rootEnv)
rootChunk()
assert(type(rootCallbacks.collision) == 'function' and type(rootCallbacks.swap) == 'function'
  and type(rootCallbacks.session) == 'function', 'real entrypoint registers expected runtime callbacks')
cars[18].collidedWith = 20
cars[18].collisionPosition = vec(0, 0, 0)
rootCallbacks.collision(18)
assert(OnCarEventManager.processQueuedEvents() == nil, 'real collision callback event queue processes')
local rootIncident = AccidentManager.cars_culpritInAccidentIndex[18]
assert(rootIncident and hasEvent('incident-created', 18) and hasEvent('queue-callback-returned', 18),
  'real entrypoint callback produces correlated incident and callback-returned events')
local rootCaptureBefore = Logger.getOBS1Stats().capture
rootCallbacks.session()
assert(hasEvent('session-start') and Logger.getOBS1Stats().capture == rootCaptureBefore + 1,
  'real entrypoint session callback renews only on generation change and emits session context')
rootCallbacks.swap(18)
assert(hasEvent('lifecycle-swap', 18), 'real entrypoint lifecycle callback emits observation context')
local rootUpdate = rootEnv.script.MANIFEST__UPDATE
assert(type(rootUpdate) == 'function', 'headless entrypoint exposes its real UPDATE callback')
local contextCapture, contextSession = Logger.getOBS1Stats().capture, CarManager.sessionGeneration
local previousAttempts = Logger.getOBS1Stats().attempts
local function updateContext(label, expectedReason, enabled, paused, live, noWrites)
  local writesBefore = #writes
  rootUpdate(.5)
  assert(CarManager.runtimeEnabled == enabled and CarManager.runtimePaused == paused
    and CarManager.runtimeLive == live and CarManager.runtimeSuspensionReason == expectedReason,
    'real root UPDATE sets runtime context for ' .. label)
  Logger.observe('lifecycle-context-probe', nil, nil, nil, nil, label)
  local stats = Logger.getOBS1Stats()
  assert(stats.capture == contextCapture and CarManager.sessionGeneration == contextSession
    and stats.attempts >= previousAttempts,
    'context edge ' .. label .. ' preserves session and does not decrease output attempts')
  previousAttempts = stats.attempts
  local found
  for i = 1, stats.count do
    local record = Logger.getOBS1Record(i)
    if record.kind == 'lifecycle-context-probe' and record.detail == label then found = record end
  end
  assert(found and found.context == (expectedReason or 'live')
    and found.runtimeEnabled == enabled and found.runtimePaused == paused and found.runtimeLive == live,
    'per-record context/boolean snapshot matches real UPDATE edge ' .. label)
  if noWrites then assert(#writes == writesBefore, 'suspended ' .. label .. ' performs no physics writer calls') end
end
simState.isLive, simState.isPaused, simState.isReplayActive = true, false, false
storage.enabled = true
updateContext('live-start', nil, true, false, true, false)
simState.isLive, simState.isPaused = false, true
updateContext('pause', 'pause', true, true, false, true)
simState.isLive, simState.isPaused = true, false
updateContext('live-after-pause', nil, true, false, true, false)
simState.isReplayActive = true
updateContext('replay', 'replay', true, false, false, true)
simState.isReplayActive = false
updateContext('live-after-replay', nil, true, false, true, false)
storage.enabled = false
updateContext('disabled', 'disabled', false, false, false, true)
storage.enabled = true
updateContext('live-after-disabled', nil, true, false, true, false)
local contextCaptureBeforeLifecycleCallbacks = Logger.getOBS1Stats().capture
rootCallbacks.jumped(18)
assert(Logger.getOBS1Stats().capture == contextCaptureBeforeLifecycleCallbacks,
  'real jump callback does not renew the observation session')
rootCallbacks.swap(18)
assert(Logger.getOBS1Stats().capture == contextCaptureBeforeLifecycleCallbacks,
  'real swap callback does not renew the observation session')
OnCarEventManager.clear()

-- Keep per-record context after the original live lifecycle marker is overwritten by the bounded ring.
local savedContext = { CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive,
  CarManager.runtimeSuspensionReason }
rootCallbacks.session()
simState.isLive, simState.isPaused, simState.isReplayActive = false, true, false
rootUpdate(.5)
simState.isLive, simState.isPaused = true, false
rootUpdate(.5)
for i = 1, 200 do Logger.observe('incident-context-overwrite', nil, nil, i, nil, 'live-context') end
Logger.observe('incident-live-survivor', nil, nil, nil, nil, 'captured-before-pause')
simState.isLive, simState.isPaused = false, true
rootUpdate(.5)
for i = 1, 60 do Logger.observe('incident-context-overwrite', nil, nil, 1000 + i, nil, 'pause-context') end
local retainedContext = snapshot()
local foundOriginalLiveTransition, foundLiveSurvivor, foundPauseContext = false, false, false
for i = 1, retainedContext.count do
  local record = retainedContext.records[i]
  if record.kind == 'lifecycle-context' and record.detail == 'live' then foundOriginalLiveTransition = true end
  if record.kind == 'incident-live-survivor' then
    foundLiveSurvivor = record.context == 'live' and record.runtimeEnabled == true
      and record.runtimePaused == false and record.runtimeLive == true
  end
  if record.kind == 'lifecycle-context' and record.detail == 'pause' then
    foundPauseContext = record.context == 'pause' and record.runtimeEnabled == true
      and record.runtimePaused == true and record.runtimeLive == false
  end
end
assert(retainedContext.count == 256 and not foundOriginalLiveTransition and foundLiveSurvivor and foundPauseContext,
  'ring overwrite removes original transition while surviving records retain their captured context and flags')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive, CarManager.runtimeSuspensionReason = nil, false, false, nil
assert(Logger.observe('incident-context-unknown', nil, nil, nil, nil, 'missing-runtime-context'))
local unknownContext
local unknownSnapshot = snapshot()
for i = 1, unknownSnapshot.count do
  local record = unknownSnapshot.records[i]
  if record.kind == 'incident-context-unknown' then unknownContext = record end
end
assert(unknownContext and unknownContext.context == 'UNKNOWN' and unknownContext.runtimeEnabled == 'UNKNOWN'
  and unknownContext.runtimePaused == false and unknownContext.runtimeLive == false,
  'absent context fields remain UNKNOWN while explicit false booleans are preserved')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive, CarManager.runtimeSuspensionReason =
  savedContext[1], savedContext[2], savedContext[3], savedContext[4]
simState.isLive, simState.isPaused, simState.isReplayActive = true, false, false
storage.enabled = true
ac.onCarCollision, ac.onCarJumped, ac.onCarSwap, ac.onSessionStart, ac.iterateCars =
  savedAcMethods.onCarCollision, savedAcMethods.onCarJumped, savedAcMethods.onCarSwap,
  savedAcMethods.onSessionStart, savedAcMethods.iterateCars
StorageManager.getStorage_Global = oldGlobalStorage
storage.enabled = nil
package.path = originalPackagePath
-- Separate true generations ensure formatter and sink faults independently reach their probes.
local savedFormat = string.format
local oldSink = ac.log
Logger.OBS1_FOCUS_CAR = 24
CarManager.resetSession()
Logger.observe('fresh-format-probe', 24)
string.format = function() error('injected OBS envelope formatter failure') end
local formatProbe = Logger.observe('formatter-only-probe', 24, 9)
string.format = savedFormat
assert(formatProbe == true and Logger.getOBS1Stats().formatFailures > 0,
  'format failure is counted while ring recording remains successful')
CarManager.resetSession()
Logger.observe('fresh-sink-probe', 24)
local sinkAttemptsBefore = #output
ac.log = function(line) output[#output + 1] = line; error('injected OBS sink failure after possible write') end
assert(Logger.observe('sink-only-probe', 24, 9))
ac.log = oldSink
local failedDelivery = Logger.getOBS1Stats()
assert(#output > sinkAttemptsBefore and failedDelivery.sinkThrewUncertain == 1
  and failedDelivery.sinkReturned == 2 and failedDelivery.attempts == 3,
  'sink throw after side effect is uncertain, not confirmed, and attempt is charged')
CarManager.resetSession()
Logger.observe('fresh-unavailable-probe', 24)
local beforeUnavailable = Logger.getOBS1Stats()
ac.log = nil
assert(Logger.observe('unavailable-sink-probe', 24, 9), 'accepted ring record is not represented as delivered')
local unavailableStats = Logger.getOBS1Stats()
assert(unavailableStats.attempts == beforeUnavailable.attempts + 1
  and unavailableStats.sinkUnavailable == beforeUnavailable.sinkUnavailable + 1
  and unavailableStats.sinkReturned == beforeUnavailable.sinkReturned,
  'absent ac.log charges one attempt and records unavailable delivery separately')
ac.log = oldSink
assert(Logger.observe('restored-sink-probe', 24, 10))
local restoredSinkStats = Logger.getOBS1Stats()
assert(restoredSinkStats.attempts == beforeUnavailable.attempts + 2
  and restoredSinkStats.sinkReturned == beforeUnavailable.sinkReturned + 1
  and restoredSinkStats.sinkUnavailable == unavailableStats.sinkUnavailable,
  'restored sink resumes bounded attempts and returned counter without claiming past delivery')

-- Stale queued identity is discarded; generation/session changes do not adopt old context.
local staleEvents = {}
OnCarEventManager.OnCarEventExecutions[OnCarEventManager.OnCarEventType.Jumped] = function() staleEvents[#staleEvents+1] = 'dispatch' end
assert(OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Jumped, 8))
local queuedStaleGeneration = CarManager.getCarGeneration(8)
CarManager.bumpCarGeneration(8)
OnCarEventManager.processQueuedEvents()
assert(#staleEvents == 0 and hasEvent('queue-stale', 8), 'recycled identity is marked stale, not current')
local staleRecord
local staleSnapshot = snapshot()
for i = 1, staleSnapshot.count do
  local record = Logger.getOBS1Record(i)
  if record.kind == 'queue-stale' and record.car == 8 then staleRecord = record end
end
assert(staleRecord and staleRecord.generation == queuedStaleGeneration
  and staleRecord.generation ~= CarManager.getCarGeneration(8), 'stale event retains old generation, not current identity')
local oldQueueSession = CarManager.sessionGeneration
assert(OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Jumped, 8))
CarManager.resetSession()
OnCarEventManager.processQueuedEvents()
local staleAcrossSession
local afterSessionStale = snapshot()
for i = 1, afterSessionStale.count do
  local record = afterSessionStale.records[i]
  if record.kind == 'queue-stale' and record.car == 8 then staleAcrossSession = record end
end
assert(staleAcrossSession and staleAcrossSession.referenceSession == oldQueueSession
  and staleAcrossSession.session ~= oldQueueSession,
  'same-module stale queue record keeps its old reference session, never current identity')
for i = 1, 256 do
  assert(OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Collision,
    9, position, 11, cars[9], cars[10]))
end
assert(not OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Collision,
  9, position, 11, cars[9], cars[10]) and hasEvent('queue-overflow'), 'bounded FIFO reports overflow')
OnCarEventManager.clear()
AccidentManager.registerCollision(-1, position, 1)
assert(hasEvent('incident-rejected'), 'real manager records a known rejected incident guard')
local priorCapture = Logger.getOBS1Stats().capture
CarManager.resetSession()
Logger.observe('session-start', 24, CarManager.getCarGeneration(24))
local second = snapshot()
assert(second.capture == priorCapture + 1 and second.count == 1 and second.records[1].kind == 'session-start',
  'true generation change resets capture on same module instance')
local capture = second.capture
CarManager.suspendLifecycle()
Logger.observe('suspend-not-session', 24, nil)
CarManager.bumpCarGeneration(24)
Logger.observe('lifecycle-context', nil, nil, nil, nil, 'pause/replay/disable/swap-context')
assert(snapshot().capture == capture, 'suspend does not renew session budgets')

-- Two independent real incidents create overlapping zones; resolving one leaves the other registered.
local completionSentinel = {}
local sentinelIncident = assert(AccidentManager.registerCollision(16, vec(0, 0, 0), 18))
local sentinelZone = AccidentManager.accidents_yellowFlagZoneIndex[sentinelIncident]
local savedZoneRemoval = RaceTrackManager.removeYellowFlagZone
RaceTrackManager.removeYellowFlagZone = function() error(completionSentinel) end
local resolveOK, resolveError = pcall(AccidentManager.informAboutCarReset, 16)
RaceTrackManager.removeYellowFlagZone = savedZoneRemoval
assert(not resolveOK and resolveError == completionSentinel
  and AccidentManager.accidents_resolved[sentinelIncident] == false,
  'zone-removal failure propagates and leaves incident unresolved')
local falseIncidentCompletion = false
local failedResolveSnapshot = snapshot()
for i = 1, failedResolveSnapshot.count do
  local record = failedResolveSnapshot.records[i]
  if record.kind == 'incident-resolved' and record.incident == sentinelIncident then falseIncidentCompletion = true end
end
assert(not falseIncidentCompletion, 'failed incident cleanup emits no incident-resolved completion')
local savedIndexUpdate = CompletableIndexCollectionManager.updateFirstNonResolvedIndex
local beforeZoneFailure = snapshot()
CompletableIndexCollectionManager.updateFirstNonResolvedIndex = function() error(completionSentinel) end
local zoneOK, zoneError = pcall(RaceTrackManager.removeYellowFlagZone, sentinelZone)
CompletableIndexCollectionManager.updateFirstNonResolvedIndex = savedIndexUpdate
assert(not zoneOK and zoneError == completionSentinel, 'zone index-update failure propagates unchanged')
local zoneCompletionFabricated = false
local afterZoneFailure = snapshot()
for i = 1, afterZoneFailure.count do
  local record = afterZoneFailure.records[i]
  if record.kind == 'zone-removed' and record.zone == sentinelZone then zoneCompletionFabricated = true end
end
assert(not zoneCompletionFabricated and beforeZoneFailure.count <= afterZoneFailure.count,
  'failed zone removal does not emit a completion event')
AccidentManager.resetSession()
assert(hasEvent('incident-resolved') and hasEvent('zone-reset'), 'session reset correlates incident resolution and zone reset')
local oldIncidentCleanupUnknown = false
local cleanupSnapshot = snapshot()
for i = 1, cleanupSnapshot.count do
  local record = cleanupSnapshot.records[i]
  if record.kind == 'incident-resolved' and record.incident ~= 'UNKNOWN' then
    if record.referenceSession == 'UNKNOWN' then oldIncidentCleanupUnknown = true end
  end
end
assert(oldIncidentCleanupUnknown, 'legacy incident cleanup IDs carry explicit unknown origin-session provenance')
cars[10].splinePosition, cars[11].splinePosition = .500, .502
cars[12].splinePosition, cars[13].splinePosition = .501, .503
local incidentA = assert(AccidentManager.registerCollision(10, vec(0, 0, 0), 12))
local incidentB = assert(AccidentManager.registerCollision(12, vec(0, 0, 0), 14))
local zoneA, zoneB = AccidentManager.accidents_yellowFlagZoneIndex[incidentA], AccidentManager.accidents_yellowFlagZoneIndex[incidentB]
assert(zoneA ~= zoneB and RaceTrackManager.isSplinePositionInYellowZone(.49), 'real zone records overlap')
AccidentManager.informAboutCarReset(10)
assert(AccidentManager.accidents_resolved[incidentA] and AccidentManager.accidents_resolved[incidentB] == false
  and RaceTrackManager.isSplinePositionInYellowZone(.49), 'resolving one overlap preserves the independent zone')
assert(hasEvent('incident-resolved') and hasEvent('zone-removed'), 'logical incident resolution is correlated to zone removal')
assert(RaceTrackManager.removeYellowFlagZone(zoneA) == false, 'zone removal is idempotent')

-- Fixed ring/detail/output/byte caps and bounded scalar storage under many arbitrary IDs.
-- Detail-limit markers use the normal attempt path and cannot steal the reserved global-truncation slot.
CarManager.resetSession()
table.clear(output)
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 7
for i = 1, 48 do Logger.observe('ordinary-transition', 7, i, nil, nil, 'detail-limit-fill') end
for i = 1, 110 do Logger.observe('incident-created', nil, nil, 3000 + i, nil, 'essential-limit-fill') end
local beforeLastDetail = Logger.getOBS1Stats()
assert(beforeLastDetail.attempts == 159, 'header plus 48 details plus 110 essentials exactly fill 159 normal attempts')
assert(Logger.observe('ordinary-transition', 7, 49, nil, nil, 'detail-limit-trigger'))
local reservedMarker = Logger.getOBS1Stats()
assert(reservedMarker.attempts == 160 and reservedMarker.outputSaturated,
  'detail-limit trigger cannot claim a reserved attempt ahead of global truncation')
local beforeEssentialAfterCap = #output
assert(Logger.observe('incident-created', nil, nil, 99999, nil, 'essential-after-final-cap'))
assert(#output == beforeEssentialAfterCap and not output[#output]:find('essential-after-final-cap', 1, true)
  and output[#output]:find('global output truncated', 1, true),
  'the final attempted line is global truncation; later essentials are charged but not emitted')
for i = 1, #output do assert(#output[i] <= 384, 'reserved marker scenario full envelope stays within byte cap') end
assert(reservedMarker.bytesAttempted <= 61440 and reservedMarker.attempts <= 160,
  'reserved marker scenario respects complete envelope and total-attempt budgets')

CarManager.resetSession()
table.clear(output)
Logger.OBS1_FOCUS_CAR = 29
for i = 1, 64 do Logger.observe('ordinary-transition', 29, i, nil, nil, string.rep('x', 10000)) end
for i = 65, 80 do Logger.observe('ordinary-transition', 29, i, nil, nil, 'admission-overflow') end
Logger.observe('incident-created', nil, nil, 900, 901, 'essential-after-detail-cap')
local afterDetailQuota = Logger.getOBS1Stats()
local essentialAfterDetail = false
for i = 1, #output do if output[i]:find('essential-after-detail-cap', 1, true) then essentialAfterDetail = true end end
assert(afterDetailQuota.details == 64 and afterDetailQuota.detailLines == 48
  and afterDetailQuota.detailAdmissionDrops == 16 and afterDetailQuota.detailOutputDrops == 16
  and afterDetailQuota.detailOutputLimited and essentialAfterDetail,
  'detail output/admission quotas are independent and do not filter essential events')
for i = 1, 400 do Logger.observe('incident-created', nil, nil, i, i, 'global') end
local saturated = snapshot()
assert(saturated.count == 256 and saturated.overwrites > 0 and saturated.details == 64
  and saturated.attempts == 160 and saturated.detailLines <= 48 and saturated.bytesAttempted <= 61440,
  'ring, independent detail and global attempt/byte budgets remain bounded')
local observedLineCount, observedByteCount = 0, 0
local sawGlobalLossMarker = false
for i = 1, #output do
  if output[i]:find('[OBS1]', 1, true) then
    observedLineCount, observedByteCount = observedLineCount + 1, observedByteCount + #output[i]
    if output[i]:find('global output truncated', 1, true) then sawGlobalLossMarker = true end
    assert(#output[i] <= 384, 'each attempted full envelope is byte-bounded')
  end
end
assert(observedLineCount == saturated.attempts and observedByteCount == saturated.bytesAttempted
  and saturated.sinkReturned + saturated.sinkThrewUncertain + saturated.sinkUnavailable == saturated.attempts,
  'all OBS sink attempts, including loss markers, are charged and delivery accounting reconciles')
assert(saturated.outputSaturated and saturated.globalOutputDrops > 0 and saturated.lossMarkers >= 2
  and sawGlobalLossMarker, 'global output saturation and losses have an attempted explicit marker')
local oldest = Logger.getOBS1Record(1)
local newest = Logger.getOBS1Record(saturated.count)
assert(oldest.sequence == newest.sequence - 255, 'ring returns surviving records in sequence order')
local attemptCountBefore = #output
for i = 1, 1000 do Logger.observe('incident-created', nil, nil, 1000 + i, 2000 + i, 'after-cap') end
assert(#output == attemptCountBefore and Logger.getOBS1Stats().attempts == saturated.attempts,
  'saturated output prevents unbounded sink retries')
local beforeFocusChurn = Logger.getOBS1Stats()
for i = 1, 2000 do
  Logger.OBS1_FOCUS_CAR = i
  Logger.observe('ordinary-transition', i, i, nil, nil, 'bounded-focus-churn')
end
assert(Logger.getOBS1Stats().count == beforeFocusChurn.count
  and Logger.getOBS1Stats().details == beforeFocusChurn.details
  and Logger.getOBS1Stats().attempts == beforeFocusChurn.attempts,
  'thousands of distinct IDs/focus changes use fixed scalar bookkeeping after admission saturation')
Logger.OBS1_ENABLED = false
local beforeDisabled = Logger.getOBS1Stats().count
for i = 1, 1000 do
  Logger.OBS1_FOCUS_CAR = i
  Logger.observe('disabled-churn', i, i)
end
assert(Logger.getOBS1Stats().count == beforeDisabled and Logger.getOBS1Stats().attempts == saturated.attempts,
  'disabled fast path preserves capture budgets')

-- The public query scans at most the private 256-record ring and returns only the latest eight matches.
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = true, 24
CarManager.resetSession()
for i = 1, 300 do
  local carIndex = i % 3 == 1 and 24 or (i % 3 == 0 and 0 or 7)
  local referenceSession = carIndex == 24 and i % 2 == 0 and ('old-session-' .. tostring(i)) or nil
  assert(Logger.observe('incident-query-ring', carIndex, 10000 + i, i, i + 1,
    'interleaved-' .. tostring(i), nil, referenceSession))
end
local recent24 = Logger.getOBS1RecentForCar(24)
assert(recent24 and recent24.car == 24 and recent24.scanned == 256 and recent24.matchingCount == 85
  and recent24.limited == true and #recent24.records == 8,
  'query counts all matches in the retained ring while returning at most eight')
for i = 1, #recent24.records do
  local record = recent24.records[i]
  assert(record.car == 24 and record.sequence == 277 + (i - 1) * 3,
    'latest-eight query records are exact selected-car matches in chronological order')
end
assert(recent24.records[1].referenceSession == 'UNKNOWN'
  and recent24.records[2].referenceSession == 'old-session-280'
  and recent24.records[8].generation == 10298,
  'query preserves stored old reference-session and generation values without relabeling')
local recentZero = Logger.getOBS1RecentForCar(0)
local recentEmpty = Logger.getOBS1RecentForCar(5)
assert(recentZero and recentZero.matchingCount > 0 and recentEmpty and recentEmpty.matchingCount == 0
  and #recentEmpty.records == 0 and recentEmpty.scanned == 256 and not recentEmpty.limited,
  'zero is a valid car index and an unassociated selected car returns an empty bounded result')
Logger.OBS1_ENABLED = false
local beforeRecentDisabled = loggerState()
assert(Logger.getOBS1RecentForCar(24).matchingCount == 85, 'disabled query reads retained historic matches')
assertLoggerStateUnchanged(beforeRecentDisabled, 'disabled full-ring query')
Logger.OBS1_ENABLED = true

-- OBS3 stays passive, samples only configured cars, and keeps session/window quotas fixed.
CarManager.resetSession()
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
simState.isLive, simState.isPaused, simState.isReplayActive, simState.isSessionStarted = true, false, false, true
Logger.OBS1_ENABLED, Logger.OBS3_ENABLED = true, false
Logger.OBS3_TARGET_CAR, Logger.OBS3_PEER_CAR_1, Logger.OBS3_PEER_CAR_2 = 24, 25, 26
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 0, 'OBS3 default-off performs no sample collection')
Logger.OBS3_ENABLED = true
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 1, 'enabled OBS3 samples configured target and peers')
local firstOBS3 = Logger.getOBS3Frame(1)
assert(firstOBS3 and firstOBS3.slots[1].valid and firstOBS3.slots[1].positionX == cars[24].position.x
  and firstOBS3.slots[2].valid and firstOBS3.slots[3].valid
  and firstOBS3.slots[1].isInPit == false and firstOBS3.slots[1].isInPitlane == false,
  'frame stores three configured cars and preserves known false pit flags')
local expectedState24 = CarStateMachine.getCurrentState(24)
assert(firstOBS3.slots[1].state == (expectedState24 == nil and 'UNKNOWN' or expectedState24),
  'OBS3 reads the existing FSM getCurrentState source, or marks it unknown')
firstOBS3.slots[1].positionX = -100
assert(Logger.getOBS3Frame(1).slots[1].positionX ~= -100, 'OBS3 frame getter returns independent copies')
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 1, 'same-clock tick does not burst/catch up above 20 Hz')
simState.isPaused, CarManager.runtimePaused, CarManager.runtimeLive = true, true, false
Logger.tickOBS3(.05)
simState.isPaused, CarManager.runtimePaused, CarManager.runtimeLive = false, false, true
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 1, 'pause/resume at unchanged active time does not bypass the rate limiter')
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 2 and Logger.getOBS3Frame(2).discontinuity,
  'pause preserves the window and marks its first resumed frame discontinuous')
Logger.invalidateOBS3('test-jump')
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().windowsStarted == 2, 'jump invalidates a window without renewing its session quota')
local savedCar24 = cars[24]
local framesBeforeMissingTarget = Logger.getOBS3Stats().frames
cars[24] = nil
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
cars[24] = savedCar24
assert(Logger.getOBS3Stats().frames == framesBeforeMissingTarget and not Logger.getOBS3Stats().active
  and Logger.getOBS3Stats().missingTarget > 0, 'missing target invalidates the window without committing a partial frame')
Logger.OBS3_TARGET_CAR = 0 / 0
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(not Logger.getOBS3Stats().active, 'NaN target invalidates capture without collection')
Logger.OBS3_ENABLED, Logger.OBS3_TARGET_CAR = true, 24
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
local savedPeer26 = cars[26]
cars[26] = nil
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
cars[26] = savedPeer26
assert(Logger.getOBS3Frame(5).slots[3].carIndex == 26 and not Logger.getOBS3Frame(5).slots[3].valid,
  'configured missing peer remains an explicitly invalid slot')
local framesBeforeGenerationChange = Logger.getOBS3Stats().frames
CarManager.bumpCarGeneration(24)
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == framesBeforeGenerationChange and not Logger.getOBS3Stats().active,
  'car-generation change abandons the current window without storing mixed identities')
local savedClock = GameTimeManager.getPlayingGameTime
GameTimeManager.getPlayingGameTime = function() return 0 / 0 end
Logger.tickOBS3(.05)
assert(not Logger.getOBS3Stats().active, 'invalid active clock abandons capture safely')
GameTimeManager.getPlayingGameTime = savedClock
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
Logger.OBS3_ENABLED = false
Logger.tickOBS3(.05)
local windowsBeforeToggleReturn = Logger.getOBS3Stats().windowsStarted
Logger.OBS3_ENABLED = true
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().windowsStarted == windowsBeforeToggleReturn + 1,
  'disable/return abandons but never renews or hides the existing session quota')
for window = 3, 8 do
  for frame = 1, 200 do GameTimeManager.update(.05); Logger.tickOBS3(.05) end
end
local obs3Capped = Logger.getOBS3Stats()
assert(obs3Capped.windowsStarted == 8 and obs3Capped.frames <= 1600,
  'only eight windows/1600 frames can be captured in one real session')
local beforeOBS3Read = Logger.getOBS3Stats()
Logger.getOBS3Frame(1); Logger.getOBS3Stats()
assert(Logger.getOBS3Stats().frames == beforeOBS3Read.frames
  and Logger.getOBS3Stats().windowsStarted == beforeOBS3Read.windowsStarted,
  'read-only OBS3 getters do not renew windows or quotas')
CarManager.resetSession()
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().windowsStarted == 1 and Logger.getOBS3Stats().frames == 1,
  'only a real CarManager session-generation change resets the OBS3 budget')
local firstWindow = Logger.getOBS3Frame(1).window
GameTimeManager.update(11)
Logger.tickOBS3(11)
local afterHitch = Logger.getOBS3Stats()
assert(afterHitch.frames == 2 and afterHitch.windowsStarted == 2
  and Logger.getOBS3Frame(2).window ~= firstWindow and Logger.getOBS3Frame(2).discontinuity,
  '11-second late tick closes the old window before capture and rearms once without catch-up')
local sawQuantifiedWindowSummary = false
for i = 1, Logger.getOBS1Stats().count do
  local record = Logger.getOBS1Record(i)
  if record.kind == 'obs3-window-summary' and record.detail:find('w1 f1 time', 1, true) then
    sawQuantifiedWindowSummary = true
  end
end
assert(sawQuantifiedWindowSummary, 'window summary includes bounded window index, frame count and closure reason')
local beforeLongHitchWindow = Logger.getOBS3Frame(2).window
GameTimeManager.update(20)
Logger.tickOBS3(20)
assert(Logger.getOBS3Stats().frames == 3 and Logger.getOBS3Stats().windowsStarted == 3
  and Logger.getOBS3Frame(3).window ~= beforeLongHitchWindow,
  '20-second hitch also closes before capture without filling/catching up the expired window')
GameTimeManager.update(10)
Logger.tickOBS3(10)
assert(Logger.getOBS3Stats().windowsStarted == 4 and Logger.getOBS3Stats().frames == 4
  and Logger.getOBS3Frame(4).window == 4,
  'exact ten-second boundary closes before sampling and begins no catch-up frame in the old window')
local savedGetSim = ac.getSim
local ffi = require('ffi')
local SimSnapshot = ffi.typeof('struct { bool isPaused; bool isReplayActive; bool isSessionStarted; bool isLive; }')
local cdataSim = SimSnapshot(false, false, true, true)
ac.getSim = function() return cdataSim end
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().active, 'OBS3 reads documented simulation context fields from LuaJIT FFI cdata')
local simFields = { isPaused = false, isReplayActive = false, isSessionStarted = true, isLive = true }
ac.getSim = function() return setmetatable({}, { __index = simFields }) end
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().active, 'OBS3 accepts protected metatable-backed simulation context')
ac.getSim = function() error('injected getSim failure') end
Logger.tickOBS3(.05)
assert(not Logger.getOBS3Stats().active, 'getSim fault closes the window rather than retaining stale active context')
ac.getSim = savedGetSim
GameTimeManager.update(.05)
Logger.tickOBS3(.05)
local savedGetCar, framesBeforeCarFault = ac.getCar, Logger.getOBS3Stats().frames
ac.getCar = function(index) if index == 24 then error('injected getCar failure') end return savedGetCar(index) end
GameTimeManager.update(.06)
Logger.tickOBS3(.05)
ac.getCar = savedGetCar
assert(Logger.getOBS3Stats().frames == framesBeforeCarFault and not Logger.getOBS3Stats().active,
  'getCar target fault does not publish a partial/stale frame or keep the window active: frames='
    .. tostring(Logger.getOBS3Stats().frames) .. '/' .. tostring(framesBeforeCarFault)
    .. ' active=' .. tostring(Logger.getOBS3Stats().active))

-- Fresh real session generations isolate getter-contract probes from the eight-window cap.
local savedAc, savedGetCar = ac, ac.getCar
local savedOBS1, savedOBS3 = Logger.OBS1_ENABLED, Logger.OBS3_ENABLED
local savedTarget, savedPeer1, savedPeer2 = Logger.OBS3_TARGET_CAR, Logger.OBS3_PEER_CAR_1, Logger.OBS3_PEER_CAR_2
local function resetGetterProbe()
  ac = savedAc
  savedAc.getCar = savedGetCar
  CarManager.resetSession()
  CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
  simState.isLive, simState.isPaused, simState.isReplayActive, simState.isSessionStarted = true, false, false, true
  Logger.OBS1_ENABLED, Logger.OBS3_ENABLED = true, true
  Logger.OBS3_TARGET_CAR, Logger.OBS3_PEER_CAR_1, Logger.OBS3_PEER_CAR_2 = 24, 25, 26
end
resetGetterProbe()
local calledCars = {}
local callableGetter = setmetatable({}, { __call = function(_, index)
  calledCars[index] = (calledCars[index] or 0) + 1
  return cars[index]
end })
savedAc.getCar = callableGetter
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 1 and calledCars[24] == 1 and calledCars[25] == 1 and calledCars[26] == 1
  and not calledCars[0] and not calledCars[27],
  'callable-table getter captures exactly the configured target and two peers')

resetGetterProbe()
local proxyAc = setmetatable({ getSim = savedAc.getSim, log = savedAc.log }, { __index = function(_, key)
  if key == 'getCar' then return savedGetCar end
  return rawget(savedAc, key)
end })
ac = proxyAc
Logger.tickOBS3(.05)
assert(Logger.getOBS3Stats().frames == 1, 'ac.getCar supplied through ac-table __index is honored: frames='
  .. tostring(Logger.getOBS3Stats().frames) .. ' active=' .. tostring(Logger.getOBS3Stats().active)
  .. ' abandoned=' .. tostring(Logger.getOBS3Stats().abandoned))

local function assertGetterFault(label, badGetter, proxy)
  resetGetterProbe()
  if proxy then ac = proxy else savedAc.getCar = badGetter end
  Logger.tickOBS3(.05)
  local failed = Logger.getOBS3Stats()
  assert(failed.frames == 0 and failed.windowsStarted == 1 and failed.abandoned == 1 and not failed.active,
    label .. ': fault abandons without a stale/partial frame')
  ac = savedAc
  savedAc.getCar = savedGetCar
  GameTimeManager.update(.06)
  Logger.tickOBS3(.05)
  local recovered = Logger.getOBS3Stats()
  assert(recovered.frames == 1 and recovered.windowsStarted == 2,
    label .. ': recovery starts a later window without renewing session quota')
end
assertGetterFault('nil getter', nil)
assertGetterFault('non-callable getter', 17)
assertGetterFault('throwing getter', function() error('injected getCar failure') end)
assertGetterFault('throwing ac.__index', nil, setmetatable({ getSim = savedAc.getSim, log = savedAc.log }, { __index = function(_, key)
  if key == 'getCar' then error('injected ac __index failure') end
  return rawget(savedAc, key)
end }))
ac = savedAc
savedAc.getCar = savedGetCar
Logger.OBS1_ENABLED, Logger.OBS3_ENABLED = savedOBS1, savedOBS3
Logger.OBS3_TARGET_CAR, Logger.OBS3_PEER_CAR_1, Logger.OBS3_PEER_CAR_2 = savedTarget, savedPeer1, savedPeer2

print('test_observability: PASS (real Logger/managers, correlation, failure isolation, identity and budgets)')
