# Floors, Stairs and Themed Floors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the hotel grow upward and downward. Stairwells open an upper floor (hotel level 3), a rooftop (level 5) and a basement (level 7). Each floor has its own room kinds (Sunroom upstairs, Garden on the roof, Spa below). Cats path between floors, guests use upstairs bedrooms, and the player views and builds one floor at a time.

**Architecture:** Floors reuse plan 02's `FloorState` per level. Upper cells must stand on indoor cells below, and basement cells under ground cells. A `stairs` room (exactly 2×3) on floor L opens a landing on L+1 and links L and L+1 in navigation. Navigation becomes 3D: `LotPoint` gains `floor`, nav keys include the floor, solids are per floor, and each floor apart counts as 100 units of distance, so the existing A* and "nearest point" logic keep working unchanged. Venues, slots and actors carry their floor. Presentation stacks floors `FloorHeight` apart and hides floors above the viewed one.

**Tech Stack:** C# 9, the .NET 9 domain harness, Unity 6000.3 URP, uGUI.

**Spec:** [hotel-growth design](../specs/2026-09-22-hotel-growth-design.md): "Floors". **Depends on:** plans 02 and 03 merged.

---

## Conventions

- Domain tests: `dotnet run --project tests/unity-domain` (the final line is `PASS <n> checks`). Unity: `.\tools\unity.ps1 Test` (exit 0).
- Domain edits are listed as exact **replace → with** pairs against the code as it stands after plans 02 and 03. Each "replace" string must match the stated number of times. If it doesn't, stop and report: an earlier plan has drifted.
- `…/Domain/` is `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/`.
- Floor levels: `-1` basement, `0` ground, `1` upstairs, `2` rooftop.

## Rules implemented here

| Rule | Where |
|---|---|
| Unlocks: upstairs at hotel level 3, rooftop at 5, basement at 7 (God mode ignores them) | `FloorGate`, public `FloorLock` |
| Upper cells need an indoor cell below; basement cells need a ground cell above; only ground cells need owned land | `PaintCells`, `ValidateShell` |
| Floors open only through stairs: painting a floor with no cells is refused; the first basement stairs are allowed | `ApplyShell`, `draw_room` |
| Stairs are exactly 2×3, cost the fitting plus the landing tiles, and keep their stairs and landing clear | `RoomShape`, `OpenLanding`, `ValidateShell` |
| Room kinds per floor: ground regular/suite/lounge/stairs; upstairs adds sunroom; rooftop garden only; basement spa/lounge/stairs | `AllowedKind`, `KindHint` |
| The rooftop and garden rooms count as outdoor surfaces (planters, benches) | `IndoorAt`, `ValidateLayout` |
| Themed rooms are ready with any reachable activity and add +15 / +20 / +25 coins/min (one of each kind counts) | `ComputeRoomStatus`, `Rate` |
| Erasing is refused under an upper floor, over a basement, or on a stair landing | `EraseCells` |

## Files

- Modify (domain): `HotelShell.cs`, `HotelModel.cs`, `HotelNavigation.cs`, `HotelState.cs`, `HotelLife.cs`, `HotelVisitors.cs`
- Modify: `tests/unity-domain/ShellSuites.cs`, `tests/unity-domain/Program.cs`
- Modify (presentation): `VoxelWorldShell.cs`, `VoxelWorld.cs`, `VoxelWorldRooms.cs`, `VoxelWorldPreview.cs`, `HotelShellUI.cs`, `HotelUI.cs`, `HotelParityUI.cs`, `Tests/EditMode/ShellPresentationTests.cs`

---

### Task 1: Floor rules and stairwells (domain)

**Files:** `HotelShell.cs`, `HotelModel.cs`, `HotelNavigation.cs`, `tests/unity-domain/ShellSuites.cs`, `tests/unity-domain/Program.cs`

- [x] **Step 1: Write the failing test**

Append to `ShellSuites`:

```csharp
	public static JObject PaintOn(int level,int x,int z,int w,int d){var p=Paint(x,z,w,d);p["floor"]=level;return p;}
	public static JObject RoomOn(int level,int x,int z,int w,int d,int rotation,string kind="regular"){var p=Room(x,z,w,d,rotation,kind);p["floor"]=level;return p;}
	public static JObject Furnish(string item,int level,float x,float z,int rotation=0){return new JObject{{"item",item},{"x",x},{"y",z},{"rotation",rotation},{"floor",level}};}
	public static void RunFloors(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;var lot=m.Hotel();lot.rooms.Clear();lot.floors.Clear();lot.objects.Clear();lot.paths.Clear();
		Check(FindClear(m,10,8,out int x,out int z),"floors: clear land");
		Check(m.Execute("paint_floor",Paint(x,z,8,7)).success,"floors: ground floor island");
		Check(m.Execute("set_edge",EdgePayload("door","v:"+x+","+(z+3))).success,"floors: front door");
		var stairs=RoomOn(0,x+1,z+1,2,3,0,"stairs");
		var early=m.Quote("draw_room",stairs);Check(!early.success&&early.message.Contains("level 3"),"floors: upstairs opens at hotel level 3 ("+early.message+")");
		m.Hotel().level=3;
		Check(m.FloorLock(1)==null&&m.FloorLock(2).Contains("level 5"),"floors: FloorLock explains locked floors for the UI");
		Check(!m.Quote("paint_floor",PaintOn(1,x+4,z,1,1)).success,"floors: no painting upstairs before a stairwell");
		double coins=m.State.coins;var built=m.Execute("draw_room",stairs);Check(built.success,"floors: stairs built ("+built.message+")");
		Check(HotelModel.Floor(m.Hotel(),1)?.cells.Count==6,"floors: stairs open a 2x3 landing upstairs");
		Check(Math.Abs(coins-m.State.coins-188)<.01,"floors: stairs cost 68 fitting + 120 landing ("+(coins-m.State.coins)+")");
		var off=m.Quote("paint_floor",PaintOn(1,x+9,z,1,1));Check(!off.success&&off.message.Contains("underneath"),"floors: upstairs needs floor underneath ("+off.message+")");
		Check(m.Execute("paint_floor",PaintOn(1,x+3,z,5,4)).success,"floors: grow upstairs over the ground floor");
		var above=m.Quote("erase_floor",Paint(x+4,z+1,1,1));Check(!above.success&&above.message.Contains("above"),"floors: can't erase ground under upstairs ("+above.message+")");
		var landing=m.Quote("erase_floor",PaintOn(1,x+1,z+1,1,1));Check(!landing.success&&landing.message.Contains("stairs"),"floors: can't erase the landing ("+landing.message+")");
		var draft=m.RoomDraft(x+4,z,x+7,z+2,"regular",1);Check((int)draft["door"]==1,"floors: upstairs bedroom opens onto the landing hall");
		Check(m.Execute("draw_room",draft).success,"floors: bedroom upstairs");var room=m.Hotel().rooms.Last();
		Check(room.floor==1&&HotelModel.Interior(m.Hotel(),room),"floors: upstairs bedroom is interior");
		var garden=m.Quote("draw_room",RoomOn(1,x+3,z+3,3,3,0,"garden"));Check(!garden.success&&garden.message.Contains("Upstairs holds"),"floors: gardens belong on the roof ("+garden.message+")");
		var roof=m.Quote("draw_room",RoomOn(1,x+3,z,2,3,0,"stairs"));Check(!roof.success&&roof.message.Contains("level 5"),"floors: the rooftop opens at hotel level 5 ("+roof.message+")");
		Check(!m.Quote("draw_room",RoomOn(0,x+4,z+4,3,3,0,"spa")).success,"floors: no spas on the ground floor");
		m.Hotel().level=7;
		var down=m.Execute("draw_room",RoomOn(-1,x+5,z+4,2,3,0,"stairs"));Check(down.success,"floors: basement stairs open the basement ("+down.message+")");
		Check(HotelModel.Floor(m.Hotel(),-1)?.cells.Count==6,"floors: the basement starts under its stairs");
		var outside=m.Quote("paint_floor",PaintOn(-1,x+9,z,1,1));Check(!outside.success&&outside.message.Contains("under the hotel"),"floors: the basement stays under the hotel");
		Console.WriteLine("Shell floors suite passed");
	}
```

