using System;
using System.Collections.Generic;
using System.Linq;

namespace Purrington.Domain
{
 // Plaza events: host one a day, neighbors who like the theme (or you) come to the square, and chatting fills the Buzz meter.
 public sealed partial class HotelModel
 {
  public const float PlazaRing=1.4f;
  public const int BronzeCoins=80,SilverCoins=180,GoldCoins=320,SilverFriendship=3,GoldFriendship=6,SilverBuzz=40,GoldBuzz=80,GiftBuzz=15;
  public static int ChatBuzz(string reaction)=>reaction=="love"?20:reaction=="like"?15:reaction=="meh"?8:0;
  public event Action<string> PlazaEventEnded;
  float plazaTick,plazaCheckpoint;

  public string PlazaEventId=>State.currentHotel==0?Hotel(0).town.plazaEvent:"";
  public bool PlazaEventActive=>PlazaEventId.Length>0;
  public float PlazaRemaining=>Hotel(0).town.plazaRemaining;
  public int PlazaBuzz=>Hotel(0).town.plazaBuzz;
  public IReadOnlyList<string> PlazaAttendees=>Hotel(0).town.plazaAttendees.AsReadOnly();
  bool Attending(string neighbor)=>PlazaEventActive&&Hotel(0).town.plazaAttendees.Contains(neighbor);
  public static string BuzzTier(int buzz)=>buzz>=GoldBuzz?"gold":buzz>=SilverBuzz?"silver":"bronze";

  // Who would come if the event started now: neighbors who are out, and either like the theme or are close friends.
  public string[] PredictAttendees(string eventId)
  {
   var e=PlazaContent.Current?.Find(eventId);var neighbors=NeighborContent.Current;
   if(e==null||neighbors==null||State.currentHotel!=0)return Array.Empty<string>();
   return neighbors.Neighbors.Where(n=>{
    var v=NeighborNow(n);if(!v.present)return false;
    int tier=NeighborData(n.id).tier;string reaction=n.Reaction(e.topic);
    if(reaction=="dislike")return tier>=3;
    return reaction=="love"||reaction=="like"||tier>=2;
   }).Select(n=>n.id).ToArray();
  }
  public CommandResult CanHost(string eventId)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   var e=PlazaContent.Current?.Find(eventId);
   if(e==null)return CommandResult.Fail("Choose an event.");
   if(PlazaEventActive)return CommandResult.Fail(PlazaContent.Current.Find(PlazaEventId)?.name+" is already on.");
   if(MarketDayRemaining>0)return CommandResult.Fail("Market Day is using the square.");
   if(Hotel(0).town.plazaDay==Clock.day)return CommandResult.Fail("The square needs a rest. One event a day.");
   if(!e.OpenAt(Clock.minute))return CommandResult.Fail(e.name+" runs from "+Hours(e.from)+" to "+Hours(e.to)+".");
   double price=State.settings.godMode?0:e.price;
   if(State.coins<price)return CommandResult.Fail("Need "+Math.Ceiling(price-State.coins)+" more Cat Coins.",price);
   return CommandResult.Ok("Host "+e.name+" · "+price+" Cat Coins",price);
  }
  static string Hours(float minute){int m=(int)minute%1440;return (m/60).ToString("00")+":"+(m%60).ToString("00");}
  public CommandResult HostEvent(string eventId)
  {
   var check=CanHost(eventId);if(!check.success)return check;
   var e=PlazaContent.Current.Find(eventId);var attendees=PredictAttendees(eventId);double price=check.cost;int day=Clock.day;
   EndChatNow();
   var r=Transaction(()=>{
    var town=Hotel(0).town;State.coins-=price;
    town.plazaEvent=e.id;town.plazaRemaining=e.duration;town.plazaBuzz=0;town.plazaDay=day;town.plazaResult="";
    town.plazaAttendees=attendees.ToList();
   },e.name+" has begun! "+(attendees.Length==0?"Nobody's here yet... chat up the square.":attendees.Length+" neighbor"+(attendees.Length==1?"":"s")+" came."));
   r.cost=r.success?price:0;plazaTick=0;
   return r;
  }
  void AddBuzz(int amount){var town=Hotel(0).town;town.plazaBuzz=Math.Max(0,Math.Min(100,town.plazaBuzz+amount));}

