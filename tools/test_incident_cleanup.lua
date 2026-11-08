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
local storage = { distanceFromAccidentToSeeYellowFlag_meters = 100 }
StorageManager = { getStorage = function() return storage end }
local observations = 0
Logger = { log = function() end, observe = function() observations = observations + 1 end }
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
assert(type(RaceTrackManager.getYellowZoneReadOnly) == 'function', 'read-only yellow-zone snapshot API exists')
assert(zones[1] ~= zones[2] and zones[2] ~= zones[3] and zones[3] ~= zones[4],
  'fixture uses distinct zone IDs for incidents sharing nearby splines')
local zoneSnapshots = {}
for i, incidentIndex in ipairs({ first, second, mixed, survivor }) do
  local zone = RaceTrackManager.getYellowZoneReadOnly(zones[i])
  assert(zone and zone.zone == zones[i] and zone.incident == incidentIndex and zone.resolved == false
    and type(zone.startSplinePosition) == 'number' and type(zone.endSplinePosition) == 'number',
    'read-only getter returns registered incident and raw bounds for zone #' .. zones[i])
  zoneSnapshots[i] = zone
end
local aliasProbe = RaceTrackManager.getYellowZoneReadOnly(zones[1])
aliasProbe.zone, aliasProbe.incident, aliasProbe.startSplinePosition = -99, -99, 999
aliasProbe.endSplinePosition, aliasProbe.resolved = -999, true
local unmodifiedZone = RaceTrackManager.getYellowZoneReadOnly(zones[1])
assert(unmodifiedZone.zone == zones[1] and unmodifiedZone.incident == first and unmodifiedZone.resolved == false
  and unmodifiedZone.startSplinePosition == zoneSnapshots[1].startSplinePosition
  and unmodifiedZone.endSplinePosition == zoneSnapshots[1].endSplinePosition,
  'mutating returned zone snapshot cannot mutate operational zone storage')
for _, invalidZoneID in ipairs({ 0, -1, 1.5, 0 / 0, math.huge, -math.huge, '1', true, {} }) do
  assert(RaceTrackManager.getYellowZoneReadOnly(invalidZoneID) == nil, 'invalid zone ID returns nil safely')
end
assert(RaceTrackManager.getYellowZoneReadOnly(nil) == nil, 'nil zone ID returns nil safely')
local zoneIDPresent = function(zoneID)
  for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
    for i = 1, #bucket do if bucket[i] == zoneID then return true end end
  end
  return false
end
local function zonesShareBucket(firstZone, secondZone)
  for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
    local hasFirst, hasSecond = false, false
    for i = 1, #bucket do
      if bucket[i] == firstZone then hasFirst = true end
      if bucket[i] == secondZone then hasSecond = true end
    end
    if hasFirst and hasSecond then return true end
  end
  return false
end
assert(zonesShareBucket(zones[1], zones[2]), 'two distinct incident zones overlap in real indexed buckets')
assert(zoneIDPresent(zones[1]) and AccidentManager.accidents_yellowFlagZoneIndex[first] == zones[1]
  and AccidentManager.accidents_resolved[first] == false,
  'snapshot alias mutation leaves actual bucket membership and incident links unchanged')
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
for i = 1, 3 do
  local resolvedZone = RaceTrackManager.getYellowZoneReadOnly(zones[i])
  assert(resolvedZone and resolvedZone.zone == zones[i] and resolvedZone.resolved == true
    and resolvedZone.incident == nil and resolvedZone.startSplinePosition == nil
    and resolvedZone.endSplinePosition == nil,
    'resolved known zone remains readable with cleared payload: #' .. zones[i])
end
local survivingZone = RaceTrackManager.getYellowZoneReadOnly(zones[4])
assert(survivingZone and survivingZone.incident == survivor and survivingZone.resolved == false
  and zoneIDPresent(zones[4]), 'overlapping independent surviving zone snapshot remains registered')
