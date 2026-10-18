param(
    [ValidateSet('Preview', 'Install', 'Rollback')]
    [string]$Mode = 'Preview',
    [string]$AssettoCorsaRoot,
    [string]$BackupRoot,
    [string]$JournalPath,
    [switch]$Interactive,
    [switch]$LibraryOnly,
    [switch]$NoPause
)

$script:PackageRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:PayloadRelativeRoot = 'payload/SimOpenTrackDay'

function ConvertTo-SotdFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path)
}

function Set-SotdPackageRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $script:PackageRoot = ConvertTo-SotdFullPath $Path
}

function ConvertTo-SotdComparablePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-SotdFullPath $Path
    $root = [IO.Path]::GetPathRoot($full)
    while ($full.Length -gt $root.Length -and ($full.EndsWith('\') -or $full.EndsWith('/'))) {
        $full = $full.Substring(0, $full.Length - 1)
    }
    return $full
}

function Test-SotdPathOverlap {
    param([string]$First, [string]$Second)
    $a = ConvertTo-SotdComparablePath $First
    $b = ConvertTo-SotdComparablePath $Second
    if ([string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $separator = [IO.Path]::DirectorySeparatorChar
    return $a.StartsWith($b + $separator, [StringComparison]::OrdinalIgnoreCase) -or
        $b.StartsWith($a + $separator, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-SotdNoOverlap {
    param([string]$First, [string]$Second, [string]$Description)
    if (Test-SotdPathOverlap $First $Second) {
        throw "$Description paths overlap: '$First' and '$Second'."
    }
}

function Assert-SotdNoReparseAncestors {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = ConvertTo-SotdFullPath $Path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point or symlink is not allowed in path ancestry: '$current'."
            }
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent -or [string]::Equals($parent.FullName, $current, [StringComparison]::OrdinalIgnoreCase)) { break }
        $current = $parent.FullName
    }
}

function Assert-SotdDirectoryAncestors {
    param([Parameter(Mandatory = $true)][string]$Path)
    $parent = [IO.Directory]::GetParent((ConvertTo-SotdFullPath $Path))
    while ($null -ne $parent) {
        if (Test-Path -LiteralPath $parent.FullName) {
            $item = Get-Item -LiteralPath $parent.FullName -Force -ErrorAction Stop
            if (-not $item.PSIsContainer) { throw "A path ancestor is not a directory: '$($parent.FullName)'." }
        }
        $next = [IO.Directory]::GetParent($parent.FullName)
        if ($null -eq $next -or [string]::Equals($next.FullName, $parent.FullName, [StringComparison]::OrdinalIgnoreCase)) { break }
        $parent = $next
    }
}

function Assert-SotdFileOrAbsent {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-SotdDirectoryAncestors $Path
    Assert-SotdNoReparseAncestors $Path
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.PSIsContainer) { throw "Expected a file or absent path, found a directory: '$Path'." }
    }
}

function Assert-SotdSafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath.Contains('\') -or
        $RelativePath.StartsWith('/') -or $RelativePath -match '^[A-Za-z]:' -or
        $RelativePath -match '[\x00-\x1f<>:"|?*]') {
        throw "Invalid relative payload path: '$RelativePath'."
    }
    $segments = $RelativePath.Split('/')
    foreach ($segment in $segments) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..' -or
            $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            throw "Unsafe path segment in '$RelativePath'."
        }
        $deviceBase = ($segment -split '\.')[0]
        if ($deviceBase -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
            throw "Reserved Windows path segment in '$RelativePath'."
        }
    }
}

function Get-SotdSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Assert-SotdHash {
    param([Parameter(Mandatory = $true)][string]$Hash, [string]$Description)
    if ($Hash -notmatch '^[A-Fa-f0-9]{64}$') { throw "Invalid SHA-256 hash for $Description." }
}

function Get-SotdACPaths {
    param([Parameter(Mandatory = $true)][string]$AssettoCorsaRoot)
    $root = ConvertTo-SotdComparablePath $AssettoCorsaRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Assetto Corsa root does not exist: '$root'." }
    Assert-SotdNoReparseAncestors $root
    $acs = Join-Path $root 'acs.exe'
    $acsX86 = Join-Path $root 'acs_x86.exe'
    if (-not ((Test-Path -LiteralPath $acs -PathType Leaf) -or (Test-Path -LiteralPath $acsX86 -PathType Leaf))) {
        throw "Assetto Corsa root must contain acs.exe or acs_x86.exe: '$root'."
    }
    $apps = Join-Path $root 'apps'
    if (-not (Test-Path -LiteralPath $apps -PathType Container)) { throw "Assetto Corsa root must contain an apps directory: '$root'." }
    Assert-SotdNoReparseAncestors $apps
    $target = Join-Path (Join-Path (Join-Path $apps 'lua') 'SimOpenTrackDay') ''
    $target = ConvertTo-SotdComparablePath $target
    Assert-SotdNoReparseAncestors $target
    return @{ Root = $root; Target = $target }
}

