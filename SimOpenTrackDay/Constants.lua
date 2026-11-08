local Constants = {}

local sim = ac.getSim()

Constants.APP_NAME = "SimOpenTrackDay"
Constants.APP_VERSION = "0.1"
Constants.APP_AUTHOR = "dreasgrech"
Constants.APP_DEVELOPER = "SnakeD"
Constants.APP_ICON_SIZE = vec2(128, 128)
Constants.IS_ONLINE = sim.isOnlineRace

-- F0: minimum Custom Shaders Patch build (ac.getPatchVersionCode). Below it, or when the build
-- cannot be read, the app fails closed and stays inert. Reference build: 0.3.2-preview2 (4305).
Constants.MIN_CSP_BUILD = 4305
local cspBuildOk, cspBuild = false, nil
if type(ac.getPatchVersionCode) == 'function' then
  cspBuildOk, cspBuild = pcall(ac.getPatchVersionCode)
end
if not cspBuildOk or type(cspBuild) ~= 'number' or cspBuild ~= cspBuild then cspBuild = nil end
Constants.CSP_BUILD = cspBuild
Constants.CSP_BUILD_OK = (cspBuild ~= nil) and (cspBuild >= Constants.MIN_CSP_BUILD)

Constants.CAN_APP_RUN = (not Constants.IS_ONLINE) and Constants.CSP_BUILD_OK
Constants.ENABLE_DEVELOPMENT_DEBUG_PANEL = false

Constants.ENABLE_ACCIDENT_HANDLING_IN_APP = true -- disable accident handling for now since it's still WIP

-- Lateral distance (in meters) used as the ray length when checking whether another car is
-- blocking one side of a car. Represents the typical lateral lane width to probe for a blocking car.
Constants.SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING = 1.5

return Constants
