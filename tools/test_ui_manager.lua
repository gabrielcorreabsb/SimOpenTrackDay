-- Focused headless checks for the simplified UIManager car list.
-- Width probes exercise calls under mocked viewport widths only; they do not
-- establish CSP wrapping or visual rendering.

package.path = './?.lua;./?/init.lua;' .. package.path

local checks = 0
local function check(condition, message)
  checks = checks + 1
  if not condition then error('FAIL: ' .. message, 2) end
end

local renderedText, selectableLabels, selectableRows, stateLookups, wrappedWidths = {}, {}, {}, {}, {}
local selectedLabel, followedCar, currentWidth = nil, nil, 80
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
  text = function(text) renderedText[#renderedText + 1] = text end,
  textWrapped = function(text)
    renderedText[#renderedText + 1] = text
    wrappedWidths[#wrappedWidths + 1] = ui.availableSpaceX()
  end,
  textColored = function() end, pushStyleColor = function() end, popStyleColor = function() end,
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
  sameLine = function() end,
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
  renderedText, selectableLabels, selectableRows, stateLookups, wrappedWidths = {}, {}, {}, {}, {}
  separatorCount = 0
end

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
    string.format('wrapped text is invoked under the mocked available width %d', width))
  check(#stateLookups == 2 and stateLookups[1] == 1 and stateLookups[2] == 3,
    string.format('uninitialized car is skipped at width %d', width))
end

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