  void AdvancePlaza(float seconds)
  {
   if(State.currentHotel!=0||!PlazaEventActive)return;
   var town=Hotel(0).town;
   town.plazaRemaining=Math.Max(0,town.plazaRemaining-seconds);
   plazaTick+=seconds;
   while(plazaTick>=4){plazaTick-=4;AddBuzz(town.plazaAttendees.Count);}
   if(town.plazaRemaining<=0){FinishPlaza();return;}
   plazaCheckpoint+=seconds;
   if(plazaCheckpoint>=1){plazaCheckpoint=0;TrySave();}
  }
  // Pays out once, in one transaction; a failed save leaves the event finishing and retries next tick.
  void FinishPlaza()
  {
   var e=PlazaContent.Current?.Find(PlazaEventId);var town=Hotel(0).town;
   string tier=BuzzTier(town.plazaBuzz);string summary="";
   var r=Transaction(()=>{
    int coins=tier=="gold"?GoldCoins:tier=="silver"?SilverCoins:BronzeCoins;
    int friendship=tier=="gold"?GoldFriendship:tier=="silver"?SilverFriendship:0;
    State.coins+=coins;
    var parts=new List<string>{"+"+coins+" Cat Coins"};
    if(friendship>0&&town.plazaAttendees.Count>0)
    {
     parts.Add("friends +"+friendship);
     foreach(var id in town.plazaAttendees)
     {
      var n=NeighborContent.Current?.Find(id);if(n==null)continue;
      var state=NeighborRecord(id);state.friendship=Math.Min(100,state.friendship+friendship);
      var (_,reward)=ClaimNeighborTiers(state,n);if(reward.Length>0)parts.Add(reward);
     }
    }
    if(tier=="gold")
    {
     var strays=State.cats.Where(c=>!c.known&&c.id<12).ToArray();
     if(strays.Length>0){var cat=strays[StableHash(town.plazaDay+":"+e?.id)%(uint)strays.Length];cat.known=true;parts.Add(cat.name+" heard all about it");}
     var item=Catalog.Find(e?.goldItem);
     if(item!=null){State.storage.Add(new ObjectState{id=Id("object"),itemId=item.id,paid=0});parts.Add("a "+item.name.ToLowerInvariant()+" for storage");}
    }
    string headline=(e?.name??"The event")+": "+char.ToUpperInvariant(tier[0])+tier.Substring(1)+"!";
    summary=(tier=="gold"&&e!=null?e.gold+" ":"")+headline+" "+string.Join(" · ",parts);
    town.plazaResult=tier;town.plazaSerial++;town.plazaEvent="";town.plazaRemaining=0;town.plazaAttendees.Clear();
   },"");
   if(r.success)PlazaEventEnded?.Invoke(summary);
  }

  // Attendees stand in a ring around the square, close enough to chat with from the middle.
  NeighborView PlazaView(NeighborContent.Neighbor n)
  {
   var town=Hotel(0).town;int index=town.plazaAttendees.IndexOf(n.id);
   var center=TownContent.Current.Point("square");int count=Math.Max(4,town.plazaAttendees.Count);
   double angle=index*Math.PI*2/count+.4;
   var at=new LotPoint(center.x+(float)Math.Cos(angle)*PlazaRing,center.z+(float)Math.Sin(angle)*PlazaRing);
   var state=NeighborData(n.id);
   return new NeighborView{id=n.id,name=n.name,place="square",position=at,present=true,facing=(float)Math.Atan2(center.x-at.x,center.z-at.z),friendship=state.friendship,tier=TierFor(state.friendship)};
  }

  internal bool ValidPlaza(HotelData h,int index)
  {
   var t=h.town;var content=PlazaContent.Current;
   if(t.plazaEvent==null||t.plazaResult==null||t.plazaAttendees==null||!Finite(t.plazaRemaining)||t.plazaRemaining<0||t.plazaRemaining>600||t.plazaBuzz<0||t.plazaBuzz>100||t.plazaDay<0||t.plazaSerial<0)return false;
   if(!new[]{"","bronze","silver","gold"}.Contains(t.plazaResult))return false;
   if(index!=0&&(t.plazaEvent.Length>0||t.plazaDay>0||t.plazaSerial>0||t.plazaAttendees.Count>0))return false;
   if(t.plazaEvent.Length==0){if(t.plazaRemaining>0||t.plazaAttendees.Count>0)return false;}
   else if(content!=null&&content.Find(t.plazaEvent)==null)return false;
   if(t.plazaAttendees.Distinct().Count()!=t.plazaAttendees.Count||t.plazaAttendees.Any(id=>id==null||NeighborContent.Current!=null&&NeighborContent.Current.Find(id)==null))return false;
   return true;
  }
 }
}
