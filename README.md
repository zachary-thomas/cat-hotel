# Purrington Hotel

> **Purrington Hotel is moving to Unity.** All new development happens in the [Unity project](unity/PurringtonHotel/README.md) (`unity/PurringtonHotel`, Unity 6000.3.24f1 LTS). The Godot project at the repository root (`project.godot`, `scenes/`, `scripts/`, `tests/*.gd`) is **legacy**: it is kept only as the behavior and art reference for Unity parity, and it receives no new features. Current plans live in [docs/superpowers](docs/superpowers/plans/2026-09-22-hotel-growth-00-roadmap.md).

A creative cat hotel built around shared spaces: expand the lot, arrange rooms and cottages, decorate gardens, and watch cats check in, socialize and visit the milkshake bar.

Meadow opens as a connected main hotel with a planted fountain garden and an arrival street. Lower counters fit the cat staff, while neighbors stroll past gardens and voxel homes outside the lot. Camera limits reveal glimpses of the streets around your hotel. See [the latest game captures](docs/creative-preview/neighborhood-polish/README.md).

The neighborhood and lower desks appear when loading an existing save; no reset is needed.

Cats now trade little conversations in readable speech bubbles, with matching waves, head tilts and happy reactions. Fireplaces flicker and spark, fountains spurt, litter scatters during digging, and milkshake machines vibrate during service. Boxes, scratchers, toys, cushions and garden decorations also respond with small movements. See [the in-game animations](docs/creative-preview/lively-hotel/README.md). Existing furnishings gain these details automatically, and the Animated motion setting controls them.

## Unity (active development)

The [Unity project](unity/PurringtonHotel/README.md) preserves **voxel 3D, orthographic isometric gameplay**, with a brighter mobile interface. A Windows development build succeeds, 13 Unity EditMode tests pass, and an automated runtime smoke check captures 18 screens without exceptions. This is an initial Meadow slice; complete pointer/device walkthroughs and full Godot feature parity remain outstanding. The existing Godot game below remains available and unchanged as the reference. See [Unity screenshots and test evidence](docs/unity-migration/evidence/README.md).

The project now pins installed **Unity 6000.3.24f1 LTS**. The Windows preview and 13 EditMode tests have been verified on 6.3; rendering and input packages were upgraded by Unity.

## Legacy Godot build (reference only)

Everything from here down describes the legacy Godot game, kept as the parity reference. For the game under active development, see the [Unity project](unity/PurringtonHotel/README.md).

**Godot project Play (F5), the standard Windows launcher, and both preview packages now use the redesigned hotel.** The main project scene is `scenes/creative_hotel.tscn`.

- Open [Play.cmd](builds/windows/Play.cmd) for the Windows game.
- Or use [Play Creative Hotel.cmd](builds/creative-social/Play%20Creative%20Hotel.cmd).
- The [Windows ZIP](builds/PurringtonHotel-WindowsPreview.zip) and [Creative ZIP](builds/PurringtonHotel-CreativeSocialPreview.zip) contain the same current game.
- In Godot, run the project with **F5**. Reopen the project after updating if an already-running editor retains its old main-scene setting. Enable **Input** in Godot's embedded Game view so clicks reach the game.

## Test on Android

Download the APK from [GitHub Releases](https://github.com/zachary-thomas/cat-hotel/releases) and open it on your phone to install **Purrington Hotel Preview**. Requires a 64-bit ARM Android device running Android 7.0 or newer with OpenGL ES 3.0.

See [Android installation, testing and build instructions](docs/ANDROID-TESTING.md). This debug-signed preview has its own saves and includes no live billing or advertising SDK.

## God mode for development

Open **Settings → God mode**. It unlocks every map, land parcel, cat and item requirement. Building, copying, resizing, paths, service upgrades and staff changes cost nothing. The header reads **FREE** while it is active.

Turning God mode off restores normal prices. Creations and unlocked content remain saved; switching modes restarts the 20-action Undo history. Free construction carries no paid refund value. Geometry, access and room-readiness checks remain active so you can debug real hotel behavior. Fresh saves start with God mode off.

**Settings → Start fresh** loads the latest starter hotel after a confirmation. This resets the current preview's progress; existing saves otherwise keep their layouts. A failed save leaves your previous hotel intact.

## Spend time with a cat

Tap a guest in the hotel or choose a portrait in **Cats** to open a live care room. The illustrated portraits remain in the collection.

- **Pet:** stroke the cat or rest your finger gently to hear a purr.
- **Brush:** select Brush and drag across its coat.
- **Feather:** drag the feather for the cat to follow and pounce toward.
- **Yarn:** drag and flick the ball for a short chase.
- **Cushion / Box:** select the tool and tap the room to offer it.
- **Use selected tool** provides the same activities with a button or keyboard. **About & friends** contains preferences and playdate invitations.

Back returns to your hotel camera or collection position. Sound effects and Animated motion settings also apply to care. The room follows your current hotel's theme, and normal hotel life continues while you play. See [care screenshots and verification](docs/creative-preview/cat-care/README.md).

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
.\tools\package-android.ps1           # Build and verify the Android test APK
.\tools\test-creative-package.ps1 -Rendered
```

Godot 4.7.2 binaries are bundled locally under ignored `.tools/godot`. The Windows preview uses the locally available editor-capable runner; the Android test APK uses the matching Android export template. Store release signing, live billing and physical-device testing remain outside this development preview.

## Saves

Project play uses `%APPDATA%/Godot/app_userdata/Purrington Hotel/creative-social-preview-save.0.json` and `.1.json`. The packaged game has the separate application identity `Purrington Creative Social Preview`, and its launcher uses `%LOCALAPPDATA%/Purrington Creative Social Preview 2026-09/` as its profile root.

Two checksummed journal slots preserve a fallback. Failed build saves roll back coins and geometry together. Save errors have a retry action; unreadable journals remain protected for recovery. The creative game does not load the legacy `hotel-save` schema. Legacy source remains in `scenes/main.tscn` for regression coverage and history.

## Source and licenses

- `scripts/creative`: authoritative lot model, maps, content, navigation, activities, renderer and UI.
- `scripts/core`, `scripts/world`, `scripts/ui`: shared content, original cat art, shaders and retained legacy systems.
- `tests`, `tools`, `docs/creative-preview`: verification, packaging and design review.

Built with [Godot](https://godotengine.org/license/). Engine/dependency notices, Fredoka and Nunito font licenses, and bundled mobile plugin licenses accompany the Windows packages. No live payment or advertising service is invoked by this preview.