AccidentManager.informAboutCarReset(2)
assert(AccidentManager.accidents_resolved[survivor] == false, 'repeated reset preserves unrelated incident')
assertZoneIDs({ zones[1], zones[2], zones[3] }, { zones[4] })
assert(RaceTrackManager.getYellowZoneReadOnly(zones[1]).resolved == true
  and RaceTrackManager.getYellowZoneReadOnly(zones[4]).resolved == false,
  'idempotent cleanup preserves resolved and independent active snapshots')

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
AccidentManager.informAboutCarReset(1)
local previousZoneID = zones[1]
RaceTrackManager.resetOwnedYellowFlagZones()
local afterZoneReset = RaceTrackManager.getYellowZoneReadOnly(previousZoneID)
assert(afterZoneReset and afterZoneReset.resolved == true and afterZoneReset.incident == nil
  and afterZoneReset.startSplinePosition == nil and afterZoneReset.endSplinePosition == nil,
  'known resolved zone remains readable after manager index reset')
local reuseIncident = add(2, 3)
local reusedZoneID = AccidentManager.accidents_yellowFlagZoneIndex[reuseIncident]
local reusedZone = RaceTrackManager.getYellowZoneReadOnly(reusedZoneID)
assert(reusedZoneID == 1 and reusedZone and reusedZone.incident == reuseIncident
  and reusedZone.resolved == false and reusedZone.generation == nil and reusedZone.session == nil,
  'reused zone ID reports current raw association without inventing origin-session identity')

-- Inventory pagination counts examined IDs (including resolved entries) and restarts stale cursors.
local inventoryIDs = {}
for i = 1, 36 do
  local incident = assert(add(1, 5))
  inventoryIDs[i] = AccidentManager.accidents_yellowFlagZoneIndex[incident]
  AccidentManager.informAboutCarReset(1)
end
local page1 = assert(RaceTrackManager.getYellowZoneInventoryReadOnly(nil))
assert(page1.scanned == 32 and not page1.complete and page1.nextCursor == 33
  and page1.zones[1].resolved == false and page1.zones[2].resolved == true,
  'inventory scans at most 32 IDs and includes resolved zone IDs in examined range')
local page2 = assert(RaceTrackManager.getYellowZoneInventoryReadOnly(page1.nextCursor, page1.epoch, page1.revision))
assert(page2.scanned <= 32 and page2.complete, 'inventory completes with bounded second page')
local stalePage = assert(RaceTrackManager.getYellowZoneInventoryReadOnly(page1.nextCursor, page1.epoch, page1.revision - 1))
assert(stalePage.restarted and stalePage.cursor == 1, 'revision-stale cursor restarts at first ID')
local staleEpoch = assert(RaceTrackManager.getYellowZoneInventoryReadOnly(page1.nextCursor, page1.epoch - 1, page1.revision))
assert(staleEpoch.restarted and staleEpoch.cursor == 1, 'epoch-stale cursor restarts at first ID')
local coverage = assert(RaceTrackManager.getYellowZoneCoverageReadOnly(cars[3].splinePosition))
assert(coverage.scanned <= 32 and (coverage.covered == false or coverage.covered == true or coverage.covered == nil),
  'geometric coverage is bounded and tri-state')
local inventoryAlias = page1.zones[1]
if inventoryAlias then
  local originalID = inventoryAlias.zone
  inventoryAlias.zone = -100
  assert(RaceTrackManager.getYellowZoneInventoryReadOnly(1).zones[1].zone == originalID,
    'inventory results do not alias zone storage')
end
local revisionBeforeBounds = RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision
local movingIncident = assert(add(1, 5))
local movingZone = AccidentManager.accidents_yellowFlagZoneIndex[movingIncident]
AccidentManager.accidents_splinePosition[movingIncident] = .02
AccidentManager.accidents_victimSplinePosition[movingIncident] = .01
RaceTrackManager.updateYellowFlagZones()
local revisionAfterBounds = RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision
assert(revisionAfterBounds > revisionBeforeBounds, 'bounds updates advance inventory revision')
local wrapCoverage = assert(RaceTrackManager.getYellowZoneCoverageReadOnly(.995))
assert(wrapCoverage.covered == true and RaceTrackManager.isSplinePositionInYellowZone(.995),
  'wraparound zone coverage matches the operational check across spline zero')
local bucket18 = RaceTrackManager.yellowFlagsZones_bucket[18]
local crowdedBucket = {}
for i = 1, 33 do crowdedBucket[i] = movingZone end
RaceTrackManager.yellowFlagsZones_bucket[18] = crowdedBucket
local partialCoverage = assert(RaceTrackManager.getYellowZoneCoverageReadOnly(.9))
assert(partialCoverage.scanned == 32 and partialCoverage.total == 33 and partialCoverage.limited
  and partialCoverage.covered == nil, 'partial negative coverage is unknown after the 32-entry bound')
