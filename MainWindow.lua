local MainWindow = {}

local ui = ui
local ui_textColored = ui.textColored
local ui_newLine = ui.newLine
local ui_separator = ui.separator
local ui_button = ui.button
local math = math
local Localization = require('Localization')
local ColorManager = ColorManager
local AppIconRenderer_draw = AppIconRenderer.draw
local UIManager = UIManager
local UIManager_toggleSettingsWindow = UIManager.toggleSettingsWindow
local UIManager_drawMainWindowLateralOffsetsSection = UIManager.drawMainWindowLateralOffsetsSection
local UIManager_drawUICarList = UIManager.drawUICarList
local UIManager_drawAppNotRunningMessageInMainWindow = UIManager.drawAppNotRunningMessageInMainWindow
local localeIndexes = { en = 1, ['pt-BR'] = 2, es = 3 }
local locales = { 'en', 'pt-BR', 'es' }

function MainWindow.draw(shouldAppRun, anyMissingCSPElements, missingCSPElementsErrorMessage)
  ui_textColored(Localization.text("SimOpenTrackDay allows you to alter the AI cars' behavior to act more like humans driving during a track day event by yielding to faster cars and overtaking slower cars."), ColorManager.RGBM_Colors.WhiteSmoke)
  ui_newLine(1)
  local localeIndex, localeChanged = ui.combo(Localization.label('Language', 'settings.language'), localeIndexes[Localization.getLocale()] or 1, ui.ComboFlags.None, Localization.localeNames)
  if localeChanged then Localization.setLocale(locales[localeIndex] or 'en') end
  ui_newLine(1)

  -- Show the missing CSP elements error message if needed
  if anyMissingCSPElements and missingCSPElementsErrorMessage and missingCSPElementsErrorMessage ~= '' then
    ui_textColored(missingCSPElementsErrorMessage, rgbm(1, 0, 0, 1))
    ui_newLine(1)
    ui_separator()
    ui_newLine(1)
  end

  AppIconRenderer_draw()

  local settingsButtonText = Localization.text('Modify Settings')
  local settingsButtonWidth = math.min(ui.availableSpaceX(), math.max(120, ui.measureDWriteText(settingsButtonText, 14, -1).x + 24))
  if ui_button(Localization.label('Modify Settings', 'main.settings'), vec2(settingsButtonWidth, 40)) then
    UIManager_toggleSettingsWindow()
  end
  ui_newLine(1)

  -- If the app is not running, show a message and stop drawing further UI
  if (not shouldAppRun()) then
    UIManager_drawAppNotRunningMessageInMainWindow()
    return
  end

  -- ui.text(string.format('AI cars yielding to the %s', RaceTrackManager.TrackSideStrings[RaceTrackManager.getYieldingSide()]))
  -- ui.newLine(1)

  ui.dwriteText(Localization.text('Driving lanes'), 17)
  ui_separator()
  UIManager_drawMainWindowLateralOffsetsSection()

  ui_newLine(1)

  ui.dwriteText(Localization.text('AI car list'), 17)
  ui_separator()
  UIManager_drawUICarList()

end

return MainWindow
