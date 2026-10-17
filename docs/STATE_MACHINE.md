# Máquina de Estados (FSM) dos Carros IA — Realistic Trackday

Documento descreve a **Finite State Machine (FSM)** que governa o comportamento
de cada carro IA: estados, o que fazem, transições e como adicionar novos.

- **Arquivo central:** `CarStateMachine/CarStateMachine.lua`
- **Estados:** `CarStateMachine/States/CarState_<Nome>.lua`
- **Template:** `CarStateMachine/CarState_TEMPLATE.lua`
- **Enum:** `CarStateMachine.CarStateType` (`CarStateMachine.lua:26`)

---

## 1. Visão geral

Cada carro IA é uma **FSM** com três peças de estado por carro:

| Dado | Tabela | Conteúdo |
| --- | --- | --- |
| Estado atual | `cars_state[carIndex]` | valor do enum `CarStateType` |
| Estado anterior | `CarStateMachine.cars_previousState[carIndex]` | de onde viemos |
| Tempo no estado | `CarManager.cars_timeInCurrentState[carIndex]` | segundos acumulados |

### Enum `CarStateType` (bitmask)

Cada estado é uma **potência de 2** (bitmask), mas a FSM usa um valor por vez.

| Valor | Estado | Valor | Estado |
| --- | --- | --- | --- |
| 1 | `DRIVING_NORMALLY` | 1024 | `EASING_IN_OVERTAKE` |
| 4 | `EASING_IN_YIELD` | 2048 | `STAYING_ON_OVERTAKING_LANE` |
| 8 | `STAYING_ON_YIELDING_LANE` | 4096 | `EASING_OUT_OVERTAKE` |
| 32 | `EASING_OUT_YIELD` | 8192 | `NAVIGATING_AROUND_ACCIDENT` |
| 64 | `WAITING_AFTER_ACCIDENT` (só enum) | 16384 | `DRIVING_IN_YELLOW_FLAG_ZONE` |
| 128 | `COLLIDED_WITH_TRACK` | 32768 | `AFTER_CUSTOMAIFLOOD_TELEPORT` |
| 256 | `COLLIDED_WITH_CAR` | 65536 | `DEFENDING_POSITION` |
| 512 | `ANOTHER_CAR_COLLIDED_INTO_ME` | | |

> `WAITING_AFTER_ACCIDENT` existe só no enum; sem arquivo nem funções (legado).

### Contrato das 4 funções

Todo estado registra **4 funções** em **tabelas paralelas** indexadas pelo valor
do estado:

| Tabela | Função | Papel |
| --- | --- | --- |
| `states_entryFunctions` | `entry` | uma vez, ao entrar |
| `states_updateFunctions` | `update` | todo frame no estado |
| `states_transitionFunctions` | `transition` | decide o próximo estado (ou `nil`) |
| `states_exitFunctions` | `exit` | limpeza, ao sair |

`states_minimumTimeInState[state]` define o tempo mínimo (s) antes de poder sair.

### Dispatch de `updateCar`

`CarStateMachine.updateCar(carIndex, dt, sortedCarsList, sortedCarsListIndex)`
(`CarStateMachine.lua:239`) roda por frame nesta ordem:

1. **Transição enfileirada:** se há `queuedStatesToTransitionInto`, faz
   `changeState` e chama a `entry` do novo estado.
2. **Update:** chama `states_updateFunctions[state]`.
3. **Incrementa** `cars_timeInCurrentState += dt`.
4. **Tempo mínimo:** se `currentTimeInState < minimumTimeInState`, `return`.
5. **Transição:** chama `states_transitionFunctions[state]`; se retornar um
   estado, chama a `exit` atual e **enfileira** a transição.

Ou seja: `entry` ocorre no frame seguinte ao `transition`; `exit` é imediato
quando o `transition` decide mudar.

---

## 2. Diagrama de transições (ASCII)

