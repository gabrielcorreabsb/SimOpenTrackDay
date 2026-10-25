local ControlDebugPanel = {}

local ui = ui
local Localization = require('Localization')
local CarManager = CarManager
local CarOperations = CarOperations
local CarStateMachine = CarStateMachine
local GameTimeManager = GameTimeManager
local Logger = Logger
local RaceTrackManager = RaceTrackManager
local StorageManager = StorageManager
local ac = ac
local math = math
local pairs = pairs
local tostring = tostring
local type = type
local selectedCarIndex = -1
local choices, choiceCount, choiceLocale = {}, -1, nil
local ownerScratch = {}
local lastRefreshTime = nil
local cache = { car = -1, sessionGeneration = nil, carGeneration = nil, lastPull = nil,
  records = {}, stats = nil, matchingCount = 0, scanned = 0, limited = false,
  incidents = {}, zones = {}, error = false, inventory = nil, coverage = nil,
  zoneDecision = nil, accidentDecision = nil, pending = nil }
local clockInvalid = false
local inventoryCursor, inventoryEpoch, inventoryRevision, inventorySession = nil, nil, nil, nil

local function text(source, ...)
  local value = Localization.text(source, ...)
  if ui.textWrapped then ui.textWrapped(value) else ui.text(value) end
end

