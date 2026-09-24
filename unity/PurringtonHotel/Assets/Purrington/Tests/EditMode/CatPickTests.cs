using System.Linq;
using System.Reflection;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Tapping a guest cat opens its care screen from any destination and any viewed floor.
 public sealed class CatPickTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  GameObject root;
  [SetUp] public void Setup(){ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);root=new GameObject("pick test");}
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);}

  static void Call(VoxelWorld world,string method)=>typeof(VoxelWorld).GetMethod(method,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(world,null);
  HotelModel Model(int map){var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);model.State.currentHotel=map;return model;}
  static void BuildUpstairs(HotelModel model){
   model.State.settings.godMode=true;
   JObject Stairs(int x,int z)=>new JObject{{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",0},{"x",x},{"y",z}};
   var spot=Enumerable.Range(-12,24).SelectMany(x=>Enumerable.Range(-12,24).Select(z=>(x,z))).FirstOrDefault(p=>model.Quote("draw_room",Stairs(p.x,p.z)).success);
   Assert.IsTrue(model.Execute("draw_room",Stairs(spot.x,spot.z)).success);
  }
  VoxelWorld Settle(HotelModel model){var world=root.AddComponent<VoxelWorld>();world.Initialize(model);for(int i=0;i<40;i++){model.Tick(1.5f);Call(world,"Update");}Physics.SyncTransforms();return world;}
  static Vector2 ScreenOf(VoxelWorld world,WorldPick cat)=>world.WorldCamera.WorldToScreenPoint(cat.GetComponent<Collider>().bounds.center);

  [Test] public void TravellingFromATallerHotelShowsTheGroundFloor(){
   var model=Model(0);BuildUpstairs(model);
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);world.SetViewFloor(1);
   model.State.currentHotel=1;Call(world,"Refresh");
   Assert.AreEqual(0,world.ViewFloor,"Seaside has no upstairs, so its ground floor is shown with its roofs off");
   Assert.IsFalse(root.GetComponentsInChildren<Transform>().Any(t=>t.name=="Roof"),"no roof hides the resort's rooms");
  }

  [Test] public void EveryGuestCatIsTappableOnEveryDestination(){
   for(int map=0;map<=3;map++){
    Object.DestroyImmediate(root);root=new GameObject("pick test");
    var world=Settle(Model(map));
    var cats=root.GetComponentsInChildren<WorldPick>().Where(p=>p.catId>=0).ToList();Assert.That(cats.Count,Is.GreaterThan(0),"map "+map);
    foreach(var cat in cats){
     Assert.AreEqual(cat.catId,world.PickAt(ScreenOf(world,cat)).catId,"map "+map+": a tap on cat "+cat.catId+" wins over the bed or counter it stands at");
     Assert.That(world.PickAt(ScreenOf(world,cat)+new Vector2(18,-14)).catId,Is.GreaterThanOrEqualTo(0),"map "+map+": a tap just beside cat "+cat.catId+" still finds a cat");
    }
   }
  }

  [Test] public void GroundCatsStayTappableWhileLookingUpstairs(){
   var model=Model(0);BuildUpstairs(model);var world=Settle(model);
   var guest=model.Actors.First(a=>a.kind==ActorKind.Guest&&a.floor==0);
   world.SetViewFloor(1);Physics.SyncTransforms();
   var cat=root.GetComponentsInChildren<WorldPick>().First(p=>p.catId==guest.catId);
   Assert.AreEqual(guest.catId,world.PickAt(ScreenOf(world,cat)).catId);
  }
 }
}
