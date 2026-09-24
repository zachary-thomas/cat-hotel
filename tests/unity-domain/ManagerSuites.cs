using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

// Phase 1 of Meadow Life: the player directs the manager in Life and chats with guests.
static class ManagerSuites
{
 const string ChatterPath="unity/PurringtonHotel/Assets/Resources/Content/Chatter.json";

 public static void Run(Action<bool,string> check,Func<string,JObject> P,ParityContent content)
 {
  RunChatterContent(check,content);
  RunWalking(check,content);
  RunQueue(check,content);
  RunChat(check,content);
  RunSaves(check,content);
  RunFloors(check,P,content);
  Console.WriteLine("Manager suite passed");
 }

 static HotelModel Fresh(ParityContent content,MemoryStore store=null)
 {
  var m=new HotelModel(store??new MemoryStore(),content);m.LoadOrCreate();
  return m;
 }
 static void TickUntil(HotelModel m,Func<bool> done,float seconds){for(float t=0;t<seconds&&!done();t+=.2f)m.Tick(.2f);}
 static ActorSnapshot Guest(HotelModel m,int catId)=>m.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest&&a.catId==catId);

 static void RunChatterContent(Action<bool,string> check,ParityContent content)
 {
  var raw=File.ReadAllText(ChatterPath);
  var chatter=ChatterContent.LoadJson(raw);
  check(ReferenceEquals(ChatterContent.Current,chatter),"chatter registers as current");
  check(chatter.Topics.Length==6,"six chat topics");
  foreach(var pref in content.Cats.Select(c=>(string)c["preference"]).Distinct())check(chatter.Preferences.Contains(pref),"guest likes cover preference "+pref);
  check(chatter.Lines.All(l=>l.text.Length<=ChatterContent.MaxLine),"every line fits two bubble rows");
  check(chatter.Lines.Count(l=>l.preference==null)==72,"72 shared guest lines");
  foreach(var pref in chatter.Preferences)
  {
   var reactions=chatter.TopicIds.Select(t=>chatter.Reaction(pref,t)).ToArray();
   check(reactions.Count(r=>r=="love")==1&&reactions.Count(r=>r=="dislike")==1&&reactions.Count(r=>r=="like")==2,"one love, two likes, one dislike for "+pref);
  }
  check(chatter.Reaction("food","snacks")=="love"&&chatter.Reaction("food","play")=="dislike"&&chatter.Reaction("food","naps")=="meh","food cat tastes");
  check(chatter.Reaction("unknown","snacks")=="meh","unknown preference is neutral");
  var picked=chatter.Pick("guest","warm","naps","love",1);
  check(chatter.Lines.Any(l=>l.text==picked&&l.topic=="naps"&&l.reaction=="love"&&(l.preference==null||l.preference=="warm")),"picked line matches topic and reaction");
  check(chatter.Pick("guest","food","snacks","love",7)==chatter.Pick("guest","food","snacks","love",7),"line choice is deterministic");
  check(!chatter.Lines.Where(l=>l.preference=="warm").Select(l=>l.text).Contains(chatter.Pick("guest","food","naps","love",3)),"other preferences' lines stay out");
  var original=JObject.Parse(raw);
  void Reject(Action<JObject> change,string reason)
  {
   var bad=(JObject)original.DeepClone();change(bad);bool rejected=false;
   try{ChatterContent.LoadJson(bad.ToString());}catch(FormatException){rejected=true;}
   check(rejected,reason);
  }
  Reject(j=>j["lines"][0]["text"]=new string('a',81),"reject a line over 80 characters");
  Reject(j=>j["lines"][0]["text"]="<b>loud</b>","reject marked-up lines");
  Reject(j=>j["lines"][0]["topic"]="taxes","reject unknown topic");
  Reject(j=>j["lines"][0]["reaction"]="shrug","reject unknown reaction");
  Reject(j=>j["lines"]=new JArray(((JArray)j["lines"]).Where(l=>!((string)l["topic"]=="play"&&(string)l["reaction"]=="meh"))),"reject missing topic/reaction coverage");
  Reject(j=>((JObject)j["pools"]).Remove("signoff"),"reject missing sign-off pool");
  Reject(j=>j["guestLikes"]["food"]["dislike"]="snacks","reject contradictory likes");
  Reject(j=>j["schema"]=2,"reject unknown chatter schema");
  check(ReferenceEquals(ChatterContent.Current,chatter),"rejected chatter does not replace registry");
 }

 static void RunWalking(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);
  check(m.ManagerInHotel&&m.ManagerPosition.floor==0,"manager starts inside the hotel lot");
  var lobby=new LotPoint(-1.25f,-1.25f);
  check(!m.OrderManagerWalk(new LotPoint(500,500)).success&&m.ManagerOrders.Count==0,"unreachable ground is refused");
  check(!m.OrderManagerWalk(new LotPoint(float.NaN,0)).success,"non-finite ground is refused");
  check(m.OrderManagerWalk(lobby).success&&m.ManagerOrders.Count==1&&m.ManagerOrders[0].kind==ManagerOrderKind.Walk,"walk order queued");
  m.Tick(.2f);check(m.ManagerWalking,"manager walks");
  TickUntil(m,()=>m.ManagerOrders.Count==0,30);
  check(m.ManagerOrders.Count==0&&!m.ManagerWalking&&m.ManagerPosition.Distance(lobby)<.8f,"walk arrives in the lobby at "+m.ManagerPosition.x+","+m.ManagerPosition.z);
  check(m.CanWalk(m.ManagerPosition.x,m.ManagerPosition.z),"manager stands on open floor");

  check(m.OrderManagerStreet("square").success,"street order uses the town route");
  TickUntil(m,()=>m.Hotel().town.destination=="",60);
  check(!m.ManagerInHotel&&m.Hotel().town.floor==0&&m.ManagerPosition.Distance(TownContent.Current.Point("square"))<.01f,"manager reaches the square");
  check(m.OrderManagerWalk(lobby).success,"walk back into the hotel from the street");
  bool sawStreet=false;
  for(int i=0;i<300&&m.ManagerOrders.Count>0;i++){m.Tick(.2f);if(!m.ManagerInHotel){sawStreet=true;check(TownRoute.Find(TownContent.Current,new LotPoint(m.Hotel().town.x,m.Hotel().town.z),"hotel_gate").Count>0,"street leg stays on authored links");}}
  check(sawStreet&&m.ManagerInHotel&&m.ManagerPosition.Distance(lobby)<.8f,"manager walks home through the gate");

  m.OrderManagerStreet("paw_mart_door");TickUntil(m,()=>m.Hotel().town.destination=="",60);
  check(m.Hotel().town.shop=="paw_mart","manager inside Paw Mart");
  check(m.OrderManagerWalk(lobby).success&&m.Hotel().town.shop=="","a walk order leaves the shop");
  TickUntil(m,()=>m.ManagerOrders.Count==0,60);
  check(m.ManagerInHotel,"back from the shop");

  var paused=Fresh(content);
  check(paused.OrderManagerWalk(lobby).success,"pause setup");
  paused.Tick(.2f);paused.PauseManagerOrders(true);var stopped=paused.ManagerPosition;
  for(int i=0;i<25;i++)paused.Tick(.2f);
  check(paused.ManagerPosition.Distance(stopped)<.0001f&&paused.ManagerOrders.Count==1&&!paused.ManagerWalking,"paused orders hold still without being dropped");
  paused.PauseManagerOrders(false);TickUntil(paused,()=>paused.ManagerOrders.Count==0,30);
  check(paused.ManagerPosition.Distance(lobby)<.8f,"resumed order arrives");

  // Furniture dropped on the manager moves it to open floor rather than making the save unloadable.
  var blocked=Fresh(content);var solid=blocked.Hotel().objects.First(o=>Catalog.Find(o.itemId).shape!="rug"&&Catalog.Find(o.itemId).role!="gate"&&o.floor==0);
  HotelModel.Size(solid,out float sw,out float sd);
  var state=HotelModel.Copy(blocked.State);state.hotels[0].town.x=solid.x+sw/2;state.hotels[0].town.z=solid.z+sd/2;state.hotels[0].town.phase="hotel";
  check(HotelModel.Valid(state),"a manager standing in furniture is still a loadable save");
  check(blocked.Restore(state)&&!blocked.CanWalk(blocked.ManagerPosition.x,blocked.ManagerPosition.z),"restored manager is inside furniture");
  blocked.Tick(.2f);
  check(blocked.CanWalk(blocked.ManagerPosition.x,blocked.ManagerPosition.z)&&blocked.ManagerPosition.Distance(new LotPoint(solid.x+sw/2,solid.z+sd/2))<4,"manager settles on nearby open floor");

  var other=Fresh(content);other.SetGodMode(true);other.Travel(1);
  check(!other.OrderManagerWalk(new LotPoint(0,0)).success&&!other.OrderManagerChat(0).success,"orders are Meadow only");
 }

 static void RunQueue(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);
  TickUntil(m,()=>m.Actors.Count(a=>a.kind==ActorKind.Guest)>=4,60);
  var guests=m.Actors.Where(a=>a.kind==ActorKind.Guest).Select(a=>a.catId).ToArray();
  check(guests.Length>=4,"four starter guests arrive");
  check(!m.OrderManagerChat(17).success,"absent cats cannot be ordered");
  check(m.OrderManagerChat(guests[0]).success&&m.OrderManagerPet(guests[1]).success&&m.OrderManagerChat(guests[2]).success,"three cat actions queue");
  check(!m.OrderManagerChat(guests[3]).success&&m.ManagerOrders.Count==HotelModel.ManagerQueueLimit,"the queue holds three");
  check(!m.OrderManagerChat(guests[0]).success,"duplicate action refused");
  check(m.CancelManagerOrder(2).success&&m.ManagerOrders.Count==2&&!m.CancelManagerOrder(5).success,"cancel one queued action");
  check(m.OrderManagerWalk(new LotPoint(-1.25f,-1.25f)).success&&m.ManagerOrders.Count==1&&m.ManagerOrders[0].kind==ManagerOrderKind.Walk,"tapping ground replaces the queue");
  check(m.OrderManagerChat(guests[0]).success&&m.ManagerOrders.Count==1&&m.ManagerOrders[0].kind==ManagerOrderKind.Chat,"a cat action replaces a plain walk");
  m.ClearManagerOrders();check(m.ManagerOrders.Count==0,"clear the queue");

  int reached=-1;string how="";m.ManagerReachedCat+=(id,kind)=>{reached=id;how=kind;};
  check(m.OrderManagerPet(guests[1]).success,"pet order");
  TickUntil(m,()=>reached>=0,40);
  var petted=Guest(m,guests[1]);
  check(reached==guests[1]&&how=="pet"&&petted!=null&&m.ManagerPosition.Distance(new LotPoint(petted.x,petted.z,petted.floor))<=1.5f,"manager reaches the cat to pet it");

  check(m.OrderManagerFollow(guests[2]).success,"follow order");
  float closest=99;for(int i=0;i<100;i++){m.Tick(.2f);var g=Guest(m,guests[2]);if(g!=null)closest=Math.Min(closest,m.ManagerPosition.Distance(new LotPoint(g.x,g.z,g.floor)));}
  check(closest<=1.8f&&m.ManagerOrders.Count==1&&m.ManagerOrders[0].kind==ManagerOrderKind.Follow,"follow keeps close and stays on the list ("+closest+")");

  string failure=null;m.ManagerOrderFailed+=msg=>failure=msg;
  m.ClearManagerOrders();check(m.OrderManagerChat(guests[3]).success,"chat order before the cat leaves");
  m.State.cats[guests[3]].known=false;m.Tick(.2f);m.Tick(.2f);
  check(failure!=null&&m.ManagerOrders.Count==0,"order fails when the cat leaves: "+failure);
 }

 // Walks to a chatty guest and opens the chat. Sleeping guests only mumble, so try the next cat.
 static ActorSnapshot OpenChat(HotelModel m,Action<bool,string> check)
 {
  TickUntil(m,()=>m.Actors.Count(a=>a.kind==ActorKind.Guest)>=4,60);
  foreach(var id in m.Actors.Where(a=>a.kind==ActorKind.Guest).Select(a=>a.catId).ToArray())
  {
   if(!m.OrderManagerChat(id).success)continue;
   TickUntil(m,()=>m.CurrentChat!=null||m.ManagerOrders.Count==0,40);
   if(m.CurrentChat==null)continue;
   if(m.CurrentChat.busy){check(m.CurrentChat.topics.Length==0&&m.CurrentChat.exchangesLeft==0,"dozing guests only mumble");m.EndChat();continue;}
   return Guest(m,id);
  }
  return null;
 }

 static void RunChat(Action<bool,string> check,ParityContent content)
 {
  var chatter=ChatterContent.Current;
  var m=Fresh(content);
  var guest=OpenChat(m,check);
  check(guest!=null,"a guest opens a chat");
  var chat=m.CurrentChat;var cat=m.State.cats[guest.catId];
  check(m.ManagerPosition.Distance(new LotPoint(guest.x,guest.z,guest.floor))<=1.5f,"chat opens beside the guest");
  check(chat.topics.Length==3&&chat.topics.Distinct().Count()==3&&chat.topics.All(chatter.HasTopic)&&chat.exchangesLeft==3&&chat.counts,"three topic bubbles offered");
  check(!chat.line.Contains("{manager}")&&chat.line.Length>0,"greeting is voiced");
  var frozen=Guest(m,guest.catId);float frozenRemaining=frozen.remaining;string frozenPhase=frozen.phase;float fx=frozen.x,fz=frozen.z;
  for(int i=0;i<10;i++)m.Tick(.2f);
  var held=Guest(m,guest.catId);
  check(m.CurrentChat!=null&&held.remaining==frozenRemaining&&held.phase==frozenPhase&&held.x==fx&&held.z==fz,"guest pauses for the chat");

  check(!m.Talk("taxes").success&&!m.Talk(chatter.TopicIds.First(t=>!chat.topics.Contains(t))).success,"only offered topics can be picked");
  int bond=cat.bond;string topic=chat.topics[0];string reaction=chatter.Reaction(cat.preference,topic);long serial=chat.serial;
  var said=m.Talk(topic);
  check(said.success&&m.CurrentChat.reaction==reaction&&m.CurrentChat.line==said.message&&m.CurrentChat.serial>serial,"guest answers with its reaction");
  check(chatter.Lines.Any(l=>l.text==said.message&&l.topic==topic&&l.reaction==reaction),"the answer comes from that topic and reaction");
  check(cat.bond==Math.Max(0,Math.Min(100,bond+HotelModel.ReactionBond(reaction)))&&m.CurrentChat.bondDelta==cat.bond-bond,"friendship moves with the reaction");
  check(cat.chatsToday==1&&cat.chatDay==m.Clock.day,"the chat is counted today");
  check(m.CurrentChat.exchangesLeft==2&&!m.CurrentChat.topics.Contains(topic)&&m.CurrentChat.topics.Length==3,"fresh topics without a repeat");
  check(m.Talk(m.CurrentChat.topics[0]).success&&m.Talk(m.CurrentChat.topics[0]).success,"three exchanges");
  check(m.CurrentChat.exchangesLeft==0&&m.CurrentChat.topics.Length==0&&!m.Talk("snacks").success,"only Bye after three exchanges");
  check(cat.chatsToday==1,"one chat counts once");
  check(HotelModel.ReactionBond("love")==4&&HotelModel.ReactionBond("like")==2&&HotelModel.ReactionBond("meh")==1&&HotelModel.ReactionBond("dislike")==-1,"reaction friendship values");
  var bye=m.EndChat();
  check(bye.success&&m.CurrentChat==null&&Guest(m,guest.catId).speech==bye.message&&bye.message.Length>0,"guest signs off in its own bubble");
  for(int i=0;i<25;i++)m.Tick(.2f);
  var resumed=Guest(m,guest.catId);
  check(resumed==null||resumed.remaining!=frozenRemaining||resumed.phase!=frozenPhase||resumed.x!=fx||resumed.z!=fz,"guest resumes after the chat");

  // Daily cap: chats past the third still talk but leave friendship alone, and the count resets the next day.
  var capped=Fresh(content);guest=OpenChat(capped,check);check(guest!=null,"cap setup");
  var capCat=capped.State.cats[guest.catId];capped.EndChat();
  capCat.chatDay=capped.Clock.day;capCat.chatsToday=HotelModel.ManagerChatsPerDay;capCat.bond=50;
  check(capped.BeginChat(guest.catId).success&&!capped.CurrentChat.counts&&chatter.Lines.All(l=>l.text!=capped.CurrentChat.line),"chatted-out greeting");
  check(capped.Talk(capped.CurrentChat.topics[0]).success&&capCat.bond==50&&capCat.chatsToday==HotelModel.ManagerChatsPerDay&&capped.CurrentChat.bondDelta==0,"chatted-out talk leaves friendship alone");
  capped.EndChat();capped.State.elapsed+=HotelClock.DayLengthSeconds;
  check(capped.BeginChat(guest.catId).success&&capped.CurrentChat.counts,"the next day counts again");
  capCat.bond=100;string love=capped.CurrentChat.topics.FirstOrDefault(t=>chatter.Reaction(capCat.preference,t)!="dislike")??capped.CurrentChat.topics[0];
  capped.Talk(love);check(capCat.bond<=100&&capCat.bond>=99,"friendship stays within 100");
  capCat.bond=0;capped.Talk(capped.CurrentChat.topics[0]);check(capCat.bond>=0,"friendship never drops below 0");
  capped.EndChat();

  var timeout=Fresh(content);check(OpenChat(timeout,check)!=null,"timeout setup");
  for(int i=0;i<240&&timeout.CurrentChat!=null;i++)timeout.Tick(.2f);
  check(timeout.CurrentChat==null,"an idle chat times out");

  var walkAway=Fresh(content);check(OpenChat(walkAway,check)!=null,"walk-away setup");
  walkAway.OrderManagerWalk(new LotPoint(9.25f,-9.25f));check(walkAway.CurrentChat==null,"a new order ends the chat");

  var failStore=new MemoryStore();var failing=Fresh(content,failStore);guest=OpenChat(failing,check);check(guest!=null,"rollback setup");
  int before=failing.State.cats[guest.catId].bond;failStore.fail=true;
  check(!failing.Talk(failing.CurrentChat.topics[0]).success&&failing.State.cats[guest.catId].bond==before&&failing.State.cats[guest.catId].chatsToday==0&&failing.CurrentChat.exchangesLeft==3,"failed save rolls the chat back");
  failStore.fail=false;

  // Same moves, same words: two identical runs produce the same greeting and answer.
  string Script(){var run=Fresh(content);var g=OpenChat(run,check);var hello=run.CurrentChat.line;var answer=run.Talk(run.CurrentChat.topics[0]).message;return g.catId+"|"+hello+"|"+answer;}
  check(Script()==Script(),"chats are deterministic");

  // Chatting and walking never touch hotel income.
  var busy=Fresh(content);var quiet=Fresh(content);
  OpenChat(busy,check);quiet.State.elapsed=busy.State.elapsed;quiet.State.coins=busy.State.coins;
  for(int i=0;i<300;i++){if(busy.CurrentChat!=null&&busy.CurrentChat.exchangesLeft>0)busy.Talk(busy.CurrentChat.topics[0]);busy.Tick(.2f);quiet.Tick(.2f);}
  check(Math.Abs(busy.State.coins-quiet.State.coins)<.0001,"income is unaffected by the manager");
 }

 static void RunSaves(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);var guest=OpenChat(m,(ok,msg)=>{});m.Talk(m.CurrentChat.topics[0]);m.EndChat();
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(HotelModel.Valid(round)&&round.cats[guest.catId].chatsToday==1&&round.cats[guest.catId].chatDay==m.Clock.day,"chat counters survive a save");
  var bad=HotelModel.Copy(m.State);bad.cats[0].chatsToday=HotelModel.ManagerChatsPerDay+1;check(!HotelModel.Valid(bad),"reject too many chats");
  bad=HotelModel.Copy(m.State);bad.cats[0].chatsToday=-1;check(!HotelModel.Valid(bad),"reject negative chats");
  bad=HotelModel.Copy(m.State);bad.cats[0].chatDay=-1;check(!HotelModel.Valid(bad),"reject negative chat day");
  bad=HotelModel.Copy(m.State);bad.hotels[0].town.phase="hotel";bad.hotels[0].town.floor=5;check(!HotelModel.Valid(bad),"reject a floor that was never built");
  bad=HotelModel.Copy(m.State);bad.hotels[0].town.phase="street";bad.hotels[0].town.x=0;bad.hotels[0].town.z=12.75f;bad.hotels[0].town.floor=1;bad.hotels[0].town.shop="";check(!HotelModel.Valid(bad),"reject a street manager on an upper floor");
  var json=JObject.FromObject(m.State);json["cats"][0]["chatsToday"]="lots";check(!m.RestoreJson(json.ToString()),"strict save rejects text chat counts");
  json=JObject.FromObject(m.State);((JObject)json["cats"][0]).Remove("chatDay");((JObject)json["cats"][0]).Remove("chatsToday");((JObject)json["hotels"][0]["town"]).Remove("floor");
  check(m.RestoreJson(json.ToString()),"saves without the new fields still load");
 }

 static void RunFloors(Action<bool,string> check,Func<string,JObject> P,ParityContent content)
 {
  var m=Fresh(content);m.State.coins=100000;
  var h=m.Hotel();h.rooms.Clear();h.floors.Clear();h.objects.Clear();h.paths.Clear();h.level=3;
  var arr=m.Map()["arrival"];int x=(int)Math.Floor((float)arr[0])-7,z=(int)Math.Floor((float)arr[1])-6;
  check(m.Execute("paint_floor",ShellSuites.Paint(x,z,8,7)).success,"manager floors: lobby");
  check(m.Execute("draw_room",ShellSuites.RoomOn(0,x+1,z+1,2,3,0,"stairs")).success,"manager floors: stairs");
  // A front door on the lobby's west wall, beside the hotel's street exit.
  var exitCell=(int)Math.Floor((float)m.Map()["base"][1]+(float)m.Map()["base"][3]-.25f);
  check(m.Execute("set_edge",new JObject{{"floor",0},{"kind","door"},{"edges",new JArray("v:"+x+","+exitCell)}}).success,"manager floors: lobby front door");
  check(m.Execute("paint_floor",ShellSuites.PaintOn(1,x+3,z,5,6)).success,"manager floors: upstairs hall");
  var upstairs=new LotPoint(x+5.25f,z+2.25f,1);
  var order=m.OrderManagerWalk(upstairs);check(order.success,"walk upstairs: "+order.message);
  bool changedInStairs=true;var last=m.ManagerPosition;
  for(int i=0;i<300&&m.ManagerOrders.Count>0;i++)
  {
   m.Tick(.2f);var now=m.ManagerPosition;
   if(now.floor!=last.floor)changedInStairs&=now.x>=x+1&&now.x<x+3&&now.z>=z+1&&now.z<z+4;
   last=now;
  }
  check(m.ManagerPosition.floor==1&&m.Hotel().town.floor==1&&m.ManagerPosition.Distance(upstairs)<.8f,"manager climbs to the upper floor");
  check(changedInStairs,"manager changes floor inside the stairwell");
  check(m.MovementSegmentClear(m.ManagerPosition,m.ManagerPosition,false),"manager stands on the upper floor's open cells");
  var reload=new HotelModel(new MemoryStore{state=HotelModel.Copy(m.State)},content);
  check(reload.LoadOrCreate().success&&reload.ManagerPosition.floor==1,"upstairs manager survives a reload");
  var trip=m.OrderManagerStreet("square");check(trip.success,"street trip from upstairs: "+trip.message);
  TickUntil(m,()=>m.Hotel().town.destination=="",90);
  check(!m.ManagerInHotel&&m.Hotel().town.floor==0&&m.ManagerPosition.Distance(TownContent.Current.Point("square"))<.01f,"manager comes downstairs and out to the square");
  check(m.OrderManagerWalk(upstairs).success,"street to upstairs");
  TickUntil(m,()=>m.ManagerOrders.Count==0,90);
  check(m.ManagerPosition.floor==1&&m.ManagerPosition.Distance(upstairs)<.8f,"manager walks from the square back upstairs");
 }
}
