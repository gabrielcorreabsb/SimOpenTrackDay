# Plano incremental de desenvolvimento do SimOpenTrackDay

## Estado e autoridade

**Consolidado em 2026-10-21**, a partir da conversa, da [auditoria M0](CSP_CAPABILITY_AUDIT.md) e do [roadmap original](SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md). Baseline de código auditada: `10ed904d2c2178e5d3c5ec3298d474c37e34ecbd`.

- **Entrega documental original (`a45ab3b`):** consolidação publicada em `main`; sua autorização não incluía código nem worktrees.
- **M0:** auditoria de fontes concluída; confirmação funcional no CSP pendente. A matriz distingue SDK, exemplos externos, código atual e runtime.
- **M1a:** primeira entrega local revisada em 2026-10-21. Em 2026-10-22, o diagnóstico no CSP identificou bloqueio indevido da representação `cdata` de `physics.allowed`; correção delimitada implementada/revisada e revalidada localmente: 87 sintaxes PASS, testes headless 14 PASS / 1 FAIL preexistente. Nova sessão CSP confirmou permissão na amostra e o usuário relatou retorno dos estados das IAs; aceite integral do M1a ainda pendente. Posteriormente, o usuário autorizou commit, push da branch M1a e encerramento da worktree; integração em `main` e retirada do diagnóstico temporário não integram essa autorização.
- **M1b em diante:** propostas, não autorizadas nem implementadas por este plano. Não há cronograma ou promessa de versão vinculante.
- Em divergências sobre capacidades e baseline, usar as evidências da auditoria; o roadmap continua sendo backlog, não uma descrição confiável de tudo que já funciona.

Objetivo de produto: track day offline com tráfego orgânico, cessão de passagem e cautela contextual, preservando decisões nativas da IA. Não prometer point-by obrigatório, veto universal a ultrapassagens, serviço de pit em qualquer pista ou falha mecânica física universal.

## Sequência e dependências

Trabalhar primeiro a segurança, depois uma fatia funcional pequena. Não criar todos os managers candidatos do roadmap de uma só vez.

| Etapa | Dependência / entrega limitada | Critério verificável de saída |
| --- | --- | --- |
| **M0 — Auditoria** | Fontes/SDK/exemplos confrontados; inventário e riscos registrados | Matriz com contexto, proveniência, riscos e fallback; lacunas runtime explícitas. Fontes concluídas, runtime pendente. |
| **M1a — Isolamento e lifecycle** | M0; proteger jogador, inválidos, replay e fluxo de reset/disable; identidade por geração e eventos obsoletos | Testes focados sem writes proibidos para jogador/replay/índice inválido; sessão/índice reciclado não herda evento/cooldown antigo. Política de disable e cleanup delimitada por contrato, sem alegar restauração de valor desconhecido. |
| **M1b — Ownership, fatia estreita** | M1a; coordenar poucos controles inicialmente, prioridades/expiração e solicitado versus aplicado | Testes de arbitragem e cap global removido sem contaminar pedido individual; liberação só conforme contrato/baseline conhecida; modo observacional quando não houver controle seguro. |
| **Estabilização antecipada de incidentes** | M1a/M1b; antecipar correções de segurança originalmente em M8, sem trazer todo o logbook/reentrada | Saídas/expiração testadas para restrições e estados terminais; pit stop não vira acidente por estar parado; evitar parada indefinida involuntária. Recuperação no CSP ainda requer cenário manual. |
| **M2 — Fases observacionais por carro** | M1a; integração de controle somente após M1b. Primeira entrega de realismo de baixo acoplamento | Fases independentes, com origem observada/estimada/desconhecida; pit desde início, resets e início tardio cobertos. Nenhuma escrita física na fatia inicial. |
| **M3 — Personalidades e BehaviorPolish** | M1b/M2; seed por sessão/identidade, variação lenta e bounded; integrar helpers com consumidores reais | Repetibilidade por seed, reset correto, ausência de sorteio ilimitado por frame; checks em 30/60/120 Hz e comparação manual sem nova instabilidade. |
| **M4 — Tráfego e suavização** | M1b/M3; gap/TTC, histórico, histerese, abort/cooldown e rampa | Casos de wrap, hairpin, aproximação lateral/pit e dado incoerente; fallback conservador para desconhecido. A/B no CSP antes de alegar menos contatos/filas. |
| **M5 — Observador de pit e probe** | M0/M1a; aproveitar M2 quando útil, sem torná-lo bloqueio para observação independente. Atuação do probe depende de M1b | Eventos distintos de pedido/entrada/box/serviço/saída; timeout e negação seguros; prova manual por build/modo/layout. Sem fuel drain/teleporte. Probe separado e desativado por padrão. |
| **M6 — Pit e serviço opt-in** | M5 comprovado no jogo para combinações explicitadas e M1b | Ciclo completo e repetível no cenário suportado; serviço só em box confirmado e parado, com resultado observado; falha volta a estado seguro/observacional. |
| **M7 — Condições e sensores** | Leitura pode iniciar após M1a; adaptações dependem de M1b/M2/M3 | Nil/NaN/ausência neutros; leitura meteorológica não duplica grip. Risco mecânico virtual rotulado; física real só por contrato validado do carro. |
| **M8 — Incidentes e observabilidade restantes** | M1a/M1b e preferencialmente M4/M5; completar após a estabilização antecipada | Incidentes deduplicados/resolvidos/expirados, logs limitados e A/B reproduzível. Sem teleporte padrão ou reentrada arriscada; escopo opt-in separado para recuperação física. |
| **M9 — Consolidação** | Somente capacidades efetivamente implementadas e verificadas | Matriz real de suporte, benchmark contra baseline, documentação/pacote, instalação e rollback manuais. Não declarar suporte geral a partir de um cenário. |

