$ErrorActionPreference = 'Stop'

$approvedRoot = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $approvedRoot -PathType Container)) { throw "Approved log-test sandbox is unavailable: $approvedRoot" }
$sandbox = Join-Path $approvedRoot ('sotd-log-tests-' + [guid]::NewGuid().ToString('N'))
$sandboxFull = [IO.Path]::GetFullPath($sandbox)
if (-not $sandboxFull.StartsWith([IO.Path]::GetFullPath($approvedRoot), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Log test sandbox escaped the approved temporary directory.'
}

$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Get-SotdLogBomCount {
    param([byte[]]$Bytes)
    $count = 0
    for ($i = 0; $i -le $Bytes.Length - 3; $i++) {
        if ($Bytes[$i] -eq 0xEF -and $Bytes[$i + 1] -eq 0xBB -and $Bytes[$i + 2] -eq 0xBF) { $count++ }
    }
    return $count
}

. (Join-Path $PSScriptRoot 'distribution/installer.logging.ps1')

try {
    [void][IO.Directory]::CreateDirectory($sandbox)

    # Default root resolves under %LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs (or %USERPROFILE%).
    $defaultLog = Start-SotdInstallerLog -LogName 'unit'
    Assert ($null -ne $defaultLog -and -not [string]::IsNullOrEmpty([string]$defaultLog.Path)) `
        'Start-SotdInstallerLog returns a log path'
    $defaultRoot = if (-not [string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
        Join-Path $env:LOCALAPPDATA 'SimOpenTrackDay\InstallerLogs'
    } else {
        Join-Path $env:USERPROFILE 'SimOpenTrackDay\InstallerLogs'
    }
    $defaultPath = [IO.Path]::GetFullPath([string]$defaultLog.Path)
    Assert ($defaultPath.StartsWith([IO.Path]::GetFullPath($defaultRoot), [StringComparison]::OrdinalIgnoreCase)) `
        'default log path resolves under InstallerLogs'
    $defaultLeaf = Split-Path -Leaf $defaultPath
    Assert ($defaultLeaf.StartsWith('installer-unit', [StringComparison]::Ordinal)) `
        'default log file name starts with installer-unit'
    Assert ([IO.Path]::GetExtension($defaultLeaf) -eq '.log') 'default log file name has a .log extension'
    Assert ((Split-Path -Leaf (Split-Path -Parent $defaultPath)) -match '^\d{8}T\d{6}Z$') `
        'log directory uses the yyyyMMddTHHmmssZ utc-stamp format'

    $defaultBytes = [IO.File]::ReadAllBytes($defaultPath)
    Assert ($defaultBytes.Length -ge 3 -and $defaultBytes[0] -eq 0xEF -and $defaultBytes[1] -eq 0xBB -and $defaultBytes[2] -eq 0xBF) `
        'log file begins with a UTF-8 BOM'
    $defaultText = [IO.File]::ReadAllText($defaultPath)
    Assert ($defaultText.Contains('SimOpenTrackDay installer log')) 'log header identifies the product'
    Assert ($defaultText.Contains('UTC start:')) 'log header records the UTC start'

    $defaultDirectory = Split-Path -Parent $defaultPath
    Stop-SotdInstallerLog
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'Get-SotdInstallerLogPath is empty after Stop'
    if (Test-Path -LiteralPath $defaultDirectory) { Remove-Item -LiteralPath $defaultDirectory -Recurse -Force }

    # A custom root keeps the remaining assertions isolated from the user profile.
    $customRoot = Join-Path $sandbox 'logs'
    $customLog = Start-SotdInstallerLog -LogName 'unit' -LogRoot $customRoot
    $customPath = [IO.Path]::GetFullPath([string]$customLog.Path)
    Assert ($customPath.StartsWith([IO.Path]::GetFullPath($customRoot), [StringComparison]::OrdinalIgnoreCase)) `
        'custom log path resolves under the sandbox root'
    $customLeaf = Split-Path -Leaf $customPath
    Assert ($customLeaf.StartsWith('installer-unit', [StringComparison]::Ordinal)) 'custom log file name starts with installer-unit'
    Assert ([IO.Path]::GetExtension($customLeaf) -eq '.log') 'custom log file name has a .log extension'

    Write-SotdInstallerLog -Message 'hello world' -Level 'INFO'
    $customText = [IO.File]::ReadAllText($customPath)
    $infoLine = @($customText -split "`r?`n" | Where-Object { $_ -match 'hello world' })[0]
    Assert ($infoLine -match '^: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z? \[INFO\] hello world$') `
        'INFO line has an ISO timestamp, level, and message'

    Write-SotdInstallerLog -Message 'custom level' -Level 'WARN'
    $customText = [IO.File]::ReadAllText($customPath)
    Assert ($customText -match '\[WARN\] custom level') 'custom level is recorded as [WARN]'

    for ($i = 0; $i -lt 3; $i++) { Write-SotdInstallerLog -Message "bulk $i" -Level 'DEBUG' }
    $customBytes = [IO.File]::ReadAllBytes($customPath)
    Assert ($customBytes[0] -eq 0xEF -and $customBytes[1] -eq 0xBB -and $customBytes[2] -eq 0xBF) `
        'BOM still leads the file after multiple writes'
    Assert ((Get-SotdLogBomCount $customBytes) -eq 1) 'no extra BOM is inserted by later writes'

    Stop-SotdInstallerLog
    $afterStopText = [IO.File]::ReadAllText($customPath)
    Assert ($afterStopText.Contains('end UTC:')) 'Stop writes the log end marker'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'log path is empty after Stop'

    $sizeAfterStop = ([IO.File]::ReadAllBytes($customPath)).Length
    Write-SotdInstallerLog -Message 'should be ignored' -Level 'INFO'
    $silentBytes = [IO.File]::ReadAllBytes($customPath)
    Assert ($silentBytes.Length -eq $sizeAfterStop) 'Write after Stop is silent'
    Assert (-not ([IO.File]::ReadAllText($customPath).Contains('should be ignored'))) 'Write after Stop records nothing'

    # A traversal segment in a supplied LogRoot is refused before any file is created.
    $traversalFailed = $false
    try { Start-SotdInstallerLog -LogName 'unit' -LogRoot (Join-Path $sandbox '..\evil') | Out-Null }
    catch { $traversalFailed = $true }
    Assert $traversalFailed 'a log root containing a traversal segment is rejected'
    Assert ([string]::IsNullOrEmpty([string](Get-SotdInstallerLogPath))) 'traversal rejection leaves logging off'

    # A log root below a reparse point is refused where the host permits junction creation.
    $junctionTarget = Join-Path $sandbox 'junction-target'
    $junctionPath = Join-Path $sandbox 'logs-junction'
    [void][IO.Directory]::CreateDirectory($junctionTarget)
    $junctionCreated = $false
    try {
        New-Item -ItemType Junction -Path $junctionPath -Target $junctionTarget -ErrorAction Stop | Out-Null
        $junctionCreated = $true
    } catch {
        Write-Host '# SKIP: junction unavailable'
    }
    if ($junctionCreated) {
        $junctionRoot = Join-Path $junctionPath 'nested'
        $junctionFailed = $false
        try { Start-SotdInstallerLog -LogName 'unit' -LogRoot $junctionRoot | Out-Null }
        catch { $junctionFailed = $true }
        Assert $junctionFailed 'a log root below a reparse point is rejected'
        Assert (-not (Test-Path -LiteralPath (Join-Path $junctionTarget 'nested'))) `
            'reparse-point rejection creates nothing under the junction target'
        Remove-Item -LiteralPath $junctionPath -Force
    }

    Write-Host "Installer logging tests passed: $checks checks."
}
finally {
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
