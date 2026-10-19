# Plano: padronização progressiva da UI

## Direção e limites

Melhorar hierarquia, consistência e responsividade do SimOpenTrackDay usando os tokens azuis e componentes project-owned já existentes. Garry’s App Hub é apenas referência de princípios gerais; não copiar código, paleta, identidade ou estrutura. Manter as cinco abas, strings/IDs estáveis, ordem e fluxos, dados, controles, estados e workaround de texto nativo na lista de carros.

Este plano não autoriza alterações de IA, storage/persistência, bootstrap, manifest, metadados, instalação, vendor/submodule, novas ações ou fluxos não aprovados. Não adicionar gear de configurações, presets, undo/redo, sidebar ou categorias nesta sequência. Não usar emojis, pulsação contínua, cor como único significado, nem rótulos/unidades não confirmados. Offsets são normalizados [-1..1]; preservar “Default/Padrão”, nunca apresentar como metros ou renomear para “Linha ideal”. Clique em carro já seleciona e segue a câmera: não duplicar essa ação.

O plano [UI_IDENTITY.md](UI_IDENTITY.md) permanece independente; suas propostas de dashboard, sidebar e paleta não são adotadas nesta sequência.

## Princípios visuais e de interação

- Manter fundo azul-escuro, superfícies e acento azul existentes; usar sucesso/aviso/erro semanticamente, sempre com texto/forma redundante.
- Reutilizar `Section.section`, `Toggle.render`, `Slider.render`, `UIControls` e `Style`; estender com mudanças pequenas antes de criar componentes ou sistemas novos.
- Priorizar controles CSP nativos. Scopes de estilo/clip/font/item width sempre balanceados, inclusive em erro. Não alterar `FramePadding`/`ItemSpacing` globalmente nem invalidar medições responsivas sem caso demonstrado.
- Botões sem nova ação: definir papéis visuais somente onde callsites existentes precisarem; estados normal/hover/pressed/disabled devem continuar distintos e ter alvo clicável razoável.
- “Ativado” é diferente de “Operacional”; offline é permitido e não equivale a incompatibilidade CSP. Mensagens vazias, filtradas, desativadas e incompatíveis devem ser avaliadas sem ocultar controles necessários.
- Manter idioma acessível no fluxo atual; todo texto novo precisa de localização e IDs estáveis. Evitar glyphs/emojis cuja renderização varie.
- Responsivo: avaliar 480/700/900+ px em en/pt-BR/es; 80 px é caso de robustez e fechamento acessível, não promessa de UI completa.

## Fases, critérios e estado

### 0. Primitivas e chrome já presentes

**[x] Implementado no código-fonte; CSP pendente.** Tokens/medidas e helpers compartilhados, filtros responsivos e ajustes do chrome sem título/background nativos; o fundo customizado usa clip temporário. `tools/test_ui_controls.lua`, `tools/test_ui_manager.lua` e `tools/test_main_window.lua` oferecem contratos headless. Nenhum teste headless comprova pixels, hit-testing ou rendering CSP. Preservar a ressalva: `WindowRounding` não garante cantos arredondados no fill customizado.

### 1. Papéis de botões + agrupamento de Faixas na Overview

**[x] Código e contratos headless implementados nesta rodada; gate CSP pendente.**

- Centralizar papéis visuais de botões já existentes (selecionado/quieto/chrome/desabilitado conforme callsite), incluindo hover/pressed, sem inventar ações. O papel desabilitado é visual; `ui.pushDisabled/popDisabled` continua responsável por bloquear interação. Melhorar consistência de controles nativos com tokens; evitar alterações globais de geometria.
- Reaproveitar `Section.section` para agrupar uma única seção de Faixas de condução na Overview, mantendo `UILateralOffsetsImageWidget`, os valores normalizados, controles/estados e destinos atuais.
- Não redesenhar a lista nem criar toggle customizado/sliders customizados nesta fase. A centralização de papéis de botão só reutiliza as cores existentes; não representa refinamento visual geral de checkbox, combo ou slider.
- **Aceite de fonte/headless:** IDs e fluxos preservados; seção agrupada no lugar atual; papéis de botão vêm de `Theme.button` e `Style.pushButton/popButton`; scopes balanceados; testes focados cobrem agrupamento, estilos e geometria/seleção já existentes. O teste de MainWindow usa UIManager stub para o conteúdo interno: comprova chamada/agrupamento condicional, não rendering do widget de offsets.

