# Unity implementation and continuation plan

## Required identity and architecture

**NON-NEGOTIABLE: a voxel 3D game viewed through an orthographic isometric camera.** Preserve block-built cats, furniture, buildings, and scenery. Keep pan/zoom useful for hotel management and maintain readable cats at phone size. UI polish must leave the voxel world visible.

Create `unity/PurringtonHotel` alongside Godot. Pin an installed Unity 6.3 LTS patch, use Universal 3D/URP, Input System, uGUI/TextMeshPro, and Unity Test Framework. Use Unity Package Manager for dependencies and commit resolved versions. Bootstrap, Meadow, and Cat Care are separate scenes, with gameplay, presentation, editor, and test assemblies. Support Windows previews, Android development APKs, and iOS export; final iOS compilation and signing require macOS/Xcode.

Keep the simulation in plain C# services. Unity views render authoritative state; they do not own coins, construction legality, or friendship. ScriptableObjects define cats, furniture, rooms, and maps using the existing content IDs and initial prices. Typed gameplay commands return success, cost, and a player-readable reason. Preview validates without charging. Inject time and storage for deterministic verification. Refresh views from state-change notifications.

Use fresh versioned Unity saves under a distinct application identity. Alternate two checksummed journal slots, recover from the latest valid slot, and preserve unreadable files for recovery. Construction saves are transactional: failure restores wallet, ownership, layout, and history and exposes Retry. Undo/Redo keeps up to 20 construction actions and preserves subsequently earned income and friendship. Never read, overwrite, or convert Godot saves automatically.

## First playable milestone: Meadow

Status: **Windows development build and initial automated verification complete; full acceptance pending**. The project now pins installed 6000.3.24f1 LTS and the Windows preview has been revalidated. Configuration succeeded, 13 Unity EditMode tests passed, and a programmatic runtime smoke check passed with 18 captures and no exceptions. An Android development APK build succeeded; device testing remains pending. Milestones 1 and 2 remain open for remaining behavior and actual pointer/device acceptance. The following requirements define completion, rather than reporting completed work.

- Recreate Meadow's connected hotel, reception, planted fountain garden, arrival street, and neighborhood. Improve materials, lighting, and restrained animation without losing voxel shapes. Maintain the orthographic isometric view in gameplay and placement.
- Deliver arrivals, check-in at real reception, reachable beds and basic activities, income, and friendship. Invalidate navigation after layout changes; guests cannot walk through walls or use disconnected venues. Unfinished rooms remain editable and saved, with a readable explanation of why they are inactive.
- Provide room and furniture placement, movement, rotation, removal, storage/retrieval, quote/cancel/confirm, and 20-action Undo/Redo. Removing a room preserves its furniture in Storage. Readiness depends on a reachable bed and constructed access to working reception.
- Include Pet, Brush, Feather, Yarn, Cushion, and Box. Preserve the internal `wand` ID for Feather. Preserve the source's 12-second friendship cooldown, +3 ordinary/+6 favorite reward, and cap of 100; interaction continues during cooldown without extra save writes. Failed care saves roll back progress.
- Keep hotel life advancing during care. Return to the previous camera, selected cat, and collection scroll. Life displays implemented activity information; Map exposes Meadow and honestly marks later destinations unavailable.
- Provide the complete loop: welcome a cat → earn coins → furnish a room → care for the cat → save → restart with progress intact.

### Mobile UI direction

Use cream surfaces, mint primary actions, coral highlights, golden rewards, dark text, Fredoka headings, and Nunito body text. Reuse portraits and licensed art in native interactive layouts. Retain labeled Hotel, Cats, Build, Life, and Map navigation with a prominent central Build action.

Replace the large welcome panel with a collapsible objective card. Use compact money/status indicators, illustrated catalogue cards, and bottom sheets. Placement collapses browsing to item, price, Rotate, Cancel, and Place, leaving at least half the safe screen height for the world. Reflow secondary details into sheets at large text sizes. Cat care has a large live voxel character stage and immediate tool feedback.

Support safe areas, minimum 48-unit touch targets, 56-unit primary controls, 100%/125%/150% text, reduced motion, and independent music/effects controls. UI events never place furniture or pan the world underneath. Desktop can use a side catalogue while keeping the same actions and navigation semantics.

## Ordered continuation backlog

