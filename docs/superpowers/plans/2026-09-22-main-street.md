# Main Street and Shops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a named and appearance-customized cat manager a walkable Meadow Main Street with a town square, separate Paw Mart and clothing stores, cashier conversations, optional quests and purchases, shopping carts, and one square event.

**Architecture:** A pure C# town model owns manager travel, purchases, quests, and event state in the existing version-3 journal save. Unity presentation builds additive voxel street/store art, activates one closed-store interior after arrival, and renders cats/carts from model state. The clothing shop uses the already planned shared wardrobe and its purchase/equip transactions.

**Tech Stack:** Unity 6000.3.24f1 LTS, C# 9, URP, uGUI/TextMeshPro, Input System, Newtonsoft.Json, .NET 9 domain harness, Unity EditMode tests, `tools/unity.ps1`.

**Spec:** [Main Street design](../specs/2026-09-22-main-street-design.md). Also read [art direction](../../art/STYLE-GUIDE.md), [neighborhood behavior reference](../../NEIGHBORHOOD.md), and [wardrobe plan](2026-09-22-hotel-growth-05-wardrobe.md).

## Global Constraints

- Meadow House is the first walkable town. Other hotel destinations retain their current neighborhoods and navigation.
- Both stores are open from the start, have separate buildings/interiors/owners/inventories/quests, and remain opaque from outside.
- The manager can be renamed, choose one of six coats and four marking patterns, and wear owned outfits. The restaurant is outside this plan.
- Store goods and town events are optional. Ordinary hotel income and care never require restocking.
- Reuse wardrobe ownership and `BuyWear`/`Dress` after hotel-growth plan 05 lands. Preserve the three friendship-gift items.
- No Godot runtime or save edits. Do not hand-edit `GodotGeometry.json`; new town art is additive Unity geometry.
- New save fields are optional in version 3, strictly validated when present, and defaulted for older saves. No duplicate charges, quest rewards, or events after reload.
- Preserve the user's existing uncommitted files. The current hotel-growth plan is active; do not reset, cherry-pick, or edit its files concurrently. Do not run two Unity editors/builds at once.
- Maintain 360×640 through 430×932 portrait, 1280×800 landscape, 100/125/150% text, safe areas, reduced motion, keyboard/mouse and touch input.

## File and task map

| Unit | Responsibility | Main files |
| --- | --- | --- |
| Content and routes | One source for street nodes, store entrances, prices, and event locations | `Assets/Resources/Content/MainStreet.json`, `Runtime/Domain/TownContent.cs`, `TownRoute.cs` |
| Durable state | Name, safe position, trip, quests, specials, square event | `Runtime/Domain/HotelTown.cs`, `HotelState.cs`, `StrictSaveJson.cs`, `HotelValidation.cs` |
| Exterior | Plaza and two opaque storefronts; manager appearance, travel and camera | `Runtime/Presentation/MainStreetArt.cs`, `ManagerCatArt.cs`, `VoxelWorldTown.cs`, `VoxelWorldInput.cs` |
| Interior and dialogue | One active interior, cashier target, shop owner, Talk/Quest/Buy/Leave | `Runtime/Presentation/StoreInteriorView.cs`, `HotelTownUI.cs` |
| Paw Mart | Grocery interior, cart actors and poses | `Runtime/Presentation/PawMartArt.cs`, `ShoppingCartRig.cs`, `GodotCatRig.cs` |
| Clothing store | Distinct boutique art; existing wardrobe purchase/try-on | `Runtime/Presentation/ClothingStoreArt.cs`, `HotelTownUI.cs`, wardrobe plan files only if integration requires it |
| Square event | Market Day time/reward and event visuals | `Runtime/Domain/TownEvent.cs`, `Runtime/Presentation/TownSquareArt.cs`, `HotelTownUI.cs` |

Add `.meta` files for every Unity asset/script. The original Godot export remains available as the visual baseline. Task owners must finish and review one dependency before a successor edits shared files. Art tasks may be delegated in parallel only after Task 1 freezes content ids and anchors, and only in separate new art files.

## Dependencies and subagent dispatch

