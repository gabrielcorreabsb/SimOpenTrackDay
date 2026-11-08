local UILateralOffsetsImageWidget = {}

local ui = ui
local ui_drawRectFilled = ui.drawRectFilled
local ui_drawRect = ui.drawRect
local ui_drawLine = ui.drawLine
local ui_getCursor = ui.getCursor
local ui_setCursor = ui.setCursor
local ui_availableSpaceX = ui.availableSpaceX
local ui_measureText = ui.measureText
local ui_text = ui.text
local ui_textColored = ui.textColored
local ui_textLineHeightWithSpacing = ui.textLineHeightWithSpacing
local ui_itemRectMax = ui.itemRectMax
local Localization = require('Localization')
local Theme = require('lib/uilib/Theme')
local math = math
local math_max = math.max
local vec2 = vec2

local GRAPH_MIN_WIDTH = 300
local PANEL_PADDING = 12
local NARROW_PADDING = 6
local ROW_GAP = 10
local TEXT_GAP = 4
local BLOCK_GAP = 8
local AXIS_GAP = 8
local MARKER_SIZE = 10
local TRACK_HEIGHT = 16
local CONTENT_SAFETY = 2
local PANEL_ROUNDING = 4

-- Preserve the established semantic marker colors: normal, yielding and overtaking.
local COLOR_DEFAULT = rgbm(0.40, 1.00, 0.40, 1.00)
local COLOR_YIELDING = rgbm(1.00, 0.70, 0.20, 1.00)
local COLOR_OVERTAKE = rgbm(0.20, 0.65, 1.00, 1.00)

local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Overtaking = StorageManager.getStorage_Overtaking()
local wrappedLineScratch = {}

local ROWS = {
  { label = 'Default', color = COLOR_DEFAULT, mode = 1 },
  { label = 'Yielding', color = COLOR_YIELDING, mode = 2 },
  { label = 'Overtaking', color = COLOR_OVERTAKE, mode = 3 },
}
local rowValues = { 0, 0, 0 }
local rowStatuses = { '', '', '' }
local rowTitleHeights = { 0, 0, 0 }

local function clampNorm(value)
  if value < -1 then return -1 end
  if value > 1 then return 1 end
  return value
end

local function nativeLineHeight()
  if ui_textLineHeightWithSpacing then return ui_textLineHeightWithSpacing() end
  return ui_measureText('M', -1).y
end

local function nativeTextWidth(text)
  return ui_measureText(text, -1).x
end

local function pushWrappedLine(lineCount, line)
  lineCount = lineCount + 1
  wrappedLineScratch[lineCount] = line
  return lineCount
end

local function nextUTF8Byte(text, index)
  local first = string.byte(text, index)
  if not first or first < 128 then return index + 1 end
  if first < 224 then return index + 2 end
  if first < 240 then return index + 3 end
  return index + 4
end

-- Explicit line breaks keep native measurement and drawing inside the same panel width.
local function wrapNativeText(text, maxWidth)
  for i = #wrappedLineScratch, 1, -1 do wrappedLineScratch[i] = nil end
  maxWidth = math_max(1, maxWidth)
  local line, lineCount = '', 0
  for word in text:gmatch('%S+') do
    local candidate = line == '' and word or (line .. ' ' .. word)
    if line ~= '' and nativeTextWidth(candidate) > maxWidth then
      lineCount = pushWrappedLine(lineCount, line)
      line = ''
    end
    if nativeTextWidth(word) <= maxWidth then
      line = line == '' and word or (line .. ' ' .. word)
    else
      local index = 1
      while index <= #word do
        local nextIndex = nextUTF8Byte(word, index)
        local glyph = word:sub(index, nextIndex - 1)
        candidate = line .. glyph
        if line ~= '' and nativeTextWidth(candidate) > maxWidth then
          lineCount = pushWrappedLine(lineCount, line)
          line = glyph
        else
          line = candidate
        end
        index = nextIndex
      end
    end
  end
  if line ~= '' then lineCount = pushWrappedLine(lineCount, line) end
  if lineCount == 0 then return '' end
  return table.concat(wrappedLineScratch, '\n', 1, lineCount)
end

local function measuredBlockHeight(text, width)
  local wrapped = wrapNativeText(text, width)
  local measured = ui_measureText(wrapped, -1).y
  return math_max(nativeLineHeight(), measured) + CONTENT_SAFETY
end

