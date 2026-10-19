local Slider = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Localization = require('Localization')
local ui_textWrapped = ui.textWrapped or ui.text
local ui_measureText = ui.measureText

local function popSliderScopes()
  local styleOk, styleError = pcall(Style.popSurface)
  local widthOk, widthError = pcall(ui.popItemWidth)
  if not styleOk then return false, styleError end
  if not widthOk then return false, widthError end
  return true
end

local function render(label, tooltip, value, minValue, maxValue, width, format, defaultValue, forceStacked)
  local sourceLabel = label
  if not label:find('###', 1, true) and label:sub(1, 2) ~= '##' then label = Localization.label(label) end
  local visible, suffix = label:match('^(.-)(###.*)$')
  if not visible then visible, suffix = label, nil end
  local isHidden = visible:sub(1, 2) == '##' or visible == ''
  local availableWidth = math.max(0, ui.availableSpaceX())
  local stacked = not isHidden and (forceStacked or
    (ui_measureText(visible, -1).x + math.min(width, availableWidth) + Theme.spacing.sm > availableWidth))
  local sliderLabel = label
  if stacked then
    ui_textWrapped(visible)
    sliderLabel = suffix or ('###' .. sourceLabel)
    width = math.min(availableWidth, math.max(width, Theme.slider.stackedMaxWidth))
  end
  tooltip = Localization.text(tooltip)
  width = math.min(width, availableWidth)
  if format then format = Localization.text(format) end
  ui.pushItemWidth(width)
  Style.pushSurface()
  local sliderOk, result = pcall(ui.slider, sliderLabel, value, minValue, maxValue, format)
  local cleanupOk, cleanupError = popSliderScopes()
  if not sliderOk then error(result, 0) end
  if not cleanupOk then error(cleanupError, 0) end
  if ui.itemHovered() then
    ui.setTooltip(string.format('%s\n\n%s: %.2f', tooltip, Localization.text('Default'), defaultValue))
    if ui.mouseClicked(ui.MouseButton.Right) then result = defaultValue end
  end
  return result
end

-- Contract matches UIOperations.renderSlider exactly; long labels stack only
-- when the native label and slider would exceed the available content width.
Slider.render = function(label, tooltip, value, minValue, maxValue, width, format, defaultValue)
  return render(label, tooltip, value, minValue, maxValue, width, format, defaultValue, false)
end

-- Opt-in stacked variant for long labels. Keep the original hidden suffix on
-- ui.slider to preserve its ImGui ID; wrapped text is separate and non-interactive.
Slider.renderStacked = function(label, tooltip, value, minValue, maxValue, width, format, defaultValue)
  return render(label, tooltip, value, minValue, maxValue, width, format, defaultValue, true)
end

return Slider
