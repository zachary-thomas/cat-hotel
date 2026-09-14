param([switch]$Rendered, [ValidatePattern('^\d+x\d+$')][string]$Resolution = '450x900', [string[]]$Suites)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$existingSuites = @('test_model', 'test_store', 'test_life', 'test_commerce', 'test_audio', 'test_cat_collision', 'test_app', 'test_experience', 'test_grounds', 'test_views', 'test_layout', 'test_layout_grounds', 'test_mobile_layout', 'test_mobile_navigation','test_mobile_views', 'test_building', 'test_startup_offline')
$buildSuites = @('test_furniture_content','test_furniture_layout','test_furniture_inventory','test_build_session','test_build_transactions','test_build_input','test_build_mode','test_build_recovery','test_build_history','test_shared_layout','test_room_blueprint','test_build_flow','test_shared_navigation','test_furniture_preview')
$knownSuites = $existingSuites + $buildSuites
if (-not $Suites) {
    $Suites = $knownSuites
}
foreach ($requestedSuite in $Suites) {
    if ($requestedSuite -notin $knownSuites) { throw "Unknown behavioral suite: $requestedSuite" }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "tests/$requestedSuite.gd"))) { throw "Suite does not exist: $requestedSuite" }
}
$godotPath = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command godot4 -ErrorAction SilentlyContinue }
    if (-not $command) { throw 'Godot 4.4 or later is required.' }
    $godotPath = $command.Source
}
$testProfile = Join-Path $projectRoot '.tools\test-profile'
New-Item -ItemType Directory -Path $testProfile -Force | Out-Null
$originalAppData = $env:APPDATA
$originalLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $testProfile
    $env:LOCALAPPDATA = $testProfile
    foreach ($suite in $Suites) {
        $arguments = @('--headless', '--path', $projectRoot, '--script', "tests/$suite.gd")
        if ($Rendered -and $suite -in @('test_mobile_navigation','test_mobile_views','test_cat_collision','test_app','test_experience','test_grounds','test_views','test_building','test_startup_offline','test_build_mode','test_build_flow')) { $arguments = @('--path', $projectRoot, '--rendering-method', 'gl_compatibility', '--resolution', $Resolution, '--script', "tests/$suite.gd") }
        $suiteOutput = & $godotPath @arguments 2>&1
        $suiteExitCode = $LASTEXITCODE
        $suiteOutput | Write-Output
        if ($suiteExitCode -ne 0 -or ($suiteOutput -join "`n") -match 'SCRIPT ERROR:') { throw "$suite failed with exit code $suiteExitCode or a script error" }
    }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalData
}
