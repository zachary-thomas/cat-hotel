using System;

namespace Purrington.Domain {
 public sealed partial class HotelModel {
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
  void AdvanceMarketDay(float seconds){
   var town=Hotel(0).town;
   if(town.eventRemaining<=0)return;
   float before=town.eventRemaining;int token=town.marketCompletionSerial;
   town.eventRemaining=Math.Max(0,before-seconds);
   if(town.eventRemaining==0)town.marketCompletionSerial++;
   // The timer and completion token are one saved transition.
   if(!TrySave()){town.eventRemaining=before;town.marketCompletionSerial=token;}
  }
 }
}
