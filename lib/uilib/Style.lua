local Style = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local vec2 = vec2
local colorStack = {}
local windowPushCounts = {}

local function push(index, color)
  ui.pushStyleColor(index, color)
  colorStack[#colorStack + 1] = true
end

local function pop(count)
  count = count or 1
  for _ = 1, count do
    if #colorStack == 0 then error('Style color stack underflow') end
    colorStack[#colorStack] = nil
    ui.popStyleColor()
  end
end

local function colorIndex(name)
  local colors = ui.StyleColor
  return colors[name]
end

Style.windowBegin = function(name, opts)
  opts = opts or {}
  if opts.background ~= false then
    -- getCursor() is in window/content coordinates and moves opposite the scroll.
    -- Add the active scroll offset to pin the fill to the viewport; the draw call
    -- remains clipped to the current window's client area.
    local cursor = ui.getCursor()
    local scroll = vec2(ui.getScrollX(), ui.getScrollY())
    local left = vec2(cursor.x + scroll.x, cursor.y + scroll.y)
    local size = ui.windowSize()
    ui.drawRectFilled(left, vec2(left.x + size.x, left.y + size.y), Theme.colors.bg)
  end
  push(colorIndex('Text'), Theme.colors.text)
  push(colorIndex('Border'), Theme.colors.divider)
  Style.pushAccent()
  windowPushCounts[#windowPushCounts + 1] = 5
  return name
end

Style.windowEnd = function()
  local count = windowPushCounts[#windowPushCounts]
  if not count then error('Style.windowEnd without windowBegin') end
  windowPushCounts[#windowPushCounts] = nil
  pop(count)
end

Style.pushAccent = function()
  push(colorIndex('CheckMark'), Theme.colors.accent)
  push(colorIndex('SliderGrab'), Theme.colors.accent)
  push(colorIndex('SliderGrabActive'), Theme.colors.accent)
end

Style.popAccent = function()
  pop(3)
end

Style.pushSurface = function()
  push(colorIndex('FrameBg'), Theme.colors.surface)
  push(colorIndex('FrameBgHovered'), Theme.colors.divider)
  push(colorIndex('FrameBgActive'), Theme.colors.accentSoft)
end

Style.popSurface = function()
  pop(3)
end

Style.push = push
Style.pop = pop

return Style
