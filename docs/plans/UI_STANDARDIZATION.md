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

**[x] Refinamento de fonte implementado; revisão CSP após correção pendente.** Simplificada a marca do cabeçalho para o nome em fonte nativa, sem a logo decorativa. Nome e contexto partilham o inset horizontal; a altura do fundo é derivada da medição nativa do contexto para que este não atravesse sua borda. Close alinha na linha do título. Em larguras wide, enable, label+combo do idioma e status ocupam uma linha com baselines comuns; no fallback estreito, ficam em linhas separadas e respeitam a largura disponível. Preservados nome/versão, pista/sessão, controle “Ativado”, estado “Operacional”, idioma acessível e Close/ID. Manter estado habilitado distinto de disponibilidade operacional e compatibilidade; não esconder idioma atrás de gear. Preservar as regras atuais de `Constants`: offline é permitido e online não é operacional; nenhum runtime foi alterado. Não declarar validado em CSP além da observação inicial limitada descrita na fase 2.

### 4. Uniformizar navegação das cinco abas

**[x] Refinamento de fonte implementado; revisão CSP pendente.** Abas usam tipografia nativa medida pelo mesmo stack/font usado para desenhá-las; texto inativo recebe contraste elevado, enquanto seleção conserva fundo/underline e hover/pressed próprios. Nomes, IDs, ordem, destino, cinco abas e fallback compacto preservados. Ainda não há evidência visual CSP pós-alteração nos três idiomas/larguras.

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

Estado desta rodada: fases 0–1 e refinamentos de cabeçalho/títulos/abas (fases 3–4) implementados em fonte; gate visual CSP da fase 2 e fases 5–8 pendentes. `Section.section` usa texto/medição nativos sob o stack de fonte explícito da MainWindow; o workaround DWrite da lista permanece intocado. A função reutilizável de Faixas permanece top-level; `Section.section` fecha group após falha do callback e preserva o erro original. A label do idioma agora é texto localizado explícito, separada do combo com ID estável. Sem módulo, API ou contrato de runtime novos. `ui.drawRectFilledMultiColor` já era usado pela seção e seu registro de compatibilidade no entrypoint foi feito pelo responsável e coberto estaticamente. MainWindow tem teste com stub do payload UIManager: comprova título, agrupamento/gating e cleanup de group/child/styles/fontes, não pixels ou widget real. Nenhuma validação CSP pós-alteração.

Validação final desta rodada (2026-10-19):

- Rodada completa dos 12 testes `tools/test_*.lua`: 11 aprovados; `test_ui_smoke.lua` permanece bloqueado pela fixture preexistente ausente `tools/fixtures/settings_baseline.lua`, não recriada.
- Após a correção do cleanup de grupos, reexecução focada de MainWindow (620 verificações), roteamento de SettingsWindow e localização aprovada. Sintaxe LuaJIT aprovada nos 84 arquivos; os dois arquivos Lua alterados depois da rodada foram revalidados.
- Revisão do diff sem achados pendentes, whitespace e destinos dos links locais aprovados. Sem instalação, commit, push ou validação visual/runtime CSP nesta rodada.
- Correção visual de títulos/cabeçalho/abas e label explícita do idioma: `tools/test_main_window.lua` passou com 639 checks; `tools/test_settings_navigation.lua` e `tools/test_localization.lua` passaram. São contratos headless, não evidência CSP pós-correção.
- Correção focada de geometria do cabeçalho: MainWindow passou com 722 checks, incluindo posições capturadas de texto/contexto, checkbox, label/combo de idioma, status e fundo em 480/900/1200 px nos três idiomas; Settings navigation e localization passaram novamente. Mock geometry verifica relações/limites de layout do código, não rendering CSP ou clipping real.
- Correção de altura/limites do cabeçalho: MainWindow passou com 749 checks; Settings navigation e localization passaram; compilação de sintaxe LuaJIT dos três arquivos Lua afetados (`MainWindow.lua`, `Theme.lua`, `test_main_window.lua`) passou. O mock agora avança cursor/item bounds com alturas distintas para checkbox, combo e texto wrapped; asserts confirmam que a separação externa fica abaixo dos bounds, incluindo combo mais alto que texto Operational e status de aviso multi-linha mais alto que o combo. Resultados 620/639/722 acima são checkpoints anteriores, não contagem desta correção.

## Histórico de validação anterior (não é resultado desta rodada)

- Em 2026-10-19, após a alteração focada de chrome, `tools/test_main_window.lua` passou com 545 verificações headless; revisão anterior registrou rodada final 11/12 testes, com `test_ui_smoke.lua` bloqueado pela fixture preexistente ausente, além de sintaxe nos 84 arquivos. Esses números são evidência histórica, não resultado da fase 1 atual.
- A fase anterior não executou instalação ou validação visual CSP. A entrada de `lib/uilib/UIControls.lua` em `tools/payload.manifest` é explícita; os asserts do manifesto comprovam apenas o arquivo-fonte, não instalação ou rendering.
