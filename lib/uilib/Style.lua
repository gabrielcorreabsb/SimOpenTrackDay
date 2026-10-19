local Style = {}
local ui = ui
local Theme = require('lib/uilib/Theme')
local vec2 = vec2
local ui_pushClipRect = ui.pushClipRect
local ui_popClipRect = ui.popClipRect
local colorStack = {}
local windowPushCounts = {}
local EMPTY_OPTIONS = {}

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
  opts = opts or EMPTY_OPTIONS
  if opts.background ~= false then
    -- getCursor() is in window/content coordinates and moves opposite the scroll.
    -- Add scroll and remove padding to pin the fill to the viewport. Only this
    -- fill replaces the content clip; ordinary content keeps its original clip.
    local cursor = ui.getCursor()
    local scroll = vec2(ui.getScrollX(), ui.getScrollY())
    local inset = Theme.layout.windowInset
    local left = vec2(cursor.x + scroll.x - inset, cursor.y + scroll.y - inset)
    local size = ui.windowSize()
    ui_pushClipRect(vec2(0, 0), size, false)
    local fillOk, fillError = pcall(ui.drawRectFilled, left, vec2(left.x + size.x, left.y + size.y), Theme.colors.bg)
    local clipPopOk, clipPopError = pcall(ui_popClipRect)
    if not fillOk then error(fillError, 0) end
    if not clipPopOk then error(clipPopError, 0) end
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

Style.pushButton = function(role)
  local colors = Theme.button[role]
  if not colors then error('Unknown button style role: ' .. tostring(role), 2) end
  push(colorIndex('Button'), colors.normal)
  push(colorIndex('ButtonHovered'), colors.hovered)
  push(colorIndex('ButtonActive'), colors.pressed)
  push(colorIndex('Text'), colors.text)
end

Style.popButton = function()
  pop(4)
end

Style.push = push
Style.pop = pop

return Style