RaceTrackManager.yellowFlagsZones_bucket[18] = bucket18

-- Register both wrap orientations from event-time cars (not post-registration table edits).
local function newWrap(culpritSpline, victimSpline)
  AccidentManager.resetSession()
  storage.distanceFromAccidentToSeeYellowFlag_meters = 100
  cars[1].splinePosition, cars[2].splinePosition = culpritSpline, victimSpline
  local incident = assert(add(1, 2))
  return incident, AccidentManager.accidents_yellowFlagZoneIndex[incident]
end
local wrapA, wrapZoneA = newWrap(.999, .001)
local wrapBoundsA = assert(RaceTrackManager.getYellowZoneReadOnly(wrapZoneA))
assert(math.abs(wrapBoundsA.startSplinePosition - .979) < 1e-9 and wrapBoundsA.endSplinePosition == .001,
  '.999/.001 registration stores its shortest wrap arc and backwards padding')
assert(RaceTrackManager.isSplinePositionInYellowZone(.979)
  and RaceTrackManager.isSplinePositionInYellowZone(.001)
  and RaceTrackManager.isSplinePositionInYellowZone(0)
  and RaceTrackManager.isSplinePositionInYellowZone(1)
  and not RaceTrackManager.isSplinePositionInYellowZone(.5),
  'wrap-zone endpoints are inclusive, 0 equals 1, and distant spline is outside')
assert(RaceTrackManager.getYellowZoneCoverageReadOnly(.001).covered == true,
  'read-only coverage agrees with operational wrap-zone endpoint query')

-- R3: specific-zone containment is wrap aware, read-only and rejects invalid inputs.
local specificRevision = RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision
assert(RaceTrackManager.isSplinePositionInZone(wrapZoneA, .979)
  and RaceTrackManager.isSplinePositionInZone(wrapZoneA, .001)
  and RaceTrackManager.isSplinePositionInZone(wrapZoneA, 0)
  and RaceTrackManager.isSplinePositionInZone(wrapZoneA, 1)
  and not RaceTrackManager.isSplinePositionInZone(wrapZoneA, .5),
  'specific-zone containment is wrap aware and inclusive at both endpoints')
assert(not RaceTrackManager.isSplinePositionInZone(0, .5)
  and not RaceTrackManager.isSplinePositionInZone(-1, .5)
  and not RaceTrackManager.isSplinePositionInZone(1.5, .5)
  and not RaceTrackManager.isSplinePositionInZone(9999, .5)
  and not RaceTrackManager.isSplinePositionInZone('1', .5)
  and not RaceTrackManager.isSplinePositionInZone(nil, .5)
  and not RaceTrackManager.isSplinePositionInZone(wrapZoneA, 1.5)
  and not RaceTrackManager.isSplinePositionInZone(wrapZoneA, 0/0)
  and not RaceTrackManager.isSplinePositionInZone(wrapZoneA, math.huge)
  and not RaceTrackManager.isSplinePositionInZone(wrapZoneA, '0.5'),
  'specific-zone containment rejects unknown zone ids and non-finite splines')
assert(RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision == specificRevision,
  'specific-zone containment never mutates zone storage or revision')

-- R3: full-circle containment and the resolved-zone false path, with no observation emitted.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 10000
cars[1].splinePosition, cars[2].splinePosition = .4, .4
local fullCircleIncident = assert(add(1, 2))
local fullCircleZone = AccidentManager.accidents_yellowFlagZoneIndex[fullCircleIncident]
local observationsBeforeFullCircleQuery = observations
assert(RaceTrackManager.isSplinePositionInZone(fullCircleZone, .2)
  and RaceTrackManager.isSplinePositionInZone(fullCircleZone, .8)
  and RaceTrackManager.isSplinePositionInZone(fullCircleZone, .4),
  'full-circle zone containment covers every spline position')
assert(observations == observationsBeforeFullCircleQuery,
  'specific-zone containment emits no observation')
assert(RaceTrackManager.removeYellowFlagZone(fullCircleZone))
assert(not RaceTrackManager.isSplinePositionInZone(fullCircleZone, .2),
  'resolved zone id is never contained')
storage.distanceFromAccidentToSeeYellowFlag_meters = 100

