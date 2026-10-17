local Section = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local vec2 = vec2

-- Uses a restrained heading/divider treatment rather than an overlaying draw-list
-- background, so native controls always remain visible and first-frame sizing is safe.
Section.section = function(label, callback, opts)
  opts = opts or {}
  local left = ui.getCursor()
  local available = opts.width or ui.availableSpaceX()
  local headerHeight = Theme.type.section + Theme.spacing.md
  ui.drawRectFilled(left, vec2(left.x + available, left.y + headerHeight), Theme.colors.surface, 4, 0)
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + Theme.spacing.sm))
  ui.beginGroup()
  Style.push(ui.StyleColor.Text, Theme.colors.accent)
  ui.dwriteText(label, Theme.type.section)
  Style.pop()
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + headerHeight + Theme.spacing.sm))
  if callback then callback() end
  ui.endGroup()
  local boundsMin, boundsMax = ui.itemRectMin(), ui.itemRectMax()
  local finish = ui.getCursor()
  local top = math.min(left.y, boundsMin.y)
  local bottom = math.max(finish.y, boundsMax.y + Theme.spacing.sm)
  ui.drawRect(vec2(left.x, top), vec2(left.x + available, bottom), Theme.colors.divider, 4, 0, 1)
  ui.setCursor(vec2(left.x, bottom + (opts.trailing == false and 0 or Theme.spacing.md)))
end

return Section