```
                          +---------------------+
                          |  DRIVING_NORMALLY   |  <- estado inicial/default
                          +----------+----------+
                                     |
        +----------------------------+----------------------------+
        |                    |                    |               |
   [yield carro        [overtake carro       [bandeira        [acidente
    atrás]              à frente]             amarela]         à frente]
        |                    |                    |               |
        v                    v                    v               |
+-------+---------+  +-------+----------+  +------+-------+       |
| EASING_IN_YIELD |  | EASING_IN_      |  | DRIVING_IN_  |       |
+-------+---------+  | OVERTAKE        |  | YELLOW_FLAG_ |       |
        |            +-------+---------+  | ZONE         |       |
        v                    v            +------+-------+       |
+-------+-----------+  +-----+-------------+     |               |
| STAYING_ON_       |  | STAYING_ON_       |     |               |
| YIELDING_LANE     |  | OVERTAKING_LANE   |     |               |
+-------+-----------+  +-----+-------------+     |               |
        |                    |                   |               |
        v                    v                   v               |
+-------+-----------+  +-----+-----------+  +----+----------------+--+
| EASING_OUT_YIELD  |  | EASING_OUT_     |  | NAVIGATING_AROUND_     |
+-------+-----------+  | OVERTAKE        |  | ACCIDENT               |
        |              +-----+-----------+  +----+----------------+--+
        +---------+----------+-------------------+
                  v
          +---------------------+
          |  DRIVING_NORMALLY   |
          +---------------------+
```

### Estados especiais (fora do fluxo principal)

```
+---------------------+------------------------------------------------------+
| DEFENDING_POSITION  | mantém a linha de corrida por defenseDuration_s sob  |
|                     | pressão; ao expirar -> EASING_IN_YIELD.              |
+---------------------+------------------------------------------------------+
| DRIVING_IN_YELLOW_  | entra em zona de acidente: reduz velocidade,         |
| FLAG_ZONE           | hazards ligados, colisões desativadas.               |
+---------------------+------------------------------------------------------+
| NAVIGATING_AROUND_  | desvia de carro parado/acidentado via                |
| ACCIDENT            | CollisionAvoidanceManager.computeDesiredLateralOffset|
+---------------------+------------------------------------------------------+
| COLLIDED_WITH_TRACK | stubs: apenas desligam o carro. Sem transição.       |
| COLLIDED_WITH_CAR   |                                                      |
| ANOTHER_CAR_COLLIDED| (este tem minimumTimeInState = 10s)                  |
| _INTO_ME            |                                                      |
+---------------------+------------------------------------------------------+
| AFTER_CUSTOMAIFLOOD | pós-respawn do AI Flood: reinicia fuel/RPM/gear e   |
| _TELEPORT           | reativa o carro. Transição vazia (comentada).        |
+---------------------+------------------------------------------------------+
```

---

## 3. Contrato de cada estado

Formato: arquivo, `minimumTimeInState (min)`, `entry`, `update`, transições e
`exit`.

### 3.1 DRIVING_NORMALLY
- **Arquivo:** `States/CarState_DrivingNormally.lua` — **min:** `0`
- **Entry:** sincroniza offset calculado com o real; alvo =
  `storage.defaultLateralOffset`; limpa refs de overtake/yield; setas off;
  restaura aggression/difficulty/grip/caution padrão; reseta throttle.
- **Update:** `driveSafelyToSide(car, targetOffset, 1000, storage.overrideAiAwareness, true, false)`.
- **Transições:** `handleYellowFlagZone` -> `DRIVING_IN_YELLOW_FLAG_ZONE` /
  `NAVIGATING_AROUND_ACCIDENT`; `handleShouldWeYieldToBehindCar` ->
  `EASING_IN_YIELD`; `handleShouldWeOvertakeFrontCar` -> `EASING_IN_OVERTAKE`.
- **Exit:** `ReasonWhyCantYield = None`. Ignora nos pits ou dentro de
  `storage.deferTimeAfterSessionStart`.

