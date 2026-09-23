# Shell Rendering + Mobile Build Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the building shell (hallway and lobby floors, continuous walls, doors, windows, archways, roof) and give players the mobile build tools from the spec: Grow, Room drawing with an automatic door side, Doors & windows tapping, and Erase. Controls: one finger draws, two fingers pan and pinch.

**Architecture:** Task 1 adds pure domain helpers (`ShellDraw`, `HotelModel.RoomDraft`, and a `RoomState.door` side override) that are tested in the .NET harness. Presentation adds `VoxelWorldShell.cs` (a `VoxelWorld` partial) that renders `ShellDraw.Runs` through the existing `Wall()` styling, and `HotelShellUI.cs` (a `HotelUI` partial) that plugs the tools into the existing command flow (`BeginCommand` → `UpdateCommandTarget` → `PreviewCommand` → `PlaceCommand`) in `HotelParityUI.cs`.

**Tech Stack:** Unity 6000.3 URP, uGUI/TextMeshPro, Input System, NUnit EditMode, the .NET 9 domain harness.

**Spec:** [hotel-growth design](../specs/2026-09-22-hotel-growth-design.md): "Build tools", "Presentation". **Depends on:** plan 02 merged.

---

## Conventions

- Domain tests: `dotnet run --project tests/unity-domain` (the final line is `PASS <n> checks`). Unity tests: `.\tools\unity.ps1 Test` (exit 0).
- Presentation files use dense one-line members like their neighbors. New files may use one member per line.
- Grid units vs world units: domain coordinates are grid cells. The world multiplies by `VoxelWorld.Unit` (1.1). `ScreenToGround` already returns grid units.
- Room-wall convention from `VoxelWorldRooms.Wall(parent,w,d,side,…)`: side 0 is at x=w, side 1 at z=d, side 2 at x=0 and side 3 at z=0, each facing inward. In cutaway view, sides 2 and 3 (back walls) stand 2.1 tall and sides 0 and 1 (front) stand 0.25.

## Files

- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelShellDraw.cs`
- Modify: `…/Domain/HotelState.cs`, `HotelModel.cs`, `HotelNavigation.cs`, `HotelShell.cs`, `StrictSaveJson.cs` (door side)
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldShell.cs`
- Modify: `…/Presentation/VoxelWorld.cs` (rebuild signature + `BuildShell()` call), `VoxelWorldRooms.cs` (interior rooms skip their walls; `Wall()` options), `VoxelWorldInput.cs` (two-finger pan, offset cursor, drag end), `VoxelWorldPreview.cs` (floor and room previews)
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelShellUI.cs`
- Modify: `…/Presentation/HotelParityUI.cs` (hooks), `HotelUI.cs:770` (category), `HotelApp.cs:71` (event)
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/ShellPresentationTests.cs`
- Modify: `tests/unity-domain/ShellSuites.cs`, `tests/unity-domain/Program.cs`
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ParityInputAcceptance.cs` (Task 6)

---

### Task 1: Drawing helpers and door side (domain)

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Domain/HotelShellDraw.cs`
- Modify: `HotelState.cs`, `StrictSaveJson.cs`, `HotelModel.cs`, `HotelNavigation.cs`, `HotelShell.cs`
- Modify: `tests/unity-domain/ShellSuites.cs`, `tests/unity-domain/Program.cs`

Why the door side exists: the legacy `RoomShape` ties a regular room's door to its short side (`width ≥ 4` on the rotation axis). A 4×3 room drawn beside a hallway must still be able to open onto that hallway, so rooms gain an optional `door` side. The default `-1` means "use `rotation`", so the legacy behavior and the Godot oracle are unchanged.

- [x] **Step 1: Write the failing test**

Append to `ShellSuites` in `tests/unity-domain/ShellSuites.cs`:

