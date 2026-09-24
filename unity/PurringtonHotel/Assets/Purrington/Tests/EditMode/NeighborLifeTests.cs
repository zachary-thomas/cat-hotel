using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Meadow Life phase 2: neighbors ship with the game and the Neighbors page describes them (docs/superpowers/plans/2026-09-24-meadow-life-02-neighbors.md).
 public sealed class NeighborLifeTests {
  [SetUp] public void Setup(){
   ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
   Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
   TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
   ChatterContent.LoadJson(Resources.Load<TextAsset>("Content/Chatter").text);
   NeighborContent.LoadJson(Resources.Load<TextAsset>("Content/Neighbors").text);
   QuestContent.LoadJson(Resources.Load<TextAsset>("Content/Quests").text);
   PlazaContent.LoadJson(Resources.Load<TextAsset>("Content/Events").text);
  }
  [Test] public void PlazaEventsShipWithTheGame(){
   Assert.AreEqual(3,PlazaContent.Current.Events.Length);
   foreach(var e in PlazaContent.Current.Events){Assert.IsNotNull(Catalog.Find(e.goldItem),e.id);Assert.IsTrue(ChatterContent.Current.HasTopic(e.topic),e.id);}
   Assert.AreEqual("gold",HotelModel.BuzzTier(HotelModel.GoldBuzz));
  }
  [Test] public void OutskirtsSpotsSitInClearedLawn(){
   foreach(var spot in QuestContent.Current.Spots){
    var p=TownContent.Current.Point(spot.id);
    Assert.IsTrue(OutskirtsArt.Cleared.Any(r=>r.Contains(new Vector2(p.x,p.z))),spot.id+" has room around it");
   }
   CollectionAssert.Contains(HotelUI.PixelIconIds,"note");
  }
  [Test] public void SixNeighborsWithGiftsAndSignatureWear(){
   var content=NeighborContent.Current;
   Assert.AreEqual(6,content.Neighbors.Length);
   foreach(var n in content.Neighbors){Assert.IsNotNull(Wardrobe.Find(n.bestGift),n.id);Assert.IsNotNull(content.FindGift(n.favoriteGift),n.id);}
   CollectionAssert.Contains(HotelUI.PixelIconIds,"gift");
  }
  [Test] public void LikesStayHiddenUntilLearned(){
   var n=NeighborContent.Current.Find("tom");var state=new NeighborState{id="tom"};
   Assert.AreEqual("Loves ? · Likes ?, ? · Dislikes ?",HotelUI.LikesLine(n,state));
   state.learned.Add(n.love);state.learned.Add(n.dislike);
   StringAssert.StartsWith("Loves Weather",HotelUI.LikesLine(n,state));StringAssert.EndsWith("Dislikes Gossip",HotelUI.LikesLine(n,state));
  }
  [Test] public void WhereLineNamesThePlace(){
   Assert.AreEqual("At home",HotelUI.WhereLine(null,TownContent.Current));
   Assert.AreEqual("At the square",HotelUI.WhereLine(new NeighborView{present=true,place="square"},TownContent.Current));
   Assert.AreEqual("Heading to Paw Mart",HotelUI.WhereLine(new NeighborView{present=true,walking=true,place="paw_mart_door"},TownContent.Current));
  }
 }
}
