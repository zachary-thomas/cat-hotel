param(
    [ValidateSet('Open','Configure','Rendering','Test','Windows','Android','iOS','Play','QA')][string]$Action='Open'
)
$ErrorActionPreference='Stop'
$unityRepo=Split-Path -Parent $PSScriptRoot
$unityProject=Join-Path $unityRepo 'unity/PurringtonHotel'
$unityCli=Join-Path $env:LOCALAPPDATA 'Unity/bin/unity.exe'
if (-not (Test-Path -LiteralPath $unityCli)) {
    $unityCommand=Get-Command unity -ErrorAction SilentlyContinue
    if (-not $unityCommand) { throw 'Unity CLI is missing. Install the official Unity CLI, then rerun this command.' }
    $unityCli=$unityCommand.Source
}
if ($Action -eq 'Open') { & $unityCli open $unityProject; exit $LASTEXITCODE }
# With the Editor already open, Test and Windows run inside it through the bridge instead of a second Unity instance.
$bridgeAlive=Join-Path $unityProject 'Temp/ClaudeBridge/alive'
if (($Action -eq 'Test' -or $Action -eq 'Windows') -and (Test-Path -LiteralPath $bridgeAlive) -and ((Get-Date).ToUniversalTime()-[datetime]::Parse((Get-Content -LiteralPath $bridgeAlive -Raw).Trim()).ToUniversalTime()).TotalSeconds -le 20) {
    & (Join-Path $PSScriptRoot 'unity-bridge.ps1') -Action ($(if ($Action -eq 'Test') { 'test' } else { 'build' }))
    exit $LASTEXITCODE
}
if ($Action -eq 'Play') {
    $unityPreview=Join-Path $unityRepo 'builds/unity/Windows/PurringtonHotel.exe'
    if (-not (Test-Path -LiteralPath $unityPreview)) { throw 'Build the Windows preview first: tools/unity.ps1 Windows' }
    Start-Process -FilePath $unityPreview
    exit 0
}
if ($Action -eq 'QA') {
    $unityPreview=Join-Path $unityRepo 'builds/unity/Windows/PurringtonHotel.exe'
    if (-not (Test-Path -LiteralPath $unityPreview)) { throw 'Build the Windows preview first.' }
    $unityCapture=Join-Path $unityRepo 'builds/unity/captures'
    $unityProfile=Join-Path $unityRepo ('tmp/unity-qa-profile-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $unityCapture,$unityProfile -Force | Out-Null
    $unityArguments='-purrington-smoke "{0}" -purrington-profile "{1}" -logFile "{2}"' -f $unityCapture,$unityProfile,(Join-Path $unityCapture 'player.log')
    $unityProcess=Start-Process -FilePath $unityPreview -ArgumentList $unityArguments -WindowStyle Hidden -PassThru
    if (-not $unityProcess.WaitForExit(180000)) { throw 'Preview QA did not finish within three minutes; inspect the player log.' }
    if ($unityProcess.ExitCode -ne 0) { throw "Preview QA failed with exit code $($unityProcess.ExitCode)" }
    Get-Content (Join-Path $unityCapture 'result.txt')
    exit 0
}
if ($Action -eq 'Test') {
    $unityResults=Join-Path $unityRepo 'builds/unity/test-results.xml'
    New-Item -ItemType Directory -Path (Split-Path -Parent $unityResults) -Force | Out-Null
    & $unityCli test $unityProject --mode EditMode --report-format junit --output $unityResults --timeout 600
    exit $LASTEXITCODE
}
$unityMethod=switch ($Action) {
    'Configure' { 'Purrington.Editor.ProjectSetup.Configure' }
    'Rendering' { 'Purrington.Editor.ProjectSetup.ConfigureRendering' }
    'Windows' { 'Purrington.Editor.ProjectSetup.BuildWindows' }
    'Android' { 'Purrington.Editor.ProjectSetup.BuildAndroid' }
    'iOS' { 'Purrington.Editor.ProjectSetup.BuildIOS' }
}
& $unityCli run $unityProject -- -executeMethod $unityMethod
exit $LASTEXITCODE