```csharp
	public static void RunDraw(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		var f=new FloorState();foreach(var c in ShellGrid.Cells(0,0,3,2))f.cells[c]=0;f.edges["h:1,2"]=new EdgeState{kind="door"};
		var runs=ShellDraw.Runs(f);
		Check(runs.Count(r=>r.kind=="door")==1&&runs.Sum(r=>r.length)==10,"draw: 3x2 island outline is 10 edges with one door");
		var south=runs.Where(r=>r.axis=='h'&&r.z==2).OrderBy(r=>r.x).ToList();
		Check(south.Count==3&&south[0].kind=="wall"&&south[1].kind=="door"&&south[2].kind=="wall"&&south.All(r=>r.inward==-1),"draw: a door splits the south wall into wall/door/wall facing inward");
		Check(runs.Single(r=>r.axis=='h'&&r.z==0).length==3&&runs.Single(r=>r.axis=='h'&&r.z==0).inward==1,"draw: the north wall merges into one run");
		f.edges["v:1,0"]=new EdgeState{kind="wall"};Check(ShellDraw.Runs(f).Any(r=>r.axis=='v'&&r.x==1&&r.inward==0),"draw: interior walls face both ways");
		Check(ShellDraw.NearestEdge(2.1f,5.5f)=="v:2,5"&&ShellDraw.NearestEdge(2.5f,5.9f)=="h:2,6","draw: taps pick the nearest edge");
		Check(ShellDraw.Line(0,0,3,1).Count==4&&ShellDraw.Line(0,0,3,1).Last()==(3,1),"draw: strokes fill the cells between samples");
		Check(ShellDraw.NextKind(f,"h:0,0")=="door"&&ShellDraw.NextKind(f,"h:1,2")=="window"&&ShellDraw.NextKind(f,"v:1,0")=="door","draw: tapping cycles wall → door → window");
		f.edges["h:0,0"]=new EdgeState{kind="window"};Check(ShellDraw.NextKind(f,"h:0,0")=="open","draw: outside windows cycle to an archway");
		f.edges["v:1,0"].kind="window";Check(ShellDraw.NextKind(f,"v:1,0")=="wall","draw: inside windows cycle back to a wall");
		var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=100000;OwnPlots(m);
		Check(FindClear(m,8,6,out int x,out int z),"draw: clear land");
		Check(m.Execute("paint_floor",Paint(x,z+3,8,1)).success,"draw: hallway south of the new room");
		var draft=m.RoomDraft(x+3,z+2,x,z,"regular");
		Check((int)draft["rotation"]==0&&(int)draft["door"]==1&&(int)draft["w"]==4&&(int)draft["h"]==3&&(int)draft["x"]==x&&(int)draft["y"]==z,"draw: a 4x3 drag puts its door on the hallway side ("+draft.ToString(Newtonsoft.Json.Formatting.None)+")");
		var drawn=m.Execute("draw_room",draft);Check(drawn.success,"draw: drafted room is valid ("+drawn.message+")");var room=m.Hotel().rooms.Last();
		Check(ShellGrid.WallAt(HotelModel.Floor(m.Hotel(),0),"h:"+(x+1)+","+(z+3))=="door","draw: the double door opens onto the hallway");
		HotelModel.DoorPosition(room,out float dx,out float dz);Check(Math.Abs(dx-(x+2))<.01&&Math.Abs(dz-(z+3.25f))<.01,"draw: DoorPosition follows the door side ("+dx+","+dz+")");
		Check(m.Execute("move_room",new JObject{{"id",room.id},{"x",x},{"y",z},{"rotation",room.rotation}}).success&&room.door==1,"draw: moving without turning keeps the door side");
		Check(!m.Quote("draw_room",m.RoomDraft(x+5,z,x+7,z+2,"regular")).success,"draw: a 3x3 bedroom is refused");
		Console.WriteLine("Shell draw suite passed");
	}
```

Register it in `tests/unity-domain/Program.cs` after `ShellSuites.RunShellUndo(Check,P,content);`:

```csharp
ShellSuites.RunDraw(Check,P,content);
```

- [x] **Step 2: Run to verify it fails**

Run: `dotnet run --project tests/unity-domain`
Expected: build error `The name 'ShellDraw' does not exist in the current context`.

- [x] **Step 3: Add the door side**

| File | Replace | With |
|---|---|---|
| `HotelState.cs` | `public int x,z,width,depth,rotation,floor;` | `public int x,z,width,depth,rotation,floor,door=-1;` |
| `StrictSaveJson.cs` | `Numbers(r,"floor",true,true);` | `Numbers(r,"floor",true,true);Numbers(r,"door",true,true);` |
| `HotelModel.cs` (`RoomShape`) | `r.rotation>=0&&r.rotation<4` | `r.rotation>=0&&r.rotation<4&&r.door>=-1&&r.door<4` |
| `HotelModel.cs` (`Apply`) | `new[]{"rotation","w","h","service","staff","floor"}` | `new[]{"rotation","w","h","service","staff","floor","door"}` |
| `HotelModel.cs` (`place_room`) | `floor=(int?)p["floor"]??0};` | `floor=(int?)p["floor"]??0,door=(int?)p["door"]??-1};` |
| `HotelModel.cs` (move/copy) | `r.rotation=(int?)p["rotation"]??r.rotation;` | `r.rotation=(int?)p["rotation"]??r.rotation;if(r.door>=0)r.door=((r.door+r.rotation-old.rotation)%4+4)%4;` |
| `HotelNavigation.cs` (`DoorPosition`) | `switch(r.rotation){case 0:` | `switch(r.door>=0?r.door:r.rotation){case 0:` |
| `HotelShell.cs` (`DoorSides`) | `new[]{r.rotation}` | `new[]{r.door>=0?r.door:r.rotation}` |

