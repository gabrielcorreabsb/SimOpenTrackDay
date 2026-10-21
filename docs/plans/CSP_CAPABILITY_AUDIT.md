# Auditoria M0: capacidades CSP na Lua App

## Estado, escopo e proveniência

- **Data:** 2026-10-21. **Baseline de código:** `10ed904d2c2178e5d3c5ec3298d474c37e34ecbd`.
- **Resultado:** auditoria de fontes concluída; viabilidade de atuação no jogo ainda pendente. Não é certificação de suporte a uma versão do CSP.
- A investigação original foi somente leitura do projeto, com verificações locais descritas abaixo. Esta consolidação altera apenas documentação; não implementa milestones nem modifica instalação, manifest, ferramentas, dependências ou configuração do OpenCode.
- O [roadmap original](SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md) permanece como hipóteses/backlog. O [plano incremental](DEVELOPMENT_PLAN.md) registra a sequência revisada e os gates de execução.

Fontes internas consultadas na medida necessária: [regras](../../AGENTS.md), [README](../../README.md), [arquitetura](../ARCHITECTURE.md), [FSM](../STATE_MACHINE.md), [testes](../TESTING.md) e [workflow](../WORKFLOW_OPENCODE.md), confrontadas com a implementação. Descrições históricas não prevalecem sobre o código inspecionado.

### Quatro classes de evidência independentes

| Classe | O que estabelece | O que não estabelece |
| --- | --- | --- |
| **S — SDK** | Assinatura, campos e contrato documentado no SDK consultado | Disponibilidade/permissão na instalação ou efeito físico real |
| **E — exemplo externo** | Outro projeto contém aquele uso, no commit indicado | Funcionamento no SimOpenTrackDay, licença para copiar ou suporte universal |
| **P — projeto** | Há chamada/consumo no código atual, distinguindo ativo, parcial e inativo | Que a chamada já foi executada com sucesso no jogo |
| **R — runtime** | Resultado observado em cenário, instalação e build identificados | Generalização para outros modos, carros, pistas ou builds |

**R das capacidades de IA auditadas: pendente.** A confirmação histórica de 18/10/2026 é limitada à recuperação do carregamento da UI após retirar módulos antigos da raiz do AC; não comprova física/IA, todas as abas ou o bootstrap posterior. Ver [incidente de carregamento](MODULE_LOADING_HARDENING.md).

### SDK e contexto

O agregado distribuído em [lib/ac_apps/lib.lua](../../lib/ac_apps/lib.lua) veio do commit local `d87be0d2de7280109bda25a5daeaa711bea4d468`, de 26/04/2026, identificado como `v0.3.0-preview361`. Isso **não identifica o SDK instalado nem a build CSP do usuário**. O submódulo de compatibilidade estava em `7007085f48ad12a0bcf35eaed028691111a83697`.

O [entrypoint oficial de Lua Apps](https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/7cf60f5a406820ee4e39f3a62ed121fa36274001/ac_apps.lua) importa os módulos physics/AI, com `withPhysics=true` e permissão `luatools`; não importa automaticamente o módulo unrestricted. As implementações nativas C++ não estão nessas declarações Lua. O agregado local também perde parte da separação original por contexto: um marcador de seção isolado não comprova que uma função pertence a car script ou app.

`physics.allowed()` documenta que, quando falso, só `raycastTrack` está disponível. É necessário verificar permissões e comportamento no contexto instalado; existência do símbolo não basta. As notas de opt-in de pista do módulo unrestricted **não provam** que toda chamada AI da app exige `ALLOW_DISPLAY`, nem autorizam alterar pistas.

## Inventário de capacidades

Referências `lib.lua:<linha>` são localizadores da baseline, não chamadas executadas nesta auditoria. Em todas as linhas abaixo, **build instalada desconhecida e R pendente**.

