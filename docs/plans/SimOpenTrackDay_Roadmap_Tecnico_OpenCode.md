# SimOpenTrackDay — Plano mestre de evolução técnica para OpenCode

> **Tipo:** especificação de produto, levantamento de referências, mapa de viabilidade CSP e backlog executável.  
> **Projeto:** [gabrielcorreabsb/SimOpenTrackDay](https://github.com/gabrielcorreabsb/SimOpenTrackDay)  
> **Contexto:** Assetto Corsa (original, PC), Custom Shaders Patch (CSP), aplicativo Lua, sessões **offline** com IA.  
> **Data do levantamento:** 21 de outubro de 2026.  
> **Estado:** plano proposto; **não** significa que as novas funcionalidades estejam implementadas ou validadas no jogo.  
> **Uso sugerido:** salvar como `docs/plans/ROADMAP_TRACKDAY_REALISM.md` após revisão humana e entregar ao OpenCode. Não executar todas as etapas em uma única alteração.

---

## 0. INSTRUÇÃO PRONTA PARA O OPENCODE

Copie este pedido para uma nova sessão do OpenCode juntamente com este arquivo:

> Analise `AGENTS.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/TESTING.md` e `docs/WORKFLOW_OPENCODE.md` apenas na medida necessária. Use este roadmap como **hipóteses e backlog**, não como autorização para alterar todo o projeto. Primeiro realize uma auditoria de viabilidade das APIs do CSP no contexto **Lua App** do SimOpenTrackDay; separe capacidades comprovadas pelo SDK, exemplificadas por outros mods, presentes no código e confirmadas em runtime. Inspecione o código-fonte atual em vez de confiar em descrições antigas. Forneça inventário de funções, riscos, dependências e um plano incremental com critérios verificáveis. **Não altere código, manifests, ferramentas, dependências, configurações globais do OpenCode nem a instalação do jogo nessa primeira etapa.** Quando eu autorizar um milestone e arquivos específicos, implemente só esse milestone, acrescente testes focados, respeite as licenças e reporte evidências e limitações. Nunca afirme que mocks provam comportamento no jogo.

### Decisões de produto já assumidas

1. O projeto não deve virar um simulador de corrida com IA excessivamente agressiva; deve parecer um **track day com condutores humanos de habilidades diferentes**.
2. O diferencial é **tráfego orgânico, cessão de passagem, cautela contextual, ciclos de entrada e saída da pista, imprevistos plausíveis e estabilidade**.
3. **Não prometer point-by compulsório, proibição total de ultrapassagens, fiscalização infalível ou controle absoluto da IA nativa.** A máquina de estados própria do mod controla apenas a lógica que ela introduz; o Assetto Corsa ainda faz decisões nativas.
4. Continuar como aplicativo offline, com **degradação graciosa** quando uma API estiver ausente ou não se comportar como esperado.
5. Sistemas avançados de física de um veículo e clima controlado por Weather FX **não pertencem automaticamente ao mesmo contexto de execução** de uma Lua App. Integrações opcionais só após prova técnica.
6. Não causar modificações invasivas na instalação, nos carros, em `data.acd`, na configuração do Pure, em outros mods ou no perfil do jogador.
7. Features experimentais vêm **desativadas por padrão**; novas opções devem preservar configurações existentes.
8. O plano pressupõe ciclos curtos de implementação, teste A/B, medição de estabilidade e aceite humano entre milestones.

---

## 1. VISÃO E ESCOPO

### 1.1 Problema a resolver

Um track day real não é uma corrida. É uma sessão compartilhada por veículos e pilotos heterogêneos: carros de rua, esportivos, iniciantes, intermediários e experientes, cada um com ritmos, capacidade de reconhecer tráfego, técnica e períodos de descanso diferentes. A IA tradicional do AC tende a repetir comportamentos previsíveis e, em certos contextos, reage como oponente de competição.

O SimOpenTrackDay deve criar a sensação de participar de um **evento organizado**, preservando o prazer de dirigir e respeitando os limites efetivos do CSP.

### 1.2 Objetivos mensuráveis

- Menos manobras laterais bruscas, contatos evitáveis e engarrafamentos duradouros.
- Pilotos com variações estáveis e distinguíveis de ritmo, reação e cooperação.
- AI capaz de **tentar** completar ciclos de sessão: box → saída → aquecimento → ritmo normal → resfriamento → box.
- Monitoramento real de combustível, pneus, temperatura e danos **quando telemetria estiver disponível**.
- Reação ao clima que respeite o controlador ativo (Pure, Sol, base, etc.) sem duplicar artificialmente a física da chuva.
- Recuperação conservadora de incidentes; nenhuma reposição arriscada na pista como comportamento padrão.
- Overhead de CPU e alocações controlados para grades de 20–30 carros.
- Características novas independentes, desligáveis e testáveis sem afetar indiscriminadamente a IA.

### 1.3 Fora de escopo inicial

- Multiplayer/servidores; este app já declara uso offline.
- Substituição integral do controlador nativo de direção.
- Autorizações de ultrapassagem efetivamente obrigatórias para **toda** IA.
- Pit crew animado 3D, NPCs ou mecânica de veículos universal.
- Emular tempestades por uma Lua App que não seja o controlador Weather FX.
- Suporte obrigatório a qualquer carro de terceiros, inclusive mods com física peculiar.
- Prometer falhas mecânicas com impacto físico sem acesso validado ao script de física correspondente.
- Reutilizar código GPL/AGPL/restritivo sem aprovação de compatibilidade de licença.

---

## 2. BASELINE: O QUE JÁ EXISTE NO REPOSITÓRIO

Reavaliar no checkout atual; itens abaixo foram observados em fontes e documentação consultadas em 21/10/2026. Não são certificação de funcionamento no CSP.

| Componente | Evidência / observação | Ação sugerida |
|---|---|---|
| `SimOpenTrackDay.lua` | Loop principal e callbacks; acumula decisões por carro e eventos; API compat checks | Não dispersar novos writes; definir prioridades e ciclo de reset |
| `CarManager.lua` | Dados por índice (DoD), cache de posição lateral, amostras de velocidade, lista reutilizável | Reaproveitar sem alocações por frame |
| `CarStateMachine/` | Condução normal, cedência, ultrapassagens, amarela, acidentes | Preservar FSM; conectá-la a sinais consultivos, não refazê-la sem motivo |
| `CarOperations.lua` | Offsets laterais, cautela, agressividade, top speed, throttle, indicadoras | Centralizar writes e documentar semântica real das chamadas |
| `BehaviorPolish.lua` | Helpers de suavização, hesitação e confiança, documentados sem call sites principais | Integrar após testes; verificar fórmulas e temporalidade |
| `HumanErrorManager.lua` | Uso de `setAIBrakeMistake` e `setAITractionMistake` com chances/cooldown | Filtrar IA, adaptar a perfis, proteger contra incidentes artificiais |
| `AccidentManager.lua` | Registro de acidentes/zonas amarelas; casos de colisão contra pista ignorados; flag de acidentes default false | Corrigir gestão e critérios antes de habilitar por padrão |
| `RaceFlagManager.lua` | `physics.overrideRacingFlag` com cautela | Não assumir jurisdição completa das bandeiras; operar de forma aditiva |
| `RaceTrackManager.lua` | Dados do traçado e buckets de zonas amarelas | Reaproveitar para curvas, perigos e perfis por circuito |
| `SessionDetails.lua` | Tempo desde o início da sessão | Base para fase de condução por carro, sem assumir que todos começam juntos |
| `StorageManager.lua` | Preferências por pista/tipo de sessão e perfis comportamentais | Adicionar novos campos via esquema existente, migração não destrutiva |
| `CarSpeedLimiter.lua` | Tentativa desabilitada/documentada por problema de atuação de pedais | Não reativar sem teste específico |
| `CollisionAvoidanceManager.lua`, `FrenetAvoid.lua`, `Pathfinding.lua` | Lógica experimental ou desabilitada | Separar pesquisa de ambiente estável |
| `CustomAIFloodManager.lua` | Experimental/desabilitado | Tratar fluxo de carros reciclados como outra modalidade |
| UI unificada | Overview, Behavior, Yielding, Overtaking, Advanced; pt-BR/en/es | Não redesenhar tudo; adicionar seções gradualmente |

### Alertas existentes de engenharia

- O README descreve **v0.1 como prévia**, com validação runtime/visual limitada; não inferir sucesso em pista.
- O projeto usa **LuaJIT 2.1 / Lua 5.1**; utilizar `bit.*`, não operadores bitwise de Lua 5.3.
- **Não mover módulos de runtime da raiz do repositório** por simples reorganização.
- Não editar `lib/ac_apps/` (SDK distribuído) ou o submódulo `lib/AssettoCorsaCSPLuaCompatibilityManager/` incidentalmente.
- Preservar os registros de diagnóstico `[RTD-DIAG-*]`, contratos do `manifest.ini`, licença/créditos e `CSPCompatibilityManager.ShowErrorModalDialog = false`, salvo alteração autorizada e validada.
- **Incidente já documentado:** módulos antigos na raiz do diretório do jogo sombrearam módulos novos do app; `__dirname` foi usado para priorizar a pasta correta. Nunca copiar módulos para a raiz do AC, limpar `package.loaded` globalmente ou "consertar" com exclusões automáticas.
- Alguns testes de UI dependem de um fixture historicamente ausente (`tools/fixtures/settings_baseline.lua`); não reportar testes como aprovados se falharem por esse motivo.
- Há perfis `Casual`, `Realistic`, `Competitive` e modos `TrackDay`, `Race`, `HybridAdaptive`, mas **não inferir automaticamente** que cada campo atualmente afeta o comportamento em runtime.
- `DEFENDING_POSITION` foi descrito como não alcançável em transições normais; defesa competitiva não combina com Track Day de segurança.

**Referências internas obrigatórias:**

- [README](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/README.md)
- [AGENTS.md](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/AGENTS.md)
- [Arquitetura](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/ARCHITECTURE.md)
- [Máquina de estados](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/STATE_MACHINE.md)
- [Testes](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/TESTING.md)
- [Workflow OpenCode](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/WORKFLOW_OPENCODE.md)
- [Incidente de module-loading](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/plans/MODULE_LOADING_HARDENING.md)

---

## 3. REFERÊNCIAS EXTERNAS: MODS, TÉCNICAS E LICENÇAS

**IMPORTANTE:** código disponível publicamente **não significa** código de livre reutilização. URLs são fontes de estudo; revisar licença no commit exato antes de copiar qualquer trecho.

| Referência | Técnica/ideia aplicável | Limite / licença consultada | Links |
|---|---|---|---|
| **Realistic Trackday**, Andreas Grech | Origem da lógica de yield/overtake, FSM, compatibilidade CSP | **MIT**; origem do projeto; preservar notices/autoria | [Repo](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday) |
| **Verve AI** | Personalidades, variação de ritmo, pneus frios, recuperação, telemetria diagnóstica, prevenção de conflitos | **Licença própria restritiva**: inspiração, **não** copiar, redistribuir fork ou incorporar módulos sem permissão | [Repo](https://github.com/ververacing/verve), [LICENSE](https://github.com/ververacing/verve/blob/main/LICENSE.txt) |
| **Full Send AI** | Aprendizado por microsetor, observação de slip e frenagem, ajuste contextual de hints | **GPL-3.0**; estudar ideia, evitar incorporar código no projeto MIT sem decisão explícita | [Repo](https://github.com/Eddlm/Full-Send-AI) |
| **ApexFlow** | Motoristas por estilo, gap/closing speed, pit strategy, indicadores e memória por pista | **MIT** verificada; não assumir compatibilidade de qualquer parâmetro em Track Day | [Repo](https://github.com/Silxyst/ApexFlow), [AI controller](https://github.com/Silxyst/ApexFlow/blob/master/src/ai_controller.lua), [estratégia](https://github.com/Silxyst/ApexFlow/blob/master/src/race_strategy.lua) |
| **RARE — Rules and Race Enhancements** | `setAIPitStopRequest`, pit stops de IA, pneus, `OutLap/FlyingLap/InLap` | **AGPL-3.0**; código para estudo, **não** copiar para MIT sem avaliação de licença | [Repo](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements), [AI.lua](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements/blob/main/RARE/src/controllers/ai.lua) |
| **Mechanical Realism Framework (MRF)** | Falhas de ignição/óleo/arrefecimento/freios/câmbio, reparos por pit crew, estados publicados | **MIT** verificada; projetado principalmente para scripts físicos em carros históricos, **não** IA universal | [Repo](https://github.com/cvr-admin/gec_feature_script), [README](https://github.com/cvr-admin/gec_feature_script/blob/main/README.md) |
| **AC ConditionReports** | Monitor de condições, hora, meteorologia e grip, UI e i18n | **MIT** verificada; bom exemplo de abordagem somente leitura do clima | [Repo](https://github.com/otherchriso/AC_ConditionReports) |
| **Assetto Corsa Race Logger** | Telemetria de todo o grid, detecção de incidentes, lap/stop/replay, logs reprodutíveis | **MIT** verificada; inspiração para debrief e testes A/B, não necessariamente incluir visualizador web | [Repo](https://github.com/Zhaoyi-Fan/assetto-corsa-race-logger) |
| **AC Tracer** | Telemetria CSP Lua, comparação por posição na pista, análise de curvas e treino | Repositório público; **licença não confirmada neste levantamento**; usar apenas ideias até confirmar | [Repo](https://github.com/tobi/ac-tracer) |
| **Auto Yellow Hazards** | Priorização de luzes de emergência, incidente, histerese na bandeira amarela | Consultar licença no commit; não controlar automaticamente indicadores do jogador contra sua intenção | [Repo](https://github.com/yukkine0704/assetto-corsa-auto-yellow-hazards) |
| **Pro Engineer** | Engenheiro virtual, recomendações de pneus/freios/combustível via telemetria | App externo/overlay; estudar abordagem, não acoplar executável ou IA remota por padrão | [Repo](https://github.com/Rgosh/ac-pro-engineer) |
| **CSP Lua SDK** | Fonte de truth para contextos, APIs, assinatura e tipos | Inspecionar SDK instalado em `extension/internal/lua-sdk`, não só repositório remoto | [Repo](https://github.com/ac-custom-shaders-patch/acc-lua-sdk), [README](https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/README.md) |
| **CSP Weather FX Base** | Separação implementação visual vs controlador meteorológico | **Domínio público** conforme README, **mas** contexto não é Lua App | [Repo](https://github.com/ac-custom-shaders-patch/acc-weatherfx-base) |
| **Controlador weather base** | `ac.ConditionsSet()`, `ac.setConditionsSet2()` | Exemplo de **weather controller**, não API automaticamente invocável por app | [Código](https://github.com/ac-custom-shaders-patch/acc-extension-config/blob/master/weather-controllers/base/controller.lua) |

### Novas ideias extraídas desse levantamento

1. **Engenheiro de pista local (read-only):** avisar sobre temperatura, desgaste, autonomia de combustível, provável número de voltas restantes, entrada/saída de box e fase da sessão; inspiração AC ConditionReports/Pro Engineer.
2. **Livro de bordo automático:** registrar eventos do grid inteiro (incidentes, paradas, manobras, tempos de pista, aquecimento, condições); inspiração Race Logger.
3. **Sistema de observabilidade de mod conflitante:** detectar valores da IA sobrescritos por outro mod e oferecer modo somente leitura ou controle seletivo; inspiração Verve.
4. **Previsão de manutenção:** separar advertência, sugestão de pit, pit solicitado, serviço efetuado e confirmação do retorno; inspiração RARE/ApexFlow.
5. **Memória de setores difíceis:** detectar curvas onde há aproximações perigosas e atrasar mudanças laterais; inspiração Full Send/AC Tracer, sem otimização de pace agressivo.
6. **Pits como ciclo do participante, não penalidade de corrida:** sessões individuais de duração desigual, intervalos de descanso, abastecimento e retorno.
7. **Comunicação de segurança não intrusiva:** indicar incidente, sinalização com prioridade e cooldown sem usar hazard indiscriminadamente; inspiração Auto Yellow Hazards.
8. **Relatório de sessão orientado ao track day:** manobras seguras, tempo livre de tráfego, número de voltas, melhor volta apenas como dado secundário, frequência de filas/incident response.
9. **Perfis de confiabilidade mecânica por tipo de carro:** carro de rua, preparado, GT e histórico, mas falha física apenas em veículos compatíveis.
10. **Framework de compatibilidade por capability:** suporte diferenciado a CSP builds, car scripts, layout, AI pit spline, Weather FX/Pure e AI Flood.

---

## 4. MATRIZ DE VIABILIDADE E SEGURANÇA

Legenda: **L1** = observação/estado comprovável na Lua App (validar campos no jogo); **L2** = atuação em APIs exemplificadas mas runtime/modo não validado; **L3** = depende de contexto alternativo/car script; **N** = não garantir como compromisso do produto.

| Recurso | Nível | Status / cautela |
|---|---|---|
| Identificar AI/player, velocidade, posição, pitlane, pneus e combustível | L1 | Dados variam por carro e SDK: nil-safe, amostragem, sem semântica presumida |
| Observar clima (`ac.getSim()` e campos rain/track, se disponíveis) | L1 | Apenas estados reportados; chuva visual ≠ chuva física |
| Registrar telemetria e incidentes | L1 | Não tratar contato/culpa como incontroversos; observação incerta |
| Fases de volta/ritmo por veículo | L1/L2 | FSM interna é viável, aplicação física é aproximada |
| Pedir parada da IA (`physics.setAIPitStopRequest`) | L2 | RARE a utiliza; testar CSP local, tipo da sessão, `pit_lane.ai`, entrada e reinício |
| Escolher pneus da IA (`physics.setAITyres`) | L2 | RARE e ApexFlow têm exemplos; só oferecer com detecção e confirmação |
| Reabastecer IA (`physics.setCarFuel`) | L2 | API aparece em mods; **não** roubar combustível para forçar pit em padrão |
| Limitar top speed / throttle de IA | L2 | SimOpenTrackDay já documenta respostas não confiáveis em alguns modos |
| Ajustar agressividade, cautela, dificuldade, spline | L2 | Influência parcial; não é controle integral de direções/ultrapassagens |
| Aquecimento/resfriamento da IA | L1/L2 | Fases e hints + telemetria: efeito real precisa de validação |
| Desgaste mecânico virtual de longo prazo | L1 | É score/estado informativo; **não** prometer dano físico |
| Falha física real de bomba, óleo, radiador, motor, caixa | L3 | Preferir script do próprio carro e física estendida; MRF é referência |
| Criar sequência de chuva dinâmica por `setConditionsSet2` | L3 | Apenas controlador Weather FX, não uma função genérica de Lua App |
| Point-by obrigatório / bloquear totalmente ultrapassagens nativas | N | Sem API de veto universal comprovada |
| Mandar IA a qualquer pitbox/garantir serviço correto em todos os layouts | N | Dependente de IA nativa, conteúdo do circuito e contexto de sessão |
| Colisões desabilitadas como solução generalizada | N | Não mascarar erros; usar apenas em cenários especificamente testados |

**Regra para OpenCode:** implementar um **probe isolado** para cada capacidade desconhecida antes de criar uma camada de produto que dependa dela. Registrar: versão exata do CSP, contexto, track/layout, modo de sessão, AI count, resultado, falhas, método de fallback. Um símbolo estar presente no código de outro mod não demonstra suporte em toda instalação.


---

## 5. ARQUITETURA-ALVO: PEQUENAS CAMADAS SEM SUBSTITUIR A FSM

### 5.1 Fluxo de dados recomendado

```text
   CSP: ac.getSim(), ac.getCar(), iterateCars(), rodas, pista, clima
                                |
                          Snapshot/cache
                                |
         +----------------------+-----------------------+
         |                      |                       |
 DriverPersonality       TrafficAwareness         ConditionMonitor
 (por veículo)           (risco, TTC, slots)       (pneu, fuel, danos)
         |                      |                       |
         +------------+---------+------------+----------+
                      |                      |
                DrivingPhase            PitStopPlanner
                (por veículo)           (por veículo)
                      |                      |
                      +----------+-----------+
                                 |
                        Intent/Policy Layer
                    (não concede poderes que
                     a API não possui)
                                 |
                   AIControlCoordinator (writer)
                   /       |         |         \
            CSP hints    flags     lateral    pit request
                   \_______|_________|_________/
                                 |
                     Verificação / telemetria
```

- **Sensor/observação:** lê dados do simulador e atualiza caches. Não cria objetos por frame desnecessariamente.
- **Modelo de piloto e pista:** mantém estado por carro/track sem escrever diretamente nas APIs.
- **Política:** decide intenções com prioridades explícitas.
- **Atuação:** controla, em um único lugar, as funções CSP usadas pelo projeto; restaura apenas o que gerencia e cujo valor de base pode ser conhecido com segurança.
- **Monitoramento:** compara intenção e resultado. Se o resultado não corresponder, marca a capability como degradada; não repetir tentativas agressivas.

### 5.2 Módulos candidatos (não mover runtime existente)

| Novo módulo | Responsabilidade | Dependências principais |
|---|---|---|
| `CSPCapabilities.lua` | Detectar funções, campos, versão e resultados dos probes | Entrypoint/compat checks |
| `AIControlCoordinator.lua` | Arbitrar writes, prioridades, duração, restauração; diagnosticar conflitos | `CarOperations`, `CarManager` |
| `DriverPersonalityManager.lua` | Perfis individuais persistentes e seed por sessão | `StorageManager`, `CarManager` |
| `TrafficAwarenessManager.lua` | TTC, distância segura, gaps e manobras arriscadas | `CarManager`, `RaceTrackManager` |
| `DrivingPhaseManager.lua` | Fases por carro e sessão; aquecimento/resfriamento | `SessionDetails`, `PitManager` |
| `CarConditionMonitor.lua` | Amostrar fuel/tyres/temps/damage, normalizar confiabilidade | CSP snapshots |
| `PitManager.lua` | Intenção, solicitação, detecção de entrada/parada/saída; watchdog | `CSPCapabilities`, `CarConditionMonitor` |
| `PitServiceManager.lua` | Política de serviço e confirmação **somente após pit detectado** | `PitManager`, CSP capability |
| `EnvironmentManager.lua` | Adaptação **read-only** às condições recebidas de Weather FX/physics | `CarConditionMonitor`, `CSPCapabilities` |
| `MechanicalConditionManager.lua` | Estado virtual e integração opcional com car scripts MRF-like | `CarConditionMonitor` |
| `IncidentObserver.lua` | Registro de incidentes e obstruções sem culpar jogador automaticamente | `AccidentManager`, `RaceTrackManager` |
| `SessionEventLog.lua` | Eventos estruturados/debrief; flush assíncrono somente se API permitir | `Logger`, `StorageManager` |
| `TrackLearningManager.lua` | Memória de risco por microsetor e snapshots | `RaceTrackManager`, `SessionEventLog` |

**Não criar todos os arquivos no primeiro PR.** O nome exato é uma proposta. Centralização pode ser incremental usando os wrappers existentes. Evitar ciclo de `require`; desenhar grafo de dependência antes de acrescentar módulos.

### 5.3 Prioridades entre comandos

1. **Segurança e integridade de dados:** app disabled, car invalid, car no longer AI, session reset, paused/replay.
2. **Situação especial:** incidentes reais/obstrução próxima, recuperação crítica, pit ingress/egress.
3. **Transições de fase:** aquecimento ou resfriamento, pedido de pit.
4. **Tráfego:** preservar distância e coordenar yield/overtake própria FSM.
5. **Personalidade/ritmo:** ajustes suaves que nunca anulam medidas de segurança.
6. **Extras estéticos:** mensagens, indicadores opcionais.

Ao receber dois pedidos sobre a mesma propriedade (ex.: cautela), não confiar na ordem de execução por módulo. `AIControlCoordinator` deve escolher prioridade, compor quando seguro e emitir um único valor. Registrar `owner`, `reason`, `expiresAt`, `baseline`, `lastWritten`, e expor modo **monitor-only**.

### 5.4 Modelo de dados ilustrativo — NÃO é código pronto

```lua
-- Lua 5.1 / LuaJIT 2.1, pseudocódigo esquemático.
-- Ajustar ao padrão de DoD indexed arrays usado por CarManager.
-- NÃO adicionar tabela aninhada por frame no código quente.

DriverProfile = {
  skill = 0.65,            -- nível relativo de domínio
  awareness = 0.70,        -- percepção de tráfego
  patience = 0.85,         -- propensão a esperar
  consistency = 0.60,      -- variação de ritmo entre voltas
  mechanicalSympathy = 0.80,
  riskAversion = 0.75,
  experienceWithTrack = 0.40,
}

-- PerCarState: por carIndex, reutilizável, com geração de sessão.
-- Valores são apenas exemplos de dados; não mapear diretamente para
-- setAILevel/setAICaution sem calibrar no contexto do CSP.
PerCarState = {
  carIndex = 7,
  generation = 3,
  mode = 'permanent_grid',
  phase = 'WARM_UP',
  pitPhase = 'OUT',
  pitRequestReason = nil,
  pitRequestAt = nil,
  lastObservedLap = 1,
  lastObservedSpline = 0.45,
  observedTyreWear = nil,
  observedFuel = nil,
  featureConfidence = 0.0,
}
```

### 5.5 Ciclo de vida e reset

- Identificar reset de sessão, layout, troca do veículo de índice, `Jumped`, reinício e destruição/recriação de IA.
- Adotar `sessionGeneration` para invalidar memória transitória ao mudar sessão. **Car index não é identidade persistente de piloto** se existe AI Flood/reciclagem.
- Registrar baseline e escrituras anteriores de cada propriedade somente quando a semântica de leitura for estável. Em caso de valor sobrescrito externamente, **não disputar controle** em loop.
- Na desativação, cancelar intenções pendentes e remover controles próprios por wrappers documentados; nunca restaurar valores adivinhados que pertencem a outro mod.
- Não manipular o carro do jogador a menos que ele ative separadamente uma função que o afete (ex.: HUD; nunca força física como padrão).

---

## 6. FEATURE: PILOTOS INDIVIDUAIS E TRÁFEGO ORGÂNICO

### 6.1 Personalidade persistente por evento

A IA deve diferir em **habilidade**, **consistência**, **consciência espacial**, **cautela**, **paciência**, **fluência no traçado** e **conservação mecânica**. Não confundir personalidade com um único slider de agressividade.

- Criar perfil por piloto na inicialização da sessão; sem usar `math.random()` irrestrito a cada frame.
- Usar `sessionSeed` e determinismo possível em mocks para reprodução de incidentes.
- O ritmo varia lentamente por volta/setor, **não** por alteração brusca da aderência toda vez que a IA cruza um limite.
- Iniciantes podem frear antecipadamente, manter margens e demorar a ceder, **não** provocar colisões frequentes sem causa.
- Pilotos experientes podem ler o tráfego cedo sem entrar em modo corrida/defesa de posição.
- Personalidades podem incorporar classe do carro; estabelecer `vehicleClassConfidence` para fallback quando dados do carro são insuficientes.
- Presets propostos: `Beginner`, `Intermediate`, `Experienced`, `Mixed Trackday`; internos em inglês, labels localizados.
- Oferecer distribuição configurável (exemplo **não estatístico**: 35% Beginner, 45% Intermediate, 20% Experienced).
- Persistência da personalidade entre sessões: opcional por `track+car+driverName`, com cuidado para nomes homônimos e índice reciclado. Por padrão, persistir o **preset** e sortear perfis por sessão.

### 6.2 Percepção e risco no trânsito

Calcular distância **livre** ao longo da pista, velocidade relativa, potencial de fechamento e viabilidade lateral. Um TTC simplificado é `gapMeters / max(closingSpeed_mps, epsilon)` apenas para carros seguindo a mesma direção e na mesma região do traçado. Não usar distância Euclidiana sozinha para decidir carros vizinhos em Hairpins, cruzamentos, pit lanes ou trechos paralelos.

**Algoritmo proposto:**

1. Listar vizinhos ordenados por progresso de spline e progresso/lap com normalização circular; lidar com pitlane e teleport.
2. Filtrar falsos vizinhos por diferença de voltas, posição espacial, sentido, piso, lateral, pitlane e status.
3. Estimar `closingSpeed`, `gap`, `TTC` e histórico curto de aproximação; se medidas não forem coerentes, marcar risco `unknown`, não “seguro”.
4. Introduzir **histerese** e tempo mínimo para iniciar/cancelar deslocamento, sem mover bruscamente entre offsets.
5. Negar à FSM **suas próprias manobras** quando há lacuna crítica, curva estreita ou ocorrência de incidente; registrar que a IA nativa permanece autônoma.
6. Depois da ultrapassagem, retornar progressivamente ao offset de origem; nunca atravessar um veículo próximo.
7. Priorizar alteração de observação/decisão sobre comandos físicos invasivos.

**Critérios de aceite:** reduzir mudanças bruscas e conflitos laterais no conjunto de testes; manter tempo preso atrás de carro lento dentro de limite definido após medir baseline; nenhuma nova alocação por frame.

### 6.3 Aprendizado por trecho (opcional, não v0.2)

Inspirar-se no Full Send AI (amostras por ~50 m e ajuste progressivo), mas mudar o objetivo para **segurança e consistência**. Segmentar a pista em janelas métricas normalizadas pelo comprimento real; incluir fechamento circular `0/1`, sessões curtas, pistas sem spline ou com pistas alternativas, limites de memória.

`TrackLearningManager` poderá estimar por setor:

- Taxa de aproximações críticas;
- Duração média de obstruções e incidentes;
- Mudanças bruscas de direção;
- Curvatura/estreitamento do spline;
- Consistência de frenagem (apenas quando telemetria confiável).

Usar a memória somente para ajuste suave de **cautela e timing de yield**, e não para adicionar aderência arbitrária; coletar evidência antes de automatizar.

---

## 7. FEATURE: CONTROLE DE BOXES (PIT LIFECYCLE)

### 7.1 Descoberta técnica (primeiro passo obrigatório)

A referência **RARE** usa `physics.setAIPitStopRequest(driver.index, trigger)` ao verificar `ac.getPatchVersionCode() >= 2278`; em builds anteriores há um workaround alterando combustível, que **não deve** ser adotado como comportamento padrão. O RARE também utiliza `physics.setAITyres()`, `physics.setCarFuel()` e estados de entrada/permanência no box. **Uma checagem de versão feita pelo RARE não é prova universal de suporte em Track Day nem de resultado confiável em todo circuito.**

Teste mínimo em ambiente separado:

- Verificar se a função existe no contexto real do app e se o SDK instalado descreve sua assinatura.
- Usar carro de IA em pista conhecida, modo offline Track Day e depois Practice/Race para comparar.
- Solicitar parada **sem** diminuir combustível artificialmente; observar se a IA muda a trajetória, entra no `pit_lane.ai`, para no box, conclui serviço e retorna.
- Registrar builds do CSP, track/layout, IA nativa, versão do Content Manager, configurações relevantes, estado inicial/final e tempo.
- Testar carro sem `pit_lane.ai`, pitbox lotado, AI Flood, falta de combustível e reset de sessão.
- Em falha: **fail-closed**, cancelar pedido ou restringir a UI a “pit sugerido”; nunca teleportar ao pit automaticamente como fallback.

### 7.2 FSM de pit por veículo

```text
OUT_ON_TRACK
   ├─ condição de pit → PIT_REQUEST_PENDING
   │                       ├─ pedido aceito/observar heading → APPROACHING_PIT
   │                       ├─ timeout/capability failed → SUGGEST_ONLY
   │                       └─ cancelamento → OUT_ON_TRACK
   ├─ pitlane detectada espontaneamente → ENTERING_PITLANE
   └─ resfriamento sem pit possível → COOLDOWN_ON_TRACK

APPROACHING_PIT → ENTERING_PITLANE → IN_PITLANE
                                     ├─ isInPit, velocidade estável → SERVICE_PENDING
                                     ├─ saída sem parar → OUT_ON_TRACK (+ anotação)
                                     └─ timeout/erro → SAFE_FALLBACK

SERVICE_PENDING → SERVICE_IN_PROGRESS → SERVICE_COMPLETE
                                      → EXITING_PITLANE → OUT_ON_TRACK
```

Separar `pit intent` (intenção), `pit request attempted` (comando enviado), `pit entry observed` (observação), `service performed` (confirmação) e `pit exit observed` (observação). **Nunca** reportar como sucesso apenas porque a API retornou sem erro.

### 7.3 Causas de parada

| Causa | Fonte | Comportamento inicial |
|---|---|---|
| Combustível baixo | autonomia estimada com histórico, evitando divisão por zero | Sugerir pit; requisitar se compatibilidade confirmada |
| Pneu gasto | telemetria por roda; semântica de `tyreWear` validada por veículo | Sugerir pit; serviço opcional |
| Pneu frio | temperatura / tempo de rodagem | **não** forçar pit automaticamente; aquecimento no traçado |
| Fim de stint individual | relógio por carro | cooldown → pit request se disponível |
| Superaquecimento real | campo de temperatura real disponível | alerta + decisão por gravidade |
| Falha mecânica via integração | evento assinado de car script | pit request / abort; sem inventar reparo |
| Incidente danoso | dano/velocidade imobilizada | tratar via recovery/retirement; não “serviço instantâneo” |
| Entrada espontânea da IA | `isInPitlane`, `isInPit` observados | respeitar, não tentar impedir |

### 7.4 Serviços e tempo de manutenção

- **Somente após confirmar parada em pitbox**, oferecer troca de pneus/refuel/serviço quando API/contexto suportarem.
- Preferir lógica nativa do carro/jogo quando existir. Não sobrepor `setCarFuel()` a um abastecimento ativo do AC.
- Se a única opção for um **serviço virtual**, comunicar claramente: tempo simulado e estado UI, não reparo físico garantido.
- Adicionar cooldown do pedido, limite de tentativas, timeout e watchdog anti-loop.
- Validar pressão/temperatura de pneu pós-serviço e componentes do carro apenas se dados forem expostos.
- Evitar reabastecimento arbitrário quando o veículo sai da pista; não "completar tanque" ao teleport como fallback.
- Estimativa de consumo por volta usando médias robustas, excluindo reset, teleport, parada e troca de sessão.

### 7.5 Pit speed, entrada, saída e segurança

- Monitorar velocidade quando `car.isInPitlane` e emitir alertas/UI, com regra configurável por pista.
- **Não prometer aplicar fisicamente um limitador**: o repositório atual documenta limites de `setAITopSpeed()` e modulação de pedais.
- Deixar o próprio jogo conduzir o veículo na pitlane quando o path existe; não usar offsets de pista nessa região.
- A pista pode não fornecer uma pitlane funcional. Estabelecer `pitLaneSupport = unknown/observed/unsupported`.
- Se `isInPitlane=true`, pausar decisões de ultrapassagem e outras intervenções laterais próprias.
- Na saída, retornar a fases de aquecimento da mesma identidade de piloto; validar que pit reentry é possível antes de anunciar sucesso.
- No modo `AI Flood`, usar **monitor-only** para pits até demonstrar persistência de carros e compatibilidade do ciclo.

---

## 8. FEATURE: RECONHECIMENTO, AQUECIMENTO, SESSÃO LIVRE E RESFRIAMENTO

### 8.1 Dois relógios diferentes

- `SessionDetails`: estado **global** (sessão aberta, encerramento, bandeira, tempo total).
- `DrivingPhaseManager`: estado **por piloto** (tempo desde a entrada, voltas percorridas, condições dos pneus, tempo de stint).

Isso permite 20 carros com ritmos e horários de participação diferentes. Não presumir que todas as IAs começam a aquecer quando o evento abre.

### 8.2 FSM de fase do participante

```text
PIT/INACTIVE
      | saída observada
      v
SIGHTING (RECONHECIMENTO) [opcional por configuração]
      | volta/distância mínima, sem perigo
      v
WARM_UP (AQUECIMENTO)
      | critérios de calor OU tempo/volta conservador, com dados indisponíveis
      v
FREE_RUNNING (SESSÃO LIVRE)
      | fim de stint / saúde mecânica / pedido voluntário
      v
COOL_DOWN (RESFRIAMENTO)
      | pit solicitado ou entrada detectada
      v
RETURN_TO_PIT → PIT/INACTIVE
```

Cada estado prevê timeout/retorno seguro em `NO_SUPPORT`, `INCIDENT`, `SESSION_RESET`. A transição não é garantida se a IA original não conseguir ir ao pit.

### 8.3 Comportamento sugerido

**Reconhecimento**

- Primeira volta após início de sessão, com ritmo estável e conservador, sem “formação de corrida” e com maior margem do carro da frente.
- Não exigir seguir um instrutor real/virtual; possível modo `follow-lead` ficaria experimental, porque a API não garante o comportamento.
- O jogador recebe sugestões discretas de reconhecimento, não controle automático do seu acelerador.

**Aquecimento**

- Subir o ritmo gradualmente, influenciado por temperatura/pressão de pneus e telemetria **quando disponível**.
- Sem dados confiáveis de pneus, usar tempo de rodagem/voltas como proxy e exibir "aquecimento estimado".
- Evitar penalizar aderência duas vezes se pneus frios já reduzem grip real.

**Sessão livre**

- Piloto mantém seu perfil, com flutuação lenta de ritmo e reação ao tráfego.
- Diferentes veículos podem ter diferentes durações de stint (configurável).

**Resfriamento**

- Antecipar pit de forma gradual; reduzir ritmo/agressividade em **hints consultivos** e minimizar manobras laterais próprias.
- Acompanhar queda de temperaturas reais; não inventar resfriamento físico quando inexistente.
- Concluir apenas após parada observada ou fim da sessão; caso contrário registrar fase incompleta.

### 8.4 Configuração proposta

```text
Session / Driving Phases
  Enable driving phases: ON
  Enable sighting lap: optional
  Minimum sighting distance: [track-specific]
  Warm-up policy: tyres-if-available / time-or-laps fallback
  Target stint duration: range by experience (not one universal time)
  Cool-down before pit: optional
  Auto-request pit at stint end: only if capability validated
  Track session mode: permanent grid / AI Flood aware
```

Evitar fixar "3 voltas para aquecer" ou temperaturas universais para toda categoria de pneu/carro. Limiares exemplificativos em testes não equivalem a dados físicos reais.


---

## 9. FEATURE: PNEUS, DESGASTE, DANOS E FALHAS MECÂNICAS

### 9.1 Separar três conceitos para não anunciar simulação inexistente

1. **Estado físico observado:** condição que o AC/CSP ou car script já simula e reporta (ex.: consumo real de combustível, temperatura, avaria, `tyreWear`).
2. **Indicador sintético de risco:** pontuação de desgaste/risco produzida pelo SimOpenTrackDay, **sem alterar a física**. Usar expressão "risco estimado", não "falha real".
3. **Falha com efeito físico:** mudança concreta no comportamento/estado físico, viável apenas com função CSP/contexto/permissão e suporte ao carro comprovados.

Iniciar por (1), opcionalmente (2), adiar (3). Um slider "Mechanical Failures" não pode prometer quebrar radiadores em qualquer mod de carro.

### 9.2 Integração inspirada no Mechanical Realism Framework

O [MRF](https://github.com/cvr-admin/gec_feature_script) (MIT) possui modelos de velas, bomba de combustível, pressão do óleo, desgaste de freios, radiadores, pneus, câmbio, elétrica e reparos. O projeto foi originalmente voltado a carros históricos; sua instalação implica acesso a arquivos de `data/` e `extension/` do carro e física estendida. O README apresenta escopo/estado da IA em evolução; **não presumir cobertura automática da IA do SimOpenTrackDay**.

Plano de integração sem violar isolamento:

- Modo `observe` para **qualquer carro** cujos campos normais são legíveis.
- Modo `external-car-script` ativado somente se um provedor conhecido (MRF ou adaptador compatível) expuser estado interpretável e versionado.
- Não tocar no `data.acd` nem injetar script de carro silenciosamente.
- Definir contrato `IExternalMechanicalStateProvider` conceitual: `isSupported(car)`, `readState(car)`, `getServiceCapabilities(car)`, `getConfidence()`; efetuar descoberta/ponte de dados de modo suportado, não inventar comunicação global.
- Respeitar interpretação publicada de canais `CPHYS_SCRIPT_n` **apenas** no carro/versão para o qual tenham esse significado; índices iguais em outros carros podem indicar outra coisa.
- Falhas `nil/unknown` na API não viram valores zero ou alertas falsos.
- Efeitos visuais como fumaça e vapor são opcionais e dependem da integração física/visual; não emitir efeito de motor quebrado apenas porque uma estimativa ultrapassou limiar.

### 9.3 Falhas possíveis por horizonte

| Sistema | Fase de observação (prioridade) | Falha avançada condicionada a integração | Riscos |
|---|---|---|---|
| Combustível | Consumo por volta, autonomia, combustível baixo | Bomba falhando, alimentação irregular/vazamento | Não alterar `setCarFuel` durante sessão sem motivo confirmado |
| Pneus | Temperatura/pressão/wear por roda, se legível | Furo e reparo | Semântica `tyreWear`/temp difere entre fontes; validar |
| Freios | Temperatura/desempenho estimado disponível | Fading/desgaste de pastilhas | Não simular brake failure só mudando AI grip |
| Arrefecimento | Água/óleo/temperatura de motor quando exposto | Radiador danificado, perda de potência por aquecimento | Não inventar degradação física em carros sem script |
| Motor | RPM, limites e dano reportado | Válvula, ignição, turbina, óleo | As regras dependem do carro e física estendida |
| Câmbio | Marchas e eventos se disponíveis | Engates falhos, dano acumulado | `overrideCarControls` não é mecânica de quebra genérica |
| Suspensão | Danos reportados por roda | Suspensão gravemente danificada | Não teleportar sem necessidade |
| Elétrica | Apenas se o carro expuser dados | Alternador/bateria/ignição | Não aplicar genericamente em carros modernos |

### 9.4 Modelo de risco — ilustrativo, não parâmetros reais

```text
risk = baseRisk(vehicleClass, reliabilityProfile)
       × stressFactor(temperature, RPM, damage, drivingDuration)
       × wearFactor(tyres/brakes/components)
       × randomSessionFactor(seed)

P(event in dt) = 1 - exp(-hazardPerSecond × dt)
```

Esse modelo é uma **forma de converter taxa de risco em probabilidade por tempo**, não uma calibração de falhas automotivas. Jamais inventar taxas como se fossem de veículos reais. Calibrar para raridade/escala escolhida pelo usuário; manter defaults conservadores e opcionais. Repetir teste com `dt` variável para não tornar falhas dependentes de FPS.

**Escada de consequências**: observação → aviso → recomendação de pit → `pit intent` → serviço confirmado → retorno se possível. Evitar “quebrou = DNF instantâneo” sem contexto físico e validação.

### 9.5 Compatibilidade com carros diferentes

- Não presumir que todos tenham pneus slick, aquecimento semelhante ou mesma temperatura ideal.
- Distinguir carro de rua, GT, fórmula, histórico e desconhecido com confiança configurável; se não houver metadados, usar fallback genérico conservador.
- Carros híbridos/eletrificados não devem receber modelo arbitrário de bomba de combustível ou radiador histórico.
- Comparar **evolução** do sinal de cada carro antes de confiar em unidade/faixa; por exemplo, `tyreWear` pode requerer normalização invertida ou outra semântica.
- Interoperabilidade com MRF jamais assumida em multiplayer nem em todo carro de IA.

---

## 10. FEATURE: CLIMA DINÂMICO E ADAPTAÇÃO AMBIENTAL

### 10.1 Dois projetos diferentes

**A. Adaptação ao clima (prioridade alta, Lua App):** ler chuva, estado da pista, temperatura e condições quando expostas pelo `ac.getSim()`/SDK; ajustar suavemente cautela e decisão da IA. Funciona como observador; não muda a meteorologia.

**B. Gerador de clima (prioridade baixa, addon independente):** um **Weather FX Controller** próprio ou integração oficialmente documentada com o controlador existente. O controlador base do CSP usa `ac.ConditionsSet()` e `ac.setConditionsSet2()`, mas isso **não** prova que essas funções possam ser chamadas da Lua App principal.

Fontes: [Weather FX Base](https://github.com/ac-custom-shaders-patch/acc-weatherfx-base), [controller base](https://github.com/ac-custom-shaders-patch/acc-extension-config/blob/master/weather-controllers/base/controller.lua), [SDK Weather Controller](https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/ac_wfx_controller.lua).

### 10.2 Arquitetura de adaptador

```text
Conditions provider (CSP/Pure/Sol/Unknown)
    |
    v
EnvironmentManager.readConditions()
    | -- rain intensity (optional)
    | -- reported track wetness/water (optional)
    | -- ambient/track temperature (optional)
    | -- weather controller name (optional)
    | -- signal quality / timestamp
    v
EnvironmentProfile = Dry / Damp / Wet / HeavyWet / Unknown
    |
    v
smooth caution / pace / TTC safety margin
```

**Atenção à física:** RainFX visual nem sempre representa aderência física; não multiplicar automaticamente perda de grip físico por outra perda idêntica. Preferir ajuste de decisão/cautela da IA à adulteração de aderência. Em condições `unknown`, desabilitar adaptações específicas em vez de assumir chuva ou seco.

### 10.3 Testes de integração

- Weather FX desligado; base controller; Pure Planner (quando instalado pelo usuário); chuva visual com pista seca; pista molhada com chuva cessando; mudança rápida de tempo.
- Confirmar no log **campos realmente lidos**, unidades e escalas antes de aplicar limites.
- Não mudar/reescrever arquivos de Pure, Sol ou CSP Weather FX automaticamente.
- Usar histerese para alternância `dry ↔ damp ↔ wet`, filtrando tremulações de sensores; restaurar o modificador de cautela quando clima estabiliza.
- Testar custo de polling (não recalcular condições para cada carro a cada frame).

### 10.4 Cenários de ambiente

- Manhã fria e seca: warm-up mais longo **se suportado por telemetria**.
- Tempo nublado aquecendo: gradual mudança de perfil.
- Chuva começando: cautela e distâncias aumentadas.
- Chuva cessando / pista secando: parâmetros retornam gradualmente ao baseline.
- Falha do provedor: voltar a comportamento neutro e registrar a limitação.

---

## 11. FEATURE: INCIDENTES, RECUPERAÇÃO E SINALIZAÇÃO

### 11.1 Observação de incidentes separada da culpa

Inspirar-se no [Race Logger](https://github.com/Zhaoyi-Fan/assetto-corsa-race-logger): rastrear perda de controle, parada anormal, colisão observada e região de pista, com confiança de evidência. **Não** inferir culpado automaticamente apenas por `collidedWith` ou por qual carro foi amostrado primeiro.

Dados mínimos de evento:

```text
sessionId, timestamp, eventType, carIndex, otherCarIndex?,
trackID, splinePosition, position?, speedBefore?, speedAfter?,
confidence, observedInputs?, source, lifecycleState
```

- Registrar contatos, não produzir “acidente” de um único tick por toque mínimo.
- Agrupar contatos próximos em uma única ocorrência usando janela temporal e posições.
- Diferenciar baixa velocidade de pit/pausa/engarrafamento/espera legítima de carro imobilizado após acidente.
- Detecção de direção contrária/rodada: combinar orientação com tangente da pista, histerese e tempo mínimo; referência [Auto Yellow Hazards](https://github.com/yukkine0704/assetto-corsa-auto-yellow-hazards).
- Eventos ligados a `CarStateMachine` são internos: se a IA nativa provocar algo inesperado, registrar como observado, não como estado causado pelo mod.

### 11.2 Estados seguros para recuperação

```text
INCIDENT_DETECTED
   -> MONITORING (pode retomar sozinho?)
   -> WAIT_FOR_SAFE_GAP (se reposicionamento foi explicitamente permitido)
   -> RECOVERY_ATTEMPT (uma tentativa, se capability validada)
   -> VERIFY_MOTION_AND_HEADING
   -> RECOVERED / STOPPED_SAFE / DISABLED
```

- Não teleportar o carro para a frente do jogador ou IA que se aproxima.
- Não voltar o carro em sentido contrário por causa de sinal incorreto da tangente da spline.
- Não habilitar “colisões desativadas” permanentemente após um incidente.
- Não reiniciar combustível, pneus ou temperatura como efeito colateral de repositionamento; se a API os reseta, preservar somente dados confiáveis **se autorizado e tecnicamente possível**.
- Aplicar limite de tentativas e cooldown; desistir com segurança.
- O módulo de recuperação do Verve é excelente referência conceitual, porém sua licença restringe cópia/reutilização de código.

### 11.3 Bandeiras e sinais

- Observar o que o jogo sinaliza, sem supor que `overrideRacingFlag` cria uma direção de prova completa.
- Manter zona de cautela associada ao incidente e encerrá-la quando resolvido, com debounce.
- Evitar sobrescrever um sinal nativo mais importante com “nenhuma bandeira” em todo frame; definir governança de ownership/priority.
- **Hazard lights:** respeitar manual override do jogador, eventos de incidente e clear delay; quando o carro não possui setas/hazard, degradar silenciosamente.
- Sugerir **alerta informativo de pit lane / obstrução** antes de inventar bandeiras oficiais que o jogo não suporta.
- Incidentes ficam visíveis no debrief, mas sem penalidades automáticas em versões iniciais.

---

## 12. FEATURE: TELEMETRIA, ENGENHEIRO E LIVRO DE BORDO

### 12.1 Novo diferencial: Track Day Logbook

Inspirado em AC ConditionReports, Race Logger e AC Tracer, priorizar **feedback leve e local**:

- Histórico de tempo em pista vs boxes por veículo;
- Número de stints, volta de saída, volta rápida, volta de retorno;
- Consumo médio por stint e confiança da estimativa;
- Evolução de pneus, temperatura e eventuais danos reportados;
- Número de solicitações de pit, entradas efetivas, serviços concluídos e falhas;
- Incidentes observados, tipos, zonas da pista e dados objetivos de velocidade/posição;
- Duração de impedimentos no tráfego e manobras iniciadas/concluídas pela FSM;
- Curva de consistência do piloto e comparação entre perfis de IA (sem ranquear como campeonato).

**Não inventar resultados**: separação rigorosa entre evento observado e intenção do app. Exibir `estimated`/`unknown` e não mascarar amostras faltantes.

### 12.2 Esquema de eventos sugerido (versão 1)

```json
{
  "schemaVersion": 1,
  "sessionId": "local-synthetic-id",
  "game": "Assetto Corsa",
  "appVersion": "0.x",
  "trackFullId": "track_layout",
  "sessionType": "Practice",
  "cspVersion": "measured-at-runtime",
  "events": [
    {
      "t": 132.5,
      "carIndex": 7,
      "carGeneration": 2,
      "kind": "PIT_REQUEST",
      "cause": "LOW_FUEL_ESTIMATED",
      "confidence": 0.8,
      "commandIssued": true,
      "observedOutcome": "UNKNOWN"
    }
  ]
}
```

O JSON é contrato conceitual, não prova de API de gravação na Lua App. Ao implementar, documentar o mecanismo efetivo de persistência permitido pelo CSP (`ac.storage`, API de arquivos, exportação manual, etc.). Não escrever JSON completo com todos os carros **a cada frame**.

### 12.3 Amostragem e custo

- Coleta rápida apenas de sinais necessários à FSM; evitar múltiplas varreduras `ac.iterateCars()` por frame.
- Atualizações de condição/temperatura em frequência menor que o loop principal quando suficiente.
- Risco/sector learning sob amostragem por evento ou intervalo definido.
- Histórico circular por carro ou por sessão; tamanho máximo configurável.
- Debrief agregado após final da sessão; arquivos/exports opcionais por comando do usuário.
- Retenção local opt-in, sobretudo se gravar nome de motorista, identificação do carro ou informações do usuário.
- Nunca incluir uploads automáticos, chamadas de APIs de IA externas ou telemetria cloud como requisito básico.

### 12.4 UI: engenheiro não intrusivo

Adicionar a uma aba existente ou, se justificar, aba `Session` sem redesenhar a janela toda:

```text
Session
  Driving phase: WARM UP
  Elapsed stint: 08:21
  Fuel: observed 21.4 L | estimate 7.1 laps remaining
  Tyres: temperature observed / unavailable
  Conditions: damp (reported) | confidence medium
  Pit: no request | capability: unverified
  Safety: yellow-zone notification (if active)
```

- Mensagens curtas, prioridade por gravidade, cooldown e limite de frequência.
- Oferecer cabeçalho para origem: `observed`, `estimated`, `unsupported`.
- i18n em inglês fonte, pt-BR/es; mensagens internas e enums não devem ser traduzidos para persistência.
- Sem áudio por padrão; módulo eventual de voz precisa de controles de volume/antispam e ser opcional.

---

## 13. CONFLITOS COM OUTROS MODS E MODO COMPATÍVEL

### 13.1 Problema

Verve e Full Send AI relatam conflitos com outros mods que ajustam os mesmos parâmetros da IA. Se SimOpenTrackDay e outro mod escrevem `setExtraAIGrip`, `setAILevel`, `setAICaution`, `setAITopSpeed` ou offset constantemente, o resultado depende da ordem de execução e pode oscilar.

### 13.2 Solução de produto

**Controle por domínio**, cada um com três estados: `Disabled`, `MonitorOnly`, `Control`.

| Domínio | Default futuro sugerido | Motivo |
|---|---|---|
| Tráfego lateral/yield | Control (como atual, após validação) | Função central do mod |
| Personalidade de pace | MonitorOnly até testes | Pode colidir com Verve/Full Send/ApexFlow |
| Grip extra | Disabled | Alto risco de duplo ajuste |
| Pit request | Disabled até capability comprovada | A IA nativa pode ignorar |
| Clima | MonitorOnly | Weather controller pertence a outro contexto |
| Mecânica virtual | MonitorOnly | Não interferir no carro |
| Recovery/teleport | Disabled | Alto risco de acidentes e perda de estado |
| Flags/hazards | MonitorOnly ou controle seletivo | Sinalização nativa/manual tem prioridade |

Nunca prometer detecção universal de outro mod: observar divergências em leituras disponíveis e oferecer orientação no UI (“possível controlador externo”), sem fingir capacidade de identificar processos/mods que não expõem tal informação.

### 13.3 Testes de coexistência

- SimOpenTrackDay isolado; +Verve; +ApexFlow; +Full Send AI; +RARE, **somente se ambiente suportar**.
- Nunca ativar dois módulos de grip com controle simultâneo por padrão.
- Caso de conflito, a solução é permitir desligar controle de um domínio, não competir agressivamente por prioridade.
- Ao desabilitar o app, retirar seus writes e confirmar que não ficou limitador/offset ativo por responsabilidade própria.

---


---

## 14. ROADMAP EXECUTÁVEL E ORDEM DE ENTREGA

**Sem datas artificiais.** Versões abaixo são marcos propostos, não promessas de release. Priorizar estabilidade e testes sobre features visuais. Não desenvolver todos os módulos em paralelo no mesmo contexto.

### M0 — Auditoria de arquitetura/API, sem alteração de runtime

**Objetivo:** produzir mapa verificado do que existe e do que o CSP realmente expõe ao projeto.

**Tarefas:**

- [ ] Ler a árvore real e os arquivos relevantes, comparar `README`/`ARCHITECTURE`/`STATE_MACHINE` ao código.
- [ ] Identificar APIs `physics.*`/`ac.*` usadas e quaisquer APIs desejadas apenas observadas em mods externos.
- [ ] Confirmar contexto suportado para cada API no SDK **instalado** e nos arquivos distribuídos no projeto, incluindo variação por versão do CSP.
- [ ] Revisar conflitos entre comandos, registros de estado, reset, acidente, indicação de curva, pits e manutenção de storage.
- [ ] Identificar campos declarados em `StorageManager` que não têm consumers efetivos (por exemplo, `pointBySpeedDeltaKmh`, comportamento de `BehaviorPolish`).
- [ ] Entregar `docs/plans/CSP_CAPABILITY_AUDIT.md` e lista de provas no jogo necessárias, sem afirmar que algo foi validado no jogo se apenas lido em código.

**Aceite:** matriz `API × contexto × build × source × evidência × risco × fallback`, com pelo menos os recursos de pit, pneus, velocidade, feedback da AI e condições do sim.

### M1 / v0.2 — Controle central e ciclo de vida

**Dependência:** M0.

- [ ] Consolidar uso de AI knobs por um coordenador pequeno e testável, inicialmente sem alterar os valores aplicados aos carros na configuração padrão.
- [ ] Implementar `Disabled/MonitorOnly/Control` por domínio, progressivamente.
- [ ] Garantir limpeza em app disabled, session reset, pitlane, mudança de carIndex e troca de IA.
- [ ] Instrumentar conflitos/diferenças entre intenções e estado observado, quando a API permitir.
- [ ] Proteger jogador de ajustes destinados à IA.
- [ ] Adicionar testes de prioridade, ordem e reset sem tocar na instalação real.

**Aceite:** modo padrão mantém comportamento anterior (comparação), sem writes de grip extra novos; ao desligar o app, nenhuma limitação própria persiste indevidamente; regressões são detectáveis.

### M2 / v0.3 — Fases de condução por veículo

**Dependência:** M1; entrega de alto valor e baixo acoplamento físico.

- [ ] `DrivingPhaseManager` com `SIGHTING`, `WARM_UP`, `FREE_RUNNING`, `COOL_DOWN`, `PIT/INACTIVE`, `UNKNOWN`.
- [ ] Per-car timers e contador de voltas, com eventos de entrada/saída.
- [ ] Read-only por padrão; controle de cautela suave apenas após teste.
- [ ] UI de fase com indicação explícita do estado e da confiança.
- [ ] Testar reinício, carro em pit desde o começo e pit espontâneo.

**Aceite:** transições corretas e independentes por piloto; não há reset indevido de toda a grade; jogador só recebe informações.

### M3 / v0.4 — Personalidades e integração de BehaviorPolish

**Dependência:** M1/M2.

- [ ] Perfis individuais com seed e opções de mistura.
- [ ] Integrar `BehaviorPolish` em pontos reais da FSM, nunca adicionar randômico sem limite por frame.
- [ ] Personalizar reação/cautela/consistência **se observavelmente suportado**.
- [ ] Desativar mecanismos competitivos de defesa de posição em `TrackDay`.
- [ ] Adicionar testes de perfil e estabilidade (identidades, geração de sessão, seed, cleanup).

**Aceite:** diferenças replicáveis e suaves; sem aumento substancial de acidentes ou perda de estabilidade em grid misto.

### M4 / v0.5 — Tráfego inteligente e monitor de proximidade

**Dependência:** M1/M3.

- [ ] TTC/histórico de fechamento e segurança lateral usando caches existentes.
- [ ] Diferenciar intenção de manobra e manobra nativa observada.
- [ ] Adicionar abort/cooldown e rampa de offset, com testes de curva, hairpin e pit entry.
- [ ] Telemetria de tentativas, recusas e manobras concluídas.

**Aceite:** menos movimentos laterais bruscos e menos contatos evitáveis nas mesmas sessões de referência; ausência de nova formação sistêmica de filas.

### M5 / v0.6 — Pit telemetry e capability probe

**Dependência:** M0/M1/M2.

- [ ] Criar `PitManager` **inicialmente read-only**: pitlane, pitbox, duração, ingress/egress.
- [ ] Separar pedido, comando e resultado observado.
- [ ] Implementar probe desativado por padrão para `setAIPitStopRequest`, se a função existir.
- [ ] Adicionar estimativa de autonomia por veículo e recomendação de pit.
- [ ] Executar prova manual com modo Track Day e `Practice/Race` para comparação.

**Aceite:** ciclos observados e logs confiáveis, sem alterar combustível e sem anunciar serviço apenas por API call.

### M6 / v0.7 — Pit request e manutenção básica (opt-in)

**Dependência:** sucesso do probe M5 em pelo menos um cenário de suporte.

- [ ] FSM de pit e timeouts, request/cancelamento, cooldown.
- [ ] Interagir com `setAITyres()`/`setCarFuel()` **somente** depois de validação do modo e confirmação de box.
- [ ] Detectar serviço concluído e retorno com revisão de fuel/tyres quando possível.
- [ ] Fallback para recomendação em pistas/carros incompatíveis.
- [ ] Nunca adotar truque de esvaziar tanque como padrão.

**Aceite:** processo funcional e repetível em track/layout selecionado; falha volta a estado seguro, sem AI presa em loop de pit.

### M7 / v0.8 — Condições, pneus e prognóstico mecânico

**Dependência:** M1/M2/M3.

- [ ] `CarConditionMonitor` para combustível, temperatura, tyres, damage com quality flags.
- [ ] `EnvironmentManager` observador dos sinais reais do CSP, sem controlador próprio.
- [ ] Adaptar cautela e fase de aquecimento com histerese e sem double-counting de grip.
- [ ] `MechanicalConditionManager` read-only/virtual com mensagens honestas.
- [ ] Modo experimental de integração MRF-like, sem modificar carros por padrão.

**Aceite:** comportamento neutro se faltarem sensores; chuva muda cautela apenas se o dado for confiável; nenhum dano físico inventado.

### M8 / v0.9 — Incidentes, recuperação segura e observabilidade

**Dependência:** M1 e preferencialmente M4/M5.

- [ ] Melhorar deduplicação de contatos e flags associadas a incidentes.
- [ ] `IncidentObserver` e dados estruturados com confiança.
- [ ] Recuperação natural e watchdog sem teleporte; versão opt-in de reentrada, caso API validada.
- [ ] Livro de bordo com eventos e métricas de sessão.
- [ ] Comparações automáticas entre versão antiga/nova a partir de logs locais.

**Aceite:** menos obstruções persistentes, sem carros reaparecendo indevidamente na frente do tráfego; métricas reproduzíveis.

### M9 / v1.0 — Produto consolidado

**Dependência:** milestones implementados e validados isoladamente.

- [ ] Presets `Realistic Track Day`, `Casual Track Day`, `Mixed Cars`, `Experimental` (não mudar default antigo sem migração consciente).
- [ ] Compatibilidade explicitada na UI: CSP build/track/pit/weather/mechanics, com statuses `supported`, `observed`, `experimental`, `unsupported`.
- [ ] Guia de instalação/rollback, changelog, CI de sintaxe/tests e pacote correto.
- [ ] Benchmark de 20–30 carros com custos aceitáveis definidos contra baseline.
- [ ] Documentar incompatibilidade/convivência com Verve, Full Send, ApexFlow e RARE sem afirmações universais.

**Aceite:** pacote testado em CSP real, funcionalidades ativáveis de maneira independente, sem regressão de yield/overtake nem bugs de instalação conhecidos.

### Backlog futuro (não comprometer v1.0)

- Controlador meteorológico separado compatível com as interfaces oficiais do Weather FX.
- Adaptação física profunda por `CarScript` para carros compatíveis com MRF.
- Serviço de box com tempos e recursos por equipe/carro com integração física real.
- Identificação assistida de zonas seguras de ultrapassagem por geometria, **somente consultiva**.
- Instrutor virtual com análise de telemetria, offline/local (sem exigir rede ou modelo externo).
- Replay local e visualizador de incidentes sem modificar runtime do jogo.
- Simulação de equipe de pista, marshalling avançado e procedimentos reais apenas se houver API viável.
- Integração oficial com outros mods por troca de dados **somente se os dois lados expuserem interface de interoperabilidade**.

---

## 15. MATRIZ DE TESTES REPRODUZÍVEIS

### 15.1 Checklist local que já existe no projeto

Usar instruções de [`docs/TESTING.md`](https://github.com/gabrielcorreabsb/SimOpenTrackDay/blob/main/docs/TESTING.md) no checkout atualizado. Comandos ilustrativos do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
luajit tools/test_module_path.lua
luajit tools/test_main_window.lua
luajit tools/test_settings_model.lua
luajit tools/test_localization.lua
luajit tools/test_version.lua
luajit tools/test_ui_manager.lua
luajit tools/test_native_controls.lua
```

`test_ui_smoke.lua` já foi documentado com bloqueio de fixture em um estado do repositório; verificar se continua assim antes de classificá-lo. Mocks são evidência de **contrato local**, nunca de renderização e comportamento real no CSP.

### 15.2 Testes unitários a criar por etapa

| Caso | Entrada simulada | Resultado esperado |
|---|---|---|
| Sessão reiniciada | `sessionGeneration` muda com carros antigos | Perfis temporários e pedidos pendentes invalidados |
| AI Flood recicla índice | Mesmo `carIndex`, nova geração/identidade | Sem herdar serviço/pit e danos do veículo anterior |
| Sem função de pit | `physics.setAIPitStopRequest=nil` | Feature `unsupported`, recomendação apenas, sem crash |
| Pit request sem movimento | API retorna, mas pit nunca é observado | Timeout, status `not_confirmed`, sem serviço inventado |
| Pit sem `pit_lane.ai` | Pit entry impossível | Sem teleporte e sem tentativas infinitas |
| Falso `isInPitlane` | Veículo passa pitlane mas não para | Não considerar serviço concluído |
| Combustível sobe por pit nativo | Sinal de `fuel` aumenta | Registrar abastecimento observado, não escrever outro |
| Wear inválido | Campo nil/NaN, unidade estranha | `unknown`, sem recomendar troca com falsa precisão |
| TTC head-to-head | Carros em lados opostos do hairpin | Não tratados como vizinhos na mesma linha |
| Normalização circular | Posições 0.995 e 0.005 na mesma volta | Gap correto próximo à linha de largada |
| Carro parado em pit | `speed=0`, `isInPit=true` | Não abrir incidente de pista |
| Hazard manual | Jogador modifica as luzes | Não sobrescrever intenção manual |
| Chuva alternando rapidamente | Wetness oscila em torno do limiar | Histerese impede writes por tick |
| Múltiplas intenções | Safety / Traffic / Personality pedem cautela | Writer aplica prioridade declarada |
| Módulo desabilitado | App OFF durante overtake/pit | Estado interno limpo e comandos próprios restaurados quando seguro |
| dt irregular | Rodar mesma sequência a 30/60/120 FPS simulados | Eventos/probabilidades/imersão temporal comparáveis |
| Persistência antiga | Settings existentes sem novas chaves | Defaults/migração sem perda de configuração |
| Idiomas | en/pt-BR/es | Labels traduzidos, IDs internos invariantes |
| Inputs do jogo indisponíveis | Campos nil e callbacks parciais | UI mantém funcionamento; aviso claro sem crash |

### 15.3 Cenários manuais em jogo

| ID | Cenário | Objetivo principal |
|---|---|---|
| S01 | Nordschleife, grid 20 carros com velocidades distintas | Tráfego orgânico e filas |
| S02 | Spa, carros de desempenho semelhante | Yield/offset e segurança em curvas |
| S03 | Um carro muito rápido atrás de um lento | TTC e manobra assistida, sem garantia de point-by |
| S04 | Pit lane funcional, 1 IA solicitada ao pit | Request → chegada → parada → saída |
| S05 | Mesmo carro em modo Track Day vs Practice/Race | Detectar dependências de modo do CSP |
| S06 | Layout sem pit lane de IA funcional | Degradação limpa |
| S07 | Sessão com AI Flood ou reciclagem | Invalidação correta de estado/pit |
| S08 | Início com pneus frios e telemetria disponível | Aquecimento por carro |
| S09 | Mudança gradual de chuva no Pure (se instalado) | Adaptar sem conflitar com o controlador |
| S10 | Incidente na entrada de curva | Cautela, detecção, não bloquear tudo |
| S11 | Carro parado legítimo no box | Não ser classificado como acidente |
| S12 | Fim de stint individual | Cooldown e eventual pit seguro |
| S13 | Habilitar/desabilitar recursos 10 vezes | Sem parâmetro preso/resíduo de writer |
| S14 | Modo MonitorOnly com Verve/ApexFlow | Não disputar knobs da IA |
| S15 | 30 IAs, gravação de sessão longa | Tempo de frame, GC, vazamentos de estado |

**Registrar cada sessão com:** versão exata do CSP, commit SimOpenTrackDay, GPU/CPU apenas como metadado de teste, pista/layout, condições, carros/AI count, outras extensões ativas, modo, seed quando possível, vídeo/logs, resultados e falhas. Não afirmar que uma pista ou carro passou sem executar.

### 15.4 Métricas sugeridas

- `contacts_per_100_car_km` ou `contacts_per_car_hour` (melhor que contato bruto, pois sessões têm duração diferente).
- `risky_yield_attempts_per_100_maneuvers` com definição objetiva e thresholds calibrados.
- `successful_yield_maneuvers` confirmados por mudança observada de ordem e espaço (não só state change).
- `following_queue_duration_s` para carros lentos bloqueando tráfego.
- `unrecoverable_stops_per_session` e `time_to_recover_s`.
- `pit_requests`, `pit_entries`, `pit_stops`, `pit_exits`, `pit_fallbacks`, `pit_timeouts` **separados**.
- `lap_time_cv` / desvio padrão por condutor, excluindo outlap/inlap/incident laps.
- `ai_writer_conflicts`, `unknown_sensor_fraction`, `invalid_states`.
- Overhead: custo médio e percentis da rotina por frame, picos de alocação/GC, tempo total de sessão.

**Definir baseline antes de prometer metas numéricas.** Compare A/B com mesma pista, carros e condições, e preferencialmente mesma seed; faça múltiplas sessões para evitar conclusões por sorte.

### 15.5 Orçamento de performance e segurança

- `ac.iterateCars()` idealmente **uma vez por frame** no core; compartilhar snapshot ao invés de rescan em cada módulo.
- No hot path, preferir `carIndex`/arrays reutilizáveis, tabelas prealocadas e cache de spline/posição; evitar string.format/log/recriação de vec3 todo frame.
- Se precisar indexar setor de pista, precomputar na inicialização/layout change; não calcular curvatura completa a cada tick.
- Não usar `pcall()` per-car/per-frame indiscriminadamente como substituto de uma camada de capacidade validada.
- Amostrar sensores de baixa volatilidade com frequência menor; histograma de eventos em vez de armazenar tudo em memória.
- Caps de logs e ring buffers; cooldown de incidentes; timeouts para processos que não chegam a terminal state.
- Sem alterações no filesystem do jogo durante testes headless; instalar só manualmente em cópia de teste após autorização.

---

## 16. REGISTRO DE CAPABILITIES (EXEMPLO DE ESPECIFICAÇÃO)

O OpenCode deve produzir uma matriz real antes de escrever código dependente dela. Este formato é exemplo de contrato para documentação e testes, **não** afirmação de suporte:

```yaml
cspCapabilities:
  aiPitStopRequest:
    symbol: physics.setAIPitStopRequest
    context: lua-app
    evidence: RARE-src/controllers/ai.lua (exemplo externo)
    localSDKVerified: false
    trackDayRuntimeVerified: false
    fallback: suggestion-only
  aiTyreChange:
    symbol: physics.setAITyres
    context: lua-app
    evidence: RARE + ApexFlow (exemplos externos)
    localSDKVerified: false
    runtimeVerified: false
    fallback: native-service-only
  weatherController:
    symbol: ac.setConditionsSet2
    context: weather-controller
    evidence: CSP base controller
    luaAppSupported: unverified/do-not-assume
    fallback: read-only-environment
  aiTopSpeed:
    symbol: physics.setAITopSpeed
    context: lua-app
    evidence: SimOpenTrackDay already calls it
    effectInTrackDay: uncertain; documented issues
    fallback: advisory-pace-only
  racingFlag:
    symbol: physics.overrideRacingFlag
    context: lua-app
    evidence: SimOpenTrackDay already calls it
    ownershipRisk: high
    fallback: local-notification
```

Quando testado, registrar `testId`, `cspVersionCode`, `resultObserved`, `log`, `scenarios`, `fallback` e `checkedAt`. Substituir `unknown` por `supported` só mediante runtime explícito.

---

## 17. ORDEM DE ISSUES / PRs INDEPENDENTES

Dividir milestones em tickets de risco pequeno. Sugerir o seguinte backlog inicial:

| Ticket | Entrega | Arquivos autorizáveis por ticket (propostos) |
|---|---|---|
| `SOTD-001` | Auditoria SDK/contextos/capabilities | Apenas `docs/plans/` |
| `SOTD-002` | Plano de prioridades dos AI knobs + testes | `CarOperations.lua` + novo coordenador + testes, após aprovação |
| `SOTD-003` | Resolver reset de estados por geração/sessão | `CarManager.lua`, `SessionDetails.lua`, testes |
| `SOTD-004` | Adicionar FSM de fases somente leitura | Novo `DrivingPhaseManager.lua`, `SessionDetails.lua`, testes |
| `SOTD-005` | Visualizar fase na UI (i18n) | `SettingsWindow.lua`/`MainWindow.lua` e catálogos, testes |
| `SOTD-006` | Perfis individuais + seed determinística | `StorageManager.lua`, novo `DriverPersonalityManager.lua`, testes |
| `SOTD-007` | Integrar `BehaviorPolish` às decisões existentes | FSM e helper, testes |
| `SOTD-008` | Proximidade/TTC e segurança lateral | `CarManager.lua`, `TrafficAwarenessManager.lua`, testes |
| `SOTD-009` | Pit observer sem writes | `PitManager.lua`, `SessionDetails.lua`, testes |
| `SOTD-010` | Prova de `setAIPitStopRequest` em cópia de teste | Capability doc + probe isolado, sem instalar no jogo sem autorização |
| `SOTD-011` | Pit request opt-in, condicionado a probe aprovado | `PitManager.lua`, coordenador, testes |
| `SOTD-012` | Condições: fuel/pneus/danos reportados | `CarConditionMonitor.lua`, testes |
| `SOTD-013` | Adaptador de clima read-only | `EnvironmentManager.lua`, testes |
| `SOTD-014` | Logging estruturado mínimo, sem UI web | `SessionEventLog.lua`, testes |
| `SOTD-015` | Incidentes com debounce e confiança | `IncidentObserver.lua`, `AccidentManager.lua`, testes |
| `SOTD-016` | Prova recuperação da IA / fallback | Plano + testes focados, código experimental opt-in |
| `SOTD-017` | Integração MRF-style como estudo isolado | Documento de bridge apenas, antes de código |
| `SOTD-018` | Benchmarks e matriz de coexistência | `tools/` + documentação (sem alterar mod de terceiros) |

Cada ticket deve ter: **objetivo, escopo de arquivos, requisitos, não-objetivos, testes unitários, prova in-game requerida e plano de rollback**. Se o SDK não confirmar a API, transformar em estudo ou observação em vez de inventar workaround.

---

## 18. REGRAS DE IMPLEMENTAÇÃO E LICENÇAS

### 18.1 Não copiar por inércia

- Preservar crédito a Andreas Grech e licença MIT do projeto de origem. Verificar `LICENSE` e histórico reais antes de redistribuir.
- **Verve:** licença restritiva específica; usar somente inspiração conceitual, salvo permissão expressa para outra finalidade.
- **RARE:** licença AGPL-3.0; **Full Send AI:** GPL-3.0. Adaptação direta/cópia de código pode criar obrigações incompatíveis com uma estratégia de manter o SimOpenTrackDay MIT; obter avaliação/decisão explícita primeiro.
- **ApexFlow, MRF, AC ConditionReports, Race Logger:** licenças MIT verificadas; ainda assim preservar copyright, notices e rastrear proveniência de cada trecho incorporado. Preferir implementação própria baseada no design.
- **AC Tracer:** não confirmar licença no levantamento; código público não é automaticamente reutilizável.
- **CSP Weather FX Base:** domínio público indicado no README; verificar escopo do conteúdo copiado e compatibilidade de contexto.
- Consultar licenças atuais no commit específico; a tabela de 21/10/2026 pode envelhecer.

### 18.2 Compatibilidade, segurança e limites

- Não modificar `manifest.ini` nem bootstrap sem autorização separada e teste de compatibilidade.
- Não alterar paths globais, `LUA_PATH`, `package.loaded`, itens de CSP vendor ou outras instalações.
- Não habilitar `AI Flood` custom ou módulos experimentais só para demonstrar features.
- Não adicionar update downloader silencioso; updates manuais e reversíveis.
- Não fazer write em controles do jogador para forçar “regras de pista”.
- Não usar anticheat/telemetria de terceiros. Trabalho restrito a sessão local offline.
- Configuração preexistente deve permanecer; versões de esquema migráveis, preferencialmente sem limpeza destrutiva.
- Remover instrumentação provisória e flags de desenvolvimento antes de release, preservando diagnósticos necessários contratados por `AGENTS.md`.

---

## 19. DEFINIÇÃO DE PRONTO (DoD) PARA CADA FASE

Uma tarefa só fica "concluída" quando:

1. **Feature scope** e comportamento esperado estão documentados, com suporte/experimental/unknown claramente indicado.
2. O código Lua 5.1/LuaJIT 2.1 não usa APIs inexistentes, bitwise nativo ou estruturas incompatíveis com o padrão do projeto.
3. Testes localizados foram criados e executados (resultado real; não "testado" por inferência).
4. Não há regressão conhecida em yield/overtake ou nos controles/estados já usados.
5. Storage, UI e i18n permanecem consistentes; novas features default-off quando necessário.
6. Há tratamento de missing API, campos nil, replay/pausa, reset de sessão, carro trocado e app disabled.
7. O desempenho foi medido contra o baseline quando o recurso toca hot path.
8. Experimentos que dependem de CSP foram identificados como **pendentes de validação manual no jogo** até ela realmente ocorrer.
9. O diff está restrito aos arquivos aprovados; nenhuma atualização incidental do SDK vendor/submódulo.
10. Existem instruções de backup, instalação em cópia de teste e rollback não destrutivo.

### Formato recomendado de handoff do OpenCode

```text
Objetivo entregue:
Arquivos inspecionados e alterados:
APIs confirmadas no SDK (com contexto):
APIs confirmadas no runtime (com versão, modo e teste):
Decisões e tradeoffs:
Resultados de testes executados:
Testes não executados/bloqueados:
Risco de licença/cópia:
Limitações conhecidas:
Próximo ticket sugerido:
```

---

## 20. DECISÕES RECOMENDADAS (RESUMO EXECUTIVO PARA IMPLEMENTAÇÃO)

**Primeiro:** auditar APIs e centralizar writers/estado. O risco maior é gerar conflitos e deixar parâmetros da IA presos depois de desligar o mod.

**Segundo:** entregar fases da condução (reconhecimento, aquecimento, sessão livre e resfriamento) e personalidades em modo predominantemente consultivo. Isso oferece percepção de track day real sem depender de controle total da IA.

**Terceiro:** testar de maneira isolada o pedido de pit encontrado no RARE (`physics.setAIPitStopRequest`). Se o modo Track Day não obedecer, manter monitoramento e sugestão de manutenção; não alterar combustível para forçar pit no padrão.

**Quarto:** enriquecer tráfego, clima e condições mecânicas usando sensores confiáveis e histerese, antes de tentar simulação de danos físicos universal.

**Quinto:** adicionar livro de bordo e testes A/B inspirados em Race Logger para medir se a IA está realmente mais humana, segura e variada.

**Posicionamento final:** SimOpenTrackDay deve ser um **simulador de convivência, uso e ciclos de pista em track days offline**, e não um substituto universal da IA, do Weather FX, dos scripts físicos dos carros ou da direção de prova nativa.

---

## 21. REFERÊNCIAS CANÔNICAS E LEITURAS POR TAREFA

### Antes de qualquer alteração de runtime

1. `AGENTS.md` do projeto — normas locais de execução e escopo.
2. `docs/WORKFLOW_OPENCODE.md` — processo proporcional e sem sobrecarga de agentes.
3. `docs/ARCHITECTURE.md` — fluxo per-frame, hot paths, cachês, ordem de require.
4. `docs/STATE_MACHINE.md` — quatro funções de cada estado, transições e estados experimentais.
5. `docs/TESTING.md` — testes possíveis, limitações dos mocks e instalação segura.
6. SDK **instalado** do CSP em `extension/internal/lua-sdk`, documentação in situ quando acessível.

### Quando for trabalhar com boxes e pneus

- [RARE AI controller](https://github.com/ac-sim-improvement-mods/ac-rules-and-race-enhancements/blob/main/RARE/src/controllers/ai.lua) — `setAIPitStopRequest`, `setAITyres`, outlap/inlap.
- [ApexFlow race strategy](https://github.com/Silxyst/ApexFlow/blob/master/src/race_strategy.lua) — histórico por piloto, fuel/lap, monitor de pit.
- [ApexFlow README](https://github.com/Silxyst/ApexFlow) — escopo e requisitos documentados pelo autor.

### Quando for trabalhar com comportamento e conflitos

- [Verve README](https://github.com/ververacing/verve) — conceitos de personalidade, recuperação e conflito de AI grip, **sem reutilização de código**.
- [Full Send AI](https://github.com/Eddlm/Full-Send-AI) — conceitos de curva/microsetor e percepção de aderência.
- [CSP Lua SDK](https://github.com/ac-custom-shaders-patch/acc-lua-sdk) — documentação de contexto e funções.

### Quando for trabalhar com clima e mecânica

- [Base weather controller](https://github.com/ac-custom-shaders-patch/acc-extension-config/blob/master/weather-controllers/base/controller.lua) — contrato de controlador climático.
- [Weather FX base](https://github.com/ac-custom-shaders-patch/acc-weatherfx-base) — implementação visual/climática separada.
- [AC ConditionReports](https://github.com/otherchriso/AC_ConditionReports) — observação de condições sem controlo do clima.
- [Mechanical Realism Framework](https://github.com/cvr-admin/gec_feature_script) — script físico e reparos de carro, com limites de integração.

### Quando for trabalhar com testes, UI e logbook

- [Race Logger](https://github.com/Zhaoyi-Fan/assetto-corsa-race-logger) — logging de todos os carros, agregação de incidentes, replay/debrief.
- [AC Tracer](https://github.com/tobi/ac-tracer) — telemetria por posição e análise de setor (licença a confirmar).
- [Auto Yellow Hazards](https://github.com/yukkine0704/assetto-corsa-auto-yellow-hazards) — incidente, hazard, prioridade e debounce.
- [Pro Engineer](https://github.com/Rgosh/ac-pro-engineer) — mensagens de engenheiro por telemetria.

---

## 22. PERGUNTAS QUE O OPENCODE DEVE RESPONDER NA AUDITORIA (NÃO PERGUNTAR AO USUÁRIO O QUE O CÓDIGO RESPONDE)

1. `physics.setAIPitStopRequest()` está presente na build/SDK alvo e acessível no mesmo contexto da Lua App? Existe comportamento diferente no modo Track Day?
2. `physics.setAITyres()` troca pneus corretamente quando a IA está fisicamente no box? Quais condições são necessárias?
3. Em quais sessões `setAITopSpeed()`, `setAIThrottleLimit()` e `setAIBrakeHint()` surtem efeito observável? Há interferência de AI Flood?
4. `physics.setExtraAIGrip()` e `physics.setAILevel()` são alterados por módulos já existentes e por outro mod? Como evitar escrever o mesmo knob em duas camadas?
5. Quais campos exatos da estrutura `ac.StateCar` e dos `wheels` fornecem desgaste/temperatura confiáveis na build-alvo? Quais unidades e semânticas?
6. Como a Lua App identifica um carro estacionário em box sem depender apenas de velocidade zero?
7. Há forma documentada e segura de distinguir pit lane válida, pitbox e ausência de `pit_lane.ai`?
8. Quando o app é desabilitado durante uma manobra, quais valores já escritos em CSP exigem restauração? Quais não podem ser lidos de volta com segurança?
9. `BehaviorPolish` tem parâmetros configurados sem efeitos runtime? Onde inserir as funções sem quebrar transições?
10. `HumanErrorManager` modifica apenas carros controlados pela IA? A chance foi normalizada por `dt` e há cooldown consistente?
11. O que ocorre com cache, storage e identidade de carros quando há teleport/reset/AI Flood?
12. Quais parâmetros já estão controlados pelo AC/CSP e não precisam ser duplicados como simulação artificial de temperatura, chuva, dano ou flag?
13. É possível uma ponte de status MRF para Lua App **sem** alterar os carros de terceiros e sem interpretar canais arbitrariamente?
14. Quais testes headless existentes passam no checkout atual? Quais falham e por quê? Quais são impossíveis sem instalação manual do jogo?
15. Qual milestone oferece maior melhoria de realismo com menor risco de segurança/compatibilidade para a primeira implementação autorizada?

---

**Nota de confiabilidade:** as referências deste documento são links e observações de código/README consultados em 21/10/2026. Itens inferidos de mods externos e propostas de arquitetura são identificados como tal. Nenhuma implementação nova deste roadmap foi submetida ou testada no Assetto Corsa durante a criação do documento. O OpenCode deve sempre reconciliar tudo com o commit e a build efetivamente instalados antes de escrever código.
