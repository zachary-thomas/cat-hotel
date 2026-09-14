# Purrington Hotel

A playable Godot cat hotel game: learn what each guest loves, furnish a favorite room, build friendships, host gatherings and grow a collection of hotels.

## Build your own hotel

Open **Build**, choose furniture, then tap any guest room, lobby, or shared floor to position it. You can move an object directly between rooms without putting it in storage first. Rotate or nudge its preview, then tap **✓** at the displayed price. That action saves immediately. **Play** returns straight to the game; there is no Apply, checkout, or discard dialog.

**Undo** reverses the last building action and refunds its cost while keeping income earned since. **Redo** repeats it at the same price if you can afford it. History covers furniture, room moves, and copied rooms, with up to 20 actions during the running game. **×** only removes an unpurchased preview. Existing furniture and free-reuse licenses are preserved; new paid items cost coins per copy.

Tap a room and choose **Copy room** to pick up a blueprint of its shell and furnishings. The preview shows the complete room and the combined shell-plus-furniture price. Tap a clear location, rotate the entrance if needed, then **Paste**. Each copy owns its own furniture. **Rooms** also offers new regular rooms (450 coins) and suites (1,200 coins), plus building expansion. The hotel starts with two rooms and holds up to eight. Restored wings unlock additional floor space.

Doorways, walking routes, existing service fixtures, and locked wings stay clear. Guest rooms keep a reachable bed. Shared furnishings add Comfort, Entertainment, Atmosphere, and a hotel income bonus; guest preference and combination bonuses remain tied to bedrooms. Fixed lounge/service scenery remains in place.

Mobile controls keep Play and the main actions visible, support pan/pinch, and offer larger Build text under **Rooms**. Keyboard: **R** rotates a room placement; **Esc** cancels a preview or returns to play. See the [continuous Build revision](docs/superpowers/plans/2026-09-13-continuous-build-mode.md) for the design decisions and validation.

## Play

Double-click [Play.cmd](builds/windows/Play.cmd), or extract [the Windows preview ZIP](builds/PurringtonHotel-WindowsPreview.zip). Keep its executable and PCK together.

When playing inside Godot, choose **Input** in the Game toolbar so clicks reach the game. If menus are unresponsive after using inspection mode, stop and run the game again with Input selected. **Esc** also dismisses the coin screen without collecting its earnings.

To try the expansion shop without spending money, use [Test expansions.cmd](builds/windows/Test%20expansions.cmd). This clearly labeled test store uses a separate save. Normal Windows play cannot charge money or serve live ads.

```powershell
.\tools\run.ps1                      # Play from the project
.\tools\run.ps1 -CommercePreview     # Separate test-purchase save
.\tools\run.ps1 -Editor              # Open Godot
.\tools\test.ps1                     # Behavioral regression suites
.\tools\test.ps1 -Rendered -Resolution 360x800
.\tools\package.ps1                  # Rebuild the Windows preview and ZIP
```

Packaging uses the bundled Godot 4.7.2 binaries in ignored .tools/godot. Run/test scripts also accept Godot on PATH. The Windows preview uses the available editor-capable binary as its runner; production releases should use export templates.

## Gameplay

