$ErrorActionPreference = 'Stop'
$checks = 0
function Assert([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw "FAIL: $Message" }
}

$toolsDirectory = $PSScriptRoot
$repositoryRoot = Split-Path -Parent $toolsDirectory
$builderPath = Join-Path $toolsDirectory 'build_package.ps1'
$manifestPath = Join-Path $toolsDirectory 'runtime-manifest.txt'
$sandboxBase = Join-Path $env:LOCALAPPDATA 'Temp\opencode'
if (-not (Test-Path -LiteralPath $sandboxBase -PathType Container)) {
    throw "Approved package-test sandbox is unavailable: $sandboxBase"
}
$sandbox = Join-Path $sandboxBase ('package-test-' + [Guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $sandbox 'source'
$outputParent = Join-Path $sandbox 'packages'
$outputPath = Join-Path $outputParent 'SimOpenTrackDay-0.1'
New-Item -ItemType Directory -Path $sourceRoot, $outputParent | Out-Null

try {
    $manifestEntries = @([IO.File]::ReadAllLines($manifestPath) | ForEach-Object { $_.Trim() } |
        Where-Object { $_.Length -gt 0 -and -not $_.StartsWith('#') })
    $staticPaths = @($manifestEntries | Where-Object { $_ -cne 'lib/i18n/*.lua' })
    Assert (@($manifestEntries | Where-Object { $_ -ceq 'lib/i18n/*.lua' }).Count -eq 1) `
        'runtime manifest has only the constrained direct-locale wildcard'

    $baseLocales = @('en.lua', 'pt-BR.lua', 'es.lua')
    $expectedBasePaths = @($staticPaths + ($baseLocales | ForEach-Object { 'lib/i18n/' + $_ }))
    Assert ($expectedBasePaths.Count -eq 66) 'the checked-in runtime manifest resolves to the expected 66 current payload files'

    $fixtureRuntimePaths = @($expectedBasePaths + 'lib/i18n/fr.lua')
    foreach ($relativePath in $fixtureRuntimePaths) {
        $target = Join-Path $sourceRoot ($relativePath.Replace('/', '\'))
        $targetDirectory = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
        if ($relativePath -eq 'LICENSE') {
            $contents = "MIT License`nCopyright (c) 2025 Andreas Grech`n"
        } elseif ($relativePath -eq 'lib/AssettoCorsaCSPLuaCompatibilityManager/README.md') {
            $contents = "CSP compatibility notice fixture`n"
        } else {
            $contents = "fixture:$relativePath`n"
        }
        [IO.File]::WriteAllText($target, $contents, (New-Object System.Text.UTF8Encoding($false)))
    }
    [IO.File]::WriteAllText((Join-Path $sourceRoot 'lib/i18n/readme.txt'), 'not a locale source')

    $deliveryFixtures = @(
        @{ Path = 'tools/distribution/install.bat'; Text = "@echo off`r`nrem installer fixture`r`n" },
        @{ Path = 'tools/distribution/installer.ps1'; Text = "# installer fixture`n" },
        @{ Path = 'docs/INSTALL.md'; Text = "# Install fixture`n" }
    )
    foreach ($delivery in $deliveryFixtures) {
        $target = Join-Path $sourceRoot ($delivery.Path.Replace('/', '\'))
        $targetDirectory = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }
        [IO.File]::WriteAllText($target, $delivery.Text, (New-Object System.Text.UTF8Encoding($false)))
    }

    $sourceMarker = Join-Path $sourceRoot 'MainWindow.lua'
    $sourceBefore = (Get-FileHash -LiteralPath $sourceMarker -Algorithm SHA256).Hash
    $preview = @(& $builderPath -SourceRoot $sourceRoot -OutputPath $outputPath)
    Assert (($preview -join "`n").Contains('Preview only: no files were written.')) 'default invocation is a read-only preview'
    Assert (-not (Test-Path -LiteralPath $outputPath)) 'preview does not create its output directory'

    $missingSource = Join-Path $sourceRoot 'SettingsModel.lua'
    $savedMissingContents = [IO.File]::ReadAllBytes($missingSource)
    Remove-Item -LiteralPath $missingSource
    $missingFailed = $false
    try { & $builderPath -SourceRoot $sourceRoot -OutputPath $outputPath -Build | Out-Null }
    catch { $missingFailed = $true }
    Assert $missingFailed 'missing allowlisted source files fail the build'
    Assert (-not (Test-Path -LiteralPath $outputPath)) 'missing-source failure occurs before output creation'
    [IO.File]::WriteAllBytes($missingSource, $savedMissingContents)

    $buildResult = @(& $builderPath -SourceRoot $sourceRoot -OutputPath $outputPath -Build)
    Assert (($buildResult -join "`n").Contains('Package built and verified:')) 'explicit -Build creates and verifies a new package'
    Assert ((Get-FileHash -LiteralPath $sourceMarker -Algorithm SHA256).Hash -ceq $sourceBefore) 'building does not mutate source files'

    $payloadRoot = Join-Path $outputPath 'payload/SimOpenTrackDay'
    $packagedPayload = @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse -Force)
    Assert ($packagedPayload.Count -eq 67) 'dynamic locale glob packages an added locale alongside all 66 baseline files'
    foreach ($relativePath in $fixtureRuntimePaths) {
        $target = Join-Path $payloadRoot ($relativePath.Replace('/', '\'))
        Assert (Test-Path -LiteralPath $target -PathType Leaf) "allowlisted payload file copied: $relativePath"
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'lib/i18n/readme.txt'))) 'locale glob excludes non-Lua files'
    foreach ($excluded in @(
        'CarStateMachine/CarState_TEMPLATE.lua',
        'CarStateMachine/States/CarState_DefendingPosition.lua',
        'lib/ac_apps/lib.lua', 'Profiler.lua', 'tools/test_package.ps1'
    )) {
        Assert (-not (Test-Path -LiteralPath (Join-Path $payloadRoot ($excluded.Replace('/', '\'))))) `
            "excluded development/vendor path is absent: $excluded"
    }

    $expectedDelivery = @('install.bat', 'installer.ps1', 'INSTALL.md')
    foreach ($deliveryName in $expectedDelivery) {
        $deliveryOutput = Join-Path $outputPath $deliveryName
        Assert (Test-Path -LiteralPath $deliveryOutput -PathType Leaf) "delivery file is present at package root: $deliveryName"
        $fixture = @($deliveryFixtures | Where-Object { (Split-Path $_.Path -Leaf) -ceq $deliveryName })[0]
        Assert ([IO.File]::ReadAllText($deliveryOutput) -ceq $fixture.Text) "delivery file content is copied unchanged: $deliveryName"
    }
    $actualRootFiles = @((Get-ChildItem -LiteralPath $outputPath -File -Force | ForEach-Object { $_.Name }) | Sort-Object -CaseSensitive)
    $expectedRootFiles = @(@('INSTALL.md', 'checksums.sha256', 'install.bat', 'installer.ps1') | Sort-Object -CaseSensitive)
    Assert (($actualRootFiles -join '|') -ceq ($expectedRootFiles -join '|')) 'package root contains exactly the checksum list and three delivery files'
    Assert (Test-Path -LiteralPath (Join-Path $payloadRoot 'LICENSE') -PathType Leaf) 'runtime license is in the payload'
    Assert (Test-Path -LiteralPath (Join-Path $payloadRoot 'lib/AssettoCorsaCSPLuaCompatibilityManager/README.md') -PathType Leaf) `
        'CSP compatibility notice is in the payload'

    $checksumPath = Join-Path $outputPath 'checksums.sha256'
    $checksumLines = [IO.File]::ReadAllLines($checksumPath)
    Assert ($checksumLines.Count -eq $packagedPayload.Count) 'checksum list covers every payload file and no delivery file'
    $checksumPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($line in $checksumLines) {
        if ($line -notmatch '^([0-9a-f]{64})  payload/SimOpenTrackDay/(.+)$') {
            throw "FAIL: invalid checksum line: $line"
        }
        $hash = $Matches[1]
        $relativePath = $Matches[2]
        Assert ($checksumPaths.Add($relativePath)) "checksum path is unique: $relativePath"
        $payloadFile = Join-Path $payloadRoot ($relativePath.Replace('/', '\'))
        Assert (Test-Path -LiteralPath $payloadFile -PathType Leaf) "checksum references only a payload file: $relativePath"
        $actualHash = (Get-FileHash -LiteralPath $payloadFile -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert ($hash -ceq $actualHash) "SHA-256 verifies for $relativePath"
    }
    Assert ($checksumPaths.Contains('lib/i18n/fr.lua')) 'newly added locale is included in checksums'
    $existingOutput = Join-Path $outputParent 'existing-package'
    New-Item -ItemType Directory -Path $existingOutput | Out-Null
    $sentinel = Join-Path $existingOutput 'keep.txt'
    [IO.File]::WriteAllText($sentinel, 'preserve')
    $existingFailed = $false
    try { & $builderPath -SourceRoot $sourceRoot -OutputPath $existingOutput -Build | Out-Null }
    catch { $existingFailed = $true }
    Assert $existingFailed 'builder refuses an existing output directory'
    Assert ([IO.File]::ReadAllText($sentinel) -ceq 'preserve') 'existing output is left untouched'

    $overlapFailed = $false
    try { & $builderPath -SourceRoot $sourceRoot -OutputPath (Join-Path $sourceRoot 'nested-output') -Build | Out-Null }
    catch { $overlapFailed = $true }
    Assert $overlapFailed 'output nested under SourceRoot is rejected'
    Assert (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'nested-output'))) 'overlap rejection creates no output'

    $traversalPath = Join-Path $sandbox '..\escaped-package'
    $traversalFailed = $false
    try { & $builderPath -SourceRoot $sourceRoot -OutputPath $traversalPath -Build | Out-Null }
    catch { $traversalFailed = $true }
    Assert $traversalFailed 'OutputPath traversal segments are rejected'
    Assert (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $sandbox) 'escaped-package'))) `
        'traversal rejection creates no outside directory'

    $junctionTarget = Join-Path $sandbox 'junction-target'
    $junctionPath = Join-Path $sandbox 'output-junction'
    New-Item -ItemType Directory -Path $junctionTarget | Out-Null
    $junctionCreated = $false
    try {
        New-Item -ItemType Junction -Path $junctionPath -Target $junctionTarget | Out-Null
        $junctionCreated = $true
    } catch {
        Write-Output 'Reparse-point output test skipped: this host could not create a directory junction.'
    }
    if ($junctionCreated) {
        $reparseFailed = $false
        $reparseOutput = Join-Path $junctionPath 'package'
        try { & $builderPath -SourceRoot $sourceRoot -OutputPath $reparseOutput -Build | Out-Null }
        catch { $reparseFailed = $true }
        Assert $reparseFailed 'output paths containing a reparse point are rejected'
        Assert (-not (Test-Path -LiteralPath (Join-Path $junctionTarget 'package'))) `
            'reparse-point rejection creates no output under the junction target'
        Remove-Item -LiteralPath $junctionPath -Force
    }

    Write-Output "Package sandbox tests passed: $checks checks."
}
finally {
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
