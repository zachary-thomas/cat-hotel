using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Phase C: cat blush, the shell detail kit and the retired Godot sign.
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
 }
}