```text
Hotel growth plan 02 (save v3) ─┐
Hotel growth plan 05 (wardrobe) ├─> 1 content/route -> 2 save/name -> 3 travel
                                │                       -> 4 exterior -> 5 interior
                                └───────────────────────────────> 6 commerce -> 7 Paw Mart/carts
                                                                   -> 8 clothing store
                                                                   -> 9 square event -> 10 QA
```

Recommended execution: one fresh subagent per task, with a spec review and code review before the next shared-file task. Give each agent its task, the spec, and the dependency's final interface; use separate worktrees only when the existing user's work will not be lost and the user has chosen that workflow. The UI/scene tasks share one Unity editor gate, so run them serially. Do not start Task 8 until the wardrobe implementation is compiled and its own save tests pass.

### Task 1: Town content and pedestrian routes

**Files:** Create `unity/PurringtonHotel/Assets/Resources/Content/MainStreet.json`, `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/TownContent.cs`, `TownRoute.cs`, `tests/unity-domain/TownSuites.cs`; modify `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelApp.cs`, `tests/unity-domain/Purrington.Domain.Tests.csproj`, `Program.cs`.

**Interfaces:** `TownContent.LoadJson(string json)` returns validated content and installs `TownContent.Current`; `TownContent.Has(string id)`, `IsStreetTarget(string id)`, `NearestStreetTarget(LotPoint point,float radius)`, `Point(string id)`, `Offer(string id)`, `HasCoat(string id)`, and `HasMarkings(string id)` expose records. `TownRoute.Find(TownContent content, LotPoint start, string targetId)` returns street waypoints or an empty list. Content ids: `hotel_gate`, `square`, `paw_mart_door`, `clothing_door`, `paw_mart_cashier`, `clothing_cashier`; the cashier ids are interior-only.

- [ ] **Step 1: Write failing route/content tests.** In `TownSuites.Run`, assert that all six ids exist, both doors connect from `hotel_gate`, every route stays on authored pedestrian links, and an unknown id returns no route.

```csharp
var town=TownContent.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/MainStreet.json"));
Check(town.Has("paw_mart_door")&&town.Has("clothing_door"),"both shop doors authored");
Check(town.HasCoat("honey")&&town.HasCoat("charcoal")&&town.HasMarkings("tabby"),"manager appearance choices");
Check(town.NearestStreetTarget(town.Point("square"),1.25f)=="square","ground taps snap to pedestrian graph");
Check(TownRoute.Find(town,town.Point("hotel_gate"),"square").Count>1,"square reachable");
Check(TownRoute.Find(town,town.Point("hotel_gate"),"unknown").Count==0,"unknown destination rejected");
```

- [ ] **Step 2: Run `dotnet run --project tests/unity-domain`; confirm the new suite fails because the content/route types do not exist.**
- [ ] **Step 3: Add a schema-1 JSON file with node positions and explicit undirected pedestrian links.** Use the current Meadow road at z≈12.5–17.5 and keep the buildable base `[-12,-12,24,24]` untouched. Anchor the square around the east street houses (current decorative homes at x=28,z=-8.5 and x=28,z=29); Task 4 will replace only those two homes. Add six coat ids (`honey`, `cream`, `ginger`, `cocoa`, `gray`, `charcoal`) with style-guide colors and four marking ids (`solid`, `tuxedo`, `tabby`, `patchwork`). Validate duplicate ids, non-finite positions, missing links, and routes through shop footprints. Use Dijkstra over the authored graph; return points in travel order, including the destination. Load `MainStreet.json` in `HotelApp.InitializeProfile` before `Model.LoadOrCreate`, and in the domain runner before loading saves, so strict validation has the content registry available.

