local UILateralOffsetsImageWidget = {}

-- local bindings
local ui = ui
local ui_drawRectFilled = ui.drawRectFilled
local ui_drawLine = ui.drawLine
local ui_getCursor = ui.getCursor
local ui_availableSpaceX = ui.availableSpaceX
local ui_drawRect = ui.drawRect
local ui_dwriteDrawText = ui.dwriteDrawText
local ui_measureDWriteText = ui.measureDWriteText
local Localization = require('Localization')
local ui_invisibleButton = ui.invisibleButton
local math = math
local math_abs = math.abs
local vec2 = vec2

-- ========== CONFIGURABLE CONSTANTS ==========
-- Layout
local PREVIEW_WIDTH              = 360
local PREVIEW_HEIGHT             = 128
local PREVIEW_MARGIN             = 12
local CARD_ROUNDING              = 6
local TRACK_ROUNDING             = 4
local TRACK_HALF_HEIGHT          = 14
local TICK_HEIGHT                = 10
local TICK_HEIGHT_CENTER         = 20

-- Marker (car) shape
local CAR_WIDTH                  = 26
local CAR_HEIGHT                 = 18
local CAR_ROUNDING               = 4
local CAR_NOSE_SIZE              = 6

-- If STACK_MARKERS = true, each marker is drawn on a separate "row" around track midline.
-- Row index is an integer offset from midline: -1 = above, 0 = center, +1 = below (you can use any integers).
local STACK_MARKERS              = true
local ROW_SPACING                = 18            -- pixels between rows
local DEFAULT_ROW_INDEX          = 0             -- e.g., 0   (center)
local YIELDING_ROW_INDEX         = 1             -- e.g., +1  (below)
local OVERTAKE_ROW_INDEX         = -1            -- e.g., -1  (above)

-- If STACK_MARKERS = false, all markers share the same baseline (track midline).
-- You can still nudge captions using CAPTION_OFFSET_Y below.
local CAPTION_OFFSET_Y           = 6             -- pixels below marker to place caption text

-- Colors
local COLOR_CARD_BG              = rgbm(0.08, 0.08, 0.08, 0.90)
local COLOR_CARD_BORDER          = rgbm(0.25, 0.25, 0.25, 1.00)
local COLOR_TRACK_FILL           = rgbm(0.14, 0.14, 0.14, 1.00)
local COLOR_TRACK_BORDER         = rgbm(0.32, 0.32, 0.32, 1.00)
local COLOR_TICK                 = rgbm(0.55, 0.55, 0.55, 1.00)
local COLOR_TEXT                 = rgbm(0.85, 0.85, 0.85, 1.00)
local COLOR_TEXT_MINOR           = rgbm(0.80, 0.80, 0.80, 1.00)
local COLOR_CAR_OUTLINE          = rgbm(0.00, 0.00, 0.00, 0.65)
local COLOR_CURB_RED             = rgbm(0.85, 0.20, 0.20, 0.90)
local COLOR_CURB_WHITE           = rgbm(0.92, 0.92, 0.95, 0.90)

-- Marker colors
local COLOR_DEFAULT_MARKER       = rgbm(0.40, 1.00, 0.40, 1.00)
local COLOR_YIELDING_MARKER      = rgbm(1.00, 0.70, 0.20, 1.00)
local COLOR_OVERTAKE_MARKER      = rgbm(0.20, 0.65, 1.00, 1.00)

-- Lines/weights
local CENTERLINE_THICKNESS       = 2
local TICK_THICKNESS             = 1
local MARKER_NOSE_THICKNESS      = 2

-- Fonts
local CAPTION_FONT_SIZE          = 11
local LABEL_FONT_SIZE            = 11

-- Labels/toggles
local SHOW_EDGE_LABELS_L0R       = true        -- draw "L", "0", "R"
local SHOW_CAPTIONS              = true        -- draw "Default", "Yielding", "Overtake" under markers
local LABEL_LEFT_TEXT            = "L"
local LABEL_CENTER_TEXT          = "0"
local LABEL_RIGHT_TEXT           = "R"
local CAPTION_DEFAULT_TEXT       = "Default"
local CAPTION_YIELDING_TEXT      = "Yield"
local CAPTION_OVERTAKE_TEXT      = "Overtake"

local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Overtaking = StorageManager.getStorage_Overtaking()

local function clampNorm(x)
  if x < -1 then return -1 end
  if x >  1 then return  1 end
  return x
end

-- Map normalized lateral offset [-1..1] to an X pixel within the inner track bar.
local function mapOffsetToX(offsetNormalized, trackLeftX, trackWidth)
  local t = (clampNorm(offsetNormalized) * 0.5) + 0.5   -- -1 → 0, 0 → 0.5, +1 → 1
  return trackLeftX + t * trackWidth
end