- [x] **Step 4: Create `HotelShellDraw.cs`**

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
// A straight stretch of one wall kind on one grid line. inward is +1 when the indoor side is the cell at (x,z) (east/south of the line), -1 when it is the west/north cell, 0 for interior walls.
public struct WallRun {public char axis;public int x,z,length,inward;public string kind;}
public static class ShellDraw {
 // Merges consecutive edges on the same grid line with the same kind and facing, so the renderer builds a few long walls instead of one box per edge.
 public static List<WallRun> Runs(FloorState f){var runs=new List<WallRun>();if(f==null)return runs;var edges=new List<WallRun>();foreach(var e in ShellGrid.Edges(f)){string kind=ShellGrid.WallAt(f,e);if(kind==null)continue;ShellGrid.TryEdge(e,out char axis,out int x,out int z);ShellGrid.Sides(e,out var a,out var b);bool ia=ShellGrid.Indoor(f,a),ib=ShellGrid.Indoor(f,b);edges.Add(new WallRun{axis=axis,x=x,z=z,length=1,kind=kind,inward=ia&&ib?0:ib?1:-1});}foreach(var r in edges.OrderBy(v=>v.axis).ThenBy(v=>v.axis=='v'?v.x:v.z).ThenBy(v=>v.axis=='v'?v.z:v.x)){if(runs.Count>0){var last=runs[runs.Count-1];bool touching=last.axis==r.axis&&(r.axis=='v'?last.x==r.x&&last.z+last.length==r.z:last.z==r.z&&last.x+last.length==r.x);if(touching&&last.kind==r.kind&&last.inward==r.inward){last.length++;runs[runs.Count-1]=last;continue;}}runs.Add(r);}return runs;}
 // The grid edge closest to a ground point, for tap-to-edit doors and windows.
 public static string NearestEdge(float x,float z){int cx=(int)Math.Floor(x),cz=(int)Math.Floor(z);float fx=x-cx,fz=z-cz;float toV=Math.Min(fx,1-fx),toH=Math.Min(fz,1-fz);return toV<=toH?ShellGrid.Edge('v',fx<.5f?cx:cx+1,cz):ShellGrid.Edge('h',cx,fz<.5f?cz:cz+1);}
 // Cells along a finger stroke between two cells (Bresenham), so fast drags leave no gaps.
 public static List<(int x,int z)> Line(int x0,int z0,int x1,int z1){var cells=new List<(int x,int z)>();int dx=Math.Abs(x1-x0),dz=Math.Abs(z1-z0),sx=x0<x1?1:-1,sz=z0<z1?1:-1,error=dx-dz;for(int n=0;n<4096;n++){cells.Add((x0,z0));if(x0==x1&&z0==z1)break;int twice=2*error;if(twice>-dz){error-=dz;x0+=sx;}if(twice<dx){error+=dx;z0+=sz;}}return cells;}
 // Next edge kind when tapping an edge: wall → door → window → (outside only) archway → wall.
 public static string NextKind(FloorState f,string edge){string now=ShellGrid.WallAt(f,edge)??"none";bool outside=ShellGrid.Exterior(f,edge);return now=="wall"?"door":now=="door"?"window":now=="window"?(outside?"open":"wall"):"wall";}
}
public sealed partial class HotelModel {
 // Turns a dragged footprint into a draw_room payload. Rotation only satisfies the legacy minimum shape; the door goes on the side that opens onto hallway floor, then bare land, preferring camera-facing sides.
 public JObject RoomDraft(int x0,int z0,int x1,int z1,string kind,int level=0){int x=Math.Min(x0,x1),z=Math.Min(z0,z1),fw=Math.Abs(x1-x0)+1,fd=Math.Abs(z1-z0)+1;var h=Hotel();var f=Floor(h,level);int rotation=RoomShape(new RoomState{kind=kind,width=fw,depth=fd})?0:1;int door=0,bestScore=-1;foreach(int side in new[]{1,0,3,2}){int score=2;foreach(var e in ShellGrid.DoorEdges(x,z,fw,fd,side)){ShellGrid.EdgeCenter(e,out float ex,out float ez);float ox=side==0?ex+.5f:side==2?ex-.5f:ex,oz=side==1?ez+.5f:side==3?ez-.5f:ez;bool indoor=ShellGrid.Indoor(f,ShellGrid.Cell((int)Math.Floor(ox),(int)Math.Floor(oz)));bool inRoom=h.rooms.Any(r=>r.floor==level&&Rect(r).Has(ox,oz));score=Math.Min(score,inRoom?0:indoor?2:1);}if(score>bestScore){door=side;bestScore=score;}}return new JObject{{"kind",kind},{"x",x},{"y",z},{"w",rotation==0?fw:fd},{"h",rotation==0?fd:fw},{"rotation",rotation},{"door",door},{"floor",level},{"buy",true}};}
}
}
```

- [x] **Step 5: Run to verify it passes**

Run: `dotnet run --project tests/unity-domain`
Expected: `Shell draw suite passed` and `PASS <n> checks`; the oracle section still passes.

- [x] **Step 6: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Domain tests/unity-domain
git commit -m "feat(domain): wall runs, edge picking, room drafts with a free door side"
```