local wrapB, wrapZoneB = newWrap(.001, .999)
local wrapBoundsB = assert(RaceTrackManager.getYellowZoneReadOnly(wrapZoneB))
assert(math.abs(wrapBoundsB.startSplinePosition - .979) < 1e-9 and wrapBoundsB.endSplinePosition == .001
  and RaceTrackManager.isSplinePositionInYellowZone(.999),
  'reverse participant role registers identical shortest wrap protection')
local nearWrapA, nearWrapZoneA = newWrap(.98, .02)
local nearWrapBoundsA = assert(RaceTrackManager.getYellowZoneReadOnly(nearWrapZoneA))
assert(math.abs(nearWrapBoundsA.startSplinePosition - .96) < 1e-9 and nearWrapBoundsA.endSplinePosition == .02
  and RaceTrackManager.isSplinePositionInYellowZone(.98)
  and not RaceTrackManager.isSplinePositionInYellowZone(.5),
  '.98/.02 wrap bounds and coverage are created at event registration')
local nearWrapB, nearWrapZoneB = newWrap(.02, .98)
local nearWrapBoundsB = assert(RaceTrackManager.getYellowZoneReadOnly(nearWrapZoneB))
assert(math.abs(nearWrapBoundsB.startSplinePosition - .96) < 1e-9 and nearWrapBoundsB.endSplinePosition == .02,
  'reversed .98/.02 participant roles create equivalent registered bounds')

-- Independent overlapping zones remain indexed when one is removed; unchanged bounds do not churn buckets.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 100
cars[1].splinePosition, cars[2].splinePosition = .999, .001
local overlapIncidentA = assert(add(1, 2))
local overlapZoneA = AccidentManager.accidents_yellowFlagZoneIndex[overlapIncidentA]
cars[4].splinePosition, cars[5].splinePosition = .98, .02
local overlapIncidentB = assert(add(4, 5))
local overlapZoneB = AccidentManager.accidents_yellowFlagZoneIndex[overlapIncidentB]
assert(RaceTrackManager.isSplinePositionInYellowZone(0), 'both overlap registrations cover the seam')
local seamBucket = RaceTrackManager.yellowFlagsZones_bucket[0]
local seamFirst, seamSecond = seamBucket[1], seamBucket[2]
local noChangeRevision = RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision
RaceTrackManager.updateYellowFlagZones()
assert(RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision == noChangeRevision
  and RaceTrackManager.yellowFlagsZones_bucket[0] == seamBucket
  and seamBucket[1] == seamFirst and seamBucket[2] == seamSecond,
  'unchanged bounds preserve bucket reference, ordering, and revision')
AccidentManager.informAboutCarReset(1)
assert(RaceTrackManager.getYellowZoneReadOnly(overlapZoneA).resolved == true
  and RaceTrackManager.getYellowZoneReadOnly(overlapZoneB).resolved == false
  and RaceTrackManager.isSplinePositionInYellowZone(0)
  and RaceTrackManager.getYellowZoneCoverageReadOnly(0).covered == true,
  'selectively resetting one overlapping incident preserves the other in both query APIs')
assert(overlapZoneB ~= overlapZoneA, 'overlapping incidents own independent zone IDs')

-- Invalid update settings and event positions preserve active bounds and all bucket contents.
local preservedZone = assert(RaceTrackManager.getYellowZoneReadOnly(overlapZoneB))
local preservedBucket = RaceTrackManager.yellowFlagsZones_bucket[0]
local preservedCount = #preservedBucket
local preservedRevision = RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision
storage.distanceFromAccidentToSeeYellowFlag_meters = -1
RaceTrackManager.updateYellowFlagZones()
storage.distanceFromAccidentToSeeYellowFlag_meters = 100
AccidentManager.accidents_splinePosition[overlapIncidentB] = 1.2
RaceTrackManager.updateYellowFlagZones()
local afterInvalid = assert(RaceTrackManager.getYellowZoneReadOnly(overlapZoneB))
assert(afterInvalid.startSplinePosition == preservedZone.startSplinePosition
  and afterInvalid.endSplinePosition == preservedZone.endSplinePosition
  and #RaceTrackManager.yellowFlagsZones_bucket[0] == preservedCount
  and RaceTrackManager.yellowFlagsZones_bucket[0][1] == preservedBucket[1]
  and RaceTrackManager.getYellowZoneInventoryReadOnly(1).revision == preservedRevision
  and AccidentManager.accidents_resolved[overlapIncidentB] == false,
  'invalid setting or event spline preserves active incident, bounds, buckets, and revision')