### 3.2 EASING_IN_YIELD
- **Arquivo:** `States/CarState_EasingInYield.lua` — **min:** `0`
- **Entry:** valida `cars_currentlyYieldingCarToIndex` (setado pelo estado
  anterior); offset calculado a partir do real; seta para o lado de yield.
- **Update:** `yieldSafelyToSide(...)`; sem brecha -> `setAIThrottleLimit(0.4)` +
  `setPedalPosition(Brake, 0.2)`.
- **Transições:** perseguidor claramente à frente (`clearAhead_meters`) ->
  `EASING_OUT_YIELD`; chegou ao offset de yield -> `STAYING_ON_YIELDING_LANE`.
- **Exit:** reseta brake, throttle limit e setas.

### 3.3 STAYING_ON_YIELDING_LANE
- **Arquivo:** `States/CarState_StayingOnYieldingLane.lua` — **min:** `0`
- **Entry:** valida o carro perseguidor; `ReasonWhyCantYield = None`.
- **Update:** `setAICaution(AICaution_Yielding)`; agressão/dificuldade de yield
  opcionais; se perseguidor perto (`distanceToOvertakingCarToLimitSpeed`) limita
  throttle/top-speed, senão reseta; `yieldSafelyToSide`.
- **Transições (todas -> `EASING_OUT_YIELD`):** perseguidor não existe, está
  claramente à frente, claramente atrás, somos mais rápidos (leeway `20` km/h)
  ou saiu da faixa de overtake.
- **Exit:** caution, agressão/dificuldade padrão, top-speed, pedais, throttle,
  setas.

### 3.4 EASING_OUT_YIELD
- **Arquivo:** `States/CarState_EasingOutYield.lua` — **min:** `0`
- **Entry:** seta offset calculado; reseta throttle/top-speed/caution; seta
  invertida (voltando ao centro).
- **Update:** `driveSafelyToSide(..., storage_Yielding.rampRelease_mps, ...)`.
- **Transições:** `handleShouldWeYieldToBehindCar` -> `EASING_IN_YIELD` (novo
  carro); chegou ao offset normal (lado de overtake) -> limpa
  `cars_currentlyYieldingCarToIndex` e vai para `DRIVING_NORMALLY`.
- **Exit:** setas.

### 3.5 EASING_IN_OVERTAKE
- **Arquivo:** `States/CarState_EasingInOvertake.lua` — **min:** `0`
- **Entry:** valida `cars_currentlyOvertakingCarIndex`; seta offset calculado.
- **Update:** `calculateAICautionAggressionDifficultyWhileOvertaking`
  (aplica caution/agressão/dificuldade) e `overtakeSafelyToSide(...)`.
- **Transições:** ultrapassado inválido -> `EASING_OUT_OVERTAKE`; carro atrás
  (≠ ultrapassado) pede yield -> `EASING_IN_YIELD`; chegou ao offset ->
  `STAYING_ON_OVERTAKING_LANE`.
- **Exit:** caution, agressão/dificuldade padrão, setas.

### 3.6 STAYING_ON_OVERTAKING_LANE
- **Arquivo:** `States/CarState_StayingOnOvertakingLane.lua` — **min:** `0`
- **Entry:** vazia.
- **Update:** recalcula caution/agressão/dificuldade de overtake e
  `overtakeSafelyToSide` para manter a faixa.
- **Transições:** ultrapassado inválido -> `EASING_OUT_OVERTAKE`;
  `handleOvertakeNextCarWhileAlreadyOvertaking` -> permanece; claramente à
  frente do ultrapassado -> `EASING_OUT_OVERTAKE`; ultrapassado claramente à
  frente (`clearAhead_meters + 40`) -> `EASING_OUT_OVERTAKE`; carro atrás
  (≠ ultrapassado) pede yield -> `EASING_IN_YIELD`.