---

### Task 2: Render the shell

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldShell.cs`
- Create: `unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/ShellPresentationTests.cs`
- Modify: `…/Presentation/VoxelWorld.cs` (lines 38–39), `…/Presentation/VoxelWorldRooms.cs` (lines 8, 11, 12)

- [x] **Step 1: Write the failing EditMode tests**

```csharp
using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class ShellPresentationTests {
 [Test]public void WallRunsMapOntoRoomWallSides(){
  VoxelWorld.ShellWallPlacement(new WallRun{axis='v',x=2,z=3,length=4,inward=1,kind="wall"},1.1f,out var o,out float w,out float d,out int side);
  Assert.AreEqual(2,side);Assert.AreEqual(0f,w);Assert.AreEqual(4.4f,d,1e-4f);Assert.AreEqual(2.2f,o.x,1e-4f);Assert.AreEqual(3.3f,o.z,1e-4f);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='v',x=2,z=3,length=1,inward=-1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(0,side);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='h',x=2,z=3,length=2,inward=1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(3,side);Assert.AreEqual(2.2f,w,1e-4f);Assert.AreEqual(0f,d);
  VoxelWorld.ShellWallPlacement(new WallRun{axis='h',x=2,z=3,length=2,inward=-1,kind="wall"},1.1f,out o,out w,out d,out side);Assert.AreEqual(1,side);}
 [Test]public void CutawayKeepsBackAndInteriorWallsTall(){
  Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(2,1),1e-4f);Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(3,1),1e-4f);
  Assert.AreEqual(.25f,VoxelWorld.CutawayHeight(0,-1),1e-4f);Assert.AreEqual(.25f,VoxelWorld.CutawayHeight(1,-1),1e-4f);
  Assert.AreEqual(2.1f,VoxelWorld.CutawayHeight(2,0),1e-4f);}
}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `.\tools\unity.ps1 Test`
Expected: compile error `'VoxelWorld' does not contain a definition for 'ShellWallPlacement'`.

- [x] **Step 3: Give `Wall()` two options (`VoxelWorldRooms.cs`)**

1. Change the signature `void Wall(Transform parent,float w,float d,int side,float height,bool door,string accent,string panel){` to `void Wall(Transform parent,float w,float d,int side,float height,bool door,string accent,string panel,bool decor=true,float doorWidth=-1){`.
2. In its door branch, change `float opening=Mathf.Min(length-.44f,2.06f)` to `float opening=doorWidth>0?doorWidth:Mathf.Min(length-.44f,2.06f)`.
3. On line 12, change `if(span<1.4f)continue;int windows=` to `if(span<1.4f||!decor)continue;int windows=`. With this, auto-decor windows only appear where the caller allows them.
4. On line 8, interior rooms stop drawing their own walls and roof, because the shell draws them. Change `if(r.kind=="terrace"){` so that the `else{` branch only runs for pavilions. Replace the text `}else{var full=Group(root,"FullWalls");` with `}else if(!HotelModel.Interior(model.Hotel(),r)){var full=Group(root,"FullWalls");`.

- [x] **Step 4: Create `VoxelWorldShell.cs`**

