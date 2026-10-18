$ErrorActionPreference = 'Stop'

$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Harness output bypasses the mocked global Write-Host so it is never swallowed.
function Write-Harness([string]$Message) { Microsoft.PowerShell.Utility\Write-Host $Message }

$approvedRoot = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $approvedRoot -PathType Container)) { throw "Approved installer sandbox is unavailable: $approvedRoot" }
$sandbox = Join-Path $approvedRoot ('sotd-progress-tests-' + [guid]::NewGuid().ToString('N'))
$sandboxFull = [IO.Path]::GetFullPath($sandbox)
if (-not $sandboxFull.StartsWith([IO.Path]::GetFullPath($approvedRoot), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Progress installer test sandbox escaped the approved temporary directory.'
}

# Global Write-Host is buffered so installer progress output can be asserted on.
# It is removed in the finally block so it never leaks into another test run.
$global:SotdProgressOutput = ''
function global:Write-Host {
    param([string]$Message)
    $global:SotdProgressOutput += [string]$Message + "`n"
}

function Write-ProgressPackage {
    param([string]$Root, [hashtable]$Payload)
    [void][IO.Directory]::CreateDirectory($Root)
    $payloadRoot = Join-Path $Root 'payload/SimOpenTrackDay'
    foreach ($relative in $Payload.Keys) {
        $path = Join-Path $payloadRoot ($relative -replace '/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        [IO.File]::WriteAllText($path, [string]$Payload[$relative], (New-Object Text.UTF8Encoding($false)))
    }
    $checksums = New-Object System.Collections.ArrayList
    foreach ($relative in ($Payload.Keys | Sort-Object)) {
        $path = Join-Path $payloadRoot ($relative -replace '/', '\')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$checksums.Add("$hash  payload/SimOpenTrackDay/$relative")
    }
    [IO.File]::WriteAllLines((Join-Path $Root 'checksums.sha256'), [string[]]$checksums.ToArray(), (New-Object Text.UTF8Encoding($false)))
}

function New-ProgressEnvironment {
    param([string]$Name)
    $base = Join-Path $sandbox $Name
    $package = Join-Path $base 'package ! & source'
    $acRoot = Join-Path $base 'Assetto Corsa ! & sandbox'
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
    Write-ProgressPackage $package $payload
    [IO.File]::WriteAllText((Join-Path $target 'manifest.ini'), 'old-manifest-version')
    [IO.File]::WriteAllText((Join-Path $target 'SimOpenTrackDay.lua'), 'old-entry-version')
    [IO.File]::WriteAllText((Join-Path $target 'LICENSE'), 'old-license')
    return @{ Base = $base; Package = $package; ACRoot = $acRoot; Target = $target; Payload = $payload }
}

try {
    [void][IO.Directory]::CreateDirectory($sandbox)

    $installerPath = Join-Path $PSScriptRoot 'distribution/installer.ps1'
    $installerText = [IO.File]::ReadAllText($installerPath)
    . $installerPath -LibraryOnly:$true

    Assert ($null -ne (Get-Command Write-SotdProgress -ErrorAction SilentlyContinue)) 'progress helper is defined'
    Assert ($installerText.Contains('[switch]$ShowProgress')) 'installer exposes the -ShowProgress switch'
    Assert ($installerText.Contains('[switch]$Quiet')) 'installer exposes the -Quiet switch'
    Assert ([bool]$ShowProgress -eq $false) 'progress defaults to off when the switch is not supplied'

    # 1) ShowProgress on: the install plan reports Backing up and Installing stages with indices.
    $install = New-ProgressEnvironment 'show-progress'
    Set-SotdPackageRoot $install.Package
    $ShowProgress = $true
    $Quiet = $false
    $plan = Get-SotdPayloadPlan $install.Target
    $global:SotdProgressOutput = ''
    $installJournal = Install-SotdPlan -Plan $plan -TargetRoot $install.Target -AssettoCorsaRoot $install.ACRoot `
        -BackupRoot (Join-Path $install.Base 'backup') -RequestedJournalPath (Join-Path $install.Base 'journal.json')
    $installOutput = $global:SotdProgressOutput
    Assert ($installOutput -match '\[1/3\] Backing up ') 'install reports the first of three backups'
    Assert ($installOutput -match '\[3/3\] Backing up ') 'install reports the last of three backups'
    Assert ($installOutput -match '\[1/4\] Installing ') 'install reports the first of four installs'
    Assert ($installOutput -match '\[4/4\] Installing ') 'install reports the last of four installs'
    Assert ($installOutput.Contains('Backing up LICENSE')) 'install progress names the backed up path'
    Assert ($installOutput.Contains('Installing nested/path with spaces.lua')) 'install progress names a new nested path'
    Assert ($installOutput -match '\(elapsed \d+s\)') 'install progress reports elapsed seconds'

    # Index monotonicity: with four changed entries the install indices appear in order 1..4.
    $installIndices = @([regex]::Matches($installOutput, '\[(\d+)/4\] Installing') | ForEach-Object { [int]$_.Groups[1].Value })
    Assert (($installIndices -join ',') -eq '1,2,3,4') 'install indices are monotonic from 1 to N'

    # 2) ShowProgress on: the rollback reports each restored/removed path.
    $global:SotdProgressOutput = ''
    Invoke-SotdRollback -AssettoCorsaRoot $install.ACRoot -JournalPath $installJournal
    $rollbackOutput = $global:SotdProgressOutput
    Assert ($rollbackOutput -match '\[1/4\] Rolling back ') 'rollback reports the first of four entries'
    Assert ($rollbackOutput -match '\[4/4\] Rolling back ') 'rollback reports the last of four entries'
    Assert ($rollbackOutput.Contains('Rolling back LICENSE')) 'rollback progress names the restored path'

    # 3) Default (no -ShowProgress) must stay silent so existing headless callers are unaffected.
    $default = New-ProgressEnvironment 'default-silent'
    Set-SotdPackageRoot $default.Package
    $ShowProgress = $false
    $Quiet = $false
    $global:SotdProgressOutput = ''
    $defaultJournal = Install-SotdPlan -Plan (Get-SotdPayloadPlan $default.Target) -TargetRoot $default.Target `
        -AssettoCorsaRoot $default.ACRoot -BackupRoot (Join-Path $default.Base 'backup') -RequestedJournalPath (Join-Path $default.Base 'journal.json')
    Assert (-not ($global:SotdProgressOutput -match '\[\d+/\d+\]')) 'default install prints no progress lines'
    Assert (Test-Path -LiteralPath $defaultJournal -PathType Leaf) 'default install still completes'

    # 4) Quiet suppresses progress even when ShowProgress is explicitly enabled.
    $quietCase = New-ProgressEnvironment 'quiet'
    Set-SotdPackageRoot $quietCase.Package
    $ShowProgress = $true
    $Quiet = $true
    $global:SotdProgressOutput = ''
    $quietCaseJournal = Install-SotdPlan -Plan (Get-SotdPayloadPlan $quietCase.Target) -TargetRoot $quietCase.Target `
        -AssettoCorsaRoot $quietCase.ACRoot -BackupRoot (Join-Path $quietCase.Base 'backup') -RequestedJournalPath (Join-Path $quietCase.Base 'journal.json')
    Assert (-not ($global:SotdProgressOutput -match '\[\d+/\d+\]')) '-Quiet suppresses progress lines'
    Assert (Test-Path -LiteralPath $quietCaseJournal -PathType Leaf) '-Quiet still performs the install work'

    # 5) Read-only Preview never prints progress, even with -ShowProgress enabled.
    $preview = New-ProgressEnvironment 'preview-silent'
    Set-SotdPackageRoot $preview.Package
    $ShowProgress = $true
    $Quiet = $false
    $previewBackup = Join-Path $preview.Base 'backup'
    $global:SotdProgressOutput = ''
    Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $preview.ACRoot -BackupRoot $previewBackup -ShowProgress:$true | Out-Null
    Assert (-not ($global:SotdProgressOutput -match '\[\d+/\d+\]')) 'preview prints no progress lines'
    Assert (-not (Test-Path -LiteralPath $previewBackup)) 'preview still creates no backup'

    # 6) Total of zero is a safe no-op.
    $global:SotdProgressOutput = ''
    Write-SotdProgress -Stage 'Installing' -Index 1 -Total 0 -Path 'nothing.lua' -StartedUtc $null -Quiet:$false
    Assert ($global:SotdProgressOutput -eq '') 'a zero total prints nothing'

    # 7) The installer script retains its UTF-8 BOM after the progress change.
    $installerBytes = [IO.File]::ReadAllBytes($installerPath)
    Assert ($installerBytes.Length -ge 3 -and $installerBytes[0] -eq 239 -and $installerBytes[1] -eq 187 -and $installerBytes[2] -eq 191) 'installer script retains its UTF-8 BOM'

    Write-Harness "Installer progress tests passed: $checks checks."
} finally {
    Remove-Item Function:\global:Write-Host -ErrorAction SilentlyContinue
    Remove-Variable SotdProgressOutput -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