**Caminho inicial recomendado:** M1a → M1b restrito → estabilização de incidentes → M2 observacional. Observação de pit/ambiente pode formar uma lane independente depois da base de isolamento, se não disputar os mesmos arquivos.

O roadmap sugeria versões v0.2–v1.0; estes rótulos não obrigam entregar todas as features antes de uma release. Revisar alcance após cada resultado, em vez de preservar uma sequência inviável.

## Contrato obrigatório antes de implementar

Cada milestone deve ganhar um ticket curto aprovado pelo usuário:

1. Objetivo e comportamento observável; baseline relevante e riscos que pretende reduzir.
2. **Lista exata de arquivos autorizados**, incluindo arquivos novos, testes e documentação. Lista de candidatos não equivale a autorização.
3. Exclusões: o que não muda, especialmente valores físicos, UI, persistência, callbacks, vendor e instalação.
4. Critérios de aceite locais e no CSP, responsável por cada evidência e fallback se o dado/API estiver ausente.
5. Plano de validação proporcional e limites conhecidos, incluindo falhas preexistentes.
6. Necessidade de worktree/branch, ponto-base e operações Git autorizadas. Commit/push de uma etapa não autoriza os seguintes.

### Ticket M1a aprovado — isolamento e lifecycle

**Gate aprovado em 2026-10-21:** implementação delimitada, testes focados e atualização apenas deste documento. A inspeção confirmou `main`/`origin/main` em `a45ab3bfe2cf802d3dbcd99b91db3cbdad121458`, sem alterações tracked preexistentes. Untracked locais foram preservados. Entre a baseline auditada `10ed904` e esse commit só houve documentação: os achados M0 pertinentes continuavam no runtime, sem necessidade de refazer a auditoria.

**Objetivo e mudança deliberada:** impedir atuação por carro no jogador (inclusive autopilot), humanos e índices inválidos/inexistentes; impedir novas atuações em pausa, replay, disable ou permissão física ausente/desconhecida. Aplicar o gate comum aos writers e ao dispatch da FSM, inclusive awake, callbacks e vítimas de incidentes. APIs necessárias ausentes bloqueiam a atuação correspondente.

