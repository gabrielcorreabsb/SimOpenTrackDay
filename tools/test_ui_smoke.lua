-- Mock-CSP smoke harness for SettingsWindow. Run from the repository root:
--   luajit tools/test_ui_smoke.lua
-- This is a headless interaction harness, not an Assetto Corsa renderer/runtime test.

local scriptPath = debug.getinfo(1, 'S').source:sub(2)
local toolsDir = scriptPath:match('^(.*)[/\\]') or 'tools'
local root = toolsDir:match('^(.*)[/\\]tools$') or '.'

package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
local baselineFixture = require('tools.fixtures.settings_baseline')

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write('FAIL: ' .. message .. '\n')
  end
end

local styleColorNames = {
  'Text', 'TextDisabled', 'WindowBg', 'ChildBg', 'PopupBg', 'Border', 'BorderShadow',
  'FrameBg', 'FrameBgHovered', 'FrameBgActive', 'TitleBg', 'TitleBgActive',
  'TitleBgCollapsed', 'MenuBarBg', 'ScrollbarBg', 'ScrollbarGrab',
  'ScrollbarGrabHovered', 'ScrollbarGrabActive', 'CheckMark', 'SliderGrab',
  'SliderGrabActive', 'Button', 'ButtonHovered', 'ButtonActive', 'Header',
  'HeaderHovered', 'HeaderActive', 'Separator', 'SeparatorHovered', 'SeparatorActive',
  'ResizeGrip', 'ResizeGripHovered', 'ResizeGripActive', 'Tab', 'TabHovered',
  'TabActive', 'TabUnfocused', 'TabUnfocusedActive', 'PlotLines', 'PlotLinesHovered',
  'PlotHistogram', 'PlotHistogramHovered', 'TextSelectedBg', 'DragDropTarget',
  'NavHighlight', 'NavWindowingHighlight', 'NavWindowingDimBg', 'ModalWindowDimBg',
  'TextHovered', 'TextActive'
}
local styleColor = {}
for i, name in ipairs(styleColorNames) do styleColor[name] = i - 1 end
local comboFlags = { None = 0, NoPreview = 1, NoArrowButton = 2, WidthFitPreview = 4 }
local mouseButton = { Left = 0, Right = 1, Middle = 2 }
local mockStorageBackend = {}

local function newVec2(x, y)
  return { x = x or 0, y = y or 0, set = function(self, a, b)
    if type(a) == 'table' then self.x, self.y = a.x, a.y else self.x, self.y = a, b end
    return self
  end, sub = function(self, other) self.x, self.y = self.x - other.x, self.y - other.y; return self end,
  add = function(self, other) self.x, self.y = self.x + other.x, self.y + other.y; return self end }
end

