-- Headless read-only contract for the opt-in ownership inspection panel.
package.path = './?.lua;./?/init.lua;' .. package.path
table.clear = table.clear or function(value) for key in pairs(value) do value[key] = nil end end

local checks = 0
local function check(ok, message)
  checks = checks + 1
  if not ok then error('FAIL: ' .. message, 2) end
end

local sim = { isLive = true, isReplayActive = false, isSessionStarted = true, isPaused = false, carsCount = 2 }
local cars = {
  [0] = { index = 0, isAIControlled = false, isConnected = true, isActive = true },
  [1] = { index = 1, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 80, splinePosition = 0.16 },
  [2] = { index = 2, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 60 },
}
local allowed = true
local writes = 0
ac = { getSim = function() return sim end, getCar = function(index) return cars[index] end }
physics = { allowed = function() return allowed end,
  setAITopSpeed = function() writes = writes + 1 end,
  setAIThrottleLimit = function() writes = writes + 1 end }
GameTimeManager = { now = 12, getPlayingGameTime = function() return GameTimeManager.now end }
StorageManager = { getStorage = function() return { globalTopSpeedLimitKmh = 0 } end,
  getStorage_UI = function() return { uiLanguage = 'en' } end,
  getStorage_Overtaking = function() return {} end, getStorage_Yielding = function() return {} end,
  getStorage_AICarValues = function() return {} end }
