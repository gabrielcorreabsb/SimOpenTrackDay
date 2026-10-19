local Toggle = {}
local ui = ui
local ui_availableSpaceX = ui.availableSpaceX
local ui_measureText = ui.measureText
local Style = require('lib/uilib/Style')
local Theme = require('lib/uilib/Theme')
local Localization = require('Localization')
local wrappedWords = {}

local function wrapLabelWithoutChangingID(label)
  local visible, suffix = label:match('^(.-)(###.*)$')
  if not visible or visible == '' or visible:sub(1, 2) == '##' then return label end

  local maxWidth = math.max(0, ui_availableSpaceX() - 30)
  if not ui_measureText or ui_measureText(visible, -1).x <= maxWidth then return label end

  for i = #wrappedWords, 1, -1 do wrappedWords[i] = nil end
  local line, outputCount = '', 0
  for word in visible:gmatch('%S+') do
    local candidate = line == '' and word or (line .. ' ' .. word)
    if line ~= '' and ui_measureText(candidate, -1).x > maxWidth then
      outputCount = outputCount + 1
      wrappedWords[outputCount] = line
      line = word
    else
      line = candidate
    end
  end
  if line ~= '' then
    outputCount = outputCount + 1
    wrappedWords[outputCount] = line
  end
  return table.concat(wrappedWords, '\n', 1, outputCount) .. suffix
end

local function popToggleStyles()
  local accentOk, accentError = pcall(Style.popAccent)
  local surfaceOk, surfaceError = pcall(Style.popSurface)
  if not accentOk then return false, accentError end
  if not surfaceOk then return false, surfaceError end
  return true
end

Toggle.render = function(label, value)
  if not label:find('###', 1, true) and label:sub(1, 2) ~= '##' then
    label = Localization.label(label)
  end
  label = wrapLabelWithoutChangingID(label)
  Style.pushSurface()
  Style.pushAccent()
  local checkboxOk, changed = pcall(ui.checkbox, label, value)
  local cleanupOk, cleanupError = popToggleStyles()
  if not checkboxOk then error(changed, 0) end
  if not cleanupOk then error(cleanupError, 0) end
  return changed
end

return Toggle
