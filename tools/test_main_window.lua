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
  fontDepth = 0, dwriteFontDepth = 0, nativeFontDepth = 0, fontStack = {}, fontPushes = {},
  childFontStacks = {},
  wrappedFonts = {}, availableWidth = 1200, contentVisible = true,
  measureRequests = {},
  cursor = vec2(8, 8), scroll = vec2(0, 0), windowSize = vec2(1024, 768), windowPos = vec2(0, 0),
  preserveCursorForNextDraw = false,
  pendingButton = nil, pendingCheckbox = nil, pendingCombo = {},
  windowOpenCalls = {},
  comboRows = {}, buttonRows = {}, text = {}, wrapped = {}, gradients = {}, measuredTexts = {},
  dwriteRows = {}, columnLayouts = {}, columnWidths = {},
  headerColumns = false, headerColumnIndex = 0, headerColumnCount = 0,
  shouldRunCalls = 0, carListCalls = 0, notRunningCalls = 0, errors = 0,
  clipDepth = 0, clipRects = {}, nativeMeasureRequests = {}, tooltips = {}, hovered = false,
  throwBackgroundFill = false,
}
local function event(kind, ...)
  state.events[#state.events + 1] = { kind, ... }
end
local function clearFrame()
  state.events, state.children, state.comboRows, state.buttonRows = {}, {}, {}, {}
  state.childFontStacks = {}
  state.text, state.wrapped, state.wrappedFonts, state.gradients = {}, {}, {}, {}
  state.dwriteRows, state.columnLayouts, state.columnWidths = {}, {}, {}
  state.measuredTexts = {}
  state.fontPushes = {}
  state.measureRequests = {}
  state.clipRects, state.nativeMeasureRequests, state.tooltips = {}, {}, {}
  state.headerColumns, state.headerColumnIndex, state.headerColumnCount = false, 0, 0
  state.headerColumnWidths = {}
  state.carListCalls, state.notRunningCalls = 0, 0
end
local throwFooterText = false

_G.ui = {
  ComboFlags = { None = 0 }, SelectableFlags = { None = 0 },
  Font = { Title = 'title-font', Main = 'main-font' },
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
  pushDWriteFont = function(font)
    assert(font == 'Segoe UI', 'legacy DWrite stack retains its named font')
    state.dwriteFontDepth = state.dwriteFontDepth + 1
    state.fontDepth = state.dwriteFontDepth + state.nativeFontDepth
    event('dwrite-font+', font)
  end,
  popDWriteFont = function()
    assert(state.dwriteFontDepth > 0, 'DWrite font stack underflow')
    state.dwriteFontDepth = state.dwriteFontDepth - 1
    state.fontDepth = state.dwriteFontDepth + state.nativeFontDepth
    event('dwrite-font-')
  end,
  pushFont = function(font)
    assert(font == ui.Font.Title or font == ui.Font.Main, 'pushFont requires a declared application font role')
    state.fontStack[#state.fontStack + 1] = font
    state.nativeFontDepth = #state.fontStack
    state.fontDepth = state.dwriteFontDepth + state.nativeFontDepth
    state.fontPushes[#state.fontPushes + 1] = font
    event('font+', font)
  end,
  popFont = function()
    assert(#state.fontStack > 0, 'font stack underflow')
    local popped = state.fontStack[#state.fontStack]
    state.fontStack[#state.fontStack] = nil
    state.nativeFontDepth = #state.fontStack
    state.fontDepth = state.dwriteFontDepth + state.nativeFontDepth
    event('font-', popped)
  end,
  pushItemWidth = function(width) state.widthDepth = state.widthDepth + 1; state.itemWidth = width; event('width+', width) end,
  popItemWidth = function() assert(state.widthDepth > 0); state.widthDepth = state.widthDepth - 1; event('width-') end,
  pushDisabled = function() state.disabledDepth = state.disabledDepth + 1 end,
  popDisabled = function() assert(state.disabledDepth > 0); state.disabledDepth = state.disabledDepth - 1 end,
  text = function(text) state.text[#state.text + 1] = text; event('text', text) end,
  textWrapped = function(text)
    if throwFooterText and state.fontStack[#state.fontStack] == ui.Font.Main then
      error('injected footer text failure')
    end
    state.wrapped[#state.wrapped + 1] = text
    state.wrappedFonts[#state.wrappedFonts + 1] = state.fontStack[#state.fontStack]
    event('wrapped', text)
  end,
  textColored = function(text) state.text[#state.text + 1] = text; event('colored', text) end,
  dwriteText = function(text)
    state.text[#state.text + 1] = text
    state.dwriteRows[#state.dwriteRows + 1] = { text = text, font = state.fontStack[#state.fontStack], x = state.cursor.x, y = state.cursor.y }
    state.cursor.x = state.cursor.x + #text * 8
    event('dwrite', text)
  end,
  combo = function(label, index, _, options)
    state.comboRows[#state.comboRows + 1] = { label = label, index = index, options = options, disabled = state.disabledDepth > 0, font = state.fontStack[#state.fontStack] }
    event('combo', label)
    local nextIndex = state.pendingCombo[label]
    if nextIndex ~= nil then state.pendingCombo[label] = nil; return nextIndex, nextIndex ~= index end
    return index, false
  end,
  checkbox = function(label, value)
    state.checkboxValues = state.checkboxValues or {}
    state.checkboxValues[label] = value
    state.checkboxFonts = state.checkboxFonts or {}
    state.checkboxFonts[label] = state.fontStack[#state.fontStack]
    event('checkbox', label)
    if state.pendingCheckbox == label then state.pendingCheckbox = nil; return true end
    return false
  end,
  button = function(label, size)
    state.buttonRows[#state.buttonRows + 1] = { label = label, width = size.x, height = size.y, x = state.cursor.x, y = state.cursor.y, font = state.fontStack[#state.fontStack] }
    event('button', label)
    state.lastButton = label
    if state.pendingButton == label then state.pendingButton = nil; return true end
    return false
  end,
  separator = function() event('separator') end,
  columns = function(count, border, id)
    state.columnLayouts[#state.columnLayouts + 1] = { count = count, border = border, id = id }
    if id == 'headerControls' then
      state.headerColumns, state.headerColumnIndex, state.headerColumnCount = true, 0, count
      state.headerColumnWidths = {}
    elseif count == 1 and state.headerColumns then
      state.headerColumns = false
    end
  end,
  setColumnWidth = function(index, width)
    state.columnWidths[#state.columnWidths + 1] = { index = index, width = width }
    if state.headerColumns then state.headerColumnWidths[index + 1] = width end
  end,
  nextColumn = function()
    if state.headerColumns then state.headerColumnIndex = state.headerColumnIndex + 1 end
    event('nextColumn')
  end,
  windowWidth = function() return state.windowSize.x end,
  sameLine = function(_, gap) state.cursor.x = state.cursor.x + (gap or 0); event('sameLine') end,
  newLine = function() event('newLine') end,
  availableSpaceX = function()
    if state.headerColumns then
      local total = math.min(state.availableWidth, state.windowSize.x)
      local index = state.headerColumnIndex + 1
      local columnWidth = state.headerColumnWidths[index]
      if not columnWidth then
        columnWidth = total
        for i = 1, index - 1 do columnWidth = columnWidth - (state.headerColumnWidths[i] or 0) end
      end
      return math.max(0, math.min(columnWidth, total))
    end
    return state.availableWidth
  end,
  measureDWriteText = function(text, size, wrap)
    state.measuredTexts[#state.measuredTexts + 1] = text
    state.measureRequests[#state.measureRequests + 1] = { text = text, size = size, wrap = wrap }
    return vec2(#text * 8, 14)
  end,
  measureText = function(text, wrap)
    state.nativeMeasureRequests[#state.nativeMeasureRequests + 1] = {
      text = text, wrap = wrap, font = state.fontStack[#state.fontStack], width = #text * 12,
    }
    return vec2(#text * 12, 20)
  end,
  itemHovered = function() return state.hovered end,
  setTooltip = function(text) state.tooltips[#state.tooltips + 1] = text end,
  getCursor = function() return vec2(state.cursor.x, state.cursor.y) end,
  setCursor = function(position) state.cursor = vec2(position.x, position.y) end,
  getScrollX = function() return state.scroll.x end,
  getScrollY = function() return state.scroll.y end,
  windowSize = function() return state.windowSize end,
  windowPos = function() return state.windowPos end,
  cursorScreenPos = function() return vec2(state.windowPos.x + state.cursor.x, state.windowPos.y + state.cursor.y) end,
  itemRectMin = function() return vec2(0, 0) end,
  itemRectMax = function() return vec2(0, 0) end,
  textLineHeightWithSpacing = function() return 18 end,
  drawLine = function(...) event('drawLine', ...) end,
  dummy = function(size) state.cursor.x = state.cursor.x + size.x end,
  drawRectFilled = function(p1, p2, color, ...)
    if state.throwBackgroundFill and color == require('lib/uilib/Theme').colors.bg then
      error('injected app background fill failure')
    end
    event('fill', p1, p2, color, ...)
  end,
  pushClipRect = function(p1, p2, intersect)
    state.clipDepth = state.clipDepth + 1
    state.clipRects[#state.clipRects + 1] = { p1 = p1, p2 = p2, intersect = intersect }
    event('clip+', p1, p2, intersect)
  end,
  popClipRect = function()
    assert(state.clipDepth > 0, 'clip stack underflow')
    state.clipDepth = state.clipDepth - 1
    event('clip-')
  end,
  drawRectFilledMultiColor = function(...)
    state.gradients[#state.gradients + 1] = { ... }
    event('gradient')
  end,
  beginChild = function(id)
    state.children[#state.children + 1] = id
    local nativeStack = {}
    for i, font in ipairs(state.fontStack) do nativeStack[i] = font end
    state.childFontStacks[#state.children] = nativeStack
    event('beginChild', id)
    return state.contentVisible
  end,
  endChild = function()
    assert(#state.children > 0, 'endChild without beginChild')
    local expectedFontStack = state.childFontStacks[#state.children]
    assert(#state.fontStack == #expectedFontStack, 'native font stack depth must match beginChild at endChild')
    for i, font in ipairs(expectedFontStack) do
      assert(state.fontStack[i] == font, 'native font stack must match beginChild at endChild')
    end
    local id = state.children[#state.children]
    state.children[#state.children] = nil
    state.childFontStacks[#state.childFontStacks] = nil
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
_G.ac = {
  setWindowOpen = function(id, open) state.windowOpenCalls[#state.windowOpenCalls + 1] = { id = id, open = open } end,
}
_G.RaceTrackManager = {
  getTrackName = function() return 'Mock Track' end,
  getSessionTypeName = function() return 'Practice' end,
}
_G.ColorManager = { RGBM_Colors = { WhiteSmoke = 'white-smoke', Red = 'red' } }
_G.UIManager = {
  drawAppNotRunningMessageInMainWindow = function() state.notRunningCalls = state.notRunningCalls + 1; event('not-running') end,
  drawUICarList = function() state.carListCalls = state.carListCalls + 1; event('car-list') end,
  drawMainWindowLateralOffsetsSection = function() event('lanes') end,
}
_G.SettingsWindow = {
  drawContent = function(tab, available)
    state.contentCalls = state.contentCalls or {}
    state.contentCalls[#state.contentCalls + 1] = { tab = tab, available = available, disabled = state.disabledDepth > 0 }
    state.contentCalls[#state.contentCalls].font = state.fontStack[#state.fontStack]
    event('content', tab)
  end,
}
_G.Constants = { APP_NAME = 'SimOpenTrackDay', APP_VERSION = '0.1', APP_AUTHOR = 'dreasgrech', APP_DEVELOPER = 'SnakeD' }

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

local manifestFile = assert(io.open('manifest.ini', 'rb'))
local manifest = manifestFile:read('*a')
manifestFile:close()
local windowSection = manifest:match('%[WINDOW_0%]([%s%S]-)%[')
check(windowSection and windowSection:find('ID = mainWindow', 1, true) and
  windowSection:find('FUNCTION_MAIN = MANIFEST__FUNCTION_MAIN', 1, true) and
  windowSection:find('FUNCTION_ICON = MANIFEST__FUNCTION_ICON', 1, true) and
  windowSection:find('SIZE = 1024, 768', 1, true),
  'chrome flags preserve the main window ID, callbacks, and declared initial size')
check(windowSection and windowSection:find('FLAGS = NO_TITLE_BAR, NO_BACKGROUND, NO_COLLAPSE', 1, true) and
  windowSection:find('PADDING = 8, 8', 1, true) and Theme.layout.windowInset == 8 and
  not windowSection:find('FIXED_SIZE', 1, true) and not windowSection:find('NO_MOVE', 1, true) and
  not windowSection:find('NO_INPUTS', 1, true),
  'manifest chrome flags request no native title/background without disabling movement or resize')

local function draw(shouldRun, missing, message)
  clearFrame()
  if state.preserveCursorForNextDraw then
    state.preserveCursorForNextDraw = false
  else
    state.cursor = vec2(8, 8)
  end
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
  check(state.clipDepth == 0, 'temporary background clip is balanced after draw')
  check(state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
    'legacy DWrite and native font stacks balance independently after draw')
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
local closeID = Localization.label('Close', 'main.window.close')
local closeButton
for _, row in ipairs(state.buttonRows) do if row.label == closeID then closeButton = row end end
check(closeButton and closeButton.width > 0 and closeButton.width <= state.availableWidth and
  closeButton.x + closeButton.width == 8 + state.availableWidth,
  'visible header close control keeps its stable ID and fits the main content width')
check(#state.gradients == 1 and findEvent('clip+') < findEvent('fill') and findEvent('fill') < findEvent('clip-'),
  'background fill is clipped to the viewport and restores the prior clip before header drawing')
check(state.clipRects[1] and state.clipRects[1].p1.x == 0 and state.clipRects[1].p1.y == 0 and
  state.clipRects[1].p2.x == state.windowSize.x and state.clipRects[1].p2.y == state.windowSize.y and
  state.clipRects[1].intersect == false,
  'background fill uses a non-intersecting clip limited to the window viewport')
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
local expectedFooter = Localization.text('%s v%s | developed by %s | original author: %s',
  Constants.APP_NAME, Constants.APP_VERSION, Constants.APP_DEVELOPER, Constants.APP_AUTHOR)
check(footer:find(expectedFooter, 1, true) ~= nil and footer:find('SnakeD', 1, true) ~= nil and
  footer:find('dreasgrech', 1, true) ~= nil,
  'MainWindow footer contains app identity, current developer, and original author')
local usedTitleFont, usedMainFont = false, false
for _, font in ipairs(state.fontPushes) do
  if font == ui.Font.Title then usedTitleFont = true end
  if font == ui.Font.Main then usedMainFont = true end
end
check(usedTitleFont and usedMainFont, 'rendered header/navigation and controls use explicit Title and Main font roles')
check(state.checkboxFonts['Enabled###settings.app.enabled'] == ui.Font.Title and
  findCombo('settings.language').font == ui.Font.Title and state.contentCalls[1].font == ui.Font.Title,
  'enabled, language, and settings content controls use Title font scope')
check(state.wrappedFonts[#state.wrappedFonts] == ui.Font.Main,
  'footer credit text is rendered under Main font scope')
local titleNavButtons = 0
for _, row in ipairs(state.buttonRows) do
  local _, id = row.label:match('^(.-)###(.*)$')
  if id and id:match('^main%.tab%.') then
    titleNavButtons = titleNavButtons + 1
    check(row.font == ui.Font.Title, 'navigation button uses Title font scope')
  end
end
check(titleNavButtons == 5, 'all five navigation buttons render in Title font scope')
local titleHeader = false
for _, row in ipairs(state.dwriteRows) do
  if row.text == 'SimOpenTrackDay' and row.font == ui.Font.Title then titleHeader = true end
end
check(titleHeader, 'main application title renders under the native Title font')
check(not pcall(ui.popFont), 'native font mock rejects underflow')

-- Exercise the real word-wrapping Toggle while retaining its native checkbox ID.
local Toggle = require('lib/uilib/Toggle')
state.availableWidth = 160
local longToggle = 'Enable the behavior controls while keeping the original stable identity###settings.long.toggle'
Toggle.render(longToggle, true)
local wrappedToggle
for label in pairs(state.checkboxValues) do
  if label:find('settings.long.toggle', 1, true) then wrappedToggle = label end
end
check(wrappedToggle and wrappedToggle:match('###settings.long%.toggle$') and wrappedToggle:find('\n', 1, true),
  'real Toggle wraps a long label into lines without changing its hidden ID')
check(state.checkboxValues[wrappedToggle] == true and #state.styles == 0,
  'wrapped label still uses the native checkbox and balances its styles')
state.availableWidth = 1200

state.availableWidth = 759
draw(function() return true end, false, nil)
local headerColumnsAt759 = false
for _, layout in ipairs(state.columnLayouts) do if layout.id == 'headerControls' then headerColumnsAt759 = true end end
check(not headerColumnsAt759, 'header avoids its three-column control layout below 760 px')
state.availableWidth = 760
draw(function() return true end, false, nil)
local headerColumnsAt760 = false
for _, layout in ipairs(state.columnLayouts) do
  if layout.id == 'headerControls' and layout.count == 3 then headerColumnsAt760 = true end
end
check(headerColumnsAt760 and #state.columnWidths == 2,
  'header uses three columns and two explicit widths starting at 760 px')

-- The native chrome is replaced with an explicit close action; closing does not
-- mutate app enablement or the transient active tab.
state.availableWidth = 1200
UIState.activeTab = 'Behavior'
storage.enabled = true
state.pendingButton = Localization.label('Close', 'main.window.close')
local windowCallsBeforeClose = #state.windowOpenCalls
draw(function() return true end, false, nil)
check(#state.windowOpenCalls == windowCallsBeforeClose + 1 and
  state.windowOpenCalls[#state.windowOpenCalls].id == 'mainWindow' and
  state.windowOpenCalls[#state.windowOpenCalls].open == false,
  'header close button requests mainWindow closed through ac.setWindowOpen')
check(storage.enabled and UIState.activeTab == 'Behavior',
  'closing the window leaves app enablement and active tab unchanged')

state.windowSize = vec2(480, 768)
state.availableWidth = 464
draw(function() return true end, false, nil)
local normalCloseButton, normalCloseEvent
for _, row in ipairs(state.buttonRows) do
  if row.label == Localization.label('Close', 'main.window.close') then normalCloseButton = row end
end
normalCloseEvent = findEvent('button', Localization.label('Close', 'main.window.close'))
local wordmarkRow
for _, row in ipairs(state.dwriteRows) do if row.text == 'SimOpenTrackDay' then wordmarkRow = row end end
local logoRight = 0
for _, item in ipairs(state.events) do
  if item[1] == 'drawLine' then logoRight = math.max(logoRight, item[2].x, item[3].x) end
end
check(normalCloseButton and normalCloseButton.width <= 464 and
  normalCloseButton.x + normalCloseButton.width == state.windowSize.x - Theme.layout.windowInset and
  normalCloseButton.y == Theme.layout.windowInset and wordmarkRow and
  logoRight <= wordmarkRow.x and
  wordmarkRow.x + ui.measureDWriteText('SimOpenTrackDay', Theme.type.title, -1).x + Theme.spacing.sm <= normalCloseButton.x,
  '480 px header positions Close at the right inset and reserves a non-overlapping brand rectangle')

-- At narrow content widths, hide branding that cannot fit beside the close
-- control instead of allowing the rectangles to overlap.
state.windowSize = vec2(80, 768)
state.availableWidth = 64
UIState.activeTab = 'Overview'
draw(function() return true end, false, nil)
local narrowClose, firstLogoLine
for index, item in ipairs(state.events) do
  if item[1] == 'drawLine' and not firstLogoLine then firstLogoLine = index end
end
for _, row in ipairs(state.buttonRows) do
  if row.label:match('###(.*)$') == 'main.window.close' then narrowClose = row end
end
check(narrowClose and narrowClose.width <= 64 and
  narrowClose.x >= Theme.layout.windowInset and
  narrowClose.x + narrowClose.width <= state.windowSize.x - Theme.layout.windowInset and
  not firstLogoLine,
  '80 px viewport keeps Close inside the inset and hides the brand when its rectangle cannot fit')

for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  Localization.setLocale(locale)
  state.windowSize, state.availableWidth = vec2(480, 768), 464
  draw(function() return true end, false, nil)
  local fullClose
  for _, row in ipairs(state.buttonRows) do
    if row.label:match('###(.*)$') == 'main.window.close' then fullClose = row end
  end
  local nativeCloseMeasure
  for _, request in ipairs(state.nativeMeasureRequests) do
    if request.text == Localization.text('Close') then nativeCloseMeasure = request end
  end
  local fullVisible, fullID
  if fullClose then fullVisible, fullID = fullClose.label:match('^(.-)###(.*)$') end
  check(fullClose and fullVisible == Localization.text('Close') and fullID == 'main.window.close' and
    nativeCloseMeasure and nativeCloseMeasure.font == ui.Font.Title and
    fullClose.width == nativeCloseMeasure.width + Theme.spacing.md,
    string.format('full close label uses current native font measurement and stable ID in %s', locale))
  local dwriteMeasuredClose = false
  for _, text in ipairs(state.measureRequests) do if text.text == Localization.text('Close') then dwriteMeasuredClose = true end end
  check(not dwriteMeasuredClose, 'close label width is not measured with the DirectWrite font')

  state.windowSize, state.availableWidth, state.hovered = vec2(80, 768), 64, true
  draw(function() return true end, false, nil)
  local compactClose
  for _, row in ipairs(state.buttonRows) do
    if row.label:match('###(.*)$') == 'main.window.close' then compactClose = row end
  end
  check(compactClose and compactClose.label == 'X###main.window.close' and
    compactClose.width == ui.measureText('X', -1).x + Theme.spacing.md and compactClose.width <= 64 and
    state.tooltips[#state.tooltips] == Localization.text('Close'),
    string.format('narrow close uses compact stable control and localized hover text in %s', locale))
  state.hovered = false
end
Localization.setLocale('en')
state.windowSize = vec2(1024, 768)
state.availableWidth = 1200

-- Navigation width follows the actual visible localized labels and Theme spacing,
-- regardless of whether selection is shown with a glyph or another treatment.
state.availableWidth = 1200
UIState.activeTab = 'Overview'
draw(function() return true end, false, nil)
local expectedTabWidth = 0
local measuredVisibleTabs = {}
for _, row in ipairs(state.buttonRows) do
  local visible, id = row.label:match('^(.-)###(.*)$')
  if id and id:match('^main%.tab%.') then measuredVisibleTabs[#measuredVisibleTabs + 1] = visible end
end
check(#measuredVisibleTabs == 5, 'navigation measurement is derived from five actual tab buttons, excluding header actions')
for index, visible in ipairs(measuredVisibleTabs) do
  expectedTabWidth = expectedTabWidth + #visible * 8 + Theme.spacing.lg
  if index > 1 then expectedTabWidth = expectedTabWidth + Theme.spacing.sm end
end
local measuredVisibleSelection = false
for _, text in ipairs(state.measuredTexts) do
  if text == measuredVisibleTabs[1] then measuredVisibleSelection = true end
end
check(measuredVisibleSelection, 'visible selected-tab label participates in navigation measurement')
for _, tab in ipairs({ 'Overview', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }) do
  local found = false
  for _, request in ipairs(state.measureRequests) do
    if request.text == tab then found = request.size == Theme.type.tab and request.wrap == -1 end
  end
  check(found, 'navigation measures visible ' .. tab .. ' text with Theme tab typography')
end
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
state.cursor, state.scroll = vec2(-29, -83), vec2(37, 91)
state.windowPos, state.windowSize = vec2(431, 217), vec2(900, 700)
state.preserveCursorForNextDraw = true
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
state.cursor, state.scroll = vec2(8, 8), vec2(0, 0)
state.windowPos, state.windowSize = vec2(0, 0), vec2(1024, 768)

state.throwBackgroundFill = true
clearFrame()
state.cursor = vec2(8, 8)
local backgroundOK, backgroundError = pcall(MainWindow.draw, function() return true end, false, nil)
state.throwBackgroundFill = false
check(not backgroundOK and tostring(backgroundError):find('injected app background fill failure', 1, true) and
  state.clipDepth == 0 and #state.styles == 0,
  'background draw error is rethrown after restoring viewport clip and style scopes')

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
state.pendingCombo['###main.tabs'] = 3
draw(function() return true end, false, nil)
check(findCombo('main.tabs') ~= nil and UIState.activeTab == 'Yielding' and
  state.contentCalls[1].tab == 'Yielding', 'compact navigation selection changes active tab: ' ..
  tostring(UIState.activeTab) .. ' / ' .. tostring(findCombo('main.tabs') and findCombo('main.tabs').label) ..
  ' / ' .. tostring(Localization.getLocale()))
local navigationCombo = findCombo('main.tabs')
check(navigationCombo and navigationCombo.options[1] == 'Overview' and
  navigationCombo.options[2] == 'Behavior' and navigationCombo.options[5] == 'Advanced',
  'compact navigation presents translated tab text without IDs')
check(navigationCombo and navigationCombo.disabled == false, 'navigation remains operable at narrow width')

-- Language changes persist from the global header, including while the app is unavailable.
state.pendingCombo['###settings.language'] = 2
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
    local languageComboLabel = width < 300 and '###settings.language' or Localization.label('Language', 'settings.language')
    state.pendingCombo[languageComboLabel] = localeIndex
    draw(function() return true end, false, nil)
    check(Localization.getLocale() == locale and findCombo('settings.language') ~= nil,
      string.format('global language control remains available at %d px in %s (actual %s, combo %s)',
         width, locale, tostring(Localization.getLocale()), tostring(findCombo('settings.language') ~= nil)))
    local localizedFooter = table.concat(state.wrapped, '\n')
    local expectedLocalizedFooter = Localization.text('%s v%s | developed by %s | original author: %s',
      Constants.APP_NAME, Constants.APP_VERSION, Constants.APP_DEVELOPER, Constants.APP_AUTHOR)
    check(localizedFooter:find(expectedLocalizedFooter, 1, true) ~= nil and
      localizedFooter:find('SnakeD', 1, true) ~= nil and localizedFooter:find('dreasgrech', 1, true) ~= nil,
      string.format('MainWindow footer preserves both credits in %s at %d px', locale, width))
    local nav = findCombo('main.tabs')
    if nav then
      check(nav.disabled == false and #nav.options == 5,
        string.format('compact navigation is operable and complete at %d px in %s', width, locale))
      state.pendingCombo[width < 300 and '###main.tabs' or Localization.label('Navigation', 'main.tabs')] = 4
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
check(state.dwriteFontDepth == 0 and state.nativeFontDepth == 0, 'both font stacks clean up after SettingsWindow error')
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
check(state.dwriteFontDepth == 0 and state.nativeFontDepth == 0, 'both font stacks clean up after car-list error')
UIManager.drawUICarList = originalCarList

throwFooterText = true
clearFrame()
local footerFailureOK, footerFailure = pcall(MainWindow.draw, function() return true end, false, nil)
check(not footerFailureOK and tostring(footerFailure):find('injected footer text failure', 1, true) ~= nil,
  'footer text failure is rethrown after protected drawing')
check(#state.children == 0 and state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
  'DWrite, native title, and footer Main font scopes clean up after footer error')
local footerPopEvent, childEndEvent
for index, item in ipairs(state.events) do
  if item[1] == 'font-' and item[2] == ui.Font.Main then footerPopEvent = index end
  if item[1] == 'endChild' and item[2] == 'mainPageContent' then childEndEvent = index end
end
check(footerPopEvent and childEndEvent and footerPopEvent < childEndEvent,
  'footer Main font pops before endChild after footer rendering error')
check(#state.styles == 0 and #state.childFontStacks == 0,
  'footer-error cleanup leaves style and child font snapshots balanced')
throwFooterText = false

-- Optional native stack APIs can be absent; legacy DWrite behavior remains safe.
local savedFont, savedPushFont, savedPopFont = ui.Font, ui.pushFont, ui.popFont
ui.Font, ui.pushFont, ui.popFont = nil, nil, nil
package.loaded.MainWindow = nil
MainWindow = require('MainWindow')
draw(function() return true end, true, 'Required CSP item missing (native-font fallback)')
check(state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
  'MainWindow remains drawable when optional native font APIs are absent')
check(table.concat(state.wrapped, '\n'):find('Required CSP item missing (native-font fallback)', 1, true) ~= nil,
  'native-font fallback still renders the existing CSP compatibility warning')
check(findCombo('settings.language') ~= nil and findCombo('main.tabs') ~= nil and
  state.checkboxValues['Enabled###settings.app.enabled'] == true,
  'native-font fallback retains default enabled, language, and navigation controls without crashing')
ui.Font, ui.pushFont, ui.popFont = savedFont, savedPushFont, savedPopFont

print(string.format('MainWindow headless checks passed: %d checks.', checks))
