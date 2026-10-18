Constants = require("Constants")
Logger = require("Logger")
CSPCompatibilityManager = require("lib.AssettoCorsaCSPLuaCompatibilityManager.CSPCompatibilityManager")

CSPCompatibilityManager.addFunction(function() return ac.log end, "ac.log")
CSPCompatibilityManager.addFunction(function() return ac.warn end, "ac.warn")
CSPCompatibilityManager.addFunction(function() return ac.error end, "ac.error")
CSPCompatibilityManager.addFunction(function() return ac.getSim end, "ac.getSim")
CSPCompatibilityManager.addFunction(function() return ac.getCar end, "ac.getCar")
CSPCompatibilityManager.addFunction(function() return ac.onCarJumped end, "ac.onCarJumped")
CSPCompatibilityManager.addFunction(function() return ac.onCarCollision end, "ac.onCarCollision")
CSPCompatibilityManager.addFunction(function() return ac.iterateCars end, "ac.iterateCars")
CSPCompatibilityManager.addFunction(function() return ac.setTargetCar end, "ac.setTargetCar")
CSPCompatibilityManager.addFunction(function() return ac.setTurningLights end, "ac.setTurningLights")
CSPCompatibilityManager.addFunction(function() return ac.worldCoordinateToTrack end, "ac.worldCoordinateToTrack")
CSPCompatibilityManager.addFunction(function() return ac.worldCoordinateToTrackProgress end, "ac.worldCoordinateToTrackProgress")
CSPCompatibilityManager.addFunction(function() return ac.trackProgressToWorldCoordinate end, "ac.trackProgressToWorldCoordinate")
CSPCompatibilityManager.addFunction(function() return ac.getTrackUpcomingTurn end, "ac.getTrackUpcomingTurn")
CSPCompatibilityManager.addFunction(function() return ac.overrideCarControls end, "ac.overrideCarControls")
CSPCompatibilityManager.addFunction(function() return ac.hasTrackSpline end, "ac.hasTrackSplines")
CSPCompatibilityManager.addFunction(function() return ac.getTrackFullID end, "ac.getTrackFullID")
CSPCompatibilityManager.addFunction(function() return ac.storage end, "ac.storage")
CSPCompatibilityManager.addFunction(function() return ac.focusCar end, "ac.focusCar")
CSPCompatibilityManager.addFunction(function() return ac.setCurrentCamera end, "ac.setCurrentCamera")
CSPCompatibilityManager.addFunction(function() return ac.setCurrentDrivableCamera end, "ac.setCurrentDrivableCamera")
CSPCompatibilityManager.addFunction(function() return ac.getCarMaxSpeedWithGear end, "ac.getCarMaxSpeedWithGear")

