# Foundation-only logging. Existing installer behavior is unchanged unless this module is started explicitly.
#
# This module is intentionally self-contained: it is loaded with a standalone dot-source and does not
# depend on installer.ps1 internals. It mirrors the installer's reparse-point ancestry guard, refuses
# traversal segments in the supplied root, and rejects any final path that escapes the resolved root.

$script:SotdLogPath = $null
$script:SotdLogWriter = $null
$script:SotdLogStartUtc = $null

function ConvertTo-SotdLogFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path)
}

function ConvertTo-SotdLogComparablePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    while ($full.Length -gt $root.Length -and ($full.EndsWith('\') -or $full.EndsWith('/'))) {
        $full = $full.Substring(0, $full.Length - 1)
    }
    return $full
}

function Test-SotdLogTraversalSegment {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $false }
    return [bool]($Value -match '(^|[\\/])\.\.($|[\\/])')
}

function Test-SotdLogPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $candidate = ConvertTo-SotdLogComparablePath $Path
    $container = ConvertTo-SotdLogComparablePath $Root
    if ([string]::Equals($candidate, $container, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $candidate.StartsWith($container + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-SotdLogNoReparseAncestors {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = ConvertTo-SotdLogFullPath $Path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point or symlink is not allowed in log path ancestry: '$current'."
            }
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent -or [string]::Equals($parent.FullName, $current, [StringComparison]::OrdinalIgnoreCase)) { break }
        $current = $parent.FullName
    }
}

function Start-SotdInstallerLog {
    param(
        [string]$LogName = 'installer',
        [string]$LogRoot
    )

    if ([string]::IsNullOrWhiteSpace($LogName)) { throw 'LogName must be a non-empty value.' }
    if ($LogName.IndexOfAny([char[]]'\/:*?"<>|') -ge 0 -or $LogName -eq '.' -or $LogName -eq '..') {
        throw "LogName must be a plain file name without separators or traversal segments: '$LogName'."
    }

    if ([string]::IsNullOrWhiteSpace($LogRoot)) {
        if (-not [string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
            $LogRoot = Join-Path $env:LOCALAPPDATA 'SimOpenTrackDay\InstallerLogs'
        } elseif (-not [string]::IsNullOrEmpty($env:USERPROFILE)) {
            $LogRoot = Join-Path $env:USERPROFILE 'SimOpenTrackDay\InstallerLogs'
        } else {
            throw 'Neither LOCALAPPDATA nor USERPROFILE is defined; cannot resolve the installer log root.'
        }
    } elseif (Test-SotdLogTraversalSegment $LogRoot) {
        throw "Refusing a log root containing a traversal segment: '$LogRoot'."
    }

    $logRootFull = ConvertTo-SotdLogFullPath $LogRoot
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd\THHmmss\Z', [Globalization.CultureInfo]::InvariantCulture)
    $stampDirectory = Join-Path $logRootFull $stamp
    # The default log name already carries the installer marker; custom names are namespaced so every
    # produced file is self-identifying inside the shared log root.
    $leaf = if ($LogName -ceq 'installer') { 'installer.log' } else { "installer-$LogName.log" }
    $logPath = ConvertTo-SotdLogFullPath (Join-Path $stampDirectory $leaf)

    if (-not (Test-SotdLogPathWithin -Path $logPath -Root $logRootFull)) {
        throw "Refusing a log path outside the resolved log root: '$logPath'."
    }

    Assert-SotdLogNoReparseAncestors -Path $logRootFull
    [void][IO.Directory]::CreateDirectory($stampDirectory)
    Assert-SotdLogNoReparseAncestors -Path $stampDirectory

    $encoding = New-Object System.Text.UTF8Encoding($true)
    $script:SotdLogWriter = $encoding
    $script:SotdLogStartUtc = [DateTime]::UtcNow
    $script:SotdLogPath = $logPath

    $iso = $script:SotdLogStartUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $header = @(
        '# SimOpenTrackDay installer log',
        "# UTC start: $iso",
        "# Host: $env:COMPUTERNAME",
        "# User: $env:USERNAME",
        '# Mode: <pending>',
        "# OS: $env:OS",
        ''
    ) -join [Environment]::NewLine
    $header += [Environment]::NewLine
    if ([IO.File]::Exists($logPath)) {
        [IO.File]::AppendAllText($logPath, $header, $encoding)
    } else {
        [IO.File]::WriteAllText($logPath, $header, $encoding)
    }

    return [pscustomobject]@{ Path = $script:SotdLogPath }
}

function Write-SotdInstallerLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Level = 'INFO'
    )
    if ([string]::IsNullOrEmpty($script:SotdLogPath)) { return }
    $iso = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $line = ": $iso [$Level] $Message" + [Environment]::NewLine
    [IO.File]::AppendAllText($script:SotdLogPath, $line, $script:SotdLogWriter)
}

function Stop-SotdInstallerLog {
    if ([string]::IsNullOrEmpty($script:SotdLogPath)) { return }
    $iso = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    $line = "# SimOpenTrackDay installer log end UTC: $iso" + [Environment]::NewLine
    [IO.File]::AppendAllText($script:SotdLogPath, $line, $script:SotdLogWriter)
    $script:SotdLogPath = $null
    $script:SotdLogWriter = $null
    $script:SotdLogStartUtc = $null
}

function Get-SotdInstallerLogPath {
    return $script:SotdLogPath
}
