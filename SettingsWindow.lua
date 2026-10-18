local SettingsWindow = {}

-- bindings
local ui = ui
local ui_itemHovered = ui.itemHovered
local Localization = require('Localization')
local ui_setTooltip_raw = ui.setTooltip
local ui_setTooltip = function(message, ...) return ui_setTooltip_raw(Localization.text(message, ...)) end
local ui_pushDisabled = ui.pushDisabled
local ui_popDisabled = ui.popDisabled
local ui_columns = ui.columns
local ui_setColumnWidth = ui.setColumnWidth
local ui_nextColumn = ui.nextColumn
local ui_button = ui.button
local ui_newLine = ui.newLine
local ui_text_raw = ui.text
local ui_text = function(message, ...) return ui_text_raw(Localization.text(message, ...)) end
local ui_separator = ui.separator
local ui_textColored_raw = ui.textColored
local ui_textColored = function(message, color, ...) return ui_textColored_raw(Localization.text(message, ...), color) end
local ui_pushStyleColor = ui.pushStyleColor
local ui_popStyleColor = ui.popStyleColor
local ui_dwriteText = ui.dwriteText
local Toggle = require('lib/uilib/Toggle')
local ui_checkbox = Toggle.render
local ui_combo = ui.combo
local ui_pushDWriteFont = ui.pushDWriteFont
local ui_popDWriteFont = ui.popDWriteFont
local ui_StyleColor = ui.StyleColor
local string = string
local string_format = string.format
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_getTrackName = RaceTrackManager.getTrackName
local RaceTrackManager_getSessionTypeName = RaceTrackManager.getSessionTypeName
local RaceTrackManager_getOvertakingSide = RaceTrackManager.getOvertakingSide
local RaceTrackManager_getYieldingSide = RaceTrackManager.getYieldingSide
local ColorManager = ColorManager
local Theme = require('lib/uilib/Theme')
local Style = require('lib/uilib/Style')
local Section = require('lib/uilib/Section')
local Logo = require('lib/uilib/Logo')
local Slider = require('lib/uilib/Slider')
local UIOperations_renderSlider = Slider.render
local UILateralOffsetsImageWidget = UILateralOffsetsImageWidget
local UILateralOffsetsImageWidget_draw = UILateralOffsetsImageWidget.draw
local UIAppNameVersionWidget = UIAppNameVersionWidget
local UIAppNameVersionWidget_drawBottomRight = UIAppNameVersionWidget.drawBottomRight
local UIOperations = UIOperations
local UIOperations_createDisabledSection = UIOperations.createDisabledSection

local SettingsModel = require('SettingsModel')
local UIState = require('UIState')
local StorageManager_getPerTrackPerModeStorageKey = SettingsModel.getPerTrackPerModeStorageKey
local StorageManager_Profile = SettingsModel.Profile
local StorageManager_BehaviorMode = SettingsModel.BehaviorMode
local StorageManager_applyBehaviorProfile = SettingsModel.applyBehaviorProfile

local StorageManager_options_default = SettingsModel.options_default
local StorageManager_options_min = SettingsModel.options_min
local StorageManager_options_max = SettingsModel.options_max

local StorageManager_options_Yielding_default = SettingsModel.options_Yielding_default
local StorageManager_options_Yielding_min = SettingsModel.options_Yielding_min
local StorageManager_options_Yielding_max = SettingsModel.options_Yielding_max

local StorageManager_options_Overtaking_default = SettingsModel.options_Overtaking_default
local StorageManager_options_Overtaking_min = SettingsModel.options_Overtaking_min
local StorageManager_options_Overtaking_max = SettingsModel.options_Overtaking_max

local StorageManager_options_AICarValues_default = SettingsModel.options_AICarValues_default
local StorageManager_options_AICarValues_min = SettingsModel.options_AICarValues_min
local StorageManager_options_AICarValues_max = SettingsModel.options_AICarValues_max

local StorageManager_options_PathFinding_default = SettingsModel.options_PathFinding_default
local StorageManager_options_PathFinding_min = SettingsModel.options_PathFinding_min
local StorageManager_options_PathFinding_max = SettingsModel.options_PathFinding_max

local StorageManager_Options = SettingsModel.Options
local StorageManager_Options_Yielding = SettingsModel.Options_Yielding
local StorageManager_Options_Overtaking = SettingsModel.Options_Overtaking
local StorageManager_Options_AICarValues = SettingsModel.Options_AICarValues
local StorageManager_Options_PathFinding = SettingsModel.Options_PathFinding



local UI_HEADER_TEXT_FONT_SIZE = 15
local ui_availableSpaceX = ui.availableSpaceX
local ui_sameLine = ui.sameLine
local function translatedLabel(text, id) return Localization.label(text, id) end

local DEFAULT_SLIDER_WIDTH = 200
local DEFAULT_SLIDER_FORMAT = '%.2f'

local DEFAULT_SLIDERGRAB_STYLECOLOR = Theme.colors.accent
local AICAUTION_SLIDERGRAB_COLOR_WHEN_SET_TO_ZERO = Theme.colors.accentSoft

local storage = SettingsModel.getStorage()
local storage_Yielding = SettingsModel.getStorage_Yielding()
local storage_Overtaking = SettingsModel.getStorage_Overtaking()
local storage_AICarValues = SettingsModel.getStorage_AICarValues()
local storage_PathFinding = SettingsModel.getStorage_PathFinding()
local storage_Behavior = SettingsModel.getStorage_Behavior()
local function drawLanguageSelector()
    local indexes = { en = 1, ['pt-BR'] = 2, es = 3 }
    local locales = { 'en', 'pt-BR', 'es' }
    local index, changed = ui_combo(translatedLabel('Language', 'settings.language'), indexes[Localization.getLocale()] or 1, ui.ComboFlags.None, Localization.localeNames)
    if changed then Localization.setLocale(locales[index] or 'en') end
end


local getSliderColorForAICautionWhenSetToZero = function(aiCautionValue)
    return aiCautionValue < 1 and AICAUTION_SLIDERGRAB_COLOR_WHEN_SET_TO_ZERO or DEFAULT_SLIDERGRAB_STYLECOLOR
end

