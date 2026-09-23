using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Phase C destination kits, following world-map.png: a Seaside beach with palms, umbrellas and a pier; autumn trees,
 // leaf piles, mushrooms and a woodpile at Forest Lodge; a steaming hot spring, snowmen and snowy pines at Snowcap Spa.
 // Pieces stand in authored (Godot) coordinates outside the hotel's base lot and every purchasable plot, clear of the
 // roads, neighbour houses and water listed in each map's scenery bounds, so construction is never blocked.
 public sealed partial class VoxelWorld {
  Transform kit;
  void BuildDestinationKit(){
   kit=Group(scenery,"Destination kit");
   switch(currentMap){case 1:SeasideKit();break;case 2:ForestKit();break;case 3:SnowcapKit();break;}
   Bake(kit);
  }
  static Vector3 At(float x,float z,float y=0)=>new Vector3(x,GrassY+y,z);

  void SeasideKit(){
   foreach(var (x,z) in new[]{(-20f,-22.6f),(-8f,-22.9f),(4f,-22.4f),(16f,-22.8f),(-30.5f,8f),(-29.5f,-18f)})Palm(x,z,Hash((uint)(x*13+z*7),1));
   string[] canopy={"F2A7B5","F7CC62","8CC8D6"};int i=0;
   foreach(var (x,z) in new[]{(-14f,-21.8f),(-2f,-22f),(10f,-21.8f)}){Umbrella(x,z,canopy[i%3]);Lounger(x+1.1f,z+.2f,canopy[(i+1)%3]);i++;}
   // Sandcastle with a little flag.
   Box(kit,At(21,-22.4f,.18f),new Vector3(1,.36f,1),"E6C797");Box(kit,At(21,-22.4f,.5f),new Vector3(.6f,.28f,.6f),"E8CB9E");foreach(var (dx,dz) in new[]{(-.45f,-.45f),(.45f,-.45f),(-.45f,.45f),(.45f,.45f)})Box(kit,At(21+dx,-22.4f+dz,.45f),new Vector3(.24f,.18f,.24f),"DDB985");
   Box(kit,At(21,-22.4f,.9f),new Vector3(.04f,.5f,.04f),"8A6B4F");Box(kit,At(21.14f,-22.4f,1.05f),new Vector3(.24f,.14f,.03f),"E98A7A");
   // A wooden pier runs out to sea from the east shore, with lanterns at the end, a lifebuoy and a rowing boat.
   for(float x=24.5f;x<36;x+=.55f){Box(kit,At(x,-2,.12f),new Vector3(.5f,.1f,2.4f),Shade("B3824C",((int)(x*3)%3-1)*.05f));}
   for(float x=24.8f;x<36;x+=2.2f)foreach(float z in new[]{-3.1f,-.9f})Box(kit,At(x,z,-.2f),new Vector3(.22f,.8f,.22f),"8A6B4F");
   foreach(float z in new[]{-3.1f,-.9f}){Box(kit,At(35.6f,z,.55f),new Vector3(.12f,.9f,.12f),"425C35");Box(kit,At(35.6f,z,1.08f),new Vector3(.24f,.26f,.24f),SurfacePalette.LanternGlow);var glow=Group(kit,"Pier lantern glow");glow.localPosition=At(35.6f,z,1.1f);LampAnchor.Mark(glow,3.5f,.9f);}
   Box(kit,At(30.4f,-3.25f,.45f),new Vector3(.08f,.46f,.46f),"F4F1E8");Box(kit,At(30.4f,-3.25f,.45f),new Vector3(.1f,.2f,.2f),"E98A7A");
   Box(kit,At(32,-6.2f,.05f),new Vector3(2.6f,.3f,1),"E98A7A");Box(kit,At(32,-6.2f,.22f),new Vector3(2.2f,.08f,.7f),"F4F1E8");Box(kit,At(32,-6.2f,.26f),new Vector3(.2f,.06f,.9f),"B3824C");
  }
  void Palm(float x,float z,float lean){
   float h=2.6f+lean*.8f;int segments=Mathf.RoundToInt(h/.3f);
   for(int s=0;s<segments;s++){float t=s/(float)segments;Box(kit,At(x+t*t*.5f,z,.15f+s*.3f),new Vector3(.3f,.3f,.3f),s%2==0?"B08A62":"C29C73");}
   var top=At(x+.5f,z,.15f+segments*.3f);
   foreach(var dir in new[]{Vector3.right,Vector3.left,Vector3.forward,Vector3.back,(Vector3.right+Vector3.forward).normalized,(Vector3.left+Vector3.back).normalized})
    for(int k=1;k<=3;k++)Box(kit,top+dir*(k*.35f)+Vector3.down*(k*k*.06f),new Vector3(.4f,.12f,.4f),k==3?"8FB86A":"6E9B62");
   foreach(var d in new[]{new Vector3(.12f,-.2f,.1f),new Vector3(-.1f,-.2f,-.08f)})Box(kit,top+d,Vector3.one*.18f,"8A6B4F");
  }
  void Umbrella(float x,float z,string color){
   Box(kit,At(x,z,.8f),new Vector3(.08f,1.6f,.08f),"F4F1E8");
   for(int r=0;r<3;r++){float w=1.9f-r*.55f;Box(kit,At(x,z,1.55f+r*.14f),new Vector3(w,.12f,w),r%2==0?color:"F4F1E8");}
  }
  void Lounger(float x,float z,string color){
   Box(kit,At(x,z,.22f),new Vector3(.7f,.1f,1.6f),"B3824C");Box(kit,At(x,z+.1f,.3f),new Vector3(.6f,.06f,1.2f),color);Box(kit,At(x,z-.72f,.45f),new Vector3(.6f,.35f,.12f),color);
   foreach(var (dx,dz) in new[]{(-.3f,-.7f),(.3f,-.7f),(-.3f,.7f),(.3f,.7f)})Box(kit,At(x+dx,z+dz,.09f),new Vector3(.08f,.18f,.08f),"8A6B4F");
   Box(kit,At(x-.6f,z+.5f,.12f),new Vector3(.5f,.04f,.9f),"8CC8D6");
  }

  void ForestKit(){
   string[] autumn={"D9824A","E3B04B","C9573A","E09A55"};int i=0;
   foreach(var (x,z) in new[]{(-28f,-20f),(28.5f,-20.5f),(-12.5f,-28f),(13.5f,-29.5f),(-27.5f,9f),(29f,11.5f),(1.5f,-32.5f)}){AutumnTree(x,z,autumn[i%autumn.Length],Hash((uint)(x*17+z*5),2));LeafPile(x+1.6f,z+1.2f,autumn[(i+1)%autumn.Length]);i++;}
   foreach(var (x,z) in new[]{(-24.5f,-18f),(25.5f,8.5f),(10.5f,-26f),(-9.5f,-25.8f)})Mushrooms(x,z);
   // A woodpile and chopping stump between the pines to the north.
   for(int row=0;row<3;row++)for(int k=0;k<4-row;k++)Box(kit,At(-.5f+k*.42f+row*.21f,-27.5f,.18f+row*.36f),new Vector3(.38f,.36f,1.3f),Shade("8A6B4F",((k+row)%2)*.08f));
   Box(kit,At(2.2f,-27.3f,.25f),new Vector3(.7f,.5f,.7f),"9A7556");Box(kit,At(2.2f,-27.3f,.51f),new Vector3(.62f,.02f,.62f),"D8B98F");
   foreach(var (x,z) in new[]{(4.2f,-26.6f),(5f,-27.6f)}){Box(kit,At(x,z,.22f),new Vector3(.55f,.44f,.55f),"E07F35");Box(kit,At(x,z,.5f),new Vector3(.1f,.14f,.1f),"5F7040");}
  }
  void AutumnTree(float x,float z,string color,float size){
   float h=1.4f+size*.6f;Box(kit,At(x,z,h/2),new Vector3(.4f,h,.4f),"7A5A42");
   float r=1.3f+size*.5f;
   Box(kit,At(x,z,h+.4f),new Vector3(r*2,.8f,r*2),color);Box(kit,At(x,z,h+1.1f),new Vector3(r*1.5f,.7f,r*1.5f),Shade(color,.08f));Box(kit,At(x,z,h+1.65f),new Vector3(r*.9f,.5f,r*.9f),Shade(color,.16f));
   foreach(var (dx,dz) in new[]{(.9f,.4f),(-.7f,-.8f),(.3f,-1f)})Box(kit,At(x+dx*r*.8f,z+dz*r*.8f,h+.1f),new Vector3(.5f,.4f,.5f),Shade(color,-.1f));
  }
  void LeafPile(float x,float z,string color){for(int k=0;k<5;k++){float a=k*1.3f;Box(kit,At(x+Mathf.Cos(a)*.35f,z+Mathf.Sin(a)*.3f,.06f+(k==0?.08f:0)),new Vector3(.45f,.12f+(k==0?.12f:0),.4f),Shade(color,(k%3-1)*.08f));}}
  void Mushrooms(float x,float z){foreach(var (dx,dz,s) in new[]{(0f,0f,1f),(.35f,.2f,.7f),(-.25f,.3f,.55f)}){Box(kit,At(x+dx,z+dz,.12f*s),new Vector3(.12f,.24f,.12f)*s,"F4F1E8");Box(kit,At(x+dx,z+dz,.28f*s),new Vector3(.34f,.14f,.34f)*s,"D9573F");Box(kit,At(x+dx+.06f*s,z+dz,.36f*s),new Vector3(.06f,.03f,.06f)*s,"FFFFFF");}}

  void SnowcapKit(){
   // Hot spring: a ring of rocks around warm water, with steam and two lanterns.
   const float hx=30.5f,hz=8;
   Box(kit,At(hx,hz,.04f),new Vector3(5,.1f,3.8f),"8C9BA8");Box(kit,At(hx,hz,.12f),new Vector3(4.2f,.1f,3),"7FC7D6");Box(kit,At(hx,hz,.15f),new Vector3(3.6f,.04f,2.4f),"A8DDE6");
   for(int k=0;k<22;k++){float a=k/22f*Mathf.PI*2;float s=.45f+Hash(77,k)*.3f;Box(kit,At(hx+Mathf.Cos(a)*2.35f,hz+Mathf.Sin(a)*1.75f,s/2),new Vector3(s,s,s),Hash(78,k)<.5f?"A3A9AE":"8E959B");}
   for(int k=0;k<7;k++)Box(kit,At(hx-1.2f+k*.4f+Hash(79,k)*.2f,hz-.6f+Hash(80,k)*1.2f,.5f+Hash(81,k)*.9f),Vector3.one*(.22f+Hash(82,k)*.18f),"F4F6F2");
   foreach(float dz in new[]{-2.3f,2.3f}){Box(kit,At(hx-2.6f,hz+dz,.55f),new Vector3(.12f,1.1f,.12f),"425C35");Box(kit,At(hx-2.6f,hz+dz,1.2f),new Vector3(.26f,.28f,.26f),SurfacePalette.LanternGlow);var glow=Group(kit,"Spring lantern glow");glow.localPosition=At(hx-2.6f,hz+dz,1.2f);LampAnchor.Mark(glow,3.5f,.9f);}
   Box(kit,At(hx+2.2f,hz-2.6f,.4f),new Vector3(1.2f,.8f,.1f),"B3824C");Box(kit,At(hx+2.2f,hz-2.55f,.45f),new Vector3(.8f,.3f,.02f),"E98A7A");
   foreach(var (x,z) in new[]{(-29.5f,4.5f),(8f,-25f),(26f,11.2f)})Snowman(x,z);
   foreach(var (x,z) in new[]{(28.5f,-21f),(-18f,-25f),(-3f,-25f),(30.5f,-17f),(-29.5f,9.5f)})SnowPine(x,z,Hash((uint)(x*11+z*3),4));
   // A red sled leaning by the path.
   Box(kit,At(-27,-1,.18f),new Vector3(.7f,.08f,1.5f),"D9573F");foreach(float dx in new[]{-.3f,.3f})Box(kit,At(-27+dx,-1,.06f),new Vector3(.06f,.1f,1.6f),"6E4A3B");
  }
  void Snowman(float x,float z){
   const float k=1.7f;void B(float dx,float dz,float y,Vector3 size,string c)=>Box(kit,At(x+dx*k,z+dz*k,y*k),size*k,c);
   B(0,0,.4f,Vector3.one*.8f,"F4F6F2");B(0,0,1.05f,Vector3.one*.58f,"F8FAF8");B(0,0,1.55f,Vector3.one*.42f,"FFFFFF");
   B(.25f,0,1.55f,new Vector3(.2f,.07f,.07f),"E07F35");foreach(float dz in new[]{-.1f,.1f})B(.21f,dz,1.64f,new Vector3(.04f,.06f,.06f),"3B2F2A");
   B(0,0,1.33f,new Vector3(.5f,.1f,.5f),"D9573F");B(.1f,.22f,1.2f,new Vector3(.12f,.3f,.1f),"D9573F");
   B(0,0,1.84f,new Vector3(.34f,.16f,.34f),"425C35");
  }
  void SnowPine(float x,float z,float size){
   float h=.9f+size*.5f;Box(kit,At(x,z,h/2),new Vector3(.5f,h,.5f),"6E4A3B");
   for(int k=0;k<4;k++){float w=3.4f-k*.8f+size*.5f,y=h+k*.8f;Box(kit,At(x,z,y+.3f),new Vector3(w,.6f,w),"5F7F68");Box(kit,At(x,z,y+.66f),new Vector3(w*.82f,.14f,w*.82f),"F4F6F2");}
  }
 }
}