| Domínio e funções/campos | S / contexto documentado | E | P na baseline | Risco e fallback proposto |
| --- | --- | --- | --- | --- |
| `ac.getSim`, `ac.getCar`, `ac.iterateCars` | Lua App; estado do sim e carros | RARE, ApexFlow, ConditionReports | Ativos no loop/coleta | Índice não é identidade persistente; snapshots com geração e dado inválido como desconhecido |
| `physics.setAITopSpeed`, `setAIThrottleLimit`, `setAIBrakeHint` | SDK physics/AI; `lib.lua:14729–14749` | RARE/ApexFlow exemplificam controles AI | Top speed/throttle ativos; hint também em caminho experimental de pedais | Não são controle integral da IA; desabilitar domínio se não comprovado, sem inventar baseline |
| `setAILevel`, `setAIAggression`, `setAICaution`, `setExtraAIGrip` | SDK physics/AI; `14653–14780` | RARE/ApexFlow | Ativos em operações, inicialização e FSM | Ranges e valores nativos diferentes dos armazenados; não adicionar grip para simular clima/pneus |
| `setAISplineOffset`, `setAISplineAbsoluteOffset` | Normalizado e metros, respectivamente; `14756–14768` | ApexFlow | Offset normalizado ativo | Limites de pista e decisão nativa permanecem; sem promessa de veto de ultrapassagem |
| `setAIStopCounter`, `setGentleStop`, `preventAIFromRetiring` | SDK physics/AI; contador em segundos; prevent-retiring temporário | Exemplos de controle AI | Ativos, inclusive pós-incidente | Renovação pode manter carro parado; requer prioridade, expiração e recuperação limitada |
| `setAIBrakeMistake`, `setAITractionMistake` | SDK physics/AI; duração e severidade; `14797+` | Não necessário para provar presença | Ativos em `HumanErrorManager` | Falta filtro AI/pit e reset próprio; não ampliar até isolamento validado |
| `disableCarCollisions`, `overrideRacingFlag` | SDK physics; `14508+`, `14588+` | Não necessário para provar presença | Ativos em incidentes/zonas e bandeira da câmera | Colisões desativadas não são solução geral; `ac.FlagType.None` devolve controle nativo, não apaga bandeira nativa |
| `ac.setTargetCar`, luzes, `ac.overrideCarControls` | SDK; alvo implícito e controles também podem alcançar jogador | Exemplos não provam isolamento | Alvo/luzes ativos; overrides de pedais presentes | Definir alcance e ownership; efeito cruzado entre scripts não foi demonstrado |
| `physics.setAIPitStopRequest` | SDK AI `14782–14785`; `false` suprime ida ao pit por curto tempo | RARE usa gate de patch code `>=2278` | Sem integração ativa de pit | Gate externo não é mínimo universal; probe separado, opt-in, timeout e fallback observacional |
| `setAITyres`, `setCarFuel`, `setAILapsToComplete` | Índice de composto 0-based, litros, voltas; `14787–14795`, `14393+` | RARE/ApexFlow para pneus/combustível | Sem serviço ativo; há fuel em estado experimental AfterCustomFlood; laps não usado | Pneus também resetam dano; fuel invalida volta. Sem esvaziar tanque ou teleportar como fallback |
| `isInPitlane`, `isInPit`, `isAIGoingToPits`, `isRequestingPitStop`, `pitTransform` | `StateCar`, `4760–4850`; pitlane é área, pit é próprio box | RARE/ApexFlow leem estados | Parcial; sem observador completo do ciclo | Pedido, entrada, box, serviço e saída devem ser eventos distintos |
| `wheels[0..3]`, temperaturas, `tyreWear`, pressão, danos, fuel | `StateWheel`/`StateCar`, `4652–5038`; disponibilidade física varia | RARE/ApexFlow interpretam desgaste; semântica não universal | Fuel/pedais/estado parcialmente consumidos; monitor completo ausente | Nil/NaN/sensor ausente não viram zero; pressão/unidades e polaridade de desgaste requerem confirmação |
| `rainIntensity`, `rainWetness`, `rainWater`, temperaturas, `roadGrip`, vento | `StateSim`, `5148+`; leitura de ambiente | ConditionReports | Sem adaptação ambiental integrada | Chuva visual não prova grip físico; leitura neutra quando indisponível |
| `ac.ConditionsSet`, `ac.setConditionsSet2` | Exemplo de WeatherFX controller; `setConditionsSet2` ausente no SDK App local | Controlador base oficial | Ausentes | Não oferecer geração de clima pela app; projeto/contexto separado se autorizado |
| Falha mecânica física e canais MRF | Car physics script e contrato do carro, não API universal de grid | MRF publica canais versionados | Sem ponte MRF | Score virtual deve ser rotulado; integração só por contrato suportado, sem modificar carros |
| `ac.storage`, `ac.log/warn/error` | Persistência/debounce e logs no SDK | Não exige backend novo | StorageManager e logs presentes | Novas keys via schema; logs limitados/opt-in, sem IO/cloud/per-frame presumidos |

### Contratos que afetam o desenho

