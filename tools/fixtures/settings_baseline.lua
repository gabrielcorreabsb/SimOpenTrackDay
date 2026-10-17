-- Data-only inventory captured from the authorized pre-integration baseline snapshot.
-- Update only from an explicitly supplied baseline source, never from current SettingsWindow.
return {
  sliders = {
    ["##debugCarStateOverheadShowDistance"] = { min = 10, max = 500, format = "Car gizmos draw distance: %.0fm", default = 125, tooltip = "The maximum distance from the camera focused car at which to show the car state overhead text." },
    ["##debugOverridePlayerCarLateralOffsetValue"] = { min = -1, max = 1, format = "Player car lateral offset override value: %.2f", default = 0, tooltip = "The lateral offset value to force the player car to use when the override is enabled." },
    ["##debugSimulateAccidentSplinePosition"] = { min = 0, max = 1, format = "Accident spline position: %.3f", default = 0.001, tooltip = "The spline position to use when simulating an accident." },
    ["AI lookahead window"] = { min = 0, max = 10, format = "%.2f s", default = 2, tooltip = "How far ahead the AI looks to anticipate." },
    ["AI reaction delay"] = { min = 0, max = 2, format = "%.2f s", default = 0.4, tooltip = "How long the AI waits before reacting to a situation." },
    ["AI reaction jitter"] = { min = 0, max = 1, format = "%.2f s", default = 0.2, tooltip = "Random extra delay added on top of reaction delay." },
    ["Aggression while driving normally"] = { min = 0, max = 1, format = "%.2f", default = 0.5, tooltip = "The default aggression level cars exhibit when driving on the default driving lane.\
\
The higher this value is, the more aggressive the cars will be (although the exact definition of aggression is still a bit unclear at the moment)." },
    ["Aggression while overtaking (No obstacle in front)"] = { min = 0, max = 1, format = "%.2f", default = 1, tooltip = "The aggression level used when overtaking another car if there is no obstacle in front of the overtaking car.\
\
The higher this value is, the more aggressive the cars will be while overtaking when there is no obstacle in front of them." },
    ["Aggression while overtaking (Obstacle in front)"] = { min = 0, max = 1, format = "%.2f", default = 0.95, tooltip = "The aggression level used when overtaking another car if there is an obstacle in front of the overtaking car.\
\
The lower this value is, the more cautious the cars will be while overtaking when there is an obstacle in front of them." },
    ["Aggression while overtaking in corner"] = { min = 0, max = 1, format = "%.2f", default = 0.95, tooltip = "The aggression level used when overtaking another car while in a corner.\
\
The lower this value is, the more cautious the cars will be while overtaking in corners." },
    ["Aggression while yielding"] = { min = 0, max = 1, format = "%.2f", default = 0.5, tooltip = "The aggression level used when yielding (giving way to faster cars).\
\
The lower this value is, the more cautious the cars will be while yielding." },
    ["Anchor ahead distance"] = { min = 0, max = 30, format = "%.2f m", default = 0, tooltip = "The distance ahead of the car where the pathfinding system will place an anchor point to help guide the car around obstacles." },
    ["Approx car radius"] = { min = 0.5, max = 5, format = "%.2f m", default = 1.6, tooltip = "The approximate radius of the car used by the pathfinding system for collision avoidance." },
    ["Caution while driving normally"] = { min = 0, max = 16, format = "%.2f", default = 3, tooltip = "The default gap cars keep between each other while driving on the default driving lane.\
\
The higher this value is, the more cautious the cars will be by keeping a larger gap between each other, which can provide a more relaxed trackday experience." },
    ["Caution while overtaking (No obstacle in front)"] = { min = 0, max = 16, format = "%.2f", default = 0, tooltip = "The caution level used when overtaking another car if there is no obstacle in front of the overtaking car.\
\
The lower this value is, the more aggressive the cars will be while overtaking when there is no obstacle in front of them." },
    ["Caution while overtaking (Obstacle in front)"] = { min = 0, max = 16, format = "%.2f", default = 1, tooltip = "The caution level used when overtaking another car if there is an obstacle in front of the overtaking car.\
\
The higher this value is, the more cautious the cars will be while overtaking when there is an obstacle in front of them." },
    ["Caution while overtaking in corner"] = { min = 0, max = 16, format = "%.2f", default = 2, tooltip = "The caution level used when overtaking another car while in a corner.\
\
The higher this value is, the more cautious the cars will be while overtaking in corners." },
    ["Caution while yielding"] = { min = 0, max = 16, format = "%.2f", default = 4, tooltip = "The caution level used when yielding (giving way to faster cars).\
\
The higher this value is, the more cautious the cars will be while yielding." },
    ["Default Lateral Offset [-1..1]"] = { min = -1, max = 1, format = "%.2f", default = 0, tooltip = "The default lateral offset from the centerline that AI cars will try to maintain when not yielding or overtaking.\
-1 = fully to the left\
0 = center of the track (racing line)\
1 = fully to the right" },
    ["Defense duration max (s)"] = { min = 0, max = 10, format = "%.1f s", default = 3, tooltip = "Maximum time defending position before yielding." },
    ["Defense duration min (s)"] = { min = 0, max = 10, format = "%.1f s", default = 1, tooltip = "Minimum time defending position before yielding." },
    ["Defer yielding/overtaking for a while after session start"] = { min = 0, max = 300, format = "%.2f seconds", default = 0, tooltip = "The time after the session starts during which no yielding or overtaking will be performed by AI cars.\
\
Usually only applicable for race scenarios where you don't want the cars to try and yield immediately after start because it creates chaos." },
    ["Detect car ahead distance"] = { min = 5, max = 200, format = "%.2f m", default = 50, tooltip = "Start overtaking if the car in front is within this distance" },
    ["Detect car behind distance"] = { min = 5, max = 200, format = "%.2f m", default = 50, tooltip = "Start yielding if the overtaking car behind is within this distance" },
    ["Difficulty Level while driving normally"] = { min = 0, max = 2, format = "%.2f", default = 0.8, tooltip = "The default difficulty level cars exhibit when driving on the default driving lane.\
\
The higher this value is, the more effective the cars will be with the pedals and how fast they can handle corners." },
    ["Difficulty Level while overtaking (No obstacle in front)"] = { min = 0, max = 2, format = "%.2f", default = 2, tooltip = "The difficulty level used when overtaking another car if there is no obstacle in front of the overtaking car.\
\
The higher this value is, the more effective the cars will be with the pedals and how fast they can handle corners while overtaking when there is no obstacle in front of them." },
    ["Difficulty Level while overtaking (Obstacle in front)"] = { min = 0, max = 2, format = "%.2f", default = 1.5, tooltip = "The difficulty level used when overtaking another car if there is an obstacle in front of the overtaking car.\
\
The lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while overtaking when there is an obstacle in front of them." },
    ["Difficulty Level while overtaking in corner"] = { min = 0, max = 2, format = "%.2f", default = 0.7, tooltip = "The difficulty level used when overtaking another car while in a corner.\
\
The lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while overtaking in corners." },
    ["Difficulty Level while yielding"] = { min = 0, max = 2, format = "%.2f", default = 0.6, tooltip = "The difficulty level used when yielding (giving way to faster cars).\
\
The lower this value is, the less effective the cars will be with the pedals and how fast they can handle corners while yielding." },
    ["Distance from accident to see yellow flag (m)"] = { min = 50, max = 500, format = "%.2f m", default = 200, tooltip = "Distance from accident at which AI will see the yellow flag and start slowing down." },
    ["Distance to overtaking car to apply speed limiting"] = { min = 1, max = 100, format = "%.2f m", default = 10, tooltip = "When yielding, if an overtaking car is within this distance behind us, we will limit our speed to let it pass more easily." },
    ["Distance to start navigating around car in accident (m)"] = { min = 5, max = 100, format = "%.2f m", default = 30, tooltip = "Distance from accident at which AI will start navigating around the car in accident." },
    ["Entry blend time"] = { min = 0, max = 5, format = "%.2f s", default = 1.5, tooltip = "Time to fade in when entering a new state (yielding, overtaking, etc.).\
Higher = smoother transitions." },
    ["Error cooldown (s)"] = { min = 0, max = 30, format = "%.1f s", default = 7, tooltip = "Minimum time between human errors on the same car." },
    ["Exit blend time"] = { min = 0, max = 5, format = "%.2f s", default = 2, tooltip = "Time to fade out when leaving a state." },
    ["Forward distance"] = { min = 10, max = 500, format = "%.2f m", default = 60, tooltip = "The distance ahead of the car that the pathfinding system will consider when calculating paths around obstacles." },
    ["Global top speed limit"] = { min = 0, max = 500, format = "%.2f km/h", default = 0, tooltip = "A global top speed limit applied to all AI cars.\
0  = no global top speed limit." },
    ["Human errors enabled"] = { min = 0, max = 1, format = "%.0f", default = 1, tooltip = "Whether AI cars make realistic mistakes (lock-ups, traction loss)." },
    ["Lateral split exponent"] = { min = 1, max = 5, format = "%.2f", default = 2.2, tooltip = "The exponent used to weight lateral splits in the pathfinding calculations." },
    ["Lock-up probability (per sec)"] = { min = 0, max = 0.1, format = "%.3f", default = 0.03, tooltip = "Chance per second of brake lock-up when braking hard." },
    ["Lookahead confidence threshold"] = { min = 0, max = 1, format = "%.2f", default = 0.7, tooltip = "Min confidence to act on lookahead." },
    ["Max absolute offset normalized"] = { min = 0.1, max = 1, format = "%.2f", default = 1, tooltip = "The maximum absolute lateral offset (normalized) that the pathfinding system will allow when calculating paths around obstacles." },
    ["Minimum top speed to limit to overtaking car"] = { min = 0, max = 300, format = "%.2f km/h", default = 60, tooltip = "When yielding, the yielding car's top speed will not be limited below this speed even if the overtaking car is very slow.\
0.0 = no minimum top speed limit while yielding" },
    ["Number of path samples"] = { min = 2, max = 64, format = "%.0f", default = 12, tooltip = "The number of path samples the pathfinding system will use to evaluate possible paths around obstacles." },
    ["Overtake aggressiveness"] = { min = 0, max = 1, format = "%.2f", default = 0.5, tooltip = "How assertive AI is when space is marginal." },
    ["Overtaking Lateral Offset [-1..1] -> Overtaking side: Left"] = { min = -1, max = 1, format = "%.2f", default = -0.8, tooltip = "The lateral offset from the centerline that AI cars will drive to when overtaking another car.\
-1 = fully to the left\
0 = center of the track\
1 = fully to the right" },
    ["Overtaking Lateral Offset decrement step"] = { min = 0.1, max = 1, format = "%.3f m/s", default = 0.5, tooltip = "How quickly the lateral offset returns to normal once an overtaking car has fully driven past the overtaken car.\
The higher it is, the more quickly cars will change lanes moving back to the default lateral offset after finishing overtaking." },
    ["Overtaking Lateral Offset increment step"] = { min = 0.1, max = 1, format = "%.3f m/s", default = 0.5, tooltip = "How quickly the lateral offset ramps up when overtaking another car.\
The higher it is, the more quickly cars will change lanes when moving to the overtaking side" },
    ["Point-by speed delta (km/h)"] = { min = 0, max = 80, format = "%.0f km/h", default = 15, tooltip = "How much faster (km/h) a car behind must be to yield." },
    ["Safety margin"] = { min = 0, max = 2, format = "%.2f m", default = 0.4, tooltip = "The safety margin added around obstacles by the pathfinding system to prevent collisions." },
    ["Split reach distance"] = { min = 1, max = 50, format = "%.2f m", default = 5, tooltip = "The distance at which the pathfinding system will split its path calculations to explore different routes around obstacles." },
    ["The distance which determines whether a car is far enough ahead of another car"] = { min = 4, max = 20, format = "%.2f m", default = 10, tooltip = "When checking if a car is clear ahead of another car, this is the distance used to determine if it is clear." },
    ["Throttle pedal limit when yielding to overtaking car [0..1]"] = { min = 0, max = 1, format = "%.2f", default = 0.9, tooltip = "When yielding, the yielding car's throttle pedal input will be limited to this fraction to let the overtaking car pass more easily.\
1.0 = no throttle pedal limiting\
0.5 = limit throttle pedal input to half\
0.0 = completely let go of the throttle pedal" },
    ["Time to leave path blocked after sample hit"] = { min = 0, max = 5, format = "%.2f seconds", default = 0.5, tooltip = "The time the pathfinding system will leave a path marked as blocked after a sample in the path was hit during a collision check." },
    ["Top speed limit value to overtaking car [0..1]"] = { min = 0, max = 1, format = "%.2f", default = 0.7, tooltip = "When yielding, the yielding car's top speed will be limited to this fraction of the overtaking car's current speed to let it pass more easily.\
1.0 = no top speed limiting\
0.5 = limit top speed to half the current speed of the overtaking car.\
0.0 = make the car grind to a halt" },
    ["Traction mistake prob (per sec)"] = { min = 0, max = 0.1, format = "%.3f", default = 0.02, tooltip = "Chance per second of traction loss on throttle." },
    ["Yielding Lateral Offset [-1..1] -> Yielding side: Right"] = { min = -1, max = 1, format = "%.2f", default = 0.8, tooltip = "The lateral offset from the centerline that AI cars will drive to when yielding (giving way to faster cars).\
-1 = fully to the left\
0 = center of the track\
1 = fully to the right" },
    ["Yielding Lateral Offset decrement step"] = { min = 0.1, max = 1, format = "%.2f m/s", default = 0.25, tooltip = "How quickly the lateral offset returns to normal once an overtaking car has fully driven past the yielding car.\
The higher it is, the more quickly cars will change lanes moving back to the default lateral offset after finishing yielding." },
    ["Yielding Lateral Offset increment step"] = { min = 0.1, max = 1, format = "%.2f m/s", default = 0.25, tooltip = "How quickly the lateral offset ramps up when yielding to an overtaking car.\
The higher it is, the more quickly cars will change lanes when moving to the yielding side." },
  },
  checkboxes = {
    ["Check sides while overtaking"] = true,
    ["Check sides while yielding"] = true,
    ["Draw tyres side offtrack gizmos"] = true,
    ["Handle Overtaking"] = true,
    ["Handle Yielding"] = true,
    ["Handle accidents (WORK IN PROGRESS - BEST NOT USED FOR NOW)"] = true,
    ["Log car overtaking"] = true,
    ["Log car yielding"] = true,
    ["Log fast AI state changes"] = true,
    ["Override AI awareness"] = true,
    ["Override original Aggression values when driving normally"] = true,
    ["Override original Difficulty Level when driving normally"] = true,
    ["Override original Difficulty Level when overtaking"] = true,
    ["Override original Difficulty Level when yielding"] = true,
    ["Override original aggression when overtaking"] = true,
    ["Override original aggression when yielding"] = true,
    ["Override player car lateral offset"] = true,
    ["Realistic Trackday Disabled for: Mock Track (Mode: Practice)"] = true,
    ["Require overtaking car to be on overtaking lane to yield"] = true,
    ["Require yielding car to be on yielding lane to overtake"] = true,
    ["Show Advanced Behavior Sliders"] = true,
    ["Show UI Car List"] = true,
    ["Show car state overhead text"] = true,
    ["Show raycasts when driving laterally"] = true,
    ["Use indicator lights when driving on overtaking lane"] = true,
    ["Use indicator lights when driving on yielding lane"] = true,
    ["Use indicator lights when easing in to overtake"] = true,
    ["Use indicator lights when easing in yield"] = true,
    ["Use indicator lights when easing out of overtaking"] = true,
    ["Use indicator lights when easing out of yield"] = true,
  },
  buttons = {
    ["Simulate accident (manual)"] = true,
    ["Simulate accident (random)"] = true,
  },
  combos = {
    ["AI Behavior Profile"] = true,
  },
  fields = {
    ["storage.clearAhead_meters"] = true,
    ["storage.defaultLateralOffset"] = true,
    ["storage.deferTimeAfterSessionStart"] = true,
    ["storage.distanceFromAccidentToSeeYellowFlag_meters"] = true,
    ["storage.distanceToStartNavigatingAroundCarInAccident_meters"] = true,
    ["storage.globalTopSpeedLimitKmh"] = true,
    ["storage.overtakingLateralOffset"] = true,
    ["storage.yieldingLateralOffset"] = true,
    ["storage_AICarValues.AIAggression_OvertakingWithNoObstacleInFront"] = true,
    ["storage_AICarValues.AIAggression_OvertakingWithObstacleInFront"] = true,
    ["storage_AICarValues.AIAggression_WhileInCorner"] = true,
    ["storage_AICarValues.AIAggression_Yielding"] = true,
    ["storage_AICarValues.AICaution_OvertakingWhileInCorner"] = true,
    ["storage_AICarValues.AICaution_OvertakingWithNoObstacleInFront"] = true,
    ["storage_AICarValues.AICaution_OvertakingWithObstacleInFront"] = true,
    ["storage_AICarValues.AICaution_Yielding"] = true,
    ["storage_AICarValues.AIDifficultyLevel_OvertakingWithNoObstacleInFront"] = true,
    ["storage_AICarValues.AIDifficultyLevel_OvertakingWithObstacleInFront"] = true,
    ["storage_AICarValues.AIDifficultyLevel_WhileInCorner"] = true,
    ["storage_AICarValues.AIDifficultyLevel_Yielding"] = true,
    ["storage_AICarValues.defaultAIAggression"] = true,
    ["storage_AICarValues.defaultAICaution"] = true,
    ["storage_AICarValues.defaultAIDifficultyLevel"] = true,
    ["storage_Behavior.aiLookaheadConfidenceThreshold"] = true,
    ["storage_Behavior.aiLookaheadWindow_s"] = true,
    ["storage_Behavior.aiReactionDelay_s"] = true,
    ["storage_Behavior.aiReactionJitter_s"] = true,
    ["storage_Behavior.defenseDurationMax_s"] = true,
    ["storage_Behavior.defenseDurationMin_s"] = true,
    ["storage_Behavior.entryBlendTime_s"] = true,
    ["storage_Behavior.errorCooldown_s"] = true,
    ["storage_Behavior.exitBlendTime_s"] = true,
    ["storage_Behavior.humanErrorEnabled"] = true,
    ["storage_Behavior.humanLockupProbability"] = true,
    ["storage_Behavior.humanTractionMistakeProbability"] = true,
    ["storage_Behavior.overtakeAggressiveness"] = true,
    ["storage_Behavior.pointBySpeedDeltaKmh"] = true,
    ["storage_Debugging.debugCarGizmosDrawistance"] = true,
    ["storage_Debugging.debugOverridePlayerCarLateralOffsetValue"] = true,
    ["storage_Debugging.debugSimulateAccidentSplinePosition"] = true,
    ["storage_Overtaking.detectCarAhead_meters"] = true,
    ["storage_Overtaking.overtakeRampRelease_mps"] = true,
    ["storage_Overtaking.overtakeRampSpeed_mps"] = true,
    ["storage_PathFinding.anchorAheadMeters"] = true,
    ["storage_PathFinding.approxCarRadiusMeters"] = true,
    ["storage_PathFinding.forwardDistanceMeters"] = true,
    ["storage_PathFinding.lateralSplitExponent"] = true,
    ["storage_PathFinding.maxAbsOffsetNormalized"] = true,
    ["storage_PathFinding.numberOfPathSamples"] = true,
    ["storage_PathFinding.safetyMarginMeters"] = true,
    ["storage_PathFinding.splitReachMeters"] = true,
    ["storage_PathFinding.timeToLeavePathBlockedAfterSampleHitSeconds"] = true,
    ["storage_Yielding.detectCarBehind_meters"] = true,
    ["storage_Yielding.distanceToOvertakingCarToLimitSpeed"] = true,
    ["storage_Yielding.minimumSpeedLimitKmhToLimitToOvertakingCar"] = true,
    ["storage_Yielding.rampRelease_mps"] = true,
    ["storage_Yielding.rampSpeed_mps"] = true,
    ["storage_Yielding.speedLimitValueToOvertakingCar"] = true,
    ["storage_Yielding.throttlePedalLimitWhenYieldingToOvertakingCar"] = true,
  },
}
