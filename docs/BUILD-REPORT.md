# Godot prototype build report

This report describes the earlier prototype. The subsequent [gameplay expansion report](EXPANSION-IMPLEMENTATION.md) documents the implemented cat interactions, hotel systems, DLC and ads integration, seven test suites and remaining mobile launch work.

September 8, 2026 • Godot 4.7.2.stable.official.ed1daf0bf

## Delivered

- A real Godot project with procedural 3D voxel geometry and animated feline characters.
- Portrait title screen, live hotel view, four-zone upgrade sheet, hotel map, cat collection, offline earnings, and settings.
- Meadow House and Seaside Suites, with distinct palettes, greenery, and service upgrades. Forest Lodge and Snowcap Spa are visibly labeled future content.
- Automatic shared Cat Coin income, instant upgrade purchases, hotel levels, and the 10,000-coin/level-10 Seaside gate.
- Eight-hour capped offline earnings, per-segment rates, persisted pending claims, and repeat-claim protection.
- Two-slot checksummed local saves. Failed purchases roll back; a corrupt newest slot falls back to the preceding valid snapshot.
- Mouse/touch input handling, pan/zoom, zone selection, cat reactions, sound effects, reduced animation, haptics on supported mobile devices, and mobile safe-area handling.
- A portable Windows preview pack and ZIP, with the Godot runner and engine/dependency notices.

## Verification performed

All four suites passed with zero assertion failures:

1. **Model:** live accrual, fractional frames, upgrade cost/debit, insufficient funds, level gate, persistent network income, two-hour/eight-hour examples, capped unclaimed segments, different rates per segment, rollback of the device clock, repeat claims, save validation.
2. **Store:** alternating writes, purchase round-trip, pending reward persistence, claimed reward reload, corrupt newest-slot recovery, failed write reporting.
3. **Audio:** soundtrack loops, distinct cues, earned-coin thresholds and cooldowns, meow cooldowns, independent music/effect muting, background pause, and hotel track changes.
4. **App:** real scene construction, title Play click, upgrade click, map disabled state, collection/settings, second-hotel transition, offline Collect click, and save reload. Presentation checks cover persistent cat actors after upgrades, walking routes, guests appearing when services open, frozen poses and shader motion when animations are disabled, touch target bounds, and drag release over the HUD.

The app suite ran headlessly and with the OpenGL Compatibility renderer on the available NVIDIA GPU. Rendered runs passed at 450×900 and 360×800 window sizes. Screenshots were inspected; over-bright lighting and a misplaced settings button were corrected. The packaged PCK was separately launched headlessly with the bundled runner and exited successfully.

The restricted host emits a Godot platform diagnostic that it cannot read the Windows root certificate store. No network functionality is used by this game, and no GDScript errors or test failures remained in the final runs. This diagnostic is distinct from game behavior.

## Visual and activity update

- Reframed the orthographic camera so the hotel fills the portrait play area. Added staggered oak floors, paneled walls, curtains, bed linens and paw motifs, cabinetry, food bowls, reception details, lanterns, fences, gardens, flowering ground cover, and fuller voxel trees.
- Five native shaders provide subtle surface grain/edge highlights, contact shadows, wind in foliage, animated water, and a warm screen color grade with a clear area behind the HUD. Geometry remains batched by material; the compatibility renderer uses 4× MSAA. The screen effect runs below the UI so text stays crisp.
- Cats sleep, blink, eat, play, breathe, sway their tails, and walk between service waypoints. Staff wear uniforms; a porter carries folded towels. Buying an upgrade preserves existing actors and their routine progress. Opening the kitchen and lounge adds their guests.
- Floating paw-coin indicators display actual service income rates. Activity captions reflect a cat's current routine. These visual effects do not award extra coins or change the idle economy.
- Rebuilt the portrait interface with Fredoka/Nunito typography, paw-coin artwork, illustrated navigation, a hotel-level progress bar, room previews, hotel-map dioramas, and layered cat portraits. Menu art and icons are original vector drawing code.
- Existing saves and the economy format remain compatible. Disabling gentle animations freezes cats, foliage and water, and suppresses drifting pollen.

Fresh screenshots are in [the gallery](prototype-screenshots/README.md). The smaller [360×800 captures](prototype-screenshots/phone-360x800/02-hotel.png) were also inspected. These are actual Godot frames, with disposable test saves used for later screens.
## Audio, expansion, tree stability, and lighting update

