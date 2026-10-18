# SimOpenTrackDay 0.1 — instalação manual

Esta é uma versão de preview de desenvolvimento. O instalador PowerShell tem modos Preview, Install e Rollback. Preview é o padrão; a execução exige caminhos informados pelo usuário e confirmação exata `YES`. Não há destino padrão nem garantia de compatibilidade/renderização CSP. O manifesto SHA-256 verifica integridade do payload, não autenticidade, assinatura dos scripts ou origem confiável.

## Conteúdo do pacote

Extraia o pacote completo para uma pasta de sua escolha, fora do checkout. Ele contém `payload/SimOpenTrackDay/`, `install.bat`, `installer.ps1`, este `INSTALL.md` e `checksums.sha256`. O payload não inclui Git, SDK nem vendor desnecessário; retém a dependência de compatibilidade CSP requerida em runtime e seu notice, além de `LICENSE` e notices aplicáveis. Testes e árvore geral de documentação não são incluídos no payload.

Use Windows PowerShell 5.1. Preserve backups e configurações antes de instalar. O instalador não deve apagar arquivos desconhecidos nem limpar/resetar armazenamento do usuário. Conflitos são recusados: pare e revise manualmente; não use exclusão, espelhamento ou purge para forçar instalação.

## 1. Preview (somente leitura)

Localize a raiz da instalação AC que contém `acs.exe`; não suponha uma localização Steam. Informe explicitamente a pasta extraída e a raiz AC:

```powershell
$package = "C:\caminho com espaços\SimOpenTrackDay-0.1"
$acRoot = "D:\caminho com espaços\Assetto Corsa"
& "$package\install.bat" -Mode Preview -AssettoCorsaRoot "$acRoot"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$package\installer.ps1" -Mode Preview -AssettoCorsaRoot "$acRoot"
```

Revise o plano, caminhos e conflitos. Preview não escreve arquivos de instalação.

### Como ler a saída (a janela fecha em duplo clique)

O instalador é um script PowerShell invocado por `powershell.exe -File`. Em duplo clique no `install.bat` ou no `installer.ps1`, o Windows abre a janela do console, executa e fecha imediatamente após a última linha — comportamento padrão do PowerShell quando não há prompt interativo. Apenas o modo Install pausa para a confirmação `YES`; Preview e Rollback encerram logo depois de imprimir o resultado.

Para conseguir ler a saída, escolha uma das opções:

- **Salvar em arquivo de log** (mais simples para revisar depois):

  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$package\installer.ps1" -Mode Preview -AssettoCorsaRoot "$acRoot" *> "D:\preview.txt"
  notepad "D:\preview.txt"
  ```

  `*>` redireciona stdout e stderr para o mesmo arquivo.

- **Abrir o PowerShell manualmente** (Win+R → `powershell.exe` → Enter) e rodar o comando direto; a janela fica aberta durante a execução e você rola para cima para ver tudo.

- **Manter a saída na mesma janela** usando `Start-Process -Wait -NoNewWindow`:

  ```powershell
  Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$package\installer.ps1",'-Mode','Preview','-AssettoCorsaRoot',"$acRoot" -Wait -NoNewWindow
  ```

Em todas as três formas, o instalador continua sendo o mesmo; o que muda é só como você captura/visualiza a saída. Erros são sempre impressos em stderr antes de fechar.

## 2. Instalar (após revisão e backup)

`-BackupRoot` é opcional; sem ele, o instalador escolhe uma pasta de backup no perfil do usuário. O journal fica no backup por padrão. Informe caminho explícito se desejado. A raiz AC precisa conter `acs.exe` ou `acs_x86.exe` e `apps`; o destino é `<raiz>\apps\lua\SimOpenTrackDay`.

```powershell
$backup = "D:\backups\SimOpenTrackDay"
& "$package\install.bat" -Mode Install -AssettoCorsaRoot "$acRoot" -BackupRoot "$backup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$package\installer.ps1" -Mode Install -AssettoCorsaRoot "$acRoot" -BackupRoot "$backup"
```

Leia o plano e digite `YES` somente se concordar. Registre o caminho do journal para rollback. Instalação é ação do usuário; agentes não devem executá-la.

## 3. Rollback

Use o journal da transação e a mesma raiz AC:

```powershell
$journal = "D:\backups\SimOpenTrackDay\SimOpenTrackDay-<id>.json"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$package\installer.ps1" -Mode Rollback -AssettoCorsaRoot "$acRoot" -JournalPath "$journal"
```

O backup associado é lido do journal. Não remova journal/backups antes de confirmar o resultado. Em conflito/erro, pare e preserve arquivos e journal para inspeção; o rollback não promete remover todos os arquivos temporários/empty directories remanescentes. Não force remoção automatizada nem apague arquivos desconhecidos.

## Troubleshooting

Sintomas comuns durante o uso da versão instalada no Assetto Corsa. Esta seção **não** é sobre erros do instalador PowerShell (esses aparecem em stderr antes do instalador fechar a janela); é sobre erros runtime Lua depois que o app já está carregando dentro do AC.

### Sintoma: `UI draw failed: .../MainWindow.lua:165: attempt to call field 'drawContent' (a nil value)`

O traceback indica que, na primeira frame, `MainWindow.lua:165` chama `SettingsWindow.drawContent(…)`, mas o campo `drawContent` não existe na tabela `SettingsWindow` que foi carregada. A fonte atual (commit `e855e3d`) define `SettingsWindow.drawContent` em `SettingsWindow.lua:471`, então **a fonte está consistente**. O sintoma aponta para **payload instalado desatualizado** no destino AC, normalmente um `apps/lua/SimOpenTrackDay/SettingsWindow.lua` deixado por uma versão anterior do app, quando `SettingsWindow` ainda era um módulo procedural sem o campo `drawContent`.

**Como confirmar antes de qualquer reinstalação:**

```powershell
# 1. Hash do SettingsWindow.lua no pacote extraído
Get-FileHash -LiteralPath "C:\pacote\extraido\payload\SimOpenTrackDay\SettingsWindow.lua" -Algorithm SHA256