local function finiteNumber(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function safeText(value)
  local ok, s = pcall(tostring, value)
  if not ok then return Localization.text('unavailable') end
  if type(s) ~= 'string' then return Localization.text('unavailable') end
  if #s <= 128 then return s end
  local limit = 125
  if string.byte(s, limit + 1) >= 128 and string.byte(s, limit + 1) < 192 then
    repeat
      limit = limit - 1
    until limit <= 0 or string.byte(s, limit + 1) < 128 or string.byte(s, limit + 1) >= 192
  end
  return string.sub(s, 1, limit) .. '...'
end

local function safeFormat(formatString, value)
  local ok, result = pcall(string.format, formatString, value)
  if not ok then return Localization.text('unavailable') end
  return safeText(result)
end

local function rebuildChoices(count, locale)
  for i = #choices, 1, -1 do choices[i] = nil end
  choices[1] = Localization.text('No car selected')
  for index = 0, count - 1 do choices[index + 2] = tostring(index) end
  choiceCount, choiceLocale = count, locale
end

local function clearCache()
  cache.car, cache.sessionGeneration, cache.carGeneration = selectedCarIndex, nil, nil
  cache.lastPull, cache.stats, cache.matchingCount, cache.scanned, cache.limited, cache.error = lastRefreshTime, nil, 0, 0, false, false
  for i = #cache.records, 1, -1 do cache.records[i] = nil end
  for i = #cache.incidents, 1, -1 do cache.incidents[i] = nil end
  for i = #cache.zones, 1, -1 do cache.zones[i] = nil end
  cache.inventory, cache.coverage, cache.zoneDecision, cache.accidentDecision, cache.pending = nil, nil, nil, nil, nil
end

local function safeLookup(fn, ...)
  if type(fn) ~= 'function' then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function refresh(now, carGeneration, sessionGeneration)
  if selectedCarIndex < 0 or not finiteNumber(now) then return end
  if cache.car ~= selectedCarIndex or cache.sessionGeneration ~= sessionGeneration or cache.carGeneration ~= carGeneration then clearCache() end
  if finiteNumber(lastRefreshTime) and (now < lastRefreshTime or now - lastRefreshTime < 0.25) then return end
  lastRefreshTime, cache.lastPull = now, now
  cache.car, cache.sessionGeneration, cache.carGeneration = selectedCarIndex, sessionGeneration, carGeneration
  cache.error = false
  cache.inventory, cache.coverage, cache.zoneDecision, cache.accidentDecision, cache.pending = nil, nil, nil, nil, nil
  local logger = rawget(_G, 'Logger')
  local query = type(logger) == 'table' and rawget(logger, 'getOBS1RecentForCar') or nil
  if type(query) == 'function' then
    local ok, result = pcall(query, selectedCarIndex)
    if ok and type(result) == 'table' and result.car == selectedCarIndex and type(result.records) == 'table' and
      finiteNumber(result.matchingCount) and result.matchingCount >= 0 and result.matchingCount <= 256 and
      finiteNumber(result.scanned) and result.scanned >= 0 and result.scanned <= 256 then
      local records = {}
      local n = math.min(8, #result.records)
      local validRecords = true
      for i = 1, n do
        local record = result.records[i]
        if type(record) ~= 'table' or record.car ~= selectedCarIndex then validRecords = false; break end
        records[#records + 1] = record
      end
      if not validRecords then cache.error = true; records = {} end
      cache.records, cache.stats = records, type(result.stats) == 'table' and result.stats or nil
      cache.matchingCount = finiteNumber(result.matchingCount) and math.max(0, math.floor(result.matchingCount)) or n
      cache.scanned = finiteNumber(result.scanned) and math.max(0, math.floor(result.scanned)) or 0
      cache.limited = result.limited == true or cache.matchingCount > #records
    else cache.error = true; cache.records, cache.stats, cache.matchingCount = {}, nil, 0 end
  else cache.records, cache.stats, cache.matchingCount, cache.error = {}, nil, 0, true end

  for i = #cache.incidents, 1, -1 do cache.incidents[i] = nil end
  for i = #cache.zones, 1, -1 do cache.zones[i] = nil end
  local track = rawget(_G, 'RaceTrackManager')
  local inventoryFn = type(track) == 'table' and rawget(track, 'getYellowZoneInventoryReadOnly') or nil
  if type(inventoryFn) == 'function' then
    local ok, page = pcall(inventoryFn, inventoryCursor, inventoryEpoch, inventoryRevision)
    if ok and type(page) == 'table' and type(page.zones) == 'table' and finiteNumber(page.scanned) and page.scanned >= 0 and page.scanned <= 32 then
      local zones, valid = {}, true
      for i = 1, math.min(32, #page.zones) do
        local z = page.zones[i]
        if type(z) ~= 'table' then valid = false; break end
        zones[#zones + 1] = z
      end
      if valid then
        cache.inventory = { zones = zones, scanned = math.floor(page.scanned), complete = page.complete == true,
          cursor = page.cursor, nextCursor = page.nextCursor, epoch = page.epoch, revision = page.revision,
          session = page.session, restarted = page.restarted == true }
        if page.restarted or page.epoch ~= inventoryEpoch or page.revision ~= inventoryRevision or page.session ~= inventorySession then
          inventoryCursor = page.cursor
        end
        inventoryEpoch, inventoryRevision, inventorySession = page.epoch, page.revision, page.session
      end
    end
  end
  local car = safeLookup(ac.getCar, selectedCarIndex)
  local spline = car and car.splinePosition or nil
  local coverageFn = type(track) == 'table' and rawget(track, 'getYellowZoneCoverageReadOnly') or nil
  if type(coverageFn) == 'function' and finiteNumber(spline) then
    local ok, result = pcall(coverageFn, spline)
    if ok and type(result) == 'table' and finiteNumber(result.scanned) and result.scanned >= 0 and result.scanned <= 32 then cache.coverage = result end
  end
  local function optionalSnapshot(globalName, method)
    local manager = rawget(_G, globalName)
    local getter = type(manager) == 'table' and rawget(manager, method) or nil
    if type(getter) ~= 'function' then return nil end
    local ok, result = pcall(getter, selectedCarIndex)
    if ok and type(result) == 'table' and result.car == selectedCarIndex then return result end
    return nil
  end
  cache.zoneDecision = optionalSnapshot('RaceTrackManager', 'getYellowZoneDecisionReadOnly')
  cache.accidentDecision = optionalSnapshot('AccidentManager', 'getAccidentDecisionReadOnly')
  cache.pending = optionalSnapshot('CarStateMachine', 'getPendingReadOnly')
  local accidentManager = rawget(_G, 'AccidentManager')
  if type(accidentManager) == 'table' then
    local culpritMap = rawget(accidentManager, 'cars_culpritInAccidentIndex')
    local victimMap = rawget(accidentManager, 'cars_victimInAccidentIndex')
    local resolvedMap = rawget(accidentManager, 'accidents_resolved')
    local firstMap = rawget(accidentManager, 'accidents_carIndex')
    local secondMap = rawget(accidentManager, 'accidents_collidedWithCarIndex')
    local zoneMap = rawget(accidentManager, 'accidents_yellowFlagZoneIndex')
    local maps = { { map = culpritMap, role = 'Culprit', roleField = firstMap },
      { map = victimMap, role = 'Victim', roleField = secondMap } }
    local seen = {}
    for m = 1, 2 do
      local link = maps[m]
      local id = type(link.map) == 'table' and link.map[selectedCarIndex] or nil
      local validID = finiteNumber(id) and id > 0 and id % 1 == 0
      local active = validID and type(resolvedMap) == 'table' and resolvedMap[id] == false
      local selectedIsRole = type(link.roleField) == 'table' and link.roleField[id] == selectedCarIndex
      if active and selectedIsRole and not seen[id] and #cache.incidents < 2 and type(firstMap) == 'table' and type(secondMap) == 'table' then
        seen[id] = true
        cache.incidents[#cache.incidents + 1] = { id = id, role = link.role,
          first = firstMap[id], second = secondMap[id], generationKnown = false }
        local zoneID = type(zoneMap) == 'table' and zoneMap[id] or nil
        if finiteNumber(zoneID) and zoneID > 0 and zoneID % 1 == 0 and #cache.zones < 2 then
          local track = rawget(_G, 'RaceTrackManager')
          local getter = type(track) == 'table' and rawget(track, 'getYellowZoneReadOnly') or nil
          local zone = safeLookup(getter, zoneID)
          if type(zone) == 'table' and zone.zone == zoneID and zone.incident == id and zone.resolved == false then
            cache.zones[#cache.zones + 1] = { zone = zoneID, incident = id,
              startSplinePosition = zone.startSplinePosition, endSplinePosition = zone.endSplinePosition,
              boundsValid = finiteNumber(zone.startSplinePosition) and finiteNumber(zone.endSplinePosition), unknown = false }
          else cache.zones[#cache.zones + 1] = { zone = zoneID, unknown = true } end
        end
      end
    end
  end
end

local function displayRecordCurrent(record, carGeneration, sessionGeneration)
  local refSession, generation = record.referenceSession, record.generation
  if not finiteNumber(refSession) or refSession < 0 or refSession % 1 ~= 0 or
    not finiteNumber(generation) or generation < 0 or generation % 1 ~= 0 or
    not finiteNumber(sessionGeneration) or not finiteNumber(carGeneration) then return 'Unknown' end
  if record.referenceSession ~= sessionGeneration or record.generation ~= carGeneration then return 'Stale' end
  return 'Current'
end

local function drawHistory(carGeneration, sessionGeneration)
  text('Recent recorded events')
  local logger = rawget(_G, 'Logger')
  local enabled, focus
  if type(logger) == 'table' then
    enabled, focus = rawget(logger, 'OBS1_ENABLED'), rawget(logger, 'OBS1_FOCUS_CAR')
  end
  if enabled == false then text('Observation capture is off.')
  elseif enabled ~= true then text('Observation capture status unknown.')
  elseif type(focus) ~= 'number' or focus < 0 then text('Capture focus unknown; events may be missing.')
  elseif focus ~= selectedCarIndex then text('Capture focus differs from this car; events may be missing.') end
  if cache.error then text('Observation query unavailable.')
  elseif cache.matchingCount == 0 then text('No matching recorded events; this does not prove nothing happened.')
  else
    local first = math.max(1, #cache.records - 7)
    for i = first, #cache.records do
      local r = cache.records[i]
      local stamp = r.activeTimeValid and finiteNumber(r.activeTime) and safeFormat('%.2fs', r.activeTime) or Localization.text('time unknown')
      text('#%s · %s · %s · %s', safeText(r.sequence), stamp, safeText(r.kind), Localization.text(displayRecordCurrent(r, carGeneration, sessionGeneration)))
      text('Incident: %s · zone: %s · event detail: %s', safeText(r.incident or Localization.text('unavailable')),
         safeText(r.zone or Localization.text('unavailable')), safeText(r.detail or Localization.text('unavailable')))
      text('Historical context: %s', safeText(r.context or Localization.text('Unknown')))
    end
    if cache.limited then text('Showing the latest 8 of %s matching events.', safeText(cache.matchingCount)) end
  end
  local stats = cache.stats
  if type(stats) == 'table' and ((finiteNumber(stats.drops) and stats.drops > 0) or
    (finiteNumber(stats.overwrites) and stats.overwrites > 0) or
    (finiteNumber(stats.detailAdmissionDrops) and stats.detailAdmissionDrops > 0) or
    (finiteNumber(stats.detailOutputDrops) and stats.detailOutputDrops > 0) or
    (finiteNumber(stats.sinkThrewUncertain) and stats.sinkThrewUncertain > 0) or
    (finiteNumber(stats.sinkUnavailable) and stats.sinkUnavailable > 0) or
    (finiteNumber(stats.formatFailures) and stats.formatFailures > 0) or stats.outputSaturated or stats.outputFormatterFailed) then
    text('Capture has losses or truncated output; silence is not proof of no event.')
  end
end

local function drawAssociations(carGeneration, sessionGeneration)
  text('Incident links (may be incomplete)')
  if #cache.incidents == 0 then text('Incident association unknown; no active role link is available.') end
  for i = 1, #cache.incidents do
    local item = cache.incidents[i]
    text('%s · incident %s · participants %s / %s · association generation unknown', Localization.text(item.role),
      safeText(item.id), safeText(item.first or Localization.text('unavailable')), safeText(item.second or Localization.text('unavailable')))
  end
  text('Associated zones · registered bounds only')
  if #cache.zones == 0 then text('Yellow-zone association unknown; this is not evidence that no zone exists.') end
  for i = 1, #cache.zones do
    local zone = cache.zones[i]
    if zone.unknown then text('Zone %s · association or current status unknown.', safeText(zone.zone))
    else
      local start = finiteNumber(zone.startSplinePosition) and safeFormat('%.4f', zone.startSplinePosition) or Localization.text('unavailable')
      local finish = finiteNumber(zone.endSplinePosition) and safeFormat('%.4f', zone.endSplinePosition) or Localization.text('unavailable')
      text('Zone %s · incident %s · registered %s → %s', safeText(zone.zone), safeText(zone.incident), start, finish)
    end
  end
  local inventory = cache.inventory
  text('Registered yellow zones · partial inventory page')
  if not inventory then text('Zone inventory unavailable or unknown.')
  else
    text('IDs examined: %s · epoch: %s · revision: %s · session: %s', safeText(inventory.scanned), safeText(inventory.epoch or Localization.text('Unknown')), safeText(inventory.revision or Localization.text('Unknown')), safeText(inventory.session or Localization.text('Unknown')))
    text('Page cursor: %s · next cursor: %s', safeText(inventory.cursor or Localization.text('Unknown')), safeText(inventory.nextCursor or Localization.text('End')))
    if finiteNumber(inventory.session) and finiteNumber(CarManager.sessionGeneration) and inventory.session ~= CarManager.sessionGeneration then
      text('Inventory page is stale for this session.')
    end
    if inventory.restarted then text('Inventory page restarted because its snapshot changed.') end
    for i = 1, #inventory.zones do
      local z = inventory.zones[i]
      local status = z.resolved == false and Localization.text('Active') or z.resolved == true and Localization.text('Resolved') or Localization.text('Unknown')
      text('Zone %s · %s · incident %s · %s → %s', safeText(z.zone or Localization.text('unavailable')), status, safeText(z.incident or Localization.text('unavailable')),
        finiteNumber(z.startSplinePosition) and safeFormat('%.4f', z.startSplinePosition) or Localization.text('unavailable'),
        finiteNumber(z.endSplinePosition) and safeFormat('%.4f', z.endSplinePosition) or Localization.text('unavailable'))
    end
    text(inventory.complete and 'Inventory page complete.' or 'Inventory page partial; more IDs may remain.')
    local nextFn = type(ui) == 'table' and rawget(ui, 'button') or nil
    if not inventory.complete and type(nextFn) == 'function' then
      local ok, clicked = pcall(nextFn, Localization.text('Next zone page'))
      if ok and clicked then inventoryCursor = inventory.nextCursor end
    end
  end
  local coverage = cache.coverage
  text('Coverage · current geometry predicate only')
  if not coverage then text('Coverage unknown or unavailable.')
  else
    if finiteNumber(coverage.session) and finiteNumber(CarManager.sessionGeneration) and coverage.session ~= CarManager.sessionGeneration then
      text('Coverage snapshot is stale for this session.')
    end
    if cache.inventory and (coverage.epoch ~= cache.inventory.epoch or coverage.revision ~= cache.inventory.revision or coverage.session ~= cache.inventory.session) then
      text('Coverage and inventory snapshots do not share the same revision.')
    end
    text('Coverage epoch: %s · revision: %s · session: %s', safeText(coverage.epoch or Localization.text('Unknown')),
      safeText(coverage.revision or Localization.text('Unknown')), safeText(coverage.session or Localization.text('Unknown')))
    text('Bucket candidates examined: %s of %s · coverage: %s%s', safeText(coverage.scanned), safeText(coverage.total or Localization.text('Unknown')),
      coverage.covered == true and Localization.text('Yes') or coverage.covered == false and Localization.text('No') or Localization.text('Unknown'),
      coverage.limited and Localization.text(' · incomplete') or '')
    local matches = type(coverage.candidates) == 'table' and coverage.candidates or {}
    for i = 1, math.min(32, #matches) do
      local match = matches[i]
      text('Covered zone: %s', safeText(type(match) == 'table' and match.zone or match))
    end
  end
  local function identityCurrent(snapshot)
    return type(snapshot) == 'table' and finiteNumber(snapshot.session) and finiteNumber(sessionGeneration) and
      snapshot.session == sessionGeneration and finiteNumber(snapshot.generation) and finiteNumber(carGeneration) and
      snapshot.generation == carGeneration
  end
  local function drawDecision(title, decision, chosenKey)
    text(title)
    local logger = rawget(_G, 'Logger')
    local enabled, focus
    if type(logger) == 'table' then enabled, focus = rawget(logger, 'OBS1_ENABLED'), rawget(logger, 'OBS1_FOCUS_CAR') end
    if enabled == false then text('Observation capture is off.'); return end
    if enabled == true and focus ~= selectedCarIndex then text('Capture focus differs from this car; events may be missing.'); return end
    if enabled ~= true or not finiteNumber(focus) then text('Capture focus unknown; events may be missing.'); return end
    if not decision then text('Decision snapshot unavailable, stale, or not observed.') return end
    local query, navigation = decision, nil
    if chosenKey == 'chosenIncident' then
      query = type(decision.query) == 'table' and decision.query or nil
      navigation = type(decision.navigation) == 'table' and decision.navigation or nil
      if not query then text('Accident query was not observed for this car.')
      elseif focus ~= selectedCarIndex then text('Capture focus differs from this car; events may be missing.')
      elseif not identityCurrent(query) then text('Accident query snapshot is stale or has unknown identity.')
      else
        text('Query source: %s · sequence: %s', safeText(query.source or Localization.text('Unknown')), safeText(query.sequence or Localization.text('Unknown')))
        text('Observed candidates: %s · limited: %s', safeText(query.examined or Localization.text('Unknown')), safeText(query.limited == true))
        local candidates = type(query.candidates) == 'table' and query.candidates or {}
        for i = 1, math.min(32, #candidates) do
          local candidate = candidates[i]
          text('Consulted candidate: %s', safeText(type(candidate) == 'table' and candidate.incident or candidate or Localization.text('Unknown')))
          if type(candidate) == 'table' and candidate.reason ~= nil then text('Candidate reason: %s', safeText(candidate.reason)) end
        end
        text('Chosen by query: %s · chosen car: %s', safeText(query.chosenIncident or Localization.text('Unknown')), safeText(query.chosenCar or Localization.text('Unknown')))
      end
      if not navigation then text('Accident assignment has not been observed.')
      elseif not identityCurrent(navigation) then text('Accident assignment snapshot is stale or has unknown identity.')
      else
        if not query then text('Assignment is shown without a matching query sample.') end
        text('Assignment origin: %s · query sequence: %s · matches query: %s', safeText(navigation.assignmentOrigin or Localization.text('Unknown')),
          safeText(navigation.querySequence or Localization.text('Unknown')), safeText(navigation.matchesQuery == true and Localization.text('Yes') or navigation.matchesQuery == false and Localization.text('No') or Localization.text('Unknown')))
        text('Assigned incident: %s · assigned car: %s', safeText(navigation.assignedIncident or Localization.text('Unknown')), safeText(navigation.assignedCar or Localization.text('Unknown')))
        text('Compared query incident: %s · car: %s', safeText(navigation.comparedIncident or Localization.text('Unknown')), safeText(navigation.comparedCar or Localization.text('Unknown')))
      end
    elseif identityCurrent(query) then
      text('Observed candidates: %s · limited: %s', safeText(query.examined or Localization.text('Unknown')), safeText(query.limited == true))
      local candidates = type(query.candidates) == 'table' and query.candidates or {}
      for i = 1, math.min(32, #candidates) do
        local candidate = candidates[i]
        local id = type(candidate) == 'table' and (candidate.zone or candidate.incident or candidate.id) or candidate
        text('Consulted candidate: %s', safeText(id or Localization.text('Unknown')))
      end
      text('Query sequence: %s', safeText(query.sequence or Localization.text('Unknown')))
      text('Chosen by query: %s', safeText(query[chosenKey] or Localization.text('Unknown')))
      text('Consumer branch: %s · returned state: %s', safeText(query.consumer or Localization.text('Unknown')), safeText(query.stateReturned or Localization.text('Unknown')))
    else text('Decision snapshot belongs to another or unknown car/session generation.') end
    text('Historical query sample; not a current-state or causal claim.')
  end
  drawDecision('Observed yellow-zone query', cache.zoneDecision, 'chosenZone')
  drawDecision('Observed accident query/assignment', cache.accidentDecision, 'chosenIncident')
  local pending = cache.pending
  text('Pending FSM transition')
  if pending and pending.car == selectedCarIndex and pending.session == sessionGeneration and pending.pending == nil and pending.currentGeneration == carGeneration then
    text('Queued transition: %s', Localization.text('No pending transition'))
  elseif pending and pending.car == selectedCarIndex and pending.session == sessionGeneration and pending.valid == true and pending.currentGeneration == carGeneration and pending.pendingGeneration == pending.currentGeneration then
    text('Queued transition: %s', safeText(pending.pending))
  else text('Pending transition unknown or stale.') end
  text('Coverage describes the current geometry predicate, not guaranteed risk or physical effect.')
end

local function drawDiagnostics(carGeneration, sessionGeneration, now)
  refresh(now, carGeneration, sessionGeneration)
  if clockInvalid then text('History refresh clock unavailable; cached data may be stale.') end
  if cache.car ~= selectedCarIndex or cache.sessionGeneration ~= sessionGeneration or cache.carGeneration ~= carGeneration then
    text('Diagnostic snapshot stale or unavailable for this car/session.')
    return
  end
  drawHistory(carGeneration, sessionGeneration)
  drawAssociations(carGeneration, sessionGeneration)
end

local function drawCurrentTelemetry(car, carIndex)
  if car then
    text('Speed: %s km/h · in pitlane: %s · parked in pit: %s',
      finiteNumber(car.speedKmh) and safeFormat('%.0f', car.speedKmh) or Localization.text('unavailable'),
      type(car.isInPitlane) == 'boolean' and tostring(car.isInPitlane) or Localization.text('unavailable'),
      type(car.isInPit) == 'boolean' and tostring(car.isInPit) or Localization.text('unavailable'))
  else text('Speed: unavailable · in pitlane: unavailable · parked in pit: unavailable') end
  local fsm = rawget(_G, 'CarStateMachine')
  local current = safeLookup(type(fsm) == 'table' and rawget(fsm, 'getCurrentState'), carIndex)
  local previous = safeLookup(type(fsm) == 'table' and rawget(fsm, 'getPreviousState'), carIndex)
  text('Current state: %s · previous state: %s', safeText(current or Localization.text('unavailable')), safeText(previous or Localization.text('unavailable')))
end

local function generationStatus(record, carGeneration, sessionGeneration)
  if not record then return end
  local carMatches = record.carGeneration == carGeneration
  local sessionMatches = record.sessionGeneration == sessionGeneration
  if carMatches and sessionMatches then text('Record generations · car: %s · session: %s · current', tostring(record.carGeneration), tostring(record.sessionGeneration))
  else text('Record generations · car: %s · session: %s · stale relative to current selection/session', tostring(record.carGeneration), tostring(record.sessionGeneration)) end
end

local function drawRequestList(title, slot, now, carGeneration, sessionGeneration)
  text(title)
  if not slot or not slot.byOwner then text('No active requests.'); return end
  local ownerCount = 0
  for owner, request in pairs(slot.byOwner) do if request.active then ownerCount = ownerCount + 1; ownerScratch[ownerCount] = owner end end
  table.sort(ownerScratch, function(a, b) return tostring(a) < tostring(b) end)
  if ownerCount == 0 then text('No active requests.') end
  for i = 1, ownerCount do
    local owner, request = ownerScratch[i], slot.byOwner[ownerScratch[i]]
    if finiteNumber(now) and finiteNumber(request.expiresAt) then
      local ttl = request.expiresAt - now
      text('Owner: %s · value: %s · priority: %s · TTL: %s · %s', safeText(owner), safeText(request.value), safeText(request.priority), safeFormat('%.2fs', ttl), Localization.text(ttl > 0 and 'valid' or 'expired'))
    else text('Owner: %s · value: %s · priority: %s · TTL: unavailable', safeText(owner), safeText(request.value), safeText(request.priority)) end
    generationStatus(request, carGeneration, sessionGeneration)
    ownerScratch[i] = nil
  end
end

local function drawApplied(title, winner, applied, requests, carGeneration, sessionGeneration)
  text(title)
  if winner then text('Winner: %s · value: %s', tostring(winner.owner), tostring(winner.value)) else text('Winner: none') end
  if applied then
    text('Last successful setter: %s · value: %s', tostring(applied.owner), tostring(applied.value))
    generationStatus(applied, carGeneration, sessionGeneration)
    if not requests or requests.activeCount == 0 then text('Pending neutral indication · inferred from applied state without active requests; physical state is unconfirmed.') end
  else text('No successful setter recorded.') end
end

function ControlDebugPanel.draw()
  ui.separator()
  text('Control ownership debug')
  local sim = ac.getSim()
  local count = sim and sim.carsCount or 0
  if not finiteNumber(count) or count < 0 then count = 0 end
  count = math.floor(count)
  local locale = Localization.getLocale()
  if choiceCount ~= count or choiceLocale ~= locale then rebuildChoices(count, locale) end
  if selectedCarIndex >= count then selectedCarIndex = -1; clearCache() end
  local choice, changed = ui.combo(Localization.label('Car index', 'control-debug.car'), selectedCarIndex < 0 and 1 or selectedCarIndex + 2, ui.ComboFlags.None, choices)
  if changed then
    local nextIndex = choice == 1 and -1 or choice - 2
    if type(nextIndex) ~= 'number' or nextIndex < 0 or nextIndex >= count or nextIndex % 1 ~= 0 then nextIndex = -1 end
    if nextIndex ~= selectedCarIndex then selectedCarIndex = nextIndex; clearCache() end
  end
  text('Runtime flags · enabled: %s · paused: %s · live: %s', tostring(CarManager.runtimeEnabled), tostring(CarManager.runtimePaused), tostring(CarManager.runtimeLive))
  local replayState = sim and sim.isReplayActive
  text('Replay active: %s', type(replayState) == 'boolean' and tostring(replayState) or Localization.text('unavailable'))
  text('Session generation: %s', tostring(CarManager.sessionGeneration))
  if selectedCarIndex < 0 then text('Select a car index to inspect its gates and control state.'); return end
  local carOK, car = pcall(ac.getCar, selectedCarIndex)
  if not carOK then car = nil end
  local classification = Localization.text('Car type unavailable')
  if car then
    if selectedCarIndex == 0 then classification = Localization.text('Player')
    elseif car.isAIControlled == true then classification = Localization.text('AI')
    elseif car.isAIControlled == false then classification = Localization.text('Human') end
  else classification = Localization.text('Car unavailable') end
  local aiFlag = car and car.isAIControlled
  if type(aiFlag) ~= 'boolean' then aiFlag = Localization.text('unavailable') else aiFlag = tostring(aiFlag) end
  text('Selected car · index: %d · classification: %s · AI flag: %s', selectedCarIndex, classification, aiFlag)
  local writable, _, gateReason = CarManager.isWritableAICar(selectedCarIndex)
  local permission, permissionReason = CarManager.hasPhysicsPermission()
  text('Writable AI car: %s · gate reason: %s', tostring(writable), tostring(gateReason))
  text('Physics permission: %s · reason: %s', tostring(permission), tostring(permissionReason))
  local getGeneration = type(CarManager) == 'table' and rawget(CarManager, 'getCarGeneration') or nil
  local carGeneration = safeLookup(getGeneration, selectedCarIndex)
  local sessionGeneration = type(CarManager) == 'table' and rawget(CarManager, 'sessionGeneration') or nil
  text('Car generation: %s', tostring(carGeneration or Localization.text('unavailable')))
  local telemetryOK = pcall(drawCurrentTelemetry, car, selectedCarIndex)
  if not telemetryOK then pcall(text, 'Diagnostic data unavailable; existing control view remains available.') end
  local storage = StorageManager.getStorage()
  text('Global top speed cap: %s km/h', tostring(storage.globalTopSpeedLimitKmh))
  local clockOK, gameTime = pcall(GameTimeManager.getPlayingGameTime)
  if not clockOK or not finiteNumber(gameTime) then gameTime = nil end
  if gameTime then text('Active simulation time: %.2fs', gameTime) else text('Active simulation time: unavailable') end
  if cache.car ~= selectedCarIndex or cache.sessionGeneration ~= sessionGeneration or cache.carGeneration ~= carGeneration then clearCache() end
  local clockFn = type(ui) == 'table' and rawget(ui, 'time') or nil
  local clockOK, now = false, nil
  if type(clockFn) == 'function' then clockOK, now = pcall(clockFn) end
  clockInvalid = not clockOK or not finiteNumber(now) or (finiteNumber(lastRefreshTime) and now < lastRefreshTime)
  if clockInvalid then now = nil end
  local diagnosticsOK = pcall(drawDiagnostics, carGeneration, sessionGeneration, now)
  if not diagnosticsOK then
    clearCache()
    cache.error = true
    pcall(text, 'Diagnostic data unavailable; existing control view remains available.')
  end
  local topRequests, topWinner, topApplied, throttleRequests, throttleWinner, throttleApplied = CarOperations.getOwnedControlState(selectedCarIndex)
  drawRequestList('Top-speed requests', topRequests, gameTime, carGeneration, sessionGeneration)
  drawApplied('Top-speed control', topWinner, topApplied, topRequests, carGeneration, sessionGeneration)
  drawRequestList('Throttle requests', throttleRequests, gameTime, carGeneration, sessionGeneration)
  drawApplied('Throttle control', throttleWinner, throttleApplied, throttleRequests, carGeneration, sessionGeneration)
  text('A recorded applied value is the last successful setter call, not a physics readback.')
  text('No applied record does not prove that the car is physically released.')
end

return ControlDebugPanel
