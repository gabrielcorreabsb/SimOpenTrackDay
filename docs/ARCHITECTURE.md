# ARCHITECTURE.md — Mapa Arquitetural

> Mapa denso do código para **desenvolvedores** e **AI agents** que vão modificar o app.
> Leia o `docs/AGENT.md` primeiro para o onboarding; este documento entra no "como as peças se encaixam".

Escopo: app **LuaJIT 2.1 / Lua 5.1** carregado pelo **CSP** como `apps/lua/SimOpenTrackDay/manifest.ini`. A compatibilidade de APIs é checada pelo entry point; runtime e visual in-game não estão validados por este mapa.
Entry point: `SimOpenTrackDay.lua`. O `manifest.ini` registra os callbacks:

| Callback | Onde | Papel |
| --- | --- | --- |
| `MANIFEST__UPDATE(dt)` | `SimOpenTrackDay.lua` | **Coração por frame**: física/decisão de todos os carros |
| `MANIFEST__FUNCTION_MAIN(dt)` | `SimOpenTrackDay.lua` | Janela principal (ImGui) |
| `MANIFEST__FUNCTION_SETTINGS()` | `SimOpenTrackDay.lua` | Janela de settings |
| `MANIFEST__FUNCTION_ICON()` | `SimOpenTrackDay.lua` | Desenho vetorial do ícone OTD |
| `MANIFEST__TRANSPARENT(dt)` | `SimOpenTrackDay.lua` | Overlay world-space (texto overhead, nome do carro) |

---

## 1. Visão geral

### 1.1 Fluxo por frame (ASCII)

```
 manifest.ini [SIM_CALLBACKS] UPDATE
        │
        ▼
 script.MANIFEST__UPDATE(dt)              SimOpenTrackDay.lua
        │  shouldAppRun()? não → return
        │  sim.isPaused?   não → return
        │
        ├─ GameTimeManager.update(dt)
        ├─ CarManager._currentFrameId += 1  ← invalida cache lateral/frame
        ├─ SessionDetails.update(dt)
        ├─ CameraManager.getFocusedCarIndex()
        │     └─ RaceTrackManager.isSplinePositionInYellowZone(pos)
        │           └─ RaceFlagManager.set/removeRaceFlag(Caution)
        │
        ├─── carList = CarManager.cars_currentReusableList
        │        table.clear(carList)  ← reuso, sem alocar
        │        for i, car in ac.iterateCars() do
        │             CarManager.ensureDefaults(car.index)
        │             CarManager.saveCarSpeed(car)  ← buffer de velocidade
        │             CarStateMachine.setReasonWhyCantYield/Overtake(None)
        │        end
        │
        ├─ sortedCars = CarManager.sortCarListByTrackPosition(carList)
        │        └─ insertion sort incremental (ver §2)
        │
        ├─ OnCarEventManager.processQueuedEvents()
        ├─ CarStateMachine.handleQueuedAccidents()
        ├─ HumanErrorManager.update(dt, sortedCars, storage_Behavior, t)
        │
        ├─ for i = 1, #sortedCars do
        │     CarManager.sortedCarList_carIndexToSortedIndex[carIndex] = i
        │     if car.isAIControlled then
        │         CarStateMachine.updateCar(carIndex, dt, sortedCars, i)
        │             └─ estado atual → states_transitionFunctions → states_updateFunctions
        │                    └─ (yield/overtake) → CarOperations.driveSafelyToSide(...)
        │                          └─ physics.setAISplineOffset(...)   // consome o offset lateral
        │         CarOperations.setAITopSpeed(carIndex, min(requested, global))
        │     end
        │  end
        │
        ├─ RaceTrackManager.updateYellowFlagZones()
        └─ debug override (opcional, storage_Debugging)
```

### 1.2 Subsistemas (responsabilidade em 1 linha)

**Núcleo (modificam o comportamento):**

