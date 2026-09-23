using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
static class TownCommerceSuites {
 public static void Run(Action<bool,string> check) {
  Wardrobe.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/Wardrobe.json"));
  var content=ParityContent.Current;
  HotelModel Fresh(MemoryStore s){var m=new HotelModel(s,content);check(m.LoadOrCreate().success,"commerce setup");m.State.coins=1000;return m;}
  var store=new MemoryStore();var m=Fresh(store);
  check(!m.BuyTownItem("unknown").success,"unknown offer");
  foreach(var pair in new[]{("welcome_basket",30),("market_bundle",80)}){double before=m.State.coins;check(m.BuyTownItem(pair.Item1).success&&m.State.coins==before-pair.Item2,"exact price "+pair.Item1);check(!m.BuyTownItem(pair.Item1).success&&m.State.coins==before-pair.Item2,"duplicate special "+pair.Item1);}
  check(m.TownInventory.Contains("market_bundle"),"inventory exposes held bundle");
  check(!m.CompleteTownQuest("welcome_picnic").success,"accept before completion");
  check(m.AcceptTownQuest("welcome_picnic").success&&m.CompleteTownQuest("welcome_picnic").success&&m.State.cats[5].known,"basket invites Biscuit");
  double coins=m.State.coins;check(!m.CompleteTownQuest("welcome_picnic").success&&m.State.coins==coins,"no repeated reward");
  check(m.AcceptTownQuest("first_look").success&&m.OwnsWear("store_ribbon"),"quest grants free ribbon");
  check(!m.CompleteTownQuest("first_look").success,"ribbon must be equipped");
  check(!m.DressManager("head","store_ribbon").success&&!m.DressManager("neck","bow_tie").success,"manager slot and ownership");
  check(m.DressManager("neck","store_ribbon").success&&m.CompleteTownQuest("first_look").success,"first look completion");
  check(m.Dress(0,"neck","store_ribbon").success,"ribbon is shared wardrobe");
  var reload=new HotelModel(store,content);check(reload.LoadOrCreate().success&&reload.State.managerOutfit["neck"]=="store_ribbon","equipped manager reload");
  check(!reload.CompleteTownQuest("welcome_picnic").success&&!reload.AcceptTownQuest("first_look").success&&!reload.CompleteTownQuest("first_look").success,"reload cannot repeat claims");
  var known=Fresh(new MemoryStore());known.State.cats[5].known=true;known.BuyTownItem("welcome_basket");known.AcceptTownQuest("welcome_picnic");coins=known.State.coins;check(known.CompleteTownQuest("welcome_picnic").success&&known.State.coins==coins+40,"known Biscuit grants 40");
  var poor=Fresh(new MemoryStore());poor.State.coins=29;check(!poor.BuyTownItem("welcome_basket").success&&poor.State.coins==29,"insufficient basket coins");poor.State.coins=79;check(!poor.BuyTownItem("market_bundle").success,"insufficient bundle coins");
  check(!poor.AcceptTownQuest("unknown").success&&!poor.CompleteTownQuest("unknown").success,"unknown quest");poor.AcceptTownQuest("welcome_picnic");check(!poor.CompleteTownQuest("welcome_picnic").success,"basket required");
  foreach(var flags in new[]{new[]{"unknown:accepted"},new[]{"first_look:completed"},new[]{"first_look:accepted","first_look:rewarded"},new[]{"first_look:accepted","first_look:accepted"}}){var bad=JObject.FromObject(m.State);bad["hotels"][0]["town"]["questFlags"]=new JArray(flags);check(!m.RestoreJson(bad.ToString()),"corrupt quest flags");}
  foreach(var outfit in new[]{new JObject{{"hat","store_ribbon"}},new JObject{{"head","store_ribbon"}},new JObject{{"head","sun_hat"}}}){var bad=JObject.FromObject(m.State);bad["managerOutfit"]=outfit;check(!m.RestoreJson(bad.ToString()),"corrupt manager outfit");}
  void Rollback(Action<HotelModel> prepare,Func<HotelModel,CommandResult> command,string label){var s=new MemoryStore();var model=Fresh(s);prepare(model);string before=JsonConvert.SerializeObject(model.State);s.fail=true;check(!command(model).success&&JsonConvert.SerializeObject(model.State)==before,label);}
  Rollback(_=>{},v=>v.BuyTownItem("welcome_basket"),"purchase rollback");
  Rollback(_=>{},v=>v.AcceptTownQuest("first_look"),"accept and ribbon rollback");
  Rollback(v=>v.AcceptTownQuest("first_look"),v=>v.DressManager("neck","store_ribbon"),"dress rollback");
  Rollback(v=>{v.BuyTownItem("welcome_basket");v.AcceptTownQuest("welcome_picnic");},v=>v.CompleteTownQuest("welcome_picnic"),"discovery rollback");
  Rollback(v=>{v.State.cats[5].known=true;v.BuyTownItem("welcome_basket");v.AcceptTownQuest("welcome_picnic");},v=>v.CompleteTownQuest("welcome_picnic"),"coin reward rollback");
  check(Wardrobe.All.Count(w=>w.price>0)==9&&Wardrobe.All.Count(w=>w.giftCat>=0)==3,"preserve nine paid items and three gifts");
  check(!poor.BuyWear("store_ribbon").success,"ribbon is quest-only");
  var ordinary=Fresh(new MemoryStore());double rate=ordinary.Rate();check(rate>0&&ordinary.Care(0,"brush").success&&ordinary.TownInventory.Count==0,"care and income need no stock");
  var malformed=JObject.FromObject(m.State);malformed["managerOutfit"]["neck"]=5;check(!m.RestoreJson(malformed.ToString()),"non-string manager outfit rejected");
  malformed=JObject.FromObject(m.State);malformed["hotels"][0]["town"]["specialFlags"]=new JArray("market_bundle","market_bundle");check(!m.RestoreJson(malformed.ToString()),"duplicate held special rejected");
  var authored=JObject.Parse(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/MainStreet.json"));
  authored["quests"][0]["cat"]=999;bool rejected=false;try{TownContent.LoadJson(authored.ToString());}catch(FormatException){rejected=true;}check(rejected,"quest cat must exist");
 }
}