CSPCompatibilityManager.addFunction(function() return ui.button end, "ui.button")
CSPCompatibilityManager.addFunction(function() return ui.newLine end, "ui.newLine")
CSPCompatibilityManager.addFunction(function() return ui.text end, "ui.text")
CSPCompatibilityManager.addFunction(function() return ui.drawRect end, "ui.drawRect")
CSPCompatibilityManager.addFunction(function() return ui.drawRectFilled end, "ui.drawRectFilled")
CSPCompatibilityManager.addFunction(function() return ui.availableSpaceY end, "ui.availableSpaceY")
CSPCompatibilityManager.addFunction(function() return ui.beginGroup end, "ui.beginGroup")
CSPCompatibilityManager.addFunction(function() return ui.endGroup end, "ui.endGroup")
CSPCompatibilityManager.addFunction(function() return ui.dummy end, "ui.dummy")
CSPCompatibilityManager.addFunction(function() return ui.drawLine end, "ui.drawLine")
CSPCompatibilityManager.addFunction(function() return ui.getCursor end, "ui.getCursor")
CSPCompatibilityManager.addFunction(function() return ui.drawTextClipped end, "ui.drawTextClipped")
CSPCompatibilityManager.addFunction(function() return ui.dwriteDrawText end, "ui.dwriteDrawText")
CSPCompatibilityManager.addFunction(function() return ui.invisibleButton end, "ui.invisibleButton")
CSPCompatibilityManager.addFunction(function() return ui.pushItemWidth end, "ui.pushItemWidth")
CSPCompatibilityManager.addFunction(function() return ui.popItemWidth end, "ui.popItemWidth")
CSPCompatibilityManager.addFunction(function() return ui.itemHovered end, "ui.itemHovered")
CSPCompatibilityManager.addFunction(function() return ui.setTooltip end, "ui.setTooltip")
CSPCompatibilityManager.addFunction(function() return ui.pushDisabled end, "ui.pushDisabled")
CSPCompatibilityManager.addFunction(function() return ui.popDisabled end, "ui.popDisabled")
CSPCompatibilityManager.addFunction(function() return ui.columns end, "ui.columns")
CSPCompatibilityManager.addFunction(function() return ui.ButtonFlags end, "ui.buttonFlags")
CSPCompatibilityManager.addFunction(function() return ui.windowSize end, "ui.windowSize")
CSPCompatibilityManager.addFunction(function() return ui.drawImage end, "ui.drawImage")
CSPCompatibilityManager.addFunction(function() return ui.pushDWriteFont end, "ui.pushDWriteFont")
CSPCompatibilityManager.addFunction(function() return ui.pushStyleColor end, "ui.pushStyleColor")
CSPCompatibilityManager.addFunction(function() return ui.popStyleColor end, "ui.popStyleColor")
CSPCompatibilityManager.addFunction(function() return ui.styleColor end, "ui.styleColor")
CSPCompatibilityManager.addFunction(function() return ui.StyleColor end, "ui.StyleColor")
CSPCompatibilityManager.addFunction(function() return ui.combo end, "ui.combo")
CSPCompatibilityManager.addFunction(function() return ui.ComboFlags end, "ui.ComboFlags")
CSPCompatibilityManager.addFunction(function() return ui.textColored end, "ui.textColored")
CSPCompatibilityManager.addFunction(function() return ui.setColumnWidth end, "ui.setColumnWidth")
CSPCompatibilityManager.addFunction(function() return ui.popDWriteFont end, "ui.popDWriteFont")
CSPCompatibilityManager.addFunction(function() return ui.separator end, "ui.separator")
CSPCompatibilityManager.addFunction(function() return ui.setCursor end, "ui.setCursor")
CSPCompatibilityManager.addFunction(function() return ui.measureDWriteText end, "ui.measureDWriteText")
CSPCompatibilityManager.addFunction(function() return ui.nextColumn end, "ui.nextColumn")
CSPCompatibilityManager.addFunction(function() return ui.itemRectMin end, "ui.itemRectMin")
CSPCompatibilityManager.addFunction(function() return ui.itemRectMax end, "ui.itemRectMax")
CSPCompatibilityManager.addFunction(function() return ui.textLineHeightWithSpacing end, "ui.textLineHeightWithSpacing")
CSPCompatibilityManager.addFunction(function() return ui.cursorScreenPos end, "ui.cursorScreenPos")
CSPCompatibilityManager.addFunction(function() return ui.setItemAllowOverlap end, "ui.setItemAllowOverlap")
CSPCompatibilityManager.addFunction(function() return ui.setCursorScreenPos end, "ui.setCursorScreenPos")
CSPCompatibilityManager.addFunction(function() return ui.windowPos end, "ui.windowPos")
CSPCompatibilityManager.addFunction(function() return ui.windowWidth end, "ui.windowWidth")
CSPCompatibilityManager.addFunction(function() return ui.columnSortingHeader end, "ui.columnSortingHeader")
CSPCompatibilityManager.addFunction(function() return ui.pushColumnsBackground end, "ui.pushColumnsBackground")
CSPCompatibilityManager.addFunction(function() return ui.popColumnsBackground end, "ui.popColumnsBackground")
CSPCompatibilityManager.addFunction(function() return ui.pushID end, "ui.pushID")
CSPCompatibilityManager.addFunction(function() return ui.popID end, "ui.popID")
CSPCompatibilityManager.addFunction(function() return ui.selectable end, "ui.selectable")
CSPCompatibilityManager.addFunction(function() return ui.itemClicked end, "ui.itemClicked")
CSPCompatibilityManager.addFunction(function() return ui.sameLine end, "ui.sameLine")
CSPCompatibilityManager.addFunction(function() return ui.getScrollMaxY end, "ui.getScrollMaxY")
CSPCompatibilityManager.addFunction(function() return ui.getScrollX end, "ui.getScrollX")
CSPCompatibilityManager.addFunction(function() return ui.getScrollY end, "ui.getScrollY")
CSPCompatibilityManager.addFunction(function() return ui.slider end, "ui.slider")
CSPCompatibilityManager.addFunction(function() return ui.dwriteText end, "ui.dwriteText")
CSPCompatibilityManager.addFunction(function() return ui.checkbox end, "ui.checkbox")
CSPCompatibilityManager.addFunction(function() return ui.MouseButton end, "ui.MouseButton")
CSPCompatibilityManager.addFunction(function() return ui.mouseClicked end, "ui.mouseClicked")
CSPCompatibilityManager.addFunction(function() return ui.availableSpaceX end, "ui.availableSpaceX")

