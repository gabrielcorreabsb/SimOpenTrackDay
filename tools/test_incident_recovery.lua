local root = (arg[0]:gsub('tools[\\/]test_incident_recovery.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path
table.clear = table.clear or function(value) for key in pairs(value) do value[key] = nil end end
local ffi = require('ffi')

CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
local sim = { trackLengthM = 5000, raceSessionType = 1, carsCount = 6 }
local function vec(x, y, z) return { x = x, y = y, z = z } end
local cars = {}
for i = 0, 5 do
  cars[i] = { index = i, position = vec(i * 2, 0, 0), splinePosition = .1 + i * .1,
    isConnected = true, isActive = true, isInPit = false, isInPitlane = false,
    speedKmh = 30, collisionDepth = 0 }
end
ac = { SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4,
    TimeAttack = 5, Drift = 6, Drag = 7 }, getSim = function() return sim end,
  getTrackName = function() return 'incident-recovery-test' end,
  getCar = function(index) return cars[index] end }
StorageManager = { getStorage = function() return { distanceFromAccidentToSeeYellowFlag_meters = 100 } end }
local observed = {}
Logger = { log = function() end, observe = function(...) observed[#observed + 1] = { ... } end }
vec3 = function(x, y, z) return vec(x, y, z) end
CarManager = { sessionGeneration = 1, carGeneration = {}, cars_navigatingAroundAccidentIndex = {},
  cars_navigatingAroundCarIndex = {}, getCarGeneration = function(index) return CarManager.carGeneration[index] or 0 end,
  isWritableAICar = function(index) return index > 0 end }
local activeStops, informed = {}, {}
CarOperations = { hasActiveIncidentStop = function(index) return activeStops[index] == true end }
CarStateMachine = { CarStateType = { NAVIGATING_AROUND_ACCIDENT = 8192 },
  getCurrentState = function() end,
  informAboutAccident = function(index) informed[#informed + 1] = index end }
local clock = 0
GameTimeManager = { getPlayingGameTime = function() return clock end }
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
AccidentManager = dofile(root .. 'AccidentManager.lua')

local function eventStamp(culprit, victim, options)
  options = options or {}
  local a, b = cars[culprit], cars[victim]
  return { index = culprit, generation = CarManager.getCarGeneration(culprit),
    victimIndex = victim, session = CarManager.sessionGeneration,
    culpritGeneration = CarManager.getCarGeneration(culprit), victimGeneration = CarManager.getCarGeneration(victim),
    positionX = a.position.x, positionY = a.position.y, positionZ = a.position.z, splinePosition = a.splinePosition,
    victimPositionX = b.position.x, victimPositionY = b.position.y, victimPositionZ = b.position.z,
    victimSplinePosition = b.splinePosition,
    culpritIsInPitlane = options.culpritIsInPitlane, victimIsInPitlane = options.victimIsInPitlane,
    culpritSpeedKmh = options.culpritSpeedKmh, victimSpeedKmh = options.victimSpeedKmh,
    culpritVelocityX = options.culpritVelocityX, culpritVelocityY = options.culpritVelocityY,
    culpritVelocityZ = options.culpritVelocityZ,
    victimVelocityX = options.victimVelocityX, victimVelocityY = options.victimVelocityY,
    victimVelocityZ = options.victimVelocityZ }
end
local function add(culprit, victim, options)
  return AccidentManager.registerCollision(culprit, vec(0, 0, 0), victim + 1, eventStamp(culprit, victim, options))
end
local function reset()
  AccidentManager.resetSession()
  table.clear(informed); table.clear(observed); table.clear(activeStops)
  for i = 0, 5 do
    cars[i].isConnected, cars[i].isActive, cars[i].isInPitlane, cars[i].isInPit = true, true, false, false
    cars[i].speedKmh, cars[i].collisionDepth = 30, 0
    cars[i].position, cars[i].splinePosition = vec(i * 2, 0, 0), .1 + i * .1
  end
  clock = 0
end
local function tick(count, dt)
  for _ = 1, count do clock = clock + dt; AccidentManager.updateRecovery(dt) end
end
local function holdClock(count, dt)
  for _ = 1, count do AccidentManager.updateRecovery(dt) end
end
local function expectPit(options, expected, label)
  reset()
  local index = assert(add(1, 2, options))
  assert(AccidentManager.accidents_pitManoeuvre[index] == expected, label .. ' pit classification')
  assert(AccidentManager.shouldAdmitIncidentStop(index) == not expected, label .. ' writer admission')
  if expected then
    assert(AccidentManager.cars_culpritInAccidentIndex[1] == nil
      and AccidentManager.cars_victimInAccidentIndex[2] == nil
      and AccidentManager.accidents_yellowFlagZoneIndex[index] == nil and #informed == 0,
      label .. ' is observation-only (no operational maps, zone or notification)')
    assert(AccidentManager.accidents_culpritIsInPitlane[index] == true
      and AccidentManager.accidents_victimIsInPitlane[index] == true
      and AccidentManager.accidents_culpritSpeedKmh[index] == options.culpritSpeedKmh
      and AccidentManager.accidents_victimSpeedKmh[index] == options.victimSpeedKmh,
      label .. ' preserves contact-time pit/speed evidence')
  else
    assert(AccidentManager.cars_culpritInAccidentIndex[1] == index
      and AccidentManager.cars_victimInAccidentIndex[2] == index
      and AccidentManager.accidents_yellowFlagZoneIndex[index] ~= nil and #informed == 1,
      label .. ' retains existing normal incident policy')
  end
end

expectPit({ culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 0, victimSpeedKmh = 15 }, true, 'inclusive 0/15 km/h')
expectPit({ culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 15.001, victimSpeedKmh = 60 }, false, 'above 15 km/h')
expectPit({ culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = -1, victimSpeedKmh = 10 }, false, 'negative speed')
expectPit({ culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 0/0, victimSpeedKmh = 10 }, false, 'NaN speed')
expectPit({ culpritIsInPitlane = true, victimIsInPitlane = false,
  culpritSpeedKmh = 10, victimSpeedKmh = 60 }, false, 'mixed pitlane flags')
expectPit({ culpritIsInPitlane = true, victimIsInPitlane = nil,
  culpritSpeedKmh = 10, victimSpeedKmh = 60 }, false, 'unknown pitlane flag')
reset()
cars[1].isInPit = true
local ownBoxRecord = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = true,
  culpritSpeedKmh = 10, victimSpeedKmh = 60 }))
assert(AccidentManager.accidents_pitManoeuvre[ownBoxRecord] == false,
  'own pit box is not pitlane evidence')

-- R1 severity gate: low relative speed with both participants moving is not an incident.
reset()
local lowSeverityBase = CompletableIndexCollectionManager.getLastIndexCreated(1)
local lowSeverityResult = add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 60, victimSpeedKmh = 55 })
assert(lowSeverityResult == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == lowSeverityBase
  and #informed == 0, 'low-severity contact creates no incident, zone or S2 admission')
local lowSeverityObservations = 0
for i = 1, #observed do
  if observed[i][1] == 'incident-rejected'
    and observed[i][6] == 'low-severity-contact-ignored' then
    lowSeverityObservations = lowSeverityObservations + 1
  end
end
assert(lowSeverityObservations == 1, 'low-severity contact emits exactly one incident-rejected observation')

-- Either participant stopped, or relative speed >= 20 km/h, stays severity-worthy.
reset()
local stoppedContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 5, victimSpeedKmh = 40 }))
assert(stoppedContact and AccidentManager.accidents_yellowFlagZoneIndex[stoppedContact] ~= nil
  and #informed == 1, 'a stopped participant makes the contact severity-worthy')
reset()
local relativeContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 40, victimSpeedKmh = 60 }))
assert(relativeContact and AccidentManager.accidents_yellowFlagZoneIndex[relativeContact] ~= nil,
  'relative speed at or above 20 km/h is severity-worthy')

