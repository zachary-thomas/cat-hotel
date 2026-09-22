# Task 2 report: wardrobe content and cat rigs

## Changes

- `HotelApp` loads and validates `Resources/Content/Wardrobe.json` before restoring a save. A missing asset now stops profile initialization with a clear error.
- Added `CatOutfitView` to build each item's voxel boxes under its head or body anchor, size them from the anchor's own authored surfaces, and replace or clear worn pieces. Authored eyes and muzzle face positive Z, so the neck piece uses the body's positive Z face.
- Guest actors apply their saved outfits when first built and when the outfit signature changes. The signature cache is cleared when a map rebuild removes rigs and when actors leave.
- The care rig applies the saved outfit when opened, including when an existing stage is reused. `PreviewOutfit` supplies the try-on hook for the wardrobe UI.
- Added EditMode content and anchor tests, with Unity `.meta` files for both new C# files.

## Verification

- First compiler-only EditMode build failed before reaching the new test because Unity's generated project file did not yet include the shared `HotelWardrobe.cs`. Refreshed ignored generated project compile entries for `HotelWardrobe.cs`, `CatOutfitView.cs`, and `WardrobeTests.cs` locally.
- Final `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -nologo -v:q`: **passed, 0 warnings, 0 errors**. This compiles the EditMode test; it does not execute Unity tests.
- `dotnet run --project tests/unity-domain/Purrington.Domain.Tests.csproj --no-restore`: **passed, 676,159 checks**, including the Wardrobe suite.
- `git diff --check`: passed. Self-review checked outfit replacement, slot matching, cache lifetime, and anchor geometry.

## Files

- `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/CatOutfitView.cs` and `.meta`
- `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelApp.cs`
- `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorld.cs`
- `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldCare.cs`
- `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/WardrobeTests.cs` and `.meta`

## Remaining verification and concerns

- Unity EditMode execution and Play mode visual checks were deferred because the original checkout has an active Unity Editor and this isolated worktree must not start another Editor. In particular, hat clearance between ears and bow tie placement under the chin require visual confirmation.
- The parent integration task must connect the wardrobe UI to `VoxelWorld.PreviewOutfit` and manager outfit application after ownership validation. Street neighbors remain undressed because they are not roster cats.