Identidade usa gerações de sessão/carro nos dados existentes. Capturar snapshots escalares e gerações dos participantes de colisões; descartar eventos/transições obsoletos, inclusive após Jumped/reset/swap, desaparecimento/reaparecimento observável e troca IA/humano. Session start invalida mesmo disabled. Pausa congela tempo/estado e purga pendências nas bordas; disable/replay invalidam estado próprio. Limpar caches, cooldowns, referências e vínculos de acidentes/zonas sem recuperação física completa.

Separar inicialização/limpeza de memória de escrita física. Observações de aggression/level devem preceder a primeira atuação e não atravessar identidades; não equivalem a baseline nativa confiável. Não escrever defaults para simular restauração nem reativar colisões indiscriminadamente. A única exceção global à suspensão é liberar a bandeira própria para `FlagType.None`, quando permitido/disponível, sem restaurar estado de outros mods.

**Allowlist exata:**

| Tipo | Arquivos autorizados |
| --- | --- |
| Runtime existente | `SimOpenTrackDay.lua`, `CarManager.lua`, `CarOperations.lua`, `HumanErrorManager.lua`, `OnCarEventManager.lua`, `CarStateMachine/CarStateMachine.lua`, `AccidentManager.lua`, `RaceTrackManager.lua`, `DataStructures/CompletableIndexCollectionManager.lua` |
| Testes novos | `tools/test_player_guard.lua`, `tools/test_session_lifecycle.lua` |
| Documentação existente | `docs/plans/DEVELOPMENT_PLAN.md` |
| Preparação | `.gitignore` existente e `.ignore` novo no checkout principal e na lane; `.slim/worktrees.json` novo, local/ignorado, no principal |

O helper de coleção deve apenas reiniciar contadores de uma coleção existente em-place, sem criar coleções por reset. Não ampliar a allowlist sem novo gate. Auditoria histórica, `TESTING.md`, states individuais, `SessionDetails.lua`, `GameTimeManager.lua`, `RaceFlagManager.lua`, payload e manifest não fazem parte da edição.

**Exclusões:** M1b/ownership/arbitragem/solicitado versus aplicado, tuning, novos multiplicadores de grip, pit automático, recuperação completa de incidentes, UI, storage/settings, vendor, dependências, configuração do OpenCode e instalação do jogo. Preservar LuaJIT/Lua 5.1, bindings locais e estruturas DoD reutilizáveis.

**Isolamento aprovado e criado:** branch `omos/m1a-player-lifecycle`, worktree `E:\Projetos\SimOpenTrackDay\.slim\worktrees\m1a-player-lifecycle`, base fixa `a45ab3bfe2cf802d3dbcd99b91db3cbdad121458`. Submódulo inicializado na lane em `7007085f48ad12a0bcf35eaed028691111a83697`, sem atualização. A exceção no checkout principal limita-se aos ignores e metadados citados; runtime/testes/docs ficam somente na lane. Nenhum commit, push, integração ou remoção foi autorizado.

**Aceite e donos da evidência:** implementador cria e executa os dois testes focados, com recorder das chamadas dos módulos reais sob mocks; integrador reconcilia os artefatos e executa sintaxe e todos os testes Lua headless; revisor inspeciona o diff somente leitura. Cobrir IA elegível positiva e zero writes proibidos, awake/frame/Jumped/vítima jogador, índices inválidos, APIs/permissão ausentes, dt inválido, dez ciclos de suspensão, `Collision(A) → Jumped(A) → Collision(A)`, reset da vítima, sessão disabled e não herança de cooldowns/baselines/transições/referências/zonas. Limpeza de memória não deve emitir writes físicos.

**Limites:** mock testa contrato lógico, não efeito CSP. Reciclagem silenciosa sem sinal observável não tem identidade certificável; resíduos físicos sem liberação segura ficam para M1b/validação no CSP. Permanecem pendentes ordem real de callbacks, Flood/recycle, jogador/autopilot, replay/pausa/reset, dez ciclos de ativação e resíduos por controle. A falha preexistente de `test_ui_smoke.lua` por fixture ausente deve aparecer no resultado integrado, sem substituição do fixture ou declaração de suíte verde.