### 2. Gate visual CSP após a primeira fatia

**[!] Falhou na primeira observação visual do usuário; validação após as correções ainda pendente.** Na captura CSP real em pt-BR, janela de aproximadamente 1024 px, o título da seção de Faixas apresentava glyphs sobrepostos; abas tinham tipografia fraca, a marca do cabeçalho foi considerada feia e os elementos desalinhados. A evidência cobre apenas essa captura/idioma/largura; não comprova interação, demais idiomas, drag/resize ou performance. Correções de cabeçalho/títulos/abas foram autorizadas sem ampliar para lista ou controles. Para fechar o gate, verificar 480/700/900+ px e três idiomas, mais Close em 80 px; legibilidade, alinhamento, overflow, hover/pressed/disabled, scroll, fundo/clip, drag, resize, close/reopen e uso/performance. Mocks não são evidência CSP.

### 3. Enxugar e validar hierarquia do cabeçalho

**[x] Hierarquia de fonte implementada no fonte; revisão CSP pendente.** Nome do app usa o papel nativo `ui.Font.Title`; pista/sessão, controles, status e botão usam `ui.Font.Main` e o contexto recebe cor secundária; abas continuam no papel `Title`. Esses papéis são enumerações de fonte nativa, não tamanhos em pixels ou pesos garantidos. `Theme.type` permanece referência de medidas DirectWrite e não é usada como conversão para `ui.Font`. O nome e contexto partilham inset; medição/renderização do contexto usa Main. O fundo permanece plano, compartilhado com `Section`. Em larguras wide, controles ficam na linha alinhada; no fallback estreito, quebram sem ocultar idioma ou Close. Fechar usa `ui.iconButton(ui.Icons.Cancel)` com ID escopado `main.window.close`, tooltip localizado e ação existente quando APIs estão disponíveis; sem elas, cai no botão CSP nativo localizado existente. Preservados nome/versão, pista/sessão, controle “Ativado”, estado “Operacional”, cinco abas e Close/ID. O entrypoint agora registra `ui.iconButton` e `ui.Icons.Cancel` uma vez cada; `ui.Font.Main/Title` e `ui.pushID/popID` já estavam registrados. A verificação é de fonte e não comprova disponibilidade, rendering ou interação CSP.

### 4. Uniformizar navegação das cinco abas

**[x] Refinamento preservado; revisão CSP pendente.** Abas usam o papel nativo `Title`, e texto/medição compartilham o mesmo stack. Texto inativo conserva contraste elevado; seleção mantém fundo/underline e hover/pressed. Nomes, IDs, ordem, destino, cinco abas e fallback compacto preservados. Ainda não há evidência visual CSP pós-alteração nos três idiomas/larguras.

### 5. Lista compacta — sem redesign na fase atual

**[ ] Futuro, após seu gate CSP.** Avaliar alinhamento compacto de número/estado/velocidade/offset e leitura de estados, mantendo seleção e ação de câmera existentes, filtros/contagens e workaround de texto nativo. Definir mensagens claras para lista vazia, filtro sem resultados, app desativado e incompatibilidade; preservar offline permitido. Não duplicar ação da linha com novo ícone, não pulsar e não introduzir métricas/unidades novas. Aceite: nenhum estado depende apenas de cor; foco/seleção e texto permanecem claros em três idiomas.

### 6. Refino dos controles nativos

**[ ] Planejado; ainda não implementado.** Primeiro revisar checkbox e rótulos de estado (checked/unchecked/disabled), depois slider e combo nativos usando tokens locais de altura, padding e rounding somente quando houver ganho visual demonstrável. Não alterar `FramePadding`/`ItemSpacing` globalmente nem assumir que arredondar o fill customizado arredonda a janela.