local function setUp(settingsFile, accidentsEnabled, scrollPosition, initialLocale)
  package.loaded['SettingsWindow'] = nil
  package.loaded['SettingsModel'] = nil
  package.loaded['UIState'] = nil
  package.loaded['UIStorage'] = nil
  for _, name in ipairs({ 'Theme', 'Style', 'Section', 'Logo', 'Slider', 'Toggle' }) do
    package.loaded['lib/uilib/' .. name] = nil
    package.loaded['lib.uilib.' .. name] = nil
  end
  package.loaded['UIAppNameVersionWidget'] = nil
  package.loaded['UIOperations'] = nil
  package.loaded['StorageManager'] = nil
  package.loaded['Localization'] = nil

  local state = {
    events = {}, sliders = {}, sliderCalls = {}, checkboxes = {}, buttonLabels = {}, tooltips = {}, controlIDs = {},
    consumerCalls = { slider = 0, toggle = 0, uiOperationsSlider = 0 },
    pendingCheckbox = {}, pendingSlider = {}, pendingCombo = {}, mouseRight = {},
    colorDepth = 0, fontDepth = 0, widthDepth = 0, disabledDepth = 0, idDepth = 0,
    styleColorPushes = {},
    groupDepth = 0, columnsDepth = 0, frame = 0, availableX = 900, columnCounts = {}, currentColumn = 0, sectionColumns = {},
    cursor = newVec2(-(scrollPosition and scrollPosition.x or 0), -(scrollPosition and scrollPosition.y or 0)),
    windowPosition = newVec2(137, 83), windowSize = newVec2(1024, 768), fillRects = 0, firstLogoLine = nil,
    scroll = newVec2(scrollPosition and scrollPosition.x or 0, scrollPosition and scrollPosition.y or 0),
    firstFill = nil, firstFillIndex = nil, screenCursorSets = 0, localCursorSets = 0,
  }
  local function event(name, ...)
    state.events[#state.events + 1] = { name, ... }
  end
  local function visibleLabel(label)
    local visible, id = label:match('^(.-)###(.*)$')
    if not visible and label:sub(1, 2) ~= '##' then visible = label end
    return visible or label, id
  end
  local function requireEnabled(kind)
    return state.disabledDepth == 0
  end
  local ui = {
    StyleColor = styleColor, ComboFlags = comboFlags, MouseButton = mouseButton,
    ButtonFlags = { None = 0 },
    styleColor = function(index, alpha)
      assert(type(index) == 'number' and index >= 0 and index < #styleColorNames,
        'unsupported ui.StyleColor enum index')
      return { index = index, alpha = alpha }
    end,
    pushStyleColor = function(index, value)
      assert(type(index) == 'number' and index >= 0 and index < #styleColorNames,
        'invalid/unsupported StyleColor: ' .. tostring(index))
      state.colorDepth = state.colorDepth + 1; event('color+', index)
      state.styleColorPushes[#state.styleColorPushes + 1] = { index = index, value = value }
    end,
    popStyleColor = function(count)
      count = count or 1
      assert(count > 0 and state.colorDepth >= count, 'StyleColor stack underflow')
      state.colorDepth = state.colorDepth - count; event('color-', count)
    end,
    pushDWriteFont = function() state.fontDepth = state.fontDepth + 1; event('font+') end,
    popDWriteFont = function() assert(state.fontDepth > 0, 'DWriteFont stack underflow'); state.fontDepth = state.fontDepth - 1; event('font-') end,
    pushItemWidth = function(width)
      state.widthDepth = state.widthDepth + 1
      state.itemWidth = width
    end,
    popItemWidth = function() assert(state.widthDepth > 0, 'itemWidth stack underflow'); state.widthDepth = state.widthDepth - 1 end,
    pushDisabled = function() state.disabledDepth = state.disabledDepth + 1; event('disabled+') end,
    popDisabled = function() assert(state.disabledDepth > 0, 'disabled stack underflow'); state.disabledDepth = state.disabledDepth - 1; event('disabled-') end,
    pushID = function() state.idDepth = state.idDepth + 1 end,
    popID = function() assert(state.idDepth > 0, 'ID stack underflow'); state.idDepth = state.idDepth - 1 end,
    beginGroup = function() state.groupDepth = state.groupDepth + 1 end,
    endGroup = function() assert(state.groupDepth > 0, 'group stack underflow'); state.groupDepth = state.groupDepth - 1 end,
    columns = function(n)
      state.columnCounts[#state.columnCounts + 1] = n
      state.currentColumn, state.currentColumnCount = 0, n
      state.columnsDepth = n == 1 and 0 or state.columnsDepth + 1
    end,
    setColumnWidth = function() end,
    nextColumn = function() state.currentColumn = math.min(state.currentColumn + 1, (state.currentColumnCount or 1) - 1) end,
    windowWidth = function() return 1760 end,
    checkbox = function(label, value)
      local visible, id = visibleLabel(label)
      if not state.firstControlIndex then state.firstControlIndex = #state.events + 1 end
      event('checkbox', visible)
      state.lastItemLabel = visible
      state.checkboxes[visible] = { value = value, disabled = not requireEnabled() }
      state.controlIDs[visible] = id
      if (state.pendingCheckbox[label] or state.pendingCheckbox[visible]) and requireEnabled() then state.pendingCheckbox[label], state.pendingCheckbox[visible] = nil, nil; return true end
      return false
    end,
    button = function(label)
      if not state.firstControlIndex then state.firstControlIndex = #state.events + 1 end
      event('button', label)
      state.buttonLabels[label] = true
      return state.pendingButton == label and requireEnabled()
    end,
    combo = function(label, value, flags, options)
      local visible, id = visibleLabel(label)
      if not state.firstControlIndex then state.firstControlIndex = #state.events + 1 end
      event('combo', visible)
      state.lastItemLabel = visible
      state.controlIDs[visible] = id
      assert(flags == comboFlags.None, 'unsupported ComboFlags')
      state.combos = state.combos or {}
      state.combos[visible] = { value = value, options = options, disabled = not requireEnabled() }
      local nextValue = state.pendingCombo[label] or state.pendingCombo[visible]
      if nextValue ~= nil and requireEnabled() then state.pendingCombo[label] = nil; return nextValue, nextValue ~= value end
      return value, false
    end,
    slider = function(label, value, minimum, maximum, format)
      local visible, id = visibleLabel(label)
      if not state.firstControlIndex then state.firstControlIndex = #state.events + 1 end
      event('slider', visible)
      state.lastItemLabel = visible
      state.controlIDs[visible] = id
      state.sliders[visible] = { value = value, min = minimum, max = maximum, format = format, width = state.itemWidth, disabled = not requireEnabled() }
      local action = state.pendingSlider[label] or state.pendingSlider[visible]
      if action and requireEnabled() then
        state.pendingSlider[label] = nil
        if action.value ~= nil then return action.value end
      end
      return value
    end,
    itemHovered = function() return state.disabledDepth == 0 and state.hoverLabel == state.lastItemLabel end,
    setTooltip = function(text) state.tooltips[#state.tooltips + 1] = text end,
    mouseClicked = function(button) return button == mouseButton.Right and state.rightClick end,
    text = function() end, textColored = function() end,
    dwriteText = function(text, size)
      state.dwriteTexts = state.dwriteTexts or {}
      state.dwriteTexts[#state.dwriteTexts + 1] = text
      if text == 'Yielding' or text == 'Overtaking' or text == 'Accidents' or text == 'Pathfinding' then
        state.sectionColumns[text] = state.currentColumn
      end
      state.lastDWriteSize = size
    end,
    newLine = function() end, separator = function() end,
    drawLine = function(from, to)
      if not state.firstLogoLine then state.firstLogoLine = #state.events + 1 end
      state.lines = state.lines or {}
      state.lines[#state.lines + 1] = { from = from, to = to }
      event('line')
    end,
    drawRect = function() end,
    drawRectFilledMultiColor = function(...)
      state.gradientCalls = (state.gradientCalls or 0) + 1
      event('gradient')
    end,
    drawRectFilled = function(left, right)
      state.fillRects = state.fillRects + 1
      if not state.firstFill then
        state.firstFill = { x = left.x, y = left.y, right = right.x, bottom = right.y }
        state.firstFillIndex = #state.events + 1
      end
      event('fill', left, right)
    end,
    cursorScreenPos = function()
      return newVec2(state.cursor.x + state.windowPosition.x, state.cursor.y + state.windowPosition.y)
    end,
    setCursorScreenPos = function(position)
      state.screenCursorSets = state.screenCursorSets + 1
      state.cursor = newVec2(position.x - state.windowPosition.x, position.y - state.windowPosition.y)
    end,
    getCursor = function() return newVec2(state.cursor.x, state.cursor.y) end,
    setCursor = function(position)
      state.localCursorSets = state.localCursorSets + 1
      state.cursor = newVec2(position.x, position.y)
    end,
    newLine = function(amount) state.cursor.y = state.cursor.y + (amount or 20) end,
    availableSpaceX = function() return state.availableX end,
    availableSpaceY = function() return 700 end,
    itemRectMax = function() return newVec2(state.cursor.x + 100, state.cursor.y + 20) end,
    itemRectMin = function() return newVec2(state.cursor.x, state.cursor.y) end,
    windowPos = function() return newVec2(state.windowPosition.x, state.windowPosition.y) end,
    windowSize = function() return newVec2(state.windowSize.x, state.windowSize.y) end,
    measureDWriteText = function(text) return newVec2(#text * 7, 12) end,
    getScrollX = function() return state.scroll.x end, getScrollY = function() return state.scroll.y end,
    getScrollMaxY = function() return 0 end, textLineHeightWithSpacing = function() return 20 end,
    setItemAllowOverlap = function() end, invisibleButton = function() end,
    dummy = function(size) state.cursor.y = state.cursor.y + size.y end,
  }

  _G.ui = ui
  _G.vec2 = newVec2
  _G.rgbm = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
  _G.Constants = { ENABLE_ACCIDENT_HANDLING_IN_APP = accidentsEnabled, APP_VERSION = '0.9.8', APP_AUTHOR = 'dreasgrech', APP_NAME = 'SimOpenTrackDay' }
  _G.Logger = { log = function() end }
  _G.ac = {
    getSim = function() return { raceSessionType = 'practice' } end,
    getTrackFullID = function() return 'smoke_track' end,
    storage = function(defaults, namespace)
      if defaults.mode ~= nil then
        local values = {}
        for key, value in pairs(defaults) do values[key] = value end
        return setmetatable({}, {
          __index = function(_, key)
            local value = values[key]
            if value == nil then error('Unknown key: ' .. tostring(key), 2) end
            return value
          end,
          __newindex = function(_, key, value)
            if values[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
            values[key] = value
          end,
        })
      end
      if namespace == 'ui' then
        local values = mockStorageBackend[namespace]
        if not values then
          values = {}
          for key, value in pairs(defaults) do values[key] = value end
          mockStorageBackend[namespace] = values
        end
        return setmetatable({}, {
          __index = function(_, key)
            if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
            return values[key]
          end,
          __newindex = function(_, key, value)
            if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
            values[key] = value
          end,
        })
      end
      return defaults
    end,
  }
  _G.RaceTrackManager = {
    TrackSideStrings = { [1] = 'Left', [2] = 'Right' },
    getTrackName = function() return 'Mock Track' end,
    getSessionTypeName = function() return 'Practice' end,
    getOvertakingSide = function() return 1 end,
    getYieldingSide = function() return 2 end,
  }
  _G.ColorManager = { RGBM_Colors = { DarkKhaki = {}, Yellow = {}, Gainsboro = {} } }
  _G.AppIconRenderer = { draw = function() end }
  _G.UILateralOffsetsImageWidget = { draw = function() end }
  _G.UIManager = { VERTICAL_SCROLLBAR_WIDTH = 20 }
  _G.AccidentManager = { simulateAccident_manual = function() end, simulateAccident_random = function() end }
  _G.vec3 = function(x, y, z) return { x = x, y = y, z = z } end

  local storageManager = require('StorageManager')
  _G.StorageManager = storageManager
  local localization = require('Localization')
  if initialLocale ~= 'preserve' then localization.setLocale(initialLocale or 'en') end
  _G.UIAppNameVersionWidget = require('UIAppNameVersionWidget')
  local uiOperations = require('UIOperations')
  local renderSlider = uiOperations.renderSlider
  uiOperations.renderSlider = function(label, tooltip, value, minimum, maximum, width, format, defaultValue)
    state.consumerCalls.uiOperationsSlider = state.consumerCalls.uiOperationsSlider + 1
    local visibleLabel = label:match('^(.-)###') or label
    state.sliderCalls[visibleLabel] = {
      tooltip = tooltip, value = value, min = minimum, max = maximum,
      width = width, format = format, default = defaultValue,
    }
    return renderSlider(label, tooltip, value, minimum, maximum, width, format, defaultValue)
  end
  _G.UIOperations = uiOperations

  local sliderModule = require('lib/uilib/Slider')
  local sliderRender = sliderModule.render
  state.sliderRenderSource = debug.getinfo(sliderRender, 'S').source:gsub('\\', '/')
  sliderModule.render = function(label, tooltip, value, minimum, maximum, width, format, defaultValue)
    state.consumerCalls.slider = state.consumerCalls.slider + 1
    local visibleLabel = label:match('^(.-)###') or label
    state.sliderCalls[visibleLabel] = {
      tooltip = tooltip, value = value, min = minimum, max = maximum,
      width = width, format = format, default = defaultValue,
    }
    return sliderRender(label, tooltip, value, minimum, maximum, width, format, defaultValue)
  end
  local toggleModule = require('lib/uilib/Toggle')
  local toggleRender = toggleModule.render
  state.toggleRenderSource = debug.getinfo(toggleRender, 'S').source:gsub('\\', '/')
  toggleModule.render = function(label, value)
    state.consumerCalls.toggle = state.consumerCalls.toggle + 1
    return toggleRender(label, value)
  end

  local chunk, err = loadfile(settingsFile)
  assert(chunk, err)
  local getDebuggingStorage = storageManager.getStorage_Debugging
  storageManager.getStorage_Debugging = function()
    error('SettingsWindow must not read persisted debugging preferences', 2)
  end
  local settings = chunk()
  state.storage = storageManager.getStorage()
  state.behavior = storageManager.getStorage_Behavior()
  state.debugging = getDebuggingStorage()
  state.yielding = storageManager.getStorage_Yielding()
  state.overtaking = storageManager.getStorage_Overtaking()
  state.ai = storageManager.getStorage_AICarValues()
  state.accidentsEnabled = accidentsEnabled
  state.ui = ui
  state.sliderConsumer = package.loaded['lib/uilib/Slider'] or package.loaded['lib.uilib.Slider']
  state.toggleConsumer = package.loaded['lib/uilib/Toggle'] or package.loaded['lib.uilib.Toggle']
  state.uiState = require('UIState')
  return settings, storageManager, state
end

local settingsTabs = { 'Overview', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }
local function draw(settings, state, verifyCoordinates, onlyTab, operationalAvailable)
  state.frame = state.frame + 1
  state.columnCounts = {}
  state.controlIDs, state.sectionColumns, state.dwriteTexts = {}, {}, {}
  state.sliders, state.checkboxes, state.combos = {}, {}, {}
  state.sliderCalls, state.buttonLabels = {}, {}
  state.lines, state.events, state.firstLogoLine, state.firstControlIndex = {}, {}, nil, nil, nil
  state.firstFill, state.firstFillIndex, state.fillRects = nil, nil, 0
  local oldTab = state.uiState.activeTab
  for _, tab in ipairs(onlyTab and { onlyTab } or settingsTabs) do
    state.uiState.activeTab = tab
    settings.drawContent(tab, operationalAvailable ~= false)
  end
  state.uiState.activeTab = oldTab
  check(state.colorDepth == 0, 'StyleColor stack balanced after draw')
  check(state.fontDepth == 0, 'DWriteFont stack balanced after draw')
  check(state.widthDepth == 0, 'itemWidth stack balanced after draw')
  check(state.disabledDepth == 0, 'disabled stack balanced after draw')
  check(state.idDepth == 0, 'ID stack balanced after draw')
  check(state.groupDepth == 0, 'group stack balanced after draw')
  if verifyCoordinates then
    check(state.localCursorSets > 0, 'Section uses getCursor/setCursor window-coordinate positioning')
  end
end

local sliderStorageFields
local function inventory(path, accidentsEnabled)
  local settings, _, state = setUp(path, accidentsEnabled)
  draw(settings, state)
  local initialCheckboxes = {}
  for label in pairs(state.checkboxes) do initialCheckboxes[label] = true end
  local sawShowAdvancedControls = state.checkboxes['Show Advanced Controls'] ~= nil
  state.pendingCheckbox['Show Advanced Behavior Sliders'] = true
  draw(settings, state)
  state.pendingCheckbox['Show Advanced Controls'] = true
  draw(settings, state)
  draw(settings, state)
  local checkboxes = {}
  for label in pairs(initialCheckboxes) do checkboxes[label] = true end
  for label in pairs(state.checkboxes) do checkboxes[label] = true end
  return {
    sliders = state.sliderCalls,
    checkboxes = checkboxes,
    advancedToggleVariants = sawShowAdvancedControls and state.uiState.advancedControlsOpen and
      state.checkboxes['Hide Advanced Controls'] ~= nil,
    buttons = state.buttonLabels,
    combos = state.combos or {},
    fields = sliderStorageFields(path),
  }
end

sliderStorageFields = function(path)
  local file = assert(io.open(path, 'rb'))
  local fields = {}
  for line in file:lines() do
    -- Slider assignments are one-line statements; dropping line/inline comments keeps
    -- commented-out controls from entering this schema inventory.
    line = line:gsub('%-%-.*$', '')
    local objectName, fieldName = line:match('([%w_]+)%.([%w_]+)%s*=%s*UIOperations_renderSlider%(')
    if objectName and fieldName then fields[objectName .. '.' .. fieldName] = true end
  end
  file:close()
  return fields
end

local currentPath = root .. '/SettingsWindow.lua'
local function sortedKeys(map)
  local keys = {}
  for key in pairs(map) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end
local function emitFixture(data)
  local function emitMap(name, map, values)
    print('  ' .. name .. ' = {')
    for _, key in ipairs(sortedKeys(map)) do
      if values then
        local row = map[key]
        print(string.format('    [%q] = { min = %s, max = %s, format = %q, default = %s, tooltip = %q },',
          key, tostring(row.min), tostring(row.max), row.format, tostring(row.default), row.tooltip))
      else
        print(string.format('    [%q] = true,', key))
      end
    end
    print('  },')
  end
  print('return {')
  emitMap('sliders', data.sliders, true)
  emitMap('checkboxes', data.checkboxes)
  emitMap('buttons', data.buttons)
  emitMap('combos', data.combos)
  emitMap('fields', data.fields)
  print('}')
end

local externalBaselinePath = os.getenv('RTD_BASELINE_SETTINGS')
if externalBaselinePath and os.getenv('RTD_DUMP_BASELINE_FIXTURE') == '1' then
  emitFixture(inventory(externalBaselinePath, true))
  os.exit(0)
end

local function normalizeBrandLabel(label)
  label = label:gsub('^SimOpenTrackDay ', 'Realistic Trackday ')
  return (label:gsub(' Enabled for:', ' Disabled for:'))
end
local function normalizedSet(source)
  local result = {}
  for label in pairs(source) do result[normalizeBrandLabel(label)] = true end
  return result
end
local current = inventory(currentPath, true)
local expected = baselineFixture
if externalBaselinePath then
  local sourceBaseline = inventory(externalBaselinePath, true)
  for label, row in pairs(expected.sliders) do
    local actual = sourceBaseline.sliders[label]
    check(actual and actual.min == row.min and actual.max == row.max and actual.format == row.format and
      actual.default == row.default and actual.tooltip == row.tooltip,
      'versioned fixture agrees with optional baseline source slider: ' .. label)
  end
end

local sliderCount = 0
for label, row in pairs(expected.sliders) do
  sliderCount = sliderCount + 1
  local actual = current.sliders[label]
  check(actual ~= nil, 'baseline active slider retained: ' .. label)
  if actual then
    check(actual.min == row.min and actual.max == row.max and actual.format == row.format and
      actual.default == row.default and actual.tooltip == row.tooltip,
      'baseline slider min/max/format/default/tooltip retained: ' .. label)
  end
end
for label in pairs(current.sliders) do check(expected.sliders[label] ~= nil, 'no un-baselined active slider: ' .. label) end

local function compareLabels(kind, actualSource, normalize)
  local actual = normalize and normalizedSet(actualSource) or actualSource
  local total = 0
  for label in pairs(expected[kind]) do total = total + 1; check(actual[label], 'baseline active ' .. kind .. ' retained: ' .. label) end
  for label in pairs(actual) do check(expected[kind][label], 'no un-baselined active ' .. kind .. ': ' .. label) end
  return total
end
local checkboxCount
local buttonCount = compareLabels('buttons', current.buttons)
check(current.advancedToggleVariants == true,
  'Advanced tab contributes both localized advanced-controls toggle states to the tab-union inventory')
local currentBaselineCheckboxes = {}
for label, value in pairs(current.checkboxes) do
  if label ~= 'Show Advanced Controls' and label ~= 'Hide Advanced Controls' and
      label ~= 'Hide Advanced Behavior Sliders' then
    currentBaselineCheckboxes[label] = value
  end
end
checkboxCount = compareLabels('checkboxes', currentBaselineCheckboxes, true)
local baselineCombos = {}
for label, value in pairs(current.combos) do if label ~= 'Language' then baselineCombos[label] = value end end
local comboCount = compareLabels('combos', baselineCombos)
check(comboCount == 1 and current.combos['AI Behavior Profile'] ~= nil,
  'Settings tabs retain the profile combo; language selection belongs to the global header')
local fieldCount = compareLabels('fields', current.fields)
print(string.format('Baseline active controls: %d sliders, %d checkboxes, %d buttons, %d combos; %d storage fields (comments excluded).',
  sliderCount, checkboxCount, buttonCount, comboCount, fieldCount))

local settings, storageManager, state = setUp(currentPath, true)
state.debugging.drawCarList = true
state.debugging.debugShowCarStateOverheadText = true
state.storage.enabled = true
draw(settings, state, true)
  check(state.sliders['Entry blend time'] == nil,
  'advanced behavior sliders are genuinely collapsed by default')
check(state.combos.Language == nil, 'language selector is global and no longer duplicated in Settings content')
check(state.storage.handleAccidents == false, 'legacy debugging flags do not enable accident handling')
for _, removedDeveloperControl in ipairs({
  'Show UI Car List', 'Show car state overhead text', 'Show raycasts when driving laterally',
  'Draw tyres side offtrack gizmos', 'Log fast AI state changes', 'Log car yielding',
  'Log car overtaking', 'Override player car lateral offset',
}) do
  check(state.checkboxes[removedDeveloperControl] == nil,
    'removed developer control is absent from Settings: ' .. removedDeveloperControl)
end
check(state.sliders['##debugCarStateOverheadShowDistance'] == nil and
  state.sliders['##debugOverridePlayerCarLateralOffsetValue'] == nil and
  state.sliders['##debugSimulateAccidentSplinePosition'] == nil,
  'removed developer sliders are absent from Settings')
check(next(state.buttonLabels) == nil, 'removed developer action buttons are absent from Settings')
local profileCombo = state.combos['AI Behavior Profile']
check(profileCombo and profileCombo.options[1] == 'Casual' and profileCombo.options[2] == 'Realistic' and profileCombo.options[3] == 'Competitive',
  'profile combo items are localized display text, never labels with hidden IDs')
for label in pairs(state.checkboxes) do
  check(not label:find('###', 1, true), 'interactive labels do not expose hidden IDs: ' .. label)
end
for label in pairs(state.combos) do
  check(not label:find('###', 1, true), 'combo labels do not expose hidden IDs: ' .. label)
end
local localizationLocales = require('Localization').locales
check(#localizationLocales == 3 and localizationLocales[1] == 'en' and localizationLocales[2] == 'pt-BR' and localizationLocales[3] == 'es',
  'real Localization module exposes exactly the supported locale contract')
local offsetControlID = state.controlIDs['Default Lateral Offset [-1..1]']
check(offsetControlID == 'Default Lateral Offset [-1..1]', 'slider retains its source-English widget ID')
local localization = require('Localization')
localization.setLocale('pt-BR')
draw(settings, state)
check(state.controlIDs['Deslocamento lateral padrão [-1..1]'] == offsetControlID,
  'Portuguese label changes while retaining the source-English slider ID')
check(table.concat(state.dwriteTexts or {}, '\n'):find('Cautela', 1, true) ~= nil,
  'Settings section labels render translated text without ID suffixes')
localization.setLocale('es')
draw(settings, state)
check(state.controlIDs['Desplazamiento lateral predeterminado [-1..1]'] == offsetControlID,
  'Spanish label changes while retaining the source-English slider ID')
localization.setLocale('en')
state.availableX = 480
draw(settings, state)
local narrowIsSingleColumn = true
for _, count in ipairs(state.columnCounts) do if count > 1 then narrowIsSingleColumn = false end end
check(narrowIsSingleColumn, 'narrow layout stacks all Settings sections into one column')
for _, slider in pairs(state.sliderCalls) do
  check(slider.width <= state.availableX, 'narrow slider width fits the available content area')
end
state.availableX = 1200
draw(settings, state)
local wideUsesColumns = false
for _, count in ipairs(state.columnCounts) do if count > 1 then wideUsesColumns = true end end
check(wideUsesColumns, 'wide layout uses multi-column grouping where space allows')
state.availableX = 80
draw(settings, state)
for _, slider in pairs(state.sliderCalls) do
  check(slider.width >= 0, 'very narrow slider request remains non-negative')
end
for _, slider in pairs(state.sliders) do
  check(slider.width <= 80, 'very narrow native slider dimensions are not widened past available space')
end
local function checkTabWidth(width)
  local s, _, snapshot = setUp(currentPath, true)
  snapshot.availableX = width
  snapshot.uiState.advancedControlsOpen = true
  draw(s, snapshot)
  for label, slider in pairs(snapshot.sliderCalls) do
    local drawn = snapshot.sliders[label]
    check(drawn and drawn.width <= width, string.format('tab-union slider width fits at %d px: %s', width, label))
  end
end
for _, width in ipairs({ 80, 480, 700, 900, 1200, 1760 }) do checkTabWidth(width) end

local disabledSettings, disabledManager, disabledState = setUp(currentPath, true)
local originalBehaviorMode = disabledState.behavior.mode
disabledState.pendingCombo['AI Behavior Profile'] = disabledManager.Profile.Competitive
draw(disabledSettings, disabledState, false, 'Behavior', false)
check(disabledState.combos['AI Behavior Profile'] and disabledState.combos['AI Behavior Profile'].disabled and
  disabledState.behavior.mode == originalBehaviorMode,
  'unavailable app/CSP wrapper disables profile controls and leaves simulation values unchanged')
disabledState.pendingCheckbox['Handle Yielding'] = true
local originalHandleYielding = disabledState.yielding.handleYielding
draw(disabledSettings, disabledState, false, 'Yielding', false)
check(disabledState.checkboxes['Handle Yielding'] and disabledState.checkboxes['Handle Yielding'].disabled and
  disabledState.yielding.handleYielding == originalHandleYielding,
  'unavailable wrapper disables operational lane toggles without writing values')
local entryFile = assert(io.open(root .. '/SimOpenTrackDay.lua', 'rb'))
local entrySource = entryFile:read('*a')
entryFile:close()
local mainCallback = entrySource:match('function script%.MANIFEST__FUNCTION_MAIN%(dt%)%s*(.-)function script%.MANIFEST__FUNCTION_ICON')
local mainWindowDelegation = 'MainWindow.draw(shouldAppRun, anyMissingCSPElements, missingCSPElementsErrorMessage)'
check(mainCallback ~= nil and mainCallback:find(mainWindowDelegation, 1, true) ~= nil,
  'entry main callback delegates to MainWindow.draw with the app/CSP arguments')
if mainCallback then
  local mainWindowFile = assert(io.open(root .. '/MainWindow.lua', 'rb'))
  local mainWindowSource = mainWindowFile:read('*a')
  mainWindowFile:close()
  local languageSelector = "Localization.label('Language', 'settings.language')"
  local languageSelectorPosition = mainWindowSource:find(languageSelector, 1, true)
  local appRunGuardPosition = mainWindowSource:find('shouldAppRun()', 1, true)
  check(languageSelectorPosition ~= nil,
    'MainWindow presentation exposes the language selector with its stable ID')
  check(languageSelectorPosition ~= nil and appRunGuardPosition ~= nil and languageSelectorPosition < appRunGuardPosition,
    'MainWindow language selector is available before the app-running guard')
end
local sliderGrabAccentFound = false
local accent = require('lib/uilib/Theme').colors.accent
for _, push in ipairs(state.styleColorPushes) do
  local value = push.value
  if push.index == styleColor.SliderGrab and value and value.r == accent.r and
      value.g == accent.g and value.b == accent.b then
    sliderGrabAccentFound = true
  end
end
check(sliderGrabAccentFound, 'Settings content retains the Theme accent SliderGrab style')
state.hoverLabel = nil

state.pendingCheckbox['Show Advanced Behavior Sliders'] = true
draw(settings, state)
check(state.debugging.drawCarList == true and state.debugging.debugShowCarStateOverheadText == true,
  'advanced visibility leaves legacy debugging flags untouched')
check(state.sliders['Entry blend time'] ~= nil, 'advanced sliders visible on enabling draw')
state.pendingCheckbox['Hide Advanced Behavior Sliders'] = true
draw(settings, state)
check(state.debugging.drawCarList == true and state.debugging.debugShowCarStateOverheadText == true,
  'advanced visibility remains transient and leaves legacy debugging flags untouched')
check(state.sliders['Entry blend time'] == nil, 'advanced sliders are removed from layout when collapsed')

state.pendingCheckbox['Show Advanced Controls'] = true
draw(settings, state, false, 'Advanced')
check(state.uiState.advancedControlsOpen == true and state.sliders['Forward distance'] ~= nil,
  'Advanced tab opens its operational controls without changing the baseline schemas')
check(state.checkboxes['Handle accidents (WORK IN PROGRESS - BEST NOT USED FOR NOW)'] ~= nil and
  state.sliders['Distance from accident to see yellow flag (m)'] and
  state.sliders['Distance from accident to see yellow flag (m)'].disabled,
  'operational accident controls remain present and dependent sliders start disabled')

local profile = storageManager.Profile.Competitive
state.pendingCombo['AI Behavior Profile'] = profile
draw(settings, state)
check(state.behavior.mode == storageManager.BehaviorMode.Race,
  'profile choice applies without writing an undeclared storage key')
local unknownProfileReadOk = pcall(function() return state.behavior.profile end)
local unknownProfileWriteOk = pcall(function() state.behavior.profile = profile end)
check(not unknownProfileReadOk and not unknownProfileWriteOk,
  'profile UI never reads or writes the undeclared behavior.profile key')
check(state.behavior.humanErrorEnabled == true, 'competitive profile enables human errors')

profile = storageManager.Profile.Casual
state.pendingCombo['AI Behavior Profile'] = profile
draw(settings, state)
check(state.behavior.mode == storageManager.BehaviorMode.TrackDay and
  state.behavior.entryBlendTime_s == 0.5 and state.behavior.humanErrorEnabled == false,
  'Casual profile remains selectable and applies its existing values')

profile = storageManager.Profile.Realistic
state.pendingCombo['AI Behavior Profile'] = profile
draw(settings, state)
check(state.behavior.mode == storageManager.BehaviorMode.TrackDay,
  'Realistic profile remains selectable and applies its original mode')
check(state.behavior.entryBlendTime_s == 1.5 and state.behavior.pointBySpeedDeltaKmh == 15 and
  state.behavior.humanErrorEnabled == false, 'Realistic profile defaults remain unchanged')

state.storage.overrideAiAwareness = false
state.pendingCheckbox['Override AI awareness'] = true
draw(settings, state)
check(state.storage.overrideAiAwareness == true, 'AI awareness override toggles on')
state.pendingCheckbox['Override AI awareness'] = true
draw(settings, state)
check(state.storage.overrideAiAwareness == false, 'AI awareness override toggles off')

check(state.sliderConsumer and type(state.sliderConsumer.render) == 'function',
  'SettingsWindow consumes real lib.uilib.Slider.render')
check(state.toggleConsumer ~= nil, 'SettingsWindow consumes real lib.uilib.Toggle')
check(state.sliderRenderSource and state.sliderRenderSource:find('/lib/uilib/Slider.lua', 1, true),
  'Slider consumer resolves to the real lib/uilib/Slider.lua source')
check(state.toggleRenderSource and state.toggleRenderSource:find('/lib/uilib/Toggle.lua', 1, true),
  'Toggle consumer resolves to the real lib/uilib/Toggle.lua source')
check(state.consumerCalls.slider > 0, 'SettingsWindow actually calls Slider.render')
check(state.consumerCalls.toggle > 0, 'SettingsWindow actually calls Toggle.render')
check(state.consumerCalls.uiOperationsSlider == 0,
  'SettingsWindow does not route sliders through legacy UIOperations.renderSlider')
local accidentSettings, _, accidentState = setUp(currentPath, true)
accidentState.storage.enabled = true
accidentState.uiState.advancedControlsOpen = true
draw(accidentSettings, accidentState)
accidentState.pendingCheckbox['Handle accidents (WORK IN PROGRESS - BEST NOT USED FOR NOW)'] = true
draw(accidentSettings, accidentState)
check(accidentState.storage.handleAccidents == true, 'operational accident handling remains selectable')
check(accidentState.sliders['Distance from accident to see yellow flag (m)'] and
  accidentState.sliders['Distance from accident to see yellow flag (m)'].disabled == false,
  'operational accident-avoidance controls enable when accident handling is enabled')

local overtakingSettings, _, overtakingState = setUp(currentPath, true)
overtakingState.storage.enabled = true
overtakingState.overtaking.handleOvertaking = true
draw(overtakingSettings, overtakingState)
local overtakingSlider = overtakingState.sliders['Overtaking Lateral Offset [-1..1] -> Overtaking side: Left']
check(overtakingSlider and overtakingSlider.disabled == false,
  'overtaking slider is enabled when handleOvertaking is true')
overtakingState.overtaking.handleOvertaking = false
draw(overtakingSettings, overtakingState)
overtakingSlider = overtakingState.sliders['Overtaking Lateral Offset [-1..1] -> Overtaking side: Left']
check(overtakingSlider and overtakingSlider.disabled == true,
  'overtaking slider is disabled when handleOvertaking is false')

local overrideSettings, _, overrideState = setUp(currentPath, true)
overrideState.storage.enabled = true
overrideState.ai.overrideOriginalAIAggression_drivingNormally = false
overrideState.ai.overrideOriginalAIDifficultyLevel_drivingNormally = false
draw(overrideSettings, overrideState)
check(overrideState.sliders['Aggression while driving normally'].disabled == true and
  overrideState.sliders['Difficulty Level while driving normally'].disabled == true,
  'aggression and difficulty sliders are disabled when their overrides are off')
overrideState.ai.overrideOriginalAIAggression_drivingNormally = true
overrideState.ai.overrideOriginalAIDifficultyLevel_drivingNormally = true
draw(overrideSettings, overrideState)
check(overrideState.sliders['Aggression while driving normally'].disabled == false and
  overrideState.sliders['Difficulty Level while driving normally'].disabled == false,
  'aggression and difficulty sliders are enabled when their overrides are on')

-- Right-click reset honors hover and disabled guards; resetting a disabled slider is a no-op.
local resetLabel = 'Minimum top speed to limit to overtaking car'
state.yielding.speedLimitValueToOvertakingCar = 1.0
local resetValueBefore = state.yielding.minimumSpeedLimitKmhToLimitToOvertakingCar
state.storage.enabled = true
state.rightClick = true
state.hoverLabel = resetLabel
state.pendingSlider[resetLabel] = { value = 123 }
draw(settings, state)
check(state.yielding.minimumSpeedLimitKmhToLimitToOvertakingCar == resetValueBefore,
  'disabled speed-floor slider ignores right-click/reset interaction')
check(state.widthDepth == 0, 'slider item widths balanced after reset interactions')

local activeResetLabel = 'Caution while driving normally'
local activeResetDefault = baselineFixture.sliders[activeResetLabel].default
state.ai.defaultAICaution = 8
state.hoverLabel = activeResetLabel
draw(settings, state)
check(state.sliders[activeResetLabel] and state.sliders[activeResetLabel].disabled == false,
  'active slider is enabled for reset test')
check(state.ai.defaultAICaution == activeResetDefault,
  'right-click on active slider resets it to the baseline default')

if failures > 0 then
  io.stderr:write(string.format('UI smoke harness failed: %d assertion(s); %d checks.\n', failures, checks))
  os.exit(1)
end
print(string.format('UI smoke harness passed: %d assertions/checks.', checks))
