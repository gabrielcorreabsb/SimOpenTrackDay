-- Focused checks of the real project-owned Toggle, Slider and Style modules.
-- Mocks exercise contracts and cleanup only; they do not establish CSP visuals.

package.path = './?.lua;./?/init.lua;' .. package.path

local checks = 0
local function check(condition, message)
  checks = checks + 1
  if not condition then error('FAIL: ' .. message, 2) end
end

local state = {
  width = 480, font = 'Main', locale = 'en', styleDepth = 0, stylePushes = {}, stylePops = 0,
  itemWidths = {}, measureCalls = {}, dwriteCalls = 0, checkboxRows = {}, sliderRows = {},
  textRows = {}, tooltip = nil, hovered = false, rightClicked = false,
  checkboxChanged = false, sliderValue = 0.75, throwCheckbox = false, throwSlider = false,
  disabledDepth = 0,
}
local translations = {
  en = {
    ['Toggle a long translated setting label and preserve the state'] = 'Toggle a long translated setting label and preserve the state',
    ['Default'] = 'Default', ['Test tooltip'] = 'Test tooltip',
  },
  ['pt-BR'] = {
    ['Toggle a long translated setting label and preserve the state'] = 'Ativar esta opção traduzida e manter o estado visível',
    ['Default'] = 'Padrão', ['Test tooltip'] = 'Dica de teste',
  },
  es = {
    ['Toggle a long translated setting label and preserve the state'] = 'Activar esta opción traducida y mantener visible el estado',
    ['Default'] = 'Predeterminado', ['Test tooltip'] = 'Ayuda de prueba',
  },
}
local function measure(text, font)
  local maximum = 0
  for line in (text .. '\n'):gmatch('(.-)\n') do
    maximum = math.max(maximum, #line * (font == 'Title' and 11 or 8))
  end
  return { x = maximum, y = font == 'Title' and 24 or 18 }
end

_G.rgbm = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
_G.vec2 = function(x, y) return { x = x, y = y } end
_G.ui = {
  StyleColor = {
    FrameBg = 1, FrameBgHovered = 2, FrameBgActive = 3,
    CheckMark = 4, SliderGrab = 5, SliderGrabActive = 6,
  },
  Font = { Main = 'Main', Title = 'Title' },
  availableSpaceX = function() return state.width end,
  measureText = function(text)
    state.measureCalls[#state.measureCalls + 1] = { text = text, font = state.font }
    return measure(text, state.font)
  end,
  measureDWriteText = function(text)
    state.dwriteCalls = state.dwriteCalls + 1
    return { x = #text, y = 10 }
  end,
  checkbox = function(label, checked)
    if state.throwCheckbox then error('injected checkbox failure', 0) end
    state.checkboxRows[#state.checkboxRows + 1] = {
      label = label, checked = checked, changed = state.checkboxChanged,
      font = state.font, disabledDepth = state.disabledDepth,
    }
    return state.checkboxChanged
  end,
  slider = function(label, value, minimum, maximum, format)
    if state.throwSlider then error('injected slider failure', 0) end
    state.sliderRows[#state.sliderRows + 1] = {
      label = label, value = value, minimum = minimum, maximum = maximum,
      format = format, width = state.itemWidths[#state.itemWidths],
      font = state.font, styleDepth = state.styleDepth,
    }
    return state.sliderValue
  end,
  pushStyleColor = function(index, color)
    state.styleDepth = state.styleDepth + 1
    state.stylePushes[#state.stylePushes + 1] = { index = index, color = color }
  end,
  popStyleColor = function()
    assert(state.styleDepth > 0, 'mock style stack underflow')
    state.styleDepth = state.styleDepth - 1
    state.stylePops = state.stylePops + 1
  end,
  pushItemWidth = function(width) state.itemWidths[#state.itemWidths + 1] = width end,
  popItemWidth = function()
    assert(#state.itemWidths > 0, 'mock item-width stack underflow')
    state.itemWidths[#state.itemWidths] = nil
  end,
  textWrapped = function(text)
    state.textRows[#state.textRows + 1] = { text = text, font = state.font, method = 'wrapped' }
  end,
  text = function(text)
    state.textRows[#state.textRows + 1] = { text = text, font = state.font, method = 'text' }
  end,
  itemHovered = function() return state.hovered end,
  setTooltip = function(text) state.tooltip = text end,
  MouseButton = { Right = 1 },
  mouseClicked = function(button) return button == 1 and state.rightClicked end,
}
package.loaded.Localization = {
  text = function(source, ...)
    local text = translations[state.locale][source] or source
    if select('#', ...) > 0 then return string.format(text, ...) end
    return text
  end,
  label = function(source, stableID)
    local visible = translations[state.locale][source] or source
    return visible .. '###' .. (stableID or source)
  end,
}
package.loaded['lib/uilib/Theme'] = nil
package.loaded['lib/uilib/Style'] = nil
package.loaded['lib/uilib/Toggle'] = nil
package.loaded['lib/uilib/Slider'] = nil
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Toggle = require('lib/uilib/Toggle')
local Slider = require('lib/uilib/Slider')

local longToggle = 'Toggle a long translated setting label and preserve the state'
for _, locale in ipairs({ 'en', 'pt-BR', 'es' }) do
  state.locale, state.width = locale, 170
  local changed = Toggle.render(longToggle, false)
  local row = state.checkboxRows[#state.checkboxRows]
  local visible, id = row.label:match('^(.-)###(.*)$')
  check(changed == false and row.checked == false and id == longToggle,
    'unchecked native checkbox preserves value and stable source ID in ' .. locale)
  check(visible and visible:find('\n', 1, true) and visible:gsub('\n', ' ') == translations[locale][longToggle],
    'checkbox wraps the localized visible label in native-font measurements in ' .. locale)
  check(row.font == 'Main' and #state.measureCalls > 0 and state.measureCalls[#state.measureCalls].font == 'Main',
    'checkbox label is measured with its active native font in ' .. locale)
  state.checkboxChanged = true
  check(Toggle.render(longToggle, true) == true and state.checkboxRows[#state.checkboxRows].checked == true,
    'checked state remains explicit and native checkbox change is returned in ' .. locale)
  state.checkboxChanged = false
  check(state.styleDepth == 0, 'checkbox Style scopes are balanced in ' .. locale)
end
state.width = 700
Toggle.render(longToggle, false)
check(not state.checkboxRows[#state.checkboxRows].label:find('\n', 1, true),
  'checkbox label remains single-line when it fits at wide width')
state.disabledDepth = 1
Toggle.render(longToggle, true)
check(state.checkboxRows[#state.checkboxRows].checked and state.checkboxRows[#state.checkboxRows].disabledDepth == 1,
  'externally disabled checkbox retains its checked state and visible native control')
state.disabledDepth = 0

local beforeToggleFailure = state.stylePops
state.throwCheckbox = true
local toggleOK, toggleError = pcall(Toggle.render, longToggle, true)
state.throwCheckbox = false
check(not toggleOK and toggleError == 'injected checkbox failure',
  'checkbox failure rethrows its original error')
check(state.styleDepth == 0 and state.stylePops == beforeToggleFailure + 6,
  'checkbox failure restores all real Style color scopes')
local accentTokens = 0
for _, push in ipairs(state.stylePushes) do
  if push.index == ui.StyleColor.CheckMark and push.color == Theme.colors.accent then accentTokens = accentTokens + 1 end
end
check(accentTokens > 0 and state.dwriteCalls == 0,
  'checkboxes retain the blue checked mark and do not use DirectWrite for native label sizing')

state.width, state.locale = 480, 'en'
local defaultValue = 0.4
local sliderResult = Slider.render('Sample value###settings.sample', 'Test tooltip', 0.25,
  -2, 3, 220, '%.3f', defaultValue)
local ordinarySlider = state.sliderRows[#state.sliderRows]
check(sliderResult == state.sliderValue and ordinarySlider.label == 'Sample value###settings.sample' and
  ordinarySlider.value == 0.25 and ordinarySlider.minimum == -2 and ordinarySlider.maximum == 3 and
  ordinarySlider.format == '%.3f' and ordinarySlider.width == 220,
  'slider preserves ID, value, range, precision format and normal width')
check(state.styleDepth == 0 and #state.itemWidths == 0 and ordinarySlider.font == 'Main',
  'slider returns with native font, Style and item-width scopes balanced')

state.hovered, state.rightClicked, state.sliderValue, state.locale = true, true, 2.5, 'pt-BR'
local resetValue = Slider.render('Reset value###settings.reset', 'Test tooltip', 2.5,
  -5, 5, 180, '%.1f', defaultValue)
check(resetValue == defaultValue and state.tooltip:find('Dica de teste', 1, true) and
  state.tooltip:find('Padrão: 0.40', 1, true),
  'hover tooltip is localized and right-click restores the declared default')
state.hovered, state.rightClicked = false, false

state.locale, state.width = 'es', 180
local stackedResult = Slider.render(translations.es[longToggle] .. '###settings.long.slider',
  'Test tooltip', 0.5, 0, 1, 220, '%.2f', 0.5)
local stackedSlider = state.sliderRows[#state.sliderRows]
local stackedLabel = state.textRows[#state.textRows]
check(stackedResult == state.sliderValue and stackedLabel and stackedLabel.method == 'wrapped' and
  stackedLabel.text == translations.es[longToggle] and stackedLabel.font == 'Main' and
  stackedSlider.label == '###settings.long.slider' and stackedSlider.width == 180,
  'narrow slider stacks a native-measured localized label while preserving hidden widget ID and bounded width')

state.width = 100
Slider.render('###settings.hidden', 'Test tooltip', 0.2, 0, 1, 220, '%.1f', 0.2)
local hiddenSlider = state.sliderRows[#state.sliderRows]
check(hiddenSlider.label == '###settings.hidden' and hiddenSlider.width == 100 and
  #state.textRows == 1,
  'hidden slider label is not exposed or wrapped in narrow layout')

local styleDepthBeforeError, itemWidthsBeforeError = state.styleDepth, #state.itemWidths
state.throwSlider = true
local sliderOK, sliderError = pcall(Slider.render, 'Error slider###settings.error', 'Test tooltip',
  0.3, 0, 1, 160, '%.2f', 0.3)
state.throwSlider = false
check(not sliderOK and sliderError == 'injected slider failure', 'slider failure rethrows its original error')
check(state.styleDepth == styleDepthBeforeError and #state.itemWidths == itemWidthsBeforeError,
  'slider failure restores real Style and item-width scopes')

local savedWrapped = ui.textWrapped
ui.textWrapped = nil
package.loaded['lib/uilib/Slider'] = nil
Slider = require('lib/uilib/Slider')
state.width = 180
Slider.render(translations.es[longToggle] .. '###settings.fallback',
  'Test tooltip', 0.5, 0, 1, 220, '%.2f', 0.5)
check(state.textRows[#state.textRows].method == 'text' and
  state.sliderRows[#state.sliderRows].label == '###settings.fallback',
  'slider stacked-label fallback uses native ui.text when wrapped-text API is absent')
ui.textWrapped = savedWrapped

check(state.styleDepth == 0 and #state.itemWidths == 0 and state.dwriteCalls == 0,
  'all native controls finish without leaked styles, widths or DirectWrite measurements')
print(string.format('Native control tests passed: %d checks.', checks))