local drawAICarValuesSection = function()
    local wideLayout = ui_availableSpaceX() >= 1100
    ui_columns(wideLayout and 3 or 1, false, "aiCarValuesSection")
    if wideLayout then
      ui_setColumnWidth(0, ui.windowWidth() * 0.32)
      ui_setColumnWidth(1, ui.windowWidth() * 0.32)
      ui_setColumnWidth(2, ui.windowWidth() * 0.32)
    end

    Section.section('Caution', function()
    ui_newLine(1)
    ui_text('Caution determines how much space cars keep from each other while driving.\nA higher caution means a larger gap between cars.')
    ui_newLine(1)

    ui_pushStyleColor(ui_StyleColor.SliderGrab, getSliderColorForAICautionWhenSetToZero(storage_AICarValues.defaultAICaution))
    storage_AICarValues.defaultAICaution =  UIOperations_renderSlider('Caution while driving normally', 'The default gap cars keep between each other while driving on the default driving lane.\n\nThe higher this value is, the more cautious the cars will be by keeping a larger gap between each other, which can provide a more relaxed trackday experience.', storage_AICarValues.defaultAICaution, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.DefaultAICaution], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.DefaultAICaution], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.DefaultAICaution]) -- do not drop the minimum below 2 because 1 is used while overtaking
    ui_popStyleColor()

    storage_AICarValues.AICaution_OvertakingWithNoObstacleInFront =  UIOperations_renderSlider('Caution while overtaking (No obstacle in front)', 'The caution level used when overtaking another car if there is no obstacle in front of the overtaking car.\n\nThe lower this value is, the more aggressive the cars will be while overtaking when there is no obstacle in front of them.', storage_AICarValues.AICaution_OvertakingWithNoObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AICaution_OvertakingWithNoObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AICaution_OvertakingWithNoObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AICaution_OvertakingWithNoObstacleInFront])

    ui_pushStyleColor(ui_StyleColor.SliderGrab, getSliderColorForAICautionWhenSetToZero(storage_AICarValues.AICaution_OvertakingWithObstacleInFront))
    storage_AICarValues.AICaution_OvertakingWithObstacleInFront =  UIOperations_renderSlider('Caution while overtaking (Obstacle in front)', 'The caution level used when overtaking another car if there is an obstacle in front of the overtaking car.\n\nThe higher this value is, the more cautious the cars will be while overtaking when there is an obstacle in front of them.', storage_AICarValues.AICaution_OvertakingWithObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AICaution_OvertakingWithObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AICaution_OvertakingWithObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AICaution_OvertakingWithObstacleInFront])
    ui_popStyleColor()

    ui_pushStyleColor(ui_StyleColor.SliderGrab, getSliderColorForAICautionWhenSetToZero(storage_AICarValues.AICaution_OvertakingWhileInCorner))
    storage_AICarValues.AICaution_OvertakingWhileInCorner =  UIOperations_renderSlider('Caution while overtaking in corner', 'The caution level used when overtaking another car while in a corner.\n\nThe higher this value is, the more cautious the cars will be while overtaking in corners.', storage_AICarValues.AICaution_OvertakingWhileInCorner, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AICaution_OvertakingWhileInCorner], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AICaution_OvertakingWhileInCorner], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AICaution_OvertakingWhileInCorner])
    ui_popStyleColor()

    ui_pushStyleColor(ui_StyleColor.SliderGrab, getSliderColorForAICautionWhenSetToZero(storage_AICarValues.AICaution_Yielding))
    storage_AICarValues.AICaution_Yielding =  UIOperations_renderSlider('Caution while yielding', 'The caution level used when yielding (giving way to faster cars).\n\nThe higher this value is, the more cautious the cars will be while yielding.', storage_AICarValues.AICaution_Yielding, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AICaution_Yielding], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AICaution_Yielding], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AICaution_Yielding])
    ui_popStyleColor()
    end)
    if wideLayout then ui_nextColumn() end

    Section.section('Aggression', function()
    ui_newLine(1)
    ui_text('Aggression determines how aggressively cars drive on the track.\nA higher aggression means the cars will try to go faster and take more risks.')
    ui_newLine(1)

    if ui_checkbox('Override original Aggression values when driving normally', storage_AICarValues.overrideOriginalAIAggression_drivingNormally) then storage_AICarValues.overrideOriginalAIAggression_drivingNormally = not storage_AICarValues.overrideOriginalAIAggression_drivingNormally end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original aggression value thats is set from the game launcher when the car is driving normally.') end

    local overrideOriginalAIAggression_drivingNormally = storage_AICarValues.overrideOriginalAIAggression_drivingNormally
    UIOperations_createDisabledSection(not overrideOriginalAIAggression_drivingNormally, function()
        storage_AICarValues.defaultAIAggression =  UIOperations_renderSlider('Aggression while driving normally', 'The default aggression level cars exhibit when driving on the default driving lane.\n\nThe higher this value is, the more aggressive the cars will be (although the exact definition of aggression is still a bit unclear at the moment).', storage_AICarValues.defaultAIAggression, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.DefaultAIAggression], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.DefaultAIAggression], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.DefaultAIAggression]) -- do not set above 0.95 because 1.0 is reserved for overtaking with no obstacles
    end)

    if ui_checkbox('Override original aggression when overtaking', storage_AICarValues.overrideOriginalAIAggression_overtaking) then storage_AICarValues.overrideOriginalAIAggression_overtaking = not storage_AICarValues.overrideOriginalAIAggression_overtaking end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original aggression value thats is set from the game launcher when the car is overtaking another car.') end

    local overrideOriginalAIAggression_overtaking = storage_AICarValues.overrideOriginalAIAggression_overtaking
    UIOperations_createDisabledSection(not overrideOriginalAIAggression_overtaking, function()
        storage_AICarValues.AIAggression_OvertakingWithNoObstacleInFront = UIOperations_renderSlider('Aggression while overtaking (No obstacle in front)', 'The aggression level used when overtaking another car if there is no obstacle in front of the overtaking car.\n\nThe higher this value is, the more aggressive the cars will be while overtaking when there is no obstacle in front of them.', storage_AICarValues.AIAggression_OvertakingWithNoObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIAggression_OvertakingWithNoObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIAggression_OvertakingWithNoObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIAggression_OvertakingWithNoObstacleInFront])
        storage_AICarValues.AIAggression_OvertakingWithObstacleInFront = UIOperations_renderSlider('Aggression while overtaking (Obstacle in front)', 'The aggression level used when overtaking another car if there is an obstacle in front of the overtaking car.\n\nThe lower this value is, the more cautious the cars will be while overtaking when there is an obstacle in front of them.', storage_AICarValues.AIAggression_OvertakingWithObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIAggression_OvertakingWithObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIAggression_OvertakingWithObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIAggression_OvertakingWithObstacleInFront])
        storage_AICarValues.AIAggression_WhileInCorner = UIOperations_renderSlider('Aggression while overtaking in corner', 'The aggression level used when overtaking another car while in a corner.\n\nThe lower this value is, the more cautious the cars will be while overtaking in corners.', storage_AICarValues.AIAggression_WhileInCorner, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIAggression_WhileInCorner], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIAggression_WhileInCorner], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIAggression_WhileInCorner])
    end)

    if ui_checkbox('Override original aggression when yielding', storage_AICarValues.overrideOriginalAIAggression_yielding) then storage_AICarValues.overrideOriginalAIAggression_yielding = not storage_AICarValues.overrideOriginalAIAggression_yielding end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original aggression value thats is set from the game launcher when the car is yielding (giving way to faster cars).') end

    local overrideOriginalAIAggression_yielding = storage_AICarValues.overrideOriginalAIAggression_yielding
    UIOperations_createDisabledSection(not overrideOriginalAIAggression_yielding, function()
        storage_AICarValues.AIAggression_Yielding = UIOperations_renderSlider('Aggression while yielding', 'The aggression level used when yielding (giving way to faster cars).\n\nThe lower this value is, the more cautious the cars will be while yielding.', storage_AICarValues.AIAggression_Yielding, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIAggression_Yielding], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIAggression_Yielding], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIAggression_Yielding])
    end)
    end)
    if wideLayout then ui_nextColumn() end

    Section.section('Difficulty', function()
    ui_newLine(1)
    ui_text('Difficulty Level affects how effective the cars are with the pedals and how fast they can handle corners.\nA higher difficulty level means the cars will be overall faster and more competitive.')
    ui_newLine(1)

    if ui_checkbox('Override original Difficulty Level when driving normally', storage_AICarValues.overrideOriginalAIDifficultyLevel_drivingNormally) then storage_AICarValues.overrideOriginalAIDifficultyLevel_drivingNormally = not storage_AICarValues.overrideOriginalAIDifficultyLevel_drivingNormally end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original difficulty level thats is set from the game launcher when the car is driving normally.') end

    local overrideOriginalAIDifficultyLevel_drivingNormally = storage_AICarValues.overrideOriginalAIDifficultyLevel_drivingNormally
    UIOperations_createDisabledSection(not overrideOriginalAIDifficultyLevel_drivingNormally, function()
        storage_AICarValues.defaultAIDifficultyLevel =  UIOperations_renderSlider('Difficulty Level while driving normally', 'The default difficulty level cars exhibit when driving on the default driving lane.\n\nThe higher this value is, the more effective the cars will be with the pedals and how fast they can handle corners.', storage_AICarValues.defaultAIDifficultyLevel, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.DefaultAIDifficultyLevel], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.DefaultAIDifficultyLevel], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.DefaultAIDifficultyLevel])
    end)

    if ui_checkbox('Override original Difficulty Level when overtaking', storage_AICarValues.overrideOriginalAIDifficultyLevel_overtaking) then storage_AICarValues.overrideOriginalAIDifficultyLevel_overtaking = not storage_AICarValues.overrideOriginalAIDifficultyLevel_overtaking end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original difficulty level thats is set from the game launcher when the car is overtaking another car.') end

    local overrideOriginalAIDifficultyLevel_overtaking = storage_AICarValues.overrideOriginalAIDifficultyLevel_overtaking
    UIOperations_createDisabledSection(not overrideOriginalAIDifficultyLevel_overtaking, function()
        storage_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront = UIOperations_renderSlider('Difficulty Level while overtaking (No obstacle in front)', 'The difficulty level used when overtaking another car if there is no obstacle in front of the overtaking car.\n\nThe higher this value is, the more effective the cars will be with the pedals and how fast they can handle corners while overtaking when there is no obstacle in front of them.', storage_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront])
        storage_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront = UIOperations_renderSlider('Difficulty Level while overtaking (Obstacle in front)', 'The difficulty level used when overtaking another car if there is an obstacle in front of the overtaking car.\n\nThe lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while overtaking when there is an obstacle in front of them.', storage_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront])
        storage_AICarValues.AIDifficultyLevel_WhileInCorner = UIOperations_renderSlider('Difficulty Level while overtaking in corner', 'The difficulty level used when overtaking another car while in a corner.\n\nThe lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while overtaking in corners.', storage_AICarValues.AIDifficultyLevel_WhileInCorner, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIDifficultyLevel_WhileInCorner], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIDifficultyLevel_WhileInCorner], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIDifficultyLevel_WhileInCorner])
    end)

    if ui_checkbox('Override original Difficulty Level when yielding', storage_AICarValues.overrideOriginalAIDifficultyLevel_yielding) then storage_AICarValues.overrideOriginalAIDifficultyLevel_yielding = not storage_AICarValues.overrideOriginalAIDifficultyLevel_yielding end
    if ui_itemHovered() then ui_setTooltip('If enabled, will override the original difficulty level thats is set from the game launcher when the car is yielding (giving way to faster cars).') end

    local overrideOriginalAIDifficultyLevel_yielding = storage_AICarValues.overrideOriginalAIDifficultyLevel_yielding
    UIOperations_createDisabledSection(not overrideOriginalAIDifficultyLevel_yielding, function()
        storage_AICarValues.AIDifficultyLevel_Yielding = UIOperations_renderSlider('Difficulty Level while yielding', 'The difficulty level used when yielding (giving way to faster cars).\n\nThe lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while yielding.', storage_AICarValues.AIDifficultyLevel_Yielding, StorageManager_options_AICarValues_min[StorageManager_Options_AICarValues.AIDifficultyLevel_Yielding], StorageManager_options_AICarValues_max[StorageManager_Options_AICarValues.AIDifficultyLevel_Yielding], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_AICarValues_default[StorageManager_Options_AICarValues.AIDifficultyLevel_Yielding])
    end)
    end)
    ui_columns(1, false)
