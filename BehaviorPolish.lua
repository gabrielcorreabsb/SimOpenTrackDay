-- BehaviorPolish.lua
-- Polimento de comportamento da IA: 3 camadas que tornam a IA mais natural.
-- Modulo puro: sem ac.*, physics.* ou qualquer dependencia externa.
-- math.random e permitido (assumindo seed externo, sem responsabilidade aqui).

local BehaviorPolish = {}

-- ============================================================
-- 1. PHASE BLEND
-- Rampa suave de um valor inicial ao alvo ao longo de `blendTime_s`.
-- Funcao: BehaviorPolish.lerp(currentValue, targetValue, blendTime_s, dt) -> newValue
-- ============================================================
BehaviorPolish.lerp = function(currentValue, targetValue, blendTime_s, dt)
  if blendTime_s <= 0 then return targetValue end
  local step = dt / blendTime_s
  return currentValue + (targetValue - currentValue) * math.min(step, 1.0)
end

-- ============================================================
-- 2. HESITACAO
-- Atraso aleatorio antes de agir.
-- Funcao: BehaviorPolish.shouldReactNow(reactionDelay_s, jitter_s, lastReactionTime_s, currentTime_s) -> boolean
-- ============================================================
BehaviorPolish.shouldReactNow = function(reactionDelay_s, jitter_s, lastReactionTime_s, currentTime_s)
  if reactionDelay_s <= 0 and jitter_s <= 0 then return true end
  local delay = reactionDelay_s + (math.random() - 0.5) * 2 * jitter_s
  return (currentTime_s - lastReactionTime_s) >= delay
end

-- ============================================================
-- 3. LOOK-AHEAD COM RUIDO
-- Coleta amostras de pace (delta speed vs carro da frente) ao longo de uma
-- janela, retorna confianca (0..1) com ruido gaussiano.
-- Funcao: BehaviorPolish.confidenceFromPaceObservations(paceObservations, threshold) -> number
-- ============================================================
BehaviorPolish.confidenceFromPaceObservations = function(paceObservations, threshold)
  if #paceObservations == 0 then return 0 end
  local sum = 0
  for _, v in ipairs(paceObservations) do sum = sum + v end
  local mean = sum / #paceObservations
  -- ruido ~5% via gaussiana de media 1
  local noise = 1.0 + (math.random() - 0.5) * 0.1
  local confidence = (mean / threshold) * noise
  return math.max(0, math.min(1, confidence))
end

return BehaviorPolish
