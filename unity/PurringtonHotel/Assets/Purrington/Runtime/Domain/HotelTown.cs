using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Purrington.Domain
{
 [Serializable] public sealed class TownState
 {
  public float x=0,z=12.75f,eventRemaining;
  public int marketCompletionSerial;
  public string destination="",shop="",phase="street";
  public List<string> questFlags=new List<string>(),specialFlags=new List<string>();
 }
 public sealed partial class HotelModel
 {
  const float ManagerSpeed=2.4f;
  public event Action<string> ManagerArrived;
  public IReadOnlyList<LotPoint> ManagerRoute=>Array.AsReadOnly(BuildManagerRoute(Hotel().town.destination).ToArray());
  List<LotPoint> BuildManagerRoute(string targetId)
  {
   var empty=new List<LotPoint>();
   var town=TownContent.Current;
   if(State.currentHotel!=0||town==null||!town.IsStreetTarget(targetId))return empty;
   var state=Hotel(0).town;var position=new LotPoint(state.x,state.z);
   var gate=town.Point("hotel_gate");var bounds=Map(0)["base"];
   var exit=new LotPoint((float)Math.Floor(gate.x*2)*.5f+.25f,(float)bounds[1]+(float)bounds[3]-.25f);
   if(state.phase=="street")return TownRoute.Find(town,position,targetId);
   if(state.phase!="hotel"||!MovementSegmentClear(position,position,false)||!MovementSegmentClear(exit,exit,false))return empty;
   var hotel=ActivityRoute(position,exit);
   if(hotel.Count==0||!MovementSegmentClear(position,hotel[0],false))return empty;
   var street=TownRoute.Find(town,gate,targetId);
   if(street.Count==0)return empty;
   var joined=new List<LotPoint>{position};
   int first=hotel.Count>1&&MovementSegmentClear(position,hotel[1],false)?1:0;
   for(int i=first;i<hotel.Count;i++)if(hotel[i].Distance(joined[joined.Count-1])>.0001f)joined.Add(hotel[i]);
   if(joined[joined.Count-1].Distance(exit)>.0001f)joined.Add(exit);
   joined.AddRange(street);
   return joined;
  }
  public CommandResult SendManager(string targetId)
  {
   if(State.currentHotel!=0||TownContent.Current==null||!TownContent.Current.IsStreetTarget(targetId))return CommandResult.Fail("Choose a Meadow destination.");
   if(Hotel(0).town.phase=="street"&&Hotel(0).town.destination==""&&new LotPoint(Hotel(0).town.x,Hotel(0).town.z).Distance(TownContent.Current.Point(targetId))<.0001f)return CommandResult.Fail("Already at this destination.");
   if(BuildManagerRoute(targetId).Count==0)return CommandResult.Fail("The way to Main Street is blocked.");
   return Transaction(()=>{Hotel(0).town.destination=targetId;Hotel(0).town.shop="";},"On the way to "+targetId+".");
  }
  public CommandResult SkipManagerTravel()
  {
   string target=Hotel(0).town.destination;
   if(State.currentHotel!=0||string.IsNullOrEmpty(target))return CommandResult.Fail("Choose a Meadow destination.");
   var route=BuildManagerRoute(target);
   if(route.Count==0)return CommandResult.Fail("The way to Main Street is blocked.");
   var point=TownContent.Current.Point(target);
   var result=Transaction(()=>ArriveManager(target,point),"Arrived at "+target+".");
   if(result.success)ManagerArrived?.Invoke(target);
   return result;
  }
  void ArriveManager(string target,LotPoint point)
  {
   var state=Hotel(0).town;state.x=point.x;state.z=point.z;state.phase="street";state.destination="";
   state.shop=TownContent.Current.Shop("paw_mart")?.door==target?"paw_mart":TownContent.Current.Shop("clothing")?.door==target?"clothing":"";
  }
  void AdvanceManager(float seconds)
  {
   if(State.currentHotel!=0||string.IsNullOrEmpty(Hotel(0).town.destination))return;
   string target=Hotel(0).town.destination;
   var route=BuildManagerRoute(target);
   if(route.Count==0)return;
   float remaining=seconds*ManagerSpeed;string phase=Hotel(0).town.phase;
   var at=new LotPoint(Hotel(0).town.x,Hotel(0).town.z);
   foreach(var next in route.Skip(1))
   {
    if(phase=="hotel"&&next.Distance(TownContent.Current.Point("hotel_gate"))<.0001f){at=next;phase="street";continue;}
    float gap=at.Distance(next);
    if(gap<=remaining){at=next;remaining-=gap;}
    else{float portion=remaining/gap;at=new LotPoint(at.x+(next.x-at.x)*portion,at.z+(next.z-at.z)*portion);remaining=0;break;}
   }
   bool arrived=at.Distance(TownContent.Current.Point(target))<.0001f;
   if(!arrived&&at.Distance(new LotPoint(Hotel(0).town.x,Hotel(0).town.z))<.00001f)return;
   var result=Transaction(()=>{if(arrived)ArriveManager(target,at);else{Hotel(0).town.x=at.x;Hotel(0).town.z=at.z;Hotel(0).town.phase=phase;}},arrived?"Arrived at "+target+".":"On the way.");
   if(result.success&&arrived)ManagerArrived?.Invoke(target);
  }
  internal static bool ValidManagerName(string name)
  {
   if(string.IsNullOrWhiteSpace(name)||name!=name.Trim()||name.IndexOf('<')>=0||name.IndexOf('>')>=0)return false;
   for(int i=0;i<name.Length;i++)
   {
    if(char.IsHighSurrogate(name[i]))
    {
     if(i+1>=name.Length||!char.IsLowSurrogate(name[i+1]))return false;
    }
    else if(char.IsLowSurrogate(name[i]))return false;
    // These are classified as letters or symbols but render as blank glyphs.
    if("\u2800\u3164\u115F\u1160\uFFA0".IndexOf(name[i])>=0)return false;
    var category=CharUnicodeInfo.GetUnicodeCategory(name,i);
    if(category==UnicodeCategory.Control||category==UnicodeCategory.Format||category==UnicodeCategory.LineSeparator||category==UnicodeCategory.ParagraphSeparator||category==UnicodeCategory.OtherNotAssigned||category==UnicodeCategory.PrivateUse||category==UnicodeCategory.Surrogate)return false;
    if(char.IsHighSurrogate(name[i]))i++;
   }
   int count=new StringInfo(name).LengthInTextElements;
   return count>=1&&count<=24;
  }
  public CommandResult RenameManager(string name)
  {
   string clean=(name??"").Trim();
   if(!ValidManagerName(clean))return CommandResult.Fail("Choose a name with 1\u201324 characters.");
   return Transaction(()=>State.managerName=clean,"Manager renamed.");
  }
  public CommandResult SetManagerAppearance(string coat,string markings)
  {
   var town=TownContent.Current;
   if(town==null||!town.HasCoat(coat)||!town.HasMarkings(markings))return CommandResult.Fail("Choose a coat and markings.");
   return Transaction(()=>{State.managerCoat=coat;State.managerMarkings=markings;},"Manager look updated.");
  }
  internal bool ValidTown(TownState state,TownContent content,int index)
  {
   if(state==null||content==null||!Finite(state.x)||!Finite(state.z)||Math.Abs(state.x)>256||Math.Abs(state.z)>256||!Finite(state.eventRemaining)||state.eventRemaining<0||state.eventRemaining>90||state.marketCompletionSerial<0||index!=0&&(state.eventRemaining>0||state.marketCompletionSerial>0))return false;
   if(state.destination==null||state.shop==null||state.questFlags==null||state.specialFlags==null)return false;
   if(state.destination.Length>0&&!content.IsStreetTarget(state.destination))return false;
   if(state.shop.Length>0&&content.Shop(state.shop)==null)return false;
   if(state.phase!="hotel"&&state.phase!="street")return false;
   var position=new LotPoint(state.x,state.z);
   if(state.phase=="hotel")
   {
    if(index!=0||state.shop.Length>0||!MovementSegmentClear(position,position,false,0))return false;
   }
   else if(state.shop.Length==0&&TownRoute.Find(content,position,"hotel_gate").Count==0)return false;
   if(state.questFlags.Any(id=>id==null)||state.questFlags.Distinct().Count()!=state.questFlags.Count)return false;
   // Only authored quest stages are accepted; completion and reward are atomic.
   if(state.questFlags.Any(flag=>!content.Quests.Any(q=>new[]{"accepted","completed","rewarded"}.Any(stage=>flag==(string)q["id"]+":"+stage))))return false;
   foreach(var quest in content.Quests){string id=(string)quest["id"];bool accepted=state.questFlags.Contains(id+":accepted"),completed=state.questFlags.Contains(id+":completed"),rewarded=state.questFlags.Contains(id+":rewarded");if(completed!=rewarded||completed&&!accepted)return false;string grant=(string)quest["grantWear"];if(index==0&&grant!=null&&accepted!=State.wardrobe.Contains(grant))return false;}
   if(index!=0&&(state.questFlags.Count>0||state.specialFlags.Count>0))return false;
   if(state.specialFlags.Any(id=>id==null||content.Offer(id)==null)||state.specialFlags.Distinct().Count()!=state.specialFlags.Count)return false;
   return true;
  }
 }
}
