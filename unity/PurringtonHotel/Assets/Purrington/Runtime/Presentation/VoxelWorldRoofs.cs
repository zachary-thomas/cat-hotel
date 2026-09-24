using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Phase C roof kit, shown in the exterior view. Any footprint gets a stepped voxel hip roof: each cell rises with its distance
 // from the roof edge (up to three steps), in alternating shingle bands, with an eave lip all round, a ridge cap along the top
 // and a brick chimney. Each destination has its own roof: terracotta Meadow, blue Seaside, brown cabin Forest,
 // and slate under snow with icicles at Snowcap.
 public sealed partial class VoxelWorld {
  const float RoofBase=2.84f,RoofStep=.2f;const int RoofSteps=3;
  readonly List<(Transform puff,Vector3 from,float phase)> smoke=new List<(Transform,Vector3,float)>();
  static readonly string[] RoofColors={"C07F68","7FB2C0","8C5E47","8C9BA8"};
  static readonly Vector2Int[] RoofSides={new Vector2Int(1,0),new Vector2Int(-1,0),new Vector2Int(0,1),new Vector2Int(0,-1)};
  public static Dictionary<Vector2Int,int> RoofDepths(ICollection<Vector2Int> cells){
   // Breadth-first distance from the roof edge: cells beside open air are 1, the next ring 2, and so on.
   var depth=new Dictionary<Vector2Int,int>();var queue=new Queue<Vector2Int>();
   foreach(var c in cells)if(RoofSides.Any(s=>!cells.Contains(c+s))){depth[c]=1;queue.Enqueue(c);}
   while(queue.Count>0){var c=queue.Dequeue();foreach(var s in RoofSides){var n=c+s;if(cells.Contains(n)&&!depth.ContainsKey(n)){depth[n]=depth[c]+1;queue.Enqueue(n);}}}
   return depth;
  }
  void BuildRoof(Transform root,FloorState floor){
   var roof=Group(root,"Roof");string color=RoofColors[Mathf.Clamp(currentMap,0,3)];bool snow=currentMap==3;
   var above=HotelModel.Floor(model.Hotel(),floor.level+1);var cells=new HashSet<Vector2Int>();
   foreach(var key in floor.cells.Keys){
    if(ShellGrid.Indoor(above,key))continue;ShellGrid.TryCell(key,out int x,out int z);
    // Under an upper-floor terrace the roof stays a flat ceiling slab so it never pokes through the terrace floor.
    if(above!=null&&above.cells.ContainsKey(key)){Box(roof,new Vector3((x+.5f)*Unit,RoofBase,(z+.5f)*Unit),new Vector3(Unit+.02f,.23f,Unit+.02f),Shade(color,-.14f));continue;}
    cells.Add(new Vector2Int(x,z));
   }
   if(cells.Count==0){Bake(roof);return;}
   var depth=RoofDepths(cells);int peak=Mathf.Min(RoofSteps,depth.Values.Max());
   foreach(var c in cells){
    int d=Mathf.Min(RoofSteps,depth[c]);var center=new Vector3((c.x+.5f)*Unit,0,(c.y+.5f)*Unit);
    for(int k=0;k<d;k++){bool top=k==d-1;string band=snow&&top?"F4F6F2":Shade(color,k%2==0?-.12f:-.02f);Box(roof,center+Vector3.up*(RoofBase+k*RoofStep),new Vector3(Unit+.02f,k==0?.23f:RoofStep+.01f,Unit+.02f),band);}
    if(d==peak&&peak>1)Box(roof,center+Vector3.up*(RoofBase+(peak-1)*RoofStep+.13f),new Vector3(Unit+.02f,.06f,Unit+.02f),snow?"FFFFFF":Shade(color,-.3f));
    // The eave lip overhangs every open edge; Snowcap hangs a few icicles from it.
    foreach(var s in RoofSides){
     if(cells.Contains(c+s))continue;var out3=new Vector3(s.x,0,s.y);bool alongX=s.y!=0;
     Box(roof,center+out3*(Unit/2+.1f)+Vector3.up*(RoofBase-.06f),alongX?new Vector3(Unit+.22f,.1f,.22f):new Vector3(.22f,.1f,Unit+.22f),snow?"F4F6F2":Shade(color,-.28f));
     if(snow)for(int i=0;i<3;i++){float t=(i-1)*Unit*.3f+(Hash((uint)(c.x*92821^c.y*68917),i)-.5f)*.12f;float len=.1f+Hash((uint)(c.x*31^c.y*57),i+9)*.16f;var along=alongX?Vector3.right:Vector3.forward;Box(roof,center+out3*(Unit/2+.18f)+along*t+Vector3.up*(RoofBase-.11f-len/2),new Vector3(.05f,len,.05f),"DDEFF7");}
    }
   }
   // A chimney on the deepest cell nearest the middle of the roof.
   var mid=new Vector2((float)cells.Average(c=>c.x),(float)cells.Average(c=>c.y));
   var chimneyCell=cells.Where(c=>depth[c]>=peak).OrderBy(c=>(new Vector2(c.x,c.y)-mid).sqrMagnitude).ThenBy(c=>c.x).ThenBy(c=>c.y).First();
   float topY=RoofBase+(Mathf.Min(RoofSteps,depth[chimneyCell])-1)*RoofStep+.1f;var chimney=new Vector3((chimneyCell.x+.72f)*Unit,topY,(chimneyCell.y+.3f)*Unit);
   Box(roof,chimney+Vector3.up*.3f,new Vector3(.32f,.6f,.32f),"A8604B");Box(roof,chimney+Vector3.up*.2f,new Vector3(.34f,.05f,.34f),"8E4F3D");
   Box(roof,chimney+Vector3.up*.63f,new Vector3(.42f,.08f,.42f),snow?"F4F6F2":"6E4A3B");
   Bake(roof);
   // Chimney smoke: a few soft puffs that rise, drift and fade (animated in UpdateLife; hidden with the roof in cutaway).
   for(int k=0;k<4;k++){var puff=Group(roof,"Chimney smoke");Box(puff,Vector3.zero,Vector3.one*.28f,"E9E6DF");smoke.Add((puff,chimney+Vector3.up*.75f,k/4f));}
  }
 }
}
