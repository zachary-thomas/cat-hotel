using System;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

// Phase 2 of Meadow Life: neighbors with routines, friendship tiers and gifts.
static class NeighborSuites
{
 const string NeighborsPath="unity/PurringtonHotel/Assets/Resources/Content/Neighbors.json";

 public static void Run(Action<bool,string> check,ParityContent content)
 {
  if(ChatterContent.Current==null)ChatterContent.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/Chatter.json"));
  RunContent(check,content);
  RunRoutines(check,content);
  RunChat(check,content);
  RunTiers(check,content);
  RunGifts(check,content);
  RunSaves(check,content);
  Console.WriteLine("Neighbor suite passed");
 }

 static HotelModel Fresh(ParityContent content,MemoryStore store=null){var m=new HotelModel(store??new MemoryStore(),content);m.LoadOrCreate();return m;}
 // Sets the clock to a minute of day one (the game starts at 08:00).
 static void At(HotelModel m,float minute){m.State.elapsed=minute>=HotelClock.StartMinute?minute-HotelClock.StartMinute:minute+HotelClock.DayLengthSeconds-HotelClock.StartMinute;}
 static void StandAt(HotelModel m,string node){var p=TownContent.Current.Point(node);var t=m.Hotel(0).town;t.phase="street";t.x=p.x;t.z=p.z;t.floor=0;t.shop="";t.destination="";}
 static void TickUntil(HotelModel m,Func<bool> done,float seconds){for(float t=0;t<seconds&&!done();t+=.2f)m.Tick(.2f);}
 static string Friendly(NeighborContent.Neighbor n,string[] topics)=>topics.First(t=>n.Reaction(t)!="dislike");

 static void RunContent(Action<bool,string> check,ParityContent content)
 {
  var raw=File.ReadAllText(NeighborsPath);
  var neighbors=NeighborContent.LoadJson(raw);
  var town=TownContent.Current;
  check(neighbors.Neighbors.Length==6&&neighbors.Gifts.Length==6,"six neighbors and six gifts");
  var starter=content.CreateState();
  foreach(var n in neighbors.Neighbors)
  {
   check(n.schedule.All(s=>town.IsStreetTarget(s.place))&&town.IsStreetTarget(n.home),n.id+" keeps to Main Street");
   check(!starter.cats[n.introduces].known,n.id+" introduces a cat the player has not met");
   check(Catalog.Find(n.friendGift)!=null,n.id+" gives real furniture");
   var wear=Wardrobe.Find(n.bestGift);check(wear!=null&&wear.giftNeighbor==n.id&&wear.price==0,n.id+" has a signature wear gift");
   check(neighbors.FindGift(n.favoriteGift)!=null,n.id+" has a favorite gift on sale");
   check(ChatterContent.Current.TopicIds.All(t=>n.topics.ContainsKey(t)&&n.topics[t].Length>=2),n.id+" talks about every topic");
   check(new[]{n.greeting,n.signoff,n.chattedOut,n.tierUp,n.giftLove,n.giftOk}.All(p=>p.All(l=>l.Length<=ChatterContent.MaxLine)),n.id+" lines fit the bubble");
  }
  check(neighbors.Neighbors.Select(n=>n.introduces).Distinct().Count()==6,"each neighbor introduces a different cat");
  check(neighbors.Neighbors.Select(n=>n.favoriteGift).Distinct().Count()==6,"each neighbor has its own favorite gift");
  var original=JObject.Parse(raw);
  void Reject(Action<JObject> change,string reason)
  {
   var bad=(JObject)original.DeepClone();change(bad);bool rejected=false;
   try{NeighborContent.LoadJson(bad.ToString());}catch(FormatException){rejected=true;}
   check(rejected,reason);
  }
  Reject(j=>j["neighbors"][0]["schedule"][0][1]="the moon","reject a place off Main Street");
  Reject(j=>j["neighbors"][0]["schedule"][1][0]=100,"reject a schedule that goes back in time");
  Reject(j=>j["neighbors"][0]["greeting"][0]=new string('a',81),"reject long neighbor lines");
  Reject(j=>((JObject)j["neighbors"][0]["topics"]).Remove("naps"),"reject a missing topic");
  Reject(j=>j["neighbors"][0]["likes"]["dislike"]="snacks","reject contradictory likes");
  Reject(j=>j["neighbors"][0]["favoriteGift"]="gold bar","reject an unknown favorite gift");
  Reject(j=>j["neighbors"][0]["coat"]="plaid","reject an unknown coat");
  Reject(j=>((JArray)j["neighbors"]).Add(j["neighbors"][0].DeepClone()),"reject duplicate neighbors");
  Reject(j=>((JArray)j["neighbors"][0]["tierUp"]).RemoveAt(0),"reject missing tier-up lines");
  check(ReferenceEquals(NeighborContent.Current,neighbors),"rejected neighbor content does not replace registry");
 }