- `SimOpenTrackDay.lua` — bootstrap do CSP, bindings, registro de callbacks, loop por frame (`MANIFEST__UPDATE`), UI de entrada.
- `CarManager.lua` — DoD de estado por `carIndex`, defaults, amostragem de velocidade, cache de offset lateral, sort incremental da lista de carros.
- `CarOperations.lua` — wrappers de `physics.*` + drive/yield/overtake, raycasts de bloqueio, anchor points, anti-drag-race, teleporte.
- `CarStateMachine/CarStateMachine.lua` — FSM central por carro: `states_entryFunctions` / `states_transitionFunctions` / `states_updateFunctions` / `states_exitFunctions`.
- `CarStateMachine/States/*.lua` — implementação de cada estado (ver `docs/STATE_MACHINE.md`).
- `StorageManager.lua` — DoD de opções (enum → collection → fillInDoDTables → storageTable → `ac.storage`) + perfis de comportamento.
- `SettingsWindow.lua` — UI de configurações (ImGui), seções de sliders (Global/Debugging/AI Car Values/Yielding/Overtaking/Behavior/Pathfinding).
- `UIManager.lua` — tabela de debug por carro, texto overhead, seção de lateral offsets (preview).
- `RaceTrackManager.lua` — metadata da pista (nome/comprimento/sessão), lados yield/overtake, bucket de yellow zones.
- `BehaviorPolish.lua` — funções **puras**: phase blend (`lerp`), hesitação (`shouldReactNow`), look-ahead com ruído (`confidenceFromPaceObservations`).
- `HumanErrorManager.lua` — dispara `physics.setAIBrakeMistake` / `setAITractionMistake` com probabilidade e cooldown.
- `RaceFlagManager.lua` — `setRaceFlag`/`removeRaceFlag` (bandeira de caution via `physics.overrideRacingFlag`).
- `AccidentManager.lua` — registro de acidentes + zonas amarelas + navegação ao redor; `simulateAccident*()`.

**Experimento / desligado:**

- `Pathfinding.lua` — paths laterais em situações de tapado. **Requerido pelo entry point**, mas só roda com `Constants.PATHFINDING_DEBUGGING`. Não altera produção.
- `FrenetAvoid.lua` — planner frenet mínimo. `require` **comentado**. Desligado.
- `CollisionAvoidanceManager.lua` — `computeDesiredLateralOffset` ao redor de acidente. `require` **comentado**. Desligado.
- `CarSpeedLimiter.lua` — limiter via slew de pedais (contorna falha do `setAITopSpeed`). `require` comentado.
- `CustomAIFloodManager.lua` — teleporte/ciclo de AI Flood. `require` comentado.
- `Profiler.lua` — profiler hierárquico (begin/end, amostragem). `require` comentado; **nunca usado em produção**.

**Suporte (raramente o foco de mudanças de IA):**

- `OnCarEventManager.lua` — fila de eventos `Collision`/`Jumped`; enfileira e processa 1x/frame.
- `GameTimeManager.lua` — tempo de jogo acumulado; base de cooldowns (ex.: `HumanErrorManager`).
- `SessionDetails.lua` — tempo desde o início da sessão; usado no defer de yield/overtake.
- `CameraManager.lua` — carro focado pela câmera (usado na lógica de yellow flag).
- `Strings/` + `StringsManager.lua` — textos de debug (reason why cant yield/overtake, state exit reason).
- `DataStructures/` — `QueueManager`, `StackManager`, `DequeManager`, `CompletableIndexCollectionManager`.
- `VecPool.lua` — singleton de `vec3` temporário (`getTempVec3`).
- `MathHelpers.lua` — vetores/escalares sem alocação.
- `ColorManager.lua`, `AppIconRenderer.lua`, `UIOperations.lua`, `UILateralOffsetsImageWidget.lua`, `UIAppNameVersionWidget.lua` — UI.
- `Constants.lua`, `Logger.lua`, `Enum.lua` — constantes, log e helpers de bit flags.
- `lib/ac_apps/` — SDK do CSP (vendor; não editar como código do app). `lib/AssettoCorsaCSPLuaCompatibilityManager/` é o submodule de compatibilidade, a atualizar deliberadamente. `lib/uilib/` é biblioteca própria do projeto e não deve ser confundida com vendor.