-- Draw a simple rounded rectangle “car” with a small “nose” triangle.
local function drawCarMarker(xCenter, midY, color)
  local halfW = CAR_WIDTH * 0.5
  local halfH = CAR_HEIGHT * 0.5
  local p1 = vec2(xCenter - halfW, midY - halfH)
  local p2 = vec2(xCenter + halfW, midY + halfH)

  ui_drawRectFilled(p1, p2, color, CAR_ROUNDING)
  ui_drawRect(p1, p2, COLOR_CAR_OUTLINE, CAR_ROUNDING)
  ui_drawRect(vec2(xCenter - 5, midY - 4), vec2(xCenter + 5, midY + 4), COLOR_CAR_OUTLINE, 2)
  ui_drawLine(vec2(xCenter - 11, p2.y), vec2(xCenter + 11, p2.y), color, 3)
  ui_drawLine(vec2(xCenter - 8, p1.y), vec2(xCenter + 8, p1.y), color, 2)

  -- nose pointing “up” to hint forward direction
  local noseY = p1.y - CAR_NOSE_SIZE
  ui_drawLine(vec2(xCenter - CAR_NOSE_SIZE, p1.y), vec2(xCenter, noseY), color, MARKER_NOSE_THICKNESS)
  ui_drawLine(vec2(xCenter + CAR_NOSE_SIZE, p1.y), vec2(xCenter, noseY), color, MARKER_NOSE_THICKNESS)
end

-- Compute baseline Y for a marker based on row index and STACK_MARKERS toggle.
local function rowY(trackMidY, rowIndex)
  if STACK_MARKERS then
    return trackMidY + (rowIndex * ROW_SPACING)
  else
    return trackMidY
  end
end

local function markerX(offset, trackLeftX, trackWidth, minX, maxX)
  return math.max(minX, math.min(maxX, mapOffsetToX(offset, trackLeftX, trackWidth)))
end

local function captionWidth(text)
  return ui_measureDWriteText(text, CAPTION_FONT_SIZE, -1).x
end

local function captionX(width, x, cardLeft, cardRight)
  return math.max(cardLeft + 4, math.min(cardRight - width - 4, x - width * 0.5))
end

