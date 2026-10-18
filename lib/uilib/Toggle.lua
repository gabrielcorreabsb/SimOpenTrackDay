local Toggle = {}
local ui = ui
local Style = require('lib/uilib/Style')
local Localization = require('Localization')

Toggle.render = function(label, value)
  if not label:find('###', 1, true) and label:sub(1, 2) ~= '##' then
    label = Localization.label(label)
  end
  Style.pushSurface()
  Style.pushAccent()
  local changed = ui.checkbox(label, value)
  Style.popAccent()
  Style.popSurface()
  return changed
end

return Toggle