### 1.3 Ordem de `require` (importa!)

`SimOpenTrackDay.lua` carrega os módulos na ordem: `Constants` → `Logger` → `CSPCompatibilityManager` → `VecPool` → DataStructures → `GameTimeManager` → `AppIconRenderer` → `ColorManager` → `RaceTrackManager` → `StorageManager` → `MathHelpers` → `CarManager` → `CarOperations` → `CameraManager` → `Strings*` → `StringsManager` → `OnCarEventManager` → `CarStateMachine` → `States/*` → `AccidentManager` → `RaceFlagManager` → UI → `SessionDetails` → `Pathfinding` → `BehaviorPolish` → `HumanErrorManager` → `SettingsWindow`.

Motivo: **vários módulos capturam storage no load time**, ex. `CarStateMachine/CarStateMachine.lua`:
```lua
local storage_Yielding = StorageManager.getStorage_Yielding()
local storage_Debugging = StorageManager.getStorage_Debugging()
```
Por isso `StorageManager` precisa ser requerido antes deles. Não reordene sem checar capturas de load time.

---

## 2. Hot paths (por frame)

Otimizações já aplicadas — **preserve-as** ao modificar.

### 2.1 Cache de offset lateral real

`CarManager.getActualTrackLateralOffset(carIndex, carPosition)` (`CarManager.lua`):
```lua
local cached = CarManager.cars_lateralOffsetCacheByCar[carIndex]
if cached and cached.frameId == CarManager._currentFrameId then return cached.x end
-- só aqui chama a API cara:
local carTrackCoordinates = ac.worldCoordinateToTrack(carPosition)
CarManager.cars_lateralOffsetCacheByCar[carIndex] = {x = carTrackCoordinates.x, frameId = CarManager._currentFrameId}
```
- `CarManager._currentFrameId` é incrementado **uma vez** por `MANIFEST__UPDATE`.
- Regra: **só chame `ac.worldCoordinateToTrack` em cache miss.** Vários call sites (`isCarDrivingOnSide`, side checks) dependem disso.

### 2.2 Lista de carros reutilizável

`SimOpenTrackDay.lua`:
```lua
local carList = CarManager.cars_currentReusableList
table.clear(carList)
```
- **Nunca** faça `carList = {}` por frame. `cars_currentReusableList` (declarada em `CarManager.lua`) é reusada; o sort é feito **in place**.

### 2.3 Sort incremental

`CarManager.sortCarListByTrackPosition(carList)` (`CarManager.lua`):
1. Conta carros "dirty" comparando `CarManager.cars_previousSplinePosition[car.index]` com a posição atual.
2. Se `dirtyCarsCount > totalCars * 0.5` → `table.sort` completo (fallback).
3. Senão → **insertion sort** incremental (O(n) com poucas mudanças), reordenando só o que saiu de ordem.
4. Cacheia as posições atuais em `cars_previousSplinePosition` para o próximo frame.
- O resultado é guardado em `CarManager.currentSortedCarsList` e o índice reverso em `CarManager.sortedCarList_carIndexToSortedIndex[carIndex]`.
- A ordem é **decrescente** por `splinePosition` (o carro mais à frente primeiro).

### 2.4 Anchor points sem alocação

`CarOperations.getSideAnchorPoints(pos, fwd, left, up, half, outTable)` (`CarOperations.lua`):
- Pool: `CarOperations._reusableSideAnchorTable` + **8 scratch vec3** (`_reusableVec3_center`, `...frontLeft`, `...centerLeft`, `...rearLeft`, `...frontRight`, `...centerRight`, `...rearRight`, `...right`).
- `outTable` default é o pool; `table_clear(outTable)` no início; retorna a tabela com `frontLeft/centerLeft/rearLeft/frontRight/centerRight/rearRight/center/forwardDirection/leftDirection/rightDirection/upDirection`.
- **Nunca aloque** `vec3()` dentro do hot path. `VecPool.getTempVec3` retorna **um singleton compartilhado** — não guarde referência entre chamadas.
- Cuidado: `checkIfCarIsBlockedByAnotherCarAndSaveSideBlockRays` salva as direções/ray data em `CarManager.cars_sideBlockRaysData[carIndex]`, que é limpo a cada `CarStateMachine.updateCar` (`CarStateMachine/CarStateMachine.lua`).

