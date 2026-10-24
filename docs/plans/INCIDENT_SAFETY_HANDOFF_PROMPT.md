# Prompt de continuidade — Incident & Safety System

Preparado em 2026-10-23. Copie o conteúdo da seção **Prompt** para outro contexto, aberto na worktree indicada. Este arquivo é documentação, não configuração, comando ou instrução global do OpenCode. Os fatos abaixo são um snapshot a reconfirmar, não garantia de estado atual.

## Prompt

Conduza o encerramento incremental da fase **Incident & Safety System** do SimOpenTrackDay antes de M2, novas bandeiras operacionais, punições esportivas ou outros sistemas de simulação. Siga o plano consolidado em `docs/plans/DEVELOPMENT_PLAN.md`, especialmente “Encerramento da fase Incident & Safety System”, e preserve os tickets/evidências S1/S2 existentes.

Objetivo: **detecção → validação → incidente → zona de segurança → reação da IA → recuperação observada → resolução → liberação de recursos**. Não fazer refatoração preventiva ampla nem prometer recuperação física completa.

### 1. Local correto e baseline que não pode ser perdida

- Repositório principal: `E:\Projetos\SimOpenTrackDay`.
- Trabalho local a continuar: `E:\Projetos\SimOpenTrackDay\.slim\worktrees\incident-stale-cleanup`.
- Branch esperada: `omos/incident-stale-cleanup`.
- Base integrada anterior M1a/M1b: `9ce6f47e98e2e80ca40a274e72103a99960d2e02`. **Essa base sozinha não contém S1/S2; não é o HEAD esperado após o checkpoint.** O usuário autorizou um commit dos onze arquivos e push desta branch para `origin`, mantendo `main` e a lane. Confirme no log/HEAD, no status e na referência remota se a publicação foi concluída; preserve diferenças adicionais. Não criar outra lane a partir apenas da base anterior nem presumir que S1/S2 continuam untracked/não commitados.
- Submódulo esperado: gitlink `7007085f48ad12a0bcf35eaed028691111a83697`; checkout principal estava limpo nesse SHA, mas a lane estava sem o submódulo inicializado. Não inicializar/atualizar dependências incidentalmente.
- O principal possui alterações locais de `.gitignore`/`.ignore`, `.slim/` e codemaps preexistentes. Não editar, mover, remover nem atualizar `.slim/worktrees.json`.

Antes de qualquer edição, inspecione diretório, branch, HEAD, status incluindo untracked/staged, diff completo pertinente, remotos, worktrees e estado/gitlink do submódulo. Leia os arquivos atuais; não confie em GitHub, histórico do plano ou HEAD para substituir a implementação local. Se a lane ou o conteúdo esperado não estiver disponível, pare e relate; não recrie S1/S2 nem descarte diferenças automaticamente. Preserve tudo sem stash/reset/clean.

A entrega original S1/S2 contém estes nove caminhos locais:

- `AccidentManager.lua`
- `CarOperations.lua`
- `CarStateMachine/CarStateMachine.lua`
- `CarStateMachine/States/CarState_CollidedWithCar.lua`
- `CarStateMachine/States/CarState_AnotherCarCollidedIntoMe.lua`
- `tools/test_incident_cleanup.lua` — adicionado por S1; conferir rastreamento e preservar.
- `tools/test_incident_release.lua` — adicionado por S2; conferir rastreamento e preservar.
- `tools/test_session_lifecycle.lua`
- `docs/plans/DEVELOPMENT_PLAN.md`

Somam-se a eles a atualização documental de `docs/README.md` e este novo `docs/plans/INCIDENT_SAFETY_HANDOFF_PROMPT.md`. Reconfirme o inventário em vez de tratar essas listas como autorização para sobrescrever arquivos ou como inventário permanente.

### 2. Leitura orientada e estado real

Leia `AGENTS.md`, `docs/README.md`, `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`, `docs/TESTING.md` e as seções pertinentes do plano. Consulte `docs/plans/CSP_CAPABILITY_AUDIT.md` apenas para as capacidades necessárias. Não carregar árvores documentais inteiras. Arquitetura/FSM têm descrições históricas: os estados de colisão locais já foram alterados por S2; não revertê-los para corresponder ao texto antigo.