### Entrega local M1a e evidências — 2026-10-21

Nos nove módulos autorizados, a implementação separa observação de atuação: jogador/humanos podem ter buffers de memória, mas o gate central rejeita seus controles. O gate usa os sinais documentados `isLive`, `isReplayActive`, `isSessionStarted`, carro AI/ativo/conectado e `physics.allowed() == true`; ausência de permissão/API bloqueia a atuação correspondente. Inicialização e invalidação não aplicam defaults físicos nem reativam colisões.

Eventos capturam gerações dos dois participantes e snapshots escalares; reset/swap, sessão e mudanças observáveis invalidam trabalho antigo. A FSM valida pendências e reconstrói estado ausente pelo dispatch elegível, sem perder uma FSM saudável durante pausa. Referências recebidas de um carro invalidado cancelam a manobra dependente em memória; isso não restaura controles físicos anteriores. Acidentes, zonas, caches, cooldowns e observações têm limpeza delimitada, reutilizando as coleções existentes. A fila de callbacks reutiliza **256 registros**: colisões excedentes são descartadas; Jumped com fila cheia purga pendências antes de entrar. Não há garantia de registrar toda colisão em sobrecarga.

Implementação e testes foram delegados na branch/worktree indicada; a revisão foi somente leitura e os achados reportados foram corrigidos antes da validação integrada. O integrador leu/reconciliou os artefatos e executou uma rodada integrada, com LuaJIT `2.1.1720049189`, a partir da lane:

| Check realmente executado | Resultado e limite |
| --- | --- |
| `tools/check_lua_syntax.ps1 -Root <worktree> -LuaJitPath <luajit.exe>` | **PASS: 87 arquivos**, com exclusões de vendor/submódulo do próprio script |
| Todos os 15 `tools/test_*.lua`, cada um em processo LuaJIT separado | **14 PASS / 1 FAIL**; inclui `test_module_path`, `test_no_diagnostics` e os dois testes novos. A execução agregada terminou com código 1 |
| `test_ui_smoke.lua` sem substituição ou geração de fixture | **FAIL preexistente:** `tools.fixtures.settings_baseline` não encontrado; `tools/fixtures/settings_baseline.lua` continua ausente. Não há suíte integral verde |
| `test_player_guard.lua` e `test_session_lifecycle.lua`, também executados isoladamente na implementação/revisão | **PASS sob mocks**: matriz de writers básicos, índices inválidos, jogador/autopilot/humanos, APIs/permissão ausentes; entry/callbacks reais com gerações, pausa, reset/swap, referências, zonas e dez ciclos de disable/replay com permissão física ativa |
| Revisão do diff/allowlist, `git diff --check` e links locais deste documento | **PASS**; avisos LF/CRLF do Git não foram erros de whitespace |

O harness usa managers reais, mas substitui UI/SDK, relógio/sessão e parte dos estados. As regressões finais exercitam a entry real de `DrivingNormally` e mantêm instalada a transição real vulnerável de `StayingOnOvertakingLane`; isso não equivale à execução integral de todos os estados. Nessa rodada de 2026-10-21 não houve teste CSP, renderização real, benchmark, empacotamento/instalador ou instalação no jogo. Manifest, payload, vendor, dependências e settings não foram alterados.

**Aceite local limitado às evidências acima; runtime pendente.** Validar no CSP a ordem de callbacks, reset da vítima/jogador, swap/Flood/recycle e troca IA/humano; pausa e replay sem atuação; dez ciclos com resíduos por controle observados. Registrar build CSP, revisão instalada e cenário. Baseline observada não prova valor nativo nem liberação de overrides desconhecidos; não certificar reciclagem silenciosa. M1b e recuperação física completa continuam excluídos.

### Diagnóstico CSP e correção de permissão — 2026-10-22

O usuário instalou manualmente a cópia M1a e relatou ausência dos estados dos carros. A instrumentação temporária `[M1a-GATE]`, aprovada e limitada aos dois módulos de entrada/gate e aos dois testes M1a, não alterou a política de atuação nem a UI. Os hashes dos arquivos copiados foram confrontados com a lane; a automação não modificou instalação ou settings.

