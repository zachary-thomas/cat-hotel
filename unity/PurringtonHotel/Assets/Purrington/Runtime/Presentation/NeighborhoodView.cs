using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
 public sealed class NeighborhoodView
 {
  public readonly Transform Root;
  readonly List<Walker> walkers=new List<Walker>();
  HotelModel model;
  const float VisitSpeed=1.62f;
  sealed class Walker
  {
   public GodotCatRig rig;
   public Vector2 start,finish,lastVisitorPosition,entryTarget;
   public float length,distance,speed,turn,turnFrom;
   public int direction,waypoint,routeRevision;
   public string visitorId;
   public bool entering,returning,inside,returnBlocked;
   public readonly List<Vector2> transit=new List<Vector2>();
  }

  public NeighborhoodView(GodotGeometry geometry,Transform parent,int map)
  {
   Root=new GameObject("Independent neighborhood "+map).transform;
   Root.SetParent(parent,false);
   geometry.Build(Root,(JObject)geometry.Map(map)["neighborhood"]);
   int[] routeIndices=map==0?new[]{0,1,1,2,3,4,4,5,1,4}:new[]{0,1,2,3,4,5};
   var routeUses=new Dictionary<int,int>();
   for(int i=0;i<routeIndices.Length;i++)
   {
    int routeIndex=routeIndices[i];
    var route=geometry.Map(map)["routes"][routeIndex];
    int lane=routeUses.TryGetValue(routeIndex,out int used)?used:0;
    routeUses[routeIndex]=lane+1;
    // Each additional cat gets its own parallel walking lane, so opposing
    // walkers and faster cats cannot run through one another on shared routes.
    float offset=lane*.85f;
    var walker=new Walker{
     rig=new GodotCatRig(geometry,Root,"neighbors",(i%6).ToString(),i+30),
     start=new Vector2((float)route["start"][0],(float)route["start"][1]+offset),
     finish=new Vector2((float)route["finish"][0],(float)route["finish"][1]+offset),
     length=(float)route["length"],speed=.52f+i%3*.025f,direction=i<3?1:-1
    };
    float ratio=map==0?new[]{.47f,.2f,.5f,.36f,.58f,.2f,.5f,.65f,.8f,.8f}[i]:new[]{.47f,.28f,.36f,.58f,.76f,.65f}[i];
    walker.distance=walker.length*ratio;
    // Keep the street and hotel renderings identical at the handoff.
    walker.rig.Root.localScale=Vector3.one*.83f;
    Place(walker);
    walkers.Add(walker);
   }
  }

  static Vector2 Position(Walker walker)
  {
   var point=walker.rig.Root.localPosition;
   return new Vector2(point.x/VoxelWorld.Unit,point.z/VoxelWorld.Unit);
  }

  static void Place(Walker walker)
  {
   var point=Vector2.Lerp(walker.start,walker.finish,walker.distance/walker.length);
   walker.rig.Root.localPosition=new Vector3(point.x*VoxelWorld.Unit,.18f,point.y*VoxelWorld.Unit);
   walker.rig.Root.localRotation=Quaternion.Euler(0,walker.direction>0?90:-90,0);
  }

  public bool IsVisitorVisible(int index)
  {
   return index<0||index>=walkers.Count||walkers[index].inside;
  }

  // Call before synchronizing world actor rigs. The street rig stays visible
  // through entry; only one rig is visible at either side of the handoff.
  public void SetVisitors(HotelModel hotel)
  {
   model=hotel;
   var visitors=hotel.Actors.Where(a=>a.kind==ActorKind.DayVisitor).ToArray();
   for(int i=0;i<walkers.Count;i++)
   {
    var walker=walkers[i];
    var visitor=visitors.FirstOrDefault(a=>a.visitorIndex==i);
    if(visitor!=null)
    {
     // A cat with no safe way back to the sidewalk remains in place until a
     // layout edit opens a route; it cannot be reused for another visit yet.
     if(walker.returnBlocked){hotel.CancelVisitorEntry(i);continue;}
     walker.lastVisitorPosition=new Vector2(visitor.x,visitor.z);
     if(walker.visitorId!=visitor.id)
     {
      walker.visitorId=visitor.id;
      walker.returning=false;
      walker.inside=false;
      if(visitor.phase=="enter")
      {
       if(!BeginEntry(walker,visitor)){AbandonEntry(walker,i);continue;}
      }
      else walker.inside=true; // Already inside when a destination view is rebuilt.
     }
     if(visitor.phase=="enter"&&walker.entering)
     {
      var target=new Vector2(visitor.x,visitor.z);
      if((walker.routeRevision!=hotel.Revision||(target-walker.entryTarget).sqrMagnitude>.0001f)&&!BeginEntry(walker,visitor))
      {AbandonEntry(walker,i);continue;}
      // Keep the domain actor parked until this actual street journey finishes.
      if(walker.waypoint<walker.transit.Count)hotel.ExtendVisitorEntry(i,.35f);
     }
     else
     {
      walker.entering=false;
      walker.inside=true;
     }
     walker.rig.Root.gameObject.SetActive(!walker.inside);
    }
    else if(walker.visitorId!=null)
    {
     walker.visitorId=null;
     if(walker.inside)BeginReturn(walker);
     else if(walker.entering)ReturnToSidewalk(walker);
     walker.inside=false;
     walker.entering=false;
     walker.rig.Root.gameObject.SetActive(true);
    }
   }
  }

  bool BeginEntry(Walker walker,ActorSnapshot visitor)
  {
   var planned=new List<Vector2>();
   var position=Position(walker);
   var entrance=model.VisitorEntrance;
   var origin=new LotPoint(position.x,position.y);
   // Outside the lot, stay on the central street corridor until the gateway.
   // Once inside, re-route from the actual rendered position, never from the
   // original entrance or the hidden actor's newly relocated destination.
   if(!InBase(position))
   {
    planned.Add(new Vector2(entrance.x-.45f,walker.start.y));
    origin=entrance;
   }
   var target=new Vector2(visitor.x,visitor.z);
   var route=model.ActivityRoute(origin,new LotPoint(target.x,target.y));
   if(route.Count==0)return false;
   planned.AddRange(route.Select(p=>new Vector2(p.x,p.z)));
   planned.Add(target);
   if(!SafeRoute(position,planned))return false;
   walker.entering=true;
   walker.returning=walker.returnBlocked=false;
   walker.transit.Clear();walker.transit.AddRange(planned);
   walker.waypoint=0;walker.turn=0;
   walker.entryTarget=target;walker.routeRevision=model.Revision;
   float length=0;
   var previous=position;
   foreach(var point in walker.transit){length+=Vector2.Distance(previous,point);previous=point;}
   model.ExtendVisitorEntry(visitor.visitorIndex,length/VisitSpeed+.2f);
   walker.rig.Root.gameObject.SetActive(true);
   return true;
  }

  void AbandonEntry(Walker walker,int index)
  {
   model.CancelVisitorEntry(index);
   walker.visitorId=null;
   walker.entering=walker.inside=false;
   ReturnToSidewalk(walker);
   walker.rig.Root.gameObject.SetActive(true);
  }

  void BeginReturn(Walker walker)
  {
   walker.rig.Root.localPosition=new Vector3(walker.lastVisitorPosition.x*VoxelWorld.Unit,.18f,walker.lastVisitorPosition.y*VoxelWorld.Unit);
   walker.turn=0;
   ReturnToSidewalk(walker);
  }

  void ReturnToSidewalk(Walker walker)
  {
   walker.transit.Clear();
   walker.waypoint=0;
   walker.returning=true;
   walker.routeRevision=model.Revision;
   var position=Position(walker);
   if(InBase(position))
   {
    var route=model.ActivityRoute(new LotPoint(position.x,position.y),model.VisitorEntrance);
    walker.transit.AddRange(route.Select(p=>new Vector2(p.x,p.z)));
    if(route.Count==0){walker.returnBlocked=true;return;}
    walker.transit.Add(new Vector2(model.VisitorEntrance.x+.45f,walker.start.y));
   }
   else walker.transit.Add(new Vector2(Mathf.Clamp(position.x,walker.start.x,walker.finish.x),walker.start.y));
   walker.returnBlocked=!SafeRoute(position,walker.transit);
   if(walker.returnBlocked)walker.transit.Clear();
  }

  bool InBase(Vector2 position)
  {
   var bounds=model.Map()["base"];
   return position.x>=(float)bounds[0]&&position.x<(float)bounds[0]+(float)bounds[2]&&position.y>=(float)bounds[1]&&position.y<(float)bounds[1]+(float)bounds[3];
  }

  bool SafeRoute(Vector2 position,IEnumerable<Vector2> points)
  {
   foreach(var next in points){if(!SafeLotStep(position,next))return false;position=next;}
   return true;
  }

  // Street travel is outside the navigation graph. Clip only the portion in
  // the owned base, then check it against current walls/furniture/navigation.
  bool SafeLotStep(Vector2 from,Vector2 to)
  {
   var bounds=model.Map()["base"];
   float enter=0,leave=1;
   var delta=to-from;
   if(!ClipAxis(from.x,delta.x,(float)bounds[0]+.001f,(float)bounds[0]+(float)bounds[2]-.001f,ref enter,ref leave)||
      !ClipAxis(from.y,delta.y,(float)bounds[1]+.001f,(float)bounds[1]+(float)bounds[3]-.001f,ref enter,ref leave))return true;
   var start=from+delta*enter;var end=from+delta*leave;
   return model.MovementSegmentClear(new LotPoint(start.x,start.y),new LotPoint(end.x,end.y),false);
  }

  static bool ClipAxis(float origin,float delta,float min,float max,ref float enter,ref float leave)
  {
   if(Mathf.Abs(delta)<.000001f)return origin>=min&&origin<=max;
   float a=(min-origin)/delta,b=(max-origin)/delta;
   enter=Mathf.Max(enter,Mathf.Min(a,b));leave=Mathf.Min(leave,Mathf.Max(a,b));
   return enter<=leave;
  }

  bool AdvanceTransit(Walker walker,float delta,bool motion)
  {
   float remaining=delta*VisitSpeed;
   while(remaining>0&&walker.waypoint<walker.transit.Count)
   {
    var position=Position(walker);
    var target=walker.transit[walker.waypoint];
    float gap=Vector2.Distance(position,target);
    if(gap<.001f){walker.waypoint++;continue;}
    float step=Mathf.Min(gap,remaining);
    var next=Vector2.MoveTowards(position,target,step);
    if(!ClearStep(walker,position,next))break;
    walker.rig.Root.localPosition=new Vector3(next.x*VoxelWorld.Unit,.18f,next.y*VoxelWorld.Unit);
    var direction=(target-position).normalized;
    walker.rig.Root.localRotation=Quaternion.Euler(0,Mathf.Atan2(direction.x,direction.y)*Mathf.Rad2Deg,0);
    remaining-=step;
    if(step>=gap-.001f)walker.waypoint++;
   }
   bool walking=walker.waypoint<walker.transit.Count;
   walker.rig.Advance(delta,motion,walking?"walk":"rest",walking);
   if(!walking&&walker.returning)
   {
    walker.returning=false;
    walker.distance=Mathf.Clamp(Position(walker).x-walker.start.x,0,walker.length);
    walker.direction=walker.distance<walker.length*.5f?1:-1;
    Place(walker);
   }
   return walking;
  }

  bool ClearStep(Walker walker,Vector2 from,Vector2 to)
  {
   var segment=to-from;
   float squared=segment.sqrMagnitude;
   foreach(var other in walkers)
   {
    if(other==walker||!other.rig.Root.gameObject.activeSelf)continue;
    var point=Position(other);
    float initialDistance=Vector2.Distance(point,from);
    if(initialDistance<.74f&&Vector2.Distance(point,to)>initialDistance+.00001f)continue;
    float along=squared>.000001f?Mathf.Clamp01(Vector2.Dot(point-from,segment)/squared):0;
    if(Vector2.Distance(point,from+segment*along)<.74f)return false;
   }
   return true;
  }

  public void Advance(float delta,bool motion)
  {
   foreach(var walker in walkers)
   {
    if(!walker.rig.Root.gameObject.activeSelf)continue;
    if(walker.returning&&walker.routeRevision!=model.Revision)ReturnToSidewalk(walker);
    if(walker.returnBlocked)
    {
     if(walker.routeRevision!=model.Revision)ReturnToSidewalk(walker);
     if(walker.returnBlocked){walker.rig.Advance(delta,motion,"rest",false);continue;}
    }
    if(walker.entering||walker.returning){AdvanceTransit(walker,delta,motion);continue;}
    if(!motion)continue;
    float remaining=delta;
    while(remaining>.00001f)
    {
     float step;
     if(walker.turn>.00001f)
     {
      step=Mathf.Min(remaining,walker.turn);
      walker.turn=Mathf.Max(0,walker.turn-step);
      float t=1-walker.turn/1.6f;
      walker.rig.Root.localRotation=Quaternion.Euler(0,(walker.turnFrom+Mathf.PI*Mathf.SmoothStep(0,1,t))*Mathf.Rad2Deg,0);
      walker.rig.Advance(step,true,"sniff",false);
     }
     else
     {
      float toEnd=walker.direction>0?walker.length-walker.distance:walker.distance;
      step=Mathf.Min(remaining,toEnd/walker.speed);
      float nextDistance=Mathf.Clamp(walker.distance+walker.direction*walker.speed*step,0,walker.length);
      var next=Vector2.Lerp(walker.start,walker.finish,nextDistance/walker.length);
      if(!ClearStep(walker,Position(walker),next)){walker.rig.Advance(remaining,true,"sniff",false);break;}
      walker.distance=nextDistance;
      Place(walker);
      walker.rig.Advance(step,true,"walk",true);
      if(step>=toEnd/walker.speed-.00001f)
      {
       walker.turnFrom=walker.direction>0?Mathf.PI/2:-Mathf.PI/2;
       walker.direction=-walker.direction;
       walker.turn=1.6f;
      }
     }
     remaining-=step;
    }
   }
  }
 }
}
