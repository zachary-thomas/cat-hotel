using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Phase C: cat blush, the shell detail kit, the retired Godot sign, roofs and destination kits.
 public sealed class WorldDetailTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  GameObject root;
  [SetUp] public void Setup(){ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);root=new GameObject("detail test");}
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);}

  [Test] public void EveryCatHasTwoBlushCheeksOnItsHead(){
   using(var geometry=new GodotGeometry()){
    foreach(var rig in new[]{new GodotCatRig(geometry,root.transform,"cats","0",0),new GodotCatRig(geometry,root.transform,"staff","0",1),new GodotCatRig(geometry,root.transform,ManagerCatArt.Recipe(geometry,"charcoal","tuxedo"),2)}){
     var head=rig.Bindings["head"];var cheeks=head.GetComponentsInChildren<Transform>(true).Where(t=>t.name=="Blush").ToList();
     Assert.AreEqual(2,cheeks.Count,rig.Root.name);
     // Cheeks sit on either side of the face, below the eyes.
     var eyeY=rig.Root.InverseTransformPoint(rig.Bindings["eyes.0"].position).y;
     foreach(var c in cheeks)Assert.That(rig.Root.InverseTransformPoint(c.position).y,Is.LessThan(eyeY));
     Assert.That(Mathf.Sign(rig.Root.InverseTransformPoint(cheeks[0].position).x),Is.Not.EqualTo(Mathf.Sign(rig.Root.InverseTransformPoint(cheeks[1].position).x)));
    }
   }
  }

  [Test] public void HotelShellGetsEntranceLanternsAndSconcesAndTheOldSignIsRetired(){
   var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);
   var names=root.GetComponentsInChildren<LampAnchor>(true).Select(a=>a.name).ToList();
   Assert.That(names.Count(n=>n=="Entrance lantern glow"),Is.GreaterThanOrEqualTo(2),"lanterns frame the front door");
   Assert.That(names.Count(n=>n=="Sconce glow"),Is.GreaterThan(0),"inside walls carry sconces");
   var sign=root.GetComponentsInChildren<TextMesh>(true).FirstOrDefault(t=>t.text=="Meadow House");
   Assert.That(sign==null||!sign.gameObject.activeInHierarchy,Is.True,"the Godot Meadow House board gives way to the PURRINGTON arch");
  }

  [Test] public void SeasideLifeMovesOnlyWithMotionOn(){
   var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);model.State.currentHotel=1;
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);
   var all=root.GetComponentsInChildren<Transform>(true);
   Assert.AreEqual(3,all.Count(t=>t.name=="Sailboat"));Assert.That(all.Count(t=>t.name=="Surf"),Is.GreaterThan(20));Assert.AreEqual(3,all.Count(t=>t.name=="Towel"));
   var boat=all.First(t=>t.name=="Sailboat");var step=typeof(VoxelWorld).GetMethod("UpdateLife",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
   model.State.settings.motion=false;var before=boat.localPosition;step.Invoke(world,new object[]{2f});Assert.AreEqual(before,boat.localPosition,"reduced motion keeps the harbour still");
   model.State.settings.motion=true;step.Invoke(world,new object[]{2f});Assert.AreNotEqual(before,boat.localPosition,"boats sail");
  }

  [Test] public void RoofsStepUpFromTheirEdges(){
   var cells=new System.Collections.Generic.HashSet<Vector2Int>();for(int x=0;x<5;x++)for(int z=0;z<5;z++)cells.Add(new Vector2Int(x,z));cells.Remove(new Vector2Int(4,4));
   var depth=VoxelWorld.RoofDepths(cells);
   Assert.AreEqual(1,depth[new Vector2Int(0,0)]);Assert.AreEqual(2,depth[new Vector2Int(1,2)]);Assert.AreEqual(3,depth[new Vector2Int(2,2)]);
   Assert.AreEqual(1,depth[new Vector2Int(3,4)],"cells beside a notch are edges too");Assert.AreEqual(cells.Count,depth.Count);
  }

  [Test] public void DestinationKitsStayOffTheHotelLotsRoadsAndHouses(){
   for(int map=0;map<=3;map++){
    Object.DestroyImmediate(root);root=new GameObject("detail test");
    var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);model.State.currentHotel=map;
    var world=root.AddComponent<VoxelWorld>();world.Initialize(model);
    var kit=root.GetComponentsInChildren<Transform>(true).FirstOrDefault(t=>t.name=="Destination kit");Assert.IsNotNull(kit,"map "+map);
    var meshes=kit.GetComponentsInChildren<MeshFilter>(true);Assert.That(meshes.Length,Is.GreaterThan(0),"map "+map+" has props");
    // Reserved ground, in authored units: the base lot and every purchasable plot, then the map's roads and neighbour houses.
    var reserved=new System.Collections.Generic.List<Rect>();
    var m=model.Map();Rect Lot(Newtonsoft.Json.Linq.JToken r)=>new Rect((float)r[0]*VoxelWorld.Unit,(float)r[1]*VoxelWorld.Unit,(float)r[2]*VoxelWorld.Unit,(float)r[3]*VoxelWorld.Unit);
    reserved.Add(Lot(m["base"]));foreach(var plot in m["plots"])reserved.Add(Lot(plot["rect"]));
    using(var geometry=new GodotGeometry())foreach(var r in geometry.Map(map)["sceneryBounds"])reserved.Add(new Rect((float)r[0],(float)r[1],(float)r[2],(float)r[3]));
    foreach(var f in meshes)foreach(var v in f.sharedMesh.vertices){
     var p=kit.InverseTransformPoint(f.transform.TransformPoint(v));
     foreach(var r in reserved)Assert.IsFalse(r.xMin+.05f<p.x&&p.x<r.xMax-.05f&&r.yMin+.05f<p.z&&p.z<r.yMax-.05f,"map "+map+" prop at "+p+" overlaps "+r);
    }
   }
  }
 }
}