- Top speed: km/h; `math.huge` ou `1e9` remove a limitação segundo o SDK. Throttle: `1` remove o limite. Isso não restaura um limite de outro mod.
- Brake hint é um hint de `ai.ini`, não posição absoluta do pedal. O valor do arquivo pode ser referência, mas não é readback de overrides atuais.
- `setAILevel` admite `0..2`; `car.aiLevel` documenta `0..1` ou `-1`. Aggression admite `0..1`, com ajuste do launcher descrito no SDK. Não confundir leitura com valor de escrita sem verificar.
- Caution é experimental (`0..16`, padrão documentado `1`). Extra grip documenta `1` como grip normal e 120% por padrão. Logo, **escrever `1` não comprova restaurar o baseline nativo**.
- Não foram encontrados getters dos overrides atuais de top speed, throttle, caution, grip, brake hint e offsets. Shadow-state registra somente o que este app escreveu; não detecta confiavelmente outro mod nem recupera valores nativos desconhecidos.
- `preventAIFromRetiring` é temporário e exige repetição. `setAIPitStopRequest(false)` não é cancelamento permanente. `setAITyres` também reseta dano; chamada sem erro não prova troca efetiva nem serviço concluído.
- `isAIControlled` inclui autopilot. A política futura deve proteger explicitamente o jogador, inclusive índice 0, em vez de depender só desse flag.
- `isRefueling`, `isChangingTyres` e `isRepairing` aparecem com tipagem `string` no agregado; tipo/validade precisam de verificação. `fuelPerLap` depende de física; `getCarPhysics().isAvailable` importa. Temperatura de freio zero pode indicar indisponibilidade.
- O SDK descreve `tyreWear` em `0..1`, sem definir polaridade nesse campo. Comentários e limiares de mods não substituem calibração por build/carro.
- `hasTrackSpline`, coordenadas/progresso e track sides não comprovam `pit_lane.ai` navegável nem box válido. `setAISpline` substitui spline: **não** é inspeção segura do caminho de pit. Não foi encontrada API documentada suficiente para certificar o pit path.

## Evidência externa e licenças

As fontes abaixo foram lidas, **não executadas no CSP**. Nenhum trecho foi incorporado. Gate de build e comentários de um mod não são contratos universais do SDK.

