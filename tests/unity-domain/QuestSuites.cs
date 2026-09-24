using System;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

// Phase 3 of Meadow Life: neighbor requests and rumors that lead to the outskirts.
static class QuestSuites
{
 const string QuestsPath="unity/PurringtonHotel/Assets/Resources/Content/Quests.json";

 public static void Run(Action<bool,string> check,ParityContent content)
 {
  RunContent(check);
  RunRequests(check,content);
  RunRumors(check,content);
  RunSaves(check,content);
  Console.WriteLine("Quest suite passed");
 }

 static HotelModel Fresh(ParityContent content){var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();return m;}
 static void At(HotelModel m,float minute){m.State.elapsed=minute>=HotelClock.StartMinute?minute-HotelClock.StartMinute:minute+HotelClock.DayLengthSeconds-HotelClock.StartMinute;}
 static void StandAt(HotelModel m,string node){var p=TownContent.Current.Point(node);var t=m.Hotel(0).town;t.phase="street";t.x=p.x;t.z=p.z;t.floor=0;t.shop="";t.destination="";}
 static void TickUntil(HotelModel m,Func<bool> done,float seconds){for(float t=0;t<seconds&&!done();t+=.2f)m.Tick(.2f);}
 static HotelModel Friendly(ParityContent content,int friendship=20,int tier=1)
 {
  var m=Fresh(content);At(m,600);StandAt(m,"square");
  m.Hotel(0).neighbors.Add(new NeighborState{id="marmalade",friendship=friendship,tier=tier});
  return m;
 }

 static void RunContent(Action<bool,string> check)
 {
  var raw=File.ReadAllText(QuestsPath);var quests=QuestContent.LoadJson(raw);
  check(quests.Spots.Length==3&&quests.Spots.All(s=>TownContent.Current.IsStreetTarget(s.id)),"three outskirts spots on the street graph");
  check(quests.Spots.All(s=>QuestContent.Finds.All(f=>quests.Rumors.Any(r=>r.spot==s.id&&r.find==f))),"a rumor for every spot and find");
  check(quests.Builds.All(b=>b.items.All(i=>Catalog.Find(i)!=null))&&quests.Treasures.All(i=>Catalog.Find(i)!=null),"requests and treasures name real furniture");
  foreach(var spot in quests.Spots)check(TownRoute.Find(TownContent.Current,TownContent.Current.Point("hotel_gate"),spot.id).Count>1,spot.id+" is reachable from the hotel");
  var original=JObject.Parse(raw);
  void Reject(Action<JObject> change,string reason)
  {
   var bad=(JObject)original.DeepClone();change(bad);bool rejected=false;
   try{QuestContent.LoadJson(bad.ToString());}catch(FormatException){rejected=true;}
   check(rejected,reason);
  }
  Reject(j=>j["spots"][0]["id"]="the moon","reject a spot off the street graph");
  Reject(j=>j["rumors"]=new JArray(((JArray)j["rumors"]).Skip(1)),"reject a missing rumor");
  Reject(j=>j["builds"][0]["items"][0]="rocket","reject unknown request furniture");
  Reject(j=>j["treasures"][0]="crown jewels","reject unknown treasure");
  Reject(j=>j["rumors"][0]["text"]=new string('a',81),"reject a long rumor");
  Reject(j=>((JObject)j["found"]).Remove("kittenKnown"),"reject a missing found line");
  check(ReferenceEquals(QuestContent.Current,quests),"rejected quest content does not replace registry");
 }

