local HumanErrorManager = {}
local table_clear = table.clear
HumanErrorManager.lastEventTimeByCar = {}  -- carIndex → timestamp_s
HumanErrorManager.errorCountByCar = {}      -- carIndex → integer

-- Atualiza erros para todos os carros. Chamada do MANIFEST__UPDATE.
-- @param dt number
-- @param sortedCarsList table<integer, ac.StateCar>
-- @param storage_Behavior table — storage do Behavior (lê humanErrorEnabled, lockupProb, tractionProb, errorCooldown_s)
-- @param gameTime_s number — tempo atual de jogo (de GameTimeManager.getPlayingGameTime())
function HumanErrorManager.update(dt, sortedCarsList, storage_Behavior, gameTime_s)
  if type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge
    or type(gameTime_s) ~= 'number' or gameTime_s ~= gameTime_s then return end
  if not storage_Behavior.humanErrorEnabled then return end
  local lockupProb = storage_Behavior.humanLockupProbability or 0.0
  local tractionProb = storage_Behavior.humanTractionMistakeProbability or 0.0
  local cooldown = storage_Behavior.errorCooldown_s or 7.0  -- default razoável

  for _, car in ipairs(sortedCarsList) do
    local carIndex = car.index
    if not CarManager.isWritableAICar(carIndex) or car.index ~= carIndex then
      HumanErrorManager.lastEventTimeByCar[carIndex] = nil
      HumanErrorManager.errorCountByCar[carIndex] = nil
    else
    local lastT = HumanErrorManager.lastEventTimeByCar[carIndex] or -1000

    -- lock-up: brake pressure > 0.9 + curvatura significativa + cooldown + roll aleatório
    if car.brake > 0.9 and (gameTime_s - lastT) >= cooldown and math.random() < lockupProb * dt then
      -- duration entre 0.2 e 0.5s; severity 0.3..0.7
      local duration = 0.2 + math.random() * 0.3
      if physics and type(physics.setAIBrakeMistake) == 'function' then physics.setAIBrakeMistake(carIndex, duration) else break end
      HumanErrorManager.lastEventTimeByCar[carIndex] = gameTime_s
      HumanErrorManager.errorCountByCar[carIndex] = (HumanErrorManager.errorCountByCar[carIndex] or 0) + 1
    elseif car.gas > 0.8 and (gameTime_s - lastT) >= cooldown and math.random() < tractionProb * dt then
      local duration = 0.2 + math.random() * 0.3
      local severity = 0.3 + math.random() * 0.4
      if physics and type(physics.setAITractionMistake) == 'function' then physics.setAITractionMistake(carIndex, duration, severity) else break end
      HumanErrorManager.lastEventTimeByCar[carIndex] = gameTime_s
      HumanErrorManager.errorCountByCar[carIndex] = (HumanErrorManager.errorCountByCar[carIndex] or 0) + 1
    end
    end
  end
end

function HumanErrorManager.resetCar(carIndex)
  HumanErrorManager.lastEventTimeByCar[carIndex] = nil
  HumanErrorManager.errorCountByCar[carIndex] = nil
end

function HumanErrorManager.resetAll()
  table_clear(HumanErrorManager.lastEventTimeByCar)
  table_clear(HumanErrorManager.errorCountByCar)
end

return HumanErrorManager
