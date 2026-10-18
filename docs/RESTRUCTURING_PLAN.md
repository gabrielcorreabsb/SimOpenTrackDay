# Plano de reestruturação

Plano atual e fonte única de direção para as próximas etapas. Substitui propostas anteriores de janelas/páginas separadas; documentos históricos servem apenas como referência, não como especificação concorrente.

## Contexto e limites

- Base B foi alterada localmente, sem commit e sem redesenho executado. Há novos `MainWindow`, `SettingsModel` e `UIState`; `UIStorage` preexistente está não rastreado. `Localization`, `StorageManager`, `SimOpenTrackDay`, `SettingsWindow` e ferramentas de teste também têm alterações locais.
- Esses módulos não estão publicados. Antes de trabalho compartilhado, consolidar apenas dependências necessárias, revisar os diffs e preservar alterações alheias; não presumir que a base está coerente.
- Estado: P0 publicado em `origin/main` no commit `64e3d69476d99a52dc58108505e64f896ba1b878`; base B local, P1–P5 pendentes. Implementação P1–P4 pode começar dentro do escopo abaixo. P5 trata da criação do pacote seguro; execução em instalação real não está autorizada. Permanecem vedados reset de armazenamento e mudanças em vendor/submódulos ou configuração OpenCode.
- Usuário autorizou em 18/10/2026 a remoção de diagnósticos e, posteriormente, uma janela com abas internas. A direção UX abaixo foi orientada pelo designer; ainda não está implementada.
- Commit/push por unidade validada, com staging explícito. Coordenador e git-release revisam/publicam; preservar arquivos dirty não relacionados, sem force push ou reescrita de histórico. Se push falhar, resolver antes da etapa seguinte.

## Unidades e critérios de aceite

### P0 — Plano e índice | em documentação

- Arquivos-alvo: `docs/RESTRUCTURING_PLAN.md`, um link em `docs/README.md`.
- Aceite: plano único, links relativos válidos e revisão do diff da unidade P0 (estes dois arquivos), preservando alterações dirty alheias. Não executar testes Lua.

### P1 — Base coerente B | pendente

- Alvo: consolidar refatoração local e dependências necessárias já existentes, sem incluir arquivos alheios; revisar `MainWindow`, `SettingsModel`, `UIState`, `UIStorage`, localização, armazenamento, janela, entry point e testes pertinentes.
- Aceite: inventário de diffs e dependências, compatibilidade de APIs/contratos documentada, testes adaptados e verdes antes de compartilhar a base. Não afirmar publicação prévia dos novos módulos.

### P2 — Retirada de instrumentação diagnóstica | pendente

- Alvo: remover os nove registros `[RTD-DIAG-*]`, `SOTD-MEM-PROBE`, debug UI/overlays/traces e ações de desenvolvimento, conforme autorização explícita de 18/10/2026.
- Aceite: nenhum diagnóstico removido é substituído por outro; erros operacionais e `xpcall` permanecem sem mascaramento; verificações CSP e `CSPCompatibilityManager.ShowErrorModalDialog = false` são preservados. Não alterar defaults salvos nem namespaces. Esquemas debug legados podem permanecer inertes para preservar configurações.
- Não transformar a lista operacional de carros em interface debug; não tocar IA ou física.

### P3 — Uma janela com abas internas | pendente