 static void RunRoutines(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);var town=TownContent.Current;
  At(m,100);check(m.NeighborViews.All(v=>!v.present),"everyone is home in the small hours");
  At(m,600);var marmalade=m.Neighbor("marmalade");
  check(marmalade.present&&!marmalade.walking&&marmalade.position.Distance(town.Point("square"))<.01f&&marmalade.place=="square","Marmalade is at the square mid-morning");
  At(m,545);marmalade=m.Neighbor("marmalade");
  check(marmalade.present&&marmalade.walking&&marmalade.position.Distance(town.Point("square"))>1,"Marmalade walks between places");
  int present=0;
  for(float minute=0;minute<HotelClock.DayLengthSeconds;minute+=7)
  {
   At(m,minute);
   foreach(var v in m.NeighborViews.Where(v=>v.present))
   {
    present++;
    check(TownRoute.Find(town,v.position,"hotel_gate").Count>0,v.id+" stays on the pedestrian links at "+minute);
    check(v.position.z>=12||v.position.z<=-12,v.id+" never walks through the hotel");
   }
  }
  check(present>100,"neighbors are out and about during the day");
  var other=Fresh(content);other.SetGodMode(true);other.Travel(1);
  check(other.NeighborViews.Count==0&&other.Neighbor("dot")==null,"neighbors live at Meadow only");
 }

 static void RunChat(Action<bool,string> check,ParityContent content)
 {
  var neighbors=NeighborContent.Current;var n=neighbors.Find("marmalade");
  var m=Fresh(content);At(m,600);
  var order=m.OrderManagerNeighbor("marmalade");check(order.success&&m.ManagerOrders[0].kind==ManagerOrderKind.ChatNeighbor,"order a chat with Marmalade");
  check(!m.OrderManagerNeighbor("marmalade").success,"duplicate neighbor order refused");
  TickUntil(m,()=>m.CurrentChat!=null||m.ManagerOrders.Count==0,120);
  check(m.CurrentChat!=null&&m.CurrentChat.neighbor=="marmalade"&&!m.ManagerInHotel,"the manager walks out and starts the chat");
  check(m.ManagerPosition.Distance(m.Neighbor("marmalade").position)<=2.1f,"the chat opens beside her");
  check(n.greeting.Select(l=>l.Replace("{manager}",m.State.managerName)).Contains(m.CurrentChat.line),"she greets in her own voice");
  string topic=Friendly(n,m.CurrentChat.topics);string reaction=n.Reaction(topic);
  var said=m.Talk(topic);
  check(said.success&&n.topics[topic].Contains(said.message),"she answers from her own lines");
  var state=m.NeighborData("marmalade");
  check(state.friendship==HotelModel.NeighborReactionFriendship(reaction)&&state.chatsToday==1&&state.learned.Contains(topic)&&m.CurrentChat.bondDelta==state.friendship,"friendship, the daily count and learned likes update");
  var bye=m.EndChat();check(bye.success&&n.signoff.Contains(bye.message)&&m.CurrentChat==null,"she signs off");

  // Chatting holds a neighbor's routine: Marmalade leaves for the bench at 13:00, but not mid-chat.
  var hold=Fresh(content);At(hold,775);StandAt(hold,"square");
  check(hold.BeginNeighborChat("marmalade").success,"chat just before she leaves");
  for(int i=0;i<50;i++)hold.Tick(.2f);
  check(hold.CurrentChat!=null&&hold.Neighbor("marmalade").position.Distance(TownContent.Current.Point("square"))<.01f,"she waits while you talk");
  hold.EndChat();for(int i=0;i<5;i++)hold.Tick(.2f);
  check(!hold.Neighbor("marmalade").walking,"she finishes her pause after the chat");
  for(int i=0;i<25;i++)hold.Tick(.2f);
  check(hold.Neighbor("marmalade").walking,"then she heads off, a little late");

  var capped=Fresh(content);At(capped,600);StandAt(capped,"square");
  capped.Hotel(0).neighbors.Add(new NeighborState{id="marmalade",friendship=20,tier=1,chatDay=capped.Clock.day,chatsToday=HotelModel.NeighborChatsPerDay});
  check(capped.BeginNeighborChat("marmalade").success&&!capped.CurrentChat.counts&&n.chattedOut.Contains(capped.CurrentChat.line),"chatted out for today");
  capped.Talk(capped.CurrentChat.topics[0]);check(capped.NeighborData("marmalade").friendship==20,"chatted-out talk leaves friendship alone");
  capped.EndChat();

  var far=Fresh(content);At(far,600);check(!far.BeginNeighborChat("marmalade").success,"the manager has to walk over first");
  At(far,100);check(!far.OrderManagerNeighbor("marmalade").success,"nobody answers the door at night");

  string failure=null;var leaving=Fresh(content);leaving.ManagerOrderFailed+=msg=>failure=msg;At(leaving,1150);
  check(leaving.Neighbor("marmalade").present&&leaving.OrderManagerNeighbor("marmalade").success,"order as she walks home");
  TickUntil(leaving,()=>failure!=null||leaving.CurrentChat!=null,60);
  check(failure!=null&&failure.Contains("went home")||leaving.CurrentChat!=null,"either you catch her or she goes home: "+failure);
 }

 static void RunTiers(Action<bool,string> check,ParityContent content)
 {
  var n=NeighborContent.Current.Find("marmalade");
  HotelModel Near(int friendship,int tier){var m=Fresh(content);At(m,600);StandAt(m,"square");m.Hotel(0).neighbors.Add(new NeighborState{id="marmalade",friendship=friendship,tier=tier});m.BeginNeighborChat("marmalade");return m;}
  var one=Near(14,0);check(!one.State.cats[n.introduces].known,"Maple is a stranger at first");
  one.Talk(Friendly(n,one.CurrentChat.topics));
  check(one.NeighborData("marmalade").tier==1&&one.State.cats[n.introduces].known&&one.CurrentChat.tierUp==n.tierUp[0]&&one.CurrentChat.reward.Contains(one.State.cats[n.introduces].name),"Acquaintance: Marmalade introduces Maple");
  var known=Near(14,0);known.State.cats[n.introduces].known=true;double coins=known.State.coins;
  known.Talk(Friendly(n,known.CurrentChat.topics));
  check(Math.Abs(known.State.coins-coins-60)<.001&&known.CurrentChat.reward.Contains("60"),"an already-known cat becomes 60 coins");
  var two=Near(39,1);int stored=two.State.storage.Count;
  two.Talk(Friendly(n,two.CurrentChat.topics));
  check(two.NeighborData("marmalade").tier==2&&two.State.storage.Count==stored+1&&two.State.storage.Last().itemId==n.friendGift&&two.State.storage.Last().paid==0,"Friend: flowers arrive in storage");
  check(HotelModel.Valid(two.State),"a friendship gift keeps the save valid");
  var three=Near(74,2);check(!three.OwnsWear(n.bestGift)&&!three.BuyWear(n.bestGift).success,"the baker's hat can't be bought");
  three.Talk(Friendly(n,three.CurrentChat.topics));
  check(three.NeighborData("marmalade").tier==3&&three.OwnsWear(n.bestGift),"Best Friend: the baker's hat is yours");
  check(three.DressManager("head",n.bestGift).success,"the manager can wear it");
  var drop=Near(76,3);string dislike=n.dislike;
  check(HotelModel.TierFor(0)==0&&HotelModel.TierFor(15)==1&&HotelModel.TierFor(40)==2&&HotelModel.TierFor(75)==3&&HotelModel.TierFor(100)==3,"tier thresholds");
  drop.Hotel(0).neighbors[0].friendship=75;drop.Hotel(0).neighbors[0].tier=3;
  check(drop.OwnsWear(n.bestGift),"rewards stay earned even if friendship later dips");
 }

 static void RunGifts(Action<bool,string> check,ParityContent content)
 {
  var n=NeighborContent.Current.Find("marmalade");var m=Fresh(content);At(m,600);
  double coins=m.State.coins;
  check(m.BuyGift("cinnamon_jar").success&&m.GiftCount("cinnamon_jar")==1&&Math.Abs(coins-m.State.coins-14)<.001,"buy a cinnamon jar");
  check(m.BuyGift("tennis_ball").success&&!m.BuyGift("gold bar").success,"buy another gift, refuse an unknown one");
  check(!m.GiveGift("cinnamon_jar").success,"gifts are given during a chat");
  StandAt(m,"square");m.BeginNeighborChat("marmalade");
  check(!m.GiveGift("sardine_tin").success,"can't give what you don't have");
  var given=m.GiveGift("cinnamon_jar");
  check(given.success&&n.giftLove.Contains(given.message)&&m.CurrentChat.reaction=="love"&&m.NeighborData("marmalade").friendship==HotelModel.FavoriteGiftFriendship&&m.GiftCount("cinnamon_jar")==0&&!m.State.gifts.ContainsKey("cinnamon_jar"),"the favorite gift is loved");
  check(!m.GiveGift("tennis_ball").success&&m.GiftCount("tennis_ball")==1,"one present per day");
  m.EndChat();m.State.elapsed+=HotelClock.DayLengthSeconds;StandAt(m,"square");m.BeginNeighborChat("marmalade");
  var ok=m.GiveGift("tennis_ball");
  check(ok.success&&n.giftOk.Contains(ok.message)&&m.NeighborData("marmalade").friendship==HotelModel.FavoriteGiftFriendship+HotelModel.GiftFriendship,"other gifts are appreciated too");
  var poorStore=new MemoryStore();var poor=Fresh(content,poorStore);poor.State.coins=5;check(!poor.BuyGift("sheet_music").success&&poor.GiftCount("sheet_music")==0,"not enough coins");
  poor.State.coins=100;poorStore.fail=true;check(!poor.BuyGift("sheet_music").success&&poor.State.coins==100&&poor.GiftCount("sheet_music")==0,"failed save rolls a purchase back");
 }

 static void RunSaves(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);At(m,600);StandAt(m,"square");m.BuyGift("sardine_tin");m.BeginNeighborChat("marmalade");m.Talk(m.CurrentChat.topics[0]);m.EndChat();
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(HotelModel.Valid(round)&&round.hotels[0].neighbors.Count==1&&round.gifts["sardine_tin"]==1,"neighbors and gifts survive a save");
  HotelState Bad(Action<HotelState> change){var s=HotelModel.Copy(m.State);change(s);return s;}
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].friendship=101)),"reject friendship over 100");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].id="bob")),"reject an unknown neighbor");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].chatsToday=4)),"reject too many chats");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].tier=4)),"reject an impossible tier");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors[0].learned.Add("taxes"))),"reject an unknown learned topic");
  check(!HotelModel.Valid(Bad(s=>s.hotels[0].neighbors.Add(new NeighborState{id="marmalade"}))),"reject duplicate neighbor records");
  check(!HotelModel.Valid(Bad(s=>s.hotels[1].neighbors.Add(new NeighborState{id="dot"}))),"reject neighbors at other destinations");
  check(!HotelModel.Valid(Bad(s=>s.gifts["gold bar"]=1)),"reject unknown gifts");
  check(!HotelModel.Valid(Bad(s=>s.gifts["sardine_tin"]=0)),"reject empty gift entries");
  check(!HotelModel.Valid(Bad(s=>s.wardrobe.Add("baker_hat"))),"best-friend gifts are never bought");
  var json=JObject.FromObject(m.State);json["gifts"]["sardine_tin"]="one";check(!m.RestoreJson(json.ToString()),"strict save rejects text gift counts");
  json=JObject.FromObject(m.State);json["hotels"][0]["neighbors"][0]["friendship"]="lots";check(!m.RestoreJson(json.ToString()),"strict save rejects text friendship");
  json=JObject.FromObject(m.State);json.Remove("gifts");foreach(var h in json["hotels"])((JObject)h).Remove("neighbors");
  check(m.RestoreJson(json.ToString()),"saves from before neighbors still load");
 }
}