```json
{
  "schema": 1,
  "coats": [
    {"id":"honey","color":"#B3824C"},{"id":"cream","color":"#EAD6AF"},
    {"id":"ginger","color":"#C98542"},{"id":"cocoa","color":"#80634E"},
    {"id":"gray","color":"#9C9F9B"},{"id":"charcoal","color":"#4A514E"}
  ],
  "markings": ["solid","tuxedo","tabby","patchwork"],
  "nodes": [
    {"id":"hotel_gate","x":0,"z":12.75,"area":"street"},
    {"id":"east_walk","x":12,"z":17.48,"area":"street"},
    {"id":"square","x":28,"z":18,"area":"street"},
    {"id":"paw_mart_door","x":28,"z":9,"area":"street"},
    {"id":"clothing_door","x":28,"z":24,"area":"street"},
    {"id":"paw_mart_cashier","x":0,"z":3,"area":"paw_mart"},
    {"id":"clothing_cashier","x":0,"z":3,"area":"clothing"}
  ],
  "links": [["hotel_gate","east_walk"],["east_walk","square"],
            ["square","paw_mart_door"],["square","clothing_door"]],
  "stores": [{"id":"paw_mart","door":"paw_mart_door","cashier":"paw_mart_cashier"},
             {"id":"clothing","door":"clothing_door","cashier":"clothing_cashier"}],
  "offers": [],
  "event": {"id":"market_day","anchor":"square","duration":90}
}
```

Task 6 fills `offers` with the two grocery products and adds the two quest records in the same schema. Street coordinates are hotel grid units; cashier coordinates are local store-interior units. `TownContent` rejects links whose endpoints are not both in `area:"street"`.

- [ ] **Step 4: Run the domain suite; expect its final `PASS` line and no route through a decorative house or across the hotel's room wall.** The `hotel_gate` to existing `VisitorEntrance` connector uses `HotelModel.ActivityRoute`; street nodes begin beyond the base edge.
- [ ] **Step 5: Commit the content, domain helpers, and test harness registration as `feat(town): define Meadow pedestrian graph`.**

### Task 2: Manager identity and safe save defaults

**Files:** Create `Runtime/Domain/HotelTown.cs`; modify `Runtime/Domain/HotelState.cs`, `StrictSaveJson.cs`, `HotelValidation.cs`; extend `tests/unity-domain/TownSuites.cs`.

**Interfaces:** `HotelState.managerName`, `managerCoat`, `managerMarkings`, and `managerOutfit : Dictionary<string,string>`; `HotelData.town`. `TownState` holds `x`, `z`, `destination`, `shop`, `questFlags : List<string>`, `specialFlags : List<string>`, and `eventRemaining`; `HotelModel.RenameManager(string name)` and `SetManagerAppearance(string coat,string markings)` return `CommandResult`.

- [ ] **Step 1: Add tests for a fresh name, rename, reload, legacy v3 save without town fields, invalid names, malformed town fields, and a failing save store.**

```csharp
Check(model.State.managerName=="Manager","default manager name");
Check(model.State.managerCoat=="honey"&&model.State.managerMarkings=="solid","default appearance");
Check(model.RenameManager("  Poppy  ").success&&model.State.managerName=="Poppy","trim and rename");
Check(model.SetManagerAppearance("charcoal","tuxedo").success,"change coat and markings");
Check(!model.SetManagerAppearance("purple","solid").success,"unknown coat rejected");
Check(!model.RenameManager("<size=0>hidden</size>").success,"reject markup name");
var oldJson=JObject.Parse(JsonConvert.SerializeObject(model.State));
oldJson.Remove("managerName");oldJson.Remove("managerCoat");oldJson.Remove("managerMarkings");oldJson.Remove("managerOutfit");
foreach(var hotel in oldJson["hotels"])((JObject)hotel).Remove("town");
string legacyV3WithoutTown=oldJson.ToString();
Check(model.RestoreJson(legacyV3WithoutTown),"older version-three save defaults town");
```

- [ ] **Step 2: Run the domain suite and see the rename/default tests fail.**
- [ ] **Step 3: Add optional version-3 fields, initialize Meadow town at the hotel gate, and validate 1–24 visible characters, one of the six coat ids, one of the four marking ids, finite/safe coordinates, known destination/shop/flag ids, and nonnegative finite event time.** `RenameManager` and `SetManagerAppearance` use the existing `Transaction` save/rollback pattern and never change a cat's collection identity. Encode display text through TMP's plain-text path rather than accepting rich-text tags.

