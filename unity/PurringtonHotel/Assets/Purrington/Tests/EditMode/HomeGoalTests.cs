using Newtonsoft.Json.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // The Hotel tab's "Next:" card: what it asks for and how far along the next hotel level is.
 public sealed class HomeGoalTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  HotelModel model;
  [SetUp] public void Setup(){model=new HotelModel(new MemoryStore(),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));Assert.IsTrue(model.LoadOrCreate().success);model.State.pendingCoins=0;}

  [Test] public void StarterHotelAsksForAnUpgradeAndCountsTowardTheNextLevel(){
   var goal=HotelUI.NextGoal(model);
   Assert.That(goal.Headline,Does.StartWith("Next: "));
   Assert.IsTrue(goal.ShowProgress);Assert.AreEqual(0,goal.Progress);
   Assert.AreEqual("0 / 2 upgrades to level "+(model.Hotel().level+1),goal.Caption);
   if(goal.Target=="upgrade"){
    model.State.coins=1e6;
    Assert.IsTrue(model.Execute("upgrade",new JObject{{"service",0}}).success);
    goal=HotelUI.NextGoal(model);Assert.AreEqual(.5f,goal.Progress);StringAssert.StartsWith("1 / 2",goal.Caption);
   }
  }

  [Test] public void OfflineCoinsComeFirst(){
   model.State.pendingCoins=250;
   var goal=HotelUI.NextGoal(model);
   Assert.AreEqual("collect",goal.Target);Assert.AreEqual("Collect 250 coins",goal.Headline);
  }
 }
}