Register it in `Program.cs` after `ShellSuites.RunDraw(Check,P,content);`:

```csharp
ShellSuites.RunFloors(Check,P,content);
```

- [x] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `'HotelModel' does not contain a definition for 'FloorLock'`.

- [x] **Step 3: Apply the edits**

**1. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
int level=(int?)p["floor"]??0;if(level!=0)return CommandResult.Fail("Upper floors open with a stairwell.");
```

with:

```csharp
int level=(int?)p["floor"]??0;var gate=FloorGate(h,level);if(gate!=null)return CommandResult.Fail(gate);if(action=="paint_floor"&&level!=0&&(Floor(h,level)?.cells.Count??0)==0)return CommandResult.Fail("Place a stairwell to open this floor.");
```

**2. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(!Owned(x+.5f,z+.5f,State.currentHotel)){
```

with:

```csharp
if(level!=0){if(!ShellGrid.Indoor(Floor(h,level>0?level-1:0),key))return CommandResult.Fail(level>0?"Upper floors need hotel floor underneath.":"The basement stays under the hotel.");}else if(!Owned(x+.5f,z+.5f,State.currentHotel)){
```

**3. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(h.paths.TryGetValue(key,out var path)){
```

with:

```csharp
if(level==0&&h.paths.TryGetValue(key,out var path)){
```

**4. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(h.rooms.Any(r=>r.floor==level&&Rect(r).Has(x+.5f,z+.5f)))return CommandResult.Fail("Remove the room here first.");
```

with:

```csharp
if(h.rooms.Any(r=>r.floor==level&&Rect(r).Has(x+.5f,z+.5f)))return CommandResult.Fail("Remove the room here first.");if(level>=0&&ShellGrid.Indoor(Floor(h,level+1),key))return CommandResult.Fail("Remove the floor above first.");if(level==0&&ShellGrid.Indoor(Floor(h,-1),key))return CommandResult.Fail("Remove the basement below first.");if(h.rooms.Any(r=>r.kind=="stairs"&&r.floor==level-1&&Rect(r).Has(x+.5f,z+.5f)))return CommandResult.Fail("Remove the stairs here first.");
```

**5. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
!levels.Add(f.level)||f.level!=0)
```

with:

```csharp
!levels.Add(f.level)||f.level<-1||f.level>2)
```

**6. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(!Owned(x+.5f,z+.5f,index))return CommandResult.Fail("Grow the hotel on land you own.");
```

with:

```csharp
if(f.level!=0){if(!ShellGrid.Indoor(Floor(h,f.level>0?f.level-1:0),c.Key))return CommandResult.Fail(f.level>0?"Upper floors need hotel floor underneath.":"The basement stays under the hotel.");continue;}if(!Owned(x+.5f,z+.5f,index))return CommandResult.Fail("Grow the hotel on land you own.");
```

**7. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(inside==0){if(r.floor!=0)return CommandResult.Fail("Upper-floor rooms need floor under them.");continue;}if(inside!=w*d||!IndoorKind(r.kind))
```

with:

```csharp
if(inside==0){if(r.floor!=0)return CommandResult.Fail("Upper-floor rooms need floor under them.");if(r.kind=="stairs"||Themed(r.kind))return CommandResult.Fail("Draw this room inside the hotel.");continue;}if(!AllowedKind(r.floor,r.kind))return CommandResult.Fail(KindHint(r.floor));if(inside!=w*d||!IndoorKind(r.kind))
```

**8. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
public static bool IndoorKind(string kind){return kind=="regular"||kind=="suite"||kind=="shared";}
```

with:

```csharp
public static bool IndoorKind(string kind){return kind=="regular"||kind=="suite"||kind=="shared"||kind=="stairs"||Themed(kind);}
 public static bool Themed(string kind){return kind=="sunroom"||kind=="garden"||kind=="spa";}
 static bool AllowedKind(int level,string kind){switch(level){case 0:return kind=="regular"||kind=="suite"||kind=="shared"||kind=="stairs";case 1:return kind=="regular"||kind=="suite"||kind=="shared"||kind=="sunroom"||kind=="stairs";case 2:return kind=="garden";case -1:return kind=="spa"||kind=="shared"||kind=="stairs";default:return false;}}
 static string KindHint(int level){return level==1?"Upstairs holds bedrooms, suites, lounges and sunrooms.":level==2?"The rooftop is for gardens.":level==-1?"The basement holds spas and lounges.":"Sunrooms, gardens and spas belong on their own floors.";}
 string FloorGate(HotelData h,int level){if(level<-1||level>2)return "Choose a hotel floor.";if(level==0||State.settings.godMode)return null;int need=level==1?3:level==2?5:7;return h.level>=need?null:(level==1?"The upper floor":level==2?"The rooftop":"The basement")+" opens at hotel level "+need+".";}
 CommandResult OpenLanding(HotelData h,RoomState r){var gate=FloorGate(h,r.floor+1);if(gate!=null)return CommandResult.Fail(gate);var up=Floor(h,r.floor+1,true);RoomCells(r,out int x,out int z,out int w,out int d);double cost=0;foreach(var c in ShellGrid.Cells(x,z,w,d))if(!up.cells.ContainsKey(c)){double price=Price(ShellGrid.CellPrice);up.cells[c]=price;cost+=price;}return CommandResult.Ok("Stairs lead up",cost);}
```

