using System;
using System.IO;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

static class TownSuites
{
 public static void Run(Action<bool,string> check)
 {
  var town=TownContent.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/MainStreet.json"));
  foreach(var id in new[]{"hotel_gate","square","paw_mart_door","clothing_door","paw_mart_cashier","clothing_cashier"})check(town.Has(id),"town id "+id);
  check(town.HasCoat("honey")&&town.HasCoat("charcoal")&&town.HasMarkings("tabby"),"manager appearance choices");
  check(town.NearestStreetTarget(town.Point("square"),1.25f)=="square","ground taps snap to pedestrian graph");
  check(!town.IsStreetTarget("paw_mart_cashier")&&!town.IsStreetTarget("clothing_cashier"),"cashiers stay indoors");
  foreach(var target in new[]{"square","paw_mart_door","clothing_door"})
  {
   var route=TownRoute.Find(town,town.Point("hotel_gate"),target);
   check(route.Count>1&&route.Last().Distance(town.Point(target))<.001f,target+" reachable");
   for(int i=1;i<route.Count;i++)check(town.HasStreetLink(route[i-1],route[i]),target+" route uses authored links");
  }
  check(TownRoute.Find(town,town.Point("hotel_gate"),"unknown").Count==0,"unknown destination rejected");
  check(TownRoute.Find(town,town.Point("hotel_gate"),"paw_mart_cashier").Count==0,"interior destination rejected");
  var original=JObject.Parse(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/MainStreet.json"));
  void Reject(Action<JObject> change,string reason)
  {
   var bad=(JObject)original.DeepClone();change(bad);
   bool rejected=false;try{TownContent.LoadJson(bad.ToString());}catch(FormatException){rejected=true;}
   check(rejected,reason);
  }
  Reject(j=>((JArray)j["nodes"]).Add(((JArray)j["nodes"])[0].DeepClone()),"duplicate node rejected");
  Reject(j=>((JArray)j["links"]).Add(new JArray("square","missing")),"missing link endpoint rejected");
  Reject(j=>((JArray)j["links"]).Add(new JArray("square","paw_mart_cashier")),"interior pedestrian link rejected");
  Reject(j=>((JObject)((JArray)j["nodes"])[0])["x"]=1e99,"non-finite node position rejected");
  Reject(j=>{((JArray)j["nodes"]).Add(new JObject{{"id","blocked"},{"x",28},{"z",0},{"area","street"}});((JArray)j["links"]).Add(new JArray("square","blocked"));},"link across shop footprint rejected");
  check(ReferenceEquals(TownContent.Current,town),"invalid content does not replace registry");
 }
}