- M1a/M1b e painel de inspeção estão integrados na base indicada, mas aceite integral CSP não está estabelecido.
- **S1 implementado/revisado para o checkpoint:** reset/identidade descarta todos os incidentes ativos envolvendo o participante e suas zonas, inclusive vítima compartilhada; preserva incidentes independentes. Não restaura física. Conferir estado Git corrente, sem presumir alterações não commitadas.
- **S2 implementado/revisado para o checkpoint:** episódio por carro/geração/sessão, dez segundos ativos desde primeira admissão, sobreposição sem extensão, marcador impede rearmar registro antigo. Após prazo cessa renovação; libera pedidos `INCIDENT_STOP` e controles comprovadamente próprios, respeita handback e último stop counter antes da saída. Sobrevivente válido ainda recebe handback se o reset do outro resolver o incidente.
- Última validação integrada registrada: **92 sintaxes PASS; 18/19 testes PASS**, cada teste em processo separado; `test_incident_release` tem **17 grupos de integração com módulos reais sob mocks**. São resultados anteriores, não checks executados nesta nova sessão.
- Único FAIL conhecido: `tools/test_ui_smoke.lua:10`, por ausência de `tools.fixtures.settings_baseline`. Não gerar/substituir fixture nem usar overrides para esconder a falha.
- **Aceite S2 no CSP pendente.** Último log analisado registrou app carregado e colisão `19 → 31`/zona às 20:10:01 de 2026-10-23; usuário disse “Pelo replay nenhum parou...”. Não houve prova suficiente de aplicação, prazo ou handback. Logs de “switching to” precedem enqueue, não comprovam dispatch/entry. Reprodução de uma gravação live não é o mesmo que executar física do app em replay; seu gate não apaga efeitos já gravados.
- Hashes de sete arquivos correntes instalados coincidiam com a lane na conferência anterior; isso não certifica todo o payload nem bytes carregados historicamente. A compatibilidade tinha pendência de arquivos no caminho esperado apesar do carregamento positivo no log: não inferir falha de carregamento nem reparar instalação sem autorização.
- **S2-D não autorizado:** foi proposta instrumentação temporária em quatro arquivos, mas o usuário escolheu revisar os limites. Não assumir essa proposta como ticket aprovado.

### 3. Invariantes e limites não negociáveis

1. Zero writes por carro no jogador/índice `0` (inclusive autopilot), humanos, inválidos ou identidade obsoleta; zero atuação em pausa, replay, disable ou permissão ausente/desconhecida. `physics.allowed` aceita função ou `cdata` chamável sob `pcall`, exigindo retorno exatamente `true`.
2. Preservar gerações de carro/sessão, snapshots e descarte de eventos antigos. Pausa simples conserva episódio/evidências e congela tempo; reset/replay/disable/invalidação descartam memória sem setters. Não adotar holds descartados numa identidade nova nem forçar recuperação pós-invalidação.
3. Preservar M1b: donos, prioridades, leases, cap após arbitragem e no máximo uma tentativa por controle/índice/resolução. Pedido, vencedor, último setter e transferência lógica são distintos; shadow não é readback. Liberar somente recursos próprios confirmados sem apagar outros pedidos legítimos.
4. Não inventar baseline física: cautela volta à política configurada, não valor nativo conhecido. S2 pressupõe exclusividade de gentle stop pelo app durante o episódio testado; top speed/throttle também têm a premissa de exclusividade documentada em M1b. O app não detecta essas premissas.
5. Setter pode lançar erro depois de possível efeito. Progredir liberações próprias independentes; canal incerto mantém pendência conservadora. Não inverter estado desconhecido, declarar sucesso falso ou renovar parada após prazo para obter evidência.
6. Dez segundos é política de teste, não tuning CSP validado. Handback não prova movimento, recuperação ou desaparecimento do obstáculo e não encerra a amarela.
7. Não reativar colisões genericamente nem restaurar estados de terceiros por suposição. O terceiro argumento de `disableCarCollisions` é `applyToRemote`, não ownership. Não prometer limpeza física após invalidação ou retirada de aquisições antigas; teste prospectivo em sessão nova.
8. Prazo de incidente provoca reavaliação, não remoção automática. CLEARING requer estabilidade de observações válidas por intervalo justificado; dado ausente/desconhecido não prova pista livre. Preserve S1 e incidentes independentes; risco remanescente exige evidência atual.
9. Pit é contexto, não exclusão absoluta: parado sozinho não é acidente; contato não é prova suficiente de perigo persistente; acidente real no pit não deve ser ignorado automaticamente.
10. LuaJIT 2.1/Lua 5.1, `bit.*`, runtime na raiz, bindings locais e tabelas DoD/buffers reutilizáveis; evitar alocação por frame. Preservar manifest/callbacks, nove `[RTD-DIAG-*]`, `ShowErrorModalDialog = false`, créditos/licenças e vendor/submódulo.

Não alterar OpenCode, agentes/prompts/config globais, SDK, dependências, manifest ou instalador incidentalmente. Não implementar punições/enforcement, M2, grip/tuning, teleporte, pit automático ou recuperação física completa. Não criar `FlagDirector`, arbitragem universal ou segunda FSM preventiva; justificar extrações apenas por necessidades demonstradas nos módulos existentes.

Sem autorização específica, não criar/remover branch ou worktree, fazer commit/stage/push/merge/rebase/cherry-pick, inicializar submódulo, limpar arquivos, instalar no jogo, alterar settings ou executar rollback. A autorização anterior limita-se ao checkpoint dos onze arquivos, não se estende a novos commits/publicações nem à integração ou remoção da lane. Copiar este prompt não autoriza essas ações nem libera uma allowlist geral de runtime.

