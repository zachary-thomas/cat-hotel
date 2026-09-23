using Purrington.Domain;
using UnityEngine;
using Newtonsoft.Json.Linq;
using System.Linq;
using System.Collections.Generic;

namespace Purrington.Presentation
{
 public sealed partial class VoxelWorld
 {
  readonly Dictionary<string,float> deskElevations=new Dictionary<string,float>();
  static float CountertopHeight(JObject recipe)
  {
   float bestArea=0,top=.74f;
   System.Action<JObject,Matrix4x4> visit=null;
   visit=(node,parent)=>{
    var matrix=parent*GodotGeometry.Matrix(node["transform"]);
    foreach(var part in node["parts"]??new JArray()){
     if((string)part["mesh"]!="cube")continue;
     var m=matrix*GodotGeometry.Matrix(part["transform"]);
     var size=m.lossyScale;float area=Mathf.Abs(size.x*size.z);
     if(Mathf.Abs(size.y)>.25f||area<=bestArea||Mathf.Abs(size.x)<.7f||Mathf.Abs(size.z)<.7f)continue;
     bestArea=area;top=m.MultiplyPoint3x4(Vector3.up*.5f).y;
    }
    foreach(var child in node["children"]??new JArray())visit((JObject)child,matrix);
   };
   visit(recipe,Matrix4x4.identity);return top;
  }
  readonly Dictionary<Transform,float> noseReach=new Dictionary<Transform,float>();
  // Venue approach points sit a quarter lot from the furniture edge, closer than a cat's head reaches, so cats standing at a
  // desk, counter or bowl (guests in front, staff behind) step back just far enough that their nose stops at the edge instead of inside it.
  void ClearVenue(ActorSnapshot actor,GodotCatRig rig,ref Vector3 position,float face)
  {
   if(actor.action.StartsWith("walk")||string.IsNullOrEmpty(actor.venueId))return;
   var o=model.State.objects.FirstOrDefault(x=>x.id==actor.venueId);if(o==null)return;
   HotelModel.Size(o,out float w,out float d);
   float x0=o.x*Unit,x1=(o.x+w)*Unit,z0=o.z*Unit,z1=(o.z+d)*Unit;
   // Seats, beds and mats place the cat on top of the furniture; only cats standing beside it are adjusted.
   if(position.x>x0&&position.x<x1&&position.z>z0&&position.z<z1)return;
   float reach=NoseReach(rig);
   var forward=new Vector2(Mathf.Sin(face),Mathf.Cos(face));
   float enter=RayEnter(new Vector2(position.x,position.z),forward,x0,x1,z0,z1);
   if(enter<reach){position.x-=forward.x*(reach-enter);position.z-=forward.y*(reach-enter);}
  }
  // Distance along dir from p to where it enters the rectangle, or infinity when it misses.
  static float RayEnter(Vector2 p,Vector2 dir,float x0,float x1,float z0,float z1)
  {
   float tMin=0,tMax=float.PositiveInfinity;
   for(int axis=0;axis<2;axis++)
   {
    float origin=axis==0?p.x:p.y,delta=axis==0?dir.x:dir.y,lo=axis==0?x0:z0,hi=axis==0?x1:z1;
    if(Mathf.Abs(delta)<1e-5f){if(origin<lo||origin>hi)return float.PositiveInfinity;continue;}
    float a=(lo-origin)/delta,b=(hi-origin)/delta;if(a>b){var t=a;a=b;b=t;}
    tMin=Mathf.Max(tMin,a);tMax=Mathf.Min(tMax,b);if(tMin>tMax)return float.PositiveInfinity;
   }
   return tMin;
  }
  // How far the head reaches ahead of the rig origin, measured once per rig from its built geometry.
  float NoseReach(GodotCatRig rig)
  {
   if(noseReach.TryGetValue(rig.Root,out float reach))return reach;
   reach=0;
   foreach(var renderer in rig.Bindings["head"].GetComponentsInChildren<MeshRenderer>())
   {
    var mesh=renderer.GetComponent<MeshFilter>();if(!mesh||!mesh.sharedMesh)continue;var b=mesh.sharedMesh.bounds;
    for(int i=0;i<8;i++){var corner=b.center+Vector3.Scale(b.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));reach=Mathf.Max(reach,rig.Root.InverseTransformPoint(renderer.transform.TransformPoint(corner)).z*rig.Root.localScale.z);}
   }
   if(reach<=0)reach=.45f;
   return noseReach[rig.Root]=reach+.04f;
  }
  void StaffDeskPose(ActorSnapshot actor,GodotCatRig rig,ref Vector3 position)
  {
   if(!objects.TryGetValue(actor.venueId,out var counter))return;
   // Measure authored counter and head geometry in their own spaces. The old
   // universal offset left short staff hidden by taller counters.
   var item=model.State.objects.First(o=>o.id==actor.venueId);
   string key=actor.id+":"+item.itemId;
   if(!deskElevations.TryGetValue(key,out float lift)){
   float desktop=CountertopHeight(geometry.Recipe("items",item.itemId));
   var head=rig.Bindings["head"];
   float headBottom=float.PositiveInfinity;
   foreach(var renderer in head.GetComponentsInChildren<MeshRenderer>())
   {
    var mesh=renderer.GetComponent<MeshFilter>();if(!mesh)continue;
    var bounds=mesh.sharedMesh.bounds;
    for(int i=0;i<8;i++)
    {
     var corner=bounds.center+Vector3.Scale(bounds.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));
     var local=rig.Root.InverseTransformPoint(renderer.transform.TransformPoint(corner));
     headBottom=Mathf.Min(headBottom,local.y*rig.Root.localScale.y);
    }
   }
   if(float.IsInfinity(headBottom))headBottom=.7f;
   lift=Mathf.Max(0,counter.position.y+desktop-GroundY-headBottom+.08f);
   deskElevations[key]=lift;
   }
   position.y=GroundY+lift;
   var platform=rig.Root.Find("Desk staff platform");
   if(!platform)
   {
    platform=Group(rig.Root,"Desk staff platform");
    Box(platform,Vector3.zero,Vector3.one,"A88558");
   }
   float scale=rig.Root.localScale.y;
   platform.localPosition=new Vector3(0,-lift/(2*scale),0);
   platform.localScale=new Vector3(.78f,Mathf.Max(.03f,lift)/scale,.78f);
  }
 }
}