 static void RunRequests(Action<bool,string> check,ParityContent content)
 {
  var stranger=Fresh(content);At(stranger,600);StandAt(stranger,"square");stranger.BeginNeighborChat("marmalade");
  check(string.IsNullOrEmpty(stranger.NeighborData("marmalade").request)&&stranger.RumorSpot=="","strangers don't ask favors or share rumors");

  var m=Friendly(content);
  check(m.BeginNeighborChat("marmalade").success,"chat with an acquaintance");
  var state=m.NeighborData("marmalade");
  check(state.request.Length>0&&state.requestDay==m.Clock.day&&m.CurrentChat.request==m.RequestText(state)&&m.CurrentChat.request.Length>0,"the first chat of the day brings a request");
  check(m.RumorSpot.Length>0&&m.CurrentChat.rumor&&QuestContent.Current.Rumors.Any(r=>r.text==m.CurrentChat.line&&r.spot==m.RumorSpot),"and a rumor, told instead of hello");
  string posted=state.request;string rumor=m.RumorSpot;m.EndChat();
  m.BeginNeighborChat("marmalade");
  check(m.NeighborData("marmalade").request==posted&&m.RumorSpot==rumor&&!m.CurrentChat.rumor,"one request and one rumor per day");
  m.EndChat();

  // Fetch: bring the gift they asked for.
  var fetch=Friendly(content);var record=fetch.Hotel(0).neighbors[0];record.request="fetch:tennis_ball";record.requestDay=fetch.Clock.day;fetch.Hotel(0).town.rumorDay=fetch.Clock.day;
  fetch.BeginNeighborChat("marmalade");
  check(!fetch.CurrentChat.requestReady,"not ready without the gift");
  var nudge=fetch.AnswerRequest();check(nudge.success&&nudge.message.Contains("tennis ball")&&fetch.NeighborData("marmalade").request=="fetch:tennis_ball","she repeats the request");
  fetch.BuyGift("tennis_ball");fetch.EndChat();fetch.BeginNeighborChat("marmalade");
  double coins=fetch.State.coins;int friendship=fetch.NeighborData("marmalade").friendship;
  check(fetch.CurrentChat.requestReady,"ready once the gift is in the basket");
  var done=fetch.AnswerRequest();
  check(done.success&&QuestContent.Current.Thanks.Contains(done.message)&&Math.Abs(fetch.State.coins-coins-HotelModel.FetchCoins)<.001&&fetch.GiftCount("tennis_ball")==0,"fetch request: coins in, gift out");
  check(fetch.NeighborData("marmalade").friendship==friendship+HotelModel.RequestFriendship&&fetch.NeighborData("marmalade").requestsDone==1&&fetch.NeighborData("marmalade").request=="","friendship and a finished request");
  check(fetch.CurrentChat.reward.Contains("+"+HotelModel.FetchCoins),"the chat shows the reward");
  check(!fetch.AnswerRequest().success,"no more favors today");
  fetch.EndChat();fetch.BeginNeighborChat("marmalade");check(fetch.NeighborData("marmalade").request=="","no second request the same day");
  fetch.EndChat();fetch.State.elapsed+=HotelClock.DayLengthSeconds;StandAt(fetch,"square");fetch.BeginNeighborChat("marmalade");
  check(fetch.NeighborData("marmalade").request.Length>0,"a new request the next day");

  // Build: add more pieces from a group than there were when asked.
  var build=Friendly(content);var b=build.Hotel(0).neighbors[0];
  int fountains=build.Hotel(0).objects.Count(o=>o.itemId=="fountain"||o.itemId=="pool");
  b.request="build:splash";b.requestBase=fountains;b.requestDay=build.Clock.day;build.Hotel(0).town.rumorDay=build.Clock.day;
  build.BeginNeighborChat("marmalade");
  check(!build.CurrentChat.requestReady&&build.RequestProgress(b)=="0 / 1 built","build request starts at zero");
  build.Hotel(0).objects.Add(new ObjectState{id="object9001",itemId="fountain",x=0,z=0});
  check(build.RequestReady(b)&&build.RequestProgress(b)=="1 / 1 built","a new fountain counts");
  coins=build.State.coins;
  check(build.AnswerRequest().success&&Math.Abs(build.State.coins-coins-HotelModel.BuildCoins)<.001,"build request pays more");

  // A favor can push a neighbor into the next tier, and the tier reward pays out with it.
  var tierUp=Friendly(content,37,1);var t=tierUp.Hotel(0).neighbors[0];t.request="fetch:tennis_ball";t.requestDay=tierUp.Clock.day;tierUp.Hotel(0).town.rumorDay=tierUp.Clock.day;
  tierUp.BuyGift("tennis_ball");tierUp.BeginNeighborChat("marmalade");int stored=tierUp.State.storage.Count;
  tierUp.AnswerRequest();
  check(tierUp.NeighborData("marmalade").tier==2&&tierUp.State.storage.Count==stored+1&&tierUp.CurrentChat.tierUp.Length>0,"a favor can earn the next tier");
 }

