using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class TownEventSuites {
 public static void Run(Action<bool,string> check) {
  FinalFixChecks(check);
  var content=ParityContent.Current;
  var store=new MemoryStore();var model=new HotelModel(store,content);check(model.LoadOrCreate().success,"event setup");
  check(!model.StartMarketDay().success,"bundle required");
  model.State.coins=1000;check(model.BuyTownItem("market_bundle").success,"bundle bought");
  double rate=model.Rate();check(model.StartMarketDay().success,"event starts once");
  check(!model.StartMarketDay().success,"duplicate start rejected");
  check(Math.Abs(model.MarketDayRemaining-90)<.01,"full event duration");
  model.Tick(0);check(model.MarketDayRemaining==90,"paused game time does not advance event");
  model.Tick(30);check(Math.Abs(model.MarketDayRemaining-60)<.01,"active time advances");
  check(Math.Abs(model.Rate()-rate)<.01,"ordinary rate continues");
  var loaded=new HotelModel(store,content);check(loaded.LoadOrCreate().success&&Math.Abs(loaded.MarketDayRemaining-60)<.01,"remaining persists");
  int token=loaded.MarketDayReactionToken;loaded.Tick(60);
  check(loaded.MarketDayRemaining==0&&loaded.MarketDayReactionToken==token+1,"completion emits one token");
  loaded.Tick(30);check(loaded.MarketDayReactionToken==token+1,"no repeat token");
  var ended=new HotelModel(store,content);check(ended.LoadOrCreate().success&&ended.MarketDayReactionToken==token+1&&ended.MarketDayRemaining==0,"completed state reloads");
  check(ended.BuyTownItem("market_bundle").success&&ended.StartMarketDay().success,"bundle may be bought again");
  store.fail=true;float before=ended.MarketDayRemaining;int prior=ended.MarketDayReactionToken;ended.Tick(90);
  check(ended.MarketDayRemaining==before&&ended.MarketDayReactionToken==prior,"failed completion save rolls back event");
  store.fail=false;ended.Tick(90);check(ended.MarketDayReactionToken==prior+1,"completion retries once");
  var invalid=JObject.FromObject(ended.State);invalid["hotels"][0]["town"]["marketCompletionSerial"]=-1;check(!ended.RestoreJson(invalid.ToString()),"negative token rejected");
  invalid=JObject.FromObject(ended.State);invalid["hotels"][0]["town"]["eventRemaining"]=91;check(!ended.RestoreJson(invalid.ToString()),"overlong event rejected");
  invalid=JObject.FromObject(ended.State);invalid["hotels"][1]["town"]["eventRemaining"]=1;check(!ended.RestoreJson(invalid.ToString()),"event only in Meadow");
  var legacy=JObject.FromObject(ended.State);((JObject)legacy["hotels"][0]["town"]).Remove("marketCompletionSerial");
  check(ended.RestoreJson(legacy.ToString()),"optional v3 reaction field loads");
  var blocked=new MemoryStore();var fresh=new HotelModel(blocked,content);check(fresh.LoadOrCreate().success,"blocked start setup");
  check(fresh.BuyTownItem("market_bundle").success,"blocked start bundle");blocked.fail=true;
  check(!fresh.StartMarketDay().success&&fresh.MarketDayRemaining==0&&fresh.TownInventory.Contains("market_bundle"),"failed start save retains bundle");
  var pacedStore=new MemoryStore();var paced=new HotelModel(pacedStore,content);paced.LoadOrCreate();paced.State.coins=1000;paced.BuyTownItem("market_bundle");paced.StartMarketDay();
  int writes=0;for(int frame=0;frame<60;frame++){var saved=pacedStore.state;paced.Tick(1f/60);if(!ReferenceEquals(saved,pacedStore.state))writes++;}
  check(writes<=2,"market timer checkpoints at most once a second, not each frame");
  check(paced.MarketDayRemaining<89.1f&&paced.MarketDayRemaining>88.9f,"market clock remains smooth between checkpoints");
  paced.Tick(.125f);check(paced.Save().success,"explicit save flushes subsecond market time");
  var pacedReload=new HotelModel(pacedStore,content);check(pacedReload.LoadOrCreate().success&&Math.Abs(pacedReload.MarketDayRemaining-paced.MarketDayRemaining)<.0001f,"explicit save reload preserves current timer");
  before=paced.MarketDayRemaining;pacedStore.fail=true;paced.Tick(1);check(paced.MarketDayRemaining==before,"failed periodic checkpoint rolls back its tick");
  pacedStore.fail=false;paced.Tick(95);int completed=paced.MarketDayReactionToken;
  var finalReload=new HotelModel(pacedStore,content);check(finalReload.LoadOrCreate().success&&finalReload.MarketDayRemaining==0&&finalReload.MarketDayReactionToken==completed,"completion flushes immediately");
  finalReload.Tick(1);check(finalReload.MarketDayReactionToken==completed,"checkpoint cadence cannot repeat completion after reload"); }
 static void FinalFixChecks(Action<bool,string> check){
  var occupiedStore=new MemoryStore();var occupied=new HotelModel(occupiedStore,ParityContent.Current);occupied.LoadOrCreate();occupied.State.coins=2000;
  foreach(var cat in occupied.State.cats)cat.known=cat.id==5;
  occupied.Tick(.1f);occupied.BuyTownItem("welcome_basket");occupied.AcceptTownQuest("welcome_picnic");occupied.CompleteTownQuest("welcome_picnic");var actorIds=string.Join(";",occupied.Actors.Select(a=>a.id));var occupiedReservations=string.Join(";",occupied.Reservations.OrderBy(p=>p.Key));occupied.AdvanceTownWelcome(.1f);
  check(occupied.Actors.Any(a=>a.catId==5&&a.speech.Contains("Basket"))&&actorIds==string.Join(";",occupied.Actors.Select(a=>a.id)),"existing Biscuit reacts without duplicate actor");check(occupiedReservations==string.Join(";",occupied.Reservations.OrderBy(p=>p.Key)),"existing Biscuit keeps reservations");
  var unknown=new HotelModel(new MemoryStore(),ParityContent.Current);unknown.LoadOrCreate();unknown.State.coins=2000;unknown.BuyTownItem("welcome_basket");unknown.AcceptTownQuest("welcome_picnic");unknown.CompleteTownQuest("welcome_picnic");unknown.AdvanceTownWelcome(.1f);check(unknown.State.cats[5].known&&unknown.Actors.Any(a=>a.catId==5&&a.speech.Contains("Basket")),"new Biscuit discovers and visits");
  var store=new MemoryStore();var model=new HotelModel(store,ParityContent.Current);model.LoadOrCreate();model.State.coins=2000;
  model.SendManager("paw_mart_door");model.SkipManagerTravel();var door=new LotPoint(model.Hotel().town.x,model.Hotel().town.z);
  store.fail=true;check(!model.LeaveTownShop().success&&model.Hotel().town.shop=="paw_mart","failed Leave remains inside");store.fail=false;
  check(model.LeaveTownShop().success&&model.Hotel().town.shop==""&&new LotPoint(model.Hotel().town.x,model.Hotel().town.z).Distance(door)==0,"Leave clears shop and preserves door");
  var reload=new HotelModel(store,ParityContent.Current);check(reload.LoadOrCreate().success&&reload.Hotel().town.shop=="","Leave survives reload");
  var neighbor=TownContent.Current.Neighbors("paw_mart_door").First();var near=TownContent.Current.Point(neighbor);var delta=door.Distance(near);model.Hotel().town.x=door.x+(near.x-door.x)*.0005f/delta;model.Hotel().town.z=door.z+(near.z-door.z)*.0005f/delta;
  check(model.SendManager("paw_mart_door").success,"near-node trip starts");model.Tick(.1f);check(model.Hotel().town.destination==""&&model.Hotel().town.shop=="paw_mart","near-node trip reaches destination");
  model.State.cats[5].known=true;model.BuyTownItem("welcome_basket");model.AcceptTownQuest("welcome_picnic");double coins=model.State.coins;model.CompleteTownQuest("welcome_picnic");check(model.State.coins==coins+40,"known Biscuit reward once");
  reload=new HotelModel(store,ParityContent.Current);check(reload.LoadOrCreate().success,"pending Basket reload");reload.Tick(.1f);var reservations=string.Join(";",reload.Reservations.OrderBy(p=>p.Key));reload.AdvanceTownWelcome(.1f);
  check(reload.Actors.Any(a=>a.catId==5&&a.speech.Contains("Basket")),"Biscuit has actual hotel reaction with full roster");check(reservations==string.Join(";",reload.Reservations.OrderBy(p=>p.Key)),"welcome preserves reservations");
  reload.Save();var during=new HotelModel(store,ParityContent.Current);during.LoadOrCreate();during.AdvanceTownWelcome(.1f);check(during.Actors.Any(a=>a.speech.Contains("Basket")),"interrupted Basket welcome resumes");
  store.fail=true;during.AdvanceTownWelcome(10);check(!during.Hotel().town.basketWelcomeDelivered,"failed welcome acknowledgment stays pending");store.fail=false;during.AdvanceTownWelcome(10);check(during.Hotel().town.basketWelcomeDelivered,"Basket welcome acknowledged");
  var done=new HotelModel(store,ParityContent.Current);done.LoadOrCreate();done.AdvanceTownWelcome(1);check(!done.Actors.Any(a=>a.kind==ActorKind.TownWelcome)&&!done.CompleteTownQuest("welcome_picnic").success,"Basket welcome and reward cannot repeat after reload");
  done.BuyTownItem("market_bundle");done.StartMarketDay();done.Tick(90);check(done.Hotel().town.marketWelcomeDelivered==0,"market completion queues hotel welcome while away");
  var market=new HotelModel(store,ParityContent.Current);market.LoadOrCreate();market.AdvanceTownWelcome(.1f);check(market.Actors.Any(a=>a.kind==ActorKind.TownWelcome&&a.speech.Contains("Market Day")),"Market completion delivers actual actor after reload");market.AdvanceTownWelcome(6);
  var queuedStore=new MemoryStore();var queued=new HotelModel(queuedStore,ParityContent.Current);queued.LoadOrCreate();queued.State.coins=2000;queued.BuyTownItem("market_bundle");queued.StartMarketDay();queued.Tick(90);queued.AdvanceTownWelcome(1);queued.BuyTownItem("welcome_basket");queued.AcceptTownQuest("welcome_picnic");queued.CompleteTownQuest("welcome_picnic");queued.Save();
  var queuedReload=new HotelModel(queuedStore,ParityContent.Current);check(queuedReload.LoadOrCreate().success&&queuedReload.Hotel().town.welcomeKind=="market","active market welcome retains identity when Basket arrives");queuedReload.AdvanceTownWelcome(5);check(queuedReload.Hotel().town.marketWelcomeDelivered==1&&!queuedReload.Hotel().town.basketWelcomeDelivered,"active welcome finishes before queued Basket");queuedReload.AdvanceTownWelcome(.1f);check(queuedReload.Actors.Any(a=>a.catId==5&&a.speech.Contains("Basket")),"queued Basket follows Market welcome");
  var finished=new HotelModel(store,ParityContent.Current);finished.LoadOrCreate();finished.AdvanceTownWelcome(1);check(finished.Hotel().town.marketWelcomeDelivered==1&&!finished.Actors.Any(a=>a.kind==ActorKind.TownWelcome),"Market welcome durable and idempotent");
 }

}