### 2.5 Yellow zones com bucket O(1)

`RaceTrackManager.isSplinePositionInYellowZone(splinePos)` (`RaceTrackManager.lua`):
- `bucket = yellowFlagsZones_bucket[floor(splinePos / 0.05)]` (`YELLOW_ZONE_BUCKET_SIZE = 0.05`, `YELLOW_ZONE_BUCKET_COUNT = ceil(1/0.05)`).
- Cada bucket guarda a lista de índices de zonas ativas que cobrem aquele trecho.
- **Wrap cíclico**: uma zona pode cruzar 0.0/1.0; `forEachYellowZoneBucketIndex` popula **dois ranges** de buckets nesse caso. Mantenha essa simetria em `addYellowFlagZoneToBuckets`/`removeYellowFlagZoneFromBuckets`.
- `getYellowZoneBucketIndex` faz clamp de índices fora de `[0, COUNT-1]`.

### 2.6 Iteração de carros

- `ac.iterateCars()` é **caro** → chame **uma vez por frame** no `MANIFEST__UPDATE` e itere o resultado.
- `ac.getCar(index)` é usado pontualmente; não itere a frota com ele dentro de loops por carro.

### 2.7 Amostragem de velocidade

`CarManager.saveCarSpeed(car)` (`CarManager.lua`) mantém um buffer circular de `CAR_SPEEDS_BUFFER_SIZE`:
- `cars_speedBuffer`, `cars_speedBufferIndex`, `cars_speedBufferTotal`, `cars_speedSampleCount`, `cars_averageSpeedKmh`.
- Ignora carros parados (`speedKmh < 1`); a média é `total / sampleCount`.

### 2.8 Resumo dos pontos quentes

| Ponto | Arquivo | Regra |
| --- | --- | --- |
| `_currentFrameId += 1` | `SimOpenTrackDay.lua` | 1x/frame, invalida cache |
| `table.clear(carList)` | `SimOpenTrackDay.lua` | Nunca `{}` por frame |
| `ac.iterateCars()` | `SimOpenTrackDay.lua` | 1x/frame |
| `sortCarListByTrackPosition` | `CarManager.lua` | Preserve incremental + fallback 50% |
| `getActualTrackLateralOffset` | `CarManager.lua` | Cache hit evita `worldCoordinateToTrack` |
| `getSideAnchorPoints` | `CarOperations.lua` | Pool + scratch, zero alocação |
| `isSplinePositionInYellowZone` | `RaceTrackManager.lua` | Bucket O(1); wrap correto |
| `VecPool.getTempVec3` | `VecPool.lua` | Singleton — só uso temporário |

---

## 3. Acoplamento (quem chama quem)

### 3.1 Cadeia principal (setas)