-- Missing speeds stay conservative: an absent measurement never proves a free track.
reset()
local unknownSpeedContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false }))
assert(unknownSpeedContact and AccidentManager.accidents_yellowFlagZoneIndex[unknownSpeedContact] ~= nil,
  'unknown speeds conservatively create an incident and zone')

-- F1: relative speed uses collision-time velocity vectors, not equal speed magnitudes.
reset()
local headOnContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 100, victimSpeedKmh = 100,
  culpritVelocityX = 27.78, culpritVelocityY = 0, culpritVelocityZ = 0,
  victimVelocityX = -27.78, victimVelocityY = 0, victimVelocityZ = 0 }))
assert(headOnContact and AccidentManager.accidents_yellowFlagZoneIndex[headOnContact] ~= nil,
  'head-on contact with equal speed magnitudes is severity-worthy')
reset()
local tBoneContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 100, victimSpeedKmh = 100,
  culpritVelocityX = 27.78, culpritVelocityY = 0, culpritVelocityZ = 0,
  victimVelocityX = 0, victimVelocityY = 0, victimVelocityZ = 27.78 }))
assert(tBoneContact and AccidentManager.accidents_yellowFlagZoneIndex[tBoneContact] ~= nil,
  'T-bone contact with perpendicular velocity vectors is severity-worthy')
