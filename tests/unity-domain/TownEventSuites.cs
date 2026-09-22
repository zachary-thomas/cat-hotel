using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;

static class TownEventSuites {
 public static void Run(Action<bool,string> check) {
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
}