end

local drawLateralOffsetsSection = function()
    ui_newLine(1)
    Section.section('Lateral Offsets (Driving Lanes)', function()
    ui_newLine(1)

    local wide = ui_availableSpaceX() >= 820
    ui_columns(wide and 2 or 1, false, "lateralsSection")
    if wide then ui_setColumnWidth(0, ui.windowWidth() * 0.46) end

    local handleYielding = storage_Yielding.handleYielding
    local handleOvertaking = storage_Overtaking.handleOvertaking

    local overtakingSide = RaceTrackManager_getOvertakingSide()
    UIOperations_createDisabledSection(not handleOvertaking, function()
        storage.overtakingLateralOffset =  UIOperations_renderSlider(translatedLabel(Localization.text('Overtaking Lateral Offset [-1..1] -> Overtaking side: %s', Localization.text(RaceTrackManager.TrackSideStrings[overtakingSide])), 'settings.offset.overtaking'), Localization.text('The lateral offset from the centerline that AI cars will drive to when overtaking another car.\n-1 = fully to the left\n0 = center of the track\n1 = fully to the right'), storage.overtakingLateralOffset, StorageManager_options_min[StorageManager_Options.OvertakingLateralOffset], StorageManager_options_max[StorageManager_Options.OvertakingLateralOffset], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_default[StorageManager_Options.OvertakingLateralOffset])
    end)

    storage.defaultLateralOffset =  UIOperations_renderSlider('Default Lateral Offset [-1..1]', 'The default lateral offset from the centerline that AI cars will try to maintain when not yielding or overtaking.\n-1 = fully to the left\n0 = center of the track (racing line)\n1 = fully to the right', storage.defaultLateralOffset, StorageManager_options_min[StorageManager_Options.DefaultLateralOffset], StorageManager_options_max[StorageManager_Options.DefaultLateralOffset], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_default[StorageManager_Options.DefaultLateralOffset])

    local yieldingSide = RaceTrackManager_getYieldingSide()
    UIOperations_createDisabledSection(not handleYielding, function()
        storage.yieldingLateralOffset =  UIOperations_renderSlider(translatedLabel(Localization.text('Yielding Lateral Offset [-1..1] -> Yielding side: %s', Localization.text(RaceTrackManager.TrackSideStrings[yieldingSide])), 'settings.offset.yielding'), Localization.text('The lateral offset from the centerline that AI cars will drive to when yielding (giving way to faster cars).\n-1 = fully to the left\n0 = center of the track\n1 = fully to the right'), storage.yieldingLateralOffset, StorageManager_options_min[StorageManager_Options.YieldingLateralOffset], StorageManager_options_max[StorageManager_Options.YieldingLateralOffset], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_default[StorageManager_Options.YieldingLateralOffset])
    end)

    -- ui.newLine(1)

    if yieldingSide == overtakingSide then
      ui_textColored('Warning: Yielding side and overtaking side are the same!', ColorManager.RGBM_Colors.Yellow)
    end

    if wide then ui_nextColumn() end

    UILateralOffsetsImageWidget_draw(storage)

    ui_columns(1, false)
    end)
