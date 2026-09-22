# Task 5 report — hidden shop interiors and cashier conversation

## Result

Implemented in the isolated `codex/main-street` worktree. Paw Mart and Thread & Paw have separate, small orthographic interior stages located outside street camera bounds. Both roots start inactive. A store stage activates only after the manager arrives at its authored door in Town mode, or when the player re-enters from that same door. Entry captures street camera state and hides the street manager; Leave restores both. Switching a stage always deactivates the other.

Each store has its own furniture and owner cat: Miso wears a grocery apron and Clover wears a boutique scarf. The manager uses the selected coat and markings and moves through an aisle waypoint to the counter. A cashier click opens a named conversation only on arrival. The sheet offers Talk, Quest, Buy, and Leave. Talk has a store-specific line. Quest and Buy are placeholder panels for Tasks 6–8. Back closes an open detail, then the cashier sheet, then the store.

Interior pointer input latches whether a press began outside UI and only accepts a cashier collider on release. Street destination, hotel construction, camera pan, and store selection input do not run while an interior is visible. Exterior shells and roofs remain opaque; no exported Godot geometry was changed.

## Tests and verification

- Added `StoreInteriorTests.cs` for initially hidden roots, exclusive activation, owner identity, cashier route completion, Back behavior, and invalid store IDs. Test code was included in the generated local EditMode project file for a compiler-only check.
- `dotnet build Purrington.EditModeTests.csproj --no-restore -v:q` in the isolated Unity project: **passed, 0 warnings, 0 errors**. This compiles presentation code and the new tests; it does not execute Unity tests.
- `dotnet run --project tests/unity-domain --no-restore`: **PASS 676135 checks**. Dense 600-second simulation: 209 visits, 18 cleanings, 18 guests.
- `git diff --check`: passed.
- A Unity Editor session, Unity EditMode test execution, simulated pointer acceptance at 100% and 150% text, visual camera review, and runtime input checks were **deferred** because the original checkout has an active Editor and a second Editor/build was prohibited for this task.

## Files

- Added `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/StoreInteriorView.cs` and `.meta`.
- Added `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/StoreInteriorTests.cs` and `.meta`.
- Updated `VoxelWorldTown.cs`, `VoxelWorld.cs`, `VoxelWorldInput.cs`, `HotelTownUI.cs`, `HotelUI.cs`, and `HotelApp.cs` for lifecycle, input, camera, and UI wiring.
- Generated Unity `.csproj` files were modified locally only to include new sources for the compiler check; these files are ignored and are not committed.

## Self-review and concerns

- Verified the world entry gate checks Town mode, Meadow map, and the domain's arrived shop ID. Closed storefront taps still send a door destination and do not expose a stage.
- Verified both stage roots are inactive at construction and that `Enter` activates exactly one. Exiting clears the active ID and hides the manager. The street camera's focus, zoom, manual mode, and fit bounds are restored from entry.
- Verified the cashier event fires only after both authored waypoints are reached, including when a large time step crosses both in one update.
- Quest and Buy intentionally contain placeholder content until commerce and quest work in Tasks 6–8. They grant no coins, items, or rewards.
- The generated view art and touch layouts still need an Editor/player visual and pointer pass before claiming acceptance, especially for portrait layouts at 150% text.
