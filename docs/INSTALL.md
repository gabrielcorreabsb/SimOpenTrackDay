# SimOpenTrackDay — instalação

O instalador copia os arquivos de runtime listados em `tools/payload.manifest` para `<Assetto Corsa>\apps\lua\SimOpenTrackDay\`. **Nunca copie os módulos diretamente para a raiz do jogo:** arquivos homônimos ali podem ser carregados antes dos módulos atuais e deixar as abas vazias. Veja o [incidente e o plano de prevenção](plans/MODULE_LOADING_HARDENING.md).

O instalador atual apaga o conteúdo da pasta de destino antes de copiar. Não oferece backup nem rollback automático. Feche o jogo e o launcher, faça backup da instalação existente e preserve as configurações antes de prosseguir.

## Requisitos

- Windows com PowerShell 5.1 (padrão do Windows 10/11).
- Uma instalação do Assetto Corsa (Steam, Epic ou GOG) que já contenha `apps\lua\` — qualquer versão que rode com CSP.

## Como instalar

1. No checkout, abra `tools\install.bat`. Uma janela do terminal vai abrir.
2. Quando pedir o caminho da instalação, informe a **raiz do Assetto Corsa**, sem acrescentar `apps\lua`. Exemplos:
   - Steam: `D:\Steam\steamapps\common\assettocorsa`
   - Outra instalação: `C:\Jogos\AssettoCorsa`
3. Confira o destino exibido: `<raiz informada>\apps\lua\SimOpenTrackDay\`. O script acrescenta `apps\lua` automaticamente.
4. Digite `YES` e pressione Enter para confirmar; a comparação não diferencia maiúsculas de minúsculas. Qualquer outra resposta cancela.
5. Leia o resultado. O `.bat` aguarda uma tecla ao final; confirme que a cópia terminou sem erro antes de abrir o jogo.

Embora o parâmetro receba a raiz do jogo, os arquivos são copiados somente para a pasta do app. Se for instalar manualmente, use esse mesmo destino e o payload listado no manifest; não extraia o repositório inteiro na raiz do AC.

## Como atualizar

Faça um novo backup, feche o jogo/launcher e execute `tools\install.bat` novamente. O instalador substitui o conteúdo da pasta do app; arquivos adicionais colocados nela também serão removidos. Não é necessário apagar a instalação manualmente antes. As configurações externas à pasta do app não devem ser apagadas para atualizar ou diagnosticar a UI.

## Se der erro

A janela mostra uma mensagem curta. O motor PowerShell registra o destino, operações de cópia e a mensagem de erro em

```
%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs\installer-yyyyMMdd-HHmmss.txt
```

Para abrir:

1. Pressione Win+R, digite `%LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs` e dê Enter.
2. Abra o arquivo `.txt` mais recente num editor de texto (Notepad serve).

Erros comuns:

- **`Folder not found` / `Assetto Corsa root not found`** — confira o caminho da instalação.
- **`Missing apps\lua under` / `Expected apps\lua folder under`** — informe a raiz do jogo que contém `apps\lua`, não a própria pasta `apps\lua`.
- **`Aborted`** — a confirmação não foi `YES`; nada foi instalado nessa execução.
- **Acesso negado** — feche jogo/launcher e confira as permissões; a mensagem sozinha não determina a causa.
- **Abas vazias / `drawContent` nil** — siga o [troubleshooting](TESTING.md#6-operational-troubleshooting). Reinstalar somente a pasta do app não remove cópias conflitantes de módulos na raiz do jogo. O instalador atual ainda não detecta essa situação automaticamente.

## O que o instalador copia

Tudo o que está listado em `tools/payload.manifest`: módulos Lua da raiz do mod, `manifest.ini`, `LICENSE` e os caminhos de runtime das subpastas declaradas. A lista é a fonte de verdade; não copie arquivos de desenvolvimento por associação de nome. Para adicionar um arquivo de runtime, inclua seu caminho relativo no manifest e revise o payload.

## Para desenvolvedores

`installer.ps1` é o motor. Pode ser chamado direto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\installer.ps1" -AssettoCorsaRoot "C:\Jogos\AssettoCorsa"
```

O motor chamado diretamente **não pede a confirmação `YES`**: ela pertence ao `.bat`. Revise o destino e faça backup antes de executar esse comando. Você sempre informa a raiz da instalação; o script define o destino dentro de `apps\lua`.

Verificações locais estão em `tools/test_*.lua` e `tools/check_lua_syntax.ps1`, com limites descritos em [Testing](TESTING.md). O instalador não valida carregamento, renderização ou comportamento no CSP. Para desfazer uma atualização, feche o jogo e restaure manualmente o backup da pasta do app, preservando as configurações.
