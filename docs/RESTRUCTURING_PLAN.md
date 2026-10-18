# Plano de reestruturação

Plano atual e fonte única de direção para as próximas etapas. Substitui propostas anteriores de janelas/páginas separadas; documentos históricos servem apenas como referência, não como especificação concorrente.

## Contexto e limites

- Base B foi consolidada e publicada em P1 (`origin/main`, `7d38fae2712d496b34e8cd67ee61f4e0207a0273`). Inclui módulos de apresentação, estado, queries e armazenamento compartilhado da UI; os três documentos do usuário (`docs/AGENT.md`, `docs/ARCHITECTURE.md`, `docs/LOCALIZATION.md`) foram preservados fora da unidade.
- Estado: P0 inicial publicado em `origin/main` no commit `64e3d69476d99a52dc58108505e64f896ba1b878`; atualização documental da paleta publicada em `origin/main` no commit `90f300a5a5a0a3474435c58dda21537695b72571`. P1 publicado em `origin/main` no commit `7d38fae2712d496b34e8cd67ee61f4e0207a0273`; P2 publicado em `origin/main` no commit `fb96a1600d4c081377fd6477bf3bbdd4de4a77e6`; P3 publicado em `origin/main` no commit `950e883ea304378e43742661c55c0d99c76f90be`; P4 publicado em `origin/main` no commit `e5999d2f882bf60ed1fca89203120c2b36ea69b7`; P5 publicado em `origin/main` no commit `4066badc3a6289e6b192aa802fb1e0e0fad7f22b`. Documentação adicional sobre leitura da saída do instalador publicada em commit posterior. Sem instalação real autorizada.
- Usuário autorizou em 18/10/2026 a remoção de diagnósticos e, posteriormente, uma janela com abas internas. P3 implementa a direção aprovada; validação manual/CSP continua pendente.
- Commit/push por unidade validada, com staging explícito. Coordenador e git-release revisam/publicam; preservar arquivos dirty não relacionados, sem force push ou reescrita de histórico. Se push falhar, resolver antes da etapa seguinte.

## Unidades e critérios de aceite

### P0 — Plano e índice | publicado

- Arquivos-alvo: `docs/RESTRUCTURING_PLAN.md`, um link em `docs/README.md`.
- Aceite: plano único, links relativos válidos e revisão do diff da unidade P0 (estes dois arquivos), preservando alterações dirty alheias. Não executar testes Lua.

### P1 — Base coerente B | publicado

- Unidade: `MainWindow.lua`, `SettingsModel.lua`, `UIState.lua`, `UIStorage.lua`, `Localization.lua`, `StorageManager.lua`, `SettingsWindow.lua`, `SimOpenTrackDay.lua`, `tools/test_main_window.lua`, `tools/test_settings_model.lua`, `tools/test_ui_smoke.lua` e `tools/test_localization.lua`.
- Evidência registrada em 18/10/2026: testes main/localization passaram; SettingsModel (27), UI smoke (822) e logo smoke (21) passaram; sintaxe (77) passou; `git diff --check` passou; revisão read-only sem achados. Esta evidência não equivale a validação CSP.
- P1 concluído e publicado.

### P2 — Retirada de instrumentação diagnóstica | publicado

- Unidade operativa: remoção de traces, probes, overlays e ações de desenvolvimento, incluindo os nove `[RTD-DIAG-*]` autorizados em 18/10/2026; não restaurá-los. A lista operacional mínima de carros (ID, estado e velocidade/offset) fica sempre visível enquanto o app está em execução. Esquemas debug legados permanecem intocados/inertes.
- Aceite: preservar erros operacionais, `xpcall`, verificações CSP e `CSPCompatibilityManager.ShowErrorModalDialog = false`; sem mascarar erros nem trocar diagnósticos removidos por novos. Não alterar defaults/namespaces, IA ou física. Validação final concluída: `test_main_window`, UIManager (49), UI smoke (775; 56 sliders, 22 checkboxes, 0 dev buttons, 1 combo, 56 storage fields), logo (20), localization e no-diagnostics estático passaram; sintaxe PowerShell (79) e `git diff --check` passaram; revisão read-only sem achados. Reutilizado teste SettingsModel (27) da evidência P1, sem alterações aos seus contratos/código. Validação CSP/manual não realizada.
- Testes focados `tools/test_ui_manager.lua` e `tools/test_no_diagnostics.lua` verificam contratos estáticos/headless, não CSP. Após P2, próxima etapa é P3 (uma janela com abas).