for _, invalid in ipairs({ 'bad', 0/0, math.huge, -0.01, 1.01 }) do
  assert(not RaceTrackManager.isSplinePositionInYellowZone(invalid)
    and RaceTrackManager.getYellowZoneCoverageReadOnly(invalid) == nil,
    'invalid operational and read-only spline queries are safe and unknown')
end

-- Point zones at the cyclic seam index only the point, never an entire bucket or lap.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 0
cars[1].splinePosition, cars[2].splinePosition = 0, 1
local pointIncident = assert(add(1, 2))
local pointZone = AccidentManager.accidents_yellowFlagZoneIndex[pointIncident]
assert(RaceTrackManager.isSplinePositionInYellowZone(0)
  and RaceTrackManager.isSplinePositionInYellowZone(1)
  and not RaceTrackManager.isSplinePositionInYellowZone(.001)
  and not RaceTrackManager.isSplinePositionInYellowZone(.049),
  'zero-extent seam zone is inclusive only at the point and does not expand to its bucket')
local pointBuckets = 0
for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
  for _, zone in ipairs(bucket) do if zone == pointZone then pointBuckets = pointBuckets + 1 end end
end
assert(pointBuckets == 1, 'seam point zone is indexed in one bucket only')

-- R4: re-indexing a zone must never duplicate its id within a bucket, and distinct zones stay separate.
-- The current public API cannot produce a duplicate id (remove runs before re-add), so this test
-- pins the observable invariant; the dedupe loop in addYellowFlagZoneToBuckets is defensive only.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 100
cars[1].splinePosition, cars[2].splinePosition = .3, .32
local hygieneIncident = assert(add(1, 2))
local hygieneZone = AccidentManager.accidents_yellowFlagZoneIndex[hygieneIncident]
cars[4].splinePosition, cars[5].splinePosition = .6, .62
local hygieneOther = assert(add(4, 5))
local hygieneOtherZone = AccidentManager.accidents_yellowFlagZoneIndex[hygieneOther]
local function maxOccurrencesInAnyBucket(zoneID)
  local maximum = 0
  for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
    local count = 0
    for i = 1, #bucket do if bucket[i] == zoneID then count = count + 1 end end
    if count > maximum then maximum = count end
  end
  return maximum
end
assert(maxOccurrencesInAnyBucket(hygieneZone) == 1, 'a new zone appears at most once per bucket')
for _ = 1, 3 do
  AccidentManager.accidents_splinePosition[hygieneIncident] = .5
  AccidentManager.accidents_victimSplinePosition[hygieneIncident] = .52
  RaceTrackManager.updateYellowFlagZones()
  AccidentManager.accidents_splinePosition[hygieneIncident] = .3
  AccidentManager.accidents_victimSplinePosition[hygieneIncident] = .32
  RaceTrackManager.updateYellowFlagZones()
end
assert(maxOccurrencesInAnyBucket(hygieneZone) == 1
  and maxOccurrencesInAnyBucket(hygieneOtherZone) == 1,
  're-indexing the same zone id never duplicates it in a bucket')
assert(zoneIDPresent(hygieneZone) and zoneIDPresent(hygieneOtherZone)
  and hygieneZone ~= hygieneOtherZone,
  'distinct independent zones remain indexed without merging')

AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 0
cars[1].splinePosition, cars[2].splinePosition = .4, .4
local interiorPointIncident = assert(add(1, 2))
local interiorPointZone = AccidentManager.accidents_yellowFlagZoneIndex[interiorPointIncident]
assert(RaceTrackManager.isSplinePositionInYellowZone(.4)
  and not RaceTrackManager.isSplinePositionInYellowZone(.399)
  and not RaceTrackManager.isSplinePositionInYellowZone(.401),
  'zero-extent non-seam zone is an exact inclusive point')
local interiorPointBucketCount = 0
for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
  for _, zone in ipairs(bucket) do if zone == interiorPointZone then interiorPointBucketCount = interiorPointBucketCount + 1 end end
end
assert(interiorPointBucketCount == 1, 'non-seam point zone is indexed in one bucket')

