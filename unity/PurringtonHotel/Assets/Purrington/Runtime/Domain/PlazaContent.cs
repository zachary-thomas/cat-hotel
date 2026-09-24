using System;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
 // Plaza events at Meadow from Resources/Content/Events.json. Load after ChatterContent and the catalog.
 public sealed class PlazaContent
 {
  public sealed class Event
  {
   public string id,name,topic,goldItem,pitch,gold;
   public double price;
   public float from,to,duration;
   public string[] greeting=Array.Empty<string>();
   public bool OpenAt(float minute)=>minute>=from&&minute<to;
  }
  public static PlazaContent Current{get;private set;}
  public Event[] Events{get;private set;}=Array.Empty<Event>();
  public Event Find(string id)=>id==null?null:Array.Find(Events,e=>e.id==id);

  public static PlazaContent LoadJson(string json)
  {
   var root=JObject.Parse(json);
   if((int?)root["schema"]!=1)throw new FormatException("Expected events schema 1");
   var c=new PlazaContent();
   c.Events=(root["events"] as JArray??throw new FormatException("Missing events")).Select(e=>new Event{
    id=Text(e["id"]),name=Text(e["name"]),topic=Text(e["topic"]),goldItem=Text(e["goldItem"]),pitch=Text(e["pitch"]),gold=Text(e["gold"]),
    price=(double?)e["price"]??-1,from=(float?)e["from"]??-1,to=(float?)e["to"]??-1,duration=(float?)e["duration"]??-1,
    greeting=(e["greeting"] as JArray??new JArray()).Select(Text).ToArray()}).ToArray();
   if(c.Events.Length==0||c.Events.Select(e=>e.id).Distinct().Count()!=c.Events.Length)throw new FormatException("Events need distinct ids");
   foreach(var e in c.Events)
   {
    if(e.price<=0||e.from<0||e.to>HotelClock.DayLengthSeconds||e.to<=e.from||e.duration<30||e.duration>600||e.greeting.Length==0)throw new FormatException("Invalid event "+e.id);
    if(ChatterContent.Current!=null&&!ChatterContent.Current.HasTopic(e.topic))throw new FormatException(e.id+" has an unknown topic");
    if(Catalog.All.Length>0&&Catalog.Find(e.goldItem)==null)throw new FormatException(e.id+" has an unknown gold item");
    if(e.greeting.Concat(new[]{e.pitch,e.gold}).Any(l=>l.Length>ChatterContent.MaxLine))throw new FormatException(e.id+" has a line that is too long");
   }
   Current=c;
   return c;
  }
  static string Text(JToken t)
  {
   if(t==null||t.Type!=JTokenType.String||string.IsNullOrWhiteSpace((string)t))throw new FormatException("Missing event text");
   var text=(string)t;
   if(text.IndexOf('<')>=0||text.IndexOf('>')>=0)throw new FormatException("Marked-up event text: "+text);
   return text;
  }
 }
}