### P3 — Uma janela com abas internas | publicado

- Direção UX: uma janela, sem janelas separadas por aba; header sempre visível com marca/logo, contexto de pista/sessão, enable, idioma e acesso à lista operacional. Abas: Overview (driving lanes: offsets/visual e lista de carros), Behavior (perfil, caution, aggression, difficulty), Yielding, Overtaking e Advanced (demais controles operacionais recolhíveis). Sem aba Diagnostics.
- Em telas estreitas, abas fazem wrap ou viram seletor com rótulos completos, sem clipping em PT/ES; conteúdo usa uma coluna como fallback. Validar larguras/escala no CSP. Texto essencial visível, tooltip complementar; distinguir desligado de indisponível por online/compatibilidade sem depender de cor.
- Perfil é inferência parcial de três campos; preservar aplicação explícita e não inventar `storage.profile`.
- Alvo técnico: remover `WINDOW_1` e callback/routing de Settings coordenadamente em manifest/UIManager; manter `WINDOW_0`/`mainWindow`, entry point raiz, `ICON`/`RENDER`/`UPDATE`. `MainWindow` compõe apresentação; `SettingsWindow` pode virar renderização de conteúdo, não segunda janela. `SettingsModel` concentra queries/actions; `UIState.activeTab` é transitório, sem storage key.
- Direção visual: paleta azul, amarelo e verde, com hierarquia tipográfica e espaçamento modernos, atualizando as cores do Theme e reaproveitando Logo e componentes existentes. Usar amarelo/verde moderadamente para não competir com o azul de ação/seleção; estados devem ter texto, não depender só da cor.
- Gradientes sutis são preferência visual adicional do usuário; tipografia principal branca (`#FFFFFF`), substituindo o texto primário `#EAF0F6` indicado anteriormente. Demais cores de referência: fundo `#101820`, superfície `#192631`, borda `#344554`, texto secundário `#A8B6C5`, ação/seleção azul `#2463EB`, atenção amarela `#F4C95D`, confirmação verde `#49B879`, texto desabilitado `#82909D`.
- Alvo técnico: uma `mainWindow`, cinco abas Overview/Behavior/Yielding/Overtaking/Advanced, header fixo e conteúdo em child scroll; seletor compacto em telas estreitas. Idioma e enable globais; seleção/expansões transitórias em `UIState`, sem novas chaves persistidas. Sem aba Diagnostics; manter erros operacionais e compatibilidade CSP. A atualização de versão e identidade do produto pertence a P4.
- Evidência final: `test_main_window` (305), UI smoke (946: baseline 56 sliders, 21 checkboxes, +1 enable global real testado = 22, 0 dev buttons, 1 profile combo, 56 storage fields), UIManager (49), logo (19), localization e no-diagnostics passaram; sintaxe (79) e `git diff --check` passaram. SettingsModel (27) reutilizado da evidência P1; contrato invariante, não reexecutado. Dois bugs de lifecycle/breakpoint foram corrigidos e a revisão final não apontou pendências. Mocks/testes não validam CSP/rendering; validação manual CSP não realizada.

### P4 — Identidade e versão 0.1 | validado, aguardando publicação

- Estado da unidade: versão exata `0.1` e identidade própria SimOpenTrackDay atualizadas; preview de desenvolvimento, não certificação. Validação final: teste de versão (4), main window (305), UI smoke (946: 56 sliders, 21 content checkboxes, 1 enable global, 1 combo, 56 storage fields), localization e no-diagnostics passaram; sintaxe (80) e `git diff --check` passaram. Revisão read-only sem novos achados; duas correções conhecidas conferidas pelo coordenador. O tratamento de versão existente em `StorageManager` registra a mudança e atualiza `usingAppVersion`; não houve migração de namespaces/schema. CSP, in-game e deploy não realizados.

