using System;
using System.Linq;

namespace Purrington.Domain
{
 // Neighbor requests (fetch a gift, build something) and rumors that send the manager to the Meadow outskirts.
 public sealed partial class HotelModel
 {
  public const int FetchCoins=50,BuildCoins=120,RequestFriendship=8,LostItemCoins=80,KnownKittenCoins=100;
  public event Action<string> ManagerFound;
  public string RumorSpot=>State.currentHotel==0?Hotel(0).town.rumorSpot:"";

  int CountPlaced(string[] items)=>Hotel(0).objects.Count(o=>items.Contains(o.itemId));

  public string RequestText(NeighborState state)
  {
   var quests=QuestContent.Current;var neighbors=NeighborContent.Current;
   if(quests==null||neighbors==null||string.IsNullOrEmpty(state.request))return "";
   if(state.request.StartsWith("fetch:"))
   {
    var gift=neighbors.FindGift(state.request.Substring(6));
    return Voice(quests.Fetch[StableHash(state.id+":"+state.requestDay)%(uint)quests.Fetch.Length].Replace("{gift}",gift?.name.ToLowerInvariant()??"present"));
   }
   return Voice(quests.FindBuild(state.request.Substring(6))?.text??"");
  }
  public bool RequestReady(NeighborState state)
  {
   if(string.IsNullOrEmpty(state.request))return false;
   if(state.request.StartsWith("fetch:"))return GiftCount(state.request.Substring(6))>0;
   var build=QuestContent.Current?.FindBuild(state.request.Substring(6));
   return build!=null&&CountPlaced(build.items)>=state.requestBase+build.count;
  }
  public string RequestProgress(NeighborState state)
  {
   if(string.IsNullOrEmpty(state.request))return "";
   if(state.request.StartsWith("fetch:"))return RequestReady(state)?"You have it":"Buy one at Paw Mart";
   var build=QuestContent.Current?.FindBuild(state.request.Substring(6));
   return build==null?"":Math.Min(build.count,Math.Max(0,CountPlaced(build.items)-state.requestBase))+" / "+build.count+" built";
  }

  // The first chat of the day with an Acquaintance or closer may bring a new request, and a rumor if none is going around.
  // Returns the rumor line when this neighbor passes one on.
  string PostNeighborExtras(NeighborContent.Neighbor n)
  {
   var quests=QuestContent.Current;var neighbors=NeighborContent.Current;
   if(quests==null||State.currentHotel!=0)return null;
   var existing=NeighborData(n.id);int day=Clock.day;
   if(existing.tier<1)return null;
   bool request=string.IsNullOrEmpty(existing.request)&&existing.requestDay!=day;
   var town=Hotel(0).town;bool rumor=town.rumorSpot.Length==0&&town.rumorDay!=day;
   if(!request&&!rumor)return null;
   string line=null;
   var r=Transaction(()=>{
    var state=NeighborRecord(n.id);
    if(request)
    {
     uint hash=StableHash(day+":"+n.id+":request");state.requestDay=day;
     if(hash%2==0)
     {
      var gifts=neighbors.Gifts.Where(g=>g.id!=n.favoriteGift).ToArray();
      state.request="fetch:"+gifts[(hash/2)%(uint)gifts.Length].id;state.requestBase=0;
     }
     else
     {
      var build=quests.Builds[(hash/2)%(uint)quests.Builds.Length];
      state.request="build:"+build.id;state.requestBase=CountPlaced(build.items);
     }
    }
    if(rumor)
    {
     var pick=quests.Rumors[StableHash(day+":rumor:"+n.id)%(uint)quests.Rumors.Length];
     town.rumorSpot=pick.spot;town.rumorFind=pick.find;town.rumorGiver=n.id;town.rumorDay=day;
     line=Voice(pick.text);
    }
   },"");
   return r.success?line:null;
  }

  // In a neighbor chat: repeat the request, or complete it when it's ready.
  public CommandResult AnswerRequest()
  {
   if(chat==null||chat.neighbor==null)return CommandResult.Fail("Chat with a neighbor first.");
   var n=NeighborContent.Current.Find(chat.neighbor);var existing=NeighborData(n.id);
   if(string.IsNullOrEmpty(existing.request))return CommandResult.Fail(n.name+" doesn't need anything today.");
   if(!RequestReady(existing))
   {
    chat.line=Voice(QuestContent.Current.Reminder.Replace("{request}",RequestText(existing)));chat.reaction="";chat.tierUp="";chat.reward="";chat.rumor=false;chat.serial=++chatSerial;chatClock=0;
    return CommandResult.Ok(chat.line);
   }
   bool fetch=existing.request.StartsWith("fetch:");int coins=fetch?FetchCoins:BuildCoins;
   string line=Voice(QuestContent.Current.Thanks[StableHash(n.id+":"+existing.requestsDone)%(uint)QuestContent.Current.Thanks.Length]);
   int before=existing.friendship,after=before;string tierLine="",reward="";
   var r=Transaction(()=>{
    var state=NeighborRecord(n.id);
    if(fetch){string gift=state.request.Substring(6);int left=GiftCount(gift)-1;if(left>0)State.gifts[gift]=left;else State.gifts.Remove(gift);}
    State.coins+=coins;state.friendship=Math.Min(100,state.friendship+RequestFriendship);
    state.request="";state.requestBase=0;state.requestsDone++;
    (tierLine,reward)=ClaimNeighborTiers(state,n);
    after=state.friendship;
   },line);
   if(!r.success)return r;
   chat.line=line;chat.reaction="love";chat.bond=after;chat.bondDelta=after-before;chat.tierUp=tierLine;
   chat.reward="+"+coins+" Cat Coins"+(reward.Length>0?" · "+reward:"");chat.requestDone=true;chat.rumor=false;RefreshChatRequest();chat.serial=++chatSerial;chatClock=0;
   r.progressChanged=true;
   return r;
  }

