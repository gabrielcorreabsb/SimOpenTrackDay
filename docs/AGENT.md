# AGENT.md — Guia de Entrada

> Ponto de entrada para **AI agents** e **desenvolvedores humanos** que chegam no projeto pela primeira vez.
> Leia isto antes de abrir qualquer arquivo. Depois siga para a documentação detalhada (seção 8).

---

## 1. O que é este projeto

**SimOpenTrackDay** é um fork em desenvolvimento de **Assetto Corsa Realistic Trackday**, um app em **Lua** para o **Assetto Corsa**, carregado via **Custom Shaders Patch (CSP)**. O projeto upstream é de Andreas Grech; consulte o README e a licença MIT para atribuição.

Ele altera o comportamento dos carros controlados pela **IA** para que ajam como humanos num *track day* em vez de bots que seguem a *racing line* com "antolhos". Comportamentos principais:

- **Ceder passagem (yield)**: um carro mais lento sai da racing line para um lado fixo (esquerda ou direita, conforme a regra) e deixa o carro mais rápido passar.
- **Ultrapassar (overtake)**: o carro mais rápido passa pelo lado oposto ao de yield.
- **Retornar à racing line**: após a manobra, o carro volta suavemente para a racing line quando for seguro.
- **Erros humanos**: acidentes/lockups/traction mistakes são aceitos e telegrafados (não é determinístico).

A inspiração é a experiência real das **Touristenfahrten da Nordschleife**, onde por regulamento só se ultrapassa pela esquerda e carros que cedem o fazem pela direita.

---

## 2. Stack técnica

| Item | Valor |
| --- | --- |
| **Engine** | **LuaJIT 2.1** (compatível com **Lua 5.1**) — a mesma engine que o CSP usa internamente |
| **CSP alvo** | **0.3.0+** |
| **Manifest** | `manifest.ini` com `[CORE] LAZY = NONE` |
| **Callbacks** | `MANIFEST__UPDATE`, `MANIFEST__FUNCTION_MAIN`, `MANIFEST__FUNCTION_SETTINGS`, `MANIFEST__FUNCTION_ICON`, `MANIFEST__TRANSPARENT` |
| **SDK/submodules** | `lib/ac_apps/` (SDK do CSP) e `lib/AssettoCorsaCSPLuaCompatibilityManager/` (submodule de compatibilidade) — não editar como código do app; atualizar o submodule deliberadamente |
| **Biblioteca própria** | `lib/uilib/` — código do projeto; não confundir com o SDK vendor ou o submodule de compatibilidade |

As funções de CSP `physics.setAIBrakeMistake` e `physics.setAITractionMistake` são registradas via `CSPCompatibilityManager.addFunction(...)` no topo do entry point. `physics.setAILapsToComplete` existe no SDK distribuído, mas não é registrada nem usada pelo app atual.

> **Importante**: o payload no repositório está na raiz. Instalado, o entry point fica em `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua`. Não mova os módulos para uma nova hierarquia dentro do repositório.

---

## 3. Layout de pastas (alto nível)

