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
  // Street edge of the hotel-side sidewalk (lot units); shop gardens end here.
  public const float HotelSidewalkZ=12.025f;
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
   Box(paving,"Hotel-side sidewalk",new Vector3(0,.11f,12.5f*U),new Vector3((SidewalkMaxX-SidewalkMinX)*U,.16f,.95f*U),"E4DCCB");
   Box(paving,"Hotel-side kerb",new Vector3(0,.2f,12.98f*U),new Vector3((SidewalkMaxX-SidewalkMinX)*U,.08f,.16f),"BBB6A5");
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
    foreach(float lz in new[]{q.z-4.4f,q.z+4.4f}){var lamp=Group(Root,"Square lamp");float lx=(q.x+side*7.4f)*U;Box(lamp,"Post",new Vector3(lx,1.65f,lz*U),new Vector3(.18f,3.1f,.18f),"425C35");LampAnchor.Mark(Box(lamp,"Lantern",new Vector3(lx,3.2f,lz*U),new Vector3(.48f,.6f,.48f),SurfacePalette.LanternGlow),4.5f);}
    float px=(q.x+side*2.6f)*U,pz=(q.z+4.3f)*U;Box(Root,"Stone planter",new Vector3(px,.45f,pz),new Vector3(.9f,.7f,.9f),"BF7958");Box(Root,"Foliage",new Vector3(px,.9f,pz),new Vector3(1.1f,.5f,1.1f),"738448");
   }
   Decorate(q);
  }
  // Plaza dressing stays on the rim: bunting between the far lamps, trees in planters at each end and flower beds by the sidewalk.
  void Decorate(LotPoint q){
   var decor=Group(Root,"Square decorations");
   foreach(float lz in new[]{q.z+4.4f}){
    float x0=(q.x-7.4f)*U,x1=(q.x+7.4f)*U,z=lz*U;
    Box(decor,"Bunting string",new Vector3((x0+x1)/2,3.05f,z),new Vector3(x1-x0,.04f,.04f),"F4F1E8");
    int i=0;for(float x=x0+.5f;x<x1-.3f;x+=.55f,i++){float sag=.25f*(1-Mathf.Pow(2*(x-x0)/(x1-x0)-1,2));Box(decor,"Bunting flag",new Vector3(x,2.88f-sag,z),new Vector3(.3f,.3f,.05f),Blooms[i%Blooms.Length]);Box(decor,"Bunting flag tip",new Vector3(x,2.68f-sag,z),new Vector3(.14f,.12f,.05f),Blooms[i%Blooms.Length]);}
   }
   foreach(int side in new[]{-1,1}){
    float tx=(q.x+side*7.3f)*U,tz=(q.z+.2f)*U;var tree=Group(decor,"Planter tree");
    Box(tree,"Round planter",new Vector3(tx,.4f,tz),new Vector3(1.3f,.6f,1.3f),"E4DCCB");Box(tree,"Planter soil",new Vector3(tx,.72f,tz),new Vector3(1.1f,.08f,1.1f),"8A6B4F");
    Box(tree,"Trunk",new Vector3(tx,1.5f,tz),new Vector3(.28f,1.6f,.28f),"8A6B4F");
    Box(tree,"Canopy",new Vector3(tx,2.5f,tz),new Vector3(1.6f,.9f,1.6f),"738448");Box(tree,"Canopy",new Vector3(tx,3.15f,tz),new Vector3(1.1f,.6f,1.1f),"8FA35E");
    for(int k=0;k<4;k++)Box(tree,"Blossom",new Vector3(tx+(k%2==0?-.5f:.5f),2.95f,tz+(k<2?-.5f:.5f)),new Vector3(.2f,.2f,.2f),k%2==0?"F2A7B5":"F4F1E8");
   }
   // Flower beds along the sidewalk edge either side of the market arch and the crosswalk path.
   foreach(var bed in new[]{(a:1.8f,b:6.8f),(a:-6.8f,b:-1.8f)}){
    float mid=(q.x+(bed.a+bed.b)/2)*U,w=(bed.b-bed.a)*U,z=(q.z-4.6f)*U;
    Box(decor,"Flower bed edging",new Vector3(mid,.24f,z),new Vector3(w,.18f,.7f),"BBB6A5");Box(decor,"Flower bed soil",new Vector3(mid,.3f,z),new Vector3(w-.15f,.08f,.5f),"8A6B4F");
    int i=0;for(float x=mid-w/2+.2f;x<mid+w/2-.1f;x+=.34f,i++){Box(decor,"Flower stem",new Vector3(x,.44f,z+(i%2==0?-.1f:.1f)),new Vector3(.06f,.2f,.06f),"738448");Box(decor,"Flower bloom",new Vector3(x,.58f,z+(i%2==0?-.1f:.1f)),new Vector3(.17f,.13f,.17f),Blooms[(i+2)%Blooms.Length]);}
   }
   foreach(int side in new[]{-1,1})PawMartArt.Plant((n,x,y,z,w,h,d,c)=>Box(decor,n,new Vector3(x,y+.13f,z),new Vector3(w,h,d),c),(q.x+side*3.6f)*U,(q.z+4.3f)*U);
  }
  // Street signs share one letter size so the shops and the hotel read at the same, cat-appropriate scale.
  public const float SignPixel=.065f;
  static readonly string[] Blooms={"F2A7B5","F7CC62","C9B6E4","F4F1E8","E6B7C1"};
  void Store(string id,string title,bool boutique){
   var store=content.Shop(id);var f=store.footprint;var plan=ShopPlan.For(id);var root=Group(Root,id);Storefronts[id]=root;
   float cx=(f.x+f.w/2)*U,cz=(f.z+f.d/2)*U,T=ShopPlan.Thickness;
   // Plan space turns half a circle onto the street, exactly as StoreInteriorView.Place does, so the shell hugs the rooms.
   Vector3 W(float lx,float y,float lz)=>new Vector3(cx-lx,y,cz-lz);
   var shell=Group(root,"Opaque shell");var roof=Group(root,"Opaque roof");
   string roofColor=boutique?"BF7958":"425C35",wingRoof=boutique?"D98FA3":"5F7040";
   foreach(var room in plan.Rooms){
    var r=room.rect;bool main=r.yMin<=plan.Bounds.yMin+.01f;
    Hit(Box(shell,room.name+" shell",W(r.center.x,.1f+room.height/2,r.center.y),new Vector3(r.width+T,room.height,r.height+T),main?"EFE2C9":boutique?"F4E4D8":"E8DDC4"),id);
    Box(roof,room.name+" roof",W(r.center.x,.37f+room.height,r.center.y),new Vector3(r.width+T+.2f,.55f,r.height+T+.2f),main?roofColor:wingRoof);
    float front=cz-r.yMin+T/2,left=cx-r.xMax,right=cx-r.xMin;
    Box(root,"Timber cornice",new Vector3((left+right)/2,room.height-.05f,front+.08f),new Vector3(right-left+T,.2f,.3f),"B3824C");
    // Set-back wings show one window with a flower box toward the street.
    if(!main&&r.yMin<0)Window(root,(left+right)/2,front,boutique,room.height);
   }
   float x=cx-plan.DoorX,front0=cz-plan.Bounds.yMin+T/2;
   var door=Box(root,"Door",new Vector3(x,1.1f,front0+.12f),new Vector3(1.2f,2.1f,.23f),"425C35");Hit(door,id);
   Box(root,"Door handle",new Vector3(x+.38f,1.1f,front0+.27f),new Vector3(.09f,.3f,.07f),"D7AE55");
   Box(root,"Door step",new Vector3(x,.14f,front0+.4f),new Vector3(1.6f,.12f,.6f),"D9CFBC");
   float boardWidth=VoxelLetters.Width(title,SignPixel)+.4f;
   Hit(Box(root,"Shop signboard",new Vector3(x,3.05f,front0+.14f),new Vector3(boardWidth,.62f,.1f),"244335"),id); // the signboard is a tap target too
   var letters=geometry.Build(root,VoxelLetters.Recipe("Store sign "+title,title,SignPixel,.05f,"F4EAD5"));letters.localPosition=new Vector3(x,3.05f,front0+.19f);letters.localScale=new Vector3(1,1,-1);
   foreach(float offset in new[]{-2.1f,2.1f})Window(root,x+offset,front0,boutique,3.6f);
   Yard(id,plan,cx,cz,boutique);
  }
  void Window(Transform root,float x,float front,bool boutique,float height){
   Box(root,"Window frame",new Vector3(x,1.45f,front+.12f),new Vector3(1.8f,1.5f,.24f),"B3824C");
   Box(root,"Opaque display",new Vector3(x,1.45f,front+.27f),new Vector3(1.5f,1.22f,.08f),"DCE5C5");
   Box(root,"Window mullion",new Vector3(x,1.45f,front+.3f),new Vector3(.08f,1.22f,.04f),"B3824C");
   // Striped awning: alternating bands along the width.
   for(int i=0;i<5;i++)Box(root,"Awning stripe",new Vector3(x-.84f+i*.42f,Mathf.Min(2.4f,height-.9f),front+.5f),new Vector3(.42f,.18f,.9f),i%2==0?(boutique?"BF7958":"738448"):"F4F1E8");
   Box(root,"Window box",new Vector3(x,.72f,front+.36f),new Vector3(1.7f,.26f,.34f),"B3824C");
   for(int i=0;i<6;i++){float bx=x-.7f+i*.28f;Box(root,"Window box leaves",new Vector3(bx,.92f,front+.36f),new Vector3(.24f,.16f,.24f),"738448");Box(root,"Window box bloom",new Vector3(bx,1.04f,front+.36f),new Vector3(.14f,.12f,.14f),Blooms[i%Blooms.Length]);}
  }
  // Each shop sits back from the sidewalk behind a front garden: a stepping-stone path, flower beds, a picket fence and lamps.
  // The yard is not part of the storefront, so it stays in view while the dollhouse interior is open.
  void Yard(string id,ShopPlan plan,float cx,float cz,bool boutique){
   var yard=Group(Root,id+" front garden");float T=ShopPlan.Thickness;
   float front=cz-plan.Bounds.yMin+T/2,fence=HotelSidewalkZ*U-.25f,door=cx-plan.DoorX,left=cx-plan.Bounds.xMax-T/2,right=cx-plan.Bounds.xMin+T/2;
   int step=0;for(float z=front+.75f;z<fence+.2f;z+=.55f,step++)Box(yard,"Stepping stone",new Vector3(door+(step%2==0?-.08f:.08f),.1f,z),new Vector3(1.1f,.08f,.42f),step%3==0?"D9CFBC":"E4DCCB");
   // The main room's frontage between the side walls, split by the path.
   var main=plan.Rooms[0].rect;float mainLeft=cx-main.xMax-T/2,mainRight=cx-main.xMin+T/2;
   foreach(var bed in new[]{(a:mainLeft+.2f,b:door-1),(a:door+1,b:mainRight-.2f)}){
    if(bed.b-bed.a<.6f)continue;float mid=(bed.a+bed.b)/2,z=front+.75f;
    Box(yard,"Flower bed edging",new Vector3(mid,.12f,z),new Vector3(bed.b-bed.a+.1f,.16f,.8f),"BBB6A5");
    Box(yard,"Flower bed soil",new Vector3(mid,.17f,z),new Vector3(bed.b-bed.a-.1f,.1f,.6f),"8A6B4F");
    int i=0;for(float bx=bed.a+.2f;bx<bed.b-.1f;bx+=.36f,i++){float bz=z+(i%2==0?-.12f:.14f);Box(yard,"Flower stem",new Vector3(bx,.32f,bz),new Vector3(.06f,.24f,.06f),"738448");Box(yard,"Flower bloom",new Vector3(bx,.47f,bz),new Vector3(.18f,.14f,.18f),Blooms[i%Blooms.Length]);}
   }
   // White picket fence along the sidewalk with a gap for the path.
   foreach(var run in new[]{(a:left,b:door-.8f),(a:door+.8f,b:right)}){
    if(run.b-run.a<.3f)continue;
    foreach(float y in new[]{.3f,.55f})Box(yard,"Fence rail",new Vector3((run.a+run.b)/2,y,fence),new Vector3(run.b-run.a,.07f,.05f),"F4F1E8");
    for(float px=run.a+.1f;px<=run.b;px+=.32f)Box(yard,"Picket",new Vector3(px,.38f,fence),new Vector3(.12f,.6f,.07f),"F4F1E8");
    foreach(float px in new[]{run.a,run.b})Box(yard,"Fence post",new Vector3(px,.42f,fence),new Vector3(.16f,.74f,.16f),"E4DCCB");
   }
   foreach(float side in new[]{-1.05f,1.05f}){var lamp=Group(yard,"Garden lamp");Box(lamp,"Post",new Vector3(door+side,1.05f,fence-.25f),new Vector3(.14f,1.9f,.14f),"425C35");LampAnchor.Mark(Box(lamp,"Lantern",new Vector3(door+side,2.1f,fence-.25f),new Vector3(.36f,.46f,.36f),SurfacePalette.LanternGlow),3.4f,.8f);}
   // The notch beside the set-back wing becomes a patio: a café corner for Paw Mart, a garden nook for the boutique.
   var wing=System.Array.Find(plan.Rooms,r=>r.rect.yMin>plan.Bounds.yMin+.01f&&r.rect.yMin<0).rect;
   float px0=cx-wing.xMax-T/2,px1=cx-wing.xMin+T/2,nz0=cz-wing.yMin+T/2,nz1=front;
   // Clear of the main room's side wall.
   if(px1>mainLeft&&px1<mainRight)px1=mainLeft;if(px0<mainRight&&px0>mainLeft)px0=mainRight;
   float pcx=(px0+px1)/2,pcz=(nz0+nz1)/2,depth=(nz1-nz0-.2f)/5;
   for(int i=0;i<5;i++)Box(yard,"Patio deck",new Vector3(pcx,.1f,nz0+.1f+(i+.5f)*depth),new Vector3(px1-px0-.1f,.08f,depth-.03f),i%2==0?"D2AD77":"C9A674");
   if(!boutique){
    var cafe=Group(yard,"Cafe corner");
    Box(cafe,"Cafe table",new Vector3(pcx,.62f,pcz),new Vector3(.9f,.08f,.9f),"F4F1E8");Box(cafe,"Table stem",new Vector3(pcx,.36f,pcz),new Vector3(.12f,.5f,.12f),"425C35");
    Box(cafe,"Umbrella pole",new Vector3(pcx,1.4f,pcz),new Vector3(.07f,2.2f,.07f),"B3824C");
    Box(cafe,"Umbrella canopy",new Vector3(pcx,2.45f,pcz),new Vector3(1.9f,.12f,1.9f),"BF7958");Box(cafe,"Umbrella canopy",new Vector3(pcx,2.57f,pcz),new Vector3(1.3f,.12f,1.3f),"F4F1E8");Box(cafe,"Umbrella canopy",new Vector3(pcx,2.69f,pcz),new Vector3(.6f,.12f,.6f),"BF7958");
    foreach(float side in new[]{-.85f,.85f}){Box(cafe,"Cafe stool",new Vector3(pcx+side,.42f,pcz),new Vector3(.45f,.08f,.45f),"738448");Box(cafe,"Stool leg",new Vector3(pcx+side,.22f,pcz),new Vector3(.1f,.36f,.1f),"425C35");}
    Box(cafe,"Teacup",new Vector3(pcx+.2f,.72f,pcz),new Vector3(.14f,.12f,.14f),"9FB7C9");
    for(int i=0;i<2;i++){float bx=px0+.5f+i*.75f,bz=nz1-.4f;Box(cafe,"Produce crate",new Vector3(bx,.3f,bz),new Vector3(.65f,.4f,.5f),"B3824C");for(int k=0;k<3;k++)Box(cafe,"Crate fruit",new Vector3(bx-.2f+k*.2f,.55f,bz),new Vector3(.17f,.15f,.17f),i==0?"BF7958":"D7AE55");}
   }else{
    var nook=Group(yard,"Garden nook");
    Box(nook,"Garden bench seat",new Vector3(pcx,.5f,nz0+.95f),new Vector3(1.6f,.12f,.5f),"F4F1E8");Box(nook,"Garden bench back",new Vector3(pcx,.85f,nz0+.73f),new Vector3(1.6f,.55f,.1f),"F4F1E8");
    foreach(float side in new[]{-.65f,.65f})Box(nook,"Bench leg",new Vector3(pcx+side,.26f,nz0+.95f),new Vector3(.12f,.36f,.4f),"BBB6A5");
    foreach(float side in new[]{-1f,1f}){float tx=pcx+side*1.2f,tz=nz1-.5f;Box(nook,"Topiary pot",new Vector3(tx,.3f,tz),new Vector3(.45f,.45f,.45f),"BF7958");Box(nook,"Topiary",new Vector3(tx,.8f,tz),new Vector3(.55f,.55f,.55f),"738448");Box(nook,"Topiary",new Vector3(tx,1.2f,tz),new Vector3(.35f,.3f,.35f),"8FA35E");}
    Box(nook,"Bird bath",new Vector3(pcx,.35f,nz1-.55f),new Vector3(.2f,.5f,.2f),"E4DCCB");Box(nook,"Bird bath bowl",new Vector3(pcx,.64f,nz1-.55f),new Vector3(.6f,.1f,.6f),"9FB7C9");
   }
  }
  // The hotel's signature is a small timber arch over its gate path, high enough for cats to walk beneath.
  void HotelSign(LotPoint gate){
   var sign=Group(Root,"Hotel sign");const string title="PURRINGTON";
   float gx=gate.x*U,gz=(gate.z-.3f)*U,width=VoxelLetters.Width(title,SignPixel)+.4f;
   foreach(float side in new[]{-1f,1f})Box(sign,"Arch post",new Vector3(gx+side*(width/2+.08f),1.35f,gz),new Vector3(.14f,2.7f,.14f),"B3824C");
   Box(sign,"Signboard",new Vector3(gx,2.42f,gz),new Vector3(width,.62f,.1f),"244335");
   Box(sign,"Signboard trim",new Vector3(gx,2.78f,gz),new Vector3(width+.34f,.08f,.18f),"B3824C");
   var letters=geometry.Build(sign,VoxelLetters.Recipe("Hotel sign letters",title,SignPixel,.05f,"F7CC62"));letters.localPosition=new Vector3(gx,2.42f,gz+.05f);letters.localScale=new Vector3(1,1,-1);
   // The hotel motto hangs beneath on a cream plank, two short chains keeping it clear of cats walking through.
   const float motto=.03f;string[] lines={"GOOD CATS","BRIGHTER DAYS"};float plank=VoxelLetters.Width(lines[1],motto)+.3f;
   foreach(float side in new[]{-1f,1f})Box(sign,"Motto chain",new Vector3(gx+side*(plank/2-.12f),2.02f,gz),new Vector3(.03f,.18f,.03f),"6E4A3B");
   Box(sign,"Motto plank",new Vector3(gx,1.74f,gz),new Vector3(plank,.4f,.08f),"F4E3C0");
   for(int i=0;i<2;i++){var line=geometry.Build(sign,VoxelLetters.Recipe("Motto letters",lines[i],motto,.03f,i==0?"244335":"C0664A"));line.localPosition=new Vector3(gx,1.83f-i*.18f,gz+.04f);line.localScale=new Vector3(1,1,-1);}
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