end

local drawBehaviorSection = function()
    ui_newLine(1)
    Section.section('Behavior & Mode', function()
    ui_newLine(1)

    -- Profile dropdown
    -- Profile is inferred from persisted behavior values because it is not a
    -- declared ac.storage field.
    local profileIndex = SettingsModel.inferBehaviorProfile(storage_Behavior)

    local profileNames = {Localization.text('Casual'), Localization.text('Realistic'), Localization.text('Competitive')}
    local newProfileIndex, profileChanged = ui_combo(translatedLabel('AI Behavior Profile', 'behavior.profile'), profileIndex, ui.ComboFlags.None, profileNames)
    if profileChanged and newProfileIndex ~= profileIndex then
        profileIndex = newProfileIndex
        StorageManager_applyBehaviorProfile(profileIndex)
    end
    ui_newLine(0.5)
    if ui_itemHovered() then
        ui_setTooltip([[Choose the overall AI driving style:
  Casual      - Trackday only, instant reactions, no errors, no defense.
  Realistic   - Trackday/Hybrid, human timing, no errors, gradual blending.
  Competitive - Race mode, defend position, human errors (brake/traction), aggressive.]])
    end

    -- Mode display (read-only; shows what mode the profile activated)
    local modeNames = {[StorageManager_BehaviorMode.TrackDay] = "Track Day", [StorageManager_BehaviorMode.Race] = "Race", [StorageManager_BehaviorMode.HybridAdaptive] = "Hybrid (Auto)"}
    ui_text(Localization.text('Current Mode: %s', Localization.text(modeNames[storage_Behavior.mode] or 'Unknown')))
    ui_newLine(1)

    -- Advanced section with 14 sliders
    local isAdvancedOpen = UIState.advancedBehaviorOpen
    local checkboxLabel = translatedLabel(isAdvancedOpen and 'Hide Advanced Behavior Sliders' or 'Show Advanced Behavior Sliders', 'behavior.advanced.toggle')
    if ui_checkbox(checkboxLabel, isAdvancedOpen) then isAdvancedOpen = not isAdvancedOpen end
    UIState.advancedBehaviorOpen = isAdvancedOpen
    if ui_itemHovered() then ui_setTooltip('Granular sliders for the behavior polish values.\nMost users should pick a Profile above and leave these at defaults.') end

    if isAdvancedOpen then
        ui_newLine(1)

        storage_Behavior.entryBlendTime_s = UIOperations_renderSlider('Entry blend time', 'Time to fade in when entering a new state (yielding, overtaking, etc.).\nHigher = smoother transitions.', storage_Behavior.entryBlendTime_s, 0.0, 5.0, DEFAULT_SLIDER_WIDTH, '%.2f s', 1.5)
        storage_Behavior.exitBlendTime_s = UIOperations_renderSlider('Exit blend time', 'Time to fade out when leaving a state.', storage_Behavior.exitBlendTime_s, 0.0, 5.0, DEFAULT_SLIDER_WIDTH, '%.2f s', 2.0)
        storage_Behavior.aiReactionDelay_s = UIOperations_renderSlider('AI reaction delay', 'How long the AI waits before reacting to a situation.', storage_Behavior.aiReactionDelay_s, 0.0, 2.0, DEFAULT_SLIDER_WIDTH, '%.2f s', 0.4)
        storage_Behavior.aiReactionJitter_s = UIOperations_renderSlider('AI reaction jitter', 'Random extra delay added on top of reaction delay.', storage_Behavior.aiReactionJitter_s, 0.0, 1.0, DEFAULT_SLIDER_WIDTH, '%.2f s', 0.2)
        storage_Behavior.aiLookaheadWindow_s = UIOperations_renderSlider('AI lookahead window', 'How far ahead the AI looks to anticipate.', storage_Behavior.aiLookaheadWindow_s, 0.0, 10.0, DEFAULT_SLIDER_WIDTH, '%.2f s', 2.0)
        storage_Behavior.aiLookaheadConfidenceThreshold = UIOperations_renderSlider('Lookahead confidence threshold', 'Min confidence to act on lookahead.', storage_Behavior.aiLookaheadConfidenceThreshold, 0.0, 1.0, DEFAULT_SLIDER_WIDTH, '%.2f', 0.7)
        storage_Behavior.pointBySpeedDeltaKmh = UIOperations_renderSlider('Point-by speed delta (km/h)', 'How much faster (km/h) a car behind must be to yield.', storage_Behavior.pointBySpeedDeltaKmh, 0.0, 80.0, DEFAULT_SLIDER_WIDTH, '%.0f km/h', 15.0)
        storage_Behavior.defenseDurationMin_s = UIOperations_renderSlider('Defense duration min (s)', 'Minimum time defending position before yielding.', storage_Behavior.defenseDurationMin_s, 0.0, 10.0, DEFAULT_SLIDER_WIDTH, '%.1f s', 1.0)
        storage_Behavior.defenseDurationMax_s = UIOperations_renderSlider('Defense duration max (s)', 'Maximum time defending position before yielding.', storage_Behavior.defenseDurationMax_s, 0.0, 10.0, DEFAULT_SLIDER_WIDTH, '%.1f s', 3.0)
        storage_Behavior.overtakeAggressiveness = UIOperations_renderSlider('Overtake aggressiveness', 'How assertive AI is when space is marginal.', storage_Behavior.overtakeAggressiveness, 0.0, 1.0, DEFAULT_SLIDER_WIDTH, '%.2f', 0.5)
        storage_Behavior.humanErrorEnabled = UIOperations_renderSlider('Human errors enabled', 'Whether AI cars make realistic mistakes (lock-ups, traction loss).', storage_Behavior.humanErrorEnabled and 1 or 0, 0, 1, DEFAULT_SLIDER_WIDTH, '%.0f', 1) >= 0.5
        storage_Behavior.humanLockupProbability = UIOperations_renderSlider('Lock-up probability (per sec)', 'Chance per second of brake lock-up when braking hard.', storage_Behavior.humanLockupProbability, 0.0, 0.10, DEFAULT_SLIDER_WIDTH, '%.3f', 0.03)
        storage_Behavior.humanTractionMistakeProbability = UIOperations_renderSlider('Traction mistake prob (per sec)', 'Chance per second of traction loss on throttle.', storage_Behavior.humanTractionMistakeProbability, 0.0, 0.10, DEFAULT_SLIDER_WIDTH, '%.3f', 0.02)
        storage_Behavior.errorCooldown_s = UIOperations_renderSlider('Error cooldown (s)', 'Minimum time between human errors on the same car.', storage_Behavior.errorCooldown_s or 7.0, 0.0, 30.0, DEFAULT_SLIDER_WIDTH, '%.1f s', 7.0)
    end
    end)
