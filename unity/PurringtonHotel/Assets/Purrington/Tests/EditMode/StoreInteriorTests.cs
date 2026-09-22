using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class StoreInteriorTests {
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
}
