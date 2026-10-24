local root = (arg[0]:gsub('tools[\\/]test_incident_cleanup.lua$', ''))
package.path = root .. '?.lua;' .. root .. '?/init.lua;' .. package.path

CompletableIndexCollectionManager = dofile(root .. 'DataStructures/CompletableIndexCollectionManager.lua')
local sim = { trackLengthM = 5000, raceSessionType = 1 }
ac = { SessionType = { Undefined = 0, Practice = 1, Qualify = 2, Race = 3, Hotlap = 4,
    TimeAttack = 5, Drift = 6, Drag = 7 }, getSim = function() return sim end,
  getTrackName = function() return 'test-track' end }
local cars = {}
for i = 0, 5 do
  cars[i] = { index = i, position = { x = i, y = 0, z = 0 }, splinePosition = .1 + i * .1 }
end
ac.getCar = function(index) return cars[index] end
StorageManager = { getStorage = function() return { distanceFromAccidentToSeeYellowFlag_meters = 100 } end }
Logger = { log = function() end }
vec3 = function(x, y, z) return { x = x, y = y, z = z } end
CarManager = { getCarGeneration = function() return 0 end,
  isWritableAICar = function(index) return index ~= 0 end }
local writes = {}
CarOperations = { toggleCarCollisions = function(index) writes[#writes + 1] = index end }
CarStateMachine = { CarStateType = { NAVIGATING_AROUND_ACCIDENT = 8192 },
  getCurrentState = function() end, informAboutAccident = function() end }
RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
AccidentManager = dofile(root .. 'AccidentManager.lua')

local function add(culprit, victim)
  return AccidentManager.registerCollision(culprit, { x = 0, y = 0, z = 0 }, victim + 1)
end
local function addTrack(culprit)
  -- register a real incident/zone, then model a track-contact record (whose victim field is nil).
  local incident = add(culprit, 5)
  AccidentManager.accidents_collidedWithTrack[incident] = true
  AccidentManager.accidents_collidedWithCarIndex[incident] = nil
  AccidentManager.cars_victimInAccidentIndex[5] = nil
  return incident
end
local first = add(1, 2) -- A -> B
local second = add(3, 2) -- C -> B; reverse victim map now points only here
local mixed = add(2, 4) -- B also appears as a culprit
local survivor = add(5, 4)
assert(first and second and mixed and survivor)
local function assertClean(index)
  assert(AccidentManager.accidents_resolved[index] == true, 'incident #' .. index .. ' resolved')
end
local zones = {}
for i, index in ipairs({ first, second, mixed, survivor }) do
  zones[i] = AccidentManager.accidents_yellowFlagZoneIndex[index]
end
local zoneIDPresent = function(zoneID)
  for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
    for i = 1, #bucket do if bucket[i] == zoneID then return true end end
  end
  return false
end
local function assertZoneIDs(removed, retained)
  for _, zoneID in ipairs(removed) do
    assert(not zoneIDPresent(zoneID), 'resolved zone ID is absent from every real bucket')
  end
  for _, zoneID in ipairs(retained) do
    assert(zoneIDPresent(zoneID), 'active zone ID remains in a real bucket')
  end
end
local originalProximity = AccidentManager.isCarComingUpToAccident
local proximityCalls = 0
AccidentManager.isCarComingUpToAccident = function(...)
  proximityCalls = proximityCalls + 1
  return originalProximity(...)
end
assert(RaceTrackManager.isSplinePositionInYellowZone(cars[2].splinePosition)
  and RaceTrackManager.isSplinePositionInYellowZone(cars[4].splinePosition))
assertZoneIDs({}, { zones[1], zones[2], zones[3], zones[4] })
local writesBefore = #writes
AccidentManager.informAboutCarReset(2)
assert(proximityCalls == 0, 'reset does not invoke AccidentManager proximity lookup')
assert(#writes == writesBefore, 'cleanup is memory-only')
assertClean(first); assertClean(second); assertClean(mixed)
assert(AccidentManager.accidents_resolved[survivor] == false, 'unrelated incident remains active')
assert(AccidentManager.cars_victimInAccidentIndex[2] == nil
  and AccidentManager.cars_culpritInAccidentIndex[2] == nil, 'reset links removed')
assert(AccidentManager.cars_culpritInAccidentIndex[5] == survivor
  and AccidentManager.cars_victimInAccidentIndex[4] == survivor,
  'surviving incident reverse links remain intact')
assertZoneIDs({ zones[1], zones[2], zones[3] }, { zones[4] })
AccidentManager.informAboutCarReset(2)
assert(AccidentManager.accidents_resolved[survivor] == false, 'repeated reset preserves unrelated incident')
assertZoneIDs({ zones[1], zones[2], zones[3] }, { zones[4] })

local trackIncident = addTrack(1)
local trackZone = AccidentManager.accidents_yellowFlagZoneIndex[trackIncident]
local function invalidStateSnapshot()
  return AccidentManager.accidents_carIndex[survivor], AccidentManager.accidents_carIndex[trackIncident],
    AccidentManager.accidents_collidedWithTrack[trackIncident],
    AccidentManager.accidents_collidedWithCarIndex[trackIncident],
    AccidentManager.cars_culpritInAccidentIndex[5], AccidentManager.cars_culpritInAccidentIndex[1],
    AccidentManager.accidents_yellowFlagZoneIndex[survivor], AccidentManager.accidents_yellowFlagZoneIndex[trackIncident]
end
local function assertInvalidStateUnchanged(before, label)
  assert(AccidentManager.accidents_resolved[survivor] == false
    and AccidentManager.accidents_resolved[trackIncident] == false, label .. ' preserves active incidents')
  assert(AccidentManager.accidents_carIndex[survivor] == before[1]
    and AccidentManager.accidents_carIndex[trackIncident] == before[2]
    and AccidentManager.accidents_collidedWithTrack[trackIncident] == before[3]
    and AccidentManager.accidents_collidedWithCarIndex[trackIncident] == before[4]
    and AccidentManager.cars_culpritInAccidentIndex[5] == before[5]
    and AccidentManager.cars_culpritInAccidentIndex[1] == before[6]
    and AccidentManager.accidents_yellowFlagZoneIndex[survivor] == before[7]
    and AccidentManager.accidents_yellowFlagZoneIndex[trackIncident] == before[8], label .. ' preserves payload and links')
  assertZoneIDs({ zones[1], zones[2], zones[3] }, { zones[4], trackZone })
end
local invalidIndices = { '1', true, {}, 0/0, -1, 1.5, math.huge, -math.huge }
local beforeInvalid = { invalidStateSnapshot() }
for i = 1, #invalidIndices do
  local before = #writes
  AccidentManager.informAboutCarReset(invalidIndices[i])
  assert(#writes == before, 'invalid reset index performs no writes')
  assertInvalidStateUnchanged(beforeInvalid, 'invalid reset index')
end
-- nil cannot be stored in an ipairs array; exercise it explicitly against the active nil-victim record.
local beforeNilWrites = #writes
AccidentManager.informAboutCarReset(nil)
assert(#writes == beforeNilWrites, 'nil reset index performs no writes')
assertInvalidStateUnchanged(beforeInvalid, 'nil reset index')
AccidentManager.informAboutCarReset(1)
assert(AccidentManager.accidents_resolved[trackIncident] == true,
  'valid culprit reset resolves the active track-contact record')

-- Mocked writer predicate being false does not gate memory-only reset cleanup.
local writerAllowed = true
CarManager.isWritableAICar = function(index) return writerAllowed and index ~= 0 end
for _, scenario in ipairs({
  { index = 0, gate = false }, -- player observation
  { index = 1, gate = false }, -- permission denied
  { index = 3, gate = false }, -- human/absent-style observation
}) do
  local index = scenario.index
  writerAllowed = true
  local incident = add(index == 1 and 1 or 3, index)
  writerAllowed = scenario.gate
  local before = #writes
  AccidentManager.informAboutCarReset(index)
  assert(AccidentManager.accidents_resolved[incident] == true)
  assert(#writes == before, 'observation cleanup must not write controls')
end
writerAllowed = true
local nextIncident = add(1, 4)
assert(nextIncident > survivor and AccidentManager.accidents_resolved[survivor] == false,
  'resolved incident IDs are not reused')
print('test_incident_cleanup: PASS')