- **Exit:** caution, dificuldade/agressão padrão, setas.

### 3.7 EASING_OUT_OVERTAKE
- **Arquivo:** `States/CarState_EasingOutOvertake.lua` — **min:** `0`
- **Entry:** valida `cars_currentlyOvertakingCarIndex`; seta offset calculado.
- **Update:** `driveSafelyToSide(..., storage_Overtaking.overtakeRampRelease_mps, ...)`.
- **Transições:** ultrapassado inválido -> `DRIVING_NORMALLY`; carro atrás
  (≠ ultrapassado) pede yield -> `EASING_IN_YIELD`;
  `handleOvertakeNextCarWhileAlreadyOvertaking` -> `EASING_IN_OVERTAKE`; chegou
  ao offset normal (lado de yield) -> limpa ref e vai para `DRIVING_NORMALLY`.
- **Exit:** setas.

### 3.8 DEFENDING_POSITION (novo)
- **Arquivo:** `States/CarState_DefendingPosition.lua` (também inline em
  `CarStateMachine.lua:614-720` para máxima compatibilidade) — **min:** `0`
- **Entry:** sorteia `defenseDuration_s` em `[defenseDurationMin_s,
  defenseDurationMax_s]` (default `1.0`–`3.0` s de `getStorage_Behavior`);
  `StateExitReason.YieldingToCar`.
- **Update:** decrementa o timer e chama
  `driveSafelyToSide(car, storage.defaultLateralOffset, 1000, true, false, false)`.
- **Transições:** timer `<= 0` -> `EASING_IN_YIELD`; carro de trás não pressiona
  mais -> `DRIVING_NORMALLY`. Pressão = distância `<= 30 m` **e** velocidade
  relativa `carBehind - our >= 5 km/h`.
- **Exit:** limpa `cars_defenseRemainingTime_s[carIndex]`.
- **Nota:** definido, mas **ainda sem transição de entrada** a partir de outros
  estados; pronto para ser conectado.

### 3.9 DRIVING_IN_YELLOW_FLAG_ZONE
- **Arquivo:** `States/CarState_DrivingInYellowFlagZone.lua` — **min:** `0`
- **Entry:** vazia.
- **Update:** `setAITopSpeed(50)`, `toggleTurningLights(Hazards)`,
  `toggleCarCollisions(false)`.
- **Transições:** `isCarComingUpToAccident` dentro de
  `distanceToStartNavigatingAroundCarInAccident_meters` ->
  `NAVIGATING_AROUND_ACCIDENT`; saiu da zona -> `DRIVING_NORMALLY`.
- **Exit:** top-speed e setas.

### 3.10 NAVIGATING_AROUND_ACCIDENT
- **Arquivo:** `States/CarState_NavigatingAroundAccident.lua` — **min:** `0`
- **Entry:** vazia.
- **Update:** `setAICaution(0)`, `setAITopSpeed(30)`; recalcula acidente mais
  próximo; offset via `CollisionAvoidanceManager.computeDesiredLateralOffset`;
  `driveSafelyToSide(..., 5, true, false)`; `preventAIFromRetiring`;
  `toggleCarCollisions(false)`.
- **Transições:** sem índice de acidente, acidente resolvido, carro não
  encontrado, ou já passamos e estamos a `> 10 m` -> `DRIVING_NORMALLY`;
  acidente mais próximo detectado -> permanece.
- **Exit:** caution, top-speed, pedais e `cars_navigatingAroundAccidentIndex = 0`.

### 3.11 COLLIDED_WITH_TRACK
- **Arquivo:** `States/CarState_CollidedWithTrack.lua` — **min:** `0`
- **Entry/Exit:** vazias. **Update:** `stopCarAfterAccident(carIndex)`.
- **Transição:** vazia — **estado terminal**.

