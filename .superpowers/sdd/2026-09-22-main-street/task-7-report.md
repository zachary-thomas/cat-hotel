# Task 7 report — Paw Mart interior and shopping carts

## Result
Implemented in the isolated codex/main-street checkout. PawMartArt adds staggered pale timber floorboards, timber pantry shelves with labeled cream cartons, raised apple/greens produce bins, a framed chilled milk cabinet, nested basket stacks, and a checkout belt/register. The central approach and browsing paths remain open. Materials follow docs/art/STYLE-GUIDE.md. GodotGeometry.json is unchanged.

ShoppingCartRig builds the same reusable four-wheel voxel cart for the manager and two distinct NPC shoppers (Olive: cream/tabby; Bean: cocoa/tuxedo). It has open basket rails, chassis, paw-height handle, four separately rotating wheels, and swappable welcome produce/market parcel contents. GodotGeometry reuses matching meshes. SetPose takes accumulated travel distance and stage-local cat position/facing; its offset rotates with the cat on every turn. Contents bob with traveled distance and wheels rotate around their axles. Stationary frames do not add motion. Reduced motion removes both wheel rotation and contents bobbing while preserving the front-paw push pose and route/result.

A successful Paw Mart purchase starts a short manager cart loop and returns to the cashier for a 1.4-second handoff pose. Failed transactions never start it. A second successful purchase during that loop updates contents. Inventory/notice refresh stays on the existing success path; presentation grants no items. The conversation stays accessible throughout the routine, including Leave/Back. Two shoppers run half a loop apart on an authored rectangle; each retains its own rig, cart, and travel distance. Switching to clothing or leaving hides all grocery carts. Entering a shop resets the transient manager routine. Application pause freezes route progression and suppresses spin/bob; resume continues from the same position. Purchases persist through the existing domain transaction; these decorative routines are intentionally transient.

## Files
- Added Runtime/Presentation/PawMartArt.cs and .meta.
- Added Runtime/Presentation/ShoppingCartRig.cs and .meta.
- Added Tests/EditMode/ShoppingCartTests.cs and .meta (four regression tests).
- Updated Runtime/Presentation/StoreInteriorView.cs, GodotCatRig.cs, HotelTownUI.cs.
- Updated ignored generated Presentation/EditMode csproj source references locally for compiler validation; not committed.
- Added this report.

All runtime/test paths above are under unity/PurringtonHotel/Assets/Purrington.

## Verification and evidence
- RED: dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -v:q failed with 12 expected missing API compilation errors (ShoppingCartRig, ShoppingCarts, StartPurchaseRoutine, IsShopping), zero warnings.
- GREEN compilation, final: same command succeeded: Build succeeded. 0 Warning(s), 0 Error(s). 1.38 seconds.
- Full domain suite: dotnet run --project tests/unity-domain --no-restore: PASS 676207 checks. Dense 600s: 209 visits, 18 cleaned, 18 guests, 4380ms CPU. All listed domain suites passed.
- git -c safe.directory=C:/Users/zach7/.codex/worktrees/main-street/cat-hotel diff --check: exit 0, no whitespace errors (only Git LF-to-CRLF notices).
- EditMode regressions compile and cover all four cardinal facing offsets, independent cart ownership, four wheel transforms, reduced-motion wheel reset, completion/parking and purchase contents, clothing hiding, static front-paw pose, independent NPC movement, zero-time freeze, and application pause/resume. These Unity-dependent tests were NOT executed; compiler checks are not runtime test passes.

## Self-review and remaining gates
Reviewed that carts share one construction, follow the full cat quaternion rather than a world-fixed offset, track distance rather than elapsed time for spinning, preserve static push paws when motion is disabled, and disappear through the Paw Mart parent hierarchy in clothing. Checkout handoff lasts beyond one frame. Miso faces the counter from behind it. No domain reward code or exported geometry changed.

Deferred as explicitly instructed: executing EditMode tests in Unity; runtime phone/desktop captures at 360x640, 390x844, 430x932, 1280x800; visual assessment of manager/NPC pushing, sharp turns, parking, checkout, path clearances, paw/handle alignment and outfit clipping; pause/resume behavior in actual players. No second Unity Editor, player build, or modification to the original checkout was performed. Task 8 still owns interior manager wardrobe rendering; final outfit/handle clipping review must include its outfits. The push handle is authored around the existing scaled front-paw location, but visual correctness is not claimed from compilation alone.
