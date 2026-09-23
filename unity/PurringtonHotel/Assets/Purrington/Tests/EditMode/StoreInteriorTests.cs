using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class StoreInteriorTests {
 sealed class MemoryStore:ISaveStore {
  HotelState saved;public bool fail;
  public HotelState Load()=>saved==null?null:HotelModel.Copy(saved);
  public bool Save(HotelState state){if(fail)return false;saved=HotelModel.Copy(state);return true;}
 }
 GodotGeometry geometry;
 [SetUp] public void LoadTown(){TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);geometry=new GodotGeometry();}
 [TearDown] public void ReleaseGeometry(){geometry.Dispose();}
 [Test] public void StoresRemainHiddenUntilEntryAndOnlyOneIsVisible() {
  var root=new GameObject("test interiors");
  try {
   var view=new StoreInteriorView(geometry,root.transform);
   Assert.IsFalse(view.IsVisible);
   Assert.AreEqual(0,view.VisibleStoreCount);
   view.Enter("paw_mart");
   Assert.AreEqual("paw_mart",view.ActiveStoreId);
   Assert.AreEqual(1,view.VisibleStoreCount);
   Assert.AreEqual("Miso",view.OwnerName);
   Assert.AreEqual(1,root.GetComponentsInChildren<TownInterior>().Length);
   view.Enter("clothing");
   Assert.AreEqual("clothing",view.ActiveStoreId);
   Assert.AreEqual(1,view.VisibleStoreCount);
   Assert.AreEqual("Clover",view.OwnerName);
   Assert.AreEqual(1,root.GetComponentsInChildren<TownInterior>().Length);
   view.Exit();
   Assert.IsFalse(view.IsVisible);
   Assert.AreEqual(0,view.VisibleStoreCount);
  } finally {Object.DestroyImmediate(root);}
 }
 [Test] public void CashierRequiresArrivalAndBackClosesConversationFirst() {
  var root=new GameObject("test interiors");
  try {
   var view=new StoreInteriorView(geometry,root.transform);
   int selected=0;view.CashierSelected+=_=>selected++;
   view.Enter("paw_mart");
   Assert.IsTrue(view.SelectCashier());
   Assert.IsFalse(view.IsConversationOpen);
   view.Advance(30,true);
   Assert.IsTrue(view.IsConversationOpen);
   Assert.AreEqual(1,selected);
   Assert.IsTrue(view.Back());
   Assert.IsTrue(view.IsVisible);
   Assert.IsFalse(view.IsConversationOpen);
   Assert.IsTrue(view.Back());
   Assert.IsFalse(view.IsVisible);
  } finally {Object.DestroyImmediate(root);}
 }
 [TestCase("paw_mart")]
 [TestCase("clothing")]
 public void PlanHasSeveralRoomsJoinedByDoorwaysAndOneStreetDoor(string id){
  var plan=ShopPlan.For(id);Assert.That(plan.Rooms.Length,Is.GreaterThanOrEqualTo(3));
  var walls=plan.Walls();
  Assert.That(walls.Count(w=>!w.exterior),Is.GreaterThanOrEqualTo(plan.Rooms.Length),"partitions separate the rooms");
  // Every doorway splits its partition: the wall pieces on that line leave a gap around the doorway.
  foreach(var d in plan.Doorways)Assert.IsFalse(walls.Any(w=>!w.exterior&&Mathf.Abs(w.at.x-d.x)<w.size.x/2-.01f&&Mathf.Abs(w.at.z-d.y)<w.size.z/2-.01f),"doorway at "+d+" is open");
  Assert.IsFalse(walls.Any(w=>w.exterior&&Mathf.Abs(w.at.z-plan.Bounds.yMin)<.01f&&Mathf.Abs(w.at.x-plan.DoorX)<w.size.x/2),"street door is open");
  var f=TownContent.Current.Shop(id).footprint;
  Assert.That(plan.Size.x,Is.EqualTo(f.w*VoxelWorld.Unit).Within(.01));Assert.That(plan.Size.y,Is.EqualTo(f.d*VoxelWorld.Unit).Within(.01));
  Assert.That(plan.Bounds.center.magnitude,Is.LessThan(.01f),"plans are centered so the shell and the interior share a center");
 }
 [Test] public void UnknownStoreIsRejected() {
  var root=new GameObject("test interiors");
  try {var view=new StoreInteriorView(geometry,root.transform);Assert.Throws<System.ArgumentException>(()=>view.Enter("closed"));}
  finally {Object.DestroyImmediate(root);}
 }
 [TestCase("paw_mart")]
 [TestCase("clothing")]
 public void ExploreReopensSavedStoreWithoutFollowOverridingInteriorCamera(string id){
  var store=new MemoryStore();
  var content=ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
  var original=new HotelModel(store,content);
  Assert.IsTrue(original.LoadOrCreate().success);
  var door=TownContent.Current.Point(TownContent.Current.Shop(id).door);
  var saved=original.Hotel(0).town;saved.x=door.x;saved.z=door.z;saved.phase="street";saved.shop=id;saved.destination="";
  Assert.IsTrue(original.Save().success);
  var reloaded=new HotelModel(store,content);
  Assert.IsTrue(reloaded.LoadOrCreate().success);
  var host=new GameObject("saved shop camera regression");
  try {
   var world=host.AddComponent<VoxelWorld>();world.Initialize(reloaded);
   // ExploreMainStreet calls these in order, with Rebuild setting the world viewport between them.
   world.EnterTownMode();
   Assert.AreEqual(id,world.StoreInterior.ActiveStoreId);
   Assert.AreEqual(1,world.ActiveStoreInteriorCount);
   var camera=world.WorldCamera;
   world.SetWorldRect(new Rect(0,0,Screen.width,Screen.height));
   Vector3 framed=camera.transform.position;float size=camera.orthographicSize;
   world.FocusManager();
   Assert.That(Vector3.Distance(camera.transform.position,framed),Is.LessThan(.001f));
   Assert.That(camera.orthographicSize,Is.EqualTo(size).Within(.001f));
   var stage=world.StoreInterior.Focus;
   var screen=camera.WorldToViewportPoint(new Vector3(stage.x,stage.y,-stage.z));
   Assert.That(screen.x,Is.InRange(.1f,.9f));
   Assert.That(screen.y,Is.InRange(.1f,.9f));
   // A portrait sheet leaves only the upper half for the shop: fit every floor corner.
   var viewport=new Rect(0,Screen.height*.5f,Screen.width,Screen.height*.5f);world.SetWorldRect(viewport);
   var half=ShopPlan.For(id).Size/2;
   foreach(float x in new[]{-half.x,half.x})foreach(float z in new[]{-half.y,half.y}){
    var point=camera.WorldToScreenPoint(new Vector3(stage.x+x,0,-(stage.z+z)));
    Assert.IsTrue(viewport.Contains(point),"Shop floor is cropped at "+point);
   }
  } finally {Object.DestroyImmediate(host);}
 }
 [Test] public void LeavePersistsButSuspendingTownRetainsShopAndFailedLeaveKeepsView(){
  var store=new MemoryStore();var model=new HotelModel(store,ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));model.LoadOrCreate();model.SendManager("paw_mart_door");model.SkipManagerTravel();
  var host=new GameObject("Leave regression");try{
   var world=host.AddComponent<VoxelWorld>();world.Initialize(model);world.EnterTownMode();world.ExitTownMode();Assert.AreEqual("paw_mart",model.Hotel().town.shop);
   world.EnterTownMode();Assert.AreEqual(1,world.ActiveStoreInteriorCount);store.fail=true;world.ExitStoreInterior();Assert.AreEqual(1,world.ActiveStoreInteriorCount);Assert.AreEqual("paw_mart",model.Hotel().town.shop);
   store.fail=false;world.ExitStoreInterior();Assert.AreEqual(0,world.ActiveStoreInteriorCount);world.ExitTownMode();world.EnterTownMode();Assert.AreEqual(0,world.ActiveStoreInteriorCount);
   var reload=new HotelModel(store,ParityContent.Current);Assert.IsTrue(reload.LoadOrCreate().success);Assert.AreEqual("",reload.Hotel().town.shop);
  }finally{Object.DestroyImmediate(host);}
 }
 [TestCase(true)]
 [TestCase(false)]
 public void LeavingStoreRestoresStreetFollow(bool following){
  var model=new HotelModel(new MemoryStore(),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
  Assert.IsTrue(model.LoadOrCreate().success);
  var host=new GameObject("street follow regression");
  try {
   var world=host.AddComponent<VoxelWorld>();world.Initialize(model);world.EnterTownMode();
   if(!following)world.FitTown();
   model.Hotel(0).town.shop="paw_mart";world.EnterStoreInterior("paw_mart");world.ExitStoreInterior();
   var field=typeof(VoxelWorld).GetField("townFollowing",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
   Assert.AreEqual(following,(bool)field.GetValue(world));
  } finally {Object.DestroyImmediate(host);}
 }}
