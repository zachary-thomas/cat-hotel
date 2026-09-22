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
