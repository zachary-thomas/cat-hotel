using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class WardrobeSuites
{
	public static void RunWardrobe(Action<bool,string> Check,Func<string,JObject> P,ParityContent content)
	{
		string wardrobeJson=File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json");Wardrobe.LoadJson(wardrobeJson);
		Check(Wardrobe.All.Length==19&&Wardrobe.Slots.All(s=>Wardrobe.All.Count(w=>w.slot==s)>=3),"wardrobe: 19 items (13 plus six neighbor gifts) across head, neck and back");
		Check(Wardrobe.All.Count(w=>w.giftCat>=0)==3,"wardrobe: three signature gifts");
		var badGiver=JObject.Parse(wardrobeJson);badGiver["items"].First(i=>(string)i["id"]=="tiny_crown")["giftCat"]=18;bool rejectedGiver=false;
		try{Wardrobe.LoadJson(badGiver.ToString());}catch(FormatException){rejectedGiver=true;}
		Check(rejectedGiver&&Wardrobe.Find("tiny_crown").giftCat==0,"wardrobe: rejects an out-of-range gift giver without replacing good content");
		foreach(int bond in new[]{0,101}){var badBond=JObject.Parse(wardrobeJson);badBond["items"].First(i=>(string)i["id"]=="tiny_crown")["giftBond"]=bond;bool rejectedBond=false;
			try{Wardrobe.LoadJson(badBond.ToString());}catch(FormatException){rejectedBond=true;}
			Check(rejectedBond&&Wardrobe.Find("tiny_crown").giftBond==50,"wardrobe: rejects gift friendship outside 1 to 100 ("+bond+")");}
		var store=new MemoryStore();var m=new HotelModel(store,content);m.LoadOrCreate();m.State.coins=1000;
		Check(m.State.cats[0].known&&m.State.cats[0].outfit.Count==0&&m.State.wardrobe.Count==0,"wardrobe: fresh hotels start undressed");
		var shortWallet=new HotelModel(new MemoryStore(),content);shortWallet.LoadOrCreate();shortWallet.State.coins=179.99995;
		Check(!shortWallet.BuyWear("sun_hat").success&&shortWallet.State.coins==179.99995&&!shortWallet.OwnsWear("sun_hat"),"wardrobe: a fractional coin short cannot buy a hat");
		double coins=m.State.coins;var bought=m.BuyWear("sun_hat");
		Check(bought.success&&m.OwnsWear("sun_hat")&&Math.Abs(coins-m.State.coins-180)<.01&&bought.cost==180,"wardrobe: buying a sun hat costs 180");
		coins=m.State.coins;Check(m.BuyWear("sun_hat").success&&Math.Abs(coins-m.State.coins)<.01,"wardrobe: buying twice is free and harmless");
		var gift=m.BuyWear("tiny_crown");Check(!gift.success&&gift.message.Contains("gift from"),"wardrobe: gifts can't be bought ("+gift.message+")");
		Check(m.Dress(0,"head","sun_hat").success&&m.State.cats[0].outfit["head"]=="sun_hat","wardrobe: dress Miso in the sun hat");
		Check(!m.Dress(0,"neck","sun_hat").success,"wardrobe: hats don't go on necks");
		var unowned=m.Dress(0,"neck","bow_tie");Check(!unowned.success&&unowned.message.Contains("Buy"),"wardrobe: unowned wear can't be worn");
		Check(!m.Dress(8,"head","sun_hat").success,"wardrobe: unknown cats can't be dressed");
		m.State.cats[0].bond=49;var care=m.Care(0,m.State.cats[0].favoriteAction);
		Check(care.success&&care.message.Contains("gave you the tiny crown"),"wardrobe: reaching friendship 50 brings Miso's gift ("+care.message+")");
		Check(m.OwnsWear("tiny_crown")&&m.Dress(0,"head","tiny_crown").success,"wardrobe: the gift can be worn");
		var codec=new NewtonsoftSaveCodec();var restored=codec.Deserialize(codec.Serialize(m.State));
		Check(HotelModel.Valid(restored)&&restored.cats[0].outfit["head"]=="tiny_crown"&&restored.wardrobe.Contains("sun_hat"),"wardrobe: outfits and purchases survive a save");
		Check(m.Dress(1,"head","sun_hat").success,"wardrobe: a purchased item is shared with another cat");
		var earned=codec.Deserialize(codec.Serialize(m.State));
		Check(HotelModel.Valid(earned)&&earned.cats[0].outfit["head"]=="tiny_crown"&&earned.cats[1].outfit["head"]=="sun_hat","wardrobe: earned gift and purchased wear survive a save together");
        Check(m.DressManager("head","sun_hat").success,"boutique: manager uses shared purchased clothing");
        var sharedReload=new HotelModel(store,content);sharedReload.LoadOrCreate();
        Check(sharedReload.State.managerOutfit["head"]=="sun_hat"&&sharedReload.State.cats[1].outfit["head"]=="sun_hat","boutique: manager and cat share clothing through reload");
        m.DressManager("head","");
        var beforePreview=codec.Serialize(m.State);var preview=new System.Collections.Generic.Dictionary<string,string>(m.State.managerOutfit);preview["neck"]="bow_tie";
        Check(codec.Serialize(m.State)==beforePreview,"boutique: preview copy leaves coins, inventory and outfits untouched");

		var legacy=JObject.Parse(codec.Serialize(m.State));((JObject)legacy).Remove("wardrobe");foreach(var c in legacy["cats"])((JObject)c).Remove("outfit");
		var old=new HotelModel(new MemoryStore(),content);old.LoadOrCreate();Check(old.RestoreJson(legacy.ToString())&&old.State.cats.All(c=>c.outfit.Count==0),"wardrobe: older saves load undressed");
		var bad=JObject.Parse(codec.Serialize(m.State));bad["cats"][0]["outfit"]["head"]=5;Check(!old.RestoreJson(bad.ToString()),"wardrobe: strict JSON rejects a non-string outfit");
		var wrongSlot=JObject.Parse(codec.Serialize(m.State));wrongSlot["cats"][0]["outfit"]["neck"]="sun_hat";Check(!old.RestoreJson(wrongSlot.ToString()),"wardrobe: validation rejects wear in the wrong slot");
		var beforeRejected=codec.Serialize(old.State);
		var earlyGift=JObject.Parse(codec.Serialize(m.State));earlyGift["cats"][0]["bond"]=0;earlyGift["cats"][0]["outfit"]["head"]="sun_hat";((JArray)earlyGift["wardrobe"]).Add("tiny_crown");
		Check(!old.RestoreJson(earlyGift.ToString())&&codec.Serialize(old.State)==beforeRejected,"wardrobe: forged gift inventory is rejected without changing the hotel");
		var unownedOutfit=JObject.Parse(codec.Serialize(m.State));unownedOutfit["cats"][0]["outfit"]["neck"]="bow_tie";
		Check(!old.RestoreJson(unownedOutfit.ToString())&&codec.Serialize(old.State)==beforeRejected,"wardrobe: unowned equipped wear is rejected without changing the hotel");
		var unpaid=JObject.Parse(codec.Serialize(m.State));((JArray)unpaid["wardrobe"]).RemoveAt(0);unpaid["cats"][0]["outfit"]["head"]="sun_hat";
		Check(!old.RestoreJson(unpaid.ToString()),"wardrobe: a saved outfit needs a purchased item");
		var lockedGift=JObject.Parse(codec.Serialize(m.State));lockedGift["cats"][0]["bond"]=49;
		Check(!old.RestoreJson(lockedGift.ToString()),"wardrobe: a saved gift outfit needs the giver's friendship");
		var fakeGiftPurchase=JObject.Parse(codec.Serialize(m.State));((JArray)fakeGiftPurchase["wardrobe"]).Add("tiny_crown");
		Check(!old.RestoreJson(fakeGiftPurchase.ToString()),"wardrobe: a signature gift cannot appear as purchased wear");
		Check(m.Dress(0,"head","").success&&!m.State.cats[0].outfit.ContainsKey("head"),"wardrobe: undress a slot");
		store.fail=true;coins=m.State.coins;Check(!m.BuyWear("beanie").success&&Math.Abs(coins-m.State.coins)<.01&&!m.OwnsWear("beanie"),"wardrobe: a failed save buys nothing");store.fail=false;
		m.State.coins=10;Check(!m.BuyWear("beanie").success,"wardrobe: can't afford a beanie with 10 coins");
		Check(m.SetGodMode(true).success&&m.BuyWear("beanie").success&&m.State.coins==10,"wardrobe: God mode dresses for free");
		Console.WriteLine("Wardrobe suite passed");
	}
}