- Alvo: identidade própria SimOpenTrackDay e versão exatamente `0.1` em Constants/manifest e superfícies mantidas; revisar catálogos e fixtures cirurgicamente, sem regenerar baseline.
- Remover referências à marca antiga da superfície mantida quando desnecessárias; não apagar créditos, avisos ou histórico. Preservar copyright, licença MIT e `LICENSE` completo de Andreas Grech, notices e proveniência; não alegar que nome/URL de marca são obrigação jurídica.
- Não reescrever history/artifacts/vendor/submódulo/FUNDING. `Realistic` é enum/perfil, não marca. Revisar README para versão herdada e changelog conciso para o futuro.
- Aceite: busca revisada por marca/versão nos alvos autorizados, paridade localization/fixtures e testes relevantes sem alterar licença/proveniência. A P4 documenta `SOTD_BASELINE_SETTINGS` e `SOTD_DUMP_BASELINE_FIXTURE`; a fixture versionada permanece inalterada. O dump emite candidato em stdout, não grava fixture. `AGENTS.md` permanece intocado.

### P5 — Empacotamento seguro | publicado em `origin/main` no commit `4066badc3a6289e6b192aa802fb1e0e0fad7f22b`

- Alvo: allowlist do payload runtime e wrapper BAT para PowerShell; Preview por padrão, Build apenas com destino novo externo à fonte e diretório pai existente. O instalador oferece Preview/Install/Rollback; Install exige raiz AC explícita, backup/journal e confirmação `YES`; conflitos são recusados. Checksums cobrem integridade do payload, não autenticidade/assinatura.
- Guia autocontido: [Install](INSTALL.md), copiado como `INSTALL.md` no pacote, explica extração, escolha explícita da raiz `acs.exe`, caminhos com espaços, preview, backup, rollback e preservação de arquivos/configuração desconhecidos. Inclui nota sobre o console fechar em duplo clique (saída de Preview/Rollback) e três formas de capturar a saída. Sem caminho Steam presumido; agentes não executam instalação real.
- Validação sandbox: `tools/test_package.ps1` (302), `tools/test_installer.ps1` (passou, inclui install/rollback, conflito de temp e propriedade do journal) e `tools/test_distribution.ps1` (523, fonte real, build, CLI/BAT não-dot-sourced, caminhos com espaços e caracteres `! &`). Sintaxe PowerShell e `git diff --check` passaram; luaJIT sintaxe 80 arquivos não regrediu. Mocks/raízes temporárias não validam CSP. Instalação real, rendering CSP e deploy continuam não executados.

## Validação, publicação e retomada

- Por etapa, selecionar comandos conforme escopo e reutilizar evidência ainda válida: `git diff --check` e revisão de links/diff para documentação; Lua somente quando mudanças de runtime/testes forem autorizadas.
- Matriz Lua pertinente: `luajit tools/test_main_window.lua`, `luajit tools/test_settings_model.lua`, `luajit tools/test_ui_manager.lua`, `luajit tools/test_no_diagnostics.lua`, `luajit tools/test_ui_smoke.lua`, `luajit tools/test_logo_smoke.lua`, `luajit tools/test_localization.lua`, `luajit tools/test_version.lua` e `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_lua_syntax.ps1`. Não executar tudo redundantemente; adaptar testes sem remover asserts de IDs de storage ou estados de carros.
- Mocks/headless não validam CSP nem rendering e não resolvem inferência parcial de perfil. Após entrega, validação manual no CSP pelo usuário: uma janela com abas internas, header persistente, controles acessíveis, rótulos sem clipping, idiomas/larguras, enable, persistência, configurações legadas e erro/indisponibilidade. Consulte [Testing](TESTING.md) e [Localization](LOCALIZATION.md).
- Não fazer deploy, restart ou limpeza de cache; não alegar que refatoração corrigiu erro ainda. Não editar `AGENTS.md` agora.
- Próximo passo: encerrar a sequência P0–P5; validação manual no CSP e instalação real continuam a cargo do usuário. Cada unidade validada recebeu commit e push com lista explícita de staging e intervalo/branch remoto informado ao git-release. Falha no push interromperia a sequência até resolução.