end


SettingsWindow.draw = function()
    Style.windowBegin('settingsWindow')
    Logo.draw(42)

    ui_pushDWriteFont('Segoe UI')

    ui_textColored(Localization.text('SETTINGS  /  %s', StorageManager_getPerTrackPerModeStorageKey()), Theme.colors.muted)
    drawLanguageSelector()
    ui_newLine(1)

    -- Draw the Enabled checkbox
    local appEnabled = storage.enabled
    local enabledCheckBoxColor = appEnabled and Theme.colors.accent or Theme.colors.muted
    ui_pushStyleColor(ui_StyleColor.Text, enabledCheckBoxColor)
    local enabledDisabledText = appEnabled and 'Enabled' or 'Disabled'
    local enabledLabel = Localization.text('SimOpenTrackDay %s for: %s (Mode: %s)', Localization.text(enabledDisabledText), RaceTrackManager_getTrackName(), Localization.text(RaceTrackManager_getSessionTypeName()))
    if ui_checkbox(translatedLabel(enabledLabel, 'settings.app.enabled'), appEnabled) then storage.enabled = not storage.enabled end
    ui_popStyleColor(1)
    if ui_itemHovered() then ui_setTooltip('Enable the SimOpenTrackDay app for this specific track and session mode.\n\nEach track and session mode type use individually saved settings.') end

    ui_newLine(1)

    -- start the global app-enabled disabled section if the app is disabled
    if not appEnabled then
        ui_pushDisabled()
    end

    -- if ui.checkbox('Draw markers on top (no depth test)', storage.drawOnTop) then storage.drawOnTop = not storage.drawOnTop end
    -- if ui.itemHovered() then ui.setTooltip('If markers are hidden by car bodywork, enable this so text ignores depth testing.') end

    -- local comboValueChanged
    -- storage.yieldSide, comboValueChanged = ui.combo('Yielding Side', storage.yieldSide, ui.ComboFlags.NoPreview, RaceTrackManager.TrackSideStrings)
    -- if ui.itemHovered() then ui.setTooltip('The track side which AI will yield to when you approach from the rear.') end

    drawLateralOffsetsSection()

    ui_newLine(1)
    ui_separator()

    drawAICarValuesSection()

    -- storage.maxLateralOffset_normalized =  ui.slider('Max Side offset', storage.maxLateralOffset_normalized, StorageManager_options_min[StorageManager_Options.MaxLateralOffset_normalized], StorageManager_options_max[StorageManager_Options.MaxLateralOffset_normalized])
    -- if ui.itemHovered() then ui.setTooltip('How far to move towards the chosen side when yielding/overtaking(0.1 barely moving to the side, 1.0 moving as much as possible to the side).') end

    ui_newLine(1)
    ui_separator()

    drawBehaviorSection()

    ui_newLine(1)
    ui_separator()

    -- Create the Yielding and Overtaking table with 2 columns
    local splitBehavior = ui_availableSpaceX() >= 960
    ui_columns(splitBehavior and 2 or 1, true, "yieldingOvertakingSection")
    if splitBehavior then ui_setColumnWidth(0, ui.windowWidth() * 0.46) end
    --ui.setColumnWidth(1, 260)

    local handleYielding = storage_Yielding.handleYielding
    local handleOvertaking = storage_Overtaking.handleOvertaking

    Section.section('Yielding', function()
    ui_newLine(1)

    local handleYieldingCheckboxColor = handleYielding and Theme.colors.accent or Theme.colors.muted
    ui_pushStyleColor(ui_StyleColor.Text, handleYieldingCheckboxColor)
    if ui_checkbox('Handle Yielding', storage_Yielding.handleYielding) then storage_Yielding.handleYielding = not storage_Yielding.handleYielding end
    ui_popStyleColor(1)
    if ui_itemHovered() then ui_setTooltip('If enabled, AI cars will attempt to yield to the specified Yielding Lateral Offset side of the track') end

    UIOperations_createDisabledSection(not handleYielding, function()
        if ui_checkbox('Check sides while yielding', storage_Yielding.handleSideCheckingWhenYielding) then storage_Yielding.handleSideCheckingWhenYielding = not storage_Yielding.handleSideCheckingWhenYielding end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will check for other cars on the side when yielding so they don't crash into them.") end

        if ui_checkbox('Require overtaking car to be on overtaking lane to yield', storage_Yielding.requireOvertakingCarToBeOnOvertakingLane) then storage_Yielding.requireOvertakingCarToBeOnOvertakingLane = not storage_Yielding.requireOvertakingCarToBeOnOvertakingLane end
        if ui_itemHovered() then ui_setTooltip("If enabled, the yielding car will only yield if the overtaking car is actually driving on the overtaking lane.") end

        ui_newLine(1)

        if ui_checkbox('Use indicator lights when easing in yield', storage_Yielding.UseIndicatorLightsWhenEasingInYield) then storage_Yielding.UseIndicatorLightsWhenEasingInYield = not storage_Yielding.UseIndicatorLightsWhenEasingInYield end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will use their indicator lights while driving to the reach the yielding lane.") end

        if ui_checkbox('Use indicator lights when easing out of yield', storage_Yielding.UseIndicatorLightsWhenEasingOutYield) then storage_Yielding.UseIndicatorLightsWhenEasingOutYield = not storage_Yielding.UseIndicatorLightsWhenEasingOutYield end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will use their indicator lights while driving from the yielding lane back to the default driving lane.") end

        if ui_checkbox('Use indicator lights when driving on yielding lane', storage_Yielding.UseIndicatorLightsWhenDrivingOnYieldingLane) then storage_Yielding.UseIndicatorLightsWhenDrivingOnYieldingLane = not storage_Yielding.UseIndicatorLightsWhenDrivingOnYieldingLane end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will keep their indicator lights on while driving on the yielding lane.") end

        ui_newLine(1)

        storage_Yielding.detectCarBehind_meters =  UIOperations_renderSlider('Detect car behind distance', 'Start yielding if the overtaking car behind is within this distance', storage_Yielding.detectCarBehind_meters, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.DetectCarBehind_meters], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.DetectCarBehind_meters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_Yielding_default[StorageManager_Options_Yielding.DetectCarBehind_meters])

        storage_Yielding.rampSpeed_mps =  UIOperations_renderSlider('Yielding Lateral Offset increment step', 'How quickly the lateral offset ramps up when yielding to an overtaking car.\nThe higher it is, the more quickly cars will change lanes when moving to the yielding side.', storage_Yielding.rampSpeed_mps, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.RampSpeed_mps], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.RampSpeed_mps], DEFAULT_SLIDER_WIDTH, '%.2f m/s', StorageManager_options_Yielding_default[StorageManager_Options_Yielding.RampSpeed_mps])

        storage_Yielding.rampRelease_mps =  UIOperations_renderSlider('Yielding Lateral Offset decrement step', 'How quickly the lateral offset returns to normal once an overtaking car has fully driven past the yielding car.\nThe higher it is, the more quickly cars will change lanes moving back to the default lateral offset after finishing yielding.', storage_Yielding.rampRelease_mps, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.RampRelease_mps], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.RampRelease_mps], DEFAULT_SLIDER_WIDTH, '%.2f m/s', StorageManager_options_Yielding_default[StorageManager_Options_Yielding.RampRelease_mps])

        ui_newLine(1)

        storage_Yielding.speedLimitValueToOvertakingCar = UIOperations_renderSlider('Top speed limit value to overtaking car [0..1]', "When yielding, the yielding car's top speed will be limited to this fraction of the overtaking car's current speed to let it pass more easily.\n1.0 = no top speed limiting\n0.5 = limit top speed to half the current speed of the overtaking car.\n0.0 = make the car grind to a halt", storage_Yielding.speedLimitValueToOvertakingCar, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.SpeedLimitValueToOvertakingCar], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.SpeedLimitValueToOvertakingCar], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_Yielding_default[StorageManager_Options_Yielding.SpeedLimitValueToOvertakingCar])
        local speedLimitValueToOvertakingCar  = storage_Yielding.speedLimitValueToOvertakingCar
        UIOperations_createDisabledSection(speedLimitValueToOvertakingCar >= 1.0, function()
            storage_Yielding.minimumSpeedLimitKmhToLimitToOvertakingCar = UIOperations_renderSlider('Minimum top speed to limit to overtaking car', "When yielding, the yielding car's top speed will not be limited below this speed even if the overtaking car is very slow.\n0.0 = no minimum top speed limit while yielding", storage_Yielding.minimumSpeedLimitKmhToLimitToOvertakingCar, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.MinimumSpeedLimitKmhToLimitToOvertakingCar], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.MinimumSpeedLimitKmhToLimitToOvertakingCar], DEFAULT_SLIDER_WIDTH, '%.2f km/h', StorageManager_options_Yielding_default[StorageManager_Options_Yielding.MinimumSpeedLimitKmhToLimitToOvertakingCar])

        end)

        storage_Yielding.throttlePedalLimitWhenYieldingToOvertakingCar = UIOperations_renderSlider('Throttle pedal limit when yielding to overtaking car [0..1]', "When yielding, the yielding car's throttle pedal input will be limited to this fraction to let the overtaking car pass more easily.\n1.0 = no throttle pedal limiting\n0.5 = limit throttle pedal input to half\n0.0 = completely let go of the throttle pedal", storage_Yielding.throttlePedalLimitWhenYieldingToOvertakingCar, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.ThrottlePedalLimitWhenYieldingToOvertakingCar], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.ThrottlePedalLimitWhenYieldingToOvertakingCar], DEFAULT_SLIDER_WIDTH, DEFAULT_SLIDER_FORMAT, StorageManager_options_Yielding_default[StorageManager_Options_Yielding.ThrottlePedalLimitWhenYieldingToOvertakingCar])

        local anySpeedLimitingWhileYieldingApplied = 
            speedLimitValueToOvertakingCar < 1.0 or 
            storage_Yielding.throttlePedalLimitWhenYieldingToOvertakingCar < 1.0

        UIOperations_createDisabledSection(not anySpeedLimitingWhileYieldingApplied, function()
            storage_Yielding.distanceToOvertakingCarToLimitSpeed = UIOperations_renderSlider('Distance to overtaking car to apply speed limiting', 'When yielding, if an overtaking car is within this distance behind us, we will limit our speed to let it pass more easily.', storage_Yielding.distanceToOvertakingCarToLimitSpeed, StorageManager_options_Yielding_min[StorageManager_Options_Yielding.DistanceToOvertakingCarToLimitSpeed], StorageManager_options_Yielding_max[StorageManager_Options_Yielding.DistanceToOvertakingCarToLimitSpeed], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_Yielding_default[StorageManager_Options_Yielding.DistanceToOvertakingCarToLimitSpeed])
        end)
    end)
    end)
    if splitBehavior then ui_nextColumn() end

    Section.section('Overtaking', function()
    ui_newLine(1)

    local handleOvertakingCheckboxColor = handleOvertaking and Theme.colors.accent or Theme.colors.muted
    ui_pushStyleColor(ui_StyleColor.Text, handleOvertakingCheckboxColor)
    if ui_checkbox('Handle Overtaking', storage_Overtaking.handleOvertaking) then storage_Overtaking.handleOvertaking = not storage_Overtaking.handleOvertaking end
    ui_popStyleColor(1)
    if ui_itemHovered() then ui_setTooltip('If enabled, AI cars will attempt to overtake to the specified Overtaking Lateral Offset side of the track') end
    
    UIOperations_createDisabledSection(not handleOvertaking, function()
        if ui_checkbox('Check sides while overtaking', storage_Overtaking.handleSideCheckingWhenOvertaking) then storage_Overtaking.handleSideCheckingWhenOvertaking = not storage_Overtaking.handleSideCheckingWhenOvertaking end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will check for other cars on the side when overtaking so they don't crash into them.") end

        if ui_checkbox('Require yielding car to be on yielding lane to overtake', storage_Overtaking.requireYieldingCarToBeOnYieldingLane) then storage_Overtaking.requireYieldingCarToBeOnYieldingLane = not storage_Overtaking.requireYieldingCarToBeOnYieldingLane end
        if ui_itemHovered() then ui_setTooltip("If enabled, the overtaking car will only overtake if the yielding car is actually driving on the yielding lane.") end

        ui_newLine(1)

        if ui_checkbox('Use indicator lights when easing in to overtake', storage_Overtaking.UseIndicatorLightsWhenEasingInOvertaking) then storage_Overtaking.UseIndicatorLightsWhenEasingInOvertaking = not storage_Overtaking.UseIndicatorLightsWhenEasingInOvertaking end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will use their indicator lights when driving to the overtaking lane.") end

        if ui_checkbox('Use indicator lights when easing out of overtaking', storage_Overtaking.UseIndicatorLightsWhenEasingOutOvertaking) then storage_Overtaking.UseIndicatorLightsWhenEasingOutOvertaking = not storage_Overtaking.UseIndicatorLightsWhenEasingOutOvertaking end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will use their indicator lights when driving from the overtaking lane back to the default driving lane.") end

        if ui_checkbox('Use indicator lights when driving on overtaking lane', storage_Overtaking.UseIndicatorLightsWhenDrivingOnOvertakingLane) then storage_Overtaking.UseIndicatorLightsWhenDrivingOnOvertakingLane = not storage_Overtaking.UseIndicatorLightsWhenDrivingOnOvertakingLane end
        if ui_itemHovered() then ui_setTooltip("If enabled, cars will keep their indicator lights on while driving on the overtaking lane.") end

        ui_newLine(1)

        storage_Overtaking.detectCarAhead_meters =  UIOperations_renderSlider('Detect car ahead distance', 'Start overtaking if the car in front is within this distance', storage_Overtaking.detectCarAhead_meters, StorageManager_options_Overtaking_min[StorageManager_Options_Overtaking.DetectCarAhead_meters], StorageManager_options_Overtaking_max[StorageManager_Options_Overtaking.DetectCarAhead_meters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_Overtaking_default[StorageManager_Options_Overtaking.DetectCarAhead_meters])

        storage_Overtaking.overtakeRampSpeed_mps =  UIOperations_renderSlider('Overtaking Lateral Offset increment step', 'How quickly the lateral offset ramps up when overtaking another car.\nThe higher it is, the more quickly cars will change lanes when moving to the overtaking side', storage_Overtaking.overtakeRampSpeed_mps, StorageManager_options_Overtaking_min[StorageManager_Options_Overtaking.OvertakeRampSpeed_mps], StorageManager_options_Overtaking_max[StorageManager_Options_Overtaking.OvertakeRampSpeed_mps], DEFAULT_SLIDER_WIDTH, '%.3f m/s', StorageManager_options_Overtaking_default[StorageManager_Options_Overtaking.OvertakeRampSpeed_mps])

        storage_Overtaking.overtakeRampRelease_mps =  UIOperations_renderSlider('Overtaking Lateral Offset decrement step', 'How quickly the lateral offset returns to normal once an overtaking car has fully driven past the overtaken car.\nThe higher it is, the more quickly cars will change lanes moving back to the default lateral offset after finishing overtaking.', storage_Overtaking.overtakeRampRelease_mps, StorageManager_options_Overtaking_min[StorageManager_Options_Overtaking.OvertakeRampRelease_mps], StorageManager_options_Overtaking_max[StorageManager_Options_Overtaking.OvertakeRampRelease_mps], DEFAULT_SLIDER_WIDTH, '%.3f m/s', StorageManager_options_Overtaking_default[StorageManager_Options_Overtaking.OvertakeRampRelease_mps])
    end)
    end)

    -- finish two columns
    ui_columns(1, false)

    ui_newLine(1)
    ui_separator()

    UIOperations_createDisabledSection(not Constants.ENABLE_ACCIDENT_HANDLING_IN_APP, function()
        local pathWide = ui_availableSpaceX() >= 820
        ui_columns(pathWide and 2 or 1, true, "accidentsSection")
        if pathWide then ui_setColumnWidth(0, ui.windowWidth() * 0.46) end

        Section.section('Accidents', function()
        ui_newLine(1)

        if ui_checkbox('Handle accidents (WORK IN PROGRESS - BEST NOT USED FOR NOW)', storage.handleAccidents) then storage.handleAccidents = not storage.handleAccidents end
        if ui_itemHovered() then ui_setTooltip('If enabled, AI will stop and remain stopped after an accident until the other cars pass.') end

        local handleAccidents = storage.handleAccidents
        UIOperations_createDisabledSection(not handleAccidents, function()
            storage.distanceFromAccidentToSeeYellowFlag_meters =  UIOperations_renderSlider('Distance from accident to see yellow flag (m)', 'Distance from accident at which AI will see the yellow flag and start slowing down.', storage.distanceFromAccidentToSeeYellowFlag_meters, 50, 500, DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_default[StorageManager_Options.DistanceFromAccidentToSeeYellowFlag_meters])

            storage.distanceToStartNavigatingAroundCarInAccident_meters =  UIOperations_renderSlider('Distance to start navigating around car in accident (m)', 'Distance from accident at which AI will start navigating around the car in accident.', storage.distanceToStartNavigatingAroundCarInAccident_meters, 5, 100, DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_default[StorageManager_Options.DistanceToStartNavigatingAroundCarInAccident_meters])
        end)
        end)

    if pathWide then ui_nextColumn() end

        Section.section('Pathfinding', function()
        ui_newLine(1)

        storage_PathFinding.forwardDistanceMeters =  UIOperations_renderSlider('Forward distance', 'The distance ahead of the car that the pathfinding system will consider when calculating paths around obstacles.', storage_PathFinding.forwardDistanceMeters, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.ForwardDistanceMeters], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.ForwardDistanceMeters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.ForwardDistanceMeters])
        storage_PathFinding.anchorAheadMeters = UIOperations_renderSlider('Anchor ahead distance', 'The distance ahead of the car where the pathfinding system will place an anchor point to help guide the car around obstacles.', storage_PathFinding.anchorAheadMeters, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.AnchorAheadMeters], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.AnchorAheadMeters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.AnchorAheadMeters])
        storage_PathFinding.numberOfPathSamples = UIOperations_renderSlider('Number of path samples', 'The number of path samples the pathfinding system will use to evaluate possible paths around obstacles.', storage_PathFinding.numberOfPathSamples, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.NumberOfPathSamples], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.NumberOfPathSamples], DEFAULT_SLIDER_WIDTH, '%.0f', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.NumberOfPathSamples])
        storage_PathFinding.maxAbsOffsetNormalized = UIOperations_renderSlider('Max absolute offset normalized', 'The maximum absolute lateral offset (normalized) that the pathfinding system will allow when calculating paths around obstacles.', storage_PathFinding.maxAbsOffsetNormalized, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.MaxAbsOffsetNormalized], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.MaxAbsOffsetNormalized], DEFAULT_SLIDER_WIDTH, '%.2f', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.MaxAbsOffsetNormalized])
        storage_PathFinding.splitReachMeters = UIOperations_renderSlider('Split reach distance', 'The distance at which the pathfinding system will split its path calculations to explore different routes around obstacles.', storage_PathFinding.splitReachMeters, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.SplitReachMeters], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.SplitReachMeters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.SplitReachMeters])
        storage_PathFinding.lateralSplitExponent = UIOperations_renderSlider('Lateral split exponent', 'The exponent used to weight lateral splits in the pathfinding calculations.', storage_PathFinding.lateralSplitExponent, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.LateralSplitExponent], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.LateralSplitExponent], DEFAULT_SLIDER_WIDTH, '%.2f', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.LateralSplitExponent])
        storage_PathFinding.approxCarRadiusMeters = UIOperations_renderSlider('Approx car radius', 'The approximate radius of the car used by the pathfinding system for collision avoidance.', storage_PathFinding.approxCarRadiusMeters, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.ApproxCarRadiusMeters], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.ApproxCarRadiusMeters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.ApproxCarRadiusMeters])
        storage_PathFinding.safetyMarginMeters = UIOperations_renderSlider('Safety margin', 'The safety margin added around obstacles by the pathfinding system to prevent collisions.', storage_PathFinding.safetyMarginMeters, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.SafetyMarginMeters], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.SafetyMarginMeters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.SafetyMarginMeters])
        storage_PathFinding.timeToLeavePathBlockedAfterSampleHitSeconds = UIOperations_renderSlider('Time to leave path blocked after sample hit', 'The time the pathfinding system will leave a path marked as blocked after a sample in the path was hit during a collision check.', storage_PathFinding.timeToLeavePathBlockedAfterSampleHitSeconds, StorageManager_options_PathFinding_min[StorageManager_Options_PathFinding.TimeToLeavePathBlockedAfterSampleHitSeconds], StorageManager_options_PathFinding_max[StorageManager_Options_PathFinding.TimeToLeavePathBlockedAfterSampleHitSeconds], DEFAULT_SLIDER_WIDTH, '%.2f seconds', StorageManager_options_PathFinding_default[StorageManager_Options_PathFinding.TimeToLeavePathBlockedAfterSampleHitSeconds])


        -- finish two columns
        ui_columns(1, false)
        end)
    end)


    ui_newLine(1)
    ui_separator()

    Section.section('Other', function()
    ui_newLine(1)

    if ui_checkbox('Override AI awareness', storage.overrideAiAwareness) then storage.overrideAiAwareness = not storage.overrideAiAwareness end
    if ui_itemHovered() then ui_setTooltip('If enabled, our computed lateral offset will override the value from Kunos, otherwise our computed lateral offset adds to it. (EXPERIMENTAL)') end

    storage.globalTopSpeedLimitKmh = UIOperations_renderSlider('Global top speed limit', 'A global top speed limit applied to all AI cars.\n0  = no global top speed limit.', storage.globalTopSpeedLimitKmh, StorageManager_options_min[StorageManager_Options.GlobalTopSpeedLimitKmh], StorageManager_options_max[StorageManager_Options.GlobalTopSpeedLimitKmh], DEFAULT_SLIDER_WIDTH, '%.2f km/h', StorageManager_options_default[StorageManager_Options.GlobalTopSpeedLimitKmh])

    storage.clearAhead_meters = UIOperations_renderSlider('The distance which determines whether a car is far enough ahead of another car', 'When checking if a car is clear ahead of another car, this is the distance used to determine if it is clear.', storage.clearAhead_meters, StorageManager_options_min[StorageManager_Options.ClearAhead_meters], StorageManager_options_max[StorageManager_Options.ClearAhead_meters], DEFAULT_SLIDER_WIDTH, '%.2f m', StorageManager_options_default[StorageManager_Options.ClearAhead_meters])

    storage.deferTimeAfterSessionStart = UIOperations_renderSlider('Defer yielding/overtaking for a while after session start', "The time after the session starts during which no yielding or overtaking will be performed by AI cars.\n\nUsually only applicable for race scenarios where you don't want the cars to try and yield immediately after start because it creates chaos.", storage.deferTimeAfterSessionStart, StorageManager_options_min[StorageManager_Options.DeferTimeAfterSessionStart], StorageManager_options_max[StorageManager_Options.DeferTimeAfterSessionStart], DEFAULT_SLIDER_WIDTH, '%.2f seconds', StorageManager_options_default[StorageManager_Options.DeferTimeAfterSessionStart])
    end)
    ui_separator()


