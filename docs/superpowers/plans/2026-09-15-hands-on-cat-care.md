# Hands-on Cat Care Implementation Plan

> Execute the approved conversation design task by task; state/audio work may run independently of the care UI and stage.

**Goal:** Tap a guest or collection portrait to pet, brush and play with a live cat in a themed room while preserving the illustrated collection.

**Architecture:** A dedicated creative care controller owns navigation and UI; an isolated SubViewport stage owns gestures, props and cat poses. The existing model remains authoritative for friendship, with continuous audio separate from reward persistence.

**Tech Stack:** Godot 4.7.2, GDScript, existing voxel cats, illustrated tools and bundled audio.

**Spec:** Approved “Hands-on Cat Care” plan in this task. Six activities, four staged room themes, safe single-pointer input, return navigation, reduced motion, sound settings, existing friendship rules and no save migration.

## Implementation tasks

- [x] State and audio: preserve 3/6-point rewards and 12-second cooldown; expose progress_changed; skip unchanged saves; guard blocked saves; rollback failed writes. Add start_care_purr/stop_care_purr and focused lifecycle tests.
- [x] Stage: add creative_care_stage.gd and creative_care_room.gd with hit-tested affectionate contact, brush prop, feather tracking/pounces, bounded yarn rolling/chasing, cushion and box. One pointer, explicit cancellation, isolated world and motion settings.
- [x] Screen and routing: add creative_care_screen.gd; open_cat_care and return context in creative_ui.gd; add pick_guest to creative_world.gd. Keep stage alive during care feedback and resize; preserve hotel camera and collection scroll.
- [x] Verification: add creative care integration tests and runner entries. Exercise actual input events, navigation, settings, persistence, all identities/themes and rendered responsive layouts. Run relevant creative and shared regressions. Document controls and verification limits.

## Acceptance

Pet/Brush react only over cat geometry; gestures never pan the hotel. Feather and Yarn respond spatially. All six activities work with the accessible action button. Save feedback does not recreate the stage. Release, cancellation, focus loss, pause, mute and exit cannot leave purring or a held pointer behind. No personal save files are used by tests.

## Verification results

Care state and integration tests pass; rendered coverage includes 24 layouts and all six activity screenshots. All 18 cat identities pass. Relevant creative UI/app/world/gesture/life/model/save suites and legacy audio/mobile-view regressions pass. See `docs/creative-preview/cat-care/README.md` for screenshots and reproduction. Physical Android verification remains pending; no APK or release was published.
