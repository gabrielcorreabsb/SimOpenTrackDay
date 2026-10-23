local ControlDebugPanel = {}

local ui = ui
local Localization = require('Localization')
local CarManager = CarManager
local CarOperations = CarOperations
local GameTimeManager = GameTimeManager
local StorageManager = StorageManager
local ac = ac
local math = math
local pairs = pairs
local tostring = tostring
local type = type
local selectedCarIndex = -1
local choices = {}
local choiceCount = -1
local choiceLocale = nil
local ownerScratch = {}
local ui_textWrapped = ui.textWrapped
local function ownerLess(a, b) return tostring(a) < tostring(b) end

local function text(source, ...)
  local value = Localization.text(source, ...)
  if ui_textWrapped then ui_textWrapped(value) else ui.text(value) end
end

local function finiteNumber(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function rebuildChoices(count, locale)
  for i = #choices, 1, -1 do choices[i] = nil end
  choices[1] = Localization.text('No car selected')
  for index = 0, count - 1 do choices[index + 2] = tostring(index) end
  choiceCount, choiceLocale = count, locale
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
  if not slot or not slot.byOwner then
    text('No active requests.')
    return
  end
  local ownerCount = 0
  for owner, request in pairs(slot.byOwner) do
    if request.active then
      ownerCount = ownerCount + 1
      ownerScratch[ownerCount] = owner
    end
  end
  table.sort(ownerScratch, ownerLess)
  if ownerCount == 0 then text('No active requests.') end
  for i = 1, ownerCount do
    local owner = ownerScratch[i]
    local request = slot.byOwner[owner]
    if finiteNumber(now) and finiteNumber(request.expiresAt) then
      local ttl = request.expiresAt - now
      if ttl > 0 then
        text('Owner: %s · value: %s · priority: %s · TTL: %.2fs · valid', tostring(owner), tostring(request.value), tostring(request.priority), ttl)
      else
        text('Owner: %s · value: %s · priority: %s · TTL: %.2fs · expired', tostring(owner), tostring(request.value), tostring(request.priority), ttl)
      end
    else
      text('Owner: %s · value: %s · priority: %s · TTL: unavailable', tostring(owner), tostring(request.value), tostring(request.priority))
    end
    generationStatus(request, carGeneration, sessionGeneration)
    ownerScratch[i] = nil
  end
end

local function drawApplied(title, winner, applied, requests, carGeneration, sessionGeneration)
  text(title)
  if winner then text('Winner: %s · value: %s', tostring(winner.owner), tostring(winner.value))
  else text('Winner: none') end
  if applied then
    text('Last successful setter: %s · value: %s', tostring(applied.owner), tostring(applied.value))
    generationStatus(applied, carGeneration, sessionGeneration)
    if not requests or requests.activeCount == 0 then
      text('Pending neutral indication · inferred from applied state without active requests; physical state is unconfirmed.')
    end
  else
    text('No successful setter recorded.')
  end
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
  if selectedCarIndex >= count then selectedCarIndex = -1 end
  local selectedOption = selectedCarIndex < 0 and 1 or selectedCarIndex + 2
  local choice, changed = ui.combo(Localization.label('Car index', 'control-debug.car'), selectedOption, ui.ComboFlags.None, choices)
  if changed then
    selectedCarIndex = choice == 1 and -1 or choice - 2
  end

  text('Runtime flags · enabled: %s · paused: %s · live: %s', tostring(CarManager.runtimeEnabled), tostring(CarManager.runtimePaused), tostring(CarManager.runtimeLive))
  local replayState = sim and sim.isReplayActive
  text('Replay active: %s', type(replayState) == 'boolean' and tostring(replayState) or Localization.text('unavailable'))
  text('Session generation: %s', tostring(CarManager.sessionGeneration))
  if selectedCarIndex < 0 then
    text('Select a car index to inspect its gates and control state.')
    return
  end

  local car = ac.getCar(selectedCarIndex)
  local classification = Localization.text('Car type unavailable')
  if car then
    if selectedCarIndex == 0 then classification = Localization.text('Player')
    elseif car.isAIControlled == true then classification = Localization.text('AI')
    elseif car.isAIControlled == false then classification = Localization.text('Human')
    end
  else
    classification = Localization.text('Car unavailable')
  end
  local aiFlag = car and car.isAIControlled
  if type(aiFlag) ~= 'boolean' then aiFlag = Localization.text('unavailable') else aiFlag = tostring(aiFlag) end
  text('Selected car · index: %d · classification: %s · AI flag: %s', selectedCarIndex, classification, aiFlag)
  local writable, _, gateReason = CarManager.isWritableAICar(selectedCarIndex)
  local permission, permissionReason = CarManager.hasPhysicsPermission()
  text('Writable AI car: %s · gate reason: %s', tostring(writable), tostring(gateReason))
  text('Physics permission: %s · reason: %s', tostring(permission), tostring(permissionReason))
  local carGeneration = CarManager.getCarGeneration(selectedCarIndex)
  local sessionGeneration = CarManager.sessionGeneration
  text('Car generation: %s', tostring(carGeneration))

  local storage = StorageManager.getStorage()
  text('Global top speed cap: %s km/h', tostring(storage.globalTopSpeedLimitKmh))
  local clockOK, now = pcall(GameTimeManager.getPlayingGameTime)
  if not clockOK or not finiteNumber(now) then now = nil end
  if now then text('Active simulation time: %.2fs', now)
  else text('Active simulation time: unavailable') end
  local topRequests, topWinner, topApplied, throttleRequests, throttleWinner, throttleApplied =
    CarOperations.getOwnedControlState(selectedCarIndex)
  drawRequestList('Top-speed requests', topRequests, now, carGeneration, sessionGeneration)
  drawApplied('Top-speed control', topWinner, topApplied, topRequests, carGeneration, sessionGeneration)
  drawRequestList('Throttle requests', throttleRequests, now, carGeneration, sessionGeneration)
  drawApplied('Throttle control', throttleWinner, throttleApplied, throttleRequests, carGeneration, sessionGeneration)
  text('A recorded applied value is the last successful setter call, not a physics readback.')
  text('No applied record does not prove that the car is physically released.')
end

return ControlDebugPanel
