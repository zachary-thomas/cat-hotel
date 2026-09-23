using System;
using System.Collections.Generic;
using System.Linq;
namespace Purrington.Domain {
 public sealed partial class HotelModel {
  public IReadOnlyList<string> TownInventory=>Hotel(0).town.specialFlags.AsReadOnly();
  public bool TownQuestAccepted(string id)=>Hotel(0).town.questFlags.Contains(id+":accepted");
  public bool TownQuestCompleted(string id)=>Hotel(0).town.questFlags.Contains(id+":completed");
  public CommandResult BuyTownItem(string id){
   var offer=TownContent.Current?.Offer(id);
   if(State.currentHotel!=0||offer==null)return CommandResult.Fail("That item is not sold here.");
   if(TownInventory.Contains(id))return CommandResult.Fail("That special is already ready.");
   double price=(double)offer["price"];
   if(State.coins<price)return CommandResult.Fail("Not enough Cat Coins.");
   var result=Transaction(()=>{State.coins-=price;Hotel(0).town.specialFlags.Add(id);},(string)offer["name"]+" is ready.");
   result.cost=result.success?price:0;return result;
  }
  public CommandResult AcceptTownQuest(string id){
   var quest=TownContent.Current?.Quest(id);
   if(State.currentHotel!=0||quest==null)return CommandResult.Fail("Choose a shop quest.");
   if(TownQuestAccepted(id))return CommandResult.Fail("This quest was already accepted.");
   string grant=(string)quest["grantWear"];
   if(grant!=null&&Wardrobe.Find(grant)==null)return CommandResult.Fail("The quest wardrobe is unavailable.");
   return Transaction(()=>{Hotel(0).town.questFlags.Add(id+":accepted");if(grant!=null&&!State.wardrobe.Contains(grant))State.wardrobe.Add(grant);},(string)quest["name"]+" accepted.");
  }
  public CommandResult CompleteTownQuest(string id){
   var quest=TownContent.Current?.Quest(id);
   if(State.currentHotel!=0||quest==null||!TownQuestAccepted(id)||TownQuestCompleted(id))return CommandResult.Fail("This quest is not ready to complete.");
   string required=(string)quest["requiresSpecial"],wear=(string)quest["requiresWear"];
   if(required!=null&&!TownInventory.Contains(required))return CommandResult.Fail("Pick up the Welcome Basket first.");
   if(wear!=null&&(!OwnsWear(wear)||!State.managerOutfit.TryGetValue(Wardrobe.Find(wear).slot,out var equipped)||equipped!=wear))return CommandResult.Fail("Equip the store ribbon on your manager first.");
   int cat=(int?)quest["cat"]??-1;bool known=cat>=0&&State.cats[cat].known;
   return Transaction(()=>{
    if(required!=null)Hotel(0).town.specialFlags.Remove(required);
    if(cat>=0){if(known)State.coins+=(double)quest["knownCoins"];else State.cats[cat].known=true;}
    Hotel(0).town.questFlags.Add(id+":completed");Hotel(0).town.questFlags.Add(id+":rewarded");
   },cat>=0?(known?"Biscuit is invited back! +40 Cat Coins.":"Biscuit is invited to the hotel!"):"First Look complete!");
  }
  public CommandResult DressManager(string slot,string id){
   if(!Wardrobe.Slots.Contains(slot))return CommandResult.Fail("Choose head, neck or back.");
   if(string.IsNullOrEmpty(id))return Transaction(()=>State.managerOutfit.Remove(slot),"Manager outfit updated.");
   var wear=Wardrobe.Find(id);
   if(wear==null||wear.slot!=slot)return CommandResult.Fail("That doesn't go there.");
   if(!OwnsWear(id))return CommandResult.Fail("Add this to the wardrobe first.");
   return Transaction(()=>State.managerOutfit[slot]=id,"Manager wears "+wear.name+".");
  }
 }
}
