local Constants = {}

local sim = ac.getSim()

Constants.APP_NAME = "SimOpenTrackDay"
Constants.APP_VERSION = "0.2"
Constants.APP_AUTHOR = "dreasgrech"
Constants.APP_DEVELOPER = "SnakeD"
Constants.APP_ICON_SIZE = vec2(128, 128)
Constants.IS_ONLINE = sim.isOnlineRace

-- F0: minimum Custom Shaders Patch build (ac.getPatchVersionCode). Below it, or when the build
-- cannot be read, the app fails closed and stays inert. Reference build: 0.3.2-preview2 (4305).
Constants.MIN_CSP_BUILD = 4305
-- CSP may expose ac.getPatchVersionCode as a callable FFI cdata (like physics.allowed), and the
-- result may be an FFI integer, so accept both and normalize the value with tonumber().
local cspBuildFnType = type(ac.getPatchVersionCode)
local cspBuildOk, cspBuild = false, nil
if cspBuildFnType == 'function' or cspBuildFnType == 'cdata' then
  cspBuildOk, cspBuild = pcall(ac.getPatchVersionCode)
end
local cspBuildRawType = type(cspBuild)
cspBuild = cspBuildOk and tonumber(cspBuild) or nil
if cspBuild ~= cspBuild then cspBuild = nil end
Constants.CSP_BUILD = cspBuild
Constants.CSP_BUILD_PROBE = string.format('fn=%s ok=%s result=%s', cspBuildFnType, tostring(cspBuildOk), cspBuildRawType)
Constants.CSP_BUILD_OK = (cspBuild ~= nil) and (cspBuild >= Constants.MIN_CSP_BUILD)

Constants.CAN_APP_RUN = (not Constants.IS_ONLINE) and Constants.CSP_BUILD_OK
Constants.ENABLE_DEVELOPMENT_DEBUG_PANEL = false
-- Development only (F1-3 calibration): holds the camera-focused AI car at fixed lateral offsets and
-- logs where it actually drives, tag [CAL]. Keep false in releases.
Constants.ENABLE_OFFSET_CALIBRATION = false
-- Development only (D1): logs the focused AI's actual x, AI line x and normal-driving target, tag [LINE].
Constants.ENABLE_LINE_LOG = false

Constants.ENABLE_ACCIDENT_HANDLING_IN_APP = true -- disable accident handling for now since it's still WIP

-- Lateral distance (in meters) used as the ray length when checking whether another car is
-- blocking one side of a car. Represents the typical lateral lane width to probe for a blocking car.
Constants.SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING = 1.5

return Constants
