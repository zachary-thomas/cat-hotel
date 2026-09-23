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
