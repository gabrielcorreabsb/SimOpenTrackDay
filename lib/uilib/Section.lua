local Section = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
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
  local title = Localization.text(label)
  local titleSize = ui.measureText(title, -1)
  local headerHeight = math.max(Theme.type.section, titleSize.y) + Theme.spacing.md
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
