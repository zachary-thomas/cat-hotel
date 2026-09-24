using System;
using System.Collections.Generic;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Animated life for each destination: sailboats, buoys, surf, sparkles, gulls, a crab and sunbathing cats at Seaside;
 // a campfire with cats warming up, ducks, a squirrel and birds at Forest Lodge; steam, bathing cats and a skater at
 // Snowcap Spa; butterflies at Meadow. Everything sits off the hotel lots and plots, has no colliders, and stays still
 // with reduced motion on.
 public sealed partial class VoxelWorld {
  readonly List<Action<float,float>> life=new List<Action<float,float>>();
  Transform lifeRoot;float lifeClock;
  public int LifeCount=>life.Count;
  void BuildDestinationLife(){
   life.Clear();lifeRoot=Group(scenery,"Destination life");
   switch(currentMap){case 0:MeadowLife();break;case 1:SeasideLife();break;case 2:ForestLife();break;case 3:SnowcapLife();break;}
   foreach(var a in life)a(0,0);
  }
  void UpdateLife(float dt){
   if(!model.State.settings.motion)return;lifeClock+=dt;foreach(var a in life)a(lifeClock,dt);
   smoke.RemoveAll(s=>!s.puff);
   foreach(var (puff,from,phase) in smoke){float c=Mathf.Repeat(lifeClock*.25f+phase,1);puff.localPosition=from+new Vector3(c*.5f+Mathf.Sin(lifeClock+phase*6)*.08f,c*1.6f,c*.2f);puff.localScale=Vector3.one*(.5f+c*1.1f)*Mathf.Sin(Mathf.Min(1,c*1.4f)*Mathf.PI*.5f+(c>.7f?(c-.7f)/.3f*Mathf.PI*.5f:0));}
  }
  Transform Piece(string name,float x,float z,float y=0){var g=Group(lifeRoot,name);g.localPosition=At(x,z,y);return g;}
  static float Yaw(float dx,float dz)=>Mathf.Atan2(dx,dz)*Mathf.Rad2Deg;
  // A cat from the manager palette, posed each frame with one of the rig's actions.
  GodotCatRig LifeCat(string coat,string markings,int seed,float x,float z,float y,float yaw,string action){
   var rig=new GodotCatRig(geometry,lifeRoot,ManagerCatArt.Recipe(geometry,coat,markings),seed);
   rig.Root.localPosition=At(x,z,y);rig.Root.localRotation=Quaternion.Euler(0,yaw,0);
   life.Add((t,dt)=>rig.Advance(dt,true,action,false));return rig;
  }

  void SeasideLife(){
   Sailboat(34,-15,5,6,.09f,0,"E98A7A","F4F1E8");Sailboat(-6,-31,10,3,.06f,2,"8CC8D6","F7CC62");Sailboat(48,2,6,10,.05f,4,"F4F1E8","F2A7B5");
   foreach(var (x,z,p) in new[]{(29f,-7f,0f),(30f,5f,1.3f),(15f,-28f,2.6f)})Buoy(x,z,p);
   // Surf rolls up the sand along both shorelines.
   int seg=0;for(float z=-23.5f;z<10;z+=1.6f)Foam(24.8f,z,Vector3.right,seg++);for(float x=-40;x<24;x+=1.6f)Foam(x,-24.8f,Vector3.back,seg++);
   for(int i=0;i<34;i++){bool east=i%2==0;float x=east?26+Hash(301,i)*22:-32+Hash(302,i)*52,z=east?-24+Hash(303,i)*38:-42+Hash(304,i)*15;Sparkle(x,z,Hash(305,i));}
   Gull(20,-20,8,5.5f,0);Gull(20,-20,6,6.2f,2.5f);Gull(38,4,7,5f,1.2f);
   // Cats sunbathing on striped towels between the umbrellas.
   string[] coats={"honey","cream","ginger"},marks={"tabby","solid","tuxedo"},towels={"F2A7B5","8CC8D6","F7CC62"};int k=0;
   foreach(var (x,z) in new[]{(-16f,-22.8f),(7.5f,-22.6f),(19f,-21.3f)}){Towel(x,z,towels[k]);LifeCat(coats[k],marks[k],200+k,x,z,.04f,90+k*40,"sleep");k++;}
   Crab(13,-23.4f);
   // The lighthouse lamp turns, glowing at dusk; surf breaks around the sea rocks.
   var lamp=Piece("Lighthouse lamp",LighthouseX,LighthouseZ,4.12f);Box(lamp,Vector3.zero,new Vector3(.6f,.6f,.6f),SurfacePalette.LanternGlow);Box(lamp,new Vector3(.45f,0,0),new Vector3(.3f,.34f,.34f),SurfacePalette.LanternGlow);
   var beam=Group(lamp,"Lighthouse glow");beam.localPosition=new Vector3(.8f,0,0);LampAnchor.Mark(beam,7,1.2f);
   life.Add((t,dt)=>lamp.localRotation=Quaternion.Euler(0,t*45,0));
   int r=0;foreach(var (x,z,w) in SeaRocks)for(int q=0;q<4;q++){var ring=Piece("Rock surf",x,z,.1f);float a0=q*Mathf.PI*.5f;Box(ring,new Vector3(Mathf.Cos(a0)*w*.7f,0,Mathf.Sin(a0)*w*.6f),new Vector3(.5f,.04f,.5f),"F4F8F6");float ph=r++*.7f;
    life.Add((t,dt)=>{float s=.8f+Mathf.Sin(t*1.1f+ph)*.3f;ring.localScale=new Vector3(s,1,s);});}
  }
  void Sailboat(float cx,float cz,float rx,float rz,float speed,float phase,string hull,string sail){
   var boat=Piece("Sailboat",cx+rx,cz);var body=Group(boat,"Hull");
   Box(body,new Vector3(0,.1f,0),new Vector3(2.2f,.36f,.8f),hull);Box(body,new Vector3(1.2f,.14f,0),new Vector3(.4f,.28f,.5f),hull);Box(body,new Vector3(0,.3f,0),new Vector3(2,.06f,.66f),"D8B98F");
   Box(body,new Vector3(0,1.5f,0),new Vector3(.1f,2.4f,.1f),"8A6B4F");
   for(int k=0;k<6;k++){float w=1.4f-k*.22f;Box(body,new Vector3(-.08f-w/2,.55f+k*.35f,0),new Vector3(w,.33f,.05f),sail);}
   Box(body,new Vector3(.18f,2.78f,0),new Vector3(.3f,.14f,.03f),hull);
   life.Add((t,dt)=>{float a=phase+t*speed;boat.localPosition=At(cx+Mathf.Cos(a)*rx,cz+Mathf.Sin(a)*rz,Mathf.Sin(t*1.7f+phase)*.05f);
    boat.localRotation=Quaternion.Euler(0,Yaw(-Mathf.Sin(a)*rx,Mathf.Cos(a)*rz)-90,0);body.localRotation=Quaternion.Euler(Mathf.Sin(t*1.3f+phase)*4,0,Mathf.Sin(t*1.1f+phase)*2);});
  }
  void Buoy(float x,float z,float phase){
   var b=Piece("Buoy",x,z);Box(b,new Vector3(0,.22f,0),new Vector3(.36f,.44f,.36f),"E98A7A");Box(b,new Vector3(0,.3f,0),new Vector3(.38f,.1f,.38f),"F4F1E8");Box(b,new Vector3(0,.56f,0),new Vector3(.08f,.24f,.08f),"425C35");
   life.Add((t,dt)=>{b.localPosition=At(x,z,Mathf.Sin(t*1.6f+phase)*.07f-.05f);b.localRotation=Quaternion.Euler(Mathf.Sin(t*1.2f+phase)*8,0,Mathf.Cos(t*.9f+phase)*6);});
  }
  void Foam(float x,float z,Vector3 seaward,int i){
   var f=Piece("Surf",x,z,.08f);bool alongZ=seaward.x!=0;
   Box(f,new Vector3(0,.05f,0),alongZ?new Vector3(.3f,.04f,1.3f):new Vector3(1.3f,.04f,.3f),"F4F8F6");
   Box(f,seaward*.28f+new Vector3(0,.04f,0),alongZ?new Vector3(.14f,.03f,.7f):new Vector3(.7f,.03f,.14f),"E4F2F2");
   float phase=i*.55f;
   life.Add((t,dt)=>{float s=Mathf.Sin(t*.8f+phase);f.localPosition=At(x,z,.08f)+seaward*(.35f+s*.3f);f.localScale=new Vector3(alongZ?.6f+.4f*(s*.5f+.5f):1,1,alongZ?1:.6f+.4f*(s*.5f+.5f));});
  }
  void Sparkle(float x,float z,float phase){
   var s=Piece("Sparkle",x,z,.12f);Box(s,Vector3.zero,new Vector3(.34f,.03f,.08f),"FFFFFF");Box(s,Vector3.zero,new Vector3(.08f,.03f,.34f),"FFFFFF");
   life.Add((t,dt)=>{float k=Mathf.Pow(Mathf.Max(0,Mathf.Sin(t*1.9f+phase*6.28f)),3);s.localScale=Vector3.one*k;});
  }
  void Gull(float cx,float cz,float r,float h,float phase){
   var g=Piece("Gull",cx+r,cz,h);
   Box(g,Vector3.zero,new Vector3(.18f,.16f,.46f),"FFFFFF");Box(g,new Vector3(0,.06f,.26f),new Vector3(.14f,.14f,.16f),"FFFFFF");Box(g,new Vector3(0,.04f,.37f),new Vector3(.05f,.04f,.09f),"F7CC62");Box(g,new Vector3(0,.02f,-.28f),new Vector3(.12f,.05f,.14f),"D9DDE0");
   var wings=new Transform[2];for(int s=0;s<2;s++){wings[s]=Group(g,"Wing");Box(wings[s],new Vector3((s==0?-1:1)*.3f,0,0),new Vector3(.5f,.04f,.24f),"D9DDE0");Box(wings[s],new Vector3((s==0?-1:1)*.58f,0,-.02f),new Vector3(.12f,.04f,.18f),"8E959B");}
   life.Add((t,dt)=>{float a=phase+t*.35f;g.localPosition=At(cx+Mathf.Cos(a)*r,cz+Mathf.Sin(a)*r,h+Mathf.Sin(t*.7f+phase)*.3f);g.localRotation=Quaternion.Euler(0,Yaw(-Mathf.Sin(a),Mathf.Cos(a)),-12);
    float flap=Mathf.Sin(t*5+phase)*28;wings[0].localRotation=Quaternion.Euler(0,0,-flap);wings[1].localRotation=Quaternion.Euler(0,0,flap);});
  }
  void Towel(float x,float z,string color){var tw=Piece("Towel",x,z,.015f);for(int s=0;s<5;s++)Box(tw,new Vector3(0,0,(s-2)*.36f),new Vector3(1,.02f,.36f),s%2==0?color:"F4F1E8");}
  void Crab(float x,float z){
   var c=Piece("Crab",x,z);Box(c,new Vector3(0,.1f,0),new Vector3(.3f,.12f,.22f),"E07F35");foreach(float s in new[]{-1f,1f}){Box(c,new Vector3(s*.2f,.12f,.14f),new Vector3(.1f,.08f,.1f),"E07F35");Box(c,new Vector3(s*.06f,.2f,.08f),new Vector3(.04f,.06f,.04f),"3B2F2A");for(int l=0;l<3;l++)Box(c,new Vector3(s*.19f,.04f,-.06f+l*.07f),new Vector3(.12f,.03f,.03f),"C9573A");}
   life.Add((t,dt)=>{float s=Mathf.Sin(t*.5f);c.localPosition=At(x+s*1.4f,z,Mathf.Abs(Mathf.Sin(t*9))*.02f);});
  }

  void ForestLife(){
   // Campfire with flickering flames and two cats warming their paws.
   const float fx=26.5f,fz=-1f;var fire=Piece("Campfire",fx,fz);
   for(int k=0;k<8;k++){float a=k/8f*Mathf.PI*2;Box(fire,new Vector3(Mathf.Cos(a)*.55f,.1f,Mathf.Sin(a)*.55f),Vector3.one*.24f,k%2==0?"A3A9AE":"8E959B");}
   Box(fire,new Vector3(0,.12f,0),new Vector3(.8f,.12f,.14f),"7A5A42");Box(fire,new Vector3(0,.14f,0),new Vector3(.14f,.12f,.8f),"6E4A3B");
   var flames=new Transform[3];string[] flameColors={SurfacePalette.LanternGlow,"F2A03C","E9683A"};
   for(int k=0;k<3;k++){flames[k]=Group(fire,"Flame");flames[k].localPosition=new Vector3(0,.25f,0);Box(flames[k],new Vector3(0,.18f-k*.04f,0),new Vector3(.4f-k*.1f,.36f+k*.1f,.4f-k*.1f),flameColors[k]);}
   var glow=Group(fire,"Campfire glow");glow.localPosition=new Vector3(0,.8f,0);LampAnchor.Mark(glow,4.5f,1.1f);
   life.Add((t,dt)=>{for(int k=0;k<3;k++){float f=.8f+Mathf.PerlinNoise(t*3+k*7,k)*.5f;flames[k].localScale=new Vector3(1,f,1);flames[k].localRotation=Quaternion.Euler(0,t*40*(k%2==0?1:-1),0);}});
   LifeCat("ginger","tabby",210,fx-1.6f,fz+.4f,0,Yaw(1.6f,-.4f),"warm");LifeCat("charcoal","tuxedo",211,fx+1.4f,fz+1f,0,Yaw(-1.4f,-1f),"warm");
   // Ducks paddle along the pond across the road.
   for(int d=0;d<3;d++)Duck(-4,21.4f,7,.6f,d*.9f,d==0);
   Squirrel(15,-27);
   foreach(var (cx,cz,p) in new[]{(0f,-30f,0f),(-18f,-20f,2f)})Bird(cx,cz,p);
  }
  void Duck(float cx,float cz,float rx,float rz,float phase,bool mother){
   float k=mother?1:.6f;var d=Piece("Duck",cx,cz);
   Box(d,new Vector3(0,.12f,0)*k,new Vector3(.3f,.22f,.5f)*k,mother?"8A6B4F":"F7CC62");Box(d,new Vector3(0,.32f,.2f)*k,new Vector3(.18f,.2f,.18f)*k,mother?"4F725B":"F7CC62");Box(d,new Vector3(0,.3f,.33f)*k,new Vector3(.1f,.05f,.12f)*k,"E07F35");
   life.Add((t,dt)=>{float a=Mathf.Sin(t*.12f+phase*.3f)*1.2f;float x=cx+Mathf.Sin(a)*rx,z=cz+Mathf.Sin(a*2)*rz;float dx=Mathf.Cos(a)*rx,dz=Mathf.Cos(a*2)*2*rz;
    d.localPosition=At(x-phase*.9f*Mathf.Sign(dx),z,Mathf.Sin(t*2+phase)*.02f);d.localRotation=Quaternion.Euler(0,Yaw(dx,dz),Mathf.Sin(t*2.4f+phase)*4);});
  }
  void Squirrel(float x,float z){
   var s=Piece("Squirrel",x,z);Box(s,new Vector3(0,.14f,0),new Vector3(.16f,.22f,.28f),"B8683E");Box(s,new Vector3(0,.3f,.12f),new Vector3(.14f,.14f,.14f),"B8683E");Box(s,new Vector3(0,.3f,-.2f),new Vector3(.14f,.34f,.12f),"D9824A");
   life.Add((t,dt)=>{float cycle=t%6;float hop=cycle<3?Mathf.Abs(Mathf.Sin(cycle*Mathf.PI*2)):0;float along=Mathf.PingPong(t*.35f,2.4f)-1.2f;s.localPosition=At(x+along,z+Mathf.Sin(t*.3f)*.6f,hop*.25f);s.localRotation=Quaternion.Euler(0,Mathf.Repeat(t*.35f,4.8f)<2.4f?90:-90,0);});
  }
  void Bird(float cx,float cz,float phase){
   var b=Piece("Bird",cx,cz,7);Box(b,Vector3.zero,new Vector3(.14f,.12f,.3f),"5F7040");Box(b,new Vector3(0,.04f,.18f),new Vector3(.05f,.03f,.07f),"E3B04B");
   var wings=new Transform[2];for(int s=0;s<2;s++){wings[s]=Group(b,"Wing");Box(wings[s],new Vector3((s==0?-1:1)*.2f,0,0),new Vector3(.32f,.03f,.16f),"738448");}
   life.Add((t,dt)=>{float a=phase+t*.45f;b.localPosition=At(cx+Mathf.Cos(a)*9,cz+Mathf.Sin(a)*5,7+Mathf.Sin(t+phase));b.localRotation=Quaternion.Euler(0,Yaw(-Mathf.Sin(a)*9,Mathf.Cos(a)*5),0);float flap=Mathf.Sin(t*9+phase)*35;wings[0].localRotation=Quaternion.Euler(0,0,-flap);wings[1].localRotation=Quaternion.Euler(0,0,flap);});
  }

  void SnowcapLife(){
   // Steam curls up from the hot spring while two cats soak with their eyes closed.
   for(int k=0;k<8;k++){float px=SpringX-1.4f+Hash(401,k)*2.8f,pz=SpringZ-.8f+Hash(402,k)*1.6f,phase=Hash(403,k)*4;var puff=Piece("Steam",px,pz,.3f);Box(puff,Vector3.zero,Vector3.one*.32f,"F8FAF8");
    life.Add((t,dt)=>{float c=Mathf.Repeat(t*.35f+phase,1);puff.localPosition=At(px+Mathf.Sin(t*.8f+phase)*.2f,pz,.3f+c*1.8f);puff.localScale=Vector3.one*Mathf.Sin(c*Mathf.PI)*(1+c);});}
   LifeCat("cream","solid",220,SpringX-.7f,SpringZ-.3f,-.42f,Yaw(1,.2f),"sleep");LifeCat("gray","tabby",221,SpringX+.8f,SpringZ+.4f,-.42f,Yaw(-1,-.3f),"sleep");
   // A cat skates circles on the frozen pond across the road.
   var skater=LifeCat("cocoa","tuxedo",222,-4.4f,19.8f,.06f,0,"walk");life.RemoveAt(life.Count-1);
   life.Add((t,dt)=>{float a=t*.5f;skater.Root.localPosition=At(-4.4f+Mathf.Cos(a)*1.8f,19.8f+Mathf.Sin(a)*.7f,.06f);skater.Root.localRotation=Quaternion.Euler(0,Yaw(-Mathf.Sin(a)*1.8f,Mathf.Cos(a)*.7f),Mathf.Sin(t*2)*6);skater.Advance(dt,true,"walk",true);});
  }
  const float SpringX=31.5f,SpringZ=8.5f;

  void MeadowLife(){
   // Butterflies drift over the wildflower plot and the lawn beside the road.
   string[] wings={"F2A7B5","F7CC62","C9B6E4","8CC8D6"};int i=0;
   foreach(var (x,z) in new[]{(17f,-6f),(19f,3f),(16f,8f),(-17f,-4f),(-18f,6f),(3f,-17f)})Butterfly(x,z,wings[i%wings.Length],i++*1.7f);
  }
  void Butterfly(float cx,float cz,string color,float phase){
   var b=Piece("Butterfly",cx,cz,1);Box(b,Vector3.zero,new Vector3(.04f,.04f,.14f),"3B2F2A");
   var w=new Transform[2];for(int s=0;s<2;s++){w[s]=Group(b,"Wing");Box(w[s],new Vector3((s==0?-1:1)*.1f,0,.02f),new Vector3(.16f,.02f,.16f),color);Box(w[s],new Vector3((s==0?-1:1)*.08f,0,-.08f),new Vector3(.1f,.02f,.1f),Shade(color,-.1f));}
   life.Add((t,dt)=>{float a=phase+t*.4f;float x=cx+Mathf.Sin(a)*2.2f+Mathf.Sin(a*2.3f)*.8f,z=cz+Mathf.Cos(a*1.3f)*1.6f;b.localPosition=At(x,z,.9f+Mathf.Abs(Mathf.Sin(t*2+phase))*.5f);b.localRotation=Quaternion.Euler(0,Yaw(Mathf.Cos(a),-Mathf.Sin(a*1.3f)),0);
    float flap=Mathf.Sin(t*14+phase)*55;w[0].localRotation=Quaternion.Euler(0,0,-flap);w[1].localRotation=Quaternion.Euler(0,0,flap);});
  }
 }
}
