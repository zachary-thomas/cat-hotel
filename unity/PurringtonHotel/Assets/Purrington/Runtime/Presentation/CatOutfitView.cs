using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
// Wear parts are voxel boxes in units of the anchor's core mesh width.
public static class CatOutfitView {
 public static string Signature(IDictionary<string,string> outfit)=>outfit==null?"":string.Join("|",Wardrobe.Slots.Select(slot=>outfit.TryGetValue(slot,out var id)?id:""));

 public static void Apply(GodotGeometry geometry,GodotCatRig rig,IDictionary<string,string> outfit){
  foreach(var slot in Wardrobe.Slots){
   if(!rig.Bindings.TryGetValue(slot=="head"?"head":"body",out var anchor))continue;
   var old=anchor.Find("Wear_"+slot);if(old){old.gameObject.SetActive(false);old.SetParent(null);Release(old.gameObject);}
   if(outfit==null||!outfit.TryGetValue(slot,out var id)||string.IsNullOrEmpty(id))continue;
   var wear=Wardrobe.Find(id);if(wear==null||wear.slot!=slot)continue;
   var bounds=CoreBounds(anchor);float unit=Mathf.Max(.05f,bounds.size.x);
   // Miso's authored eyes and muzzle point along +Z, so the neck origin is on the body's +Z face.
   var origin=slot=="neck"?new Vector3(bounds.center.x,bounds.max.y-.15f*unit,bounds.max.z+.4f*unit):new Vector3(bounds.center.x,bounds.max.y,bounds.center.z);
   var root=new GameObject("Wear_"+slot).transform;root.SetParent(anchor,false);root.localPosition=origin;
   foreach(var part in wear.parts){var box=part["box"];if(box==null||box.Count()!=6)continue;var cube=GameObject.CreatePrimitive(PrimitiveType.Cube);Release(cube.GetComponent<Collider>());cube.name="Wear part";cube.transform.SetParent(root,false);var size=new Vector3((float)box[3],(float)box[4],(float)box[5])*unit;cube.transform.localPosition=new Vector3((float)box[0],(float)box[1],(float)box[2])*unit+size/2;cube.transform.localScale=size;cube.GetComponent<MeshRenderer>().sharedMaterial=geometry.Material((string)part["color"]);}
  }
 }

 // The first direct authored mesh is the body/head core. Ears, eyes, limbs and props are separate children.
 static Bounds CoreBounds(Transform anchor){
  var filter=anchor.GetComponent<MeshFilter>();if(!filter)foreach(Transform child in anchor){filter=child.GetComponentInChildren<MeshFilter>(true);if(filter)break;}
  if(!filter||!filter.sharedMesh)return new Bounds(Vector3.zero,Vector3.one*.3f);
  var meshBounds=filter.sharedMesh.bounds;var result=new Bounds();bool any=false;
  for(int i=0;i<8;i++){var corner=meshBounds.center+Vector3.Scale(meshBounds.extents,new Vector3((i&1)==0?-1:1,(i&2)==0?-1:1,(i&4)==0?-1:1));var point=anchor.InverseTransformPoint(filter.transform.TransformPoint(corner));if(!any){result=new Bounds(point,Vector3.zero);any=true;}else result.Encapsulate(point);}
  return result;
 }
 static void Release(Object value){if(!value)return;if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);}
}
}
