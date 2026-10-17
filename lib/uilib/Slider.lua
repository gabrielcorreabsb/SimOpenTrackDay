local Slider = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')

-- Contract matches UIOperations.renderSlider exactly.
Slider.render = function(label, tooltip, value, minValue, maxValue, width, format, defaultValue)
  ui.pushItemWidth(width)
  Style.pushSurface()
  local result = ui.slider(label, value, minValue, maxValue, format)
  Style.popSurface()
  ui.popItemWidth()
  if ui.itemHovered() then
    ui.setTooltip(string.format('%s\n\nDefault: %.2f', tooltip, defaultValue))
    if ui.mouseClicked(ui.MouseButton.Right) then result = defaultValue end
  end
  return result
end

return Slider
