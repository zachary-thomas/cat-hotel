using System.Collections.Generic;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // The Meadow outskirts behind the plaza: Lily Pond, Old Oak and Hilltop Lookout, with stepping stones from the plaza
 // and a sparkle where the current rumor points. Positions are lot units, like MainStreetArt.
 public sealed class OutskirtsArt {
  const float U=VoxelWorld.Unit;
  public const string RumorPickId="rumor";
  // Scenery (houses, lawn trees) inside these lot areas is not built.
  public static readonly Rect[] Cleared={Rect.MinMaxRect(-28,32,-9,49),Rect.MinMaxRect(10,33,30,48),Rect.MinMaxRect(-9,33,9,52)};
  public readonly Transform Root;
  readonly GodotGeometry geometry;readonly TownContent content;
  readonly Dictionary<string,Transform> sparkles=new Dictionary<string,Transform>();
  float clock;
  public OutskirtsArt(GodotGeometry geometry,Transform parent,TownContent content){
   this.geometry=geometry;this.content=content;Root=MainStreetArt.Group(parent,"Meadow outskirts");
   Stones("bench_west","pond_path","lily_pond");Stones("bench_east","oak_path","old_oak");Stones("square","hilltop",null,30);
   Pond(content.Point("lily_pond"));Oak(content.Point("old_oak"));Hill(content.Point("hilltop"));
   foreach(var id in new[]{"lily_pond","old_oak","hilltop"})sparkles[id]=Sparkle(content.Point(id));
  }
  Transform Box(Transform parent,string name,Vector3 lot,Vector3 size,string color)=>geometry.Build(parent,ManagerCatArt.Node(name,new Vector3(lot.x*U,lot.y,lot.z*U),new Vector3(size.x*U,size.y,size.z*U),color));
  // Flat stones every step along the path, skipping paving that is already there.
  void Stones(string a,string b,string c,float fromZ=-999){
   var group=MainStreetArt.Group(Root,"Stepping stones");
   var ids=c==null?new[]{a,b}:new[]{a,b,c};
   for(int i=1;i<ids.Length;i++){
    var p=content.Point(ids[i-1]);var q=content.Point(ids[i]);float length=p.Distance(q);int steps=Mathf.FloorToInt(length/1.3f);
    for(int s=1;s<steps;s++){
     float t=s/(float)steps;float x=p.x+(q.x-p.x)*t,z=p.z+(q.z-p.z)*t;
     if(z<fromZ||Mathf.Abs(x)<8&&z>20&&z<30)continue;
     float jitter=((s*37+i*11)%5-2)*.06f;
     Box(group,"Stone",new Vector3(x+jitter,.1f,z-jitter),new Vector3(.62f,.08f,.48f),(s+i)%3==0?"D9CFBC":"E4DCCB");
    }
   }
  }
  void Pond(LotPoint at){
   var pond=MainStreetArt.Group(Root,"Lily Pond");
   float cx=at.x-4,cz=at.z+3.2f;
   Box(pond,"Pond rim",new Vector3(cx,.06f,cz),new Vector3(8.6f,.1f,6.2f),"BBB6A5");
   Box(pond,"Pond water",new Vector3(cx,.1f,cz),new Vector3(7.8f,.08f,5.4f),"7FB9C9");
   Box(pond,"Pond shallows",new Vector3(cx+2.6f,.11f,cz-1.6f),new Vector3(2.2f,.07f,1.6f),"A5D3DC");
   foreach(var pad in new[]{new Vector2(-2.2f,.8f),new Vector2(-.6f,-1.2f),new Vector2(1.4f,1.4f),new Vector2(-2.8f,-1.6f)})Box(pond,"Lily pad",new Vector3(cx+pad.x,.16f,cz+pad.y),new Vector3(.7f,.04f,.7f),"6E9A4A");
   Box(pond,"Lily flower",new Vector3(cx-.6f,.24f,cz-1.2f),new Vector3(.24f,.14f,.24f),"F2A7B5");
   Box(pond,"Lily flower",new Vector3(cx+1.4f,.24f,cz+1.4f),new Vector3(.22f,.12f,.22f),"F8F3E3");
   for(int i=0;i<7;i++){float rx=cx-4.1f+i%2*.4f,rz=cz-2.4f+i*.8f;Box(pond,"Reed",new Vector3(rx,.6f,rz),new Vector3(.12f,1.1f+(i%3)*.25f,.12f),"738448");Box(pond,"Reed tip",new Vector3(rx,1.2f+(i%3)*.13f,rz),new Vector3(.16f,.28f,.16f),"8B6A45");}
   // A little jetty where the manager (and Old Tom) stand.
   Box(pond,"Jetty",new Vector3(at.x-.8f,.16f,at.z+.9f),new Vector3(1.8f,.12f,1.1f),"B3824C");
   foreach(float side in new[]{-1.5f,-.1f})Box(pond,"Jetty post",new Vector3(at.x+side,.3f,at.z+1.4f),new Vector3(.16f,.5f,.16f),"8B6A45");
  }
  void Oak(LotPoint at){
   var oak=MainStreetArt.Group(Root,"Old Oak");
   float cx=at.x+3,cz=at.z+3;
   Box(oak,"Trunk",new Vector3(cx,2.3f,cz),new Vector3(1.5f,4.6f,1.5f),"6E5034");
   Box(oak,"Bark",new Vector3(cx+.3f,2.6f,cz-.77f),new Vector3(.3f,2.8f,.06f),"5A4129");
   Box(oak,"Hollow",new Vector3(cx-.4f,1.4f,cz-.77f),new Vector3(.56f,.7f,.06f),"2E2218");
   Box(oak,"Branch",new Vector3(cx+1.4f,4,cz),new Vector3(1.6f,.4f,.4f),"6E5034");
   foreach(var root in new[]{new Vector3(-1,0,0),new Vector3(1,0,0),new Vector3(0,0,-1),new Vector3(0,0,1)})Box(oak,"Root",new Vector3(cx+root.x*.9f,.2f,cz+root.z*.9f),new Vector3(root.x!=0?.9f:.5f,.35f,root.z!=0?.9f:.5f),"6A4E32");
   // Three dark, lumpy crowns so it reads as old and different from the pale lawn trees.
   Box(oak,"Crown",new Vector3(cx-.6f,5.3f,cz+.4f),new Vector3(4.2f,2.4f,4.2f),"3F6B2E");
   Box(oak,"Crown",new Vector3(cx+1.9f,4.7f,cz-.4f),new Vector3(3.2f,2,3.2f),"4F7A35");
   Box(oak,"Crown",new Vector3(cx+.4f,6.6f,cz+1.2f),new Vector3(3,1.8f,3),"5E8C3F");
   Box(oak,"Crown tuft",new Vector3(cx-2.3f,4.5f,cz-1),new Vector3(1.8f,1.4f,1.8f),"4F7A35");
   Box(oak,"Crown tuft",new Vector3(cx+.9f,7.6f,cz+.6f),new Vector3(1.6f,.9f,1.6f),"6FA04A");
   foreach(var acorn in new[]{new Vector2(-.9f,-2.1f),new Vector2(2.4f,-1.7f),new Vector2(-2.6f,-1.9f)})Box(oak,"Acorn",new Vector3(cx+acorn.x,4.1f,cz+acorn.y),new Vector3(.22f,.26f,.22f),"B3824C");
   foreach(var m in new[]{new Vector2(-1.8f,-1.2f),new Vector2(-2.2f,-.4f),new Vector2(1.6f,-1.9f)}){Box(oak,"Mushroom stem",new Vector3(cx+m.x,.18f,cz+m.y),new Vector3(.12f,.3f,.12f),"F4EAD5");Box(oak,"Mushroom cap",new Vector3(cx+m.x,.36f,cz+m.y),new Vector3(.34f,.12f,.34f),"BF7958");}
  }
  void Hill(LotPoint at){
   var hill=MainStreetArt.Group(Root,"Hilltop Lookout");
   float cx=at.x,cz=at.z+3.6f;
   Box(hill,"Hill",new Vector3(cx,.3f,cz),new Vector3(7,.6f,5.6f),"7FA650");
   Box(hill,"Hill middle",new Vector3(cx,.8f,cz+.3f),new Vector3(5,.5f,4),"8BB35A");
   Box(hill,"Hill top",new Vector3(cx,1.25f,cz+.5f),new Vector3(3,.4f,2.6f),"97BE63");
   for(int i=0;i<3;i++)Box(hill,"Step",new Vector3(cx,.14f+i*.45f,at.z+.7f+i*.7f),new Vector3(1.2f,.28f+i*.45f,.7f),"D9CFBC");
   // A telescope on a tripod and a small bench for stargazers.
   float top=1.45f;
   foreach(float leg in new[]{-.25f,.25f})Box(hill,"Tripod leg",new Vector3(cx+.9f+leg,top+.35f,cz+.4f),new Vector3(.08f,.7f,.08f),"425C35");
   Box(hill,"Telescope",new Vector3(cx+.9f,top+.8f,cz+.4f),new Vector3(.28f,.28f,.9f),"D7AE55");
   Box(hill,"Telescope lens",new Vector3(cx+.9f,top+.84f,cz-.06f),new Vector3(.34f,.34f,.1f),"A5D3DC");
   Box(hill,"Bench seat",new Vector3(cx-.9f,top+.35f,cz+.8f),new Vector3(1.3f,.14f,.5f),"B3824C");
   foreach(float leg in new[]{-.5f,.5f})Box(hill,"Bench leg",new Vector3(cx-.9f+leg,top+.16f,cz+.8f),new Vector3(.12f,.3f,.4f),"425C35");
   Box(hill,"Flag pole",new Vector3(cx-1.8f,top+1,cz+1.4f),new Vector3(.08f,2,.08f),"F4EAD5");
   Box(hill,"Flag",new Vector3(cx-1.45f,top+1.75f,cz+1.4f),new Vector3(.6f,.38f,.04f),"BF7958");
  }
  Transform Sparkle(LotPoint at){
   var s=MainStreetArt.Group(Root,"Rumor sparkle");s.localPosition=new Vector3(at.x*U,0,at.z*U);
   var gem=MainStreetArt.Group(s,"Gem");gem.localPosition=new Vector3(0,2.2f,0);
   geometry.Build(gem,ManagerCatArt.Node("Sparkle",Vector3.zero,new Vector3(.6f,.6f,.6f),"F4D35E"));
   geometry.Build(gem,ManagerCatArt.Node("Sparkle ring",Vector3.zero,new Vector3(1.2f,.14f,.14f),"FFF3C4"));
   geometry.Build(gem,ManagerCatArt.Node("Sparkle ring",Vector3.zero,new Vector3(.14f,1.2f,.14f),"FFF3C4"));
   geometry.Build(gem,ManagerCatArt.Node("Sparkle ring",Vector3.zero,new Vector3(.14f,.14f,1.2f),"FFF3C4"));
   LampAnchor.Mark(gem.GetChild(0),3.5f);
   var hit=new GameObject("Rumor pick");hit.transform.SetParent(s,false);var box=hit.AddComponent<BoxCollider>();box.center=new Vector3(0,1,0);box.size=new Vector3(1.6f,2.4f,1.6f);hit.AddComponent<WorldPick>().objectId=RumorPickId;
   s.gameObject.SetActive(false);
   return s;
  }
  public void Update(HotelModel model,float delta,bool motion,bool pickable){
   clock+=delta;string spot=model.RumorSpot;
   foreach(var pair in sparkles){
    bool on=pair.Key==spot;pair.Value.gameObject.SetActive(on);if(!on)continue;
    var gem=pair.Value.Find("Gem");
    if(motion&&gem){gem.localPosition=new Vector3(0,2.2f+Mathf.Sin(clock*2.4f)*.2f,0);gem.localRotation=Quaternion.Euler(45,clock*90,45);}
    var hit=pair.Value.GetComponentInChildren<BoxCollider>();if(hit)hit.enabled=pickable;
   }
  }
 }
}