```
SimOpenTrackDay/ (payload na raiz do repositório)
├─ SimOpenTrackDay.lua                 # ENTRY POINT (callbacks do manifest)
├─ CarManager.lua                      # estado dos carros (DoD) + helpers de posição
├─ CarOperations.lua                   # operações de yield/overtake entre carros
├─ StorageManager.lua                  # settings + storage per-track-per-mode
├─ SettingsWindow.lua                  # UI de settings (ImGui)
├─ UIManager.lua / UIOperations.lua    # HUD e overlays
├─ HumanErrorManager.lua               # lockups / traction mistakes
├─ AccidentManager.lua                 # detecção e navegação de acidentes
├─ CollisionAvoidanceManager.lua       # evitar colisões
├─ RaceTrackManager.lua                # spline, racing line, offsets
├─ BehaviorPolish.lua                  # helpers puros de comportamento
├─ Enum.lua / Constants.lua            # enums e constantes globais
├─ Logger.lua / Profiler.lua           # logging e profiling
│
├─ CarStateMachine/
│  ├─ CarStateMachine.lua              # FSM central: entry/update/transition/exit
│  ├─ CarState_TEMPLATE.lua            # template para novos estados
│  └─ States/
│     ├─ CarState_DrivingNormally.lua
│     ├─ CarState_EasingInYield.lua
│     ├─ CarState_StayingOnYieldingLane.lua
│     ├─ CarState_EasingOutYield.lua
│     ├─ CarState_EasingInOvertake.lua
│     ├─ CarState_StayingOnOvertakingLane.lua
│     ├─ CarState_EasingOutOvertake.lua
│     ├─ CarState_DefendingPosition.lua
│     ├─ CarState_NavigatingAroundAccident.lua
│     ├─ CarState_DrivingInYellowFlagZone.lua
│     ├─ CarState_CollidedWithTrack.lua
│     ├─ CarState_CollidedWithCar.lua
│     ├─ CarState_AnotherCarCollidedIntoMe.lua
│     └─ CarState_AfterCustomAIFloodTeleport.lua
│
├─ Strings/                            # textos de debug (reason/exit reason)
│  ├─ Strings.lua
│  ├─ Strings_StateExitReason.lua
│  ├─ Strings_ReasonWhyCantYield.lua
│  └─ Strings_ReasonWhyCantOvertake.lua
│
├─ DataStructures/                     # estruturas reutilizáveis
│  ├─ QueueManager.lua
│  ├─ StackManager.lua
│  ├─ DequeManager.lua
│  └─ CompletableIndexCollectionManager.lua
│
├─ lib/ac_apps/                        # SDK CSP (vendor)
├─ lib/AssettoCorsaCSPLuaCompatibilityManager/ # submodule de compatibilidade
├─ lib/uilib/                          # biblioteca própria do projeto
│
└─ docs/                               # esta documentação
```

Os demais `*.lua` no root (ex.: `CameraManager`, `GameTimeManager`, `SessionDetails`, `VecPool`, `Pathfinding`, `FrenetAvoid`, etc.) são módulos principais carregados pelo entry point.

---

## 4. Entry points por intenção

Use a tabela abaixo conforme o que você quer fazer:

| Quero... | Vá para |
| --- | --- |
| **Entender o fluxo principal** | `SimOpenTrackDay.lua` → `script.MANIFEST__UPDATE` |
| **Entender a decisão de um carro individual** | `CarManager.lua` → `getActualTrackLateralOffset` + estados em `CarStateMachine/States/` |
| **Mudar UI de tela principal** | `SimOpenTrackDay.lua` → `MANIFEST__FUNCTION_MAIN` |
| **Mudar tela de settings** | `SettingsWindow.lua` → `MANIFEST__FUNCTION_SETTINGS` |
| **Mexer em settings/persistência** | `StorageManager.lua` (ver seção 5) |
| **Adicionar uma feature** | Seção 6 |

**Fluxo resumido do `MANIFEST__UPDATE`**: atualiza estado global (tempo de sessão, pista, flags) → reconstrói a lista ordenada de carros → roda a FSM de cada carro → aplica operações (yield/overtake) → atualiza UI/HUD.

### Estados da FSM (referência rápida)

Cada estado é um **bit flag** em `CarStateMachine.CarStateType`. O estado de um carro é testado/somado com `bit.band`/`bit.bor`.

| Estado | Bit | Papel |
| --- | --- | --- |
| `DRIVING_NORMALLY` | 1 | Segue a racing line, comportamento padrão |
| `EASING_IN_YIELD` | 4 | Transição suave para a faixa de yield |
| `STAYING_ON_YIELDING_LANE` | 8 | Mantém-se fora da racing line cedendo passagem |
| `EASING_OUT_YIELD` | 32 | Retorna à racing line após o yield |
| `DEFENDING_POSITION` | 65536 | Segura a racing line sob pressão antes de ceder |
| `EASING_IN_OVERTAKE` | 1024 | Transição para a faixa de ultrapassagem |
| `STAYING_ON_OVERTAKING_LANE` | 2048 | Mantém-se na faixa de ultrapassagem |
| `EASING_OUT_OVERTAKE` | 4096 | Retorna à racing line após ultrapassar |
| `NAVIGATING_AROUND_ACCIDENT` | 8192 | Desvia de acidente na pista |
| `DRIVING_IN_YELLOW_FLAG_ZONE` | 16384 | Comportamento sob bandeira amarela |
| `COLLIDED_WITH_TRACK` | 128 | Recuperação após sair da pista |
| `COLLIDED_WITH_CAR` | 256 | Recuperação após colisão com outro carro |
| `ANOTHER_CAR_COLLIDED_INTO_ME` | 512 | Reação a ser atingido |
| `WAITING_AFTER_ACCIDENT` | 64 | Espera após acidente |
| `AFTER_CUSTOMAIFLOOD_TELEPORT` | 32768 | Reintegração após teleporte do CustomAIFlood |

