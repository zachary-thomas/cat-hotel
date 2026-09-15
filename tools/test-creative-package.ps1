param([switch]$Rendered)
$ErrorActionPreference='Stop'
$creativeRoot=Split-Path -Parent $PSScriptRoot
$creativePackage=Join-Path $creativeRoot 'builds/creative-social'
$creativeProfile=Join-Path $creativeRoot ('.tools/creative-smoke-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
$creativeRunner=Join-Path $creativePackage 'CreativeHotel.exe'
$creativeSentinel=Join-Path $creativeProfile 'Godot/app_userdata/Purrington Hotel/hotel-save.0.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $creativeSentinel) -Force | Out-Null
Set-Content -LiteralPath $creativeSentinel -Value 'Legacy save isolation sentinel - do not change' -Encoding utf8
$creativeOriginalHash=(Get-FileHash -LiteralPath $creativeSentinel).Hash
$oldCreativeAppData=$env:APPDATA
$oldCreativeLocalData=$env:LOCALAPPDATA
try {
    $env:APPDATA=$creativeProfile
    $env:LOCALAPPDATA=$creativeProfile
    $creativeDirectLog=Join-Path $creativeProfile 'direct-executable.log'
    $creativeDirect=Start-Process -FilePath $creativeRunner -WorkingDirectory $creativePackage -WindowStyle Hidden -ArgumentList @('--headless','--quit-after','20','--log-file',$creativeDirectLog) -PassThru -Wait
    if ($creativeDirect.ExitCode -ne 0) { throw 'Direct executable launch failed.' }
    $creativeDefaultSave=Join-Path $creativeProfile 'Godot/app_userdata/Purrington Creative Social Preview/creative-social-preview-save.1.json'
    $creativeOtherSlot=Join-Path $creativeProfile 'Godot/app_userdata/Purrington Creative Social Preview/creative-social-preview-save.0.json'
    if (-not (Test-Path -LiteralPath $creativeDefaultSave) -and -not (Test-Path -LiteralPath $creativeOtherSlot)) { throw 'Direct executable did not create the isolated creative save.' }
    foreach ($creativeMode in @('write','reopen')) {
        $creativeLog=Join-Path $creativeProfile ($creativeMode+'.log')
        $creativeArgs=@('--headless','--path',$creativePackage,'--main-pack',(Join-Path $creativePackage 'CreativeHotel.pck'),'--script',(Join-Path $creativeRoot 'tools/creative_pack_smoke.gd'),'--log-file',$creativeLog)
        if ($Rendered) { $creativeArgs=$creativeArgs | Where-Object { $_ -ne '--headless' }; $creativeArgs+=@('--resolution','1280x800') }
        if ($creativeMode -eq 'reopen') { $creativeArgs+=@('--','--verify-reopen') }
        $creativeProcess=Start-Process -FilePath $creativeRunner -WorkingDirectory $creativePackage -WindowStyle Hidden -ArgumentList $creativeArgs -PassThru -Wait
        $creativeLogText=Get-Content -LiteralPath $creativeLog -Raw
        if ($creativeProcess.ExitCode -ne 0 -or $creativeLogText -match 'SCRIPT ERROR:' -or $creativeLogText -notmatch 'CREATIVE PACK: 0 failures') { Write-Output $creativeLogText; throw "Pack $creativeMode check failed." }
        Write-Output "Creative package $creativeMode smoke passed."
    }
    if ((Get-FileHash -LiteralPath $creativeSentinel).Hash -ne $creativeOriginalHash) { throw 'Legacy save sentinel was modified.' }
    $creativeDirectOutput=Get-Content -LiteralPath $creativeDirectLog -Raw
    if ($creativeDirectOutput -match 'SCRIPT ERROR:') { throw 'Direct launch had a script error.' }
    Write-Output 'Direct executable and launcher profile isolation verified; legacy sentinel unchanged.'
} finally {
    $env:APPDATA=$oldCreativeAppData
    $env:LOCALAPPDATA=$oldCreativeLocalData
}
