local MainWindow = {}

local ui = ui
local Localization = require('Localization')
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Logo = require('lib/uilib/Logo')
local Toggle = require('lib/uilib/Toggle')
local UIState = require('UIState')
local SettingsWindow = SettingsWindow
local UIManager = UIManager
local StorageManager = StorageManager
local RaceTrackManager = RaceTrackManager
local math = math

local localeIndexes = { en = 1, ['pt-BR'] = 2, es = 3 }
local locales = { 'en', 'pt-BR', 'es' }
local tabSources = { 'Overview', 'Behavior', 'Yielding', 'Overtaking', 'Advanced' }
local tabIDs = { 'overview', 'behavior', 'yielding', 'overtaking', 'advanced' }
local tabLabels = { '', '', '', '', '' }
local tabNames = { '', '', '', '', '' }
local visibleTabLabels = { '', '', '', '', '' }
local tabWidthScratch = { 0, 0, 0, 0, 0 }
local storage = StorageManager.getStorage()
local Constants = Constants
local TAB_GAP = Theme.spacing.sm
local ui_textWrapped = ui.textWrapped
local ui_drawRectFilled = ui.drawRectFilled
local ui_drawRectFilledMultiColor = ui.drawRectFilledMultiColor
local drawState = {
  shouldAppRun = nil,
  anyMissingCSPElements = false,
  missingCSPElementsErrorMessage = nil,
  shouldRun = false,
  operationalAvailable = false,
  childOpen = false,
  fontOpen = false,
  styleOpen = false
}

local debug_traceback = debug.traceback
local function returnError(errorValue)
  return debug_traceback(tostring(errorValue), 2)
end

local function currentTabIndex()
  for i = 1, #tabSources do
    if UIState.activeTab == tabSources[i] then return i end
  end
  UIState.activeTab = 'Overview'
  return 1
end

local function drawTabNavigation()
  local selectedIndex = currentTabIndex()
  local totalWidth = 0
  for i = 1, #tabSources do
    tabLabels[i] = Localization.text(tabSources[i])
    visibleTabLabels[i] = i == selectedIndex and (tabLabels[i] .. '  ✓') or tabLabels[i]
    tabNames[i] = Localization.label(tabSources[i], 'main.tab.' .. tabIDs[i])
    if i == selectedIndex then
      local marker = tabNames[i]:find('###', 1, true)
      tabNames[i] = tabNames[i]:sub(1, marker - 1) .. '  ✓' .. tabNames[i]:sub(marker)
    end
    tabWidthScratch[i] = ui.measureDWriteText(visibleTabLabels[i], Theme.type.body, -1).x + Theme.spacing.lg
    totalWidth = totalWidth + tabWidthScratch[i]
    if i > 1 then totalWidth = totalWidth + TAB_GAP end
  end

  if totalWidth > ui.availableSpaceX() then
    ui.pushItemWidth(math.min(ui.availableSpaceX(), 350))
    local newIndex, changed = ui.combo(Localization.label('Navigation', 'main.tabs'), selectedIndex, ui.ComboFlags.None, tabLabels)
    ui.popItemWidth()
    if changed then UIState.activeTab = tabSources[newIndex] or 'Overview' end
    return
  end

  for i = 1, #tabSources do
    if i > 1 then ui.sameLine(0, TAB_GAP) end
    local isSelected = i == selectedIndex
    if isSelected then
      Style.push(ui.StyleColor.Button, Theme.colors.accent)
      Style.push(ui.StyleColor.ButtonHovered, Theme.colors.accent)
      Style.push(ui.StyleColor.ButtonActive, Theme.colors.accent)
      Style.push(ui.StyleColor.Text, Theme.colors.white)
    end
    if ui.button(tabNames[i], vec2(tabWidthScratch[i], 34)) then
      UIState.activeTab = tabSources[i]
      selectedIndex = i
    end
    if isSelected then Style.pop(4) end
  end
end