local function currentItemBottom()
  local cursorBottom = ui_getCursor().y
  if ui_itemRectMax then
    local itemMax = ui_itemRectMax()
    if itemMax then return math_max(cursorBottom, itemMax.y) end
  end
  return cursorBottom
end

local function drawWrappedText(text, x, y, width, color)
  local wrapped = wrapNativeText(text, width)
  ui_setCursor(vec2(x, y))
  if color then
    ui_textColored(wrapped, color)
  else
    ui_text(wrapped)
  end
  return currentItemBottom()
end

local function drawSingleLine(text, color, x, y)
  ui_setCursor(vec2(x, y))
  ui_textColored(text, color)
  return currentItemBottom()
end

local function markerPosition(value, trackLeft, trackWidth)
  local normalized = (clampNorm(value) + 1) * 0.5
  return trackLeft + normalized * trackWidth
end

local function loadRows(storage)
  rowValues[1] = storage.defaultLateralOffset
  rowValues[2] = storage.yieldingLateralOffset
  rowValues[3] = storage.overtakingLateralOffset
  rowStatuses[1] = Localization.text('Active · %.3f', rowValues[1])
  rowStatuses[2] = storage_Yielding.handleYielding and
    Localization.text('Enabled · %.3f', rowValues[2]) or Localization.text('Disabled · saved %.3f', rowValues[2])
  rowStatuses[3] = storage_Overtaking.handleOvertaking and
    Localization.text('Enabled · %.3f', rowValues[3]) or Localization.text('Disabled · saved %.3f', rowValues[3])
end

