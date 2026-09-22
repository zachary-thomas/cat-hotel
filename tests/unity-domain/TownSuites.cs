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
  var halfway=new LotPoint(20,17.74f);
  var resumed=TownRoute.Find(town,halfway,"clothing_door");
  check(resumed.Count>1&&resumed[0].Distance(halfway)<.001f&&resumed.Last().Distance(town.Point("clothing_door"))<.001f,"in-progress street route resumes");
  check(resumed.Skip(1).All((point)=>point.Distance(town.Point("square"))<.001f||point.Distance(town.Point("clothing_door"))<.001f),"resumed route stays on the eastern pedestrian links");
  for(int i=1;i<resumed.Count;i++)check(town.HasStreetLink(resumed[i-1],resumed[i]),"resumed route uses authored link");
  var returning=TownRoute.Find(town,halfway,"hotel_gate");
  check(returning.Count==3&&returning[1].Distance(town.Point("east_walk"))<.001f&&returning.Last().Distance(town.Point("hotel_gate"))<.001f,"in-progress route can return toward hotel");
  check(TownRoute.Find(town,new LotPoint(20,17.745f),"square").Count==0,"nearby off-link start rejected");
  check(TownRoute.Find(town,new LotPoint(0,14),"square").Count==0,"off-link start cannot create unauthored connector");
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
  var parity=ParityContent.LoadJson(File.ReadAllText("unity/PurringtonHotel/Assets/Resources/Content/GodotReference.json"));
  var manager=new HotelModel(new MemoryStore(),parity);
  check(manager.LoadOrCreate().success,"town starter saves");
  check((string)JObject.FromObject(manager.State)["managerName"]=="Manager","default manager name saved");
  check(manager.State.managerCoat=="honey"&&manager.State.managerMarkings=="solid","default manager appearance");
  check(manager.State.hotels[0].town!=null&&town.Point("hotel_gate").Distance(new LotPoint(manager.State.hotels[0].town.x,manager.State.hotels[0].town.z))<.001f,"Meadow town starts at gate");
  check(manager.RenameManager("  Poppy  ").success&&manager.State.managerName=="Poppy","trim and rename");
  check(manager.SetManagerAppearance("charcoal","tuxedo").success&&manager.State.managerCoat=="charcoal"&&manager.State.managerMarkings=="tuxedo","appearance saved");
  check(!manager.RenameManager("<size=0>hidden</size>").success,"reject markup name");
  check(!manager.RenameManager(new string('x',25)).success,"reject long name");
  check(!manager.RenameManager("   ").success,"reject blank name");
  check(!manager.SetManagerAppearance("purple","solid").success,"reject unknown coat");
  var reloaded=new HotelModel(new MemoryStore{state=HotelModel.Copy(manager.State)},parity);
  check(reloaded.LoadOrCreate().success&&reloaded.State.managerName=="Poppy"&&reloaded.State.managerCoat=="charcoal","manager reload");
  var oldJson=JObject.FromObject(manager.State);
  oldJson.Remove("managerName");oldJson.Remove("managerCoat");oldJson.Remove("managerMarkings");oldJson.Remove("managerOutfit");
  foreach(var hotel in oldJson["hotels"])((JObject)hotel).Remove("town");
  check(manager.RestoreJson(oldJson.ToString())&&manager.State.managerName=="Manager"&&manager.State.hotels[0].town!=null,"legacy v3 defaults");
  var changed=JObject.FromObject(manager.State);
  ((JObject)changed["hotels"][0]["town"])["x"]=1e99;
  check(!manager.RestoreJson(changed.ToString()),"reject unsafe town position");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["destination"]="missing";
  check(!manager.RestoreJson(changed.ToString()),"reject unknown destination");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["shop"]="missing";
  check(!manager.RestoreJson(changed.ToString()),"reject unknown shop");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["questFlags"]="not an array";
  check(!manager.RestoreJson(changed.ToString()),"reject malformed quest flags");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["questFlags"]=new JArray("unknown");
  check(!manager.RestoreJson(changed.ToString()),"reject unknown quest flag");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["specialFlags"]=new JArray("unknown");
  check(!manager.RestoreJson(changed.ToString()),"reject unknown special flag");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["eventRemaining"]=-1;
  check(!manager.RestoreJson(changed.ToString()),"reject negative event time");
  var failing=new MemoryStore{state=HotelModel.Copy(manager.State)};
  var rollback=new HotelModel(failing,parity);check(rollback.LoadOrCreate().success,"rollback setup");
  failing.fail=true;
  check(!rollback.RenameManager("Willow").success&&rollback.State.managerName=="Manager","rename rollback");
  check(!rollback.SetManagerAppearance("cream","tabby").success&&rollback.State.managerCoat=="honey","appearance rollback");
 }
}