> O template `CarState_TEMPLATE.lua` mostra o contrato de cada estado: `states_entryFunctions`, `states_updateFunctions`, `states_transitionFunctions`, `states_exitFunctions`, todos com a assinatura `(carIndex, dt, sortedCarsList, sortedCarsListIndex, storage)`.

---

## 5. Convenções do código

### Naming
- `snake_case` para funções e variáveis locais.
- `CamelCase` + nome do módulo para **tabelas principais** e **enums** (`CarManager`, `StorageManager.BehaviorProfiles`, `StorageManager.Options_Behavior`, `CarStateMachine.CarStateType`).

### Bindings locais no topo de cada arquivo
Cada arquivo cria `local` no topo para as APIs que usa:

```lua
local ac_getCar            = ac.getCar
local physics_setAITopSpeed = physics.setAITopSpeed
local CarManager_getActualTrackLateralOffset = CarManager.getActualTrackLateralOffset
```

**Use esses locals** dentro das funções; **nunca chame `ac.getCar(...)` diretamente**. Isso melhora performance (evita lookup de tabela em hot path) e mantém um ponto único de acoplamento.

### Bitwise
Use a biblioteca **`bit.*` do LuaJIT**: `bit.band`, `bit.bor`, `bit.bnot`, `bit.bxor`, `bit.lshift`, `bit.rshift`.

> **NÃO use `&`, `|`, `~`, `<<`, `>>`** — são operadores de **Lua 5.3** e **não existem no LuaJIT 2.1**. Você quebrará o app.

Os estados da FSM são **bit flags** (`DRIVING_NORMALLY = 1`, `EASING_IN_YIELD = 4`, `STAYING_ON_YIELDING_LANE = 8`, `EASING_OUT_YIELD = 32`, ...), então máscaras com `bit.band`/`bit.bor` são o padrão para testar/transicionar estados.

### Estado de carro (Data-Oriented Design)
O estado **não** fica em instâncias de carro. Ele vive em tabelas DoD indexadas por índice de carro:
- `CarManager.cars_*Index` (índices)
- `CarManager.cars_*` (dados)

Sempre acesse via essas tabelas e mantenha os índices consistentes.

### Storage per-track-per-mode
Settings são salvos **por pista e por modo** de jogo (Practice, Qualify, Race, Hotlap, TimeAttack, Drift, Drag). Não crie storage ad-hoc: use `StorageManager.getStorage*()`:

```lua
StorageManager.getStorage()
StorageManager.getStorage_Global()
StorageManager.getStorage_Debugging()
StorageManager.getStorage_Yielding()
StorageManager.getStorage_Overtaking()
StorageManager.getStorage_AICarValues()
StorageManager.getStorage_PathFinding()
StorageManager.getStorage_Behavior()
```

### Erros são aceitos
`HumanErrorManager` pode disparar `physics.setAIBrakeMistake` / `physics.setAITractionMistake` intencionalmente. Comportamento "perfeito demais" é **errado** para os objetivos do app — tudo deve ser telegrafado para o jogador.

---

## 6. Como adicionar uma nova feature (workflow típico)

1. **Decidir modo e perfil**
    Se a feature afeta o comportamento da IA, crie/estenda uma entrada em `StorageManager.BehaviorProfiles`.

2. **Nova option**
   - Adicione um ID no enum correspondente (ex.: `StorageManager.Options_Behavior`).
   - Adicione a entrada na collection `*_beforeDoD` (ex.: `optionsCollection_Behavior_beforeDoD`).
   - Adicione o campo na `storageTable_*` (ex.: `storageTable_Behavior`).
   - Os defaults/min/max fluem por `fillInDoDTables(collection, default, min, max)`.

3. **Slider no UI**
    Para opções de behavior, edite `SettingsWindow.lua` na seção de Behavior. Categorias novas ganham uma seção análoga.