```csharp
public CommandResult RenameManager(string name) {
    string clean=(name??"").Trim();
    int count=new System.Globalization.StringInfo(clean).LengthInTextElements;
    if(count<1||count>24||clean.IndexOf('<')>=0||clean.IndexOf('>')>=0)
        return CommandResult.Fail("Choose a name with 1–24 characters.");
    return Transaction(()=>State.managerName=clean,"Manager renamed.");
}
public CommandResult SetManagerAppearance(string coat,string markings) {
    if(!TownContent.Current.HasCoat(coat)||!TownContent.Current.HasMarkings(markings))
        return CommandResult.Fail("Choose a coat and markings.");
    return Transaction(()=>{State.managerCoat=coat;State.managerMarkings=markings;},"Manager look updated.");
}
```

- [ ] **Step 4: Re-run the suite and the existing `JournalSaveIntegrityTests` through `tools/unity.ps1 Test`; confirm old saves and save-write rollback still pass.**
- [ ] **Step 5: Commit as `feat(town): save manager name and town state`.**

### Task 3: Manager travel and trip recovery

**Files:** Modify `Runtime/Domain/HotelTown.cs`, `HotelLife.cs`; extend `tests/unity-domain/TownSuites.cs`.

**Interfaces:** `HotelModel.SendManager(string targetId)`, `HotelModel.SkipManagerTravel()`, `HotelModel.ManagerRoute` (read-only snapshot), `HotelModel.ManagerArrived` event. A ground tap resolves to `TownContent.Current.NearestStreetTarget(point,1.25f)` before calling `SendManager`; travel accepts only street targets and only when Meadow is active.

- [ ] **Step 1: Test tap-to-travel, repeated taps, pause/reload during travel, Skip walk, a blocked hotel exit, non-Meadow rejection, and zero duplicate arrivals.** Simulate `Tick(.2f)` until arrival; assert the saved position is the last safe waypoint and the destination survives reload.

```csharp
Check(model.SendManager("paw_mart_door").success,"start Paw Mart walk");
for(int i=0;i<600&&model.Hotel().town.destination!="";i++)model.Tick(.2f);
Check(model.Hotel().town.shop=="paw_mart","enter only after reaching door");
Check(model.SendManager("unknown").success==false,"reject unknown target");
```

- [ ] **Step 2: Run the domain suite; confirm the travel assertions fail.**
- [ ] **Step 3: Join `ActivityRoute` from the manager's hotel position to `VisitorEntrance` with `TownRoute.Find` outside the lot. Advance distance in the domain `Tick`, commit arrival once, and derive the route again after load or layout revision.** `SkipManagerTravel` uses the same route validation and arrival transition. A blocked route returns `"The way to Main Street is blocked."` and leaves the cat at its last safe position.

```csharp
public CommandResult SendManager(string targetId) {
    if(State.currentHotel!=0||!TownContent.Current.IsStreetTarget(targetId))return CommandResult.Fail("Choose a Meadow destination.");
    var route=BuildManagerRoute(targetId);
    if(route.Count==0)return CommandResult.Fail("The way to Main Street is blocked.");
    return Transaction(()=>Hotel().town.destination=targetId,"On the way to "+targetId+".");
}
```

- [ ] **Step 4: Run the domain suite, including its dense-hotel simulation, and verify the manager neither occupies guest reservations nor breaks actor separation.**
- [ ] **Step 5: Commit as `feat(town): route manager from hotel to Main Street`.**

### Task 4: Exterior voxel art, camera, and destination input

**Files:** Create `Runtime/Presentation/MainStreetArt.cs`, `ManagerCatArt.cs`, `VoxelWorldTown.cs`, `HotelTownUI.cs`, `Tests/EditMode/MainStreetViewTests.cs`; modify `VoxelWorld.cs`, `VoxelWorldInput.cs`, `NeighborhoodView.cs`, `GodotCatRig.cs`, `HotelApp.cs`, `HotelUI.cs`.

**Interfaces:** `VoxelWorld.EnterTownMode()`, `FocusManager()`, `ExitTownMode()`, `StoreSelected(string id)`; `HotelTownUI` exposes Explore/Follow/Skip/Rename and destination buttons. Shop interiors remain inactive in this task.

- [ ] **Step 1: Add EditMode checks that the exterior has two distinct opaque storefront roots, one square, walkable anchors matching Task 1, and no interior renderer enabled.** Test all six coats and four markings on the live rig, verify eyes/ears remain readable and owned outfits attach to the same head/body bindings. Add an input acceptance step: tap a store sign and verify manager travel begins; drag/pinch retains camera control; Back returns to Hotel.