- Checkbox: manter label/estado explícitos, IDs estáveis e comportamento nativo; distinguir desmarcado de desabilitado.
- Slider: preservar faixa, precisão/formato, valor exposto, reset por botão direito, default, tooltip, quebra de label e fallback responsivo do `Slider.render`.
- Combo: preservar texto/seleção/IDs, popup nativo, largura responsiva e acesso a opções completas em narrow layouts.
- Qualquer style var local precisa de SDK/enum confirmado, registro de compatibilidade pelo responsável do entrypoint e pop balanceado, inclusive em erros. Hoje a mudança de botões apenas centraliza cores existentes; nada desses refinamentos está marcado como entregue.

Aceite: comparação nos três idiomas e larguras-alvo sem regressão de interação, geometria/medição ou IDs; headless cobre contratos, CSP decide pixels e usabilidade.

### 7. Controles customizados — opcionais e por último

**[ ] Condicional, não faz parte da primeira fatia.** Manter checkbox/switch e slider CSP nativos enquanto atendem. Um switch customizado só será considerado se teste visual demonstrar lacuna; manter alvo maior que o trilho, texto/estado redundantes e IDs estáveis. Slider customizado é última opção, pois precisa preservar ranges, formato, precisão, reset/default, tooltip, label wrap, acessibilidade e comportamento existente. Qualquer API/enum novo exige confirmação no SDK, registro de compatibilidade pelo responsável do entrypoint e teste focado.

### 8. Revisão final

**[ ] Futuro.** Revisar contraste, leitura sem cor, tooltip/foco/alvos, traduções/IDs, performance e ausência de alterações de comportamento. CSP permanece gate distinto dos testes headless e da checagem de sintaxe. Só marcar uma fase concluída com evidência correspondente; não inferir compatibilidade ou aparência instaladas a partir do fonte.

## Implementação e evidência

Estado desta rodada: fases 0–1 e refinamentos de cabeçalho/títulos/abas (fases 3–4) implementados em fonte; gate visual CSP da fase 2 e fases 5–8 pendentes. `Section.section` mantém texto/medição nativos; o workaround DirectWrite da lista permanece intocado. A função reutilizável de Faixas permanece top-level; `Section.section` fecha group após erro do callback e preserva o erro original. O cabeçalho usa fontes nativas Title/Main em scopes locais, sem mudar a fonte dos conteúdos de Settings/Sections. Os registros de `ui.iconButton` e `ui.Icons.Cancel` agora estão no entrypoint e são verificados estaticamente uma vez cada; fallback segue disponível. O registro existente de `ui.drawRectFilledMultiColor` permanece intocado. Os testes MainWindow usam mocks; comprovam contratos de fonte, IDs e fluxo, não pixels, glyphs ou runtime CSP.

Validação final desta rodada (2026-10-19):

