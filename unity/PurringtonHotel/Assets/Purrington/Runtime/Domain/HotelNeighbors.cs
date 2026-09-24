using System;
using System.Collections.Generic;
using System.Linq;

namespace Purrington.Domain
{
 [Serializable] public sealed class NeighborState
 {
  public string id;
  public int friendship,chatDay,chatsToday,giftDay,tier;
  public List<string> learned=new List<string>();
  // An open favor: "fetch:<gift id>" or "build:<request id>", with the placed count when it was asked for.
  public string request="";
  public int requestBase,requestDay,requestsDone;
 }
 // Where a neighbor is right now. Positions come from the game clock and the neighbor's schedule, so they are never saved.
 public sealed class NeighborView
 {
  public string id,name,place;
  public LotPoint position;
  public bool present,walking;
  public float facing;
  public int friendship,tier;
 }
 // Meadow neighbors: routines along Main Street, friendship tiers with rewards, and gifts from Paw Mart.
 public sealed partial class HotelModel
 {
  public const int NeighborChatsPerDay=3;
  const float NeighborSpeed=1.1f,NeighborReach=1.8f;
  public static readonly int[] TierFriendship={0,15,40,75};
  public static readonly string[] TierNames={"Stranger","Acquaintance","Friend","Best Friend"};
  public static int TierFor(int friendship){int tier=0;for(int i=1;i<TierFriendship.Length;i++)if(friendship>=TierFriendship[i])tier=i;return tier;}
  public static int NeighborReactionFriendship(string reaction)=>reaction=="love"?5:reaction=="like"?3:reaction=="dislike"?-2:1;
  public const int FavoriteGiftFriendship=10,GiftFriendship=3;
  readonly Dictionary<string,float> neighborDelay=new Dictionary<string,float>(StringComparer.Ordinal);
  readonly Dictionary<string,List<LotPoint>> neighborRoutes=new Dictionary<string,List<LotPoint>>(StringComparer.Ordinal);
  int neighborDelayDay=-1;

  // Read-only: a neighbor the player has never spoken to has a default record that is not stored until something changes.
  public NeighborState NeighborData(string id)=>Hotel(0).neighbors.Find(n=>n.id==id)??new NeighborState{id=id};
  NeighborState NeighborRecord(string id){var list=Hotel(0).neighbors;var record=list.Find(n=>n.id==id);if(record==null){record=new NeighborState{id=id};list.Add(record);}return record;}
  public int GiftCount(string id)=>id!=null&&State.gifts.TryGetValue(id,out int n)?n:0;

  public IReadOnlyList<NeighborView> NeighborViews
  {
   get
   {
    var content=NeighborContent.Current;
    if(content==null||State.currentHotel!=0||TownContent.Current==null)return Array.Empty<NeighborView>();
    return content.Neighbors.Select(NeighborNow).ToArray();
   }
  }
  public NeighborView Neighbor(string id){var n=NeighborContent.Current?.Find(id);return n==null||State.currentHotel!=0||TownContent.Current==null?null:NeighborNow(n);}

  NeighborView NeighborNow(NeighborContent.Neighbor n)
  {
   if(Attending(n.id))return PlazaView(n);
   var clock=Clock;var town=TownContent.Current;
   if(neighborDelayDay!=clock.day){neighborDelay.Clear();neighborDelayDay=clock.day;}
   float minute=clock.minute-(neighborDelay.TryGetValue(n.id,out float delay)?delay:0);
   int count=n.schedule.Length,slot=-1;
   for(int i=0;i<count;i++)if(n.schedule[i].minute<=minute)slot=i;
   float start;
   if(slot<0){slot=count-1;start=n.schedule[slot].minute-HotelClock.DayLengthSeconds;}else start=n.schedule[slot].minute;
   string from=n.schedule[(slot-1+count)%count].place,to=n.schedule[slot].place;
   var state=NeighborData(n.id);
   var view=new NeighborView{id=n.id,name=n.name,place=to,friendship=state.friendship,tier=TierFor(state.friendship)};
   var route=NeighborRoute(from,to);
   float along=(minute-start)*NeighborSpeed;
   view.position=town.Point(to);view.present=to!=n.home;
   for(int i=1;i<route.Count;i++)
   {
    var a=route[i-1];var b=route[i];float gap=a.Distance(b);
    if(gap<.0001f)continue;
    float dx=b.x-a.x,dz=b.z-a.z;view.facing=(float)Math.Atan2(dx,dz);
    if(along<gap){float k=along/gap;view.position=new LotPoint(a.x+dx*k,a.z+dz*k);view.walking=true;view.present=true;break;}
    along-=gap;
   }
   return view;
  }
  List<LotPoint> NeighborRoute(string from,string to)
  {
   string key=from+"|"+to;
   if(neighborRoutes.TryGetValue(key,out var route))return route;
   var town=TownContent.Current;
   route=from==to?new List<LotPoint>{town.Point(to)}:TownRoute.Find(town,town.Point(from),to);
   if(route.Count==0)route=new List<LotPoint>{town.Point(to)};
   neighborRoutes[key]=route;
   return route;
  }
  bool ManagerMeets(NeighborView v,float reach)=>v!=null&&v.present&&!ManagerInHotel&&Hotel(0).town.shop.Length==0&&ManagerPosition.Distance(v.position)<=reach;

