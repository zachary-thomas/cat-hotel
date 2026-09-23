using System.Collections.Generic;
using UnityEngine;
namespace Purrington.Presentation {
 // One floor plan per shop, shared by the street shell and the dollhouse interior so both always have the same shape.
 // Plan space: x across the shop, -z is the street side with the front door; rects are room floors, walls sit on their edges.
 public sealed class ShopPlan {
  public sealed class Room {public string name,floor;public Rect rect;public float height;}
  public struct Wall {public Vector3 at,size,normal;public bool exterior;}
  public const float Thickness=.3f,DoorGap=1.4f,InnerGap=1.3f;
  public readonly Room[] Rooms;public readonly float DoorX;public readonly Vector2[] Doorways;
  public readonly Rect Bounds;
  // Size of the building including walls, which is also the shop's authored lot footprint (in world units).
  public Vector2 Size=>new Vector2(Bounds.width+Thickness,Bounds.height+Thickness);
  ShopPlan(float doorX,Vector2[] doorways,params Room[] rooms){
   Rooms=rooms;DoorX=doorX;Doorways=doorways;var b=rooms[0].rect;
   foreach(var r in rooms)b=Rect.MinMaxRect(Mathf.Min(b.xMin,r.rect.xMin),Mathf.Min(b.yMin,r.rect.yMin),Mathf.Max(b.xMax,r.rect.xMax),Mathf.Max(b.yMax,r.rect.yMax));
   Bounds=b;
  }
  static Room R(string name,float x0,float z0,float x1,float z1,string floor,float height)=>new Room{name=name,rect=Rect.MinMaxRect(x0,z0,x1,z1),floor=floor,height=height};
  // Paw Mart: a grocery hall at the door, a fresh market wing set back beside a café patio, and a stockroom behind.
  public static readonly ShopPlan PawMart=new ShopPlan(-2.25f,new[]{new Vector2(1.5f,-1.2f),new Vector2(-2.4f,1.5f)},
   R("Grocery hall",-6,-4.75f,1.5f,1.5f,"D2AD77",3.6f),R("Fresh market",1.5f,-2.25f,6,4.75f,"DCE5C5",3.2f),R("Stockroom",-6,1.5f,1.5f,4.75f,"CAC4B2",3.2f));
  // Clothing: a boutique floor at the door, a fitting room set back beside a garden nook, and an accessory salon behind.
  public static readonly ShopPlan Clothing=new ShopPlan(1.75f,new[]{new Vector2(-1.75f,-.6f),new Vector2(-1.75f,2.6f),new Vector2(.4f,.75f)},
   R("Boutique",-1.75f,-4.5f,5.25f,.75f,"D2AD77",3.6f),R("Fitting room",-5.25f,-2,-1.75f,4.5f,"E8D3B2",3.2f),R("Accessory salon",-1.75f,.75f,5.25f,4.5f,"E6D5E8",3.2f));
  public static ShopPlan For(string id)=>id=="paw_mart"?PawMart:id=="clothing"?Clothing:null;
  // Exterior edges become full walls (the front door leaves a gap); edges shared by two rooms become low partitions with a doorway.
  public List<Wall> Walls(){
   var walls=new List<Wall>();
   for(int i=0;i<Rooms.Length;i++){
    var r=Rooms[i].rect;
    Edge(walls,i,true,r.yMin,r.xMin,r.xMax,Vector3.back);Edge(walls,i,true,r.yMax,r.xMin,r.xMax,Vector3.forward);
    Edge(walls,i,false,r.xMin,r.yMin,r.yMax,Vector3.left);Edge(walls,i,false,r.xMax,r.yMin,r.yMax,Vector3.right);
   }
   return walls;
  }
  // An edge runs along x (alongX) at z=c, or along z at x=c, from a to b.
  void Edge(List<Wall> walls,int index,bool alongX,float c,float a,float b,Vector3 normal){
   var shared=new List<(float a,float b,bool mine)>();
   for(int j=0;j<Rooms.Length;j++){
    if(j==index)continue;var o=Rooms[j].rect;
    float oc=alongX?(normal.z<0?o.yMax:o.yMin):(normal.x<0?o.xMax:o.xMin);if(Mathf.Abs(oc-c)>.01f)continue;
    float lo=Mathf.Max(a,alongX?o.xMin:o.yMin),hi=Mathf.Min(b,alongX?o.xMax:o.yMax);if(hi-lo>.01f)shared.Add((lo,hi,index<j));
   }
   shared.Sort((x,y)=>x.a.CompareTo(y.a));
   float cursor=a;
   foreach(var s in shared){
    if(s.a>cursor)Segments(walls,alongX,c,cursor,s.a,normal,true);
    if(s.mine)Segments(walls,alongX,c,s.a,s.b,normal,false);
    cursor=s.b;
   }
   if(b>cursor)Segments(walls,alongX,c,cursor,b,normal,true);
  }
  void Segments(List<Wall> walls,bool alongX,float c,float a,float b,Vector3 normal,bool exterior){
   var gaps=new List<(float a,float b)>();
   if(exterior&&alongX&&Mathf.Abs(c-Bounds.yMin)<.01f&&DoorX>a&&DoorX<b)gaps.Add((DoorX-DoorGap/2,DoorX+DoorGap/2));
   if(!exterior)foreach(var d in Doorways){float along=alongX?d.x:d.y,across=alongX?d.y:d.x;if(Mathf.Abs(across-c)<.01f&&along>a&&along<b)gaps.Add((along-InnerGap/2,along+InnerGap/2));}
   // Exterior runs reach past both corners so neighbouring walls close without notches.
   float start=exterior?a-Thickness/2:a,end=exterior?b+Thickness/2:b;
   foreach(var g in gaps){Add(walls,alongX,c,start,g.a,normal,exterior);start=g.b;}
   Add(walls,alongX,c,start,end,normal,exterior);
  }
  static void Add(List<Wall> walls,bool alongX,float c,float a,float b,Vector3 normal,bool exterior){
   if(b-a<.05f)return;float mid=(a+b)/2,length=b-a;
   walls.Add(new Wall{at=alongX?new Vector3(mid,0,c):new Vector3(c,0,mid),size=alongX?new Vector3(length,0,Thickness):new Vector3(Thickness,0,length),normal=normal,exterior=exterior});
  }
 }
}
