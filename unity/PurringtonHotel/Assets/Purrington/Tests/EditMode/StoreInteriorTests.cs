using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class StoreInteriorTests {
 sealed class MemoryStore:ISaveStore {
  HotelState saved;
  public HotelState Load()=>saved==null?null:HotelModel.Copy(saved);
  public bool Save(HotelState state){saved=HotelModel.Copy(state);return true;}
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
  } finally {Object.DestroyImmediate(host);}
 }
}
