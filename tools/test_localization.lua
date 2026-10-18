-- Run from repository root: luajit tools/test_localization.lua
package.path = './?.lua;./?/init.lua;' .. package.path

local known = { uiLanguage = 'en' }
local globalStorage = setmetatable({}, {
  __index = function(_, key)
    if known[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
    return known[key]
  end,
  __newindex = function(_, key, value)
    if known[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
    known[key] = value
  end,
})
_G.StorageManager = { getStorage_Global = function() return globalStorage end }

local localization = require('Localization')
local en = require('lib/i18n/en')
local pt = require('lib/i18n/pt-BR')
local es = require('lib/i18n/es')
local failures = 0
local function check(value, message)
  if not value then failures = failures + 1; io.stderr:write('FAIL: ' .. message .. '\n') end
end

local function formatSignature(text)
  local result, index = {}, 1
  while index <= #text do
    if text:sub(index, index) ~= '%' then index = index + 1
    elseif text:sub(index + 1, index + 1) == '%' then
      result[#result + 1] = '%%'
      index = index + 2
    else
      local token = text:sub(index):match('^(%%[-+#0 ]*%d*%.?%d*[aAeEfgGdiouxXcsq])')
      check(token ~= nil, 'valid format token in: ' .. text)
      if token then result[#result + 1] = token; index = index + #token else index = index + 1 end
    end
  end
  return table.concat(result, '|')
end

check(#localization.locales == 3 and localization.locales[1] == 'en' and
  localization.locales[2] == 'pt-BR' and localization.locales[3] == 'es', 'supported locale list')
check(table.concat(localization.localeNames, '|') == 'English|Português (Brasil)|Español', 'locale display names')
local catalogSize = 0
for key, englishText in pairs(en) do
  catalogSize = catalogSize + 1
  check(key == englishText, 'English catalog is canonical source English: ' .. key)
  check(pt[key] ~= nil and es[key] ~= nil, 'all catalogs contain msgid: ' .. key)
  if pt[key] then check(formatSignature(englishText) == formatSignature(pt[key]), 'pt-BR placeholders match: ' .. key) end
  if es[key] then check(formatSignature(englishText) == formatSignature(es[key]), 'es placeholders match: ' .. key) end
end
check(catalogSize >= 300, 'catalog includes the broad UI msgid inventory')
for key in pairs(pt) do check(en[key] ~= nil, 'no extra pt-BR msgid: ' .. key) end
for key in pairs(es) do check(en[key] ~= nil, 'no extra es msgid: ' .. key) end

-- Required msgids from final live UI call sites, plus dynamic values fed into
-- those templates. This guards inventory coverage independently of catalog size.
local requiredMsgids = {
  'Driving lanes', 'AI car list', 'SimOpenTrackDay is not running.',
  'yes #%d', '%s v%s by %s', 'Center', 'Left', 'Right',
  'Undefined', 'Practice', 'Qualify', 'Race', 'Hotlap', 'TimeAttack', 'Drift', 'Drag',
  'DrivingNormally', 'EasingInYield', 'StayingOnYieldingLane', 'EasingOutYield',
  'WaitingAfterAccident', 'CollidedWithTrack', 'CollidedWithCar', 'AnotherCarCollidedIntoMe',
  'EasingInOvertake', 'StayingOnOvertakingLane', 'EasingOutOvertake',
  'NavigatingAroundAccident', 'DrivingInYellowFlagZone', 'AfterCustomAIFloodTeleport', 'DefendingPosition',
}
for _, msgid in ipairs(requiredMsgids) do
  check(en[msgid] == msgid and pt[msgid] ~= nil and es[msgid] ~= nil, 'required live UI msgid catalogued: ' .. msgid)
end

local function sourceContains(path, text)
  local file = assert(io.open(path, 'rb'))
  local source = file:read('*a')
  file:close()
  return source:find(text, 1, true) ~= nil
end
local function readSource(path)
  local file = assert(io.open(path, 'rb'))
  local source = file:read('*a')
  file:close()
  return source
end
local uiManagerSource = readSource('UIManager.lua')
local columnDisplayMap = uiManagerSource:match('local carColumnDisplayNames%s*=%s*(%b{})')
check(columnDisplayMap ~= nil, 'UIManager display-name map can be isolated as a literal table')
if columnDisplayMap then
  local loadMap = loadstring('return ' .. columnDisplayMap)
  check(loadMap ~= nil, 'UIManager display-name map is safe Lua literal data')
  if loadMap then
    local displayNames = loadMap()
    for sourceName, displayName in pairs(displayNames) do
      check(en[displayName] == displayName and pt[displayName] ~= nil and es[displayName] ~= nil,
        'car column display msgid covered in all locales: ' .. sourceName .. ' -> ' .. displayName)
    end
  end
end

for _, localePath in ipairs({ 'lib/i18n/en.lua', 'lib/i18n/pt-BR.lua', 'lib/i18n/es.lua' }) do
  local source = readSource(localePath)
  for _, duplicatedMsgid in ipairs({ "['Yielding']", "['Overtaking']" }) do
    local _, occurrences = source:gsub(duplicatedMsgid:gsub('([%[%]])', '%%%1'), '')
    check(occurrences == 1, localePath .. ' has exactly one entry for ' .. duplicatedMsgid)
  end
end
check(pt['Choose the overall AI driving style:\n  Casual      - Trackday only, instant reactions, no errors, no defense.\n  Realistic   - Trackday/Hybrid, human timing, no errors, gradual blending.\n  Competitive - Race mode, defend position, human errors (brake/traction), aggressive.']:find('Descontraído', 1, true) ~= nil,
  'Portuguese profile name matches its translated Casual tooltip name')
check(es['Choose the overall AI driving style:\n  Casual      - Trackday only, instant reactions, no errors, no defense.\n  Realistic   - Trackday/Hybrid, human timing, no errors, gradual blending.\n  Competitive - Race mode, defend position, human errors (brake/traction), aggressive.']:find('Informal', 1, true) ~= nil,
  'Spanish profile name matches its translated Casual tooltip name')

local function splitArguments(callText)
  local args, start, depth = {}, 1, 0
  local quote, escaped = nil, false
  local index = 1
  while index <= #callText do
    local char = callText:sub(index, index)
    if quote then
      if escaped then escaped = false
      elseif char == '\\' then escaped = true
      elseif char == quote then quote = nil end
    elseif char == '"' or char == "'" then quote = char
    elseif char == '[' then
      local equals = callText:sub(index):match('^%[(=*)%[')
      if equals then
        local closeAt = callText:find(']' .. equals .. ']', index + #equals + 2, true)
        if closeAt then index = closeAt + #equals + 1 end
      end
    elseif char == '(' then depth = depth + 1
    elseif char == ')' then
      if depth == 0 then args[#args + 1] = callText:sub(start, index - 1); break end
      depth = depth - 1
    elseif char == ',' and depth == 0 then
      args[#args + 1] = callText:sub(start, index - 1)
      start = index + 1
    end
    index = index + 1
  end
  return args
end

local function firstLiteral(expression)
  local quote, start, escaped
  for index = 1, #expression do
    local char = expression:sub(index, index)
    if not quote then
      if char == '"' or char == "'" then quote, start, escaped = char, index, false
      elseif char == '[' then
        local equals = expression:sub(index):match('^%[(=*)%[')
        if equals then
          local closing = ']' .. equals .. ']'
          local closeAt = expression:find(closing, index + #equals + 2, true)
          if closeAt then
            local literal = expression:sub(index, closeAt + #equals + 1)
            local chunk = loadstring('return ' .. literal)
            if chunk then return chunk() end
            return nil
          end
        end
      end
    elseif escaped then escaped = false
    elseif char == '\\' then escaped = true
    elseif char == quote then
      local literal = expression:sub(start, index)
      local chunk = loadstring('return ' .. literal)
      if chunk then return chunk() end
      return nil
    end
  end
end

local function stripLuaComments(source)
  local result, index = {}, 1
  local function longBracketAt(position)
    local equals = source:sub(position):match('^%[(=*)%[')
    if not equals then return nil end
    local closing = ']' .. equals .. ']'
    local closeAt = source:find(closing, position + #equals + 2, true)
    return closeAt and closeAt + #equals + 1 or #source
  end
  while index <= #source do
    local two = source:sub(index, index + 1)
    local char = source:sub(index, index)
    if char == '"' or char == "'" then
      local start, escaped = index, false
      index = index + 1
      while index <= #source do
        local current = source:sub(index, index)
        if escaped then escaped = false
        elseif current == '\\' then escaped = true
        elseif current == char then index = index + 1; break end
        index = index + 1
      end
      result[#result + 1] = source:sub(start, index - 1)
    elseif char == '[' and longBracketAt(index) then
      local finish = longBracketAt(index)
      result[#result + 1] = source:sub(index, finish)
      index = finish + 1
    elseif two == '--' then
      local commentStart = index + 2
      local finish = longBracketAt(commentStart)
      if finish then
        index = finish + 1
      else
        local newline = source:find('\n', commentStart, true)
        index = newline or (#source + 1)
      end
      result[#result + 1] = ' '
    else
      result[#result + 1] = char
      index = index + 1
    end
  end
  return table.concat(result)
end

local function checkLiteralUIArgs(source, functionNames, label)
  source = stripLuaComments(source)
  local found = 0
  for _, name in ipairs(functionNames) do
    local position = 1
    while true do
      local callAt = source:find(name, position, true)
      if not callAt then break end
      local previous = callAt > 1 and source:sub(callAt - 1, callAt - 1) or ''
      local afterName = callAt + #name
      local nextChar = source:sub(afterName, afterName)
      if not previous:match('[%w_%.]') and not nextChar:match('[%w_]') then
        local open = afterName
        while source:sub(open, open):match('%s') do open = open + 1 end
        if source:sub(open, open) == '(' then
          local args = splitArguments(source:sub(open + 1))
          local msgid = firstLiteral(args[1] or '')
          if (name == 'ui_checkbox' or name == 'ui_button' or name == 'Section.section') and
              (args[1] or ''):match('^%s*translatedLabel%(') then
            msgid = nil -- second literal in translatedLabel is an ImGui ID, not a msgid
          end
          if msgid then
            found = found + 1
            check(en[msgid] == msgid and pt[msgid] ~= nil and es[msgid] ~= nil,
              label .. ' literal msgid translated in all locales: ' .. msgid)
          end
          position = open + 1
        else
          position = afterName
        end
      else
        position = afterName
      end
    end
  end
  return found
end

local settingsSource = readSource('SettingsWindow.lua')
local literalUICallCount = checkLiteralUIArgs(settingsSource,
  { 'ui_checkbox', 'ui_setTooltip', 'Section.section', 'ui_button', 'ui_text', 'ui_textColored' },
  'SettingsWindow')
check(literalUICallCount >= 60, 'SettingsWindow literal UI inventory extracted without commented code')

local sliderCallCount = 0
for line in settingsSource:gmatch('[^\r\n]+') do
  line = line:gsub('%-%-.*$', '')
  local callStart = line:find('UIOperations_renderSlider(', 1, true)
  if callStart then
    local args = splitArguments(line:sub(callStart + #('UIOperations_renderSlider(')))
    local label, tooltip = firstLiteral(args[1] or ''), firstLiteral(args[2] or '')
    if label and tooltip then
      sliderCallCount = sliderCallCount + 1
      if label:sub(1, 2) == '##' then
        check(not en[label] and not pt[label] and not es[label], 'hidden-only slider ID is preserved as nonlocalizable: ' .. label)
      else
        check(en[label] == label and pt[label] ~= nil and es[label] ~= nil, 'slider label translated: ' .. label)
      end
      check(en[tooltip] == tooltip and pt[tooltip] ~= nil and es[tooltip] ~= nil, 'slider tooltip translated: ' .. tooltip)
    else
      check(false, 'slider label and tooltip can be extracted from caller: ' .. line)
    end
  end
end
check(sliderCallCount >= 50, 'inventory extracted from live SettingsWindow slider calls')
check(sourceContains('SimOpenTrackDay.lua', "Localization.text('Driving lanes')"), 'Driving lanes msgid is present at its live call site')
check(sourceContains('SimOpenTrackDay.lua', "Localization.text('AI car list')"), 'AI car list msgid is present at its live call site')
check(sourceContains('UIManager.lua', "T('SimOpenTrackDay is not running.')"), 'not-running msgid is present at its live call site')
check(sourceContains('UIManager.lua', 'T("yes #%d", currentlyYieldingCarIndex)'), 'yielding status uses an unformatted template msgid')
check(sourceContains('UIManager.lua', 'T("yes #%d", currentlyOvertakingCarIndex)'), 'overtaking status uses an unformatted template msgid')
check(sourceContains('UIAppNameVersionWidget.lua', "Localization.text('%s v%s by %s'"), 'version widget uses an unformatted template msgid')
check(sourceContains('UIManager.lua', 'T(CarStateMachine.CarStateTypeStrings[state])'), 'car-state table display routes state labels through localization')
check(sourceContains('UIManager.lua', 'T(yieldingSideString)'), 'yielding side display routes side through localization')
check(sourceContains('UIManager.lua', 'T(defaultDrivingSideString)'), 'default side display routes side through localization')

check(localization.getLocale() == 'en', 'missing language falls back to English')
check(localization.text('Current Mode: %s', 'Race') == 'Current Mode: Race', 'English formatting')
check(localization.setLocale('pt-BR') and known.uiLanguage == 'pt-BR', 'locale persists globally')
check(localization.text('Current Mode: %s', 'Corrida') == 'Modo atual: Corrida', 'translated formatting')
check(localization.text('untranslated msgid') == 'untranslated msgid', 'missing translation falls back to source')
local savedClose = pt.Close
pt.Close = nil
check(localization.text('Close') == 'Close', 'a real missing catalog entry falls back to its English msgid')
pt.Close = savedClose
check(localization.label('Modify Settings', 'settings.open') == 'Alterar configurações###settings.open', 'label has stable ID')
local stableLabel = 'Modify Settings###main.settings'
local function labelID(value) return value:match('###(.+)$') end
check(labelID(localization.label(stableLabel)) == 'main.settings', 'existing ### ID is preserved without duplication')
check(localization.label(stableLabel, 'override.id') == 'Alterar configurações###override.id', 'explicit ID overrides an embedded ID')
check(localization.label('Visible##hidden') == 'Visible###hidden', 'visible ## label is normalized idempotently')
check(formatSignature('%03d %.2f %% %s %08.3A') == '%03d|%.2f|%%|%s|%08.3A', 'format parser captures flags, precision, escaped percent, and conversion types')
check(formatSignature('%03d %.2f %s') ~= formatSignature('%s %.2f %03d'), 'format parser detects reordered placeholders')
check(localization.label('##debug-only') == '##debug-only', 'hidden-only ID label is preserved')
check(not localization.setLocale('fr') and localization.getLocale() == 'pt-BR', 'invalid locale rejected without changing locale')
check(localization.setLocale('es') and known.uiLanguage == 'es' and localization.text('Left') == 'Izquierda', 'locale can be changed and persisted')
check(localization.text('yes #%d', 12) == 'sí #12', 'Spanish formatted car-status placeholder')
check(localization.text('%s v%s by %s', 'SimOpenTrackDay', '1.2', 'Author') == 'SimOpenTrackDay v1.2 por Author', 'Spanish formatted version-widget placeholders')
check(localization.text('Center') == 'Centro', 'center side localization is present')
localization.setLocale('pt-BR')
check(localization.text('yes #%d', 12) == 'sim #12', 'Portuguese formatted car-status placeholder')
check(localization.text('%s v%s by %s', 'SimOpenTrackDay', '1.2', 'Author') == 'SimOpenTrackDay v1.2 por Author', 'Portuguese formatted version-widget placeholders')
localization.label(stableLabel)
localization.setLocale('es')
check(labelID(localization.label(stableLabel)) == labelID('Modify Settings###main.settings'), 'embedded label ID remains stable across locales')

known.uiLanguage = 'pt-BR'
package.loaded.Localization = nil
local reloaded = require('Localization')
check(reloaded.getLocale() == 'pt-BR', 'valid persisted locale is loaded on module initialization')

known.uiLanguage = 'invalid'
package.loaded.Localization = nil
local fallback = require('Localization')
check(fallback.getLocale() == 'en' and known.uiLanguage == 'invalid', 'invalid persisted locale falls back without unsafe storage access')
if failures > 0 then error(string.format('Localization tests failed: %d assertion(s)', failures)) end
print('Localization tests passed.')
