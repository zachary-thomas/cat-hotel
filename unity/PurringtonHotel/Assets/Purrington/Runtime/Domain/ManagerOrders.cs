using System;
using System.Collections.Generic;
using System.Linq;

namespace Purrington.Domain
{
 public enum ManagerOrderKind { Walk, Chat, Pet, Follow, ChatNeighbor, Search }
 public sealed class ManagerOrder
 {
  public ManagerOrderKind kind;
  public LotPoint point;
  public int catId=-1;
  public string neighbor;
  internal float elapsed;
 }
 // Orders the player gives the manager in Life. The queue is not saved: after a reload the manager simply
 // stands at its saved position. Walking inside the hotel keeps a planned path instead of re-planning every tick.
 public sealed partial class HotelModel
 {
  public const int ManagerQueueLimit=3;
  const float ChatReach=1.2f,FollowGap=1.6f,CatchUpSeconds=30,PersistSeconds=5;
  readonly List<ManagerOrder> managerOrders=new List<ManagerOrder>();
  readonly List<LotPoint> managerPath=new List<LotPoint>();
  readonly List<bool> managerPathStreet=new List<bool>();
  int managerStep,managerPathRevision=-1,managerSettledRevision=-1;
  float managerReplan,managerPersist;
  bool managerPathActive;
  LotPoint managerPathGoal;
  public event Action<int,string> ManagerReachedCat;
  public event Action<string> ManagerOrderFailed;
  public IReadOnlyList<ManagerOrder> ManagerOrders=>managerOrders.AsReadOnly();
  public bool ManagerOrdersPaused{get;private set;}
  public LotPoint ManagerPosition{get{var t=Hotel(0).town;return new LotPoint(t.x,t.z,t.phase=="hotel"?t.floor:0);}}
  public bool ManagerWalking=>State.currentHotel==0&&(!string.IsNullOrEmpty(Hotel(0).town.destination)||managerPathActive&&!ManagerOrdersPaused&&managerStep<managerPath.Count);
  public bool ManagerInHotel=>Hotel(0).town.phase=="hotel";

  LotPoint ManagerExit()
  {
   var gate=TownContent.Current.Point("hotel_gate");var bounds=Map(0)["base"];
   return new LotPoint((float)Math.Floor(gate.x*2)*.5f+.25f,(float)bounds[1]+(float)bounds[3]-.25f);
  }
  Actor GuestActor(int catId)=>actors.Find(a=>a.view.kind==ActorKind.Guest&&a.view.catId==catId);
  CommandResult MeadowOnly()=>State.currentHotel!=0||TownContent.Current==null?CommandResult.Fail("Choose a Meadow destination."):null;

