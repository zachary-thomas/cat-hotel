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
 public JObject RoomDraft(int x0,int z0,int x1,int z1,string kind,int level=0){int x=Math.Min(x0,x1),z=Math.Min(z0,z1),fw=Math.Abs(x1-x0)+1,fd=Math.Abs(z1-z0)+1;var h=Hotel();var f=Floor(h,level);int rotation=RoomShape(new RoomState{kind=kind,width=fw,depth=fd})?0:1;int door=0,bestScore=-1;foreach(int side in new[]{1,0,3,2}){int score=2;foreach(var e in ShellGrid.DoorEdges(x,z,fw,fd,side)){ShellGrid.EdgeCenter(e,out float ex,out float ez);float ox=side==0?ex+.5f:side==2?ex-.5f:ex,oz=side==1?ez+.5f:side==3?ez-.5f:ez;bool indoor=ShellGrid.Indoor(f,ShellGrid.Cell((int)Math.Floor(ox),(int)Math.Floor(oz)));bool inRoom=h.rooms.Any(r=>r.floor==level&&RoomHas(r,ox,oz));score=Math.Min(score,inRoom?0:indoor?2:1);}if(score>bestScore){door=side;bestScore=score;}}return new JObject{{"kind",kind},{"x",x},{"y",z},{"w",rotation==0?fw:fd},{"h",rotation==0?fd:fw},{"rotation",rotation},{"door",door},{"floor",level},{"buy",true}};}
}
}
