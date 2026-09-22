using System;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 public sealed partial class VoxelWorld {
  MainStreetArt townArt;GodotCatRig managerRig;StoreInteriorView storeInterior;
  bool townMode,townFollowing,townSavedManual;Vector3 townSavedFocus;float townSavedZoom;Bounds? townSavedBounds;
  string previewCoat,previewMarkings,managerLook;
  bool interiorPointerOwned;
  public bool IsTownMode=>townMode;
  public int TownStorefrontCount=>townArt?.Storefronts.Count??0;
  public int ActiveStoreInteriorCount=>storeInterior?.VisibleStoreCount??0;
  public StoreInteriorView StoreInterior=>storeInterior;
  public Bounds TownSquareBounds=>townArt?.SquareBounds??new Bounds();
  public event Action<string> StoreSelected;
  public event Action<string> TownMessage;
  public event Action<CommandResult> TownCommand;
  public event Action<string> CashierSelected;
  public event Action<string> StoreEntered;
  void InitializeStoreInterior(){
   storeInterior=new StoreInteriorView(geometry,renderRoot);
   storeInterior.CashierSelected+=id=>CashierSelected?.Invoke(id);
   model.ManagerArrived+=OnManagerArrived;
  }
  void OnManagerArrived(string target){
   if(!townMode||currentMap!=0)return;
   foreach(string id in new[]{"paw_mart","clothing"})if(TownContent.Current.Shop(id)?.door==target){EnterStoreInterior(id);return;}
  }
  public void EnterStoreInterior(string id){
   if(!townMode||currentMap!=0||model.Hotel(0).town.shop!=id)return;
   if(storeInterior.IsVisible)return;
   storeInterior.SetManagerAppearance(model.State.managerCoat,model.State.managerMarkings);
   storeInterior.Enter(id);townFollowing=false;pressed=false;
   townStreetFocus=focus;townStreetZoom=zoom;townStreetManual=manualCamera;townStreetBounds=lastFitBounds;
   focus=storeInterior.Focus;zoom=5.5f;manualCamera=true;lastFitBounds=null;UpdateCamera();
   SyncManager(0);
   StoreEntered?.Invoke(id);
  }
  Vector3 townStreetFocus;float townStreetZoom;bool townStreetManual;Bounds? townStreetBounds;
  public void ExitStoreInterior(){
   if(storeInterior==null||!storeInterior.IsVisible)return;
   storeInterior.Exit();pressed=false;focus=townStreetFocus;zoom=townStreetZoom;manualCamera=townStreetManual;lastFitBounds=townStreetBounds;UpdateCamera();SyncManager(0);
  }
  public bool SelectStoreCashier(){return storeInterior!=null&&storeInterior.SelectCashier();}
  void RefreshTown(){
   if(TownContent.Current==null)return;
   if(townArt==null)townArt=new MainStreetArt(geometry,renderRoot,TownContent.Current);
   townArt.Root.gameObject.SetActive(currentMap==0);
   if(currentMap!=0&&townMode)ExitTownMode();
   SyncManager(0);
  }
  public void EnterTownMode(){
   if(currentMap!=0||townMode)return;
   if(care)SetCareMode(0,false);ClearPreview();SetPathPainting(false);
   townSavedFocus=focus;townSavedZoom=zoom;townSavedManual=manualCamera;townSavedBounds=lastFitBounds;
   townMode=true;pressed=false;FocusManager();
   var state=model.Hotel(0).town;
   if(state.shop=="paw_mart"||state.shop=="clothing")EnterStoreInterior(state.shop);
  }
  public void ExitTownMode(){
   if(!townMode)return;ExitStoreInterior();townMode=false;townFollowing=false;pressed=false;
   previewCoat=previewMarkings=null;SyncManager(0);
   focus=townSavedFocus;zoom=townSavedZoom;manualCamera=townSavedManual;lastFitBounds=townSavedBounds;UpdateCamera();
  }
  public void FocusManager(){
   if(!townMode||storeInterior?.IsVisible==true)return;townFollowing=true;manualCamera=true;lastFitBounds=null;
   var t=model.Hotel(0).town;focus=new Vector3(t.x*Unit,.6f,t.z*Unit);
   var rect=VisibleWorldRect();zoom=Mathf.Max(4.8f,4.8f*Screen.height/Mathf.Max(1,rect.height));UpdateCamera();
  }
  public void FocusManagerAppearance(){if(storeInterior?.IsVisible==true)return;FocusManager();zoom*=.45f;UpdateCamera();}
  public void FitTown(){if(!townMode||storeInterior?.IsVisible==true)return;townFollowing=false;FocusBounds(new Bounds(new Vector3(25*Unit,1.5f,17*Unit),new Vector3(23*Unit,5,30*Unit)));}
  public void PreviewManagerAppearance(string coat,string markings){previewCoat=coat;previewMarkings=markings;SyncManager(0);}
  public void ClearManagerPreview(){previewCoat=previewMarkings=null;SyncManager(0);}
  public bool SelectTownStore(string id){
   if(!townMode||TownContent.Current.Shop(id)==null)return false;
   if(model.Hotel(0).town.shop==id&&model.Hotel(0).town.destination==""){EnterStoreInterior(id);return true;}
   StoreSelected?.Invoke(id);return true;
  }
  public void SelectTownGround(Vector3 point){
   if(!townMode)return;
   string target=MainStreetArt.StreetTarget(TownContent.Current,new LotPoint(point.x,point.z));
   if(target==null){TownMessage?.Invoke("Tap a Main Street path.");return;}
   var result=model.SendManager(target);TownCommand?.Invoke(result);
  }
  void SyncManager(float delta){
   if(TownContent.Current==null)return;
   string coat=previewCoat??model.State.managerCoat,marking=previewMarkings??model.State.managerMarkings,look=coat+"/"+marking;
   if(managerRig==null||managerLook!=look){DisposeNode(managerRig?.Root);managerRig=new GodotCatRig(geometry,renderRoot,ManagerCatArt.Recipe(coat,marking),91);managerRig.Root.localScale=Vector3.one*.83f;managerLook=look;}
   managerRig.Root.gameObject.SetActive(currentMap==0&&(storeInterior==null||!storeInterior.IsVisible));
   if(currentMap!=0)return;
   var t=model.Hotel(0).town;var at=new Vector3(t.x*Unit,GroundY,t.z*Unit);var moved=at-managerRig.Root.localPosition;
   if(moved.sqrMagnitude>.000001f)managerRig.Root.localRotation=Quaternion.LookRotation(moved);
   managerRig.Root.localPosition=at;bool walking=!string.IsNullOrEmpty(t.destination);
   managerRig.Advance(delta,model.State.settings.motion,walking?"walk":"rest",walking);
   if(townMode&&townFollowing)focus=at+Vector3.up*.5f;
  }
 }
}