```
 manifest.ini UPDATE
        │
        ▼
 script.MANIFEST__UPDATE
        │
        ├─→ GameTimeManager.update ──► (tempo p/ HumanErrorManager)
        ├─→ SessionDetails.update
        ├─→ CameraManager.getFocusedCarIndex ──► RaceTrackManager.isSplinePositionInYellowZone ──► RaceFlagManager.set/removeRaceFlag
        │
        ├─→ CarManager.ensureDefaults ──► (CarStateMachine.initializeCarInStateMachine, AccidentManager.setCarNavigatingAroundAccident, CarOperations.*)
        ├─→ CarManager.saveCarSpeed
        ├─→ CarManager.sortCarListByTrackPosition
        ├─→ OnCarEventManager.processQueuedEvents ──► OnCarEventExecutions[Collision|Jumped]
        ├─→ CarStateMachine.handleQueuedAccidents
        ├─→ HumanErrorManager.update ──► physics.setAIBrakeMistake / setAITractionMistake
        │
        └─(por carro)─→ CarStateMachine.updateCar
                            └─→ CarStateMachine.states_{entry,transition,update,exit}Functions[state]
                                    └─→ CarOperations.driveSafelyToSide / overtakeSafelyToSide / yieldSafelyToSide
                                            └─→ physics.setAISplineOffset / setAITopSpeed / setAIThrottleLimit /
                                                setAICaution / setAIAggression / setExtraAIGrip / raycasts
                                    └─→ CarManager.getActualTrackLateralOffset
                                    └─→ CarManager.isCarOffTrack / getClosingSpeed
                                    └─→ AccidentManager.*
                                    └─→ RaceTrackManager.getYieldingSide/getOvertakingSide
```

### 3.2 Quem importa / é importado por

| Módulo | Importa de | É importado por |
| --- | --- | --- |
| `SimOpenTrackDay.lua` | quase todos (raiz) | — (entry point) |
| `CarManager` | `StorageManager`, `RaceTrackManager`, `CarStateMachine`, `AccidentManager`, `CarOperations`, `Strings`, `VecPool` | entry point, `CarOperations`, `CarStateMachine`, states, UI |
| `CarOperations` | `CarManager`, `RaceTrackManager`, `StorageManager`, `VecPool`, `MathHelpers` | states, `CarStateMachine`, entry point, `AccidentManager` |
| `CarStateMachine` | `StorageManager`, `Strings*`, `CarManager`, `CarOperations`, `RaceTrackManager`, `AccidentManager`, `QueueManager` | entry point, states, `CarManager` |
| `States/*` | `CarStateMachine`, `CarManager`, `CarOperations`, `RaceTrackManager`, `StorageManager`, `Strings*` | entry point (require, registram as funções) |
| `StorageManager` | `ac`, `Constants` | quase todos (capturado no load) |
| `SettingsWindow` | `StorageManager`, `UIOperations`, `RaceTrackManager`, `Logger` | entry point (`MANIFEST__FUNCTION_SETTINGS`) |
| `UIManager` | `CarManager`, `CarStateMachine`, `StorageManager`, `RaceTrackManager`, `Strings`, widgets | entry point |
| `RaceTrackManager` | `ac`, `CompletableIndexCollectionManager`, `Logger` | `CarManager`, `CarOperations`, `CarStateMachine`, UI, `AccidentManager` |
| `BehaviorPolish` | **nada** (puro) | (consumido via storage/estados, quando ativado) |
| `HumanErrorManager` | `physics`, `GameTimeManager` (via arg) | entry point (`MANIFEST__UPDATE`) |
| `RaceFlagManager` | `physics.overrideRacingFlag` | entry point |
| `AccidentManager` | `CarManager`(via API), `RaceTrackManager`, `QueueManager` | entry point, `CarStateMachine`, states |
| `OnCarEventManager` | `QueueManager` | entry point |
| `Pathfinding` | `CarManager`, `VecPool`, `MathHelpers`, `Render` | entry point (require; gated) |
| `FrenetAvoid`/`CollisionAvoidanceManager`/`CarSpeedLimiter`/`CustomAIFloodManager`/`Profiler` | vários | ninguém (require comentado) |

> Há dependências **circulares em runtime** (`CarManager ↔ CarStateMachine ↔ CarOperations`).
> Elas só funcionam porque os módulos são **globais** e as funções são chamadas em runtime, não no load.
> Evite adicionar chamadas de módulo no **load time** dentro de um ciclo.

---

## 4. Convenções de DoD (Data-Oriented Design)

**Regra de ouro:** estado de carro é `CarManager.cars_*[carIndex]` — tabelas paralelas, **1 entrada por índice**.
**Não** criar tabela/objeto por instância de carro, nem `table` aninhada por carro fora dos casos já existentes.