```csharp
Assert.That(world.TownStorefrontCount,Is.EqualTo(2));
Assert.That(world.ActiveStoreInteriorCount,Is.Zero);
var square=TownContent.Current.Point("square");
Assert.That(world.TownSquareBounds.Contains(new Vector3(square.x*VoxelWorld.Unit,0,square.z*VoxelWorld.Unit)),Is.True);
```

- [ ] **Step 2: Run `tools/unity.ps1 Test`; see the new view test fail.**
- [ ] **Step 3: Build street paving and a compact square beside the existing east road, replacing the two decorative east homes noted in Task 1. Create separate grocery and clothing exteriors, signs, doors, two kiosk shells, lamps, benches, event board, and a manager `GodotCatRig`.** `ManagerCatArt` creates one voxel rig recipe with the binding names required by `GodotCatRig`; a new constructor overload accepts that recipe. Coat colors tint fur-only pieces; solid/tuxedo/tabby/patchwork markings are anchored voxel overlays, leaving eyes, nose, and clothes legible. The manager panel previews choices before `SetManagerAppearance` saves them. Keep roofs opaque. Extend camera limits only while Town mode is active; preserve and restore hotel focus/zoom. Scene taps use storefront hit components before ground clicks; a pavement tap resolves through `NearestStreetTarget` and walks there, while taps farther than 1.25 units from a path show `"Tap a Main Street path."` Two-finger pan/pinch still owns camera input.

```csharp
public void EnterTownMode(){townMode=true;townSavedFocus=focus;townSavedZoom=zoom;FocusManager();}
public void ExitTownMode(){townMode=false;focus=townSavedFocus;zoom=townSavedZoom;UpdateCamera();}
```

- [ ] **Step 4: Run EditMode tests and capture 360×640, 390×844, and 1280×800 exterior shots. Check each marking on light and dark coats, shop signs, cat scale, clear paths, room-build input isolation, and the Fit/Follow controls.**
- [ ] **Step 5: Commit as `feat(town): render and explore Meadow Main Street`.**

### Task 5: Hidden interiors and cashier conversation

**Files:** Create `Runtime/Presentation/StoreInteriorView.cs`, `Tests/EditMode/StoreInteriorTests.cs`; modify `VoxelWorldTown.cs`, `HotelTownUI.cs`, `HotelUI.cs`.

**Interfaces:** `StoreInteriorView.Enter(string storeId)`, `Exit()`, `CashierSelected` event. Accepted ids: `paw_mart`, `clothing`. UI choices are `Talk`, `Quest`, `Buy`, `Leave`; shopping effects are added in Tasks 6–8.

- [ ] **Step 1: Test that tapping a closed building shows no interior; arrival at a store door activates only that store's interior; tapping its cashier walks the manager to the counter before opening dialogue; Back closes dialogue then exits to the same door.**

```csharp
Assert.That(interior.IsVisible,Is.False);
interior.Enter("paw_mart");
Assert.That(interior.ActiveStoreId,Is.EqualTo("paw_mart"));
Assert.That(interior.VisibleStoreCount,Is.EqualTo(1));
```

- [ ] **Step 2: Run EditMode tests and verify the visibility/cashier checks fail.**
- [ ] **Step 3: Build a separate small orthographic interior stage for each store, sharing only a `StoreInteriorView` camera/input contract. Do not reveal either interior through the street roof.** The shop owner uses an existing cat rig with a distinct outfit. The manager routes to the cashier along two authored interior waypoints; arrival opens the choice sheet. Talk shows a short, named line; Quest and Buy show panels populated by Task 6; Leave returns to the saved street door.

```csharp
public void Enter(string storeId){
    if(storeId!="paw_mart"&&storeId!="clothing")throw new ArgumentException("Unknown store");
    ActiveStoreId=storeId;
    pawMartRoot.SetActive(storeId=="paw_mart");
    clothingRoot.SetActive(storeId=="clothing");
}
```

- [ ] **Step 4: Run EditMode and pointer acceptance at 100/150% text; verify UI hit testing blocks world taps, store switches never expose the other interior, and exiting restores street camera/input.**
- [ ] **Step 5: Commit as `feat(town): enter closed shops and speak to cashiers`.**

