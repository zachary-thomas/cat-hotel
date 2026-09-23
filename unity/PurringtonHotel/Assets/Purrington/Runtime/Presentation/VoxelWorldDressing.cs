using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Phase C detail kit, driven by the shell's wall runs so it follows any hotel footprint:
 // vines along the tops of outer walls, flower beds along their base, lanterns beside entrances,
 // and wall-mounted bookshelves and glowing sconces on inside partitions. Nothing here stands on the floor
 // inside a room, so furniture placement, paths and cats are never blocked.
 public sealed partial class VoxelWorld {
  static readonly string[] DressBlooms={"F2A7B5","F7CC62","C9B6E4","F4F1E8","E6B7C1"};
  static readonly string[] BookColors={"BF7958","738448","9FB7C9","D7AE55","C9B6E4","E6B7C1","5F7040"};
  static float Hash(uint seed,int i){uint x=seed^(uint)(i*2654435761u);x^=x>>15;x*=2246822519u;x^=x>>13;x*=3266489917u;x^=x>>16;return (x&0xFFFF)/65535f;}
  static Vector3 Outward(int side)=>side==0?Vector3.right:side==1?Vector3.forward:side==2?Vector3.left:Vector3.back;
  // primary is true once per run (the full-height pass), for pieces that must not be duplicated between full and cutaway walls;
  // beds is an always-visible group for ground-level pieces.
  void DressRun(Transform at,Transform beds,WallRun run,int side,float height,int level,bool primary){
   float length=run.length*Unit;bool v=run.axis=='v';var axis=v?Vector3.forward:Vector3.right;var outward=Outward(side);
   uint seed=(uint)(run.x*73856093)^(uint)(run.z*19349663)^(uint)(level*83492791)^(v?0x9E3779B9u:0u);
   bool exterior=run.inward!=0;
   if(exterior&&height>2&&(run.kind=="wall"||run.kind=="window")){
    // Vines grow along the outer edge of the wall cap and trail down the outside face only, never into the rooms.
    int i=0;for(float t=.3f;t<length-.2f;t+=.5f,i++){
     if(Hash(seed,i)<.4f)continue;
     Box(at,axis*t+outward*.12f+Vector3.up*(GroundY+height+.08f),new Vector3(.2f,.12f,.2f),Shade("6e9b62",(Hash(seed,i+17)-.5f)*.1f));
     float drop=.2f+Hash(seed,i+31)*.42f;var root=axis*t+outward*.15f;int leaf=0;
     for(float y=0;y<drop;y+=.15f,leaf++)Box(at,root+axis*((Hash(seed,i*7+leaf)-.5f)*.14f)+Vector3.up*(GroundY+height-.02f-y),Vector3.one*(.22f-y*.1f),Shade("6e9b62",(Hash(seed,i*11+leaf)-.5f)*.1f));
     if(Hash(seed,i+57)>.45f)Box(at,root+outward*.08f+Vector3.up*(GroundY+height-.1f-drop*.55f),Vector3.one*.11f,DressBlooms[(int)(Hash(seed,i+91)*DressBlooms.Length)%DressBlooms.Length]);
    }
   }
   if(exterior&&height>2&&run.kind=="door"&&level==0){
    // A pair of glowing wall lanterns frames each entrance.
    foreach(float t in new[]{-.12f,length+.12f}){
     var p=axis*t+outward*.2f;Box(at,p+Vector3.up*1.75f,new Vector3(.08f,.22f,.08f),"425C35");
     Box(at,p+outward*.06f+Vector3.up*1.95f,new Vector3(.2f,.26f,.2f),SurfacePalette.LanternGlow);Box(at,p+outward*.06f+Vector3.up*2.12f,new Vector3(.24f,.06f,.24f),"425C35");
     var glow=Group(at,"Entrance lantern glow");glow.localPosition=p+outward*.3f+Vector3.up*1.95f;LampAnchor.Mark(glow,3.2f,.9f);
    }
   }
   if(exterior&&primary&&level==0&&(run.kind=="wall"||run.kind=="window")&&length>.8f){
    // A flower bed hugs the base of the outer wall. It lives outside the wall groups so it shows in cutaway and exterior views alike.
    var bedAt=Group(beds,"Wall bed");bedAt.localPosition=at.localPosition;at=bedAt;
    var bed=axis*(length/2)+outward*.34f;
    Box(at,bed+Vector3.up*.06f,v?new Vector3(.36f,.12f,length-.2f):new Vector3(length-.2f,.12f,.36f),"8A6B4F");
    int i=0;for(float t=.22f;t<length-.15f;t+=.28f,i++){
     var p=axis*t+outward*(.28f+Hash(seed,i+200)*.12f);float tall=.14f+Hash(seed,i+300)*.14f;
     Box(at,p+Vector3.up*(.12f+tall/2),new Vector3(.07f,tall,.07f),"738448");
     Box(at,p+Vector3.up*(.14f+tall),Vector3.one*.15f,Hash(seed,i+400)<.3f?"8FA35E":DressBlooms[i%DressBlooms.Length]);
    }
   }
   if(!exterior&&height>2&&run.kind=="wall"&&length>=2*Unit-.01f){
    // Inside partitions: a bookshelf on one face and a warm sconce on the other.
    var n=v?Vector3.right:Vector3.forward;if(Hash(seed,7)<.5f)n=-n;var mid=axis*(length/2);
    Box(at,mid+n*.19f+Vector3.up*1.42f,v?new Vector3(.24f,.05f,.95f):new Vector3(.95f,.05f,.24f),"B3824C");
    Box(at,mid+n*.12f+Vector3.up*1.36f,v?new Vector3(.1f,.1f,.06f):new Vector3(.06f,.1f,.1f),"B3824C");
    float x=-.4f;int b=0;while(x<.3f){float w=.07f+Hash(seed,b+500)*.05f,h=.2f+Hash(seed,b+600)*.12f;Box(at,mid+axis*(x+w/2)+n*.2f+Vector3.up*(1.445f+h/2),v?new Vector3(.17f,h,w-.01f):new Vector3(w-.01f,h,.17f),BookColors[(int)(Hash(seed,b+700)*BookColors.Length)%BookColors.Length]);x+=w;b++;}
    Box(at,mid+axis*.36f+n*.2f+Vector3.up*1.55f,Vector3.one*.16f,"BF7958");Box(at,mid+axis*.36f+n*.2f+Vector3.up*1.7f,Vector3.one*.18f,"738448");
    var s=mid-n*.15f;Box(at,s+Vector3.up*1.8f,v?new Vector3(.12f,.22f,.08f):new Vector3(.08f,.22f,.12f),"B3824C");
    Box(at,s-n*.08f+Vector3.up*1.95f,Vector3.one*.17f,SurfacePalette.LanternGlow);
    var glow=Group(at,"Sconce glow");glow.localPosition=s-n*.3f+Vector3.up*1.9f;LampAnchor.Mark(glow,2.6f,.6f);
   }
  }
  // The Godot meadow carries a "Meadow House" board beside the gate; the voxel PURRINGTON arch replaces it, so it is retired.
  void RetireGodotSigns(){
   if(!scenery)return;
   foreach(var label in scenery.GetComponentsInChildren<TextMesh>(true))if(label.text=="Meadow House"&&label.transform.parent)label.transform.parent.gameObject.SetActive(false);
  }
 }
}
