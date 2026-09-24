using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
 // Meadow neighbors from Resources/Content/Neighbors.json. Load after TownContent and ChatterContent so places
 // and topics can be checked against them.
 public sealed class NeighborContent
 {
  public sealed class Gift{public string id,name;public double price;}
  public sealed class Slot{public float minute;public string place;}
  public sealed class Neighbor
  {
   public string id,name,personality,coat,markings,home,favoriteGift,friendGift,bestGift,love,dislike;
   public int introduces;
   public string[] like=Array.Empty<string>();
   public Slot[] schedule=Array.Empty<Slot>();
   public readonly Dictionary<string,string[]> topics=new Dictionary<string,string[]>(StringComparer.Ordinal);
   public string[] greeting,signoff,chattedOut,tierUp,giftLove,giftOk;
   public string Reaction(string topic)=>love==topic?"love":dislike==topic?"dislike":like.Contains(topic)?"like":"meh";
  }
  public static NeighborContent Current{get;private set;}
  public Neighbor[] Neighbors{get;private set;}=Array.Empty<Neighbor>();
  public Gift[] Gifts{get;private set;}=Array.Empty<Gift>();
  public Neighbor Find(string id)=>id==null?null:Array.Find(Neighbors,n=>n.id==id);
  public Gift FindGift(string id)=>id==null?null:Array.Find(Gifts,g=>g.id==id);

  public static NeighborContent LoadJson(string json)
  {
   var root=JObject.Parse(json);
   if((int?)root["schema"]!=1)throw new FormatException("Expected neighbor schema 1");
   var c=new NeighborContent();
   c.Gifts=(root["gifts"] as JArray??throw new FormatException("Missing gifts")).Select(g=>new Gift{id=Text(g["id"],"gift id"),name=Text(g["name"],"gift name"),price=(double?)g["price"]??-1}).ToArray();
   if(c.Gifts.Any(g=>g.price<=0||double.IsNaN(g.price)||double.IsInfinity(g.price))||c.Gifts.Select(g=>g.id).Distinct().Count()!=c.Gifts.Length)throw new FormatException("Invalid gifts");
   var town=TownContent.Current;var chatter=ChatterContent.Current;
   var list=new List<Neighbor>();
   foreach(var t in root["neighbors"] as JArray??throw new FormatException("Missing neighbors"))
   {
    var likes=t["likes"] as JObject??throw new FormatException("Missing likes");
    var n=new Neighbor{id=Text(t["id"],"id"),name=Line(Text(t["name"],"name")),personality=Text(t["personality"],"personality"),coat=Text(t["coat"],"coat"),markings=Text(t["markings"],"markings"),
     home=Text(t["home"],"home"),favoriteGift=Text(t["favoriteGift"],"favoriteGift"),friendGift=Text(t["friendGift"],"friendGift"),bestGift=Text(t["bestGift"],"bestGift"),
     introduces=(int?)t["introduces"]??-1,love=Text(likes["love"],"love"),dislike=Text(likes["dislike"],"dislike"),
     like=(likes["like"] as JArray??throw new FormatException("Missing like")).Select(v=>Text(v,"like")).ToArray()};
    n.schedule=(t["schedule"] as JArray??throw new FormatException("Missing schedule")).Select(s=>s is JArray pair&&pair.Count==2?new Slot{minute=(float?)pair[0]??-1,place=Text(pair[1],"place")}:throw new FormatException("Invalid slot")).ToArray();
    if(n.schedule.Length<2||n.schedule.Any(s=>s.minute<0||s.minute>=HotelClock.DayLengthSeconds)||n.schedule.Zip(n.schedule.Skip(1),(a,b)=>b.minute>a.minute).Any(ok=>!ok))throw new FormatException("Schedule for "+n.id+" must be two or more rising minutes");
    if(!n.schedule.Any(s=>s.place==n.home))throw new FormatException(n.id+" never goes home");
    if(town!=null&&n.schedule.Any(s=>!town.IsStreetTarget(s.place)))throw new FormatException(n.id+" visits a place off Main Street");
    if(town!=null&&(!town.HasCoat(n.coat)||!town.HasMarkings(n.markings)))throw new FormatException(n.id+" needs a known coat and markings");
    if(n.introduces<0||n.introduces>=18)throw new FormatException(n.id+" must introduce a guest cat");
    if(c.FindGift(n.favoriteGift)==null)throw new FormatException(n.id+" has an unknown favorite gift");
    var topicIds=chatter?.TopicIds.ToArray();
    var reactions=new[]{n.love,n.dislike}.Concat(n.like).ToArray();
    if(reactions.Distinct().Count()!=reactions.Length||topicIds!=null&&reactions.Any(r=>!topicIds.Contains(r)))throw new FormatException(n.id+" has invalid likes");
    foreach(var p in (t["topics"] as JObject??throw new FormatException("Missing topics")).Properties())n.topics[p.Name]=Lines(p.Value,"topic "+p.Name);
    if(topicIds!=null&&topicIds.Any(id=>!n.topics.ContainsKey(id)))throw new FormatException(n.id+" needs lines for every topic");
    n.greeting=Lines(t["greeting"],"greeting");n.signoff=Lines(t["signoff"],"signoff");n.chattedOut=Lines(t["chattedOut"],"chattedOut");
    n.tierUp=Lines(t["tierUp"],"tierUp");n.giftLove=Lines(t["giftLove"],"giftLove");n.giftOk=Lines(t["giftOk"],"giftOk");
    if(n.tierUp.Length!=3)throw new FormatException(n.id+" needs three tier-up lines");
    list.Add(n);
   }
   if(list.Count==0||list.Select(n=>n.id).Distinct().Count()!=list.Count)throw new FormatException("Neighbors need distinct ids");
   c.Neighbors=list.ToArray();
   Current=c;
   return c;
  }
  static string Text(JToken t,string field)
  {
   if(t==null||t.Type!=JTokenType.String||string.IsNullOrWhiteSpace((string)t))throw new FormatException("Missing "+field);
   return (string)t;
  }
  static string Line(string text)
  {
   if(text.Length>ChatterContent.MaxLine||text.IndexOf('<')>=0||text.IndexOf('>')>=0)throw new FormatException("Line too long or marked up: "+text);
   return text;
  }
  static string[] Lines(JToken t,string field)
  {
   var lines=(t as JArray??throw new FormatException("Missing "+field)).Select(v=>Line(Text(v,field))).ToArray();
   if(lines.Length==0)throw new FormatException("Empty "+field);
   return lines;
  }
 }
}