**9. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
new[]{"regular","suite","shared","terrace"}.Contains(r.kind)
```

with:

```csharp
new[]{"regular","suite","shared","terrace","stairs","sunroom","garden","spa"}.Contains(r.kind)&&(r.kind!="stairs"||r.width==2&&r.depth==3)&&(!Themed(r.kind)||r.width>=3&&r.depth>=3)
```

**10. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(h.rooms.Any(b=>b!=r&&Rect(b).Intersects(Rect(r))))
```

with:

```csharp
if(h.rooms.Any(b=>b!=r&&b.floor==r.floor&&Rect(b).Intersects(Rect(r))))
```

**11. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
var room=h.rooms.Find(r=>Rect(r).Encloses(b));if(h.rooms.Any(r=>r!=room&&Rect(r).Intersects(b)))
```

with:

```csharp
var room=h.rooms.Find(r=>r.floor==o.floor&&Rect(r).Encloses(b));if(h.rooms.Any(r=>r!=room&&r.floor==o.floor&&Rect(r).Intersects(b)))
```

**12. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
h.objects.Any(other=>other!=o&&Catalog.Find(other.itemId)?.shape!="rug"&&
```

with:

```csharp
h.objects.Any(other=>other!=o&&other.floor==o.floor&&Catalog.Find(other.itemId)?.shape!="rug"&&
```

**13. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
room!=null&&room.kind!="terrace"||IndoorAt(h,o.floor,b)
```

with:

```csharp
room!=null&&room.kind!="terrace"&&room.kind!="garden"||IndoorAt(h,o.floor,b)
```

**14. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
static bool IndoorAt(HotelData h,int level,LotRect b){return ShellGrid.Indoor(
```

with:

```csharp
static bool IndoorAt(HotelData h,int level,LotRect b){return level!=2&&ShellGrid.Indoor(
```

**15. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
r.paid=cost=Price(Interior(h,r)?Fitting(r):Shell(r));h.rooms.Add(r);break;
```

with:

```csharp
r.paid=cost=Price(Interior(h,r)?Fitting(r):Shell(r));h.rooms.Add(r);if(r.kind=="stairs"){var landing=OpenLanding(h,r);if(!landing.success)return landing;cost+=landing.cost;}break;
```

**16. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
case "draw_room":{int level=(int?)p["floor"]??0;
```

with:

```csharp
case "draw_room":{int level=(int?)p["floor"]??0;var gate=FloorGate(h,level);if(gate!=null)return CommandResult.Fail(gate);if(level!=0&&!(level==-1&&(string)p["kind"]=="stairs")&&(Floor(h,level)?.cells.Count??0)==0)return CommandResult.Fail("Place a stairwell to open this floor.");
```

**17. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
  foreach(var o in h.objects){var f=Floor(h,o.floor);var b=Rect(o);int inside=0
```

with:

```csharp
  foreach(var s in h.rooms.Where(v=>v.kind=="stairs")){RoomCells(s,out int sx,out int sz,out int sw,out int sd);var up=Floor(h,s.floor+1);if(ShellGrid.Cells(sx,sz,sw,sd).Any(c=>!ShellGrid.Indoor(up,c)))return CommandResult.Fail("Stairs need floor at the top.");var land=new LotRect(sx,sz,sw,sd);if(h.rooms.Any(r=>r.floor==s.floor+1&&Rect(r).Intersects(land))||h.objects.Any(o=>(o.floor==s.floor||o.floor==s.floor+1)&&Rect(o).Intersects(land)))return CommandResult.Fail("Keep the stairs and landing clear.");}
  foreach(var o in h.objects){var f=Floor(h,o.floor);var b=Rect(o);int inside=0
```

**18. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(r==null)return new RoomStatusInfo{status="Missing room",message="This room was removed."};
```

with:

```csharp
if(r==null)return new RoomStatusInfo{status="Missing room",message="This room was removed."};if(r.kind=="stairs")return new RoomStatusInfo{ready=true,status="Stairs",message="Cats can go between floors."};
```

**19. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
o=new ObjectState{id=Id("object"),itemId=item.id,paid=cost};
```

with:

```csharp
o=new ObjectState{id=Id("object"),itemId=item.id,paid=cost,floor=(int?)p["floor"]??0};
```

**20. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
o.x=(float)p["x"];o.z=(float)p["y"];o.rotation=(int?)p["rotation"]??0;
```

with:

```csharp
o.x=(float)p["x"];o.z=(float)p["y"];o.rotation=(int?)p["rotation"]??0;o.floor=(int?)p["floor"]??o.floor;
```

**21. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
depth=(int)template["h"],rotation=(int?)p["rotation"]??0};
```

with:

```csharp
depth=(int)template["h"],rotation=(int?)p["rotation"]??0,floor=(int?)p["floor"]??0};
```

**22. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
o.id=Id("object");o.room=r.id;
```

with:

```csharp
o.id=Id("object");o.room=r.id;o.floor=r.floor;
```

