using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 public sealed class MarketDayViewTests {
  GameObject root;GodotGeometry geometry;HotelModel model;
  [SetUp] public void Setup(){
   ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
   TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
   root=new GameObject("Market Day test");geometry=new GodotGeometry();
   model=new HotelModel(new ViewMemoryStore(),ParityContent.Current);Assert.That(model.LoadOrCreate().success,Is.True);
  }
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);geometry.Dispose();}
  [Test] public void SheetStatusAndActionsTrackRealTicks(){
   var host=new GameObject("inactive UI fixture");host.SetActive(false);
   try{
    var app=host.AddComponent<HotelApp>();typeof(HotelApp).GetProperty("Model").SetValue(app,model);
    var ui=host.AddComponent<HotelUI>();var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
    typeof(HotelUI).GetField("app",flags).SetValue(ui,app);
    var label=new GameObject("market status",typeof(RectTransform)).AddComponent<TMPro.TextMeshProUGUI>();label.transform.SetParent(host.transform);
    var action=new GameObject("market start",typeof(RectTransform)).GetComponent<RectTransform>();action.SetParent(host.transform);
    typeof(HotelUI).GetField("marketStatus",flags).SetValue(ui,label);typeof(HotelUI).GetField("marketStart",flags).SetValue(ui,action);
    var refresh=(System.Action)System.Delegate.CreateDelegate(typeof(System.Action),ui,typeof(HotelUI).GetMethod("RefreshValues",flags));model.Changed+=refresh;
    model.BuyTownItem("market_bundle");model.StartMarketDay();Assert.That(label.text,Does.Contain("90s"));Assert.IsFalse(action.gameObject.activeSelf);
    model.Tick(2);Assert.That(label.text,Does.Contain("88s"));model.Tick(88);Assert.That(label.text,Does.Contain("Completed"));
    model.BuyTownItem("market_bundle");Assert.IsTrue(action.gameObject.activeSelf);Assert.That(label.text,Does.Contain("Bundle ready"));model.Changed-=refresh;
   }finally{Object.DestroyImmediate(host);}
  }
  [Test] public void HotelWelcomeRendersActualCatAndWaitsDuringTown(){
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);model.BuyTownItem("market_bundle");model.StartMarketDay();model.Tick(90);
   world.EnterTownMode();var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
   typeof(VoxelWorld).GetMethod("SyncManager",flags).Invoke(world,new object[]{2f});Assert.AreEqual(6,model.Hotel().town.welcomeRemaining);
   world.ExitTownMode();typeof(VoxelWorld).GetMethod("SyncManager",flags).Invoke(world,new object[]{.1f});
   typeof(VoxelWorld).GetMethod("SyncActors",flags).Invoke(world,null);
   var actors=(System.Collections.IDictionary)typeof(VoxelWorld).GetField("actors",flags).GetValue(world);
   Assert.IsTrue(actors.Contains("town:welcome"));var rig=(GodotCatRig)actors["town:welcome"];Assert.IsTrue(rig.Root.gameObject.activeInHierarchy);
   Assert.That(model.Actors[model.Actors.Count-1].speech,Does.Contain("Market Day"));
  }
  [Test] public void QuietRunningAndCompletedSquare(){
   var art=new TownSquareArt(geometry,root.transform,TownContent.Current,model);
   Assert.That(art.KioskCount,Is.EqualTo(2));Assert.That(art.IsMarketVisible,Is.False);
   Assert.That(art.BoardText.text,Does.Contain("Paw Mart"));
   Assert.That(model.BuyTownItem("market_bundle").success,Is.True);art.Update(model,0,false);
   Assert.That(art.BoardText.text,Does.Contain("Ready"));
   Assert.That(model.StartMarketDay().success,Is.True);art.Update(model,0,false);
   Assert.That(art.IsMarketVisible,Is.True);Assert.That(art.BoardText.text,Does.Contain("90s"));
   Assert.That(art.Market.Find("Market kiosk 1"),Is.Not.Null);Assert.That(art.Market.Find("Market kiosk 2"),Is.Not.Null);
   model.Tick(90);art.Update(model,0,false);
   Assert.That(art.IsMarketVisible,Is.False);Assert.That(art.BoardText.text,Does.Contain("guests"));
   art.Update(model,5,false);Assert.That(art.BoardText.text,Does.Contain("Completed"));
  }
  sealed class ViewMemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
 }
}
