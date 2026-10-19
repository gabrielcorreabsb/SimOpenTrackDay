# Plano: prevenção de colisões no carregamento Lua

## Estado e escopo

Incidente resolvido no ambiente do usuário em **2026-10-18**, após a retirada de cópias antigas do projeto da raiz do Assetto Corsa. O usuário confirmou que a interface voltou a funcionar. Isso é confirmação manual limitada de carregamento/UI, não validação de todas as abas, idiomas, simulação ou desempenho.

**Somente o bootstrap foi implementado no código-fonte**, após a recuperação do incidente: `SimOpenTrackDay.lua` prioriza `__dirname` antes do primeiro `require`. A validação no CSP dessa alteração permanece pendente; a instalação do jogo não foi modificada nesta etapa. O instalador e a UI não foram alterados. Não mover módulos nem alterar manifest, callbacks, SDK, submódulo, persistência ou comportamento da IA para resolver este problema.

## Descobertas confirmadas

- O log registrava `UI draw failed` em `MainWindow.lua`, na chamada a `SettingsWindow.drawContent`, com `attempt to call field 'drawContent' (a nil value)`.
- O entrypoint e `MainWindow.lua` da cópia de teste eram novos, mas `Constants` retornava `RealisticTrackday 0.9.8`, não `SimOpenTrackDay 0.1`.
- O módulo carregado de configurações tinha `draw`, mas não `drawContent`; a origem registrada da função era `.\SettingsWindow.lua`.
- O `package.path` observado continha caminhos externos, incluindo `.\?.lua`, antes da pasta do app. Existia `LUA_PATH` definido no ambiente do usuário. `package.loaded` ainda não continha os três módulos inspecionados antes dos respectivos carregamentos.
- Havia cópias antigas de módulos diretamente na raiz do jogo. Assim, os `require` misturavam módulos antigos dessa raiz com os atuais em `apps/lua/SimOpenTrackDay/`.

Os logs e arquivos comprovam uma **colisão de resolução de módulos**. Renomear o app não bastou, pois os nomes internos dos módulos continuaram iguais. A hipótese inicial de cache como causa principal não foi confirmada; a limpeza de cache feita pelo usuário não resolveu o problema enquanto os arquivos conflitantes permaneciam presentes.

## Recuperação realizada e limites

Com autorização do usuário e o jogo/launcher fechados, foram removidos somente **37 arquivos diretamente na raiz do jogo**, identificados como pertencentes ao projeto. Antes da remoção, houve inventário, backup e comparação SHA-256; a identidade de 35 arquivos foi conferida contra objetos Git e a de dois pelo conteúdo. Outros arquivos e pastas da raiz foram preservados. `SettingsWindow.lua`, visto anteriormente na raiz, já não estava presente no inventário final e não integra esses 37 arquivos.

O backup local contém `cleanup-plan.json`, `cleanup-result.json`, os arquivos preservados e o log anterior à limpeza. Ele não é um artefato versionado nem deve ser redistribuído com dados pessoais. Nenhuma pasta de configurações ou storage foi apagada; nenhuma mudança de runtime foi necessária para a recuperação confirmada.

Após a remoção houve ainda um erro transitório procurando `.\Constants.lua`, já inexistente. A causa desse erro específico não foi estabelecida antes de o usuário informar o sucesso; não tratá-lo como prova de um mecanismo de cache nem prescrever alteração do preprocessador com base nele.

## Escopo aprovado e proposta não autorizada

O usuário aprovou **somente a prioridade da pasta real do app via `__dirname`**, antes dos primeiros `require`. A alteração do instalador abaixo não foi aprovada e não integra esta implementação. O relato adicional de borda cinza na UI deve ser investigado separadamente, sem ampliar o bootstrap para mudanças visuais.

### 1. Prioridade da pasta do app no bootstrap

**Escopo aprovado:** início de `SimOpenTrackDay.lua`, antes do primeiro `require` do projeto, e um teste focado em `tools/`.

- Obter a pasta efetiva do script por `__dirname`, documentado no SDK distribuído em `lib/ac_apps/lib.lua`, em vez de fixar `SimOpenTrackDay` ou um caminho de instalação.
- Prefixar `package.path` com os padrões dessa pasta (`?.lua` e `?/init.lua`), preservando os caminhos anteriores para dependências do CSP.
- Validar a disponibilidade/formato de `__dirname` no bootstrap real antes de fechar a implementação. Não substituir silenciosamente por `.` se a pasta não puder ser determinada.
- Não limpar `package.loaded` indiscriminadamente, substituir o loader global, alterar `LUA_PATH` do usuário ou adicionar busca/alocações por frame.