reset()
local scalarFallbackLow = add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 60, victimSpeedKmh = 55 })
assert(scalarFallbackLow == nil,
  'without velocity data the scalar |delta speed| fallback still ignores a trivial contact')
reset()
local scalarFallbackWorthy = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 40, victimSpeedKmh = 60 }))
assert(scalarFallbackWorthy and AccidentManager.accidents_yellowFlagZoneIndex[scalarFallbackWorthy] ~= nil,
  'without velocity data the scalar fallback keeps a severity-worthy contact')
reset()
local partialSpeedContact = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 40, victimSpeedKmh = 0 / 0 }))
assert(partialSpeedContact and AccidentManager.accidents_yellowFlagZoneIndex[partialSpeedContact] ~= nil,
  'one non-finite speed without velocity data stays conservative')

-- F1b: the local player as victim is always severity-worthy.
reset()
local playerVictimContact = assert(add(1, 0, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 60, victimSpeedKmh = 55 }))
assert(playerVictimContact and AccidentManager.accidents_yellowFlagZoneIndex[playerVictimContact] ~= nil
  and #informed == 1, 'a trivial contact touching the player victim still creates an incident and zone')

-- Classification is pinned to enqueue-time evidence, not mutable current car state.
reset()
cars[1].isInPitlane, cars[2].isInPitlane = false, false
cars[1].speedKmh, cars[2].speedKmh = 80, 90
local capturedPit = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 5, victimSpeedKmh = 10 }))
assert(AccidentManager.accidents_pitManoeuvre[capturedPit] == true,
  'pit classification uses callback snapshots when current SDK fields differ')

-- The public registration accepts SDK-style cdata vectors and safely rejects malformed payloads.
reset()
local Position = ffi.typeof('struct { double x; double y; double z; }')
local cdataPosition = ffi.new(Position)
cdataPosition.x, cdataPosition.y, cdataPosition.z = 1, 2, 3
local cdataIncident = assert(AccidentManager.registerCollision(1, cdataPosition, 3))
local beforeMalformed = CompletableIndexCollectionManager.getLastIndexCreated(1)
local malformedOK, malformedResult = pcall(AccidentManager.registerCollision, 1, { x = 1, y = 2 }, 4)
assert(malformedOK and malformedResult == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == beforeMalformed
  and AccidentManager.accidents_resolved[cdataIncident] == false,
  'malformed public collision payload rejects safely without registering')

-- A suppressed pit record has no reverse-map ownership and cannot block another real pair.
reset()
local pitRecord = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 5, victimSpeedKmh = 15 }))
assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == pitRecord + 1,
  'an observation-only pit record does not reserve its culprit for an independent collision')

-- Same validated pair in normal context promotes the old record exactly once.
reset()
local promoted = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 0, victimSpeedKmh = 15 }))
local stalePromotionStamp = eventStamp(2, 1, { culpritIsInPitlane = false,
  victimIsInPitlane = false, culpritSpeedKmh = 30, victimSpeedKmh = 35 })
stalePromotionStamp.session = CarManager.sessionGeneration + 1
assert(AccidentManager.registerCollision(2, vec(0, 0, 0), 2, stalePromotionStamp) == nil
  and AccidentManager.accidents_pitManoeuvre[promoted] == true
  and AccidentManager.accidents_yellowFlagZoneIndex[promoted] == nil,
  'stale identity cannot reset or promote a pit observation')
assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 35 }) == promoted,
  'normal contact in reversed order promotes the original pit record ID')
assert(AccidentManager.accidents_pitManoeuvre[promoted] == false
  and AccidentManager.cars_culpritInAccidentIndex[1] == promoted
  and AccidentManager.cars_victimInAccidentIndex[2] == promoted
  and AccidentManager.accidents_yellowFlagZoneIndex[promoted] ~= nil and #informed == 1
  and AccidentManager.shouldAdmitIncidentStop(promoted),
  'promotion creates the normal risk/participants and notification once')
local lastIndex = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 35, victimSpeedKmh = 30 }) == nil
  and add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
    culpritSpeedKmh = 35, victimSpeedKmh = 30 }) == nil,
  'existing duplicate/reversed-pair policy rejects post-promotion repeats')
assert(CompletableIndexCollectionManager.getLastIndexCreated(1) == lastIndex and #informed == 1,
  'post-promotion repeats do not allocate IDs or extend notification')

-- F4: the severity rule also governs the pit-record fall-through (promotion above keeps priority).
reset()
local fallbackPit = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 5, victimSpeedKmh = 10 }))
local fallbackOwner = assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local fallbackBase = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 60, victimSpeedKmh = 55 }) == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == fallbackBase
  and AccidentManager.accidents_pitManoeuvre[fallbackPit] == true
  and AccidentManager.accidents_yellowFlagZoneIndex[fallbackPit] == nil,
  'trivial contact on a pit-record fall-through creates no record and no zone')
local fallbackWorthy = assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(fallbackWorthy ~= fallbackPit and AccidentManager.accidents_pitManoeuvre[fallbackPit] == true
  and AccidentManager.accidents_yellowFlagZoneIndex[fallbackWorthy] ~= nil,
  'severity-worthy contact on the same fall-through creates the normal record and zone')
assert(fallbackOwner ~= fallbackWorthy and AccidentManager.cars_culpritInAccidentIndex[1] == fallbackOwner,
  'the fall-through never overwrites independent culprit ownership')

-- Reversed promotion must not overwrite a participant's independent culprit ownership.
reset()
local rolePit = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 5, victimSpeedKmh = 10 }))
local independent = assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local independentZone = AccidentManager.accidents_yellowFlagZoneIndex[independent]
local unpromoted = assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(unpromoted ~= rolePit and AccidentManager.accidents_pitManoeuvre[rolePit] == true
  and AccidentManager.accidents_yellowFlagZoneIndex[rolePit] == nil
  and AccidentManager.cars_culpritInAccidentIndex[1] == independent
  and AccidentManager.cars_victimInAccidentIndex[1] == unpromoted
  and AccidentManager.accidents_yellowFlagZoneIndex[independent] == independentZone
  and AccidentManager.accidents_yellowFlagZoneIndex[unpromoted] ~= nil,
  'conflicting promotion falls back to an actionable normal record without overwriting independent ownership')
local beforePairRepeat = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and add(2, 1, { culpritIsInPitlane = true, victimIsInPitlane = true,
    culpritSpeedKmh = 5, victimSpeedKmh = 10 }) == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == beforePairRepeat,
  'active fallback normal record takes priority over its older pit record for normal and pit repeats')
cars[3].speedKmh = 5
tick(13, .25)
assert(AccidentManager.accidents_resolved[unpromoted] == true
  and AccidentManager.accidents_resolved[independent] == false
  and AccidentManager.cars_culpritInAccidentIndex[1] == independent
  and AccidentManager.cars_victimInAccidentIndex[1] == nil
  and RaceTrackManager.getYellowZoneReadOnly(independentZone).resolved == false,
  'resolving the fallback retains the independent culprit link and its unresolved zone')