MathHelpers = { approach = function(value) return value end, vsub = function() end, dot = function() end }
local diagnosticQueries, zoneQueries = 0, 0
local zoneFixtures = {}
Logger = { error = function() end, log = function() end, warn = function() end,
  OBS1_ENABLED = true, OBS1_FOCUS_CAR = 1,
  getOBS1RecentForCar = function(index)
    diagnosticQueries = diagnosticQueries + 1
    local records = {}
    for i = 1, 8 do records[i] = { car = index, sequence = i, activeTime = i, activeTimeValid = true, kind = 'fsm-changed',
      incident = nil, zone = nil, detail = 'state update', referenceSession = 1, generation = 1 } end
    return { car = index, records = records, stats = { drops = 0, overwrites = 0 }, matchingCount = 10, scanned = 12, limited = true }
  end }
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
render = { createRay = function() end }
VecPool = { getTempVec3 = function() end }
vec3 = function() return { set = function() end } end
RaceTrackManager = { TrackSide = { LEFT = 1, RIGHT = 2 }, getYellowZoneReadOnly = function(id)
  zoneQueries = zoneQueries + 1
  return zoneFixtures[id] or { zone = id, incident = 1, startSplinePosition = 0.1, endSplinePosition = 0.2, resolved = false }
end }
local inventoryCalls, coverageCalls, zoneDecisionCalls, inventoryCursors = 0, 0, 0, {}
RaceTrackManager.getYellowZoneInventoryReadOnly = function(cursor, epoch, revision)
  inventoryCalls = inventoryCalls + 1
  inventoryCursors[#inventoryCursors + 1] = cursor == nil and '<first>' or cursor
  return { zones = { { zone = 21, incident = 11, startSplinePosition = .12, endSplinePosition = .25 } },
    cursor = cursor, nextCursor = 33, scanned = 32, complete = false, epoch = 1, revision = 2, session = 1 }
end
RaceTrackManager.getYellowZoneCoverageReadOnly = function(position)
  coverageCalls = coverageCalls + 1
  return { zones = { { zone = 21 } }, candidates = { { zone = 21 } }, scanned = 1, total = 1, limited = false, covered = true, epoch = 1, revision = 2, session = CarManager.sessionGeneration }
end
RaceTrackManager.getYellowZoneDecisionReadOnly = function(index)
  zoneDecisionCalls = zoneDecisionCalls + 1
  return { car = index, session = CarManager.sessionGeneration, generation = CarManager.getCarGeneration(index), candidates = { { zone = 21, incident = 11 } }, examined = 1, limited = false,
    chosenZone = 21, matched = true, sequence = 4, consumer = 'fsm-handle-yellow', stateReturned = 'DrivingInYellowFlagZone' }
end
RaceTrackManager.getYieldingSide = function() return 1 end
RaceTrackManager.getOvertakingSide = function() return 2 end
RaceTrackManager.getLateralOffsetSign = function() return 1 end
RaceTrackManager.getOppositeSide = function() return 2 end
CarStateMachine = { getCurrentState = function(index) return index == 1 and 'DrivingInYellowFlagZone' or 'DrivingNormally' end,
  getPreviousState = function(index) return index == 1 and 'NavigatingAroundAccident' or 'DrivingNormally' end,
  getPendingReadOnly = function(index) return { car = index, pending = nil, valid = false,
    session = CarManager.sessionGeneration, currentGeneration = CarManager.getCarGeneration(index) } end }
CarManager = dofile('CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
local accidentNavigationOnly = false
AccidentManager = { getAccidentDecisionReadOnly = function(index)
  local generation = CarManager.getCarGeneration(index)
  local navigation = { session = CarManager.sessionGeneration, generation = generation,
    assignedIncident = 44, assignedCar = 2, assignmentOrigin = 'UNKNOWN', matchesQuery = false }
  if not accidentNavigationOnly then
    navigation.comparedIncident, navigation.comparedCar, navigation.querySequence = 44, 2, 9
  end
  return { car = index, session = CarManager.sessionGeneration, generation = CarManager.getCarGeneration(index),
    query = not accidentNavigationOnly and { session = CarManager.sessionGeneration, generation = generation,
      candidates = { { incident = 44, reason = 'within-range' } }, examined = 1, limited = false,
      chosenIncident = 44, chosenCar = 2, sequence = 9, source = 'actual-query' } or nil,
    navigation = navigation }
end }
local operations = dofile('CarOperations.lua')
CarOperations = operations

local cameraCalls, storageWrites, raycasts = 0, 0, 0
CameraManager = { setFocusedCarIndex = function() cameraCalls = cameraCalls + 1 end }
ac.setCameraMode = function() cameraCalls = cameraCalls + 1 end
ac.storage = function() storageWrites = storageWrites + 1; error('unexpected storage write') end
render.createRay = function() raycasts = raycasts + 1; error('unexpected raycast') end

assert(operations.requestAITopSpeed(1, 90, 'TRAFFIC_YIELD'))
assert(operations.requestAITopSpeed(1, 70, 'YELLOW_FLAG'))
assert(operations.requestAIThrottleLimit(1, .4, 'TRAFFIC_YIELD'))
assert(operations.resolveOwnedAIControls(0))
-- Keep the last successful throttle setter record after owner release. The
-- panel may report this inferred neutral, but cannot claim physical readback.
assert(operations.releaseAIThrottleLimit(1, 'TRAFFIC_YIELD'))
-- Create a pending neutral and an expired request to cover distinct ownership states.
assert(operations.releaseAITopSpeed(1, 'YELLOW_FLAG'))
GameTimeManager.now = 14
assert(operations.requestAITopSpeed(1, 50, 'INCIDENT_STOP'))
GameTimeManager.now = 16
assert(operations.requestAITopSpeed(1, 20, 'COMPAT'))
operations._topSpeedRequests[1].byOwner.TRAFFIC_YIELD.sessionGeneration = CarManager.sessionGeneration - 1

for _, name in ipairs({ 'requestAITopSpeed', 'releaseAITopSpeed', 'requestAIThrottleLimit',
  'releaseAIThrottleLimit', 'clearOwnedControlsForCar', 'clearAllOwnedControls', 'resolveOwnedAIControls' }) do
  operations[name] = function() error('debug panel attempted ownership mutation: ' .. name) end
end
for _, name in ipairs({ 'ensureDefaults', 'setCalculatedTrackLateralOffset' }) do
  CarManager[name] = function() error('debug panel attempted CarManager mutation: ' .. name) end
end

local state = { calls = {}, selection = 1, nextPageClick = false }
state.uiTime = 1
ui = {
  time = function() return state.uiTime end,
  ComboFlags = { None = 0 },
  separator = function() state.calls[#state.calls + 1] = { 'separator' } end,
  textWrapped = function(value) state.calls[#state.calls + 1] = { 'text', value } end,
  combo = function(label, selected, _, choices)
    state.calls[#state.calls + 1] = { 'combo', label, selected, choices }
    if state.selection then local next = state.selection; state.selection = nil; return next, true end
    return selected, false
  end,
  button = function() local clicked = state.nextPageClick; state.nextPageClick = false; return clicked end,
}
local localization = require('Localization')
local ControlDebugPanel = require('ControlDebugPanel')

local function snapshot(value, seen)
  if type(value) ~= 'table' then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do result[snapshot(key, seen)] = snapshot(child, seen) end
  return result
end
local function equal(a, b, seen)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for key, value in pairs(a) do if not equal(value, b[key], seen) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end
local ownership = { operations._topSpeedRequests, operations._throttleRequests,
  operations._topSpeedWinner, operations._throttleWinner, operations._topSpeedApplied,
  operations._throttleApplied, operations._topSpeedAttempted, operations._throttleAttempted }
local beforeOwnership = snapshot(ownership)
local function collectTableRefs(value, result)
  if type(value) ~= 'table' or result[value] then return end
  result[value] = true
  for key, child in pairs(value) do
    collectTableRefs(key, result)
    collectTableRefs(child, result)
  end
end
local beforeRefs = {}
collectTableRefs(ownership, beforeRefs)
local refs = {}
for i, tableRef in ipairs(ownership) do refs[i] = tableRef end
local beforeGenerations = snapshot({ CarManager.carGeneration, CarManager.sessionGeneration,
  CarManager._currentFrameId, GameTimeManager.now })
local writesBeforePanel = writes

local function draw()
  state.calls = {}
  ControlDebugPanel.draw()
  check(equal(beforeOwnership, snapshot(ownership)), 'drawing preserves all request/winner/applied/attempted records')
  local currentRefs = {}
  collectTableRefs(ownership, currentRefs)
  for reference in pairs(beforeRefs) do check(currentRefs[reference], 'nested ownership record reference remains stable') end
  for reference in pairs(currentRefs) do check(beforeRefs[reference], 'draw creates no replacement ownership record tables') end
  for i, tableRef in ipairs(ownership) do check(tableRef == refs[i], 'ownership table reference remains stable #' .. i) end
  check(equal(beforeGenerations, snapshot({ CarManager.carGeneration, CarManager.sessionGeneration,
    CarManager._currentFrameId, GameTimeManager.now })), 'draw does not change generations, frame, or simulation clock')
  check(writes == writesBeforePanel and cameraCalls == 0 and storageWrites == 0 and raycasts == 0,
    'draw performs no physics/camera/storage-write/raycast side effects')
end

draw()
check(state.calls[2] and state.calls[2][1] == 'text', 'panel renders through read-only text UI')
check(diagnosticQueries == 0, 'no car selection causes no diagnostic query')
check(state.calls[3] and state.calls[3][1] == 'combo' and state.calls[3][2] == 'Car index###control-debug.car',
  'car selection uses its stable internal ID')
local choicesRef = state.calls[3][4]
check(#choicesRef == 3 and choicesRef[1] == 'No car selected' and choicesRef[2] == '0' and choicesRef[3] == '1',
  'selector has a distinct no-selection sentinel and the complete zero-based car range')
local initialCalls = #state.calls
check(initialCalls > 3, 'panel shows runtime/suspension context before a car is selected')

state.selection = 3
draw()
check(state.calls[3][4] == choicesRef, 'selector reuses its choices table across draws with unchanged count/locale')
local rendered = table.concat((function()
  local rows = {}
  for _, call in ipairs(state.calls) do if call[1] == 'text' then rows[#rows + 1] = call[2] end end
  return rows
end)(), '\n')
for _, expected in ipairs({ 'Writable AI car:', 'Physics permission:', 'Top-speed requests',
  'Throttle requests', 'Winner:', 'Last successful setter:',
  'Replay active: false', 'classification: AI', 'stale relative to current selection/session',
  'No applied record does not prove that the car is physically released.',
  'Pending neutral indication · inferred from applied state without active requests; physical state is unconfirmed.',
  'A recorded applied value is the last successful setter call, not a physics readback.' }) do
  check(rendered:find(expected, 1, true) ~= nil, 'selected-car panel reports readonly field/disclaimer: ' .. expected .. '\n' .. rendered)
end
check(rendered:find('INCIDENT_STOP', 1, true) ~= nil and rendered:find('TRAFFIC_YIELD', 1, true) ~= nil and
  rendered:find('COMPAT', 1, true) ~= nil and rendered:find('expired', 1, true) ~= nil and
  rendered:find('· valid', 1, true) ~= nil and rendered:find('Winner: none', 1, true) ~= nil,
  'panel displays valid and expired requests plus winner/applied divergence without changing owner records')
check(rendered:find('Record generations · car: 0 · session: -1 · stale relative to current selection/session', 1, true) ~= nil,
  'request records expose stale generation metadata independently of current selection')
local incidentAt, trafficAt = rendered:find('INCIDENT_STOP', 1, true), rendered:find('TRAFFIC_YIELD', 1, true)
local compatAt = rendered:find('COMPAT', 1, true)
check(compatAt and incidentAt and trafficAt and compatAt < incidentAt and incidentAt < trafficAt,
  'owner list ordering is stable and deterministic')

state.selection = 2 -- index 0: a player car with no managed requests
draw()
local noRequestText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then noRequestText[#noRequestText + 1] = call[2] end end
check(table.concat(noRequestText, '\n'):find('No active requests.', 1, true) ~= nil,
  'panel reports an empty request set for a selected car without managed requests')
check(table.concat(noRequestText, '\n'):find('classification: Player', 1, true) ~= nil,
  'zero-index player is selectable and classified separately from the no-selection sentinel')
check(table.concat(noRequestText, '\n'):find('Selected car · index: 0 · classification: Player · AI flag: false', 1, true) ~= nil,
  'index-zero car remains readable as the player even when it is human-controlled')

state.selection = 1 -- distinct no-selection sentinel
draw()
local noSelectionText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then noSelectionText[#noSelectionText + 1] = call[2] end end
check(table.concat(noSelectionText, '\n'):find('Select a car index to inspect its gates and control state.', 1, true) ~= nil,
  'sentinel selection does not inspect car index zero')

-- A bad active clock remains an informational condition and does not abort drawing.
state.selection = 3
GameTimeManager.getPlayingGameTime = function() error('injected invalid clock') end
draw()
local invalidClockText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then invalidClockText[#invalidClockText + 1] = call[2] end end
local invalidClockRendered = table.concat(invalidClockText, '\n')
check(invalidClockRendered:find('Active simulation time: unavailable', 1, true) and
  invalidClockRendered:find('TTL: unavailable', 1, true),
  'invalid clock is reported as unavailable without interrupting panel draw')
GameTimeManager.getPlayingGameTime = function() return GameTimeManager.now end

local localeBeforeChoices = localization.getLocale()
assert(localization.setLocale('es'))
draw()
check(state.calls[3][4] == choicesRef and state.calls[3][4][1] == 'Ningún coche seleccionado',
  'reusable selector choices refresh their sentinel text in the active locale')
localization.setLocale(localeBeforeChoices)

-- A denied gate, player, human, disabled, paused and replay states remain inspectable.
state.selection = 3 -- return to AI car index 1
draw()
for _, mode in ipairs({ 'denied', 'player', 'human', 'disabled', 'paused', 'replay' }) do
  allowed = mode ~= 'denied'
  sim.isReplayActive = mode == 'replay'
  CarManager.runtimeEnabled = mode ~= 'disabled'
  CarManager.runtimePaused = mode == 'paused'
  CarManager.runtimeLive = mode ~= 'replay'
  cars[1].isAIControlled = mode ~= 'human'
  if mode == 'player' then cars[1].index = 0 else cars[1].index = 1 end
  draw()
  check(#state.calls > 3, 'panel remains visible while runtime is ' .. mode)
  local textRows = {}
  for _, call in ipairs(state.calls) do if call[1] == 'text' then textRows[#textRows + 1] = call[2] end end
  local modeText = table.concat(textRows, '\n')
  if mode == 'replay' then check(modeText:find('Replay active: true', 1, true) ~= nil, 'active replay state is visible') end
  if mode == 'human' then check(modeText:find('classification: Human', 1, true) ~= nil, 'human classification is visible') end
end
check(localization ~= nil, 'localization dependency is available to the optional panel')
state.uiTime = 10
state.selection = 3
draw()
check(diagnosticQueries == 2 and zoneQueries == 0, 'diagnostic history is pulled once and absent incident maps do not trigger zone scans')
local historyRows = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' and call[2]:find('fsm%-changed') then historyRows[#historyRows + 1] = call[2] end end
check(#historyRows == 8, 'timeline presentation is limited to eight selected-car events')
state.uiTime = 10.1
draw()
check(diagnosticQueries == 2, 'panel does not bypass the 0.25 second pull interval')
state.uiTime = 10.26
draw()
check(diagnosticQueries == 3, 'selected-car history refreshes after the interval')
check(table.concat((function() local rows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then rows[#rows + 1] = call[2] end end; return rows end)(), '\n')
  :find('Coverage · current geometry predicate only', 1, true) ~= nil,
  'coverage is explicitly labeled as the current geometry predicate')
check(inventoryCalls == 3 and coverageCalls == 3 and zoneDecisionCalls == 3,
  'inventory, coverage and observed-decision getters are each pulled only on the shared refresh cadence (' .. inventoryCalls .. '/' .. coverageCalls .. '/' .. zoneDecisionCalls .. ')')
check(table.concat((function() local rows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then rows[#rows + 1] = call[2] end end; return rows end)(), '\n')
  :find('Chosen by query: 21', 1, true) ~= nil, 'query choice is distinguished from registered and covered zones')
local decisionRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then decisionRows[#decisionRows + 1] = call[2] end end
local decisionText = table.concat(decisionRows, '\n')
check(decisionText:find('Consumer branch: fsm%-handle%-yellow · returned state:', 1, false) ~= nil and
  decisionText:find('Consulted candidate: 44', 1, true) and decisionText:find('Candidate reason: within%-range') and
  decisionText:find('Query source: actual-query · sequence: 9', 1, true) and
  decisionText:find('Assignment origin: UNKNOWN · query sequence: 9 · matches query: No', 1, true) and
  decisionText:find('Assigned incident: 44 · assigned car: 2', 1, true),
  'real decision snapshot fields distinguish queried candidates, yellow branch consumption and accident assignment: ' .. decisionText)
check(decisionText:find('Queued transition: No pending transition', 1, true) ~= nil,
  'FSM getter validly reports an empty queue even though its pending-only valid flag is false')
state.nextPageClick = true
draw()
check(state.nextPageClick == false, 'next-page action was consumed')
state.uiTime = 10.52
draw()
check(inventoryCalls == 4 and inventoryCursors[4] == 33, 'inventory pagination advances only after an explicit UI action and remains refresh-cadenced')
accidentNavigationOnly = true
state.uiTime = 10.78
draw()
local navigationOnlyRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then navigationOnlyRows[#navigationOnlyRows + 1] = call[2] end end
local navigationOnlyText = table.concat(navigationOnlyRows, '\n')
check(navigationOnlyText:find('Accident query was not observed for this car.', 1, true) and
  navigationOnlyText:find('Assignment is shown without a matching query sample.', 1, true) and
  navigationOnlyText:find('Assignment origin: UNKNOWN · query sequence: Unknown · matches query: No', 1, true),
  'navigation-only wrapper keeps absent query fields unknown and assignment provenance distinct')

-- The UI clock is CSP's callable UI clock, not the active simulation clock.
local queriesBeforeClockCases = diagnosticQueries
state.uiTime = 11.029
draw()
check(diagnosticQueries == queriesBeforeClockCases, '0.249-second interval does not pull again')
ui.time = function() error('injected UI clock failure') end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'throwing UI clock never falls back to per-redraw pulls')
ui.time = function() return 0/0 end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'NaN UI clock never triggers a pull')
ui.time = function() return nil end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'nil UI clock never triggers a pull')
ui.time = function() return math.huge end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'positive infinity UI clock never triggers a pull')
ui.time = function() return -math.huge end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'negative infinity UI clock never triggers a pull')
ui.time = function() return 9 end
draw()
check(diagnosticQueries == queriesBeforeClockCases, 'backward UI clock never triggers a pull')
ui.time = function() return state.uiTime end
state.uiTime = 11.30
draw()
check(diagnosticQueries == queriesBeforeClockCases + 1, 'valid UI clock recovers after interval')

local captureFlag, captureFocus = Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR
Logger.OBS1_ENABLED = false
state.uiTime = 11.56
draw()
local captureOffRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then captureOffRows[#captureOffRows + 1] = call[2] end end
check(table.concat(captureOffRows, '\n'):find('Observation capture is off.', 1, true) ~= nil,
  'false capture flag is distinct from missing/unknown')
Logger.OBS1_ENABLED = true
Logger.OBS1_FOCUS_CAR = 2
state.uiTime = 11.82
draw()
local focusRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then focusRows[#focusRows + 1] = call[2] end end
check(table.concat(focusRows, '\n'):find('Capture focus differs from this car', 1, true) ~= nil,
  'different capture focus is explicit')
Logger.OBS1_FOCUS_CAR = nil
state.uiTime = 11.82
draw()
local unknownFocusRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then unknownFocusRows[#unknownFocusRows + 1] = call[2] end end
check(table.concat(unknownFocusRows, '\n'):find('Capture focus unknown', 1, true) ~= nil,
  'missing capture focus is not presented as matching')
Logger.OBS1_ENABLED, Logger.OBS1_FOCUS_CAR = captureFlag, captureFocus

local queryBeforeSelection = diagnosticQueries
state.selection = 2 -- change to index zero: selection changes do not bypass pull rate
draw()
state.selection = 3 -- index one
draw()
state.selection = 2
draw()
check(diagnosticQueries == queryBeforeSelection, 'rapid selection cycling cannot exceed global refresh interval')
state.selection = nil
state.uiTime = 12.08
draw()
check(diagnosticQueries == queryBeforeSelection + 1, 'one pull occurs after cycling once the shared interval elapses')

-- Real AccidentManager field names and exact culprit/victim role checks.
AccidentManager = {
  cars_culpritInAccidentIndex = { [1] = 11 }, cars_victimInAccidentIndex = { [1] = 12 },
  accidents_resolved = { [11] = false, [12] = false },
  accidents_carIndex = { [11] = 1, [12] = 2 }, accidents_collidedWithCarIndex = { [11] = 2, [12] = 1 },
  accidents_yellowFlagZoneIndex = { [11] = 21, [12] = 22 },
}
zoneFixtures[21] = { zone = 21, incident = 11, startSplinePosition = 0.12, endSplinePosition = 0.25, resolved = false }
zoneFixtures[22] = { zone = 22, incident = 12, startSplinePosition = 0.27, endSplinePosition = 0.31, resolved = false }
local zonesCalledBefore = zoneQueries
state.uiTime = 12.34
state.selection = 3
draw()
check(zoneQueries - zonesCalledBefore == 2, 'two valid independent incident links perform at most two zone lookups')
local associationText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then associationText[#associationText + 1] = call[2] end end
local associationRendered = table.concat(associationText, '\n')
check(associationRendered:find('incident 11', 1, true) and associationRendered:find('incident 12', 1, true),
  'culprit and victim links use the actual resolved-map and role fields')
check(associationRendered:find('Zone 21 · incident 11 · registered 0.1200 → 0.2500', 1, true) and
  associationRendered:find('Zone 22 · incident 12 · registered 0.2700 → 0.3100', 1, true) and
  associationRendered:find('Coverage · current geometry predicate only', 1, true) and
  associationRendered:find('Observed yellow-zone query', 1, true), 'registered bounds are distinct from coverage and observed query decisions')

-- Stale role links and uncertain/resolved zone records must not look registered/current.
AccidentManager.cars_victimInAccidentIndex[1] = 11 -- wrong: selected car is not that incident's victim
zoneFixtures[21] = { zone = 21, incident = 99, startSplinePosition = 0/0, endSplinePosition = 0.2, resolved = false }
zoneFixtures[22] = { zone = 22, incident = 12, startSplinePosition = 0.27, endSplinePosition = 0.31, resolved = true }
state.uiTime = 12.60
draw()
local invalidLinkText = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then invalidLinkText[#invalidLinkText + 1] = call[2] end end
local invalidLinkRendered = table.concat(invalidLinkText, '\n')
check(not invalidLinkRendered:find('Victim · incident 11', 1, true), 'reverse role index is verified against actual accident participants')
check(invalidLinkRendered:find('Zone 21 · association or current status unknown', 1, true),
  'mismatched zone association is not presented as registered current bounds')
AccidentManager.cars_victimInAccidentIndex[1] = 12
state.uiTime = 12.86
draw()
local resolvedZoneText = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then resolvedZoneText[#resolvedZoneText + 1] = call[2] end end
check(table.concat(resolvedZoneText, '\n'):find('Zone 22 · association or current status unknown', 1, true),
  'resolved zone is not presented as current registered bounds')
zoneFixtures[21] = { zone = 21, incident = 11, startSplinePosition = 0/0, endSplinePosition = 0.25, resolved = false }
zoneFixtures[22] = { zone = 22, incident = 12, startSplinePosition = 0.27, endSplinePosition = 0.31, resolved = false }
state.uiTime = 13.12
draw()
local invalidBoundsText = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then invalidBoundsText[#invalidBoundsText + 1] = call[2] end end
check(table.concat(invalidBoundsText, '\n'):find('Zone 21 · incident 11 · registered unavailable → 0.2500', 1, true),
  'non-finite spline bounds are displayed as unavailable, not normalized or inferred')

-- Unknown generation/reference session never becomes a false stale assertion.
Logger.getOBS1RecentForCar = function(index)
  diagnosticQueries = diagnosticQueries + 1
  return { car = index, records = {
    { car = index, sequence = 101, kind = 'lifecycle', context = 'historic-live', referenceSession = CarManager.sessionGeneration, generation = CarManager.getCarGeneration(index) },
    { car = index, sequence = 102, kind = 'lifecycle', context = 'old-session', referenceSession = CarManager.sessionGeneration + 3, generation = CarManager.getCarGeneration(index) + 2 },
    { car = index, sequence = 103, kind = 'lifecycle', context = 'unknown-ref', referenceSession = 'UNKNOWN', generation = -1 },
  }, matchingCount = 3, scanned = 3, stats = {} }
end
state.uiTime = 13.38
draw()
local identityText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then identityText[#identityText + 1] = call[2] end end
local identityRendered = table.concat(identityText, '\n')
check(identityRendered:find('#101 · time unknown · lifecycle · Current', 1, true) ~= nil,
  'matching known reference identity is explicitly current')
check(identityRendered:find('#102 · time unknown · lifecycle · Stale', 1, true) ~= nil,
  'known mismatched reference identity is explicitly stale')
check(identityRendered:find('#103 · time unknown · lifecycle · Unknown', 1, true) ~= nil,
  'unknown reference metadata is not mislabeled stale')
check(identityRendered:find('Historical context: historic%-live') and identityRendered:find('Historical context: old%-session'),
  'timeline labels historical context without replacing it with live flags')
Logger.OBS1_ENABLED = 'unknown-value'
draw()
local unknownFlagRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then unknownFlagRows[#unknownFlagRows + 1] = call[2] end end
check(table.concat(unknownFlagRows, '\n'):find('Observation capture status unknown.', 1, true),
  'non-boolean capture flag is unknown, never silently off')
Logger.OBS1_ENABLED = true

local originalLoggerGlobal = Logger
_G.Logger = { OBS1_ENABLED = true, OBS1_FOCUS_CAR = 1 }
state.uiTime = 13.64
draw()
local missingQueryRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then missingQueryRows[#missingQueryRows + 1] = call[2] end end
local missingQueryRendered = table.concat(missingQueryRows, '\n')
check(missingQueryRendered:find('Observation query unavailable.', 1, true) ~= nil and
  not missingQueryRendered:find('No matching recorded events', 1, true),
  'missing read-only API is unavailable, not a false no-events result')
_G.Logger = originalLoggerGlobal

Logger.getOBS1RecentForCar = function() diagnosticQueries = diagnosticQueries + 1; error('injected query failure') end
state.uiTime = 14.16
draw()
local failedQueryText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then failedQueryText[#failedQueryText + 1] = call[2] end end
local failedQueryRendered = table.concat(failedQueryText, '\n')
check(failedQueryRendered:find('Observation query unavailable.', 1, true) ~= nil,
  'throwing logger query is reported as unavailable without aborting panel draw')
check(failedQueryRendered:find('Top-speed requests', 1, true) ~= nil and
  not failedQueryRendered:find('Historical context: historical', 1, true),
  'query failure keeps ownership rows and does not re-present cached history as current')

Logger.getOBS1RecentForCar = function(index)
  diagnosticQueries = diagnosticQueries + 1
  return { car = index, matchingCount = 1, scanned = 1, records = { { car = index, sequence = 99, kind = 'test',
    context = 'replay-context', referenceSession = 0/0, generation = -1,
    detail = setmetatable({}, { __tostring = function() error('hostile tostring') end }) } },
    stats = { sinkThrewUncertain = 1, sinkUnavailable = 1, formatFailures = 1, detailOutputDrops = 1 } }
end
state.uiTime = 14.42
draw()
local hostileText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then hostileText[#hostileText + 1] = call[2] end end
local hostileRendered = table.concat(hostileText, '\n')
check(hostileRendered:find('Current state: DrivingInYellowFlagZone · previous state: NavigatingAroundAccident', 1, true),
  'live FSM getters remain separate from historical logger events')
check(hostileRendered:find('Historical context: replay%-context') and hostileRendered:find('Unknown', 1, true),
  'invalid reference metadata remains unknown and historical context is displayed')
check(hostileRendered:find('Capture has losses or truncated output', 1, true),
  'sink uncertainty, unavailable sink, formatting failure, and detail drops surface as capture loss')
check(hostileRendered:find('unavailable', 1, true) ~= nil, 'hostile dynamic text conversion is contained')

local longUTF8 = string.rep('A', 127) .. 'é'
Logger.getOBS1RecentForCar = function(index)
  diagnosticQueries = diagnosticQueries + 1
  return { car = index, matchingCount = 1, scanned = 1, records = { { car = index, sequence = 100, kind = 'test',
    context = 'UNKNOWN', referenceSession = 0, generation = 0, detail = longUTF8 } }, stats = {} }
end
state.uiTime = 14.68
draw()
local boundedText = {}
for _, call in ipairs(state.calls) do if call[1] == 'text' then boundedText[#boundedText + 1] = call[2] end end
check(table.concat(boundedText, '\n'):find(string.rep('A', 125) .. '...', 1, true) ~= nil,
  'dynamic UTF-8 text is cut at a safe boundary and stays within 128 bytes')

local localeBefore = localization.getLocale()
assert(localization.setLocale('pt-BR'))
state.uiTime = 14.94
draw()
local ptText = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then ptText[#ptText + 1] = call[2] end end
check(table.concat(ptText, '\n'):find('Eventos registrados recentes', 1, true) ~= nil, 'panel diagnostic labels use the pt-BR catalog')
check(table.concat(ptText, '\n'):find('Responsável: COMPAT', 1, true) ~= nil,
  'ownership request row uses the full Portuguese translation')
assert(localization.setLocale('es'))
state.uiTime = 15.20
draw()
local esText = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then esText[#esText + 1] = call[2] end end
check(table.concat(esText, '\n'):find('Eventos registrados recientes', 1, true) ~= nil, 'panel diagnostic labels use the Spanish catalog')
check(table.concat(esText, '\n'):find('Responsable: COMPAT', 1, true) ~= nil,
  'ownership request row uses the full Spanish translation')
localization.setLocale(localeBefore)

-- Session/car identity invalidation is immediate, but does not reset the shared pull timer.
Logger.getOBS1RecentForCar = function(index)
  diagnosticQueries = diagnosticQueries + 1
  return { car = index, matchingCount = 1, scanned = 1,
    records = { { car = index, sequence = 500, kind = 'test', detail = 'old-generation',
      context = 'old-reference', referenceSession = CarManager.sessionGeneration,
      generation = CarManager.getCarGeneration(index) } }, stats = {} }
end
state.uiTime = 15.46
draw()
local queryBeforeIdentityChange = diagnosticQueries
cars[1].speedKmh = 1e308
draw()
local largeSpeedRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then largeSpeedRows[#largeSpeedRows + 1] = call[2] end end
local largeSpeedLine
for _, row in ipairs(largeSpeedRows) do if row:find('Speed:', 1, true) then largeSpeedLine = row end end
local speedValue = largeSpeedLine and largeSpeedLine:match('Speed: (.-) km/h')
check(speedValue and #speedValue <= 128, 'large finite speed formatting is byte-bounded')
local originalFormat = string.format
string.format = function(formatString, ...)
  if formatString == '%.0f' then error('injected speed formatter failure') end
  return originalFormat(formatString, ...)
end
cars[1].speedKmh = 80
draw()
string.format = originalFormat
local formatterFailureRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then formatterFailureRows[#formatterFailureRows + 1] = call[2] end end
local formatterFailureText = table.concat(formatterFailureRows, '\n')
check(formatterFailureText:find('Speed: unavailable km/h', 1, true) and formatterFailureText:find('Top-speed requests', 1, true),
  'isolated speed formatter failure falls back and preserves ownership diagnostics')
CarManager.carGeneration[1] = CarManager.getCarGeneration(1) + 1
CarManager.sessionGeneration = CarManager.sessionGeneration + 1
beforeGenerations = snapshot({ CarManager.carGeneration, CarManager.sessionGeneration, CarManager._currentFrameId, GameTimeManager.now })
ui.time = function() error('clock unavailable during identity change') end
draw()
local invalidatedRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then invalidatedRows[#invalidatedRows + 1] = call[2] end end
local invalidatedText = table.concat(invalidatedRows, '\n')
check(not invalidatedText:find('old%-generation') and invalidatedText:find('Diagnostic snapshot stale or unavailable', 1, true),
  'session/generation change invalidates old cached history even with an unavailable UI clock')
check(diagnosticQueries == queryBeforeIdentityChange,
  'identity invalidation does not bypass the shared interval when the clock is unavailable')
ui.time = function() return 15.50 end
draw()
check(diagnosticQueries == queryBeforeIdentityChange,
  'valid but too-early clock after identity change still respects global refresh interval')
zoneFixtures[21] = { zone = 21, incident = 11, startSplinePosition = 1e308, endSplinePosition = -1e308, resolved = false }
ui.time = function() return 15.72 end
draw()
check(diagnosticQueries == queryBeforeIdentityChange + 1, 'identity snapshot refreshes when the shared interval elapses')
local largeZoneLine
for _, call in ipairs(state.calls) do
  if call[1] == 'text' and call[2]:find('Zone 21 · incident 11 · registered', 1, true) then largeZoneLine = call[2] end
end
local largeZoneStart = largeZoneLine and largeZoneLine:match('registered (.-) →')
check(largeZoneStart and #largeZoneStart <= 128, 'large finite spline bound format is byte-bounded')

local cutCases = {
  { prefix = string.rep('A', 124), character = 'é', expected = string.rep('A', 124) .. '...' },
  { prefix = string.rep('A', 123), character = '€', expected = string.rep('A', 123) .. '...' },
  { prefix = string.rep('A', 122), character = '😀', expected = string.rep('A', 122) .. '...' },
}
ui.time = function() return state.uiTime end
for i = 1, #cutCases do
  local cutCase = cutCases[i]
  local dynamic = cutCase.prefix .. cutCase.character .. string.rep('z', 12)
  Logger.getOBS1RecentForCar = function(index)
    diagnosticQueries = diagnosticQueries + 1
    return { car = index, matchingCount = 1, scanned = 1,
      records = { { car = index, sequence = 600 + i, kind = 'utf8', context = 'UNKNOWN',
        referenceSession = 'UNKNOWN', generation = 'UNKNOWN', detail = dynamic } }, stats = {} }
  end
  state.uiTime = 15.98 + (i - 1) * 0.26
  draw()
  local renderedRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then renderedRows[#renderedRows + 1] = call[2] end end
  check(table.concat(renderedRows, '\n'):find('event detail: ' .. cutCase.expected, 1, true) ~= nil,
    'UTF-8 truncation backs up before a split ' .. tostring(#cutCase.character) .. '-byte codepoint: ' .. table.concat(renderedRows, '\n'))
end

-- Role-link deduplication, invalid IDs, partial data and throwing optional getters.
local zoneCallsBeforeDuplicate = zoneQueries
AccidentManager.cars_culpritInAccidentIndex[1], AccidentManager.cars_victimInAccidentIndex[1] = 31, 31
AccidentManager.accidents_resolved[31] = false
AccidentManager.accidents_carIndex[31], AccidentManager.accidents_collidedWithCarIndex[31] = 1, 1
AccidentManager.accidents_yellowFlagZoneIndex[31] = 31
zoneFixtures[31] = { zone = 31, incident = 31, startSplinePosition = 0.4, endSplinePosition = 0.5, resolved = false }
state.uiTime = 16.76
draw()
check(zoneQueries - zoneCallsBeforeDuplicate == 1, 'duplicate culprit/victim role link is deduplicated to one zone query')
local duplicateRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then duplicateRows[#duplicateRows + 1] = call[2] end end
local duplicateText = table.concat(duplicateRows, '\n')
check(duplicateText:find('Culprit · incident 31', 1, true) and not duplicateText:find('Victim · incident 31', 1, true),
  'duplicate same-incident roles remain bounded to the first available link')

AccidentManager.cars_culpritInAccidentIndex[1], AccidentManager.cars_victimInAccidentIndex[1] = 0/0, 31.5
local callsBeforeInvalidIDs = zoneQueries
state.uiTime = 17.02
draw()
check(zoneQueries == callsBeforeInvalidIDs, 'NaN and non-integer incident IDs never trigger zone getters')

AccidentManager = { cars_culpritInAccidentIndex = { [1] = 99 } } -- deliberately partial maps
state.uiTime = 17.28
draw()
local partialRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then partialRows[#partialRows + 1] = call[2] end end
check(table.concat(partialRows, '\n'):find('Incident association unknown', 1, true) ~= nil,
  'partial incident maps render unknown instead of inventing participant data')

AccidentManager = {
  cars_culpritInAccidentIndex = { [1] = 32 }, cars_victimInAccidentIndex = {}, accidents_resolved = { [32] = false },
  accidents_carIndex = { [32] = 1 }, accidents_collidedWithCarIndex = { [32] = 2 }, accidents_yellowFlagZoneIndex = { [32] = 32 },
}
local throwingZoneCalls = 0
RaceTrackManager.getYellowZoneReadOnly = function() throwingZoneCalls = throwingZoneCalls + 1; error('zone getter failure') end
state.uiTime = 17.54
draw()
local zoneFailureRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then zoneFailureRows[#zoneFailureRows + 1] = call[2] end end
check(throwingZoneCalls == 1 and table.concat(zoneFailureRows, '\n'):find('Zone 32 · association or current status unknown', 1, true),
  'throwing zone getter is counted, contained, and reported as unknown')
check(table.concat(zoneFailureRows, '\n'):find('Top-speed requests', 1, true), 'zone getter failure preserves existing ownership UI')
RaceTrackManager.getYellowZoneReadOnly = function(id) zoneQueries = zoneQueries + 1; return zoneFixtures[id] end

local fsmCurrentCalls, fsmPreviousCalls = 0, 0
CarStateMachine.getCurrentState = function() fsmCurrentCalls = fsmCurrentCalls + 1; error('current FSM getter failure') end
CarStateMachine.getPreviousState = function() fsmPreviousCalls = fsmPreviousCalls + 1; error('previous FSM getter failure') end
state.uiTime = 17.80
draw()
local fsmFailureRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then fsmFailureRows[#fsmFailureRows + 1] = call[2] end end
check(fsmCurrentCalls == 1 and fsmPreviousCalls == 1 and table.concat(fsmFailureRows, '\n'):find('Current state: unavailable', 1, true),
  'throwing live FSM getters are individually protected')
check(table.concat(fsmFailureRows, '\n'):find('Top-speed requests', 1, true), 'FSM getter failure preserves ownership UI')
CarStateMachine.getCurrentState = function(index) return index == 1 and 'DrivingInYellowFlagZone' or 'DrivingNormally' end
CarStateMachine.getPreviousState = function(index) return index == 1 and 'NavigatingAroundAccident' or 'DrivingNormally' end

Logger.getOBS1RecentForCar = function(index)
  diagnosticQueries = diagnosticQueries + 1
  return { car = index, records = { { car = 2, sequence = 999, kind = 'foreign-car', context = 'wrong target' } },
    matchingCount = 1, scanned = 1, stats = {} }
end
state.uiTime = 18.06
draw()
local foreignRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then foreignRows[#foreignRows + 1] = call[2] end end
local foreignText = table.concat(foreignRows, '\n')
check(foreignText:find('Observation query unavailable.', 1, true) and not foreignText:find('foreign%-car'),
  'foreign-car record in malformed snapshot is rejected, never rendered as the selected car')

Logger.getOBS1RecentForCar = function(index) diagnosticQueries = diagnosticQueries + 1; return nil end
state.uiTime = 18.32
draw()
local nilSnapshotRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then nilSnapshotRows[#nilSnapshotRows + 1] = call[2] end end
check(table.concat(nilSnapshotRows, '\n'):find('Observation query unavailable.', 1, true) ~= nil,
  'nil helper snapshot is unavailable rather than an empty event history')

local savedLogger = Logger
_G.Logger = setmetatable({ OBS1_ENABLED = true, OBS1_FOCUS_CAR = 1 }, { __index = function() error('logger lookup metamethod') end })
state.uiTime = 18.58
draw()
local loggerMetatableRows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then loggerMetatableRows[#loggerMetatableRows + 1] = call[2] end end
check(table.concat(loggerMetatableRows, '\n'):find('Observation query unavailable.', 1, true),
  'throwing optional logger lookup does not abort panel rendering')
_G.Logger = savedLogger

local validSelection = state.selection
state.selection = 99
draw()
check(table.concat((function() local rows = {}; for _, call in ipairs(state.calls) do if call[1] == 'text' then rows[#rows + 1] = call[2] end end; return rows end)(), '\n')
  :find('Select a car index', 1, true) ~= nil, 'out-of-range selector values fall back to no selection')
state.selection = validSelection
check(Logger.OBS1_ENABLED == true and Logger.OBS1_FOCUS_CAR == 1,
  'panel never changes capture enablement or diagnostic focus')
print(string.format('Control debug panel read-only tests passed: %d checks.', checks))
