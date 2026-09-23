using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;
public sealed class ShoppingCartTests {
 GodotGeometry geometry;GameObject root;
 [SetUp] public void Setup(){TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);geometry=new GodotGeometry();root=new GameObject("cart tests");}
 [TearDown] public void Cleanup(){Object.DestroyImmediate(root);geometry.Dispose();}
 [Test] public void CartFollowsPawsThroughTurnsAndWheelsTrackDistance(){
  var cart=new ShoppingCartRig(geometry,root.transform,"manager");
  foreach(float angle in new[]{0f,90f,180f,270f}){
   var facing=Quaternion.Euler(0,angle,0);var at=new Vector3(4,.18f,7);
   cart.SetPose(at,facing,2,false);
   Assert.That(Vector3.Distance(cart.Root.localPosition,at+facing*Vector3.forward*cart.FrontOffset),Is.LessThan(.001f));
   Assert.That(Quaternion.Angle(cart.Root.localRotation,facing),Is.LessThan(.001f));
  }
  Assert.That(cart.WheelAngle,Is.Not.EqualTo(0));Assert.AreEqual(4,cart.Wheels.Count);
  cart.SetPose(Vector3.zero,Quaternion.identity,2,true);Assert.AreEqual(0,cart.WheelAngle);
  foreach(var wheel in cart.Wheels)Assert.That(Quaternion.Angle(wheel.localRotation,Quaternion.identity),Is.LessThan(.001f));
 }
 [Test] public void PurchaseRoutineParksDistinctCartsAndClothingHidesAll(){
  var view=new StoreInteriorView(geometry,root.transform);view.Enter("paw_mart");
  Assert.AreEqual(3,view.ShoppingCarts.Count);
  Assert.AreNotSame(view.ShoppingCarts[0].Root,view.ShoppingCarts[1].Root);
  Assert.IsTrue(view.SelectCashier());view.Advance(30,true);
  Assert.IsTrue(view.StartPurchaseRoutine("welcome_basket"));view.Advance(30,true);
  Assert.IsFalse(view.IsShopping);Assert.IsTrue(view.IsConversationOpen);
  Assert.AreEqual("welcome_basket",view.ShoppingCarts[0].Contents);
  view.Advance(0,false);foreach(var cart in view.ShoppingCarts)Assert.AreEqual(0,cart.WheelAngle);
  view.Enter("clothing");foreach(var cart in view.ShoppingCarts)Assert.IsFalse(cart.Root.gameObject.activeInHierarchy);
 }
 [Test] public void ZeroTimeFreezesTravelAndNpcCartsMoveIndependently(){
  var view=new StoreInteriorView(geometry,root.transform);view.Enter("paw_mart");
  var first=view.ShoppingCarts[1];var second=view.ShoppingCarts[2];var at=first.Root.localPosition;
  Assert.That(Vector3.Distance(at,second.Root.localPosition),Is.GreaterThan(1));
  view.Advance(1,true);Assert.That(Vector3.Distance(at,first.Root.localPosition),Is.GreaterThan(.1f));
  at=first.Root.localPosition;float angle=first.WheelAngle;view.Advance(0,true);
  Assert.AreEqual(at,first.Root.localPosition);Assert.AreEqual(angle,first.WheelAngle);
  view.Advance(0,false);Assert.AreEqual(at,first.Root.localPosition);Assert.AreEqual(0,first.WheelAngle);
  Assert.IsFalse(view.StartPurchaseRoutine("welcome_basket"));
  typeof(StoreInteriorPause).GetMethod("OnApplicationPause",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(root.GetComponent<StoreInteriorPause>(),new object[]{true});view.Advance(5,true);
  Assert.AreEqual(at,first.Root.localPosition);Assert.AreEqual(0,first.WheelAngle);
  typeof(StoreInteriorPause).GetMethod("OnApplicationPause",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(root.GetComponent<StoreInteriorPause>(),new object[]{false});view.Advance(1,true);
  Assert.That(Vector3.Distance(at,first.Root.localPosition),Is.GreaterThan(.1f));
 }
 [Test] public void ReducedMotionKeepsStaticPawPoseAndPurchaseDestination(){
  var rig=new GodotCatRig(geometry,root.transform,ManagerCatArt.Recipe("honey","solid"),0);
  rig.Advance(1,false,"push_cart",true);
  Assert.That(Quaternion.Angle(rig.Bindings["legs.1"].localRotation,Quaternion.identity),Is.GreaterThan(1));
  var view=new StoreInteriorView(geometry,root.transform);view.Enter("paw_mart");view.SelectCashier();view.Advance(30,false);
  Assert.IsTrue(view.StartPurchaseRoutine("market_bundle"));view.Advance(30,false);
  Assert.IsFalse(view.IsShopping);Assert.IsTrue(view.IsConversationOpen);Assert.AreEqual(0,view.ShoppingCarts[0].WheelAngle);
 }
}