---@param storage StorageTable
---@param rightInset? number Optional inset reserved at the right edge of the containing section.
function UILateralOffsetsImageWidget.draw(storage, rightInset)
  local cursor = ui_getCursor()
  local availableWidth = math_max(0, ui_availableSpaceX())
  if availableWidth < 80 and not rightInset then return end

  rightInset = math_max(0, rightInset or 0)
  local panelWidth = math_max(0, availableWidth - rightInset)
  if panelWidth < 80 then return end
  local graphEnabled = panelWidth >= GRAPH_MIN_WIDTH
  local padding = panelWidth < 180 and NARROW_PADDING or PANEL_PADDING
  local innerWidth = math_max(1, panelWidth - padding * 2)
  local panelLeft = cursor.x
  local contentLeft = panelLeft + padding
  local instruction = Localization.text('Choose where AI cars try to position themselves in each situation.')
  local targetNote = Localization.text('Configured targets, not live car positions.')
  local safetyNote = Localization.text('The maneuver depends on traffic and safety conditions.')
  local axisLeft = Localization.text('−1 · Left')
  local axisCenter = Localization.text('0')
  local axisRight = Localization.text('+1 · Right')
  local lineHeight = nativeLineHeight()

  loadRows(storage)
  local instructionHeight = measuredBlockHeight(instruction, innerWidth)
  local targetHeight = measuredBlockHeight(targetNote, innerWidth)
  local safetyHeight = measuredBlockHeight(safetyNote, innerWidth)
  local panelHeight = padding + instructionHeight + BLOCK_GAP + targetHeight + BLOCK_GAP + safetyHeight + BLOCK_GAP
  if graphEnabled then panelHeight = panelHeight + lineHeight + AXIS_GAP + 40 + TEXT_GAP end
  for index = 1, 3 do
    rowTitleHeights[index] = measuredBlockHeight(Localization.text(ROWS[index].label) .. ' · ' .. rowStatuses[index], innerWidth-14)
    panelHeight = panelHeight + rowTitleHeights[index] + ROW_GAP
  end
  panelHeight = panelHeight + padding

  local panelTL = vec2(panelLeft, cursor.y)
  local panelBR = vec2(panelLeft + panelWidth, cursor.y + panelHeight)
  ui_drawRectFilled(panelTL, panelBR, Theme.colors.surface, PANEL_ROUNDING)
  ui_drawRect(panelTL, panelBR, Theme.colors.divider, PANEL_ROUNDING)

  local y = cursor.y + padding
  local actualBottom = drawWrappedText(instruction, contentLeft, y, innerWidth)
  y = math_max(y + instructionHeight, actualBottom) + BLOCK_GAP
  actualBottom = drawWrappedText(targetNote, contentLeft, y, innerWidth)
  y = math_max(y + targetHeight, actualBottom) + BLOCK_GAP
  actualBottom = drawWrappedText(safetyNote, contentLeft, y, innerWidth)
  y = math_max(y + safetyHeight, actualBottom) + BLOCK_GAP

  local trackLeft = contentLeft + MARKER_SIZE * 0.5
  local trackWidth = math_max(1, innerWidth - MARKER_SIZE)
  if graphEnabled then
    local centerWidth = nativeTextWidth(axisCenter)
    local rightWidth = nativeTextWidth(axisRight)
    drawSingleLine(axisLeft, Theme.colors.muted, contentLeft, y)
    drawSingleLine(axisCenter, Theme.colors.muted, trackLeft + trackWidth * 0.5 - centerWidth * 0.5, y)
    drawSingleLine(axisRight, Theme.colors.muted, contentLeft + innerWidth - rightWidth, y)
    y = y + lineHeight + AXIS_GAP
  end

  if graphEnabled then
    local railY=y+TRACK_HEIGHT*.5+12
    ui_drawLine(vec2(trackLeft,railY),vec2(trackLeft+trackWidth,railY),Theme.colors.divider,2)
    local centerX=trackLeft+trackWidth*.5
    ui_drawLine(vec2(centerX,railY-5),vec2(centerX,railY+5),Theme.colors.muted,1)
    -- Fixed vertical marker lanes prevent equal and near-equal targets obscuring identity.
    for index=1,3 do
      local row=ROWS[index]; local x=markerPosition(rowValues[index],trackLeft,trackWidth)
      local markerY=railY+(index-2)*12
      ui_drawLine(vec2(x,railY),vec2(x,markerY),row.color,1)
      local a,b=vec2(x-5,markerY-5),vec2(x+5,markerY+5)
      local enabled=index==1 or (index==2 and storage_Yielding.handleYielding) or (index==3 and storage_Overtaking.handleOvertaking)
      if enabled then ui_drawRectFilled(a,b,row.color,index==1 and 0 or 5) else ui_drawRect(a,b,row.color,index==1 and 0 or 5) end
      if index==1 then
        -- square is the default marker
      elseif index==2 then
         ui_drawLine(vec2(x,markerY-5),vec2(x+5,markerY),row.color,2); ui_drawLine(vec2(x+5,markerY),vec2(x,markerY+5),row.color,2)
        ui_drawLine(vec2(x,markerY+5),vec2(x-5,markerY),row.color,2); ui_drawLine(vec2(x-5,markerY),vec2(x,markerY-5),row.color,2)
      else
        ui_drawLine(vec2(x-4,markerY-4),vec2(x+4,markerY+4),row.color,2); ui_drawLine(vec2(x-4,markerY+4),vec2(x+4,markerY-4),row.color,2)
      end
    end
    y=y+40+TEXT_GAP
  end
  for index=1,3 do
    local row=ROWS[index]; local label=Localization.text(row.label)
    local status=rowStatuses[index]
    local title=label..' · '..status
    local markX=contentLeft+5; local markY=y+lineHeight*.5
    if graphEnabled then
    if index==1 then ui_drawRectFilled(vec2(markX-3,markY-3),vec2(markX+3,markY+3),row.color,0)
    elseif index==2 then
      ui_drawLine(vec2(markX,markY-4),vec2(markX+4,markY),row.color,2); ui_drawLine(vec2(markX+4,markY),vec2(markX,markY+4),row.color,2)
      ui_drawLine(vec2(markX,markY+4),vec2(markX-4,markY),row.color,2); ui_drawLine(vec2(markX-4,markY),vec2(markX,markY-4),row.color,2)
    else ui_drawLine(vec2(markX-3,markY-3),vec2(markX+3,markY+3),row.color,2); ui_drawLine(vec2(markX-3,markY+3),vec2(markX+3,markY-3),row.color,2) end
    end
    local titleX=graphEnabled and contentLeft+14 or contentLeft
    local titleWidth=graphEnabled and innerWidth-14 or innerWidth
    actualBottom=drawWrappedText(title,titleX,y,titleWidth,row.color)
    rowTitleHeights[index]=measuredBlockHeight(title,titleWidth)
    y=math_max(y+rowTitleHeights[index],actualBottom)+ROW_GAP
  end

  local contentBottom = math_max(y - ROW_GAP + padding, cursor.y + panelHeight)
  ui_setCursor(vec2(cursor.x, contentBottom))
end

return UILateralOffsetsImageWidget
