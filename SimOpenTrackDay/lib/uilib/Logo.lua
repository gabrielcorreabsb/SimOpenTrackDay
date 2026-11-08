local Logo = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local vec2 = vec2

-- Compact vector OTD mark, drawn only from line primitives.
Logo.draw = function(size, position)
  size = size or 52
  local p = position or ui.getCursor()
  local s = size / 52
  local function pt(x, y) return vec2(p.x + x * s, p.y + y * s) end
  local red, white, dim = Theme.colors.accent, Theme.colors.text, Theme.colors.muted
  -- O: squared racing letterform
  ui.drawLine(pt(1, 7), pt(1, 31), red, 3*s)
  ui.drawLine(pt(1, 7), pt(12, 7), red, 3*s)
  ui.drawLine(pt(12, 7), pt(12, 31), red, 3*s)
  ui.drawLine(pt(1, 31), pt(12, 31), red, 3*s)
  -- T: broad cap and stem
  ui.drawLine(pt(16, 7), pt(31, 7), white, 3*s)
  ui.drawLine(pt(23.5, 7), pt(23.5, 31), white, 3*s)
  -- D: open angular bowl gives the monogram a circuit-like silhouette.
  ui.drawLine(pt(36, 7), pt(36, 31), red, 3*s)
  ui.drawLine(pt(36, 7), pt(43, 7), red, 3*s)
  ui.drawLine(pt(43, 7), pt(49, 13), red, 3*s)
  ui.drawLine(pt(49, 13), pt(49, 25), red, 3*s)
  ui.drawLine(pt(49, 25), pt(43, 31), red, 3*s)
  ui.drawLine(pt(43, 31), pt(36, 31), red, 3*s)
  -- Track line breaking away from the lettering, finishing in a start/finish dash.
  ui.drawLine(pt(2, 38), pt(17, 38), dim, 1.5*s)
  ui.drawLine(pt(17, 38), pt(22, 35), dim, 1.5*s)
  ui.drawLine(pt(22, 35), pt(29, 35), dim, 1.5*s)
  ui.drawLine(pt(29, 35), pt(34, 38), dim, 1.5*s)
  ui.drawLine(pt(34, 38), pt(50, 38), dim, 1.5*s)
  if position == nil then
    ui.dummy(vec2(size, size + Theme.spacing.sm))
  end
end

return Logo