| Milestone | Behavior to restore | Godot source / regression reference |
|---|---|---|
| 1. Foundation and visual proof | Clean import, pinned packages, scenes, orthographic voxel rendering, mobile layout, initial preview | `creative_world`, `creative_objects`, `creative_neighborhood`; `test_creative_world`, `test_creative_voxel_polish`, `test_creative_lighting`, `test_creative_ui` |
| 2. Playable Meadow | First-loop requirements above, durable saves, Windows preview and Android APK | `creative_model`, `lot_geometry`, `social_simulation`, care screen/stage; `test_creative_model`, `test_creative_building`, `test_creative_care_state`, `test_creative_save_integrity` |
| 3. Construction parity | Copy/resize rooms; individually editable lobby, milkshake café, lounge, playroom, sunroom, and terrace templates; earth/gravel/brick path painting/erasure; full catalogue, land, and God mode | `creative_content`, `creative_model`, `lot_geometry`; `test_creative_content`, `test_creative_building`, `test_creative_god_mode`, `test_creative_maps_integration` |
| 4. Hotel-life parity | Exclusive activity/seat reservations, automatic milkshake attendants, housekeeping, upgrades, social exchanges, gatherings, scrapbook, speech, and reactive objects | `social_simulation`, `creative_life`, `creative_moments`, `creative_dialogue`, object/water motion; `test_creative_services`, `test_creative_social`, `test_creative_moments`, `test_creative_speech`, `test_creative_object_motion` |
| 5. Destination parity | Seaside promenade/café, Forest woodland playroom, Snowcap fireside courtyard, themed care rooms/neighborhoods, map ownership and travel | `creative_maps`, `creative_neighborhood`, `creative_care_room`; `test_creative_maps_integration`, `test_creative_meadow`, `test_creative_neighborhood`, `test_creative_care` |
| 6. Mobile readiness | Device profiling, touch/lifecycle recovery, accessibility, Android distribution preparation, signed iOS testing | Existing mobile UI/gesture tests and Android testing guide; new Unity device evidence required |

Source names above refer to `scripts/creative/*.gd` and `tests/*.gd`. Read the current source when porting; do not use legacy `scenes/main.tscn` as the game specification.

### Parity rules that must survive later milestones

- Construction has no eight-room cap. Regular rooms support two guests and suites four. Rooms cost 450/1,200 initially; extra floor costs 25 per cell. Adjacent parcels cost 750, 750, and 1,000. Shrinking/refunds honor the amount actually paid. Furniture footprints include half-cell units; do not round them away during the port.
- An access path cannot reach a bed through a closed wall. Disconnection makes a room inactive without deleting it. Outdoor activities may use grass access. Moved reception becomes the new arrival destination.
- Milkshakes proceed through ordering, serving, and a reserved seat; staff stations and guest slots remain exclusive. Removing a venue releases reservations without awarding completion. Copied counters add attendants/capacity, not duplicate hotel-wide upgrade income. Housekeeping unlocks at level 3 and never creates guest rewards.
- Known guests rotate through available operational capacity. Removing capacity removes excess guests and releases reservations. Conversations are cancellable, nearby, same-area exchanges, do not create visits, and preserve the underlying activity timer.
- God mode starts off, persists when enabled, grants unlocks/free edits, and retains geometry/access validation. Changing it clears construction history. Free items carry zero refund value; disabling it keeps creations/unlocks and restores normal prices.
- Seaside retains Meadow level 10 and 10,000 earned Cat Coins. Forest/Snowcap expansion access remains a clearly labeled preview/test unlock until a separate commerce project is authorized. Do not add live payments or ads.

## Delivery and acceptance

The current slice uses reception → play → bedside-rest visual routines and room-based income/arrivals; it does not yet reproduce exclusive venue reservations, the source's full service simulation, two/four-guest room capacities, content catalogue, offline reconciliation, or every transaction/recovery behavior. The care tools currently use selected-tool/tap interactions rather than full stroke/flick gesture parity. Named Meadow and Cat Care scenes share a runtime bootstrap; care is a runtime view rather than an independent scene-flow implementation. These are continuation tasks, not completed parity. See the [project README](../../unity/PurringtonHotel/README.md) for the current implementation boundary.

Each milestone provides a playable build where tooling permits, screenshots, test results, known limitations, and an updated checklist. Record actual editor/build versions and measured hardware. Follow [QA.md](QA.md); do not substitute successful compilation for a rendered walkthrough or claim a device test from simulator results.

Windows targets 60 FPS and mobile targets a stable 30 FPS baseline. These are goals until measured. Defer emulator installation initially; use Device Simulator for layout and real devices for final touch, graphics, lifecycle, and performance checks.