function Get-SotdPayloadPlan {
    param([Parameter(Mandatory = $true)][string]$TargetRoot)
    $package = $script:PackageRoot
    $payloadRoot = Join-Path $package ($script:PayloadRelativeRoot -replace '/', '\')
    $checksumFile = Join-Path $package 'checksums.sha256'
    if (-not (Test-Path -LiteralPath $checksumFile -PathType Leaf)) { throw "Missing checksum file: '$checksumFile'." }
    if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) { throw "Missing payload directory: '$payloadRoot'." }
    Assert-SotdNoReparseAncestors $package
    Assert-SotdNoReparseAncestors $checksumFile
    Assert-SotdNoReparseAncestors $payloadRoot
    Assert-SotdNoOverlap $package $TargetRoot 'Package and installation target'

    $lines = [IO.File]::ReadAllLines($checksumFile)
    if ($lines.Length -eq 0) { throw 'Checksum file is empty.' }
    $entries = New-Object System.Collections.ArrayList
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $relativePaths = New-Object System.Collections.ArrayList
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { throw 'Checksum file contains an empty line/entry.' }
        if ($line -notmatch '^([A-Fa-f0-9]{64})  payload/SimOpenTrackDay/(.+)$') {
            throw "Invalid checksum entry: '$line'. Expected '<sha256>  payload/SimOpenTrackDay/<relative-path>'."
        }
        $expectedHash = $matches[1].ToLowerInvariant()
        $relative = $matches[2]
        Assert-SotdSafeRelativePath $relative
        if (-not $seen.Add($relative)) { throw "Duplicate or case-colliding checksum path: '$relative'." }
        [void]$relativePaths.Add($relative)
        $source = Join-Path $payloadRoot ($relative -replace '/', '\')
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Checksum-listed payload file is missing: '$relative'." }
        Assert-SotdNoReparseAncestors $source
        $actualHash = Get-SotdSha256 $source
        if ($actualHash -ne $expectedHash) { throw "SHA-256 mismatch for payload '$relative'." }
        [void]$entries.Add(@{ RelativePath = $relative; SourcePath = $source; SourceHash = $expectedHash })
    }

    foreach ($required in @('manifest.ini', 'SimOpenTrackDay.lua', 'LICENSE')) {
        $found = $false
        foreach ($relative in $relativePaths) {
            if ([string]::Equals([string]$relative, $required, [StringComparison]::OrdinalIgnoreCase)) { $found = $true; break }
        }
        if (-not $found) { throw "Required payload file is not checksum-listed: '$required'." }
    }
    foreach ($relative in $relativePaths) {
        $parts = ([string]$relative).Split('/')
        for ($index = 1; $index -lt $parts.Length; $index++) {
            $parent = ($parts[0..($index - 1)] -join '/')
            if ($seen.Contains($parent)) { throw "Payload file/directory path collision: '$parent' and '$relative'." }
        }
    }

    $plan = New-Object System.Collections.ArrayList
    foreach ($entry in $entries) {
        $target = Join-Path $TargetRoot ($entry.RelativePath -replace '/', '\')
        Assert-SotdSafeRelativePath $entry.RelativePath
        Assert-SotdNoReparseAncestors $target
        $exists = Test-Path -LiteralPath $target
        if ($exists) {
            $item = Get-Item -LiteralPath $target -Force -ErrorAction Stop
            if ($item.PSIsContainer) { throw "Target file path is an existing directory: '$target'." }
            $originalHash = Get-SotdSha256 $target
            $status = if ($originalHash -eq $entry.SourceHash) { 'Unchanged' } else { 'Changed' }
        } else {
            $originalHash = $null
            $status = 'New'
        }
        [void]$plan.Add(@{
            RelativePath = $entry.RelativePath
            SourcePath = $entry.SourcePath
            SourceHash = $entry.SourceHash
            TargetPath = $target
            Exists = [bool]$exists
            OriginalHash = $originalHash
            Status = $status
        })
    }
    return ,$plan
}

function Write-SotdJournal {
    param([Parameter(Mandatory = $true)]$Journal, [Parameter(Mandatory = $true)][string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void][IO.Directory]::CreateDirectory($parent) }
    Assert-SotdNoReparseAncestors $Path
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.writing'
    $json = ConvertTo-Json -InputObject $Journal -Depth 12
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $stream = New-Object IO.FileStream($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $previous = $Path + '.' + [guid]::NewGuid().ToString('N') + '.previous'
        [IO.File]::Replace($temporary, $Path, $previous)
        if (Test-Path -LiteralPath $previous -PathType Leaf) { [IO.File]::Delete($previous) }
    }
    else { [IO.File]::Move($temporary, $Path) }
}

function Get-SotdPathParts {
    param([string]$RelativePath)
    $directory = [IO.Path]::GetDirectoryName(($RelativePath -replace '/', '\'))
    $name = [IO.Path]::GetFileName(($RelativePath -replace '/', '\'))
    if ([string]::IsNullOrEmpty($directory)) { return @{ Directory = ''; Name = $name } }
    return @{ Directory = $directory; Name = $name }
}

function Join-SotdRelative {
    param([string]$Left, [string]$Right)
    if ([string]::IsNullOrEmpty($Left)) { return $Right -replace '\\', '/' }
    return (($Left.TrimEnd('\', '/') + '/' + $Right) -replace '\\', '/')
}

function Get-SotdInstallTempRelative {
    param([string]$RelativePath, [string]$TransactionId)
    $parts = Get-SotdPathParts $RelativePath
    return Join-SotdRelative $parts.Directory ('.' + $parts.Name + '.' + $TransactionId + '.install.tmp')
}

function Get-SotdRollbackTempRelative {
    param([string]$RelativePath, [string]$TransactionId)
    $parts = Get-SotdPathParts $RelativePath
    return Join-SotdRelative $parts.Directory ('.' + $parts.Name + '.' + $TransactionId + '.rollback.tmp')
}

function Get-SotdUniqueTransactionTempRelative {
    param([string]$RelativePath, [string]$TransactionId, [string]$Kind, [string]$UniqueId)
    $parts = Get-SotdPathParts $RelativePath
    return Join-SotdRelative $parts.Directory ('.' + $parts.Name + '.' + $TransactionId + '.' + $Kind + '.' + $UniqueId + '.tmp')
}

function Install-SotdPlan {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string]$AssettoCorsaRoot,
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [string]$RequestedJournalPath
    )
    $transactionId = [guid]::NewGuid().ToString('N')
    $backupTransactionRoot = Join-Path $BackupRoot ('SimOpenTrackDay-' + $transactionId)
    $journalPath = if ($RequestedJournalPath) { ConvertTo-SotdFullPath $RequestedJournalPath } else { Join-Path $BackupRoot ('SimOpenTrackDay-' + $transactionId + '.json') }
    Assert-SotdNoOverlap $journalPath $TargetRoot 'Journal and installation target'
    Assert-SotdNoOverlap $journalPath $script:PackageRoot 'Journal and package'
    Assert-SotdNoOverlap $journalPath $backupTransactionRoot 'Journal and transaction backup'
    Assert-SotdNoReparseAncestors $journalPath
    if (Test-Path -LiteralPath $journalPath) { throw "Journal already exists: '$journalPath'." }
    if (Test-Path -LiteralPath $backupTransactionRoot) { throw "Backup transaction path already exists: '$backupTransactionRoot'." }

    $journalEntries = New-Object System.Collections.ArrayList
    foreach ($item in $Plan) {
        $changed = $item.Status -ne 'Unchanged'
        $backupRelative = if ($changed -and $item.Exists) { Join-SotdRelative 'files' $item.RelativePath } else { $null }
        $installTemp = if ($changed) { Get-SotdInstallTempRelative $item.RelativePath $transactionId } else { $null }
        $rollbackTemp = if ($changed -and $item.Exists) { Get-SotdRollbackTempRelative $item.RelativePath $transactionId } else { $null }
        if ($changed) {
            foreach ($tempRelative in @($installTemp, $rollbackTemp)) {
                if ($tempRelative) {
                    Assert-SotdSafeRelativePath $tempRelative
                    $tempPath = Join-Path $TargetRoot ($tempRelative -replace '/', '\')
                    Assert-SotdFileOrAbsent $tempPath
                    if (Test-Path -LiteralPath $tempPath) { throw "Transaction temp path already exists: '$tempPath'." }
                }
            }
        }
        [void]$journalEntries.Add(@{
            RelativePath = $item.RelativePath
            NewHash = $item.SourceHash
            OriginalHash = $item.OriginalHash
            Changed = [bool]$changed
            Status = if ($changed) { 'Pending' } else { 'Unchanged' }
            BackupRelativePath = $backupRelative
            InstallTempRelativePath = $installTemp
            RollbackTempRelativePath = $rollbackTemp
            RestoreTempRelativePaths = @()
            DisplacedTempRelativePaths = @()
        })
    }

    $journal = @{
        Format = 'SimOpenTrackDay.InstallJournal'
        Version = 1
        TransactionId = $transactionId
        State = 'Prepared'
        TargetRoot = (ConvertTo-SotdComparablePath $TargetRoot)
        BackupRoot = (ConvertTo-SotdComparablePath $BackupRoot)
        BackupTransactionRoot = (ConvertTo-SotdComparablePath $backupTransactionRoot)
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Progress = 'Prepared'
        Entries = @($journalEntries.ToArray())
    }

    # The durable journal precedes every backup and installation file mutation.
    Write-SotdJournal $journal $journalPath
    try {
        [void][IO.Directory]::CreateDirectory($BackupRoot)
        [void][IO.Directory]::CreateDirectory($backupTransactionRoot)

        foreach ($entry in $journal.Entries) {
            if (-not $entry.Changed -or -not $entry.OriginalHash) { continue }
            $item = $null
            foreach ($candidate in $Plan) { if ($candidate.RelativePath -eq $entry.RelativePath) { $item = $candidate; break } }
            if ($null -eq $item -or (Get-SotdSha256 $item.TargetPath) -ne $entry.OriginalHash) {
                throw "Target changed since preview; refusing to back up '$($entry.RelativePath)'."
            }
            $backupPath = Join-Path $backupTransactionRoot ($entry.BackupRelativePath -replace '/', '\')
            Assert-SotdNoReparseAncestors $backupPath
            $backupParent = Split-Path -Parent $backupPath
            [void][IO.Directory]::CreateDirectory($backupParent)
            if (Test-Path -LiteralPath $backupPath) { throw "Backup file already exists: '$backupPath'." }
            $journal.State = 'BackingUp'
            $journal.Progress = 'Backing up ' + $entry.RelativePath
            $entry.Status = 'BackingUp'
            Write-SotdJournal $journal $journalPath
            Copy-Item -LiteralPath $item.TargetPath -Destination $backupPath -ErrorAction Stop
            if ((Get-SotdSha256 $backupPath) -ne $entry.OriginalHash) { throw "Backup hash verification failed for '$($entry.RelativePath)'." }
            $entry.Status = 'BackedUp'
            $journal.Progress = 'Backed up ' + $entry.RelativePath
            Write-SotdJournal $journal $journalPath
        }

        foreach ($entry in $journal.Entries) {
            if (-not $entry.Changed) { continue }
            $item = $null
            foreach ($candidate in $Plan) { if ($candidate.RelativePath -eq $entry.RelativePath) { $item = $candidate; break } }
            if ($null -eq $item) { throw "Internal plan entry missing: '$($entry.RelativePath)'." }
            if ((Get-SotdSha256 $item.SourcePath) -ne $entry.NewHash) { throw "Payload changed since validation: '$($entry.RelativePath)'." }
            $currentExists = Test-Path -LiteralPath $item.TargetPath -PathType Leaf
            if ($entry.OriginalHash) {
                if (-not $currentExists -or (Get-SotdSha256 $item.TargetPath) -ne $entry.OriginalHash) {
                    throw "Target changed since preview; refusing to replace '$($entry.RelativePath)'."
                }
            } elseif ($currentExists -or (Test-Path -LiteralPath $item.TargetPath)) {
                throw "New target appeared since preview; refusing to overwrite '$($entry.RelativePath)'."
            }
            $targetParent = Split-Path -Parent $item.TargetPath
            [void][IO.Directory]::CreateDirectory($targetParent)
            $tempPath = Join-Path $TargetRoot ($entry.InstallTempRelativePath -replace '/', '\')
            if (Test-Path -LiteralPath $tempPath) { throw "Install temp path appeared: '$tempPath'." }
            Assert-SotdNoReparseAncestors $tempPath
            $journal.State = 'Installing'
            $journal.Progress = 'Installing ' + $entry.RelativePath
            $entry.Status = 'Installing'
            Write-SotdJournal $journal $journalPath
            Copy-Item -LiteralPath $item.SourcePath -Destination $tempPath -ErrorAction Stop
            if ((Get-SotdSha256 $tempPath) -ne $entry.NewHash) { throw "Staged payload hash verification failed for '$($entry.RelativePath)'." }
            if ($entry.OriginalHash) {
                $rollbackTempPath = Join-Path $TargetRoot ($entry.RollbackTempRelativePath -replace '/', '\')
                [IO.File]::Replace($tempPath, $item.TargetPath, $rollbackTempPath)
                if ((Get-SotdSha256 $rollbackTempPath) -ne $entry.OriginalHash) { throw "Atomic replacement backup hash mismatch for '$($entry.RelativePath)'." }
            }
            else { [IO.File]::Move($tempPath, $item.TargetPath) }
            if ((Get-SotdSha256 $item.TargetPath) -ne $entry.NewHash) { throw "Installed hash verification failed for '$($entry.RelativePath)'." }
            $entry.Status = 'Installed'
            $journal.Progress = 'Installed ' + $entry.RelativePath
            Write-SotdJournal $journal $journalPath
        }
        $journal.State = 'Installed'
        $journal.Progress = 'Complete'
        Write-SotdJournal $journal $journalPath
        Write-Host "Install complete. Rollback journal: $journalPath"
        return $journalPath
    } catch {
        $journal.State = 'Interrupted'
        $journal.Progress = 'Interrupted: ' + $_.Exception.Message
        try { Write-SotdJournal $journal $journalPath } catch { }
        throw "Install stopped safely. Recovery journal: '$journalPath'. Do not delete it; run -Mode Rollback -AssettoCorsaRoot `"$AssettoCorsaRoot`" -JournalPath `"$journalPath`". Cause: $($_.Exception.Message)"
    }
}

function Read-SotdJournal {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-SotdFullPath $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Journal file does not exist: '$full'." }
    Assert-SotdNoReparseAncestors $full
    try { $journal = [IO.File]::ReadAllText($full) | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Cannot parse rollback journal '$full': $($_.Exception.Message)" }
    if ($journal.Format -ne 'SimOpenTrackDay.InstallJournal' -or $journal.Version -ne 1 -or
        $journal.TransactionId -notmatch '^[A-Fa-f0-9]{32}$' -or $null -eq $journal.Entries) {
        throw 'Unsupported or invalid installer journal.'
    }
    return $journal
}

function Invoke-SotdRollback {
    param([string]$AssettoCorsaRoot, [string]$JournalPath, [string]$RequestedBackupRoot)
    if (-not $AssettoCorsaRoot) { throw '-AssettoCorsaRoot is required for Rollback.' }
    if (-not $JournalPath) { throw '-JournalPath is required for Rollback.' }
    $ac = Get-SotdACPaths $AssettoCorsaRoot
    $journalFullPath = ConvertTo-SotdFullPath $JournalPath
    $journal = Read-SotdJournal $journalFullPath
    $targetRoot = ConvertTo-SotdComparablePath $journal.TargetRoot
    $backupRoot = ConvertTo-SotdComparablePath $journal.BackupRoot
    $backupTransactionRoot = ConvertTo-SotdComparablePath $journal.BackupTransactionRoot
    $expectedBackupTransactionRoot = ConvertTo-SotdComparablePath (Join-Path $backupRoot ('SimOpenTrackDay-' + $journal.TransactionId))
    if (-not [string]::Equals($backupTransactionRoot, $expectedBackupTransactionRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Journal backup transaction root does not match its backup root and transaction ID.'
    }
    if (-not [string]::Equals($ac.Target, $targetRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Journal target '$targetRoot' does not match the supplied Assetto Corsa target '$($ac.Target)'."
    }
    if ($RequestedBackupRoot -and -not [string]::Equals((ConvertTo-SotdComparablePath $RequestedBackupRoot), $backupRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Supplied -BackupRoot does not match the journal backup root.'
    }
    Assert-SotdNoOverlap $targetRoot $backupRoot 'Installation and backup'
    Assert-SotdNoOverlap $backupRoot $script:PackageRoot 'Backup and package'
    Assert-SotdNoOverlap $journalFullPath $targetRoot 'Journal and target'
    Assert-SotdNoOverlap $journalFullPath $script:PackageRoot 'Journal and package'
    Assert-SotdNoOverlap $journalFullPath $backupTransactionRoot 'Journal and transaction backup'
    Assert-SotdNoOverlap $backupTransactionRoot $targetRoot 'Transaction backup and target'
    Assert-SotdNoOverlap $backupTransactionRoot $script:PackageRoot 'Transaction backup and package'
    Assert-SotdNoReparseAncestors $targetRoot
    Assert-SotdDirectoryAncestors $backupRoot
    Assert-SotdNoReparseAncestors $backupRoot
    Assert-SotdNoReparseAncestors $backupTransactionRoot

    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $preflight = New-Object System.Collections.ArrayList
    foreach ($entry in $journal.Entries) {
        if ($entry.Changed -isnot [bool]) { throw "Invalid Changed flag in journal for '$($entry.RelativePath)'." }
        $allowedStatuses = @('Pending', 'BackingUp', 'BackedUp', 'Installing', 'Installed', 'RolledBack', 'Unchanged')
        if ($entry.Status -isnot [string] -or $entry.Status -notin $allowedStatuses) { throw "Invalid status in journal for '$($entry.RelativePath)'." }
        Assert-SotdSafeRelativePath ([string]$entry.RelativePath)
        if (-not $seen.Add([string]$entry.RelativePath)) { throw "Duplicate/case-colliding path in journal: '$($entry.RelativePath)'." }
        Assert-SotdHash ([string]$entry.NewHash) "journal new hash for $($entry.RelativePath)"
        if ($entry.OriginalHash) { Assert-SotdHash ([string]$entry.OriginalHash) "journal original hash for $($entry.RelativePath)" }
        if (-not $entry.Changed) {
            if ($entry.Status -ne 'Unchanged' -or -not $entry.OriginalHash -or $entry.OriginalHash -ne $entry.NewHash -or
                $entry.BackupRelativePath -or $entry.InstallTempRelativePath -or $entry.RollbackTempRelativePath) {
                throw "Inconsistent unchanged entry in journal for '$($entry.RelativePath)'."
            }
            continue
        }
        if ($entry.Status -eq 'Unchanged') { throw "Changed entry is marked Unchanged in journal for '$($entry.RelativePath)'." }
        if ($entry.OriginalHash) {
            if ($entry.BackupRelativePath -ne (Join-SotdRelative 'files' $entry.RelativePath)) { throw "Forged backup path in journal for '$($entry.RelativePath)'." }
        } elseif ($entry.BackupRelativePath) { throw "Unexpected backup path for new file '$($entry.RelativePath)'." }
        if (-not $entry.InstallTempRelativePath) { throw "Missing install temp path in journal for '$($entry.RelativePath)'." }
        if ([bool]$entry.OriginalHash -ne [bool]$entry.RollbackTempRelativePath) { throw "Inconsistent rollback temp metadata for '$($entry.RelativePath)'." }
        $target = Join-Path $targetRoot ($entry.RelativePath -replace '/', '\')
        Assert-SotdDirectoryAncestors $target
        Assert-SotdNoReparseAncestors $target
        $exists = Test-Path -LiteralPath $target
        if ($exists -and (Get-Item -LiteralPath $target -Force).PSIsContainer) { throw "Rollback target is a directory: '$target'." }
        $currentHash = if ($exists) { Get-SotdSha256 $target } else { $null }
        $backupPath = $null
        if ($entry.OriginalHash) {
            $expectedBackupRelative = Join-SotdRelative 'files' $entry.RelativePath
            $backupPath = Join-Path $backupTransactionRoot ($expectedBackupRelative -replace '/', '\')
            Assert-SotdFileOrAbsent $backupPath
            if (Test-Path -LiteralPath $backupPath) {
                if ((Get-SotdSha256 $backupPath) -ne $entry.OriginalHash) { throw "Backup hash mismatch for '$($entry.RelativePath)'." }
            }
        }
        $installTempExpected = Get-SotdInstallTempRelative $entry.RelativePath $journal.TransactionId
        if ($entry.Changed -and $entry.InstallTempRelativePath -ne $installTempExpected) { throw "Forged install temp path in journal for '$($entry.RelativePath)'." }
        $installTemp = if ($entry.InstallTempRelativePath) { Join-Path $targetRoot ($entry.InstallTempRelativePath -replace '/', '\') } else { $null }
        if ($installTemp) {
            Assert-SotdSafeRelativePath $entry.InstallTempRelativePath
            Assert-SotdFileOrAbsent $installTemp
            if (Test-Path -LiteralPath $installTemp) {
                $installTempHash = Get-SotdSha256 $installTemp
                if ($installTempHash -ne $entry.NewHash -and
                    ($entry.Status -notin @('Installing', 'RolledBack') -or $journal.State -notin @('Interrupted', 'Installing', 'RollingBack', 'RolledBack') -or
                     ($entry.OriginalHash -and $currentHash -ne $entry.OriginalHash) -or (-not $entry.OriginalHash -and $currentHash))) {
                    throw "Unrecognized install temp contents for '$($entry.RelativePath)'; preserving conflicting file."
                }
            }
        }
        $rollbackTemp = $null
        if ($entry.OriginalHash -and $entry.Changed) {
            $rollbackTempExpected = Get-SotdRollbackTempRelative $entry.RelativePath $journal.TransactionId
            if ($entry.RollbackTempRelativePath -ne $rollbackTempExpected) { throw "Forged rollback temp path in journal for '$($entry.RelativePath)'." }
            $rollbackTemp = Join-Path $targetRoot ($entry.RollbackTempRelativePath -replace '/', '\')
            Assert-SotdSafeRelativePath $entry.RollbackTempRelativePath
            Assert-SotdFileOrAbsent $rollbackTemp
            if ((Test-Path -LiteralPath $rollbackTemp) -and (Get-SotdSha256 $rollbackTemp) -ne $entry.OriginalHash) {
                throw "Rollback temp hash conflict for '$($entry.RelativePath)'."
            }
        }

        foreach ($tempKind in @('Restore', 'Displaced')) {
            $propertyName = $tempKind + 'TempRelativePaths'
            $registeredTemps = @($entry.$propertyName)
            $seenTemps = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            foreach ($relativeTemp in $registeredTemps) {
                if (-not $relativeTemp) { throw "Empty $tempKind temp path in journal for '$($entry.RelativePath)'." }
                Assert-SotdSafeRelativePath ([string]$relativeTemp)
                $kind = $tempKind.ToLowerInvariant()
                $template = Get-SotdUniqueTransactionTempRelative $entry.RelativePath $journal.TransactionId $kind 'SOTDUID'
                $prefix = $template.Substring(0, $template.IndexOf('SOTDUID', [StringComparison]::Ordinal))
                $ownedPattern = '^' + [regex]::Escape($prefix) + '[A-Fa-f0-9]{32}\.tmp$'
                if (-not ([string]$relativeTemp -match $ownedPattern)) {
                    throw "Unowned $tempKind temp path in journal for '$($entry.RelativePath)'."
                }
                if (-not $seenTemps.Add([string]$relativeTemp)) { throw "Duplicate $tempKind temp path in journal." }
                $tempPath = Join-Path $targetRoot ([string]$relativeTemp -replace '/', '\')
                Assert-SotdFileOrAbsent $tempPath
                if (Test-Path -LiteralPath $tempPath) {
                    $tempHash = Get-SotdSha256 $tempPath
                    $expectedHash = if ($tempKind -eq 'Restore') { $entry.OriginalHash } else { $entry.NewHash }
                    if (-not $expectedHash) { throw "Unexpected $tempKind temp for new file '$($entry.RelativePath)'." }
                    if ($tempHash -ne $expectedHash -and $journal.State -notin @('RollingBack', 'Interrupted')) {
                        throw "Unrecognized $tempKind temp contents for '$($entry.RelativePath)'."
                    }
                }
            }
        }

        if ($entry.Changed) {
            if ($entry.OriginalHash) {
                if ($currentHash -and $currentHash -ne $entry.OriginalHash -and $currentHash -ne $entry.NewHash) {
                    throw "Rollback conflict: target '$($entry.RelativePath)' changed after installation."
                }
                if ($currentHash -eq $entry.NewHash -and -not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
                    throw "Required original backup is missing for '$($entry.RelativePath)'."
                }
                if (-not $currentHash) { throw "Rollback conflict: original target '$($entry.RelativePath)' is missing." }
            } elseif ($currentHash -and $currentHash -ne $entry.NewHash) {
                throw "Rollback conflict: newly installed target '$($entry.RelativePath)' was modified."
            }
        }
        [void]$preflight.Add(@{
            Entry = $entry; Target = $target; Exists = [bool]$exists; CurrentHash = $currentHash
            Backup = $backupPath; InstallTemp = $installTemp; RollbackTemp = $rollbackTemp
        })
    }

    # No target changes occur before every target, temporary, and available backup passes preflight.
    $journal.State = 'RollingBack'
    $journal.Progress = 'Preflight complete'
    Write-SotdJournal $journal $journalFullPath
    foreach ($item in $preflight) {
        $entry = $item.Entry
        if (-not $entry.Changed) { continue }
        $targetNowExists = Test-Path -LiteralPath $item.Target -PathType Leaf
        $targetNowHash = if ($targetNowExists) { Get-SotdSha256 $item.Target } else { $null }
        if ($entry.OriginalHash -and $targetNowHash -eq $entry.NewHash) {
            $restoreId = [guid]::NewGuid().ToString('N')
            $restoreRelative = Get-SotdUniqueTransactionTempRelative $entry.RelativePath $journal.TransactionId 'restore' $restoreId
            $displacedRelative = Get-SotdUniqueTransactionTempRelative $entry.RelativePath $journal.TransactionId 'displaced' $restoreId
            $restorePath = Join-Path $targetRoot ($restoreRelative -replace '/', '\')
            $displacedPath = Join-Path $targetRoot ($displacedRelative -replace '/', '\')
            Assert-SotdFileOrAbsent $restorePath
            Assert-SotdFileOrAbsent $displacedPath
            $entry.RestoreTempRelativePaths = @(@($entry.RestoreTempRelativePaths) + @($restoreRelative))
            $entry.DisplacedTempRelativePaths = @(@($entry.DisplacedTempRelativePaths) + @($displacedRelative))
            $journal.Progress = 'Preparing restore ' + $entry.RelativePath
            Write-SotdJournal $journal $journalFullPath
            $parent = Split-Path -Parent $restorePath
            [void][IO.Directory]::CreateDirectory($parent)
            Copy-Item -LiteralPath $item.Backup -Destination $restorePath -ErrorAction Stop
            if ((Get-SotdSha256 $restorePath) -ne $entry.OriginalHash) { throw "Restore staging hash mismatch for '$($entry.RelativePath)'. Journal: '$journalFullPath'." }
            if ((Get-SotdSha256 $item.Target) -ne $entry.NewHash) { throw "Target changed during rollback: '$($entry.RelativePath)'. Journal: '$journalFullPath'." }
            $journal.Progress = 'Restoring ' + $entry.RelativePath
            Write-SotdJournal $journal $journalFullPath
            [IO.File]::Replace($restorePath, $item.Target, $displacedPath)
            if ((Get-SotdSha256 $displacedPath) -ne $entry.NewHash) { throw "Displaced file hash mismatch for '$($entry.RelativePath)'. Journal: '$journalFullPath'." }
        } elseif (-not $entry.OriginalHash -and $targetNowHash -eq $entry.NewHash) {
            $journal.Progress = 'Removing created file ' + $entry.RelativePath
            Write-SotdJournal $journal $journalFullPath
            if ((Get-SotdSha256 $item.Target) -ne $entry.NewHash) { throw "New target changed during rollback: '$($entry.RelativePath)'. Journal: '$journalFullPath'." }
            [IO.File]::Delete($item.Target)
        }
        if ($item.InstallTemp -and (Test-Path -LiteralPath $item.InstallTemp -PathType Leaf)) {
            if ((Get-SotdSha256 $item.InstallTemp) -eq $entry.NewHash) {
                $journal.Progress = 'Removing verified staged file ' + $entry.RelativePath
                Write-SotdJournal $journal $journalFullPath
                [IO.File]::Delete($item.InstallTemp)
            }
        }
        $entry.Status = 'RolledBack'
        $journal.Progress = 'Rolled back ' + $entry.RelativePath
        Write-SotdJournal $journal $journalFullPath
    }
    $journal.State = 'RolledBack'
    $journal.Progress = 'Complete'
    Write-SotdJournal $journal $journalFullPath
    Write-Host "Rollback complete. Journal retained: $journalFullPath"
}

function Invoke-SotdInstaller {
    param(
        [ValidateSet('Preview', 'Install', 'Rollback')][string]$Mode = 'Preview',
        [string]$AssettoCorsaRoot,
        [string]$BackupRoot,
        [string]$JournalPath
    )
    if ($Mode -eq 'Rollback') {
        Invoke-SotdRollback $AssettoCorsaRoot $JournalPath $BackupRoot
        return
    }
    if (-not $AssettoCorsaRoot) { throw '-AssettoCorsaRoot is required for Preview and Install.' }
    $ac = Get-SotdACPaths $AssettoCorsaRoot
    if (-not $BackupRoot) {
        if ($env:LOCALAPPDATA) { $BackupRoot = Join-Path $env:LOCALAPPDATA 'SimOpenTrackDay\InstallerBackups' }
        else { $BackupRoot = Join-Path $env:USERPROFILE 'SimOpenTrackDay\InstallerBackups' }
    }
    $BackupRoot = ConvertTo-SotdComparablePath $BackupRoot
    Assert-SotdNoOverlap $script:PackageRoot $ac.Target 'Package and installation target'
    Assert-SotdNoOverlap $BackupRoot $ac.Target 'Backup and installation target'
    Assert-SotdNoOverlap $BackupRoot $script:PackageRoot 'Backup and package'
    Assert-SotdNoReparseAncestors $BackupRoot
    $plan = Get-SotdPayloadPlan $ac.Target
    Write-Host "Source: $script:PackageRoot\$script:PayloadRelativeRoot"
    Write-Host "Target: $($ac.Target)"
    foreach ($item in $plan) { Write-Host ('{0,-9} {1}' -f $item.Status, $item.RelativePath) }
    if ($Mode -eq 'Preview') { return }

    $confirmation = Read-Host 'Type YES to install these checksum-verified files'
    if ($confirmation -cne 'YES') { Write-Host 'Cancelled; no installation files were written.'; return }

    # Revalidate all source and target hashes after confirmation before creating the journal.
    $freshPlan = Get-SotdPayloadPlan $ac.Target
    if ($freshPlan.Count -ne $plan.Count) { throw 'Payload changed after preview; refusing installation.' }
    for ($index = 0; $index -lt $plan.Count; $index++) {
        if ($freshPlan[$index].RelativePath -cne $plan[$index].RelativePath -or
            $freshPlan[$index].SourceHash -ne $plan[$index].SourceHash -or
            $freshPlan[$index].OriginalHash -ne $plan[$index].OriginalHash) {
            throw "Source or target changed after preview at '$($plan[$index].RelativePath)'."
        }
    }
    return Install-SotdPlan $freshPlan $ac.Target $ac.Root $BackupRoot $JournalPath
}

function Invoke-SotdSelfTest {
    param([switch]$WhatIf)
    Write-Host 'Self-test placeholder (will be implemented in unit U6).'
    return 0
}

function Show-SotdInteractiveMenu {
    param(
        [string]$AssettoCorsaRoot,
        [string]$BackupRoot,
        [string]$JournalPath,
        [switch]$NoPause
    )
    Write-Host 'SimOpenTrackDay installer'
    Write-Host '========================='
    while ($true) {
        Write-Host ''
        Write-Host '  1) Preview (read-only)'
        Write-Host '  2) Install (writes files, needs YES)'
        Write-Host '  3) Rollback from a journal'
        Write-Host '  4) Run self-test (sandbox smoke check)'
        Write-Host '  5) Exit'
        $selection = Read-Host 'Choose an option [1-5]:'
        if ($null -ne $selection) { $selection = ([string]$selection).Trim() } else { $selection = '' }

        if ($selection -eq '5') {
            Write-Host 'Exiting installer.'
            return
        }
        if ($selection -eq '4') {
            $null = Invoke-SotdSelfTest
        } elseif ($selection -eq '1' -or $selection -eq '2' -or $selection -eq '3') {
            if (-not $AssettoCorsaRoot) {
                $AssettoCorsaRoot = Read-Host 'Assetto Corsa root (folder containing acs.exe):'
            }
            if (-not $AssettoCorsaRoot) {
                Write-Host 'An Assetto Corsa root is required for this action.'
                continue
            }
            if ($selection -eq '1') {
                $previewArguments = @{ Mode = 'Preview'; AssettoCorsaRoot = $AssettoCorsaRoot }
                if ($BackupRoot) { $previewArguments.BackupRoot = $BackupRoot }
                $null = Invoke-SotdInstaller @previewArguments
            } elseif ($selection -eq '2') {
                if (-not $BackupRoot) { $BackupRoot = Read-Host 'Backup root (leave empty for default):' }
                if (-not $JournalPath) { $JournalPath = Read-Host 'Journal path (leave empty for default):' }
                $installArguments = @{ Mode = 'Install'; AssettoCorsaRoot = $AssettoCorsaRoot; BackupRoot = $BackupRoot; JournalPath = $JournalPath }
                $null = Invoke-SotdInstaller @installArguments
            } else {
                if (-not $JournalPath) { $JournalPath = Read-Host 'Journal path (leave empty for default):' }
                $rollbackArguments = @{ Mode = 'Rollback'; AssettoCorsaRoot = $AssettoCorsaRoot; JournalPath = $JournalPath }
                if ($BackupRoot) { $rollbackArguments.BackupRoot = $BackupRoot }
                $null = Invoke-SotdInstaller @rollbackArguments
            }
        } else {
            Write-Host 'Invalid choice'
            continue
        }

        if (-not $NoPause) {
            $reply = Read-Host 'Press Enter to return to the menu, or type Q to quit:'
            if ($reply -and ([string]$reply).Trim() -match '^(?i:q)$') { return }
        }
    }
}

if (-not $LibraryOnly) {
    if ($Interactive) {
        try {
            $menuArguments = @{}
            if ($AssettoCorsaRoot) { $menuArguments.AssettoCorsaRoot = $AssettoCorsaRoot }
            if ($BackupRoot) { $menuArguments.BackupRoot = $BackupRoot }
            if ($JournalPath) { $menuArguments.JournalPath = $JournalPath }
            Show-SotdInteractiveMenu @menuArguments -NoPause:$NoPause
            exit 0
        } catch {
            [Console]::Error.WriteLine("Installer error: $($_.Exception.Message)")
            exit 1
        }
    }
    try {
        Invoke-SotdInstaller -Mode $Mode -AssettoCorsaRoot $AssettoCorsaRoot -BackupRoot $BackupRoot -JournalPath $JournalPath
        exit 0
    } catch {
        [Console]::Error.WriteLine("Installer error: $($_.Exception.Message)")
        exit 1
    }
}
