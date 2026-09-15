param([switch]$Rendered, [ValidatePattern('^\d+x\d+$')][string]$Resolution='390x844', [string[]]$Suites)
$ErrorActionPreference='Stop'
$creativeRoot=Split-Path -Parent $PSScriptRoot
$creativeEngine=Join-Path $creativeRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$creativeProfile=Join-Path $creativeRoot '.tools/creative-test-profile'
New-Item -ItemType Directory -Path $creativeProfile -Force | Out-Null
$oldCreativeAppData=$env:APPDATA
$oldCreativeLocalData=$env:LOCALAPPDATA
try {
    $env:APPDATA=$creativeProfile
    $env:LOCALAPPDATA=$creativeProfile
    if (-not $Suites) { $Suites=@('test_creative_content','test_creative_model','test_creative_building','test_creative_maps_integration','test_creative_save_integrity','test_creative_services','test_creative_god_mode','test_creative_social','test_creative_world','test_creative_ui','test_creative_app','test_creative_dense') }
    foreach ($suite in $Suites) {
        if ($suite -notmatch '^test_creative_[a-z_]+$') { throw 'Invalid creative suite name' }
        $creativeArgs=@('--headless','--path',$creativeRoot,'--script',"tests/$suite.gd")
        if ($Rendered) { $creativeArgs=@('--path',$creativeRoot,'--resolution',$Resolution,'--script',"tests/$suite.gd") }
        $creativeOutput=& $creativeEngine @creativeArgs 2>&1
        $creativeExit=$LASTEXITCODE
        $creativeOutput | Write-Output
        if ($creativeExit -ne 0 -or ($creativeOutput -join "`n") -match 'SCRIPT ERROR:') { throw "$suite failed" }
    }
} finally {
    $env:APPDATA=$oldCreativeAppData
    $env:LOCALAPPDATA=$oldCreativeLocalData
}