---@param storage StorageTable
function UILateralOffsetsImageWidget.draw(storage)
  -- Reserve block area from current cursor
  local cursor = ui_getCursor()
  local availableWidth = math.max(0, ui_availableSpaceX())
  local previewWidth = math.min(PREVIEW_WIDTH, availableWidth)
  local handleYielding = storage_Yielding.handleYielding
  local handleOvertaking = storage_Overtaking.handleOvertaking
  local defaultCaption = SHOW_CAPTIONS and Localization.text(CAPTION_DEFAULT_TEXT) or nil
  local yieldingCaption = SHOW_CAPTIONS and handleYielding and Localization.text(CAPTION_YIELDING_TEXT) or nil
  local overtakeCaption = SHOW_CAPTIONS and handleOvertaking and Localization.text(CAPTION_OVERTAKE_TEXT) or nil
  local defaultCaptionWidth = defaultCaption and captionWidth(defaultCaption) or 0
  local yieldingCaptionWidth = yieldingCaption and captionWidth(yieldingCaption) or 0
  local overtakeCaptionWidth = overtakeCaption and captionWidth(overtakeCaption) or 0
  local widestCaption = 0
  widestCaption = math.max(widestCaption, defaultCaptionWidth, yieldingCaptionWidth, overtakeCaptionWidth)
  local minimumWidth = math.max(CAR_WIDTH + PREVIEW_MARGIN * 2, widestCaption + 8)
  if previewWidth < minimumWidth then return end
  local tl = vec2(cursor.x + math.max(0, (availableWidth - previewWidth) * 0.5), cursor.y)
  local br = vec2(tl.x + previewWidth, cursor.y + PREVIEW_HEIGHT)

  -- Card
  ui_drawRectFilled(tl, br, COLOR_CARD_BG, CARD_ROUNDING)
  ui_drawRect(tl, br, COLOR_CARD_BORDER, CARD_ROUNDING)

  -- Inner “track” rect
  local trackTL   = vec2(tl.x + PREVIEW_MARGIN, tl.y + PREVIEW_MARGIN)
  local trackBR   = vec2(br.x - PREVIEW_MARGIN, br.y - PREVIEW_MARGIN)
  local trackMidY = (trackTL.y + trackBR.y) * 0.5
  local trackW    = trackBR.x - trackTL.x

  -- Track fill and edges
  ui_drawRectFilled(vec2(trackTL.x, trackMidY - TRACK_HALF_HEIGHT),
                    vec2(trackBR.x, trackMidY + TRACK_HALF_HEIGHT),
                    COLOR_TRACK_FILL, TRACK_ROUNDING)
  ui_drawRect(vec2(trackTL.x, trackMidY - TRACK_HALF_HEIGHT),
              vec2(trackBR.x, trackMidY + TRACK_HALF_HEIGHT),
              COLOR_TRACK_BORDER, TRACK_ROUNDING)

  -- Curbs (zebras) on Left and Right track borders
  ui_drawLine(vec2(trackTL.x, trackMidY - TRACK_HALF_HEIGHT), vec2(trackTL.x, trackMidY), COLOR_CURB_RED, 4)
  ui_drawLine(vec2(trackTL.x, trackMidY), vec2(trackTL.x, trackMidY + TRACK_HALF_HEIGHT), COLOR_CURB_WHITE, 4)
  ui_drawLine(vec2(trackBR.x, trackMidY - TRACK_HALF_HEIGHT), vec2(trackBR.x, trackMidY), COLOR_CURB_WHITE, 4)
  ui_drawLine(vec2(trackBR.x, trackMidY), vec2(trackBR.x, trackMidY + TRACK_HALF_HEIGHT), COLOR_CURB_RED, 4)

  -- Ticks at -1, -0.5, 0, 0.5, 1
  local ticks = { -1.0, -0.5, 0.0, 0.5, 1.0 }
  for i = 1, #ticks do
    local x = mapOffsetToX(ticks[i], trackTL.x, trackW)
    local h = (math_abs(ticks[i]) < 1e-4) and TICK_HEIGHT_CENTER or TICK_HEIGHT
    local thick = (math_abs(ticks[i]) < 1e-4) and CENTERLINE_THICKNESS or TICK_THICKNESS
    ui_drawLine(vec2(x, trackMidY - h), vec2(x, trackMidY + h), COLOR_TICK, thick)
  end

  -- Edge labels "L | 0 | R"
  if SHOW_EDGE_LABELS_L0R then
    local edgeLabelY = trackMidY - LABEL_FONT_SIZE * 0.5
    ui_dwriteDrawText(LABEL_LEFT_TEXT, LABEL_FONT_SIZE, vec2(trackTL.x - 9, edgeLabelY), COLOR_TEXT_MINOR)
    
    local cx = mapOffsetToX(0, trackTL.x, trackW)
    ui_dwriteDrawText(LABEL_CENTER_TEXT, LABEL_FONT_SIZE, vec2(cx - 3, edgeLabelY), COLOR_TEXT_MINOR)

    ui_dwriteDrawText(LABEL_RIGHT_TEXT, LABEL_FONT_SIZE, vec2(trackBR.x + 2, edgeLabelY), COLOR_TEXT_MINOR)
  end

  -- Read offsets from storage
  local offDefault   = storage.defaultLateralOffset
  local offYielding  = storage.yieldingLateralOffset
  local offOvertake  = storage.overtakingLateralOffset

  -- Marker positions (X)
  local markerMinX, markerMaxX = trackTL.x + CAR_WIDTH * 0.5, trackBR.x - CAR_WIDTH * 0.5
  local xDefault  = markerX(offDefault, trackTL.x, trackW, markerMinX, markerMaxX)
  local xYielding = markerX(offYielding, trackTL.x, trackW, markerMinX, markerMaxX)
  local xOvertake = markerX(offOvertake, trackTL.x, trackW, markerMinX, markerMaxX)

  -- Marker positions (Y) — controlled by the new row index constants
  local yDefault  = rowY(trackMidY, DEFAULT_ROW_INDEX)
  local yYielding = rowY(trackMidY, YIELDING_ROW_INDEX)
  local yOvertake = rowY(trackMidY, OVERTAKE_ROW_INDEX)

  -- Draw markers
  drawCarMarker(xDefault,  yDefault,  COLOR_DEFAULT_MARKER)
  if handleYielding then
    drawCarMarker(xYielding, yYielding, COLOR_YIELDING_MARKER)
  end

  if handleOvertaking then
    drawCarMarker(xOvertake, yOvertake, COLOR_OVERTAKE_MARKER)
  end

  -- Captions under each marker
  if SHOW_CAPTIONS then
      ui_dwriteDrawText(defaultCaption, CAPTION_FONT_SIZE, vec2(captionX(defaultCaptionWidth, xDefault, tl.x, br.x), yDefault + (CAR_HEIGHT * 0.5) + CAPTION_OFFSET_Y), COLOR_TEXT)

    if handleYielding then
        ui_dwriteDrawText(yieldingCaption, CAPTION_FONT_SIZE, vec2(captionX(yieldingCaptionWidth, xYielding, tl.x, br.x), yYielding + (CAR_HEIGHT * 0.5) + CAPTION_OFFSET_Y), COLOR_TEXT)
    end

    if handleOvertaking then
        ui_dwriteDrawText(overtakeCaption, CAPTION_FONT_SIZE, vec2(captionX(overtakeCaptionWidth, xOvertake, tl.x, br.x), yOvertake + (CAR_HEIGHT * 0.5) + CAPTION_OFFSET_Y), COLOR_TEXT)
    end
  end

  -- Reserve layout space so following UI doesn’t overlap the drawing
  ui_invisibleButton("##lateralPreviewReserve", vec2(previewWidth, PREVIEW_HEIGHT))
end

return UILateralOffsetsImageWidget
