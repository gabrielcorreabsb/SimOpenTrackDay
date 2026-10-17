# Guia de Testes — SimOpenTrackDay

Este documento descreve como validar o código-fonte do projeto em desenvolvimento **SimOpenTrackDay** antes e depois de uma instalação manual no Assetto Corsa (AC). Cobre pré-requisitos, sintaxe Lua, mocks headless e cenários in-game. A documentação e os checks de fonte não determinam o estado dos arquivos atualmente instalados; runtime CSP e validação visual in-game continuam pendentes. Isso não representa build publicado ou release.

> **Regra de ouro:** mantenha uma cópia de backup da instalação antiga e da configuração do usuário. Não apague a instalação existente nem limpe configurações para testar esta versão em desenvolvimento; prefira uma instalação paralela.

---

## 1. Pré-requisitos de ambiente

### 1.1 LuaJIT 2.1 (instalar uma vez)

LuaJIT é a engine que o CSP/AC usa internamente. É necessária para rodar o
script `check_lua_syntax.ps1` (validação de sintaxe dos arquivos `.lua`).

Instalação via winget:

```powershell
winget install --id=DEVCOM.LuaJIT -e --accept-package-agreements --accept-source-agreements
```

- Versão esperada: `LuaJIT 2.1.19907` ou superior.

Para conferir a versão instalada:

```powershell
luajit -v
```

### 1.2 Script de validação de sintaxe

O checker mantido no repositório é `tools/check_lua_syntax.ps1`. Ele percorre os arquivos `.lua`, compila cada um com LuaJIT e informa falhas de sintaxe. A contagem é dinâmica: depende dos arquivos encontrados, não de um total fixo. O checker exclui `lib/ac_apps/` e `lib/AssettoCorsaCSPLuaCompatibilityManager/`, além de `*.bak`; não exclui `lib/uilib/`.

---

## 2. Antes de cada commit / push

### 2.1 Validar sintaxe (contagem dinâmica)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
```

O script localiza `luajit` no `PATH` por padrão. Os parâmetros opcionais `-LuaJitPath <path-to-luajit.exe>` e `-Root <project-root>` permitem indicar outros caminhos. A saída final indica a quantidade verificada e o processo falha se houver arquivo inválido.

Se houver falha, leia o bloco `FAIL` apontado (arquivo + linha) e
conserte antes de seguir.

### 2.2 Grep de regressões óbvias (opcional, mas recomendado)

Estas checagens pegam erros que passam pela validação de sintaxe (a sintaxe
está OK, mas a API usada é errada).

```powershell
# Deve dar 0 matches: a lista de carros deve vir do CarManager
findstr /N /C:"local carList = {}" *.lua

# Em Enum.lua, deve dar 0 matches com "&": use bit.band
findstr /N /C:"& " Enum.lua