```csharp
using System;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Purrington.Presentation {public sealed partial class VoxelWorld {
 public event Action GroundDragEnded;
 Vector2 pinchMid;bool pinchMidValid;
 // Maps a domain wall run onto Wall()'s rectangle convention (side 0 at x=w, 1 at z=d, 2 at x=0, 3 at z=0, facing inward).
 public static void ShellWallPlacement(WallRun run,float unit,out Vector3 origin,out float w,out float d,out int side){float length=run.length*unit;origin=new Vector3(run.x*unit,0,run.z*unit);if(run.axis=='v'){w=0;d=length;side=run.inward<0?0:2;}else{w=length;d=0;side=run.inward<0?1:3;}}
 // Cutaway view: camera-facing outside walls drop to a curb; back walls and interior partitions stay tall, like pavilion rooms.
 public static float CutawayHeight(int side,int inward){return inward!=0&&(side==0||side==1)?.25f:2.1f;}
 void BuildShell(){foreach(var floor in model.Hotel().floors.Where(f=>f.level==0)){var root=Group(layout,"Shell_"+floor.level);rooms["shell:"+floor.level]=root;var boards=Group(root,"Floor");foreach(var key in floor.cells.Keys){ShellGrid.TryCell(key,out int x,out int z);if(model.State.rooms.Any(r=>r.floor==floor.level&&HotelModel.Interior(model.Hotel(),r)&&InRoom(r,x+.5f,z+.5f)))continue;ShellBoards(boards,x,z);}Bake(boards);
  var full=Group(root,"FullWalls");var cut=Group(root,"CutawayWalls");string accent=(string)model.Map()["accent"]??"a86030";foreach(var run in ShellDraw.Runs(floor)){ShellWallPlacement(run,Unit,out var origin,out float w,out float d,out int side);string panel=new[]{"738448","7E8C65","87936E","697F59"}[Math.Abs(run.x*31+run.z*17)%4];foreach(var (group,height) in new[]{(full,2.46f),(cut,CutawayHeight(side,run.inward))}){var at=Group(group,"Run_"+run.axis+run.x+"_"+run.z);at.localPosition=origin;ShellRun(at,run,w,d,side,height,accent,panel);}}Bake(full);Bake(cut);
  var roof=Group(root,"Roof");string color=new[]{"a87868","82a9a2","7c8e6d","d9e1d7"}[currentMap];foreach(var key in floor.cells.Keys){ShellGrid.TryCell(key,out int x,out int z);Box(roof,new Vector3((x+.5f)*Unit,2.84f,(z+.5f)*Unit),new Vector3(Unit+.02f,.23f,Unit+.02f),Shade(color,-.14f));}Bake(roof);SetCutawayOn(root);}}
 static bool InRoom(RoomState r,float x,float z){HotelModel.RoomSize(r,out float w,out float d);return x>=r.x&&z>=r.z&&x<r.x+w&&z<r.z+d;}
 void ShellBoards(Transform parent,int x,int z){float x0=x*Unit,z0=z*Unit;Box(parent,new Vector3(x0+Unit/2,.07f,z0+Unit/2),new Vector3(Unit,.2f,Unit),"a86030");for(int row=0;row<3;row++){int grain=(x*7+z*3+row)%4;Box(parent,new Vector3(x0+Unit/2,.151f,z0+(row+.5f)*Unit/3),new Vector3(Unit-.014f,.048f,Unit/3-.011f),Shade("D2AD77",(grain-1.5f)*.032f));}}
 void ShellRun(Transform at,WallRun run,float w,float d,int side,float height,string accent,string panel){float length=run.length*Unit;
  if(run.kind=="wall"){Wall(at,w,d,side,height,false,accent,panel,decor:run.inward!=0);return;}
  if(run.kind=="door"){Wall(at,w,d,side,height,true,accent,panel,decor:false,doorWidth:length-.2f);return;}
  if(run.kind=="open"){if(height<1)return;bool ew=run.axis=='v';foreach(float t in new[]{.08f,length-.08f})Box(at,ew?new Vector3(0,GroundY+1.15f,t):new Vector3(t,GroundY+1.15f,0),new Vector3(.22f,2.3f,.22f),accent);Box(at,ew?new Vector3(0,GroundY+2.3f,length/2):new Vector3(length/2,GroundY+2.3f,0),ew?new Vector3(.24f,.18f,length):new Vector3(length,.18f,.24f),accent);return;}
  // window: plain wall plus one sill-and-pane window per cell, sized to fit a single cell (auto-decor windows need 1.4+ units).
  Wall(at,w,d,side,height,false,accent,panel,decor:false);if(height<1)return;bool v=run.axis=='v';for(int i=0;i<run.length;i++){float c=(i+.5f)*Unit;var p=v?new Vector3(0,1.52f,c):new Vector3(c,1.52f,0);Box(at,p,v?new Vector3(.2f,.97f,.9f):new Vector3(.9f,.97f,.2f),accent);Box(at,p,v?new Vector3(.215f,.8f,.74f):new Vector3(.74f,.8f,.215f),"90bfc0");Box(at,p-Vector3.up*.53f,v?new Vector3(.43f,.12f,1f):new Vector3(1f,.12f,.43f),"f0d8c0");}}
 void SetCutawayOn(Transform root){var full=root.Find("FullWalls");var cut=root.Find("CutawayWalls");var roof=root.Find("Roof");if(full)full.gameObject.SetActive(exterior);if(cut)cut.gameObject.SetActive(!exterior);if(roof)roof.gameObject.SetActive(exterior);}
 Vector2 DrawPoint(Vector2 p){return Touchscreen.current!=null&&Touchscreen.current.primaryTouch.press.isPressed?p+Vector2.up*(Screen.dpi>0?Screen.dpi*.35f:90f):p;}
}}
```

Notes for the implementer:
- `rooms["shell:0"]` registers the shell with the existing `SetCutaway` loop (`VoxelWorld.cs:35`), which toggles children named `FullWalls`, `CutawayWalls` and `Roof`. Only `TryGetValue`, `Values` and `Clear` touch `rooms`, so the extra key is safe.
- Check the name of the field `SetCutaway` writes (`exterior`) and the `SetActive` rule for `roof` in `VoxelWorld.cs:35`. `SetCutawayOn` must mirror it exactly. If the rule differs, copy it from there.
- `GroundY` is the private const in `VoxelWorld.cs:12`.