local beforeBlockedIncident = CompletableIndexCollectionManager.getLastIndexCreated(1)
local thirdPair = assert(add(1, 4, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(thirdPair ~= independent and thirdPair ~= rolePit
  and AccidentManager.cars_culpritInAccidentIndex[1] == thirdPair
  and AccidentManager.cars_victimInAccidentIndex[3] == independent,
  'an active independent A→C pair is admitted despite A already owning A→B; role maps remain compatibility hints')
assert(CompletableIndexCollectionManager.getLastIndexCreated(1) > beforeBlockedIncident,
  'independent pair receives a new incident ID')
local lastAfterThirdPair = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(add(4, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and add(1, 4, { culpritIsInPitlane = false, victimIsInPitlane = false,
    culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == lastAfterThirdPair,
  'same active pair is deduplicated in either callback order after role-map overwrite')

-- Independent normal pairs survive owner-map overwrite, then resolve independently.
reset()
local pairAB = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local pairAC = assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(pairAB ~= pairAC and AccidentManager.cars_culpritInAccidentIndex[1] == pairAC
  and AccidentManager.cars_victimInAccidentIndex[2] == pairAB,
  'A→B and A→C coexist while scalar ownership maps remain compatibility hints')
local pairCount = CompletableIndexCollectionManager.getLastIndexCreated(1)
assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
    culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and CompletableIndexCollectionManager.getLastIndexCreated(1) == pairCount,
  'unordered pair identity deduplicates after role-map overwrite')
AccidentManager.informAboutCarReset(3)
assert(AccidentManager.accidents_resolved[pairAC] == true
  and AccidentManager.accidents_resolved[pairAB] == false
  and AccidentManager.cars_culpritInAccidentIndex[1] == nil
  and AccidentManager.cars_victimInAccidentIndex[2] == pairAB
  and RaceTrackManager.getYellowZoneReadOnly(AccidentManager.accidents_yellowFlagZoneIndex[pairAB]).resolved == false,
  'resolving the newer shared-culprit record clears its map but preserves the older link and zone')
assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and AccidentManager.accidents_resolved[pairAB] == false,
  'resolving the newer pair never makes an older still-active pair duplicable')
AccidentManager.informAboutCarReset(2)
assert(AccidentManager.accidents_resolved[pairAB] == true
  and AccidentManager.cars_victimInAccidentIndex[2] == nil,
  'older pair cleanup removes only its own remaining role ownership')

-- The opposite resolution order also retains the other record and its independent zone.
reset()
pairAB = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
pairAC = assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local retainedZone = AccidentManager.accidents_yellowFlagZoneIndex[pairAC]
AccidentManager.informAboutCarReset(2)
assert(AccidentManager.accidents_resolved[pairAB] == true
  and AccidentManager.accidents_resolved[pairAC] == false
  and RaceTrackManager.getYellowZoneReadOnly(retainedZone).resolved == false
  and AccidentManager.cars_culpritInAccidentIndex[1] == pairAC,
  'resolving A→B first leaves A→C ownership and its yellow zone active')

-- Valid duplicate contact resets LC1 even when the culprit role map points at another pair.
reset()
pairAB = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
pairAC = assert(add(1, 3, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local zoneAB, zoneAC = AccidentManager.accidents_yellowFlagZoneIndex[pairAB], AccidentManager.accidents_yellowFlagZoneIndex[pairAC]
tick(8, .25)
assert(add(2, 1, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }) == nil
  and AccidentManager.cars_culpritInAccidentIndex[1] == pairAC,
  'validated duplicate contact is rejected by pair records despite the culprit map naming A→C')
tick(12, .25)
assert(AccidentManager.accidents_resolved[pairAB] == false
  and AccidentManager.accidents_resolved[pairAC] == false
  and RaceTrackManager.getYellowZoneReadOnly(zoneAB).resolved == false
  and RaceTrackManager.getYellowZoneReadOnly(zoneAC).resolved == false,
  'contact resets both relevant LC1 windows without resolving either independent risk')
tick(1, .25)
assert(AccidentManager.accidents_resolved[pairAB] == true
  and AccidentManager.accidents_resolved[pairAC] == true,
  'both independent windows complete only after fresh post-contact continuity')

reset()
local oldGenerationPair = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
CarManager.carGeneration[1] = CarManager.getCarGeneration(1) + 1
local currentGenerationPair = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(currentGenerationPair ~= oldGenerationPair
  and AccidentManager.accidents_resolved[oldGenerationPair] == false,
  'a pair from an obsolete participant generation cannot deduplicate current identity')

reset()
local oldSessionPair = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
CarManager.sessionGeneration = CarManager.sessionGeneration + 1
local currentSessionPair = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
assert(currentSessionPair ~= oldSessionPair
  and AccidentManager.accidents_resolved[oldSessionPair] == false,
  'a pair from an obsolete session cannot deduplicate a current-session contact')
CarManager.sessionGeneration = CarManager.sessionGeneration - 1

-- Recovery resolves on absence of obstruction inside the incident's own zone band.
reset()
local incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
assert(incidentZone ~= nil, 'severity-worthy contact owns a yellow zone')
cars[1].speedKmh, cars[2].speedKmh = 19.99, 20
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'moving participants resolve after 3 continuous valid seconds regardless of absolute speed')

-- A participant stopped inside its own zone band keeps the incident and zone beyond 3 seconds.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[1].speedKmh = 5
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'stopped participant inside the zone keeps the incident and zone')
cars[1].speedKmh = 6
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a participant that starts moving removes the zone after 3 valid seconds')

-- Leaving the zone band is absence even while stopped.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[1].speedKmh, cars[1].splinePosition = 0, .9
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a stopped participant outside the zone band does not obstruct resolution')

-- Disconnecting a stopped participant is valid absence, not a permanent obstruction.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[1].speedKmh = 5
tick(8, .25)
cars[1].isConnected = false
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a disconnected stopped participant is absence, not an obstruction')

-- Unreadable participant data keeps the zone.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[1].speedKmh = 5
cars[2].speedKmh = 0 / 0
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'unreadable participant speed keeps the zone')
cars[2].speedKmh = 60
cars[2].splinePosition = 0 / 0
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false,
  'unreadable participant spline keeps the zone')
