# SimOpenTrackDay minimal installer.
#
# Wipes <AssettoCorsaRoot>/apps/lua/SimOpenTrackDay/ and copies the runtime
# payload listed in tools/payload.manifest into it. No checksum, no journal,
# no rollback: this is a clean-overwrite tool, not a transactional installer.
#
# Required: -AssettoCorsaRoot must point at an Assetto Corsa installation
# (the parent of apps/, content/, etc.). The script appends "apps\lua"
# itself.
#
# Logs failures to %LOCALAPPDATA%\SimOpenTrackDay\InstallerLogs\installer-yyyyMMdd-HHmmss.txt
# so a double-clicked install.bat still leaves a breadcrumb when something
# goes wrong.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AssettoCorsaRoot
)

$ErrorActionPreference = 'Stop'

function Write-SotdLog {
    param([string]$Message)
    Write-Host $Message
}

function Get-SotdLogPath {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $LogRoot ("installer-{0}.txt" -f $stamp)
}

function Initialize-SotdLog {
    param([string]$Target)
    $script:LogFile = Get-SotdLogPath
    $script:LogTarget = $Target
    Set-Content -LiteralPath $script:LogFile -Value ("SimOpenTrackDay installer log`r`nStarted: {0}`r`nTarget: {1}`r`n" -f (Get-Date -Format 'o'), $Target) -Encoding UTF8
}

function Append-SotdLog {
    param([string]$Line)
    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $Line -Encoding UTF8
    }
}

function Complete-SotdLog {
    param([string]$Status)
    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value ("`r`nFinished: {0}`r`nStatus: {1}" -f (Get-Date -Format 'o'), $Status) -Encoding UTF8
    }
}

function Resolve-SotdRepositoryRoot {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Read-SotdPayloadManifest {
    param([string]$RepoRoot)
    $manifestPath = Join-Path (Join-Path $RepoRoot 'tools') 'payload.manifest'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Payload manifest not found: $manifestPath"
    }
    $entries = New-Object System.Collections.Generic.List[string]
    Get-Content -LiteralPath $manifestPath | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line.StartsWith('#')) { return }
        [void]$entries.Add($line)
    }
    return $entries
}

function Resolve-SotdManifestEntries {
    param(
        [string]$RepoRoot,
        [System.Collections.Generic.List[string]]$Entries
    )
    $resolved = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Entries) {
        $absolute = Join-Path $RepoRoot ($entry -replace '/', [IO.Path]::DirectorySeparatorChar)
        if ($entry.EndsWith('/*.lua')) {
            $parent = Split-Path -Parent $absolute
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                throw "Manifest glob parent missing: $parent"
            }
            Get-ChildItem -LiteralPath $parent -Filter '*.lua' -File | Sort-Object Name | ForEach-Object {
                $prefix = $entry.Substring(0, $entry.Length - 6)
                if (-not $prefix.EndsWith('/')) { $prefix = $prefix + '/' }
                [void]$resolved.Add(@{ Source = $_.FullName; Relative = ($prefix + $_.Name) })
            }
        }
        elseif (Test-Path -LiteralPath $absolute -PathType Leaf) {
            [void]$resolved.Add(@{ Source = $absolute; Relative = $entry })
        }
        else {
            throw "Manifest entry missing on disk: $entry"
        }
    }
    return $resolved
}

function Reset-SotdTargetDirectory {
    param([string]$TargetDir)
    if (Test-Path -LiteralPath $TargetDir) {
        Get-ChildItem -LiteralPath $TargetDir -Force -Recurse | Remove-Item -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
}

function Copy-SotdPayloadFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    $destParent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

$LogRoot = Join-Path $env:LOCALAPPDATA 'SimOpenTrackDay\InstallerLogs'
if (-not (Test-Path -LiteralPath $LogRoot)) {
    New-Item -ItemType Directory -LiteralPath $LogRoot -Force | Out-Null
}

try {
    if (-not (Test-Path -LiteralPath $AssettoCorsaRoot -PathType Container)) {
        throw "Assetto Corsa root not found: $AssettoCorsaRoot"
    }
    $appsLua = Join-Path $AssettoCorsaRoot 'apps\lua'
    if (-not (Test-Path -LiteralPath $appsLua -PathType Container)) {
        throw "Expected apps\lua folder under: $AssettoCorsaRoot"
    }
    $targetDir = Join-Path $appsLua 'SimOpenTrackDay'

    Initialize-SotdLog -Target $targetDir

    $repoRoot = Resolve-SotdRepositoryRoot
    $entries = Read-SotdPayloadManifest -RepoRoot $repoRoot
    $resolved = Resolve-SotdManifestEntries -RepoRoot $repoRoot -Entries $entries
    Append-SotdLog ("Manifest entries: {0}" -f $resolved.Count)

    Write-SotdLog ("Wiping {0}" -f $targetDir)
    Reset-SotdTargetDirectory -TargetDir $targetDir

    $copied = 0
    foreach ($entry in $resolved) {
        $destination = Join-Path $targetDir ($entry.Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        Append-SotdLog ("Copy {0} -> {1}" -f $entry.Source, $destination)
        Copy-SotdPayloadFile -Source $entry.Source -Destination $destination
        $copied++
    }

    Write-SotdLog ("Copied {0} files into {1}" -f $copied, $targetDir)
    Write-SotdLog 'Done.'
    Complete-SotdLog -Status 'OK'
    exit 0
}
catch {
    $message = $_.Exception.Message
    Write-SotdLog ("ERROR: {0}" -f $message)
    if (-not $script:LogFile) {
        $script:LogFile = Get-SotdLogPath
        Set-Content -LiteralPath $script:LogFile -Value ("SimOpenTrackDay installer log`r`nFinished: {0}`r`nStatus: FAILED`r`nError: {1}`r`n" -f (Get-Date -Format 'o'), $message) -Encoding UTF8
    }
    else {
        Append-SotdLog ("ERROR: {0}" -f $message)
        Complete-SotdLog -Status 'FAILED'
    }
    Write-SotdLog ("See log: {0}" -f $script:LogFile)
    exit 1
}