  public CommandResult OrderManagerWalk(LotPoint point)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   if(!Finite(point.x)||!Finite(point.z))return CommandResult.Fail("Can't get there from here.");
   var plan=PlanManager(point);
   if(plan.Count==0)return CommandResult.Fail("Can't get there from here.");
   var stop=StopStreetTrip();if(!stop.success)return stop;
   EndChatNow();
   managerOrders.Clear();
   managerOrders.Add(new ManagerOrder{kind=ManagerOrderKind.Walk,point=plan[plan.Count-1].point});
   ResetManagerPath();
   return CommandResult.Ok("On the way.");
  }
  // Street destinations keep using the authored town route and its arrival rules (shops, events).
  public CommandResult OrderManagerStreet(string target)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   EndChatNow();
   var sent=SendManager(target);
   if(sent.success){managerOrders.Clear();ResetManagerPath();}
   return sent;
  }
  public CommandResult OrderManagerChat(int catId)=>OrderManagerCat(ManagerOrderKind.Chat,catId);
  public CommandResult OrderManagerPet(int catId)=>OrderManagerCat(ManagerOrderKind.Pet,catId);
  public CommandResult OrderManagerFollow(int catId)=>OrderManagerCat(ManagerOrderKind.Follow,catId);
  CommandResult OrderManagerCat(ManagerOrderKind kind,int catId)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   if(catId<0||catId>=State.cats.Count||GuestActor(catId)==null)return CommandResult.Fail("That cat isn't here right now.");
   string name=State.cats[catId].name;
   // A plain walk or follow is a direction, not a plan: a new cat action replaces it. Cat actions queue.
   managerOrders.RemoveAll(o=>o.kind==ManagerOrderKind.Walk||o.kind==ManagerOrderKind.Follow);
   if(kind==ManagerOrderKind.Follow)managerOrders.Clear();
   if(managerOrders.Any(o=>o.kind==kind&&o.catId==catId))return CommandResult.Fail("Already on the list.");
   if(managerOrders.Count>=ManagerQueueLimit)return CommandResult.Fail("The to-do list is full.");
   var stop=StopStreetTrip();if(!stop.success)return stop;
   EndChatNow();
   managerOrders.Add(new ManagerOrder{kind=kind,catId=catId});
   if(managerOrders.Count==1)ResetManagerPath();
   return CommandResult.Ok(kind==ManagerOrderKind.Chat?"Off to chat with "+name+".":kind==ManagerOrderKind.Pet?"Off to pet "+name+".":"Following "+name+".");
  }
  public CommandResult CancelManagerOrder(int index)
  {
   if(index<0||index>=managerOrders.Count)return CommandResult.Fail("Nothing to cancel.");
   managerOrders.RemoveAt(index);
   if(index==0)ResetManagerPath();
   return CommandResult.Ok("Cancelled.");
  }
  public void ClearManagerOrders(){managerOrders.Clear();ResetManagerPath();}
  // Build mode pauses orders without dropping them; Life resumes them from wherever the manager stopped.
  public void PauseManagerOrders(bool paused){ManagerOrdersPaused=paused;ResetManagerPath();if(paused)EndChatNow();}

  CommandResult StopStreetTrip()
  {
   var t=Hotel(0).town;
   if(t.destination.Length==0&&t.shop.Length==0)return CommandResult.Ok("");
   return Transaction(()=>{t.destination="";t.shop="";},"");
  }
  void ResetManagerPath(){managerPathActive=false;managerPath.Clear();managerPathStreet.Clear();managerStep=0;managerReplan=0;}
  void FailManagerOrder(string message)
  {
   if(managerOrders.Count>0)managerOrders.RemoveAt(0);
   ResetManagerPath();PersistManager();
   ManagerOrderFailed?.Invoke(message);
  }
  void PersistManager(){managerPersist=PersistSeconds;TrySave();}

  // A plan runs from the manager's position to a hotel point. From the street it first walks back to the
  // gate and steps onto the hotel's front path, mirroring the outbound route in BuildManagerRoute.
  List<(LotPoint point,bool street)> PlanManager(LotPoint target)
  {
   var none=new List<(LotPoint,bool)>();var result=new List<(LotPoint point,bool street)>();
   var t=Hotel(0).town;var town=TownContent.Current;LotPoint from;
   if(t.phase=="street")
   {
    var street=TownRoute.Find(town,new LotPoint(t.x,t.z),"hotel_gate");
    if(street.Count==0)return none;
    foreach(var p in street)result.Add((p,true));
    from=ManagerExit();
   }
   else from=ManagerPosition;
   var route=ActivityRoute(from,target);
   if(route.Count==0)return none;
   result.Add((from,false));
   foreach(var p in route)if(p.Distance(result[result.Count-1].point)>.0001f)result.Add((p,false));
   return result;
  }

  // Layout edits can drop furniture on the manager. Move it to the nearest open spot on the same floor.
  void SettleManager()
  {
   if(managerSettledRevision==Revision||State.currentHotel!=0||TownContent.Current==null)return;
   managerSettledRevision=Revision;
   var t=Hotel(0).town;if(t.phase!="hotel")return;
   if(t.floor!=0&&!Hotel(0).floors.Any(f=>f.level==t.floor&&f.cells.Count>0))t.floor=0;
   var here=ManagerPosition;
   if(MovementSegmentClear(here,here,false))return;
   var open=Graph(false,0).points.Values.Where(p=>p.floor==here.floor).OrderBy(p=>p.Distance(here)).ToArray();
   var spot=open.Length>0?open[0]:Arrival();
   t.x=spot.x;t.z=spot.z;t.floor=spot.floor;
   ResetManagerPath();
  }

  void AdvanceManagerOrders(float seconds)
  {
   if(State.currentHotel!=0||TownContent.Current==null)return;
   AdvanceChat(seconds);
   if(ManagerOrdersPaused||managerOrders.Count==0||chat!=null||Hotel(0).town.destination.Length>0)return;
   var order=managerOrders[0];order.elapsed+=seconds;
   if(order.kind==ManagerOrderKind.ChatNeighbor){AdvanceNeighborOrder(order,seconds);return;}
   if(order.kind==ManagerOrderKind.Search){AdvanceSearchOrder(order,seconds);return;}
   Actor guest=null;
   if(order.kind!=ManagerOrderKind.Walk)
   {
    guest=GuestActor(order.catId);
    if(guest==null){FailManagerOrder(State.cats[order.catId].name+" wandered off.");return;}
    if(ManagerInHotel&&guest.Position.floor==ManagerPosition.floor&&ManagerPosition.Distance(guest.Position)<=(order.kind==ManagerOrderKind.Follow?FollowGap:ChatReach))
    {
     if(order.kind==ManagerOrderKind.Follow){if(managerPathActive){ResetManagerPath();PersistManager();}return;}
     managerOrders.RemoveAt(0);ResetManagerPath();PersistManager();
     if(order.kind==ManagerOrderKind.Chat)BeginChat(order.catId);
     else ManagerReachedCat?.Invoke(order.catId,"pet");
     return;
    }
    if(order.kind!=ManagerOrderKind.Follow&&order.elapsed>CatchUpSeconds){FailManagerOrder("Couldn't catch up with "+State.cats[order.catId].name+".");return;}
   }
   managerReplan-=seconds;
   // Chasing a cat re-plans at most twice a second, and only when the cat has moved away from the planned goal.
   bool moved=guest!=null&&managerReplan<=0&&guest.Position.Distance(managerPathGoal)>1f;
   bool idle=!managerPathActive&&(guest==null||managerReplan<=0);
   if(idle||managerPathActive&&managerPathRevision!=Revision||moved)
   {
    var goal=guest!=null?guest.Position:order.point;
    var plan=PlanManager(goal);managerReplan=.5f;
    if(plan.Count==0){if(guest!=null&&managerPathActive&&managerPathRevision==Revision){managerPathGoal=goal;}else{FailManagerOrder("Can't get there from here.");return;}}
    else
    {
     managerPath.Clear();managerPathStreet.Clear();
     foreach(var p in plan){managerPath.Add(p.point);managerPathStreet.Add(p.street);}
     managerStep=1;managerPathActive=true;managerPathRevision=Revision;managerPathGoal=goal;
    }
   }
   StepManager(seconds);
   if(managerStep>=managerPath.Count)
   {
    if(order.kind==ManagerOrderKind.Walk){managerOrders.RemoveAt(0);ResetManagerPath();PersistManager();}
    else managerPathActive=false;
   }
  }
  void StepManager(float seconds)
  {
   var t=Hotel(0).town;float left=seconds*ManagerSpeed;
   while(left>0&&managerStep<managerPath.Count)
   {
    var next=managerPath[managerStep];bool street=managerPathStreet[managerStep];var at=ManagerPosition;
    // Crossing between the street and the hotel, or taking the stairs, is a step with no walking distance.
    if(street!=(t.phase=="street")||!street&&next.floor!=at.floor)
    {
     t.x=next.x;t.z=next.z;t.phase=street?"street":"hotel";t.floor=street?0:next.floor;managerStep++;continue;
    }
    float gap=at.Distance(next);
    if(gap<=left){t.x=next.x;t.z=next.z;left-=gap;managerStep++;continue;}
    float portion=left/gap;t.x=at.x+(next.x-at.x)*portion;t.z=at.z+(next.z-at.z)*portion;left=0;
   }
   managerPersist-=seconds;
   if(managerPersist<=0)PersistManager();
  }
 }
}
