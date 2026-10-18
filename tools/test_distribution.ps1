$ErrorActionPreference = 'Stop'
$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-CommandLineArgument([string]$Value) {
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $backslashes++; continue }
        if ($character -eq '"') {
            for ($index = 0; $index -lt (2 * $backslashes + 1); $index++) { [void]$builder.Append('\') }
            [void]$builder.Append('"')
        } else {
            for ($index = 0; $index -lt $backslashes; $index++) { [void]$builder.Append('\') }
            [void]$builder.Append($character)
        }
        $backslashes = 0
    }
    for ($index = 0; $index -lt (2 * $backslashes); $index++) { [void]$builder.Append('\') }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-ChildProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Arguments,
        [string]$StandardInput
    )
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FileName
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Could not start child process: $FileName" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if ($null -ne $StandardInput) { $process.StandardInput.WriteLine($StandardInput) }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(180000)) {
        try { $process.Kill() } catch { }
        throw "Child process timed out: $FileName $Arguments"
    }
    $process.WaitForExit()
    $result = [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdoutTask.Result
        StdErr = $stderrTask.Result
    }
    $process.Dispose()
    return $result
}

function Get-TargetSnapshot([string]$TargetRoot) {
    $snapshot = @{}
    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { return $snapshot }
    foreach ($file in Get-ChildItem -LiteralPath $TargetRoot -File -Recurse -Force) {
        $relative = $file.FullName.Substring($TargetRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        $snapshot[$relative] = Get-Sha256 $file.FullName
    }
    return $snapshot
}

function Assert-SnapshotsEqual($Expected, $Actual, [string]$Message) {
    Assert ($Expected.Count -eq $Actual.Count) "$Message (file count differs: expected $($Expected.Count), actual $($Actual.Count): $(@($Actual.Keys) -join ', '))"
    foreach ($relative in $Expected.Keys) {
        Assert ($Actual.ContainsKey($relative) -and $Actual[$relative] -ceq $Expected[$relative]) `
            "$Message (changed or missing $relative)"
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$approvedRoot = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $approvedRoot -PathType Container)) {
    throw "Approved distribution-test sandbox is unavailable: $approvedRoot"
}
$sandbox = Join-Path $approvedRoot ('SOTD distribution ! & ' + [Guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $sandbox 'package source ! & with spaces'
$acRoot = Join-Path $sandbox 'Assetto Corsa ! & with spaces'
$targetRoot = Join-Path $acRoot 'apps/lua/SimOpenTrackDay'
$backupRoot = Join-Path $sandbox 'backups ! & with spaces'
$journalPath = Join-Path $backupRoot 'install-journal.json'
$builderPath = Join-Path $PSScriptRoot 'build_package.ps1'
$manifestPath = Join-Path $PSScriptRoot 'runtime-manifest.txt'
$installerSource = Join-Path $PSScriptRoot 'distribution/installer.ps1'
$launcherSource = Join-Path $PSScriptRoot 'distribution/install.bat'
$powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$cmdExe = Join-Path $env:WINDIR 'System32/cmd.exe'

try {
    [void][IO.Directory]::CreateDirectory($sandbox)
    & $builderPath -SourceRoot $repositoryRoot -OutputPath $packageRoot -Build | Out-Null

    $installerPath = Join-Path $packageRoot 'installer.ps1'
    $launcherPath = Join-Path $packageRoot 'install.bat'
    $installDocPath = Join-Path $packageRoot 'INSTALL.md'
    Assert (Test-Path -LiteralPath $installerPath -PathType Leaf) 'real installer script is copied at package root'
    Assert (Test-Path -LiteralPath $launcherPath -PathType Leaf) 'real batch launcher is copied at package root'
    Assert (Test-Path -LiteralPath $installDocPath -PathType Leaf) 'current install instructions are copied at package root'
    $installerBytes = [IO.File]::ReadAllBytes($installerPath)
    Assert ($installerBytes.Length -ge 3 -and $installerBytes[0] -eq 239 -and
        $installerBytes[1] -eq 187 -and $installerBytes[2] -eq 191) 'packaged installer retains its UTF-8 BOM'

    $runtimeManifestLines = @([IO.File]::ReadAllLines($manifestPath) |
        ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 -and -not $_.StartsWith('#') })
    $runtimePaths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in $runtimeManifestLines) {
        if ($line -ceq 'lib/i18n/*.lua') {
            foreach ($locale in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'lib/i18n') -File |
                Where-Object { $_.Name.EndsWith('.lua', [StringComparison]::Ordinal) }) {
                $runtimePaths.Add('lib/i18n/' + $locale.Name)
            }
        } else {
            $runtimePaths.Add($line)
        }
    }
    $expectedPaths = [string[]]$runtimePaths.ToArray()
    [Array]::Sort($expectedPaths, [StringComparer]::Ordinal)
    Assert ($expectedPaths.Count -eq 66) 'current source manifest resolves to exactly 66 runtime payload files'

    $payloadRoot = Join-Path $packageRoot 'payload/SimOpenTrackDay'
    $packagedFiles = @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse -Force)
    Assert ($packagedFiles.Count -eq 66) 'real package contains exactly 66 payload files'
    $checksumLines = [IO.File]::ReadAllLines((Join-Path $packageRoot 'checksums.sha256'))
    Assert ($checksumLines.Count -eq 66) 'real checksum list contains only the 66 runtime entries'
    $checksumSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($line in $checksumLines) {
        if ($line -cnotmatch '^([0-9a-f]{64})  payload/SimOpenTrackDay/(.+)$') {
            throw "Invalid checksum line in real package: $line"
        }
        $relative = $Matches[2]
        Assert ($checksumSet.Add($relative)) "checksum path is unique: $relative"
        $sourcePath = Join-Path $repositoryRoot ($relative.Replace('/', '\'))
        $packagePath = Join-Path $payloadRoot ($relative.Replace('/', '\'))
        Assert (Test-Path -LiteralPath $packagePath -PathType Leaf) "real payload file exists: $relative"
        Assert ((Get-Sha256 $packagePath) -ceq (Get-Sha256 $sourcePath)) "packaged hash equals current source hash: $relative"
        Assert ($Matches[1] -ceq (Get-Sha256 $packagePath)) "checksum verifies packaged source: $relative"
    }
    foreach ($relative in $expectedPaths) {
        Assert ($checksumSet.Contains($relative)) "checksum covers exact manifest path: $relative"
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'CarStateMachine/CarState_TEMPLATE.lua'))) 'state template is excluded'
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'CarStateMachine/States/CarState_DefendingPosition.lua'))) 'unused DefendingPosition state is excluded'
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'lib/ac_apps'))) 'vendor SDK payload is excluded'
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'Profiler.lua'))) 'dormant runtime modules are excluded'
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot '.git'))) 'repository metadata is excluded'

    $manifestPackage = [IO.File]::ReadAllText((Join-Path $payloadRoot 'manifest.ini'))
    $constantsPackage = [IO.File]::ReadAllText((Join-Path $payloadRoot 'Constants.lua'))
    Assert ($manifestPackage -match '(?m)^VERSION\s*=\s*0\.1\s*$' -and
        $constantsPackage -match 'APP_VERSION\s*=\s*"0\.1"') 'package manifest and runtime Constants both declare version 0.1'
    Assert ($manifestPackage -match '(?m)^AUTHOR\s*=\s*dreasgrech\s*$' -and
        $constantsPackage -match 'APP_AUTHOR\s*=\s*"dreasgrech"') 'package metadata preserves the existing author'
    Assert ([IO.File]::ReadAllText((Join-Path $payloadRoot 'LICENSE')).Contains('MIT License')) 'MIT license is retained in payload'
    Assert ([IO.File]::ReadAllText((Join-Path $payloadRoot 'lib/AssettoCorsaCSPLuaCompatibilityManager/README.md')).Length -gt 0) `
        'CSP compatibility notice is retained in payload'

    $rootFiles = @((Get-ChildItem -LiteralPath $packageRoot -File -Force | ForEach-Object { $_.Name }) | Sort-Object -CaseSensitive)
    $expectedRootFiles = @(@('INSTALL.md', 'checksums.sha256', 'install.bat', 'installer.logging.ps1', 'installer.ps1') | Sort-Object -CaseSensitive)
    Assert (($rootFiles -join '|') -ceq ($expectedRootFiles -join '|')) 'package root has only the delivery files and checksum list'

    [void][IO.Directory]::CreateDirectory((Join-Path $acRoot 'apps'))
    [void][IO.Directory]::CreateDirectory($targetRoot)
    [IO.File]::WriteAllText((Join-Path $acRoot 'acs.exe'), 'sandbox executable marker')
    foreach ($relative in @('Constants.lua', 'LICENSE')) {
        $source = Join-Path $payloadRoot ($relative.Replace('/', '\'))
        $destination = Join-Path $targetRoot ($relative.Replace('/', '\'))
        Copy-Item -LiteralPath $source -Destination $destination
    }
    $originalChangedFiles = @{
        'SimOpenTrackDay.lua' = 'old entry file contents'
        'UIManager.lua' = 'old manager file contents'
    }
    foreach ($relative in $originalChangedFiles.Keys) {
        [IO.File]::WriteAllText((Join-Path $targetRoot $relative), $originalChangedFiles[$relative])
    }
    [IO.File]::WriteAllText((Join-Path $targetRoot 'user-settings.ini'), 'preserve existing user settings')
    [IO.File]::WriteAllText((Join-Path $targetRoot 'unknown-user-extra.bin'), 'preserve unknown user file')
    $initialTarget = Get-TargetSnapshot $targetRoot
    Assert ($initialTarget.Count -eq 6) 'fake AC starts with two unchanged, two changed, and two unrelated files'

    $previewArguments = @('-NoProfile', '-File', $installerPath,
        '-AssettoCorsaRoot', $acRoot, '-BackupRoot', $backupRoot, '-JournalPath', $journalPath)
    $previewCommandLine = (($previewArguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $previewResult = Invoke-ChildProcess -FileName $powershellExe -Arguments $previewCommandLine
    Assert ($previewResult.ExitCode -eq 0) "real -File default preview succeeds (stderr: $($previewResult.StdErr))"
    Assert ($previewResult.StdOut.Contains('Unchanged') -and $previewResult.StdOut.Contains('Changed') -and
        $previewResult.StdOut.Contains('New')) 'default preview reports the mixed target plan'
    Assert-SnapshotsEqual $initialTarget (Get-TargetSnapshot $targetRoot) 'preview leaves AC target unchanged'
    Assert (-not (Test-Path -LiteralPath $backupRoot) -and -not (Test-Path -LiteralPath $journalPath)) `
        'default preview creates no backup or journal'

    $installArguments = @('-NoProfile', '-File', $installerPath, '-Mode', 'Install',
        '-AssettoCorsaRoot', $acRoot, '-BackupRoot', $backupRoot, '-JournalPath', $journalPath)
    $installCommandLine = (($installArguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $installResult = Invoke-ChildProcess -FileName $powershellExe -Arguments $installCommandLine -StandardInput 'YES'
    Assert ($installResult.ExitCode -eq 0) "real CLI install accepts exact YES (stderr: $($installResult.StdErr))"
    Assert ($installResult.StdOut.Contains('Install complete')) 'CLI reports completed install'
    Assert (Test-Path -LiteralPath $journalPath -PathType Leaf) 'CLI install creates the requested rollback journal'
    $journal = [IO.File]::ReadAllText($journalPath) | ConvertFrom-Json
    $journalEntries = @($journal.Entries)
    Assert ($journalEntries.Count -eq 66) 'install journal records all 66 checksum-listed runtime files'
    Assert (@($journalEntries | Where-Object { $_.Status -eq 'Unchanged' }).Count -eq 2) 'journal identifies the two unchanged files'
    Assert (@($journalEntries | Where-Object { $_.OriginalHash -and $_.Status -eq 'Installed' }).Count -eq 2) 'journal records the two replaced old files'
    Assert (@($journalEntries | Where-Object { -not $_.OriginalHash -and $_.Status -eq 'Installed' }).Count -eq 62) 'journal records all new runtime files'
    foreach ($relative in $expectedPaths) {
        $targetFile = Join-Path $targetRoot ($relative.Replace('/', '\'))
        $packageFile = Join-Path $payloadRoot ($relative.Replace('/', '\'))
        Assert ((Get-Sha256 $targetFile) -ceq (Get-Sha256 $packageFile)) "installed hash matches package: $relative"
    }
    Assert (([IO.File]::ReadAllText((Join-Path $targetRoot 'user-settings.ini'))) -ceq 'preserve existing user settings') `
        'install preserves unknown user settings'
    Assert (([IO.File]::ReadAllText((Join-Path $targetRoot 'unknown-user-extra.bin'))) -ceq 'preserve unknown user file') `
        'install preserves unrelated files'
    $backupTransactionRoot = [string]$journal.BackupTransactionRoot
    foreach ($relative in $originalChangedFiles.Keys) {
        $backupFile = Join-Path $backupTransactionRoot ('files/' + $relative)
        Assert (([IO.File]::ReadAllText($backupFile)) -ceq $originalChangedFiles[$relative]) `
            "backup preserves pre-install contents: $relative"
    }
    Assert (@(Get-ChildItem -LiteralPath $backupTransactionRoot -File -Recurse).Count -eq 2) `
        'transaction backup contains only the two replaced originals'

    $rollbackCommand = '"{0}" -Mode Rollback -AssettoCorsaRoot "{1}" -JournalPath "{2}"' -f `
        $launcherPath, $acRoot, $journalPath
    $cmdArguments = '/d /s /c "' + $rollbackCommand + '"'
    $rollbackResult = Invoke-ChildProcess -FileName $cmdExe -Arguments $cmdArguments
    Assert ($rollbackResult.ExitCode -eq 0) "real batch launcher forwards rollback successfully (stderr: $($rollbackResult.StdErr))"
    Assert ($rollbackResult.StdOut.Contains('Rollback complete')) 'batch launcher runs actual rollback mode'
    $rolledBackTarget = Get-TargetSnapshot $targetRoot
    $rolledBackJournal = [IO.File]::ReadAllText($journalPath) | ConvertFrom-Json
    $rolledBackEntries = @($rolledBackJournal.Entries)
    foreach ($relative in $initialTarget.Keys) {
        Assert ($rolledBackTarget.ContainsKey($relative) -and $rolledBackTarget[$relative] -ceq $initialTarget[$relative]) `
            "rollback restores or preserves original target file: $relative"
    }
    $ownedRollbackTemps = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $rolledBackEntries) {
        if (-not $entry.Changed) { continue }
        if ($entry.RollbackTempRelativePath) {
            $tempRelative = ([string]$entry.RollbackTempRelativePath -replace '\\', '/')
            [void]$ownedRollbackTemps.Add($tempRelative)
            $tempPath = Join-Path $targetRoot ($tempRelative.Replace('/', '\'))
            Assert ((Get-Sha256 $tempPath) -ceq $entry.OriginalHash) "rollback preserves journal-owned original temp: $tempRelative"
        }
        foreach ($tempRelative in @($entry.DisplacedTempRelativePaths)) {
            $tempRelative = ([string]$tempRelative -replace '\\', '/')
            [void]$ownedRollbackTemps.Add($tempRelative)
            $tempPath = Join-Path $targetRoot ($tempRelative.Replace('/', '\'))
            Assert ((Get-Sha256 $tempPath) -ceq $entry.NewHash) "rollback preserves journal-owned displaced temp: $tempRelative"
        }
    }
    foreach ($relative in $rolledBackTarget.Keys) {
        Assert ($initialTarget.ContainsKey($relative) -or $ownedRollbackTemps.Contains($relative)) `
            "rollback leaves no unowned target file: $relative"
    }
    foreach ($relative in $expectedPaths) {
        if ($relative -notin @('Constants.lua', 'LICENSE', 'SimOpenTrackDay.lua', 'UIManager.lua')) {
            Assert (-not (Test-Path -LiteralPath (Join-Path $targetRoot ($relative.Replace('/', '\'))))) `
                "rollback removes only transaction-created payload file: $relative"
        }
    }
    Assert ($rolledBackJournal.State -eq 'RolledBack') 'batch rollback marks the transaction journal complete'

    $badRoot = Join-Path $sandbox 'missing AC root ! & spaces'
    $badCliArguments = @('-NoProfile', '-File', $installerPath, '-Mode', 'Preview', '-AssettoCorsaRoot', $badRoot)
    $badCliCommandLine = (($badCliArguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')
    $badCli = Invoke-ChildProcess -FileName $powershellExe -Arguments $badCliCommandLine
    Assert ($badCli.ExitCode -ne 0) 'CLI error path returns a nonzero process exit code'
    $badBatchCommand = '"{0}" -Mode Preview -AssettoCorsaRoot "{1}"' -f $launcherPath, $badRoot
    $badBatchArguments = '/d /s /c "' + $badBatchCommand + '"'
    $badBatch = Invoke-ChildProcess -FileName $cmdExe -Arguments $badBatchArguments
    Assert ($badBatch.ExitCode -ne 0) 'batch launcher propagates installer errors as a nonzero exit code'

    Write-Output "Real distribution integration checks passed: $checks checks."
}
finally {
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