| Fonte fixada | Evidência e limite |
| --- | --- |
| [RARE: ai.lua, 68cfc1c](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements/blob/68cfc1c1005090b16c7d3df5722d5ce6427c079e/RARE/src/controllers/ai.lua) | AGPL-3.0 verificada. Request usa gate `>=2278`; fallback em build inferior reduz fuel a `0.1`, prática não adotada. Marca estado de pit ao enviar pedido, sem comprovar entrada/ciclo completo. |
| [ApexFlow: race_strategy.lua, e57bc4a](https://github.com/Silxyst/ApexFlow/blob/e57bc4ade9b9e5f7e449013541b2345dd4254ef6/src/race_strategy.lua) | MIT verificada. Estratégia força pit por combustível, não demonstra `setAIPitStopRequest`. Condição pitlane OU pit não prova box imóvel. Uso de pneus também depende de gate/build. |
| [ConditionReports, 138ab68](https://github.com/otherchriso/AC_ConditionReports/tree/138ab680973e6f2f73d1182cc96e7edc5000e8e0) | Exemplo de leitura de condições, incluindo `rainWetness`; não prova capacidade de escrever clima pela app. |
| [MRF, 62a19c8](https://github.com/cvr-admin/gec_feature_script/tree/62a19c863eff6d088dc96c5d46cd74ad2d968a5b) | MIT verificada. Car script publica contratos como `cvr.pitCrew.tyres.v1`, `roadside.v1`, `status.v2`, `fuelStatus.v1`, `serviceStatus.v4`, com car index. Não é suporte mecânico universal; não interpretar CPHYS arbitrariamente. |
| [Controlador weather base, 3cfd56f](https://github.com/ac-custom-shaders-patch/acc-extension-config/blob/3cfd56f97cb60075594aca8b19653ddb197478fd/weather-controllers/base/controller.lua) | Demonstra condições no contexto de weather controller, separado da Lua App. |

Preservar a [licença MIT do projeto](../../LICENSE) e o copyright de Andreas Grech. Verve permanece referência conceitual restritiva; Full Send GPL e RARE AGPL exigem decisão de compatibilidade antes de qualquer reutilização. Fontes públicas ou licenças alegadas no roadmap não são autorização automática de cópia.

## Achados no código atual

Prioridades abaixo são para planejamento, não autorização de correção. Localizadores referem-se à baseline; **efeitos físicos residuais não foram medidos no jogo**. Nomes curtos de estados correspondem aos arquivos `CarState_*.lua` em [CarStateMachine/States](../../CarStateMachine/States/).

| ID / prioridade | Evidência no código | Risco / encaminhamento |
| --- | --- | --- |
| A01 — alta | `SimOpenTrackDay.lua:272,458–462` inicializa antes do filtro AI; `CarManager.lua:159–225` escreve controles; `HumanErrorManager.lua:16–30` não filtra AI/pit; `AccidentManager.lua:193–195` pode alcançar vítima 0 | Proteção do jogador incompleta. M1a precisa cobrir inicialização, callbacks, incidentes e erros, não somente a FSM. |
| A02 — alta | `SimOpenTrackDay.lua:303–309,409–415`: disable retorna sem cleanup central; sem gate de replay; pausa precede drenagem, callbacks `360–375` enfileiram | Writes não são explicitamente liberados ao desligar; duração real depende de cada API. Evitar fila antiga e definir política de pausa/replay. |
| A03 — alta | Session start `377–381` só notifica timer; baselines `286–296` capturados uma vez; Jumped `337–357` não limpa HumanError; caches por índice | Índice reciclado pode herdar estado. Geração por sessão/carro, descarte de eventos velhos e baseline antes de escrita quando disponível. |
| A04 — alta | `CollidedWithCar`/`AnotherCarCollidedIntoMe` têm transições vazias; `CarOperations.lua:429–437` repete throttle/top speed zero, stop/gentle stop/caution; Yellow exit só speed/lights; Navigate exit não restaura colisões | Há caminhos sem recuperação/limpeza explícita. Antecipar estabilização de incidentes após base de lifecycle/ownership. Não presumir que ligar colisão indiscriminadamente respeite Flood/outro mod. |
| A05 — alta | `SimOpenTrackDay.lua:507–509` limita velocidade e `CarOperations.lua:215–224` grava o aplicado em `cars_aiTopSpeed` | Feedback sticky: cap global 100 pode persistir no valor individual após remover o cap. Separar solicitado/aplicado em M1b. |
| A06 — média/alta | `CarState_DrivingNormally.lua:96` chama `driveSafelyToSide`; `CarOperations.lua:571` aplica `DRIVING_TO_THE_SIDE=1.3` se o caminho prossegue | Grip adicional já existe na condução normal; não apresentar o baseline como física neutra nem adicionar outro multiplicador para pneus frios/chuva. |
| A07 — alta | Compat manager verifica símbolos; `SimOpenTrackDay.lua:142–149` registra erro, mas retorno impeditivo está comentado; `setAILevel` ativo sem registro correspondente; `physics.allowed` não consultado | Registro/existência não é gate funcional. Manter modal false; planejar capability por domínio, com ausência levando a modo seguro. |
| A08 — média | HumanError usa `probabilidade * dt`, cooldown e timers por índice, sem validação de dt, filtro de pit/jogador ou reset próprio | Já há aproximação dependente de dt, não ausência total de normalização. Testar dt inválido, 30/60/120 Hz, cooldown e geração sem ampliar erros artificiais. |
| A09 — média | `BehaviorPolish` é carregado, sem consumers dos helpers; defesa inline sem transição de entrada; custom Flood require desabilitado; AfterCustomFlood depende desse caminho; anti-drag helper sem caller | Configurações e módulos existentes não demonstram comportamento integrado. Integrar somente depois da base, sem prometer anti-drag de 95% ativo. |
| A10 — média | Storage é capturado no carregamento; `StorageManager.lua:650–663,725–786` usa pista/modo e inferência parcial de perfil | Reavaliar identidade/storage em troca de sessão; não usar `behavior.profile` inexistente nem anunciar inferência confiável para toda combinação. |

### Correções de interpretação, sem alterar as referências existentes

- O steering por `CollisionAvoidanceManager`/`driveSafelyToSide` em `CarState_NavigatingAroundAccident.lua:123–144` está **comentado**. Não há base para reportar um nil-crash ativo desse trecho, nem para afirmar que o desvio lateral está integrado.
- `Pathfinding` é carregado sem caller efetivo; o flag `PATHFINDING_DEBUGGING` descrito na arquitetura não existe na baseline. Não reativar módulos experimentais para coincidir com a documentação.
- `AGENTS.md` manda preservar nove registros `[RTD-DIAG-*]`, enquanto implementação, `test_no_diagnostics` e `TESTING.md` registram sua remoção. É divergência documental a resolver em escopo próprio; **não reintroduzir diagnósticos** nesta consolidação. `ShowErrorModalDialog = false` permanece intacto.
- Campos de BehaviorPolish e aplicação manual de perfis não significam que todos os parâmetros estejam consumidos. Inferência parcial de perfil não é garantia de equivalência de configurações.
- `ac.setTargetCar` muda o alvo implícito; há risco de não restaurar no próprio contexto. Interferência global entre scripts não foi comprovada.

## Verificações já executadas na auditoria M0

Resultados históricos da baseline acima, **não uma nova execução nesta consolidação documental**:

| Verificação | Resultado | Limite |
| --- | --- | --- |
| `tools/check_lua_syntax.ps1`, LuaJIT `2.1.1720049189` | PASS, 85 arquivos | Compilação sem execução; exclui SDK/submódulo/backup, inclui `lib/uilib` |
| `test_lateral_layout`, `test_localization`, `test_logo_smoke`, `test_main_window`, `test_native_controls`, `test_no_diagnostics`, `test_settings_model`, `test_settings_navigation`, `test_ui_controls`, `test_ui_manager`, `test_version` | 11 PASS | Contratos/mock/estática dos caminhos exercitados; não prova IA, renderização ou física |
| `tools/test_ui_smoke.lua` | FAIL, carregamento na linha 10 | Fixture `tools/fixtures/settings_baseline.lua` ausente; não criada/corrigida |
| `tools/test_module_path.lua` | Não executado em M0; código inspecionado | Cria sandbox temporário; evidência histórica de outra etapa não deve ser contada como nova execução |
| Package/installer/distribution PowerShell | Não executados em M0 | Não houve instalação, rollback ou teste de pacote |
| CSP/in-game | Não executado em M0 | Nenhuma chamada auditada ganhou status R por causa de mocks ou leitura |

Ao encerrar M0, diff tracked/staged vazio; untracked preexistentes preservados. O relatório não havia sido gravado naquele momento. Nesta etapa, somente os documentos autorizados são consolidados/versionados; nenhum dos testes Lua precisa ser repetido para uma mudança exclusivamente documental.

## Protocolo futuro de comprovação em runtime

Cada resultado deve identificar revisão instalada, build/patch code CSP exato, contexto Lua App, pista/layout, carros/quantidade, modo de sessão, Flood, controlador climático e outros mods atuantes. Registrar separadamente símbolo disponível, permissão, chamada, efeito observado, duração e liberação. **Sem erro na chamada não significa suporte funcional.**

1. Obter baseline sem nova atuação: filas, contatos por 100 carro-km, paradas, fração desconhecida, CPU média/p95 e GC; não prometer metas numéricas antes dessa medição.
2. Comparar Track Day com Practice/Race, pista com/sem pit path conhecido, reset/Flood e troca de índices. Car index não é identidade persistente.
3. Verificar jogador protegido, replay e dez ciclos de ativar/desativar. Registrar resíduos por controle, inclusive os que não têm readback; não declarar cleanup integral sem observar.
4. Pit: distinguir intenção, request, entrada, box, imobilidade sustentada, serviço e saída; confirmar estados e `pitTransform` válido quando disponível, além de mudanças de sensores. Timeout gera estado seguro/observacional, nunca fuel drain ou teleporte.
5. Pneus: confirmar composto, desgaste e mudança real por build/carro, sem converter NaN/ausência em zero. Clima: validar o dado reportado sem duplicar grip nem alterar Pure/Sol.
6. Preservar instalação e settings; cópia de teste/rollback são manuais e exigem autorização. Logs devem ser limitados, úteis ao cenário e sem dados pessoais publicados.

## Respostas de viabilidade e próximo gate

O pedido de pit e a troca de pneus têm contrato no SDK e exemplos, mas Track Day, serviço completo e matriz de builds seguem pendentes. Top speed/throttle/hints têm múltiplos writers no projeto e não possuem eficácia garantida por modo/Flood. Sensores permitem observação com qualidade explícita, não semântica universal de desgaste. Box parado requer evidências combinadas; não há certificação segura de pit path apenas por API encontrada. Baselines desconhecidos impedem restauração genérica; mod coexistente pode exigir **MonitorOnly**, não detecção inventada de conflito.

BehaviorPolish permanece sem integração; HumanError tem dt aproximado mas isolamento/reset incompletos; lifecycle/cache/storage precisam de identidade por geração. Não duplicar física nativa de pneus/chuva e não supor MRF em carros sem contrato. A suíte local não está integralmente verde, nem cobre o comportamento AI no jogo.

**Próximo desenvolvimento recomendado:** M1a (isolamento/lifecycle), M1b restrito (ownership/valores solicitados versus aplicados), estabilização de incidentes e M2 observacional. Não começar por pit automático, grip novo ou arquitetura completa. Cada implementação exige milestone e arquivos explicitamente autorizados, conforme o [plano](DEVELOPMENT_PLAN.md).