# 2. Hash do SettingsWindow.lua instalado no destino AC
Get-FileHash -LiteralPath "<raiz AC>\apps\lua\SimOpenTrackDay\SettingsWindow.lua" -Algorithm SHA256

# 3. Hash esperado (consta em checksums.sha256 do pacote)
Select-String -Path "C:\pacote\extraido\checksums.sha256" -Pattern "SettingsWindow\.lua$"
```

- Se **(2)** for diferente de **(1)** e de **(3)**: payload desatualizado. Vá para "Correção" abaixo.
- Se **(2)** for igual a **(1)** e **(3)**: a fonte está alinhada; a causa é outra (CSP hook injetando módulo customizado, conflito com outro mod Lua em `apps/lua`, ou erro de parse silencioso em outro módulo carregado antes do `MainWindow`). Preserve `apps/lua/SimOpenTrackDay` para inspeção, capture o `ac.log` do CSP e investigue.

**Correção para payload desatualizado:**

```powershell
# Faça backup manual do apps\lua\SimOpenTrackDay antes (precaução):
Copy-Item -LiteralPath "<raiz AC>\apps\lua\SimOpenTrackDay" -Destination "<backup manual>" -Recurse

# Remova a pasta de instalação antiga e re-instale:
Remove-Item -LiteralPath "<raiz AC>\apps\lua\SimOpenTrackDay" -Recurse -Force
& "C:\pacote\extraido\install.bat" -Mode Install -AssettoCorsaRoot "<raiz AC>"
# quando pedir confirmação, digite YES
```

Reinstale via `install.bat -Mode Install` para que o caminho `New` force substituição completa. Preview antes (`-Mode Preview`) deve listar todos os arquivos Lua como `New` (não `Changed`) se a remoção manual foi efetiva.

### Sintoma: app não abre / janela some imediatamente / erro genérico em `ac.log`

Capture o `ac.log` do CSP (`Documents\Assetto Corsa\logs\ac.log.0` ou similar) e verifique se há linhas `UI draw failed:` diferentes das listadas acima, ou erros `module '…' not found`. Preserve a pasta `apps/lua/SimOpenTrackDay` no destino AC para inspeção manual antes de qualquer reinstalação.

## Build e validação

`tools/build_package.ps1` usa o checkout como `-SourceRoot` padrão e exige `-OutputPath` novo, externo à fonte, com diretório pai já existente. Sem `-Build`, apenas preview; com `-Build`, gera o pacote sem sobrescrever destino existente. O payload declarado contém 66 arquivos. Checksums abrangem somente runtime payload.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\build_package.ps1" -OutputPath "D:\deliveries\SimOpenTrackDay-0.1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\build_package.ps1" -OutputPath "D:\deliveries\SimOpenTrackDay-0.1" -Build
```

`tools/test_package.ps1`, `tools/test_installer.ps1` e `tools/test_distribution.ps1` usam sandbox/mocks sob `%LOCALAPPDATA%\Temp\opencode`; `test_distribution.ps1` integra o pacote com a fonte real. Nenhum deles valida instalação real nem CSP. Rendering e comportamento CSP permanecem para validação manual pelo usuário, preservando instalações e settings existentes.
