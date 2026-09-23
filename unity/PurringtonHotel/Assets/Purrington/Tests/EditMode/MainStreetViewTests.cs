using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;
namespace Purrington.Tests {
 public sealed class MainStreetViewTests {
  GameObject root; GodotGeometry geometry;
  [SetUp] public void Setup(){TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);root=new GameObject("Town test");geometry=new GodotGeometry();}
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);geometry.Dispose();}
  [Test] public void ExteriorCoversAuthoredFootprintsAndKeepsWalkingAnchorsClear(){
   var art=new MainStreetArt(geometry,root.transform,TownContent.Current);
   Assert.That(art.Storefronts.Count,Is.EqualTo(2));
   Assert.That(art.Root.GetComponentsInChildren<TownInterior>(true).Length,Is.Zero);
   foreach(var id in new[]{"paw_mart","clothing"}){
    var node=art.Storefronts[id];var f=TownContent.Current.Shop(id).footprint;
    var shell=node.Find("Opaque shell");Assert.That(shell,Is.Not.Null);
    // The shell is the union of the plan's rooms and fills the authored footprint exactly.
    var renderers=shell.GetComponentsInChildren<Renderer>();Assert.That(renderers.Length,Is.EqualTo(ShopPlan.For(id).Rooms.Length));
    var b=renderers[0].bounds;foreach(var r in renderers)b.Encapsulate(r.bounds);
    Assert.That(b.size.x,Is.EqualTo(f.w*VoxelWorld.Unit).Within(.01));Assert.That(b.size.z,Is.EqualTo(f.d*VoxelWorld.Unit).Within(.01));
    Assert.That(b.center.x,Is.EqualTo((f.x+f.w/2)*VoxelWorld.Unit).Within(.01));Assert.That(b.center.z,Is.EqualTo((f.z+f.d/2)*VoxelWorld.Unit).Within(.01));
    // The door lines up with the street door node, and the shop sits back from the sidewalk behind its front garden.
    var door=node.Find("Door");var doorNode=TownContent.Current.Point(TownContent.Current.Shop(id).door);
    Assert.That(door.localPosition.x/VoxelWorld.Unit,Is.EqualTo(doorNode.x).Within(.05));
    Assert.That(f.z+f.d,Is.LessThan(MainStreetArt.HotelSidewalkZ-2),id+" is set back from the sidewalk");
    Assert.That(art.Root.Find(id+" front garden"),Is.Not.Null);
    Assert.That(node.GetComponentsInChildren<TownStoreHit>().Length,Is.GreaterThanOrEqualTo(2));
    var roof=node.Find("Opaque roof");Assert.That(roof,Is.Not.Null,id+" roof root");
    var roofRenderer=roof.GetComponentInChildren<Renderer>();
    Assert.That(roofRenderer,Is.Not.Null,id+" roof must contain an authored surface renderer");
    Assert.That(roofRenderer.sharedMaterial.color.a,Is.EqualTo(1));
   }
   foreach(var id in TownContent.Current.StreetIds){var p=TownContent.Current.Point(id);Assert.That(art.IsPaved(new Vector3(p.x,0,p.z)),Is.True,id);}
   Assert.That(art.SquareBounds.Contains(new Vector3(0,0,25*VoxelWorld.Unit)),Is.True);
  }
  [Test] public void PavementResolvesMidLinkButRejectsGrass(){
   Assert.That(MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(0,16)),Is.Not.Null);
   Assert.That(MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(10,28)),Is.Null);
  }
  [Test] public void ManagerSharesTheHotelCatRigForEveryCoatAndMarking(){
   var guest=new GodotCatRig(geometry,root.transform,"cats","0",0);var guestBindings=guest.Bindings.Keys.OrderBy(k=>k).ToArray();
   foreach(var coat in ManagerCatArt.Coats){
    var shades=new System.Collections.Generic.HashSet<string>();
    foreach(var marking in ManagerCatArt.Markings){
     var rig=new GodotCatRig(geometry,root.transform,ManagerCatArt.Recipe(geometry,coat,marking),91);
     rig.Advance(.1f,true,"walk",true);
     Assert.That(rig.Bindings.Keys.OrderBy(k=>k).ToArray(),Is.EqualTo(guestBindings),"same voxel cat as the hotel guests");
     foreach(var name in new[]{"head","body","eyes.0","eyes.1","ears.0","ears.1","mouth"})Assert.That(rig.Bindings[name].gameObject.activeInHierarchy,Is.True);
     var eye=rig.Bindings["eyes.0"].GetComponentInChildren<Renderer>().sharedMaterial.color;
     var fur=rig.Bindings["ears.0"].GetComponentInChildren<Renderer>().sharedMaterial.color;
     Assert.That(Mathf.Abs(eye.grayscale-fur.grayscale),Is.GreaterThan(.15f),coat);
     shades.Add(string.Join(",",rig.Root.GetComponentsInChildren<Renderer>(true).Select(r=>ColorUtility.ToHtmlStringRGB(r.sharedMaterial.color)).Distinct().OrderBy(c=>c)));
     Object.DestroyImmediate(rig.Root.gameObject);
    }
    Assert.That(shades.Count,Is.EqualTo(ManagerCatArt.Markings.Length),coat+": each marking looks different");
   }
   Object.DestroyImmediate(guest.Root.gameObject);
  }
 }
}