**23. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
 CommandResult OpenLanding(HotelData h,RoomState r){
```

with:

```csharp
 public string FloorLock(int level){return FloorGate(Hotel(),level);}
 CommandResult OpenLanding(HotelData h,RoomState r){
```

**24. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
public CommandResult PreviewObject(string item,float x,float z,int rotation=0){return Quote("place_object",P("item",item,"x",x,"y",z,"rotation",rotation));}public CommandResult PlaceObject(string item,float x,float z,int rotation=0){return Execute("place_object",P("item",item,"x",x,"y",z,"rotation",rotation));}
```

with:

```csharp
public CommandResult PreviewObject(string item,float x,float z,int rotation=0,int floor=0){return Quote("place_object",P("item",item,"x",x,"y",z,"rotation",rotation,"floor",floor));}public CommandResult PlaceObject(string item,float x,float z,int rotation=0,int floor=0){return Execute("place_object",P("item",item,"x",x,"y",z,"rotation",rotation,"floor",floor));}
```

**25. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
public CommandResult PreviewMoveObject(string id,float x,float z,int rotation=0){return Quote("move_object",P("id",id,"x",x,"y",z,"rotation",rotation));}public CommandResult MoveObject(string id,float x,float z,int rotation=0){return Execute("move_object",P("id",id,"x",x,"y",z,"rotation",rotation));}
```

with:

```csharp
public CommandResult PreviewMoveObject(string id,float x,float z,int rotation=0,int? floor=null){var p=P("id",id,"x",x,"y",z,"rotation",rotation);if(floor!=null)p["floor"]=floor;return Quote("move_object",p);}public CommandResult MoveObject(string id,float x,float z,int rotation=0,int? floor=null){var p=P("id",id,"x",x,"y",z,"rotation",rotation);if(floor!=null)p["floor"]=floor;return Execute("move_object",p);}
```

**26. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
public CommandResult PreviewRetrieveObject(string id,float x,float z,int rotation=0){return Quote("retrieve_object",P("id",id,"x",x,"y",z,"rotation",rotation));}public CommandResult RetrieveObject(string id,float x,float z,int rotation=0){return Execute("retrieve_object",P("id",id,"x",x,"y",z,"rotation",rotation));}
```

with:

```csharp
public CommandResult PreviewRetrieveObject(string id,float x,float z,int rotation=0,int floor=0){return Quote("retrieve_object",P("id",id,"x",x,"y",z,"rotation",rotation,"floor",floor));}public CommandResult RetrieveObject(string id,float x,float z,int rotation=0,int floor=0){return Execute("retrieve_object",P("id",id,"x",x,"y",z,"rotation",rotation,"floor",floor));}
```

- [x] **Step 4: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Shell floors suite passed` and `PASS <n> checks` (it was 676063 during planning).

- [x] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): upper floors, rooftop and basement with stairwells"
```

---

### Task 2: 3D navigation (domain)

**Files:** `HotelState.cs`, `HotelNavigation.cs`, `tests/unity-domain/ShellSuites.cs`

- [ ] **Step 1: Write the failing test**

In `RunFloors`, insert these three lines directly before the line containing `"floors: no spas on the ground floor"`:

```csharp
		var path=m.Route(new LotPoint(x-1.5f,z+3.5f),new LotPoint(x+5.5f,z+1.5f,1),false);
		Check(path.Count>0&&path[0].floor==0&&path[path.Count-1].floor==1,"floors: cats reach the upstairs bedroom");
		Check(path.Any(p=>p.floor==1&&p.x<x+3),"floors: the route climbs the stairwell");
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `'LotPoint' does not contain a constructor that takes 3 arguments`.

- [ ] **Step 3: Apply the edits**

**1. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public struct LotPoint {public float x,z;public LotPoint(float x,float z){this.x=x;this.z=z;}public float Distance(LotPoint b){return (float)Math.Sqrt((x-b.x)*(x-b.x)+(z-b.z)*(z-b.z));}}
```

with:

```csharp
public struct LotPoint {public float x,z;public int floor;public LotPoint(float x,float z){this.x=x;this.z=z;floor=0;}public LotPoint(float x,float z,int floor){this.x=x;this.z=z;this.floor=floor;}
 // Each floor apart counts as 100 units, so points on other floors never look close and a stair link costs 100.
 public float Distance(LotPoint b){return (float)Math.Sqrt((x-b.x)*(x-b.x)+(z-b.z)*(z-b.z))+Math.Abs(floor-b.floor)*100;}}
```

**2. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
class VenueSlot {public string key,action;public float x,z,facing;}
```

with:

```csharp
class VenueSlot {public string key,action;public float x,z,facing;public int floor;public LotPoint Point=>new LotPoint(x,z,floor);}
```

**3. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public float x,z;public string[] tags;
```

with:

```csharp
public float x,z;public int floor;public LotPoint Point=>new LotPoint(x,z,floor);public string[] tags;
```

**4. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
public List<LotRect> solids=new List<LotRect>();
```

with:

```csharp
public Dictionary<int,List<LotRect>> solids=new Dictionary<int,List<LotRect>>();public List<LotRect> Solids(int floor){if(!solids.TryGetValue(floor,out var list))solids[floor]=list=new List<LotRect>();return list;}
```

**5. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
static long Key(int x,int z){return ((long)x<<32)|(uint)z;}static long Key(LotPoint p){return Key((int)Math.Floor(p.x*2),(int)Math.Floor(p.z*2));}
```

with:

```csharp
static long Key(int x,int z,int floor=0){return (((long)x<<32)|(uint)z)^((long)(floor+8)<<58);}static long Key(LotPoint p){return Key((int)Math.Floor(p.x*2),(int)Math.Floor(p.z*2),p.floor);}
```

**6. `…/Domain/HotelNavigation.cs`** · replace all 3 occurrences:

```csharp
n.solids.Add(new LotRect(
```

with:

```csharp
n.Solids(0).Add(new LotRect(
```

**7. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
var ground=Floor(h,0);if(ground!=null)foreach(var e in ShellGrid.Edges(ground)){string k=ShellGrid.WallAt(ground,e);if(k!="wall"&&k!="window")continue;ShellGrid.TryEdge(e,out char axis,out int ex,out int ez);n.solids.Add(
```

with:

```csharp
var ground=Floor(h,0);foreach(var level in h.floors)foreach(var e in ShellGrid.Edges(level)){string k=ShellGrid.WallAt(level,e);if(k!="wall"&&k!="window")continue;ShellGrid.TryEdge(e,out char axis,out int ex,out int ez);n.Solids(level.level).Add(
```

**8. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
n.solids.Add(Rect(o).Grow(.18f));
```

with:

```csharp
n.Solids(o.floor).Add(Rect(o).Grow(.18f));
```

**9. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(!Owned(p.x,p.z,index)||n.solids.Any(b=>b.Has(p.x,p.z)))continue;if(constructed&&!h.rooms.Any(r=>Rect(r).Has(p.x,p.z))
```

with:

```csharp
if(!Owned(p.x,p.z,index)||n.Solids(0).Any(b=>b.Has(p.x,p.z)))continue;if(constructed&&!h.rooms.Any(r=>r.floor==0&&Rect(r).Has(p.x,p.z))
```

**10. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
n.points[Key(x,z)]=p;}
```

with:

```csharp
n.points[Key(x,z)]=p;}
  foreach(var level in h.floors.Where(v=>v.level!=0))foreach(var c in level.cells.Keys){ShellGrid.TryCell(c,out int cx,out int cz);for(int i=0;i<2;i++)for(int j=0;j<2;j++){var p=new LotPoint(cx+i*.5f+.25f,cz+j*.5f+.25f,level.level);if(!n.Solids(level.level).Any(b=>b.Has(p.x,p.z)))n.points[Key(cx*2+i,cz*2+j,level.level)]=p;}}
```

**11. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
long k=Key(x+dx,z+dz);
```

with:

```csharp
long k=Key(x+dx,z+dz,p.Value.floor);
```

**12. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
n.edges[p.Key]=neighbors;}navCache[cache]=n;return n;}
```

with:

```csharp
n.edges[p.Key]=neighbors;}
  // Stairwells link each half-cell of the stairs to the landing directly above.
  foreach(var s in h.rooms.Where(r=>r.kind=="stairs")){var sb=Rect(s);for(int x=(int)(sb.x*2);x<(sb.x+sb.w)*2;x++)for(int z=(int)(sb.z*2);z<(sb.z+sb.d)*2;z++){long lo=Key(x,z,s.floor),hi=Key(x,z,s.floor+1);if(n.points.ContainsKey(lo)&&n.points.ContainsKey(hi)){n.edges[lo].Add(hi);n.edges[hi].Add(lo);}}}navCache[cache]=n;return n;}
```

**13. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
static bool Segment(LotPoint a,LotPoint b,Nav n){if(n.solids.Any(r=>Hits(a,b,r)))return false;
```

with:

```csharp
static bool Segment(LotPoint a,LotPoint b,Nav n){if(a.floor!=b.floor||n.Solids(a.floor).Any(r=>Hits(a,b,r)))return false;
```

**14. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(!n.points.ContainsKey(Key(x,z)))return false;
```

with:

```csharp
if(!n.points.ContainsKey(Key(x,z,a.floor)))return false;
```

**15. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(!n.points.ContainsKey(Key(x+sx,z))||!n.points.ContainsKey(Key(x,z+sz)))return false;
```

with:

```csharp
if(!n.points.ContainsKey(Key(x+sx,z,a.floor))||!n.points.ContainsKey(Key(x,z+sz,a.floor)))return false;
```

**16. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
new LotPoint(b.x-.25f,b.z+b.d/2),new LotPoint(b.x+b.w+.25f,b.z+b.d/2),new LotPoint(b.x+b.w/2,b.z-.25f),new LotPoint(b.x+b.w/2,b.z+b.d+.25f)
```

with:

```csharp
new LotPoint(b.x-.25f,b.z+b.d/2,o.floor),new LotPoint(b.x+b.w+.25f,b.z+b.d/2,o.floor),new LotPoint(b.x+b.w/2,b.z-.25f,o.floor),new LotPoint(b.x+b.w/2,b.z+b.d+.25f,o.floor)
```

**17. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
var venue=new VenueSnapshot{id=o.id,
```

with:

```csharp
var venue=new VenueSnapshot{floor=o.floor,id=o.id,
```

**18. `…/Domain/HotelNavigation.cs`** · replace all 2 occurrences:

```csharp
new VenueSlot{x=p.x,z=p.z,
```

with:

```csharp
new VenueSlot{floor=p.floor,x=p.x,z=p.z,
```

**19. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
new LotPoint(v.x,v.z).Distance(new LotPoint(s.x,s.z))
```

with:

```csharp
v.Point.Distance(s.Point)
```

**20. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
+p.z.ToString("F2",System.Globalization.CultureInfo.InvariantCulture);}
```

with:

```csharp
+p.z.ToString("F2",System.Globalization.CultureInfo.InvariantCulture)+(p.floor!=0?"@"+p.floor:"");}
```

- [ ] **Step 4: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Shell floors suite passed`. The oracle, `Life visits` and `Dense 600s` sections still pass. `PASS <n> checks` (676064 during planning).

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): floor-aware navigation linked by stairwells"
```

---

### Task 3: Hotel life across floors (domain)

**Files:** `HotelState.cs`, `HotelLife.cs`, `HotelVisitors.cs`, `tests/unity-domain/ShellSuites.cs`, `tests/unity-domain/Program.cs`

- [ ] **Step 1: Write the failing test**

Append to `ShellSuites`:

```csharp
	public static void RunFloorLife(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;
		var h=m.Hotel();h.rooms.Clear();h.floors.Clear();h.objects.Clear();h.paths.Clear();h.level=3;
		var arr=m.Map()["arrival"];int x=(int)Math.Floor((float)arr[0])-7,z=(int)Math.Floor((float)arr[1])-6;
		Check(m.Execute("paint_floor",Paint(x,z,8,7)).success,"floor life: lobby around the arrival point");
		Check(m.Execute("draw_room",RoomOn(0,x+1,z+1,2,3,0,"stairs")).success,"floor life: stairs");
		Check(m.Execute("paint_floor",PaintOn(1,x+3,z,5,6)).success,"floor life: upstairs hall");
		Check(m.Execute("draw_room",m.RoomDraft(x+4,z,x+7,z+2,"regular",1)).success,"floor life: upstairs bedroom");var room=m.Hotel().rooms.Last();
		var reception=Catalog.All.First(i=>i.role=="reception");var bed=Catalog.All.First(i=>i.role=="bed"&&i.bond==0&&i.width<=2&&i.depth<=2);
		var desk=m.Execute("place_object",Furnish(reception.id,0,x+4,z+4));Check(desk.success,"floor life: reception in the lobby ("+desk.message+")");
		var placed=m.PlaceObject(bed.id,x+4.5f,z+.5f,0,1);Check(placed.success,"floor life: bed upstairs ("+placed.message+")");
		Check(m.Hotel().objects.Last().floor==1&&m.Hotel().objects.Last().room==room.id,"floor life: the bed belongs to the upstairs bedroom");
		var bedId=m.Hotel().objects.Last().id;Check(m.MoveObject(bedId,x+4.5f,z+.5f).success&&m.Hotel().objects.Last().floor==1,"floor life: moving furniture keeps its floor");
		var status=m.RoomStatus(room.id);Check(status.ready,"floor life: upstairs bedroom is ready ("+status.status+")");
		Check(m.GuestCapacity()==2,"floor life: upstairs bedroom adds two guests ("+m.GuestCapacity()+")");
		bool climbed=false;for(int t=0;t<900&&!climbed;t++){m.Tick(1);climbed=m.Actors.Any(a=>a.floor==1);}
		Check(climbed,"floor life: a guest walks upstairs");
		Console.WriteLine("Shell floor life suite passed");
	}
```

Register it in `Program.cs` after `ShellSuites.RunFloors(Check,P,content);`:

```csharp
ShellSuites.RunFloorLife(Check,P,content);
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `'ActorSnapshot' does not contain a definition for 'floor'`.

- [ ] **Step 3: Apply the edits**

**1. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public float x,z,facing,activityElapsed,activityDuration;
```

with:

```csharp
public int floor;public float x,z,facing,activityElapsed,activityDuration;
```

**2. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
public LotPoint Position=>new LotPoint(view.x,view.z);}
```

with:

```csharp
public LotPoint Position=>new LotPoint(view.x,view.z,view.floor);}
```

**3. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var candidate=new LotPoint(origin.x+(float)Math.Cos(angle)*ring*.8f,origin.z+(float)Math.Sin(angle)*ring*.8f);
```

with:

```csharp
var candidate=new LotPoint(origin.x+(float)Math.Cos(angle)*ring*.8f,origin.z+(float)Math.Sin(angle)*ring*.8f,origin.floor);
```

**4. `…/Domain/HotelLife.cs`** · replace all 2 occurrences:

```csharp
new LotPoint(v.staffSlot.x,v.staffSlot.z)
```

with:

```csharp
v.staffSlot.Point
```

**5. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var p=new LotPoint(slot.x,slot.z);
```

with:

```csharp
var p=slot.Point;
```

**6. `…/Domain/HotelLife.cs`** · replace every occurrence:

```csharp
new LotPoint(v.x,v.z)
```

with:

```csharp
v.Point
```

**7. `…/Domain/HotelLife.cs`** · replace all 2 occurrences:

```csharp
new LotPoint(s.x,s.z)
```

with:

```csharp
s.Point
```

**8. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var p=new LotPoint(a.view.x+(float)Math.Cos(angle)*2.5f,a.view.z+(float)Math.Sin(angle)*2.5f);
```

with:

```csharp
var p=new LotPoint(a.view.x+(float)Math.Cos(angle)*2.5f,a.view.z+(float)Math.Sin(angle)*2.5f,a.view.floor);
```

**9. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
new LotPoint(waiting.view.x+(float)Math.Cos(away+angleOffset)*1.25f,waiting.view.z+(float)Math.Sin(away+angleOffset)*1.25f);
```

with:

```csharp
new LotPoint(waiting.view.x+(float)Math.Cos(away+angleOffset)*1.25f,waiting.view.z+(float)Math.Sin(away+angleOffset)*1.25f,waiting.view.floor);
```

**10. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var p=new LotPoint(a.view.x+(float)Math.Cos(angle+turnAngle)*.8f,a.view.z+(float)Math.Sin(angle+turnAngle)*.8f);
```

with:

```csharp
var p=new LotPoint(a.view.x+(float)Math.Cos(angle+turnAngle)*.8f,a.view.z+(float)Math.Sin(angle+turnAngle)*.8f,a.view.floor);
```

**11. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
foreach(var b in actors){if(a==b)continue;
```

with:

```csharp
foreach(var b in actors){if(a==b||b.view.floor!=a.view.floor)continue;
```

**12. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
new LotPoint(from.x+dx*t,from.z+dz*t)
```

with:

```csharp
new LotPoint(from.x+dx*t,from.z+dz*t,from.floor)
```

**13. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var p=a.route[a.waypoint];float gap=a.Position.Distance(p);
```

with:

```csharp
var p=a.route[a.waypoint];if(p.floor!=a.view.floor){a.view.floor=p.floor;a.waypoint++;continue;}float gap=a.Position.Distance(p);
```

**14. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
var candidate=new LotPoint(a.view.x+dx*move,a.view.z+dz*move);
```

with:

```csharp
var candidate=new LotPoint(a.view.x+dx*move,a.view.z+dz*move,a.view.floor);
```

**15. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
new LotPoint(box.x+box.w/2,box.z+box.d/2)
```

with:

```csharp
new LotPoint(box.x+box.w/2,box.z+box.d/2,o.floor)
```

**16. `…/Domain/HotelVisitors.cs`** · replace every occurrence:

```csharp
new LotPoint(v.x,v.z)
```

with:

```csharp
v.Point
```

**17. `…/Domain/HotelVisitors.cs`** · replace exactly once:

```csharp
new LotPoint(slot.x,slot.z)
```

with:

```csharp
slot.Point
```

- [ ] **Step 4: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Shell floor life suite passed`. A simulated guest walks upstairs within 900 simulated seconds. `PASS <n> checks` (676074 during planning).

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): guests, staff and visitors live on every floor"
```

---

### Task 4: Themed rooms earn their keep (domain)

**Files:** `HotelNavigation.cs`, `tests/unity-domain/ShellSuites.cs`

- [ ] **Step 1: Write the failing test**

In `RunFloorLife`, insert this block directly before `Console.WriteLine("Shell floor life suite passed");`:

```csharp
		var sun=Catalog.All.FirstOrDefault(i=>i.role=="sun"&&i.surfaces.Contains("indoor")&&i.bond==0&&i.width<=2&&i.depth<=2);
		if(sun!=null)
		{
			Check(m.Execute("draw_room",m.RoomDraft(x+5,z+4,x+7,z+6,"sunroom",1)).success,"floor life: sunroom upstairs");var sunroom=m.Hotel().rooms.Last();
			double before=m.Rate();Check(m.Execute("place_object",Furnish(sun.id,1,x+6f,z+5f)).success,"floor life: sunny spot in the sunroom");
			Check(m.RoomStatus(sunroom.id).ready&&m.Rate()-before>=15,"floor life: a ready sunroom adds income ("+(m.Rate()-before)+")");
		}
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: `System.Exception: floor life: a ready sunroom adds income`, because the sunroom isn't ready without the themed-room status rule.

- [ ] **Step 3: Apply the edits**

**1. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(r.kind=="shared"||r.kind=="terrace"){
```

with:

```csharp
if(r.kind=="shared"||r.kind=="terrace"||Themed(r.kind)){
```

**2. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
total+=h.staff.Sum()*2;}
```

with:

```csharp
total+=h.staff.Sum()*2;total+=h.rooms.Where(r=>Themed(r.kind)&&RoomStatus(r.id,i).ready).Select(r=>r.kind).Distinct().Sum(k=>k=="sunroom"?15:k=="garden"?20:25);}
```

- [ ] **Step 4: Run to verify it passes, then run the Unity gate**

Run: `dotnet run --project tests/unity-domain`. Expected: `PASS <n> checks` (676079 during planning).
Run: `.\tools\unity.ps1 Test`. Expected: exit 0. Presentation code that builds `LotPoint`, `VenueSlot` or `ActorSnapshot` still compiles, because the new fields have defaults. If Unity reports a compile error in `Presentation/`, fix only that call site by passing the floor through.

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): sunrooms, rooftop gardens and spas add income when furnished"
```

---

### Task 5: Stack floors in the world

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldShell.cs`, `VoxelWorld.cs`, `VoxelWorldRooms.cs`
- Modify: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/ShellPresentationTests.cs`

- [ ] **Step 1: Write the failing EditMode test**

Add to `ShellPresentationTests`:

```csharp
 [Test]public void FloorsStackAndHideAboveTheViewedFloor(){
  Assert.AreEqual(0f,VoxelWorld.FloorY(0),1e-4f);Assert.AreEqual(VoxelWorld.FloorHeight,VoxelWorld.FloorY(1),1e-4f);Assert.AreEqual(-VoxelWorld.FloorHeight,VoxelWorld.FloorY(-1),1e-4f);
  Assert.IsTrue(VoxelWorld.FloorVisible(1,1));Assert.IsTrue(VoxelWorld.FloorVisible(0,1));Assert.IsFalse(VoxelWorld.FloorVisible(2,1));
  Assert.IsFalse(VoxelWorld.FloorVisible(0,-1),"viewing the basement hides everything above it");Assert.IsTrue(VoxelWorld.FloorVisible(-1,0),"the basement stays built under the ground floor");}
```

- [ ] **Step 2: Run to verify it fails**

Run: `.\tools\unity.ps1 Test`
Expected: compile error `'VoxelWorld' does not contain a definition for 'FloorY'`.

- [ ] **Step 3: Add floor placement and visibility to `VoxelWorldShell.cs`**

Add these members:

```csharp
 public const float FloorHeight=2.9f;
 public static float FloorY(int level){return level*FloorHeight;}
 public static bool FloorVisible(int level,int viewFloor){return level<=viewFloor;}
 public int ViewFloor{get;private set;}
 readonly System.Collections.Generic.Dictionary<Transform,int> floorOf=new System.Collections.Generic.Dictionary<Transform,int>();
 void OnFloor(Transform root,int level){floorOf[root]=level;var p=root.localPosition;p.y+=FloorY(level);root.localPosition=p;root.gameObject.SetActive(FloorVisible(level,ViewFloor));}
 public void SetViewFloor(int level){ViewFloor=level;foreach(var pair in floorOf)if(pair.Key)pair.Key.gameObject.SetActive(FloorVisible(pair.Value,ViewFloor));if(scenery)scenery.gameObject.SetActive(ViewFloor>=0);foreach(var n in neighborhoods.Values)n.Root.gameObject.SetActive(ViewFloor>=0&&n==neighborhoods.GetValueOrDefault(currentMap));}
```

Then:
1. In `BuildShell()`, change `foreach(var floor in model.Hotel().floors.Where(f=>f.level==0))` to `foreach(var floor in model.Hotel().floors)`, and after `rooms["shell:"+floor.level]=root;` add `OnFloor(root,floor.level);`.
2. Draw a roof cell only when no indoor cell sits directly above it. Change the roof loop's `foreach(var key in floor.cells.Keys){` to `foreach(var key in floor.cells.Keys){if(ShellGrid.Indoor(HotelModel.Floor(model.Hotel(),floor.level+1),key))continue;`.
3. The rooftop (level 2) has no roof and a knee-high parapet. When `floor.level==2`, skip the roof group and pass height `.6f` for both the full and cutaway runs.
4. Skip floor boards on stair landings, which sit directly over a stairwell from the floor below. In the board loop, also `continue` when `model.State.rooms.Any(r=>r.kind=="stairs"&&r.floor==floor.level-1&&InRoom(r,x+.5f,z+.5f))`.
5. Clear `floorOf` wherever `rooms.Clear()` runs in the rebuild (`VoxelWorld.cs:39`), by appending `floorOf.Clear();`.

In `VoxelWorldRooms.BuildRoom`, after `rooms[r.id]=root;root.localPosition=new Vector3(r.x*Unit,0,r.z*Unit);` add `OnFloor(root,r.floor);`. In `VoxelWorld.BuildObject` (line 41), after `objects[o.id]=root;` add `OnFloor(root,o.floor);`.

In `ScreenToGround` (`VoxelWorld.cs:22`), change `GroundPoint(screen,GroundY)` to `GroundPoint(screen,GroundY+FloorY(ViewFloor))`, so taps land on the viewed floor. Keep the returned `p.y` as it is.

- [ ] **Step 4: Run the tests and look at it**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode with God mode on, build stairs and an upstairs room using the domain commands through the UI from Task 7, or temporarily through the Unity CLI's C# execution against `HotelApp.Model`. Check that floor 1 sits exactly on top of floor 0 with no gap or z-fighting at 2.9 units, and that ground roofs are hidden under upstairs cells.

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation unity/PurringtonHotel/Assets/Purrington/Tests/EditMode
git commit -m "feat(world): stack hotel floors, hide floors above the viewed one"
```

### Task 6: Stairs, climbing cats and camera

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldRooms.cs`, `VoxelWorld.cs` (`SyncActors`, `UpdateCamera`)

- [ ] **Step 1: Draw the stairwell**

In `BuildRoom`, for `r.kind=="stairs"` (it is an interior room, so the shell draws its walls), add six steps that rise along the room's depth away from its door side, plus a rail on the open side:

```csharp
if(r.kind=="stairs"){int steps=6;int side=r.door>=0?r.door:r.rotation;bool alongZ=side==0||side==2?false:true;for(int i=0;i<steps;i++){float t=(i+.5f)/steps;float h=(i+1)*FloorHeight/steps;var at=alongZ?new Vector3(w/2,h/2,side==1?d*(1-t):d*t):new Vector3(side==0?w*(1-t):w*t,h/2,d/2);Box(root,at,alongZ?new Vector3(w-.1f,h,d/steps):new Vector3(w/steps,h,d-.1f),Shade("a86030",i*.02f));}Bake(root);}
```

Check the result in Play mode: the lowest step sits by the door and the top step meets the landing opening above. If they run the wrong way, invert `t` for that axis. Keep the rise in whole `FloorHeight`.

- [ ] **Step 2: Put cats on their floor, smoothly**

In `SyncActors` (`VoxelWorld.cs:44`), cats are placed with `var at=new Vector3(a.x*Unit,GroundY,a.z*Unit);`. Change it to use a per-actor displayed height that eases toward `FloorY(a.floor)`. Add the field `readonly System.Collections.Generic.Dictionary<string,float> actorY=new System.Collections.Generic.Dictionary<string,float>();` in `VoxelWorldShell.cs`, and change that line to:

```csharp
float targetY=FloorY(a.floor);float shownY=actorY.TryGetValue(a.id,out var y)?Mathf.MoveTowards(y,targetY,Time.deltaTime*FloorHeight*1.5f):targetY;actorY[a.id]=shownY;var at=new Vector3(a.x*Unit,GroundY+shownY,a.z*Unit);
```

Hide actors on floors above the viewed one: after the actor root position is set, call `actorRoot.gameObject.SetActive(FloorVisible(a.floor,ViewFloor))`, using the local that holds the actor's root transform in `SyncActors`.

- [ ] **Step 3: Keep the viewed floor centered**

In `UpdateCamera`, add `FloorY(ViewFloor)` to the height of the camera's look-at point, so the orthographic camera centers on the viewed floor. In Watch mode (following a cat), call `SetViewFloor(followed.floor)` whenever the followed cat changes floors, so the camera follows it upstairs.

- [ ] **Step 4: Run the tests and look at it**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode, watch a guest walk from reception to an upstairs bedroom. They should climb over about 0.7 s, disappear when you view the ground floor, and reappear upstairs when you view floor 1.

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(world): stairwells, cats climbing between floors, floor-aware camera"
```

### Task 7: Floor switcher and floor-aware build tools

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelShellUI.cs`, `HotelUI.cs`, `HotelParityUI.cs`, `VoxelWorldPreview.cs`

- [ ] **Step 1: Floor switcher chip**

In `HotelShellUI.cs`, add `int currentFloor;` and a `FloorChip(RectTransform parent)` that draws `▲`, the floor name (`Basement`, `Ground`, `Upstairs`, `Rooftop`) and `▼`. Only show it when the hotel has more than one floor. Each arrow moves to the next existing floor and calls `app.World.SetViewFloor(currentFloor)`, then `Rebuild()`. Call `FloorChip` from the Build panel header and the Hotel panel header, in the same row as the existing panel title (`HotelUI.BuildPanel` / `HotelPanel`). Use the existing `Button(row,label,action,color,size)` helper seen in `BuildExtras`.

- [ ] **Step 2: Every build command targets the viewed floor**

- In `ShellCatalogue` and `ShellTarget`, replace every literal `{"floor",0}` and `HotelModel.Floor(app.Model.Hotel(),0)` with `currentFloor`.
- In `ShellTarget`'s `draw_room` branch, call `app.Model.RoomDraft(…,(string)commandPayload["kind"]??"regular",currentFloor)`.
- In `HotelUI.Preview`/`Place` (furniture placement), pass `currentFloor` to `PreviewObject`/`PlaceObject`/`PreviewRetrieveObject`/`RetrieveObject`. Their new `floor` parameter comes from Task 1.
- In `BeginCommand` for `place_template`, set `payload["floor"]=currentFloor`.

- [ ] **Step 3: Stairs and themed room cards**

In `ShellCatalogue`:
- Add a **Stairs** card. Tapping it begins a `draw_room` command with `{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",currentFloor}`. In `ShellTarget`, when `commandPayload["kind"]=="stairs"`, set `x,y` from the tapped cell instead of drafting a rectangle. The existing Rotate button toggles `rotation` between 0 and 1.
  - The subtitle reads `app.Model.FloorLock(currentFloor+1)??"Opens the floor above"`.
  - On the ground floor, when `app.Model.FloorLock(-1)==null`, also offer **Stairs down** with `{"floor",-1}`.
- Add themed cards only on their floors: **Sunroom** (Upstairs), **Garden** (Rooftop) and **Spa** (Basement), each drawing a `draw_room` of that kind. Card subtitles: "Sunny naps · +15 coins/min when furnished", "Open-air plants · +20 coins/min", "Warm soaks · +25 coins/min".
- When the viewed floor is locked, show one disabled card with `app.Model.FloorLock(level)` as its text.

- [ ] **Step 4: Previews on the viewed floor**

In `VoxelWorldPreview.SetCommandPreview`, raise the preview group to the viewed floor. After `preview=Group(renderRoot,"Command preview");` add `preview.localPosition=new Vector3(0,FloorY(ViewFloor),0);`.

- [ ] **Step 5: Run the tests and play-check**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode with God mode on:
1. Place stairs on the ground floor. The chip appears, and ▲ shows the 2×3 landing.
2. Grow upstairs, and draw a Bedroom and a Sunroom.
3. Place a bed and a perch.
4. Go to the rooftop: place stairs from upstairs, grow, draw a Garden and add a planter.
5. Go to the basement: Stairs down, grow, draw a Spa and add a fireplace.
6. Undo steps back through all of it.

- [ ] **Step 6: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(ui): floor switcher, stairs and themed rooms, floor-aware building"
```

### Task 8: Basement and rooftop dressing (voxel art agent + Unity QA agent)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldShell.cs`
- Create: `docs/art/qa-shots/hotel-growth/floors-*.png`

- [ ] **Step 1: Basement view**

When `ViewFloor==-1`, `SetViewFloor` hides the scenery and neighborhood (Task 5). Also set `WorldCamera.backgroundColor` to a warm dark earth (`#3B3128`) and restore the map color on leaving. `SetEvening` holds the per-map colors at `VoxelWorld.cs:36`, so reuse that array. Give basement walls lamp-lit panels by choosing `panel="8A6F55"` in `BuildShell` when `floor.level==-1`.

- [ ] **Step 2: Rooftop view**

Give garden rooms green-tinted floor boards (`Shade("82934D",…)` instead of `D2AD77`) in `BuildRoom` when `r.kind=="garden"`. Check that the parapet from Task 5 reads as a railing in both views.

- [ ] **Step 3: Capture Gate 4**

In God mode on Meadow, build a two-floor hotel with stairs, an upstairs bedroom and sunroom, a rooftop garden and a basement spa. Capture portrait and landscape at each viewed floor as `docs/art/qa-shots/hotel-growth/floors-{basement,ground,upstairs,rooftop}-{portrait,landscape}.png`, plus one Watch-mode capture of a cat mid-climb. Check against `docs/art/STYLE-GUIDE.md`.

- [ ] **Step 4: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation docs/art/qa-shots/hotel-growth
git commit -m "feat(world): basement and rooftop dressing; floors QA captures"
```

## Verification record

Tasks 1–4 were applied in order to a scratch copy (plans 02 and 03 applied) on 2026-09-22. Each task's test failed first with the expected build error, then passed: 676063 → 676064 → 676074 → 676079 checks, with the Godot oracle, the life simulation and the dense 600-second simulation green throughout. Tasks 5–8 are Unity presentation work and were **not** compiled during planning. `tools/unity.ps1 Test` and the Play-mode checks in each task are the gates.