- [x] **Step 5: Call it and rebuild on shell changes (`VoxelWorld.cs`)**

1. Line 38 (rebuild signature): change `.Append(',').Append(r.rotation);foreach(var o` to `.Append(',').Append(r.rotation).Append(',').Append(r.door).Append(',').Append(r.floor);foreach(var o`. Then change `foreach(var p in model.Hotel().plots)s.Append('|').Append(p);` to:

```csharp
foreach(var p in model.Hotel().plots)s.Append('|').Append(p);foreach(var f in model.Hotel().floors){s.Append("|F").Append(f.level);foreach(var c in f.cells.Keys)s.Append(',').Append(c);foreach(var e in f.edges)s.Append(';').Append(e.Key).Append(e.Value.kind);}
```

2. Line 39: change `BuildPaths();BuildOwnedPlots();}` to `BuildPaths();BuildOwnedPlots();BuildShell();}`.

- [x] **Step 6: Run the tests and look at it**

Run: `.\tools\unity.ps1 Test`
Expected: exit 0; `ShellPresentationTests` pass.

Then open the editor (`.\tools\unity.ps1 Open`), enter Play on Bootstrap, and compare Meadow with `docs/art/qa-shots/meadow-day-color-pass.png`. The migrated rooms must look the same: tall back walls, low front walls, and decor windows on long outside walls. Toggle Settings → exterior view and check that walls go full height and the roof appears.

- [x] **Step 7: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation unity/PurringtonHotel/Assets/Purrington/Tests/EditMode/ShellPresentationTests.cs*
git commit -m "feat(world): render hotel shell floors, walls, doors, windows, archways and roof"
```

---

### Task 3: Touch drawing (two-finger pan, offset cursor, stroke end)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldInput.cs`

- [x] **Step 1: Two fingers pan as well as pinch**

In `ReadInput`:
1. Change `pinchActive=true; pinchFirstId=firstId; pinchSecondId=secondId;` to `pinchActive=true; pinchFirstId=firstId; pinchSecondId=secondId; pinchMidValid=false;`.
2. Change `} else if(pinchOwned) {` to:

```csharp
} else if(pinchOwned) {
                    var mid=(first.position.ReadValue()+second.position.ReadValue())/2;
                    if(pinchMidValid) { manualCamera=true; focus += (ScreenToGround(pinchMid)-ScreenToGround(mid))*Unit; LimitCamera(); }
                    pinchMid=mid; pinchMidValid=true;
```

- [x] **Step 2: Draw above the finger, and report the stroke end**

1. Change `if(pathPainting) { GroundDragged?.Invoke(ScreenToGround(point)); }` to `if(pathPainting) { GroundDragged?.Invoke(ScreenToGround(DrawPoint(point))); }`.
2. In the `if(end && pressed)` block, change its first statement `pressed=false;` to `pressed=false; if(pathPainting) GroundDragEnded?.Invoke();`.

- [x] **Step 3: Verify**

Run: `.\tools\unity.ps1 Test` (exit 0). In the editor, open **Window → General → Device Simulator** and pick a phone. In Build → Paths, a one-finger drag paints with the cells appearing about 0.35 inch above the finger, and a two-finger drag pans the camera. Outside paint mode, one-finger drag still pans.

- [x] **Step 4: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/VoxelWorldInput.cs
git commit -m "feat(input): two-finger pan, offset draw cursor, stroke end event"
```

---

### Task 4: Hotel build tools

**Files:**
- Create: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelShellUI.cs`
- Modify: `…/Presentation/HotelParityUI.cs`, `HotelUI.cs:770`, `HotelApp.cs:71`, `VoxelWorldPreview.cs`

- [x] **Step 1: Create `HotelShellUI.cs`**