- Rodada completa dos 12 testes `tools/test_*.lua`: 11 aprovados; `test_ui_smoke.lua` permanece bloqueado pela fixture preexistente ausente `tools/fixtures/settings_baseline.lua`, não recriada.
- Após a correção do cleanup de grupos, reexecução focada de MainWindow (620 verificações), roteamento de SettingsWindow e localização aprovada. Sintaxe LuaJIT aprovada nos 84 arquivos; os dois arquivos Lua alterados depois da rodada foram revalidados.
- Revisão do diff sem achados pendentes, whitespace e destinos dos links locais aprovados. Sem instalação, commit, push ou validação visual/runtime CSP nesta rodada.
- Correção visual de títulos/cabeçalho/abas e label explícita do idioma: `tools/test_main_window.lua` passou com 639 checks; `tools/test_settings_navigation.lua` e `tools/test_localization.lua` passaram. São contratos headless, não evidência CSP pós-correção.
- Correção focada de geometria do cabeçalho: MainWindow passou com 722 checks, incluindo posições capturadas de texto/contexto, checkbox, label/combo de idioma, status e fundo em 480/900/1200 px nos três idiomas; Settings navigation e localization passaram novamente. Mock geometry verifica relações/limites de layout do código, não rendering CSP ou clipping real.
- Correção de altura/limites do cabeçalho: MainWindow passou com 749 checks; Settings navigation e localization passaram; compilação de sintaxe LuaJIT dos três arquivos Lua afetados (`MainWindow.lua`, `Theme.lua`, `test_main_window.lua`) passou. O mock agora avança cursor/item bounds com alturas distintas para checkbox, combo e texto wrapped; asserts confirmam que a separação externa fica abaixo dos bounds, incluindo combo mais alto que texto Operational e status de aviso multi-linha mais alto que o combo. Resultados 620/639/722 acima são checkpoints anteriores, não contagem desta correção.
- Ajuste visual separado após feedback do usuário: MainWindow e `Section` usam superfície plana uniforme; removidos apenas os usos de gradiente/faixa decorativa. O registro `ui.drawRectFilledMultiColor` no entrypoint foi preservado. Sem mudança na geometria/limites de controles. MainWindow passou novamente com 749 checks; localization, Settings navigation e `loadfile` dos quatro arquivos Lua alterados passaram. Evidência continua headless; sem validação CSP, instalação, commit ou push.
- Implementação tipográfica/ícone do cabeçalho: app Title; contexto, controles e status Main; abas Title; ícone Cancel nativo com ID escopado, tooltip, ação existente e fallback de texto. MainWindow passou com 756 checks, incluindo métricas mock distintas por papel, idiomas/larguras, fallback sem ícone e cleanup em falhas de icon/context. Localization, Settings navigation e `loadfile` dos três Lua alterados passaram. A integração CSP continua pendente; a compatibilidade de `ui.iconButton` e `ui.Icons.Cancel` ainda precisa de registro no entrypoint pelo responsável. Nenhum teste visual CSP foi executado.
- Evidência histórica anterior ao follow-up tipográfico: rodada completa relatada como 11/12 testes aprovados (somente o smoke bloqueado pela mesma fixture preexistente ausente), sintaxe LuaJIT nos 84 arquivos e links locais aprovados. Não foi reexecutada nesta atualização. O estado anterior foi publicado em `17acab0` antes daqueles ajustes; as correções seguintes permanecem locais e com revisão visual CSP pendente.
- Follow-up limitado de registro: adicionados pelo responsável do entrypoint os dois registros de `ui.iconButton`/`ui.Icons.Cancel`; o teste MainWindow exige cada string de registro exatamente uma vez. `luajit tools/test_main_window.lua` passou com 758 checks. O assert comprova apenas fonte, não disponibilidade/rendering em CSP. Nenhuma outra suíte foi executada neste follow-up.
- Validação final da implementação tipográfica reconciliada: rodada completa dos 12 testes com 11 aprovados, incluindo MainWindow com 758 checks; somente `test_ui_smoke.lua` falhou ao carregar a fixture preexistente ausente. Sintaxe LuaJIT aprovada nos 84 arquivos; revisão do delta sem achados acionáveis, whitespace e links locais aprovados. Fundos planos anteriores preservados. Sem instalação, commit, push ou validação visual/runtime CSP desta implementação.

## Histórico de validação anterior (não é resultado desta rodada)

- Em 2026-10-19, após a alteração focada de chrome, `tools/test_main_window.lua` passou com 545 verificações headless; revisão anterior registrou rodada final 11/12 testes, com `test_ui_smoke.lua` bloqueado pela fixture preexistente ausente, além de sintaxe nos 84 arquivos. Esses números são evidência histórica, não resultado da fase 1 atual.
- A fase anterior não executou instalação ou validação visual CSP. A entrada de `lib/uilib/UIControls.lua` em `tools/payload.manifest` é explícita; os asserts do manifesto comprovam apenas o arquivo-fonte, não instalação ou rendering.
