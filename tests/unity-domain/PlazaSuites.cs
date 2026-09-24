using System;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

// Phase 4 of Meadow Life: plaza events with neighbors, Buzz and payoffs.
static class PlazaSuites
{
 const string EventsPath="unity/PurringtonHotel/Assets/Resources/Content/Events.json";

 public static void Run(Action<bool,string> check,ParityContent content)
 {
  RunContent(check);
  RunHosting(check,content);
  RunDuringEvent(check,content);
  RunPayoff(check,content);
  RunSaves(check,content);
  Console.WriteLine("Plaza suite passed");
 }

 static HotelModel Fresh(ParityContent content){var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();return m;}
 static void At(HotelModel m,float minute){m.State.elapsed=minute>=HotelClock.StartMinute?minute-HotelClock.StartMinute:minute+HotelClock.DayLengthSeconds-HotelClock.StartMinute;}
 static void StandAt(HotelModel m,string node){var p=TownContent.Current.Point(node);var t=m.Hotel(0).town;t.phase="street";t.x=p.x;t.z=p.z;t.floor=0;t.shop="";t.destination="";}
 static HotelModel Evening(ParityContent content){var m=Fresh(content);At(m,1100);m.State.coins=1000;return m;}

 static void RunContent(Action<bool,string> check)
 {
  var raw=File.ReadAllText(EventsPath);var plaza=PlazaContent.LoadJson(raw);
  check(plaza.Events.Length==3&&plaza.Events.All(e=>ChatterContent.Current.HasTopic(e.topic)&&Catalog.Find(e.goldItem)!=null),"three events with real topics and gold items");
  check(plaza.Find("movie_night").OpenAt(1100)&&!plaza.Find("movie_night").OpenAt(700)&&plaza.Find("nap_a_thon").OpenAt(700),"event hours");
  var original=JObject.Parse(raw);
  void Reject(Action<JObject> change,string reason)
  {
   var bad=(JObject)original.DeepClone();change(bad);bool rejected=false;
   try{PlazaContent.LoadJson(bad.ToString());}catch(FormatException){rejected=true;}
   check(rejected,reason);
  }
  Reject(j=>j["events"][0]["topic"]="taxes","reject an unknown topic");
  Reject(j=>j["events"][0]["goldItem"]="rocket","reject an unknown gold item");
  Reject(j=>j["events"][0]["to"]=10,"reject hours that end before they start");
  Reject(j=>j["events"][0]["greeting"][0]=new string('a',81),"reject long event lines");
  Reject(j=>((JArray)j["events"]).Add(j["events"][0].DeepClone()),"reject duplicate events");
  check(ReferenceEquals(PlazaContent.Current,plaza),"rejected events do not replace registry");
 }

 static void RunHosting(Action<bool,string> check,ParityContent content)
 {
  var early=Fresh(content);At(early,700);early.State.coins=1000;
  var closed=early.CanHost("movie_night");check(!closed.success&&closed.message.Contains("18:00"),"Movie Night waits for evening");
  check(early.CanHost("nap_a_thon").success,"the Nap-a-thon is open at lunchtime");
  var poor=Evening(content);poor.State.coins=10;check(!poor.CanHost("movie_night").success,"hosting costs coins");
  var m=Evening(content);
  var coming=m.PredictAttendees("movie_night");
  check(coming.Contains("dot")&&coming.Contains("reginald")&&coming.Contains("marmalade")&&!coming.Contains("tom"),"gossip lovers come to Movie Night and Old Tom stays away: "+string.Join(",",coming));
  m.Hotel(0).neighbors.Add(new NeighborState{id="tom",friendship=80,tier=3});
  check(m.PredictAttendees("movie_night").Contains("tom"),"a best friend comes anyway");
  double coins=m.State.coins;var host=m.HostEvent("movie_night");
  check(host.success&&m.PlazaEventActive&&m.PlazaEventId=="movie_night"&&Math.Abs(coins-m.State.coins-80)<.001&&m.PlazaAttendees.Count==4,"host Movie Night: "+host.message);
  check(!m.CanHost("movie_night").success&&!m.StartMarketDay().success,"nothing else uses the square meanwhile");
  var market=Evening(content);market.Hotel(0).town.specialFlags.Add("market_bundle");check(market.StartMarketDay().success&&!market.CanHost("movie_night").success,"no events during Market Day");
 }

