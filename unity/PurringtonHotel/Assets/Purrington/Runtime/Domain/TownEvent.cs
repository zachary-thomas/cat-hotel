using System;

namespace Purrington.Domain {
 public sealed partial class HotelModel {
  float marketCheckpointElapsed;
  public float MarketDayRemaining=>Hotel(0).town.eventRemaining;
  // A durable serial lets views play each completion reaction at most once.
  public int MarketDayReactionToken=>Hotel(0).town.marketCompletionSerial;
  public bool MarketDayCompleted=>Hotel(0).town.marketCompletionSerial>0&&MarketDayRemaining<=0;
  public CommandResult StartMarketDay(){
   if(State.currentHotel!=0||TownContent.Current==null)return CommandResult.Fail("Market Day is only at Meadow House.");
   var town=Hotel(0).town;
   if(town.eventRemaining>0)return CommandResult.Fail("Market Day is already happening.");
   if(!town.specialFlags.Contains("market_bundle"))return CommandResult.Fail("Get a Market Day bundle at Paw Mart.");
   return Transaction(()=>{town.specialFlags.Remove("market_bundle");town.eventRemaining=90;},"Market Day has begun!");
  }
  // Called only while the hotel scene is visible. Pending scenes survive reload;
  // they never reserve a room or evict a guest, and wait for safe arrival space.
  public void AdvanceTownWelcome(float seconds){
   if(State.currentHotel!=0||RequiresSaveRecovery||!Finite(seconds)||seconds<=0)return;
   var town=Hotel(0).town;
   bool basket=TownQuestCompleted("welcome_picnic")&&!town.basketWelcomeDelivered;
   if(!basket&&town.marketWelcomeDelivered>=town.marketCompletionSerial)return;
   if(town.welcomeKind=="")town.welcomeKind=basket?"basket":"market";
   basket=town.welcomeKind=="basket";
   const string id="town:welcome";
   var actor=actors.Find(a=>a.view.id==id);
   var existing=actors.Find(a=>a.view.catId==(basket?5:8)&&a.view.kind==ActorKind.Guest);
   if(actor==null&&existing==null){
    var position=FreeArrival();if(!position.HasValue)return;
    actor=new Actor{view=new ActorSnapshot{id=id,catId=basket?5:8,name=State.cats[basket?5:8].name,kind=ActorKind.TownWelcome,role="town welcome",x=position.Value.x,z=position.Value.z}};
    actors.Add(actor);Activity(actor,"welcome","greet",6);
   }
   var visible=actor??existing;
   visible.view.speech=basket?"Thank you for the Welcome Basket!":"Market Day was lovely!";
   visible.view.gesture="happy";visible.view.speechElapsed=6-town.welcomeRemaining;visible.view.speechDuration=6;
   float before=town.welcomeRemaining;town.welcomeRemaining=Math.Max(0,before-seconds);
   if(town.welcomeRemaining>0)return;
   // A failed acknowledgement keeps the scene pending and retries on next frame.
   var result=Transaction(()=>{if(basket)town.basketWelcomeDelivered=true;else town.marketWelcomeDelivered++;town.welcomeRemaining=6;town.welcomeKind="";},"Hotel welcome delivered.");
   if(!result.success){Hotel(0).town.welcomeRemaining=before;return;}
   visible.view.speech="";visible.view.gesture="";
   if(actor!=null)actors.Remove(actor);
  }
  void AdvanceMarketDay(float seconds){
   var town=Hotel(0).town;
   if(town.eventRemaining<=0)return;
   float before=town.eventRemaining;int token=town.marketCompletionSerial;
   town.eventRemaining=Math.Max(0,before-seconds);
   if(town.eventRemaining==0)town.marketCompletionSerial++;
   // Keep the visible timer smooth without forcing a journal fsync every frame.
   // Explicit Save and application pause save current state; a crash can replay <1s.
   marketCheckpointElapsed+=seconds;
   if(town.eventRemaining>0&&marketCheckpointElapsed<1f)return;
   // Completion and its token are always one immediate saved transition.
   if(!TrySave()){town.eventRemaining=before;town.marketCompletionSerial=token;}
   else marketCheckpointElapsed=0;
  }
 }
}