```csharp
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
    public sealed partial class HotelUI
    {
        Vector2Int? roomAnchor;
        bool ShellDrawing(string action){return action=="paint_floor"||action=="erase_floor"||action=="draw_room";}
        void ShellCatalogue(RectTransform content)
        {
            if(category!="Hotel")return;
            Card(content,"Grow the hotel","Drag across land · "+ShellGrid.CellPrice.ToString("N0")+" coins a tile · land for sale is bought as you go","Grow",()=>BeginCommand("paint_floor",new JObject{{"floor",0},{"cells",new JArray()},{"buy",true}},"Grow the hotel"),Mint);
            foreach(var kind in new[]{"regular","suite","shared"})
            {
                string name=kind=="regular"?"Bedroom":kind=="suite"?"Suite":"Lounge";string chosen=kind;
                Card(content,name,"Drag a rectangle · inside the hotel or on open land","Draw",()=>BeginCommand("draw_room",new JObject{{"kind",chosen},{"floor",0},{"name",name}},name),Gold);
            }
            Card(content,"Doors & windows","Tap a wall: wall → door → window → archway","Edit",()=>BeginCommand("set_edge",new JObject{{"floor",0},{"kind","door"},{"edges",new JArray()}},"Doors & windows"),Mint);
            Card(content,"Remove floor","Drag across empty hotel floor · refunds the tiles","Erase",()=>BeginCommand("erase_floor",new JObject{{"floor",0},{"cells",new JArray()}},"Remove floor"),Coral);
        }
        // Handles shell tools inside UpdateCommandTarget. Returns true when the point was consumed.
        bool ShellTarget(Vector3 point)
        {
            if(commandAction=="set_edge")
            {
                var floor=HotelModel.Floor(app.Model.Hotel(),0);string edge=ShellDraw.NearestEdge(point.x,point.z);
                if(floor==null||ShellGrid.WallAt(floor,edge)==null){ShowNotice("Tap a wall of the hotel.",true);return true;}
                var payload=new JObject{{"floor",0},{"kind",ShellDraw.NextKind(floor,edge)},{"edges",new JArray(edge)}};
                var result=app.Model.Execute("set_edge",payload);if(result.success)app.Audio?.PlayEffect("build");
                app.Report(result);Rebuild();ShowNotice(result.message+(result.success&&result.cost>0?" · "+result.cost.ToString("N0")+" coins":""),!result.success);
                return true;
            }
            if(!ShellDrawing(commandAction))return false;
            int cx=Mathf.FloorToInt(point.x),cz=Mathf.FloorToInt(point.z);
            if(commandAction=="draw_room")
            {
                if(roomAnchor==null)roomAnchor=new Vector2Int(cx,cz);
                var draft=app.Model.RoomDraft(roomAnchor.Value.x,roomAnchor.Value.y,cx,cz,(string)commandPayload["kind"]??"regular");
                draft["name"]=commandPayload["name"]??commandTitle;commandPayload=draft;
            }
            else
            {
                var cells=(JArray)commandPayload["cells"];var from=lastPathCell??new Vector2Int(cx,cz);
                foreach(var (x,z) in ShellDraw.Line(from.x,from.y,cx,cz))if(!cells.Any(c=>(int)c[0]==x&&(int)c[1]==z))cells.Add(new JArray(x,z));
                lastPathCell=new Vector2Int(cx,cz);
            }
            hasTarget=true;PreviewCommand();return true;
        }
        public void GroundDragEnded(){lastPathCell=null;roomAnchor=null;}
    }
}
```

Check that `Coral`, `Mint` and `Gold` are the color fields `Card` already receives elsewhere (`HotelParityUI.cs:182` uses `Mint`). If `Coral` doesn't exist, use the color that `HotelUI` uses for destructive actions.

- [x] **Step 2: Hook it into the command flow (`HotelParityUI.cs`)**

1. In `BeginCommand`, change `lastPathCell=null;` to `lastPathCell=null;roomAnchor=null;`, and change `app.World.SetPathPainting(action=="paint_path"||action=="erase_path");` to `app.World.SetPathPainting(action=="paint_path"||action=="erase_path"||ShellDrawing(action));`.
2. Make `if(ShellTarget(point))return;` the first statement of `UpdateCommandTarget(Vector3 point)`.
3. Change `public void GroundDragged(Vector3 point){if(commandAction=="paint_path"||commandAction=="erase_path")UpdateCommandTarget(point);}` to `public void GroundDragged(Vector3 point){if(commandAction=="paint_path"||commandAction=="erase_path"||ShellDrawing(commandAction))UpdateCommandTarget(point);}`.
4. Make `ShellCatalogue(content);` the first statement of `ParityCatalogue(RectTransform content)`.

In `HotelUI.cs:770`, change `new[]{"All","Rooms","Arrangements","Land","Paths"}` to `new[]{"All","Hotel","Rooms","Arrangements","Land","Paths"}`.

In `HotelApp.cs:71`, change `World.GroundDragged+=UI.GroundDragged;` to `World.GroundDragged+=UI.GroundDragged;World.GroundDragEnded+=UI.GroundDragEnded;`.

- [x] **Step 3: Preview the shell tools (`VoxelWorldPreview.cs`)**

1. Change `if(action=="paint_path"||action=="erase_path"){` to `if(action=="paint_path"||action=="erase_path"||action=="paint_floor"||action=="erase_floor"){`.
2. In the room branch, change `var room=new RoomState{x=(int)x,z=(int)z,width=(int)w,depth=(int)d,rotation=rotation};` to `var room=new RoomState{x=(int)x,z=(int)z,width=(int)w,depth=(int)d,rotation=rotation,door=(int?)p["door"]??-1};`. The door marker then follows the drafted door side. `draw_room` already goes through this branch because its action name contains `room`.

- [x] **Step 4: Compile, test and play-check**

