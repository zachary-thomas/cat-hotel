using System;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class TownCashierRefreshTests {
 sealed class MemoryStore:ISaveStore {

  public HotelState Load()=>null;
  public bool Save(HotelState state)=>true;
 }
 [TestCase("quest")]
 [TestCase("grocery")]
 [TestCase("clothing")]
 public void SuccessfulCashierCommandRefreshesFromSavedStateBeforeShowingNotice(string action){
  TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);
  Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
  var model=new HotelModel(new MemoryStore(),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
  Assert.IsTrue(model.LoadOrCreate().success);model.State.coins=1000;
  int refreshes=0,reports=0;string displayed="Available";
  var result=action=="quest"?model.AcceptTownQuest("first_look"):action=="grocery"?model.BuyTownItem("welcome_basket"):model.BuyWear("sun_hat");
  HotelTownUI.RefreshCashier(result,()=>{
   refreshes++;
   displayed=action=="quest"?model.TownQuestAccepted("first_look")&&model.OwnsWear("store_ribbon")?"Equip ribbon / Complete":"Accept":action=="grocery"?model.TownInventory.Count==1?"Owned":"Buy":model.OwnsWear("sun_hat")?"Equip":"Buy";
  },reported=>{reports++;Assert.AreSame(result,reported);Assert.AreEqual(1,refreshes,"refresh happens before notice so rebuild cannot erase it");});
  Assert.AreEqual(1,refreshes);Assert.AreEqual(1,reports);
  Assert.AreEqual(action=="quest"?"Equip ribbon / Complete":action=="grocery"?"Owned":"Equip",displayed);
 }
 [Test] public void FailedCommandKeepsCurrentSheetAndReportsFailure(){
  int refreshes=0,reports=0;var failure=CommandResult.Fail("Couldn't save");
  HotelTownUI.RefreshCashier(failure,()=>refreshes++,result=>{reports++;Assert.AreSame(failure,result);});
  Assert.AreEqual(0,refreshes);Assert.AreEqual(1,reports);
 }
}