### Task 6: Shop purchases and authored quests

**Depends on:** hotel-growth plan 05 wardrobe domain and content, compiled and green.

**Files:** Create `Runtime/Domain/TownCommerce.cs`, `tests/unity-domain/TownCommerceSuites.cs`; modify `MainStreet.json`, `Assets/Resources/Content/Wardrobe.json`, `Runtime/Domain/HotelTown.cs`, `HotelState.cs`, `StrictSaveJson.cs`, `HotelValidation.cs`, `tests/unity-domain/Purrington.Domain.Tests.csproj`, `Program.cs`, `WardrobeSuites.cs`, `Runtime/Presentation/HotelTownUI.cs`.

**Interfaces:** `HotelModel.BuyTownItem(string id)`, `AcceptTownQuest(string id)`, `CompleteTownQuest(string id)`, `DressManager(string slot,string id)`, `TownInventory` read-only. Ids: `welcome_basket` (30 coins), `market_bundle` (80 coins), `welcome_picnic`, `first_look`. Quest flags distinguish accepted/completed/rewarded. Accepting First Look grants the free ribbon once; completion requires it equipped on the manager.

- [ ] **Step 1: Test each price, insufficient coins, repeated purchase, one-time quest reward, existing Biscuit discovery, corrupt flags, and save failure rollback.** In the first quest, the Welcome Basket invites Biscuit (cat id 5). If already known, the first completion awards 40 coins instead; repeat completion awards nothing.

```csharp
double before=model.State.coins;
Check(model.BuyTownItem("welcome_basket").success,"buy optional basket");
Check(model.State.coins==before-30,"basket price once");
Check(model.AcceptTownQuest("welcome_picnic").success,"accept grocery quest");
Check(model.CompleteTownQuest("welcome_picnic").success&&model.State.cats[5].known,"Biscuit invited once");
Check(!model.CompleteTownQuest("welcome_picnic").success,"quest reward cannot repeat");
Check(model.AcceptTownQuest("first_look").success&&model.OwnsWear("store_ribbon"),"free ribbon granted once");
Check(model.DressManager("neck","store_ribbon").success,"manager wears ribbon");
Check(model.CompleteTownQuest("first_look").success,"outfit quest completes once");
```

- [ ] **Step 2: Run the domain suite; confirm failures are from missing commerce methods.**
- [ ] **Step 3: Define stock and quest records in `MainStreet.json`; purchase through a single transaction that checks ownership, coins, and save status before changing the state.** Store a special as an owned flag, not a recurring required stock counter. Reject a second purchase while a bundle is held; Market Day consumes its bundle, after which it can be bought again. Do not make the basket quest mandatory for hotel level or passive income. Add the `store_ribbon` neck recipe to the shared Wardrobe JSON and extend its domain tests. Accepting First Look grants that item once; `DressManager` checks shared ownership, slot, and save rollback; completing the quest checks the manager's equipped ribbon.

```csharp
public CommandResult BuyTownItem(string id){
    var offer=TownContent.Current.Offer(id);
    if(offer==null)return CommandResult.Fail("That item is not sold here.");
    if(Hotel().town.specialFlags.Contains(id))return CommandResult.Fail("That special is already ready.");
    if(State.coins<offer.price)return CommandResult.Fail("Not enough Cat Coins.");
    return Transaction(()=>{State.coins-=offer.price;Hotel().town.specialFlags.Add(id);},offer.name+" is ready.");
}
```

- [ ] **Step 4: Run the complete domain suite and Unity EditMode tests. Inspect the cashier sheet for visible price, ownership, quest state, and exactly one charge/reward after reload.**
- [ ] **Step 5: Commit as `feat(town): add optional shop offers and quests`.**

### Task 7: Paw Mart voxel interior and pushable carts

**Files:** Create `Runtime/Presentation/PawMartArt.cs`, `ShoppingCartRig.cs`, `Tests/EditMode/ShoppingCartTests.cs`; modify `StoreInteriorView.cs`, `GodotCatRig.cs`, `HotelTownUI.cs`.

**Interfaces:** `ShoppingCartRig.SetPose(Vector3 catPosition, Quaternion facing, float travelDistance, bool reducedMotion)`; new rig action `push_cart`; Paw Mart owner and two NPC shoppers use distinct rigs.