cars[2].splinePosition = .3
cars[1].speedKmh = 60
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'readable absence after unreadable data resolves on a fresh full window')

-- Positive collision depth is an obstruction.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[2].collisionDepth = .01
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'participant still in contact keeps the zone')
cars[2].collisionDepth = 0
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'contact release permits resolution after a full valid window')

-- F3: any stopped non-pit car inside the band obstructs, not only the incident participants.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[4].splinePosition, cars[4].speedKmh = .25, 0
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'a third stopped car inside the band keeps the zone')
cars[4].speedKmh = 30
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a moving third car allows resolution after a full valid window')

-- Pit cars are isolated from track obstruction.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[4].splinePosition, cars[4].speedKmh, cars[4].isInPitlane = .25, 0, true
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a stopped car in the pitlane is not a track obstruction')
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[4].splinePosition, cars[4].speedKmh, cars[4].isInPit = .25, 0, true
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'a stopped car in its own pit box is not a track obstruction')

-- An unavailable car count is invalid data, never proof of a free track.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
sim.carsCount = nil
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'unavailable carsCount keeps the zone')
sim.carsCount = 6
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'readable carsCount permits resolution after a full valid window')

-- F2: a wreck that rolled just past the band end stays an obstruction inside the forward tolerance.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[2].speedKmh, cars[2].splinePosition = 0, .303
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'stopped participant within the 25 m forward tolerance keeps the zone')
cars[2].splinePosition = .31
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'stopped participant beyond the 25 m forward tolerance resolves')

-- Independent incidents resolve independently; one stopped participant freezes only its own zone.
reset()
local firstIndependent = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local secondIndependent = assert(add(4, 5, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local firstIndependentZone = AccidentManager.accidents_yellowFlagZoneIndex[firstIndependent]
local secondIndependentZone = AccidentManager.accidents_yellowFlagZoneIndex[secondIndependent]
assert(firstIndependentZone ~= secondIndependentZone, 'independent incidents own independent zones')
cars[4].speedKmh = 5
tick(13, .25)
assert(AccidentManager.accidents_resolved[firstIndependent] == true
  and AccidentManager.accidents_resolved[secondIndependent] == false
  and RaceTrackManager.getYellowZoneReadOnly(firstIndependentZone).resolved == true
  and RaceTrackManager.getYellowZoneReadOnly(secondIndependentZone).resolved == false,
  'a stopped participant freezes only its own incident zone')
cars[4].speedKmh = 60
tick(13, .25)
assert(AccidentManager.accidents_resolved[secondIndependent] == true
  and RaceTrackManager.getYellowZoneReadOnly(secondIndependentZone).resolved == true,
  'the second independent incident resolves once its participant moves')

-- An unreadable participant position is invalid data, never proof of absence.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
cars[2].position = nil
tick(1, .25)
cars[2].position = vec(4, 0, 0)
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'three seconds of consecutive complete recovery evidence resolves once')
local notificationsBeforeRepeat = #observed
AccidentManager.informAboutCarReset(1)
assert(#observed == notificationsBeforeRepeat, 'repeated resolution/reset is idempotent')

-- Unknown participant state is invalid data, never proof of absence.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[2].isConnected = nil
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'unknown isConnected is invalid data and keeps the zone')
cars[2].isConnected = true
cars[2].isActive = nil
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false,
  'unknown isActive is invalid data and keeps the zone')
