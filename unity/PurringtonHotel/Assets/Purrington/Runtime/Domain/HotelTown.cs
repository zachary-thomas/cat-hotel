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
  internal static bool ValidManagerName(string name)
  {
   if(string.IsNullOrWhiteSpace(name)||name!=name.Trim()||name.IndexOf('<')>=0||name.IndexOf('>')>=0)return false;
   for(int i=0;i<name.Length;i++)
   {
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