Essa é a primeira opção por ser pequena e atacar a precedência observada. Contudo, `package.path` não substitui módulos já presentes em `package.loaded`. O efeito sobre o preprocessamento/cache do CSP também precisa de validação real. Se o teste demonstrar resolução anterior ao bootstrap ou módulos já carregados incorretamente, reavaliar o mecanismo antes de introduzir outro workaround; não declarar isolamento completo apenas por prefixar o caminho.

**Evidência local da implementação:** `luajit tools/test_module_path.lua` passou usando o bootstrap real e módulos homônimos em sandbox, pasta renomeada com espaços, ambos os padrões de busca, barra final, preservação dos caminhos anteriores e limite de `package.loaded`. Valores de `__dirname` ausente, vazio, não-string ou composto só por separadores falham explicitamente antes de alterar `package.path`. A sintaxe passou em 80 arquivos. Dos nove testes Lua executados, oito passaram; `test_ui_smoke.lua` continua bloqueado pela ausência preexistente de `tools/fixtures/settings_baseline.lua`. Esses resultados não comprovam resolução de módulos ou renderização no CSP.

### 2. Preflight não destrutivo do instalador

**Não aprovado; fora da implementação atual.** Escopo apenas proposto: `tools/installer.ps1`, antes de `Reset-SotdTargetDirectory`, e teste PowerShell em sandbox.

- Procurar arquivos com nomes dos módulos do payload diretamente na raiz selecionada do AC, sem percorrer ou remover pastas do jogo.
- Reportar caminhos suspeitos e interromper a instalação antes de apagar/copiar a pasta do app, com orientação para revisão manual.
- Tratar coincidência de nome como suspeita, não como prova de propriedade. Nunca apagar, mover ou sobrescrever esses arquivos automaticamente.
- Manter a orientação de instalação exclusivamente em `apps/lua/SimOpenTrackDay/`, com backup prévio da instalação existente. O instalador atual substitui o conteúdo dessa pasta; não oferece rollback automático.

Esse preflight cobre a contaminação da raiz observada neste caso, não todos os diretórios externos que possam constar de `LUA_PATH`.

## Plano de execução e evidências

| Etapa | Responsável pela evidência | Aceite e limite |
| --- | --- | --- |
| Documentar incidente e instalação | Autor da documentação | Links e diff revisados; fatos, hipótese e proposta separados; sem alegar fix de runtime entregue. |
| Implementar bootstrap e teste focado | Implementador do bootstrap | LuaJIT com diretório externo contendo módulos homônimos e caminho externo inicialmente prioritário: carregar módulos da pasta do app; repetir com pasta renomeada e com espaços. Sem tocar na instalação real. |
| Exercitar cache de módulos | Implementador do bootstrap | Caso separado com `package.loaded` preenchido demonstra o limite ou a rejeição prevista, sem limpar módulos alheios. Mocks não provam o comportamento do loader CSP. |
| Preflight e teste focado — não aprovados | Sem execução nesta rodada | Se autorizados futuramente: sandbox com raiz limpa prossegue; raiz suspeita bloqueia antes de qualquer alteração do destino; arquivo suspeito e instalação existente permanecem intactos. |
| Reconciliar e verificar código | Integrador | Revisar o diff, executar sintaxe e verificações locais aplicáveis uma vez após reconciliar as mudanças. Não executar o instalador contra o jogo real como teste automatizado. |
| Confirmar no CSP | Usuário, instalação manual orientada | Inicialização a frio da cópia de teste, origem dos módulos dentro dela e conteúdo nas cinco abas, sem `drawContent` nil. Comparar ambiente limpo e colisão controlada reversível; nunca sobrescrever arquivos reais para provocar a falha. Se não houver reprodução segura no jogo, registrar essa limitação. |

Os marcadores de build/origem usados na investigação eram temporários. Qualquer nova instrumentação para a validação deve ter ciclo de remoção definido, sem reintroduzir um sistema de diagnóstico permanente incidentalmente.

## Fora de escopo

- Limpeza automática de arquivos do jogo, reset de configurações ou exclusão de caches como manutenção padrão.
- Alterar `FORCE_LUA_PREPROCESSOR`, `LAZY`, callback IDs ou `CSPCompatibilityManager.ShowErrorModalDialog = false` sem uma necessidade separadamente demonstrada.
- Refatorar todos os módulos para um namespace novo antes de testar a correção mínima.
- Corrigir deriva geral de ferramentas/testes ou afirmar que os cenários de IA/localização foram validados por este incidente.

Referências: [instalação](../INSTALL.md), [troubleshooting e testes](../TESTING.md#6-operational-troubleshooting).
