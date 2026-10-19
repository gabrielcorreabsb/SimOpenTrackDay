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
  pendingButton = nil, pendingIconButton = nil, pendingCheckbox = nil, pendingCombo = {}, throwCombo = nil,
  iconRows = {}, idStack = {}, throwIconButton = false,
  windowOpenCalls = {},
  comboRows = {}, buttonRows = {}, checkboxRows = {}, wrappedRows = {}, text = {}, wrapped = {}, gradients = {}, measuredTexts = {},
  dwriteRows = {}, columnLayouts = {}, columnWidths = {},
  headerColumns = false, headerColumnIndex = 0, headerColumnCount = 0,
  shouldRunCalls = 0, carListCalls = 0, notRunningCalls = 0, errors = 0,
  clipDepth = 0, clipRects = {}, nativeMeasureRequests = {}, tooltips = {}, hovered = false,
  groupDepth = 0, throwBackgroundFill = false, throwLaneContent = false,
  throwContextText = false,
  lastItemMaxY = 0, separatorRows = {},
}
local function event(kind, ...)
  state.events[#state.events + 1] = { kind, ... }
end
local function wrappedLineCount(text, width)
  local lines = 0
  width = math.max(1, width or state.availableWidth)
  local charWidth = state.fontStack[#state.fontStack] == 'title-font' and 12 or 10
  for line in (text .. '\n'):gmatch('(.-)\n') do
    local explicitLines = 1
    for _ in line:gmatch('\n') do explicitLines = explicitLines + 1 end
    lines = lines + math.max(explicitLines, math.ceil(#line * charWidth / width))
  end
  return math.max(1, lines)
end
local function mockFontLineHeight()
  return state.fontStack[#state.fontStack] == 'title-font' and 24 or 18
end
local function advanceMockItem(height)
  state.lastItemMaxY = state.cursor.y + height
  state.cursor.y = state.lastItemMaxY + 2
end
local function clearFrame()
  state.events, state.children, state.comboRows, state.buttonRows = {}, {}, {}, {}
  state.iconRows, state.idStack = {}, {}
  state.childFontStacks = {}
  state.text, state.wrapped, state.wrappedFonts, state.gradients = {}, {}, {}, {}
  state.checkboxRows, state.wrappedRows = {}, {}
  state.coloredRows = {}
  state.dwriteRows, state.columnLayouts, state.columnWidths = {}, {}, {}
  state.measuredTexts = {}
  state.fontPushes = {}
  state.measureRequests = {}
  state.clipRects, state.nativeMeasureRequests, state.tooltips = {}, {}, {}
  state.headerColumns, state.headerColumnIndex, state.headerColumnCount = false, 0, 0
  state.headerColumnWidths = {}
  state.lastItemMaxY = 0
  state.separatorRows = {}
  state.carListCalls, state.notRunningCalls = 0, 0
end
local throwFooterText = false

_G.ui = {
  ComboFlags = { None = 0 }, SelectableFlags = { None = 0 },
  Font = { Title = 'title-font', Main = 'main-font' },
  Icons = { Cancel = 'cancel-icon' },
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
  pushID = function(value)
    state.idStack[#state.idStack + 1] = value
    event('id+', value)
  end,
  popID = function()
    assert(#state.idStack > 0, 'ID stack underflow')
    local value = state.idStack[#state.idStack]
    state.idStack[#state.idStack] = nil
    event('id-', value)
  end,
  pushItemWidth = function(width) state.widthDepth = state.widthDepth + 1; state.itemWidth = width; event('width+', width) end,
  popItemWidth = function() assert(state.widthDepth > 0); state.widthDepth = state.widthDepth - 1; event('width-') end,
  pushDisabled = function() state.disabledDepth = state.disabledDepth + 1 end,
  popDisabled = function() assert(state.disabledDepth > 0); state.disabledDepth = state.disabledDepth - 1 end,
  text = function(text) state.text[#state.text + 1] = text; event('text', text) end,
  textWrapped = function(text)
    if state.throwContextText and text:find('Mock Track', 1, true) then error('injected context text failure') end
    if throwFooterText and state.fontStack[#state.fontStack] == ui.Font.Main and text:find('SnakeD', 1, true) then
      error('injected footer text failure')
    end
    state.wrapped[#state.wrapped + 1] = text
    state.wrappedFonts[#state.wrappedFonts + 1] = state.fontStack[#state.fontStack]
    local row = { text = text, x = state.cursor.x, y = state.cursor.y, font = state.fontStack[#state.fontStack] }
    state.wrappedRows[#state.wrappedRows + 1] = row
    event('wrapped', text)
    row.height = wrappedLineCount(text, math.max(1, state.availableWidth - math.max(0, state.cursor.x - 8))) * mockFontLineHeight()
    advanceMockItem(row.height)
    row.bottom = state.lastItemMaxY
  end,
  textColored = function(text) state.text[#state.text + 1] = text; state.coloredRows = state.coloredRows or {}; state.coloredRows[#state.coloredRows + 1] = { text = text, font = state.fontStack[#state.fontStack], x = state.cursor.x, y = state.cursor.y }; event('colored', text); advanceMockItem(mockFontLineHeight()) end,
  beginGroup = function() state.groupDepth = state.groupDepth + 1; event('group+') end,
  endGroup = function()
    assert(state.groupDepth > 0, 'group stack underflow')
    state.groupDepth = state.groupDepth - 1
    event('group-')
  end,
  dwriteText = function(text)
    state.text[#state.text + 1] = text
    state.dwriteRows[#state.dwriteRows + 1] = { text = text, font = state.fontStack[#state.fontStack], x = state.cursor.x, y = state.cursor.y }
    state.cursor.x = state.cursor.x + #text * 8
    event('dwrite', text)
  end,
  combo = function(label, index, _, options)
    if state.throwCombo and label:find(state.throwCombo, 1, true) then error('injected combo failure: ' .. label) end
    state.comboRows[#state.comboRows + 1] = { label = label, index = index, options = options, disabled = state.disabledDepth > 0, font = state.fontStack[#state.fontStack], x = state.cursor.x, y = state.cursor.y, width = state.itemWidth, height = 32 }
    event('combo', label)
    advanceMockItem(32)
    state.comboRows[#state.comboRows].bottom = state.lastItemMaxY
    local nextIndex = state.pendingCombo[label]
    if nextIndex ~= nil then state.pendingCombo[label] = nil; return nextIndex, nextIndex ~= index end
    return index, false
  end,
  checkbox = function(label, value)
    state.checkboxValues = state.checkboxValues or {}
    state.checkboxValues[label] = value
    state.checkboxFonts = state.checkboxFonts or {}
    state.checkboxFonts[label] = state.fontStack[#state.fontStack]
    state.checkboxRows[#state.checkboxRows + 1] = { label = label, x = state.cursor.x, y = state.cursor.y }
    event('checkbox', label)
    local lines = select(2, label:gsub('\n', '\n')) + 1
    state.checkboxRows[#state.checkboxRows].height = lines * mockFontLineHeight()
    advanceMockItem(lines * mockFontLineHeight())
    state.checkboxRows[#state.checkboxRows].bottom = state.lastItemMaxY
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
  iconButton = function(iconID, size, color, bgColor, framePadding)
    if state.throwIconButton then error('injected iconButton failure') end
    local row = { icon = iconID, id = state.idStack[#state.idStack], width = size.x, height = size.y,
      x = state.cursor.x, y = state.cursor.y, font = state.fontStack[#state.fontStack],
      color = color, bgColor = bgColor, framePadding = framePadding }
    state.iconRows[#state.iconRows + 1] = row
    event('iconButton', row.id)
    advanceMockItem(size.y)
    row.bottom = state.lastItemMaxY
    if state.pendingIconButton == row.id then state.pendingIconButton = nil; return true end
    return false
  end,
  separator = function() state.separatorRows[#state.separatorRows + 1] = { y = state.cursor.y }; event('separator', state.cursor.y) end,
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
    return math.max(0, state.availableWidth - math.max(0, state.cursor.x - 8))
  end,
  measureDWriteText = function(text, size, wrap)
    state.measuredTexts[#state.measuredTexts + 1] = text
    state.measureRequests[#state.measureRequests + 1] = { text = text, size = size, wrap = wrap }
    return vec2(#text * 8, 14)
  end,
  measureText = function(text, wrap)
    local charWidth, lineHeight = state.fontStack[#state.fontStack] == 'title-font' and 12 or 10, mockFontLineHeight()
    local height = wrap and wrap > 0 and wrappedLineCount(text, wrap) * lineHeight or lineHeight
    local width = #text * charWidth
    state.nativeMeasureRequests[#state.nativeMeasureRequests + 1] = {
      text = text, wrap = wrap, font = state.fontStack[#state.fontStack], width = width, height = height,
    }
    return vec2(width, height)
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
  itemRectMax = function() return vec2(state.cursor.x, state.lastItemMaxY or 0) end,
  textLineHeightWithSpacing = function() return 18 end,
  drawLine = function(...) event('drawLine', ...) end,
  dummy = function(size) state.cursor.x = state.cursor.x + size.x end,
  drawRectFilled = function(p1, p2, color, ...)
    if state.throwBackgroundFill and color == require('lib/uilib/Theme').colors.bg then
      error('injected app background fill failure')
    end
    event('fill', p1, p2, color, ...)
  end,
  drawRect = function(...) event('outline', ...) end,
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
    assert(state.groupDepth == 0, 'endChild with an open group')
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
  drawMainWindowLateralOffsetsSection = function()
    event('lanes')
    if state.throwLaneContent then error('injected lane content failure') end
  end,
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
for _, name in ipairs({ 'Theme', 'Style', 'Logo', 'Toggle', 'Section' }) do
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
  check(state.groupDepth == 0, 'section groups balanced after draw')
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
local function countEvent(kind)
  local count = 0
  for _, item in ipairs(state.events) do if item[1] == kind then count = count + 1 end end
  return count
end
local function countDWriteText(text)
  local count = 0
  for _, row in ipairs(state.dwriteRows) do if row.text == text then count = count + 1 end end
  return count
end
local function countNativeTitle(text)
  local count = 0
  for _, row in ipairs(state.coloredRows or {}) do
    if row.text == text and row.font == ui.Font.Title then count = count + 1 end
  end
  return count
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
local laneHeadingCount = 0
for _, row in ipairs(state.coloredRows or {}) do
  if row.text == Localization.text('Driving lanes') then laneHeadingCount = laneHeadingCount + 1 end
end
check(laneHeadingCount == 1 and findEvent('group+') < findEvent('lanes') and
  findEvent('lanes') < findEvent('group-') and findEvent('outline') ~= nil,
  'Overview wraps the UIManager lane-section stub in one shared Section group')
local nativeLaneMeasure, dwriteLaneTitle = false, false
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == Localization.text('Driving lanes') and request.font == ui.Font.Title then nativeLaneMeasure = true end
end
for _, row in ipairs(state.dwriteRows) do
  if row.text == Localization.text('Driving lanes') then dwriteLaneTitle = true end
end
check(nativeLaneMeasure and not dwriteLaneTitle,
  'Section title dimensions and rendering use the same native Title font, not DirectWrite')
local closeIcon
for _, row in ipairs(state.iconRows) do if row.id == 'main.window.close' then closeIcon = row end end
check(closeIcon and closeIcon.icon == ui.Icons.Cancel and closeIcon.width == Theme.layout.closeButtonSize and
  closeIcon.height == Theme.layout.closeButtonSize and closeIcon.framePadding == -1 and
  closeIcon.x + closeIcon.width == 8 + state.availableWidth and
  closeIcon.y + closeIcon.height / 2 == 8 + Theme.layout.headerTitleRowHeight / 2 and
  Theme.layout.closeButtonSize < Theme.layout.tabHeight,
  'native Cancel target is slightly smaller than tabs and centered in the unchanged title row')
check(#state.idStack == 0, 'icon close ID scope is balanced after drawing')
check(#state.gradients == 0 and findEvent('clip+') < findEvent('fill') and findEvent('fill') < findEvent('clip-'),
  'background fill is clipped to the viewport and restores the prior clip before header drawing')
check(state.clipRects[1] and state.clipRects[1].p1.x == 0 and state.clipRects[1].p1.y == 0 and
  state.clipRects[1].p2.x == state.windowSize.x and state.clipRects[1].p2.y == state.windowSize.y and
  state.clipRects[1].intersect == false,
  'background fill uses a non-intersecting clip limited to the window viewport')
local surfaceFillCount = 0
for _, item in ipairs(state.events) do
  if item[1] == 'fill' and item[4] == Theme.colors.surface then surfaceFillCount = surfaceFillCount + 1 end
end
check(surfaceFillCount >= 2 and #state.gradients == 0,
  'main header and Section use the same flat surface fill without decorative gradients')
local selectedTabUsesWhiteText = false
for _, push in ipairs(state.stylePushes) do
  if push.index == styleColor.Text and push.value == Theme.colors.white then selectedTabUsesWhiteText = true end
end
check(selectedTabUsesWhiteText, 'selected navigation text uses the static white Theme color')
local selectedButtonToken, quietButtonToken = false, false
for _, push in ipairs(state.stylePushes) do
  if push.index == styleColor.Button and push.value == Theme.button.selected.normal then selectedButtonToken = true end
  if push.index == styleColor.Button and push.value == Theme.button.quiet.normal then quietButtonToken = true end
end
check(selectedButtonToken and quietButtonToken,
  'existing tab buttons use shared selected and quiet state roles from Theme')
local StyleForButtons = require('lib/uilib/Style')
StyleForButtons.pushButton('disabled')
StyleForButtons.popButton()
check(#state.styles == 0 and state.stylePushes[#state.stylePushes].value == Theme.button.disabled.text,
  'shared disabled button role balances style scope and uses muted text')
check(findEvent('beginChild', 'mainPageContent') < findEvent('content', 'Overview') and
  findEvent('content', 'Overview') < findEvent('endChild', 'mainPageContent'),
  'child content begins, draws, and ends in order')
check(findEvent('checkbox', 'Enabled###settings.app.enabled') < findEvent('combo', '###settings.language') and
  findEvent('combo', '###settings.language') < findEvent('shouldAppRun'),
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
check(state.checkboxFonts['Enabled###settings.app.enabled'] == ui.Font.Main and
  findCombo('settings.language').font == ui.Font.Main and state.contentCalls[1].font == ui.Font.Title,
  'header controls use Main while existing settings content retains the Title scope')
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
for _, row in ipairs(state.coloredRows or {}) do
  if row.text == 'SimOpenTrackDay' and row.font == ui.Font.Title then titleHeader = true end
end
check(titleHeader, 'main application title renders under the native Title font without DirectWrite')
local titleMeasure, contextMeasure = false, false
local titleMeasureHeight, contextMeasureHeight
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == 'SimOpenTrackDay' and request.font == ui.Font.Title then titleMeasure, titleMeasureHeight = true, request.height end
  if request.text:find('Mock Track', 1, true) and request.font == ui.Font.Main then contextMeasure, contextMeasureHeight = true, request.height end
end
check(titleMeasure and contextMeasure and titleMeasureHeight > contextMeasureHeight,
  'header title and wrapped context are measured with distinct Title and Main native font roles')
local contextRow
for _, row in ipairs(state.wrappedRows) do if row.text:find('Mock Track', 1, true) then contextRow = row end end
check(contextRow and contextRow.font == ui.Font.Main,
  'track and session context renders in the native Main font')
local mutedContextStyle = false
for _, push in ipairs(state.stylePushes) do
  if push.index == styleColor.Text and push.value == Theme.colors.muted then mutedContextStyle = true end
end
check(mutedContextStyle, 'secondary track/session context uses the shared muted text color')
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

state.availableWidth = 1200

local function verifyHeaderGeometry(width, locale, wide)
  Localization.setLocale(locale)
  state.windowSize = vec2(width, 768)
  state.availableWidth = width - (2 * Theme.layout.windowInset)
  UIState.activeTab = 'Overview'
  draw(function() return true end, false, nil)
  local brand, context, enable, language, statusDot, headerFill, statusText
  for _, row in ipairs(state.coloredRows or {}) do
    if row.text == 'SimOpenTrackDay' then brand = row end
  end
  for _, row in ipairs(state.wrappedRows) do
    if row.text:find('Mock Track', 1, true) then context = row end
    if row.text == Localization.text('Language') then language = row end
    if row.text == Localization.text('Operational') or
      row.text == Localization.text('SimOpenTrackDay is not running.') then statusText = row end
  end
  for _, row in ipairs(state.checkboxRows) do
    if row.label:find('###settings.app.enabled', 1, true) then enable = row end
  end
  local languageCombo = findCombo('settings.language')
  for _, item in ipairs(state.events) do
    if item[1] == 'fill' and item[4] == Theme.colors.success then statusDot = { x = item[2].x, y = item[2].y - 5 } end
    if item[1] == 'fill' and item[4] == Theme.colors.surface and not headerFill then headerFill = item end
  end
  local headerLeft = Theme.layout.windowInset
  local headerRight = width - Theme.layout.windowInset
  check(brand and context and enable and language and languageCombo and statusDot and headerFill,
    string.format('header geometry elements exist at %d px in %s', width, locale))
  if not (brand and context and enable and language and languageCombo and statusDot and headerFill) then return end
  check(brand.x == headerLeft and enable.x == headerLeft and context.x == headerLeft and
    brand.y >= headerFill[2].y and
    brand.y + ui.measureText(brand.text, -1).y <= headerFill[2].y + Theme.layout.headerTitleRowHeight and
    context.y >= headerFill[2].y + Theme.layout.headerTitleRowHeight and
    context.y + ui.measureText(context.text, state.availableWidth).y <= headerFill[3].y,
    string.format('brand, session and controls share the header grid without crossing its background at %d px in %s', width, locale))
  check(languageCombo.x + languageCombo.width <= headerRight,
    string.format('language combo stays inside the content bounds at %d px in %s', width, locale))
  local firstHeaderSeparator = state.separatorRows[1]
  check(statusText and firstHeaderSeparator and
    firstHeaderSeparator.y > math.max(enable.bottom, languageCombo.bottom, statusText.bottom),
    string.format('header separator follows the measured checkbox, combo, and status bounds at %d px in %s', width, locale))
  if wide then
    check(enable.y == language.y and language.y == languageCombo.y and languageCombo.y == statusDot.y and
      enable.x < language.x and language.x < languageCombo.x and
      languageCombo.x + languageCombo.width < statusDot.x and statusDot.x < headerRight,
      string.format('wide enable, labeled language field and status share one aligned row at %d px in %s', width, locale))
  else
    check(enable.y < language.y and language.y == languageCombo.y and languageCombo.y < statusDot.y and
      enable.x == language.x and language.x == statusDot.x,
      string.format('narrow controls stack on a shared left grid without overlap at %d px in %s', width, locale))
  end
end

for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  verifyHeaderGeometry(900, locale, true)
  verifyHeaderGeometry(1200, locale, true)
  verifyHeaderGeometry(480, locale, false)
end
Localization.setLocale('en')

local function verifyHeaderVerticalBounds(warningStatus)
  Localization.setLocale('en')
  state.windowSize = vec2(900, 768)
  state.availableWidth = 900 - (2 * Theme.layout.windowInset)
  storage.enabled = true
  draw(function() return not warningStatus end, false, nil)
  local languageCombo, statusText
  for _, row in ipairs(state.comboRows) do
    if row.label == '###settings.language' then languageCombo = row end
  end
  for _, row in ipairs(state.wrappedRows) do
    local expected = warningStatus and Localization.text('SimOpenTrackDay is not running.') or Localization.text('Operational')
    if row.text == expected then statusText = row end
  end
  local firstHeaderSeparator = state.separatorRows[1]
  check(languageCombo and statusText and firstHeaderSeparator and
    firstHeaderSeparator.y > math.max(languageCombo.bottom, statusText.bottom),
    warningStatus and 'wide header separator follows wrapped warning and combo bottoms' or
      'wide header separator follows combo bottom when combo exceeds the status text height')
  if languageCombo and statusText then
    check(warningStatus and statusText.height > languageCombo.height or
      (not warningStatus and languageCombo.height > statusText.height),
      warningStatus and 'warning status fixture is taller than the combo' or
        'operational status fixture is shorter than the combo')
  end
end

verifyHeaderVerticalBounds(false)
verifyHeaderVerticalBounds(true)

-- The native chrome is replaced with an explicit close action; closing does not
-- mutate app enablement or the transient active tab.
state.availableWidth = 1200
UIState.activeTab = 'Behavior'
storage.enabled = true
state.pendingIconButton = 'main.window.close'
state.hovered = true
local windowCallsBeforeClose = #state.windowOpenCalls
draw(function() return true end, false, nil)
check(#state.windowOpenCalls == windowCallsBeforeClose + 1 and
  state.windowOpenCalls[#state.windowOpenCalls].id == 'mainWindow' and
  state.windowOpenCalls[#state.windowOpenCalls].open == false,
  'native icon close requests mainWindow closed through ac.setWindowOpen')
check(findEvent('iconButton', 'main.window.close') and #state.idStack == 0 and
  state.tooltips[#state.tooltips] == Localization.text('Close'),
  'native icon close retains its stable ID scope and localized tooltip')
check(storage.enabled and UIState.activeTab == 'Behavior',
  'closing the window leaves app enablement and active tab unchanged')

state.windowSize = vec2(480, 768)
state.availableWidth = 464
draw(function() return true end, false, nil)
local normalCloseButton
for _, row in ipairs(state.iconRows) do if row.id == 'main.window.close' then normalCloseButton = row end end
local wordmarkRow
for _, row in ipairs(state.coloredRows or {}) do if row.text == 'SimOpenTrackDay' then wordmarkRow = row end end
local wordmarkWidth
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == 'SimOpenTrackDay' and request.font == ui.Font.Title then wordmarkWidth = request.width end
end
check(normalCloseButton and normalCloseButton.width <= 464 and
  normalCloseButton.x + normalCloseButton.width == state.windowSize.x - Theme.layout.windowInset and
  normalCloseButton.y + normalCloseButton.height / 2 == Theme.layout.windowInset + Theme.layout.headerTitleRowHeight / 2 and wordmarkRow and
  wordmarkRow.x == Theme.layout.windowInset and
  wordmarkWidth and wordmarkRow.x + wordmarkWidth + Theme.spacing.sm <= normalCloseButton.x,
  '480 px header aligns native Title brand and Cancel icon without overlap')

-- At narrow content widths, hide branding that cannot fit beside the close
-- control instead of allowing the rectangles to overlap.
state.windowSize = vec2(80, 768)
state.availableWidth = 64
UIState.activeTab = 'Overview'
draw(function() return true end, false, nil)
local narrowClose, narrowBrand
for _, item in ipairs(state.events) do
  if item[1] == 'colored' and item[2] == 'SimOpenTrackDay' then narrowBrand = true end
end
for _, row in ipairs(state.iconRows) do if row.id == 'main.window.close' then narrowClose = row end end
check(narrowClose and narrowClose.width <= 64 and
  narrowClose.x >= Theme.layout.windowInset and
  narrowClose.x + narrowClose.width <= state.windowSize.x - Theme.layout.windowInset and
  not narrowBrand,
  '80 px viewport prioritizes the native Cancel icon when brand cannot fit')

for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  Localization.setLocale(locale)
  state.windowSize, state.availableWidth = vec2(480, 768), 464
  state.hovered = true
  draw(function() return true end, false, nil)
  local fullClose
  for _, row in ipairs(state.iconRows) do if row.id == 'main.window.close' then fullClose = row end end
  check(fullClose and fullClose.icon == ui.Icons.Cancel and fullClose.width == Theme.layout.closeButtonSize and
    state.tooltips[#state.tooltips] == Localization.text('Close'),
    string.format('native Cancel icon and localized Close tooltip remain available in %s', locale))

  state.windowSize, state.availableWidth, state.hovered = vec2(80, 768), 64, true
  draw(function() return true end, false, nil)
  local compactClose
  for _, row in ipairs(state.iconRows) do if row.id == 'main.window.close' then compactClose = row end end
  check(compactClose and compactClose.icon == ui.Icons.Cancel and compactClose.width == Theme.layout.closeButtonSize and compactClose.width <= 64 and
    state.tooltips[#state.tooltips] == Localization.text('Close'),
    string.format('80 px close prioritizes native icon, stable ID and localized hover text in %s', locale))
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
  expectedTabWidth = expectedTabWidth + #visible * 12 + Theme.spacing.lg
  if index > 1 then expectedTabWidth = expectedTabWidth + Theme.spacing.sm end
end
local measuredVisibleSelection = false
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == measuredVisibleTabs[1] then measuredVisibleSelection = true end
end
check(measuredVisibleSelection, 'visible selected-tab label participates in native-font navigation measurement')
for _, tab in ipairs({ 'Overview', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }) do
  local found = false
  for _, request in ipairs(state.nativeMeasureRequests) do
    if request.text == tab then found = request.font == ui.Font.Title and request.wrap == -1 end
  end
  check(found, 'navigation measures visible ' .. tab .. ' with the native Title font')
end
state.availableWidth = expectedTabWidth
draw(function() return true end, false, nil)
check(findCombo('main.tabs') == nil,
  'navigation uses buttons at the exact measured tab widths plus inter-tab gaps')
state.availableWidth = expectedTabWidth - 1
draw(function() return true end, false, nil)
check(findCombo('main.tabs') ~= nil,
  'navigation switches to compact combo one pixel below measured widths plus gaps')
local measuredNavigationNatively = false
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == 'Navigation' and request.font == ui.Font.Title and request.wrap == -1 then measuredNavigationNatively = true end
end
local navigationMeasuredByDWrite = false
for _, request in ipairs(state.measureRequests) do if request.text == 'Navigation' then navigationMeasuredByDWrite = true end end
check(measuredNavigationNatively and not navigationMeasuredByDWrite,
  'compact navigation label width uses the same native Title font as its rendered text')
state.availableWidth = 400
draw(function() return true end, false, nil)
local measuredWidthNavigation = findCombo('main.tabs')
local navigationWidthFromNative = nil
for _, request in ipairs(state.nativeMeasureRequests) do
  if request.text == 'Navigation' and request.wrap == -1 then navigationWidthFromNative = request.width end
end
check(measuredWidthNavigation and navigationWidthFromNative and
  measuredWidthNavigation.width == math.min(350, math.max(0, 400 - navigationWidthFromNative - Theme.spacing.sm)),
  'compact navigation combo width subtracts the native-font visible-label width')
state.availableWidth = expectedTabWidth - 1
state.throwCombo = 'main.tabs'
local navComboOK, navComboError = pcall(draw, function() return true end, false, nil)
state.throwCombo = nil
check(not navComboOK and tostring(navComboError):find('injected combo failure:', 1, true) and state.widthDepth == 0,
  'compact navigation combo error is rethrown after item-width cleanup (ok=' .. tostring(navComboOK) .. ', depth=' .. tostring(state.widthDepth) .. ', error=' .. tostring(navComboError) .. ')')
state.availableWidth = 1200
state.throwCombo = 'settings.language'
local languageComboOK, languageComboError = pcall(draw, function() return true end, false, nil)
state.throwCombo = nil
check(not languageComboOK and tostring(languageComboError):find('injected combo failure:', 1, true) and state.widthDepth == 0,
  'language combo error is rethrown after item-width cleanup')

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
check(countEvent('lanes') == 0 and countNativeTitle(Localization.text('Driving lanes')) == 0,
  'operational non-Overview tabs do not render the Overview lane card')
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
    Localization.setLocale(locale)
    local languageComboLabel = '###settings.language'
    state.pendingCombo[languageComboLabel] = localeIndex
    draw(function() return true end, false, nil)
    check(Localization.getLocale() == locale and findCombo('settings.language') ~= nil,
      string.format('global language control remains available at %d px in %s (actual %s, combo %s)',
         width, locale, tostring(Localization.getLocale()), tostring(findCombo('settings.language') ~= nil)))
    local explicitLanguageLabel = false
    for _, rowText in ipairs(state.wrapped) do
      if rowText == Localization.text('Language') then explicitLanguageLabel = true end
    end
    check(explicitLanguageLabel,
      string.format('language selector keeps its localized visible label separate from the stable combo ID in %s', locale))
    if width == 480 then
      check(countNativeTitle(Localization.text('Driving lanes')) == 1 and countEvent('lanes') == 1 and
        findEvent('group+') < findEvent('lanes') and findEvent('lanes') < findEvent('group-'),
        string.format('localized Overview lane grouping renders once in %s', locale))
    end
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
UIState.activeTab = 'Overview'
draw(function() return true end, true, 'Required CSP item missing')
check(countEvent('lanes') == 0 and countNativeTitle(Localization.text('Driving lanes')) == 0,
  'unavailable Overview omits the operational lane card')
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
check(entrySource:find('CSPCompatibilityManager.addFunction(function() return ui.drawRectFilledMultiColor end, "ui.drawRectFilledMultiColor"', 1, true) ~= nil,
  'entrypoint retains the ui.drawRectFilledMultiColor compatibility registration')
local function countSourceOccurrences(source, needle)
  local count, position = 0, 1
  while true do
    position = source:find(needle, position, true)
    if not position then return count end
    count, position = count + 1, position + #needle
  end
end
local iconButtonRegistration = 'CSPCompatibilityManager.addFunction(function() return ui.iconButton end, "ui.iconButton")'
local cancelIconRegistration = 'CSPCompatibilityManager.addFunction(function() return ui.Icons.Cancel end, "ui.Icons.Cancel")'
check(countSourceOccurrences(entrySource, iconButtonRegistration) == 1,
  'entrypoint registers ui.iconButton exactly once for the optional native close control')
check(countSourceOccurrences(entrySource, cancelIconRegistration) == 1,
  'entrypoint registers ui.Icons.Cancel exactly once for the optional native close control')
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

state.throwLaneContent = true
clearFrame()
state.cursor = vec2(8, 8)
local laneFailureOK, laneFailure = pcall(MainWindow.draw, function() return true end, false, nil)
state.throwLaneContent = false
check(not laneFailureOK and tostring(laneFailure):find('injected lane content failure', 1, true) ~= nil,
  'lane-section callback preserves and rethrows the original error')
check(state.groupDepth == 0 and #state.children == 0 and #state.styles == 0 and
  state.dwriteFontDepth == 0 and state.nativeFontDepth == 0 and #state.fontStack == 0,
  'lane-section error closes group and child, then balances styles and both font scopes')
local laneGroupEnd, laneChildEnd
for index, item in ipairs(state.events) do
  if item[1] == 'group-' then laneGroupEnd = index end
  if item[1] == 'endChild' and item[2] == 'mainPageContent' then laneChildEnd = index end
end
check(laneGroupEnd and laneChildEnd and laneGroupEnd < laneChildEnd,
  'lane group closes before MainWindow cleanup ends its child')

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

state.throwIconButton = true
clearFrame()
state.cursor = vec2(8, 8)
local iconFailureOK, iconFailure = pcall(MainWindow.draw, function() return true end, false, nil)
state.throwIconButton = false
check(not iconFailureOK and tostring(iconFailure):find('injected iconButton failure', 1, true) ~= nil,
  'native icon rendering failure is rethrown')
check(#state.idStack == 0 and #state.styles == 0 and #state.fontStack == 0 and
  state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
  'icon failure balances pushID, button/context styles and nested native-font scopes')

state.throwContextText = true
clearFrame()
state.cursor = vec2(8, 8)
local contextFailureOK, contextFailure = pcall(MainWindow.draw, function() return true end, false, nil)
state.throwContextText = false
check(not contextFailureOK and tostring(contextFailure):find('injected context text failure', 1, true) ~= nil and
  #state.styles == 0 and #state.fontStack == 0 and state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
  'context text failure restores its muted style and native Main/Title font scopes')

-- Optional native stack APIs can be absent; legacy DWrite behavior remains safe.
local savedFont, savedPushFont, savedPopFont = ui.Font, ui.pushFont, ui.popFont
local savedIconButton, savedIcons, savedPushID, savedPopID = ui.iconButton, ui.Icons, ui.pushID, ui.popID
ui.Font, ui.pushFont, ui.popFont = nil, nil, nil
ui.iconButton, ui.Icons, ui.pushID, ui.popID = nil, nil, nil, nil
package.loaded.MainWindow = nil
MainWindow = require('MainWindow')
state.pendingButton = Localization.label('Close', 'main.window.close')
local fallbackWindowCallsBefore = #state.windowOpenCalls
draw(function() return true end, true, 'Required CSP item missing (native-font fallback)')
check(state.dwriteFontDepth == 0 and state.nativeFontDepth == 0,
  'MainWindow remains drawable when optional native font APIs are absent')
check(table.concat(state.wrapped, '\n'):find('Required CSP item missing (native-font fallback)', 1, true) ~= nil,
  'native-font fallback still renders the existing CSP compatibility warning')
check(findCombo('settings.language') ~= nil and findCombo('main.tabs') ~= nil and
  state.checkboxValues['Enabled###settings.app.enabled'] == true,
  'native-font fallback retains default enabled, language, and navigation controls without crashing')
local fallbackClose
for _, row in ipairs(state.buttonRows) do
  if row.label:find('###main.window.close', 1, true) then fallbackClose = row end
end
check(fallbackClose and fallbackClose.label == Localization.label('Close', 'main.window.close') and
  #state.idStack == 0,
  'missing icon APIs fall back to the localized native Close button with its stable ID')
check(#state.windowOpenCalls == fallbackWindowCallsBefore + 1 and
  state.windowOpenCalls[#state.windowOpenCalls].id == 'mainWindow' and
  state.windowOpenCalls[#state.windowOpenCalls].open == false,
  'localized Close fallback retains the existing window-close action')
ui.Font, ui.pushFont, ui.popFont = savedFont, savedPushFont, savedPopFont
ui.iconButton, ui.Icons, ui.pushID, ui.popID = savedIconButton, savedIcons, savedPushID, savedPopID

print(string.format('MainWindow headless checks passed: %d checks.', checks))
