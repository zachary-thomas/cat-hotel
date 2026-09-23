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
 CommandResult ApplyWallTool(string action,JObject p,HotelData h){int level=(int?)p["floor"]??0;var gate=FloorGate(h,level);if(gate!=null)return CommandResult.Fail(gate);var f=Floor(h,level);if(f==null||f.cells.Count==0)return CommandResult.Fail("Build hotel floor first.");
  if(action=="draw_wall"){if(!(p["from"] is JArray a)||!(p["to"] is JArray b)||a.Count!=2||b.Count!=2||!a.Concat(b).All(Whole))return CommandResult.Fail("Drag along the grid lines.");var edges=new JArray(WallPath((int)a[0],(int)a[1],(int)b[0],(int)b[1]).ToArray());if(edges.Count==0)return CommandResult.Fail("Drag along the grid lines.");if(edges.Count>64)return CommandResult.Fail("Build walls in shorter runs.");var built=SetEdges(h,level,new JObject{{"kind","wall"},{"edges",edges}});return built.success?CommandResult.Ok("Built "+edges.Count+(edges.Count==1?" wall":" walls"),built.cost):built;}
  if(!Whole(p["x"])||!Whole(p["y"]))return CommandResult.Fail("Tap inside the space.");string kind=(string)p["kind"]??"regular";if(!IndoorKind(kind)||kind=="stairs")return CommandResult.Fail("Choose a bedroom, suite, lounge or themed room.");string start=ShellGrid.Cell((int)p["x"],(int)p["y"]);if(!f.cells.ContainsKey(start))return CommandResult.Fail("Tap inside the hotel.");
  var region=new HashSet<string>{start};var queue=new Queue<string>(region);while(queue.Count>0){var c=queue.Dequeue();ShellGrid.TryCell(c,out int x,out int z);foreach(var e in ShellGrid.CellEdges(x,z)){if(ShellGrid.WallAt(f,e)!=null)continue;ShellGrid.Sides(e,out var sa,out var sb);var next=sa==c?sb:sa;if(!f.cells.ContainsKey(next)||!region.Add(next))continue;if(region.Count>400)return CommandResult.Fail("Close this space with walls first.");queue.Enqueue(next);}}
  if(h.rooms.Any(r=>r.floor==level&&CellSet(r).Overlaps(region)))return CommandResult.Fail("Part of this space is already a room.");
  var pts=region.Select(c=>{ShellGrid.TryCell(c,out int x,out int z);return (x,z);}).ToList();var room=new RoomState{id=Id("room"),kind=kind,name=(string)p["name"]??"New room",x=pts.Min(q=>q.x),z=pts.Min(q=>q.z),floor=level,cells=region.OrderBy(c=>c,StringComparer.Ordinal).ToList()};room.width=pts.Max(q=>q.x)-room.x+1;room.depth=pts.Max(q=>q.z)-room.z+1;
  var shape=CellRoomShape(room);if(shape!=null)return CommandResult.Fail(shape);if(!RoomShape(room))return CommandResult.Fail("This space is too narrow for a "+KindName(kind)+".");room.paid=Price(ClaimPrice(kind,region.Count));h.rooms.Add(room);return CommandResult.Ok(room.name+" is ready to furnish",room.paid);}
}
}