### 4. Ordem de execução

Trabalhe em **S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9**, com os contratos completos no plano consolidado:

| Etapa | Foco |
| --- | --- |
| S2 | Auditar aceite da parada: admissão única, tempo ativo/pausa, gerações, cessar renovação, confirmar handback, dispatch posterior e falhas/interrupções. Reutilizar os testes existentes; adicionar só lacunas concretas. Separar admissão, aplicação/liberação e efeito físico |
| S3 | Inventário de todos os caminhos de colisões; retirar intangibilidade indiscriminada de passantes em amarelas sem enable/restauração genérica; testar participantes e navegação separadamente |
| S4 | Callback/fila/mapas/papéis, deduplicação, eventos inválidos/obsoletos, gerações e múltiplos participantes compatíveis, sem fundir riscos independentes |
| S5 | Distância versus spline, incidente mais próximo, wrap 0/1, overlap/buckets, antecipação por velocidade e pit, com testes determinísticos |
| S6 | Ciclo de vida equivalente a DETECTED/ACTIVE/CLEARING/RESOLVED, observação estável de risco, expiração como reavaliação, reset e limpeza idempotente |
| S7 | Transições reais dos estados de incidente, restrições/cautela, pending guards, congestionamento/retomada; setters não garantem velocidade física |
| S8 | Consolidar amarela separando risco/gravidade/zona/aviso/reação; interfaces justificadas para fixa/agitada/dupla, sem novas bandeiras operacionais ou limpar flags de terceiros |
| S9 | Integração, matriz CSP e relatório técnico; distinguir executado, observado, limitações e pendências |

Antes de cada alteração, apresente e obtenha aprovação para um ticket curto com contrato, defeito/evidência, comportamento observável, **arquivos exatos** (novos inclusive), exclusões, teste decisivo, fallback, donos da evidência e necessidade/base da lane. A aprovação anterior S1/S2 não autoriza ampliar esses tickets. Não rotular plano aprovado, log ou mock como aceite físico. Auditoria somente leitura pode identificar a próxima lacuna; não pular a ordem nem o aceite exigido.

### 5. Evidência, validação e entrega

- Implementador: testes focados do escopo com módulos reais sob mocks; revisor: diff/contratos somente leitura; integrador: ler/reconciliar artefatos e depois uma rodada integrada aplicável, não suíte inteira por microalteração. Documentação fica com quem detém o conteúdo.
- Sintaxe: `tools/check_lua_syntax.ps1 -Root <esta-lane> -LuaJitPath <luajit.exe>`. LuaJIT encontrado anteriormente em `C:\Users\SnakeD\AppData\Local\Programs\LuaJIT\bin\luajit.exe`; reconfirmar. Para mudança de runtime reconciliada, executar os `tools/test_*.lua` em processos separados, conforme `docs/TESTING.md`, sem varrer outras lanes. Para docs-only, revisar diff/links; não rodar Lua tests por obrigação fictícia.
- Matriz: colisão simples/múltipla/repetida/inversa, vítima compartilhada, incidentes independentes/overlap, linha 0/1, pit, pause/replay/reset, sessão/Flood/índice reciclado, humano/jogador/autopilot, permissão desconhecida, API ausente/erro após possível efeito, handback parcial/retry/outro owner, novo contato durante liberação, participante perdido/sobrevivente válido e movimento desconhecido.
- CSP manual em sessão nova: revisão mais diff/hashes instalados, build, pista/layout, carros/modo/grade, Flood/controladores e exclusividade; observar tempo ativo, liberação, transições reais, movimento, dano/obstrução, contatos/intangibilidade, risco/zonas, disable e 20–30 IAs. Mocks não demonstram física/rendering/performance. Instalação/rollback são do usuário, não executar automaticamente.
- Se diagnóstico temporário for necessário, propor separadamente finalidade, ativação explícita, marcos limitados e retirada. Nada de logs por frame, UI nova, alteração de decisões físicas ou contabilizar enqueue como aplicação. Sua falha não deve interferir no controle.
- Relatório final: problemas, contratos, mudanças/arquivos, revisão, comandos/códigos de saída realmente executados, observações CSP, falhas preexistentes, limites e pendências. Na falta de prova CSP exigida, declarar **implementado e verificado localmente; runtime pendente**, sem encerrar a fase.

Critério final: liberar recursos comprovadamente próprios quando permitido e verificável na identidade atual; nas invalidações, limpar memória sem writes proibidos e reportar resíduos/limitações. Nenhum registro obsoleto deve sobreviver incorretamente à perda de participantes. Nenhuma amarela deve persistir após resolução comprovada de todos os riscos associados, preservando incidentes independentes e estados de terceiros.

**Sua primeira entrega neste novo contexto deve ser a inspeção somente leitura e o menor ticket S2 necessário para avançar, com allowlist exata e pedido de aprovação antes de editar. Não reimplemente S1/S2 nem comece por uma refatoração S3–S9.**
