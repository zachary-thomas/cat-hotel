using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
[Serializable] public sealed class HotelState {
 public int version=3; public double coins=1000; public float elapsed; public int nextId=1,currentHotel; public long lastSeen; public double pendingCoins;
 public string managerName="Manager",managerCoat="honey",managerMarkings="solid"; public Dictionary<string,string> managerOutfit=new Dictionary<string,string>();
 public List<HotelData> hotels=new List<HotelData>(); public List<ObjectState> storage=new List<ObjectState>(); public List<CatState> cats=new List<CatState>(); public List<string> entitlements=new List<string>(); public List<string> wardrobe=new List<string>(); public SettingsState settings=new SettingsState();
 [JsonIgnore] public List<RoomState> rooms {get{return hotels.Count>currentHotel?hotels[currentHotel].rooms:legacyRooms;}set{if(hotels.Count>currentHotel)hotels[currentHotel].rooms=value;else legacyRooms=value;}}
 [JsonIgnore] public List<ObjectState> objects {get{return hotels.Count>currentHotel?hotels[currentHotel].objects:legacyObjects;}set{if(hotels.Count>currentHotel)hotels[currentHotel].objects=value;else legacyObjects=value;}}
 [JsonIgnore] List<RoomState> legacyRooms=new List<RoomState>(); [JsonIgnore] List<ObjectState> legacyObjects=new List<ObjectState>();
}
[Serializable] public sealed class HotelData { public bool owned,maid; public TownState town=new TownState(); public List<string> plots=new List<string>(); public List<RoomState> rooms=new List<RoomState>(); public List<FloorState> floors=new List<FloorState>(); public List<ObjectState> objects=new List<ObjectState>(); public Dictionary<string,PathState> paths=new Dictionary<string,PathState>(); public int level=1,visits,happy,cleaned,purchases,dirtCursor; public float dirtClock; public int[] upgrades={1,0,0,1},staff={0,0,0}; public Dictionary<string,bool> dirty=new Dictionary<string,bool>(); }
[Serializable] public sealed class PathState {public string style="earth";public double paid;}
[Serializable] public sealed class RoomState { public string id,name="New room",kind="regular"; public int x,z,width,depth,rotation,floor; public double paid; }
[Serializable] public sealed class ObjectState {public string id,itemId,room="";public float x,z;public int rotation,floor;public double paid;}
[Serializable] public sealed class CatState {public int id,bond,friend=-1;public string name,preference,favoriteAction;public Dictionary<string,string> outfit=new Dictionary<string,string>();public bool known=true;public float lastCare=-100;}
[Serializable] public sealed class SettingsState {public float textScale=1; public bool motion=true,music=true,sound=true,exterior,evening,godMode,assistedCare;}
public sealed class CommandResult {public bool success,progressChanged;public string message;public double cost;public List<string> displaced=new List<string>();public static CommandResult Ok(string message,double cost=0){return new CommandResult{success=true,message=message,cost=cost};}public static CommandResult Fail(string message,double cost=0){return new CommandResult{message=message,cost=cost};}}
public interface IResettableSaveStore {bool Reset(HotelState state);} public interface ISaveStore {HotelState Load();bool Save(HotelState state);} public interface ISaveStatus {bool HasExistingSave{get;}string LoadError{get;}} public interface ISaveCodec {string Serialize(HotelState state);HotelState Deserialize(string json);}
public sealed class NewtonsoftSaveCodec:ISaveCodec {public string Serialize(HotelState s){return JsonConvert.SerializeObject(s);}public HotelState Deserialize(string s){var state=StrictSaveJson.Read(s);ShellMigration.Upgrade(state);return state;}}
[Serializable] public sealed class ItemDefinition {public string id,name,category,role,shape,color;public double price;public float width,depth;public bool indoorOnly;public int capacity,service=-1,bond;public string[] tags=Array.Empty<string>(),surfaces=new[]{"indoor","outdoor"};public ItemDefinition(){}public ItemDefinition(string id,string name,string category,double price,float width,float depth,string role="decoration",bool indoorOnly=false){this.id=id;this.name=name;this.category=category;this.price=price;this.width=width;this.depth=depth;this.role=role;this.indoorOnly=indoorOnly;}}
public static class Catalog {public static ItemDefinition[] All=Array.Empty<ItemDefinition>();public static ItemDefinition Find(string id){return Array.Find(All,i=>i.id==id);}}
public sealed class ParityContent {
 public static ParityContent Current{get;private set;} public JObject[] Maps,Templates,Cats,Services,Staff; public JObject Starter; public JObject Raw;
 static JObject[] Records(JToken t){return t is JObject o?o.Properties().Select(p=>(JObject)p.Value).ToArray():t?.Children<JObject>().ToArray()??Array.Empty<JObject>();}
 public static ParityContent LoadJson(string json){var j=JObject.Parse(json);if((int?)j["schema"]!=2)throw new FormatException("Expected parity content schema 2");var c=new ParityContent{Raw=j,Maps=Records(j["maps"]),Templates=Records(j["templates"]),Cats=Records(j["cats"]),Services=Records(j["services"]),Staff=Records(j["staff"]),Starter=(JObject)j["starter"]};if(c.Maps.Length!=4||c.Cats.Length!=18)throw new FormatException("Incomplete reference content");Catalog.All=Records(j["items"]).Select(i=>new ItemDefinition{ id=(string)i["id"],name=(string)i["name"],category=(string)i["category"],price=(double?)i["cost"]??0,width=(float)i["size"][0],depth=(float)i["size"][1],role=(string)i["role"],shape=(string)i["shape"],color=(string)i["color"],capacity=(int?)i["capacity"]??0,service=(int?)i["service"]??-1,bond=(int?)i["bond"]??0,tags=i["tags"]?.ToObject<string[]>()??Array.Empty<string>(),surfaces=i["surfaces"]?.ToObject<string[]>()??new[]{"indoor","outdoor"},indoorOnly=i["surfaces"]?.Count()==1&&(string)i["surfaces"][0]=="indoor"}).ToArray();Current=c;return c;}
 public HotelState CreateState(){var s=new HotelState();if(Starter==null)throw new FormatException("Missing starter");s.coins=(double)Starter["coins"];s.nextId=(int)Starter["next_id"];s.currentHotel=(int)Starter["current_hotel"];foreach(var h in Starter["hotels"]){var d=new HotelData{owned=(bool)h["owned"],upgrades=h["upgrades"].ToObject<int[]>(),staff=h["staff"].ToObject<int[]>(),paths=h["paths"].ToObject<Dictionary<string,PathState>>()};foreach(var r in h["rooms"])d.rooms.Add(ReadRoom(r));foreach(var o in h["objects"])d.objects.Add(ReadObject(o));s.hotels.Add(d);}foreach(var c in Starter["cats"]){int id=(int)c["id"];s.cats.Add(new CatState{id=id,name=(string)c["name"],preference=(string)c["preference"],known=(bool)c["known"],favoriteAction=(string)Cats[id]["favoriteAction"]});}s.version=2;ShellMigration.Upgrade(s);s.hotels[0].town.phase="hotel";s.hotels[0].town.x=(float)Maps[0]["arrival"][0];s.hotels[0].town.z=(float)Maps[0]["arrival"][1];return s;}
 public static RoomState ReadRoom(JToken r){return new RoomState{id=(string)r["id"],name=(string)r["name"],kind=(string)r["kind"],x=(int)r["x"],z=(int)r["y"],width=(int)r["w"],depth=(int)r["h"],rotation=(int?)r["rotation"]??0,paid=(double?)r["paid"]??0};}
 public static ObjectState ReadObject(JToken o){return new ObjectState{id=(string)o["id"],itemId=(string)o["item"],room=(string)o["room"]??"",x=(float)o["x"],z=(float)o["y"],rotation=(int?)o["rotation"]??0,paid=(double?)o["paid"]??0};}
}
public struct LotPoint {public float x,z;public LotPoint(float x,float z){this.x=x;this.z=z;}public float Distance(LotPoint b){return (float)Math.Sqrt((x-b.x)*(x-b.x)+(z-b.z)*(z-b.z));}}
public sealed class RoomStatusInfo {public bool ready;public string status,message;public double bonus;}
public sealed class VenueSlot {public string key,action;public float x,z,facing;}
public sealed class VenueSnapshot {public string id,item,name,room,role,status;public bool open;public int service,capacity;public float x,z;public string[] tags;public List<VenueSlot> slots=new List<VenueSlot>();public VenueSlot staffSlot;public float frontX,frontZ,centerX,centerZ;}
public enum ActorKind { Guest, Staff, DayVisitor }
public sealed class ActorSnapshot {public ActorKind kind;public int visitorIndex=-1;public float speechElapsed,speechDuration=3.1f;public string id,name,role,action="rest",venueId="",speech="",gesture="",intent="";public int catId;public string phase,slot,sourceRoom;public bool checkedIn,drink;public float remaining;public int completed;public float x,z,facing,activityElapsed,activityDuration;public long activityToken;}
}




