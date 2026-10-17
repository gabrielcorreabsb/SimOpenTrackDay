local Toggle = {}
local ui = ui
local Style = require('lib/uilib/Style')

Toggle.render = function(label, value)
  Style.pushSurface()
  Style.pushAccent()
  local changed = ui.checkbox(label, value)
  Style.popAccent()
  Style.popSurface()
  return changed
end

return Toggle
