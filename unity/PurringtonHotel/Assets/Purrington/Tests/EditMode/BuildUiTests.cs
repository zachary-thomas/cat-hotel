using System.Linq;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // The Build tab's floor rail and tool guidance (docs/superpowers/plans/2026-09-23-build-ui-refactor.md).
 public sealed class BuildUiTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  HotelModel model;
  [SetUp] public void Setup(){model=new HotelModel(new MemoryStore(),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));Assert.IsTrue(model.LoadOrCreate().success);}
  HotelUI.FloorEntry Entry(int level)=>HotelUI.FloorStates(model).First(e=>e.Level==level);

  [Test] public void StarterFloorsSayWhichHotelLevelOpensThem(){
   var states=HotelUI.FloorStates(model);
   CollectionAssert.AreEqual(new[]{2,1,0,-1},states.Select(e=>e.Level).ToArray(),"top floor first");
   Assert.AreEqual(HotelUI.FloorState.Built,Entry(0).State);Assert.AreEqual("Ground",Entry(0).Label);
   Assert.AreEqual(HotelUI.FloorState.Locked,Entry(1).State);Assert.AreEqual("Upstairs\nLv 3",Entry(1).Label);
   Assert.AreEqual("Rooftop\nLv 5",Entry(2).Label);Assert.AreEqual("Basement\nLv 7",Entry(-1).Label);
  }

  [Test] public void StairsTurnAnOpenableFloorIntoABuiltOne(){
   model.State.settings.godMode=true;
   Assert.AreEqual(HotelUI.FloorState.Openable,Entry(1).State);Assert.AreEqual("+ Upstairs",Entry(1).Label);
   JObject Stairs(int x,int z)=>new JObject{{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",0},{"x",x},{"y",z}};
   var spot=Enumerable.Range(-12,24).SelectMany(x=>Enumerable.Range(-12,24).Select(z=>(x,z))).FirstOrDefault(p=>model.Quote("draw_room",Stairs(p.x,p.z)).success);
   Assert.IsTrue(model.Execute("draw_room",Stairs(spot.x,spot.z)).success,"a stairwell fits somewhere in the starter hotel");
   Assert.AreEqual(HotelUI.FloorState.Built,Entry(1).State);Assert.AreEqual("Upstairs",Entry(1).Label);
  }

  [Test] public void ToolHintsExplainEachStep(){
   StringAssert.Contains("2 × 3",HotelUI.ToolHintFor("draw_room",new JObject{{"kind","stairs"},{"floor",0}},false));
   StringAssert.Contains("above",HotelUI.ToolHintFor("draw_room",new JObject{{"kind","stairs"},{"floor",0}},false));
   StringAssert.Contains("below",HotelUI.ToolHintFor("draw_room",new JObject{{"kind","stairs"},{"floor",-1}},false));
   StringAssert.Contains("Drag",HotelUI.ToolHintFor("draw_room",new JObject{{"kind","regular"}},false));
   StringAssert.Contains("wall",HotelUI.ToolHintFor("set_edge",new JObject(),false));
   StringAssert.StartsWith("Tap where the room",HotelUI.ToolHintFor("",null,true));
  }

  [Test] public void EachFloorOffersItsOwnRoomTypes(){
   CollectionAssert.AreEqual(new[]{"garden"},HotelUI.RoomKinds(2));
   CollectionAssert.Contains(HotelUI.RoomKinds(1),"sunroom");CollectionAssert.Contains(HotelUI.RoomKinds(-1),"spa");
   CollectionAssert.AreEqual(new[]{"regular","suite","shared"},HotelUI.RoomKinds(0));
  }
 }
}
