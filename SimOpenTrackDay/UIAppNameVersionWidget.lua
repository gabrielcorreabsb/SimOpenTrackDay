local UIAppNameVersion = {}

--bindings
local ui = ui
local ui_cursorScreenPos = ui.cursorScreenPos
local ui_setCursorScreenPos = ui.setCursorScreenPos
local ui_measureDWriteText = ui.measureDWriteText
local ui_dwriteText = ui.dwriteText
local ui_windowPos = ui.windowPos
local ui_windowSize = ui.windowSize
local Localization = require('Localization')

-- local string = string
-- local string_format = string.format

local function versionText() return Localization.text('%s v%s | developed by %s | original author: %s', Constants.APP_NAME, Constants.APP_VERSION, Constants.APP_DEVELOPER, Constants.APP_AUTHOR) end
local versionTextColor = ColorManager.RGBM_Colors.Gainsboro

-- UIAppNameVersion.draw = function(absoluteScreenPosition, fontSize)

---@type table<number, vec2>
local cachedVersionTextDimensions = {}

local draw = function(absoluteScreenPosition, fontSize)
--[===[
    local windowContentSize = ui.windowContentSize()
    Logger.log(string.format('text size: %s, window content size: %s px, window size: %s px, scrollMaxX: %.2f, scrollMaxY: %.2f, maxCursorX: %.2f', textDimensions, windowContentSize, windowSize, ui.getScrollMaxX(), ui.getScrollMaxY(), ui.getMaxCursorX()))
    -- ui.dwriteTextAligned(
        -- versionText,
        -- versionFontSize,
        -- ui.Alignment.End,
        -- ui.Alignment.Center,
        -- --vec2(windowSize.x-windowPadding,textHeight),
        -- --vec2(windowContentSize.x-0,textHeight),
        -- vec2(windowSize.x-40,textHeight),
        -- -- vec2(-100,textHeight),
        -- -- -10,
        -- versionWordWrapping,
        -- ColorManager.RGBM_Colors.Gray
    -- )
--]===]

    local prev = ui_cursorScreenPos()
    ui_setCursorScreenPos(absoluteScreenPosition)
    ui_dwriteText(versionText(), fontSize, versionTextColor)
    ui_setCursorScreenPos(prev)
end

UIAppNameVersion.drawBottomRight = function(fontSize)
    local windowPosition = ui_windowPos()
    local windowSize = ui_windowSize()
    local cacheKey = fontSize .. ':' .. Localization.getLocale()
    local textDimensions = cachedVersionTextDimensions[cacheKey]
    if textDimensions == nil then
        textDimensions = ui_measureDWriteText(versionText(), fontSize, -1)
        cachedVersionTextDimensions[cacheKey] = textDimensions
    end

    local textWidth = textDimensions.x
    local textHeight = textDimensions.y

    local textPosition = windowPosition
    textPosition.x = textPosition.x + windowSize.x - textWidth - UIManager.VERTICAL_SCROLLBAR_WIDTH
    textPosition.y = textPosition.y + windowSize.y - textHeight - UIManager.VERTICAL_SCROLLBAR_WIDTH

    draw(textPosition, fontSize)
end

return UIAppNameVersion