### 3.12 COLLIDED_WITH_CAR
- **Arquivo:** `States/CarState_CollidedWithCar.lua` — **min:** `0`
- **Entry/Exit:** vazias. **Update:** `stopCarAfterAccident(carIndex)` +
  `toggleCarCollisions(false)`.
- **Transição:** vazia — **estado terminal**.

### 3.13 ANOTHER_CAR_COLLIDED_INTO_ME
- **Arquivo:** `States/CarState_AnotherCarCollidedIntoMe.lua` — **min:** `10`
- **Entry:** `ac.overrideCarControls` (horn comentado).
- **Update:** `stopCarAfterAccident(carIndex)` + `toggleCarCollisions(false)`.
- **Transição:** vazia — **estado terminal** (o min de 10 s não leva a lugar
  algum). **Exit:** vazia.

### 3.14 AFTER_CUSTOMAIFLOOD_TELEPORT
- **Arquivo:** `States/CarState_AfterCustomAIFloodTeleport.lua` — **min:** `0`
- **Entry:** `setCarFuel(100)`, `engageGear(3)`, `setEngineRPM(5000)`,
  `setAIStopCounter(0)`.
- **Update:** `setGentleStop(false)`, `setAICaution(0)`, `awakeCar`,
  `setAINoInput(false, false)`, `setAIStopCounter(0)`.
- **Transição:** vazia (condições comentadas) — permanece. **Exit:**
  `setAICaution(1)`, reset gas, `cars_doNoResetAfterNextCarJump = false`.

### 3.15 TEMPLATE
- **Arquivo:** `CarStateMachine/CarState_TEMPLATE.lua`
- Modelo para novos estados: define `STATE`, string, tempo mínimo e as 4
  funções vazias. Não registrar no enum — é só ponto de partida.

---

## 4. Transições importantes (regras)

As decisões de yield/overtake ficam em
`CarStateMachine.handleShouldWeYieldToBehindCar` (`CarStateMachine.lua:577`) e
`CarStateMachine.handleShouldWeOvertakeFrontCar` (`CarStateMachine.lua:405`).

### 4.1 `handleShouldWeYieldToBehindCar`

Percorre os carros atrás dentro de `detectCarBehind_meters` e retorna
`EASING_IN_YIELD` só quando **todas** passam:

- carro de trás não está nos pits;
- está dentro de `detectCarBehind_meters`;
- está de fato atrás (`isFirstCarBehindSecondCar`);
- somos mais lentos que ele (`yieldingCarSpeed < overtakingCarSpeed`);
- se `requireOvertakingCarToBeOnOvertakingLane`, está na faixa de overtake.

Senão, registra um `ReasonWhyCantYield` (ex.: `TargetSideBlocked`,
`OvertakingCarTooFarBehind`, `WeAreFasterThanOvertakingCar`) e retorna `nil`.

### 4.2 `handleShouldWeOvertakeFrontCar`

Retorna `EASING_IN_OVERTAKE` quando:

- há carro à frente e ele não está nos pits;
- distância `<= detectCarAhead_meters`;
- somos mais rápidos (`averageSpeedKmh` comparado);
- se `requireYieldingCarToBeOnYieldingLane`, ele está na faixa de yield;
- o carro atrás (se existir) não está a menos de 5 m.

Senão registra `ReasonWhyCantOvertake` (ex.: `YieldingCarIsFaster`,
`YieldingCarTooFarAhead`, `AnotherCarBehindTooClose`) e retorna `nil`.

### 4.3 Regras resumidas por situação

- **Em `DRIVING_NORMALLY`:** carro atrás claramente mais rápido ->
  `EASING_IN_YIELD`; carro à frente mais lento e elegível ->
  `EASING_IN_OVERTAKE`; zona amarela / acidente -> estados correspondentes.
- **Yield em andamento:** qualquer sinal de que o perseguidor não precisa mais
  da faixa (à frente, atrás demais, nós mais rápidos, fora da faixa) ->
  `EASING_OUT_YIELD`.
