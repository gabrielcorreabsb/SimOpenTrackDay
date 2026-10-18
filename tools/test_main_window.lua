-- Headless integration contract for the one-window MainWindow. Mocks exercise
-- API order and state transitions, not CSP rendering.
package.path = './?.lua;./?/init.lua;' .. package.path

local checks = 0
local function check(ok, message)
  checks = checks + 1
  if not ok then error('FAIL: ' .. message, 2) end
end

local function vec2(x, y) return { x = x or 0, y = y or 0 } end
_G.vec2 = vec2
_G.rgbm = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end

local names = {
  'Text', 'Border', 'CheckMark', 'SliderGrab', 'SliderGrabActive', 'FrameBg',
  'FrameBgHovered', 'FrameBgActive', 'Button', 'ButtonHovered', 'ButtonActive',
}
local styleColor = {}
for index, name in ipairs(names) do styleColor[name] = index end

local state = {
  events = {}, children = {}, styles = {}, stylePushes = {}, disabledDepth = 0, widthDepth = 0,
  fontDepth = 0, availableWidth = 1200, contentVisible = true,
  cursor = vec2(0, 0), scroll = vec2(0, 0), windowSize = vec2(1024, 768), windowPos = vec2(0, 0),
  pendingButton = nil, pendingCheckbox = nil, pendingCombo = {},
  comboRows = {}, buttonRows = {}, text = {}, wrapped = {}, gradients = {}, measuredTexts = {},
  shouldRunCalls = 0, carListCalls = 0, notRunningCalls = 0, errors = 0,
}
local function event(kind, ...)
  state.events[#state.events + 1] = { kind, ... }
end
local function clearFrame()
  state.events, state.children, state.comboRows, state.buttonRows = {}, {}, {}, {}
  state.text, state.wrapped, state.gradients = {}, {}, {}
  state.measuredTexts = {}
  state.carListCalls, state.notRunningCalls = 0, 0
end

_G.ui = {
  ComboFlags = { None = 0 }, SelectableFlags = { None = 0 },
  StyleColor = styleColor,
  pushStyleColor = function(index, value)
    state.styles[#state.styles + 1] = { index = index, value = value }
    state.stylePushes[#state.stylePushes + 1] = { index = index, value = value }
    event('style+', index)
  end,
  popStyleColor = function(count)
    count = count or 1
    assert(#state.styles >= count, 'style stack underflow')
    for _ = 1, count do state.styles[#state.styles] = nil end
    event('style-', count)
  end,
  pushDWriteFont = function() state.fontDepth = state.fontDepth + 1; event('font+') end,
  popDWriteFont = function() assert(state.fontDepth > 0); state.fontDepth = state.fontDepth - 1; event('font-') end,
  pushItemWidth = function(width) state.widthDepth = state.widthDepth + 1; state.itemWidth = width; event('width+', width) end,
  popItemWidth = function() assert(state.widthDepth > 0); state.widthDepth = state.widthDepth - 1; event('width-') end,
  pushDisabled = function() state.disabledDepth = state.disabledDepth + 1 end,
  popDisabled = function() assert(state.disabledDepth > 0); state.disabledDepth = state.disabledDepth - 1 end,
  text = function(text) state.text[#state.text + 1] = text; event('text', text) end,
  textWrapped = function(text) state.wrapped[#state.wrapped + 1] = text; event('wrapped', text) end,
  textColored = function(text) state.text[#state.text + 1] = text; event('colored', text) end,
  dwriteText = function(text) state.text[#state.text + 1] = text; event('dwrite', text) end,
  combo = function(label, index, _, options)
    state.comboRows[#state.comboRows + 1] = { label = label, index = index, options = options, disabled = state.disabledDepth > 0 }
    event('combo', label)
    local nextIndex = state.pendingCombo[label]
    if nextIndex ~= nil then state.pendingCombo[label] = nil; return nextIndex, nextIndex ~= index end
    return index, false
  end,
  checkbox = function(label, value)
    state.checkboxValues = state.checkboxValues or {}
    state.checkboxValues[label] = value
    event('checkbox', label)
    if state.pendingCheckbox == label then state.pendingCheckbox = nil; return true end
    return false
  end,
  button = function(label, size)
    state.buttonRows[#state.buttonRows + 1] = { label = label, width = size.x, height = size.y }
    event('button', label)
    if state.pendingButton == label then state.pendingButton = nil; return true end
    return false
  end,
  separator = function() event('separator') end,
  sameLine = function() event('sameLine') end,
  newLine = function() event('newLine') end,
  availableSpaceX = function() return state.availableWidth end,
  measureDWriteText = function(text)
    state.measuredTexts[#state.measuredTexts + 1] = text
    return vec2(#text * 8, 14)
  end,
  getCursor = function() return vec2(state.cursor.x, state.cursor.y) end,
  setCursor = function() end,
  getScrollX = function() return state.scroll.x end,
  getScrollY = function() return state.scroll.y end,
  windowSize = function() return state.windowSize end,
  windowPos = function() return state.windowPos end,
  cursorScreenPos = function() return vec2(state.windowPos.x + state.cursor.x, state.windowPos.y + state.cursor.y) end,
  itemRectMin = function() return vec2(0, 0) end,
  itemRectMax = function() return vec2(0, 0) end,
  textLineHeightWithSpacing = function() return 18 end,
  drawLine = function() end,
  dummy = function() end,
  drawRectFilled = function(...) event('fill', ...)
  end,
  drawRectFilledMultiColor = function(...)
    state.gradients[#state.gradients + 1] = { ... }
    event('gradient')
  end,
  beginChild = function(id)
    state.children[#state.children + 1] = id
    event('beginChild', id)
    return state.contentVisible
  end,
  endChild = function()
    assert(#state.children > 0, 'endChild without beginChild')
    local id = state.children[#state.children]
    state.children[#state.children] = nil
    event('endChild', id)
  end,
}

local persisted = { uiLanguage = 'en' }
local storage = { enabled = true }
_G.StorageManager = {
  getStorage_UI = function() return persisted end,
  getStorage_Global = function() return { uiLanguage = '' } end,
  getStorage = function() return storage end,
}
_G.RaceTrackManager = {
  getTrackName = function() return 'Mock Track' end,
  getSessionTypeName = function() return 'Practice' end,
}
_G.ColorManager = { RGBM_Colors = { WhiteSmoke = 'white-smoke', Red = 'red' } }
_G.UIManager = {
  drawAppNotRunningMessageInMainWindow = function() state.notRunningCalls = state.notRunningCalls + 1; event('not-running') end,
  drawUICarList = function() state.carListCalls = state.carListCalls + 1; event('car-list') end,
}
_G.SettingsWindow = {
  drawContent = function(tab, available)
    state.contentCalls = state.contentCalls or {}
    state.contentCalls[#state.contentCalls + 1] = { tab = tab, available = available, disabled = state.disabledDepth > 0 }
    event('content', tab)
  end,
}
_G.Constants = { APP_NAME = 'SimOpenTrackDay', APP_VERSION = '0.9.8', APP_AUTHOR = 'dreasgrech' }

package.loaded.Localization = nil
package.loaded.UIManager = nil
package.loaded.UIState = nil
for _, name in ipairs({ 'Theme', 'Style', 'Logo', 'Toggle' }) do
  package.loaded['lib/uilib/' .. name] = nil
end
local Localization = require('Localization')
local UIState = require('UIState')
local Theme = require('lib/uilib/Theme')
local MainWindow = require('MainWindow')

local function draw(shouldRun, missing, message)
  clearFrame()
  state.contentCalls = {}
  state.shouldRunCalls = 0
  MainWindow.draw(function()
    state.shouldRunCalls = state.shouldRunCalls + 1
    event('shouldAppRun')
    return shouldRun()
  end, missing, message)
  check(#state.children == 0, 'child window stack balanced after draw')
  check(#state.styles == 0, 'style-color stack balanced after draw')
  check(state.widthDepth == 0 and state.fontDepth == 0, 'item-width and font stacks balanced after draw')
  check(state.disabledDepth == 0, 'disabled stack balanced after draw')
end
local function findEvent(kind, value)
  for index, item in ipairs(state.events) do
    if item[1] == kind and (value == nil or item[2] == value) then return index end
  end
end
local function findCombo(id)
  for _, row in ipairs(state.comboRows) do if row.label:find('###' .. id, 1, true) then return row end end
end
local function visibleId(label)
  return label:match('^(.-)###(.*)$')
end

check(UIState.activeTab == 'Overview', 'tab singleton defaults to transient Overview')
check(Theme.colors.text.r == 1 and Theme.colors.text.g == 1 and Theme.colors.text.b == 1,
  'UI text base color remains white in the shared Theme')

local canRun = true
draw(function() return canRun end, false, nil)
check(#state.contentCalls == 1 and state.contentCalls[1].tab == 'Overview' and state.contentCalls[1].available,
  'Overview content receives the three-argument MainWindow callback availability')
check(state.carListCalls == 1, 'operational overview includes the car-list action')
check(#state.gradients == 1 and state.events[1][1] == 'fill', 'header gradient primitive follows the base fill')
check(state.gradients[1][3] == Theme.colors.headerGradientTopLeft and
  state.gradients[1][4] == Theme.colors.headerGradientTopRight and
  state.gradients[1][5] == Theme.colors.headerGradientBottomRight and
  state.gradients[1][6] == Theme.colors.headerGradientBottomLeft,
  'header uses static Theme gradient colors through drawRectFilledMultiColor')
local selectedTabUsesWhiteText = false
for _, push in ipairs(state.stylePushes) do
  if push.index == styleColor.Text and push.value == Theme.colors.white then selectedTabUsesWhiteText = true end
end
check(selectedTabUsesWhiteText, 'selected navigation text uses the static white Theme color')
check(findEvent('beginChild', 'mainPageContent') < findEvent('content', 'Overview') and
  findEvent('content', 'Overview') < findEvent('endChild', 'mainPageContent'),
  'child content begins, draws, and ends in order')
check(findEvent('checkbox', 'Enabled###settings.app.enabled') < findEvent('combo', 'Language###settings.language') and
  findEvent('combo', 'Language###settings.language') < findEvent('shouldAppRun'),
  'global enable and language controls precede the operational availability guard')
check(state.checkboxValues['Enabled###settings.app.enabled'] == true,
  'global enable checkbox exposes the real Enabled state and stable ID')
check(findCombo('settings.language') ~= nil, 'language control retains stable ID')
local mainWindowSourceFile = assert(io.open('MainWindow.lua', 'rb'))
local mainWindowSource = mainWindowSourceFile:read('*a')
mainWindowSourceFile:close()
check(not mainWindowSource:find('openSettingsWindow', 1, true),
  'single MainWindow no longer opens or delegates to a separate Settings window')
local footer = table.concat(state.wrapped, '\n')
check(footer:find('SimOpenTrackDay v0.9.8 by dreasgrech', 1, true) ~= nil,
  'MainWindow footer formats the existing app-name/version/author constants')

-- The measured selected-label marker participates in navigation width, including gaps.
state.availableWidth = 1200
UIState.activeTab = 'Overview'
draw(function() return true end, false, nil)
local expectedTabWidth = 0
for index, label in ipairs({ 'Overview  ✓', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }) do
  expectedTabWidth = expectedTabWidth + #label * 8 + Theme.spacing.lg
  if index > 1 then expectedTabWidth = expectedTabWidth + Theme.spacing.sm end
end
local measuredSelectedMarker = false
for _, label in ipairs(state.measuredTexts) do
  if label == 'Overview  ✓' then measuredSelectedMarker = true end
end
check(measuredSelectedMarker, 'selected-tab marker is included in the measured navigation label')
state.availableWidth = expectedTabWidth
draw(function() return true end, false, nil)
check(findCombo('main.tabs') == nil,
  'navigation uses buttons at the exact measured tab widths plus inter-tab gaps')
state.availableWidth = expectedTabWidth - 1
draw(function() return true end, false, nil)
check(findCombo('main.tabs') ~= nil,
  'navigation switches to compact combo one pixel below measured widths plus gaps')
state.availableWidth = 1200

-- Style.windowBegin pins the fill to the viewport with nonzero scroll and window position.
state.cursor, state.scroll = vec2(-37, -91), vec2(37, 91)
state.windowPos, state.windowSize = vec2(431, 217), vec2(900, 700)
draw(function() return true end, false, nil)
local viewportFill
for _, item in ipairs(state.events) do
  if item[1] == 'fill' and item[4] == Theme.colors.bg then viewportFill = item end
end
check(viewportFill ~= nil and viewportFill[2].x == 0 and viewportFill[2].y == 0 and
  viewportFill[3].x == 900 and viewportFill[3].y == 700,
  'scrolled viewport fill covers the full window-local viewport from cursor plus scroll')
check(viewportFill ~= nil and state.windowPos.x ~= 0 and state.windowPos.y ~= 0 and
  state.windowPos.x + viewportFill[2].x == state.windowPos.x and
  state.windowPos.y + viewportFill[2].y == state.windowPos.y,
  'viewport fill maps to the nonzero window screen origin')
state.cursor, state.scroll = vec2(0, 0), vec2(0, 0)
state.windowPos, state.windowSize = vec2(0, 0), vec2(1024, 768)

-- Wide navigation uses the five stable button IDs and updates the singleton.
state.availableWidth = 1760
state.pendingButton = 'Behavior###main.tab.behavior'
draw(function() return true end, false, nil)
check(UIState.activeTab == 'Behavior' and state.contentCalls[1].tab == 'Behavior',
  'wide navigation changes to Behavior before drawing content')
local navIDs = {}
for _, row in ipairs(state.buttonRows) do
  local _, id = visibleId(row.label)
  if id and id:match('^main%.tab%.') then navIDs[id] = true end
end
for _, id in ipairs({ 'main.tab.overview', 'main.tab.behavior', 'main.tab.yielding', 'main.tab.overtaking', 'main.tab.advanced' }) do
  check(navIDs[id], 'wide tab retains stable ID ' .. id)
end

-- Compact navigation at narrow width is a localized options-only combo.
state.availableWidth = 80
state.pendingCombo['Navigation###main.tabs'] = 3
draw(function() return true end, false, nil)
check(findCombo('main.tabs') ~= nil and UIState.activeTab == 'Yielding' and
  state.contentCalls[1].tab == 'Yielding', 'compact navigation selection changes active tab')
local navigationCombo = findCombo('main.tabs')
check(navigationCombo and navigationCombo.options[1] == 'Overview' and
  navigationCombo.options[2] == 'Behavior' and navigationCombo.options[5] == 'Advanced',
  'compact navigation presents translated tab text without IDs')
check(navigationCombo and navigationCombo.disabled == false, 'navigation remains operable at narrow width')

-- Language changes persist from the global header, including while the app is unavailable.
state.pendingCombo['Language###settings.language'] = 2
draw(function() return false end, false, nil)
check(persisted.uiLanguage == 'pt-BR' and Localization.getLocale() == 'pt-BR',
  'header language selection persists through Localization and app-independent UI storage')
check(findCombo('settings.language') and findCombo('main.tabs') and
  findCombo('main.tabs').options[1] == 'Visão geral',
  'header and compact tab navigation remain localized with stable IDs')
check(state.notRunningCalls == 1 and not state.contentCalls[1].available,
  'offline/disabled app retains navigation while operational content is unavailable')
local online = true
storage.enabled = true
draw(function() return storage.enabled and not online end, false, nil)
check(state.notRunningCalls == 1 and not state.contentCalls[1].available and
  findCombo('settings.language') ~= nil,
  'online/unavailable callback retains header controls while disabling operational content')

-- Verify tab and language controls remain operable across all supported layouts/locales.
for localeIndex, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  for _, width in ipairs({ 80, 480, 700, 900, 1200, 1760 }) do
    state.availableWidth = width
    UIState.activeTab = 'Overview'
    state.pendingCombo[Localization.label('Language', 'settings.language')] = localeIndex
    draw(function() return true end, false, nil)
    check(Localization.getLocale() == locale and findCombo('settings.language') ~= nil,
      string.format('global language control remains available at %d px in %s (actual %s, combo %s)',
        width, locale, tostring(Localization.getLocale()), tostring(findCombo('settings.language') ~= nil)))
    local nav = findCombo('main.tabs')
    if nav then
      check(nav.disabled == false and #nav.options == 5,
        string.format('compact navigation is operable and complete at %d px in %s', width, locale))
      state.pendingCombo[Localization.label('Navigation', 'main.tabs')] = 4
    else
      local expectedBehavior = Localization.label('Behavior', 'main.tab.behavior')
      state.pendingButton = expectedBehavior
      local buttonFound = false
      for _, row in ipairs(state.buttonRows) do
        if row.label:find('###main.tab.behavior', 1, true) then buttonFound = true end
      end
      check(buttonFound, string.format('wide navigation includes stable Behavior ID at %d px in %s', width, locale))
    end
    draw(function() return true end, false, nil)
    if nav then
      check(UIState.activeTab == 'Overtaking' and state.contentCalls[1].tab == 'Overtaking',
        string.format('compact tab selection works at %d px in %s', width, locale))
    else
      check(UIState.activeTab == 'Behavior' and state.contentCalls[1].tab == 'Behavior',
        string.format('button tab selection works at %d px in %s', width, locale))
    end
  end
end
state.availableWidth = 1200

-- Reload the presentation modules and verify MainWindow restores the persisted locale.
package.loaded.Localization = nil
package.loaded.MainWindow = nil
package.loaded['lib/uilib/Toggle'] = nil
Localization = require('Localization')
MainWindow = require('MainWindow')
draw(function() return true end, false, nil)
check(persisted.uiLanguage == 'es' and Localization.getLocale() == 'es' and
  findCombo('settings.language') and findCombo('settings.language').index == 3,
  'MainWindow reload restores persisted locale and its selected language control')

-- CSP missing state disables content but leaves header, language, and navigation active.
state.availableWidth = 480
draw(function() return true end, true, 'Required CSP item missing')
check(state.contentCalls[1] and not state.contentCalls[1].available and state.carListCalls == 0,
  'missing CSP requirements disable operational content and hide car list action')
check(findCombo('settings.language') and findCombo('main.tabs') and state.disabledDepth == 0,
  'header controls and tab navigation remain active with missing CSP requirements')
check(table.concat(state.wrapped, '\n'):find('Required CSP item missing', 1, true) ~= nil,
  'CSP message remains visible in the header')

-- Re-enabling is recalculated in the same draw after the header toggle.
storage.enabled = false
draw(function() return storage.enabled end, false, nil)
local disabledControlLabel = Localization.label('Disabled', 'settings.app.enabled')
check(findEvent('checkbox', disabledControlLabel) ~= nil and state.checkboxValues[disabledControlLabel] == false,
  'global disabled checkbox exposes its real state and stable ID')
state.pendingCheckbox = Localization.label('Disabled', 'settings.app.enabled')
draw(function() return storage.enabled end, false, nil)
check(storage.enabled and state.contentCalls[1].available,
  'same-frame header enable recalculates shouldAppRun before content draw')
local enabledControlLabel = Localization.label('Enabled', 'settings.app.enabled')
check(findEvent('checkbox', disabledControlLabel) ~= nil and state.checkboxValues[disabledControlLabel] == false and storage.enabled,
  'clicking the Disabled global checkbox preserves its stable ID and enables storage in-frame')
draw(function() return storage.enabled end, false, nil)
check(findEvent('checkbox', enabledControlLabel) ~= nil and state.checkboxValues[enabledControlLabel] == true,
  'next frame displays the real Enabled checkbox state with unchanged stable ID')
check(state.notRunningCalls == 0, 'same-frame enable removes the not-running message')

-- A collapsed/hidden child skips content and still balances begin/end.
state.contentVisible = false
draw(function() return true end, false, nil)
check(#state.contentCalls == 0 and findEvent('beginChild', 'mainPageContent') < findEvent('endChild', 'mainPageContent'),
  'hidden child skips content but always calls endChild')
state.contentVisible = true

-- UIState is transient: reloading its module returns to the default tab.
UIState.activeTab = 'Advanced'
package.loaded.UIState = nil
local reloadedUIState = require('UIState')
check(reloadedUIState.activeTab == 'Overview', 'active tab resets on module reload rather than persisting')

-- Preserve the protected manifest callback and its user-facing draw-error report.
local entryFile = assert(io.open('SimOpenTrackDay.lua', 'rb'))
local entrySource = entryFile:read('*a')
entryFile:close()
local declaration = 'function script.MANIFEST__FUNCTION_MAIN(dt)'
local startAt = assert(entrySource:find(declaration, 1, true), 'one-window entry callback declaration remains')
local finishAt = assert(entrySource:find('\nend', startAt, true), 'main callback terminator remains')
local callbackSource = entrySource:sub(startAt, finishAt + 4)
local callbackChunk = assert(loadstring([[
  local script = {}
  local MainWindow = ...
  local shouldAppRun = select(2, ...)
  local anyMissingCSPElements = select(3, ...)
  local missingCSPElementsErrorMessage = select(4, ...)
  local ac = select(5, ...)
  local debug = _G.debug
]] .. '\n' .. callbackSource .. '\nreturn script.MANIFEST__FUNCTION_MAIN'))
local callbackErrors = {}
local suppliedShouldRun = function() return true end
local callback = callbackChunk(MainWindow, suppliedShouldRun, true, 'entry CSP message', {
  error = function(message) callbackErrors[#callbackErrors + 1] = message end,
})
local operationalCallback = callbackChunk(MainWindow, suppliedShouldRun, false, nil, {
  error = function(message) callbackErrors[#callbackErrors + 1] = message end,
})
callback(0)
check(#callbackErrors == 0 and state.shouldRunCalls > 0,
  'entry callback delegates the three-argument MainWindow contract inside xpcall')

local originalContent = SettingsWindow.drawContent
SettingsWindow.drawContent = function() error('injected SettingsWindow.drawContent failure') end
callback(0)
local settingsError = callbackErrors[#callbackErrors]
check(settingsError:find('UI draw failed:', 1, true) and
  settingsError:find('injected SettingsWindow.drawContent failure', 1, true) and
  settingsError:find('stack traceback:', 1, true),
  'entry callback preserves the SettingsWindow error and traceback')
check(#state.children == 0 and state.fontDepth == 0 and #state.styles == 0,
  'SettingsWindow failure rethrows original error after child/font/style cleanup')
SettingsWindow.drawContent = originalContent

local originalCarList = UIManager.drawUICarList
UIManager.drawUICarList = function() error('injected UIManager.drawUICarList failure') end
UIState.activeTab = 'Overview'
operationalCallback(0)
local carListError = callbackErrors[#callbackErrors]
check(carListError:find('UI draw failed:', 1, true) and
  carListError:find('injected UIManager.drawUICarList failure', 1, true) and
  carListError:find('stack traceback:', 1, true),
  'entry callback preserves the car-list error and traceback')
check(#state.children == 0 and state.fontDepth == 0 and #state.styles == 0,
  'car-list failure rethrows original error after child/font/style cleanup')
UIManager.drawUICarList = originalCarList

print(string.format('MainWindow headless checks passed: %d checks.', checks))
