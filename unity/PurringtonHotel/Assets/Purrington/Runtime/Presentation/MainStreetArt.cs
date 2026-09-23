using System;
using System.Collections.Generic;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Exterior geometry uses the same coordinates as navigation. Shops flank the hotel facing the road; the plaza sits across the road from the hotel gate.
 public sealed class MainStreetArt {
  public readonly Transform Root;
  public readonly Dictionary<string,Transform> Storefronts=new Dictionary<string,Transform>();
  public readonly Bounds SquareBounds;
  readonly GodotGeometry geometry; readonly TownContent content;
  const float U=VoxelWorld.Unit;
  public const float SidewalkMinX=-35,SidewalkMaxX=35,SidewalkMinZ=18.3f,SidewalkMaxZ=20;
  // Lot-unit areas Main Street owns (plaza across the road, both shop lots); neighbor houses and lawn trees inside them are not built.
  // Shop lots sit beyond the hotel's buyable east and west plots (x ±12..20) so the hotel can still grow.
  static readonly Rect[] Cleared={Rect.MinMaxRect(-13,18,17,34),Rect.MinMaxRect(21,-1,35,12.6f),Rect.MinMaxRect(-35,-1,-21,12.6f)};
  public static bool KeepScenery(Vector3 godot){var p=new Vector2(godot.x/U,godot.z/U);foreach(var r in Cleared)if(r.Contains(p))return false;return true;}
  public MainStreetArt(GodotGeometry geometry,Transform parent,TownContent content){
   this.geometry=geometry;this.content=content;Root=Group(parent,"Meadow Main Street");
   var q=content.Point("square");SquareBounds=new Bounds(new Vector3(q.x*U,0,q.z*U),new Vector3(16*U,1,10*U));
   var paving=Group(Root,"Walkable paving");
   // One sidewalk along the far side of the road; nothing is laid on the asphalt except the zebra crossing.
   Box(paving,"Sidewalk",new Vector3(0,.11f,(SidewalkMinZ+SidewalkMaxZ)/2*U),new Vector3((SidewalkMaxX-SidewalkMinX)*U,.16f,(SidewalkMaxZ-SidewalkMinZ)*U),"E4DCCB");
   Box(paving,"Kerb",new Vector3(0,.2f,SidewalkMinZ*U),new Vector3((SidewalkMaxX-SidewalkMinX)*U,.08f,.16f),"BBB6A5");
   var gate=content.Point("hotel_gate");
   for(float z=gate.z+.7f;z<SidewalkMinZ-.3f;z+=.9f)Box(paving,"Zebra stripe",new Vector3(gate.x*U,.075f,z*U),new Vector3(2.6f*U,.03f,.45f*U),"F4F1E8");
   // The plaza sits across the road from the hotel gate.
   for(int x=-8;x<8;x++)for(int z=-5;z<5;z++)Box(paving,"Square stone",new Vector3((q.x+x+.5f)*U,.13f,(q.z+z+.5f)*U),new Vector3(U-.03f,.16f,U-.03f),(x+z)%3==0?"D9CFBC":"E4DCCB");
   Store("paw_mart","PAW MART",false);Store("clothing","CLOTHING",true);
   HotelSign(gate);
   // Plaza furniture keeps to the edges so the middle stays open for Market Day.
   foreach(int side in new[]{-1,1}){
    float bx=(q.x+side*5.5f)*U,bz=(q.z+3.6f)*U;
    var bench=Group(Root,"Timber bench");Box(bench,"Seat",new Vector3(bx,.65f,bz),new Vector3(2,.2f,.7f),"B3824C");Box(bench,"Back",new Vector3(bx,1,bz+.3f),new Vector3(2,.7f,.14f),"D2AD77");
    foreach(float leg in new[]{-.7f,.7f})Box(bench,"Leg",new Vector3(bx+leg,.34f,bz),new Vector3(.18f,.6f,.55f),"425C35");
    foreach(float lz in new[]{q.z-4.4f,q.z+4.4f}){var lamp=Group(Root,"Square lamp");float lx=(q.x+side*7.4f)*U;Box(lamp,"Post",new Vector3(lx,1.65f,lz*U),new Vector3(.18f,3.1f,.18f),"425C35");Box(lamp,"Lantern",new Vector3(lx,3.2f,lz*U),new Vector3(.48f,.6f,.48f),"D7AE55");}
    float px=(q.x+side*2.6f)*U,pz=(q.z+4.3f)*U;Box(Root,"Stone planter",new Vector3(px,.45f,pz),new Vector3(.9f,.7f,.9f),"BF7958");Box(Root,"Foliage",new Vector3(px,.9f,pz),new Vector3(1.1f,.5f,1.1f),"738448");
   }
  }
  void Store(string id,string title,bool boutique){
   var store=content.Shop(id);var f=store.footprint;var root=Group(Root,id);Storefronts[id]=root;
   float x=(f.x+f.w/2)*U,z=(f.z+f.d/2)*U,front=(f.z+f.d)*U;
   var shell=Box(root,"Opaque shell",new Vector3(x,1.9f,z),new Vector3(f.w*U,3.6f,f.d*U),"EFE2C9");Hit(shell,id);
   Box(root,"Opaque roof",new Vector3(x,3.95f,z),new Vector3(f.w*U,.55f,f.d*U),boutique?"BF7958":"425C35");
   Box(root,"Timber cornice",new Vector3(x,3.5f,front+.08f),new Vector3(f.w*U,.22f,.3f),"B3824C");
   var door=Box(root,"Door",new Vector3(x,1.2f,front+.12f),new Vector3(1.3f,2.2f,.23f),"425C35");Hit(door,id);
   Box(root,"Door handle",new Vector3(x+.4f,1.2f,front+.27f),new Vector3(.09f,.3f,.07f),"D7AE55");
   // Voxel lettering on a parapet above the roofline replaces the floating label; the world is z-mirrored, so road-facing letters flip in z.
   Box(root,"Sign parapet",new Vector3(x,4.95f,front-.1f),new Vector3(Mathf.Min(f.w*U-.6f,VoxelLetters.Width(title,.21f)+1.2f),1.9f,.24f),"244335");
   var letters=geometry.Build(root,VoxelLetters.Recipe("Store sign "+title,title,.21f,.12f,"F4EAD5"));letters.localPosition=new Vector3(x,4.95f,front+.02f);letters.localScale=new Vector3(1,1,-1);
   foreach(float offset in new[]{-3.6f,3.6f}){
    Box(root,"Window frame",new Vector3(x+offset,1.6f,front+.12f),new Vector3(2.7f,1.8f,.24f),"B3824C");
    Box(root,"Opaque display",new Vector3(x+offset,1.6f,front+.27f),new Vector3(2.35f,1.5f,.08f),"DCE5C5");
    Box(root,"Awning",new Vector3(x+offset,2.65f,front+.35f),new Vector3(3,.25f,1.2f),boutique?"BF7958":"738448");
    if(boutique){Box(root,"Display mannequin",new Vector3(x+offset,1.5f,front+.36f),new Vector3(.5f,.8f,.12f),"D6A182");Box(root,"Display head",new Vector3(x+offset,2.05f,front+.36f),new Vector3(.35f,.35f,.12f),"D7AE55");}
    else foreach(float item in new[]{-.65f,0,.65f})Box(root,"Produce display",new Vector3(x+offset+item,1.4f,front+.36f),new Vector3(.45f,.4f,.12f),item==0?"D7AE55":"BF7958");
   }
   // A short paved apron joins the door to the sidewalk.
   var doorNode=content.Point(store.door);Box(root,"Door apron",new Vector3(x,.12f,(front+doorNode.z*U)/2),new Vector3(2.4f,.16f,Mathf.Abs(doorNode.z*U-front)+.4f),"E4DCCB");
  }
  // The hotel gets the same voxel signature as the shops: an arch over its gate with lettering toward the road.
  void HotelSign(LotPoint gate){
   var sign=Group(Root,"Hotel sign");float gx=gate.x*U,gz=(gate.z-.35f)*U;const string title="PURRINGTON";
   float width=VoxelLetters.Width(title,.18f)+1;
   foreach(float side in new[]{-1f,1f})Box(sign,"Arch post",new Vector3(gx+side*width/2,1.9f,gz),new Vector3(.3f,3.8f,.3f),"B3824C");
   Box(sign,"Arch beam",new Vector3(gx,3.6f,gz),new Vector3(width+.5f,1.55f,.22f),"244335");
   Box(sign,"Arch cap",new Vector3(gx,4.45f,gz),new Vector3(width+.8f,.16f,.4f),"B3824C");
   var letters=geometry.Build(sign,VoxelLetters.Recipe("Hotel sign letters",title,.18f,.1f,"F7CC62"));letters.localPosition=new Vector3(gx,3.6f,gz+.11f);letters.localScale=new Vector3(1,1,-1);
  }
  static void Hit(Transform node,string id){node.gameObject.AddComponent<BoxCollider>();node.gameObject.AddComponent<TownStoreHit>().StoreId=id;}
  internal static Transform Group(Transform parent,string name){var t=new GameObject(name).transform;t.SetParent(parent,false);return t;}
  Transform Box(Transform parent,string name,Vector3 at,Vector3 size,string color){return geometry.Build(parent,ManagerCatArt.Node(name,at,size,color));}
  public bool IsPaved(Vector3 point){if(SquareBounds.Contains(new Vector3(point.x*U,0,point.z*U)))return true;return StreetTarget(content,new LotPoint(point.x,point.z))!=null;}
  public static string StreetTarget(TownContent content,LotPoint point){
   string nearest=content.NearestStreetTarget(point,1.25f);if(nearest!=null)return nearest;
   float best=1.25f;string target=null;
   foreach(var a in content.StreetIds)foreach(var b in content.Neighbors(a)){
    var p=content.Point(a);var q=content.Point(b);var start=new Vector2(p.x,p.z);var delta=new Vector2(q.x-p.x,q.z-p.z);
    float t=Mathf.Clamp01(Vector2.Dot(new Vector2(point.x,point.z)-start,delta)/delta.sqrMagnitude);
    float distance=Vector2.Distance(new Vector2(point.x,point.z),start+delta*t);
    if(distance<=best){best=distance;var endpoint=t<.5f?p:q;target=content.NearestStreetTarget(endpoint,.01f);}
   }
   return target;
  }
 }
 public sealed class TownStoreHit:MonoBehaviour {public string StoreId;}
 // Future interiors must carry this marker so exterior tests catch accidental activation.
 public sealed class TownInterior:MonoBehaviour {}
}
