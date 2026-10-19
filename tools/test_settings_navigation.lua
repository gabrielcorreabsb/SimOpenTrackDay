-- Headless routing checks for the real SettingsWindow module.
-- SettingsModel, Section, Slider, UI and CSP globals are deliberately narrow mocks;
-- this verifies routing/control contracts, not CSP rendering or persistence schemas.
package.path = './?.lua;./?/init.lua;' .. package.path

local function check(ok, message)
  if not ok then error('FAIL: ' .. message, 2) end
end
local function near(a, b) return type(a) == 'number' and math.abs(a - b) < 1e-9 end

local function defaults(value)
  return setmetatable({}, { __index = function() return value end })
end
local function enum()
  return setmetatable({}, { __index = function(_, key) return key end })
end
local storage = setmetatable({ defaultLateralOffset = 0.1, overtakingLateralOffset = 0.2,
  yieldingLateralOffset = 0.3 }, { __index = function() return 0 end })
local yielding = setmetatable({ handleYielding = true }, { __index = function() return 0 end })
local overtaking = setmetatable({ handleOvertaking = true }, { __index = function() return 0 end })
local behavior = setmetatable({}, { __index = function() return 0 end })
local aiValues = setmetatable({}, { __index = function() return 0 end })
local model = {
  BehaviorMode = enum(), Options = enum(), Options_Yielding = enum(), Options_Overtaking = enum(),
  Options_AICarValues = enum(), Options_PathFinding = enum(),
  options_default = defaults(0.25), options_min = defaults(-1), options_max = defaults(1),
  options_Yielding_default = defaults(0.25), options_Yielding_min = defaults(0), options_Yielding_max = defaults(1),
  options_Overtaking_default = defaults(0.25), options_Overtaking_min = defaults(0), options_Overtaking_max = defaults(1),
  options_AICarValues_default = defaults(0.25), options_AICarValues_min = defaults(0), options_AICarValues_max = defaults(1),
  options_PathFinding_default = defaults(0.25), options_PathFinding_min = defaults(0), options_PathFinding_max = defaults(1),
  getStorage = function() return storage end,
  getStorage_Yielding = function() return yielding end,
  getStorage_Overtaking = function() return overtaking end,
  getStorage_Behavior = function() return behavior end,
  getStorage_AICarValues = function() return aiValues end,
  getStorage_PathFinding = function() return {} end,
  applyBehaviorProfile = function() end, inferBehaviorProfile = function() return 1 end,
}
package.loaded.SettingsModel = model
package.loaded.Localization = {
  text = function(s, ...) if select('#', ...) > 0 then return string.format(s, ...) end return s end,
  label = function(s, id) return s .. '###' .. (id or s) end,
}

