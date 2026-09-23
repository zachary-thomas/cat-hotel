# Task 4 report — Meadow Main Street exterior

Status: DONE_WITH_CONCERNS. Implementation and compiler/domain checks completed; Unity runtime gates intentionally deferred.

## Changes

- Added MainStreetArt: additive Meadow paving, authored graph approaches, tiled compact square, distinct Paw Mart and Thread & Paw exteriors with opaque shells/roofs, clickable doors and elevated readable signs, display details, two kiosk shells, two benches, lamps, event board, and planters clear of the central routes.
- Shop shells consume the exact TownContent footprints. MainStreet.json and domain coordinates were not changed. NeighborhoodView clones the exported neighborhood recipe and removes only NeighborHome4 and NeighborHome5 for Meadow; exported source JSON stays untouched.
- Added ManagerCatArt's single voxel rig recipe with six fur coats and four anchored marking patterns. Facial pieces use contrasting colors; inner ears and nose retain their materials. GodotCatRig accepts authored recipes. Preserved head/body bindings plus wear.head, wear.neck, and wear.back attachment hooks. Existing cat rig consumers continue through the original constructor.
- Added VoxelWorld town mode with saved/restored hotel camera framing, Follow manager, Fit street, extended limits only in town, manager movement synchronized from saved domain state, live unsaved appearance preview, and no interior construction/activation.
- Scene sign/door taps dispatch StoreSelected before hotel input. Pavement uses authored graph distance within 1.25 domain units and NearestStreetTarget to choose its endpoint; grass reports “Tap a Main Street path.” Store and ground routes preserve model transaction/save-error reporting. Drag and two-finger midpoint pan/pinch disengage Follow and retain gesture ownership. Town entry cancels placement and path paint.
- Added HotelTownUI action interface and HotelUI partial panel: Explore from Hotel and Life, Follow/Skip/Fit, destination buttons, rename, six coats/four markings, Save look and Cancel. Preview changes remain unsaved until confirmed. Back returns to Hotel with original framing; store arrival remains exterior only.
- Extended the opt-in ParityInputAcceptance harness with real queued touch sign selection, route start assertion, drag, pinch, Back, placement isolation, no-interior checks, and exterior screenshot capture through its existing viewport/text-size matrix.

## Tests and results

- Wrote MainStreetViewTests before implementation. Checks cover two separate opaque storefront roots, footprint dimensions, sign/door hit components, paved anchors/square bounds, no interior markers, mid-link pavement resolution versus distant grass, and all 24 coat/marking combinations on GodotCatRig with contrasting eyes and correct animated wear parents.
- Unity red/green execution was NOT attempted: the original checkout has an open Editor and concurrent hotel-growth work; task instructions prohibit another Editor/build. Therefore no executed TDD red/green result is claimed.
- Compiler-only verification: `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore --nologo -v:q` succeeded with 0 warnings and 0 errors after local generated project restore. This compiles domain, presentation, and EditMode source against installed Unity references without opening Unity. Generated ignored project files include new source files; outputs stay in isolated worktree Temp.
- Standalone domain regression: `dotnet run --project tests/unity-domain/Purrington.Domain.Tests.csproj --no-restore` from repository root: PASS 676135 checks. Initial invocation from tests/unity-domain failed on relative content path; corrected working directory and reran successfully.
- `git diff --check`: passed.

## Deferred gates / limitations

- Run `tools/unity.ps1 Test` when isolated Editor access is safe. EditMode source compiled but tests have not executed in Unity.
- Run the real input acceptance player harness and inspect 360×640, 390×844, and 1280×800 exterior captures, 100–150% text, signs, cat scale, camera restoration, touch routing, Fit/Follow, and construction isolation. Harness is authored/compiled but not executed.
- Inspect each marking on cream and charcoal in the manager preview; screenshots/visual readability remain unverified without Unity.
- Shared wardrobe implementation is not available on this branch. Binding hooks are ready; actual owned outfit attachment/assertions are deferred under the explicit task ruling.
- No shop interior is built or activated. Store arrival is ready for subsequent interior integration.
- Physical Android/iOS touch verification remains a release gate.

## Self-review

Verified that shells use content bounds, manager preview never calls appearance save automatically, cancel/navigation discards preview, hotel input callbacks cannot receive town taps, map changes disable the Meadow art/manager, roofs are opaque, and save failures from pavement routes flow through HotelApp.Report/Retry. Corrected Back navigation so it no longer overwrites saved framing with FitHotel, preserved offline Collect behavior, moved shop signs above roofs for both facade orientations, and reset the input fixture to the square before sign travel so repeated viewport cases remain meaningful.

## Files

New: Runtime/Presentation/MainStreetArt.cs, ManagerCatArt.cs, VoxelWorldTown.cs, HotelTownUI.cs; Tests/EditMode/MainStreetViewTests.cs; corresponding Unity .meta files.
Modified: Runtime/Presentation/GodotCatRig.cs, NeighborhoodView.cs, VoxelWorld.cs, VoxelWorldInput.cs, HotelApp.cs, HotelUI.cs, HotelParityUI.cs, ParityInputAcceptance.cs.
All paths above are under unity/PurringtonHotel/Assets/Purrington/. This report is .superpowers/sdd/2026-09-22-main-street/task-4-report.md.


## Review fix — authored roof renderer lookup

Fixed the Important review finding on base 76046ba: the roof opacity test previously queried Renderer on the recipe root, whereas GodotGeometry.Build creates Renderer on its Authored surfaces child. The test now asserts that both the roof root and its child Renderer exist before checking material alpha.

Self-review: inspected every renderer lookup in MainStreetViewTests. The eye and ear material checks already use GetComponentInChildren<Renderer>(); shell dimensions intentionally inspect the recipe root transform, and storefront hit checks already traverse descendants. No production code changed.

Verification after the fix:
- `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore --nologo -v:q`: Build succeeded; 0 warnings; 0 errors (1.89 seconds reported).
- `dotnet run --project tests/unity-domain/Purrington.Domain.Tests.csproj --no-restore`: PASS 676135 checks.
- `git diff --check`: passed with no output.

Unity execution remains deferred; no second Editor was launched. The minor acceptance gaps (placement-to-town transition and exact camera-restoration assertion) remain explicitly deferred to Task 10.