### 4.1 Inicialização

- `CarManager.ensureDefaults(carIndex)` → se não `cars_initialized[carIndex]`, chama `setInitializedDefaults(carIndex)`.
- `setInitializedDefaults` faz reset completo (offsets, FSM, limites de IA, colisões) e é chamada também no `onCarJumped`.
- Lazy init: **declare a tabela no momento do uso** quando ela não estiver em `setInitializedDefaults` — não presuma que toda `cars_*` existe para todo índice.

### 4.2 Exemplos canônicos

| Tabela | Arquivo | Função |
| --- | --- | --- |
| `cars_lateralOffsetCacheByCar` | `CarManager.lua` | cache do offset lateral real por frame |
| `cars_previousSplinePosition` | `CarManager.lua` | detecção de mudança p/ sort incremental |
| `cars_speedBuffer` / `cars_speedSampleCount` | `CarManager.lua` | buffer circular de velocidades |
| `cars_defenseRemainingTime_s` | `CarManager` / `CarState_DefendingPosition` | tempo restante defendendo posição |
| `cars_currentReusableList` | `CarManager.lua` | lista reusada a cada frame |
| `cars_state` (local) | `CarStateMachine/CarStateMachine.lua` | estado atual da FSM por carro |
| `cars_sideBlockRaysData` | `CarManager` | dados dos raycasts laterais, limpos por frame |
| `sortedCarList_carIndexToSortedIndex` | `CarManager.lua` | índice reverso carIndex → posição no sort |
| `HumanErrorManager.lastEventTimeByCar` / `errorCountByCar` | `HumanErrorManager.lua` | cooldown/contagem por carro |

### 4.3 Cuidados

- Não guarde referências a tabelas/produtos **reusados** (pool) entre frames.
- Ao iterar carros, use `car.index` como chave DoD; índices de carro podem ser **reciclados** pelo AI Flood (por isso `onCarJumped` reseta).
- Prefira tabelas de números indexadas por inteiro; evite chaves string em hot path.

---

## 5. Storage (DoD de opções)

Pipeline em `StorageManager.lua`:

1. **Enum** — IDs inteiros por categoria, notação `StorageManager.Options_X`:
   ```lua
   StorageManager.Options_Behavior = { entryBlendTime = 1, exitBlendTime = 2, ..., ErrorCooldown_s = 16 }
   ```
2. **Collection** — `optionsCollection_X_beforeDoD` (lista ordenada, com metadados):
   ```lua
   local optionsCollection_Behavior_beforeDoD = {
     { name = StorageManager.Options_Behavior.entryBlendTime, default = 1.5, min = 0, max = 5 },
     { name = StorageManager.Options_Behavior.mode, default = StorageManager.BehaviorMode.HybridAdaptive, min = nil, max = nil },
     ...
   }
   ```
3. **Tabelas DoD** — `fillInDoDTables(collection, default, min, max)` preenche:
   `StorageManager.options_X_default`, `..._min`, `..._max` (indexados pelo **ID do enum**).
   A collection é zerada depois: `optionsCollection_X_beforeDoD = nil -- free memory`.
4. **`storageTable_X`** — tabela camelCase com os defaults aplicados, ex. `storageTable_Behavior` e `storageTable` (main).
5. **Storage real** — `ac.storage(storageTable, key)`:
   ```lua
   local fullTrackID = ac.getTrackFullID("_")
   local perTrackPerModeStorageKey = getStorageKeyForTrackAndMode(nil, fullTrackID, raceSessionType)
   local storage_PerTrackPerMode = ac.storage(storageTable, perTrackPerModeStorageKey)
   local storage_Behavior = ac.storage(storageTable_Behavior, getStorageKeyForTrackAndMode("behavior", fullTrackID, raceSessionType))
   ```
   Chave = `"<storageID>_<trackID>_<sessionType>"`.
6. **Getter** — `StorageManager.getStorage_X() → storage_X`.