local disabledDepth, globalDisabled = 0, false
local availableWidth, currentItemWidth = 700, nil
local combos, wrappedLabels = {}, {}
local function disabled() return globalDisabled or disabledDepth > 0 end
local ui = {
  StyleColor = { SliderGrab = 1 },
  ComboFlags = { None = 0 },
  pushDisabled = function() globalDisabled = true end,
  popDisabled = function() globalDisabled = false end,
  pushStyleColor = function() end, popStyleColor = function() end,
  itemHovered = function() return false end, availableSpaceX = function() return availableWidth end,
  measureDWriteText = function(text) return { x = #text * 8, y = 18 } end,
  pushItemWidth = function(w) currentItemWidth = w end, popItemWidth = function() currentItemWidth = nil end,
  columns = function() end, setColumnWidth = function() end, nextColumn = function() end,
  newLine = function() end, text = function() end, textColored = function() end,
  textWrapped = function(text) wrappedLabels[#wrappedLabels + 1] = text end,
  checkbox = function() return false end,
  combo = function(label) combos[#combos + 1] = { label = label, width = currentItemWidth }; return 1, false end,
  separator = function() end, setTooltip = function() end, windowWidth = function() return availableWidth end,
}
_G.ui = ui
_G.rgbm = function(...) return { ... } end
_G.RaceTrackManager = {
  TrackSideStrings = { [1] = 'Left', [2] = 'Right' },
  getOvertakingSide = function() return 1 end, getYieldingSide = function() return 2 end,
}
_G.ColorManager = { RGBM_Colors = setmetatable({}, { __index = function() return {} end }) }
_G.Theme = nil
_G.Constants = setmetatable({ APP_DEVELOPER = 'SnakeD' }, { __index = function() return false end })
_G.UIState = { activeTab = 'Overview', advancedControlsOpen = false }
_G.UIOperations = {
  createDisabledSection = function(isDisabled, callback)
    if isDisabled then disabledDepth = disabledDepth + 1 end
    callback()
    if isDisabled then disabledDepth = disabledDepth - 1 end
  end,
}

local captures, writes = {}, {}
local resetMode = false
local function slider(label, tip, value, min, max, width, format, default)
  captures[#captures + 1] = { kind = 'slider', label = label, value = value, min = min, max = max, default = default, disabled = disabled() }
  local result = disabled() and value or (resetMode and default or (value + 0.01))
  return result
end
package.loaded['lib/uilib/Slider'] = { render = slider, renderStacked = slider }
package.loaded['lib/uilib/Toggle'] = { render = function() return false end }
package.loaded['lib/uilib/Section'] = { section = function(_, callback) callback() end }
_G.UILateralOffsetsImageWidget = { draw = function() captures[#captures + 1] = { kind = 'diagram', disabled = disabled() } end }
local originalStorage = setmetatable({}, {
  __index = function(_, key) return storage[key] end,
  __newindex = function(_, key, value) writes[#writes + 1] = { key = key, value = value }; storage[key] = value end,
})
-- The SettingsWindow captures a reference at module initialization; route writes
-- through the tracked table while keeping the fixture state compact.
model.getStorage = function() return originalStorage end
package.loaded.SettingsWindow = nil
local SettingsWindow = require('SettingsWindow')

local tabs = { 'Overview', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }
local lateralTabCount, lateralTab = 0, nil
for _, tab in ipairs(tabs) do
  captures, writes = {}, {}
  SettingsWindow.drawContent(tab, true)
  local lateralSliders, diagram = {}, 0
  for _, item in ipairs(captures) do
    if item.kind == 'diagram' then diagram = diagram + 1 end
    if item.kind == 'slider' and (item.label:find('settings.offset.overtaking', 1, true) or
      item.label:find('settings.offset.yielding', 1, true) or item.label:find('Default Lateral Offset', 1, true)) then
      lateralSliders[#lateralSliders + 1] = item
    end
  end
  if #lateralSliders > 0 or diagram > 0 then lateralTabCount, lateralTab = lateralTabCount + 1, tab end
  if tab == 'Overview' then check(#lateralSliders == 0 and diagram == 0, 'Overview has no lateral sliders or editable diagram') end
end
check(lateralTabCount == 1 and lateralTab ~= 'Overview', 'all three lateral controls and diagram route to exactly one non-Overview tab')
check(lateralTab == 'Behavior', 'lateral controls and diagram route to the decided Behavior tab')
local profileCombo
for _, combo in ipairs(combos) do
  if combo.label:find('behavior.profile', 1, true) then profileCombo = combo end
end
check(profileCombo and profileCombo.label == 'AI Behavior Profile###behavior.profile',
  'profile combo keeps its visible label and stable ID at normal width')
storage.defaultLateralOffset, storage.overtakingLateralOffset, storage.yieldingLateralOffset = 0.1, 0.2, 0.3

availableWidth = 240
combos, wrappedLabels = {}, {}
SettingsWindow.drawContent('Behavior', true)
profileCombo = nil
for _, combo in ipairs(combos) do if combo.label:find('behavior.profile', 1, true) then profileCombo = combo end end
check(profileCombo and profileCombo.label == '###behavior.profile' and profileCombo.width == 240,
  'narrow profile combo hides the label while preserving its ID and available width')
local wrappedProfile = false
for _, text in ipairs(wrappedLabels) do if text == 'AI Behavior Profile' then wrappedProfile = true end end
check(wrappedProfile, 'narrow profile label is shown separately as wrapped text')
availableWidth = 700
storage.defaultLateralOffset, storage.overtakingLateralOffset, storage.yieldingLateralOffset = 0.1, 0.2, 0.3

local function findLateralControls(items)
  local found = { overtaking = {}, yielding = {}, default = {}, diagram = 0 }
  for _, item in ipairs(items) do
    if item.kind == 'diagram' then found.diagram = found.diagram + 1 end
    if item.kind == 'slider' then
      if item.label:find('settings.offset.overtaking', 1, true) then found.overtaking[#found.overtaking + 1] = item end
      if item.label:find('settings.offset.yielding', 1, true) then found.yielding[#found.yielding + 1] = item end
      if item.label:find('Default Lateral Offset', 1, true) then found.default[#found.default + 1] = item end
    end
  end
  return found
end

local function assertWrites(expected, message)
  local found = {}
  for _, write in ipairs(writes) do
    if expected[write.key] ~= nil then
      check(found[write.key] == nil, message .. ': duplicate write for ' .. write.key)
      found[write.key] = write.value
    end
  end
  for key, value in pairs(expected) do
    check(near(found[key], value), message .. ': expected ' .. key .. '=' .. tostring(value) .. ', got ' .. tostring(found[key]))
  end
end

-- Find the three lateral controls on their routed tab and assert stable IDs,
-- numeric contracts, defaults, normal edits, and guarded control behavior.
captures, writes = {}, {}
SettingsWindow.drawContent(lateralTab, true)
local normalWrites = {}
for _, write in ipairs(writes) do normalWrites[write.key] = write.value end
assertWrites({ overtakingLateralOffset = 0.21, defaultLateralOffset = 0.11, yieldingLateralOffset = 0.31 },
  'normal edits persist each lateral value at prior value + 0.01')
local lateral = {}
for _, item in ipairs(captures) do
  if item.kind == 'slider' and (item.label:find('settings.offset.overtaking', 1, true) or
    item.label:find('settings.offset.yielding', 1, true) or item.label:find('Default Lateral Offset', 1, true)) then
    lateral[#lateral + 1] = item
  end
end
check(#lateral == 3, 'routed section exposes exactly three lateral sliders')
local uniqueIDs = {}
for _, item in ipairs(lateral) do
  check(item.min == -1 and item.max == 1 and item.default == 0.25, 'lateral range/default contract remains intact')
  check(item.label:find('###settings.offset.overtaking', 1, true) or
    item.label:find('###settings.offset.yielding', 1, true) or item.label:find('Default Lateral Offset', 1, true),
    'stable lateral IDs/default English label are retained')
  check(not item.disabled, 'active lateral control is enabled')
  local id = item.label:match('###([^#]+)$')
  if id then uniqueIDs[id] = (uniqueIDs[id] or 0) + 1 end
end
check(uniqueIDs['settings.offset.overtaking'] == 1 and uniqueIDs['settings.offset.yielding'] == 1,
  'the two stable IDs each appear exactly once and are distinct')
local routedItems = findLateralControls(captures)
check(#routedItems.overtaking == 1 and #routedItems.yielding == 1 and #routedItems.default == 1 and routedItems.diagram == 1,
  'Behavior contains exactly one of each two ID sliders, default slider, and diagram')
local lastLateral, firstOtherSlider = 0, nil
for index, item in ipairs(captures) do
  if item.kind == 'diagram' or item.kind == 'slider' and
    (item.label:find('settings.offset.', 1, true) or item.label:find('Default Lateral Offset', 1, true)) then
    lastLateral = index
  elseif item.kind == 'slider' and not firstOtherSlider then
    firstOtherSlider = index
  end
end
check(lastLateral > 0 and firstOtherSlider and lastLateral < firstOtherSlider,
  'lateral controls and diagram precede the remaining Behavior sliders')

captures, writes, resetMode = {}, {}, true
SettingsWindow.drawContent(lateralTab, true)
resetMode = false
assertWrites({ defaultLateralOffset = 0.25, overtakingLateralOffset = 0.25, yieldingLateralOffset = 0.25 },
  'mocked reset writes configured defaults to all three lateral keys')

captures, writes = {}, {}
local globalBefore = { defaultLateralOffset = storage.defaultLateralOffset,
  overtakingLateralOffset = storage.overtakingLateralOffset, yieldingLateralOffset = storage.yieldingLateralOffset }
SettingsWindow.drawContent(lateralTab, false)
for _, item in ipairs(captures) do
  if item.kind == 'slider' and (item.label:find('settings.offset.', 1, true) or item.label:find('Default Lateral Offset', 1, true)) then
    check(item.disabled, 'global disabled state prevents lateral edits')
  end
end
check(storage.defaultLateralOffset == globalBefore.defaultLateralOffset and
  storage.overtakingLateralOffset == globalBefore.overtakingLateralOffset and
  storage.yieldingLateralOffset == globalBefore.yieldingLateralOffset,
  'global disabled drawing does not change any lateral values')

for _, disabledFeature in ipairs({ 'yielding', 'overtaking' }) do
  yielding.handleYielding, overtaking.handleOvertaking = disabledFeature ~= 'yielding', disabledFeature ~= 'overtaking'
  captures, writes = {}, {}
  local before = { defaultLateralOffset = storage.defaultLateralOffset,
    overtakingLateralOffset = storage.overtakingLateralOffset, yieldingLateralOffset = storage.yieldingLateralOffset }
  SettingsWindow.drawContent(lateralTab, true)
  for _, item in ipairs(captures) do
    if item.kind == 'slider' and item.label:find('settings.offset.', 1, true) then
      local shouldDisable = item.label:find('settings.offset.' .. disabledFeature, 1, true) ~= nil
      check(item.disabled == shouldDisable, disabledFeature .. ' feature flag guards only its associated lateral control')
    end
  end
  local after = { defaultLateralOffset = storage.defaultLateralOffset,
    overtakingLateralOffset = storage.overtakingLateralOffset, yieldingLateralOffset = storage.yieldingLateralOffset }
  local blockedKey = disabledFeature .. 'LateralOffset'
  check(after[blockedKey] == before[blockedKey], disabledFeature .. ' disabled control preserves its value')
  check(near(after.defaultLateralOffset, before.defaultLateralOffset + 0.01),
    disabledFeature .. ' flag leaves default control editable')
  local otherKey = (disabledFeature == 'yielding' and 'overtakingLateralOffset' or 'yieldingLateralOffset')
  check(near(after[otherKey], before[otherKey] + 0.01), disabledFeature .. ' flag leaves the other lateral control editable')
end
print('settings navigation routing contracts passed (headless SettingsWindow; mocks do not establish CSP behavior)')