- Eighteen named cats with preferences, favorite interactions and persistent friendship milestones. Twelve belong to the free game; six come with expansions.
- A close petting view with touch/hold/stroke gestures, purr audio, brushing, feather play, yarn, cushions and boxes.
- Build mode with 18 catalogue furnishings, movable individual objects, free storage, and Comfort, Entertainment, and Atmosphere scores. Different prices and diminishing returns make furnishing choices meaningful; six existing combinations still reward complementary items.
- Four services with guest-preference effects, hotel specialties, staff training and skill choices.
- Automatic guest visits, preference-based room selection, reviews, recommendations and saved memories. Happy visits also grow friendship.
- Five hotel stars earned through critic inspections and visible requirements.
- Three shared gatherings plus destination events, preparation scores, medals and first-trophy rewards.
- Playdates, souvenirs, an illustrated scrapbook and real photos saved to the local hotel album.
- Suitcase arrivals/departures, head bumps, kneading, pouncing, chasing, grooming, yawning, stretching, circling to sleep, loafing, blankets, boxes, shared naps, staff work, construction and celebration poses.
- Quiet Watch mode follows a favorite; evening lighting, drifting leaves/snow, reduced motion, music/effects controls and supported-device haptics.
- A fixed isometric camera, compact hotel HUD and full property visible from the start. Tap any boarded wing to see its repair requirements; use **Fit all** to return to the overview.
- **Outside / Inside** switches between a complete roofed hotel and the room cutaway. The choice is saved. Hinged room and entrance doors open for approaching cats or a tap, then close afterward.
- Camera dragging and zooming stop at the current property and street. Each restored wing opens another fenced garden strip for exploration and manager walking; locked land and boarded corridors stay inaccessible.
- Construction cats in hard hats repair purchased wings in 30 / 60 / 90 seconds. Work survives saving and continues while away; building space and wing income unlock only when repairs finish.
- A turquoise kitty pool, private litter nook, rainbow playpen and catnip picnic garden. Buy them with earned coins; visiting cats use each facility and it adds income.
- A colorful neighborhood with an orchard, flower boxes, a front road, pavement, crossing, four passing cats and a striped Paw Mart kiosk.
- Tap loose yarn for five coins (35-second respawn). Direct the coral-vested manager along paths, trim regrowing bushes, chase a returning mouse and tidy rooms for job rewards.
- Hire Daisy at hotel level 3 for 600 coins per hotel. She walks to untidy rooms and sweeps automatically; housekeeping and assigned manager work continue while away.
- Paw Mart sells a 30-coin treat picnic: neighbors stop by and your favorite gains three friendship. Its garden and housekeeping links use earned coins.
- Automatic income, eight-hour offline earning and service upgrades. Two rooms can grow to eight at each hotel.

Use **Build** or **Hotel life → Decorate rooms** to start decorating immediately. Furniture cards show prices and room benefits. The large **✓** saves the purchase and **×** cancels its preview. Valid furniture appears in its own colors over a filled green footprint; invalid furniture and its footprint turn red, and ✓ is disabled. Undo reverses a saved change; Play exits. Storage, room tools, and Copy/Paste are part of the same workspace.

Use **Manager** to direct your character and manage housekeeping. Tap outdoor amenities or find them under **Hotel life → Amenities & garden**. **Hotel life** also contains Watch mode, decorating, events, staff, discoveries and the scrapbook. Tap a cat or open **Cats** for its profile. Use **Rooms** to expand and **Map** to travel. Meadow House starts free; Seaside Suites opens at Meadow level 10 for 10,000 earned Cat Coins.

## Monetization

The base game is free. Every successful real-money expansion purchase permanently removes all ads and adds its listed content. Earned Cat Coin purchases remain ordinary gameplay purchases.

| Expansion | Content |
| --- | --- |
| Cat Club | Truffle, Ember and Captain |
| Forest Lodge | Woodland hotel, forest event/bonus, Juniper |
| Snowcap Spa | Mountain hotel, spa event/bonus, Flurry and Pearl |

The store displays localized prices returned by Google Play. Before purchase, interstitials are eligible only at hotel changes or completed events, after three minutes of play, at least four minutes apart, and at most three per session. Any paid expansion disables every placement.

Android billing and AdMob plugins/adapters are installed, including consent and restore-purchase flows. **Live monetization is not launch-ready:** store products, ad-unit/app IDs, signing, mobile build tools and physical-device testing remain. Ad-unit IDs are blank by default. iOS ads libraries are present, but iOS billing and an iOS export still need implementation.

See [implementation and mobile setup](docs/EXPANSION-IMPLEMENTATION.md) for configuration, validation and limitations.

## Saves and tests

Normal saves live in %APPDATA%/Godot/app_userdata/Purrington Hotel/. Two checksummed slots preserve a fallback. Legacy two-hotel saves migrate to the new format. Friendship, rooms, staff, events, stars, memories and purchase entitlements persist. Failed writes roll back transactions; store acknowledgement follows successful fulfillment. Photos live in the local photos directory.

Tests use isolated saves and cover economy, persistence, hotel life, commerce, audio, app controls and the expanded experience. Rendered tests capture the mobile layouts in ignored tmp/.

## Source and licenses

- scripts/core: simulation, content definitions and persistence.
- scripts/world: voxel scenery, guest routines and cat animations.
- scripts/ui: hotel menus, interaction view and illustrated UI.
- scripts/commerce: Google Play purchase and AdMob adapters.
- scripts/audio and assets/audio: original music and synthesized effects.
- addons: vendored billing and ads plugins with licenses.
- tests and tools: behavioral verification, asset generation and packaging.

Built with [Godot](https://godotengine.org/license/). Engine/dependency notices, Fredoka/Nunito font licenses and mobile plugin licenses are included in the Windows package. Earlier concept documents remain in docs/; the expansion implementation report supersedes their future-content and monetization proposals.