 static void RunRumors(Action<bool,string> check,ParityContent content)
 {
  HotelModel With(string spot,string find){var m=Fresh(content);var t=m.Hotel(0).town;t.rumorSpot=spot;t.rumorFind=find;t.rumorGiver="dot";t.rumorDay=m.Clock.day;return m;}
  check(!Fresh(content).OrderManagerSearch().success,"no rumor, nothing to search");
  var lost=With("old_oak","lost_item");string found=null;lost.ManagerFound+=msg=>found=msg;double coins=lost.State.coins;
  check(!lost.FindRumor().success,"you have to go there");
  check(lost.OrderManagerSearch().success&&lost.ManagerOrders[0].kind==ManagerOrderKind.Search,"search order");
  TickUntil(lost,()=>found!=null,120);
  check(found==QuestContent.Current.Found("lost_item")&&Math.Abs(lost.State.coins-coins-HotelModel.LostItemCoins)>=0&&lost.State.coins>=coins+HotelModel.LostItemCoins,"the manager walks out and finds the coin purse");
  check(lost.RumorSpot==""&&lost.Hotel(0).town.rumorsFound==1&&lost.ManagerPosition.Distance(TownContent.Current.Point("old_oak"))<.01f,"the rumor is used up");
  check(HotelModel.Valid(lost.State),"the save stays valid out at the Old Oak");

  var kitten=With("lily_pond","kitten");StandAt(kitten,"lily_pond");int known=kitten.State.cats.Count(c=>c.known);
  var k=kitten.FindRumor();
  check(k.success&&kitten.State.cats.Count(c=>c.known)==known+1&&kitten.State.cats.Any(c=>c.known&&k.message.Contains(c.name)),"a kitten becomes a new guest");
  var allKnown=With("hilltop","kitten");StandAt(allKnown,"hilltop");foreach(var c in allKnown.State.cats)c.known=true;coins=allKnown.State.coins;
  check(allKnown.FindRumor().success&&Math.Abs(allKnown.State.coins-coins-HotelModel.KnownKittenCoins)<.001,"every cat known: a tip instead");
  var treasure=With("hilltop","treasure");StandAt(treasure,"hilltop");int stored=treasure.State.storage.Count;
  var tr=treasure.FindRumor();
  check(tr.success&&treasure.State.storage.Count==stored+1&&QuestContent.Current.Treasures.Contains(treasure.State.storage.Last().itemId)&&HotelModel.Valid(treasure.State),"treasure goes to storage");
 }

 static void RunSaves(Action<bool,string> check,ParityContent content)
 {
  var m=Friendly(content);m.BeginNeighborChat("marmalade");m.EndChat();
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(HotelModel.Valid(round)&&round.hotels[0].town.rumorSpot==m.RumorSpot&&round.hotels[0].neighbors[0].request==m.NeighborData("marmalade").request,"requests and rumors survive a save");
  HotelState Bad(Action<HotelState> change){var s=HotelModel.Copy(m.State);change(s);return s;}
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.rumorSpot="the moon")),"reject an unknown rumor spot");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.rumorFind="dragon")),"reject an unknown find");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.rumorGiver="bob")),"reject an unknown rumor giver");
  check(!HotelModel.Valid(Bad(s=>{s.hotels[0].town.rumorSpot="";s.hotels[0].town.rumorFind="kitten";})),"reject a find without a spot");
  check(!HotelModel.Valid(Bad(s=>{s.hotels[1].town.rumorSpot="old_oak";s.hotels[1].town.rumorFind="kitten";s.hotels[1].town.rumorGiver="dot";})),"reject rumors at other destinations");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].request="cook:pie")),"reject an unknown request kind");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].request="fetch:gold bar")),"reject an unknown fetch gift");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].request="build:castle")),"reject an unknown build request");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].requestBase=-1)),"reject a negative request baseline");
  var json=JObject.FromObject(m.State);json["hotels"][0]["town"]["rumorDay"]="today";check(!m.RestoreJson(json.ToString()),"strict save rejects a text rumor day");
  json=JObject.FromObject(m.State);foreach(var name in new[]{"rumorSpot","rumorFind","rumorGiver","rumorDay","rumorsFound"})((JObject)json["hotels"][0]["town"]).Remove(name);
  foreach(var n in json["hotels"][0]["neighbors"])foreach(var name in new[]{"request","requestBase","requestDay","requestsDone"})((JObject)n).Remove(name);
  check(m.RestoreJson(json.ToString()),"saves from before quests still load");
 }
}