local function drawHeader()
  local headerTop = ui.getCursor()
  local headerWidth = ui.availableSpaceX()
  if headerWidth > 12 then
    local headerRight = headerTop.x + headerWidth
    local headerBottom = headerTop.y + 50
    ui_drawRectFilled(headerTop, vec2(headerRight, headerBottom), Theme.colors.surface, 8, 0)
    ui_drawRectFilledMultiColor(
      vec2(headerTop.x + 6, headerTop.y + 1), vec2(headerRight - 6, headerBottom - 1),
      Theme.colors.headerGradientTopLeft, Theme.colors.headerGradientTopRight,
      Theme.colors.headerGradientBottomRight, Theme.colors.headerGradientBottomLeft)
    if headerWidth > 16 then
      ui_drawRectFilled(vec2(headerTop.x + 8, headerBottom - 2), vec2(headerRight - 8, headerBottom), Theme.colors.accentSoft, 1, 0)
    end
  end

  Logo.draw(38)
  ui.sameLine()
  ui.dwriteText('SimOpenTrackDay', Theme.type.title)
  ui.newLine(0.5)

  local trackName = RaceTrackManager.getTrackName()
  local sessionName = Localization.text(RaceTrackManager.getSessionTypeName())
  local context = trackName .. ' | ' .. sessionName
  if ui_textWrapped then ui_textWrapped(context) else ui.text(context) end

  if Toggle.render(Localization.label(storage.enabled and 'Enabled' or 'Disabled', 'settings.app.enabled'), storage.enabled) then
    storage.enabled = not storage.enabled
  end

  local languageLabel = Localization.label('Language', 'settings.language')
  ui.pushItemWidth(math.min(ui.availableSpaceX(), 270))
  local languageIndex, languageChanged = ui.combo(languageLabel, localeIndexes[Localization.getLocale()] or 1, ui.ComboFlags.None, Localization.localeNames)
  ui.popItemWidth()
  if languageChanged then Localization.setLocale(locales[languageIndex] or 'en') end

  drawState.shouldRun = drawState.shouldAppRun()
  drawState.operationalAvailable = drawState.shouldRun and not drawState.anyMissingCSPElements
  if drawState.operationalAvailable then
    local carListLabel = Localization.label('AI car list', 'main.cars')
    local carListWidth = math.min(ui.availableSpaceX(), ui.measureDWriteText(Localization.text('AI car list'), Theme.type.body, -1).x + Theme.spacing.lg)
    if ui.button(carListLabel, vec2(carListWidth, 32)) then
      UIState.activeTab = 'Overview'
    end
  end

  if drawState.anyMissingCSPElements and drawState.missingCSPElementsErrorMessage and drawState.missingCSPElementsErrorMessage ~= '' then
    ui.separator()
    if ui_textWrapped then ui_textWrapped(drawState.missingCSPElementsErrorMessage) else ui.text(drawState.missingCSPElementsErrorMessage) end
  end

  if not drawState.shouldRun then
    UIManager.drawAppNotRunningMessageInMainWindow()
  end
end

local function drawWindowBody()
  Style.windowBegin('mainWindow')
  drawState.styleOpen = true
  ui.pushDWriteFont('Segoe UI')
  drawState.fontOpen = true

  drawHeader()
  ui.separator()
  drawTabNavigation()
  ui.separator()

  local contentVisible = ui.beginChild('mainPageContent', vec2(0, 0), false)
  drawState.childOpen = true
  if contentVisible then
    SettingsWindow.drawContent(UIState.activeTab, drawState.operationalAvailable)
    if UIState.activeTab == 'Overview' and drawState.operationalAvailable then
      ui.newLine(1)
      ui.dwriteText(Localization.text('AI car list'), Theme.type.section)
      ui.separator()
      UIManager.drawUICarList()
    end
    ui.newLine(1)
    ui.separator()
    local versionAndCredit = Localization.text('%s v%s by %s', Constants.APP_NAME, Constants.APP_VERSION, Constants.APP_AUTHOR)
    if ui_textWrapped then
      ui_textWrapped(versionAndCredit)
    else
      ui.textColored(versionAndCredit, Theme.colors.muted)
    end
  end
end

local function closeWindowScopes()
  local cleanupOk, cleanupError = true, nil
  if drawState.childOpen then
    drawState.childOpen = false
    local ok, err = pcall(ui.endChild)
    if not ok then cleanupOk, cleanupError = false, err end
  end
  if drawState.fontOpen then
    drawState.fontOpen = false
    local ok, err = pcall(ui.popDWriteFont)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.styleOpen then
    drawState.styleOpen = false
    local ok, err = pcall(Style.windowEnd)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  return cleanupOk, cleanupError
end

function MainWindow.draw(shouldAppRun, anyMissingCSPElements, missingCSPElementsErrorMessage)
  drawState.shouldAppRun = shouldAppRun
  drawState.anyMissingCSPElements = anyMissingCSPElements
  drawState.missingCSPElementsErrorMessage = missingCSPElementsErrorMessage

  local drawOk, drawError = xpcall(drawWindowBody, returnError)
  local cleanupOk, cleanupError = closeWindowScopes()

  drawState.shouldAppRun = nil
  drawState.missingCSPElementsErrorMessage = nil

  if not drawOk then error(drawError, 0) end
  if not cleanupOk then error(cleanupError, 0) end
end

return MainWindow
