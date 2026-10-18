$ErrorActionPreference = 'Stop'

$approvedRoot = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $approvedRoot -PathType Container)) { throw "Approved installer sandbox is unavailable: $approvedRoot" }
$sandbox = Join-Path $approvedRoot ('sotd-installer-tests-' + [guid]::NewGuid().ToString('N'))
$sandboxFull = [IO.Path]::GetFullPath($sandbox)
if (-not $sandboxFull.StartsWith([IO.Path]::GetFullPath($approvedRoot), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Installer test sandbox escaped the approved temporary directory.'
}

function global:Read-Host {
    param([string]$Prompt)
    return $global:SotdInstallerConfirmation
}

function global:Copy-Item {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$Force
    )
    if ($global:SotdCopyFailureRegex -and -not $global:SotdCopyFailureTriggered -and $Destination -match $global:SotdCopyFailureRegex) {
        [IO.File]::WriteAllText($Destination, 'partial-copy', (New-Object Text.UTF8Encoding($false)))
        $global:SotdCopyFailureTriggered = $true
        throw 'Injected sandbox copy interruption.'
    }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force -ErrorAction Stop
}

function Write-TestPackage {
    param([string]$Root, [hashtable]$Payload, [string[]]$Unlisted = @())
    [void][IO.Directory]::CreateDirectory($Root)
    $installerCopy = Join-Path $Root 'installer.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'distribution/installer.ps1') -Destination $installerCopy
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'distribution/install.bat') -Destination (Join-Path $Root 'install.bat')
    $payloadRoot = Join-Path $Root 'payload/SimOpenTrackDay'
    foreach ($relative in $Payload.Keys) {
        $path = Join-Path $payloadRoot ($relative -replace '/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        [IO.File]::WriteAllText($path, [string]$Payload[$relative], (New-Object Text.UTF8Encoding($false)))
    }
    foreach ($relative in $Unlisted) {
        $path = Join-Path $payloadRoot ($relative -replace '/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        [IO.File]::WriteAllText($path, 'unlisted extra', (New-Object Text.UTF8Encoding($false)))
    }
    $checksums = New-Object System.Collections.ArrayList
    foreach ($relative in ($Payload.Keys | Sort-Object)) {
        $path = Join-Path $payloadRoot ($relative -replace '/', '\')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$checksums.Add("$hash  payload/SimOpenTrackDay/$relative")
    }
    [IO.File]::WriteAllLines((Join-Path $Root 'checksums.sha256'), [string[]]$checksums.ToArray(), (New-Object Text.UTF8Encoding($false)))
}

function New-TestEnvironment {
    param([string]$Name, [string[]]$Unlisted = @())
    $base = Join-Path $sandbox $Name
    $package = Join-Path $base 'source with spaces ! & signs'
    $acRoot = Join-Path $base 'Assetto Corsa sandbox ! & spaces'
    $target = Join-Path $acRoot 'apps/lua/SimOpenTrackDay'
    [void][IO.Directory]::CreateDirectory((Join-Path $acRoot 'apps'))
    [void][IO.Directory]::CreateDirectory($target)
    [IO.File]::WriteAllText((Join-Path $acRoot 'acs.exe'), 'sandbox executable marker')
    $payload = @{
        'manifest.ini' = 'new-manifest-version'
        'SimOpenTrackDay.lua' = 'new-entry-version'
        'LICENSE' = 'sandbox license'
        'nested/path with spaces.lua' = 'nested runtime payload'
    }
    Write-TestPackage $package $payload $Unlisted
    [IO.File]::WriteAllText((Join-Path $target 'manifest.ini'), 'old-manifest-version')
    [IO.File]::WriteAllText((Join-Path $target 'SimOpenTrackDay.lua'), 'old-entry-version')
    [IO.File]::WriteAllText((Join-Path $target 'LICENSE'), 'old-license')
    [IO.File]::WriteAllText((Join-Path $target 'user-settings.ini'), 'preserve user settings')
    [IO.File]::WriteAllText((Join-Path $target 'unknown-extra.bin'), 'preserve unknown file')
    return @{ Base = $base; Package = $package; ACRoot = $acRoot; Target = $target; Payload = $payload }
}

function Use-TestPackage {
    param([string]$Package)
    Set-SotdPackageRoot $Package
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    $didThrow = $false
    try { & $Action } catch { $didThrow = $true }
    if (-not $didThrow) { throw "Expected rejection: $Message" }
}

try {
    [void][IO.Directory]::CreateDirectory($sandbox)

    # Preview performs full source validation and reports the plan without creating anything.
    $case = New-TestEnvironment 'preview' @('not-listed.txt')
    $libraryPath = Join-Path $case.Package 'installer.ps1'
    . $libraryPath -Mode Preview -LibraryOnly:$true
    $backup = Join-Path $case.Base 'backup must stay absent'
    Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $case.ACRoot -BackupRoot $backup | Out-Null
    if (Test-Path -LiteralPath $backup) { throw 'Preview created the backup root.' }
    if ((Get-Content -LiteralPath (Join-Path $case.Target 'manifest.ini') -Raw) -ne 'old-manifest-version') { throw 'Preview modified an existing target.' }
    if (Test-Path -LiteralPath (Join-Path $case.Target 'nested')) { throw 'Preview created target directories.' }
    if (Test-Path -LiteralPath (Join-Path $case.Target 'not-listed.txt')) { throw 'Preview copied an unlisted source file.' }

    # Install uses exact YES confirmation, backs up replaced files, copies only listed files, and preserves extras/settings.
    $global:SotdInstallerConfirmation = 'YES'
    $backup = Join-Path $case.Base 'transaction backups'
    $journalPath = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $case.ACRoot -BackupRoot $backup
    if (-not (Test-Path -LiteralPath $journalPath -PathType Leaf)) { throw 'Install did not create a rollback journal.' }
    foreach ($relative in $case.Payload.Keys) {
        $targetPath = Join-Path $case.Target ($relative -replace '/', '\')
        if ((Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne
            (Get-FileHash -LiteralPath (Join-Path (Join-Path $case.Package 'payload/SimOpenTrackDay') ($relative -replace '/', '\')) -Algorithm SHA256).Hash.ToLowerInvariant()) {
            throw "Installed payload hash differs: $relative"
        }
    }
    if ((Get-Content -LiteralPath (Join-Path $case.Target 'user-settings.ini') -Raw) -ne 'preserve user settings') { throw 'Install changed user settings.' }
    if ((Get-Content -LiteralPath (Join-Path $case.Target 'unknown-extra.bin') -Raw) -ne 'preserve unknown file') { throw 'Install changed an unknown target file.' }
    if (Test-Path -LiteralPath (Join-Path $case.Target 'not-listed.txt')) { throw 'Install copied an unlisted source file.' }
    # Rollback restores only replaced files and removes only transaction-created payload files.
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $case.ACRoot -JournalPath $journalPath
    if ((Get-Content -LiteralPath (Join-Path $case.Target 'manifest.ini') -Raw) -ne 'old-manifest-version' -or
        (Get-Content -LiteralPath (Join-Path $case.Target 'SimOpenTrackDay.lua') -Raw) -ne 'old-entry-version' -or
        (Get-Content -LiteralPath (Join-Path $case.Target 'LICENSE') -Raw) -ne 'old-license') { throw 'Rollback did not restore replaced file contents.' }
    if (Test-Path -LiteralPath (Join-Path $case.Target 'nested/path with spaces.lua')) { throw 'Rollback left a transaction-created payload file behind.' }
    if ((Get-Content -LiteralPath (Join-Path $case.Target 'user-settings.ini') -Raw) -ne 'preserve user settings' -or
        (Get-Content -LiteralPath (Join-Path $case.Target 'unknown-extra.bin') -Raw) -ne 'preserve unknown file') { throw 'Rollback changed settings or an unknown file.' }

    # Mixed unchanged/changed/new entries must rollback without requiring a backup for the unchanged file.
    $mixed = New-TestEnvironment 'mixed-unchanged'
    Use-TestPackage $mixed.Package
    [IO.File]::WriteAllText((Join-Path $mixed.Target 'manifest.ini'), 'new-manifest-version')
    $global:SotdInstallerConfirmation = 'YES'
    $mixedJournal = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $mixed.ACRoot -BackupRoot (Join-Path $mixed.Base 'backup')
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $mixed.ACRoot -JournalPath $mixedJournal
    if ((Get-Content -LiteralPath (Join-Path $mixed.Target 'manifest.ini') -Raw) -ne 'new-manifest-version' -or
        (Get-Content -LiteralPath (Join-Path $mixed.Target 'LICENSE') -Raw) -ne 'old-license' -or
        (Test-Path -LiteralPath (Join-Path $mixed.Target 'nested/path with spaces.lua'))) {
        throw 'Mixed rollback did not leave unchanged files untouched while restoring changed/new files.'
    }

    # A partial install copy after an earlier replacement remains preserved; rollback restores completed work.
    $interruptedInstall = New-TestEnvironment 'interrupted-install'
    Use-TestPackage $interruptedInstall.Package
    $interruptedInstallBackup = Join-Path $interruptedInstall.Base 'backup'
    $interruptedInstallJournal = Join-Path $interruptedInstallBackup 'interrupted-install.json'
    $global:SotdCopyFailureRegex = 'SimOpenTrackDay\.lua\.[A-Fa-f0-9]{32}\.install\.tmp$'
    $global:SotdCopyFailureTriggered = $false
    try {
        Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $interruptedInstall.ACRoot -BackupRoot $interruptedInstallBackup -JournalPath $interruptedInstallJournal | Out-Null
        throw 'Expected injected install copy interruption.'
    } catch {
        if (-not $global:SotdCopyFailureTriggered) { throw }
    }
    $global:SotdCopyFailureRegex = $null
    if ((Get-Content -LiteralPath (Join-Path $interruptedInstall.Target 'LICENSE') -Raw) -ne 'sandbox license') { throw 'Failure injection did not occur after an earlier replacement.' }
    $interruptedJournalData = [IO.File]::ReadAllText($interruptedInstallJournal) | ConvertFrom-Json
    $partialInstallEntry = @($interruptedJournalData.Entries | Where-Object { $_.Status -eq 'Installing' })[0]
    $partialInstallPath = Join-Path $interruptedInstall.Target ($partialInstallEntry.InstallTempRelativePath -replace '/', '\')
    if ((Get-Content -LiteralPath $partialInstallPath -Raw) -ne 'partial-copy') { throw 'Expected partial install temp was not preserved.' }
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $interruptedInstall.ACRoot -JournalPath $interruptedInstallJournal
    if ((Get-Content -LiteralPath (Join-Path $interruptedInstall.Target 'LICENSE') -Raw) -ne 'old-license' -or
        (Get-Content -LiteralPath (Join-Path $interruptedInstall.Target 'SimOpenTrackDay.lua') -Raw) -ne 'old-entry-version' -or
        (Get-Content -LiteralPath $partialInstallPath -Raw) -ne 'partial-copy') {
        throw 'Interrupted install recovery failed or overwrote the incomplete temp.'
    }

    # An interrupted restore copy leaves its temp untouched; retry uses a fresh journaled restore temp.
    $interruptedRestore = New-TestEnvironment 'interrupted-restore'
    Use-TestPackage $interruptedRestore.Package
    $restoreJournal = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $interruptedRestore.ACRoot -BackupRoot (Join-Path $interruptedRestore.Base 'backup')
    $global:SotdCopyFailureRegex = '\.restore\.[A-Fa-f0-9]{32}\.tmp$'
    $global:SotdCopyFailureTriggered = $false
    try {
        Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $interruptedRestore.ACRoot -JournalPath $restoreJournal
        throw 'Expected injected restore copy interruption.'
    } catch {
        if (-not $global:SotdCopyFailureTriggered) { throw }
    }
    $global:SotdCopyFailureRegex = $null
    $interruptedRestoreData = [IO.File]::ReadAllText($restoreJournal) | ConvertFrom-Json
    $restoreEntry = @($interruptedRestoreData.Entries | Where-Object { $_.RelativePath -eq 'LICENSE' })[0]
    $partialRestoreRelative = @($restoreEntry.RestoreTempRelativePaths)[0]
    $partialRestorePath = Join-Path $interruptedRestore.Target ($partialRestoreRelative -replace '/', '\')
    if ((Get-Content -LiteralPath $partialRestorePath -Raw) -ne 'partial-copy') { throw 'Expected partial restore temp was not preserved.' }
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $interruptedRestore.ACRoot -JournalPath $restoreJournal
    if ((Get-Content -LiteralPath (Join-Path $interruptedRestore.Target 'LICENSE') -Raw) -ne 'old-license' -or
        (Get-Content -LiteralPath $partialRestorePath -Raw) -ne 'partial-copy') {
        throw 'Interrupted restore retry failed or overwrote the incomplete restore temp.'
    }

    # Cancellation writes no backup, journal, target file, or target directory.
    $cancel = New-TestEnvironment 'cancel'
    Use-TestPackage $cancel.Package
    $global:SotdInstallerConfirmation = 'yes'
    $cancelBackup = Join-Path $cancel.Base 'cancel-backup'
    $result = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $cancel.ACRoot -BackupRoot $cancelBackup
    if ($result -or (Test-Path -LiteralPath $cancelBackup) -or
        (Get-Content -LiteralPath (Join-Path $cancel.Target 'manifest.ini') -Raw) -ne 'old-manifest-version') {
        throw 'Non-exact confirmation did not cancel without writes.'
    }

    # Missing and tampered checksum-listed source files fail before any writes.
    $missing = New-TestEnvironment 'missing-source'
    Use-TestPackage $missing.Package
    Remove-Item -LiteralPath (Join-Path $missing.Package 'payload/SimOpenTrackDay/LICENSE')
    Assert-Throws { Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $missing.ACRoot -BackupRoot (Join-Path $missing.Base 'backup') } 'missing payload source'
    if (Test-Path -LiteralPath (Join-Path $missing.Base 'backup')) { throw 'Missing-source rejection wrote a backup.' }

    $tampered = New-TestEnvironment 'tampered-source'
    Use-TestPackage $tampered.Package
    [IO.File]::WriteAllText((Join-Path $tampered.Package 'payload/SimOpenTrackDay/manifest.ini'), 'tampered after checksum')
    Assert-Throws { Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $tampered.ACRoot -BackupRoot (Join-Path $tampered.Base 'backup') } 'tampered payload hash'

    # Empty, malformed, duplicate/case-colliding, and incomplete checksum manifests are rejected.
    $invalidChecksumCases = @(
        @{ Name = 'empty-checksums'; Lines = @('') },
        @{ Name = 'invalid-checksum'; Lines = @('not-a-hash  payload/SimOpenTrackDay/manifest.ini') },
        @{ Name = 'duplicate-checksum'; Lines = @('manifest.ini', 'manifest.ini') },
        @{ Name = 'case-collision-checksum'; Lines = @('manifest.ini', 'MANIFEST.INI') },
        @{ Name = 'incomplete-checksum'; Lines = @('LICENSE') }
    )
    foreach ($invalidCase in $invalidChecksumCases) {
        $invalid = New-TestEnvironment $invalidCase.Name
        Use-TestPackage $invalid.Package
        $checksumPath = Join-Path $invalid.Package 'checksums.sha256'
        $validLines = [IO.File]::ReadAllLines($checksumPath)
        $manifestLine = $validLines | Where-Object { $_ -match 'payload/SimOpenTrackDay/manifest\.ini$' } | Select-Object -First 1
        $licenseLine = $validLines | Where-Object { $_ -match 'payload/SimOpenTrackDay/LICENSE$' } | Select-Object -First 1
        if ($invalidCase.Name -eq 'empty-checksums') { [IO.File]::WriteAllText($checksumPath, '') }
        elseif ($invalidCase.Name -eq 'invalid-checksum') { [IO.File]::WriteAllText($checksumPath, $invalidCase.Lines[0]) }
        elseif ($invalidCase.Name -eq 'duplicate-checksum') { [IO.File]::WriteAllLines($checksumPath, @($manifestLine, $manifestLine)) }
        elseif ($invalidCase.Name -eq 'case-collision-checksum') {
            $upperLine = $manifestLine -replace 'manifest\.ini$', 'MANIFEST.INI'
            [IO.File]::WriteAllLines($checksumPath, @($manifestLine, $upperLine))
        }
        else { [IO.File]::WriteAllLines($checksumPath, @($licenseLine)) }
        Assert-Throws { Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $invalid.ACRoot } $invalidCase.Name
    }

    # Traversal checksum entries and source/target overlap are rejected pre-write.
    $traversal = New-TestEnvironment 'traversal'
    Use-TestPackage $traversal.Package
    $knownHash = (Get-FileHash -LiteralPath (Join-Path $traversal.Package 'payload/SimOpenTrackDay/LICENSE') -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $traversal.Package 'checksums.sha256'), "$knownHash  payload/SimOpenTrackDay/../outside.lua")
    Assert-Throws { Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $traversal.ACRoot } 'path traversal checksum'
    Use-TestPackage $traversal.Package
    Assert-Throws { Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $traversal.ACRoot -BackupRoot $traversal.Target } 'backup/target overlap'

    # A rollback conflict is detected across the complete plan before any rollback mutation.
    $conflict = New-TestEnvironment 'rollback-conflict'
    Use-TestPackage $conflict.Package
    $global:SotdInstallerConfirmation = 'YES'
    $conflictBackup = Join-Path $conflict.Base 'backup'
    $conflictJournal = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $conflict.ACRoot -BackupRoot $conflictBackup
    [IO.File]::WriteAllText((Join-Path $conflict.Target 'manifest.ini'), 'external conflicting edit')
    Assert-Throws { Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $conflict.ACRoot -JournalPath $conflictJournal } 'modified target conflict'
    if (-not (Test-Path -LiteralPath (Join-Path $conflict.Target 'nested/path with spaces.lua'))) { throw 'Rollback conflict partially removed a created file.' }
    if ((Get-Content -LiteralPath (Join-Path $conflict.Target 'SimOpenTrackDay.lua') -Raw) -ne 'new-entry-version') { throw 'Rollback conflict partially restored another file.' }

    # Directory collisions at temp paths and forged transaction roots fail preflight before target mutation.
    $tempConflict = New-TestEnvironment 'rollback-temp-directory'
    Use-TestPackage $tempConflict.Package
    $tempConflictJournal = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $tempConflict.ACRoot -BackupRoot (Join-Path $tempConflict.Base 'backup')
    $tempJournalData = [IO.File]::ReadAllText($tempConflictJournal) | ConvertFrom-Json
    $manifestEntry = @($tempJournalData.Entries | Where-Object { $_.RelativePath -eq 'manifest.ini' })[0]
    $tempConflictPath = Join-Path $tempConflict.Target ($manifestEntry.InstallTempRelativePath -replace '/', '\')
    [void][IO.Directory]::CreateDirectory($tempConflictPath)
    Assert-Throws { Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $tempConflict.ACRoot -JournalPath $tempConflictJournal } 'rollback temp directory conflict'
    if ((Get-Content -LiteralPath (Join-Path $tempConflict.Target 'manifest.ini') -Raw) -ne 'new-manifest-version' -or
        (Get-Content -LiteralPath (Join-Path $tempConflict.Target 'LICENSE') -Raw) -ne 'sandbox license') {
        throw 'Rollback temp directory conflict caused partial target mutation.'
    }
    Remove-Item -LiteralPath $tempConflictPath -Recurse -Force

    $forgedJournal = Join-Path (Split-Path -Parent $tempConflictJournal) 'forged-root.json'
    $tempJournalData.BackupTransactionRoot = Join-Path $tempConflict.Base 'escaped-backup'
    [IO.File]::WriteAllText($forgedJournal, (ConvertTo-Json -InputObject $tempJournalData -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Assert-Throws { Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $tempConflict.ACRoot -JournalPath $forgedJournal } 'forged backup transaction root'
    if ((Get-Content -LiteralPath (Join-Path $tempConflict.Target 'manifest.ini') -Raw) -ne 'new-manifest-version') {
        throw 'Forged journal root modified the target.'
    }
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $tempConflict.ACRoot -JournalPath $tempConflictJournal

    # A rollback journal temp path with a valid extension that is not owned by this transaction is rejected.
    $unownedTemp = New-TestEnvironment 'unowned-temp'
    Use-TestPackage $unownedTemp.Package
    $unownedJournal = Invoke-SotdInstaller -Mode Install -AssettoCorsaRoot $unownedTemp.ACRoot -BackupRoot (Join-Path $unownedTemp.Base 'backup')
    $unownedData = [IO.File]::ReadAllText($unownedJournal) | ConvertFrom-Json
    $licenseEntry = @($unownedData.Entries | Where-Object { $_.RelativePath -eq 'LICENSE' })[0]
    $licenseEntry.RestoreTempRelativePaths = @('not-listed.tmp')
    $unownedForged = Join-Path (Split-Path -Parent $unownedJournal) 'unowned-temp.json'
    [IO.File]::WriteAllText($unownedForged, (ConvertTo-Json -InputObject $unownedData -Depth 12), (New-Object Text.UTF8Encoding($false)))
    $unownedExternal = Join-Path (Join-Path $unownedTemp.Target 'preserved') 'outside.tmp'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $unownedExternal))
    [IO.File]::WriteAllText($unownedExternal, 'preserved external')
    Assert-Throws { Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $unownedTemp.ACRoot -JournalPath $unownedForged } 'unowned rollback temp path'
    if ((Get-Content -LiteralPath $unownedExternal -Raw) -ne 'preserved external') { throw 'Unowned temp rejection did not preserve the external file.' }
    if ((Get-Content -LiteralPath (Join-Path $unownedTemp.Target 'LICENSE') -Raw) -ne 'sandbox license') { throw 'Unowned temp rejection partially mutated the target.' }
    Invoke-SotdInstaller -Mode Rollback -AssettoCorsaRoot $unownedTemp.ACRoot -JournalPath $unownedJournal
    if ((Get-Content -LiteralPath $unownedExternal -Raw) -ne 'preserved external') { throw 'Successful rollback after unowned rejection still touched the external file.' }

    # Reparse-point rejection is exercised where the current account permits symlink creation.
    $linkCase = New-TestEnvironment 'reparse'
    Use-TestPackage $linkCase.Package
    $linkPath = Join-Path (Join-Path $linkCase.Package 'payload/SimOpenTrackDay') 'manifest.ini'
    $symlinkCreated = $false
    try {
        Remove-Item -LiteralPath $linkPath -Force
        New-Item -ItemType SymbolicLink -Path $linkPath -Target (Join-Path $linkCase.Package 'payload/SimOpenTrackDay/LICENSE') -ErrorAction Stop | Out-Null
        $symlinkCreated = $true
    } catch {
        if (Test-Path -LiteralPath $linkPath) { throw }
        Write-Host 'SKIP: symlink test unavailable to this account.'
    }
    if ($symlinkCreated) { Assert-Throws { Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $linkCase.ACRoot } 'payload reparse point' }

    Write-Host 'Installer sandbox tests passed.'
} finally {
    Remove-Item Function:\global:Read-Host -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Copy-Item -ErrorAction SilentlyContinue
    Remove-Variable SotdInstallerConfirmation -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable SotdCopyFailureRegex -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable SotdCopyFailureTriggered -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