Run: `.\tools\unity.ps1 Test` (exit 0). In Play mode:
1. Build → Hotel → Grow. Drag across three tiles of lawn. The preview shows 3 outlines, the notice reads `Confirm · 60 coins. The hotel grows by 3 tiles`, and Confirm builds floor with walls around it.
2. Bedroom: drag 4×3 beside the new floor. The door marker faces the floor. Confirm, and the room shares walls with the lobby.
3. Doors & windows: tap a lobby outside wall three times. It becomes a door, then a window, then an archway, with a coin notice each time.
4. Undo reverts each step.
5. Drag Grow onto the "for sale" plot. The quote includes the plot price and names it.

- [x] **Step 5: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation
git commit -m "feat(ui): Hotel build tools: grow, draw rooms, doors & windows, erase"
```

---

### Task 5: Pavilion wording and land hint

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelParityUI.cs` (`ParityCatalogue`)

- [x] **Step 1: Say what Rooms and Land do now**

In `ParityCatalogue`:
- In the `Rooms` category cards, change the subtitle argument `"Rooms"` to `"Outdoor pavilion · draw indoor rooms under Hotel"`.
- At the start of the `Land` block, insert: `if(category=="Land")Card(content,"Grow straight onto land","Use Hotel → Grow: land for sale is bought as the hotel grows onto it.","Grow",()=>BeginCommand("paint_floor",new JObject{{"floor",0},{"cells",new JArray()},{"buy",true}},"Grow the hotel"),Mint);`

- [x] **Step 2: Test and commit**

Run: `.\tools\unity.ps1 Test` (exit 0).

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelParityUI.cs
git commit -m "feat(ui): explain pavilions and growing onto land"
```

---

### Task 6: Input acceptance and visual QA (Unity QA agent)

**Files:**
- Modify: `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ParityInputAcceptance.cs`
- Create: `docs/art/qa-shots/hotel-growth/shell-*.png`

- [x] **Step 1: Add a draw-room scenario to the queued pointer acceptance**

Read `ParityInputAcceptance.cs` for how existing scenarios queue real Input System touches and assert on `app.Model`. Add a scenario that runs in both touch and mouse modes:
1. Enable God mode.
2. Open Build → Hotel → Bedroom.
3. Press on an empty lawn point and drag 4×3 cells, converting grid → screen with `World.WorldCamera.WorldToScreenPoint(new Vector3(x*VoxelWorld.Unit,.18f,z*VoxelWorld.Unit))`, then release.
4. Press Confirm.
5. Assert that `app.Model.Hotel().rooms.Count` grew by 1 and the new room is `HotelModel.Interior`.
6. Undo.

Follow the existing scenarios' result reporting so a failure fails `tools/unity.ps1 QA`.

- [x] **Step 2: Build and run QA**

Run: `.\tools\unity.ps1 Windows`, then `.\tools\unity.ps1 QA`.
Expected: exit 0; `result.txt` lists the new scenario as passed.

- [x] **Step 3: Capture Gate 2**

In God mode on Meadow, build:
- a lobby at the arrival side with an archway entrance and two windows;
- a hallway joining two bedrooms and a suite;
- a scratcher and a window seat in the hallway;
- an outdoor pavilion room in the garden.

Capture cutaway and exterior views in portrait (1080×2340) and landscape (2340×1080) as `docs/art/qa-shots/hotel-growth/shell-{cutaway,exterior}-{portrait,landscape}.png`. Check that the walls meet cleanly at corners and T-junctions, door openings line up with the hallway, the floor boards under rooms and hallways match, and nothing z-fights.

- [x] **Step 4: Commit**

```bash
git add unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/ParityInputAcceptance.cs docs/art/qa-shots/hotel-growth
git commit -m "test(qa): draw-room input acceptance; shell captures"
```

## Verification record

Task 1's code was applied to a scratch copy (with plan 02 applied) on 2026-09-22 and ran green: `PASS 676041 checks`, including the Godot oracle. Tasks 2–6 are Unity presentation code and were **not** compiled during planning. Each task's `tools/unity.ps1 Test` step is the gate.

Execution update: Tasks 1–6 were implemented and independently reviewed. The committed-only Unity snapshot passed 76/76 EditMode tests, Windows build and smoke QA. The separate queued mouse/touch acceptance run completed 21 layout cases with no failed checks or runtime errors. A focused isolated-player run subsequently passed 25 checks for the 0.35-inch touch cursor offset, one- and two-finger panning, three-cell Grow price, exact 4×3 Bedroom and floor-facing door, door/window/archway cycle and coin notices, visible Undo, and the named sale-plot quote. The final JSON is in `.superpowers/sdd/2026-09-22-hotel-growth-03-shell-presentation/task6-snapshot/tmp/deferred-shell-edfafc44435d4689bf51f9fa7860be0f/deferred-shell.json`. Gate 2's four Meadow captures passed visual review at 1080×2340 and 2340×1080. The focused acceptance helper was temporary and remained in the ignored disposable snapshot; production behavior was exercised through the player UI.
