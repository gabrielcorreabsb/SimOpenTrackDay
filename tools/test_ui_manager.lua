-- Focused headless checks for the simplified UIManager car list.
-- Width probes exercise calls under mocked viewport widths only; they do not
-- establish CSP wrapping or visual rendering.

package.path = './?.lua;./?/init.lua;' .. package.path

local checks = 0
local function check(condition, message)
  checks = checks + 1
  if not condition then error('FAIL: ' .. message, 2) end
end

local renderedText, selectableLabels, selectableRows, stateLookups, wrappedWidths, statusCalls = {}, {}, {}, {}, {}, {}
local selectedLabel, followedCar, currentWidth = nil, nil, 80
local stylePushes, stylePopCount, barColors = {}, 0, {}
local buttonLabels, buttonClickLabel, buttonSizes = {}, nil, {}
local comboRows, itemWidthStack = {}, {}
local pendingFilterIndex
local measureScale = 0
local sameLineCalls = 0
local separatorCount, debugGetterCalls = 0, 0
local activeLocale = 'en'
local stateNames = { [10] = 'DrivingNormally', [11] = 'EasingInYield' }
local statesByCar = { [1] = 10, [3] = 11 }
local legacyDebugStorage = { drawCarList = true, debugShowCarStateOverheadText = true }
local catalogs = {
  en = require('lib/i18n/en'),
  ['pt-BR'] = require('lib/i18n/pt-BR'),
  es = require('lib/i18n/es'),
}
local ui
ui = {
  columns = function() end, setColumnWidth = function() end, nextColumn = function() end,
  newLine = function() end, separator = function() separatorCount = separatorCount + 1 end,
  text = function(text)
    renderedText[#renderedText + 1] = text
    statusCalls[#statusCalls + 1] = { method = 'text', text = text }
  end,
  textWrapped = function(text)
    renderedText[#renderedText + 1] = text
    wrappedWidths[#wrappedWidths + 1] = ui.availableSpaceX()
    statusCalls[#statusCalls + 1] = { method = 'wrapped', text = text }
  end,
  dwriteText = function()
    error('car list must not use dwriteText inside the scrolling child')
  end,
  measureDWriteText = function(text, size, wrap) return { x = measureScale > 0 and #text * measureScale or 60, y = 15 } end,
  StyleColor = { Text = 1, Button = 2, ButtonHovered = 3, ButtonActive = 4 },
  button = function(label, size)
    buttonLabels[#buttonLabels + 1] = label
    buttonSizes[#buttonSizes + 1] = size and size.x or nil
    return buttonClickLabel == label
  end,
  ComboFlags = { None = 0 },
  pushItemWidth = function(width) itemWidthStack[#itemWidthStack + 1] = width end,
  popItemWidth = function() itemWidthStack[#itemWidthStack] = nil end,
  combo = function(label, index, _, options)
    comboRows[#comboRows + 1] = { label = label, index = index, options = options, width = itemWidthStack[#itemWidthStack] }
    if label == '###cars.filter' and pendingFilterIndex then
      local selected = pendingFilterIndex
      pendingFilterIndex = nil
      return selected, selected ~= index
    end
    return index, false
  end,
  textColored = function() end,
  getCursor = function() return { x = 0, y = 0 } end,
  setCursor = function() end,
  drawRectFilled = function(_, _, color) barColors[#barColors + 1] = color end,
  pushStyleColor = function(index, color) stylePushes[#stylePushes + 1] = { index = index, color = color } end,
  popStyleColor = function() stylePopCount = stylePopCount + 1 end,
  textLineHeightWithSpacing = function() return 18 end,
  cursorScreenPos = function() return { x = 0, y = 0 } end,
  setCursorScreenPos = function() end,
  selectable = function(label, isSelected)
    selectableLabels[#selectableLabels + 1] = label
    local visible, id = label:match('^(.-)###(.*)$')
    selectableRows[#selectableRows + 1] = {
      visible = visible or label, id = id, selected = isSelected,
    }
    if selectedLabel == label then selectedLabel = nil; return true end
    return false
  end,
  sameLine = function() sameLineCalls = sameLineCalls + 1 end,
  SelectableFlags = { None = 0 },
  availableSpaceX = function() return currentWidth end,
}
_G.ui = ui
_G.ac = {
  getSim = function() return {} end, getCar = function() return nil end,
  setWindowOpen = function() end, isWindowOpen = function() return false end,
}
_G.StorageManager = {
  getStorage = function() return {} end,
  getStorage_Yielding = function() return {} end,
  getStorage_Overtaking = function() return {} end,
  getStorage_Debugging = function()
    debugGetterCalls = debugGetterCalls + 1
    error('UIManager must not read legacy debug settings')
  end,
}
_G.RaceTrackManager = {
  getDefaultDrivingSide = function() return 1 end,
  getOvertakingSide = function() return 1 end,
  getYieldingSide = function() return 2 end,
  TrackSideStrings = { [1] = 'Left', [2] = 'Right' },
}
_G.ColorManager = { RGBM_Colors = { Violet = {}, Yellow = {}, DarkGray = {}, Red = {}, Green = {} } }
_G.UILateralOffsetsImageWidget = { draw = function() end }
_G.CarStateMachine = {
  CarStateTypeStrings = stateNames,
  CarStateType = { DRIVING_NORMALLY = 10, EASING_IN_YIELD = 11 },
  getCurrentState = function(index)
    stateLookups[#stateLookups + 1] = index
    return statesByCar[index]
  end,
}
local cars = {
  currentSortedCarsList = {
    { index = 1, speedKmh = 123.9, position = {} },
    { index = 2, speedKmh = 90, position = {} }, -- present but not initialized
    { index = 3, speedKmh = 81.7, position = {} },
  },
  cars_initialized = { [1] = true, [2] = false, [3] = true },
  getActualTrackLateralOffset = function(index, position)
    check(position ~= nil, 'lateral-offset query receives car position')
    return index == 1 and 0.125 or -0.375
  end,
}
_G.CarManager = cars
_G.CameraManager = {
  getFocusedCarIndex = function() return 0 end,
  followCarWithChaseCamera = function(index) followedCar = index end,
}
_G.UIOperations = {}
_G.Constants = { IS_ONLINE = false }
_G.rgbm = function() return {} end
_G.vec2 = function(x, y) return { x = x, y = y } end
package.loaded.Localization = {
  text = function(source, ...)
    local translated = catalogs[activeLocale][source] or source
    if select('#', ...) > 0 then return string.format(translated, ...) end
    return translated
  end,
  label = function(text, id) return text .. '###' .. id end,
}
package.loaded.UIManager = nil
local manager = require('UIManager')

local function resetDraw()
  renderedText, selectableLabels, selectableRows, stateLookups, wrappedWidths, statusCalls = {}, {}, {}, {}, {}, {}
  separatorCount = 0
  stylePushes, stylePopCount, barColors, buttonLabels, comboRows, buttonSizes = {}, 0, {}, {}, {}, {}
  sameLineCalls = 0
end

-- Constrained translated chips fall back to a full-text selector; geometry never
-- assigns an individual chip more than the available content width.
local filterState = require('UIState')
measureScale = 10
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  activeLocale = locale
  for _, width in ipairs({ 80, 480, 700, 900, 1200, 1760 }) do
    currentWidth = width
    filterState.carFilter = 'All'
    resetDraw()
    manager.drawUICarList()
    if width == 80 then
      check(#comboRows == 1 and comboRows[1].label == '###cars.filter' and comboRows[1].width == width,
        string.format('narrow selector is width-bounded in %s', locale))
      check(comboRows[1].options[1] == string.format(catalogs[locale]['%s (%d)'] or '%s (%d)', catalogs[locale].All, 2) and
        comboRows[1].options[2] == string.format(catalogs[locale]['%s (%d)'] or '%s (%d)', catalogs[locale].Yielding, 1) and
        comboRows[1].options[3] == string.format(catalogs[locale]['%s (%d)'] or '%s (%d)', catalogs[locale].Overtaking, 0) and
        comboRows[1].options[4] == string.format(catalogs[locale]['%s (%d)'] or '%s (%d)', catalogs[locale].Incidents, 0),
        string.format('fallback options preserve localized labels and live counts in %s', locale))
      check(buttonLabels[1] == nil, 'fallback does not draw clipped filter chips')
    else
      check(#comboRows == 0, string.format('filter chips fit or wrap at %d px in %s', width, locale))
      check(#buttonSizes == 4, string.format('all four filter chips render at %d px in %s', width, locale))
      for _, buttonWidth in ipairs(buttonSizes) do
        check(buttonWidth <= width, string.format('actual button geometry is bounded at %d px in %s', width, locale))
      end
      if width == 480 then
        check(sameLineCalls > 0 and sameLineCalls < 3,
          string.format('chips wrap onto multiple rows at 480 px in %s', locale))
      end
      for _, expectedID in ipairs({ 'cars.filter.all', 'cars.filter.yielding', 'cars.filter.overtaking', 'cars.filter.incidents' }) do
        local found = false
        for _, label in ipairs(buttonLabels) do if label:match('###(.*)$') == expectedID then found = true end end
        check(found, string.format('chip stable ID %s remains present at %d px in %s', expectedID, width, locale))
      end
    end
  end
end
currentWidth, activeLocale, measureScale = 100, 'en', 0
for index, name in ipairs({ 'All', 'Yielding', 'Overtaking', 'Incidents' }) do
  currentWidth, activeLocale, measureScale = 80, 'es', 10
  pendingFilterIndex = index
  resetDraw()
  manager.drawUICarList()
  check(filterState.carFilter == name, 'compact filter selector selects ' .. name)
end
filterState.carFilter = 'All'
currentWidth, activeLocale, measureScale = 100, 'en', 0
check(#itemWidthStack == 0, 'compact filter selector balances item-width scope')

local widths = { 80, 480, 1760 }
local locales = { 'en', 'pt-BR', 'es' }
for widthIndex, width in ipairs(widths) do
  currentWidth = width
  activeLocale = locales[widthIndex]
  resetDraw()
  manager.drawUICarList()
  check(#selectableLabels == 2, string.format('initialized cars appear at mocked viewport width %d', width))
  local expectedFirst = string.format(catalogs[activeLocale]['Car #%02d - %s'], 1,
    catalogs[activeLocale][stateNames[statesByCar[1]]])
  local expectedThird = string.format(catalogs[activeLocale]['Car #%02d - %s'], 3,
    catalogs[activeLocale][stateNames[statesByCar[3]]])
  check(selectableRows[1].visible == expectedFirst and selectableRows[2].visible == expectedThird,
    string.format('row display text is localized at mocked width %d (%s)', width, activeLocale))
  check(selectableRows[1].id == 'car.row.1' and selectableRows[2].id == 'car.row.3',
    string.format('row IDs remain stable and separate from display text at width %d (%s)', width, activeLocale))
  check(selectableLabels[1] == expectedFirst .. '###car.row.1' and
    selectableLabels[2] == expectedThird .. '###car.row.3',
    string.format('stable IDs are encoded after display text at width %d (%s)', width, activeLocale))
  local expectedFirstStatus = string.format(catalogs[activeLocale]['Speed: %d km/h | Lane offset: %.3f'], 123, 0.125)
  local expectedThirdStatus = string.format(catalogs[activeLocale]['Speed: %d km/h | Lane offset: %.3f'], 81, -0.375)
  check(renderedText[1] == expectedFirstStatus and renderedText[2] == expectedThirdStatus,
    string.format('speed/lane status is localized and formatted at mocked width %d (%s)', width, activeLocale))
  check(#wrappedWidths == 2 and wrappedWidths[1] == width and wrappedWidths[2] == width,
    string.format('wrapped text is invoked when measured status exceeds mocked width %d', width))
  check(#stateLookups >= 2 and not (function() for _, i in ipairs(stateLookups) do if i == 2 then return true end end end)(),
    string.format('uninitialized car is skipped at width %d', width))
end

-- Status lines use native wrapped text (no DirectWrite) under a balanced muted Text style color.
activeLocale, currentWidth = 'en', 100
resetDraw()
manager.drawUICarList()
check(#statusCalls == 2 and statusCalls[1].method == 'wrapped' and statusCalls[2].method == 'wrapped',
  'status text renders as native wrapped text and never through dwriteText')
check(#stylePushes == stylePopCount and stylePushes[#stylePushes].index == ui.StyleColor.Text and
  stylePushes[#stylePushes].color == require('lib/uilib/Theme').colors.muted,
  'status text uses the muted Text style color with balanced push/pop')
local ThemeForBars = require('lib/uilib/Theme')
check(#barColors == 2 and barColors[1] == ThemeForBars.colors.success and barColors[2] == ThemeForBars.colors.warning,
  'car status bars map driving-normally to success and yielding to warning')

local UIStateForFilter = require('UIState')
UIStateForFilter.carFilter = 'Yielding'
resetDraw()
manager.drawUICarList()
check(#selectableLabels == 1 and selectableRows[1].id == 'car.row.3',
  'yielding filter shows only yielding cars')
check(buttonLabels[1] == 'All (2)###cars.filter.all' and buttonLabels[2] == 'Yielding (1)###cars.filter.yielding' and
  buttonLabels[4] == 'Incidents (0)###cars.filter.incidents',
  'filter chips show localized names with live counts and stable IDs')
UIStateForFilter.carFilter = 'All'
buttonClickLabel = 'Overtaking (0)###cars.filter.overtaking'
resetDraw()
manager.drawUICarList()
check(UIStateForFilter.carFilter == 'Overtaking', 'clicking a filter chip selects it')
buttonClickLabel = nil
resetDraw()
manager.drawUICarList()
check(#selectableLabels == 0, 'selected filter is applied on the next draw')
UIStateForFilter.carFilter = 'All'

resetDraw()
activeLocale = 'es'
selectedLabel = string.format(catalogs.es['Car #%02d - %s'], 3, catalogs.es[stateNames[statesByCar[3]]]) .. '###car.row.3'
manager.drawUICarList()
check(followedCar == 3, 'selecting an initialized car focuses that car')
statesByCar[3] = 10
activeLocale = 'pt-BR'
resetDraw()
manager.drawUICarList()
local selectedRowAfterChange = selectableRows[2]
check(selectedRowAfterChange and selectedRowAfterChange.id == 'car.row.3' and selectedRowAfterChange.selected,
  'selection remains attached to the same stable row ID after locale/state change')
check(selectedRowAfterChange and selectedRowAfterChange.visible ==
  string.format(catalogs['pt-BR']['Car #%02d - %s'], 3, catalogs['pt-BR']['DrivingNormally']),
  'visible row text updates with state and locale without changing its selection identity')
statesByCar[3] = 11
activeLocale = 'es'
selectedLabel = 'Coche #02 - ###car.row.2'
manager.drawUICarList()
check(followedCar == 3, 'uninitialized car cannot be focused from the list')

local wrappedStatus = string.format(catalogs.es['Speed: %d km/h | Lane offset: %.3f'], 123, 0.125)
resetDraw()
manager.drawUICarList()
check(renderedText[1] == wrappedStatus and #wrappedWidths == 2,
  'ui.textWrapped branch emits the localized status line')
ui.textWrapped = nil
package.loaded.UIManager = nil
manager = require('UIManager')
resetDraw()
manager.drawUICarList()
check(renderedText[1] == wrappedStatus and #wrappedWidths == 0,
  'ui.text fallback emits the same localized status line when wrapping API is absent')

cars.currentSortedCarsList = {}
resetDraw()
local emptyOK = pcall(manager.drawUICarList)
check(emptyOK and #selectableLabels == 0, 'empty car list returns without error')
cars.currentSortedCarsList = nil
resetDraw()
local nilOK = pcall(manager.drawUICarList)
check(nilOK and #selectableLabels == 0, 'uninitialized car-list table returns without error')
cars.currentSortedCarsList = { { index = 2, speedKmh = 90, position = {} } }
resetDraw()
local uninitializedOnlyOK = pcall(manager.drawUICarList)
check(uninitializedOnlyOK and #selectableLabels == 0, 'list containing only uninitialized cars returns without error')
check(legacyDebugStorage.drawCarList and legacyDebugStorage.debugShowCarStateOverheadText,
  'legacy debug flags can remain enabled independently of the UI')
check(debugGetterCalls == 0, 'UIManager never calls the debug-storage getter')
check(separatorCount > 0, 'car list section separator remains present')

print(string.format('UIManager tests passed: %d checks.', checks))
