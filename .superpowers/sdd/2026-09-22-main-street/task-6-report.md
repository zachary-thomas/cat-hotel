# Task 6 report — optional shop offers and authored quests

## Result
Implemented in the isolated codex/main-street checkout. Paw Mart offers the 30-coin Welcome Basket and 80-coin Market Day bundle. Held specials are unique flags exposed through a read-only TownInventory. Purchases require exact funds, charge once, and use the existing transaction/save rollback mechanism. Market Day consumption remains Task 9; once it removes the bundle flag the existing purchase command permits another bundle.

Welcome Picnic requires acceptance and the owned basket. Completion consumes that basket and discovers existing Biscuit (cat 5); if already known, it awards 40 coins instead. Accepted/completed/rewarded flags are separate and completion/reward are committed atomically. Repeated completion fails without rewards, including after reload.

First Look acceptance grants store_ribbon once. The ribbon is a new shared neck item with authored voxel geometry. Completion requires it on the manager. It cannot be bought through BuyWear; both store and care wardrobe UI explain its quest source. Nine paid pieces and three friendship gifts remain. DressManager supports removal and validates shared slots, definitions and ownership, with rollback on failure.

Cashier Quest and Buy panels now show real authored offers, prices, owned state, accepted/completed state and command actions. Paw Mart stock and clothing catalogue remain distinct. Clothing uses existing BuyWear; owned clothes can be equipped on the manager. Hotel care and income have no stock requirement.

## RED / GREEN evidence
- Initial focused test run failed compilation with CS1061 for missing BuyTownItem, TownInventory, AcceptTownQuest, CompleteTownQuest and DressManager, before implementation.
- After initial implementation, the focused run failed at `equipped manager reload`; this exposed both temporary empty-only restrictions in StrictSaveJson and HotelTown. These were replaced with typed outfit fields plus shared wardrobe ownership validation and authored quest-stage validation.
- Added invalid quest cat regression; it failed at `quest cat must exist`, then passed after authored reward bounds validation.
- Final focused command: `dotnet run --project tests/unity-domain --no-restore -- town`: PASS 149 town checks.
- Final full command: `dotnet run --project tests/unity-domain --no-restore`: PASS 676207 checks. Dense 600-second simulation: 209 visits, 18 cleanings, 18 guests.
- Compiler-only `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -v:q`: succeeded, 0 warnings, 0 errors. Initial compiler check revealed missing imported WardrobePanel source in ignored generated project references; refreshed references locally and reran successfully.
- Tests cover exact prices, insufficient funds, duplicate specials, unknown commands, accept-before-complete, missing requirements, discovery and known-cat coin reward, reload idempotency, shared ribbon ownership, strict malformed/duplicate flags, wrong-slot/unowned/non-string manager wear, and purchase/accept/dress/discovery/coin rollback.

## Files
- Added Runtime/Domain/TownCommerce.cs and .meta.
- Added tests/unity-domain/TownCommerceSuites.cs and .meta; registered in test project/Program.
- Updated Domain/HotelModel.cs, HotelTown.cs, HotelValidation.cs, StrictSaveJson.cs, TownContent.cs, HotelWardrobe.cs.
- Updated Resources/Content/MainStreet.json and Wardrobe.json.
- Updated Presentation/HotelTownUI.cs and WardrobePanel.cs.
- Updated domain WardrobeSuites.cs and Unity EditMode WardrobeTests.cs item count to 13.
- HotelState already contains the required manager outfit/town fields, so no new persistence fields were needed.
- Ignored generated Unity project references were refreshed locally for compilation and are not committed.

## Self-review and remaining gates
Checked that commerce mutations all use Transaction, rewards and progression persist together, duplicate held purchases cannot charge again, catalogue gifts cannot be bought, and manager outfits use the same ownership rules as known cats. Strict save validation rejects unknown/duplicate special flags, unknown quest stages, completed-without-accepted, mismatched completed/rewarded flags, quest ribbon without acceptance or acceptance without ribbon, and town commerce flags on non-Meadow hotels. Ordinary hotel systems remain independent of stock.

Manager outfit rendering and live try-on are explicitly coordinated with Task 8. Parent confirmed Task 8 will apply shared CatOutfitView.Apply to both street and interior manager rigs and implement try-on. No visual completion is claimed here. Unity Editor execution, EditMode test execution, actual cashier interaction/reload inspection, and portrait/text-scale visual acceptance are deferred because the original checkout has the active Editor and a second Editor/player build is prohibited. Compiler-only verification does not satisfy those gates.

Market Day must transactionally consume market_bundle from Hotel(0).town.specialFlags (Task 9). This task intentionally provides the held flag and repurchase behavior, without introducing an event lifecycle. New cat discovery enables the existing hotel visitor system; authored visit/reaction presentation remains later event/acceptance work.

## Review fix — refresh the active cashier sheet
Review identified that Model.Changed updates wallet values only. All successful cashier actions now call ReportCashier, which rebuilds the active sheet and then reports the result. This immediately reveals Equip ribbon / Complete after First Look acceptance, changes grocery offers to Owned, reveals clothing Equip actions after purchase, and displays completed quest state. Failure reports leave the current sheet intact. Reporting after rebuilding preserves the notice. The existing storeChoice, active interior/conversation, scroll restoration and Back hierarchy remain in use; no store exit, camera focus or navigation reset is introduced.

Added TownCashierRefreshTests.cs and .meta. Three parameterized cases use actual First Look, grocery and clothing commands and verify the refresh callback sees committed state before the report callback. A failure case verifies no refresh and exactly one report. This is focused presenter callback coverage; actual rendered-button interaction remains a deferred Unity execution gate.

Exact verification commands and output:
- Before adding the helper: `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -v:q` failed with two CS0117 errors: HotelTownUI did not contain RefreshCashier (RED compilation evidence). The temporary unused fixture-field warning was removed.
- After fix: `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -v:q`: `Build succeeded. 0 Warning(s) 0 Error(s)` (1.98 seconds).
- `dotnet run --project tests/unity-domain --no-restore`: `PASS 676207 checks`; dense 600s: 209 visits, 18 cleaned, 18 guests, 4401ms CPU.
- `git -c safe.directory=C:/Users/zach7/.codex/worktrees/main-street/cat-hotel diff --check`: exit 0, no whitespace errors.

Self-review confirmed every cashier mutation callback uses the refresh helper, successful results refresh exactly once, failures preserve the existing sheet, and the notice is emitted after Rebuild. Ignored generated EditMode project references include the new test locally. No second Unity Editor, player build or runtime test execution was started. The compiled regression cases still need Unity execution alongside the previously deferred cashier interaction acceptance gate.
