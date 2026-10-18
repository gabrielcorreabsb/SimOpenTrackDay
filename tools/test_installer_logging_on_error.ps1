$ErrorActionPreference = 'Stop'

$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}

# Harness output bypasses the mocked global Write-Host so it is never swallowed.
function Write-Harness([string]$Message) { Microsoft.PowerShell.Utility\Write-Host $Message }

$approvedRoot = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $approvedRoot -PathType Container)) { throw "Approved logging test sandbox is unavailable: $approvedRoot" }
$sandbox = Join-Path $approvedRoot ('sotd-logging-tests-' + [guid]::NewGuid().ToString('N'))
$sandboxFull = [IO.Path]::GetFullPath($sandbox)
if (-not $sandboxFull.StartsWith([IO.Path]::GetFullPath($approvedRoot), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Logging-on-error test sandbox escaped the approved temporary directory.'
}

# --- mocks -------------------------------------------------------------------------------------
# These global functions stand in for the installer logging module and for the GUI/host calls the
# console entry point makes on its error path. Everything is removed again in the finally block.
$global:SotdLogMockStartCount = 0
$global:SotdLogMockStopCount = 0
$global:SotdLogMockPath = $null
$global:SotdLogMockLastPath = $null
$global:SotdLogMockEntries = New-Object System.Collections.ArrayList
$global:SotdLogMockPrompts = ''
$global:SotdLogMockInputs = New-Object System.Collections.Queue
$global:SotdLogMockStartProcess = New-Object System.Collections.ArrayList
$global:SotdLogMockOutput = ''

function Set-SotdLogInputs {
    param([string[]]$Inputs)
    $global:SotdLogMockInputs = New-Object System.Collections.Queue
    foreach ($item in $Inputs) { [void]$global:SotdLogMockInputs.Enqueue([string]$item) }
}

function Reset-SotdLogCapture {
    $global:SotdLogMockEntries = New-Object System.Collections.ArrayList
    $global:SotdLogMockStartProcess = New-Object System.Collections.ArrayList
    $global:SotdLogMockOutput = ''
    $global:SotdLogMockPrompts = ''
    $global:SotdLogMockStartCount = 0
    $global:SotdLogMockStopCount = 0
}

function global:Write-Host {
    param([string]$Message)
    $global:SotdLogMockOutput += [string]$Message + "`n"
}

function global:Read-Host {
    param([string]$Prompt)
    $global:SotdLogMockPrompts += ([string]$Prompt) + "`n"
    if ($global:SotdLogMockInputs.Count -gt 0) { return [string]$global:SotdLogMockInputs.Dequeue() }
    return ''
}

function global:Start-Process {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        $ArgumentList
    )
    [void]$global:SotdLogMockStartProcess.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = [string]$ArgumentList })
}

function global:Start-SotdInstallerLog {
    param([string]$LogName = 'installer', [string]$LogRoot)
    $global:SotdLogMockStartCount++
    if ([string]::IsNullOrWhiteSpace($LogRoot)) {
        $global:SotdLogMockPath = $null
    } else {
        $global:SotdLogMockPath = Join-Path $LogRoot 'mock\installer.log'
    }
    $global:SotdLogMockLastPath = $global:SotdLogMockPath
    return [pscustomobject]@{ Path = $global:SotdLogMockPath }
}

function global:Write-SotdInstallerLog {
    param([string]$Message, [string]$Level = 'INFO')
    [void]$global:SotdLogMockEntries.Add([pscustomobject]@{ Level = [string]$Level; Message = [string]$Message })
}

function global:Stop-SotdInstallerLog {
    $global:SotdLogMockStopCount++
    $global:SotdLogMockPath = $null
}

function global:Get-SotdInstallerLogPath { return $global:SotdLogMockPath }

# [Console]::Error cannot be mocked, so the process error writer is redirected to a buffer and
# restored in the finally block.
$originalConsoleError = [Console]::Error
$consoleErrorWriter = New-Object IO.StringWriter
[Console]::SetError($consoleErrorWriter)
function Reset-SotdLogStderr { [void]$consoleErrorWriter.GetStringBuilder().Clear() }
function Get-SotdLogStderr { return $consoleErrorWriter.ToString() }

