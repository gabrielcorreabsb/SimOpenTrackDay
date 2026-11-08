local Section = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local vec2 = vec2
local Localization = require('Localization')
local EMPTY_OPTIONS = {}

-- Uses one flat shared surface for the heading; the border remains a quiet divider
-- around content and no inset gradient layer can create a contrasting left strip.
Section.section = function(label, callback, opts)
  opts = opts or EMPTY_OPTIONS
  local left = ui.getCursor()
  local available = opts.width or ui.availableSpaceX()
  local title = Localization.text(label)
  local titleSize = ui.measureText(title, -1)
  local headerHeight = math.max(Theme.type.section, titleSize.y) + Theme.spacing.md
  local headerRight = left.x + available
  local headerBottom = left.y + headerHeight
  ui.drawRectFilled(left, vec2(headerRight, headerBottom), Theme.colors.surface, 7, 0)
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + Theme.spacing.sm))
  ui.beginGroup()
  ui.textColored(title, Theme.colors.white)
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + headerHeight + Theme.spacing.sm))
  if callback then
    local callbackOk, callbackError = pcall(callback)
    local groupCloseOk, groupCloseError = pcall(ui.endGroup)
    if not callbackOk then error(callbackError, 0) end
    if not groupCloseOk then error(groupCloseError, 0) end
  else
    ui.endGroup()
  end
  local boundsMin, boundsMax = ui.itemRectMin(), ui.itemRectMax()
  local finish = ui.getCursor()
  local top = math.min(left.y, boundsMin.y)
  local bottom = math.max(finish.y, boundsMax.y + Theme.spacing.sm)
  ui.drawRect(vec2(left.x, top), vec2(left.x + available, bottom), Theme.colors.divider, 7, 0, 1)
  ui.setCursor(vec2(left.x, bottom + (opts.trailing == false and 0 or Theme.spacing.md)))
end

return Section