**Storages existentes:** `getStorage` (main), `_Global`, `_Debugging`, `_Yielding`, `_Overtaking`, `_AICarValues`, `_PathFinding`, `_Behavior`.

### 5.1 Caveat: chaves dinâmicas

Chaves que **não** estão declaradas no `storageTable` mas são gravadas em runtime:
- `storage_Behavior.profile` (`SettingsWindow.lua`)
- `storage_Debugging.showBehaviorAdvanced` (`SettingsWindow.lua`)

Isso **funciona** porque `ac.storage` aceita chaves arbitrárias, mas:
- **Persistem**, porém **sem validação de tipo/min/max** (não passam por `fillInDoDTables`).
- Não são expostas por getter dedicado nem documentadas por tipo.
- Para opções **reais** de usuário, prefira o pipeline completo (enum → collection → table).

### 5.2 Perfis de comportamento

`StorageManager.BehaviorProfiles`: `Casual`, `Realistic`, `Competitive` → `applyBehaviorProfile(profileIndex)` copia os campos para `storage_Behavior`. É chamado pela UI, **não automaticamente**.

---

## 6. Bitwise (LEMBRETE CRÍTICO)

- **LuaJIT 2.1 não tem os operadores `&`, `|`, `~`, `<<`, `>>`** — esses são **Lua 5.3**.
- Use a biblioteca `bit.*`:
  ```lua
  bit.band(a, b)     -- AND
  bit.bor(a, b)      -- OR
  bit.bnot(a)        -- NOT
  bit.bxor(a, b)     -- XOR
  bit.lshift / bit.rshift
  ```
- `Enum.lua` foi consertado para `bit.*` (`hasFlag`, `add`, `remove`). Os estados da FSM são **bit flags** (`DRIVING_NORMALLY = 1`, `EASING_IN_YIELD = 4`, ... `DEFENDING_POSITION = 65536`).
- **Não introduza** `&`, `|`, `~` em lugar nenhum do código Lua — o app quebra no parser do LuaJIT.

---

## 7. Pontos onde um dev pode tropeçar

1. **Lazy init de `cars_*`.** Declare a tabela no momento do uso (ou adicione-a em `setInitializedDefaults`). Não assuma que toda tabela existe para todo `carIndex`.
2. **`bit.*` em vez de `&`/`|`/`~`** (§6). Sempre.
3. **Tabelas reusáveis.** Use os pools (`cars_currentReusableList`, `_reusableSideAnchorTable`, `VecPool`) em vez de criar `{}`/`vec3()` em hot path. Atenção ao singleton do `VecPool`.
4. **`physics.setAITopSpeed` não tem `physics.removeAITopSpeed`.** Use `CarOperations.removeAITopSpeed(carIndex)` (`CarOperations.lua`), que faz o equivalente via `math.huge`.
5. **`physics.setAINoInput(carIndex, true)`** para "parked" de fato (o carro fica sem input). Usado em `CarState_AfterCustomAIFloodTeleport.lua`.
6. **`ac.iterateCars()` é caro** — chame **uma vez por frame** e itere o resultado (§2.6).
7. **`physics.setAITopSpeed`/`setAIThrottleLimit` não pegam em AI Flood do AC** — motivo histórico do `CarSpeedLimiter`. Não conte com eles para segurar velocidade de forma confiável; o `applyAntiDragRaceLimit` é idempotente e trata o caso do yield.
8. **`cars_sideBlockRaysData` é limpo a cada `updateCar`.** Se você popular essa tabela fora do ciclo do carro, o dado some no próximo frame.
9. **`ac.worldCoordinateToTrack` é caro** — passe só em cache miss (`getActualTrackLateralOffset`).
10. **Estados da FSM usam bit flags**, mas o `carIndex`-to-state é armazenado como valor em `cars_state`; transições passam por `queueStateTransition` e só aplicam no início do próximo `updateCar`.
11. **`CAR_SPEEDS_BUFFER_SIZE`** — o buffer de velocidade é circular; nunca acesse `cars_speedBuffer[carIndex]` diretamente sem tratar índice/`nil` (carros recém-teleportados têm buffer zerado).
12. **`RaceTrackManager` é capturado em load time** por `CarManager`/states; `getTrackFullID`/session são fixos no carregamento.