# --- sandbox package ---------------------------------------------------------------------------
function Write-LoggingPackage {
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

function New-LoggingEnvironment {
    param([string]$Name)
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
    Write-LoggingPackage $package $payload
    [IO.File]::WriteAllText((Join-Path $target 'manifest.ini'), 'old-manifest-version')
    [IO.File]::WriteAllText((Join-Path $target 'SimOpenTrackDay.lua'), 'old-entry-version')
    [IO.File]::WriteAllText((Join-Path $target 'LICENSE'), 'old-license')
    return @{ Base = $base; Package = $package; ACRoot = $acRoot; Target = $target; Payload = $payload }
}

try {
    [void][IO.Directory]::CreateDirectory($sandbox)

    $installerPath = Join-Path $PSScriptRoot 'distribution/installer.ps1'
    $installerText = [IO.File]::ReadAllText($installerPath)
    $installerBytes = [IO.File]::ReadAllBytes($installerPath)

    # Static guarantees: the opt-in switches and the untouched UTF-8 BOM.
    Assert ($installerText.Contains('[string]$LogRoot')) 'installer exposes the -LogRoot parameter'
    Assert ($installerText.Contains('[string]$LogName = ''installer''')) 'installer exposes -LogName defaulting to installer'
    Assert ($installerBytes.Length -ge 3 -and $installerBytes[0] -eq 0xEF -and $installerBytes[1] -eq 0xBB -and $installerBytes[2] -eq 0xBF) `
        'installer.ps1 retains its UTF-8 BOM'

    # The mocks must exist before the installer loads so its guard skips the real logging module.
    . $installerPath -LibraryOnly:$true
    Assert ($null -ne (Get-Command Invoke-SotdInstallerConsole -ErrorAction SilentlyContinue)) 'console entry point is defined'

    # 1) Default (no -LogRoot): a successful preview never starts a log.
    $defaultPreview = New-LoggingEnvironment 'default-preview'
    Set-SotdPackageRoot $defaultPreview.Package
    Reset-SotdLogCapture
    $code = Invoke-SotdInstallerConsole -Mode Preview -AssettoCorsaRoot $defaultPreview.ACRoot -BackupRoot (Join-Path $defaultPreview.Base 'backup')
    Assert ($code -eq 0) 'preview without -LogRoot exits 0'
    Assert ($global:SotdLogMockStartCount -eq 0) 'preview without -LogRoot never starts a log'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'Get-SotdInstallerLogPath is empty without -LogRoot'

    # 2) Default (no -LogRoot) with an induced Install error: still no log session.
    Reset-SotdLogCapture
    $code = Invoke-SotdInstallerConsole -Mode Install -AssettoCorsaRoot (Join-Path $defaultPreview.Base 'missing ac root')
    Assert ($code -eq 1) 'a failing install without -LogRoot exits 1'
    Assert ($global:SotdLogMockStartCount -eq 0) 'a failing install without -LogRoot never starts a log'
    Assert ($global:SotdLogMockEntries.Count -eq 0) 'no log entries are written when logging is off'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'Get-SotdInstallerLogPath stays empty on the default error path'

    # 3) -LogRoot on the CLI error path: log starts, the catch logs [ERROR], the finally stops it,
    #    and only the path (never a GUI window) is emitted on stderr.
    $cliCase = New-LoggingEnvironment 'cli-error'
    Set-SotdPackageRoot $cliCase.Package
    Reset-SotdLogCapture
    Reset-SotdLogStderr
    $cliLogRoot = Join-Path $cliCase.Base 'logs'
    $code = Invoke-SotdInstallerConsole -Mode Install -AssettoCorsaRoot (Join-Path $cliCase.Base 'missing ac root') -LogRoot $cliLogRoot
    Assert ($code -eq 1) 'a failing install with -LogRoot exits 1'
    Assert ($global:SotdLogMockStartCount -eq 1) 'install with -LogRoot starts exactly one log session'
    Assert ($global:SotdLogMockStopCount -eq 1) 'the finally stops the log exactly once'
    $errorEntries = @($global:SotdLogMockEntries | Where-Object { $_.Level -eq 'ERROR' })
    Assert ($errorEntries.Count -eq 1) 'the catch writes exactly one ERROR log entry'
    Assert ($errorEntries[0].Message.StartsWith('Installer error:', [StringComparison]::Ordinal)) `
        'the ERROR entry records the installer failure message'
    Assert ($global:SotdLogMockStartProcess.Count -eq 0) 'the CLI error path never launches a GUI process'
    $cliStderr = Get-SotdLogStderr
    Assert ($cliStderr.Contains('Installer log: ' + $global:SotdLogMockLastPath)) 'the CLI error path prints the log path on stderr'
    Assert (-not $cliStderr.Contains('notepad')) 'the CLI error path never mentions notepad'

    # 4) -Interactive with an error accepts the offered notepad launch.
    Set-SotdLogInputs @('1', 'y')
    Reset-SotdLogCapture
    $code = Invoke-SotdInstallerConsole -Mode Preview -AssettoCorsaRoot (Join-Path $cliCase.Base 'missing ac root') -LogRoot $cliLogRoot -Interactive
    Assert ($code -eq 1) 'an interactive error exits 1'
    Assert ($global:SotdLogMockPrompts.Contains('Open log file in Notepad now?')) 'the interactive error path offers to open the log'
    Assert ($global:SotdLogMockStartProcess.Count -eq 1) 'accepting the offer launches notepad once'
    Assert ($global:SotdLogMockStartProcess[0].FilePath -eq 'notepad.exe') 'the launched process is notepad.exe'
    Assert ($global:SotdLogMockStartProcess[0].ArgumentList.Contains([string]$global:SotdLogMockLastPath)) `
        'notepad is asked to open the resolved log file'
    Assert ($global:SotdLogMockStopCount -eq 1) 'the interactive error path also stops the log in the finally'

    # 5) -Interactive refuses the launch when the answer is not affirmative.
    Set-SotdLogInputs @('1', 'n')
    Reset-SotdLogCapture
    $code = Invoke-SotdInstallerConsole -Mode Preview -AssettoCorsaRoot (Join-Path $cliCase.Base 'missing ac root') -LogRoot $cliLogRoot -Interactive
    Assert ($code -eq 1) 'declining the offer still exits 1'
    Assert ($global:SotdLogMockPrompts.Contains('Open log file in Notepad now?')) 'the offer is presented before it can be declined'
    Assert ($global:SotdLogMockStartProcess.Count -eq 0) 'declining the offer never launches notepad'

    # 6) The real logging module: a log file is created, the mode is recorded, and the finally closes it.
    #    Dot-sourcing the module here deliberately shadows the mocks above for the remaining checks.
    . (Join-Path $PSScriptRoot 'distribution/installer.logging.ps1')
    $realSuccess = New-LoggingEnvironment 'real-success'
    Set-SotdPackageRoot $realSuccess.Package
    Set-SotdLogInputs @('YES')
    $realLogRoot = Join-Path $realSuccess.Base 'logs'
    $code = Invoke-SotdInstallerConsole -Mode Install -AssettoCorsaRoot $realSuccess.ACRoot `
        -BackupRoot (Join-Path $realSuccess.Base 'backup') -JournalPath (Join-Path $realSuccess.Base 'journal.json') -LogRoot $realLogRoot
    Assert ($code -eq 0) 'a successful install with -LogRoot exits 0'
    $successLogs = @(Get-ChildItem -LiteralPath $realLogRoot -Recurse -File -Filter 'installer.log')
    Assert ($successLogs.Count -eq 1) 'the successful install writes exactly one real installer.log'
    Assert ((Split-Path -Leaf (Split-Path -Parent $successLogs[0].FullName)) -match '^\d{8}T\d{6}Z$') `
        'the real log lives in a yyyyMMddTHHmmssZ utc-stamp directory'
    $successBytes = [IO.File]::ReadAllBytes($successLogs[0].FullName)
    Assert ($successBytes[0] -eq 0xEF -and $successBytes[1] -eq 0xBB -and $successBytes[2] -eq 0xBF) `
        'the real log file starts with a UTF-8 BOM'
    $successText = [IO.File]::ReadAllText($successLogs[0].FullName)
    Assert ($successText.Contains('SimOpenTrackDay installer log')) 'the real log header identifies the product'
    Assert ($successText.Contains('Mode: Install')) 'the real log records the requested mode'
    Assert ($successText.Contains('end UTC:')) 'Stop wrote the real log end marker in the finally'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'the real log is closed after a successful install'
    Assert (Test-Path -LiteralPath (Join-Path $realSuccess.Base 'journal.json') -PathType Leaf) `
        'logging does not disturb the successful install journal'

    # 7) The real logging module on an error path: a timestamped [ERROR] line is appended.
    $realError = New-LoggingEnvironment 'real-error'
    Set-SotdPackageRoot $realError.Package
    $realErrorLogRoot = Join-Path $realError.Base 'logs'
    $code = Invoke-SotdInstallerConsole -Mode Install -AssettoCorsaRoot (Join-Path $realError.Base 'missing ac root') -LogRoot $realErrorLogRoot
    Assert ($code -eq 1) 'a failing install with the real module exits 1'
    $errorLogs = @(Get-ChildItem -LiteralPath $realErrorLogRoot -Recurse -File -Filter 'installer.log')
    Assert ($errorLogs.Count -eq 1) 'the failing install keeps exactly one real log file for diagnostics'
    $errorText = [IO.File]::ReadAllText($errorLogs[0].FullName)
    Assert ($errorText -match '(?m)^: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z \[ERROR\] Installer error:') `
        'the real log records a timestamped [ERROR] Installer error line'
    Assert ($errorText.Contains('end UTC:')) 'the failing run still closes the real log'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'the real log is closed after a failed install'

    Write-Harness "Installer logging-on-error tests passed: $checks checks."
} finally {
    [Console]::SetError($originalConsoleError)
    Remove-Item Function:\global:Write-Host -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Read-Host -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Start-Process -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Start-SotdInstallerLog -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Write-SotdInstallerLog -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Stop-SotdInstallerLog -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Get-SotdInstallerLogPath -ErrorAction SilentlyContinue
    foreach ($name in @('SotdLogMockStartCount', 'SotdLogMockStopCount', 'SotdLogMockPath', 'SotdLogMockLastPath',
            'SotdLogMockEntries', 'SotdLogMockPrompts', 'SotdLogMockInputs', 'SotdLogMockStartProcess', 'SotdLogMockOutput')) {
        Remove-Variable $name -Scope Global -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
