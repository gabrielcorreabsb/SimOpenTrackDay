-- Run from repository root: luajit tools/test_main_window.lua
package.path = './?.lua;./?/init.lua;' .. package.path

local persisted = { uiLanguage = 'en' }
_G.StorageManager = {
  getStorage_UI = function() return persisted end,
  getStorage_Global = function() return { uiLanguage = '' } end,
}

local calls = {}
local clicked = false
local availableWidth = 300
local nextLocaleIndex, localeChanged = 1, false
local function record(name, ...) calls[#calls + 1] = { name, ... } end
_G.ui = {
  ComboFlags = { None = 0 },
  textColored = function(text) record('colored', text) end,
  newLine = function() record('newline') end,
  combo = function(label, index, _, names)
    record('combo', label)
    assert(names[1] == 'English' and names[2] == 'Português (Brasil)' and names[3] == 'Español')
    return nextLocaleIndex, localeChanged
  end,
  separator = function() record('separator') end,
  availableSpaceX = function() return availableWidth end,
  measureDWriteText = function(text, size, wrap) return { x = 150 } end,
  button = function(label, size)
    record('button', label, size.x)
    assert(size.x <= availableWidth and size.y == 40, 'button width does not exceed available width')
    return clicked
  end,
  dwriteText = function(text) record('heading', text) end,
}
_G.math = math
_G.vec2 = function(x, y) return { x = x, y = y } end
_G.rgbm = function(r, g, b, a) return { r, g, b, a } end
_G.ColorManager = { RGBM_Colors = { WhiteSmoke = 'white-smoke' } }
_G.AppIconRenderer = { draw = function() record('icon') end }
_G.UIManager = {
  toggleSettingsWindow = function() record('settings') end,
  drawAppNotRunningMessageInMainWindow = function() record('not-running') end,
  drawMainWindowLateralOffsetsSection = function() record('lanes') end,
  drawUICarList = function() record('car-list') end,
}

local Localization = require('Localization')
local MainWindow = require('MainWindow')
local function find(name, value)
  for _, call in ipairs(calls) do
    if call[1] == name and (value == nil or call[2] == value) then return true end
  end
  return false
end
local function position(name)
  for i, call in ipairs(calls) do if call[1] == name then return i end end
end
local function reset() calls = {}; clicked = false end

-- Active rendering, button action, and stable translated IDs.
clicked = true
MainWindow.draw(function() return true end, false, nil)
assert(find('button', 'Modify Settings###main.settings'), 'settings label keeps its stable ID')
assert(find('settings'), 'settings button invokes the existing toggle')
assert(find('heading', 'Driving lanes') and find('heading', 'AI car list'), 'active sections remain visible')
assert(find('lanes') and find('car-list'), 'active section callbacks run')

-- Language selection goes through Localization and persists via UI storage.
reset()
clicked = true
nextLocaleIndex, localeChanged = 2, true
MainWindow.draw(function() return false end, false, nil)
assert(persisted.uiLanguage == 'pt-BR' and Localization.getLocale() == 'pt-BR', 'selected locale persists')
assert(find('combo', 'Language###settings.language'), 'language ID remains stable at the selection call site')
assert(find('button', 'Alterar configurações###main.settings') and find('settings'), 'settings remains actionable while app is disabled')
assert(find('not-running') and not find('lanes') and not find('car-list'), 'disabled state stops below the button')
assert(position('combo') < position('button') and position('button') < position('not-running'),
  'language and settings controls precede the disabled-state guard')

-- The extracted sizing expression clamps to available width at narrow sizes.
nextLocaleIndex, localeChanged = 2, false
for _, width in ipairs({ 80, 480, 1760 }) do
  reset()
  availableWidth = width
  MainWindow.draw(function() return false end, false, nil)
  local expected = math.min(width, math.max(120, 150 + 24))
  assert(find('button', nil), 'settings button rendered at width ' .. width)
  local actual
  for _, call in ipairs(calls) do if call[1] == 'button' then actual = call[3]; break end end
  assert(actual == expected and actual <= width,
    'settings width uses original clamp formula at width ' .. width)
end
availableWidth = 300

-- CSP warning remains conditional and is presented verbatim when active.
reset()
nextLocaleIndex, localeChanged = 2, false
local cspMessage = 'Required CSP item missing'
MainWindow.draw(function() return false end, true, cspMessage)
assert(find('colored', cspMessage), 'CSP message shown verbatim')
reset()
MainWindow.draw(function() return true end, false, cspMessage)
assert(not find('colored', cspMessage), 'CSP message hidden when missing-elements flag is false')

-- Compile and execute only the entry's MAIN callback with bounded dependencies.
local entry = assert(io.open('SimOpenTrackDay.lua', 'rb'))
local source = entry:read('*a')
entry:close()
local declaration = 'function script.MANIFEST__FUNCTION_MAIN(dt)'
local startAt = assert(source:find(declaration, 1, true), 'manifest main callback declaration exists')
local closeStart = assert(source:find('\nend', startAt, true), 'manifest main callback terminator exists')
local callbackSource = source:sub(startAt, closeStart + 4)
local callbackChunk = assert(loadstring([[
  local script = {}
  local MainWindow = ...
  local shouldAppRun = select(2, ...)
  local anyMissingCSPElements = select(3, ...)
  local missingCSPElementsErrorMessage = select(4, ...)
  local ac = select(5, ...)
  local debug = _G.debug
]] .. '\n' .. callbackSource .. '\nreturn script.MANIFEST__FUNCTION_MAIN'))

local shouldRunCalls = 0
local stableShouldRun = function() shouldRunCalls = shouldRunCalls + 1; return false end
local observed = {}
local originalDraw = MainWindow.draw
MainWindow.draw = function(callback, missing, message)
  observed.callback, observed.missing, observed.message = callback, missing, message
  return originalDraw(callback, missing, message)
end
local errors = {}
local callback = callbackChunk(MainWindow, stableShouldRun, true, 'wrapper CSP message', {
  error = function(message) errors[#errors + 1] = message end,
})
callback(0)
assert(observed.callback == stableShouldRun and observed.missing == true and
  observed.message == 'wrapper CSP message', 'entry wrapper delegates stable callback and CSP values')
assert(shouldRunCalls == 1, 'delegated main window evaluates the supplied shouldAppRun callback')
assert(#errors == 0, 'successful extracted callback does not log a draw error')

MainWindow.draw = function() error('injected main-window draw failure') end
callback(0)
assert(#errors == 1 and errors[1]:find('[RTD-DIAG] draw error:', 1, true) and
  errors[1]:find('injected main-window draw failure', 1, true),
  'entry xpcall catches injected MainWindow failure and reports established diagnostic')
MainWindow.draw = originalDraw

print('MainWindow headless checks passed')
