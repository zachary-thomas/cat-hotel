using Newtonsoft.Json.Linq;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Poses the Life play view for screenshots (tools/unity-bridge.ps1 capture -Filter life:pie|life:chat|life:walk).
 public static class LifeAcceptance {
  public static string Pose(HotelApp app,string scene){
   var m=app.Model;
   if(m.State.currentHotel!=0){var travel=m.Travel(0);if(!travel.success)return "Could not travel to Meadow: "+travel.message;}
   if(scene.StartsWith("walls-")){app.World.SetWallMode(scene.Substring(6));app.UI.Navigate("Build");return "Build with walls "+app.World.WallMode;}
   if(scene=="paint"){
    // Paints each walled ground-floor room a different swatch and tints a few furnishings, then opens the paint tool.
    var walls=new[]{"rose","mint","sky","buttercream","lilac","cocoa","moss"};var floors=new[]{"walnut","maple","cherry","ash","sage","slate","blush"};int n=0;
    foreach(var r in m.State.rooms.Where(r=>r.floor==0&&Paint.HasWalls(r)).ToList()){m.Execute("paint_room",new JObject{{"id",r.id},{"surface","wall"},{"paint",walls[n%walls.Length]}});m.Execute("paint_room",new JObject{{"id",r.id},{"surface","floor"},{"paint",floors[n%floors.Length]}});n++;}
    int t=0;foreach(var o in m.State.objects.Where(o=>o.floor==0).Take(8).ToList())m.Execute("tint_object",new JObject{{"id",o.id},{"tint",1+t++%4}});
    app.World.SetWallMode(VoxelWorld.WallsUp);app.UI.Navigate("Build");app.UI.BeginPaint();return "Painted "+n+" rooms";
   }
   if(scene=="designs"||scene=="vibe"){
    var room=m.State.rooms.Where(r=>r.floor==0&&Paint.HasWalls(r)).OrderByDescending(r=>m.RoomObjects(r).Count()).First();
    if(scene=="vibe"){app.UI.Navigate("Build");app.UI.SelectRoom(room.id);return m.Vibe(room.id).Line;}
    if(m.State.blueprints.Count==0)m.SaveBlueprint(room.id);app.UI.ShowDesigns();return m.State.blueprints.Count+" designs";
   }
   if(scene=="neighbors"){app.UI.ShowNeighbors();return "Neighbors page";}
   if(scene=="plan"){var t=m.Hotel(0).town;t.plazaEvent="";t.plazaRemaining=0;t.plazaAttendees.Clear();t.plazaDay=0;m.State.elapsed+=((1100-m.Clock.minute)%1440+1440)%1440;app.UI.ShowEvents();return "Event plan";}
   if(scene.StartsWith("event-")){
    // An event in full swing: the right hour, the manager in the middle of the square, a little Buzz already.
    var e=PlazaContent.Current.Find(scene.Substring(6));if(e==null)return "Unknown event";
    float minute=e.from+30;m.State.elapsed+=((minute-m.Clock.minute)%HotelClock.DayLengthSeconds+HotelClock.DayLengthSeconds)%HotelClock.DayLengthSeconds;
    var t=m.Hotel(0).town;t.plazaDay=0;t.plazaEvent="";t.plazaRemaining=0;t.plazaAttendees.Clear();t.eventRemaining=0;
    var square=TownContent.Current.Point("square");t.phase="street";t.floor=0;t.shop="";t.destination="";t.x=square.x;t.z=square.z;
    m.State.coins=System.Math.Max(m.State.coins,500);
    var hosted=m.HostEvent(e.id);app.UI.Navigate("Life");app.World.FollowManager(true);
    return hosted.message;
   }
   if(scene=="rumor"||scene=="found"){
    var town=m.Hotel(0).town;town.rumorSpot=scene=="rumor"?"old_oak":"hilltop";town.rumorFind=scene=="rumor"?"lost_item":"kitten";town.rumorGiver="dot";town.rumorDay=m.Clock.day;
    app.UI.Navigate("Life");
    if(scene=="rumor"){var go=m.OrderManagerSearch();app.World.FollowManager(true);return go.message;}
    var hill=TownContent.Current.Point("hilltop");town.phase="street";town.floor=0;town.shop="";town.destination="";town.x=hill.x;town.z=hill.z;
    var found=m.FindRumor();app.World.FollowManager(true);if(found.success)app.UI.ShowFound(found.message);return found.message;
   }
   app.UI.Navigate("Life");
   if(scene.StartsWith("neighbor")||scene=="tier"){
    // Mid-morning, when Marmalade is at the square; the manager stands beside her.
    float minute=600;m.State.elapsed+=((minute-m.Clock.minute)%HotelClock.DayLengthSeconds+HotelClock.DayLengthSeconds)%HotelClock.DayLengthSeconds;
    var square=TownContent.Current.Point("square");var street=m.Hotel(0).town;street.phase="street";street.floor=0;street.shop="";street.destination="";var bench=TownContent.Current.Point("bench_east");street.x=square.x+(bench.x-square.x)*.2f;street.z=square.z+(bench.z-square.z)*.2f; // on the square-bench link, a step from her
    app.World.FollowManager(true);
    if(scene=="neighbor-pie"){app.UI.LifeNeighborTapped("marmalade",Vector2.zero);return "Pie menu on Marmalade";}
    if(scene=="tier"){var record=m.Hotel(0).neighbors.Find(x=>x.id=="marmalade");if(record==null){record=new NeighborState{id="marmalade"};m.Hotel(0).neighbors.Add(record);}record.friendship=14;record.tier=0;record.chatsToday=0;}
    var begun=m.BeginNeighborChat("marmalade");if(!begun.success)return begun.message;
    if(scene=="neighbor")return "Chatting with Marmalade";
    var n=NeighborContent.Current.Find("marmalade");var topic=m.CurrentChat.topics.First(t=>n.Reaction(t)!="dislike");
    return m.Talk(topic).message;
   }
   var guest=m.Actors.Where(a=>a.kind==ActorKind.Guest&&a.checkedIn&&a.action!="sleep").OrderBy(a=>a.catId).FirstOrDefault()??m.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest);
   if(scene=="walk"){var r=m.OrderManagerWalk(new LotPoint(-1.25f,-1.25f));app.World.FollowManager(true);return r.message;}
   if(guest==null)return "No guests yet.";
   if(scene=="pie"){app.World.FollowManager(false);app.UI.LifeCatTapped(guest.catId,Vector2.zero);return "Pie menu on "+guest.name;}
   if(scene=="chat"){
    // Stand the manager beside the guest, as if it had walked over.
    var t=m.Hotel(0).town;t.phase="hotel";t.destination="";t.shop="";t.floor=guest.floor;t.x=guest.x+.9f;t.z=guest.z+.3f;
    var r=m.BeginChat(guest.catId);app.World.FollowManager(true);
    return r.success?"Chatting with "+guest.name:r.message;
   }
   if(scene=="reply"){
    var t=m.Hotel(0).town;t.phase="hotel";t.destination="";t.shop="";t.floor=guest.floor;t.x=guest.x+.9f;t.z=guest.z+.3f;
    var r=m.BeginChat(guest.catId);if(!r.success)return r.message;
    app.World.FollowManager(true);var topic=m.CurrentChat.topics.FirstOrDefault();
    return topic==null?"No topics.":m.Talk(topic).message;
   }
   return "Unknown life scene "+scene;
  }
 }
}