CSPCompatibilityManager.addFunction(function() return physics.overrideRacingFlag end, "physics.overrideRacingFlag")
CSPCompatibilityManager.addFunction(function() return physics.setAIThrottleLimit end, "physics.setAIThrottleLimit")
CSPCompatibilityManager.addFunction(function() return physics.setAITopSpeed end, "physics.setAITopSpeed")
CSPCompatibilityManager.addFunction(function() return physics.setAICaution end, "physics.setAICaution")
CSPCompatibilityManager.addFunction(function() return physics.setAIAggression end, "physics.setAIAggression")
CSPCompatibilityManager.addFunction(function() return physics.setAIBrakeMistake end, "physics.setAIBrakeMistake")
CSPCompatibilityManager.addFunction(function() return physics.setAITractionMistake end, "physics.setAITractionMistake")
CSPCompatibilityManager.addFunction(function() return physics.setAIStopCounter end, "physics.setAIStopCounter")
CSPCompatibilityManager.addFunction(function() return physics.setExtraAIGrip end, "physics.setExtraAIGrip")
CSPCompatibilityManager.addFunction(function() return physics.disableCarCollisions end, "physics.disableCarCollisions")
CSPCompatibilityManager.addFunction(function() return physics.setGentleStop end, "physics.setGentleStop")
CSPCompatibilityManager.addFunction(function() return physics.preventAIFromRetiring end, "physics.preventAIFromRetiring")
CSPCompatibilityManager.addFunction(function() return physics.setAISplineOffset end, "physics.setAISplineOffset")
CSPCompatibilityManager.addFunction(function() return physics.overrideRacingFlag end, "physics.overrideRacingFlag")

CSPCompatibilityManager.addSimStateFunction(function(sim) return sim.trackLengthM end, "ac.getSim().trackLengthM")
CSPCompatibilityManager.addSimStateFunction(function(sim) return sim.raceSessionType end, "ac.getSim().raceSessionType")

CSPCompatibilityManager.addFunction(function() return physics.overrideRacingFlag end, "physics.overrideRacingFlag")
CSPCompatibilityManager.addFunction(function() return ui.dwriteText end, "ui.dwriteText")

CSPCompatibilityManager.ErrorModalDialogTextColor = rgbm(0.961, 0.914, 0.132, 0.75)

-- The modal dialog must NOT be shown during script load: `ui.modalDialog` is a draw-phase
-- primitive and calling it before the window draw callbacks are wired aborts the chunk,
-- leaving the manifest-declared windows as empty/gray overlays. We disable the auto-dialog
-- here and re-check inside the draw callback, where the modal dialog is safe to use.
CSPCompatibilityManager.ShowErrorModalDialog = false

local everythingOK = CSPCompatibilityManager.checkForMissingElements(Constants.APP_NAME, Constants.APP_VERSION)
local anyMissingCSPElements = not everythingOK
local missingCSPElementsErrorMessage = CSPCompatibilityManager.getLastGeneratedErrorMessage()
CSPCompatibilityManager.freeMemory()
if not everythingOK then
    ac.error(string.format("%s v%s is missing required Custom Shaders Patch elements and will not run as expected.", Constants.APP_NAME, Constants.APP_VERSION))
    --return false
end

