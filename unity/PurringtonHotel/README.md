# Purrington Hotel — Unity Meadow preview

**This remains a voxel 3D, orthographic isometric game.** Android and iOS drive the interface; Windows is the main development/QA platform. The existing Godot game and saves remain separate.

## Setup and current status

The project now pins installed **Unity 6000.3.24f1 LTS**. The Windows preview and 13 EditMode tests have been verified on 6.3; rendering and input packages were upgraded by Unity.

The initial Meadow slice configures and produces a **Windows development build**. **13 Unity EditMode tests pass**. Programmatic runtime smoke passes startup, orthographic camera, navigation, care stage, layouts, and save, producing 18 captures without exceptions. This is not an actual pointer-driven or device walkthrough. The 97 passing assertions from the separate .NET domain harness are additional evidence, not Unity tests. See [retained screenshots/results](../../docs/unity-migration/evidence/README.md). An Android development APK build succeeded at `builds/unity/Android/PurringtonHotel.apk` (approximately 94 MB). The existing APK was built with 6.0 and predates the 6.3 zoom/layout update; device/iOS verification remains pending.

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
- **Persistence:** Unity uses its own `Application.persistentDataPath`, with `-purrington-profile <directory>` available for isolated QA. Godot journals are never imported or overwritten. Construction and care attempt saves with rollback; all required failure/recovery scenarios still need Unity validation.

## What is implemented in source

The first slice includes voxel cats and Meadow scenery, pan/zoom, Hotel/Cats/Build/Life/Map navigation, category browsing and native block illustrations, room/furniture placement and editing, storage/retrieval, room removal with stored contents/refund, and 20-action Undo/Redo. Existing rooms rotate through Rooms → Edit; new rooms currently rotate after placement.

The interface includes safe-area handling, 100%/125%/150% text settings, music/effects/motion settings, care tools, saved collection scroll on return, compact horizontally scrolling category chips, bold typography, and native voxel-style navigation icons. Desktop header/navigation/objective panels have constrained widths. Captures cover representative layouts; the complete device matrix and actual input walkthrough remain to verify.

Follow-up fixes preserve the in-memory hotel when Retry follows an initial save-write failure and correct pinch-gesture ownership. The separate domain harness now passes 97 assertions. The expanded 13-test Unity suite now passes with zero failures/errors/skips. Physical touch testing is still pending.

## Known limits and next work

- Meadow life density is improved for playable readability (faster guest routines, closer Hotel fit, guest activity speech) but still uses reception ? play ? bedside-rest visual routines without exclusive venue reservations; full Godot service/seating simulation, capacity rotation, housekeeping, conversations, gatherings, and scrapbook remain to port.
- Income and arrivals are more readable in the Hotel header (`+N / min` under coins) and Hotel/Life panels (staying/capacity/arriving counts), but still use a simplified ready-room economy model, not full Godot economy/capacity parity. Domain construction now covers land plots, earth/gravel/brick paths, room copy/resize/move/remove, furnished templates, catalogue placement, storage, and God mode (see tests/unity-domain ConstructionSuites); Build catalogue shows larger preview cards with VoxelIcon fallback until illustrated thumbs land. Presentation polish and visual/input evidence remain open.
- Pet, Brush, Feather (wand), Yarn, Cushion, and Box use gesture input: stroke/hold, brush strokes, feather drag, yarn flick, and tap-to-place cushion/box. Friendship stays +3/+6 (favorite), 12s cooldown, cap 100. Deeper physics toy play can still improve.
- Pointer/device acceptance harness drives real Input System mouse/touch through UI (including care strokes/flicks). Physical-device sign-off and the full resolution matrix remain outstanding.
- Two-slot checksummed journal writes replace only the older slot (atomic replace) and keep Retry messaging when a write fails; corrupt-slot recovery and blocked-write-until-reset are covered by EditMode tests. Offline reconciliation, full device lifecycle matrix, and Godot migration parity still need verification.

- Seaside, Forest, and Snowcap are shown as future destinations. No live commerce, advertising, accounts, or cloud saves are included.
- Layout, accessibility, performance, and platform compatibility are targets until measured. Device Simulator does not replace physical-device testing.

Continue with the [implementation plan](../../docs/unity-migration/IMPLEMENTATION-PLAN.md) and [QA checklist](../../docs/unity-migration/QA.md). Keep Library, Temp, Logs, and build output untracked; retain `.meta` files, source assets, package locks, and license notices.