 static void RunDuringEvent(Action<bool,string> check,ParityContent content)
 {
  var m=Evening(content);m.HostEvent("movie_night");var square=TownContent.Current.Point("square");
  foreach(var id in m.PlazaAttendees){var v=m.Neighbor(id);check(v.present&&!v.walking&&v.position.Distance(square)<=1.5f,id+" stands at the square");}
  StandAt(m,"square");
  check(m.BeginNeighborChat("dot").success&&PlazaContent.Current.Find("movie_night").greeting.Contains(m.CurrentChat.line),"attendees talk about the event");
  int buzz=m.PlazaBuzz;var n=NeighborContent.Current.Find("dot");string topic=m.CurrentChat.topics[0];
  m.Talk(topic);
  check(m.PlazaBuzz==Math.Min(100,buzz+HotelModel.ChatBuzz(n.Reaction(topic))),"chatting fills the Buzz meter");
  m.BuyGift("tennis_ball");buzz=m.PlazaBuzz;m.GiveGift("tennis_ball");
  check(m.PlazaBuzz==Math.Min(100,buzz+HotelModel.GiftBuzz),"gifts add Buzz");
  m.EndChat();
  buzz=m.PlazaBuzz;for(int i=0;i<40;i++)m.Tick(.2f);
  check(m.PlazaBuzz==Math.Min(100,buzz+2*m.PlazaAttendees.Count),"a crowd builds Buzz on its own");
  var outsider=Evening(content);outsider.HostEvent("movie_night");StandAt(outsider,"square");
  check(!outsider.PlazaAttendees.Contains("tom")&&(outsider.Neighbor("tom")?.position.Distance(square)??99)>2,"Old Tom isn't at the square");
 }

 static void RunPayoff(Action<bool,string> check,ParityContent content)
 {
  string summary=null;
  var bronze=Evening(content);bronze.PlazaEventEnded+=s=>summary=s;bronze.HostEvent("movie_night");bronze.Hotel(0).town.plazaAttendees.Clear();double coins=bronze.State.coins;
  for(int i=0;i<610&&bronze.PlazaEventActive;i++)bronze.Tick(.2f);
  check(!bronze.PlazaEventActive&&bronze.Hotel(0).town.plazaResult=="bronze"&&bronze.State.coins>=coins+HotelModel.BronzeCoins&&summary!=null&&summary.Contains("Bronze"),"an empty square still pays a little: "+summary);
  check(!bronze.Neighbor("marmalade").present,"after the show Marmalade goes home on schedule");

  var gold=Evening(content);summary=null;gold.PlazaEventEnded+=s=>summary=s;gold.HostEvent("movie_night");
  foreach(var c in gold.State.cats.Where(c=>c.id>=6&&c.id<12))c.known=false;
  var attendees=gold.PlazaAttendees.ToArray();gold.Hotel(0).town.plazaBuzz=95;int known=gold.State.cats.Count(c=>c.known);int stored=gold.State.storage.Count;coins=gold.State.coins;
  for(int i=0;i<610&&gold.PlazaEventActive;i++)gold.Tick(.2f);
  check(gold.Hotel(0).town.plazaResult=="gold"&&gold.State.coins>=coins+HotelModel.GoldCoins,"gold pays the most");
  check(attendees.All(id=>gold.NeighborData(id).friendship>=HotelModel.GoldFriendship),"every attendee warms up");
  check(gold.State.cats.Count(c=>c.known)>=known+1&&gold.State.storage.Skip(stored).Any(o=>o.itemId=="lamp"),"a new guest and the gold item");
  check(summary.Contains("Gold")&&summary.Contains(PlazaContent.Current.Find("movie_night").gold),"the summary celebrates");
  check(HotelModel.Valid(gold.State),"the save stays valid after the payoff");
  check(HotelModel.BuzzTier(39)=="bronze"&&HotelModel.BuzzTier(40)=="silver"&&HotelModel.BuzzTier(80)=="gold","Buzz tiers");
 }

 static void RunSaves(Action<bool,string> check,ParityContent content)
 {
  var m=Evening(content);m.HostEvent("movie_night");m.Tick(1);
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(HotelModel.Valid(round)&&round.hotels[0].town.plazaEvent=="movie_night"&&round.hotels[0].town.plazaAttendees.Count==m.PlazaAttendees.Count,"an event in progress survives a save");
  HotelState Bad(Action<HotelState> change){var s=HotelModel.Copy(m.State);change(s);return s;}
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.plazaEvent="rave")),"reject an unknown event");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.plazaRemaining=601)),"reject an endless event");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.plazaBuzz=101)),"reject too much Buzz");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.plazaAttendees.Add("bob"))),"reject an unknown attendee");
  check(!HotelModel.Valid(Bad(s=>{s.hotels[0].town.plazaEvent="";})),"reject time left with no event");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].town.plazaResult="platinum")),"reject an unknown result");
  check(!HotelModel.Valid(Bad(s=>{s.hotels[1].town.plazaEvent="movie_night";s.hotels[1].town.plazaRemaining=10;})),"reject events at other destinations");
  var json=JObject.FromObject(m.State);json["hotels"][0]["town"]["plazaBuzz"]="loud";check(!m.RestoreJson(json.ToString()),"strict save rejects text Buzz");
  json=JObject.FromObject(Fresh(content).State);foreach(var name in new[]{"plazaEvent","plazaResult","plazaRemaining","plazaBuzz","plazaDay","plazaSerial","plazaAttendees"})((JObject)json["hotels"][0]["town"]).Remove(name);
  check(m.RestoreJson(json.ToString()),"saves from before plaza events still load");
 }
}