No `custom_shaders_patch.log` de **CSP v0.3.0-preview675**, sessão de **02:05:06**, a amostra `car=1` mostrou sessão live/iniciada e IA ativa/conectada, mas `result=physics-allowed-not-function`, `physicsAllowedType=cdata`, `physicsAllowedValue=cdata<bool ()>: 0xff` e `physicsTopSpeedType=function`. O teste de tipo Lua `function` rejeitava a API antes de consultá-la, bloqueando o dispatch da FSM. O SDK de apps instalado documenta `physics.allowed()` com retorno booleano; a representação observada é chamável FFI. **Isso prova a incompatibilidade da checagem de tipo, não que a permissão retornará true nem que a FSM já atua corretamente.** O log também registrou bordas de disable e pausa, não a segurança de todos os seus efeitos.

Uma reprodução LuaJIT isolada com callbacks `ffi.cast('bool (*)()', ...)` confirmou `pcall` bem-sucedido com retornos `true` e `false`. Trata-se de prova local da representação, não execução da API CSP real.

**Correção aprovada e implementada nesta rodada:** somente `CarManager.lua`, `SimOpenTrackDay.lua`, `tools/test_player_guard.lua`, `tools/test_session_lifecycle.lua` e este plano. `CarManager.hasPhysicsPermission()` aceita função Lua ou `cdata` sob `pcall`, exigindo chamada bem-sucedida e retorno exatamente `true`; ausência, objeto não chamável, erro, false e resultado desconhecido continuam bloqueados. Os dois helpers de bandeira usam a mesma consulta, sem ampliar a exceção de suspensão além da liberação própria para `None`. Não se usa presença de setter como substituto de permissão nem booleano solto como autorização. Demais gates e exclusões permanecem; os motivos diagnósticos distinguem API ausente, não chamável, erro, false e resultado não verdadeiro.

**Verificação da correção em 2026-10-22:** revisão somente leitura sem novo achado bloqueante; integrador leu/reconciliou os artefatos e executou uma nova rodada integrada com o mesmo LuaJIT, na lane. Sintaxe: **87 PASS**. Todos os 15 testes Lua foram executados em processos separados, incluindo `test_module_path` e `test_no_diagnostics`: **14 PASS / 1 FAIL**, código agregado 1. A única falha continua sendo `test_ui_smoke.lua:10`, por `tools.fixtures.settings_baseline` ausente, sem fixture substituto ou variável de ambiente de baseline. Não há suíte integral verde.

Os testes focados agora usam callbacks FFI reais com retornos true/false, `cdata` não chamável, função Lua com erro e retornos não booleanos, APIs ausentes e tipos desconhecidos; verificam controle AI positivo e bloqueios, além da liberação de bandeira com permissão FFI e sua negação. Esses PASS estabelecem o contrato LuaJIT sob mocks, não o valor retornado pela API instalada nem a atuação da FSM no CSP. O diagnóstico temporário permanece; a automação não instalou a correção.

**Reteste manual observado em 2026-10-22:** após nova cópia dos dois módulos pelo usuário, ele informou **“Estados voltaram”**. No mesmo log CSP v0.3.0-preview675, às **02:29:42**, a amostra `car=1` registrou `result=eligible`, `physicsCheck=true` e `physicsAllowedType=cdata`, com sessão live/iniciada e IA ativa/conectada. Os SHA-256 instalados coincidiram com a lane: `CarManager.lua` = `4AA4FD942C98706DF7BF8828FB17982227C5C76C9E2E8605E02D2CD2D52618B9`; `SimOpenTrackDay.lua` = `FC8ECEA23173C6E04825F2090C8FBCABD202513D66AAF1B701517A61C461AC37`. Isso confirma a consulta de permissão positiva na amostra e o retorno visual relatado dos estados nessa sessão, não o aceite de todos os controles/cenários M1a. O log também mostra entrada em pausa às 02:30:56 e replay às 02:31:53; essas bordas, isoladamente, não comprovam ausência de writes ou cleanup físico. Pista/layout/grade não foram registrados neste reteste.

