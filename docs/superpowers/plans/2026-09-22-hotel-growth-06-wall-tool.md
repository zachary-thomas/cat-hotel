# Freeform Wall Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Sims-style wall tool (option 3 from brainstorming) beside the rectangle room tool. Players drag walls along grid lines, one bend per drag, then tap an enclosed space to make it a room of any shape: an L-shaped suite, a lounge tucked into a corner.

**Architecture:** Both tools share one data model. Walls are stored edges (plan 02); `draw_wall` stores player walls along `HotelModel.WallPath`. `claim_room` flood-fills from the tapped cell across open floor, stopping at any wall, door or window, and saves a `RoomState` whose `cells` list holds the exact shape. Its `x/z/width/depth` are the bounding box. Rectangle rooms keep `cells == null`, which isn't even serialized. Every "is this point in the room" check goes through `RoomHas`/`RoomEncloses`/`RoomOverlaps`/`CellSet`, so validation, navigation, furniture and life all understand shaped rooms. Shaped rooms keep the player's walls (no owned-wall sync), cannot be moved or resized (you reshape them by moving walls), and are priced by their real area.

**Tech Stack:** C# 9, the .NET 9 domain harness, Unity 6000.3, uGUI.

**Spec:** [hotel-growth design](../specs/2026-09-22-hotel-growth-design.md): "Build tools", Walls (phase 2). **Depends on:** plans 02–04 merged; plan 05 may be merged too, since this was verified with it.

---

## Files

- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelWallTool.cs`
- Modify: `…/Domain/HotelState.cs`, `StrictSaveJson.cs`, `HotelShell.cs`, `HotelNavigation.cs`, `HotelLife.cs`, `HotelShellDraw.cs`, `HotelModel.cs`
- Modify: `tests/unity-domain/ShellSuites.cs`, `Program.cs`
- Modify (presentation): `VoxelWorldRooms.cs`, `VoxelWorldShell.cs`, `VoxelWorldPreview.cs`, `HotelShellUI.cs`

`…/Domain/` is `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/`.

---

### Task 1: Shaped rooms and the wall commands (domain)

- [ ] **Step 1: Write the failing test**

Append to `ShellSuites`:

```csharp
	static JObject Wall(int x0,int z0,int x1,int z1){return new JObject{{"floor",0},{"from",new JArray(x0,z0)},{"to",new JArray(x1,z1)}};}
	static JObject Claim(int x,int z,string kind){return new JObject{{"floor",0},{"x",x},{"y",z},{"kind",kind},{"name","Corner "+kind}};}
	public static void RunWallTool(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;var lot=m.Hotel();lot.rooms.Clear();lot.floors.Clear();lot.objects.Clear();lot.paths.Clear();
		Check(FindClear(m,8,7,out int x,out int z),"walls: clear land");
		Check(m.Execute("paint_floor",Paint(x,z,6,5)).success,"walls: open-plan floor");
		double coins=m.State.coins;var wall=m.Execute("draw_wall",Wall(x+6,z+2,x+3,z+5));
		Check(wall.success&&Math.Abs(coins-m.State.coins-30)<.01,"walls: an L-shaped wall of 6 edges costs 30 ("+wall.message+")");
		Check(HotelModel.WallPath(x+6,z+2,x+3,z+5).Count==6,"walls: the UI preview path matches the built walls");
		var floor=HotelModel.Floor(m.Hotel(),0);
		Check(ShellGrid.WallAt(floor,"h:"+(x+4)+","+(z+2))=="wall"&&ShellGrid.WallAt(floor,"v:"+(x+3)+","+(z+3))=="wall","walls: the bend runs along x, then z");
		var doorless=m.Quote("claim_room",Claim(x,z,"suite"));Check(!doorless.success&&doorless.message.Contains("door"),"walls: a space needs a door first ("+doorless.message+")");
		Check(m.Execute("set_edge",EdgePayload("door","v:"+x+","+(z+1))).success,"walls: front door");
		coins=m.State.coins;var suite=m.Execute("claim_room",Claim(x,z,"suite"));Check(suite.success,"walls: claim the L-shaped space as a suite ("+suite.message+")");
		var room=m.Hotel().rooms.Last();
		Check(room.cells!=null&&room.cells.Count==21&&room.width==6&&room.depth==5&&HotelModel.Interior(m.Hotel(),room),"walls: the suite keeps its 21 L-shaped cells");
		Check(Math.Abs(coins-m.State.coins-Math.Round(1225*.45,MidpointRounding.AwayFromZero))<.01,"walls: an L suite costs 45% of a 21-cell suite");
		Check(HotelModel.RoomHas(room,x+1.5f,z+3.5f)&&!HotelModel.RoomHas(room,x+4.5f,z+3.5f),"walls: membership follows the L, not its bounding box");
		var small=m.Quote("claim_room",Claim(x+4,z+3,"regular"));Check(!small.success,"walls: 9 cells is too small for a bedroom ("+small.message+")");
		Check(m.Execute("set_edge",EdgePayload("door","v:"+(x+3)+","+(z+3))).success,"walls: door between the two spaces");
		var lounge=m.Execute("claim_room",Claim(x+4,z+3,"shared"));Check(lounge.success,"walls: the small space becomes a lounge ("+lounge.message+")");
		Check(!m.Quote("claim_room",Claim(x+1,z+1,"regular")).success,"walls: claimed space can't be claimed twice");
		var plant=Catalog.All.First(i=>i.surfaces.Contains("indoor")&&i.width<=1&&i.depth<=1&&i.bond==0);
		Check(m.PlaceObject(plant.id,x+1,z+3).success&&m.Hotel().objects.Last().room==room.id,"walls: furniture in the L's arm belongs to the suite");
		Check(!m.Quote("set_edge",EdgePayload("none","h:"+(x+4)+","+(z+2))).success,"walls: walls that enclose rooms stay");
		Check(!m.Quote("move_room",new JObject{{"id",room.id},{"x",x},{"y",z},{"rotation",0}}).success,"walls: wall-tool rooms reshape by walls, not moving");
		Check(m.Route(new LotPoint(x-1.5f,z+1.5f),new LotPoint(x+4.5f,z+3.5f),false).Count>0,"walls: cats walk through the suite into the lounge");
		var codec=new NewtonsoftSaveCodec();var restored=codec.Deserialize(codec.Serialize(m.State));
		Check(HotelModel.Valid(restored)&&restored.hotels[restored.currentHotel].rooms.Last().cells.Count==9,"walls: room shapes survive a save");
		var bad=JObject.Parse(codec.Serialize(m.State));var badRoom=(JArray)bad["hotels"][m.State.currentHotel]["rooms"];badRoom[badRoom.Count-1]["cells"]=new JArray("nope");
		var other=new HotelModel(new MemoryStore(),content);other.LoadOrCreate();Check(!other.RestoreJson(bad.ToString()),"walls: corrupt room cells are rejected");
		Check(!JObject.Parse(codec.Serialize(other.State))["hotels"][0]["rooms"][0].ToString().Contains("cells"),"walls: rectangle rooms don't store cells");
		Check(m.Execute("remove_room",P("{\"id\":\""+room.id+"\"}")).success&&ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),"h:"+(x+4)+","+(z+2))=="wall","walls: removing the room keeps the walls");
		Check(m.Undo().success&&m.Hotel().rooms.Any(r=>r.id==room.id),"walls: undo restores the claimed room");
		Console.WriteLine("Wall tool suite passed");
	}
