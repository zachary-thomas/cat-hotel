param([switch]$Editor)
$ErrorActionPreference='Stop'
$creativeRoot=Split-Path -Parent $PSScriptRoot
$creativeRuntime=Join-Path $creativeRoot '.tools/godot/Godot_v4.7.2-stable_win64.exe'
$creativeProfile=Join-Path $env:LOCALAPPDATA 'Purrington Creative Social Preview 2026-09'
New-Item -ItemType Directory -Path $creativeProfile -Force | Out-Null
$oldCreativeApp=$env:APPDATA
$oldCreativeLocal=$env:LOCALAPPDATA
try {
    $env:APPDATA=$creativeProfile
    $env:LOCALAPPDATA=$creativeProfile
    $creativeArgs=@('--path',('"'+$creativeRoot+'"'),'res://scenes/creative_hotel.tscn')
    if ($Editor) { $creativeArgs+= '--editor' }
    Start-Process -FilePath $creativeRuntime -ArgumentList $creativeArgs -WorkingDirectory $creativeRoot -WindowStyle Hidden
} finally {
    $env:APPDATA=$oldCreativeApp
    $env:LOCALAPPDATA=$oldCreativeLocal
}
