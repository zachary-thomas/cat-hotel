using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;
public sealed class ClothingStoreTests {
 [SetUp] public void Load(){TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);}
 [Test] public void BoutiqueHasDistinctFixturesAndNoCarts(){
  using(var geometry=new GodotGeometry()){
   var root=new GameObject("boutique test");try{
    var view=new StoreInteriorView(geometry,root.transform);view.Enter("clothing");
    Assert.AreEqual("Clover",view.OwnerName);
    var names=root.GetComponentsInChildren<Transform>().Select(t=>t.name).ToArray();
    foreach(var name in new[]{"Head display mannequin","Neck display mannequin","Back display mannequin","Mirror","Try on platform","Checkout counter"})Assert.Contains(name,names);
    Assert.IsTrue(view.ShoppingCarts.All(c=>!c.Root.gameObject.activeInHierarchy));
   }finally{Object.DestroyImmediate(root);}
  }
 }
 [Test] public void TryOnCopiesOutfitAndCancelOrLeaveRestoresCommittedManager(){
  using(var geometry=new GodotGeometry()){
   var root=new GameObject("preview test");try{
    var view=new StoreInteriorView(geometry,root.transform);view.Enter("clothing");
    var outfit=new Dictionary<string,string>{{"head","sun_hat"}};view.SetManagerOutfit(outfit);
    view.PreviewClothing(-1,"cream","tabby",outfit,"bow_tie");
    Assert.IsTrue(view.IsTryingOn);Assert.AreEqual(1,outfit.Count);
    Assert.IsNotNull(view.PreviewRig.Bindings["body"].Find("Wear_neck"));
    Assert.IsNotNull(view.ManagerRig.Bindings["head"].Find("Wear_head"));
    Assert.IsNull(view.ManagerRig.Bindings["body"].Find("Wear_neck"));
    view.ClearClothingPreview();Assert.IsFalse(view.IsTryingOn);
    view.PreviewClothing(0,"cream","solid",outfit,"bow_tie");view.Exit();Assert.IsFalse(view.IsTryingOn);
    view.SetManagerAppearance("cocoa","patchwork");view.Enter("clothing");
    Assert.IsNotNull(view.ManagerRig.Bindings["head"].Find("Wear_head"));
   }finally{Object.DestroyImmediate(root);}
  }
 }
 sealed class MemoryStore:ISaveStore {
  HotelState saved;
  public HotelState Load()=>saved==null?null:HotelModel.Copy(saved);
  public bool Save(HotelState state){saved=HotelModel.Copy(state);return true;}
 }
 [Test] public void ReloadedManagerOutfitUsesAllBindingsOutsideAndInside(){
  TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
  var content=ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
  var store=new MemoryStore();var model=new HotelModel(store,content);model.LoadOrCreate();model.State.coins=10000;
  var expected=new Dictionary<string,string>();
  foreach(var slot in Wardrobe.Slots){var item=Wardrobe.All.First(w=>w.slot==slot&&w.giftCat<0&&w.quest==null);Assert.IsTrue(model.BuyWear(item.id).success);Assert.IsTrue(model.DressManager(slot,item.id).success);expected[slot]=item.id;}
  Assert.IsTrue(model.SetManagerAppearance("cocoa","patchwork").success);
  model=new HotelModel(store,content);model.LoadOrCreate();
  var host=new GameObject("outfit reload test");try{
   var world=host.AddComponent<VoxelWorld>();world.Initialize(model);world.EnterTownMode();
   foreach(var slot in Wardrobe.Slots)Assert.IsNotNull(world.StreetManagerRig.Bindings[slot=="head"?"head":"body"].Find("Wear_"+slot));
   var town=model.Hotel(0).town;town.shop="clothing";world.EnterStoreInterior("clothing");
   foreach(var slot in Wardrobe.Slots)Assert.IsNotNull(world.StoreInterior.ManagerRig.Bindings[slot=="head"?"head":"body"].Find("Wear_"+slot));
   Assert.AreEqual("cocoa",model.State.managerCoat);Assert.AreEqual("patchwork",model.State.managerMarkings);
   world.ExitStoreInterior();Assert.IsTrue(world.StreetManagerRig.Root.gameObject.activeSelf);
  }finally{Object.DestroyImmediate(host);}
 }

}