--[===[
local cspVersion = CSPCompatibilityManager.getCSPVersion()
Logger.log(string.format("Launching Realistic Trackday v%s.  Custom Shaders Patch: %s", Constants.APP_VERSION, cspVersion))

local showMissingCSPElementsErrorModalDialog = function(message)
  local neededFunctionsForModalDialogAvailable =
    ui.modalDialog ~= nil or
    ui.textWrapped ~= nil or
    ui.newLine ~= nil or
    ui.button ~= nil or
    ac.setClipboardText ~= nil or
    ui.sameLine ~= nil

    if not neededFunctionsForModalDialogAvailable then
      Logger.error(string.format("Cannot show error dialog because some required CSP elements are missing.\nError text: %s", message))
      return
    end

  ui.modalDialog('[Error] Missing CSP elements needed to run Realistic Trackday app', function()
    ui.textColored(message, rgbm(1, 0, 0, 1))
    ui.newLine()
    if ui.modernButton('Copy', vec2(110, 40)) then
      ac.setClipboardText(message) 
    end
    ui.sameLine()
    if ui.modernButton('Close', vec2(120, 40)) then
      return true
    end

    return false
  end, true)
end

-- Check if any CSP elements used by the app are missing
local missingCSPElements = CSPCompatibilityManager.checkForMissingCSPElements()
local anyMissingCSPElements = (#missingCSPElements > 0)
local missingCSPElementsErrorMessage

-- Show an error modal dialog if any CSP elements are missing
if anyMissingCSPElements then
  -- Build the CSP missing elements error message
  missingCSPElementsErrorMessage = "Realistic Trackday may not run as expected because some required Custom Shaders Patch elements are missing."
  missingCSPElementsErrorMessage = missingCSPElementsErrorMessage .. "\n\nThe following CSP elements are needed by the app:\n"
  for _, elementName in ipairs(missingCSPElements) do
      missingCSPElementsErrorMessage = missingCSPElementsErrorMessage .. " - " .. elementName .. "\n"
  end
  missingCSPElementsErrorMessage = missingCSPElementsErrorMessage .. "\nSee the CSP log in \"\\Documents\\Assetto Corsa\\logs\\custom_shaders_patch.log\" for more details."
  missingCSPElementsErrorMessage = missingCSPElementsErrorMessage .. "\n\nTo fix the issue, please make sure you're on the latest version of Custom Shaders Patch (https://www.patreon.com/c/x4fab/posts)"
  missingCSPElementsErrorMessage = missingCSPElementsErrorMessage .. string.format("\n\nYour CSP version is %s", cspVersion)

  -- Log the error to the CSP log as well
  Logger.error(missingCSPElementsErrorMessage)

  -- Show the error modal dialog
  showMissingCSPElementsErrorModalDialog(missingCSPElementsErrorMessage)
end
--]===]

VecPool = require("VecPool")

DequeManager = require("DataStructures.DequeManager")
StackManager = require("DataStructures.StackManager")
QueueManager = require("DataStructures.QueueManager")
CompletableIndexCollectionManager = require("DataStructures.CompletableIndexCollectionManager")

GameTimeManager = require("GameTimeManager")
AppIconRenderer = require("AppIconRenderer")
ColorManager = require("ColorManager")
RaceTrackManager = require("RaceTrackManager")
StorageManager = require("StorageManager")
MathHelpers = require("MathHelpers")
CarManager = require("CarManager")
CarOperations = require("CarOperations")
CameraManager = require("CameraManager")

Strings = require("Strings.Strings")
Strings_ReasonWhyCantYield = require("Strings.Strings_ReasonWhyCantYield")
Strings_ReasonWhyCantOvertake = require("Strings.Strings_ReasonWhyCantOvertake")
Strings_StateExitReason = require("Strings.Strings_StateExitReason")
StringsManager = require("StringsManager")
local OnCarEventManager = require("OnCarEventManager")

CarStateMachine = require("CarStateMachine.CarStateMachine")
CarState_DrivingNormally = require("CarStateMachine.States.CarState_DrivingNormally")
CarState_EasingInYield = require("CarStateMachine.States.CarState_EasingInYield")
CarState_StayingOnYieldingLane = require("CarStateMachine.States.CarState_StayingOnYieldingLane")
CarState_EasingOutYield = require("CarStateMachine.States.CarState_EasingOutYield")
CarState_CollidedWithCar = require("CarStateMachine.States.CarState_CollidedWithCar")
CarState_CollidedWithTrack = require("CarStateMachine.States.CarState_CollidedWithTrack")
CarState_AnotherCarCollidedIntoMe = require("CarStateMachine.States.CarState_AnotherCarCollidedIntoMe")
CarState_EasingInOvertake = require("CarStateMachine.States.CarState_EasingInOvertake")
CarState_StayingOnOvertakingLane = require("CarStateMachine.States.CarState_StayingOnOvertakingLane")
CarState_EasingOutOvertake = require("CarStateMachine.States.CarState_EasingOutOvertake")
CarState_NavigatingAroundAccident = require("CarStateMachine.States.CarState_NavigatingAroundAccident")
CarState_DrivingInYellowFlagZone = require("CarStateMachine.States.CarState_DrivingInYellowFlagZone")
CarState_AfterCustomAIFloodTeleport = require("CarStateMachine.States.CarState_AfterCustomAIFloodTeleport")

AccidentManager = require("AccidentManager")
RaceFlagManager = require("RaceFlagManager")
UILateralOffsetsImageWidget = require("UILateralOffsetsImageWidget")
UIAppNameVersionWidget = require("UIAppNameVersionWidget")
UIOperations = require("UIOperations")
UIManager = require("UIManager")
local Logo = require("lib/uilib/Logo")
SessionDetails = require("SessionDetails")
-- CarSpeedLimiter = require("CarSpeedLimiter")
-- CustomAIFloodManager = require("CustomAIFloodManager")
-- CollisionAvoidanceManager = require("CollisionAvoidanceManager")
-- FrenetAvoid = require("FrenetAvoid")
-- Profiler = require("Profiler")
Pathfinding = require("Pathfinding")

BehaviorPolish = require("BehaviorPolish")
HumanErrorManager = require("HumanErrorManager")

SettingsWindow = require("SettingsWindow")

-- bindings
local ac = ac
local ac_getCar = ac.getCar
local ac_getSim = ac.getSim
local ac_iterateCars = ac.iterateCars
local ui = ui
local MainWindow = require('MainWindow')
local math = math
local math_min = math.min
local Constants = Constants
local Logger = Logger
local Logger_error = Logger.error
local string = string
local string_format = string.format
local RaceTrackManager = RaceTrackManager
local RaceTrackManager_isSplinePositionInYellowZone = RaceTrackManager.isSplinePositionInYellowZone
local RaceTrackManager_updateYellowFlagZones = RaceTrackManager.updateYellowFlagZones
local AccidentManager = AccidentManager
local AccidentManager_registerCollision = AccidentManager.registerCollision
local AccidentManager_informAboutCarReset = AccidentManager.informAboutCarReset
local AppIconRenderer = AppIconRenderer
local CameraManager = CameraManager
local CameraManager_getFocusedCarIndex = CameraManager.getFocusedCarIndex
local CarManager = CarManager
local CarManager_ensureDefaults = CarManager.ensureDefaults
local CarManager_saveCarSpeed = CarManager.saveCarSpeed
local CarManager_sortCarListByTrackPosition = CarManager.sortCarListByTrackPosition
local CarOperations = CarOperations
local CarOperations_setAITopSpeed = CarOperations.setAITopSpeed
local CarStateMachine = CarStateMachine
local CarStateMachine_setReasonWhyCantOvertake = CarStateMachine.setReasonWhyCantOvertake
local CarStateMachine_setReasonWhyCantYield = CarStateMachine.setReasonWhyCantYield
local CarStateMachine_updateCar = CarStateMachine.updateCar
local CarStateMachine_handleQueuedAccidents = CarStateMachine.handleQueuedAccidents
local UIManager = UIManager
local RaceFlagManager = RaceFlagManager
local RaceFlagManager_setRaceFlag = RaceFlagManager.setRaceFlag
local RaceFlagManager_removeRaceFlag = RaceFlagManager.removeRaceFlag

-- local ENABLE_CUSTOM_AI_FLOOD_MANAGER = false

local CAN_APP_RUN = Constants.CAN_APP_RUN


local storage = StorageManager.getStorage()

local math_huge = math.huge


-- A 1-based index collection of all the cars sorted by their spline position
---@alias SortedCarsList table<integer,ac.StateCar>

---
-- Andreas: I tried making this a self-invoked anonymous function but the interpreter didn’t like it
---
local function awake()
  if (not CAN_APP_RUN) then
    Logger.log('App can not run.  Online? ' .. tostring(Constants.IS_ONLINE))
    return
  end

  -- Logger.log('Initializing')
  CarManager_ensureDefaults(0) -- ensure defaults on local player car

  -- Logger.log(ac.getTrackFullID())
  -- Logger.log(ac.getSim().raceSessionType)

  local globalStorage = StorageManager.getStorage_Global()
  if not globalStorage.appRanFirstTime then
    Logger.log('First time app run detected.  Showing app window')
    UIManager.openMainWindow()

    globalStorage.appRanFirstTime = true
  end

  -- Collect some initial data about all the cars
  for i, car in ac_iterateCars() do
    local carIndex = car.index
    local originalCarAIAggression = car.aiAggression
    local originalCarAILevel = car.aiLevel

    CarManager.cars_ORIGINAL_AI_AGGRESSION[carIndex] = originalCarAIAggression
    -- Logger.log(string.format('Original #%d AI Aggression: %.3f', i, car.aiAggression))

    CarManager.cars_ORIGINAL_AI_DIFFICULTY_LEVEL[carIndex] = originalCarAILevel
    -- Logger.log(string.format('Original #%d AI Difficulty Level: %.3f', i, originalCarAILevel))
  end
end
local awakeOk, awakeErr = xpcall(awake, function(err) return tostring(err) .. "\n" .. debug.traceback() end)
if not awakeOk then
  if ac and ac.error then ac.error("App initialization failed: " .. tostring(awakeErr)) end
end

local function shouldAppRun()
    -- local storage = StorageManager.getStorage()
    return
        CAN_APP_RUN
        -- and storage.enabled
        and storage.enabled
end

---The callback function for when a car collision event occurs
---@param carIndex integer
OnCarEventManager.OnCarEventExecutions[OnCarEventManager.OnCarEventType.Collision] = function (carIndex)
  -- local storage = StorageManager.getStorage()
  if storage.handleAccidents then
      -- Register an accident for the car collision
      local car = ac_getCar(carIndex)
      if not car then
          Logger_error(string_format('OnCarEventManager: OnCarEventType.Collision called for invalid car index %d', carIndex))
          return
      end

      --[====[
      local accidentIndex = AccidentManager.registerCollision(carIndex, car.collisionPosition, car.collidedWith)
      if not accidentIndex then
          return
      end

      CarStateMachine.informAboutAccident(accidentIndex)
      --]====]
      AccidentManager_registerCollision(carIndex, car.collisionPosition, car.collidedWith)
  end
end

---The callback function for when a car jumped event occurs
---@param carIndex integer
OnCarEventManager.OnCarEventExecutions[OnCarEventManager.OnCarEventType.Jumped] = function (carIndex)
  -- Inform the accident manager about the car reset
  AccidentManager_informAboutCarReset(carIndex)

  -- local setInitializedDefaults = not (CarManager.cars_doNoResetAfterNextCarJump[carIndex] or CarManager.cars_justTeleportedDueToManualAccidentSimulation[carIndex])
  local doNoResetAfterNextCarJump = CarManager.cars_doNoResetAfterNextCarJump[carIndex]
  if doNoResetAfterNextCarJump then
    Logger.log(string_format("Not resetting car #%d data after jump due to doNoResetAfterNextCarJump flag being set.  Removing flag now", carIndex))
    CarManager.cars_doNoResetAfterNextCarJump[carIndex] = false
    return
  end

  -- finally reset all our car data
  -- if setInitializedDefaults then
    -- Logger.log(string_format("Resetting car #%d data.  Teleported due to custom AI Flood: %s, Teleported due to manual accident simulation: %s", carIndex, tostring(CarManager.cars_doNoResetAfterNextCarJump[carIndex]), tostring(CarManager.cars_justTeleportedDueToManualAccidentSimulation[carIndex])))
    Logger.log(string_format("Resetting car #%d data.", carIndex))
    CarManager.setInitializedDefaults(carIndex)
  -- else
    -- Logger.warn(string_format("Not resetting car #%d data.  Teleported due to custom AI Flood: %s, Teleported due to manual accident simulation: %s", carIndex, tostring(CarManager.cars_doNoResetAfterNextCarJump[carIndex]), tostring(CarManager.cars_justTeleportedDueToManualAccidentSimulation[carIndex])))
  -- end
end

-- Monitor car collisions so we can register an accident
ac.onCarCollision(-1, function (carIndex)
    if (not shouldAppRun()) then return end
    local car = ac_getCar(carIndex)
    if not car then return end

    OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Collision, carIndex)
end)

