local HumanErrorManager = {}
HumanErrorManager.lastEventTimeByCar = {}  -- carIndex → timestamp_s
HumanErrorManager.errorCountByCar = {}      -- carIndex → integer

-- Atualiza erros para todos os carros. Chamada do MANIFEST__UPDATE.
-- @param dt number
-- @param sortedCarsList table<integer, ac.StateCar>
-- @param storage_Behavior table — storage do Behavior (lê humanErrorEnabled, lockupProb, tractionProb, errorCooldown_s)
-- @param gameTime_s number — tempo atual de jogo (de GameTimeManager.getPlayingGameTime())
function HumanErrorManager.update(dt, sortedCarsList, storage_Behavior, gameTime_s)
  if not storage_Behavior.humanErrorEnabled then return end
  local lockupProb = storage_Behavior.humanLockupProbability or 0.0
  local tractionProb = storage_Behavior.humanTractionMistakeProbability or 0.0
  local cooldown = storage_Behavior.errorCooldown_s or 7.0  -- default razoável

  for _, car in ipairs(sortedCarsList) do
    local carIndex = car.index
    local lastT = HumanErrorManager.lastEventTimeByCar[carIndex] or -1000

    -- lock-up: brake pressure > 0.9 + curvatura significativa + cooldown + roll aleatório
    if car.brake > 0.9 and (gameTime_s - lastT) >= cooldown and math.random() < lockupProb * dt then
      -- duration entre 0.2 e 0.5s; severity 0.3..0.7
      local duration = 0.2 + math.random() * 0.3
      physics.setAIBrakeMistake(carIndex, duration)
      HumanErrorManager.lastEventTimeByCar[carIndex] = gameTime_s
      HumanErrorManager.errorCountByCar[carIndex] = (HumanErrorManager.errorCountByCar[carIndex] or 0) + 1
    elseif car.gas > 0.8 and (gameTime_s - lastT) >= cooldown and math.random() < tractionProb * dt then
      local duration = 0.2 + math.random() * 0.3
      local severity = 0.3 + math.random() * 0.4
      physics.setAITractionMistake(carIndex, duration, severity)
      HumanErrorManager.lastEventTimeByCar[carIndex] = gameTime_s
      HumanErrorManager.errorCountByCar[carIndex] = (HumanErrorManager.errorCountByCar[carIndex] or 0) + 1
    end
  end
end

return HumanErrorManager
