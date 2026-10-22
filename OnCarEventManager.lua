local OnCarEventManager = {}
local QueueManager = QueueManager
local CarManager = CarManager

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
  if not validIndex(carIndex) then return false end
  if eventType == OnCarEventManager.OnCarEventType.Collision
    and (collisionLocalPosition == nil or not finiteNumber(collisionLocalPosition.x)
      or not finiteNumber(collisionLocalPosition.y) or not finiteNumber(collisionLocalPosition.z)
      or not finiteNumber(collidedWith) or collidedWith < 0 or collidedWith % 1 ~= 0) then return false end
  if count >= EVENT_CAPACITY then
    if eventType == OnCarEventManager.OnCarEventType.Jumped then OnCarEventManager.clear() else return false end
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
  if eventType == OnCarEventManager.OnCarEventType.Collision then
    event.x, event.y, event.z = collisionLocalPosition.x, collisionLocalPosition.y, collisionLocalPosition.z
    event.collisionPosition.x, event.collisionPosition.y, event.collisionPosition.z = event.x, event.y, event.z
    if carSnapshot then
      local position = carSnapshot.position
      if position then event.positionX, event.positionY, event.positionZ = position.x, position.y, position.z end
      event.splinePosition = carSnapshot.splinePosition
    end
    if victimSnapshot then
      local victimPosition = victimSnapshot.position
      if victimPosition then event.victimPositionX, event.victimPositionY, event.victimPositionZ = victimPosition.x, victimPosition.y, victimPosition.z end
      event.victimSplinePosition = victimSnapshot.splinePosition
    end
    if collidedWith > 0 and collidedWith % 1 == 0 then
      event.victimIndex = collidedWith - 1
      event.victimGeneration = CarManager.getCarGeneration(event.victimIndex)
    end
    event.collidedWith = collidedWith
  end
  return true
end

function OnCarEventManager.clear()
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
      if execute then execute(event.index, event) end
    end
    event.type = nil
  end
  head, tail = 1, 1
end

return OnCarEventManager
