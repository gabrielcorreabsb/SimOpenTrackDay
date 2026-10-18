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

## Build e validação

`tools/build_package.ps1` usa o checkout como `-SourceRoot` padrão e exige `-OutputPath` novo, externo à fonte, com diretório pai já existente. Sem `-Build`, apenas preview; com `-Build`, gera o pacote sem sobrescrever destino existente. O payload declarado contém 66 arquivos. Checksums abrangem somente runtime payload.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\build_package.ps1" -OutputPath "D:\deliveries\SimOpenTrackDay-0.1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\build_package.ps1" -OutputPath "D:\deliveries\SimOpenTrackDay-0.1" -Build
```

`tools/test_package.ps1` e `tools/test_installer.ps1` usam sandbox/mocks sob `%LOCALAPPDATA%\Temp\opencode`; não validam instalação real nem CSP. `tools/test_distribution.ps1` é o teste de integração com arquivos-fonte reais e permanece pendente de implementação/execução. Rendering e comportamento CSP permanecem para validação manual pelo usuário, preservando instalações e settings existentes.
