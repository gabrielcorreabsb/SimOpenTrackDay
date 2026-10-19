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
local textItems, barRects = {}, {}
local selectedLabel, clickPoint, followedCar, currentWidth = nil, nil, nil, 80
local stylePushes, stylePopCount, barColors = {}, 0, {}
local buttonLabels, buttonClickLabel, buttonSizes = {}, nil, {}
local comboRows, itemWidthStack = {}, {}
local pendingFilterIndex
local measureScale = 0
local sameLineCalls = 0
local separatorCount, debugGetterCalls = 0, 0
local activeLocale = 'en'
local throwSelectable, throwCamera = false, false
local cameraCalls = 0
local stateNames = {
  [10] = 'DrivingNormally', [11] = 'EasingInYield', [12] = 'EasingInOvertake', [13] = 'WaitingAfterAccident',
  [14] = 'DrivingInYellowFlagZone',
}
local statesByCar = { [1] = 10, [3] = 11 }
local cursor, lastItem = { x = 0, y = 0 }, nil
local function advanceItem(width, height)
  lastItem = { min = { x = cursor.x, y = cursor.y }, max = { x = cursor.x + width, y = cursor.y + height } }
  cursor.y = cursor.y + height
end
local legacyDebugStorage = { drawCarList = true, debugShowCarStateOverheadText = true }
local catalogs = {
  en = require('lib/i18n/en'),
  ['pt-BR'] = require('lib/i18n/pt-BR'),
  es = require('lib/i18n/es'),
}
local ui
local mainStorage = { defaultLateralOffset = 0, yieldingLateralOffset = -0.4, overtakingLateralOffset = 0.4 }
local yieldingStorage, overtakingStorage = { handleYielding = true }, { handleOvertaking = true }
local columnsCalls, nextColumnCalls = 0, 0
local yieldingSide, overtakingSide = 2, 1
ui = {
  columns = function() columnsCalls = columnsCalls + 1 end, setColumnWidth = function() end, nextColumn = function() nextColumnCalls = nextColumnCalls + 1 end,
  newLine = function(lines) cursor.x = 0; cursor.y = cursor.y + (lines or 1) * 18 end,
  separator = function() separatorCount = separatorCount + 1; advanceItem(currentWidth, 1) end,
  text = function(text)
    renderedText[#renderedText + 1] = text
    statusCalls[#statusCalls + 1] = { method = 'text', text = text }
    local x, y = cursor.x, cursor.y
    advanceItem(math.min(currentWidth - cursor.x, #text * 7), 18)
    textItems[#textItems + 1] = { text = text, x = x, y = y, width = lastItem.max.x - x, height = 18, wrapped = false }
  end,
  textWrapped = function(text)
    renderedText[#renderedText + 1] = text
    local width = math.max(1, ui.availableSpaceX())
    wrappedWidths[#wrappedWidths + 1] = width
    statusCalls[#statusCalls + 1] = { method = 'wrapped', text = text }
    local lines = math.max(1, math.ceil(#text * 7 / width))
    local x, y = cursor.x, cursor.y
    advanceItem(width, lines * 18)
    textItems[#textItems + 1] = { text = text, x = x, y = y, width = width, height = lines * 18, wrapped = true }
  end,
  dwriteText = function()
    error('car list must not use dwriteText inside the scrolling child')
  end,
  measureDWriteText = function(text, size, wrap) return { x = measureScale > 0 and #text * measureScale or 60, y = 15 } end,
  StyleColor = { Text = 1, Button = 2, ButtonHovered = 3, ButtonActive = 4 },
  button = function(label, size)
    buttonLabels[#buttonLabels + 1] = label
    buttonSizes[#buttonSizes + 1] = size and size.x or nil
    advanceItem(size and size.x or 60, size and size.y or 28)
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
  textColored = function(text) renderedText[#renderedText + 1] = text end,
  measureText = function(text) return { x = #text * 7, y = 18 } end,
  getCursor = function() return { x = cursor.x, y = cursor.y } end,
  itemRectMax = function() return lastItem and { x = lastItem.max.x, y = lastItem.max.y } or { x = cursor.x, y = cursor.y } end,
  setCursor = function(position) cursor = { x = position.x, y = position.y } end,
  drawRectFilled = function(min, max, color)
    barColors[#barColors + 1] = color
    barRects[#barRects + 1] = { min = min, max = max, color = color }
  end,
  drawRect = function(min, max) barRects[#barRects + 1] = { min = min, max = max, outline = true } end,
  drawLine = function(a, b, color, thickness) barRects[#barRects + 1] = { min = a, max = b, color = color, thickness = thickness or 1, line = true } end,
  pushStyleColor = function(index, color) stylePushes[#stylePushes + 1] = { index = index, color = color } end,
  popStyleColor = function() stylePopCount = stylePopCount + 1 end,
  textLineHeightWithSpacing = function() return 18 end,
  cursorScreenPos = function() return { x = 0, y = 0 } end,
  setCursorScreenPos = function() end,
  selectable = function(label, isSelected, _, size)
    if throwSelectable then error('injected selectable failure') end
    selectableLabels[#selectableLabels + 1] = label
    local visible, id = label:match('^(.-)###(.*)$')
    selectableRows[#selectableRows + 1] = {
      visible = visible or label, id = id, selected = isSelected,
      x = cursor.x, y = cursor.y, width = size and size.x or 0, height = size and size.y or 18,
    }
    advanceItem(size and size.x or 0, size and size.y or 18)
    if selectedLabel == label then selectedLabel = nil; return true end
    if clickPoint and clickPoint.x >= cursor.x - 0.001 and clickPoint.x <= cursor.x + (size and size.x or 0) and
      clickPoint.y >= cursor.y - (size and size.y or 18) and clickPoint.y <= cursor.y then
      clickPoint = nil
      return true
    end
    return false
  end,
  sameLine = function(_, spacing)
    sameLineCalls = sameLineCalls + 1
    if lastItem then cursor = { x = lastItem.max.x + (spacing or 0), y = lastItem.min.y } end
  end,
  SelectableFlags = { None = 0 },
  availableSpaceX = function() return math.max(0, currentWidth - cursor.x) end,
}
_G.ui = ui
_G.ac = {
  getSim = function() return {} end, getCar = function() return nil end,
  setWindowOpen = function() end, isWindowOpen = function() return false end,
}
_G.StorageManager = {
  getStorage = function() return mainStorage end,
  getStorage_Yielding = function() return yieldingStorage end,
  getStorage_Overtaking = function() return overtakingStorage end,
  getStorage_Debugging = function()
    debugGetterCalls = debugGetterCalls + 1
    error('UIManager must not read legacy debug settings')
  end,
}
_G.RaceTrackManager = {
  getDefaultDrivingSide = function() return 1 end,
  getOvertakingSide = function() return overtakingSide end,
  getYieldingSide = function() return yieldingSide end,
  TrackSideStrings = { [1] = 'Left', [2] = 'Right' },
}
_G.ColorManager = { RGBM_Colors = { Violet = {}, Yellow = {}, DarkGray = {}, Red = {}, Green = {} } }
package.loaded.Localization = {
  text = function(source, ...)
    local translated = catalogs[activeLocale][source] or source
    if select('#', ...) > 0 then return string.format(translated, ...) end
    return translated
  end,
  label = function(text, id) return text .. '###' .. id end,
}
_G.rgbm = function() return {} end
_G.vec2 = function(x, y) return { x = x, y = y } end
_G.UILateralOffsetsImageWidget = require('UILateralOffsetsImageWidget')
_G.CarStateMachine = {
  CarStateTypeStrings = stateNames,
  CarStateType = {
    DRIVING_NORMALLY = 10, EASING_IN_YIELD = 11, EASING_IN_OVERTAKE = 12, WAITING_AFTER_ACCIDENT = 13,
    DRIVING_IN_YELLOW_FLAG_ZONE = 14,
  },
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
  followCarWithChaseCamera = function(index)
    cameraCalls = cameraCalls + 1
    if throwCamera then error('injected camera failure') end
    followedCar = index
  end,
}
_G.UIOperations = {}
_G.Constants = { IS_ONLINE = false }
_G.rgbm = function() return {} end
_G.vec2 = function(x, y) return { x = x, y = y } end
package.loaded.UIManager = nil
local manager = require('UIManager')

local function resetDraw()
  renderedText, selectableLabels, selectableRows, stateLookups, wrappedWidths, statusCalls = {}, {}, {}, {}, {}, {}
  textItems, barRects = {}, {}
  separatorCount = 0
  stylePushes, stylePopCount, barColors, buttonLabels, comboRows, buttonSizes = {}, 0, {}, {}, {}, {}
  sameLineCalls = 0
  cursor, lastItem = { x = 0, y = 0 }, nil
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

local widths = { 80, 480, 700, 900, 1760 }
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
 for _, width in ipairs(widths) do
  currentWidth, activeLocale = width, locale
  resetDraw()
  manager.drawUICarList()
   check(#selectableLabels == 2, string.format('initialized cars appear at mocked viewport width %d', width))
   local expectedFirst = string.format(catalogs[activeLocale]['Car #%02d'], 1)
   local expectedThird = string.format(catalogs[activeLocale]['Car #%02d'], 3)
  check(selectableRows[1].visible == expectedFirst and selectableRows[2].visible == expectedThird,
    string.format('row display text is localized at mocked width %d (%s)', width, activeLocale))
  check(selectableRows[1].id == 'car.row.1' and selectableRows[2].id == 'car.row.3',
    string.format('row IDs remain stable and separate from display text at width %d (%s)', width, activeLocale))
  check(selectableLabels[1] == expectedFirst .. '###car.row.1' and
    selectableLabels[2] == expectedThird .. '###car.row.3',
    string.format('stable IDs are encoded after display text at width %d (%s)', width, activeLocale))
   local function containsText(expected)
     for _, text in ipairs(renderedText) do if text == expected then return true end end
     return false
   end
   check(containsText(catalogs[activeLocale][stateNames[statesByCar[1]]]) and
     containsText(catalogs[activeLocale][stateNames[statesByCar[3]]]),
     string.format('localized state names remain visible at mocked width %d (%s)', width, activeLocale))
   check(containsText(string.format(catalogs[activeLocale]['Speed: %d km/h'], 123)) and
     containsText(string.format(catalogs[activeLocale]['Lane offset: %.3f'], 0.125)) and
     containsText(string.format(catalogs[activeLocale]['Speed: %d km/h'], 81)) and
     containsText(string.format(catalogs[activeLocale]['Lane offset: %.3f'], -0.375)),
     string.format('split telemetry retains localized values at %d px (%s)', width, activeLocale))
   check(width == 80 and #wrappedWidths >= 6 or width > 80,
     string.format('native wrapping is used at narrow width and inline text can remain single-line at %d px (%s)', width, activeLocale))
   for _, item in ipairs(textItems) do
     check(item.x >= 0 and item.x + item.width <= width + 0.01,
       string.format('wrapped item is bounded by mock viewport %d (%s)', width, activeLocale))
   end
   check(selectableRows[1].y < selectableRows[2].y and selectableRows[2].y >= barRects[1].max.y,
     string.format('rows advance vertically without overlap at %d px (%s)', width, activeLocale))
   local firstSpeed, firstOffset
   for _, item in ipairs(textItems) do
     if item.text == string.format(catalogs[activeLocale]['Speed: %d km/h'], 123) then firstSpeed = item end
     if item.text == string.format(catalogs[activeLocale]['Lane offset: %.3f'], 0.125) then firstOffset = item end
   end
   check(firstSpeed and firstOffset and
     (width == 80 and firstOffset.x == firstSpeed.x and firstOffset.y >= firstSpeed.y + firstSpeed.height or
       width > 80 and firstSpeed.y == firstOffset.y and firstSpeed.x < firstOffset.x),
     string.format('telemetry columns align when they fit and stack when narrow at %d px (%s)', width, activeLocale))
   if width == 80 then
     local firstState
     for _, item in ipairs(textItems) do
       if item.text == catalogs[activeLocale][stateNames[statesByCar[1]]] then firstState = item; break end
     end
     check(firstState and firstState.x == selectableRows[1].x and firstState.y > selectableRows[1].y,
       string.format('narrow header stacks long state text below the selectable number in %s', activeLocale))
   else
     local firstState
     for _, item in ipairs(textItems) do
       if item.text == catalogs[activeLocale][stateNames[statesByCar[1]]] then firstState = item; break end
     end
     check(firstState and firstState.x > selectableRows[1].x and firstState.y == selectableRows[1].y,
       string.format('number and state share a row when native measurement fits at %d px (%s)', width, activeLocale))
   end
   check(barRects[1] and barRects[1].min.y == selectableRows[1].y and
     barRects[1].max.y >= math.max(firstSpeed.y + firstSpeed.height, firstOffset.y + firstOffset.height),
     string.format('state bar covers telemetry without ending early at %d px (%s)', width, activeLocale))
  check(#stateLookups >= 2 and not (function() for _, i in ipairs(stateLookups) do if i == 2 then return true end end end)(),
    string.format('uninitialized car is skipped at width %d', width))
   check(stylePopCount == #stylePushes,
     string.format('filter style scopes balance at %d px in %s', width, locale))
 end
end

-- The longest exposed state name wraps on narrow layouts and fits beside the
-- car number when the measured native width permits it.
statesByCar[3] = 14
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  for _, width in ipairs({ 80, 480, 700, 900 }) do
    activeLocale, currentWidth = locale, width
    filterState.carFilter = 'All'
    resetDraw()
    manager.drawUICarList()
    local longState
    for _, item in ipairs(textItems) do
      if item.text == catalogs[locale].DrivingInYellowFlagZone then longState = item end
    end
    check(longState and longState.x >= 0 and longState.x + longState.width <= width and
      (width == 80 and longState.height > 18 or width > 80 and longState.y == selectableRows[2].y),
      string.format('long localized state wraps or shares the title row without clipping at %d px (%s)', width, locale))
    check(barRects[2] and barRects[2].max.y >= longState.y + longState.height,
      string.format('row bar includes long state bounds at %d px (%s)', width, locale))
  end
end
statesByCar[3] = 11

-- State and telemetry remain native wrapped text; semantic bars accompany explicit state names.
activeLocale, currentWidth = 'en', 100
resetDraw()
manager.drawUICarList()
check(#statusCalls == 6 and statusCalls[1].method == 'wrapped' and statusCalls[2].method == 'wrapped',
  'state and telemetry render through native wrapped text, never dwriteText')
check(stylePopCount == #stylePushes, 'filter style colors remain balanced around the list draw')
local ThemeForBars = require('lib/uilib/Theme')
check(#barColors == 2 and barColors[1] == ThemeForBars.colors.success and barColors[2] == ThemeForBars.colors.warning,
  'car status bars map driving-normally to success and yielding to warning')
check(renderedText[1] == catalogs.en.DrivingNormally and renderedText[4] == catalogs.en.EasingInYield,
  'semantic state colors are accompanied by explicit localized state names')

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
local originalSortedCars = cars.currentSortedCarsList
cars.currentSortedCarsList = {
  { index = 1, speedKmh = 123.9, position = {} },
  { index = 2, speedKmh = 90, position = {} },
  { index = 3, speedKmh = 81.7, position = {} },
  { index = 4, speedKmh = 142.2, position = {} },
  { index = 5, speedKmh = 0, position = {} },
}
cars.cars_initialized[4], cars.cars_initialized[5] = true, true
statesByCar[4], statesByCar[5] = 12, 13
for _, case in ipairs({ { 'Overtaking', 4, 'EasingInOvertake' }, { 'Incidents', 5, 'WaitingAfterAccident' } }) do
  UIStateForFilter.carFilter = case[1]
  activeLocale = 'es'
  resetDraw()
  manager.drawUICarList()
  check(#selectableRows == 1 and selectableRows[1].id == 'car.row.' .. case[2] and
    renderedText[1] == catalogs.es[case[3]],
    case[1] .. ' filter renders its initialized fixture state and stable car ID')
  local hasCount = false
  for _, label in ipairs(buttonLabels) do
    if label == catalogs.es[case[1]] .. ' (1)###cars.filter.' .. case[1]:lower() then hasCount = true end
  end
  check(hasCount, case[1] .. ' filter count includes its initialized fixture car')
end
cars.currentSortedCarsList = originalSortedCars
cars.cars_initialized[4], cars.cars_initialized[5] = nil, nil
statesByCar[4], statesByCar[5] = nil, nil
UIStateForFilter.carFilter = 'All'
activeLocale = 'en'
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
selectedLabel = string.format(catalogs.es['Car #%02d'], 3) .. '###car.row.3'
local cameraCallsBeforeSelection = cameraCalls
manager.drawUICarList()
check(followedCar == 3 and cameraCalls == cameraCallsBeforeSelection + 1,
  'one selection performs exactly one chase-camera action')
statesByCar[3] = 10
activeLocale = 'pt-BR'
resetDraw()
manager.drawUICarList()
local selectedRowAfterChange = selectableRows[2]
check(selectedRowAfterChange and selectedRowAfterChange.id == 'car.row.3' and selectedRowAfterChange.selected,
  'selection remains attached to the same stable row ID after locale/state change')
check(selectedRowAfterChange and selectedRowAfterChange.visible ==
  string.format(catalogs['pt-BR']['Car #%02d'], 3) and
  renderedText[1] == catalogs['pt-BR']['DrivingNormally'],
  'number selection stays stable while state text updates with locale and state')
statesByCar[3] = 11
activeLocale = 'es'
selectedLabel = 'Coche #02 - ###car.row.2'
manager.drawUICarList()
check(followedCar == 3, 'uninitialized car cannot be focused from the list')

-- Clicking the state text is still inside the full-width selectable title row.
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  for _, width in ipairs({ 480, 700, 900 }) do
    activeLocale, currentWidth = locale, width
    UIStateForFilter.carFilter = 'All'
    resetDraw()
    manager.drawUICarList()
    local stateItem
    for _, item in ipairs(textItems) do
      if item.text == catalogs[locale].EasingInYield then stateItem = item; break end
    end
    check(stateItem and stateItem.x > selectableRows[2].x and stateItem.y == selectableRows[2].y,
      string.format('state occupies a distinct inline area at %d px (%s)', width, locale))
    clickPoint = { x = stateItem.x + 1, y = stateItem.y + math.min(9, stateItem.height - 1) }
    local callsBefore = cameraCalls
    resetDraw()
    manager.drawUICarList()
    check(cameraCalls == callsBefore + 1 and followedCar == 3 and
      selectableRows[1].id == 'car.row.1' and selectableRows[2].id == 'car.row.3' and
      not selectableRows[1].selected and selectableRows[2].selected,
      string.format('state-area coordinate selects only its own row and follows once at %d px (%s)', width, locale))
    check(clickPoint == nil, 'state-area click is consumed by the full-width row selectable')
  end
end
clickPoint = nil

throwSelectable = true
resetDraw()
local selectableOK, selectableError = pcall(manager.drawUICarList)
throwSelectable = false
check(not selectableOK and tostring(selectableError):find('injected selectable failure', 1, true) and
  stylePopCount == #stylePushes,
  'selectable failure preserves its error without leaking row style colors')
throwCamera = true
selectedLabel = string.format(catalogs.es['Car #%02d'], 1) .. '###car.row.1'
resetDraw()
local cameraOK, cameraError = pcall(manager.drawUICarList)
throwCamera = false
check(not cameraOK and tostring(cameraError):find('injected camera failure', 1, true) and
  stylePopCount == #stylePushes,
  'camera failure preserves its error without leaking row style colors')

local wrappedStatus = string.format(catalogs.es['Speed: %d km/h'], 123)
activeLocale, currentWidth = 'es', 100
resetDraw()
manager.drawUICarList()
check(renderedText[2] == wrappedStatus and #wrappedWidths >= 6,
  'ui.textWrapped branch emits localized split telemetry')
local savedTextWrapped = ui.textWrapped
ui.textWrapped = nil
package.loaded.UIManager = nil
manager = require('UIManager')
resetDraw()
manager.drawUICarList()
check(renderedText[2] == wrappedStatus and #wrappedWidths == 0,
  'ui.text fallback emits the same localized speed value when wrapping API is absent')
ui.textWrapped = savedTextWrapped
package.loaded.UIManager = nil
manager = require('UIManager')

cars.currentSortedCarsList = {}
activeLocale = 'en'
resetDraw()
local emptyOK = pcall(manager.drawUICarList)
check(emptyOK and #selectableLabels == 0 and renderedText[#renderedText] == catalogs.en['No cars available.'],
  'empty car list gives a clear localized message')
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  for _, width in ipairs({ 80, 480 }) do
    activeLocale, currentWidth = locale, width
    resetDraw()
    manager.drawUICarList()
    local emptyText = textItems[#textItems]
    check(renderedText[#renderedText] == catalogs[locale]['No cars available.'] and emptyText and
      emptyText.wrapped and emptyText.x + emptyText.width <= width,
      string.format('empty-list message is localized and wrapped within %d px in %s', width, locale))
  end
end
cars.currentSortedCarsList = nil
resetDraw()
local nilOK = pcall(manager.drawUICarList)
check(nilOK and #selectableLabels == 0 and renderedText[#renderedText] == catalogs.es['No cars available.'],
  'missing car-list table gives a clear localized message')
cars.currentSortedCarsList = { { index = 2, speedKmh = 90, position = {} } }
resetDraw()
local uninitializedOnlyOK = pcall(manager.drawUICarList)
check(uninitializedOnlyOK and #selectableLabels == 0 and renderedText[#renderedText] == catalogs.es['No initialized cars available.'],
  'list containing only uninitialized cars gives its own localized message')
check(textItems[#textItems] and textItems[#textItems].wrapped and textItems[#textItems].x + textItems[#textItems].width <= currentWidth,
  'uninitialized-car message uses bounded native wrapping')
filterState.carFilter = 'Incidents'
cars.currentSortedCarsList = {
  { index = 1, speedKmh = 123.9, position = {} },
  { index = 2, speedKmh = 90, position = {} },
  { index = 3, speedKmh = 81.7, position = {} },
}
activeLocale = 'pt-BR'
resetDraw()
manager.drawUICarList()
check(#selectableLabels == 0 and renderedText[#renderedText] == catalogs['pt-BR']['No cars match this filter.'],
  'empty filter results are explained in the active language')
check(textItems[#textItems] and textItems[#textItems].wrapped and textItems[#textItems].x + textItems[#textItems].width <= currentWidth,
  'empty-filter message uses bounded native wrapping')
filterState.carFilter = 'All'
check(legacyDebugStorage.drawCarList and legacyDebugStorage.debugShowCarStateOverheadText,
  'legacy debug flags can remain enabled independently of the UI')
check(debugGetterCalls == 0, 'UIManager never calls the debug-storage getter')
check(separatorCount > 0, 'car list section separator remains present')

activeLocale, currentWidth = 'pt-BR', 900
resetDraw()
columnsCalls, nextColumnCalls = 0, 0
yieldingSide, overtakingSide = 1, 1
local sectionInset = require('lib/uilib/Theme').spacing.md
cursor = { x = sectionInset, y = 50 } -- Section callback origin; availableSpaceX is width minus cursor.x.
manager.drawMainWindowLateralOffsetsSection()
check(columnsCalls == 0 and nextColumnCalls == 0,
  'lateral diagram integration does not create or advance an empty column')
local railCount = 0
for _, item in ipairs(barRects) do
  if item.line and item.max.x > item.min.x and math.abs(item.max.y - item.min.y) < 0.001 and item.thickness == 2 then railCount = railCount + 1 end
end
check(railCount == 1, 'UIManager renders the real horizontal shared-axis widget in place')
local sectionCard = barRects[1]
check(sectionCard and sectionCard.min.x == sectionInset and
  math.abs(sectionCard.min.x - sectionInset) < 0.01 and
  math.abs((currentWidth - sectionCard.max.x) - sectionInset) < 0.01,
  'UIManager passes the Section right inset so the widget has equal outer margins')
check(renderedText[#renderedText] == catalogs['pt-BR']['Adjust driving lane offsets in Behavior.'],
  'behavior adjustment guidance remains after the integrated diagram')
local warningSeen = false
for _, text in ipairs(renderedText) do
  if text == 'Yielding side and overtaking side are the same!' then warningSeen = true end
end
check(warningSeen, 'equal-side warning remains visible after diagram integration')
check(nextColumnCalls == 0, 'warning and guidance remain in the same layout flow')

print(string.format('UIManager tests passed: %d checks.', checks))
