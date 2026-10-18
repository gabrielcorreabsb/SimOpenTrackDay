local Section = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local vec2 = vec2
local Localization = require('Localization')
local ui_drawRectFilledMultiColor = ui.drawRectFilledMultiColor
local EMPTY_OPTIONS = {}

-- Uses a restrained heading/divider treatment rather than an overlaying draw-list
-- background, so native controls always remain visible and first-frame sizing is safe.
Section.section = function(label, callback, opts)
  opts = opts or EMPTY_OPTIONS
  local left = ui.getCursor()
  local available = opts.width or ui.availableSpaceX()
  local headerHeight = Theme.type.section + Theme.spacing.md
  local headerRight = left.x + available
  local headerBottom = left.y + headerHeight
  ui.drawRectFilled(left, vec2(headerRight, headerBottom), Theme.colors.surface, 7, 0)
  if available > 10 then
    ui_drawRectFilledMultiColor(
      vec2(left.x + 5, left.y + 1), vec2(headerRight - 5, headerBottom - 1),
      Theme.colors.sectionGradientLeft, Theme.colors.sectionGradientRight,
      Theme.colors.surface, Theme.colors.sectionGradientLeft)
  end
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + Theme.spacing.sm))
  ui.beginGroup()
  Style.push(ui.StyleColor.Text, Theme.colors.white)
  ui.dwriteText(Localization.text(label), Theme.type.section)
  Style.pop()
  ui.setCursor(vec2(left.x + Theme.spacing.md, left.y + headerHeight + Theme.spacing.sm))
  if callback then callback() end
  ui.endGroup()
  local boundsMin, boundsMax = ui.itemRectMin(), ui.itemRectMax()
  local finish = ui.getCursor()
  local top = math.min(left.y, boundsMin.y)
  local bottom = math.max(finish.y, boundsMax.y + Theme.spacing.sm)
  ui.drawRect(vec2(left.x, top), vec2(left.x + available, bottom), Theme.colors.divider, 7, 0, 1)
  ui.setCursor(vec2(left.x, bottom + (opts.trailing == false and 0 or Theme.spacing.md)))
end

return Section
