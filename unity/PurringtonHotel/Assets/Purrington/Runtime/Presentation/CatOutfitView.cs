using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
// Wear boxes use anchor units: one unit is the width of the head or body mesh.
public static class CatOutfitView {
 public static string Signature(IDictionary<string,string> outfit) => outfit==null?"":string.Join("|",Wardrobe.Slots.Select(slot=>outfit.TryGetValue(slot,out var id)?id:""));

 public static void Apply(GodotGeometry geometry,GodotCatRig rig,IDictionary<string,string> outfit) {
  foreach(var slot in Wardrobe.Slots) {
   if(!rig.Bindings.TryGetValue(slot=="head"?"head":"body",out var anchor))continue;
   var old=anchor.Find("Wear_"+slot);
   if(old){old.SetParent(null,false);Release(old.gameObject);}
   if(outfit==null||!outfit.TryGetValue(slot,out var id)||string.IsNullOrEmpty(id))continue;
   var wear=Wardrobe.Find(id);
   if(wear==null||wear.slot!=slot)continue;
   var bounds=LocalBounds(anchor,rig);
   float unit=Mathf.Max(.05f,bounds.size.x);
   // Authored eyes and muzzle face +z, so the neck piece belongs at bounds.max.z.
   var origin=slot=="neck"?new Vector3(bounds.center.x,bounds.max.y,bounds.max.z):new Vector3(bounds.center.x,bounds.max.y,bounds.center.z);
   var root=new GameObject("Wear_"+slot).transform;
   root.SetParent(anchor,false);
   root.localPosition=origin;
   foreach(var part in wear.parts) {
    var box=part["box"];
    var cube=GameObject.CreatePrimitive(PrimitiveType.Cube);
    Release(cube.GetComponent<Collider>());
    cube.name="Wear part";
    cube.transform.SetParent(root,false);
    var size=new Vector3((float)box[3],(float)box[4],(float)box[5])*unit;
    cube.transform.localPosition=new Vector3((float)box[0],(float)box[1],(float)box[2])*unit+size/2;
    cube.transform.localScale=size;
    cube.GetComponent<MeshRenderer>().sharedMaterial=geometry.Material((string)part["color"]);
   }
  }
 }

 // Geometry puts meshes below authored nodes. Exclude articulated rig parts and wear.
 static Bounds LocalBounds(Transform anchor,GodotCatRig rig) {
  var result=new Bounds(Vector3.zero,Vector3.zero);
  bool any=false;
  foreach(var filter in anchor.GetComponentsInChildren<MeshFilter>(true)) {
   if(filter.sharedMesh==null)continue;
   var child=filter.transform;
   while(child!=anchor&&child.parent!=anchor)child=child.parent;
   if(child!=anchor&&(child.name.StartsWith("Wear_")||rig.Bindings.Any(pair=>pair.Value==child&&(pair.Key=="head"||pair.Key=="tail"||pair.Key=="mouth"||pair.Key.StartsWith("ears.")||pair.Key.StartsWith("eyes.")||pair.Key.StartsWith("legs.")||pair.Key.StartsWith("props.")))))continue;
   var meshBounds=filter.sharedMesh.bounds;
   for(int i=0;i<8;i++) {
    var corner=meshBounds.center+Vector3.Scale(meshBounds.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));
    var local=anchor.InverseTransformPoint(filter.transform.TransformPoint(corner));
    if(!any){result=new Bounds(local,Vector3.zero);any=true;}else result.Encapsulate(local);
   }
  }
  return any?result:new Bounds(Vector3.zero,Vector3.one*.3f);
 }

 static void Release(Object value){if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);}
}
}