- Direção UX: uma janela, sem janelas separadas por aba; header sempre visível com marca/logo, contexto de pista/sessão, enable, idioma e acesso à lista operacional. Abas: Overview (driving lanes: offsets/visual e lista de carros), Behavior (perfil, caution, aggression, difficulty), Yielding, Overtaking e Advanced (demais controles operacionais recolhíveis). Sem aba Diagnostics.
- Em telas estreitas, abas fazem wrap ou viram seletor com rótulos completos, sem clipping em PT/ES; conteúdo usa uma coluna como fallback. Validar larguras/escala no CSP. Texto essencial visível, tooltip complementar; distinguir desligado de indisponível por online/compatibilidade sem depender de cor.
- Perfil é inferência parcial de três campos; preservar aplicação explícita e não inventar `storage.profile`.
- Alvo técnico: remover `WINDOW_1` e callback/routing de Settings coordenadamente em manifest/UIManager; manter `WINDOW_0`/`mainWindow`, entry point raiz, `ICON`/`RENDER`/`UPDATE`. `MainWindow` compõe apresentação; `SettingsWindow` pode virar renderização de conteúdo, não segunda janela. `SettingsModel` concentra queries/actions; `UIState.activeTab` é transitório, sem storage key.
- Direção visual: paleta azul, amarelo e verde, com hierarquia tipográfica e espaçamento modernos, atualizando as cores do Theme e reaproveitando Logo e componentes existentes. Usar amarelo/verde moderadamente para não competir com o azul de ação/seleção; estados devem ter texto, não depender só da cor.
- Pares de referência: fundo `#101820` / texto `#EAF0F6`; superfície `#192631` / borda `#344554`; texto secundário `#A8B6C5`; ação/seleção azul `#2463EB`; atenção amarelo `#F4C95D`; confirmação verde `#49B879`; texto desabilitado `#82909D`. Em botão primário/seleção azul, usar rótulo `#FFFFFF`.
- Contraste sRGB calculado como referência: texto `#EAF0F6` sobre fundo `#101820` 15.59:1; branco sobre azul `#2463EB` 5.17:1. Isto não substitui validação visual/acessibilidade no CSP.
- Aceite: controles operacionais acessíveis nas abas, layouts/idiomas e contraste de referência validados, remover contrato da segunda janela e preservar IDs/callbacks restantes. P2 e P3 só podem ser combinados se não houver entrega intermediária coerente; validar e commitar cada unidade distinguível antes da seguinte.

### P4 — Identidade e versão 0.1 | pendente

- Alvo: identidade própria SimOpenTrackDay e versão exatamente `0.1` em Constants/manifest e superfícies mantidas; revisar catálogos e fixtures cirurgicamente, sem regenerar baseline.
- Remover referências à marca antiga da superfície mantida quando desnecessárias; não apagar créditos, avisos ou histórico. Preservar copyright, licença MIT e `LICENSE` completo de Andreas Grech, notices e proveniência; não alegar que nome/URL de marca são obrigação jurídica.
- Não reescrever history/artifacts/vendor/submódulo/FUNDING. `Realistic` é enum/perfil, não marca. Revisar README para versão herdada e changelog conciso para o futuro.
- Aceite: busca revisada por marca/versão nos alvos autorizados, paridade localization/fixtures e testes relevantes sem alterar licença/proveniência.

### P5 — Empacotamento seguro | pendente, posterior

- Alvo: allowlist do payload runtime e installer BAT fino com PowerShell seguro; preview por padrão, confirmação explícita `YES`, backup SHA256, journal e rollback, conflitos sem MIR/PURGE.
- Aceite: sandbox antes de publicação, sem instalação real sem consentimento. Não bloqueia UI 0.1 nem autoriza execução em instalação real.

## Validação, publicação e retomada

- Por etapa, selecionar comandos conforme escopo e reutilizar evidência ainda válida: `git diff --check` e revisão de links/diff para documentação; Lua somente quando mudanças de runtime/testes forem autorizadas.
- Matriz Lua pertinente: `luajit tools/test_main_window.lua`, `luajit tools/test_settings_model.lua`, `luajit tools/test_ui_smoke.lua`, `luajit tools/test_logo_smoke.lua`, `luajit tools/test_localization.lua` e `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_lua_syntax.ps1`. Não executar tudo redundantemente; adaptar testes antigos a uma janela/zero diagnósticos sem remover asserts de IDs de storage ou estados de carros.
- Mocks/headless não validam CSP nem rendering e não resolvem inferência parcial de perfil. Após entrega, validação manual no CSP pelo usuário: uma janela com abas internas, header persistente, controles acessíveis, rótulos sem clipping, idiomas/larguras, enable, persistência, configurações legadas e erro/indisponibilidade. Consulte [Testing](TESTING.md) e [Localization](LOCALIZATION.md).
- Não fazer deploy, restart ou limpeza de cache; não alegar que refatoração corrigiu erro ainda. Coordenar requisito de teste RTD e documentação estritamente pertinente em etapa futura separada, sem editar `AGENTS.md` agora.
- Cada unidade validada recebe commit e push antes da próxima, com lista explícita de staging e intervalo/branch remoto informado ao git-release. Falha no push interrompe a sequência até resolução.
