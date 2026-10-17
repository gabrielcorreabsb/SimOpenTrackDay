local Constants = {}

local sim = ac.getSim()

Constants.APP_NAME = "SimOpenTrackDay"
Constants.APP_VERSION = "0.9.8"
Constants.APP_AUTHOR = "dreasgrech"
Constants.APP_ICON_SIZE = vec2(128, 128)
Constants.IS_ONLINE = sim.isOnlineRace
Constants.CAN_APP_RUN = (not Constants.IS_ONLINE)

Constants.ENABLE_ACCIDENT_HANDLING_IN_APP = true -- disable accident handling for now since it's still WIP

-- Lateral distance (in meters) used as the ray length when checking whether another car is
-- blocking one side of a car. Represents the typical lateral lane width to probe for a blocking car.
Constants.SIDE_DISTANCE_TO_CHECK_FOR_BLOCKING = 1.5

-- Constants.FRENET_DEBUGGING  = false
-- Constants.FRENET_DEBUGGING_CAR_INDEX = 0

-- Constants.PATHFINDING_DEBUGGING  = true
Constants.PATHFINDING_DEBUGGING  = false
Constants.PATHFINDING_DEBUGGING_CAR_INDEX = 0

return Constants
