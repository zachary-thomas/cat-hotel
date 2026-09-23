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
  check(manager.State.hotels[0].town!=null&&manager.State.hotels[0].town.phase=="hotel"&&manager.VisitorEntrance.Distance(new LotPoint(manager.State.hotels[0].town.x,manager.State.hotels[0].town.z))<.001f,"fresh manager starts at hotel entrance");
  var badOutfit=JObject.FromObject(manager.State);badOutfit["managerOutfit"]=new JObject{{"hat","unowned-id"}};
  check(!manager.RestoreJson(badOutfit.ToString()),"reject unvalidated manager outfit in save");
  check(manager.RenameManager("  Poppy  ").success&&manager.State.managerName=="Poppy","trim and rename");
  check(manager.SetManagerAppearance("charcoal","tuxedo").success&&manager.State.managerCoat=="charcoal"&&manager.State.managerMarkings=="tuxedo","appearance saved");
  check(!manager.RenameManager("<size=0>hidden</size>").success,"reject markup name");
  check(!manager.RenameManager("\u200B").success&&manager.State.managerName=="Poppy","reject invisible manager name");
  check(!manager.RenameManager("Po\u202Eppy").success&&manager.State.managerName=="Poppy","reject spoofed manager name");
  foreach(var filler in new[]{"\u2800","\u3164","\u115F","\u1160","\uFFA0"})
   check(!manager.RenameManager(filler).success&&manager.State.managerName=="Poppy","reject blank filler manager name");
  check(!manager.RenameManager("\uD800").success&&manager.State.managerName=="Poppy","reject unmatched high surrogate");
  check(!manager.RenameManager("\uDC00").success&&manager.State.managerName=="Poppy","reject unmatched low surrogate");
  check(manager.RenameManager("\uD83D\uDC31").success&&manager.RenameManager("Poppy").success,"visible emoji remains a valid manager name");
  check(!manager.RenameManager(new string('x',25)).success,"reject long name");
  check(!manager.RenameManager("   ").success,"reject blank name");
  check(!manager.SetManagerAppearance("purple","solid").success,"reject unknown coat");
  var reloaded=new HotelModel(new MemoryStore{state=HotelModel.Copy(manager.State)},parity);
  check(reloaded.LoadOrCreate().success&&reloaded.State.managerName=="Poppy"&&reloaded.State.managerCoat=="charcoal","manager reload");
  var oldJson=JObject.FromObject(manager.State);
  oldJson.Remove("managerName");oldJson.Remove("managerCoat");oldJson.Remove("managerMarkings");oldJson.Remove("managerOutfit");
  foreach(var hotel in oldJson["hotels"])((JObject)hotel).Remove("town");
  check(manager.RestoreJson(oldJson.ToString())&&manager.State.managerName=="Manager"&&manager.State.hotels[0].town.phase=="street"&&town.Point("hotel_gate").Distance(new LotPoint(manager.Hotel(0).town.x,manager.Hotel(0).town.z))<.001f,"legacy v3 defaults to street gate");
  var changed=JObject.FromObject(manager.State);
  changed["managerName"]="\u200B";
  check(!manager.RestoreJson(changed.ToString()),"reject invisible manager name in save");
  changed=JObject.FromObject(manager.State);changed["managerName"]="\u2800";
  check(!manager.RestoreJson(changed.ToString()),"reject blank filler manager name in save");
  changed=JObject.FromObject(manager.State);
  ((JObject)changed["hotels"][0]["town"])["x"]=1e99;
  check(!manager.RestoreJson(changed.ToString()),"reject unsafe town position");
  changed=JObject.FromObject(manager.State);((JObject)changed["hotels"][0]["town"])["phase"]="unknown";
  check(!manager.RestoreJson(changed.ToString()),"reject unknown manager travel phase");
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
  var traveler=new HotelModel(new MemoryStore(),parity);check(traveler.LoadOrCreate().success,"travel setup");
  int arrivals=0;traveler.ManagerArrived+=_=>arrivals++;
  check(traveler.SendManager("paw_mart_door").success,"start Paw Mart walk");
  check(traveler.ManagerRoute.Count>1&&traveler.ManagerRoute.Any(p=>p.Distance(traveler.VisitorEntrance)<.5f)&&traveler.ManagerRoute.Any(p=>p.Distance(town.Point("hotel_gate"))<.001f),"route joins hotel entrance to street gate");
  traveler.Tick(.2f);
  check(traveler.Hotel().town.destination=="paw_mart_door"&&traveler.Hotel().town.shop==""&&traveler.Hotel().town.phase=="hotel","travel moves through hotel first");
  var midway=new LotPoint(traveler.Hotel().town.x,traveler.Hotel().town.z);
  check(midway.Distance(traveler.VisitorEntrance)>0&&midway.Distance(town.Point("hotel_gate"))>1,"saved midpoint visits hotel connector");
  var resume=new HotelModel(new MemoryStore{state=HotelModel.Copy(traveler.State)},parity);
  check(resume.LoadOrCreate().success&&resume.Hotel().town.phase=="hotel"&&resume.ManagerRoute.Count>0,"reload recovers hotel route");
  int resumedArrivals=0;resume.ManagerArrived+=_=>resumedArrivals++;
  check(resume.SendManager("clothing_door").success,"repeated tap redirects route");
  for(int i=0;i<600&&resume.Hotel().town.destination!="";i++)resume.Tick(.2f);
  check(resume.Hotel().town.destination==""&&resume.Hotel().town.x==town.Point("clothing_door").x&&resumedArrivals==1,"redirect arrives exactly once at "+resume.Hotel().town.x+","+resume.Hotel().town.z+" phase "+resume.Hotel().town.phase+" route "+string.Join(";",resume.ManagerRoute.Select(p=>p.x+","+p.z)));
  for(int i=0;i<10;i++)resume.Tick(.2f);
  check(resumedArrivals==1,"idle ticks do not repeat arrival");
  check(!resume.SendManager("unknown").success,"unknown target rejected");
  check(resume.SendManager("paw_mart_door").success&&resume.SkipManagerTravel().success,"skip uses valid route");
  check(resume.Hotel().town.shop=="paw_mart"&&resumedArrivals==2,"shop entered on arrival");
  check(!resume.SendManager("paw_mart_door").success&&resume.Hotel().town.shop=="paw_mart","same destination after arrival does not restart trip");
  resume.Tick(.2f);check(resumedArrivals==2,"same destination cannot duplicate arrival");
  var failedTravel=new MemoryStore();var failedManager=new HotelModel(failedTravel,parity);check(failedManager.LoadOrCreate().success,"travel rollback setup");
  failedTravel.fail=true;check(!failedManager.SendManager("square").success&&failedManager.Hotel().town.destination=="","travel start rolls back on save failure");
  var blocked=new HotelModel(new MemoryStore(),parity);check(blocked.LoadOrCreate().success,"blocked exit setup");
  check(blocked.PlaceObject("garden_planter",0,11).success,"place exit blocker");
  check(!blocked.SendManager("square").success&&blocked.Hotel().town.destination=="","blocked hotel exit keeps manager safe");
  var other=new HotelModel(new MemoryStore(),parity);check(other.LoadOrCreate().success,"other neighborhood setup");
  check(other.SetGodMode(true).success&&other.Travel(1).success,"reach other neighborhood");
  check(!other.SendManager("square").success&&!other.SkipManagerTravel().success&&other.Hotel(0).town.destination=="","other neighborhood cannot send Meadow manager");
  var pausedStore=new MemoryStore();var paused=new HotelModel(pausedStore,parity);check(paused.LoadOrCreate().success&&paused.SendManager("square").success,"pause trip setup");
  paused.Tick(.2f);var safe=new LotPoint(paused.Hotel().town.x,paused.Hotel().town.z);
  pausedStore.fail=true;paused.Tick(.2f);
  check(new LotPoint(paused.Hotel().town.x,paused.Hotel().town.z).Distance(safe)<.0001f&&paused.Hotel().town.destination=="square","failed save retains last safe waypoint");
  var recovered=new HotelModel(new MemoryStore{state=HotelModel.Copy(paused.State)},parity);
  check(recovered.LoadOrCreate().success&&recovered.Hotel().town.destination=="square"&&recovered.ManagerRoute.Count>0,"pause and reload retain destination");
  var crossing=new HotelModel(new MemoryStore(),parity);check(crossing.LoadOrCreate().success&&crossing.SendManager("square").success,"street handoff setup");
  for(int i=0;i<100&&crossing.Hotel().town.phase=="hotel";i++)crossing.Tick(.2f);
  check(crossing.Hotel().town.phase=="street"&&crossing.Hotel().town.destination=="square"&&TownRoute.Find(town,new LotPoint(crossing.Hotel().town.x,crossing.Hotel().town.z),"square").Count>0,"hotel leg hands off to authored street link");
  var interrupted=new HotelModel(new MemoryStore(),parity);check(interrupted.LoadOrCreate().success&&interrupted.SendManager("square").success,"mid-hotel block setup");
  interrupted.Tick(.2f);var lastSafe=new LotPoint(interrupted.Hotel().town.x,interrupted.Hotel().town.z);
  check(interrupted.PlaceObject("garden_planter",0,11).success,"block hotel exit during trip");
  interrupted.Tick(.2f);
  check(interrupted.Hotel().town.phase=="hotel"&&interrupted.Hotel().town.destination=="square"&&new LotPoint(interrupted.Hotel().town.x,interrupted.Hotel().town.z).Distance(lastSafe)<.0001f,"blocked route retains last safe hotel waypoint");
 }
}
