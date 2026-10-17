# SimOpenTrackDay

SimOpenTrackDay é um app em Lua para Assetto Corsa, executado pelo Custom Shaders Patch (CSP). O projeto ajuda os carros controlados pela IA a ceder passagem e ultrapassar em sessões de track day, em vez de permanecerem sempre na linha de corrida.

Este é um projeto derivado independente, em desenvolvimento. Não é uma versão reescrita do zero nem um build publicado ou homologado. O `VERSION = 0.9.8` ainda presente no manifest é metadado herdado, não uma indicação de release estável. O comportamento em runtime e a apresentação visual no CSP ainda não foram validados in-game.

- [Instalação manual](#instalação-manual)
- [Uso básico](#uso-básico)
- [Testes locais](#testes-locais)
- [Contribuição](CONTRIBUTING.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Testes detalhados](docs/TESTING.md) · [Onboarding](docs/AGENT.md)
- [Reportar um problema](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues)

## O que o app oferece

- Lógica de yield e overtake para carros IA, com offsets laterais configuráveis.
- Perfis de comportamento e opções de condução em `SettingsWindow.lua`.
- Configurações associadas à pista e ao tipo de sessão por meio de `StorageManager`.
- Janela principal com lista de carros e ferramentas de diagnóstico; a interface de configurações é separada.

O resultado depende da pista, da sessão e das APIs disponíveis na versão instalada do CSP. Consulte [Testing](docs/TESTING.md) antes de experimentar e não trate os checks headless como validação in-game.

## Requisitos

- Assetto Corsa para PC.
- Custom Shaders Patch (CSP) instalado e habilitado para Lua Apps.
- Uso somente em sessões offline; o app não é executável em sessões online/multiplayer.
- LuaJIT 2.1 é necessário para executar os checks locais; o app é carregado pelo ambiente Lua do CSP.

O entry point registra funções CSP exigidas pelo app e verifica compatibilidade. Este README não fixa uma versão mínima de CSP; consulte os avisos do app/CSP e os resultados em runtime.

## Instalação manual

O repositório contém o código-fonte na raiz; a pasta de instalação do app é `apps/lua/SimOpenTrackDay/`. Faça uma cópia manual do payload de runtime:

- arquivos `.lua` de runtime na raiz, incluindo `SimOpenTrackDay.lua`;
- `manifest.ini` e `LICENSE`;
- pastas `CarStateMachine/`, `DataStructures/`, `Strings/` e `lib/`.

A instalação deve conter `apps/lua/SimOpenTrackDay/SimOpenTrackDay.lua` — o nome do diretório e o do entry point devem corresponder. Não copie os metadados do Git (diretórios `.git/` ou arquivos `.git`), `tools/`, `docs/`, `artifacts/` ou arquivos `*.bak`. O código do submódulo de compatibilidade em `lib/AssettoCorsaCSPLuaCompatibilityManager/` faz parte do runtime; não copie os metadados Git do submódulo.

Preserve instalações e configurações existentes. Use uma pasta de app separada para testar; não remova ou substitua diretórios antigos nem redefina dados do usuário como parte da instalação ou rollback.

### Clonar para desenvolvimento

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
cd SimOpenTrackDay
git submodule update --init --recursive
```

A cópia recursiva obtém o submodule de compatibilidade. O SDK CSP está em `lib/ac_apps/`; ele é código vendor e não deve ser editado como código do app.

## Uso básico

1. Instale manualmente os arquivos de runtime e habilite SimOpenTrackDay entre as Lua Apps do CSP.
2. Inicie uma sessão offline com carros IA em uma pista compatível com AI spline. O app não roda online/multiplayer.
3. Abra a janela do app pelo sidebar do Assetto Corsa. Use a janela de configurações para conferir o estado de habilitação e ajustar opções disponíveis.

A lista de carros e opções de diagnóstico podem ter custo de renderização. Para investigação, habilite apenas o que for necessário e desative as opções de debug ao terminar. A interação e os resultados precisam ser confirmados no CSP; este guia não afirma validação visual.

## Estrutura do projeto

```text
SimOpenTrackDay.lua       entry point e callbacks do manifest
SettingsWindow.lua        interface de configurações
StorageManager.lua        opções, perfis e storage por pista/sessão
CarManager.lua            estado/cache dos carros IA
CarOperations.lua         operações de yield/overtake e chamadas physics
CarStateMachine/          estados de comportamento dos carros
UIManager.lua              lista de carros e visualizações de debug
lib/uilib/                 componentes de UI próprios do projeto
lib/ac_apps/               SDK CSP distribuído
lib/AssettoCorsaCSPLuaCompatibilityManager/
                           submodule de compatibilidade
Strings/ DataStructures/  suporte de texto e estruturas
tools/ docs/               checks e documentação
```

Veja [Architecture](docs/ARCHITECTURE.md) para o fluxo de módulos e [State machine](docs/STATE_MACHINE.md) para os estados documentados.

## Testes locais

A partir da raiz do repositório, com LuaJIT no `PATH`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
luajit tools/test_ui_smoke.lua
luajit tools/test_logo_smoke.lua
```

O checker aceita `-LuaJitPath` e `-Root` opcionais. Os smoke tests usam mocks e verificam apenas os caminhos exercitados; não carregam Assetto Corsa/CSP nem validam rendering real. A comparação contra baseline original é opcional: defina `RTD_BASELINE_SETTINGS` com o caminho local do arquivo-fonte baseline antes de rodar `test_ui_smoke.lua`. A fixture versionada local continua sendo o padrão e não é atualizada automaticamente.

Os últimos resultados headless registrados são sintaxe 66, UI mock 542, logo mock 21 e comparação opcional com baseline 607. Esses números descrevem execuções anteriores, não uma garantia futura nem um teste in-game. Runtime CSP e validação visual permanecem pendentes.

## Créditos e licença

SimOpenTrackDay é um projeto derivado independente baseado em [Assetto Corsa Realistic Trackday](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday), criado por [Andreas Grech (`dreasgrech`)](https://github.com/dreasgrech). O projeto original é distribuído sob a licença MIT, copyright © 2025 Andreas Grech; consulte [`LICENSE`](LICENSE). O histórico Git e os créditos originais são preservados.

O submodule [AssettoCorsaCSPLuaCompatibilityManager](https://github.com/dreasgrech/AssettoCorsaCSPLuaCompatibilityManager) e o SDK CSP têm suas próprias origens/licenças; mantenha seus arquivos e avisos de licença intactos.
