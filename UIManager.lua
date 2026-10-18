local UIManager = {}

--bindings
local ac = ac
local ac_setWindowOpen = ac.setWindowOpen
local ui = ui
local Localization = require('Localization')
local function T(source, ...) return Localization.text(source, ...) end
local Theme = require('lib/uilib/Theme')
local ui_columns = ui.columns
local ui_setColumnWidth = ui.setColumnWidth
local ui_nextColumn = ui.nextColumn
local ui_newLine = ui.newLine
local ui_text = ui.text
local ui_separator = ui.separator
local ui_textColored = ui.textColored
local ui_textLineHeightWithSpacing = ui.textLineHeightWithSpacing
local ui_selectable = ui.selectable
local ui_sameLine = ui.sameLine
local math_floor = math.floor
local ui_textWrapped = ui.textWrapped
local StorageManager = StorageManager
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_getDefaultDrivingSide = RaceTrackManager.getDefaultDrivingSide
local RaceTrackManager_getOvertakingSide = RaceTrackManager.getOvertakingSide
local RaceTrackManager_getYieldingSide = RaceTrackManager.getYieldingSide
local ColorManager = ColorManager
local UILateralOffsetsImageWidget = UILateralOffsetsImageWidget
local UILateralOffsetsImageWidget_draw = UILateralOffsetsImageWidget.draw
local CarStateMachine = CarStateMachine
local CarStateMachine_getCurrentState = CarStateMachine.getCurrentState
local CarManager = CarManager
local CarManager_getActualTrackLateralOffset = CarManager.getActualTrackLateralOffset
local CameraManager = CameraManager
local CameraManager_followCarWithChaseCamera = CameraManager.followCarWithChaseCamera


-- These are the window IDs as defined in the manifest.ini
local MAIN_WINDOW_ID = 'mainWindow'

UIManager.VERTICAL_SCROLLBAR_WIDTH = 9 * 2 -- Andreas: the * 2 is to account for the tiny margin that's created next to the vertical scrollbar which seems to be the same size as the scrollbar width

local storage = StorageManager.getStorage()
local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Overtaking = StorageManager.getStorage_Overtaking()

local uiCarListSelectedIndex = 0

UIManager.drawUICarList = function()
  ui_separator()
  local sortedCarsList = CarManager.currentSortedCarsList
  if not sortedCarsList or #sortedCarsList == 0 then
    return
  end

  for n = 1, #sortedCarsList do
    local car = sortedCarsList[n]
    if car then
      local carIndex = car.index
      if CarManager.cars_initialized[carIndex] then
        local state = CarStateMachine_getCurrentState(carIndex)
        local stateName = T(CarStateMachine.CarStateTypeStrings[state] or '')
        local rowLabel = Localization.label(T('Car #%02d - %s', carIndex, stateName), 'car.row.' .. carIndex)
        local isSelected = carIndex == uiCarListSelectedIndex
        if ui_selectable(rowLabel, isSelected, ui.SelectableFlags.None, vec2(0, ui_textLineHeightWithSpacing())) then
          uiCarListSelectedIndex = carIndex
          CameraManager_followCarWithChaseCamera(carIndex)
        end
        local actualTrackLateralOffset = CarManager_getActualTrackLateralOffset(carIndex, car.position)
        local statusLine = T('Speed: %d km/h | Lane offset: %.3f', math_floor(car.speedKmh), actualTrackLateralOffset)
        if ui_textWrapped then
          ui_textWrapped(statusLine)
        else
          ui_text(statusLine)
        end
        ui_newLine(0.5)
      end
    end
  end
end

UIManager.drawMainWindowLateralOffsetsSection = function()
    -- ui.dwriteText('Driving Lanes', 15)
    -- ui.newLine(1)

    local wide = ui.availableSpaceX() >= 700
    ui_columns(wide and 2 or 1, false, "mainWindow_lateralsSection")
    if wide then ui_setColumnWidth(0, 260) end

    local handleYielding = storage_Yielding.handleYielding
    local handleOvertaking = storage_Overtaking.handleOvertaking

    local yieldingSide = RaceTrackManager_getYieldingSide()
    local overtakingSide = RaceTrackManager_getOvertakingSide()
    local defaultDrivingSide = RaceTrackManager_getDefaultDrivingSide()
    local yieldingSideString = RaceTrackManager.TrackSideStrings[yieldingSide]
    local overtakingSideString = RaceTrackManager.TrackSideStrings[overtakingSide]
    local defaultDrivingSideString = RaceTrackManager.TrackSideStrings[defaultDrivingSide]

    ui_newLine(1)
    if handleOvertaking then
      ui_text(T('Overtaking Lateral Offset: %.3f (%s)', storage.overtakingLateralOffset, T(overtakingSideString)))
      ui_newLine(1)
    end
    ui_text(T('Default Lateral Offset: %.3f (%s)', storage.defaultLateralOffset, T(defaultDrivingSideString)))
    if handleYielding then
      ui_newLine(1)
      ui_text(T('Yielding Lateral Offset: %.3f (%s)', storage.yieldingLateralOffset, T(yieldingSideString)))
    end

    if wide then ui_nextColumn() else ui_newLine(1) end

    UILateralOffsetsImageWidget_draw(storage)
    if yieldingSide == overtakingSide then
      ui_textColored(T('Yielding side and overtaking side are the same!'), ColorManager.RGBM_Colors.Yellow)
    end

    -- end the table
    ui_columns(1, false)
    ui_newLine(1)
    ui_textColored(
      T('Adjust driving lane offsets in Overview.'),
      Theme.colors.muted)
end

UIManager.drawAppNotRunningMessageInMainWindow = function()
    local isOnline = Constants.IS_ONLINE

    ui_textColored(T('SimOpenTrackDay is not running.'), Theme.colors.warning)
    if not isOnline then
      ui_text(T('Use the enable control in the header.'))
    end
    ui_newLine(1)

    local appEnabled = storage.enabled
    ui_text(T('App Enabled: '))
    ui_sameLine()
    local appEnabledColor = appEnabled and Theme.colors.success or Theme.colors.warning
    ui_textColored(T(appEnabled and 'yes' or 'no'), appEnabledColor)

    ui_text(T('Playing Online: '))
    ui_sameLine()
    local isOnlineColor = isOnline and Theme.colors.warning or Theme.colors.success
    ui_textColored(T(isOnline and 'yes' or 'no'), isOnlineColor)
end

---Opens or closes the specified window.
---@param windowID string
---@param open boolean @true to open, false to close
local openWindow = function(windowID, open)
  ac_setWindowOpen(windowID, open)
end

UIManager.openMainWindow = function()
  openWindow(MAIN_WINDOW_ID, true)
end

return UIManager
