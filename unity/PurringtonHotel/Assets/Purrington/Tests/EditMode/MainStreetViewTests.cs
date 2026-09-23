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
    Assert.That(shell.localScale.x,Is.EqualTo(f.w*VoxelWorld.Unit).Within(.001));
    Assert.That(shell.localScale.z,Is.EqualTo(f.d*VoxelWorld.Unit).Within(.001));
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