  void RefreshChatRequest()
  {
   if(chat?.neighbor==null)return;
   var state=NeighborData(chat.neighbor);
   chat.request=RequestText(state);chat.requestReady=RequestReady(state);
  }
  public CommandResult OrderManagerSearch()
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   string spot=RumorSpot;
   if(string.IsNullOrEmpty(spot))return CommandResult.Fail("No rumors going around right now.");
   managerOrders.RemoveAll(o=>o.kind==ManagerOrderKind.Walk||o.kind==ManagerOrderKind.Follow||o.kind==ManagerOrderKind.Search);
   if(managerOrders.Count>=ManagerQueueLimit)return CommandResult.Fail("The to-do list is full.");
   var stop=StopStreetTrip();if(!stop.success)return stop;
   EndChatNow();
   managerOrders.Add(new ManagerOrder{kind=ManagerOrderKind.Search,neighbor=spot});
   if(managerOrders.Count==1)ResetManagerPath();
   return CommandResult.Ok("Off to the "+QuestContent.Current.FindSpot(spot).name+".");
  }
  void AdvanceSearchOrder(ManagerOrder order,float seconds)
  {
   string spot=order.neighbor;
   if(RumorSpot!=spot){FailManagerOrder("That rumor has gone cold.");return;}
   var point=TownContent.Current.Point(spot);
   if(!ManagerInHotel&&Hotel(0).town.shop.Length==0&&ManagerPosition.Distance(point)<.05f)
   {
    managerOrders.RemoveAt(0);ResetManagerPath();
    var found=FindRumor();
    if(found.success)ManagerFound?.Invoke(found.message);else ManagerOrderFailed?.Invoke(found.message);
    return;
   }
   if(!managerPathActive||managerPathRevision!=Revision)
   {
    var plan=PlanManagerToStreet(spot);
    if(plan.Count==0){FailManagerOrder("Can't get there from here.");return;}
    managerPath.Clear();managerPathStreet.Clear();
    foreach(var p in plan){managerPath.Add(p.point);managerPathStreet.Add(p.street);}
    managerStep=1;managerPathActive=true;managerPathRevision=Revision;
   }
   StepManager(seconds);
   if(managerStep>=managerPath.Count)managerPathActive=false;
  }
  // Claims the active rumor's find. The manager has to be standing at the spot.
  public CommandResult FindRumor()
  {
   var quests=QuestContent.Current;var town=Hotel(0).town;
   if(quests==null||town.rumorSpot.Length==0)return CommandResult.Fail("No rumors going around right now.");
   if(ManagerInHotel||ManagerPosition.Distance(TownContent.Current.Point(town.rumorSpot))>.5f)return CommandResult.Fail("Walk out to the "+quests.FindSpot(town.rumorSpot).name+" first.");
   string find=town.rumorFind,message="";uint hash=StableHash(town.rumorDay+":"+town.rumorSpot+":"+town.rumorsFound);
   return Transaction(()=>{
    if(find=="kitten")
    {
     var strays=State.cats.Where(c=>!c.known&&c.id<12).ToArray();
     if(strays.Length>0){var cat=strays[hash%(uint)strays.Length];cat.known=true;message=quests.Found("kitten").Replace("{cat}",cat.name);}
     else{State.coins+=KnownKittenCoins;message=quests.Found("kittenKnown");}
    }
    else if(find=="lost_item"){State.coins+=LostItemCoins;message=quests.Found("lost_item");}
    else
    {
     var item=Catalog.Find(quests.Treasures[hash%(uint)quests.Treasures.Length]);
     State.storage.Add(new ObjectState{id=Id("object"),itemId=item.id,paid=0});
     message=quests.Found("treasure").Replace("{item}",item.name.ToLowerInvariant());
    }
    town.rumorSpot="";town.rumorFind="";town.rumorGiver="";town.rumorsFound++;
   },"").WithMessage(()=>message);
  }

  internal bool ValidQuests(HotelData h,int index)
  {
   var t=h.town;var quests=QuestContent.Current;
   if(t.rumorSpot==null||t.rumorFind==null||t.rumorGiver==null||t.rumorDay<0||t.rumorsFound<0)return false;
   if(index!=0&&(t.rumorSpot.Length>0||t.rumorsFound>0||t.rumorDay>0))return false;
   if(t.rumorSpot.Length==0){if(t.rumorFind.Length>0||t.rumorGiver.Length>0)return false;}
   else if(quests!=null&&(quests.FindSpot(t.rumorSpot)==null||!QuestContent.Finds.Contains(t.rumorFind)||NeighborContent.Current?.Find(t.rumorGiver)==null))return false;
   foreach(var n in h.neighbors)
   {
    if(n.request==null||n.requestBase<0||n.requestBase>10000||n.requestDay<0||n.requestsDone<0)return false;
    if(n.request.Length==0)continue;
    if(n.request.StartsWith("fetch:")){if(NeighborContent.Current!=null&&NeighborContent.Current.FindGift(n.request.Substring(6))==null)return false;}
    else if(n.request.StartsWith("build:")){if(quests!=null&&quests.FindBuild(n.request.Substring(6))==null)return false;}
    else return false;
   }
   return true;
  }
 }
 static class CommandResultExtensions
 {
  // Transactions report the message known before they run; this swaps in one computed inside the transaction.
  public static CommandResult WithMessage(this CommandResult r,Func<string> message){if(r.success)r.message=message();return r;}
 }
}
