# Unity acceptance checklist

All boxes start unchecked. Mark a check only with observed evidence; distinguish implemented, tested, blocked, and deferred work. Godot regression results are reference evidence, not proof of Unity behavior.

## Current evidence checkpoint

- Zoom/layout regression: one normalized mouse-wheel notch changes orthographic size by 15%; an opposite notch restores it. Runtime checks verify every visible top-level UI panel stays inside the screen, including 640×480, 800×760, and 320×480. One shared portrait/landscape breakpoint and scaling against both safe-area dimensions replace the inconsistent sizing rules.

- Installed editor/project version: **6000.3.24f1 LTS**. Windows build and all 13 EditMode tests passed on this version.
- Configuration and Windows development build succeeded on Unity 6.3.
- Final Windows and Android builds include the save-retry, pinch-ownership, and enlarged Menu fixes. The project was opened in Unity and entered Play mode; live inspection confirmed a loaded hotel, one guest, and an orthographic camera.
- **13 Unity EditMode tests passed**, with zero failures/errors/skips: [retained JUnit results](evidence/test-results.xml).
- Programmatic runtime smoke passed startup, orthographic camera, navigation, care stage, layouts, and save, producing 18 captures without exceptions. [Representative evidence](evidence/README.md) is retained. These checks invoke runtime actions programmatically; they are not a pointer-driven walkthrough or device test.
- A separate .NET harness reported **97 domain assertions passed**. This did not run inside Unity and does not establish Unity serialization, rendered interaction, PlayMode, or platform behavior.
- Implemented follow-up fixes preserve the current in-memory hotel when retrying a failed initial save and correct touch-pinch gesture ownership. The expanded 13-test Unity suite now passes with zero failures/errors/skips. Physical touch testing remains pending.
- An Android development APK build succeeded; iOS export, device testing, performance measurements, the complete layout matrix, and an actual pointer-driven walkthrough remain **pending**. The checklist below is the full acceptance gate and remains open where smoke coverage is insufficient.

## Foundation and first Meadow slice

- [ ] Project opens in its exact pinned Unity 6.3 LTS patch; scripts compile and scenes enter Play without console errors.
- [x] Gameplay is visibly **voxel 3D and orthographic isometric**: block-built cats, rooms, furniture, foliage, and scenery remain legible at phone size. Representative Windows runtime screenshots retained in `evidence/`.
- [ ] A fresh player welcomes a guest, earns coins, furnishes a room, uses care, restarts, and recovers the same progress.
- [ ] Arrival targets actual reception; beds/activities require legal routes; moving/removing furniture updates routes. Unfinished rooms stay saved and show clear readiness problems.
- [ ] Quotes do not mutate state or charge. Invalid/overlapping placement and insufficient funds fail with readable feedback. Cancel clears the preview. Confirm applies the shown cost once.
- [ ] Move, rotate, remove, store/retrieve, and Undo/Redo work; room removal stores contents; history is capped at 20 and preserves intervening income/friendship.
- [ ] Pet, Brush, Feather, Yarn, Cushion, and Box provide visible feedback. Friendship cooldown/reward/cap match source; failed care saves roll back progress; hotel life continues.
- [ ] Navigation/Back restores camera, cat selection, and scroll. UI clicks/drags do not affect the world underneath; pinch/pan/zoom and cancellation work.
- [ ] Save round trip, interrupted write, invalid checksum, latest-slot corruption, both-slot corruption, disk failure, rollback, Retry, and pause/resume are covered. Godot saves remain untouched.
- [ ] Life reports real implemented activity and Map labels unimplemented destinations honestly.
- [ ] Windows preview and Android development APK build successfully and their launch/loop results are recorded separately.

## UI and visual walkthrough

Test 360×640, 360×800, 390×844, 430×932, a tablet portrait/landscape layout, and 1280×800 Windows. Repeat at 100%, 125%, and 150% text with simulated safe-area insets.

- [ ] Hotel, Cats, Build, Life, Map, Settings, care, catalogue browsing, placement, selected furniture, room controls, and save-error states remain readable and operable.
- [ ] Placement leaves at least half the safe screen height for the voxel world; larger text causes useful reflow rather than clipped buttons.
- [ ] Minimum 48-unit touch targets and 56-unit primary controls; no unsafe-area overlap or unreachable actions.
- [ ] Bright toy-like UI uses consistent typography, contrast, spacing, portraits, and feedback. Warnings are not conveyed by color alone.
- [ ] Reduced motion removes unnecessary ambient/care motion; music and effects controls act independently.
- [ ] Rendered evidence includes Meadow overview, occupied hotel, placement, enlarged text, care, and a recovery/error state.

## Later parity gates

- [ ] Construction: more than eight rooms, copy/resize with paid-floor refunds, rotated editable templates, path strokes/erasure, parcels, full catalogue, inventory, and God mode behavior.
- [ ] Services: exclusive guest/staff reservations, order → serve → sit, cancellation on venue removal, moved reception, grass venues, capacity rotation, housekeeping, and nonduplicated upgrade income.
- [ ] Social: ordered/cancellable conversations, no speaking through walls, correct cooldowns, preserved activity timers, gatherings, scrapbook, and readable nonblocking speech.
- [ ] Visual life: themed neighborhoods and care rooms, waving/attention, fountain/fire/litter/counter and other object animations honoring reduced motion.
- [ ] Destinations: each starter layout is operational, all rotations of templates remain legal, ownership/travel persists, Seaside earned unlock works, preview expansions invoke no commerce.

## Evidence and platform limits

Use EditMode tests for domain rules and persistence failure injection; PlayMode tests for scene/UI integration; rendered input walkthroughs for actual interaction and layout. Record command, editor version, exit/result, timestamp, and evidence location. Report failures and skipped cases explicitly.

Device Simulator verifies layout/safe areas but does not establish real touch quality, thermal behavior, GPU performance, native plugin correctness, or lifecycle reliability. An Android APK built on Windows is not a physical-device test. iOS export on Windows is not an iOS build/signing result; final compilation/signing requires macOS/Xcode.

Profile an occupied, furnished Meadow and a later dense hotel. Target 60 FPS on the development Windows machine and stable 30 FPS on supported mobile hardware. Record device/CPU/GPU, resolution, quality tier, frame times, guest/furniture count, memory, and test duration before making performance claims. Include device suspend/resume and restart recovery. Do not call a milestone complete while its required checks are merely planned.
