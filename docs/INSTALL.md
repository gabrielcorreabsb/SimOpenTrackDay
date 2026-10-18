# SimOpenTrackDay — instalação

O instalador copia a pasta `SimOpenTrackDay/` para dentro do `apps\lua\` do Assetto Corsa. É o único arquivo do mod distribuído ao usuário final; tudo o mais vive no repositório de desenvolvimento.

## Requisitos

- Windows com PowerShell 5.1 (padrão do Windows 10/11).
- Uma instalação do Assetto Corsa (Steam, Epic ou GOG) que já contenha `apps\lua\` — qualquer versão que rode com CSP.

## Como instalar

1. Dê duplo clique em `install.bat`. Uma janela preta do PowerShell vai abrir.
2. Quando pedir o caminho da pasta `apps\lua`, cole o caminho completo. Exemplos:
   - Steam: `D:\Steam\steamapps\common\assettocorsa\apps\lua`
   - Epic: `C:\Program Files\Epic Games\AssettoCorsa\apps\lua`
   - Custom: `C:\Jogos\AssettoCorsa\apps\lua`
3. O instalador mostra o que vai fazer (apagar a pasta `SimOpenTrackDay\` atual dentro de `apps\lua\` e copiar a nova).
4. Digite `YES` (exatamente, em maiúsculas) e pressione Enter para confirmar.
5. Espere a mensagem final. A janela fecha sozinha quando termina com sucesso.

## Como atualizar

É a mesma coisa. Rode `install.bat` de novo e cole o caminho. O instalador apaga a pasta antiga e coloca a nova — não precisa desinstalar antes.

## Se der erro

A janela mostra uma mensagem curta. O log completo (com o erro real e a stack trace do PowerShell) é gravado em

```
%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs\installer-AAAA-MM-DD-HH-MM-SS.txt
```

Para abrir:

1. Pressione Win+R, digite `%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs` e dê Enter.
2. Abra o arquivo `.txt` mais recente num editor de texto (Notepad serve).

Erros comuns:

- **`Caminho nao encontrado`** — você colou o caminho da raiz do AC (`...\assettocorsa`), não o de `apps\lua`. Cole o caminho completo até `apps\lua`.
- **`Confirmacao nao confere`** — você digitou outra coisa no lugar de `YES`. Rode de novo.
- **`Permissao negada`** — o Assetto Corsa está aberto. Feche o AC antes de instalar.

## O que o instalador copia

Tudo o que está listado em `tools/payload.manifest`. Hoje são 66 arquivos: 35 `.lua` na raiz do mod, mais `manifest.ini`, `LICENSE`, as subpastas `DataStructures/`, `Strings/`, `CarStateMachine/`, `lib/uilib/`, `lib/AssettoCorsaCSPLuaCompatibilityManager/` e `lib/i18n/*.lua`. Para adicionar um arquivo novo, edite `tools/payload.manifest` adicionando o caminho relativo — não precisa mexer em `install.bat` nem em `installer.ps1`.

## Para desenvolvedores

`installer.ps1` é o motor. Pode ser chamado direto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\installer.ps1" -AssettoCorsaRoot "C:\...\apps\lua"
```

Não instala em nenhuma pasta do AC automaticamente — você sempre informa o caminho. Testes de runtime Lua estão em `tools/test_*.lua` e `tools/check_lua_syntax.ps1`. Validação completa do app dentro do Assetto Corsa exige o jogo rodando; o instalador não testa isso.