```

Register it in `Program.cs` after `ShellSuites.RunFloorLife(Check,P,content);`:

```csharp
ShellSuites.RunWallTool(Check,P,content);
```

- [ ] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `'HotelModel' does not contain a definition for 'WallPath'` (and `RoomHas`).

- [ ] **Step 3: Create `HotelWallTool.cs`**

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
public sealed partial class HotelModel {
 // Room membership for rectangle rooms and wall-tool rooms (explicit cells) alike.
 static HashSet<string> CellSet(RoomState r){if(r.cells!=null)return new HashSet<string>(r.cells);RoomCells(r,out int x,out int z,out int w,out int d);return new HashSet<string>(ShellGrid.Cells(x,z,w,d));}
 public static bool RoomHas(RoomState r,float x,float z){if(r.cells==null){RoomSize(r,out float w,out float d);return x>=r.x&&z>=r.z&&x<r.x+w&&z<r.z+d;}return r.cells.Contains(ShellGrid.Cell((int)Math.Floor(x),(int)Math.Floor(z)));}
 static IEnumerable<string> Covered(LotRect b){for(int x=(int)Math.Floor(b.x);x<Math.Ceiling(b.x+b.w);x++)for(int z=(int)Math.Floor(b.z);z<Math.Ceiling(b.z+b.d);z++)yield return ShellGrid.Cell(x,z);}
 static bool RoomEncloses(RoomState r,LotRect b){return r.cells==null?Rect(r).Encloses(b):Covered(b).All(r.cells.Contains);}
 static bool RoomOverlaps(RoomState r,LotRect b){return r.cells==null?Rect(r).Intersects(b):Covered(b).Any(r.cells.Contains);}
 static bool RoomsOverlap(RoomState a,RoomState b){return a.cells==null&&b.cells==null?Rect(a).Intersects(Rect(b)):CellSet(a).Overlaps(CellSet(b));}
 static IEnumerable<string> RoomBoundary(HashSet<string> cells){var seen=new HashSet<string>();foreach(var c in cells){ShellGrid.TryCell(c,out int x,out int z);foreach(var e in ShellGrid.CellEdges(x,z)){ShellGrid.Sides(e,out var a,out var b);if(cells.Contains(a)!=cells.Contains(b)&&seen.Add(e))yield return e;}}}
 static IEnumerable<string> RoomInside(HashSet<string> cells){var seen=new HashSet<string>();foreach(var c in cells){ShellGrid.TryCell(c,out int x,out int z);foreach(var e in ShellGrid.CellEdges(x,z)){ShellGrid.Sides(e,out var a,out var b);if(cells.Contains(a)&&cells.Contains(b)&&seen.Add(e))yield return e;}}}
 static int MinArea(string kind){return kind=="regular"?12:kind=="suite"?20:kind=="shared"?4:Themed(kind)?9:int.MaxValue;}
 static string KindName(string kind){return kind=="regular"?"bedroom":kind=="shared"?"lounge":kind;}
 static double ClaimPrice(string kind,int area){double shell=kind=="regular"?450+Math.Max(0,area-12)*25:kind=="suite"?1200+Math.Max(0,area-20)*25:area*25;return Math.Round(shell*.45,MidpointRounding.AwayFromZero);}
 // Wall-tool rooms list unique canonical cells whose bounding box is the room's x, z, width and depth.
 static string CellRoomShape(RoomState r){if(r.cells.Count==0||r.cells.Distinct().Count()!=r.cells.Count||r.rotation!=0||r.door!=-1||r.kind=="stairs")return "Keep hotel rooms tidy.";var pts=new List<(int x,int z)>();foreach(var c in r.cells){if(!ShellGrid.TryCell(c,out int x,out int z))return "Keep hotel rooms tidy.";pts.Add((x,z));}if(pts.Min(p=>p.x)!=r.x||pts.Min(p=>p.z)!=r.z||pts.Max(p=>p.x)-r.x+1!=r.width||pts.Max(p=>p.z)-r.z+1!=r.depth)return "Keep hotel rooms tidy.";return r.cells.Count<MinArea(r.kind)?"This space is too small for a "+KindName(r.kind)+".":null;}
 // The edges a wall drag builds: along x on the start's grid line, then along z on the end's grid line (one bend). Shared by draw_wall and the UI preview.
 public static List<string> WallPath(int x0,int z0,int x1,int z1){var edges=new List<string>();for(int x=Math.Min(x0,x1);x<Math.Max(x0,x1);x++)edges.Add(ShellGrid.Edge('h',x,z0));for(int z=Math.Min(z0,z1);z<Math.Max(z0,z1);z++)edges.Add(ShellGrid.Edge('v',x1,z));return edges;}
 // draw_wall: player walls along grid lines from one grid corner to another, first along x then along z (one bend).
 // claim_room: the enclosed space around a tapped cell becomes a room of any shape.
 CommandResult ApplyWallTool(string action,JObject p,HotelData h){int level=(int?)p["floor"]??0;var f=Floor(h,level);if(f==null||f.cells.Count==0)return CommandResult.Fail("Build hotel floor first.");
  if(action=="draw_wall"){if(!(p["from"] is JArray a)||!(p["to"] is JArray b)||a.Count!=2||b.Count!=2||!a.Concat(b).All(Whole))return CommandResult.Fail("Drag along the grid lines.");var edges=new JArray(WallPath((int)a[0],(int)a[1],(int)b[0],(int)b[1]).ToArray());if(edges.Count==0)return CommandResult.Fail("Drag along the grid lines.");if(edges.Count>64)return CommandResult.Fail("Build walls in shorter runs.");var built=SetEdges(h,level,new JObject{{"kind","wall"},{"edges",edges}});return built.success?CommandResult.Ok("Built "+edges.Count+(edges.Count==1?" wall":" walls"),built.cost):built;}
  if(!Whole(p["x"])||!Whole(p["y"]))return CommandResult.Fail("Tap inside the space.");string kind=(string)p["kind"]??"regular";if(!IndoorKind(kind)||kind=="stairs")return CommandResult.Fail("Choose a bedroom, suite, lounge or themed room.");string start=ShellGrid.Cell((int)p["x"],(int)p["y"]);if(!f.cells.ContainsKey(start))return CommandResult.Fail("Tap inside the hotel.");
  var region=new HashSet<string>{start};var queue=new Queue<string>(region);while(queue.Count>0){var c=queue.Dequeue();ShellGrid.TryCell(c,out int x,out int z);foreach(var e in ShellGrid.CellEdges(x,z)){if(ShellGrid.WallAt(f,e)!=null)continue;ShellGrid.Sides(e,out var sa,out var sb);var next=sa==c?sb:sa;if(!f.cells.ContainsKey(next)||!region.Add(next))continue;if(region.Count>400)return CommandResult.Fail("Close this space with walls first.");queue.Enqueue(next);}}
  if(h.rooms.Any(r=>r.floor==level&&CellSet(r).Overlaps(region)))return CommandResult.Fail("Part of this space is already a room.");
  var pts=region.Select(c=>{ShellGrid.TryCell(c,out int x,out int z);return (x,z);}).ToList();var room=new RoomState{id=Id("room"),kind=kind,name=(string)p["name"]??"New room",x=pts.Min(q=>q.x),z=pts.Min(q=>q.z),floor=level,cells=region.OrderBy(c=>c,StringComparer.Ordinal).ToList()};room.width=pts.Max(q=>q.x)-room.x+1;room.depth=pts.Max(q=>q.z)-room.z+1;
  var shape=CellRoomShape(room);if(shape!=null)return CommandResult.Fail(shape);if(!RoomShape(room))return CommandResult.Fail("This space is too narrow for a "+KindName(kind)+".");room.paid=Price(ClaimPrice(kind,region.Count));h.rooms.Add(room);return CommandResult.Ok(room.name+" is ready to furnish",room.paid);}
}
}
```