## Princípios de implementação

- LuaJIT 2.1/Lua 5.1, `bit.*`, bindings locais, tabelas DoD indexadas e buffers reutilizáveis. Não adicionar alocações por frame sem necessidade medida.
- Runtime continua na raiz; não mover módulos, vendor SDK ou submódulo. Preservar manifest, IDs de callbacks, licenças/créditos e `ShowErrorModalDialog = false`.
- Novas keys passam pelo schema/getters do StorageManager; `behavior.profile` não é campo declarado. Inferência parcial não é equivalência geral de perfil.
- UI futura usa English msgids e IDs internos estáveis; enums, logs/reasons e dados do sim não são texto traduzido. Design/UI tem escopo próprio.
- Ordem de controle: inválido/jogador/replay/disable/reset → segurança/incidentes/pit → fases → tráfego → personalidade → cosméticos. Não somar writers concorrentes sem precedência explícita.
- Ownership registra intenção, aplicado, razão, prazo e baseline **quando conhecido**. Shadow-state não é readback; não detectar conflito com outro mod sem observação disponível. Se não houver restauração segura, usar MonitorOnly ou acordo explícito de controle exclusivo.
- Valores padrão e comportamento seguro são preservados na medida possível; não adicionar grip, fuel drain, teleporte ou dano inventado para viabilizar features. Novas features experimentais ficam off por padrão.
- Não duplicar frio/desgaste/chuva já simulados pela física. MRF exige contrato por carro/build/canal; WeatherFX controller é outro contexto/projeto.
- Licença MIT/notice de Andreas Grech preservados. Antes de reutilizar código externo, conferir licença no commit; GPL/AGPL/restritiva exigem decisão separada.
- A divergência sobre os nove `[RTD-DIAG-*]` está registrada na auditoria, não resolvida por reintrodução de probes ou alteração incidental de regras.

## OpenCode V2: organização do trabalho

### Recursos nativos versus convenções deste ambiente