  public CommandResult OrderManagerNeighbor(string id)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   var v=Neighbor(id);
   if(v==null)return CommandResult.Fail("Choose a neighbor.");
   if(!v.present)return CommandResult.Fail(v.name+" is at home right now.");
   managerOrders.RemoveAll(o=>o.kind==ManagerOrderKind.Walk||o.kind==ManagerOrderKind.Follow);
   if(managerOrders.Any(o=>o.kind==ManagerOrderKind.ChatNeighbor&&o.neighbor==id))return CommandResult.Fail("Already on the list.");
   if(managerOrders.Count>=ManagerQueueLimit)return CommandResult.Fail("The to-do list is full.");
   var stop=StopStreetTrip();if(!stop.success)return stop;
   EndChatNow();
   managerOrders.Add(new ManagerOrder{kind=ManagerOrderKind.ChatNeighbor,neighbor=id});
   if(managerOrders.Count==1)ResetManagerPath();
   return CommandResult.Ok("Off to see "+v.name+".");
  }

  // Walks to the Main Street node the neighbor is at or heading for; the chat starts as soon as they are within reach.
  void AdvanceNeighborOrder(ManagerOrder order,float seconds)
  {
   var v=Neighbor(order.neighbor);
   if(v==null||!v.present){FailManagerOrder((v?.name??"They")+" went home.");return;}
   if(ManagerMeets(v,NeighborReach))
   {
    managerOrders.RemoveAt(0);ResetManagerPath();PersistManager();
    BeginNeighborChat(order.neighbor);
    return;
   }
   if(order.elapsed>CatchUpSeconds*2){FailManagerOrder("Couldn't catch up with "+v.name+".");return;}
   managerReplan-=seconds;
   if(!managerPathActive||managerPathRevision!=Revision||managerReplan<=0&&managerPathNode!=v.place)
   {
    var plan=PlanManagerToStreet(v.place);managerReplan=.5f;
    if(plan.Count==0){FailManagerOrder("Can't get there from here.");return;}
    managerPath.Clear();managerPathStreet.Clear();
    foreach(var p in plan){managerPath.Add(p.point);managerPathStreet.Add(p.street);}
    managerStep=1;managerPathActive=true;managerPathRevision=Revision;managerPathNode=v.place;
   }
   StepManager(seconds);
   if(managerStep>=managerPath.Count)managerPathActive=false;
  }
  string managerPathNode;
  List<(LotPoint point,bool street)> PlanManagerToStreet(string node)
  {
   var none=new List<(LotPoint,bool)>();var result=new List<(LotPoint point,bool street)>();
   var t=Hotel(0).town;var town=TownContent.Current;
   if(!town.IsStreetTarget(node))return none;
   if(t.phase=="street")
   {
    var street=TownRoute.Find(town,new LotPoint(t.x,t.z),node);
    foreach(var p in street)result.Add((p,true));
    return result;
   }
   var exit=ManagerExit();var here=ManagerPosition;
   var hotel=ActivityRoute(here,exit);var outside=TownRoute.Find(town,town.Point("hotel_gate"),node);
   if(hotel.Count==0||outside.Count==0)return none;
   result.Add((here,false));
   foreach(var p in hotel)if(p.Distance(result[result.Count-1].point)>.0001f)result.Add((p,false));
   if(result[result.Count-1].point.Distance(exit)>.0001f)result.Add((exit,false));
   foreach(var p in outside)result.Add((p,true));
   return result;
  }

