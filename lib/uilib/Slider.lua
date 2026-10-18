local Slider = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Localization = require('Localization')

-- Contract matches UIOperations.renderSlider exactly.
Slider.render = function(label, tooltip, value, minValue, maxValue, width, format, defaultValue)
  if not label:find('###', 1, true) and label:sub(1, 2) ~= '##' then label = Localization.label(label) end
  tooltip = Localization.text(tooltip)
  width = math.min(width, math.max(0, ui.availableSpaceX()))
  if format then format = Localization.text(format) end
  ui.pushItemWidth(width)
  Style.pushSurface()
  local result = ui.slider(label, value, minValue, maxValue, format)
  Style.popSurface()
  ui.popItemWidth()
  if ui.itemHovered() then
    ui.setTooltip(string.format('%s\n\n%s: %.2f', tooltip, Localization.text('Default'), defaultValue))
    if ui.mouseClicked(ui.MouseButton.Right) then result = defaultValue end
  end
  return result
end

return Slider
