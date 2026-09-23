using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
 // Hooks Phase B juice into the world: lamp lights, ambient petals and fireflies, hearts while petting,
 // coin sparkles above earning guests, and a settle bounce on newly placed furniture.
 public sealed partial class VoxelWorld {
  VoxelFx fx;WorldLamps lamps;
  double fxCoins=-1,fxEarned;int fxGuest;
  Dictionary<string,string> placedObjects;
  public VoxelFx Effects=>fx;
  public WorldLamps Lamps=>lamps;
  void InitializeFx(){fx=new VoxelFx(geometry,transform);lamps=gameObject.AddComponent<WorldLamps>();lamps.View=WorldCamera;}
  void UpdateFx(float dt){
   if(fx==null)return;
   bool motion=model.State.settings.motion;Tween.Reduced=!motion;fx.Motion=motion;
   bool outdoors=!care&&storeInterior?.IsVisible!=true&&ViewFloor>=0;
   fx.Ambient(ViewCenter(),WorldLighting.Glow,outdoors);
   if(care&&careRig!=null&&(careRig.Reaction=="purr"||careRig.Reaction=="brush"||careRig.Reaction=="head_bump"))fx.Affection(careRig.Bindings["head"].position+Vector3.up*.55f,dt);
   double coins=model.State.coins;
   if(fxCoins>=0&&coins>fxCoins)fxEarned+=coins-fxCoins;
   fxCoins=coins;
   // A sparkle roughly every ten seconds of income, above a guest who is staying, so earnings read as coming from cats.
   double threshold=System.Math.Max(3,model.Rate()/6);
   if(fxEarned>=threshold&&!care&&!townMode){
    fxEarned=0;
    var staying=model.Actors.Where(a=>a.kind==ActorKind.Guest&&a.checkedIn).ToList();
    if(staying.Count>0){var guest=staying[fxGuest++%staying.Count];if(actors.TryGetValue(guest.id,out var rig)&&rig.Root.gameObject.activeInHierarchy)fx.Coins(rig.Root.position+Vector3.up*1.1f,6);}
   }
   else if(fxEarned>=threshold)fxEarned=0;
  }
  Vector3 ViewCenter(){
   if(!WorldCamera)return Vector3.zero;var ray=WorldCamera.ViewportPointToRay(new Vector3(.5f,.5f,0));
   return new Plane(Vector3.up,Vector3.zero).Raycast(ray,out float hit)?ray.GetPoint(hit):WorldCamera.transform.position;
  }
  // Called after the editable hotel is rebuilt; anything new or moved drops in with a bounce.
  void SettleNewObjects(bool sameMap){
   var now=model.State.objects.ToDictionary(o=>o.id,o=>o.x+","+o.z+","+o.rotation+","+o.floor);
   if(sameMap&&placedObjects!=null)foreach(var pair in now)if((!placedObjects.TryGetValue(pair.Key,out var before)||before!=pair.Value)&&objects.TryGetValue(pair.Key,out var node))Tween.Settle(node);
   placedObjects=now;
  }
 }
}
