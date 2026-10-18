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
$sandbox = Join-Path $approvedRoot ('sotd-interactive-tests-' + [guid]::NewGuid().ToString('N'))
$sandboxFull = [IO.Path]::GetFullPath($sandbox)
if (-not $sandboxFull.StartsWith([IO.Path]::GetFullPath($approvedRoot), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Interactive installer test sandbox escaped the approved temporary directory.'
}

$global:SotdInteractiveInputs = New-Object System.Collections.Queue
$global:SotdInteractiveOutput = ''
$global:SotdInteractivePrompts = ''

function Set-SotdInteractiveInputs {
    param([string[]]$Inputs)
    $global:SotdInteractiveInputs = New-Object System.Collections.Queue
    foreach ($item in $Inputs) { [void]$global:SotdInteractiveInputs.Enqueue([string]$item) }
}

function Reset-SotdInteractiveOutput { $global:SotdInteractiveOutput = '' }

# Mirrors test_installer.ps1: global Read-Host is replaced so the menu consumes a
# preprogrammed input stack instead of blocking on the console.
function global:Read-Host {
    param([string]$Prompt)
    $global:SotdInteractivePrompts += ([string]$Prompt) + "`n"
    if ($global:SotdInteractiveInputs.Count -gt 0) { return [string]$global:SotdInteractiveInputs.Dequeue() }
    return ''
}

# Global Write-Host is buffered so menu/installer output can be asserted on.
# Restored (by removing the function) in the finally block.
function global:Write-Host {
    param([string]$Message)
    $global:SotdInteractiveOutput += [string]$Message + "`n"
}

function Write-InteractivePackage {
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

function New-InteractiveEnvironment {
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
    Write-InteractivePackage $package $payload
    [IO.File]::WriteAllText((Join-Path $target 'manifest.ini'), 'old-manifest-version')
    [IO.File]::WriteAllText((Join-Path $target 'SimOpenTrackDay.lua'), 'old-entry-version')
    [IO.File]::WriteAllText((Join-Path $target 'LICENSE'), 'old-license')
    return @{ Base = $base; Package = $package; ACRoot = $acRoot; Target = $target; Payload = $payload }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

try {
    [void][IO.Directory]::CreateDirectory($sandbox)

    $installerPath = Join-Path $PSScriptRoot 'distribution/installer.ps1'
    . $installerPath -LibraryOnly:$true

    Assert ($null -ne (Get-Command Show-SotdInteractiveMenu -ErrorAction SilentlyContinue)) 'interactive menu function is defined'
    Assert ($null -ne (Get-Command Invoke-SotdSelfTest -ErrorAction SilentlyContinue)) 'self-test function is defined'

    # 1) Preview through the menu performs a real read-only plan.
    $preview = New-InteractiveEnvironment 'preview'
    Set-SotdPackageRoot $preview.Package
    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('1', '', '5')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $preview.ACRoot -BackupRoot (Join-Path $preview.Base 'backup') -JournalPath (Join-Path $preview.Base 'journal.json')
    Assert ($global:SotdInteractiveOutput.Contains('SimOpenTrackDay installer')) 'menu prints the header'
    Assert ($global:SotdInteractiveOutput.Contains('New') -or $global:SotdInteractiveOutput.Contains('Changed') -or $global:SotdInteractiveOutput.Contains('Unchanged')) 'menu preview reports a payload plan'
    Assert ($global:SotdInteractiveOutput.Contains('Exiting installer')) 'menu option 5 exits the loop'
    Assert ((Get-Content -LiteralPath (Join-Path $preview.Target 'manifest.ini') -Raw) -eq 'old-manifest-version') 'menu preview leaves the target unchanged'

    # 2) Install through the menu replaces files, then rollback (menu) restores them.
    $install = New-InteractiveEnvironment 'install'
    Set-SotdPackageRoot $install.Package
    $installBackup = Join-Path $install.Base 'backup'
    $installJournal = Join-Path $install.Base 'journal.json'
    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('2', 'YES', '', '5')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $install.ACRoot -BackupRoot $installBackup -JournalPath $installJournal
    $installedHash = Get-Sha256 (Join-Path $install.Target 'manifest.ini')
    $packageHash = Get-Sha256 (Join-Path (Join-Path $install.Package 'payload/SimOpenTrackDay') 'manifest.ini')
    Assert ($installedHash -eq $packageHash) 'menu install replaces the payload file with the packaged contents'
    Assert (Test-Path -LiteralPath $installJournal -PathType Leaf) 'menu install creates the rollback journal'
    Assert ($global:SotdInteractiveOutput.Contains('Exiting installer')) 'menu returns after install and exits on option 5'

    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('3', '', '5')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $install.ACRoot -JournalPath $installJournal
    Assert ((Get-Content -LiteralPath (Join-Path $install.Target 'manifest.ini') -Raw) -eq 'old-manifest-version') 'menu rollback restores the original file contents'
    Assert (-not (Test-Path -LiteralPath (Join-Path $install.Target 'nested/path with spaces.lua'))) 'menu rollback removes a transaction-created payload file'

    # 3) Self-test option is headless and delegates to the placeholder.
    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('4', '', '5')
    Show-SotdInteractiveMenu
    Assert ($global:SotdInteractiveOutput.Contains('Self-test placeholder')) 'menu option 4 runs the self-test placeholder'
    Assert ((Invoke-SotdSelfTest) -eq 0) 'self-test placeholder returns exit code 0'

    # 4) Option 5 exits immediately.
    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('5')
    Show-SotdInteractiveMenu
    Assert ($global:SotdInteractiveOutput.Contains('Exiting installer')) 'menu exits immediately on option 5'

    # 5) Invalid selection is reported and returns to the menu.
    $invalid = New-InteractiveEnvironment 'invalid'
    Set-SotdPackageRoot $invalid.Package
    Reset-SotdInteractiveOutput
    Set-SotdInteractiveInputs @('9', '1', '', '5')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $invalid.ACRoot -BackupRoot (Join-Path $invalid.Base 'backup')
    Assert ($global:SotdInteractiveOutput.Contains('Invalid choice')) 'invalid selection is reported'
    Assert ($global:SotdInteractiveOutput.Contains('New') -or $global:SotdInteractiveOutput.Contains('Changed')) 'invalid selection returns to the menu and preview runs afterwards'

    # 6) The pause prompt: Enter returns to the menu; Q breaks the loop.
    $quit = New-InteractiveEnvironment 'quit'
    Set-SotdPackageRoot $quit.Package
    Reset-SotdInteractiveOutput
    $global:SotdInteractivePrompts = ''
    Set-SotdInteractiveInputs @('1', 'Q')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $quit.ACRoot -BackupRoot (Join-Path $quit.Base 'backup')
    Assert ($global:SotdInteractivePrompts.Contains('Press Enter to return to the menu')) 'the menu prompts to return to the menu or quit'
    Assert (-not $global:SotdInteractiveOutput.Contains('Exiting installer')) 'Q at the pause prompt breaks the loop without the exit message'

    Assert ($global:SotdInteractivePrompts.Contains('Choose an option')) 'the menu prompts for an option'

    # 7) -NoPause suppresses the return prompt.
    # Note: a variable named $nopause would collide with the dot-sourced [switch]$NoPause
    # parameter (PowerShell variable names are case-insensitive), so use a distinct name.
    $noPauseCase = New-InteractiveEnvironment 'nopause'
    Set-SotdPackageRoot $noPauseCase.Package
    Reset-SotdInteractiveOutput
    $global:SotdInteractivePrompts = ''
    Set-SotdInteractiveInputs @('1', '5')
    Show-SotdInteractiveMenu -AssettoCorsaRoot $noPauseCase.ACRoot -BackupRoot (Join-Path $noPauseCase.Base 'backup') -NoPause
    Assert (-not $global:SotdInteractivePrompts.Contains('Press Enter to return to the menu')) '-NoPause suppresses the return prompt'
    Assert ($global:SotdInteractiveOutput.Contains('Exiting installer')) '-NoPause still allows option 5 to exit'

    # 8) Non-interactive default (no -Interactive) is unchanged: preview writes nothing.
    $regression = New-InteractiveEnvironment 'regression'
    Set-SotdPackageRoot $regression.Package
    Reset-SotdInteractiveOutput
    $regressionBackup = Join-Path $regression.Base 'backup'
    Invoke-SotdInstaller -Mode Preview -AssettoCorsaRoot $regression.ACRoot -BackupRoot $regressionBackup | Out-Null
    Assert (-not (Test-Path -LiteralPath $regressionBackup)) 'non-interactive preview still creates no backup'
    Assert ($global:SotdInteractiveOutput.Contains('New') -or $global:SotdInteractiveOutput.Contains('Changed')) 'non-interactive preview still reports the plan'

    # 9) Static guarantees: switch exposed, UTF-8 BOM retained.
    $installerText = [IO.File]::ReadAllText($installerPath)
    Assert ($installerText.Contains('[switch]$Interactive')) 'installer exposes the -Interactive switch with a false default'
    $installerBytes = [IO.File]::ReadAllBytes($installerPath)
    Assert ($installerBytes.Length -ge 3 -and $installerBytes[0] -eq 239 -and $installerBytes[1] -eq 187 -and $installerBytes[2] -eq 191) 'installer script retains its UTF-8 BOM'

    Write-Harness "Installer interactive tests passed: $checks checks."
} finally {
    Remove-Item Function:\global:Read-Host -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Write-Host -ErrorAction SilentlyContinue
    Remove-Variable SotdInteractiveInputs -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable SotdInteractiveOutput -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable SotdInteractivePrompts -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