- [ ] **Step 1: Test that the manager and at least one NPC shopper can each own one cart, wheel rotation tracks travel only with motion enabled, the cart remains in front of paws through turns, and no cart remains visible in the clothing store.**

```csharp
cart.SetPose(catPosition,catFacing,2f,false);
Assert.That(cart.FrontOffset,Is.GreaterThan(0f));
Assert.That(cart.WheelAngle,Is.Not.EqualTo(0f));
cart.SetPose(catPosition,catFacing,2f,true);
Assert.That(cart.WheelAngle,Is.EqualTo(0f));
```

- [ ] **Step 2: Run EditMode tests and see cart/pose checks fail.**
- [ ] **Step 3: Author grocery shelves, produce bins, chilled cabinet, basket stacks, checkout, three readable product groups, and one cart mesh reused by manager/NPCs.** Cart is a rig-following prop with body, handle, four wheels, and swappable basket contents. Add a front-paw `push_cart` pose to `GodotCatRig`; use authored path loops for two shoppers. The manager's cart routine runs after Buy, without requiring aisle taps. Paused/reduced-motion modes show the purchase result and position without bobbing/spinning.

```csharp
case "push_cart":
    Rot(legs[1],-.6f);
    Rot(legs[3],-.6f);
    Rot(head,0,0,S(phase*1.2f)*.04f);
    break;
```

- [ ] **Step 4: Run Unity tests and capture manager/NPC cart pushing, turn, parking, and checkout at phone/desktop sizes. Confirm clothes do not clip the cart handle.**
- [ ] **Step 5: Commit as `feat(town): build Paw Mart and animate shopping carts`.**

### Task 8: Separate clothing store and shared wardrobe

**Depends on:** hotel-growth plan 05 wardrobe implementation compiled and green.

**Files:** Create `Runtime/Presentation/ClothingStoreArt.cs`, `Tests/EditMode/ClothingStoreTests.cs`; modify `StoreInteriorView.cs`, `HotelTownUI.cs`, wardrobe `Assets/Resources/Content/Wardrobe.json`, and its domain tests. Add `.meta` files.

**Interfaces:** Clothing Buy delegates to `HotelModel.BuyWear(id)`; try-on is presentation-only until `Dress(catId,slot,id)` or `DressManager(slot,id)` succeeds. Task 6 provides `DressManager` and the free quest ribbon; all other initial items are the planned wardrobe stock/gifts.

- [ ] **Step 1: Test a distinct clothing interior and owner; preview without charge; buy an item once; equip manager and known cats; complete First Look once; reject buying friendship gifts.**

```csharp
var coins=model.State.coins;
CatOutfitView.Apply(geometry,managerRig,new Dictionary<string,string>{{"head","sun_hat"}});
Assert.That(model.State.coins,Is.EqualTo(coins));
Assert.That(model.BuyWear("sun_hat").success,Is.True);
Assert.That(model.BuyWear("tiny_crown").success,Is.False);
Assert.That(model.DressManager("head","sun_hat").success,Is.True);
```

- [ ] **Step 2: Run Unity and domain wardrobe tests; see the new store assertions fail.**
- [ ] **Step 3: Build the boutique's racks, mirror, fitting platform, counter, folded stacks, mannequins, and unique owner. Wire Buy to the existing wardrobe transaction and Try On to temporary `CatOutfitView` pieces.** Task 6 provides the ribbon and `DressManager` transaction. Manager uses the same head/neck/back bindings as guest cats; outfit remains visible on Main Street and in shops. After equipping the ribbon, invoke `CompleteTownQuest("first_look")` once.

```csharp
void BuyClothing(string wearId){
    var result=app.Model.BuyWear(wearId);
    app.Report(result);
    if(result.success)Rebuild();
}
```

- [ ] **Step 4: Run the wardrobe/domain and Unity suites. Capture try-on, equipped manager roaming, a guest wearing an owned item, and a reload with both outfits retained.**
- [ ] **Step 5: Commit as `feat(town): open separate clothing store and try-on`.**

### Task 9: Market Day in the square

