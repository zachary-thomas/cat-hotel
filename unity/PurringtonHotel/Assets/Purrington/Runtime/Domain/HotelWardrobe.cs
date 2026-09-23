using System;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
public sealed class WearDefinition {public string id,name,slot;public double price;public int giftCat=-1,giftBond=50;public JArray parts=new JArray();}
// Wear items come from Resources/Content/Wardrobe.json; Presentation loads the text and calls LoadJson, tests read the file directly.
public static class Wardrobe {
 public static readonly string[] Slots={"head","neck","back"};
 public static WearDefinition[] All=Array.Empty<WearDefinition>();
 public static WearDefinition Find(string id){return Array.Find(All,w=>w.id==id);}
 public static void LoadJson(string json){var items=JObject.Parse(json)["items"] as JArray??throw new FormatException("Wardrobe needs items");var all=items.Select(i=>new WearDefinition{id=(string)i["id"],name=(string)i["name"],slot=(string)i["slot"],price=(double?)i["price"]??0,giftCat=(int?)i["giftCat"]??-1,giftBond=(int?)i["giftBond"]??50,parts=i["parts"] as JArray??new JArray()}).ToArray();if(all.Any(w=>string.IsNullOrEmpty(w.id)||string.IsNullOrEmpty(w.name)||!Slots.Contains(w.slot)||w.price<0||w.giftCat<-1||w.giftCat>=18||w.giftCat>=0&&(w.giftBond<1||w.giftBond>100))||all.Select(w=>w.id).Distinct().Count()!=all.Length)throw new FormatException("Invalid wardrobe item");All=all;}
}
public sealed partial class HotelModel {
 // Bought items live in State.wardrobe; signature gifts are owned while their cat's friendship stays at the gift level, so nothing needs migrating.
 public bool OwnsWear(string id){var w=Wardrobe.Find(id);if(w==null)return false;return w.giftCat>=0?w.giftCat<State.cats.Count&&State.cats[w.giftCat].known&&State.cats[w.giftCat].bond>=w.giftBond:State.wardrobe.Contains(id);}
 public CommandResult BuyWear(string id){var w=Wardrobe.Find(id);if(w==null)return CommandResult.Fail("Choose something from the wardrobe.");if(OwnsWear(id))return CommandResult.Ok(w.name+" is already in the wardrobe.");if(w.giftCat>=0)return CommandResult.Fail(w.name+" is a gift from "+State.cats[w.giftCat].name+" at friendship "+w.giftBond+".");double price=State.settings.godMode?0:w.price;if(State.coins<price)return CommandResult.Fail("Need "+Math.Ceiling(price-State.coins)+" more Cat Coins.");var r=Transaction(()=>{State.coins-=price;State.wardrobe.Add(id);},w.name+" added to the wardrobe");r.cost=r.success?price:0;return r;}
 public CommandResult Dress(int catId,string slot,string id){var c=State.cats.Find(v=>v.id==catId&&v.known);if(c==null)return CommandResult.Fail("Meet this cat first.");if(!Wardrobe.Slots.Contains(slot))return CommandResult.Fail("Choose head, neck or back.");if(string.IsNullOrEmpty(id))return Transaction(()=>c.outfit.Remove(slot),c.name+" changed back");var w=Wardrobe.Find(id);if(w==null||w.slot!=slot)return CommandResult.Fail("That doesn't go there.");if(!OwnsWear(id))return CommandResult.Fail("Buy this in the wardrobe first.");return Transaction(()=>c.outfit[slot]=id,c.name+" looks wonderful in the "+w.name.ToLowerInvariant());}
}
}
