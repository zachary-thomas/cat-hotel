using System;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Life control: while the Life tab is in play view, world taps direct the manager instead of selecting furniture.
 public sealed partial class VoxelWorld {
  public const string ManagerPickId="manager";
  bool lifeControl;Transform destinationMarker;BoxCollider managerPick;
  public bool LifeControl=>lifeControl;
  public bool FollowingManager=>townFollowing;
  public event Action ManagerTapped;
  public event Action<int,Vector2> CatTapped;
  public event Action<CommandResult> LifeCommand;
  // Build grab: the UI decides whether a press starts a grab (on a furnishing, or on the item being placed).
  // A grab that never drags is still an ordinary tap.
  public Func<Vector2,bool> GrabStart;
  public event Action<Vector3> GrabMoved,GrabEnded;
  bool grabbing;
  public bool Grabbing=>grabbing&&dragged;
  public void SetLifeControl(bool on){
   if(lifeControl==on)return;
   lifeControl=on;pressed=false;
   if(!on){if(!townMode)townFollowing=false;ClearDestinationMarker();}
   if(managerPick)managerPick.enabled=on;
  }
  public void FollowManager(bool on){
   if(!on){townFollowing=false;return;}
   if(currentMap!=0)return;
   townFollowing=true;manualCamera=true;lastFitBounds=null;
   if(model.ManagerInHotel&&ViewFloor!=model.ManagerPosition.floor)SetViewFloor(model.ManagerPosition.floor);
   var t=model.Hotel(0).town;focus=new Vector3(t.x*Unit,.6f,t.z*Unit);UpdateCamera();
  }
  void LifeTap(Vector2 point){
   var pick=PickAt(point);
   if(pick.objectId==ManagerPickId){ManagerTapped?.Invoke();return;}
   if(pick.objectId==OutskirtsArt.RumorPickId){var search=model.OrderManagerSearch();if(search.success)FollowManager(true);LifeCommand?.Invoke(search);return;}
   if(pick.objectId!=null&&pick.objectId.StartsWith(NeighborPickPrefix)){NeighborTapped?.Invoke(pick.objectId.Substring(NeighborPickPrefix.Length),point);return;}
   if(pick.catId>=0){CatTapped?.Invoke(pick.catId,point);return;}
   var ground=ScreenToGround(point);
   var walk=model.OrderManagerWalk(new LotPoint(ground.x,ground.z,ViewFloor));
   if(!walk.success&&ViewFloor==0){
    var street=GroundPoint(point,GroundY);
    string target=MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(street.x/Unit,street.z/Unit));
    if(target!=null){var sent=model.OrderManagerStreet(target);var p=TownContent.Current.Point(target);if(sent.success)ShowDestinationMarker(new Vector3(p.x,0,p.z),0);LifeCommand?.Invoke(sent);return;}
   }
   if(walk.success)ShowDestinationMarker(new Vector3(model.ManagerOrders[0].point.x,0,model.ManagerOrders[0].point.z),model.ManagerOrders[0].point.floor);
   LifeCommand?.Invoke(walk);
  }
  // A small paw print where the manager is heading; it disappears on arrival.
  void ShowDestinationMarker(Vector3 lot,int floor){
   ClearDestinationMarker();
   destinationMarker=Group(renderRoot,"Manager destination");
   destinationMarker.localPosition=new Vector3(lot.x*Unit,GroundY+FloorY(floor)+.03f,lot.z*Unit);
   string ink="3E6B4F";
   Box(destinationMarker,new Vector3(0,0,0),new Vector3(.3f,.04f,.26f),ink);
   foreach(var toe in new[]{new Vector2(-.17f,.2f),new Vector2(-.06f,.27f),new Vector2(.06f,.27f),new Vector2(.17f,.2f)})Box(destinationMarker,new Vector3(toe.x,0,toe.y),new Vector3(.09f,.04f,.09f),ink);
   if(model.State.settings.motion)Tween.Run(destinationMarker,.28f,k=>{if(destinationMarker)destinationMarker.localScale=Vector3.one*Tween.OutBack(k);});
  }
  void ClearDestinationMarker(){DisposeNode(destinationMarker);destinationMarker=null;}
  void SyncLifeManager(Vector3 at){
   if(destinationMarker&&!model.ManagerWalking)ClearDestinationMarker();
   if(managerPick==null&&managerRig!=null){
    var host=new GameObject("Manager pick");host.transform.SetParent(managerRig.Root,false);
    managerPick=host.AddComponent<BoxCollider>();managerPick.center=new Vector3(0,.6f,0);managerPick.size=new Vector3(.85f,1.3f,1.05f);
    host.AddComponent<WorldPick>().objectId=ManagerPickId;managerPick.enabled=lifeControl;
   }
   FrameChat(at);
   if(!lifeControl||!townFollowing||townMode||chatFramed)return;
   if(model.ManagerInHotel&&ViewFloor!=model.ManagerPosition.floor)SetViewFloor(model.ManagerPosition.floor);
   focus=new Vector3(at.x,.6f,at.z);
  }
  // While chatting, the camera eases in on the manager and the guest, then eases back to where it was.
  bool chatFramed;Vector3 chatSavedFocus;float chatSavedZoom;bool chatSavedManual;
  void FrameChat(Vector3 manager){
   var chat=lifeControl&&!townMode?model.CurrentChat:null;
   var guest=chat==null||chat.neighbor!=null?null:model.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest&&a.catId==chat.catId);
   var neighbor=chat?.neighbor!=null?model.Neighbor(chat.neighbor):null;
   float ease=model.State.settings.motion?Mathf.Clamp01(Time.unscaledDeltaTime*4):1;
   if(neighbor!=null){
    if(!chatFramed){chatFramed=true;chatSavedFocus=focus;chatSavedZoom=zoom;chatSavedManual=manualCamera;}
    var mid=(manager+new Vector3(neighbor.position.x*Unit,0,neighbor.position.z*Unit))*.5f;mid.y=.6f;
    manualCamera=true;focus=Vector3.Lerp(focus,mid,ease);zoom=Mathf.Lerp(zoom,Mathf.Min(chatSavedZoom,6.5f),ease);
    return;
   }
   if(guest!=null){
    if(!chatFramed){chatFramed=true;chatSavedFocus=focus;chatSavedZoom=zoom;chatSavedManual=manualCamera;}
    var mid=(manager+new Vector3(guest.x*Unit,0,guest.z*Unit))*.5f;mid.y=.6f;
    manualCamera=true;focus=Vector3.Lerp(focus,mid,ease);zoom=Mathf.Lerp(zoom,Mathf.Min(chatSavedZoom,6.5f),ease);
    if(ViewFloor!=guest.floor)SetViewFloor(guest.floor);
    return;
   }
   if(!chatFramed)return;
   chatFramed=false;manualCamera=chatSavedManual;zoom=chatSavedZoom;if(!townFollowing)focus=chatSavedFocus;
  }
  // Screen position just above a guest's head, for the pie menu and reaction chips.
  public bool CatHeadScreen(int catId,out Vector2 screen){
   screen=default;
   var a=model.Actors.FirstOrDefault(x=>x.kind==ActorKind.Guest&&x.catId==catId);
   if(a==null||!actors.TryGetValue(a.id,out var rig)||!rig.Root.gameObject.activeInHierarchy)return false;
   var p=WorldCamera.WorldToScreenPoint(rig.Root.position+Vector3.up*1.25f);
   if(p.z<=0)return false;screen=p;return true;
  }
  public bool ManagerHeadScreen(out Vector2 screen){
   screen=default;
   if(managerRig==null||!managerRig.Root.gameObject.activeInHierarchy)return false;
   var p=WorldCamera.WorldToScreenPoint(managerRig.Root.position+Vector3.up*1.25f);
   if(p.z<=0)return false;screen=p;return true;
  }
  public void ChatReaction(int catId,string reaction){
   var a=model.Actors.FirstOrDefault(x=>x.kind==ActorKind.Guest&&x.catId==catId);
   if(a==null||fx==null||!actors.TryGetValue(a.id,out var rig))return;
   if(reaction=="love")fx.Hearts(rig.Root.position+Vector3.up*1.1f,6);
   else if(reaction=="like")fx.Hearts(rig.Root.position+Vector3.up*1.1f,2);
  }
 }
}
