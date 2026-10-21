# Plano incremental de desenvolvimento do SimOpenTrackDay

## Estado e autoridade

**Consolidado em 2026-10-21**, a partir da conversa, da [auditoria M0](CSP_CAPABILITY_AUDIT.md) e do [roadmap original](SimOpenTrackDay_Roadmap_Tecnico_OpenCode.md). Baseline de código auditada: `10ed904d2c2178e5d3c5ec3298d474c37e34ecbd`.

- **Autorizado nesta entrega:** consolidar documentação e fazer seu commit/push. Não iniciar implementação, criar worktrees ou alterar ferramentas/configurações/instalação.
- **M0:** auditoria de fontes concluída; confirmação funcional no CSP pendente. A matriz distingue SDK, exemplos externos, código atual e runtime.
- **M1a em diante:** propostas, ainda não autorizadas nem implementadas por este plano. Não há cronograma ou promessa de versão vinculante.
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

### Preparação de M1a, ainda sem autorização de código

Áreas candidatas a inspecionar antes de fechar os arquivos: `SimOpenTrackDay.lua`, `CarManager.lua`, `CarOperations.lua`, `OnCarEventManager.lua`, `HumanErrorManager.lua`, `AccidentManager.lua` e `SessionDetails.lua`. Não é ordem para editar todos esses módulos nem para criar uma arquitetura paralela.

Fechar primeiro a menor fatia que proteja jogador e ciclo de vida em **todos** os caminhos de escrita, inclusive awake, callbacks e incidentes. Separar limpeza dos dados próprios da liberação de controles físicos. M1a não deve prometer restaurar knobs sem readback; M1b introduz ownership progressivamente. Correções de segurança podem alterar deliberadamente o comportamento inseguro anterior, mas não justificam tuning geral.

Aceite local proposto: chamadas instrumentadas em mocks para jogador/IA/autopilot, índice inválido/reciclado, replay, pausa, disable e session start; eventos antigos descartados; cooldown não herdado. APIs ausentes não causam novas escritas indevidas. No jogo: observar os mesmos limites e resíduos por controle, sem inferir sucesso a partir do mock.

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

A skill `worktrees` deste ambiente adota `.slim/worktrees/<slug>/` e metadados locais `.slim/worktrees.json`. É uma convenção de skill/plugin, não padrão nativo. Não criar lanes antes de conciliar essa convenção com destino, ignores e aprovação. Qualquer edição de `.gitignore`, `.ignore`, metadados ou configuração deve integrar um escopo explícito; esta entrega não faz essas alterações.

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

```text
Milestone / estado:
Objetivo e exclusões:
Arquivos autorizados:
Branch / worktree / base:
Decisões e evidências de fonte:
Alterações entregues:
Checks executados e resultados:
Cenários CSP observados / pendentes:
Falhas conhecidas e limitações:
Próximo passo e autorização necessária:
```

**Próximo gate:** aprovar o ticket e os arquivos exatos de M1a. A aprovação desta consolidação documental e de seu commit/push não autoriza implementação, criação de worktree nem alterações de configuração.
