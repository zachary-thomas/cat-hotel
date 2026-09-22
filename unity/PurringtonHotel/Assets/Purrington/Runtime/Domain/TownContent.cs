using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
 public sealed class TownContent
 {
  public sealed class Node
  {
   public string id,area;
   public LotPoint point;
  }
  public sealed class Store
  {
   public string id,door,cashier;
   public LotRect footprint;
  }
  readonly Dictionary<string,Node> nodes=new Dictionary<string,Node>(StringComparer.Ordinal);
  readonly Dictionary<string,string> coats=new Dictionary<string,string>(StringComparer.Ordinal);
  readonly HashSet<string> markings=new HashSet<string>(StringComparer.Ordinal);
  readonly Dictionary<string,JObject> offers=new Dictionary<string,JObject>(StringComparer.Ordinal);
  readonly Dictionary<string,Store> stores=new Dictionary<string,Store>(StringComparer.Ordinal);
  readonly Dictionary<string,List<string>> links=new Dictionary<string,List<string>>(StringComparer.Ordinal);
  public static TownContent Current{get;private set;}
  public IEnumerable<string> StreetIds=>nodes.Values.Where(n=>n.area=="street").Select(n=>n.id);
  public IEnumerable<string> Neighbors(string id)=>links.TryGetValue(id,out var list)?list:Enumerable.Empty<string>();
  public bool Has(string id)=>id!=null&&nodes.ContainsKey(id);
  public bool IsStreetTarget(string id)=>id!=null&&nodes.TryGetValue(id,out var node)&&node.area=="street";
  public string NearestStreetTarget(LotPoint point,float radius)
  {
   if(!Finite(point.x)||!Finite(point.z)||!Finite(radius)||radius<0)return null;
   var closest=nodes.Values.Where(n=>n.area=="street").OrderBy(n=>n.point.Distance(point)).ThenBy(n=>n.id,StringComparer.Ordinal).FirstOrDefault();
   return closest!=null&&closest.point.Distance(point)<=radius?closest.id:null;
  }
  public LotPoint Point(string id)=>nodes.TryGetValue(id,out var node)?node.point:throw new KeyNotFoundException("Unknown town node: "+id);
  public JObject Offer(string id)=>id!=null&&offers.TryGetValue(id,out var offer)?offer:null;
  public bool HasCoat(string id)=>id!=null&&coats.ContainsKey(id);
  public string CoatColor(string id)=>coats.TryGetValue(id,out var color)?color:null;
  public bool HasMarkings(string id)=>id!=null&&markings.Contains(id);
  public Store Shop(string id)=>id!=null&&stores.TryGetValue(id,out var store)?store:null;
  public bool HasStreetLink(LotPoint a,LotPoint b)=>links.Any(pair=>pair.Value.Any(id=>OnLink(a,Point(pair.Key),Point(id))&&OnLink(b,Point(pair.Key),Point(id))));
  static bool OnLink(LotPoint point,LotPoint a,LotPoint b)
  {
   float dx=b.x-a.x,dz=b.z-a.z,length2=dx*dx+dz*dz;
   if(length2<.000001f)return false;
   float t=((point.x-a.x)*dx+(point.z-a.z)*dz)/length2;
   if(t<-.000001f||t>1.000001f)return false;
   return new LotPoint(a.x+t*dx,a.z+t*dz).Distance(point)<.001f;
  }
  static bool Finite(float v)=>!float.IsNaN(v)&&!float.IsInfinity(v);
  static string RequiredString(JToken token,string field)
  {
   if(token==null||token.Type!=JTokenType.String||string.IsNullOrWhiteSpace((string)token))throw new FormatException("Missing "+field);
   return (string)token;
  }
  static float Number(JToken token,string field)
  {
   if(token==null||(token.Type!=JTokenType.Integer&&token.Type!=JTokenType.Float))throw new FormatException("Missing "+field);
   double value=(double)token;
   if(double.IsNaN(value)||double.IsInfinity(value)||value>float.MaxValue||value<-float.MaxValue)throw new FormatException("Non-finite "+field);
   return (float)value;
  }
  static JArray Array(JObject root,string field)=>root[field] as JArray??throw new FormatException("Missing "+field);
  static void AddId(HashSet<string> ids,string id){if(!ids.Add(id))throw new FormatException("Duplicate town id: "+id);}
  static bool Crosses(LotPoint a,LotPoint b,LotRect r)
  {
   // Open interior test: touching a facade or walking along its edge is allowed.
   const float eps=.001f;
   var inner=new LotRect(r.x+eps,r.z+eps,r.w-2*eps,r.d-2*eps);
   float lo=0,hi=1;
   foreach(var axis in new[]{0,1})
   {
    float origin=axis==0?a.x:a.z,delta=axis==0?b.x-a.x:b.z-a.z;
    float min=axis==0?inner.x:inner.z,max=min+(axis==0?inner.w:inner.d);
    if(Math.Abs(delta)<1e-7f){if(origin<min||origin>max)return false;continue;}
    float t1=(min-origin)/delta,t2=(max-origin)/delta;
    lo=Math.Max(lo,Math.Min(t1,t2));hi=Math.Min(hi,Math.Max(t1,t2));
    if(lo>hi)return false;
   }
   return hi>=0&&lo<=1;
  }
  public static TownContent LoadJson(string json)
  {
   var root=JObject.Parse(json);
   if((int?)root["schema"]!=1)throw new FormatException("Expected town schema 1");
   var town=new TownContent();var allIds=new HashSet<string>(StringComparer.Ordinal);
   foreach(var token in Array(root,"coats"))
   {
    if(!(token is JObject coat))throw new FormatException("Invalid coat");
    string id=RequiredString(coat["id"],"coat id"),color=RequiredString(coat["color"],"coat color");AddId(allIds,id);
    if(color.Length!=7||color[0]!='#'||color.Skip(1).Any(c=>!Uri.IsHexDigit(c)))throw new FormatException("Invalid coat color: "+id);
    town.coats.Add(id,color);
   }
   foreach(var token in Array(root,"markings")){string id=RequiredString(token,"marking id");AddId(allIds,id);town.markings.Add(id);}
   foreach(var token in Array(root,"nodes"))
   {
    if(!(token is JObject raw))throw new FormatException("Invalid town node");
    string id=RequiredString(raw["id"],"node id"),area=RequiredString(raw["area"],"node area");AddId(allIds,id);
    town.nodes.Add(id,new Node{id=id,area=area,point=new LotPoint(Number(raw["x"],"node x"),Number(raw["z"],"node z"))});
    if(area=="street")town.links.Add(id,new List<string>());
   }
   foreach(var token in Array(root,"stores"))
   {
    if(!(token is JObject raw))throw new FormatException("Invalid store");
    string id=RequiredString(raw["id"],"store id"),door=RequiredString(raw["door"],"store door"),cashier=RequiredString(raw["cashier"],"store cashier");AddId(allIds,id);
    if(!town.IsStreetTarget(door)||!town.Has(cashier)||town.nodes[cashier].area!=id)throw new FormatException("Invalid store anchors: "+id);
    var box=raw["footprint"] as JObject;
    var rect=box==null?DefaultFootprint(id):new LotRect(Number(box["x"],"footprint x"),Number(box["z"],"footprint z"),Number(box["w"],"footprint w"),Number(box["d"],"footprint d"));
    if(rect.w<=0||rect.d<=0||rect.Has(town.Point(door).x,town.Point(door).z))throw new FormatException("Invalid store footprint: "+id);
    town.stores.Add(id,new Store{id=id,door=door,cashier=cashier,footprint=rect});
   }
   var seenLinks=new HashSet<string>(StringComparer.Ordinal);
   foreach(var token in Array(root,"links"))
   {
    if(!(token is JArray pair)||pair.Count!=2)throw new FormatException("Invalid pedestrian link");
    string a=RequiredString(pair[0],"link start"),b=RequiredString(pair[1],"link end");
    if(a==b||!town.IsStreetTarget(a)||!town.IsStreetTarget(b))throw new FormatException("Link must join distinct street nodes: "+a+", "+b);
    string key=string.CompareOrdinal(a,b)<0?a+"\n"+b:b+"\n"+a;
    if(!seenLinks.Add(key))throw new FormatException("Duplicate pedestrian link: "+key);
    if(town.stores.Values.Any(s=>Crosses(town.Point(a),town.Point(b),s.footprint)))throw new FormatException("Pedestrian link crosses store footprint: "+key);
    town.links[a].Add(b);town.links[b].Add(a);
   }
   foreach(var id in town.StreetIds)
   {
    if(town.links[id].Count==0)throw new FormatException("Unlinked street node: "+id);
    if(town.stores.Values.Any(s=>s.footprint.Has(town.Point(id).x,town.Point(id).z)))throw new FormatException("Street node inside store footprint: "+id);
   }
   foreach(var token in Array(root,"offers"))
   {
    if(!(token is JObject raw))throw new FormatException("Invalid offer");
    string id=RequiredString(raw["id"],"offer id");AddId(allIds,id);town.offers.Add(id,raw);
   }
   if(!(root["event"] is JObject evt))throw new FormatException("Missing town event");
   AddId(allIds,RequiredString(evt["id"],"event id"));
   if(!town.IsStreetTarget(RequiredString(evt["anchor"],"event anchor"))||Number(evt["duration"],"event duration")<=0)throw new FormatException("Invalid town event");
   foreach(var id in new[]{"hotel_gate","square","paw_mart_door","clothing_door"})if(!town.IsStreetTarget(id))throw new FormatException("Missing street anchor: "+id);
   var reached=new HashSet<string>(StringComparer.Ordinal){"hotel_gate"};var queue=new Queue<string>();queue.Enqueue("hotel_gate");
   while(queue.Count>0)foreach(var next in town.Neighbors(queue.Dequeue()))if(reached.Add(next))queue.Enqueue(next);
   if(reached.Count!=town.links.Count)throw new FormatException("Disconnected pedestrian graph");
   Current=town;return town;
  }
  static LotRect DefaultFootprint(string id)
  {
   if(id=="paw_mart")return new LotRect(22,-6,12,14);
   if(id=="clothing")return new LotRect(22,25,12,12);
   throw new FormatException("Missing store footprint: "+id);
  }
 }
}