Worktrees e movimentação de sessões são documentados no V2. O [guia de configuração](https://opencode.ai/v2/docs/config/#worktrees) informa `worktree.directory`; sem personalização, o destino é o data directory do servidor, em `worktree/<seis primeiros caracteres do project ID>`. Isso descreve a documentação, **não identifica a configuração local instalada**.

A skill `worktrees` deste ambiente adota `.slim/worktrees/<slug>/` e metadados locais `.slim/worktrees.json`. É uma convenção de skill/plugin, não padrão nativo. Não criar lanes antes de conciliar essa convenção com destino, ignores e aprovação. Qualquer edição de `.gitignore`, `.ignore`, metadados ou configuração deve integrar um escopo explícito; a consolidação original não fez essas alterações, e o ticket M1a autoriza somente a preparação indicada acima.

Na TUI, `Ctrl+P` abre a paleta; a ação de mover sessão tem ID `session.move` e não tem atalho dedicado por padrão. O diálogo inclui criar/mover worktrees. Não pressupor um comando CLI `opencode worktree` inexistente na documentação consultada. A documentação V2 pode diferir da versão instalada: conferir disponibilidade antes de executar.

### Quando uma worktree ajuda

- Uma por milestone de risco ou experimento independente, com branch e base definidas; não uma por agente automaticamente.
- M1a e M1b tendem a disputar arquivos centrais: desenvolver sequencialmente e basear M1b no resultado integrado de M1a, não em branches divergentes antigas.
- Uma fatia somente documental ou correção pequena pode usar o checkout atual. Não criar isolamento mais caro que a tarefa.
- Arquivos untracked, settings locais e submódulos não devem ser presumidos disponíveis na nova árvore. Verificar o checkout/submódulo no SHA esperado e o roadmap versionado antes de delegar. Não atualizar dependências incidentalmente.
- Worktree não isola jogo, processos, serviços nem efeitos de shell. Instalação e teste CSP continuam manuais e separados.
- Em lanes aninhadas, verificar o root/escopo dos checks recursivos para não contar outras worktrees ou artefatos como payload/testes desta lane. Não alterar ferramentas automaticamente para acomodar lanes.

### Ciclo operacional por milestone

1. **Planejar:** fechar ticket/arquivos/aceite e inspecionar status, branch, base, ignores, submódulo, remotos e worktrees existentes. Preservar alterações preexistentes; não usar stash/reset/clean como atalho.
2. **Isolar, se aprovado:** criar branch/worktree no destino autorizado e manter a sessão principal no diretório dela. Conferir explicitamente diretório/branch de cada especialista; não presumir isolamento só pelo nome da sessão.
3. **Delegar proporcionalmente:** explorer para descoberta, fixer para implementação delimitada, designer para UI, code-reviewer somente leitura e git-release para release confirmado. São agentes deste ambiente, não nomes universais do OpenCode.
4. **Paralelizar só o independente:** separar propriedade de arquivos; testes com conhecimento compartilhado de contratos, sem duas lanes alterando o mesmo módulo. Pesquisa/read-only pode ocorrer em paralelo. Reutilizar a sessão especialista quando ela já conhece a área.
5. **Verificar:** cada lane faz checks focados do seu escopo. Integrador lê os artefatos e reconcilia writers; executa uma vez o conjunto integrado aplicável, não a suíte inteira por microalteração.
6. **Revisar:** code-reviewer inspeciona o diff sem editar. No [diff viewer](https://opencode.ai/v2/docs/cli/keybinds/#diff-viewer), `d` seleciona escopo/base e `m` marca arquivo revisado. Isso é apoio de revisão, não gate automático nem prova de aceite.
7. **Publicar/integrar:** apresentar branch, remoto e intervalo de commits antes do push. Stage apenas da allowlist. Commit, push, merge/rebase/cherry-pick e remoção de worktree exigem autorização correspondente; não apagar lane suja ou dado não integrado.
8. **Encerrar:** registrar resultado, revisão, checks realmente executados, limites e próximo gate. Cleanup somente aprovado e após verificar que nada será perdido.

Os recursos existentes já bastam: não é necessário criar agentes, slash commands, skills, plugins, modelos ou permissões para começar. Reavaliar automação apenas se houver atrito recorrente e aprovação dos arquivos exatos.

### Sessões e checkpoints

Uma sessão principal por milestone reduz mistura de objetivos. Subagentes recebem objetivo, caminhos, exclusões e dono da validação; sessão não substitui o contrato em Markdown. Leitura sob demanda conforme o [workflow do projeto](../WORKFLOW_OPENCODE.md), sem carregar toda a árvore documental por padrão.

[`/undo` e snapshots](https://opencode.ai/v2/docs/snapshots/#scope) são conveniência, não backup: cobrem arquivos elegíveis no diretório ativo, não commits/branches nem efeitos externos, e podem não capturar arquivos ignorados. Checkpoints importantes dependem de commit/backup aprovado. Mudar a conversa não garante reversão do jogo ou do shell.

## Plano de evidências e definição de pronto

| Afirmação | Dono da verificação | Evidência mínima e limite |
| --- | --- | --- |
| Documento coerente, links locais e escopo correto | Integrador documental | Leitura/diff e links; sem Lua tests para docs-only |
| Contrato lógico do milestone | Implementador, com reconciliação do integrador | Teste focado determinístico de caminhos positivos/negativos; mock não prova CSP |
| Código integra sem regressão local detectável | Integrador | Sintaxe e checks aplicáveis após reconciliar lanes; registrar falhas preexistentes e testes omitidos |
| API e efeito funcionam no contexto instalado | Usuário/testador no CSP | Build/revisão instalada e cenário reproduzível, chamada versus efeito/cleanup observados |
| Melhora de tráfego/estabilidade/performance | Integrador + testador | Baseline e A/B equivalentes, CPU/GC e eventos definidos; não concluir por impressão isolada |
| Release só contém escopo aprovado | Responsável Git + integrador | Diff staged/commit, branch/remoto/range e status final; instalação não faz parte do push |

Checks futuros devem cobrir, quando aplicáveis: APIs ausentes, sensores nil/NaN, dt inválido e 30/60/120 Hz, jogador/autopilot, reset/índice reciclado, prioridades/expiração, dez ciclos de disable, storage não destrutivo e i18n. Não expandir todos os testes de uma vez; escolher os que sustentam a afirmação daquela fatia.

Baseline local da auditoria: sintaxe PASS em 85 arquivos; 11 testes Lua headless PASS; `test_ui_smoke.lua` FAIL por fixture ausente. Module-path e testes de pacote/instalador não foram executados em M0. Resultados completos e limites estão na [auditoria](CSP_CAPABILITY_AUDIT.md); não marcar suíte integral verde.

### Cenários manuais propostos, não executados por este plano

- Nordschleife e Spa, grades mistas e carros rápidos/lentos; baseline de 20–30 carros antes de prometer orçamento de performance.
- Track Day versus Practice/Race; pit path presente/ausente, box ocupado, cancelamento e timeout, request versus entrada/serviço/saída.
- Flood, reset/Jumped, replay, troca de controle e índice; jogador protegido e dez ciclos de ativar/desativar sem resíduos próprios observados.
- Aquecimento com sensores válidos versus ausentes; Pure/Sol somente se já instalados pelo usuário, sem modificar controladores.
- Incidente real versus parada legítima no pit, recuperação e sessão longa; coexistência com outro controlador em MonitorOnly quando não houver ownership seguro.

Registrar revisão instalada, CSP exato, pista/layout/carros, sessão, outros mods/controladores, duração, logs/vídeo quando úteis e resultado por cenário. Medir pedidos de pit versus entradas/serviços/saídas, timeouts, filas, paradas, contatos por 100 carro-km, fração desconhecida, CPU média/p95 e GC. Metas quantitativas só depois de obter baseline comparável.

Um milestone só fica **concluído** quando seu escopo está entregue/revisado e suas evidências exigidas estão registradas. Se falta CSP, indicar **implementado e verificado localmente; runtime pendente**, nunca substituir a prova pelo mock.

## Handoff para a próxima sessão

- **Estado:** entrega M1a na branch `omos/m1a-player-lifecycle`; correção da incompatibilidade de tipo na consulta de permissão implementada/revisada localmente em 2026-10-22, com permissão positiva amostrada no CSP e retorno dos estados relatado pelo usuário. Aceite integral M1a pendente. M1b/tuning/UI/pit/recuperação completa excluídos.
- **Lane/base/arquivos:** `omos/m1a-player-lifecycle`, caminho/base fixa e allowlist do ticket acima. Checkout principal preservado, exceto preparação de ignores/metadados aprovada; submódulo permanece fixado.
- **Evidência mais recente (2026-10-22):** 87 sintaxes PASS; 14/15 testes PASS, incluindo novos casos FFI; única falha integrada foi o fixture preexistente ausente de `test_ui_smoke`. Revisão somente leitura encerrada sem novo achado bloqueante na correção.
- **Pendências:** validar os demais cenários CSP: callbacks/Flood/recycle, jogador/autopilot, pausa/replay sem atuação e dez ciclos/resíduos por controle. O retorno dos estados e a amostra de permissão não certificam esses contratos; mocks e fila limitada também não. Diagnóstico temporário ainda presente.
- **Publicação e próximo gate:** em 2026-10-22 o usuário autorizou commit e push da branch M1a e encerramento da worktree, preservando a branch publicada; não integrar em `main`. O diagnóstico temporário permanece. A próxima sessão deve partir do commit publicado dessa branch (não presumir M1a em `main`), propor a menor fatia M1b e sua allowlist/testes/worktree antes de editar, e explicitar cenários CSP restantes e retirada futura do diagnóstico. Somente o usuário fez cópias para a instalação. Não há autorização de implementação M1b, correção do fixture ou configuração do OpenCode.
