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
local ui_itemRectMax = ui.itemRectMax
local ui_setCursor = ui.setCursor
local ui_drawRectFilled = ui.drawRectFilled
local ui_button = ui.button
local ui_StyleColor_Button = ui.StyleColor and ui.StyleColor.Button
local ui_StyleColor_ButtonHovered = ui.StyleColor and ui.StyleColor.ButtonHovered
local ui_StyleColor_ButtonActive = ui.StyleColor and ui.StyleColor.ButtonActive
local ui_availableSpaceX = ui.availableSpaceX
local ui_measureDWriteText = ui.measureDWriteText
local ui_measureText = ui.measureText
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

local function currentItemBottom()
  local cursorBottom = ui_getCursor().y
  if ui_itemRectMax then
    local itemMax = ui_itemRectMax()
    if itemMax then return math.max(cursorBottom, itemMax.y) end
  end
  return cursorBottom
end

UIManager.drawUICarList = function()
  local filterIndex = drawCarFilterChips()
  ui_separator()
  local sortedCarsList = CarManager.currentSortedCarsList
  if not sortedCarsList or #sortedCarsList == 0 then
    if ui_textWrapped then ui_textWrapped(T('No cars available.')) else ui_text(T('No cars available.')) end
    return
  end

  if filterCounts[1] == 0 then
    if ui_textWrapped then ui_textWrapped(T('No initialized cars available.')) else ui_text(T('No initialized cars available.')) end
    return
  end

  if filterIndex ~= 1 and filterCounts[filterIndex] == 0 then
    if ui_textWrapped then ui_textWrapped(T('No cars match this filter.')) else ui_text(T('No cars match this filter.')) end
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
        local numberLabel = T('Car #%02d', carIndex)
        local rowLabel = Localization.label(numberLabel, 'car.row.' .. carIndex)
        local isSelected = carIndex == uiCarListSelectedIndex
        local rowStart = ui_getCursor()
        local indentedX = rowStart.x + CAR_ROW_INDENT
        local rowWidth = math.max(0, (ui_availableSpaceX and ui_availableSpaceX() or 500) - CAR_ROW_INDENT)
        local numberWidth = ui_measureText and ui_measureText(numberLabel, -1).x + Theme.spacing.md or 76
        numberWidth = math.min(rowWidth, numberWidth)
        ui_setCursor(vec2(indentedX, rowStart.y))
        if ui_selectable(rowLabel, isSelected, ui.SelectableFlags.None,
          vec2(rowWidth, ui_textLineHeightWithSpacing())) then
          uiCarListSelectedIndex = carIndex
          CameraManager_followCarWithChaseCamera(carIndex)
        end

        local stateMeasure = ui_measureText and ui_measureText(stateName, -1).x or rowWidth
        local stateInline = numberWidth + Theme.spacing.sm + stateMeasure <= rowWidth
        local stateX = stateInline and (indentedX + numberWidth + Theme.spacing.sm) or indentedX
        local titleY = rowStart.y + (stateInline and 0 or ui_textLineHeightWithSpacing())
        ui_setCursor(vec2(stateX, titleY))
        if ui_textWrapped then ui_textWrapped(stateName) else ui_text(stateName) end
        local titleBottom = currentItemBottom()

        local actualTrackLateralOffset = CarManager_getActualTrackLateralOffset(carIndex, car.position)
        local telemetryY = math.max(titleBottom, rowStart.y + ui_textLineHeightWithSpacing())
        local telemetryWidth = math.max(1, rowWidth * 0.5)
        local speedText = T('Speed: %d km/h', math_floor(car.speedKmh))
        local offsetText = T('Lane offset: %.3f', actualTrackLateralOffset)
        local speedWidth = ui_measureText and ui_measureText(speedText, -1).x or telemetryWidth + 1
        local offsetWidth = ui_measureText and ui_measureText(offsetText, -1).x or telemetryWidth + 1
        local telemetryInline = speedWidth <= telemetryWidth and offsetWidth <= telemetryWidth
        ui_setCursor(vec2(indentedX, telemetryY))
        -- Native text (not DirectWrite): wrapped columns stay aligned without clipping long translations.
        if telemetryInline then ui_text(speedText)
        elseif ui_textWrapped then ui_textWrapped(speedText)
        else ui_text(speedText) end
        local speedBottom = currentItemBottom()
        local offsetX = telemetryInline and (indentedX + telemetryWidth) or indentedX
        local offsetY = telemetryInline and telemetryY or speedBottom
        ui_setCursor(vec2(offsetX, offsetY))
        if telemetryInline then ui_text(offsetText)
        elseif ui_textWrapped then ui_textWrapped(offsetText)
        else ui_text(offsetText) end
        local offsetBottom = currentItemBottom()
        local rowEndY = math.max(titleBottom, speedBottom, offsetBottom)
        local barColor = carIndex == 0 and Theme.colors.accent or carStateColors[state] or Theme.colors.disabled
        ui_drawRectFilled(vec2(rowStart.x, rowStart.y), vec2(rowStart.x + CAR_BAR_WIDTH, rowEndY), barColor, 1, 0)
        ui_setCursor(vec2(rowStart.x, rowEndY))
      end
    end
  end
end

UIManager.drawMainWindowLateralOffsetsSection = function()
    local handleYielding = storage_Yielding.handleYielding
    local handleOvertaking = storage_Overtaking.handleOvertaking
    local yieldingSide = RaceTrackManager_getYieldingSide()
    local overtakingSide = RaceTrackManager_getOvertakingSide()
    UILateralOffsetsImageWidget_draw(storage, Theme.spacing.md)
    if yieldingSide == overtakingSide then
      ui_textColored(T('Yielding side and overtaking side are the same!'), ColorManager.RGBM_Colors.Yellow)
    end

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