-- Coincident participants form an arc of zero, not a fabricated half-lap in a tie.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 3000
cars[1].splinePosition, cars[2].splinePosition = .4, .4
local coincidentIncident = assert(add(1, 2))
local coincidentZone = AccidentManager.accidents_yellowFlagZoneIndex[coincidentIncident]
local coincidentBounds = assert(RaceTrackManager.getYellowZoneReadOnly(coincidentZone))
assert(math.abs(coincidentBounds.startSplinePosition - .8) < 1e-9 and coincidentBounds.endSplinePosition == .4
  and RaceTrackManager.isSplinePositionInYellowZone(.2)
  and not RaceTrackManager.isSplinePositionInYellowZone(.5),
  'coincident event positions plus 0.6 backward padding create a 0.6 arc, not full-circle coverage')

-- Full circle from event arc plus padding, and from padding alone >= one lap.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 3000
cars[1].splinePosition, cars[2].splinePosition = .2, .8
local fullBySumIncident = assert(add(1, 2))
local fullBySumZone = AccidentManager.accidents_yellowFlagZoneIndex[fullBySumIncident]
assert(RaceTrackManager.isSplinePositionInYellowZone(.5), 'event arc plus padding reaching one lap is full circle')
storage.distanceFromAccidentToSeeYellowFlag_meters = 0
AccidentManager.accidents_splinePosition[fullBySumIncident] = .4
AccidentManager.accidents_victimSplinePosition[fullBySumIncident] = .4
RaceTrackManager.updateYellowFlagZones()
assert(not RaceTrackManager.isSplinePositionInYellowZone(.5), 'full-to-point update removes stale full-circle bucket entries')
local pointAfterFull = RaceTrackManager.getYellowZoneReadOnly(fullBySumZone)
assert(pointAfterFull.startSplinePosition == .4 and pointAfterFull.endSplinePosition == .4,
  'full-to-point update stores exact point bounds')
local pointZoneBucketCount = 0
for _, bucket in pairs(RaceTrackManager.yellowFlagsZones_bucket) do
  for _, zone in ipairs(bucket) do if zone == fullBySumZone then pointZoneBucketCount = pointZoneBucketCount + 1 end end
end
assert(pointZoneBucketCount == 1, 'full-to-point reindex removes old full-circle bucket references')
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 10000
cars[1].splinePosition, cars[2].splinePosition = .4, .4
local fullByPaddingIncident = assert(add(1, 2))
local fullByPaddingZone = AccidentManager.accidents_yellowFlagZoneIndex[fullByPaddingIncident]
assert(RaceTrackManager.isSplinePositionInYellowZone(.2)
  and RaceTrackManager.isSplinePositionInYellowZone(.8), 'padding >= two laps remains explicit full-circle coverage')
assert(RaceTrackManager.removeYellowFlagZone(fullByPaddingZone)
  and not RaceTrackManager.isSplinePositionInYellowZone(.2), 'removing a full-circle zone cleans all bucket entries')

-- Invalid initial event positions reject only the zone declaration, not the incident.
AccidentManager.resetSession()
storage.distanceFromAccidentToSeeYellowFlag_meters = 100
cars[1].splinePosition, cars[2].splinePosition = 1.2, .3
local invalidInitialIncident = assert(add(1, 2))
assert(AccidentManager.accidents_resolved[invalidInitialIncident] == false
  and AccidentManager.accidents_yellowFlagZoneIndex[invalidInitialIncident] == nil,
  'invalid initial zone geometry leaves the incident active without fabricating a zone')

-- Invalid captured track lengths are tested by isolated module reloads, restoring fixture globals afterward.
local originalTrackLength, originalRaceTrackManager, originalGetSim = sim.trackLengthM, RaceTrackManager, ac.getSim
for _, invalidTrackLength in ipairs({ 0, false, 0/0, math.huge }) do
  if invalidTrackLength == false then sim.trackLengthM = nil else sim.trackLengthM = invalidTrackLength end
  RaceTrackManager = dofile(root .. 'RaceTrackManager.lua')
  AccidentManager.resetSession()
  cars[1].splinePosition, cars[2].splinePosition = .3, .31
  local invalidTrackIncident = assert(add(1, 2))
  assert(AccidentManager.accidents_resolved[invalidTrackIncident] == false
    and AccidentManager.accidents_yellowFlagZoneIndex[invalidTrackIncident] == nil,
    'invalid load-time track length leaves incident active and declines zone')
end
sim.trackLengthM, ac.getSim, RaceTrackManager = originalTrackLength, originalGetSim, originalRaceTrackManager
print('test_incident_cleanup: PASS')
