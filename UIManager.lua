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
local ui_textWrapped = ui.textWrapped
local ui_selectable = ui.selectable
local ui_sameLine = ui.sameLine
local math_floor = math.floor
local ui_pushStyleColor = ui.pushStyleColor
local ui_popStyleColor = ui.popStyleColor
local ui_StyleColor_Text = ui.StyleColor and ui.StyleColor.Text
local ui_getCursor = ui.getCursor
local ui_setCursor = ui.setCursor
local ui_drawRectFilled = ui.drawRectFilled
local ui_button = ui.button
local ui_StyleColor_Button = ui.StyleColor and ui.StyleColor.Button
local ui_StyleColor_ButtonHovered = ui.StyleColor and ui.StyleColor.ButtonHovered
local ui_StyleColor_ButtonActive = ui.StyleColor and ui.StyleColor.ButtonActive
local ui_availableSpaceX = ui.availableSpaceX
local ui_measureDWriteText = ui.measureDWriteText
local ui_combo = ui.combo
local ui_pushItemWidth = ui.pushItemWidth
local ui_popItemWidth = ui.popItemWidth
local ui_ComboFlags_None = ui.ComboFlags and ui.ComboFlags.None
local vec2 = vec2
local UIState = require('UIState')
local UIControls = require('lib/uilib/UIControls')
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

local CAR_BAR_WIDTH = 3
local CAR_ROW_INDENT = 10
local CarStateType = CarStateMachine.CarStateType or {}
local carStateColors = {}
local function setStateColors(color, ...)
  for i = 1, select('#', ...) do
    local stateID = CarStateType[(select(i, ...))]
    if stateID then carStateColors[stateID] = color end
  end
end
setStateColors(Theme.colors.success, 'DRIVING_NORMALLY')
setStateColors(Theme.colors.warning, 'EASING_IN_YIELD', 'STAYING_ON_YIELDING_LANE', 'EASING_OUT_YIELD', 'DEFENDING_POSITION')
setStateColors(Theme.colors.accent, 'EASING_IN_OVERTAKE', 'STAYING_ON_OVERTAKING_LANE', 'EASING_OUT_OVERTAKE')
setStateColors(Theme.colors.danger, 'WAITING_AFTER_ACCIDENT', 'COLLIDED_WITH_TRACK', 'COLLIDED_WITH_CAR',
  'ANOTHER_CAR_COLLIDED_INTO_ME', 'NAVIGATING_AROUND_ACCIDENT', 'DRIVING_IN_YELLOW_FLAG_ZONE')

local FILTERS = { 'All', 'Yielding', 'Overtaking', 'Incidents' }
local FILTER_IDS = { 'cars.filter.all', 'cars.filter.yielding', 'cars.filter.overtaking', 'cars.filter.incidents' }
local FILTER_COUNT = #FILTERS
local CHIP_GAP = Theme.layout.chipGap
local CHIP_HEIGHT = Theme.layout.chipHeight
local filterIndexByName = { All = 1, Yielding = 2, Overtaking = 3, Incidents = 4 }
local filterCounts = { 0, 0, 0, 0 }
local filterOptionScratch = { '', '', '', '' }
local stateFilterIndex = {}
local function setStateFilter(filterIndex, ...)
  for i = 1, select('#', ...) do
    local stateID = CarStateType[(select(i, ...))]
    if stateID then stateFilterIndex[stateID] = filterIndex end
  end
end
setStateFilter(2, 'EASING_IN_YIELD', 'STAYING_ON_YIELDING_LANE', 'EASING_OUT_YIELD', 'DEFENDING_POSITION')
setStateFilter(3, 'EASING_IN_OVERTAKE', 'STAYING_ON_OVERTAKING_LANE', 'EASING_OUT_OVERTAKE')
setStateFilter(4, 'WAITING_AFTER_ACCIDENT', 'COLLIDED_WITH_TRACK', 'COLLIDED_WITH_CAR',
  'ANOTHER_CAR_COLLIDED_INTO_ME', 'NAVIGATING_AROUND_ACCIDENT', 'DRIVING_IN_YELLOW_FLAG_ZONE')