---

## 8. Caveats de API CSP ausentes ou instáveis

| API | Status | Observação |
| --- | --- | --- |
| `physics.setAICaution` | experimental/documentado | valida; máximo prático 16 (`MAX_AI_CAUTION_VALUE` em `StorageManager.lua`) |
| `physics.setAITopSpeed` / `setAIThrottleLimit` | **não funcionam em AI Flood do AC** | motivo do `CarSpeedLimiter.lua` (desligado) e do anti-drag-race |
| `physics.setAIBrakeMistake` / `setAITractionMistake` | verificadas pelo entry point | usadas por `HumanErrorManager`; não se declara uma versão mínima de CSP neste documento |
| `physics.setAILapsToComplete` | disponível no SDK distribuído | não registrada nem usada pelo app atual |
| `physics.Collider.TrackWalls()` / `TrackGround()` | **preview649** | API de colliders; não usada diretamente hoje |
| `physics.preventAIFromRetiring` | **chamar recorrentemente** | por frame, enquanto durar a condição (`CarOperations.preventAIFromRetiring`) |
| `physics.overrideRacingFlag` | estável | base do `RaceFlagManager` |
| `ac.storage` | estável | aceita chaves arbitrárias (ver §5.1) |

As APIs CSP usadas e registradas pelo app passam por `CSPCompatibilityManager.addFunction(...)` e são verificadas por `CSPCompatibilityManager.checkForMissingElements(...)`. O SDK também contém APIs não usadas pelo app — por exemplo `physics.setAILapsToComplete` — que não são registradas. Ao adicionar uma API nova ao app, **registre-a no entry point** para receber o diagnóstico de ausência.

---

## 9. Mapa rápido de arquivos (índice)

```
SimOpenTrackDay.lua   entry point / MANIFEST__UPDATE
├─ CarManager.lua                   DoD por carIndex; sort; cache lateral
├─ CarOperations.lua                wrappers physics + yield/overtake; anchors; raycasts
├─ CarStateMachine/
│  ├─ CarStateMachine.lua           FSM central (`updateCar`)
│  ├─ CarState_TEMPLATE.lua         contrato de novo estado
│  └─ States/*.lua                  estados (ver docs/STATE_MACHINE.md)
├─ StorageManager.lua               enum→collection→DoD→storage→getters
├─ SettingsWindow.lua               UI settings (`draw`)
├─ UIManager.lua                    car list / overhead / offsets preview
├─ RaceTrackManager.lua             track meta + lados + yellow-zone buckets
├─ BehaviorPolish.lua               funções puras (lerp / hesitação / look-ahead)
├─ HumanErrorManager.lua            brake/traction mistakes com cooldown
├─ RaceFlagManager.lua              caution flag
├─ AccidentManager.lua              acidentes + yellow zones
├─ OnCarEventManager.lua            fila Collision/Jumped
├─ GameTimeManager.lua              tempo de jogo (cooldowns)
├─ SessionDetails.lua               tempo desde início da sessão
├─ (desligado) Pathfinding / FrenetAvoid / CollisionAvoidanceManager /
│              CarSpeedLimiter / CustomAIFloodManager / Profiler
├─ Strings/  DataStructures/  VecPool / MathHelpers / ColorManager / Logger / Enum
├─ lib/ac_apps/                     SDK do CSP (vendor)
├─ lib/AssettoCorsaCSPLuaCompatibilityManager/ submodule de compatibilidade
└─ lib/uilib/                       biblioteca própria
```

Documentos relacionados: `docs/AGENT.md` (onboarding), `docs/STATE_MACHINE.md` (FSM), `docs/TESTING.md` (validação), `README.md` (produto).