- [ ] **Step 4: Route every membership check through the shape helpers**

**1. `…/Domain/HotelState.cs`** · replace exactly once:

```csharp
public int x,z,width,depth,rotation,floor,door=-1; public double paid; }
```

with:

```csharp
public int x,z,width,depth,rotation,floor,door=-1; public double paid; [JsonProperty(NullValueHandling=NullValueHandling.Ignore)] public List<string> cells; }
```

**2. `…/Domain/StrictSaveJson.cs`** · replace exactly once:

```csharp
Numbers(r,"floor",true,true);Numbers(r,"door",true,true);
```

with:

```csharp
Numbers(r,"floor",true,true);Numbers(r,"door",true,true);if(r["cells"]!=null){Require(r["cells"].Type==JTokenType.Array);foreach(var c in r["cells"])Require(c.Type==JTokenType.String);}
```

**3. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
 public static bool Interior(HotelData h,RoomState r){var f=Floor(h,r.floor);if(f==null)return false;RoomCells(r,out int x,out int z,out int w,out int d);return ShellGrid.Cells(x,z,w,d).All(f.cells.ContainsKey);}
```

with:

```csharp
 public static bool Interior(HotelData h,RoomState r){var f=Floor(h,r.floor);return f!=null&&CellSet(r).All(f.cells.ContainsKey);}
```

**4. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
h.rooms.Where(v=>v.floor==f.level&&IndoorKind(v.kind)&&Interior(h,v))
```

with:

```csharp
h.rooms.Where(v=>v.floor==f.level&&v.cells==null&&IndoorKind(v.kind)&&Interior(h,v))
```