cars[2].isActive = true
cars[2].position = nil
tick(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == false,
  'a present participant without a readable position keeps the zone')
cars[2].position = vec(4, 0, 0)
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'readable state after unknown data resolves on a fresh full window')

-- Explicit absence (disconnected or missing car) remains a valid observation.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
cars[2].isConnected = false
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'an explicitly disconnected participant is valid absence')
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
incidentZone = AccidentManager.accidents_yellowFlagZoneIndex[incident]
local absentVictim = cars[2]
cars[2] = nil
tick(13, .25)
cars[2] = absentVictim
assert(AccidentManager.accidents_resolved[incident] == true
  and RaceTrackManager.getYellowZoneReadOnly(incidentZone).resolved == true,
  'a missing participant car is valid absence')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
holdClock(20, .25)
assert(AccidentManager.accidents_resolved[incident] == false,
  'repeated callbacks with a frozen active clock accrue no recovery time')
tick(5, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'recovery resumes from the frozen active-clock duration')

-- Active stop, identity/session staleness, duplicate fresh contact and bad dt all reset continuity.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(10, .25)
activeStops[1] = true
tick(1, .25)
activeStops[1] = false
tick(12, .25)
assert(AccidentManager.accidents_resolved[incident] == false,
  'active S2 episode interrupts recovery including pending-handoff guard')
local registeredBeforeDuplicate = CompletableIndexCollectionManager.getLastIndexCreated(1)
local duplicateResult = add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 })
assert(duplicateResult == nil and CompletableIndexCollectionManager.getLastIndexCreated(1) == registeredBeforeDuplicate,
  'a validated duplicate contact is rejected after resetting recovery continuity: result='
    .. tostring(duplicateResult) .. ' last=' .. tostring(CompletableIndexCollectionManager.getLastIndexCreated(1)))
tick(12, .25)
assert(AccidentManager.accidents_resolved[incident] == false, 'duplicate contact restarts the full recovery window')
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true, 'recovery resumes only after another full window')

-- An invalid identity must not clear an otherwise continuous recovery window.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
local staleContact = eventStamp(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 })
staleContact.victimGeneration = staleContact.victimGeneration + 1
assert(AccidentManager.registerCollision(1, vec(0, 0, 0), 3, staleContact) == nil,
  'stale contact is rejected before resetting recovery')
tick(5, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'rejected stale identity preserves the prior valid recovery window')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
holdClock(1, .25) -- establishes the initial valid sample without credit
clock = clock + .2
AccidentManager.updateRecovery(.1) -- clock advanced farther than supplied dt: reset
clock = clock + .05
AccidentManager.updateRecovery(.1)
for _ = 1, 58 do clock = clock + .05; AccidentManager.updateRecovery(.25) end
assert(AccidentManager.accidents_resolved[incident] == false,
  'clock/dt mismatch resets continuity without crediting the larger dt')
clock = clock + .05
AccidentManager.updateRecovery(.25)
clock = clock + .05
AccidentManager.updateRecovery(.25)
clock = clock + .05
AccidentManager.updateRecovery(.25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'bounded active-clock deltas, not supplied dt, certify continuous recovery')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(10, .25)
AccidentManager.updateRecovery(.251)
tick(12, .25)
assert(AccidentManager.accidents_resolved[incident] == false,
  'invalid dt >.25 breaks continuity without certifying a gap')
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true, 'bounded dt continuity eventually completes')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(10, .25)
clock = clock - 1
AccidentManager.updateRecovery(.25)
tick(12, .25)
assert(AccidentManager.accidents_resolved[incident] == false, 'clock rollback resets recovery continuity')
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == true, 'clock resumes with a fresh full interval')

