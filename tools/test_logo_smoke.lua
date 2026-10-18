-- Portable vector-logo and manifest icon callback smoke tests.
-- Run from the repository root with LuaJIT: luajit tools/test_logo_smoke.lua

local source = debug.getinfo(1, 'S').source:sub(2)
local toolsDir = source:match('^(.*)[/\\]') or 'tools'
local root = toolsDir:match('^(.*)[/\\]tools$') or '.'
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

local checks, failures = 0, 0
local function check(ok, message)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    io.stderr:write('FAIL: ' .. message .. '\n')
  end
end

local function vec2(x, y)
  return { x = x or 0, y = y or 0 }
end

local function installUI()
  local state = {
    cursor = vec2(0, 0), lines = {}, dummyCalls = 0, getCursorCalls = 0,
    cursorSetCalls = 0, stackCalls = 0, bitmapCalls = 0,
    viewport = vec2(1024, 768), space = vec2(100, 100),
  }
  _G.vec2 = vec2
  _G.rgbm = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
  _G.ui = {
    drawLine = function(a, b, color, thickness)
      state.lines[#state.lines + 1] = { a = vec2(a.x, a.y), b = vec2(b.x, b.y), color = color, thickness = thickness }
    end,
    getCursor = function()
      state.getCursorCalls = state.getCursorCalls + 1
      return vec2(state.cursor.x, state.cursor.y)
    end,
    setCursor = function(position)
      state.cursorSetCalls = state.cursorSetCalls + 1
      state.cursor = vec2(position.x, position.y)
    end,
    dummy = function(size)
      state.dummyCalls = state.dummyCalls + 1
      state.cursor.y = state.cursor.y + size.y
    end,
    windowSize = function() return vec2(state.viewport.x, state.viewport.y) end,
    availableSpaceX = function() return state.space.x end,
    availableSpaceY = function() return state.space.y end,
  }
  return state
end

local function resetRealModules()
  package.loaded['lib/uilib/Theme'] = nil
  package.loaded['lib.uilib.Theme'] = nil
  package.loaded['lib/uilib/Logo'] = nil
  package.loaded['lib.uilib.Logo'] = nil
  package.loaded['AppIconRenderer'] = nil
end

local state = installUI()
resetRealModules()
local Theme = require('lib/uilib/Theme')
local Logo = require('lib/uilib/Logo')

-- Default Logo.draw(size) draws the vector mark and advances layout through dummy.
state.cursor = vec2(4, 6)
Logo.draw(52)
check(#state.lines == 17, 'default Logo.draw renders 17 vector strokes')
check(state.dummyCalls == 1 and state.cursor.x == 4 and state.cursor.y == 66,
  'default Logo.draw advances cursor using dummy by size plus Theme spacing')

-- Explicit positioning draws only: no cursor query, cursor mutation, or dummy.
state.lines, state.dummyCalls, state.getCursorCalls, state.cursorSetCalls = {}, 0, 0, 0
state.cursor = vec2(17, 23)
local explicitPosition = vec2(90, 40)
Logo.draw(24, explicitPosition)
check(#state.lines == 17, 'explicit-position Logo.draw renders 17 vector strokes')
check(state.dummyCalls == 0 and state.getCursorCalls == 0 and state.cursorSetCalls == 0 and
  state.cursor.x == 17 and state.cursor.y == 23,
  'explicit-position Logo.draw does not query or mutate layout cursor')
check(state.lines[1].a.x == explicitPosition.x + 24 / 52 and
  state.lines[1].a.y == explicitPosition.y + 7 * 24 / 52,
  'explicit-position logo strokes use the provided parent coordinates')

-- The existing renderer remains a 128px vector logo at the viewport top-right.
state.lines, state.dummyCalls, state.getCursorCalls, state.cursorSetCalls = {}, 0, 0, 0
_G.Constants = { APP_ICON_SIZE = vec2(128, 128) }
_G.UIManager = { VERTICAL_SCROLLBAR_WIDTH = 18 }
local renderer = require('AppIconRenderer')
renderer.draw()
check(#state.lines == 17, 'AppIconRenderer draws the vector mark without a bitmap')
check(math.abs(state.lines[1].a.x - (878 + 128 / 52)) < 0.000001 and
  math.abs(state.lines[1].a.y - (10 + 7 * 128 / 52)) < 0.000001,
  '128px renderer positions the vector logo at top-right x=878, y=10 in a 1024px viewport')
check(state.dummyCalls == 0 and state.getCursorCalls == 0 and state.cursorSetCalls == 0 and
  state.bitmapCalls == 0, 'AppIconRenderer does not use PNG, dummy, or cursor mutation')

-- Extract and compile only the manifest icon callback, not the application entry point.
local entryPath = root .. '/SimOpenTrackDay.lua'
local file = assert(io.open(entryPath, 'rb'))
local entry = file:read('*a')
file:close()
local function callbackChunk()
  local declaration = 'function script.MANIFEST__FUNCTION_ICON()'
  local startAt = assert(entry:find(declaration, 1, true), 'manifest icon callback declaration missing')
  local closeStart = assert(entry:find('\nend', startAt, true), 'manifest icon callback terminator missing')
  local callbackSource = entry:sub(startAt, closeStart + 4)
  local prefix = [[
    local script = {}
    local Logo = ...
    local ui = _G.ui
    local math_min = math.min
  ]]
  local chunk, err = loadstring(prefix .. '\n' .. callbackSource .. '\nreturn script.MANIFEST__FUNCTION_ICON')
  assert(chunk, err)
  return chunk(Logo)
end

local manifestFile = assert(io.open(root .. '/manifest.ini', 'rb'))
local manifest = manifestFile:read('*a')
manifestFile:close()
local entryHasCallback = entry:find('function script.MANIFEST__FUNCTION_ICON()', 1, true) ~= nil
check(entryHasCallback, 'entry point defines MANIFEST__FUNCTION_ICON')
for _, section in ipairs({ 'WINDOW_0', 'WINDOW_1' }) do
  local body = manifest:match('%[' .. section .. '%](.-)%[WINDOW_%d+%]') or
    manifest:match('%[' .. section .. '%](.-)%[RENDER_CALLBACKS%]')
  check(body and body:match('FUNCTION_ICON%s*=%s*MANIFEST__FUNCTION_ICON') and entryHasCallback,
    section .. ' points to the implemented MANIFEST__FUNCTION_ICON callback')
  check(body and body:match('\n%s*ICON%s*=') == nil,
    section .. ' has no legacy ICON metadata key')
end

local callback = callbackChunk()
local upvalues = {}
for index = 1, math.huge do
  local name = debug.getupvalue(callback, index)
  if not name then break end
  upvalues[name] = true
end
check(upvalues.Logo and not upvalues.iconInvalidBoundsLogged and not upvalues.Logger,
  'extracted callback closes over the logo renderer without diagnostic state or logger')

state.lines, state.dummyCalls, state.getCursorCalls, state.cursorSetCalls = {}, 0, 0, 0
state.cursor, state.space = vec2(30, 45), vec2(40, 30)
callback()
check(#state.lines == 17 and state.lines[1].a.x == 30 + 20 / 52 and
  state.lines[1].a.y == 45 + 7 * 20 / 52,
  'callback caps large available bounds at 20 pixels')

state.lines, state.getCursorCalls = {}, 0
state.space = vec2(12, 8)
callback('ignored arguments')
check(#state.lines == 17, 'callback draws vector logo for positive bounds')
check(state.lines[1].a.x == 30 + 8 / 52 and state.lines[1].a.y == 45 + 7 * 8 / 52,
  'callback uses min(20, availableX, availableY), including an eight-pixel bound')
check(state.dummyCalls == 0 and state.getCursorCalls == 1 and state.cursorSetCalls == 0 and
  state.bitmapCalls == 0, 'callback draw does not use PNG, dummy, or cursor mutation')
check(state.stackCalls == 0, 'callback does not alter UI stacks')

state.lines, state.dummyCalls, state.getCursorCalls, state.cursorSetCalls = {}, 0, 0, 0
state.space = vec2(0, 30)
callback()
state.space = vec2(-5, 30)
callback()
check(#state.lines == 0 and state.dummyCalls == 0 and state.cursorSetCalls == 0,
  'zero and negative bounds skip drawing and layout mutation')

if failures > 0 then
  io.stderr:write(string.format('Logo smoke failed: %d assertion(s); %d checks.\n', failures, checks))
  os.exit(1)
end
print(string.format('Logo smoke passed: %d assertions/checks.', checks))
