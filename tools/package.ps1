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
start "" "%~dp0PurringtonHotel.exe" --main-pack "%~dp0PurringtonHotel.pck"
'@ | Set-Content -LiteralPath (Join-Path $destination 'Play.cmd') -Encoding ascii
@'
@echo off
start "" "%~dp0PurringtonHotel.exe" --main-pack "%~dp0PurringtonHotel.pck" -- --commerce-preview
'@ | Set-Content -LiteralPath (Join-Path $destination 'Test expansions.cmd') -Encoding ascii
@'
PURRINGTON HOTEL - WINDOWS PLAYABLE PREVIEW

Double-click Play.cmd. Keep the .exe and .pck together.
No installation is needed. This preview bundles the local Godot 4.7.2
editor-capable binary as its runner because desktop export templates were
not installed. A production release should use Godot's export template.

Open Build, choose furniture, then tap any guest room, lobby or shared floor.
The checkmark saves immediately at the shown price; X cancels the preview.
Valid furniture has a filled green footprint; invalid furniture turns red.
Play returns straight to the game.
Undo refunds a building action while preserving income; Redo repeats it if
there are enough coins. Moving and storing owned copies are free.
Tap a room and Copy room to preview its shell and furniture. Paste shows the
full cost and creates a complete, independently owned copy. Rooms opens the
new-room tools and text sizes. Comfort, entertainment and atmosphere improve
with your furnishings. Doors, walking routes and fixed service fixtures stay clear.

Click Open your hotel. Income is automatic. Use Hotel life to decorate rooms,
discover combinations, train staff, host events, earn stars and save photos.
Tap Cats or a guest for a close petting view, purrs, toys and friendship.
Use Hotel life > Watch your favorite cat to follow a guest without controls.
Use Manager to direct your coral-vested cat. Tap paths to walk, bushes to
trim, the mouse to chase, or untidy rooms to clean. Completed jobs pay coins.
Loose yarn gives 5 coins and respawns after 35 seconds.
Tap pool, litter nook, playpen or picnic sites to buy amenities with coins.
Cats use each open amenity, which adds persistent income.
The front road has passing cats and Paw Mart: share 30-coin treats to invite
neighbors over and gain 3 friendship with your favorite (120-second cooldown).
At hotel level 3, hire Daisy for 600 coins to clean rooms automatically.
Tap boarded wings to repair them; Rooms also shows repair details.
The compact header leaves the full isometric hotel visible. Fit all resets the view.
Outside / Inside toggles the full roof and walls; the chosen view is saved.
Room doors open when tapped or when cats approach, then close afterward.
Panning and zooming stop at the property and street. Each restored wing opens
another fenced garden plot for exploration and manager walking.
Map travels between the four destinations you own.
Room wings require hotel levels 2 / 4 / 6 and cost 1,200 / 3,500 / 8,000 coins.
Construction cats repair them in 30 / 60 / 90 seconds, including while away.
Each finished repair opens empty building space and adds persistent income.
Maximum: eight individually placed rooms per hotel.
Open Build to place regular rooms (450 coins) or suites (1,200 coins).
Tap floor tiles to position, rotate to choose the entrance, then confirm.
All entrances need a clear path to the lobby. Tap a room to preview real
furnishings before buying. Moving rooms and rearranging owned objects are free.
Keyboard: R rotates placement; Esc cancels the preview or closes Build.
Old saves migrate their rooms and keep furniture, cats and progress.
Drag the world to pan; mouse wheel zooms. Tap a zone to upgrade it.
The top-right menu controls music, sound effects, evening lighting, animation,
weather and touch feedback. Backgrounding the app pauses audio.

Progress saves under %APPDATA%/Godot/app_userdata/Purrington Hotel/.
Offline earning is capped at eight hours. The two .json save slots
alternate to preserve a backup. Keep both files when moving saves.

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
Compress-Archive -Path (Join-Path $destination '*') -DestinationPath (Join-Path $projectRoot 'builds/PurringtonHotel-WindowsPreview.zip') -Force
Write-Output "Preview ready: $destination\Play.cmd"
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalData
}

