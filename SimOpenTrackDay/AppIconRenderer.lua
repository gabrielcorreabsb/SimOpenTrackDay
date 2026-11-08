local AppIconRenderer = {}

local Logo = require('lib/uilib/Logo')
local APP_ICON_SIZE = Constants.APP_ICON_SIZE
local settingsWindowIconPosition = vec2(0,10)

AppIconRenderer.draw = function()
    local settingsWindowSize = ui.windowSize()
    settingsWindowIconPosition.x = settingsWindowSize.x - (APP_ICON_SIZE.x + UIManager.VERTICAL_SCROLLBAR_WIDTH)
    Logo.draw(APP_ICON_SIZE.x, settingsWindowIconPosition)
end

return AppIconRenderer
