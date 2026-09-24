using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
 // Neighbor requests and rumors from Resources/Content/Quests.json. Load after TownContent and NeighborContent.
 public sealed class QuestContent
 {
  public static readonly string[] Finds={"kitten","lost_item","treasure"};
  public sealed class Spot{public string id,name;}
  public sealed class Rumor{public string spot,find,text;}
  public sealed class Build{public string id,text;public string[] items;public int count;}
  public static QuestContent Current{get;private set;}
  public Spot[] Spots{get;private set;}=Array.Empty<Spot>();
  public Rumor[] Rumors{get;private set;}=Array.Empty<Rumor>();
  public Build[] Builds{get;private set;}=Array.Empty<Build>();
  public string[] Treasures{get;private set;}=Array.Empty<string>();
  public string[] Fetch{get;private set;}=Array.Empty<string>();
  public string[] Thanks{get;private set;}=Array.Empty<string>();
  public string Reminder{get;private set;}="";
  readonly Dictionary<string,string> found=new Dictionary<string,string>(StringComparer.Ordinal);
  public Spot FindSpot(string id)=>id==null?null:Array.Find(Spots,s=>s.id==id);
  public Build FindBuild(string id)=>id==null?null:Array.Find(Builds,b=>b.id==id);
  public string Found(string key)=>found.TryGetValue(key,out var text)?text:"";

  public static QuestContent LoadJson(string json)
  {
   var root=JObject.Parse(json);
   if((int?)root["schema"]!=1)throw new FormatException("Expected quest schema 1");
   var c=new QuestContent();var town=TownContent.Current;
   c.Spots=(root["spots"] as JArray??throw new FormatException("Missing spots")).Select(s=>new Spot{id=Text(s["id"]),name=Text(s["name"])}).ToArray();
   if(c.Spots.Length==0||c.Spots.Select(s=>s.id).Distinct().Count()!=c.Spots.Length||town!=null&&c.Spots.Any(s=>!town.IsStreetTarget(s.id)))throw new FormatException("Spots must be distinct Main Street nodes");
   c.Rumors=(root["rumors"] as JArray??throw new FormatException("Missing rumors")).Select(r=>new Rumor{spot=Text(r["spot"]),find=Text(r["find"]),text=Chat(Text(r["text"]))}).ToArray();
   foreach(var spot in c.Spots)foreach(var find in Finds)if(!c.Rumors.Any(r=>r.spot==spot.id&&r.find==find))throw new FormatException("Missing rumor for "+spot.id+"/"+find);
   if(c.Rumors.Any(r=>c.FindSpot(r.spot)==null||!Finds.Contains(r.find)))throw new FormatException("Rumor names an unknown spot or find");
   c.Builds=(root["builds"] as JArray??throw new FormatException("Missing builds")).Select(b=>new Build{id=Text(b["id"]),text=Chat(Text(b["text"])),count=(int?)b["count"]??0,items=(b["items"] as JArray??new JArray()).Select(Text).ToArray()}).ToArray();
   if(c.Builds.Length==0||c.Builds.Any(b=>b.count<1||b.count>5||b.items.Length==0)||c.Builds.Select(b=>b.id).Distinct().Count()!=c.Builds.Length)throw new FormatException("Invalid build requests");
   c.Treasures=(root["treasures"] as JArray??throw new FormatException("Missing treasures")).Select(Text).ToArray();
   if(Catalog.All.Length>0&&c.Treasures.Concat(c.Builds.SelectMany(b=>b.items)).Any(id=>Catalog.Find(id)==null))throw new FormatException("Quests name unknown furniture");
   c.Fetch=Lines(root["fetch"]);c.Thanks=Lines(root["thanks"]);c.Reminder=Text(root["reminder"]);
   if(c.Treasures.Length==0)throw new FormatException("Missing treasures");
   foreach(var p in (root["found"] as JObject??throw new FormatException("Missing found lines")).Properties())c.found[p.Name]=Text(p.Value);
   foreach(var key in new[]{"kitten","kittenKnown","lost_item","treasure"})if(!c.found.ContainsKey(key))throw new FormatException("Missing found line "+key);
   Current=c;
   return c;
  }
  static string Text(JToken t)
  {
   if(t==null||t.Type!=JTokenType.String||string.IsNullOrWhiteSpace((string)t))throw new FormatException("Missing quest text");
   var text=(string)t;
   if(text.IndexOf('<')>=0||text.IndexOf('>')>=0)throw new FormatException("Marked-up quest text: "+text);
   return text;
  }
  static string Chat(string text)=>text.Length<=ChatterContent.MaxLine?text:throw new FormatException("Line too long: "+text);
  static string[] Lines(JToken t){var lines=(t as JArray??throw new FormatException("Missing lines")).Select(v=>Chat(Text(v))).ToArray();if(lines.Length==0)throw new FormatException("Empty lines");return lines;}
 }
}
