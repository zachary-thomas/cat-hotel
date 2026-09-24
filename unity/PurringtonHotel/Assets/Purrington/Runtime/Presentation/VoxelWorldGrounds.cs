using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Hotel grounds: the hotel lot and its plots get a light scatter of the destination's ground detail (grass and flowers at
 // Meadow, dune grass and shells at Seaside, ferns and mushrooms at Forest Lodge, drifts at Snowcap) on every cell that no
 // room, floor, path or furnishing uses. It rebuilds with the hotel, so building over a cell clears it.
 public sealed partial class VoxelWorld {
  void BuildGrounds(){
   var grounds=Group(layout,"Grounds");OnFloor(grounds,0);
   var m=model.Map();var hotel=model.Hotel();var ground=HotelModel.Floor(hotel,0);
   var rects=new[]{m["base"]}.Concat(m["plots"].Select(p=>p["rect"]));
   var saved=kit;kit=grounds; // the destination detail helpers draw into kit
   uint seed=(uint)(currentMap*6151+29);var seen=new System.Collections.Generic.HashSet<Vector2Int>();
   try{
    foreach(var r in rects){
     int x0=(int)r[0],z0=(int)r[1],w=(int)r[2],d=(int)r[3];
     for(int x=x0;x<x0+w;x++)for(int z=z0;z<z0+d;z++){
      if(!seen.Add(new Vector2Int(x,z)))continue;
      float pick=Hash(seed,(x+500)*1000+(z+500));if(pick>.13f)continue;
      if(!FreeCell(hotel,ground,x,z))continue;
      float ax=(x+.5f)*Unit,az=(z+.5f)*Unit,p=pick/.13f;
      switch(currentMap){
       case 1:if(p<.5f)Tuft(ax,az,"B7C27A","9FAE62");else if(p<.8f)Shell(ax,az,p);else Starfish(ax,az,p);break;
       case 2:if(p<.4f)Tuft(ax,az,"5F8A56","7FA36A");else if(p<.7f)Fern(ax,az);else Mushroom(ax,az,p);break;
       case 3:if(p<.55f)Drift(ax,az,p*.4f);else Tuft(ax,az,"B8C8D0","D9E4EA");break;
       default:if(p<.5f)Tuft(ax,az,"8FB86A","6E9B62");else Flowers(ax,az,p);break;
      }
     }
    }
   }finally{kit=saved;}
   Bake(grounds);
  }
  // A lot cell is free when nothing is built on it or next to it on the ground floor.
  bool FreeCell(HotelData hotel,FloorState ground,int x,int z){
   for(int dx=-1;dx<=1;dx++)for(int dz=-1;dz<=1;dz++){
    int cx=x+dx,cz=z+dz;string key=cx+","+cz;
    if(hotel.paths.ContainsKey(key))return false;
    if(ground!=null&&ground.cells.ContainsKey(key))return false;
   }
   float px=x+.5f,pz=z+.5f;
   if(model.State.rooms.Any(r=>r.floor==0&&HotelModel.RoomHas(r,px,pz)))return false;
   foreach(var o in model.State.objects){if(o.floor!=0)continue;HotelModel.Size(o,out float w,out float d);if(px>o.x-.6f&&px<o.x+w+.6f&&pz>o.z-.6f&&pz<o.z+d+.6f)return false;}
   return true;
  }
  void Mushroom(float x,float z,float p){string cap=p<.85f?"C8553C":"E0B070";Box(kit,At(x,z,.07f),new Vector3(.06f,.14f,.06f),"F4EBDD");Box(kit,At(x,z,.16f),new Vector3(.2f,.07f,.2f),cap);Box(kit,At(x+.02f,z+.02f,.2f),new Vector3(.05f,.02f,.05f),"F4F1E8");}
 }
}
