# Purrington Hotel — Unity Meadow preview

**This remains a voxel 3D, orthographic isometric game.** Android and iOS drive the interface; Windows is the main development/QA platform. The existing Godot game and saves remain separate.

## Setup and current status

The project pins installed **Unity 6000.3.24f1 LTS**. The updated Windows development preview is `builds/unity/Windows/PurringtonHotel.exe`. See the [concept update, comparisons and verification results](../../docs/art/qa-shots/concept-meadow/README.md).

The existing Android APK was built with Unity 6.0 and predates this update. Physical Android/iOS verification remains pending; iOS compilation/signing requires macOS/Xcode.

Use the official Unity CLI and run these commands from the repository root:

```powershell
.\tools\unity.ps1 Open
.\tools\unity.ps1 Configure
.\tools\unity.ps1 Test
.\tools\unity.ps1 Windows
.\tools\unity.ps1 Android
.\tools\unity.ps1 iOS
.\tools\unity.ps1 Play
```

`Configure` creates the runtime prefab, named scenes, content assets, material, and TMP fonts/resources. `Test` runs EditMode tests and writes `builds/unity/test-results.xml`. `Play` launches the built preview at `builds/unity/Windows/PurringtonHotel.exe`. Android/iOS require their editor support modules; final iOS compilation/signing requires macOS/Xcode.

## Architecture

- **Domain:** plain C# hotel state, item catalogue, placement/readiness rules, half-cell navigation, construction commands, storage, care, history, and two-slot checksummed journal persistence. Save and serialization interfaces support isolated tests.
- **Presentation:** `HotelApp` connects domain, voxel world, UI, audio, and save lifecycle. `VoxelWorld` procedurally builds the orthographic hotel and cat views; `HotelUI` supplies native uGUI/TextMeshPro navigation, catalogue, settings, and care.
- **Authoring:** catalogue and Meadow starter ScriptableObjects provide initial content. `ProjectSetup` creates Bootstrap, Meadow, and CatCare authoring entrypoints around the shared runtime prefab; only Bootstrap is the build entrypoint. Care currently switches the runtime camera/UI, rather than loading a separate gameplay scene.
- **Persistence:** Unity uses its own `Application.persistentDataPath`, with `-purrington-profile <directory>` available for isolated QA. Godot journals are never imported or overwritten. Construction and care attempt saves with rollback; failed-care friendship/cooldown rollback and Assisted care preference persistence have explicit regression coverage.

## What is implemented in source

The first slice includes voxel cats and Meadow scenery, pan/zoom, Hotel/Cats/Build/Life/Map navigation, category browsing and native block illustrations, room/furniture placement and editing, storage/retrieval, room removal with stored contents/refund, and 20-action Undo/Redo. Existing rooms rotate through Rooms → Edit; new rooms currently rotate after placement.

The interface includes safe-area handling, 100%/125%/150% text settings, music/effects/motion settings, care tools, saved collection scroll on return, compact horizontally scrolling category chips, bold typography, and native voxel-style navigation icons. Desktop header/navigation/objective panels have constrained widths. Windows captures and queued mouse/touch acceptance cover portrait and landscape layouts with all three text sizes. Physical-device verification remains pending.

Save recovery preserves the in-memory hotel when Retry follows an initial save-write failure. The domain regression harness also covers construction, maps, dense hotel routines and God mode.

## Concept-inspired Meadow update

The original `docs/concept-art` hotel screenshots now guide materials, lighting, timber floors, moss wall panels, and UI. The later pastel palette is no longer the world target.

Meadow has ten street cats and up to three transient milkshake visitors when an accessible bar exists. Visitors share service reservations without consuming beds or altering progression. Reception and milkshake service use explicit customer-front/staff-rear positions, with staff elevation measured from the desktop geometry. Dialogue uses a single Godot-style named speech bubble with face avoidance and timed replies.

All 38 build items now have actual-model thumbnails. Regenerate them with **Purrington > Art > Regenerate catalogue previews**. Care includes roaming, walk-to-placement behavior, deliberate gestures, one reward per interaction, and optional **Assisted care** in Settings. Old saves default assisted care off.

## Known limits and next work

- Meadow life density is improved for playable readability (faster guest routines, closer Hotel fit, guest activity speech) but still uses reception, play and bedside-rest visual routines with exclusive venue reservations, day visitors, and timed conversations; full gatherings and scrapbook behavior remain to port.
- Income and arrivals are more readable in the Hotel header (`+N / min` under coins) and Hotel/Life panels (staying/capacity/arriving counts), but still use a simplified ready-room economy model, not full Godot economy/capacity parity. Domain construction now covers land plots, earth/gravel/brick paths, room copy/resize/move/remove, furnished templates, catalogue placement, storage, and God mode (see tests/unity-domain ConstructionSuites); Build catalogue now shows actual-model thumbnails, with a role-icon fallback for unexpected missing content. Current visual and input evidence is linked above.
- Pet, Brush, Feather (wand), Yarn, Cushion, and Box use gesture input: stroke/hold, brush strokes, feather drag, yarn flick, and tap-to-place cushion/box. Friendship stays +3/+6 (favorite), 12s cooldown, cap 100. Deeper physics toy play can still improve.
- Pointer/device acceptance harness drives real Input System mouse/touch through UI (including care strokes/flicks). Physical-device sign-off remains outstanding.
- Two-slot checksummed journal writes replace only the older slot (atomic replace) and keep Retry messaging when a write fails; corrupt-slot recovery and blocked-write-until-reset are covered by EditMode tests. Offline reconciliation, full device lifecycle matrix, and Godot migration parity still need verification.

- Seaside, Forest, and Snowcap are shown as future destinations. No live commerce, advertising, accounts, or cloud saves are included.
- Measured Windows results do not establish mobile performance or platform compatibility. Device Simulator does not replace physical-device testing.

Continue with the [implementation plan](../../docs/unity-migration/IMPLEMENTATION-PLAN.md) and [QA checklist](../../docs/unity-migration/QA.md). Keep Library, Temp, Logs, and build output untracked; retain `.meta` files, source assets, package locks, and license notices.
