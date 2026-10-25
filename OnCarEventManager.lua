local OnCarEventManager = {}
local QueueManager = QueueManager
local CarManager = CarManager
local rawget, type, pcall = rawget, type, pcall
local function observe(...)
  local lookupOK, logger = pcall(rawget, _G, 'Logger')
  if not lookupOK then return end
  local observeOK, fn = pcall(rawget, logger, 'observe')
  if not observeOK then return end
  if type(fn) == 'function' then pcall(fn, ...) end
end
local function observeEventProtected(kind, event, detail)
  if detail == nil then
    detail = event.type == OnCarEventManager.OnCarEventType.Collision and 'collision' or 'jumped'
  end
  observe(kind, event.index, event.generation, nil, nil, detail, nil, event.session)
end
local function observeEvent(kind, event, detail)
  pcall(observeEventProtected, kind, event, detail)
end

OnCarEventManager.OnCarEventType = { None = 0, Collision = 1, Jumped = 2 }
OnCarEventManager.OnCarEventExecutions = {}

-- Fixed-capacity FIFO of reusable records; overflow drops newest callback fail-closed.
local EVENT_CAPACITY = 256
local events, head, tail, count = {}, 1, 1, 0
for i = 1, EVENT_CAPACITY do events[i] = { collisionPosition = {} } end
local function validIndex(index)
  return type(index) == 'number' and index == index and index >= 0 and index < math.huge and index % 1 == 0
end
local function finiteNumber(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function OnCarEventManager.enqueueOnCarEvent(eventType, carIndex, collisionLocalPosition, collidedWith, carSnapshot, victimSnapshot)
  if not validIndex(carIndex) then observe('queue-rejected', nil, nil, nil, nil, 'invalid-index'); return false end
  if eventType == OnCarEventManager.OnCarEventType.Collision
    and (collisionLocalPosition == nil or not finiteNumber(collisionLocalPosition.x)
      or not finiteNumber(collisionLocalPosition.y) or not finiteNumber(collisionLocalPosition.z)
      or not finiteNumber(collidedWith) or collidedWith < 0 or collidedWith % 1 ~= 0) then
    observe('queue-rejected', carIndex, nil, nil, nil, 'invalid-collision-payload'); return false
  end
  if count >= EVENT_CAPACITY then
    if eventType == OnCarEventManager.OnCarEventType.Jumped then OnCarEventManager.clear() else
      observe('queue-overflow', carIndex, nil, nil, nil, 'collision-drop-newest'); return false
    end
  end
  if eventType == OnCarEventManager.OnCarEventType.Jumped then
    CarManager.bumpCarGeneration(carIndex)
  end
  local event = events[tail]
  tail = tail % EVENT_CAPACITY + 1
  count = count + 1
  event.type, event.index = eventType, carIndex
  event.session = CarManager.sessionGeneration
  event.generation = CarManager.getCarGeneration(carIndex)
  event.culpritGeneration = event.generation
  event.victimIndex, event.victimGeneration = nil, nil
  event.x, event.y, event.z = nil, nil, nil
  event.positionX, event.positionY, event.positionZ, event.splinePosition = nil, nil, nil, nil
  event.victimPositionX, event.victimPositionY, event.victimPositionZ, event.victimSplinePosition = nil, nil, nil, nil
  event.culpritIsInPitlane, event.victimIsInPitlane = nil, nil
  event.culpritSpeedKmh, event.victimSpeedKmh = nil, nil
  if eventType == OnCarEventManager.OnCarEventType.Collision then
    event.x, event.y, event.z = collisionLocalPosition.x, collisionLocalPosition.y, collisionLocalPosition.z
    event.collisionPosition.x, event.collisionPosition.y, event.collisionPosition.z = event.x, event.y, event.z
    if carSnapshot then
      local position = carSnapshot.position
      if position then event.positionX, event.positionY, event.positionZ = position.x, position.y, position.z end
      event.splinePosition = carSnapshot.splinePosition
      if type(carSnapshot.isInPitlane) == 'boolean' then event.culpritIsInPitlane = carSnapshot.isInPitlane end
      if finiteNumber(carSnapshot.speedKmh) then event.culpritSpeedKmh = carSnapshot.speedKmh end
    end
    if victimSnapshot then
      local victimPosition = victimSnapshot.position
      if victimPosition then event.victimPositionX, event.victimPositionY, event.victimPositionZ = victimPosition.x, victimPosition.y, victimPosition.z end
      event.victimSplinePosition = victimSnapshot.splinePosition
      if type(victimSnapshot.isInPitlane) == 'boolean' then event.victimIsInPitlane = victimSnapshot.isInPitlane end
      if finiteNumber(victimSnapshot.speedKmh) then event.victimSpeedKmh = victimSnapshot.speedKmh end
    end
    if collidedWith > 0 and collidedWith % 1 == 0 then
      event.victimIndex = collidedWith - 1
      event.victimGeneration = CarManager.getCarGeneration(event.victimIndex)
    end
    event.collidedWith = collidedWith
  end
  observeEvent('queue-received', event,
    eventType == OnCarEventManager.OnCarEventType.Collision and 'collision' or 'jumped')
  return true
end

function OnCarEventManager.clear()
  if count > 0 then observe('pending-clear', nil, nil, nil, nil, 'on-car-event-queue') end
  while count > 0 do
    events[head].type = nil
    head = head % EVENT_CAPACITY + 1
    count = count - 1
  end
  head, tail = 1, 1
end

function OnCarEventManager.processQueuedEvents()
  while count > 0 do
    local event = events[head]
    head = head % EVENT_CAPACITY + 1
    count = count - 1
    if event.session == CarManager.sessionGeneration
      and event.generation == CarManager.getCarGeneration(event.index)
      and (event.type ~= OnCarEventManager.OnCarEventType.Collision
        or event.victimIndex == nil or event.victimGeneration == CarManager.getCarGeneration(event.victimIndex)) then
      local execute = OnCarEventManager.OnCarEventExecutions[event.type]
      if execute then
        observeEvent('queue-dispatched', event)
        execute(event.index, event)
        observeEvent('queue-callback-returned', event)
      end
    else
      observeEvent('queue-stale', event, 'identity-or-session-mismatch')
    end
    event.type = nil
  end
  head, tail = 1, 1
end

return OnCarEventManager
