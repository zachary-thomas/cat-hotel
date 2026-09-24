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
   Scatter();
   Bake(kit);
  }
  // Free ground: outside the base lot and plots (with a margin), outside every scenery rect (roads, houses, trees, ponds)
  // and on land. Used for the small scattered details below.
  bool FreeGround(float x,float z,float r){
   var m=model.Map();
   bool Inside(float rx,float rz,float w,float d,float pad)=>x>rx-pad&&x<rx+w+pad&&z>rz-pad&&z<rz+d+pad;
   bool Lot(Newtonsoft.Json.Linq.JToken t)=>Inside((float)t[0]*Unit,(float)t[1]*Unit,(float)t[2]*Unit,(float)t[3]*Unit,r+.3f);
   if(Lot(m["base"]))return false;foreach(var plot in m["plots"])if(Lot(plot["rect"]))return false;
   foreach(var b in geometry.Map(currentMap)["sceneryBounds"])if(Inside((float)b[0],(float)b[1],(float)b[2],(float)b[3],r+.2f))return false;
   switch(currentMap){case 0:return z<9&&Mathf.Abs(x)<44;case 1:return x<24.2f-r&&z>-24.2f+r&&z<9;default:return z<11.5f&&Mathf.Abs(x)<34-r;}
  }
  // Small ground details scattered over free land: shells, starfish and dune grass at the beach; ferns, stones and flowers
  // in the forest; snow drifts and icy tufts at Snowcap; wildflowers and grass at Meadow.
  void Scatter(){
   uint seed=(uint)(currentMap*7919+17);int placed=0;
   for(int i=0;i<900&&placed<150;i++){
    float x=-44+Hash(seed,i)*88,z=-40+Hash(seed,i+5000)*52;float pick=Hash(seed,i+9000);
    if(!FreeGround(x,z,1.1f))continue;placed++;
    switch(currentMap){
     case 1:if(pick<.35f)Tuft(x,z,"B7C27A","9FAE62");else if(pick<.6f)Shell(x,z,pick);else if(pick<.75f)Starfish(x,z,pick);else if(pick<.88f)Ripple(x,z);else Driftwood(x,z);break;
     case 2:if(pick<.35f)Tuft(x,z,"5F8A56","7FA36A");else if(pick<.55f)Fern(x,z);else if(pick<.72f)Stone(x,z,"A3A9AE");else if(pick<.9f)Flowers(x,z,pick);else Log(x,z);break;
     case 3:if(pick<.45f)Drift(x,z,pick);else if(pick<.7f)Tuft(x,z,"B8C8D0","D9E4EA");else if(pick<.85f)Stone(x,z,"8E959B");else Pawprints(x,z,pick);break;
     default:if(pick<.45f)Tuft(x,z,"8FB86A","6E9B62");else if(pick<.85f)Flowers(x,z,pick);else Stone(x,z,"C9C3B5");break;
    }
   }
  }
  void Tuft(float x,float z,string a,string b){for(int k=0;k<4;k++)Box(kit,At(x+(k%2-.5f)*.12f,z+(k/2-.5f)*.12f,.08f+k*.02f),new Vector3(.05f,.16f+k*.04f,.05f),k%2==0?a:b);}
  void Shell(float x,float z,float p){string c=p<.45f?"F4E3C0":"F2C4C8";Box(kit,At(x,z,.03f),new Vector3(.2f,.06f,.16f),c);Box(kit,At(x,z-.04f,.07f),new Vector3(.12f,.04f,.08f),Shade(c,.1f));}
  void Starfish(float x,float z,float p){string c=p<.68f?"E98A7A":"F2B13A";Box(kit,At(x,z,.03f),new Vector3(.36f,.05f,.1f),c);Box(kit,At(x,z,.03f),new Vector3(.1f,.05f,.36f),c);Box(kit,At(x,z,.05f),new Vector3(.14f,.05f,.14f),Shade(c,-.1f));}
  void Ripple(float x,float z){for(int k=0;k<3;k++)Box(kit,At(x,z+k*.28f,.012f),new Vector3(1.1f-k*.2f,.02f,.07f),"DCC9A0");}
  void Driftwood(float x,float z){Box(kit,At(x,z,.07f),new Vector3(1.2f,.14f,.16f),"B8A088");Box(kit,At(x+.4f,z+.14f,.07f),new Vector3(.4f,.1f,.1f),"A48C74");}
  void Fern(float x,float z){foreach(var (dx,dz) in new[]{(.18f,0f),(-.18f,0f),(0f,.18f),(0f,-.18f)})Box(kit,At(x+dx,z+dz,.1f),new Vector3(dx!=0?.32f:.1f,.06f,dz!=0?.32f:.1f),"4F7A4F");Box(kit,At(x,z,.14f),new Vector3(.1f,.18f,.1f),"5F8A56");}
  void Stone(float x,float z,string c){Box(kit,At(x,z,.09f),new Vector3(.34f,.18f,.28f),c);Box(kit,At(x+.18f,z+.08f,.05f),new Vector3(.16f,.1f,.14f),Shade(c,-.08f));}
  void Flowers(float x,float z,float p){string[] petals={"F2A7B5","F7CC62","C9B6E4","F4F1E8","E98A7A"};for(int k=0;k<3;k++){float dx=(k-1)*.16f,dz=(k%2)*.14f;Box(kit,At(x+dx,z+dz,.1f),new Vector3(.04f,.2f,.04f),"738448");Box(kit,At(x+dx,z+dz,.22f),Vector3.one*.1f,petals[(int)(p*50+k)%petals.Length]);}}
  void Log(float x,float z){Box(kit,At(x,z,.15f),new Vector3(1.4f,.3f,.3f),"7A5A42");Box(kit,At(x+.71f,z,.15f),new Vector3(.02f,.24f,.24f),"C9A77E");Box(kit,At(x-.2f,z+.1f,.32f),new Vector3(.3f,.06f,.2f),"6E9B62");}
  void Drift(float x,float z,float p){float w=.8f+p*1.2f;Box(kit,At(x,z,.08f),new Vector3(w,.16f,w*.7f),"F8FAF8");Box(kit,At(x+.1f,z,.18f),new Vector3(w*.6f,.12f,w*.45f),"FFFFFF");}
  void Pawprints(float x,float z,float p){for(int k=0;k<5;k++)Box(kit,At(x+k*.32f,z+(k%2)*.16f,.012f),new Vector3(.1f,.02f,.1f),"C8D3DA");}
  static Vector3 At(float x,float z,float y=0)=>new Vector3(x,GrassY+y,z);
  const float LighthouseX=-37,LighthouseZ=-23.3f;
  static readonly (float x,float z,float w)[] SeaRocks={(28.5f,-18f,1.2f),(41f,-9f,1.6f),(-18f,-29f,1.1f)};

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
   // A striped lighthouse on the point, and sea rocks off the shore (their surf rings animate in VoxelWorldLife).
   for(int k=0;k<6;k++)Box(kit,At(LighthouseX,LighthouseZ,.35f+k*.6f),new Vector3(1.1f-k*.07f,.6f,1.1f-k*.07f),k%2==0?"F4F1E8":"E98A7A");
   Box(kit,At(LighthouseX,LighthouseZ,3.72f),new Vector3(1.1f,.12f,1.1f),"425C35");Box(kit,At(LighthouseX,LighthouseZ,4.5f),new Vector3(.8f,.12f,.8f),"425C35");Box(kit,At(LighthouseX,LighthouseZ,4.72f),new Vector3(.4f,.3f,.4f),"E98A7A");
   Box(kit,At(LighthouseX,LighthouseZ,.1f),new Vector3(1.6f,.2f,1.6f),"A3A9AE");
   foreach(var (x,z,w) in SeaRocks){Box(kit,At(x,z,.15f),new Vector3(w,.5f,w*.8f),"8E959B");Box(kit,At(x+w*.2f,z-w*.1f,.4f),new Vector3(w*.5f,.4f,w*.45f),"A3A9AE");}
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
   // Hot spring: a ring of rocks around warm water and two lanterns (its steam and bathers are in VoxelWorldLife).
   const float hx=SpringX,hz=SpringZ;
   Box(kit,At(hx,hz,.04f),new Vector3(5,.1f,3.8f),"8C9BA8");Box(kit,At(hx,hz,.12f),new Vector3(4.2f,.1f,3),"7FC7D6");Box(kit,At(hx,hz,.15f),new Vector3(3.6f,.04f,2.4f),"A8DDE6");
   for(int k=0;k<22;k++){float a=k/22f*Mathf.PI*2;float s=.45f+Hash(77,k)*.3f;Box(kit,At(hx+Mathf.Cos(a)*2.2f,hz+Mathf.Sin(a)*1.75f,s/2),new Vector3(s,s,s),Hash(78,k)<.5f?"A3A9AE":"8E959B");}
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
