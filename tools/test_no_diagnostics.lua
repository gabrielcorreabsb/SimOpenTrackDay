-- Run from repository root: luajit tools/test_no_diagnostics.lua
package.path = './?.lua;./?/init.lua;' .. package.path

local function read(path)
  local file = assert(io.open(path, 'rb'))
  local source = file:read('*a')
  file:close()
  return source
end

-- Remove Lua comments without treating comment markers inside quoted strings as comments.
local function stripComments(source)
  local out, i, size = {}, 1, #source
  local function longBracketAt(position)
    local equals = source:sub(position):match('^%[(=*)%[')
    if equals ~= nil then return #equals, position + #equals + 1 end
  end
  while i <= size do
    local char = source:sub(i, i)
    if char == '"' or char == "'" then
      local quote, start = char, i
      i = i + 1
      while i <= size do
        local current = source:sub(i, i)
        if current == '\\' then i = i + 2
        elseif current == quote then i = i + 1; break
        else i = i + 1 end
      end
      out[#out + 1] = source:sub(start, i - 1)
    elseif source:sub(i, i + 1) == '--' then
      local equals, contentStart = longBracketAt(i + 2)
      if equals then
        local close = ']' .. string.rep('=', equals) .. ']'
        local closeAt = source:find(close, contentStart, true)
        i = closeAt and closeAt + #close or size + 1
      else
        local newline = source:find('\n', i + 2, true)
        i = newline or size + 1
      end
    else
      local equals, contentStart = longBracketAt(i)
      if equals then
        local close = ']' .. string.rep('=', equals) .. ']'
        local closeAt = source:find(close, contentStart, true)
        local finish = closeAt and closeAt + #close - 1 or size
        out[#out + 1] = source:sub(i, finish)
        i = finish + 1
      else
        out[#out + 1] = char
        i = i + 1
      end
    end
  end
  return table.concat(out)
end

local entry = stripComments(read('SimOpenTrackDay.lua'))
local carStateMachine = stripComments(read('CarStateMachine/CarStateMachine.lua'))
local constants = stripComments(read('Constants.lua'))
local pathfinding = stripComments(read('Pathfinding.lua'))
local carOperations = stripComments(read('CarOperations.lua'))
local accidentManager = stripComments(read('AccidentManager.lua'))
local easingYield = stripComments(read('CarStateMachine/States/CarState_EasingInYield.lua'))
local easingOvertake = stripComments(read('CarStateMachine/States/CarState_EasingInOvertake.lua'))
local completableIndexes = stripComments(read('DataStructures/CompletableIndexCollectionManager.lua'))

local function check(condition, message)
  assert(condition, message)
end

for _, source in ipairs({ entry, carStateMachine, constants, pathfinding, carOperations, accidentManager }) do
  check(not source:find('[RTD-DIAG-', 1, true), 'runtime source contains no RTD diagnostic records')
  check(not source:find('[SOTD-MEM-PROBE]', 1, true), 'runtime source contains no memory probe')
  check(not source:find('[SOTD-ICON]', 1, true), 'runtime source contains no icon diagnostic')
end

check(entry:find('xpcall(awake', 1, true) and entry:find('debug.traceback()', 1, true),
  'initialization remains protected and retains traceback')
check(entry:find('xpcall(function()', 1, true) and entry:find('UI draw failed: ', 1, true) and
  entry:find('debug.traceback()', 1, true), 'draw errors remain protected, operationally reported, and traced')
check(entry:find('CSPCompatibilityManager.ShowErrorModalDialog = false', 1, true),
  'CSP modal remains disabled as required')
check(entry:find('CSPCompatibilityManager.checkForMissingElements', 1, true) and
  entry:find('is missing required Custom Shaders Patch elements', 1, true),
  'CSP validation and user-facing compatibility message remain')
check(select(2, entry:gsub('CSPCompatibilityManager%.addFunction', '')) > 20,
  'CSP compatibility API registrations remain present')
check(entry:find('function script.MANIFEST__FUNCTION_MAIN(dt)', 1, true) and
  entry:find('function script.MANIFEST__FUNCTION_ICON()', 1, true) and
  entry:find('function script.MANIFEST__UPDATE(dt)', 1, true) and
  entry:find('function script.MANIFEST__TRANSPARENT(dt)', 1, true),
  'manifest callback functions remain defined')
check(entry:find('ac.onCarCollision(-1', 1, true) and entry:find('ac.onCarJumped(-1', 1, true),
  'normal collision and jump event registration remains')

local manifest = read('manifest.ini')
local windowCount = 0
for _ in manifest:gmatch('%[WINDOW_%d+%]') do windowCount = windowCount + 1 end
check(windowCount == 1, 'manifest exposes exactly one main window')
check(manifest:find('ID = mainWindow', 1, true) and not manifest:find('[WINDOW_1]', 1, true) and
  not manifest:find('FUNCTION_SETTINGS', 1, true),
  'main window retains its ID and no separate Settings callback/window remains')
check(manifest:find('FUNCTION_MAIN = MANIFEST__FUNCTION_MAIN', 1, true) and
  manifest:find('FUNCTION_ICON = MANIFEST__FUNCTION_ICON', 1, true) and
  manifest:find('UPDATE = MANIFEST__UPDATE', 1, true) and
  manifest:find('TRANSPARENT = MANIFEST__TRANSPARENT', 1, true),
  'manifest callback IDs remain unchanged')

check(not entry:find('storage_Debugging', 1, true) and not entry:find('PATHFINDING_DEBUGGING', 1, true),
  'entry no longer reads debug storage or runs experimental pathfinding controls')
check(not constants:find('PATHFINDING_DEBUGGING', 1, true), 'pathfinding debug flags are removed')
check(not pathfinding:find('Pathfinding.drawPaths', 1, true) and
  not pathfinding:find('Pathfinding.renderCarAABB', 1, true) and
  not pathfinding:find('render.debug', 1, true), 'pathfinding debug drawing entry points are removed')
check(not carOperations:find('render.debug', 1, true) and
  not carOperations:find('renderCarSideOffTrack', 1, true) and
  not carOperations:find('renderCarBlockCheckRays_NEWDoDAPPROACH', 1, true),
  'car-operation debug gizmos and ray drawing are removed')
check(not accidentManager:find('AccidentManager.simulateAccident', 1, true) and
  not accidentManager:find('getStorage_Debugging', 1, true), 'unreferenced development accident simulations are removed')
check(not carStateMachine:find('ac.log', 1, true) and not carStateMachine:find('debug_state', 1, true),
  'car-state debug startup log is removed')
check(not carStateMachine:find('getStorage_Debugging', 1, true) and
  not carStateMachine:find('debugLogFastStateChanges', 1, true),
  'state machine no longer reads the fast-transition debug setting')
check(carStateMachine:find('changeState(carIndex, newStateToTransitionIntoThisFrame)', 1, true) and
  carStateMachine:find('states_entryFunctions[newStateToTransitionIntoThisFrame](carIndex, dt, sortedCarList', 1, true),
  'state transitions and state entry actions remain')
check(carStateMachine:find('CarStateMachine: #%d collided with another car', 1, true) and
  carStateMachine:find('CarStateMachine: #%d was collided into by another car', 1, true),
  'operational collision transition logs remain')
check(carStateMachine:find('Logger.error(string.format("CarStateMachine: #%d stat is nil!"', 1, true),
  'state-machine missing-state error remains')

for _, source in ipairs({ easingYield, easingOvertake }) do
  check(not source:find('getStorage_Debugging', 1, true) and
    not source:find('debugLogCarYielding', 1, true) and
    not source:find('debugLogCarOvertaking', 1, true),
    'yield/overtake states no longer consume debug settings')
end
check(easingYield:find('CarManager_setCalculatedTrackLateralOffset(carIndex', 1, true) and
  easingYield:find('CarOperations_toggleTurningLights(carIndex, turningLights)', 1, true) and
  easingYield:find('CarOperations_yieldSafelyToSide(carIndex, dt, car, storage, useIndicatorLights)', 1, true),
  'yield lateral offset, lights, and side-driving actions remain')
check(easingYield:find('Logger_error(string_format', 1, true), 'yield-state operational invariant errors remain')
check(easingOvertake:find('CarManager_setCalculatedTrackLateralOffset(carIndex', 1, true) and
  easingOvertake:find('CarOperations_overtakeSafelyToSide(carIndex, dt, car, storage, useIndicatorLights)', 1, true) and
  easingOvertake:find('CarOperations_setAICaution(carIndex, aiCaution)', 1, true),
  'overtake offset, caution, and side-driving actions remain')
check(easingOvertake:find('Logger_error(string_format', 1, true) and
  easingOvertake:find('Logger_warn(string_format', 1, true),
  'overtake-state operational errors and warnings remain')
check(not completableIndexes:find('Logger.log', 1, true) and
  completableIndexes:find('if resolvedCollection[i] == false then', 1, true) and
  completableIndexes:find('collections_firstNonResolvedIndex[indexIndex] = i', 1, true) and
  completableIndexes:find('break', 1, true),
  'index scan preserves first-unresolved behavior without trace logging')

for _, path in ipairs({ 'SettingsWindow.lua', 'UIManager.lua', 'MainWindow.lua' }) do
  local source = stripComments(read(path))
  check(not source:find('getStorage_Debugging', 1, true) and
    not source:find('debugLogFastStateChanges', 1, true) and
    not source:find('debugLogCarYielding', 1, true) and
    not source:find('debugLogCarOvertaking', 1, true),
    path .. ' has no live consumer for removed diagnostic settings')
end

print('No-diagnostics static contracts passed')
