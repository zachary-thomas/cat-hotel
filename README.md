# Purrington Hotel

A creative cat hotel built around shared spaces: expand the lot, arrange rooms and cottages, decorate gardens, and watch cats check in, socialize and visit the milkshake bar.

Meadow opens as a connected main hotel with a planted fountain garden and an arrival street. Lower counters fit the cat staff, while neighbors stroll past gardens and voxel homes outside the lot. Camera limits reveal glimpses of the streets around your hotel. See [the latest game captures](docs/creative-preview/neighborhood-polish/README.md).

The neighborhood and lower desks appear when loading an existing save; no reset is needed.

## Play the current game

**Godot project Play (F5), the standard Windows launcher, and both preview packages now use the redesigned hotel.** The main project scene is `scenes/creative_hotel.tscn`.

- Open [Play.cmd](builds/windows/Play.cmd) for the Windows game.
- Or use [Play Creative Hotel.cmd](builds/creative-social/Play%20Creative%20Hotel.cmd).
- The [Windows ZIP](builds/PurringtonHotel-WindowsPreview.zip) and [Creative ZIP](builds/PurringtonHotel-CreativeSocialPreview.zip) contain the same current game.
- In Godot, run the project with **F5**. Reopen the project after updating if an already-running editor retains its old main-scene setting. Enable **Input** in Godot's embedded Game view so clicks reach the game.

## God mode for development

Open **Settings → God mode**. It unlocks every map, land parcel, cat and item requirement. Building, copying, resizing, paths, service upgrades and staff changes cost nothing. The header reads **FREE** while it is active.

Turning God mode off restores normal prices. Creations and unlocked content remain saved; switching modes restarts the 20-action Undo history. Free construction carries no paid refund value. Geometry, access and room-readiness checks remain active so you can debug real hotel behavior. Fresh saves start with God mode off.

**Settings → Start fresh** loads the latest starter hotel after a confirmation. This resets the current preview's progress; existing saves otherwise keep their layouts. A failed save leaves your previous hotel intact.

## Build and hotel life

The catalogue has **Rooms, Shared spaces, Furniture, Outdoors, Storage and Land**.

- Place, move, rotate, copy, resize and remove rooms. There is no eight-room cap. Guest rooms become operational when they have a reachable bed and constructed access to reception. Empty or disconnected rooms stay saved while you finish them.
- Place a furnished lobby, milkshake café, lounge, playroom, sunroom or garden terrace. Every counter, chair and decoration stays individually editable.
- Draw connected earth, gravel and brick paths. Add planting, trees, lamps, benches, statues, fountains, fences, gates and outdoor amenities.
- Buy three adjacent parcels for 750 / 750 / 1,000 earned Cat Coins in normal play. Regular shells start at 450; suites at 1,200; extra floor is 25 per cell.
- Cats check in at the actual reception, reserve activities and seats, receive milkshakes from automatic attendants and return to beds. Staff and guests use the same changing layout. Hire housekeeping in Life at level 3.
- Preview prices before placing. Cancel clears only the preview; each confirmed change saves immediately. Undo/Redo covers 20 actions and preserves elapsed income. Removing a room stores its furnishings.
- Drag to pan, wheel or pinch to zoom, **R** to rotate and **Escape** to cancel. Focus frames your selection; Fit lot shows all land. Mobile controls account for safe areas and support up to 150% text.

All four maps have different layouts and gathering places: Meadow's connected hotel and fountain garden, Seaside's promenade and milkshake terrace, Forest's woodland playroom, and Snowcap's fireside courtyard. In normal play, Seaside requires Meadow level 10 and 10,000 earned coins. Expansion test buttons charge no money.

See [the guide and actual screenshots](docs/creative-preview/README.md) and [verification results](docs/creative-preview/verification.md).

## Development commands

```powershell
.\tools\run.ps1                       # Run the current project
.\tools\run.ps1 -Editor               # Open Godot
.\tools\test-creative.ps1             # Current game suites, including God mode
.\tools\test.ps1                      # Retained legacy regression suites
.\tools\package.ps1                   # Rebuild both current Windows packages
.\tools\test-creative-package.ps1 -Rendered
```

Godot 4.7.2 binaries are bundled locally under ignored `.tools/godot`. The Windows preview uses the locally available editor-capable runner. Production export templates, signing, live billing and physical-device testing remain outside this development preview.

## Saves

Project play uses `%APPDATA%/Godot/app_userdata/Purrington Hotel/creative-social-preview-save.0.json` and `.1.json`. The packaged game has the separate application identity `Purrington Creative Social Preview`, and its launcher uses `%LOCALAPPDATA%/Purrington Creative Social Preview 2026-09/` as its profile root.

Two checksummed journal slots preserve a fallback. Failed build saves roll back coins and geometry together. Save errors have a retry action; unreadable journals remain protected for recovery. The creative game does not load the legacy `hotel-save` schema. Legacy source remains in `scenes/main.tscn` for regression coverage and history.

## Source and licenses

- `scripts/creative`: authoritative lot model, maps, content, navigation, activities, renderer and UI.
- `scripts/core`, `scripts/world`, `scripts/ui`: shared content, original cat art, shaders and retained legacy systems.
- `tests`, `tools`, `docs/creative-preview`: verification, packaging and design review.

Built with [Godot](https://godotengine.org/license/). Engine/dependency notices, Fredoka and Nunito font licenses, and bundled mobile plugin licenses accompany the Windows packages. No live payment or advertising service is invoked by this preview.
