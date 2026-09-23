using System;
using System.Collections.Generic;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Exterior geometry uses the same coordinates as navigation. No interior is built here.
 public sealed class MainStreetArt {
  public readonly Transform Root;
  public readonly Dictionary<string,Transform> Storefronts=new Dictionary<string,Transform>();
  public readonly Bounds SquareBounds;
  readonly GodotGeometry geometry; readonly TownContent content;
  const float U=VoxelWorld.Unit;
  public MainStreetArt(GodotGeometry geometry,Transform parent,TownContent content){
   this.geometry=geometry;this.content=content;Root=Group(parent,"Meadow Main Street");
   var q=content.Point("square");SquareBounds=new Bounds(new Vector3(q.x*U,0,q.z*U),new Vector3(10*U,1,10*U));
   var paving=Group(Root,"Walkable paving");
   foreach(var a in content.StreetIds)foreach(var b in content.Neighbors(a))if(string.CompareOrdinal(a,b)<0){
    var x=content.Point(a);var y=content.Point(b);var delta=new Vector3(y.x-x.x,0,y.z-x.z);
    var path=Box(paving,"Pedestrian path",new Vector3((x.x+y.x)*U/2,.11f,(x.z+y.z)*U/2),new Vector3(2.5f*U,.16f,delta.magnitude*U+2.5f*U),"BBB6A5");
    path.localRotation=Quaternion.LookRotation(delta);
   }
   for(int x=-5;x<5;x++)for(int z=-5;z<5;z++)Box(paving,"Square stone",new Vector3((q.x+x+.5f)*U,.13f,(q.z+z+.5f)*U),new Vector3(U-.025f,.16f,U-.025f),(x+z)%3==0?"CAC4B2":"BBB6A5");
   Store("paw_mart","PAW MART",false);Store("clothing","THREAD & PAW",true);
   foreach(int side in new[]{-1,1}){
    float x=(q.x+side*4)*U,z=(q.z+3)*U;
    var bench=Group(Root,"Timber bench");Box(bench,"Seat",new Vector3(x,.65f,z),new Vector3(2,.2f,.7f),"B3824C");Box(bench,"Back",new Vector3(x,1,z+.3f),new Vector3(2,.7f,.14f),"D2AD77");
    foreach(float leg in new[]{-.7f,.7f})Box(bench,"Leg",new Vector3(x+leg,.34f,z),new Vector3(.18f,.6f,.55f),"425C35");
    var lamp=Group(Root,"Square lamp");Box(lamp,"Post",new Vector3(x,1.65f,(q.z-3.8f)*U),new Vector3(.18f,3.1f,.18f),"425C35");Box(lamp,"Lantern",new Vector3(x,3.2f,(q.z-3.8f)*U),new Vector3(.48f,.6f,.48f),"D7AE55");
   }
   // Planters sit outside the central crossing and store approaches.
   foreach(float x in new[]{q.x-4,q.x+4}){Box(Root,"Stone planter",new Vector3(x*U,.45f,(q.z-1.5f)*U),new Vector3(.9f,.7f,.9f),"BF7958");Box(Root,"Foliage",new Vector3(x*U,.9f,(q.z-1.5f)*U),new Vector3(1.1f,.5f,1.1f),"738448");}
  }
  void Store(string id,string title,bool boutique){
   var store=content.Shop(id);var f=store.footprint;var root=Group(Root,id);Storefronts[id]=root;
   float x=(f.x+f.w/2)*U,z=(f.z+f.d/2)*U,front=(boutique?f.z:f.z+f.d)*U,sign=boutique?-1:1;
   Box(root,"Opaque shell",new Vector3(x,1.9f,z),new Vector3(f.w*U,3.6f,f.d*U),"EFE2C9");
   Box(root,"Opaque roof",new Vector3(x,3.95f,z),new Vector3(f.w*U,.55f,f.d*U),boutique?"BF7958":"425C35");
   Box(root,"Timber cornice",new Vector3(x,3.5f,front+sign*.08f),new Vector3(f.w*U,.22f,.3f),"B3824C");
   var door=Box(root,"Door",new Vector3(x,1.2f,front+sign*.12f),new Vector3(1.3f,2.2f,.23f),"425C35");Hit(door,id);
   Box(root,"Door handle",new Vector3(x+.4f,1.2f,front+sign*.27f),new Vector3(.09f,.3f,.07f),"D7AE55");
   var signBoard=Group(root,"Store label");signBoard.localPosition=new Vector3(x,4.9f,z);signBoard.gameObject.AddComponent<VoxelBillboard>();
   var plate=Box(signBoard,"Store sign",Vector3.zero,new Vector3(5.6f,.8f,.24f),"244335");Hit(plate,id);
   Sign(signBoard,title,new Vector3(0,0,-.15f),.24f,false);
   foreach(float offset in new[]{-3.6f,3.6f}){
    Box(root,"Window frame",new Vector3(x+offset,1.8f,front+sign*.12f),new Vector3(2.7f,1.8f,.24f),"B3824C");
    Box(root,"Opaque display",new Vector3(x+offset,1.8f,front+sign*.27f),new Vector3(2.35f,1.5f,.08f),"DCE5C5");
    Box(root,"Awning",new Vector3(x+offset,2.85f,front+sign*.35f),new Vector3(3,.25f,1.2f),boutique?"BF7958":"738448");
    if(boutique){Box(root,"Display mannequin",new Vector3(x+offset,1.7f,front+sign*.36f),new Vector3(.5f,.8f,.12f),"D6A182");Box(root,"Display head",new Vector3(x+offset,2.25f,front+sign*.36f),new Vector3(.35f,.35f,.12f),"D7AE55");}
    else foreach(float item in new[]{-.65f,0,.65f})Box(root,"Produce display",new Vector3(x+offset+item,1.6f,front+sign*.36f),new Vector3(.45f,.4f,.12f),item==0?"D7AE55":"BF7958");
   }
  }
  static void Hit(Transform node,string id){node.gameObject.AddComponent<BoxCollider>();node.gameObject.AddComponent<TownStoreHit>().StoreId=id;}
  void Sign(Transform parent,string label,Vector3 at,float size,bool billboard=true){var t=Group(parent,label);t.localPosition=at;var text=t.gameObject.AddComponent<TextMesh>();text.text=label;text.fontSize=64;text.characterSize=size;text.anchor=TextAnchor.MiddleCenter;text.color=new Color(.97f,.95f,.89f);if(billboard)t.gameObject.AddComponent<VoxelBillboard>();}
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