# Deve dar 0 matches: physics.removeAITopSpeed não existe
findstr /N /C:"physics.removeAITopSpeed" *.lua
```

Notas:

- `local carList = {}` → o correto é usar
  `CarManager.cars_currentReusableList`.
- `& ` (bitwise nativo) → o correto é `bit.band` (LuaJIT 2.1 sem o operador
  nativo de 5.3).
- `physics.removeAITopSpeed` → não existe; use
  `CarOperations.removeAITopSpeed`.

### 2.3 Mock smoke test da UI (evidência limitada)

Execute o smoke test headless de contratos com:

```powershell
luajit tools/test_ui_smoke.lua
```

O teste usa mocks e a fixture versionada `tools/fixtures/settings_baseline.lua`; ele cobre apenas os contratos e caminhos exercitados. Não valida rendering/interação no CSP nem substitui os cenários in-game abaixo.

### 2.4 Mock smoke test do logo e callback de ícone

```powershell
luajit tools/test_logo_smoke.lua
```

Esse teste compila somente o callback de ícone extraído do entry point e testa `Logo`/renderer com uma UI mockada. Não valida rendering real no CSP.

### Últimos checks headless registrados

Os últimos resultados registrados são: sintaxe Lua 66 PASS, mock UI portátil 542 PASS, mock de logo 19 PASS e comparação opcional com baseline 607 PASS. São checks de fonte/mocks; não comprovam estado da instalação, compatibilidade CSP em execução ou aparência in-game. Para comparar com um baseline separado, defina opcionalmente `RTD_BASELINE_SETTINGS` para o caminho local desse arquivo-fonte antes de executar `tools/test_ui_smoke.lua`; a fixture versionada continua sendo o padrão e não é regenerada automaticamente.

---

## 3. Antes de instalar no AC

### 3.1 Backup da versão antiga e configurações

```powershell
$acLuaApps = "<Assetto Corsa>\apps\lua"
$backupRoot = "<backup-location>\SimOpenTrackDay-test-backup"
Copy-Item -LiteralPath (Join-Path $acLuaApps "<existing-app-directory>") -Destination (Join-Path $backupRoot "existing-app") -Recurse
```

Substitua os valores entre `<...>` por caminhos seus. Preserve também as configurações do usuário; não redefina nem remova diretórios de configuração durante esses testes.

### 3.2 Copiar a nova versão

Faça a cópia **manualmente** dos arquivos de runtime da raiz e das pastas `CarStateMachine/`, `DataStructures/`, `Strings/` e `lib/` para uma pasta paralela `<Assetto Corsa>/apps/lua/SimOpenTrackDay/`. Inclua o entry point `SimOpenTrackDay.lua`, `manifest.ini` e os demais arquivos runtime necessários. Não copie `.git/`, `tools/`, `docs/`, `artifacts/` ou arquivos `*.bak`. Não use uma cópia ampla do repositório. O entry point instalado deve ser `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua`; não crie a hierarquia `apps/lua/` dentro do clone. Mantenha instalações existentes e configurações do usuário intactas.

---

## 4. Smoke test no AC (carregar o app)

Este é um roteiro mínimo de smoke test manual para executar após instalar uma cópia de teste. Runtime CSP e validação visual permanecem pendentes; não presuma que os arquivos instalados correspondem a uma versão específica do código-fonte.

1. Abra o Assetto Corsa.
2. Vá em **Content Manager → Settings → Custom Shaders Patch**.
3. Verifique **Lua Apps** — o app "SimOpenTrackDay" deve aparecer na lista.
4. Habilite o app.
5. Volte para **Content Manager → Settings → Custom Shaders Patch → New AI
   Behaviour**.
6. Ative **AI Flood** (Trackday mode).
7. Inicie uma sessão **Practice** na Nordschleife (ou outra pista com AI spline).
8. Abra a janela in-game do "SimOpenTrackDay" pelo sidebar.

### Se der erro de CSP faltando

Se faltarem funções CSP, consulte as mensagens de compatibilidade e os logs CSP, incluindo os registros `[RTD-DIAG-*]` e a última mensagem de compatibilidade disponível. `CSPCompatibilityManager.ShowErrorModalDialog = false` desativa intencionalmente o modal de diagnóstico; não dependa de uma janela modal para perceber a falha. Isso é mais provável em **CSP < 0.3.0**. Soluções:

- Atualize o CSP para 0.3.0+ (https://acstuff.club/patch).
- **OU** desabilite o app por enquanto via "Lua Apps".

---

## 5. Cenários de validação in-game (pendentes para este fork)

Use estes cenários detalhados para validar as features após instalar manualmente uma cópia de teste. Eles descrevem verificações planejadas, não resultados já observados neste fork. Sempre que possível, deixe a tabela de debug ligada (`storage_Debugging.drawCarList = true`) para inspecionar o estado dos carros.

### Cenário 1: Trilha 1 — simulação reativada

- Pilotar 5 voltas na Nordschleife.
- **Esperado**: carros IA continuam dirigindo (não "congelam").
- **Esperado**: indicador lateral de cada carro aparece na tabela de debug.
- **Bug se**: carros IA param de se mover, ou viram NPCs inertes.

### Cenário 2: Trilha 2 — performance

- Habilite `storage_Debugging.drawCarList = true` para ver a tabela de carros.
- Pilote com 20–30 carros IA na pista.
- **Esperado**: framerate estável (acima de 60 fps na maioria dos setups).
- **Bug se**: framerate cai abaixo de 30 fps com IA moderada.

### Cenário 3: Perfil Casual

1. `SettingsWindow → Behavior & Mode → "Casual"`.
2. Pilote na Nordschleife.

- **Esperado**: carros IA cedem passagem de forma muito rápida (point-by speed
  delta = 25 km/h).
- **Esperado**: nenhuma defesa de posição.
- **Esperado**: nenhum erro humano (lock-up/traction).
- **Esperado**: transições suaves (`entryBlendTime = 0.5s`).

### Cenário 4: Perfil Realistic

1. `SettingsWindow → Behavior & Mode → "Realistic"` (default).
2. Pilote na Nordschleife.

- **Esperado**: cedem com diff > 15 km/h.
- **Esperado**: blend time 1.5s (visível: a lateral muda gradualmente).
- **Esperado**: hesitação de ~0.4s antes de reagir.
- **Esperado**: nenhuma defesa, nenhum erro.

### Cenário 5: Perfil Competitive

1. `SettingsWindow → Behavior & Mode → "Competitive"`.
2. Pilote na Nordschleife.

- **Esperado**: carros defendem posição por 1–3s antes de ceder.
- **Esperado**: lock-ups ocasionais em frenagem forte.
- **Esperado**: tração perdida na saída de curva.
- **Esperado**: cedem só se muito mais rápido (10 km/h diff).

### Cenário 6: Modo Hybrid (auto-detect)

1. Selecione o perfil Realistic (mode = `HybridAdaptive`).
2. Inicie Practice com 2 carros IA.
   - **Esperado**: AI detecta "few cars + Practice" → **Track Day mode**.
3. Aumente para 10+ carros via AI Flood.
   - **Esperado**: continua Track Day (cars adaptam).
4. Troque para Race com 2 carros.
   - **Esperado**: detecta "Race" → **Race mode** → defesa ativa.

### Cenário 7: Anti-drag-race

1. Perfil **Competitive**.
2. Pilote atrás de um AI mais lento em uma reta longa.

- **Esperado**: o AI à frente **não acelera** deliberadamente para segurar o
  jogador; `setAiTopSpeed` é limitado a 95% da sua velocidade.

---

## 6. Debugging checklist

Se algo parecer errado, ligue as flags abaixo (em `Storage`/`storage_Debugging`)
e reproduza:

1. `storage_Debugging.drawCarList = true` — mostra a tabela de carros.
2. `storage_Debugging.debugShowCarStateOverheadText = true` — texto flutuante
   acima de cada carro.
3. `storage_Debugging.debugShowRaycastsWhileDrivingLaterally = true` — desenha
   os raycasts de detecção lateral.
4. `storage_Debugging.debugDrawSideOfftrack = true` — desenha a detecção de
   off-track.
5. `Constants.PATHFINDING_DEBUGGING = true` (em `Constants.lua`) — ativa o
   Pathfinding experimental.

Lembre-se de **desligar** essas flags antes de medir performance (Cenário 2),
pois elas adicionam custo de render/debug.

---

## 7. Rolling back (sem apagar instalações ou configurações)

Se uma versão quebrar o jogo:

1. Pare o Assetto Corsa.
2. Desabilite a cópia de teste na lista Lua Apps do CSP. Não remova a instalação de teste até terminar a comparação.
3. Restaure a instalação e configuração conhecidas a partir do backup, se necessário:
   ```powershell
   Copy-Item -Path "<backup-location>\existing-app\*" -Destination "<Assetto Corsa>\apps\lua\<existing-app-directory>" -Recurse
   ```
4. Reabra o Assetto Corsa.

---

## Resumo rápido (cheat sheet)

| Etapa | Comando / Ação | Esperado |
| --- | --- | --- |
| Sintaxe | `tools/check_lua_syntax.ps1` | Contagem dinâmica; nenhuma falha |
| Grep regressões | `findstr` (3 padrões) | 0 matches cada |
| Backup | copiar instalação/configuração antiga | cópia preservada |
| Instalar | copiar para `apps/lua/SimOpenTrackDay/` | cópia paralela sem apagar a existente |
| Smoke test | habilitar Lua App + AI Flood | pendente até execução no CSP |
| Cenários | 1 → 7 | verificações planejadas, não resultados já confirmados |
| Rollback | desabilitar teste/restaurar backup | instalações e configurações preservadas |
