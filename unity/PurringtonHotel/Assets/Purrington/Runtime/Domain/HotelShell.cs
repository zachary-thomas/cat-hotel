using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
[Serializable] public sealed class FloorState {public int level;public Dictionary<string,double> cells=new Dictionary<string,double>();public Dictionary<string,EdgeState> edges=new Dictionary<string,EdgeState>();}
// room is the owning room id for walls regenerated from room rectangles, or "" for walls, doors and windows the player placed.
[Serializable] public sealed class EdgeState {public string kind="wall",room="";public double paid;}
// Grid edges between hotel cells. "v:x,z" lies on grid line x between cells (x-1,z) and (x,z); "h:x,z" lies on line z between (x,z-1) and (x,z).
public static class ShellGrid {
 public const double CellPrice=20,WallPrice=5,DoorPrice=20,WindowPrice=15,OpenPrice=10;
 public static readonly string[] Kinds={"wall","door","window","open"};
 public static string Cell(int x,int z){return x.ToString(CultureInfo.InvariantCulture)+","+z.ToString(CultureInfo.InvariantCulture);}
 public static bool TryCell(string key,out int x,out int z){x=z=0;var p=key?.Split(',');return p!=null&&p.Length==2&&int.TryParse(p[0],NumberStyles.Integer,CultureInfo.InvariantCulture,out x)&&int.TryParse(p[1],NumberStyles.Integer,CultureInfo.InvariantCulture,out z)&&Cell(x,z)==key;}
 public static string Edge(char axis,int x,int z){return axis+":"+Cell(x,z);}
 public static bool TryEdge(string key,out char axis,out int x,out int z){axis='?';x=z=0;if(key==null||key.Length<5||key[1]!=':'||(key[0]!='v'&&key[0]!='h'))return false;axis=key[0];return TryCell(key.Substring(2),out x,out z);}
 public static void Sides(string edge,out string a,out string b){TryEdge(edge,out char axis,out int x,out int z);a=axis=='v'?Cell(x-1,z):Cell(x,z-1);b=Cell(x,z);}
 public static IEnumerable<string> CellEdges(int x,int z){yield return Edge('v',x,z);yield return Edge('v',x+1,z);yield return Edge('h',x,z);yield return Edge('h',x,z+1);}
 public static IEnumerable<string> Cells(int x,int z,int w,int d){for(int i=0;i<w;i++)for(int j=0;j<d;j++)yield return Cell(x+i,z+j);}
 public static IEnumerable<string> Boundary(int x,int z,int w,int d){for(int i=0;i<w;i++){yield return Edge('h',x+i,z);yield return Edge('h',x+i,z+d);}for(int j=0;j<d;j++){yield return Edge('v',x,z+j);yield return Edge('v',x+w,z+j);}}
 public static IEnumerable<string> Inside(int x,int z,int w,int d){for(int i=1;i<w;i++)for(int j=0;j<d;j++)yield return Edge('v',x+i,z+j);for(int i=0;i<w;i++)for(int j=1;j<d;j++)yield return Edge('h',x+i,z+j);}
 // Doors are centered on a side: one edge on odd lengths, a double door on even lengths, so HotelModel.DoorPosition stays exact. Sides: 0 +x, 1 +z, 2 -x, 3 -z.
 public static IEnumerable<string> DoorEdges(int x,int z,int w,int d,int side){bool ew=side==0||side==2;int length=ew?d:w;for(int i=(length-1)/2;i<=length/2;i++)yield return side==0?Edge('v',x+w,z+i):side==1?Edge('h',x+i,z+d):side==2?Edge('v',x,z+i):Edge('h',x+i,z);}
 public static bool Indoor(FloorState f,string cell){return f!=null&&f.cells.ContainsKey(cell);}
 public static bool Exterior(FloorState f,string edge){Sides(edge,out var a,out var b);return Indoor(f,a)!=Indoor(f,b);}
 // wall, door, window, open (archway), or null for open floor and bare land.
 public static string WallAt(FloorState f,string edge){Sides(edge,out var a,out var b);bool ia=Indoor(f,a),ib=Indoor(f,b);if(!ia&&!ib)return null;if(f.edges.TryGetValue(edge,out var e))return e.kind;return ia!=ib?"wall":null;}
 public static double Price(string kind){return kind=="wall"?WallPrice:kind=="door"?DoorPrice:kind=="window"?WindowPrice:kind=="open"?OpenPrice:0;}
 public static IEnumerable<string> Edges(FloorState f){var seen=new HashSet<string>();foreach(var c in f.cells.Keys){TryCell(c,out int x,out int z);foreach(var e in CellEdges(x,z))if(seen.Add(e))yield return e;}}
 public static void EdgeCenter(string edge,out float x,out float z){TryEdge(edge,out char axis,out int ex,out int ez);x=axis=='v'?ex:ex+.5f;z=axis=='v'?ez+.5f:ez;}
}
public static class ShellMigration {
 // v2 rooms were free-standing boxes; v3 keeps each as a shell island with room-owned walls, so migrated hotels look and route the same.
 public static bool Upgrade(HotelState s){if(s==null||s.hotels==null)return false;if(s.version==3)return true;if(s.version!=2)return false;foreach(var h in s.hotels){if(h==null)return false;if(h.floors==null)h.floors=new List<FloorState>();foreach(var r in h.rooms??new List<RoomState>())if(r!=null)r.floor=0;foreach(var o in h.objects??new List<ObjectState>())if(o!=null)o.floor=0;var ground=HotelModel.Floor(h,0,true);foreach(var r in h.rooms??new List<RoomState>()){if(r==null||!HotelModel.IndoorKind(r.kind)||r.width<1||r.depth<1||r.width>80||r.depth>80||Math.Abs(r.x)>256||Math.Abs(r.z)>256)continue;HotelModel.RoomSize(r,out float w,out float d);foreach(var c in ShellGrid.Cells(r.x,r.z,(int)w,(int)d)){ground.cells[c]=0;if(h.paths!=null&&h.paths.TryGetValue(c,out var path)){s.coins+=path.paid;h.paths.Remove(c);}}}if(h.rooms!=null)HotelModel.SyncRoomWalls(h);}s.version=3;return true;}
}
public sealed partial class HotelModel {
 public static FloorState Floor(HotelData h,int level,bool create=false){var f=h.floors.Find(v=>v!=null&&v.level==level);if(f==null&&create){f=new FloorState{level=level};h.floors.Add(f);h.floors.Sort((a,b)=>a.level.CompareTo(b.level));}return f;}
 public static bool IndoorKind(string kind){return kind=="regular"||kind=="suite"||kind=="shared";}
 static void RoomCells(RoomState r,out int x,out int z,out int w,out int d){RoomSize(r,out float fw,out float fd);x=r.x;z=r.z;w=(int)fw;d=(int)fd;}
 public static bool Interior(HotelData h,RoomState r){var f=Floor(h,r.floor);if(f==null)return false;RoomCells(r,out int x,out int z,out int w,out int d);return ShellGrid.Cells(x,z,w,d).All(f.cells.ContainsKey);}
 static IEnumerable<int> DoorSides(RoomState r){return r.kind=="shared"?new[]{0,1,2,3}:new[]{r.rotation};}
 static double Fitting(RoomState r){return Math.Round(Shell(r)*.45,MidpointRounding.AwayFromZero);}
 // Room walls are regenerated from room rectangles after every command; player-placed edges (room=="") are never touched. Doors go first so a neighbour's wall never swallows a room's only door.
 internal static void SyncRoomWalls(HotelData h){foreach(var f in h.floors){foreach(var k in f.edges.Where(e=>e.Value.room!="").Select(e=>e.Key).ToList())f.edges.Remove(k);var rooms=h.rooms.Where(v=>v.floor==f.level&&IndoorKind(v.kind)&&Interior(h,v)).ToList();foreach(var r in rooms){RoomCells(r,out int x,out int z,out int w,out int d);foreach(var e in DoorSides(r).SelectMany(s=>ShellGrid.DoorEdges(x,z,w,d,s)))if(!f.edges.ContainsKey(e))f.edges[e]=new EdgeState{kind="door",room=r.id};}foreach(var r in rooms){RoomCells(r,out int x,out int z,out int w,out int d);foreach(var e in ShellGrid.Boundary(x,z,w,d))if(!f.edges.ContainsKey(e)&&!ShellGrid.Exterior(f,e))f.edges[e]=new EdgeState{kind="wall",room=r.id};}}}
}
}
