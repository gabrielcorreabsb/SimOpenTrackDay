-- Run from repository root: luajit tools/test_localization.lua
package.path = './?.lua;./?/init.lua;' .. package.path

local known = { uiLanguage = 'en' }
local uiKnown = { uiLanguage = '' }
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
local initialUIStorage = setmetatable({}, {
  __index = function(_, key)
    if uiKnown[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
    return uiKnown[key]
  end,
  __newindex = function(_, key, value)
    if uiKnown[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
    uiKnown[key] = value
  end,
})
_G.StorageManager = {
  getStorage_Global = function() return globalStorage end,
  getStorage_UI = function() return initialUIStorage end,
}

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
  'Overview', 'AI car list', 'SimOpenTrackDay is not running.',
  'Use the enable control in the header.', 'Adjust driving lane offsets in Behavior.',
  'Behavior', 'Yielding', 'Overtaking', 'Advanced', 'Navigation',
  'Show Advanced Controls', 'Hide Advanced Controls',
  'Control ownership debug', 'Car index', 'Runtime flags · enabled: %s · paused: %s · live: %s',
  'Session generation: %s', 'Select a car index to inspect its gates and control state.',
  'Writable AI car: %s · gate reason: %s', 'Physics permission: %s · reason: %s',
  'Car generation: %s', 'Global top speed cap: %s km/h', 'Active simulation time: %.2fs',
  'Top-speed requests', 'Throttle requests', 'No active requests.',
  'Owner: %s · value: %s · priority: %s · TTL: %.2fs',
  'Owner: %s · value: %s · priority: %s · TTL: unavailable',
  'Winner: %s · value: %s', 'Winner: none', 'Last successful setter: %s · value: %s',
  'No successful setter recorded.', 'Top-speed control', 'Throttle control',
  'Pending neutral indication · inferred from applied state without active requests; physical state is unconfirmed.',
  'A recorded applied value is the last successful setter call, not a physics readback.',
  'No applied record does not prove that the car is physically released.',
  'Pending neutral state, if inferred from applied state without an active request, is not confirmed physical state.',
  'Car #%02d', 'Speed: %d km/h', 'Lane offset: %.3f',
  'No cars available.', 'No initialized cars available.', 'No cars match this filter.',
  'yes #%d', '%s v%s | developed by %s | original author: %s', 'Center', 'Left', 'Right',
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
check(uiManagerSource:find("T('Car #%02d', carIndex)", 1, true) ~= nil and
  uiManagerSource:find("Localization.label(numberLabel, 'car.row.' .. carIndex)", 1, true) ~= nil and
  uiManagerSource:find('T(CarStateMachine.CarStateTypeStrings[state] or', 1, true) ~= nil,
  'selectable car number retains its stable ID and state remains independently translated')
check(uiManagerSource:find("T('Speed: %d km/h', math_floor(car.speedKmh))", 1, true) ~= nil and
  uiManagerSource:find("T('Lane offset: %.3f', actualTrackLateralOffset)", 1, true) ~= nil and
  uiManagerSource:find('if ui_textWrapped then', 1, true) ~= nil and
  uiManagerSource:find('ui_textWrapped(speedText)', 1, true) ~= nil and
  uiManagerSource:find('ui_text(offsetText)', 1, true) ~= nil,
  'car list telemetry uses separate translated values with native wrapped/inline text paths')
local mainWindowSource = readSource('MainWindow.lua')
check(mainWindowSource:find("Localization.text(tabSources[i])", 1, true) ~= nil and
  mainWindowSource:find("Localization.label(tabSources[i], 'main.tab.' .. tabIDs[i])", 1, true) ~= nil and
  mainWindowSource:find("Localization.label('Navigation', 'main.tabs')", 1, true) ~= nil,
  'all tab labels and compact navigation use localized text with stable IDs')
check(mainWindowSource:find("Localization.label(storage.enabled and 'Enabled' or 'Disabled', 'settings.app.enabled')", 1, true) ~= nil and
  mainWindowSource:find("Localization.text('Language')", 1, true) ~= nil and
  mainWindowSource:find("pcall(ui.combo, '###settings.language'", 1, true) ~= nil,
  'global enabled and language controls retain their stable IDs in MainWindow')
local settingsTabsSource = readSource('SettingsWindow.lua')
check(settingsTabsSource:find("'Show Advanced Controls'", 1, true) ~= nil and
  settingsTabsSource:find("'Hide Advanced Controls'", 1, true) ~= nil and
  settingsTabsSource:find("'advanced.controls.toggle'", 1, true) ~= nil,
  'advanced-control toggle localizes both states under one stable ID')

for _, localePath in ipairs({ 'lib/i18n/en.lua', 'lib/i18n/pt-BR.lua', 'lib/i18n/es.lua' }) do
  local source = readSource(localePath)
  for _, duplicatedMsgid in ipairs({
    "['Overview']", "['Behavior']", "['Yielding']", "['Overtaking']", "['Advanced']",
    "['Navigation']", "['Show Advanced Controls']", "['Hide Advanced Controls']",
  }) do
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
  { 'ui_checkbox', 'ui_setTooltip', 'Section.section', 'ui_button', 'ui_text', 'ui_textWrapped', 'ui_textColored' },
  'SettingsWindow')
check(literalUICallCount >= 57,
  'SettingsWindow retains its current 57+ literal UI call inventory after tab extraction: ' .. literalUICallCount)

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
check(sourceContains('MainWindow.lua', "Localization.text('AI car list')"), 'AI car list msgid is present at its live call site')
check(sourceContains('ControlDebugPanel.lua', "Localization.label('Car index', 'control-debug.car')") and
  sourceContains('ControlDebugPanel.lua', "text('Control ownership debug')") and
  sourceContains('ControlDebugPanel.lua', 'text(\'Pending neutral indication · inferred from applied state without active requests; physical state is unconfirmed.\')'),
  'optional control debug panel localizes source-English labels and retains its stable car selector ID/disclaimer')
check(sourceContains('tools/payload.manifest', 'ControlDebugPanel.lua'),
  'localized optional debug panel is included in runtime payload manifest')
check(sourceContains('MainWindow.lua', "drawStatusIndicator('SimOpenTrackDay is not running.'") and
  sourceContains('MainWindow.lua', 'UIControls.drawStatus(source, color, Localization, ui, vec2)') and
  sourceContains('lib/uilib/UIControls.lua', 'Localization.text(source)'),
  'not-running msgid reaches localization through the shared status control')
check(sourceContains('UIManager.lua', "T('Use the enable control in the header.')") and
  sourceContains('UIManager.lua', "T('Adjust driving lane offsets in Behavior.')"),
  'UIManager guidance uses current header and Behavior terminology')
check(pt['Use the enable control in the header.'] == 'Use o controle de ativação no cabeçalho.' and
  es['Use the enable control in the header.'] == 'Usa el control de activación de la cabecera.',
  'header guidance retains its PT-BR and Spanish translations')
local behaviorGuidance = 'Adjust driving lane offsets in Behavior.'
check(type(pt[behaviorGuidance]) == 'string' and pt[behaviorGuidance] ~= '' and
  type(es[behaviorGuidance]) == 'string' and es[behaviorGuidance] ~= '',
  'Behavior guidance is translated in PT-BR and Spanish')
check(pt[behaviorGuidance] == 'Ajuste os deslocamentos laterais em Comportamento.' and
  es[behaviorGuidance] == 'Ajusta los desplazamientos laterales en Comportamiento.',
  'Behavior guidance matches the final PT-BR and Spanish catalog text')
check(en['You can enable the app from the Settings.'] == nil and
  pt['You can enable the app from the Settings.'] == nil and
  es['You can enable the app from the Settings.'] == nil and
  en['These lateral offsets for the AI cars dictate the side of the track they should drive on depending on what they are currently doing (modifyable from the Settings).'] == nil and
  pt['These lateral offsets for the AI cars dictate the side of the track they should drive on depending on what they are currently doing (modifyable from the Settings).'] == nil and
  es['These lateral offsets for the AI cars dictate the side of the track they should drive on depending on what they are currently doing (modifyable from the Settings).'] == nil,
  'superseded Settings guidance msgids are removed from all catalogs')
local orphanedBrandMsgids = {
  'Realistic Trackday not running.',
  '[Error] Missing CSP elements needed to run Realistic Trackday app',
  'Realistic Trackday may not run as expected because some required Custom Shaders Patch elements are missing.',
}
for _, orphanedMsgid in ipairs(orphanedBrandMsgids) do
  check(en[orphanedMsgid] == nil and pt[orphanedMsgid] == nil and es[orphanedMsgid] == nil,
    'orphaned legacy-brand msgid removed symmetrically: ' .. orphanedMsgid)
  check(not sourceContains('MainWindow.lua', orphanedMsgid) and
    not sourceContains('UIManager.lua', orphanedMsgid) and
    not sourceContains('SimOpenTrackDay.lua', orphanedMsgid),
    'no active runtime caller remains for orphaned msgid: ' .. orphanedMsgid)
end
check(sourceContains('UIAppNameVersionWidget.lua', "Localization.text('%s v%s | developed by %s | original author: %s'"),
  'version widget uses an unformatted developer/author template msgid')
check(sourceContains('UIManager.lua', "T(CarStateMachine.CarStateTypeStrings[state] or '')"), 'car-list display routes state labels through localization')
check(sourceContains('UILateralOffsetsImageWidget.lua', "Localization.text('Choose where AI cars try to position themselves in each situation.')") and
  sourceContains('UILateralOffsetsImageWidget.lua', "Localization.text('Configured targets, not live car positions.')") and
  sourceContains('UILateralOffsetsImageWidget.lua', "Localization.text('The maneuver depends on traffic and safety conditions.')") and
  sourceContains('UILateralOffsetsImageWidget.lua', 'Localization.text(row.label)'),
    'shared-axis diagram localizes its guidance, target disclaimer, safety note and situation labels')
check(sourceContains('UILateralOffsetsImageWidget.lua', "Localization.text('Active · %.3f'"),
  'diagram status uses localized configured precision')

check(localization.getLocale() == 'en', 'missing language falls back to English')
check(localization.text('Current Mode: %s', 'Race') == 'Current Mode: Race', 'English formatting')
check(localization.setLocale('pt-BR') and uiKnown.uiLanguage == 'pt-BR', 'locale persists in UI storage')
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
check(localization.setLocale('es') and uiKnown.uiLanguage == 'es' and localization.text('Left') == 'Izquierda', 'locale can be changed and persisted')
check(localization.text('yes #%d', 12) == 'sí #12', 'Spanish formatted car-status placeholder')
check(localization.text('%s v%s | developed by %s | original author: %s', 'SimOpenTrackDay', '1.2', 'SnakeD', 'Author') ==
  'SimOpenTrackDay v1.2 | desarrollado por SnakeD | autor original: Author', 'Spanish formatted developer/author placeholders')
check(localization.text('Center') == 'Centro', 'center side localization is present')
localization.setLocale('pt-BR')
check(localization.text('yes #%d', 12) == 'sim #12', 'Portuguese formatted car-status placeholder')
check(localization.text('%s v%s | developed by %s | original author: %s', 'SimOpenTrackDay', '1.2', 'SnakeD', 'Author') ==
  'SimOpenTrackDay v1.2 | desenvolvido por SnakeD | autor original: Author', 'Portuguese formatted developer/author placeholders')
localization.label(stableLabel)
localization.setLocale('es')
check(labelID(localization.label(stableLabel)) == labelID('Modify Settings###main.settings'), 'embedded label ID remains stable across locales')

uiKnown.uiLanguage = 'pt-BR'
package.loaded.Localization = nil
local reloaded = require('Localization')
check(reloaded.getLocale() == 'pt-BR', 'valid persisted UI locale is loaded on module initialization')

uiKnown.uiLanguage = 'invalid'
package.loaded.Localization = nil
local fallback = require('Localization')
check(fallback.getLocale() == 'en' and uiKnown.uiLanguage == 'invalid', 'invalid persisted locale falls back without rewriting stored value')

-- Exercise the actual StorageManager schema against a strict, persistent
-- ac.storage mock indexed by the SDK namespace and key arguments.
local persisted = {}
local seenSchemas = {}
local storageCreations = {}
local function strictPersistentStorage(defaults, namespace)
  assert(type(namespace) == 'string', 'storage namespace must be explicit')
  seenSchemas[namespace] = defaults
  storageCreations[namespace] = (storageCreations[namespace] or 0) + 1
  local data = persisted[namespace]
  if not data then
    data = {}
    for key, value in pairs(defaults) do data[key] = value end
    persisted[namespace] = data
  else
    for key, value in pairs(defaults) do
      if data[key] == nil then data[key] = value end
    end
  end
  return setmetatable({}, {
    __index = function(_, key)
      if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
      return data[key]
    end,
    __newindex = function(_, key, value)
      if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
      data[key] = value
    end,
  })
end
_G.Constants = { APP_VERSION = 'test', APP_NAME = 'test' }
_G.Logger = { log = function() end }
_G.ac = {
  getSim = function() return { raceSessionType = 'practice' } end,
  getTrackFullID = function() return 'track-one' end,
  storage = strictPersistentStorage,
}
-- Reproduce both lookup shapes that were failing: the global legacy manager,
-- then only package.loaded's legacy manager. The shared UIStorage fallback is
-- created once and subsequently reused by real StorageManager.
local legacyLoadedManager = { getStorage_Global = function() return { uiLanguage = 'en' } end }
_G.StorageManager = legacyLoadedManager
package.loaded.StorageManager = nil
package.loaded.UIStorage = nil
package.loaded.Localization = nil
local legacyGlobalLocalization = require('Localization')
local sharedUIHandle = require('UIStorage').get()
check(legacyGlobalLocalization.getLocale() == 'en', 'legacy global manager without UI getter falls back to shared UI storage')
_G.StorageManager = nil
package.loaded.StorageManager = legacyLoadedManager
package.loaded.Localization = nil
local loadedLegacyLocalization = require('Localization')
check(loadedLegacyLocalization.getLocale() == 'en', 'package.loaded legacy manager without UI getter uses shared UI storage')
check(require('UIStorage').get() == sharedUIHandle and storageCreations.ui == 1,
  'UIStorage singleton creates one ac.storage handle across legacy-manager fallback calls')
_G.StorageManager = nil
package.loaded.StorageManager = nil
package.loaded.Localization = nil
local realStorageManager = require('StorageManager')
_G.StorageManager = realStorageManager
check(type(realStorageManager.getStorage_UI) == 'function', 'real StorageManager exposes the UI storage getter')
check(realStorageManager.getStorage_UI().uiLanguage == 'en', 'shared UI handle retains the one-time legacy locale migration')
check(realStorageManager.getStorage_UI() == sharedUIHandle and storageCreations.ui == 1,
  'real StorageManager getter reuses the fallback singleton handle')
check(seenSchemas.ui and seenSchemas.ui.uiLanguage == '', 'real UI store uses the app-independent ui namespace')
check(seenSchemas.global and seenSchemas.global.uiLanguage == 'en', 'legacy global uiLanguage schema remains for compatibility')
check(persisted.ui ~= nil, 'persistent mock is keyed by the UI storage namespace')
local undeclaredUIWrite = pcall(function() realStorageManager.getStorage_UI().otherSetting = true end)
check(not undeclaredUIWrite, 'strict UI schema rejects undeclared keys')
local realLocalization = require('Localization')
check(realLocalization.getLocale() == 'en', 'empty UI locale with absent/invalid legacy key defaults to English')
check(realLocalization.setLocale('pt-BR'), 'real schema accepts Portuguese selection')
check(realStorageManager.getStorage_UI().uiLanguage == 'pt-BR', 'Portuguese selection persists in real UI storage')
check(require('Localization') == realLocalization, 'main/settings share the same Localization module singleton')

-- Run the requested strict legacy-schema case through the real StorageManager
-- UI getter while denying uiLanguage on its legacy global getter.
persisted.ui.uiLanguage = ''
realStorageManager.getStorage_Global = function()
  return setmetatable({}, {
    __index = function(_, key) error('Unknown key: ' .. tostring(key), 2) end,
    __newindex = function(_, key) error('Unknown key: ' .. tostring(key), 2) end,
  })
end
package.loaded.Localization = nil
local missingLegacyStorageLocale = require('Localization')
check(missingLegacyStorageLocale.getLocale() == 'en',
  'strict legacy schema without uiLanguage defaults to English using declared real UI schema')
check(missingLegacyStorageLocale.setLocale('pt-BR') and persisted.ui.uiLanguage == 'pt-BR',
  'strict legacy schema still persists locale through real UI storage')

local function reloadApplication(trackID, sessionType)
  _G.ac.getTrackFullID = function() return trackID end
  _G.ac.getSim = function() return { raceSessionType = sessionType } end
  package.loaded.Localization = nil
  package.loaded.StorageManager = nil
  package.loaded.UIStorage = nil
  _G.StorageManager = nil
  local manager = require('StorageManager')
  _G.StorageManager = manager
  return require('Localization'), manager
end
local reloadedPT, otherTrackManager = reloadApplication('track-two', 'race')
check(reloadedPT.getLocale() == 'pt-BR', 'locale persists across track and session namespaces')
check(otherTrackManager.getStorage_UI().uiLanguage == 'pt-BR', 'UI language remains shared across track/mode storage')
check(otherTrackManager.getStorage_Behavior().mode ~= nil, 'strict behavior schema remains available without a profile field')
local unknownProfileRead = pcall(function() return otherTrackManager.getStorage_Behavior().profile end)
local unknownProfileWrite = pcall(function() otherTrackManager.getStorage_Behavior().profile = 'x' end)
check(not unknownProfileRead and not unknownProfileWrite, 'behavior.profile remains undeclared and rejected')
check(reloadedPT.setLocale('es'), 'Spanish selection persists')
local reloadedES, _ = reloadApplication('another-track', 'qualifying')
check(reloadedES.getLocale() == 'es', 'Spanish locale survives reloading both modules')

-- Legacy reads are strict: migrate only a declared legacy value, and never
-- rewrite invalid legacy values. Errors beyond a missing legacy key propagate.
local function localizationWithLegacy(legacyValue, legacyMode)
  local ui = { uiLanguage = '' }
  local manager = {
    getStorage_UI = function() return ui end,
    getStorage_Global = function()
      if legacyMode == 'error' then error('legacy getter failed') end
      return setmetatable({}, {
        __index = function(_, key)
          if key ~= 'uiLanguage' or legacyMode == 'missing' then error('Unknown key: ' .. tostring(key), 2) end
          return legacyValue
        end,
      })
    end,
  }
  _G.StorageManager = manager
  package.loaded.Localization = nil
  return pcall(require, 'Localization'), ui
end
for _, legacyLocale in ipairs({ 'en', 'pt-BR', 'es' }) do
  local migrated, migratedStorage = localizationWithLegacy(legacyLocale)
  check(migrated and migratedStorage.uiLanguage == legacyLocale,
    'valid legacy locale migrates exactly into UI storage: ' .. legacyLocale)
end
local invalidLegacy, invalidLegacyStorage = localizationWithLegacy('invalid')
check(invalidLegacy and invalidLegacyStorage.uiLanguage == '', 'invalid legacy locale defaults without migration/rewrite')
local missingLegacy, missingLegacyStorage = localizationWithLegacy(nil, 'missing')
check(missingLegacy and missingLegacyStorage.uiLanguage == '', 'missing strict legacy key defaults to English')
local brokenLegacy = localizationWithLegacy(nil, 'error')
check(not brokenLegacy, 'unrelated legacy getter errors propagate')

local precedenceUI = { uiLanguage = 'es' }
_G.StorageManager = {
  getStorage_UI = function() return precedenceUI end,
  getStorage_Global = function() error('legacy getter must not be called for a valid UI locale') end,
}
package.loaded.Localization = nil
local precedenceOK, precedenceLocalization = pcall(require, 'Localization')
check(precedenceOK and precedenceLocalization.getLocale() == 'es', 'valid UI locale takes precedence over legacy locale')
check(precedenceUI.uiLanguage == 'es', 'existing UI locale is not rewritten during load')

local errorUI = setmetatable({}, {
  __index = function(_, key) if key == 'uiLanguage' then error('UI getter failure') end end,
  __newindex = function(_, key) error('UI setter failure: ' .. key) end,
})
_G.StorageManager = { getStorage_UI = function() return errorUI end, getStorage_Global = function() return globalStorage end }
package.loaded.Localization = nil
local uiReadOK = pcall(require, 'Localization')
check(not uiReadOK, 'UI storage getter failures are not swallowed')

_G.StorageManager = {
  getStorage_UI = function() error('present UI getter failure') end,
  getStorage_Global = function() return globalStorage end,
}
package.loaded.Localization = nil
local throwingUIGetterOK, throwingUIGetterError = pcall(require, 'Localization')
check(not throwingUIGetterOK and tostring(throwingUIGetterError):find('present UI getter failure', 1, true) ~= nil,
  'present UI getter errors propagate without fallback')

_G.StorageManager = {
  getStorage_UI = true,
  getStorage_Global = function() return globalStorage end,
}
package.loaded.Localization = nil
local nonCallableGetterOK = pcall(require, 'Localization')
check(not nonCallableGetterOK, 'present non-callable UI getter fails instead of falling back')

_G.StorageManager = {
  getStorage_UI = function() return nil end,
  getStorage_Global = function() return globalStorage end,
}
package.loaded.Localization = nil
local nilHandleOK = pcall(require, 'Localization')
check(not nilHandleOK, 'present UI getter returning nil fails instead of falling back')

_G.StorageManager = {
  getStorage_UI = function() return {} end,
  getStorage_Global = function() return globalStorage end,
}
package.loaded.Localization = nil
local invalidHandleOK, invalidHandleError = pcall(require, 'Localization')
check(not invalidHandleOK and tostring(invalidHandleError):find('uiLanguage must be a string', 1, true) ~= nil,
  'present UI getter returning a handle without its schema field fails visibly')

local writeUI = setmetatable({}, {
  __index = function(_, key) if key == 'uiLanguage' then return '' end end,
  __newindex = function(_, key) error('unrelated UI write failure: ' .. key) end,
})
local noLegacyStorage = setmetatable({}, {
  __index = function(_, key) error('Unknown key: ' .. tostring(key), 2) end,
})
_G.StorageManager = { getStorage_UI = function() return writeUI end, getStorage_Global = function() return noLegacyStorage end }
package.loaded.Localization = nil
local writeLocalization = require('Localization')
local writeOK, writeError = pcall(function() writeLocalization.setLocale('pt-BR') end)
check(not writeOK and tostring(writeError):find('unrelated UI write failure', 1, true) ~= nil,
  'real UI store write errors are not swallowed')
check(writeLocalization.getLocale() == 'en', 'failed UI write does not change the active locale')

local strictMissingUI = setmetatable({}, {
  __index = function(_, key) error('Unknown key: ' .. tostring(key), 2) end,
  __newindex = function(_, key) error('Unknown key: ' .. tostring(key), 2) end,
})
_G.StorageManager = { getStorage_UI = function() return strictMissingUI end, getStorage_Global = function() return globalStorage end }
package.loaded.Localization = nil
local missingUISchemaOK = pcall(require, 'Localization')
check(not missingUISchemaOK, 'missing UI schema key fails visibly instead of using session-only persistence')

-- Full fallback/restart acceptance using only a backend shared across the
-- simulated process resets. Every new UIStorage module must create a fresh
-- handle while reading and writing the same strict `ui` namespace.
local savedEnvironment = {
  ac = _G.ac, Constants = _G.Constants, Logger = _G.Logger,
  StorageManagerGlobal = _G.StorageManager,
  StorageManagerLoaded = package.loaded.StorageManager,
  LocalizationLoaded = package.loaded.Localization,
  UIStorageLoaded = package.loaded.UIStorage,
}
local restartBackend, restartCreations = {}, 0
local legacyReads, legacyWrites = 0, 0
local strictLegacyWithoutLanguage = setmetatable({}, {
  __index = function(_, key)
    legacyReads = legacyReads + 1
    error('Unknown key: ' .. tostring(key), 2)
  end,
  __newindex = function(_, key)
    legacyWrites = legacyWrites + 1
    error('Unknown key: ' .. tostring(key), 2)
  end,
})
local restartLegacyStorageManager = {
  getStorage_Global = function() return strictLegacyWithoutLanguage end,
}
local function installRestartRuntime()
  _G.Constants = { APP_VERSION = 'test', APP_NAME = 'test' }
  _G.Logger = { log = function() end }
  _G.ac = {
    storage = function(defaults, namespace)
      assert(namespace == 'ui', 'fallback only creates the app-independent UI store')
      restartCreations = restartCreations + 1
      local values = restartBackend[namespace]
      if not values then
        values = {}
        for key, value in pairs(defaults) do values[key] = value end
        restartBackend[namespace] = values
      end
      return setmetatable({}, {
        __index = function(_, key)
          if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
          return values[key]
        end,
        __newindex = function(_, key, value)
          if defaults[key] == nil then error('Unknown key: ' .. tostring(key), 2) end
          values[key] = value
        end,
      })
    end,
  }
end
local function restartWithLegacyManager(locale, restartNumber)
  _G.StorageManager = nil
  package.loaded.StorageManager = nil
  package.loaded.Localization = nil
  package.loaded.UIStorage = nil
  installRestartRuntime()
  package.loaded.StorageManager = restartLegacyStorageManager
  local ok, loadedLocalization = pcall(require, 'Localization')
  check(ok, 'legacy manager without UI getter loads through UIStorage fallback after restart ' .. restartNumber .. ': ' .. tostring(loadedLocalization))
  if ok then
    check(loadedLocalization.getLocale() == locale,
      'UI locale restores across Localization/UIStorage/StorageManager reload ' .. restartNumber)
    return loadedLocalization
  end
end

_G.StorageManager = nil
package.loaded.StorageManager = nil
package.loaded.Localization = nil
package.loaded.UIStorage = nil
installRestartRuntime()
package.loaded.StorageManager = restartLegacyStorageManager
local restart1OK, restart1 = pcall(require, 'Localization')
check(restart1OK and restart1.getLocale() == 'en',
  'strict legacy storage without uiLanguage initializes the fallback path in English')
check(legacyReads == 1 and legacyWrites == 0, 'first-use migration only attempts the strict legacy read')
check(restart1OK and restart1.setLocale('pt-BR') and restartBackend.ui.uiLanguage == 'pt-BR',
  'fallback path persists Portuguese into UIStorage namespace')
check(restartCreations == 1, 'first fallback creates exactly one UI storage handle')
local restart2 = restartWithLegacyManager('pt-BR', 2)
check(restartCreations == 2, 'first simulated restart creates one fresh UIStorage handle')
check(legacyReads == 1 and legacyWrites == 0, 'valid persisted UI locale bypasses strict legacy storage after restart')
check(restart2 and restart2.setLocale('es') and restartBackend.ui.uiLanguage == 'es',
  'legacy-manager fallback persists Spanish into the same backend')
local restart3 = restartWithLegacyManager('es', 3)
check(restartCreations == 3, 'second simulated restart creates one fresh UIStorage handle')
check(legacyReads == 1 and legacyWrites == 0, 'Spanish reload also leaves unavailable legacy storage untouched')

_G.StorageManager = nil
package.loaded.StorageManager = nil
package.loaded.Localization = nil
package.loaded.UIStorage = nil
installRestartRuntime()
_G.ac.storage = function() error('ac.storage creation failed exactly') end
package.loaded.StorageManager = restartLegacyStorageManager
local creationOK, creationError = pcall(require, 'Localization')
check(not creationOK and tostring(creationError):find('ac.storage creation failed exactly', 1, true) ~= nil,
  'UIStorage creation error propagates without session-only fallback')
check(type(package.loaded.Localization) ~= 'table', 'failed UIStorage creation does not publish a fabricated locale module')
package.loaded.Localization = nil

_G.ac = savedEnvironment.ac
_G.Constants = savedEnvironment.Constants
_G.Logger = savedEnvironment.Logger
_G.StorageManager = savedEnvironment.StorageManagerGlobal
package.loaded.StorageManager = savedEnvironment.StorageManagerLoaded
package.loaded.Localization = savedEnvironment.LocalizationLoaded
package.loaded.UIStorage = savedEnvironment.UIStorageLoaded
if failures > 0 then error(string.format('Localization tests failed: %d assertion(s)', failures)) end
print('Localization tests passed.')