**5. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
  foreach(var r in h.rooms){var f=Floor(h,r.floor);RoomCells(r,out int x,out int z,out int w,out int d);int inside=f==null?0:ShellGrid.Cells(x,z,w,d).Count(f.cells.ContainsKey);if(inside==0){if(r.floor!=0)return CommandResult.Fail("Upper-floor rooms need floor under them.");if(r.kind=="stairs"||Themed(r.kind))return CommandResult.Fail("Draw this room inside the hotel.");continue;}if(!AllowedKind(r.floor,r.kind))return CommandResult.Fail(KindHint(r.floor));if(inside!=w*d||!IndoorKind(r.kind))return CommandResult.Fail("Draw rooms fully inside the hotel or fully outside it.");if(ShellGrid.Inside(x,z,w,d).Any(f.edges.ContainsKey))return CommandResult.Fail("Walls can't cut through a room.");var walls=ShellGrid.Boundary(x,z,w,d).Select(e=>ShellGrid.WallAt(f,e)).ToList();
```

with:

```csharp
  foreach(var r in h.rooms){var f=Floor(h,r.floor);var cells=CellSet(r);int inside=f==null?0:cells.Count(f.cells.ContainsKey);if(r.cells!=null){var shape=CellRoomShape(r);if(shape!=null)return CommandResult.Fail(shape);}if(inside==0){if(r.floor!=0)return CommandResult.Fail("Upper-floor rooms need floor under them.");if(r.kind=="stairs"||Themed(r.kind)||r.cells!=null)return CommandResult.Fail("Draw this room inside the hotel.");continue;}if(!AllowedKind(r.floor,r.kind))return CommandResult.Fail(KindHint(r.floor));if(inside!=cells.Count||!IndoorKind(r.kind))return CommandResult.Fail("Draw rooms fully inside the hotel or fully outside it.");if(RoomInside(cells).Any(f.edges.ContainsKey))return CommandResult.Fail("Walls can't cut through a room.");var walls=RoomBoundary(cells).Select(e=>ShellGrid.WallAt(f,e)).ToList();
```

**6. `…/Domain/HotelShell.cs`** · replace exactly once:

```csharp
if(h.rooms.Any(r=>r.floor==level&&Rect(r).Has(x+.5f,z+.5f)))return CommandResult.Fail("Remove the room here first.");
```

with:

```csharp
if(h.rooms.Any(r=>r.floor==level&&RoomHas(r,x+.5f,z+.5f)))return CommandResult.Fail("Remove the room here first.");
```

**7. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(!RoomShape(r)||!roomIds.Add(r.id)||!Owns(Rect(r),index))
```

with:

```csharp
if(!RoomShape(r)||!roomIds.Add(r.id)||!CellSet(r).All(c=>{ShellGrid.TryCell(c,out int cx,out int cz);return Owns(new LotRect(cx,cz,1,1),index);}))
```

**8. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
Rect(b).Intersects(Rect(r))
```

with:

```csharp
RoomsOverlap(b,r)
```

**9. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
var room=h.rooms.Find(r=>r.floor==o.floor&&Rect(r).Encloses(b));if(h.rooms.Any(r=>r!=room&&r.floor==o.floor&&Rect(r).Intersects(b)))
```

with:

```csharp
var room=h.rooms.Find(r=>r.floor==o.floor&&RoomEncloses(r,b));if(h.rooms.Any(r=>r!=room&&r.floor==o.floor&&RoomOverlaps(r,b)))
```

**10. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
h.rooms.Any(r=>r.floor==0&&Rect(r).Has(p.x,p.z))
```

with:

```csharp
h.rooms.Any(r=>r.floor==0&&RoomHas(r,p.x,p.z))
```

**11. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
if(indoors&&!Rect(room).Has(p.x,p.z))continue;
```

with:

```csharp
if(indoors&&!RoomHas(room,p.x,p.z))continue;
```

**12. `…/Domain/HotelNavigation.cs`** · replace exactly once:

```csharp
indoors&&!Rect(room).Has(end.x,end.z)
```

with:

```csharp
indoors&&!RoomHas(room,end.x,end.z)
```

**13. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
Rect(r).Has(a.view.x,a.view.z)
```

with:

```csharp
RoomHas(r,a.view.x,a.view.z)
```

**14. `…/Domain/HotelLife.cs`** · replace exactly once:

```csharp
Rect(r).Has(b.view.x,b.view.z)
```

with:

```csharp
RoomHas(r,b.view.x,b.view.z)
```

**15. `…/Domain/HotelShellDraw.cs`** · replace exactly once:

```csharp
h.rooms.Any(r=>r.floor==level&&Rect(r).Has(ox,oz))
```

with:

```csharp
h.rooms.Any(r=>r.floor==level&&RoomHas(r,ox,oz))
```

**16. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
r=h.rooms.Find(v=>v.id==id);if(r==null)return CommandResult.Fail("Select an existing room.");
```

with:

```csharp
r=h.rooms.Find(v=>v.id==id);if(r==null)return CommandResult.Fail("Select an existing room.");if(r.cells!=null&&action!="remove_room")return CommandResult.Fail("Reshape this room by moving its walls.");
```

**17. `…/Domain/HotelModel.cs`** · replace exactly once:

```csharp
  case "paint_floor":case "erase_floor":case "set_edge":
```

with:

```csharp
  case "draw_wall":case "claim_room":var tool=ApplyWallTool(action,p,h);if(!tool.success)return tool;cost=tool.cost;message=tool.message;break;
  case "paint_floor":case "erase_floor":case "set_edge":
```

- [ ] **Step 5: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Wall tool suite passed` and `PASS <n> checks` (676123 during planning, with plans 02–05 applied). The Godot oracle is unchanged.

- [ ] **Step 6: Search for stragglers**

Run: `grep -rn "Rect(r).Has\|Rect(room).Has\|Rect(r).Encloses" unity/PurringtonHotel/Assets/Purrington/Runtime`
Expected: no matches, other than the helpers' own rectangle branches in `HotelWallTool.cs`. A remaining match is a room-membership check that ignores shapes: switch it to `RoomHas`/`RoomEncloses`, then rerun Step 5.

- [ ] **Step 7: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): wall tool and rooms of any shape"
```

---

### Task 2: Render shaped rooms

**Files:** `…/Presentation/VoxelWorldRooms.cs`, `VoxelWorldShell.cs`, `VoxelWorldPreview.cs`

- [ ] **Step 1: Floors and picking per cell.** In `BuildRoom`, when `r.cells!=null`:
  - Replace the rectangle floor slab and boards (line 7) with per-cell boards. Call the existing `ShellBoards(root,x-r.x,z-r.z)` for each cell. The root is already offset to `r.x,r.z`. `ShellBoards` uses absolute cell coordinates, so pass the cell relative to the room origin, or temporarily parent to `layout`. Pick whichever keeps boards aligned with the hallway boards.
  - Replace the single pick `BoxCollider` with one `BoxCollider` per cell, all on the same `WorldPick` root, so tapping any part of the L selects the room.
  - Shaped rooms are always interior, so the wall/roof branch is already skipped.
- [ ] **Step 2: Membership in the shell renderer.** In `VoxelWorldShell.cs`, replace the body of `InRoom(RoomState r,float x,float z)` with `return HotelModel.RoomHas(r,x,z);`.
- [ ] **Step 3: Selection outline follows the shape.** Where the selected room is outlined (search `Outline(` in `VoxelWorldPreview.cs` and the room-edit flow in `HotelUI.EditRoom`), outline shaped rooms per cell. Loop over `r.cells` and call `Outline(cx,cz,1,1,color)`.
- [ ] **Step 4: Tests and a look.** Run `.\tools\unity.ps1 Test` (exit 0). In Play mode with God mode on, build the L-suite from the domain test through the UI of Task 3. The boards cover exactly the L, the lounge next to it has its own boards, and tapping either arm of the L selects the suite.
- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(world): render and select rooms of any shape"
```

---

### Task 3: Walls and Make-room tools

**Files:** `…/Presentation/HotelShellUI.cs`, `VoxelWorldPreview.cs`

- [ ] **Step 1: Add the cards.** In `ShellCatalogue`, after Doors & windows, add:

```csharp
            Card(content,"Walls","Drag along the grid · one bend per drag · "+ShellGrid.WallPrice.ToString("N0")+" coins an edge","Build",()=>BeginCommand("draw_wall",new JObject{{"floor",currentFloor}},"Walls"),Mint);
            foreach(var kind in new[]{"regular","suite","shared"}.Concat(currentFloor==1?new[]{"sunroom"}:currentFloor==2?new[]{"garden"}:currentFloor==-1?new[]{"spa"}:new string[0]))
            {
                string chosen=kind;string name=kind=="regular"?"Bedroom":kind=="suite"?"Suite":kind=="shared"?"Lounge":char.ToUpper(kind[0])+kind.Substring(1);
                Card(content,"Make a "+name.ToLower(),"Tap inside a walled space with a door","Tap",()=>BeginCommand("claim_room",new JObject{{"floor",currentFloor},{"kind",chosen},{"name",name}},"Make a "+name.ToLower()),Gold);
            }
```

On the rooftop only `garden` is valid, so drop the three standard kinds when `currentFloor==2`. The domain would refuse them anyway (`KindHint`); hiding them avoids a confusing card.

- [ ] **Step 2: Handle the gestures in `ShellTarget`.**
  - `draw_wall` snaps to grid corners. Take the anchor from the drag start (reuse `roomAnchor`, set on the first point), set the end from the current point, and write the payload. Also add `"draw_wall"` to `ShellDrawing`, so drags reach it.

```csharp
            if(commandAction=="draw_wall")
            {
                int gx=Mathf.RoundToInt(point.x),gz=Mathf.RoundToInt(point.z);if(roomAnchor==null)roomAnchor=new Vector2Int(gx,gz);
                commandPayload["from"]=new JArray(roomAnchor.Value.x,roomAnchor.Value.y);commandPayload["to"]=new JArray(gx,gz);
                hasTarget=true;PreviewCommand();return true;
            }
            if(commandAction=="claim_room"){commandPayload["x"]=Mathf.FloorToInt(point.x);commandPayload["y"]=Mathf.FloorToInt(point.z);hasTarget=true;PreviewCommand();return true;}
```

  - Place these before the `if(!ShellDrawing(commandAction))return false;` line. The cost pill and Confirm then work through the existing `PreviewCommand`/`PlaceCommand`.

- [ ] **Step 3: Preview.** In `VoxelWorldPreview.SetCommandPreview`, add:

```csharp
 if(action=="draw_wall"&&p["from"] is JArray from&&p["to"] is JArray to){foreach(var e in HotelModel.WallPath((int)from[0],(int)from[1],(int)to[0],(int)to[1])){ShellGrid.TryEdge(e,out char axis,out int ex,out int ez);Outline(ex,ez,axis=='v'?.01f:1,axis=='v'?1:.01f,color);}return;}
 if(action=="claim_room"){Outline((float)p["x"],(float)p["y"],1,1,color);return;}
```

Put both before the generic `action.Contains("room")` branch. `claim_room` contains "room", so order matters.

- [ ] **Step 4: Tests and play-check.** Run `.\tools\unity.ps1 Test` (exit 0). In Play mode:
  1. Grow a 6×5 floor and choose Walls.
  2. Drag from the corner (x+6, z+2) to (x+3, z+5). The preview shows an L of six edges and the quote says 30 coins. Confirm.
  3. Doors & windows: add a front door and a door between the spaces.
  4. Make a suite: tap the L. Make a lounge: tap the corner space.
  5. Undo walks back through each step.

- [ ] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(ui): wall tool and make-a-room from walled spaces"
```

---

### Task 4: Gate 5 captures (Unity QA agent)

- [ ] **Step 1:** Build (`.\tools\unity.ps1 Windows`) and run QA (`.\tools\unity.ps1 QA`), both exit 0.
- [ ] **Step 2:** In God mode on Meadow, build an L-shaped suite with a bed and armchair, a corner lounge, and a hallway alcove with a window seat. Capture cutaway portrait and landscape as `docs/art/qa-shots/hotel-growth/wall-tool-{portrait,landscape}.png`, plus one Watch-mode capture of a guest walking into the L's far arm.
- [ ] **Step 3:** Commit the captures: `git add docs/art/qa-shots/hotel-growth && git commit -m "docs: wall tool QA captures"`.

## Verification record

Task 1 was applied on 2026-09-22 to a scratch copy with plans 02–05 applied, and ran green: `PASS 676123` checks, including the Godot oracle, the life simulations and the wardrobe. Tasks 2–4 are Unity presentation work and were **not** compiled during planning.
