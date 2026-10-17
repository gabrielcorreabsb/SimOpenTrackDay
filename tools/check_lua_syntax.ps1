param(
    [string]$LuaJitPath,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LuaJitPath)) {
    $luaJitCommand = Get-Command 'luajit' -ErrorAction SilentlyContinue
    if (-not $luaJitCommand) {
        Write-Error 'LuaJIT was not found on PATH. Pass -LuaJitPath <path-to-luajit.exe>.'
        exit 1
    }
    $LuaJitPath = $luaJitCommand.Source
}

if (-not (Test-Path -LiteralPath $LuaJitPath -PathType Leaf)) {
    Write-Error "LuaJIT executable not found: $LuaJitPath"
    exit 1
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Error "Project root not found: $Root"
    exit 1
}

$Root = (Resolve-Path -LiteralPath $Root).Path
$excludedDirectories = @(
    (Join-Path $Root 'lib\ac_apps'),
    (Join-Path $Root 'lib\AssettoCorsaCSPLuaCompatibilityManager')
)
$luaFiles = Get-ChildItem -LiteralPath $Root -Filter '*.lua' -File -Recurse |
    Where-Object {
        $file = $_
        $isExcluded = $excludedDirectories | Where-Object {
            $file.FullName.StartsWith($_ + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        }
        $file.Name -notlike '*.bak' -and -not $isExcluded
    } |
    Sort-Object FullName

if (-not $luaFiles) {
    Write-Output "No Lua source files found under $Root."
    exit 0
}

$failed = 0
foreach ($luaFile in $luaFiles) {
    $relativePath = $luaFile.FullName.Substring($Root.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
    $env:LUA_SYNTAX_CHECK_FILE = $luaFile.FullName
    try {
        & $LuaJitPath -e "local chunk, err = loadfile(os.getenv('LUA_SYNTAX_CHECK_FILE')); if not chunk then io.stderr:write(err, '\n'); os.exit(1) end"
    } finally {
        Remove-Item Env:\LUA_SYNTAX_CHECK_FILE -ErrorAction SilentlyContinue
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Output "FAIL $relativePath"
        $failed++
    } else {
        Write-Output "PASS $relativePath"
    }
}

if ($failed -gt 0) {
    Write-Output "Lua syntax check failed: $failed of $($luaFiles.Count) file(s)."
    exit 1
}

Write-Output "Lua syntax check passed: $($luaFiles.Count) file(s)."
exit 0
