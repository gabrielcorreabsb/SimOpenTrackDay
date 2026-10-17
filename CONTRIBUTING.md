# Contribuir

SimOpenTrackDay é um projeto derivado independente em desenvolvimento. Leia o [README](README.md) e os [créditos/licença](README.md#créditos-e-licença) antes de alterar ou redistribuir o projeto; preserve os avisos MIT do original e os créditos das dependências.

## Preparar o checkout

```sh
git clone --recurse-submodules https://github.com/gabrielcorreabsb/SimOpenTrackDay.git
cd SimOpenTrackDay
git submodule update --init --recursive
```

O payload do app fica na raiz do checkout. `apps/lua/SimOpenTrackDay/` é o caminho de instalação, não uma pasta a criar dentro do repositório. A cópia para o Assetto Corsa é manual; veja [Instalação no README](README.md#instalação-manual) e preserve instalações/configurações existentes.

## Fluxo de contribuição

- Faça alterações focadas; preserve os nove registros `[RTD-DIAG-*]`, contratos de storage e comportamento de compatibilidade sem evidência para removê-los.
- Mantenha o submodule `lib/AssettoCorsaCSPLuaCompatibilityManager/` e o SDK em `lib/ac_apps/` conforme suas origens e licenças. O SDK é vendor: não edite como código do app.
- Para bugs deste projeto, use o [issue tracker SimOpenTrackDay](https://github.com/gabrielcorreabsb/SimOpenTrackDay/issues). O [repositório upstream](https://github.com/dreasgrech/AssettoCorsaRealisticTrackday) é referência de origem/crédito; não use releases upstream como releases deste projeto nem envie alterações ao upstream sem autorização própria.

## Verificações locais

Com LuaJIT 2.1 disponível no `PATH`, execute da raiz:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/check_lua_syntax.ps1"
luajit tools/test_ui_smoke.lua
luajit tools/test_logo_smoke.lua
```

O checker aceita `-LuaJitPath` e `-Root`. Os testes UI/logo são headless com mocks; não validam o runtime nem o rendering do CSP. Para comparação opcional, `RTD_BASELINE_SETTINGS` pode apontar para um arquivo-fonte baseline disponível localmente antes de executar o smoke UI; não use caminhos pessoais em documentação ou issues. A fixture versionada é o padrão e não se atualiza a partir do código corrente.

Antes de compartilhar uma alteração, revise o diff e registre apenas checks realmente executados. Não declare validação in-game sem realizá-la. Este fluxo não configura remotes, faz commit/push, instala o app ou publica releases automaticamente.
