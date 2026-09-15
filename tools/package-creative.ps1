$ErrorActionPreference='Stop'
$creativeRoot=Split-Path -Parent $PSScriptRoot
$creativeDestination=Join-Path $creativeRoot 'builds/creative-social'
$creativePackageProfile=Join-Path $creativeRoot '.tools/creative-package-profile'
$creativeExportSource=Join-Path $creativeRoot '.tools/creative-export-source'
$creativeConsole=Join-Path $creativeRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$creativeRuntime=Join-Path $creativeRoot '.tools/godot/Godot_v4.7.2-stable_win64.exe'
$oldCreativeAppData=$env:APPDATA
$oldCreativeLocalData=$env:LOCALAPPDATA
New-Item -ItemType Directory -Path $creativeDestination,$creativePackageProfile,$creativeExportSource -Force | Out-Null
try {
    $env:APPDATA=$creativePackageProfile
    $env:LOCALAPPDATA=$creativePackageProfile
    # Export a separate project so even opening the executable directly selects
    # the creative scene and a distinct Godot user directory.
    foreach ($creativeDirectory in @('assets','scripts','scenes','addons')) {
        Copy-Item -LiteralPath (Join-Path $creativeRoot $creativeDirectory) -Destination $creativeExportSource -Recurse -Force
    }
    foreach ($creativeFile in @('commerce.cfg','export_presets.cfg')) {
        Copy-Item -LiteralPath (Join-Path $creativeRoot $creativeFile) -Destination $creativeExportSource -Force
    }
    $creativeSettings=Get-Content -LiteralPath (Join-Path $creativeRoot 'project.godot') -Raw
    $creativeSettings=$creativeSettings.Replace('config/name="Purrington Hotel"','config/name="Purrington Creative Social Preview"').Replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://scenes/creative_hotel.tscn"')
    Set-Content -LiteralPath (Join-Path $creativeExportSource 'project.godot') -Value $creativeSettings -Encoding utf8
    $creativeOutput=& $creativeConsole --headless --path $creativeExportSource --export-pack 'Windows Desktop' (Join-Path $creativeDestination 'CreativeHotel.pck') 2>&1
    $creativeExit=$LASTEXITCODE
    if ($creativeExit -ne 0 -or ($creativeOutput -join "`n") -match 'SCRIPT ERROR:') { $creativeOutput | Write-Output; throw 'Creative preview export failed.' }
    Copy-Item -LiteralPath $creativeRuntime -Destination (Join-Path $creativeDestination 'CreativeHotel.exe') -Force
    & $creativeConsole --headless --path $creativeRoot --script tools/creative_notices.gd
    if ($LASTEXITCODE -ne 0) { throw 'Engine notices could not be generated.' }
    $creativeFonts=(Get-Content -LiteralPath (Join-Path $creativeRoot 'assets/fonts/Fredoka-OFL.txt') -Raw)+"`r`nNUNITO`r`n"+(Get-Content -LiteralPath (Join-Path $creativeRoot 'assets/fonts/Nunito-OFL.txt') -Raw)
    Set-Content -LiteralPath (Join-Path $creativeDestination 'FONT_NOTICES.txt') -Value $creativeFonts -Encoding utf8
    $creativeMobile=(Get-Content -LiteralPath (Join-Path $creativeRoot 'addons/GodotGooglePlayBilling/LICENSE') -Raw)+"`r`nADMOB`r`n"+(Get-Content -LiteralPath (Join-Path $creativeRoot 'addons/admob/LICENSE') -Raw)
    Set-Content -LiteralPath (Join-Path $creativeDestination 'MOBILE_SDK_NOTICES.txt') -Value $creativeMobile -Encoding utf8
@'
@echo off
setlocal
set "CREATIVE_PROFILE=%LOCALAPPDATA%\Purrington Creative Social Preview 2026-09"
if not exist "%CREATIVE_PROFILE%" mkdir "%CREATIVE_PROFILE%"
set "APPDATA=%CREATIVE_PROFILE%"
set "LOCALAPPDATA=%CREATIVE_PROFILE%"
start "" "%~dp0CreativeHotel.exe" --path "%~dp0." --main-pack "%~dp0CreativeHotel.pck" res://scenes/creative_hotel.tscn %* -- --save-path=user://creative-social-preview-save
'@ | Set-Content -LiteralPath (Join-Path $creativeDestination 'Play Creative Hotel.cmd') -Encoding ascii
@'
PURRINGTON HOTEL - CREATIVE SOCIAL PREVIEW

Double-click Play Creative Hotel.cmd. Keep all files together.

Build your own cat hotel with rooms, shared spaces, garden paths and three
optional land parcels. Meadow starts with two furnished rooms, reception,
a sunroom and gardens. The other maps have distinct layouts and scenery.

BUILD
Rooms: place, move, rotate, copy, resize or remove room shells. Removing
a room stores its furnishings; smaller rooms preview displaced items.
Shared spaces: place a furnished arrangement, then select and edit each
individual piece. Furniture: reception, milkshake counters, sofas, beds,
play furniture and more. Outdoors: paths, planting, benches and decorations.
Storage: retrieve owned furnishings for free. Land: preview the adjacent
plots and buy them with earned Cat Coins (750 / 750 / 1,000).

Choose an item, tap the world to position it, then Place to save it.
Drag paths for a single priced stroke. Rotate or cancel the preview.
Undo and Redo cover the last 20 build changes in the current session.
Play leaves Build immediately. Drag the world to pan, wheel/pinch to zoom.
Use Focus selection or Fit lot to find your creation. R rotates; Esc cancels.

Guest rooms need a reachable bed and a path or shared floor to reception.
Disconnected and empty construction stays saved until you finish it.
Cats choose real activities and reserve seating. Milkshake attendants serve
drinks automatically. Hire housekeeping in Life at level 3. Service training
improves the whole hotel, while extra counters and seats add capacity.

Map shows destination requirements. Seaside requires Meadow level 10 plus
10,000 earned Cat Coins. Forest, Snowcap and Cat Club can be enabled through
the clearly labeled preview test expansions. They charge no real money.
Settings include sound, music, inside/outside views and text up to150%.
Settings > God mode unlocks all maps, land, cats and item requirements.
Building, paths, upgrades and staff changes cost nothing while it is on.
Turn it off to restore normal prices. Creations and unlocked content stay.
Switching modes starts a fresh Undo history. Fresh saves start with it off.

SAVING
Every build change saves immediately; the game also saves during play.
Offline income is capped at eight hours and can be collected from Hotel.
This preview uses a separate profile with two alternating save slots:
%LOCALAPPDATA%\Purrington Creative Social Preview 2026-09\Godot\app_userdata\Purrington Creative Social Preview\
creative-social-preview-save.0.json and .1.json
The profile above starts from your normal Windows local application folder.
Existing hotel saves are not read, changed or converted.
Opening CreativeHotel.exe directly also starts the creative game in its own
Godot user directory. Use the launcher consistently to keep one preview profile.

This Windows preview bundles the locally available Godot4.7.2 runner.
A production release should use dedicated export templates and signing.
No installation or new runtime downloads are needed. No mobile package is
included. Engine, font and bundled mobile plugin notices accompany it.
'@ | Set-Content -LiteralPath (Join-Path $creativeDestination 'README.txt') -Encoding utf8
    $creativeFiles=@('CreativeHotel.exe','CreativeHotel.pck','Play Creative Hotel.cmd','README.txt','GODOT_NOTICES.txt','FONT_NOTICES.txt','MOBILE_SDK_NOTICES.txt') | ForEach-Object { Join-Path $creativeDestination $_ }
    Compress-Archive -LiteralPath $creativeFiles -DestinationPath (Join-Path $creativeRoot 'builds/PurringtonHotel-CreativeSocialPreview.zip') -Force
    # Existing shortcuts and the standard download must launch the same game.
    $standardDestination=Join-Path $creativeRoot 'builds/windows'
    New-Item -ItemType Directory -Path $standardDestination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $creativeDestination 'CreativeHotel.exe') -Destination (Join-Path $standardDestination 'PurringtonHotel.exe') -Force
    Copy-Item -LiteralPath (Join-Path $creativeDestination 'CreativeHotel.pck') -Destination (Join-Path $standardDestination 'PurringtonHotel.pck') -Force
    foreach($notice in @('README.txt','GODOT_NOTICES.txt','FONT_NOTICES.txt','MOBILE_SDK_NOTICES.txt')) {
        Copy-Item -LiteralPath (Join-Path $creativeDestination $notice) -Destination $standardDestination -Force
    }
    $standardLauncher=(Get-Content -LiteralPath (Join-Path $creativeDestination 'Play Creative Hotel.cmd') -Raw).Replace('CreativeHotel.exe','PurringtonHotel.exe').Replace('CreativeHotel.pck','PurringtonHotel.pck')
    Set-Content -LiteralPath (Join-Path $standardDestination 'Play.cmd') -Value $standardLauncher -Encoding ascii
    Set-Content -LiteralPath (Join-Path $standardDestination 'Test expansions.cmd') -Value $standardLauncher -Encoding ascii
    $standardReadme=(Get-Content -LiteralPath (Join-Path $creativeDestination 'README.txt') -Raw).Replace('Play Creative Hotel.cmd','Play.cmd').Replace('CreativeHotel.exe','PurringtonHotel.exe')
    Set-Content -LiteralPath (Join-Path $standardDestination 'README.txt') -Value $standardReadme -Encoding utf8
    $standardFiles=@('PurringtonHotel.exe','PurringtonHotel.pck','Play.cmd','Test expansions.cmd','README.txt','GODOT_NOTICES.txt','FONT_NOTICES.txt','MOBILE_SDK_NOTICES.txt') | ForEach-Object { Join-Path $standardDestination $_ }
    Compress-Archive -LiteralPath $standardFiles -DestinationPath (Join-Path $creativeRoot 'builds/PurringtonHotel-WindowsPreview.zip') -Force
    Write-Output "Creative preview packaged: $creativeDestination"
} finally {
    $env:APPDATA=$oldCreativeAppData
    $env:LOCALAPPDATA=$oldCreativeLocalData
}
