using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
 // Conversation lines come from Resources/Content/Chatter.json. Presentation loads the text; tests read the file directly.
 public sealed class ChatterContent
 {
  public const int MaxLine=80;
  public static readonly string[] Reactions={"love","like","meh","dislike"};
  public sealed class Topic{public string id,label,icon;}
  public sealed class Line{public string who,preference,topic,reaction,text;}
  sealed class Likes{public string love,dislike;public string[] like;}
  public static ChatterContent Current{get;private set;}
  public Topic[] Topics{get;private set;}=Array.Empty<Topic>();
  public IEnumerable<string> TopicIds=>Topics.Select(t=>t.id);
  public IEnumerable<string> Preferences=>likes.Keys;
  readonly Dictionary<string,Likes> likes=new Dictionary<string,Likes>(StringComparer.Ordinal);
  readonly Dictionary<string,string[]> pools=new Dictionary<string,string[]>(StringComparer.Ordinal);
  readonly List<Line> lines=new List<Line>();
  public IReadOnlyList<Line> Lines=>lines;
  public Topic FindTopic(string id)=>Array.Find(Topics,t=>t.id==id);
  public bool HasTopic(string id)=>FindTopic(id)!=null;
  public bool HasPool(string id)=>id!=null&&pools.ContainsKey(id);

  public string Reaction(string preference,string topic)
  {
   if(preference==null||!likes.TryGetValue(preference,out var l))return "meh";
   return l.love==topic?"love":l.dislike==topic?"dislike":l.like.Contains(topic)?"like":"meh";
  }
  // Specific lines for this speaker and preference join the shared pool, so overrides add flavor without replacing it.
  public string Pick(string who,string preference,string topic,string reaction,uint hash)
  {
   var options=lines.Where(l=>l.topic==topic&&l.reaction==reaction&&(l.who==who&&(l.preference==null||l.preference==preference))).ToArray();
   if(options.Length==0)options=lines.Where(l=>l.who=="guest"&&l.preference==null&&l.topic==topic&&l.reaction==reaction).ToArray();
   return options.Length==0?"...":options[hash%(uint)options.Length].text;
  }
  public string Pool(string id,uint hash)=>pools.TryGetValue(id,out var p)&&p.Length>0?p[hash%(uint)p.Length]:"...";

  public static ChatterContent LoadJson(string json)
  {
   var root=JObject.Parse(json);
   if((int?)root["schema"]!=1)throw new FormatException("Expected chatter schema 1");
   var c=new ChatterContent();
   c.Topics=(root["topics"] as JArray??throw new FormatException("Missing topics")).Select(t=>new Topic{id=Text(t["id"],"topic id"),label=Text(t["label"],"topic label"),icon=Text(t["icon"],"topic icon")}).ToArray();
   if(c.Topics.Length<3||c.Topics.Select(t=>t.id).Distinct().Count()!=c.Topics.Length)throw new FormatException("Chatter needs at least three distinct topics");
   foreach(var p in (root["guestLikes"] as JObject??throw new FormatException("Missing guestLikes")).Properties())
   {
    var l=new Likes{love=Text(p.Value["love"],"love"),dislike=Text(p.Value["dislike"],"dislike"),like=(p.Value["like"] as JArray??throw new FormatException("Missing like")).Select(v=>Text(v,"like")).ToArray()};
    var all=new[]{l.love,l.dislike}.Concat(l.like).ToArray();
    if(all.Any(t=>!c.HasTopic(t))||all.Distinct().Count()!=all.Length)throw new FormatException("Invalid likes for "+p.Name);
    c.likes[p.Name]=l;
   }
   foreach(var p in (root["pools"] as JObject??throw new FormatException("Missing pools")).Properties())
   {
    var texts=(p.Value as JArray??throw new FormatException("Pool "+p.Name+" must be a list")).Select(v=>Checked(Text(v,"pool line"))).ToArray();
    if(texts.Length==0)throw new FormatException("Empty pool "+p.Name);
    c.pools[p.Name]=texts;
   }
   foreach(string needed in new[]{"greeting","signoff","busy","chattedOut"})if(!c.pools.ContainsKey(needed))throw new FormatException("Missing pool "+needed);
   foreach(var t in root["lines"] as JArray??throw new FormatException("Missing lines"))
   {
    var line=new Line{who=Text(t["who"],"who"),preference=(string)t["preference"],topic=Text(t["topic"],"topic"),reaction=Text(t["reaction"],"reaction"),text=Checked(Text(t["text"],"text"))};
    if(!c.HasTopic(line.topic)||!Reactions.Contains(line.reaction)||line.preference!=null&&!c.likes.ContainsKey(line.preference))throw new FormatException("Invalid line: "+line.text);
    c.lines.Add(line);
   }
   foreach(var topic in c.Topics)foreach(var reaction in Reactions)
    if(!c.lines.Any(l=>l.who=="guest"&&l.preference==null&&l.topic==topic.id&&l.reaction==reaction))throw new FormatException("Missing guest lines for "+topic.id+"/"+reaction);
   Current=c;
   return c;
  }
  static string Text(JToken t,string field)
  {
   if(t==null||t.Type!=JTokenType.String||string.IsNullOrWhiteSpace((string)t))throw new FormatException("Missing "+field);
   return (string)t;
  }
  // Lines must fit two bubble rows at the smallest phone width; rich-text tags would break the plain-text bubble.
  static string Checked(string text)
  {
   if(text.Length>MaxLine||text.IndexOf('<')>=0||text.IndexOf('>')>=0)throw new FormatException("Line too long or marked up: "+text);
   return text;
  }
 }
}