---Draws the quick-filter chips and returns the selected filter index (1 = all cars).
local function drawCarFilterChips()
  for i = 1, FILTER_COUNT do filterCounts[i] = 0 end
  local list = CarManager.currentSortedCarsList
  if list then
    for n = 1, #list do
      local car = list[n]
      if car and CarManager.cars_initialized[car.index] then
        filterCounts[1] = filterCounts[1] + 1
        local fi = stateFilterIndex[CarStateMachine_getCurrentState(car.index)]
        if fi then filterCounts[fi] = filterCounts[fi] + 1 end
      end
    end
  end
  local selectedIndex = filterIndexByName[UIState.carFilter] or 1
  local chipLineWidth = math.max(0, ui_availableSpaceX and ui_availableSpaceX() or 500)
  local useCombo = false
  if ui_measureDWriteText then
    for i = 1, FILTER_COUNT do
      local chipText = T('%s (%d)', T(FILTERS[i]), filterCounts[i])
      local measured = ui_measureDWriteText(chipText, Theme.type.tab, -1).x
      if measured + Theme.spacing.lg > chipLineWidth then useCombo = true; break end
    end
  end
  if useCombo then
    for i = 1, FILTER_COUNT do filterOptionScratch[i] = T('%s (%d)', T(FILTERS[i]), filterCounts[i]) end
    ui_pushItemWidth(chipLineWidth)
    local index, changed = ui_combo('###cars.filter', selectedIndex, ui_ComboFlags_None, filterOptionScratch)
    ui_popItemWidth()
    if changed then UIState.carFilter = FILTERS[index] or 'All' end
    return filterIndexByName[UIState.carFilter] or 1
  end
  local chipLineUsed = 0
  for i = 1, FILTER_COUNT do
    local isSelected = i == selectedIndex
    ui_pushStyleColor(ui_StyleColor_Button, isSelected and Theme.colors.accentSoft or Theme.colors.surface)
    ui_pushStyleColor(ui_StyleColor_ButtonHovered, isSelected and Theme.colors.accentSoft or Theme.colors.divider)
    ui_pushStyleColor(ui_StyleColor_ButtonActive, Theme.colors.accent)
    ui_pushStyleColor(ui_StyleColor_Text, isSelected and Theme.colors.white or Theme.colors.muted)
    local chipText = T('%s (%d)', T(FILTERS[i]), filterCounts[i])
    local label = Localization.label(chipText, FILTER_IDS[i])
    local chipWidth = UIControls.chipWidth(ui_measureDWriteText and ui_measureDWriteText(chipText, Theme.type.tab, -1).x or 68, chipLineWidth)
    if i > 1 and chipLineUsed + CHIP_GAP + chipWidth <= chipLineWidth then
      ui_sameLine(0, CHIP_GAP)
      chipLineUsed = chipLineUsed + CHIP_GAP + chipWidth
    else
      chipLineUsed = chipWidth
    end
    if ui_button(label, vec2(chipWidth, CHIP_HEIGHT)) then UIState.carFilter = FILTERS[i] end
    for _ = 1, 4 do ui_popStyleColor() end
  end
  ui_newLine(0.5)
  return selectedIndex
end

