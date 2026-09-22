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
		Wardrobe.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json"));
		Check(Wardrobe.All.Length==12&&Wardrobe.Slots.All(s=>Wardrobe.All.Count(w=>w.slot==s)>=3),"wardrobe: 12 items across head, neck and back");
		Check(Wardrobe.All.Count(w=>w.giftCat>=0)==3,"wardrobe: three signature gifts");
		var store=new MemoryStore();var m=new HotelModel(store,content);m.LoadOrCreate();m.State.coins=1000;
		Check(m.State.cats[0].known&&m.State.cats[0].outfit.Count==0&&m.State.wardrobe.Count==0,"wardrobe: fresh hotels start undressed");
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
		var legacy=JObject.Parse(codec.Serialize(m.State));((JObject)legacy).Remove("wardrobe");foreach(var c in legacy["cats"])((JObject)c).Remove("outfit");
		var old=new HotelModel(new MemoryStore(),content);old.LoadOrCreate();Check(old.RestoreJson(legacy.ToString())&&old.State.cats.All(c=>c.outfit.Count==0),"wardrobe: older saves load undressed");
		var bad=JObject.Parse(codec.Serialize(m.State));bad["cats"][0]["outfit"]["head"]=5;Check(!old.RestoreJson(bad.ToString()),"wardrobe: strict JSON rejects a non-string outfit");
		var wrongSlot=JObject.Parse(codec.Serialize(m.State));wrongSlot["cats"][0]["outfit"]["neck"]="sun_hat";Check(!old.RestoreJson(wrongSlot.ToString()),"wardrobe: validation rejects wear in the wrong slot");
		Check(m.Dress(0,"head","").success&&!m.State.cats[0].outfit.ContainsKey("head"),"wardrobe: undress a slot");
		store.fail=true;coins=m.State.coins;Check(!m.BuyWear("beanie").success&&Math.Abs(coins-m.State.coins)<.01&&!m.OwnsWear("beanie"),"wardrobe: a failed save buys nothing");store.fail=false;
		m.State.coins=10;Check(!m.BuyWear("beanie").success,"wardrobe: can't afford a beanie with 10 coins");
		Check(m.SetGodMode(true).success&&m.BuyWear("beanie").success&&m.State.coins==10,"wardrobe: God mode dresses for free");
		Console.WriteLine("Wardrobe suite passed");
	}
}
