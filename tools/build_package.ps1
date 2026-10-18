param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PSScriptRoot 'runtime-manifest.txt'
$deliveryFiles = @(
    @{ Source = 'tools/distribution/install.bat'; Destination = 'install.bat' },
    @{ Source = 'tools/distribution/installer.ps1'; Destination = 'installer.ps1' },
    @{ Source = 'tools/distribution/installer.logging.ps1'; Destination = 'installer.logging.ps1' },
    @{ Source = 'docs/INSTALL.md'; Destination = 'INSTALL.md' }
)

function Get-FullPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path)
}

function Assert-NoReparseAncestors([string]$Path) {
    $cursor = Get-FullPath $Path
    while ($null -ne $cursor -and $cursor.Length -gt 0) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse points are not allowed in package paths: $cursor"
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function Test-SameOrNestedPath([string]$Candidate, [string]$Root) {
    $candidateFull = Get-FullPath $Candidate
    $rootFull = Get-FullPath $Root
    $trimChars = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootPrefix = $rootFull.TrimEnd($trimChars) + [IO.Path]::DirectorySeparatorChar
    return $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
        $candidateFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-RelativeManifestPath([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath.Contains('\') -or $RelativePath.Contains(':') -or
        $RelativePath -notmatch '^[A-Za-z0-9_.*/-]+$') {
        throw "Unsafe runtime-manifest path: $RelativePath"
    }
    foreach ($segment in $RelativePath.Split('/')) {
        if ($segment.Length -eq 0 -or $segment -eq '.' -or $segment -eq '..') {
            throw "Unsafe runtime-manifest path segment in: $RelativePath"
        }
    }
}

function Resolve-ExactCaseFile([string]$Root, [string]$RelativePath) {
    $current = $Root
    foreach ($segment in $RelativePath.Split('/')) {
        $children = @(Get-ChildItem -LiteralPath $current -Force)
        $matches = @($children | Where-Object { $_.Name -ceq $segment })
        if ($matches.Count -ne 1) {
            throw "Missing source file or incorrect path capitalization: $RelativePath"
        }
        $current = $matches[0].FullName
    }
    $item = Get-Item -LiteralPath $current -Force
    if ($item.PSIsContainer) { throw "Runtime manifest entry is not a file: $RelativePath" }
    return $item.FullName
}

function Add-CheckedRuntimePath([string]$Root, [string]$RelativePath, $Seen, $Resolved) {
    Assert-RelativeManifestPath $RelativePath
    if ($Seen.Contains($RelativePath)) {
        throw "Duplicate or case-colliding runtime path: $RelativePath"
    }
    [void]$Seen.Add($RelativePath)
    $sourceFile = Resolve-ExactCaseFile $Root $RelativePath
    Assert-NoReparseAncestors $sourceFile
    $Resolved.Add([pscustomobject]@{ RelativePath = $RelativePath; SourcePath = $sourceFile })
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot does not exist as a directory: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Runtime manifest is missing: $manifestPath"
}

$sourceFull = Get-FullPath $SourceRoot
Assert-NoReparseAncestors $sourceFull
$outputInputSegments = $OutputPath.Replace('/', '\').Split('\')
if ($outputInputSegments -contains '..') {
    throw "OutputPath traversal segments are not allowed: $OutputPath"
}
$outputFull = Get-FullPath $OutputPath
if ((Test-SameOrNestedPath $outputFull $sourceFull) -or
    (Test-SameOrNestedPath $sourceFull $outputFull)) {
    throw 'OutputPath must not overlap SourceRoot (it must be outside and not contain the source tree).'
}
if (Test-Path -LiteralPath $outputFull) {
    throw "OutputPath already exists; refusing to overwrite it: $outputFull"
}
$existingOutputItem = Get-Item -LiteralPath $outputFull -Force -ErrorAction SilentlyContinue
if ($null -ne $existingOutputItem) {
    throw "OutputPath already exists; refusing to overwrite it: $outputFull"
}
$outputParent = [IO.Directory]::GetParent($outputFull)
if ($null -eq $outputParent -or -not (Test-Path -LiteralPath $outputParent.FullName -PathType Container)) {
    throw "OutputPath parent directory must already exist: $($outputParent.FullName)"
}
Assert-NoReparseAncestors $outputParent.FullName

$seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$runtimeFiles = New-Object 'System.Collections.Generic.List[object]'
$manifestLines = [IO.File]::ReadAllLines($manifestPath)
$localeGlob = 'lib/i18n/*.lua'
$localeGlobCount = 0
foreach ($rawLine in $manifestLines) {
    $line = $rawLine.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
    if ($line.Contains('*')) {
        if ($line -cne $localeGlob) { throw "Unsupported wildcard in runtime manifest: $line" }
        $localeGlobCount++
        continue
    }
    Add-CheckedRuntimePath $sourceFull $line $seenPaths $runtimeFiles
}
if ($localeGlobCount -ne 1) { throw "Runtime manifest must contain exactly one '$localeGlob' entry." }

$localeDirectory = Join-Path $sourceFull 'lib/i18n'
if (-not (Test-Path -LiteralPath $localeDirectory -PathType Container)) {
    throw "Locale directory is missing: $localeDirectory"
}
Assert-NoReparseAncestors $localeDirectory
$localeFiles = @(Get-ChildItem -LiteralPath $localeDirectory -File -Force |
    Where-Object { $_.Name.EndsWith('.lua', [StringComparison]::Ordinal) } |
    Sort-Object -Property Name -CaseSensitive)
if ($localeFiles.Count -eq 0) { throw 'The locale glob did not match any .lua files.' }
foreach ($localeFile in $localeFiles) {
    $relativeLocalePath = 'lib/i18n/' + $localeFile.Name
    Add-CheckedRuntimePath $sourceFull $relativeLocalePath $seenPaths $runtimeFiles
}

$deliverySources = New-Object 'System.Collections.Generic.List[object]'
foreach ($deliveryFile in $deliveryFiles) {
    $relativeSource = $deliveryFile.Source
    Assert-RelativeManifestPath $relativeSource
    $sourceFile = Resolve-ExactCaseFile $sourceFull $relativeSource
    Assert-NoReparseAncestors $sourceFile
    $deliverySources.Add([pscustomobject]@{
        SourcePath = $sourceFile
        Destination = $deliveryFile.Destination
    })
}

# All inputs and paths are checked above. Preview remains entirely read-only.
$runtimePaths = [string[]]@($runtimeFiles | ForEach-Object { $_.RelativePath })
[Array]::Sort($runtimePaths, [StringComparer]::Ordinal)
if (-not $Build) {
    Write-Output "Preview only: no files were written."
    Write-Output "SourceRoot: $sourceFull"
    Write-Output "OutputPath: $outputFull"
    Write-Output "Runtime payload files: $($runtimePaths.Count)"
    foreach ($relativePath in $runtimePaths) { Write-Output "payload/SimOpenTrackDay/$relativePath" }
    foreach ($deliveryFile in $deliverySources) { Write-Output $deliveryFile.Destination }
    Write-Output 'checksums.sha256 (runtime payload only)'
    return
}

$packageRoot = $outputFull
$payloadRoot = Join-Path $packageRoot 'payload/SimOpenTrackDay'
New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null
foreach ($runtimeFile in $runtimeFiles) {
    $destinationPath = Join-Path $payloadRoot ($runtimeFile.RelativePath.Replace('/', '\'))
    $destinationDirectory = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }
    Copy-Item -LiteralPath $runtimeFile.SourcePath -Destination $destinationPath
}
foreach ($deliveryFile in $deliverySources) {
    Copy-Item -LiteralPath $deliveryFile.SourcePath -Destination (Join-Path $packageRoot $deliveryFile.Destination)
}

$checksumLines = New-Object 'System.Collections.Generic.List[string]'
foreach ($relativePath in $runtimePaths) {
    $sourceFile = Join-Path $sourceFull ($relativePath.Replace('/', '\'))
    $outputFile = Join-Path $payloadRoot ($relativePath.Replace('/', '\'))
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $outputHash = (Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -cne $outputHash) { throw "Copied payload hash mismatch: $relativePath" }
    $checksumLines.Add("$outputHash  payload/SimOpenTrackDay/$relativePath")
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines((Join-Path $packageRoot 'checksums.sha256'), $checksumLines.ToArray(), $utf8NoBom)

$outputPayloadFiles = @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse -Force)
if ($outputPayloadFiles.Count -ne $runtimePaths.Count) {
    throw "Output payload file count mismatch: expected $($runtimePaths.Count), found $($outputPayloadFiles.Count)."
}
foreach ($relativePath in $runtimePaths) {
    $outputFile = Join-Path $payloadRoot ($relativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
        throw "Output payload is missing: $relativePath"
    }
    Assert-NoReparseAncestors $outputFile
}

Write-Output "Package built and verified: $packageRoot"
Write-Output "Runtime payload files: $($runtimePaths.Count)"
Write-Output 'Checksums include runtime payload files only.'
