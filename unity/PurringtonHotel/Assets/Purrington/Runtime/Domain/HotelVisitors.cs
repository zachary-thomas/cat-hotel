using System;
using System.Linq;
using System.Collections.Generic;

namespace Purrington.Domain
{
 public sealed partial class HotelModel
 {
  float visitorClock;
  int visitorCursor;
  public int CompletedDayVisits { get; private set; }
  public int DayVisitorCount => actors.Count(a => a.view.kind == ActorKind.DayVisitor);
  // The renderer can extend this brief entry phase while its existing street
  // walker approaches. Headless simulation still advances without a renderer.
  public LotPoint VisitorEntrance => Arrival();
  public void ExtendVisitorEntry(int index,float seconds)
  {
   if(!Finite(seconds)||seconds<=0)return;
   var actor=actors.FirstOrDefault(a=>a.view.kind==ActorKind.DayVisitor&&a.view.visitorIndex==index&&a.phase=="enter");
   if(actor==null)return;
   actor.remaining=Math.Max(actor.remaining,Math.Min(seconds,60));
   actor.view.activityDuration=actor.view.activityElapsed+actor.remaining;
  }
  public void CancelVisitorEntry(int index)
  {
   var actor=actors.FirstOrDefault(a=>a.view.kind==ActorKind.DayVisitor&&a.view.visitorIndex==index&&a.phase=="enter");
   if(actor==null)return;
   Release(actor);
   actors.Remove(actor);
  }

  void TickVisitors(float seconds)
  {
   if (State.currentHotel != 0) return;
   if (VisitorsResting) return;
   visitorClock += seconds;
   float interval=7+(visitorCursor*7%6);
   if (visitorClock < interval || DayVisitorCount >= 3) return;
   visitorClock = 0;
   if (!Venues().Any(v => v.open && v.role == "bar")) return;
   var arrival = FreeArrival();
   if (!arrival.HasValue) return;
   // Only the central sidewalks connect to the hotel's entrance. Outer
   // neighborhood routes would force cats through houses and garden scenery.
   int index = new[]{1,2,8,5,6,9}[visitorCursor++ % 6];
   if (actors.Any(a => a.view.visitorIndex == index)) return;
   var visitor = new Actor { checkedIn = true, view = new ActorSnapshot {
    id = "visitor:" + index, catId = 100 + index, visitorIndex = index,
    kind = ActorKind.DayVisitor, role = "visitor",
    name = new[]{"Maple","Biscuit","Clover","Peaches","Olive","Toast","Pip","Hazel","Bean","Sunny"}[index],
    x = arrival.Value.x, z = arrival.Value.z
   }};
   actors.Add(visitor);
   Activity(visitor,"enter","arrive",2);
   visitor.view.intent="walking in from the neighborhood";
  }

  void ChooseVisitorCounter(Actor a)
  {
   foreach (var venue in Venues().Where(v => v.open && v.role == "bar")
    .OrderBy(v => a.Position.Distance(v.Point)))
   foreach (var slot in venue.slots)
   {
    var point = slot.Point;
    if (reservations.ContainsKey(slot.key) || !Free(point,a,true)) continue;
    var route = ActivityRoute(a.Position,point);
    if (route.Count == 0) continue;
    Reserve(a,venue,slot,route,false);
    a.view.intent = "visiting for a milkshake";
    return;
   }
   // Do not form an unbounded queue at a full or inaccessible counter.
   DepartVisitor(a);
  }

  void DepartVisitor(Actor a)
  {
   Release(a);a.view.venueId="";
   var route=ActivityRoute(a.Position,Arrival());
   if(route.Count==0){actors.Remove(a);return;}
   a.route=route;a.waypoint=0;
   Activity(a,"walk_depart","walk",0);
   a.view.intent="heading back to the neighborhood";
  }

  void AdvanceVisitor(Actor a,float dt)
  {
   if(a.stay>120){Release(a);actors.Remove(a);return;}
   if(a.stay>90 && a.phase!="walk_depart"){DepartVisitor(a);return;}
   if(a.phase.StartsWith("walk")){Walk(a,dt);return;}
   a.remaining-=dt;if(a.remaining>0)return;
   switch(a.phase)
   {
    case "enter":ChooseVisitorCounter(a);break;
    case "idle":ChooseVisitorCounter(a);break;
    case "order":Activity(a,"serve","wait",2.8f);break;
    case "serve":
     if(!FindSeat(a))Activity(a,"activity","drink",7.5f);
     break;
    case "sit":case "activity":CompletedDayVisits++;DepartVisitor(a);break;
    default:DepartVisitor(a);break;
   }
  }
 }
}