  public CommandResult BeginNeighborChat(string id)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   var n=NeighborContent.Current?.Find(id);var chatter=ChatterContent.Current;
   if(n==null||chatter==null)return CommandResult.Fail("Choose a neighbor.");
   var v=Neighbor(id);
   if(!v.present)return CommandResult.Fail(n.name+" is at home right now.");
   if(!ManagerMeets(v,NeighborReach+.3f))return CommandResult.Fail("Walk over to "+n.name+" first.");
   EndChatNow();
   string rumor=PostNeighborExtras(n);
   var state=NeighborData(id);int day=Clock.day,used=state.chatDay==day?state.chatsToday:0;bool counts=used<NeighborChatsPerDay;
   uint hash=StableHash(day+":"+id+":"+used+":"+chatSerial);
   chat=new ChatOffer{catId=-1,neighbor=id,name=n.name,counts=counts,bond=state.friendship,exchangesLeft=ChatExchanges};
   var plaza=Attending(id)?PlazaContent.Current?.Find(PlazaEventId):null;
   chat.line=rumor??(plaza!=null?Voice(Pick(plaza.greeting,hash)):Voice(Pick(counts?n.greeting:n.chattedOut,hash)));chat.rumor=rumor!=null;
   lastTopic=null;chatClock=0;
   chat.topics=OfferTopics(chatter,-2-(int)(StableHash(id)%100000));
   RefreshChatRequest();
   chat.serial=++chatSerial;
   Changed?.Invoke();
   return CommandResult.Ok(chat.line);
  }
  static string Pick(string[] lines,uint hash)=>lines==null||lines.Length==0?"...":lines[hash%(uint)lines.Length];

  CommandResult TalkNeighbor(string topic)
  {
   var n=NeighborContent.Current.Find(chat.neighbor);var v=Neighbor(chat.neighbor);
   if(n==null||v==null||!v.present){EndChatNow();return CommandResult.Fail("They headed home.");}
   string reaction=n.Reaction(topic);
   var existing=NeighborData(n.id);
   int day=Clock.day,used=existing.chatDay==day?existing.chatsToday:0,exchange=ChatExchanges-chat.exchangesLeft;
   bool first=exchange==0,counts=chat.counts;
   string line=Voice(Pick(n.topics.TryGetValue(topic,out var lines)?lines:null,StableHash(day+":"+n.id+":"+topic+":"+used+":"+exchange)));
   int before=existing.friendship;string tierLine="",reward="";int after=before;
   var r=Transaction(()=>{
    var state=NeighborRecord(n.id);
    if(counts&&first){state.chatDay=day;state.chatsToday=used+1;}
    if(!state.learned.Contains(topic))state.learned.Add(topic);
    if(counts)state.friendship=Math.Max(0,Math.Min(100,state.friendship+NeighborReactionFriendship(reaction)));
    if(Attending(n.id))AddBuzz(ChatBuzz(reaction));
    (tierLine,reward)=ClaimNeighborTiers(state,n);
    after=state.friendship;
   },line);
   if(!r.success)return r;
   chat.exchangesLeft--;chat.line=line;chat.reaction=reaction;chat.bond=after;chat.bondDelta=after-before;chat.tierUp=tierLine;chat.reward=reward;
   lastTopic=topic;chatClock=0;
   chat.topics=chat.exchangesLeft>0?OfferTopics(ChatterContent.Current,-2-(int)(StableHash(n.id)%100000)):Array.Empty<string>();
   chat.rumor=false;RefreshChatRequest();
   chat.serial=++chatSerial;
   r.progressChanged=chat.bondDelta!=0||tierLine.Length>0;
   return r;
  }

  public CommandResult BuyGift(string id)
  {
   var gift=NeighborContent.Current?.FindGift(id);
   if(gift==null)return CommandResult.Fail("Choose a gift.");
   if(GiftCount(id)>=99)return CommandResult.Fail("Your gift basket is full of those.");
   double price=State.settings.godMode?0:gift.price;
   if(State.coins<price)return CommandResult.Fail("Need "+Math.Ceiling(price-State.coins)+" more Cat Coins.");
   var r=Transaction(()=>{State.coins-=price;State.gifts[id]=GiftCount(id)+1;},gift.name+" added to your gift basket");
   r.cost=r.success?price:0;
   return r;
  }
  // Gifts are given during a chat. One gift per neighbor per game day counts; a favorite counts far more.
  public CommandResult GiveGift(string id)
  {
   if(chat==null||chat.neighbor==null)return CommandResult.Fail("Chat with a neighbor to give a gift.");
   var n=NeighborContent.Current.Find(chat.neighbor);var gift=NeighborContent.Current.FindGift(id);
   if(gift==null)return CommandResult.Fail("Choose a gift.");
   if(GiftCount(id)<=0)return CommandResult.Fail("You don't have a "+gift.name.ToLowerInvariant()+". Paw Mart sells them.");
   int day=Clock.day;var existing=NeighborData(n.id);
   if(existing.giftDay==day)return CommandResult.Fail(n.name+" already got a present today.");
   bool favorite=n.favoriteGift==id;
   string line=Voice(Pick(favorite?n.giftLove:n.giftOk,StableHash(day+":"+n.id+":"+id)));
   int before=existing.friendship,after=before;string tierLine="",reward="";
   var r=Transaction(()=>{
    int left=GiftCount(id)-1;if(left>0)State.gifts[id]=left;else State.gifts.Remove(id);
    var state=NeighborRecord(n.id);state.giftDay=day;
    state.friendship=Math.Min(100,state.friendship+(favorite?FavoriteGiftFriendship:GiftFriendship));
    if(Attending(n.id))AddBuzz(GiftBuzz);
    (tierLine,reward)=ClaimNeighborTiers(state,n);
    after=state.friendship;
   },line);
   if(!r.success)return r;
   chat.line=line;chat.reaction=favorite?"love":"like";chat.bond=after;chat.bondDelta=after-before;chat.tierUp=tierLine;chat.reward=reward;chat.gifted=true;chatClock=0;chat.rumor=false;RefreshChatRequest();
   chat.serial=++chatSerial;
   r.progressChanged=true;
   return r;
  }

  // Each tier pays out once, in the same transaction that crossed it.
  (string line,string reward) ClaimNeighborTiers(NeighborState state,NeighborContent.Neighbor n)
  {
   string line="",reward="";
   while(state.tier<TierFor(state.friendship)&&state.tier<3)
   {
    state.tier++;line=n.tierUp[state.tier-1];
    if(state.tier==1)
    {
     var cat=n.introduces>=0&&n.introduces<State.cats.Count?State.cats[n.introduces]:null;
     if(cat!=null&&!cat.known){cat.known=true;reward=cat.name+" heard about the hotel from "+n.name+"!";}
     else{State.coins+=60;reward=n.name+" sent 60 Cat Coins of business your way.";}
    }
    else if(state.tier==2)
    {
     var item=Catalog.Find(n.friendGift);
     if(item!=null){State.storage.Add(new ObjectState{id=Id("object"),itemId=item.id,paid=0});reward=n.name+" gave you a "+item.name.ToLowerInvariant()+". It's in storage.";}
    }
    else
    {
     var wear=Wardrobe.Find(n.bestGift);
     reward=wear!=null?n.name+" gave you the "+wear.name.ToLowerInvariant()+"! Find it in the wardrobe.":n.name+" is your best friend!";
    }
   }
   return (Voice(line),reward);
  }

  public int NeighborTierClaimed(string id)=>NeighborData(id).tier;

  internal bool ValidNeighbors(HotelData h,int index)
  {
   if(h.neighbors==null)return false;
   if(index!=0)return h.neighbors.Count==0;
   var content=NeighborContent.Current;var chatter=ChatterContent.Current;
   if(h.neighbors.Select(n=>n?.id).Distinct().Count()!=h.neighbors.Count)return false;
   foreach(var n in h.neighbors)
   {
    if(n==null||n.id==null||n.learned==null)return false;
    if(content!=null&&content.Find(n.id)==null)return false;
    if(n.friendship<0||n.friendship>100||n.chatDay<0||n.chatsToday<0||n.chatsToday>NeighborChatsPerDay||n.giftDay<0||n.tier<0||n.tier>3)return false;
    if(n.learned.Distinct().Count()!=n.learned.Count||chatter!=null&&n.learned.Any(t=>!chatter.HasTopic(t)))return false;
   }
   return true;
  }
  static bool ValidGifts(HotelState s)
  {
   if(s.gifts==null)return false;
   var content=NeighborContent.Current;
   foreach(var g in s.gifts)if(g.Key==null||g.Value<1||g.Value>99||content!=null&&content.FindGift(g.Key)==null)return false;
   return true;
  }
 }
}