**Files:** Create `Runtime/Domain/TownEvent.cs`, `Runtime/Presentation/TownSquareArt.cs`, `tests/unity-domain/TownEventSuites.cs`, `Tests/EditMode/MarketDayViewTests.cs`; modify `Runtime/Domain/HotelLife.cs`, `HotelTownUI.cs`, `VoxelWorldTown.cs`, `MainStreet.json`, domain test project and runner.

**Interfaces:** `HotelModel.StartMarketDay()` consumes one owned `market_bundle`, sets 90 seconds active time; `MarketDayRemaining` reports time; completion emits one hotel arrival/reaction token. No real-time event window or income penalty.

- [ ] **Step 1: Test no-bundle rejection, duplicate-start rejection, 90-second active-time duration, pause/reload continuation, one-time completion reaction, and continued ordinary hotel rate.**

```csharp
Check(!model.StartMarketDay().success,"bundle required");
Check(model.BuyTownItem("market_bundle").success,"bundle bought");
Check(model.StartMarketDay().success,"event starts once");
Check(Math.Abs(model.MarketDayRemaining-90)<.01,"full event duration");
```

- [ ] **Step 2: Run the new domain and EditMode tests; verify event APIs and art are missing.**
- [ ] **Step 3: Advance only active game time in `Tick`; persist remaining time and completion token, with idempotent arrival/reaction.** Render two kiosks, temporary market awnings, signs, shoppers, lights, and cat conversations in the square. Use the same space as a quiet plaza when inactive. The event board shows ready/running/completed states and a readable countdown; no surprise restart on reload.

```csharp
public CommandResult StartMarketDay(){
    if(!Hotel().town.specialFlags.Contains("market_bundle"))return CommandResult.Fail("Get a Market Day bundle at Paw Mart.");
    if(Hotel().town.eventRemaining>0)return CommandResult.Fail("Market Day is already happening.");
    return Transaction(()=>{Hotel().town.specialFlags.Remove("market_bundle");Hotel().town.eventRemaining=90;},"Market Day has begun!");
}
```

- [ ] **Step 4: Run the full domain and Unity suites; capture quiet/running/ended square at portrait and landscape sizes, with reduced motion.**
- [ ] **Step 5: Commit as `feat(town): host optional Market Day in the square`.**

### Task 10: End-to-end acceptance, asset pass, and documentation

**Files:** Modify `unity/PurringtonHotel/README.md`, `docs/unity-migration/QA.md`; create `docs/art/qa-shots/main-street/README.md` and selected captures. Fix defects only in files owned by the failing feature task.

- [ ] **Step 1: Run `dotnet run --project tests/unity-domain`, `tools/unity.ps1 Test`, `tools/unity.ps1 Windows`, and `tools/unity.ps1 QA` once on the integrated result. Record exact counts and failures.**
- [ ] **Step 2: Walk the real input path on fresh and legacy saves: rename manager → tap square → enter Paw Mart → push cart/buy basket → talk/quest → leave → enter clothing store → try/buy/equip → start Market Day → save/reload → return to hotel.** At every spend or reward, test a blocked save and confirm no lost coins or duplicate progress.
- [ ] **Step 3: Inspect screenshots at 360×640, 390×844, 430×932, 1280×800 and 100/150% text. Compare storefronts, cats, clothes, and carts to `docs/art/STYLE-GUIDE.md`; verify opaque exteriors and visible cashier choices.** Use a physical phone for release sign-off when a device/build is available; do not claim it from Windows captures.
- [ ] **Step 4: Update the README and QA checklist with controls, available stores, optional quests/events, current platform limits, and the actual test results. Keep generated builds untracked and retain source `.meta` files.**
- [ ] **Step 5: Commit QA/docs as `docs(town): record Main Street controls and acceptance`. Request a final spec/code review of the integrated diff before PR or merge.**

## Self-review and completion criteria

The plan covers every spec requirement: rename, six coats, four markings and outfit, Meadow street/square, two opaque and separately enterable stores, cashier dialogue, quests/buys, Paw Mart carts, clothing try-on, optional cat attraction, Market Day, save recovery, responsive UI, and new voxel assets/animations. The restaurant and other destinations are deliberately later phases. Execution is complete only when both shops and the square work end to end, tests pass, and the recorded Windows/device limits are accurate.
