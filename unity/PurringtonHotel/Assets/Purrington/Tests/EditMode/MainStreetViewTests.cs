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
    Assert.That(node.Find("Opaque roof").GetComponent<Renderer>().sharedMaterial.color.a,Is.EqualTo(1));
   }
   foreach(var id in TownContent.Current.StreetIds){var p=TownContent.Current.Point(id);Assert.That(art.IsPaved(new Vector3(p.x,0,p.z)),Is.True,id);}
   Assert.That(art.SquareBounds.Contains(new Vector3(28*VoxelWorld.Unit,0,18*VoxelWorld.Unit)),Is.True);
  }
  [Test] public void PavementResolvesMidLinkButRejectsGrass(){
   Assert.That(MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(28,14)),Is.Not.Null);
   Assert.That(MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(35,18)),Is.Null);
  }
  [Test] public void AllCoatsAndMarkingsKeepFaceAndWearBindingsOnAnimatedRig(){
   foreach(var coat in ManagerCatArt.Coats)foreach(var marking in ManagerCatArt.Markings){
    var rig=new GodotCatRig(geometry,root.transform,ManagerCatArt.Recipe(coat,marking),91);
    rig.Advance(.1f,true,"walk",true);
    foreach(var name in new[]{"head","body","eyes.0","eyes.1","ears.0","ears.1","mouth"})Assert.That(rig.Bindings[name].gameObject.activeInHierarchy,Is.True);
    Assert.That(rig.Bindings["wear.head"].parent,Is.EqualTo(rig.Bindings["head"]));
    Assert.That(rig.Bindings["wear.neck"].parent,Is.EqualTo(rig.Bindings["body"]));
    Assert.That(rig.Bindings["wear.back"].parent,Is.EqualTo(rig.Bindings["body"]));
    var eye=rig.Bindings["eyes.0"].GetComponentInChildren<Renderer>().sharedMaterial.color;
    var fur=rig.Bindings["ears.0"].GetComponentInChildren<Renderer>().sharedMaterial.color;
    Assert.That(Mathf.Abs(eye.grayscale-fur.grayscale),Is.GreaterThan(.15f),coat);
    Assert.That(rig.Root.GetComponentsInChildren<Transform>().Count(t=>t.name.StartsWith("Marking")),marking=="solid"?Is.EqualTo(0):Is.GreaterThan(0));
    Object.DestroyImmediate(rig.Root.gameObject);
   }
  }
 }
}
