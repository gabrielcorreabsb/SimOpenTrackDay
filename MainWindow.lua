local MainWindow = {}

local ui = ui
local Localization = require('Localization')
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Toggle = require('lib/uilib/Toggle')
local Section = require('lib/uilib/Section')
local UIControls = require('lib/uilib/UIControls')
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
local tabWidthScratch = { 0, 0, 0, 0, 0 }
local storage = StorageManager.getStorage()
local Constants = Constants
local ac = ac
local ac_setWindowOpen = ac and ac.setWindowOpen
local TAB_GAP = Theme.spacing.sm
local LAYOUT = Theme.layout
local ui_textWrapped = ui.textWrapped
local ui_drawRectFilled = ui.drawRectFilled
local ui_pushFont = ui.pushFont
local ui_popFont = ui.popFont
local ui_Font = ui.Font
local ui_iconButton = ui.iconButton
local ui_Icons = ui.Icons
local ui_pushID = ui.pushID
local ui_popID = ui.popID
local drawState = {
  shouldAppRun = nil,
  anyMissingCSPElements = false,
  missingCSPElementsErrorMessage = nil,
  shouldRun = false,
  operationalAvailable = false,
  childOpen = false,
  footerFontOpen = false,
  nativeFontOpen = false,
  headerFontOpen = false,
  brandFontOpen = false,
  contextStyleOpen = false,
  closeIDOpen = false,
  closeButtonStyleOpen = false,
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
    tabNames[i] = Localization.label(tabSources[i], 'main.tab.' .. tabIDs[i])
    tabWidthScratch[i] = ui.measureText(tabLabels[i], -1).x + Theme.spacing.lg
    totalWidth = totalWidth + tabWidthScratch[i]
    if i > 1 then totalWidth = totalWidth + TAB_GAP end
  end

  if totalWidth > ui.availableSpaceX() then
    local availableWidth = math.max(0, ui.availableSpaceX())
    local navigationText = Localization.text('Navigation')
    local navigationLabel = Localization.label('Navigation', 'main.tabs')
    local navigationWidth = ui.measureText(navigationText, -1).x
    local comboLabel = navigationLabel
    if availableWidth < LAYOUT.responsiveLabelThreshold then
      if ui_textWrapped then ui_textWrapped(navigationText) else ui.text(navigationText) end
      comboLabel = '###main.tabs'
      ui.pushItemWidth(availableWidth)
    else
      local comboWidth = UIControls.comboWidth(availableWidth, navigationWidth, LAYOUT.navigationComboMaxWidth)
      ui.pushItemWidth(comboWidth)
    end
    local comboOk, newIndex, changed = pcall(ui.combo, comboLabel, selectedIndex, ui.ComboFlags.None, tabLabels)
    local popOk, popError = pcall(ui.popItemWidth)
    if not comboOk then error(newIndex, 0) end
    if not popOk then error(popError, 0) end
    if changed then UIState.activeTab = tabSources[newIndex] or 'Overview' end
    return
  end

  for i = 1, #tabSources do
    if i > 1 then ui.sameLine(0, TAB_GAP) end
    local isSelected = i == selectedIndex
    Style.pushButton(isSelected and 'selected' or 'quiet')
    local tabTop = ui.getCursor()
    if ui.button(tabNames[i], vec2(tabWidthScratch[i], LAYOUT.tabHeight)) then
      UIState.activeTab = tabSources[i]
      selectedIndex = i
    end
    Style.popButton()
    if isSelected then
      local underlineTop = tabTop.y + LAYOUT.tabHeight - LAYOUT.tabUnderlineHeight
      ui_drawRectFilled(vec2(tabTop.x, underlineTop), vec2(tabTop.x + tabWidthScratch[i], tabTop.y + LAYOUT.tabHeight), Theme.colors.accent, 1, 0)
    end
  end
end

-- Colored dot + localized label. State is always carried by the text; the dot is reinforcement.
local function drawStatusIndicator(source, color)
  UIControls.drawStatus(source, color, Localization, ui, vec2)
end

local function currentItemBottom()
  local cursor = ui.getCursor()
  local itemMax = ui.itemRectMax()
  return math.max(cursor.y, itemMax.y)
end

local function drawHeader()
  if ui_pushFont and ui_popFont and ui_Font and ui_Font.Main then
    ui_pushFont(ui_Font.Main)
    drawState.headerFontOpen = true
  end
  local headerTop = ui.getCursor()
  local headerWidth = ui.availableSpaceX()
  local closeText = Localization.text('Close')
  local closeLabel = Localization.label('Close', 'main.window.close')
  local closeTextWidth = ui.measureText(closeText, -1).x
  local iconClose = ui_iconButton and ui_Icons and ui_Icons.Cancel and ui_pushID and ui_popID
  local closeCompact = not iconClose and closeTextWidth + Theme.spacing.md > headerWidth
  if closeCompact then closeLabel = 'X###main.window.close' end
  local closeButtonSize = iconClose and LAYOUT.closeButtonSize or LAYOUT.tabHeight
  local closeWidth = math.min(math.max(0, headerWidth), iconClose and closeButtonSize or
    ((closeCompact and ui.measureText('X', -1).x or closeTextWidth) + Theme.spacing.md))
  local brandText = 'SimOpenTrackDay'
  if ui_pushFont and ui_popFont and ui_Font and ui_Font.Title then
    ui_pushFont(ui_Font.Title)
    drawState.brandFontOpen = true
  end
  local brandSize = ui.measureText(brandText, -1)
  local brandWidth = brandSize.x
  local titleY = headerTop.y + math.max(0, (LAYOUT.headerTitleRowHeight - brandSize.y) / 2)
  if drawState.brandFontOpen then
    ui_popFont()
    drawState.brandFontOpen = false
  end
  local trackName = RaceTrackManager.getTrackName()
  local sessionName = Localization.text(RaceTrackManager.getSessionTypeName())
  local context = trackName .. ' | ' .. sessionName
  local contextWidth = math.max(0, headerWidth)
  local contextHeight = ui.measureText(context, contextWidth).y
  local contextY = headerTop.y + LAYOUT.headerTitleRowHeight + LAYOUT.headerContextGap
  local headerHeight = LAYOUT.headerTitleRowHeight + LAYOUT.headerContextGap + contextHeight + LAYOUT.headerBottomPadding
  if headerWidth > 12 then
    local headerRight = headerTop.x + headerWidth
    local headerBottom = headerTop.y + headerHeight
    ui_drawRectFilled(headerTop, vec2(headerRight, headerBottom), Theme.colors.surface, 8, 0)
  end
  if headerWidth >= brandWidth + closeWidth + Theme.spacing.lg then
    if ui_pushFont and ui_popFont and ui_Font and ui_Font.Title then
      ui_pushFont(ui_Font.Title)
      drawState.brandFontOpen = true
    end
    ui.setCursor(vec2(headerTop.x, titleY))
    ui.textColored(brandText, Theme.colors.white)
    if drawState.brandFontOpen then
      ui_popFont()
      drawState.brandFontOpen = false
    end
  end
  local closePosition = vec2(headerTop.x + headerWidth - closeWidth,
    headerTop.y + math.max(0, (LAYOUT.headerTitleRowHeight - closeButtonSize) / 2))
  ui.setCursor(closePosition)
  Style.pushButton('windowChrome')
  drawState.closeButtonStyleOpen = true
  local closeClicked
  if iconClose then
    ui_pushID('main.window.close')
    drawState.closeIDOpen = true
    closeClicked = ui_iconButton(ui_Icons.Cancel, vec2(closeWidth, closeButtonSize), Theme.colors.text, nil, -1)
    ui_popID()
    drawState.closeIDOpen = false
  else
    closeClicked = ui.button(closeLabel, vec2(closeWidth, LAYOUT.tabHeight))
  end
  Style.popButton()
  drawState.closeButtonStyleOpen = false
  if (iconClose or closeCompact) and ui.itemHovered() then ui.setTooltip(closeText) end
  if closeClicked and ac_setWindowOpen then ac_setWindowOpen('mainWindow', false) end
  ui.setCursor(vec2(headerTop.x, contextY))
  Style.push(ui.StyleColor.Text, Theme.colors.muted)
  drawState.contextStyleOpen = true
  if ui_textWrapped then ui_textWrapped(context) else ui.text(context) end
  Style.pop()
  drawState.contextStyleOpen = false

  local controlsY = headerTop.y + headerHeight + Theme.spacing.sm
  local headerControlsWide = headerWidth >= LAYOUT.headerWideControlThreshold
  ui.setCursor(vec2(headerTop.x, controlsY))
  if Toggle.render(Localization.label(storage.enabled and 'Enabled' or 'Disabled', 'settings.app.enabled'), storage.enabled) then
    storage.enabled = not storage.enabled
  end
  local controlsBottom = currentItemBottom()

  local languageText = Localization.text('Language')
  local languageLabelWidth = ui.measureText(languageText, -1).x
  local languageX, languageY, languageWidth
  if headerControlsWide then
    languageX = headerTop.x + headerWidth * LAYOUT.headerLanguageStartRatio
    local statusX = headerTop.x + headerWidth * LAYOUT.headerStatusStartRatio
    languageY = controlsY
    ui.setCursor(vec2(languageX, languageY))
    if ui_textWrapped then ui_textWrapped(languageText) else ui.text(languageText) end
    controlsBottom = math.max(controlsBottom, currentItemBottom())
    local comboX = languageX + languageLabelWidth + Theme.spacing.sm
    languageWidth = math.max(0, math.min(LAYOUT.languageComboMaxWidth, statusX - comboX - Theme.spacing.sm))
    ui.setCursor(vec2(comboX, languageY))
  else
    languageX = headerTop.x
    languageY = controlsBottom + LAYOUT.headerControlGap
    local languageAvailable = math.max(0, headerWidth)
    if languageAvailable < LAYOUT.responsiveLabelThreshold then
      ui.setCursor(vec2(languageX, languageY))
      if ui_textWrapped then ui_textWrapped(languageText) else ui.text(languageText) end
      controlsBottom = math.max(controlsBottom, currentItemBottom())
      languageY = controlsBottom + Theme.spacing.xs
      languageWidth = languageAvailable
      ui.setCursor(vec2(languageX, languageY))
    else
      ui.setCursor(vec2(languageX, languageY))
      if ui_textWrapped then ui_textWrapped(languageText) else ui.text(languageText) end
      controlsBottom = math.max(controlsBottom, currentItemBottom())
      local comboX = languageX + languageLabelWidth + Theme.spacing.sm
      languageWidth = math.max(0, math.min(LAYOUT.languageComboMaxWidth,
        headerTop.x + headerWidth - comboX))
      ui.setCursor(vec2(comboX, languageY))
    end
  end
  ui.pushItemWidth(languageWidth)
  local comboOk, languageIndex, languageChanged = pcall(ui.combo, '###settings.language', localeIndexes[Localization.getLocale()] or 1, ui.ComboFlags.None, Localization.localeNames)
  local popOk, popError = pcall(ui.popItemWidth)
  if not comboOk then error(languageIndex, 0) end
  if not popOk then error(popError, 0) end
  controlsBottom = math.max(controlsBottom, currentItemBottom())
  if languageChanged then Localization.setLocale(locales[languageIndex] or 'en') end

  local statusY = headerControlsWide and controlsY or (controlsBottom + LAYOUT.headerControlGap)
  local statusX = headerControlsWide and (headerTop.x + headerWidth * LAYOUT.headerStatusStartRatio) or headerTop.x
  ui.setCursor(vec2(statusX, statusY))
  drawState.shouldRun = drawState.shouldAppRun()
  drawState.operationalAvailable = drawState.shouldRun and not drawState.anyMissingCSPElements
  if drawState.operationalAvailable then
    drawStatusIndicator('Operational', Theme.colors.success)
  elseif storage.enabled then
    drawStatusIndicator('SimOpenTrackDay is not running.', Theme.colors.warning)
  else
    drawStatusIndicator('Disabled', Theme.colors.disabled)
  end
  controlsBottom = math.max(controlsBottom, currentItemBottom(), statusY + 5 + LAYOUT.statusDotSize)
  ui.setCursor(vec2(headerTop.x, controlsBottom + LAYOUT.headerControlGap))
  if drawState.anyMissingCSPElements and drawState.missingCSPElementsErrorMessage and drawState.missingCSPElementsErrorMessage ~= '' then
    ui.separator()
    if ui_textWrapped then ui_textWrapped(drawState.missingCSPElementsErrorMessage) else ui.text(drawState.missingCSPElementsErrorMessage) end
    controlsBottom = math.max(controlsBottom, currentItemBottom())
  end

  if not drawState.shouldRun then
    UIManager.drawAppNotRunningMessageInMainWindow()
    controlsBottom = math.max(controlsBottom, currentItemBottom())
  end
  ui.setCursor(vec2(headerTop.x, controlsBottom + LAYOUT.headerControlGap))
  if drawState.headerFontOpen then
    ui_popFont()
    drawState.headerFontOpen = false
  end
end

local function drawDrivingLanesSection()
  UIManager.drawMainWindowLateralOffsetsSection()
end

local function drawWindowBody()
  Style.windowBegin('mainWindow')
  drawState.styleOpen = true
  ui.pushDWriteFont('Segoe UI')
  drawState.fontOpen = true
  local nativeFont
  if ui_Font then
    nativeFont = ui_Font.Title or ui_Font.Main
  end
  if ui_pushFont and ui_popFont and nativeFont then
    ui_pushFont(nativeFont)
    drawState.nativeFontOpen = true
  end

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
      Section.section('Driving lanes', drawDrivingLanesSection)
      ui.newLine(1)
      ui.text(Localization.text('AI car list'))
      ui.separator()
      UIManager.drawUICarList()
    end
    ui.newLine(1)
    ui.separator()
    local versionAndCredit = Localization.text('%s v%s | developed by %s | original author: %s', Constants.APP_NAME, Constants.APP_VERSION, Constants.APP_DEVELOPER, Constants.APP_AUTHOR)
    if ui_pushFont and ui_popFont and ui_Font and ui_Font.Main then
      ui_pushFont(ui_Font.Main)
      drawState.footerFontOpen = true
    end
    if ui_textWrapped then
      ui_textWrapped(versionAndCredit)
    else
      ui.textColored(versionAndCredit, Theme.colors.muted)
    end
    if drawState.footerFontOpen then
      ui_popFont()
      drawState.footerFontOpen = false
    end
  end
end

local function closeWindowScopes()
  local cleanupOk, cleanupError = true, nil
  if drawState.closeIDOpen then
    drawState.closeIDOpen = false
    local ok, err = pcall(ui_popID)
    if not ok then cleanupOk, cleanupError = false, err end
  end
  if drawState.closeButtonStyleOpen then
    drawState.closeButtonStyleOpen = false
    local ok, err = pcall(Style.popButton)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.contextStyleOpen then
    drawState.contextStyleOpen = false
    local ok, err = pcall(Style.pop)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.brandFontOpen then
    drawState.brandFontOpen = false
    local ok, err = pcall(ui_popFont)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.headerFontOpen then
    drawState.headerFontOpen = false
    local ok, err = pcall(ui_popFont)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.footerFontOpen then
    drawState.footerFontOpen = false
    local ok, err = pcall(ui_popFont)
    if not ok then cleanupOk, cleanupError = false, err end
  end
  if drawState.childOpen then
    drawState.childOpen = false
    local ok, err = pcall(ui.endChild)
    if not ok and cleanupOk then cleanupOk, cleanupError = false, err end
  end
  if drawState.nativeFontOpen then
    drawState.nativeFontOpen = false
    local ok, err = pcall(ui_popFont)
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