UIManager.drawUICarList = function()
  local filterIndex = drawCarFilterChips()
  ui_separator()
  local sortedCarsList = CarManager.currentSortedCarsList
  if not sortedCarsList or #sortedCarsList == 0 then
    return
  end

  for n = 1, #sortedCarsList do
    local car = sortedCarsList[n]
    if car then
      local carIndex = car.index
      if CarManager.cars_initialized[carIndex] and
        (filterIndex == 1 or stateFilterIndex[CarStateMachine_getCurrentState(carIndex)] == filterIndex) then
        local state = CarStateMachine_getCurrentState(carIndex)
        local stateName = T(CarStateMachine.CarStateTypeStrings[state] or '')
        local rowLabel = Localization.label(T('Car #%02d - %s', carIndex, stateName), 'car.row.' .. carIndex)
        local isSelected = carIndex == uiCarListSelectedIndex
        local rowStart = ui_getCursor()
        local indentedX = rowStart.x + CAR_ROW_INDENT
        ui_setCursor(vec2(indentedX, rowStart.y))
        if ui_selectable(rowLabel, isSelected, ui.SelectableFlags.None, vec2(0, ui_textLineHeightWithSpacing())) then
          uiCarListSelectedIndex = carIndex
          CameraManager_followCarWithChaseCamera(carIndex)
        end
        local actualTrackLateralOffset = CarManager_getActualTrackLateralOffset(carIndex, car.position)
        local statusLine = T('Speed: %d km/h | Lane offset: %.3f', math_floor(car.speedKmh), actualTrackLateralOffset)
        local afterRow = ui_getCursor()
        ui_setCursor(vec2(indentedX, afterRow.y))
        -- Native text (not DirectWrite): dwriteText inside the scrolling child rendered corrupted glyphs.
        ui_pushStyleColor(ui_StyleColor_Text, Theme.colors.muted)
        if ui_textWrapped then
          ui_textWrapped(statusLine)
        else
          ui_text(statusLine)
        end
        ui_popStyleColor()
        local rowEnd = ui_getCursor()
        local barColor = carIndex == 0 and Theme.colors.accent or carStateColors[state] or Theme.colors.disabled
        ui_drawRectFilled(vec2(rowStart.x, rowStart.y), vec2(rowStart.x + CAR_BAR_WIDTH, rowEnd.y), barColor, 1, 0)
        ui_newLine(0.5)
      end
    end
  end
end

UIManager.drawMainWindowLateralOffsetsSection = function()
    -- ui.dwriteText('Driving Lanes', 15)
    -- ui.newLine(1)

    local wide = ui.availableSpaceX() >= 620
    ui_columns(wide and 2 or 1, false, "mainWindow_lateralsSection")
    if wide then ui_setColumnWidth(0, math.max(340, ui.availableSpaceX() * 0.48)) end

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
      if ui_textWrapped then ui_textWrapped(T('Overtaking Lateral Offset: %.3f (%s)', storage.overtakingLateralOffset, T(overtakingSideString))) else ui_text(T('Overtaking Lateral Offset: %.3f (%s)', storage.overtakingLateralOffset, T(overtakingSideString))) end
      ui_newLine(1)
    end
    if ui_textWrapped then ui_textWrapped(T('Default Lateral Offset: %.3f (%s)', storage.defaultLateralOffset, T(defaultDrivingSideString))) else ui_text(T('Default Lateral Offset: %.3f (%s)', storage.defaultLateralOffset, T(defaultDrivingSideString))) end
    if handleYielding then
      ui_newLine(1)
      if ui_textWrapped then ui_textWrapped(T('Yielding Lateral Offset: %.3f (%s)', storage.yieldingLateralOffset, T(yieldingSideString))) else ui_text(T('Yielding Lateral Offset: %.3f (%s)', storage.yieldingLateralOffset, T(yieldingSideString))) end
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
      T('Adjust driving lane offsets in Behavior.'),
      Theme.colors.muted)
end

UIManager.drawAppNotRunningMessageInMainWindow = function()
    local isOnline = Constants.IS_ONLINE

    if not isOnline then
      ui_text(T('Use the enable control in the header.'))
    end
    ui_newLine(0.5)

    local appEnabled = storage.enabled
    ui_text(T('App Enabled: '))
    ui_sameLine()
    local appEnabledColor = appEnabled and Theme.colors.success or Theme.colors.warning
    ui_textColored(T(appEnabled and 'yes' or 'no'), appEnabledColor)

    ui_sameLine(0, 20)
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
