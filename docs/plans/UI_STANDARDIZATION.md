# Plano: padronização inicial da UI

## Objetivo e limites

Padronizar medidas, hierarquia visual dos controles recorrentes e respostas a larguras limitadas usando os tokens azuis já presentes em `lib/uilib/Theme.lua`. A referência Garry’s App Hub serviu apenas para observar princípios de tokens centralizados e estados explícitos; não se reutiliza código, paleta nem identidade. Preservar as cinco abas, rótulos e IDs, ordem e fluxos atuais, funcionalidades e o workaround de texto nativo da lista de carros.

Esta etapa não redesenha o dashboard, não cria sidebar/categorias e não altera comportamento de IA, persistência, perfil, bootstrap ou instalação. `UI_IDENTITY.md` permanece um plano independente.

## Fases e critérios

1. **[x] Primitivas compartilhadas pequenas.** Concentrar medidas de layout e helpers para largura de combo/chip e indicador de estado em tokens/projeto próprio; aplicar sem mudar a navegação ou os fluxos existentes. Critério: nenhum chip solicita largura maior que o conteúdo; em espaço insuficiente, os filtros permanecem acessíveis por combo com rótulos traduzidos completos e seleção funcional. Código implementado; headless não demonstra renderização CSP.
2. **[ ] Validação visual CSP.** Instalação de teste paralela, sem tocar instalação ou preferências do usuário; conferir larguras 80/480/700/900/1200/1760, três idiomas, seleção, clipping/overflow, estados e fontes. Critério: observação manual registrada. Headless e inspeção de fonte não substituem este gate.
3. **[ ] Avaliar hierarquia das seções e Overview.** Planejar separadamente após revisão visual; decidir agrupamento/densidade sem implementar sidebar ou categorias por antecipação. Critério: proposta aprovada antes de alteração estrutural.
4. **[ ] Revisão de consistência pós-etapa.** Procurar medidas/estados duplicados nos callsites autorizados, mantendo strings e IDs estáveis. Critério: padrões recorrentes usam tokens compartilhados ou exceções documentadas.

## Ajuste focado do chrome da janela

**Fonte implementada; validação CSP pendente.** `manifest.ini` na seção `[WINDOW_0]` usa `NO_TITLE_BAR`, `NO_BACKGROUND`, `NO_COLLAPSE` e `PADDING = 8, 8`. `Theme.layout.windowInset` mantém o fill desenhado pelo app cobrindo a janela inteira; `Style.lua` aplica um clip temporário limitado ao viewport e o restaura imediatamente, inclusive se o fill falhar. A MainWindow mantém fundo/cabeçalho próprios e posiciona `Close` no canto superior direito do conteúdo com ID estável `main.window.close`; largura usa a medição da fonte nativa ativa. Se o rótulo localizado não couber, usa `X` com o mesmo ID e tooltip localizado. Marca e wordmark só aparecem se suas medidas couberem na área restante, evitando colisão; em viewport estreito, a marca pode ser ocultada. Testes headless verificam retângulos/posições, contrato do clip/fonte, manifesto, ação de fechar e preservação de estado. Não provam comportamento real do CSP nem pixels efetivamente renderizados.

Gate manual: no CSP, confirmar movimento arrastando área vazia do cabeçalho, resize pelas bordas, fechamento no canto superior direito e reabertura pela barra de apps; conferir rótulo localizado ou `X`/tooltip conforme largura, e fill cobrindo bordas sem faixas transparentes. Repetir em viewport estreito e normal. A remoção do chrome nativo pode alterar affordances e hit-testing conforme runtime; nenhuma observação visual é afirmada ainda.

Check focado executado após a correção: `luajit tools/test_main_window.lua` — 545 verificações headless aprovadas, incluindo manifesto, padding/fill, push/pop do clip inclusive em erro, geometria da marca/wordmark/close e rótulo/tooltip nas três locales com largura compacta. Não houve instalação nem validação CSP.

Validação desta etapa (2026-10-19): rodada completa com 11 de 12 testes aprovados; `test_ui_smoke.lua` segue bloqueado pela fixture preexistente ausente. Após os ajustes finais de clip/fonte, reexecução focada de MainWindow, localização, diagnósticos estáticos e bootstrap de módulos aprovada. Sintaxe dos 84 arquivos aprovada, com os quatro arquivos Lua alterados após essa rodada revalidados; diff/whitespace e links locais destes documentos conferidos. Registro das APIs usadas foi incluído na checagem de compatibilidade; isso não estabelece compatibilidade em execução CSP.

## Evidência e estado

Código da fase 1 está presente em `Theme.lua`, `UIControls.lua`, `MainWindow.lua`, `SettingsWindow.lua` e `UIManager.lua`. `tools/payload.manifest` lista explicitamente `lib/uilib/UIControls.lua`; o teste focado contém assert estático dessa entrada. Isso só verifica o manifesto-fonte — não execução do empacotador, instalação, CSP ou renderização. Testes headless verificam contratos e geometria sob mocks; não provam layout, legibilidade, interação real ou compatibilidade/renderização CSP. Fases 2–4 permanecem pendentes.

Validação de 2026-10-18:
- Rodada completa dos 12 testes `tools/test_*.lua`: dez passaram inicialmente; o teste de localização apontou uma inspeção estática que ainda procurava a tradução do status no arquivo anterior à extração. Após atualizar o caminho completo até `UIControls`, sua reexecução isolada passou. Resultado final: 11 testes aprovados e `test_ui_smoke.lua` bloqueado pela fixture preexistente ausente `tools/fixtures/settings_baseline.lua`, não recriada nesta etapa.
- `test_main_window.lua`: 419 verificações; `test_ui_manager.lua`: 267; `test_ui_controls.lua`: 46. Geometria dos filtros exercitada nas seis larguras e nos três idiomas sob mocks.
- Sintaxe LuaJIT aprovada nos 84 arquivos; sintaxe do teste de localização revalidada após seu ajuste. Revisão do delta, whitespace e destinos dos links locais aprovados.
- Nenhuma instalação executada ou observação em CSP realizada. Paleta, cinco abas e alterações locais preexistentes preservadas.
