-- Small shared drawing/layout primitives for project-owned controls.
local UIControls = {}
local Theme = require('lib/uilib/Theme')

function UIControls.comboWidth(available, labelWidth, maximum)
  available = math.max(0, available or 0)
  if available < Theme.layout.responsiveLabelThreshold then return available, true end
  return math.max(0, math.min(maximum, available - math.max(0, labelWidth or 0) - Theme.spacing.sm)), false
end

function UIControls.chipWidth(textWidth, available, padding)
  return math.min(math.max(0, available or 0), math.max(0, (textWidth or 0) + (padding or Theme.spacing.lg)))
end

function UIControls.drawStatus(source, color, Localization, ui, vec2)
  local cursor = ui.getCursor()
  local size, gap = Theme.layout.statusDotSize, Theme.layout.statusDotGap
  ui.drawRectFilled(vec2(cursor.x, cursor.y + 5), vec2(cursor.x + size, cursor.y + 5 + size), color, size / 2, 0)
  ui.setCursor(vec2(cursor.x + size + gap, cursor.y))
  local text = Localization.text(source)
  if ui.textWrapped then ui.textWrapped(text) else ui.textColored(text, color) end
end

return UIControls
