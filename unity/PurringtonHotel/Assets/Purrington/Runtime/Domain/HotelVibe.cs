using System;
using System.Collections.Generic;
using System.Linq;
namespace Purrington.Domain {
// Room vibe (B3): how Cozy, Lively and Calm a room feels, 0-100 each, from its furnishings' tags, warm light, plants,
// crowding and paint. The strongest vibe names the room, with one tip to raise it. Guests whose preference matches a
// room's vibe favor its venues.
public sealed class RoomVibe {
 public int cozy,lively,calm;
 public string Top=>cozy>=lively&&cozy>=calm?"Cozy":lively>=calm?"Lively":"Calm";
 public int TopScore=>Math.Max(cozy,Math.Max(lively,calm));
 public int Of(string vibe)=>vibe=="Cozy"?cozy:vibe=="Lively"?lively:vibe=="Calm"?calm:0;
 public string tip="";
 public string Label=>TopScore==0?"No vibe yet":Top+" "+TopScore+"%";
 public string Line=>Label+(tip.Length>0?" · "+tip:"");
}
public sealed partial class HotelModel {
 readonly Dictionary<string,RoomVibe> vibeCache=new Dictionary<string,RoomVibe>();
 static readonly HashSet<string> WarmWalls=new HashSet<string>{"buttercream","rose","cocoa"},CoolWalls=new HashSet<string>{"sky","mint","lilac","moss"};
 static readonly HashSet<string> WarmFloors=new HashSet<string>{"maple","walnut","cherry","blush"},CoolFloors=new HashSet<string>{"ash","sage","slate"};
 static readonly HashSet<string> Plants=new HashSet<string>{"plant","shrub","garden_planter","flowers","flower_bed","tree"};
 public static string VibeFor(string preference)=>preference=="warm"?"Cozy":preference=="quiet"||preference=="sunny"?"Calm":"Lively";
 public IEnumerable<ObjectState> RoomObjects(RoomState r)=>Hotel().objects.Where(o=>o.floor==r.floor&&(o.room==r.id||InRoomCenter(r,o)));
 static bool InRoomCenter(RoomState r,ObjectState o){Size(o,out float w,out float d);return RoomHas(r,o.x+w/2,o.z+d/2);}
 public RoomVibe Vibe(string roomId){
  if(vibeCache.TryGetValue(roomId,out var cached))return cached;
  var r=Hotel().rooms.Find(v=>v.id==roomId);var vibe=r==null?new RoomVibe():Vibe(r,RoomObjects(r).ToList());
  vibeCache[roomId]=vibe;return vibe;
 }
 public static RoomVibe Vibe(RoomState r,IList<ObjectState> items){
  var v=new RoomVibe();if(r.kind=="stairs")return v;
  double cozy=0,lively=0,calm=0;int warm=0,social=0,play=0,plants=0,quiet=0;
  foreach(var o in items){
   var def=Catalog.Find(o.itemId);if(def==null)continue;var tags=def.tags??Array.Empty<string>();
   if(tags.Contains("warm")){cozy+=18;warm++;}
   if(tags.Contains("quiet")){cozy+=6;calm+=12;quiet++;}
   if(tags.Contains("social")){lively+=14;social++;}
   if(tags.Contains("play")){lively+=14;play++;}
   if(tags.Contains("food"))lively+=10;
   if(tags.Contains("explore"))lively+=6;
   if(tags.Contains("sunny"))calm+=8;
   if(Plants.Contains(def.id)){calm+=12;plants++;}
   if(def.role=="bed")cozy+=8;
  }
  if(WarmWalls.Contains(r.wallPaint))cozy+=10;if(CoolWalls.Contains(r.wallPaint))calm+=10;if(r.wallPaint=="sky"||r.wallPaint=="mint"||r.wallPaint=="buttercream")lively+=6;
  if(WarmFloors.Contains(r.floorPaint))cozy+=6;if(CoolFloors.Contains(r.floorPaint))calm+=6;
  // A finished room (walls and floor both chosen) feels intentional; mismatched tints and crowding take away calm.
  if(r.wallPaint.Length>0&&r.floorPaint.Length>0){cozy+=5;lively+=5;calm+=5;}
  if(items.Where(o=>o.tint>0).Select(o=>o.tint).Distinct().Count()>2)calm-=8;
  int area=Math.Max(1,PaintArea(r));double density=items.Count/(double)area;bool crowded=density>.35;
  if(crowded){double crowd=(density-.35)*120;cozy-=crowd*.5;calm-=crowd;lively+=crowd*.25;}
  v.cozy=Clamp(cozy);v.lively=Clamp(lively);v.calm=Clamp(calm);
  string top=v.Top;
  v.tip=crowded&&top!="Lively"?"clear some space":
   top=="Cozy"?(warm==0?"add a warm light":!WarmWalls.Contains(r.wallPaint)?"try warm paint":v.cozy<100?"add a blanket or a bed":""):
   top=="Lively"?(social==0?"add a seat for company":play==0?"add a toy":v.lively<100?"add a snack table":""):
   (plants==0?"add a plant":!CoolWalls.Contains(r.wallPaint)?"try cool paint":quiet==0?"add a rug":v.calm<100?"add something sunny":"");
  if(v.TopScore==0)v.tip=items.Count==0?"add some furniture":"";
  return v;
 }
 static int Clamp(double n)=>(int)Math.Max(0,Math.Min(100,Math.Round(n)));
 // Choice bonus for a guest: up to +2 when a venue's room matches the cat's preferred vibe. Only rooms the player has
 // painted count, so unstyled hotels choose exactly as before (and the Godot parity baseline holds).
 double VibeBonus(VenueSnapshot venue,string preference){if(string.IsNullOrEmpty(venue.room))return 0;var r=Hotel().rooms.Find(v=>v.id==venue.room);if(r==null||(r.wallPaint.Length==0&&r.floorPaint.Length==0))return 0;return Vibe(r.id).Of(VibeFor(preference))/50.0;}
}
}