- Added two original, reproducibly synthesized music loops (48 seconds for Meadow, approximately 43.6 seconds for Seaside) with crossfades between hotels. Six distinct effect assets cover taps, earning, spending, collecting, construction, and opening a hotel; three synthesized cartoon meows vary guest sounds. Music and effects have independent saved switches, and pause/stop appropriately in the background.
- Passive coin sounds require actual earned currency and are limited to one cue per 5.5 seconds. Ambient meows start after 12 seconds and then occur at intervals of approximately 24–39 seconds; cat taps also meow, with a cooldown. Neither sound path awards currency.
- Added a Rooms tab, an upgrade-menu shortcut, and a tappable vacant plot. Each of three wings adds two physical furnished rooms, two guest actors, and a permanent income contribution. Costs are 1,200 / 3,500 / 8,000 coins at hotel levels 2 / 4 / 6; additional rates are 30 / 50 / 80 coins per minute. Both hotels independently support eight guest rooms. The camera and garden extend with the building.
- Expansion transactions save immediately, roll back on failed persistence, participate in offline income, and survive reloads. Older saves default to zero wings and preserve an existing sound-mute preference when introducing the new music toggle.
- Replaced overlapping tree-canopy boxes, which had coincident top faces at repeated heights, with a single exposed-surface mesh. Internal voxel faces are removed and wind displacement is continuous across shared vertices. Crown bounds include movement margin; palm fronds no longer overlap in the same plane. A 48-frame motion capture was inspected; a fixed foreground-tree patch showed a mean frame-to-frame channel change of 0.14/255, with a 99th percentile of 4/255. This is a targeted desktop check, not a guarantee across every phone GPU.
- Added emissive lantern glass, soft billboard halos, window-shaped light patches, warm floor pools, and an Evening lighting setting. Real point lights are capped at eight, have short ranges and no dynamic shadow maps. Normal daylight remains the default. Reduced motion leaves lighting steady.
- Expanded model and app tests cover level and price gates, all three wings, invalid/unowned hotel expansion, maximum capacity, migration, offline income, immediate save/reload, failed-save rollback, actual room/guest geometry, and the settings control. All four suites pass; the app passes headlessly and with rendered 450×900 and 360×800 views.

See [the motion preview](prototype-screenshots/hotel-in-motion.gif), [room expansion menu](prototype-screenshots/09-rooms-menu.png), [expanded hotel](prototype-screenshots/10-expanded-hotel.png), and [evening lighting](prototype-screenshots/11-evening-hotel.png).

## Prototype limits

- Art is procedural and inspired by the concept screenshots. It is a real-time voxel interpretation; it does not reproduce the concept render's offline global illumination or final production asset detail.
- Zone paths and guest behavior are lightweight rather than a full navigation/care simulation. Income deliberately does not depend on animation.
- Phone safe areas, touch gestures, thermal performance, accessibility services, Android signing, and iOS builds have not been validated on physical devices.
- An Android export preset is included. The machine had Android Godot templates but no discovered configured Android SDK/JDK installation; no APK was produced.
- Windows export templates were absent. The preview therefore includes the existing Godot editor-capable binary as a game runner plus the exported PCK, not a production template-based executable.
- Long-term pacing is provisional; there are no ads, purchases, accounts, or cloud saves.
- Save integrity protects local commits; deliberate device-clock manipulation is not comprehensively prevented in an offline-only game.
- Restoring a backup after actual file corruption may lose the latest transaction, as the preceding snapshot is recovered.

## Useful files

- [Godot project](../project.godot)
- [Portable preview launcher](../builds/windows/Play.cmd)
- [Windows preview ZIP](../builds/PurringtonHotel-WindowsPreview.zip)
- [Actual gameplay screenshots](prototype-screenshots/README.md)
- [Implementation plan](implementation-plan.md)
- [PRD](PRD.md)

## Platform references

Godot's [command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) describes pack export and launching. Complete mobile packaging using the official [Android export setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). The bundled runner's notices were obtained from Godot's own license APIs, described in [Complying with licenses](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).

Font sources: [Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka) and [Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), both distributed under the SIL Open Font License. Full licenses are in assets/fonts and the preview's FONT_NOTICES.txt. Shader and font implementation references: [Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html), and [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html).

