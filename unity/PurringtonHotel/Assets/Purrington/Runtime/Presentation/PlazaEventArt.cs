using System.Collections.Generic;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Props on the square for each plaza event: a movie screen, a nap field of pillows, heaps of yarn. Positions are lot units.
 public sealed class PlazaEventArt {
  const float U=VoxelWorld.Unit;
  public readonly Transform Root;
  readonly Dictionary<string,Transform> sets=new Dictionary<string,Transform>();
  readonly GodotGeometry geometry;readonly LotPoint square;
  readonly List<Transform> bobbing=new List<Transform>();readonly List<float> bobBase=new List<float>();
  float clock;
  public string Shown{get;private set;}="";
  public PlazaEventArt(GodotGeometry geometry,Transform parent,TownContent content){
   this.geometry=geometry;square=content.Point("square");Root=MainStreetArt.Group(parent,"Plaza events");
   sets["movie_night"]=Movie();sets["nap_a_thon"]=Naps();sets["yarn_festival"]=Yarn();
   foreach(var s in sets.Values)s.gameObject.SetActive(false);
  }
  Transform Box(Transform parent,string name,float x,float y,float z,float w,float h,float d,string color)=>geometry.Build(parent,ManagerCatArt.Node(name,new Vector3((square.x+x)*U,y,(square.z+z)*U),new Vector3(w*U,h,d*U),color));
  Transform Movie(){
   var set=MainStreetArt.Group(Root,"Movie Night");
   // The screen stands on the road side of the square, facing the crowd and the camera; the projector sits behind them.
   foreach(float side in new[]{-2.7f,2.7f})Box(set,"Screen post",side,1.6f,-3.6f,.18f,3.2f,.18f,"425C35");
   Box(set,"Screen",0,2,-3.55f,5.2f,2.2f,.08f,"F8F3E3");
   Box(set,"Screen frame",0,3.15f,-3.55f,5.5f,.14f,.14f,"425C35");
   Box(set,"Picture",-.8f,2.1f,-3.5f,1.6f,.9f,.04f,"A5D3DC");Box(set,"Picture",.9f,1.8f,-3.5f,1.4f,.6f,.04f,"F4D35E");
   Box(set,"Projector stand",0,.45f,3.4f,.5f,.9f,.5f,"8B6A45");Box(set,"Projector",0,1.05f,3.4f,.7f,.4f,.6f,"4A514E");Box(set,"Lens",0,1.05f,3.05f,.24f,.24f,.1f,"F4D35E");
   for(int i=0;i<5;i++){float x=-3+i*1.5f;Box(set,"Cushion",x,.2f,-2.2f,.9f,.2f,.9f,i%2==0?"BF7958":"D7AE55");}
   Box(set,"Popcorn cart",-3.8f,.55f,1.5f,.9f,1.1f,.7f,"F2A7B5");Box(set,"Popcorn",-3.8f,1.2f,1.5f,.8f,.25f,.6f,"F8F3E3");
   for(int i=0;i<9;i++){var bulb=Box(set,"String light",-4+i,3.6f-Mathf.Abs(i-4)*.08f,-3.9f,.16f,.16f,.16f,"FFF3C4");LampAnchor.Mark(bulb,2.2f,.6f);}
   return set;
  }
  Transform Naps(){
   var set=MainStreetArt.Group(Root,"Nap-a-thon");
   string[] blankets={"A5D3DC","F2A7B5","D7AE55","B5C98E","E6DFCE","BF7958"};
   for(int i=0;i<6;i++){float a=i*Mathf.PI/3+.2f;float x=Mathf.Cos(a)*3.4f,z=Mathf.Sin(a)*3;Box(set,"Blanket",x,.25f,z,1.6f,.08f,1.2f,blankets[i]);Box(set,"Pillow",x+.4f,.36f,z-.3f,.6f,.2f,.4f,"F8F3E3");}
   // A sleepy banner: three Z's getting bigger.
   for(int i=0;i<3;i++)Bob(Box(set,"Zzz",-1.2f+i*1.2f,2.2f+i*.5f,-3.6f,.3f+i*.12f,.3f+i*.12f,.08f,"3B4A6B"));
   Box(set,"Trophy base",3.8f,.3f,3.2f,.6f,.6f,.6f,"B3824C");Box(set,"Trophy",3.8f,.85f,3.2f,.46f,.5f,.46f,"F4D35E");
   return set;
  }
  Transform Yarn(){
   var set=MainStreetArt.Group(Root,"Yarn Festival");
   string[] colors={"BF7958","789B58","D7AE55","A5D3DC","F2A7B5","7A2E3B"};
   var heaps=new[]{new Vector2(-4,-2.6f),new Vector2(4,-2.6f),new Vector2(-4,2.8f),new Vector2(4,2.8f)};
   for(int h=0;h<heaps.Length;h++)for(int i=0;i<4;i++)Box(set,"Yarn ball",heaps[h].x+(i%2)*.6f-.3f,.48f+(i/2)*.5f,heaps[h].y+(i==3?.2f:0),.6f,.55f,.6f,colors[(i+h*2)%colors.Length]);
   for(int i=0;i<5;i++)Bob(Box(set,"Bouncing yarn",-2+i,.5f,2.4f,.5f,.45f,.5f,colors[i]));
   foreach(float side in new[]{-1f,1f}){Box(set,"Stall post",side*6,1.3f,0,.14f,2.6f,.14f,"B3824C");Box(set,"Stall roof",side*6,2.7f,0,1.8f,.2f,1.8f,side<0?"BF7958":"789B58");Box(set,"Stall table",side*6,.7f,0,1.6f,.2f,1,"D2AD77");}
   return set;
  }
  void Bob(Transform t){bobbing.Add(t);bobBase.Add(t.localPosition.y);}
  public void Update(HotelModel model,float delta,bool motion){
   clock+=delta;string id=model.State.currentHotel==0?model.PlazaEventId:"";
   if(id!=Shown){foreach(var pair in sets)pair.Value.gameObject.SetActive(pair.Key==id);Shown=id;}
   if(!motion||id.Length==0)return;
   for(int i=0;i<bobbing.Count;i++){var t=bobbing[i];if(!t||!t.gameObject.activeInHierarchy)continue;var p=t.localPosition;p.y=bobBase[i]+Mathf.Abs(Mathf.Sin(clock*3+i))*.25f;t.localPosition=p;}
  }
 }
}