4. **Lógica de IA**
   - **Novo estado?** Estenda a FSM em `CarStateMachine.lua` (adicione o bit flag em `CarStateType` e os arrays `states_*Functions`) e crie `CarState_<Name>.lua` em `States/`, usando `CarState_TEMPLATE.lua`.
   - **Só lógica?** Estenda o manager relevante (`CarOperations`, `CollisionAvoidanceManager`, etc.).

5. **Wiring**
    Chame a partir do `MANIFEST__UPDATE` no entry point se for per-frame. Se for evento, use os handlers de `ac.onCarJumped` / `ac.onCarCollision` (registrados no entry point).

6. **Validar**
    Rode o checker de sintaxe (seção 7); a contagem é determinada dinamicamente pelos arquivos encontrados.

---

## 7. Comandos úteis

### Validar sintaxe Lua
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
```
O checker usa `luajit` no `PATH` por padrão; opcionalmente passe `-LuaJitPath <caminho>` e `-Root <raiz-do-projeto>`. A saída informa a contagem real encontrada. Ele exclui `lib/ac_apps/` e `lib/AssettoCorsaCSPLuaCompatibilityManager/`; não exclui `lib/uilib/`.

### Localizar uma função
```powershell
Select-String -Path '*.lua' -Pattern 'getActualTrackLateralOffset'
```

### Listar todos os pontos onde uma função é chamada
```powershell
Select-String -Path '*.lua' -Pattern 'setAITopSpeed' | Select-Object -ExpandProperty FileName
```

### Listar todos os arquivos `.lua` (excluindo vendor)
```powershell
Get-ChildItem -Recurse -Filter *.lua | Where-Object { $_.FullName -notmatch '\\lib\\(ac_apps|AssettoCorsaCSPLuaCompatibilityManager)\\' }
```

---

## 8. Links para a documentação detalhada

| Documento | Conteúdo |
| --- | --- |
| `docs/ARCHITECTURE.md` | Mapa completo do código, acoplamentos entre módulos, hot paths |
| `docs/TESTING.md` | Como validar antes de pilotar |
| `docs/UI_REDESIGN_DISCOVERY.md` | Inventário e status da revisão de UI |
| `CONTRIBUTING.md` | Fluxo de contribuição |
| `README.md` (raiz) | Descrição do produto, changelog e vídeos |

---

## 9. Avisos importantes

- ⛔ **NÃO use `&`, `|`, `~`** como operadores. São **Lua 5.3 only**. Use `bit.band` / `bit.bor` / `bit.bnot`.
- ⛔ **Não edite `lib/ac_apps/` como código do projeto** (SDK vendor); atualizações no submodule de compatibilidade devem ser deliberadas. `lib/uilib/` é biblioteca própria, não vendor.
- ⛔ **NÃO modifique `manifest.ini`** para testar localmente. O CSP carrega o app como `apps/lua/<pasta>/manifest.ini`.
- ⚠️ **NÃO aloque tabelas em hot paths.** Use as tabelas reutilizáveis (ex.: `cars_currentReusableList`, `_reusableSideAnchorTable`) e pools como `VecPool`.
- ⚠️ **CSP 0.3.0+ é pré-requisito.** `physics.setAIBrakeMistake` e `physics.setAITractionMistake` passam por `CSPCompatibilityManager.addFunction`.
- ⚠️ **Respeite o DoD.** Estado de carro em tabelas indexadas, não em instâncias.
- ⚠️ **Não reinvente a roda.** Antes de criar lógica nova, verifique se já existe tabela de classes/storage/enum para estender.
- ⚠️ **Erros intencionais existem.** Não "conserte" o `HumanErrorManager` achando que é bug.

---

## 10. Checklist de onboarding (primeiros 15 minutos)

1. Leia este arquivo inteiro.
2. Abra `SimOpenTrackDay.lua` e localize `MANIFEST__UPDATE`.
3. Leia `CarStateMachine.lua` e identifique os bit flags em `CarStateType`.
4. Abra `CarState_DrivingNormally.lua` como exemplo de estado real.
5. Leia `StorageManager.lua` nas seções de enum/collection/storage Table e `getStorage*()`.
6. Rode o checker de sintaxe (seção 7); confirme a contagem dinâmica e que não há falhas.
7. Só então comece a alterar código.