- **Overtake em andamento:** terminamos ou o ultrapassado volta à frente ->
  `EASING_OUT_OVERTAKE`; novo carro à frente elegível -> continua ultrapassando
  (`handleOvertakeNextCarWhileAlreadyOvertaking`).
- **`DEFENDING_POSITION`:** timer não zerou e há pressão -> mantém a linha;
  timer zerou -> `EASING_IN_YIELD`; pressão acabou -> `DRIVING_NORMALLY`.

---

## 5. Como adicionar um novo estado (workflow)

1. **Bitflag** no enum `CarStateType` em `CarStateMachine.lua`, próxima potência
   de 2 livre (ex.: `MY_STATE = 131072`).
2. **String** em `CarStateTypeStrings[MY_STATE] = "MyState"`.
3. **Tempo mínimo:** `states_minimumTimeInState[MY_STATE] = 0` (use `0` salvo
   motivo forte).
4. **Registrar as 4 funções:** `states_entryFunctions`,
   `states_updateFunctions`, `states_transitionFunctions`,
   `states_exitFunctions`.
5. **Criar** `States/CarState_<Nome>.lua` espelhando `CarState_TEMPLATE.lua`.
6. **Opcionalmente espelhar inline** em `CarStateMachine.lua` (como
   `DEFENDING_POSITION`, que mantém as duas versões).
7. **Adicionar transições de/para** esse estado nas funções `transition` dos
   estados relevantes.
8. **Expor no debug/UI** se necessário (nome legível já vem do passo 2).

---

## 6. Pontos de cautela

- **Tempo mínimo longo prende a IA.** Use `minimumTimeInState = 0` na maioria;
  `10` é o maior usado (`ANOTHER_CAR_COLLIDED_INTO_ME`).
- **Dependências circulares sem escape.** Se A vai para B e B para A, garanta um
  timer/condição de saída (ex.: o timer de `DEFENDING_POSITION`).
- **Estados terminais são intencionais** (`COLLIDED_*`): transição vazia mantém
  o carro parado. Não adicione transições sem revisar `AccidentManager`.
- **Refs salvas pelo estado anterior.** `EASING_IN_YIELD` e
  `EASING_IN_OVERTAKE` dependem de `cars_currentlyYieldingCarToIndex` /
  `cars_currentlyOvertakingCarIndex` definidos antes da entrada.
- **`changeState` reseta `cars_timeInCurrentState`** — não confie no tempo
  anterior após transição.
- **Transições são enfileiradas:** a `entry` roda no início do próximo
  `updateCar`, não no frame que decidiu.
- **Sem `entry` registrada**, `updateCar` loga erro e aborta o frame do carro
  (`CarStateMachine.lua:283`).

---

## 7. Camadas transversais (não são estados)

```
+-------- BehaviorPolish (não é estado; condiciona transições) --------------+
| phase blend:      fade in/out das laterais em N segundos                   |
| hesitação:        delay aleatório antes de agir                            |
| look-ahead ruído: antecipação com confiança gaussiana                      |
+----------------------------------------------------------------------------+

+-------- HumanErrorManager (transversal, não é estado) ---------------------+
| dispara physics.setAIBrakeMistake / setAITractionMistake com cooldown      |
| padrão de 7 s (errorCooldown_s)                                            |
+----------------------------------------------------------------------------+
```

- **BehaviorPolish** (`BehaviorPolish.lua`): módulo puro com `lerp` (blend de
  fases), `shouldReactNow` (hesitação) e `confidenceFromPaceObservations`
  (look-ahead com ruído ~5%). Não usa `ac.*`/`physics.*`.
- **HumanErrorManager** (`HumanErrorManager.lua`): atualizado por frame
  (`HumanErrorManager.update(dt, sortedCars, storage_Behavior, gameTime_s)`);
  injeta erros humanos de brake/traction com cooldown (`errorCooldown_s`,
  default `7.0`).