local function assertInvalidRecoveryBreaksContinuity(change, restore, label)
  reset()
  local index = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
    culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
  tick(8, .25)
  change()
  tick(1, .25)
  restore()
  tick(12, .25)
  assert(AccidentManager.accidents_resolved[index] == false, label .. ' interrupts recovery continuity')
  tick(13, .25)
  assert(AccidentManager.accidents_resolved[index] == true, label .. ' permits a new full valid window')
end

assertInvalidRecoveryBreaksContinuity(function() cars[1].speedKmh = 0/0 end,
  function() cars[1].speedKmh = 30 end, 'NaN speed')
assertInvalidRecoveryBreaksContinuity(function() cars[2].collisionDepth = 0/0 end,
  function() cars[2].collisionDepth = 0 end, 'NaN collision depth')

-- Disconnection and inactivity are valid absence observations under the new criterion.
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
cars[2].isConnected = false
tick(5, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'disconnected participant counts as absence and permits resolution')
reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
cars[2].isActive = false
tick(5, .25)
assert(AccidentManager.accidents_resolved[incident] == true,
  'inactive participant counts as absence and permits resolution')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
CarManager.carGeneration[2] = 1
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == false, 'stale participant generation never certifies recovery')

reset()
incident = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
tick(8, .25)
CarManager.sessionGeneration = CarManager.sessionGeneration + 1
tick(13, .25)
assert(AccidentManager.accidents_resolved[incident] == false, 'stale session generation never certifies recovery')
CarManager.sessionGeneration = CarManager.sessionGeneration - 1

reset()
local pitRecovery = assert(add(1, 2, { culpritIsInPitlane = true, victimIsInPitlane = true,
  culpritSpeedKmh = 0, victimSpeedKmh = 15 }))
cars[1].speedKmh, cars[2].speedKmh = 5, 5
tick(13, .25)
assert(AccidentManager.accidents_resolved[pitRecovery] == true,
  'observation-only pit record uses the 5 km/h recovery threshold')

-- Shared-victim independent incidents resolve independently and remove each owned zone once.
reset()
local first = assert(add(1, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local second = assert(add(3, 2, { culpritIsInPitlane = false, victimIsInPitlane = false,
  culpritSpeedKmh = 30, victimSpeedKmh = 60 }))
local firstZone, secondZone = AccidentManager.accidents_yellowFlagZoneIndex[first], AccidentManager.accidents_yellowFlagZoneIndex[second]
assert(firstZone ~= secondZone, 'shared-victim incidents retain independent zone IDs')
cars[3].speedKmh = 5
tick(13, .25)
assert(AccidentManager.accidents_resolved[first] == true and AccidentManager.accidents_resolved[second] == false
  and RaceTrackManager.getYellowZoneReadOnly(firstZone).resolved == true
  and RaceTrackManager.getYellowZoneReadOnly(secondZone).resolved == false
  and AccidentManager.cars_victimInAccidentIndex[2] == second,
  'resolving one shared-victim incident retains the other zone and reverse-map owner')
AccidentManager.informAboutCarReset(1)
assert(AccidentManager.accidents_resolved[second] == false
  and RaceTrackManager.getYellowZoneReadOnly(secondZone).resolved == false
  and AccidentManager.cars_victimInAccidentIndex[2] == second,
  'repeated cleanup of the first incident does not clear the second incident')
cars[3].speedKmh = 20
tick(13, .25)
assert(AccidentManager.accidents_resolved[second] == true
  and RaceTrackManager.getYellowZoneReadOnly(secondZone).resolved == true
  and AccidentManager.cars_victimInAccidentIndex[2] == nil,
  'the remaining shared-victim incident resolves and cleans its own ownership')
local finalObserverCount = #observed
tick(13, .25)
assert(#observed == finalObserverCount, 'already-resolved records are not resolved twice')

print('test_incident_recovery: PASS')
