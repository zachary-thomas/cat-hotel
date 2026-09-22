using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Purrington.Domain
{
 [Serializable] public sealed class TownState
 {
  public float x=0,z=12.75f,eventRemaining;
  public string destination="",shop="";
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
   var position=new LotPoint(Hotel(0).town.x,Hotel(0).town.z);
   // At the gate, verify the hotel entrance still has an open path to the exit.
   // The saved position remains on the street graph after that handoff.
   var gate=town.Point("hotel_gate");var bounds=Map(0)["base"];
   var exit=new LotPoint((float)Math.Floor(gate.x*2)*.5f+.25f,(float)bounds[1]+(float)bounds[3]-.25f);
   if(position.Distance(town.Point("hotel_gate"))<.001f&&(!MovementSegmentClear(exit,exit,false)||ActivityRoute(VisitorEntrance,exit).Count==0))return empty;
   return TownRoute.Find(town,position,targetId);
  }
  public CommandResult SendManager(string targetId)
  {
   if(State.currentHotel!=0||TownContent.Current==null||!TownContent.Current.IsStreetTarget(targetId))return CommandResult.Fail("Choose a Meadow destination.");
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
   var state=Hotel(0).town;state.x=point.x;state.z=point.z;state.destination="";
   state.shop=TownContent.Current.Shop("paw_mart")?.door==target?"paw_mart":TownContent.Current.Shop("clothing")?.door==target?"clothing":"";
  }
  void AdvanceManager(float seconds)
  {
   if(State.currentHotel!=0||string.IsNullOrEmpty(Hotel(0).town.destination))return;
   string target=Hotel(0).town.destination;
   var route=BuildManagerRoute(target);
   if(route.Count==0)return;
   float remaining=seconds*ManagerSpeed;
   var at=new LotPoint(Hotel(0).town.x,Hotel(0).town.z);
   foreach(var next in route.Skip(1))
   {
    float gap=at.Distance(next);
    if(gap<=remaining){at=next;remaining-=gap;}
    else{float portion=remaining/gap;at=new LotPoint(at.x+(next.x-at.x)*portion,at.z+(next.z-at.z)*portion);remaining=0;break;}
   }
   bool arrived=at.Distance(TownContent.Current.Point(target))<.0001f;
   if(!arrived&&at.Distance(new LotPoint(Hotel(0).town.x,Hotel(0).town.z))<.00001f)return;
   var result=Transaction(()=>{if(arrived)ArriveManager(target,at);else{Hotel(0).town.x=at.x;Hotel(0).town.z=at.z;}},arrived?"Arrived at "+target+".":"On the way.");
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
  internal static bool ValidTown(TownState state,TownContent content)
  {
   if(state==null||content==null||!Finite(state.x)||!Finite(state.z)||Math.Abs(state.x)>256||Math.Abs(state.z)>256||!Finite(state.eventRemaining)||state.eventRemaining<0)return false;
   if(state.destination==null||state.shop==null||state.questFlags==null||state.specialFlags==null)return false;
   if(state.destination.Length>0&&!content.IsStreetTarget(state.destination))return false;
   if(state.shop.Length>0&&content.Shop(state.shop)==null)return false;
   if(state.shop.Length==0&&TownRoute.Find(content,new LotPoint(state.x,state.z),"hotel_gate").Count==0)return false;
   if(state.questFlags.Any(id=>id==null)||state.questFlags.Distinct().Count()!=state.questFlags.Count)return false;
   // No quest IDs are authored yet. Future quest content will supply the allowlist.
   if(state.questFlags.Count>0)return false;
   if(state.specialFlags.Any(id=>id==null||content.Offer(id)==null)||state.specialFlags.Distinct().Count()!=state.specialFlags.Count)return false;
   return true;
  }
 }
}
