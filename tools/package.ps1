$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$originalAppData = $env:APPDATA
$originalLocalData = $env:LOCALAPPDATA
$packageProfile = Join-Path $projectRoot '.tools\package-profile'
New-Item -ItemType Directory -Path $packageProfile -Force | Out-Null
try {
$env:APPDATA = $packageProfile
$env:LOCALAPPDATA = $packageProfile
$runtime = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
$console = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$destination = Join-Path $projectRoot 'builds\windows'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$exportOutput = & $console --headless --path $projectRoot --export-pack 'Windows Desktop' (Join-Path $destination 'PurringtonHotel.pck') 2>&1
$exportExit = $LASTEXITCODE
$exportOutput | Write-Output
if ($exportExit -ne 0 -or ($exportOutput -join "`n") -match 'SCRIPT ERROR:') { throw 'Pack export failed.' }
$runnerDestination = Join-Path $destination 'PurringtonHotel.exe'
if (-not (Test-Path -LiteralPath $runnerDestination) -or (Get-FileHash -LiteralPath $runtime).Hash -ne (Get-FileHash -LiteralPath $runnerDestination).Hash) {
    Copy-Item -LiteralPath $runtime -Destination $runnerDestination -Force
}
& $console --headless --path $projectRoot --script tools/write_notices.gd
if ($LASTEXITCODE -ne 0) { throw 'License generation failed.' }
$fontNotices = Get-Content -LiteralPath (Join-Path $projectRoot 'assets/fonts/Fredoka-OFL.txt') -Raw
$fontNotices += "`r`n`r`nNUNITO`r`n`r`n" + (Get-Content -LiteralPath (Join-Path $projectRoot 'assets/fonts/Nunito-OFL.txt') -Raw)
$fontNotices | Set-Content -LiteralPath (Join-Path $destination 'FONT_NOTICES.txt') -Encoding utf8
$mobileNotices = "GOOGLE PLAY BILLING PLUGIN`r`n`r`n" + (Get-Content -LiteralPath (Join-Path $projectRoot 'addons/GodotGooglePlayBilling/LICENSE') -Raw)
$mobileNotices += "`r`n`r`nPOING STUDIOS ADMOB PLUGIN`r`n`r`n" + (Get-Content -LiteralPath (Join-Path $projectRoot 'addons/admob/LICENSE') -Raw)
$mobileNotices | Set-Content -LiteralPath (Join-Path $destination 'MOBILE_SDK_NOTICES.txt') -Encoding utf8
@'
@echo off
set "PURRINGTON_PREVIEW=%LOCALAPPDATA%\Purrington Playful Preview 2026-09"
if not exist "%PURRINGTON_PREVIEW%" mkdir "%PURRINGTON_PREVIEW%"
set "APPDATA=%PURRINGTON_PREVIEW%"
set "LOCALAPPDATA=%PURRINGTON_PREVIEW%"
start "" "%~dp0PurringtonHotel.exe" --path "%~dp0." --main-pack "%~dp0PurringtonHotel.pck" %* -- --save-path=user://playful-mobile-preview-save
'@ | Set-Content -LiteralPath (Join-Path $destination 'Play.cmd') -Encoding ascii
@'
@echo off
start "" "%~dp0PurringtonHotel.exe" --path "%~dp0." --main-pack "%~dp0PurringtonHotel.pck" -- --commerce-preview
'@ | Set-Content -LiteralPath (Join-Path $destination 'Test expansions.cmd') -Encoding ascii
@'
PURRINGTON HOTEL - WINDOWS PLAYABLE PREVIEW

Double-click Play.cmd. Keep the .exe and .pck together.
No installation is needed. This preview bundles the local Godot 4.7.2
editor-capable binary as its runner because desktop export templates were
not installed. A production release should use Godot's export template.

Press Play to open your hotel. The five bottom destinations are Hotel, Cats,
Build, Life and Map. Hotel returns to your live hotel without resetting its
camera. The whole next-step card opens the action it describes.

Cats shows Met and To meet collections. Tap a known guest for a live care
stage: Pet, Brush, Feather, Yarn, Cushion and Box build real friendship.
Favorite and invitation actions explain their current requirements.

Build opens an illustrated catalogue. Choose a category and furniture, then
tap a room, lobby or shared floor. Rotate and Adjust position the preview.
Place saves immediately at the displayed Cat Coin price. Cancel removes only
an unpurchased preview. Undo refunds a saved action; Redo repeats it if affordable.
Play returns immediately to Hotel. Storage, room tools and Copy/Paste are in
this workspace. Valid footprints are green; invalid ones explain the problem.
Keyboard: R rotates; Esc cancels a preview or goes Back.

Life opens Garden, Manager, Staff, Scrapbook, Discoveries and Paw Mart,
plus gatherings, specialties and Watch. Watch has a Back to hotel button.
Scrapbook saves actual hotel photos to this preview profile. Map shows all
four destinations and live travel/unlock requirements. Seaside requires both
Meadow level 10 and 10,000 earned Cat Coins.

The header's Settings button offers music, sound effects, gentle animation,
touch feedback, evening lighting and weather. Text size 100%, 125% or 150%
applies throughout the interface. Scroll longer pages; Back returns to their
parent. Hotel view offers Fit the full hotel and Inside / Outside.
Drag the world to pan; the mouse wheel zooms. Tap service areas to upgrade.
Offline earnings cap at eight hours. Later leaves earnings available to collect.

Play.cmd uses a fresh, persistent overhaul preview profile at:
%LOCALAPPDATA%\Purrington Playful Preview 2026-09\Godot\app_userdata\Purrington Hotel\
(The LOCALAPPDATA above means your normal Windows local application-data folder.)
Its playful-mobile-preview-save.0.json and .1.json slots alternate backups.
Your normal game saves are separate. The package contains no preview saves,
walkthrough fixtures or logs. Subsequent preview launches retain progress.

FREE GAME AND EXPANSIONS
Meadow House, Seaside Suites and twelve guests form the free game.
Cat Club adds Truffle, Ember and Captain. Forest Lodge adds a woodland hotel
and Juniper. Snowcap Spa adds a mountain hotel, Flurry and Pearl.
Any real-money expansion purchase removes all ads permanently.
Cat Coin purchases are earned gameplay currency and do not remove ads.

Windows Play.cmd does not charge money or contact an advertising service.
To try expansion purchases, launch Test expansions.cmd. Its shop is clearly
labeled TEST STORE, charges nothing and uses a separate test save.
The Android billing and ad adapters/plugins are installed. Live payments and
ads still require store products, ad IDs, signing and mobile-device testing.
No signed mobile build has been produced. iOS billing is not implemented.

Godot Engine: https://godotengine.org/license/
Full engine and dependency notices are in GODOT_NOTICES.txt.
Fredoka and Nunito font licenses are in FONT_NOTICES.txt.
Mobile plugin licenses are in MOBILE_SDK_NOTICES.txt.
'@ | Set-Content -LiteralPath (Join-Path $destination 'README.txt') -Encoding utf8
$deliverables = @('PurringtonHotel.exe','PurringtonHotel.pck','Play.cmd','Test expansions.cmd','README.txt','GODOT_NOTICES.txt','FONT_NOTICES.txt','MOBILE_SDK_NOTICES.txt') | ForEach-Object { Join-Path $destination $_ }
Compress-Archive -LiteralPath $deliverables -DestinationPath (Join-Path $projectRoot 'builds/PurringtonHotel-WindowsPreview.zip') -Force
Write-Output "Preview ready: $destination\Play.cmd"
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalData
}