-- Monitor flood ai cars cycle event so that we also reset our state
ac.onCarJumped(-1, function(carIndex)
    if (not shouldAppRun()) then return end
    local car = ac_getCar(carIndex)
    if not car then return end

    OnCarEventManager.enqueueOnCarEvent(OnCarEventManager.OnCarEventType.Jumped, carIndex)
end)

ac.onSessionStart(function()
  if (not shouldAppRun()) then return end

  SessionDetails.informSessionInitiated()
end)

---
-- Function defined in manifest.ini
-- wiki: function to be called each frame to draw window content
---
function script.MANIFEST__FUNCTION_MAIN(dt)
  local ok, err = xpcall(function()
  MainWindow.draw(shouldAppRun, anyMissingCSPElements, missingCSPElementsErrorMessage)
  end, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
  if not ok and ac and ac.error then
    ac.error("UI draw failed: " .. tostring(err))
  end
end

function script.MANIFEST__FUNCTION_ICON()
  local p = ui.getCursor()
  local size = math_min(20, ui.availableSpaceX(), ui.availableSpaceY())
  if not (size > 0) then return end
  Logo.draw(size, p)
end

-- local frenetOffsets = {}

---
-- wiki: called after a whole simulation update
---
function script.MANIFEST__UPDATE(dt)
  if (not shouldAppRun()) then return end

  local sim = ac_getSim()

  GameTimeManager.update(dt)

  if sim.isPaused then return end

  -- invalidate the per-frame caches (e.g. the actual track lateral offset cache)
  CarManager._currentFrameId = (CarManager._currentFrameId or 0) + 1

  -------------------
  -- physics.setAITopSpeed(6,30)
    -- CarSpeedLimiter.limitTopSpeed(6, 30, dt)
  -------------------

  -- local storage = StorageManager.getStorage()
  -- local playerCar = ac_getCar(0)

  SessionDetails.update(dt)

  -- check if the player is coming up to an accident so we can set a caution flag
  -- local isPlayerComingUpToAccidentIndex = AccidentManager.isCarComingUpToAccident(playerCar, storage.distanceFromAccidentToSeeYellowFlag_meters)
  -- if isPlayerComingUpToAccidentIndex then
  local cameraFocusedCarIndex = CameraManager_getFocusedCarIndex()
  -- Logger.log(string.format("Camera focused car index is %d", cameraFocusedCarIndex or -1))
  local cameraFocusedCar = ac_getCar(cameraFocusedCarIndex)
  if cameraFocusedCar then
    local cameraFocusedCarSplinePosition = cameraFocusedCar.splinePosition
    local isFocusedCarInYellowFlagZone = RaceTrackManager_isSplinePositionInYellowZone(cameraFocusedCarSplinePosition)
    if isFocusedCarInYellowFlagZone then
      RaceFlagManager_setRaceFlag(ac.FlagType.Caution)
    else
      RaceFlagManager_removeRaceFlag()
    end
  end
  -- local playerCarSplinePosition = playerCar.splinePosition
  -- local isPlayerInYellowFlagZone = RaceTrackManager_isSplinePositionInYellowZone(playerCarSplinePosition)
  -- if isPlayerInYellowFlagZone then
    -- RaceFlagManager.setRaceFlag(ac.FlagType.Caution)
  -- else
    -- RaceFlagManager.removeRaceFlag()
  -- end

  -- build the sorted car list and do any per-car operations that doesn't require the sorted list

  ---@type SortedCarsList
  local carList = CarManager.cars_currentReusableList
  table.clear(carList)
  for i, car in ac_iterateCars() do
    carList[i] = car

    local carIndex = car.index
    CarManager_ensureDefaults(carIndex) -- Ensure defaults are set if this car hasn't been initialized yet

    CarManager_saveCarSpeed(car)

    -- clear the reason why we can't yield/overtake for this car, we'll re-set it below if needed
    CarStateMachine_setReasonWhyCantYield(carIndex, Strings.StringNames[Strings.StringCategories.ReasonWhyCantYield].None)
    CarStateMachine_setReasonWhyCantOvertake(carIndex, Strings.StringNames[Strings.StringCategories.ReasonWhyCantOvertake].None)

    -- local isCarComingUpToAccident = AccidentManager.isCarComingUpToAccident(car)
    -- if isCarComingUpToAccident then
    -- end
  end
  local sortedCars = CarManager_sortCarListByTrackPosition(carList)

  -- save a reference to the current sorted cars list for other parts of the app to use
  CarManager.currentSortedCarsList = sortedCars

  -- handle any queued accidents before updating the car state machines
  OnCarEventManager.processQueuedEvents()
  CarStateMachine_handleQueuedAccidents() -- todo: check if this can be integrated with the processQueuedEvents() above

  -- Human errors: simulate realistic mistakes (brake/traction) with cooldown
  local storage_Behavior = StorageManager.getStorage_Behavior()
  local gameTime_s = GameTimeManager.getPlayingGameTime()
  HumanErrorManager.update(dt, sortedCars, storage_Behavior, gameTime_s)

  local globalTopSpeedLimitKmh = storage.globalTopSpeedLimitKmh
  if globalTopSpeedLimitKmh == 0 then
    globalTopSpeedLimitKmh = math_huge
  end

  local totalCars = #sortedCars
  for i = 1, totalCars do
    local car = sortedCars[i]
    local carIndex = car.index
    CarManager.sortedCarList_carIndexToSortedIndex[carIndex] = i -- save the mapping of carIndex to sorted list index
    if car.isAIControlled then -- including the player car if it's AI controlled
      -- execute the state machine for this car
      CarStateMachine_updateCar(carIndex, dt, sortedCars, i)--, storage)

      -- local carState = CarStateMachine.getCurrentState(carIndex)
      -- local aiCarCurrentlyYielding = (carState == CarStateMachine.CarStateType.EASING_IN_YIELD) or (carState == CarStateMachine.CarStateType.STAYING_ON_YIELDING_LANE)
      -- CarManager.cars_currentlyYielding[carIndex] = aiCarCurrentlyYielding

      -- Apply the global top speed limit to this car
      local requestedCarTopSpeedLimitKmh = CarManager.cars_aiTopSpeed[carIndex]
      local appliedCarTopSpeedLimitKmh = math_min(requestedCarTopSpeedLimitKmh, globalTopSpeedLimitKmh)
      CarOperations_setAITopSpeed(carIndex, appliedCarTopSpeedLimitKmh)
    end
  end

  -- custom ai flood handling
  -- if ENABLE_CUSTOM_AI_FLOOD_MANAGER then
    -- local localPlayerSortedCarListIndex = CarManager.sortedCarList_carIndexToSortedIndex[0]
    -- CustomAIFloodManager.handleFlood(sortedCars, localPlayerSortedCarListIndex)
  -- end

  RaceTrackManager_updateYellowFlagZones()

  -- local sessionType = sim.raceSessionType
  -- if sessionType == ac.SessionType.Race then
    -- local isSessionStarted = sim.isSessionStarted
    -- Logger.log(string_format("Race session started: %s", tostring(isSessionStarted)))
  -- end
end

---
-- wiki: called when transparent objects are finished rendering
---
function script.MANIFEST__TRANSPARENT(dt)
  if (not shouldAppRun()) then return end
end

--[=====[ 
---
-- wiki: Called each frame after world matrix traversal ends for each app, even if none of its windows are active. 
-- wiki: Please make sure to not do anything too computationally expensive there (unless app needs it for some reason).
---
function script.update(dt)
  if (not shouldAppRun()) then return end

end
--]=====]

--[=====[ 
---
-- Save when window is closed/hidden as a last resort
-- wiki: function to be called once when window closes
---
function script.MANIFEST__FUNCTION_ON_HIDE()
  if (not shouldAppRun()) then return end
end
--]=====]
