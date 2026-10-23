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
  [1] = { index = 1, isAIControlled = true, isConnected = true, isActive = true, speedKmh = 80 },
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
Logger = { error = function() end, log = function() end, warn = function() end }
ColorManager = { RGBM_Colors = { Red = {}, SeaGreen = {} } }
render = { createRay = function() end }
VecPool = { getTempVec3 = function() end }
vec3 = function() return { set = function() end } end
RaceTrackManager = { TrackSide = { LEFT = 1, RIGHT = 2 } }
RaceTrackManager.getYieldingSide = function() return 1 end
RaceTrackManager.getOvertakingSide = function() return 2 end
RaceTrackManager.getLateralOffsetSign = function() return 1 end
RaceTrackManager.getOppositeSide = function() return 2 end
CarManager = dofile('CarManager.lua')
CarManager.runtimeEnabled, CarManager.runtimePaused, CarManager.runtimeLive = true, false, true
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

local state = { calls = {}, selection = 3 }
ui = {
  ComboFlags = { None = 0 },
  separator = function() state.calls[#state.calls + 1] = { 'separator' } end,
  textWrapped = function(value) state.calls[#state.calls + 1] = { 'text', value } end,
  combo = function(label, selected, _, choices)
    state.calls[#state.calls + 1] = { 'combo', label, selected, choices }
    if state.selection then local next = state.selection; state.selection = nil; return next, true end
    return selected, false
  end,
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
check(state.calls[3] and state.calls[3][1] == 'combo' and state.calls[3][2] == 'Car index###control-debug.car',
  'car selection uses its stable internal ID')
local choicesRef = state.calls[3][4]
check(#choicesRef == 3 and choicesRef[1] == 'No car selected' and choicesRef[2] == '0' and choicesRef[3] == '1',
  'selector has a distinct no-selection sentinel and the complete zero-based car range')
local initialCalls = #state.calls
check(initialCalls > 3, 'panel shows runtime/suspension context before a car is selected')

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
print(string.format('Control debug panel read-only tests passed: %d checks.', checks))