--[===[
    ui.separator()

    ui.text('Custom AI Flood')

    if ui.checkbox('Custom AI Flood Enabled', storage.customAIFlood_enabled) then storage.customAIFlood_enabled = not storage.customAIFlood_enabled end
    if ui.itemHovered() then ui.setTooltip('Master switch for the custom AI flood feature.') end

    storage.customAIFlood_distanceBehindPlayerToCycle_meters = ui.slider('Distance behind player to cycle (m)', storage.customAIFlood_distanceBehindPlayerToCycle_meters, 0, 500)
    if ui.itemHovered() then ui.setTooltip('Distance behind the player car at which AI cars will start to cycle.') end

    storage.customAIFlood_distanceAheadOfPlayerToCycle_meters = ui.slider('Distance ahead of player to cycle (m)', storage.customAIFlood_distanceAheadOfPlayerToCycle_meters, 0, 500)
    if ui.itemHovered() then ui.setTooltip('Distance ahead of the player car at which AI cars will start to cycle.') end

    -- storage.distanceToFrontCarToOvertake =  ui.slider('Min distance to front car to overtake (m)', storage.distanceToFrontCarToOvertake, 1.0, 20.0)
    -- if ui.itemHovered() then ui.setTooltip('Minimum distance to the car in front before an AI car will consider overtaking it.') end
--]===]

    -- Draw the app name and version at the bottom-right of the settings window
    UIAppNameVersionWidget_drawBottomRight(12)

    ui_popDWriteFont()

    -- Close the global app-enabled disabled section if the app is disabled
    if not appEnabled then
        ui_popDisabled()
    end
    Style.windowEnd()
end

--[===[
local settingsWindow = ui.addSettings({
  icon = ui.Icons.Settings,
  name = 'Realistic Trackday Settings',
  id = 'rt_settings',                                    -- your stable ID
  size = {
    default = vec2(800, 620),                            -- initial size
    min     = vec2(600, 420),                            -- smallest allowed
    max     = vec2(2000, 1400),                          -- largest allowed
    automatic = false                                    -- don’t autosize content
  },
  category = 'settings'
}, function()
  SettingsWindow.draw()
end)
settingsWindow('open') 
-- ]===]

-- ac.setWindowOpen('mainWindow', true) 
-- ac.setWindowOpen('settingsWindow', true)

return SettingsWindow
