using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Meadow Life phase 1: the Life play view directs the manager (docs/superpowers/plans/2026-09-23-meadow-life-01-manager.md).
 public sealed class ManagerLifeTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  HotelModel model;
  [SetUp] public void Setup(){
   TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
   ChatterContent.LoadJson(Resources.Load<TextAsset>("Content/Chatter").text);
   model=new HotelModel(new MemoryStore(),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
   Assert.IsTrue(model.LoadOrCreate().success);
  }

  [Test] public void ChatterShipsWithTheGameAndEveryTopicHasAnIcon(){
   var chatter=ChatterContent.Current;
   Assert.AreEqual(6,chatter.Topics.Length);
   foreach(var topic in chatter.Topics)CollectionAssert.Contains(HotelUI.PixelIconIds,topic.icon,topic.id+" has a pixel icon");
   foreach(var pref in ParityContent.Current.Cats.Select(c=>(string)c["preference"]).Distinct())CollectionAssert.Contains(chatter.Preferences.ToArray(),pref);
  }

  [Test] public void StatusLineFollowsTheManager(){
   StringAssert.StartsWith("Tap the ground",HotelUI.ManagerStatusFor(model));
   Assert.IsTrue(model.OrderManagerWalk(new LotPoint(-1.25f,-1.25f)).success);model.Tick(.2f);
   Assert.AreEqual("On the way",HotelUI.ManagerStatusFor(model));
   for(int i=0;i<300&&model.Actors.Count(a=>a.kind==ActorKind.Guest)==0;i++)model.Tick(.2f);
   var guest=model.Actors.First(a=>a.kind==ActorKind.Guest);
   Assert.IsTrue(model.OrderManagerChat(guest.catId).success);
   Assert.AreEqual("Off to chat with "+guest.name,HotelUI.ManagerStatusFor(model));
   model.ClearManagerOrders();Assert.IsTrue(model.OrderManagerStreet("square").success);for(int i=0;i<200&&model.ManagerInHotel;i++)model.Tick(.2f);
   StringAssert.Contains("Main Street",HotelUI.ManagerStatusFor(model));
  }

  [Test] public void BuildPausesTheQueueAndLifeResumesIt(){
   Assert.IsTrue(model.OrderManagerWalk(new LotPoint(-1.25f,-1.25f)).success);
   model.PauseManagerOrders(true);var before=model.ManagerPosition;
   for(int i=0;i<10;i++)model.Tick(.2f);
   Assert.AreEqual(1,model.ManagerOrders.Count);Assert.Less(model.ManagerPosition.Distance(before),.001f);
   model.PauseManagerOrders(false);for(int i=0;i<150&&model.ManagerOrders.Count>0;i++)model.Tick(.2f);
   Assert.AreEqual(0,model.ManagerOrders.Count);
  }
 }
}
