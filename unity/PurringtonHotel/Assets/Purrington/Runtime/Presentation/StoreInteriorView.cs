using System;
using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation {
 // Interiors stand inside their own storefronts; entering hides the shop exterior and lowers the walls facing the camera, like the hotel cutaway.
 public sealed class StoreInteriorView {
  readonly Transform pawMartRoot,clothingRoot;
  readonly GodotCatRig pawOwner,clothingOwner;
  GodotCatRig manager;
  Transform managerRoot;
  readonly GodotGeometry geometry;
  readonly Transform parent;
  readonly StoreInteriorPause pause;
  Dictionary<string,string> managerOutfit=new Dictionary<string,string>();
  string outfitSignature="";
  GodotCatRig previewRig;
  public GodotCatRig ManagerRig=>manager;
  public GodotCatRig PreviewRig=>previewRig;
  public bool IsTryingOn=>previewRig!=null;
  public void SetManagerOutfit(IDictionary<string,string> outfit){
   string signature=CatOutfitView.Signature(outfit);if(signature==outfitSignature)return;
   managerOutfit=new Dictionary<string,string>(outfit);outfitSignature=signature;
   CatOutfitView.Apply(geometry,manager,managerOutfit);
  }
  public void PreviewClothing(int catId,string coat,string markings,IDictionary<string,string> outfit,string wearId){
   if(ActiveStoreId!="clothing")return;
   var wear=Purrington.Domain.Wardrobe.Find(wearId);if(wear==null)return;
   ClearClothingPreview();
   previewRig=catId<0?new GodotCatRig(geometry,clothingRoot,ManagerCatArt.Recipe(geometry,coat,markings),91):new GodotCatRig(geometry,clothingRoot,"cats",catId.ToString(),catId);
   previewRig.Root.name="Fitting preview";previewRig.Root.localScale=Vector3.one*.83f;
   previewRig.Root.localPosition=new Vector3(240*VoxelWorld.Unit-3.5f,.26f,3f);
   var preview=new Dictionary<string,string>(outfit);preview[wear.slot]=wearId;
   CatOutfitView.Apply(geometry,previewRig,preview);
  }
  public void TurnClothingPreview(){if(previewRig!=null)previewRig.Root.Rotate(0,90,0);}
  public void ClearClothingPreview(){if(previewRig==null)return;ReleaseRig(previewRig.Root);previewRig=null;}
  static void ReleaseRig(Transform root){root.gameObject.SetActive(false);if(Application.isPlaying)UnityEngine.Object.Destroy(root.gameObject);else UnityEngine.Object.DestroyImmediate(root.gameObject);}
  string managerLook="honey/solid";
  Vector3 entry,aisle,counter;
  int waypoint;
  bool walking,conversation;
  readonly ShoppingCartRig[] carts=new ShoppingCartRig[3];
  readonly GodotCatRig[] shoppers=new GodotCatRig[2];
  readonly float[] shopperDistance=new float[2];
  float managerDistance,checkoutTime;int shoppingWaypoint;
  public IReadOnlyList<ShoppingCartRig> ShoppingCarts=>carts;
  public bool IsShopping {get;private set;}
  public event Action<string> CashierSelected;
  public string ActiveStoreId {get;private set;}="";
  public string OwnerName=>ActiveStoreId=="paw_mart"?"Miso":ActiveStoreId=="clothing"?"Clover":"";
  public bool IsVisible=>ActiveStoreId.Length>0;
  public bool IsConversationOpen=>conversation;
  public int VisibleStoreCount=>(pawMartRoot.gameObject.activeSelf?1:0)+(clothingRoot.gameObject.activeSelf?1:0);
  public Vector3 Focus{get{var r=ActiveStoreId=="paw_mart"?pawMartRoot:clothingRoot;return r.localPosition+r.localRotation*new Vector3((ActiveStoreId=="paw_mart"?200:240)*VoxelWorld.Unit,1.2f,0);}}
  readonly List<(Transform root,Transform full,Transform low,Vector3 normal)> walls=new List<(Transform,Transform,Transform,Vector3)>();
  public StoreInteriorView(GodotGeometry geometry,Transform parent) {
   this.geometry=geometry;this.parent=parent;pause=parent.gameObject.AddComponent<StoreInteriorPause>();
   pawMartRoot=MainStreetArt.Group(parent,"Paw Mart interior");pawMartRoot.gameObject.AddComponent<TownInterior>();
   clothingRoot=MainStreetArt.Group(parent,"Clothing interior");clothingRoot.gameObject.AddComponent<TownInterior>();
   BuildPawMart(pawMartRoot,200*VoxelWorld.Unit);
   BuildClothing(clothingRoot,240*VoxelWorld.Unit);
   Place(pawMartRoot,"paw_mart",200*VoxelWorld.Unit);Place(clothingRoot,"clothing",240*VoxelWorld.Unit);
   carts[0]=new ShoppingCartRig(geometry,pawMartRoot,"Manager");
   for(int i=0;i<2;i++){
    shoppers[i]=new GodotCatRig(geometry,pawMartRoot,ManagerCatArt.Recipe(geometry,i==0?"cream":"cocoa",i==0?"tabby":"tuxedo"),110+i);
    shoppers[i].Root.name=i==0?"Olive shopper":"Bean shopper";shoppers[i].Root.localScale=Vector3.one*.83f;
    carts[i+1]=new ShoppingCartRig(geometry,pawMartRoot,shoppers[i].Root.name);carts[i+1].SetContents(i==0?"welcome_basket":"market_bundle");
   }
   Furnish(pawMartRoot,200*VoxelWorld.Unit,"Cashier step",new Vector3(-4.4f,.325f,-1.1f),new Vector3(1,.65f,.85f),"B3824C");
   Furnish(clothingRoot,240*VoxelWorld.Unit,"Cashier step",new Vector3(3.9f,.325f,-.4f),new Vector3(1,.65f,.85f),"B3824C");
   pawOwner=Owner(pawMartRoot,"Miso","ginger","tuxedo",new Vector3(200*VoxelWorld.Unit-4.4f,.85f,-1.1f),"Grocery apron","738448");
   pawOwner.Root.localRotation=Quaternion.Euler(0,180,0);
   clothingOwner=Owner(clothingRoot,"Clover","gray","patchwork",new Vector3(240*VoxelWorld.Unit+3.9f,.85f,-.4f),"Boutique scarf","BF7958");
   clothingOwner.Root.localRotation=Quaternion.Euler(0,180,0);
   manager=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe(geometry,"honey","solid"),91);
   managerRoot=manager.Root;managerRoot.name="Interior manager";managerRoot.localScale=Vector3.one*.83f;managerRoot.gameObject.SetActive(false);
   pawMartRoot.gameObject.SetActive(false);clothingRoot.gameObject.SetActive(false);
  }
  public void SetManagerAppearance(string coat,string markings){
   string look=coat+"/"+markings;if(managerLook==look)return;
   var replacement=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe(geometry,coat,markings),91);
   replacement.Root.name="Interior manager";replacement.Root.localScale=Vector3.one*.83f;
   replacement.Root.gameObject.SetActive(false);
   if(managerRoot!=null)ReleaseRig(managerRoot);
   manager=replacement;managerRoot=replacement.Root;managerLook=look;CatOutfitView.Apply(geometry,manager,managerOutfit);
  }
  GodotCatRig Owner(Transform parent,string name,string coat,string markings,Vector3 at,string outfit,string color){
   var rig=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe(geometry,coat,markings),-1);
   rig.Root.name=name+" cashier";rig.Root.localPosition=at;rig.Root.localScale=Vector3.one*.83f;
   Box(rig.Root,outfit,new Vector3(0,.69f,.34f),new Vector3(.55f,.32f,.12f),color);
   var hit=rig.Root.gameObject.AddComponent<BoxCollider>();hit.center=new Vector3(0,.65f,0);hit.size=new Vector3(1,1.4f,1);
   rig.Root.gameObject.AddComponent<StoreCashierHit>();
   return rig;
  }
  void Box(Transform parent,string name,Vector3 at,Vector3 size,string color){geometry.Build(parent,ManagerCatArt.Node(name,at,size,color));}
  void Furnish(Transform parent,float x,string name,Vector3 at,Vector3 size,string color){Box(parent,name,at+new Vector3(x,0,0),size,color);}
  void Base(Transform parent,float x,ShopPlan plan,string wall){
   foreach(var room in plan.Rooms){var r=room.rect;var floor=MainStreetArt.Group(parent,room.name);Furnish(floor,x,room.name+" floor",new Vector3(r.center.x,-.05f,r.center.y),new Vector3(r.width,.2f,r.height),room.floor);}
   // Outer walls have a full and a knee-high version; FaceCamera shows the low one on the sides between the camera and the room.
   // Partitions between rooms stay half height with a trim cap so every room reads as its own space without hiding the next.
   foreach(var w in plan.Walls()){
    if(w.exterior){Wall(parent,x,"Outer wall",w.at,w.size,w.normal,wall);continue;}
    Furnish(parent,x,"Partition",w.at+Vector3.up*.65f,new Vector3(w.size.x,1.3f,w.size.z),wall);
    Furnish(parent,x,"Partition cap",w.at+Vector3.up*1.34f,new Vector3(w.size.x+.06f,.08f,w.size.z+.06f),"B3824C");
   }
  }
  void Wall(Transform parent,float x,string name,Vector3 at,Vector3 size,Vector3 normal,string color){
   var full=MainStreetArt.Group(parent,name);var low=MainStreetArt.Group(parent,name+" (cut)");
   Furnish(full,x,name,at+Vector3.up*1.6f,new Vector3(size.x,3.2f,size.z),color);
   Furnish(low,x,name,at+Vector3.up*.16f,new Vector3(size.x,.32f,size.z),color);
   walls.Add((parent,full,low,normal));
  }
  static void Place(Transform root,string id,float origin){
   var shop=Purrington.Domain.TownContent.Current?.Shop(id);if(shop==null)return;var f=shop.footprint;
   // Shop doors face the road (north), so the room turns around its center to put its entrance side at the door.
   root.localRotation=Quaternion.Euler(0,180,0);
   root.localPosition=new Vector3((f.x+f.w/2)*VoxelWorld.Unit+origin,0,(f.z+f.d/2)*VoxelWorld.Unit);
  }
  // cameraForward is in the parent (render root) space; walls whose outward side faces the camera drop to knee height.
  public void FaceCamera(Vector3 cameraForward){
   foreach(var w in walls){bool near=Vector3.Dot(w.root.localRotation*w.normal,cameraForward)<0;w.full.gameObject.SetActive(!near);w.low.gameObject.SetActive(near);}
  }
  void BuildPawMart(Transform root,float x){
   Base(root,x,ShopPlan.PawMart,"EFE2C9");
   PawMartArt.Build(geometry,root,x);
  }
  void BuildClothing(Transform root,float x){
   Base(root,x,ShopPlan.Clothing,"F4E4D8");
   ClothingStoreArt.Build(geometry,root,x);
  }
  public void Enter(string storeId){
   if(storeId!="paw_mart"&&storeId!="clothing")throw new ArgumentException("Unknown store",nameof(storeId));
   ClearClothingPreview();ActiveStoreId=storeId;conversation=walking=IsShopping=false;waypoint=0;managerDistance=checkoutTime=0;carts[0].Root.gameObject.SetActive(false);
   pawMartRoot.gameObject.SetActive(storeId=="paw_mart");clothingRoot.gameObject.SetActive(storeId=="clothing");
   float x=(storeId=="paw_mart"?200:240)*VoxelWorld.Unit;
   var plan=ShopPlan.For(storeId);entry=new Vector3(x+plan.DoorX,.18f,plan.Bounds.yMin+.8f);
   if(storeId=="paw_mart"){aisle=new Vector3(x-3.2f,.18f,-3.5f);counter=new Vector3(x-4.4f,.18f,-2.95f);}else{aisle=new Vector3(x+2.6f,.18f,-3.1f);counter=new Vector3(x+3.9f,.18f,-2.45f);}
   managerRoot.SetParent(storeId=="paw_mart"?pawMartRoot:clothingRoot,false);managerRoot.localPosition=entry;managerRoot.localRotation=Quaternion.identity;managerRoot.gameObject.SetActive(true);AdvanceShoppers(0,false);
  }
  public void Exit(){ClearClothingPreview();conversation=walking=IsShopping=false;ActiveStoreId="";pawMartRoot.gameObject.SetActive(false);clothingRoot.gameObject.SetActive(false);managerRoot.gameObject.SetActive(false);}
  public bool SelectCashier(){if(!IsVisible||walking||conversation||IsShopping)return false;walking=true;waypoint=0;return true;}
  public void Advance(float seconds,bool motion){
   if(!IsVisible)return;
   if(pause.IsPaused){seconds=0;motion=false;}
   AdvanceShoppers(seconds,motion);
   if(IsShopping){AdvanceShopping(seconds,motion);return;}
   if(carts[0].Root.gameObject.activeInHierarchy)carts[0].SetPose(managerRoot.localPosition,managerRoot.localRotation,managerDistance,!motion);
   pawOwner.Advance(seconds,motion,"rest",false);clothingOwner.Advance(seconds,motion,"rest",false);
   if(!walking){
    if(checkoutTime>0){checkoutTime=Mathf.Max(0,checkoutTime-Mathf.Max(0,seconds));manager.Advance(seconds,motion,"rest",false,"handoff");pawOwner.Advance(seconds,motion,"rest",false,"handoff");}
    else manager.Advance(seconds,motion,"rest",false);
    return;
   }
   float step=Mathf.Max(0,seconds)*2.4f;
   while(step>0&&walking){
    var target=waypoint==0?aisle:counter;var delta=target-managerRoot.localPosition;
    if(delta.sqrMagnitude>.0001f)managerRoot.localRotation=Quaternion.LookRotation(delta);
    float distance=delta.magnitude;managerRoot.localPosition=Vector3.MoveTowards(managerRoot.localPosition,target,step);step-=distance;
    if((managerRoot.localPosition-target).sqrMagnitude>.0001f)break;
    if(waypoint++==0)continue;
    walking=false;conversation=true;CashierSelected?.Invoke(ActiveStoreId);
   }
   manager.Advance(seconds,motion,"walk",true);
  }
  public bool StartPurchaseRoutine(string item){
   if(ActiveStoreId!="paw_mart"||!conversation)return false;
   if(IsShopping){carts[0].SetContents(item);return true;}
   carts[0].SetContents(item);carts[0].Root.gameObject.SetActive(true);managerDistance=0;shoppingWaypoint=0;IsShopping=true;
   carts[0].SetPose(managerRoot.localPosition,managerRoot.localRotation,0,true);return true;
  }
  void AdvanceShopping(float seconds,bool motion){
   float x=200*VoxelWorld.Unit;
   // Down the front aisle, through the doorway into the fresh market, past the produce and back to the till.
   var route=new[]{new Vector3(x+.9f,.18f,-3.9f),new Vector3(x+.9f,.18f,-1.2f),new Vector3(x+3.6f,.18f,-1.2f),new Vector3(x+4.2f,.18f,.2f),new Vector3(x+3.6f,.18f,-1.2f),new Vector3(x+.9f,.18f,-1.2f),new Vector3(x+.9f,.18f,-3.9f),counter};
   float remaining=Mathf.Max(0,seconds)*1.2f;
   while(remaining>0&&IsShopping){
    var target=route[shoppingWaypoint];var delta=target-managerRoot.localPosition;float distance=delta.magnitude;
    if(distance>.0001f)managerRoot.localRotation=Quaternion.LookRotation(delta);
    float travel=Mathf.Min(remaining,distance);managerRoot.localPosition=Vector3.MoveTowards(managerRoot.localPosition,target,travel);managerDistance+=travel;remaining-=travel;
    if(distance>travel+.0001f)break;
    if(++shoppingWaypoint==route.Length){IsShopping=false;checkoutTime=1.4f;managerRoot.localRotation=Quaternion.identity;}
   }
   carts[0].SetPose(managerRoot.localPosition,managerRoot.localRotation,managerDistance,!motion);
   manager.Advance(seconds,motion,IsShopping?"push_cart":"rest",IsShopping);
   if(!IsShopping){manager.Advance(0,motion,"rest",false,"handoff");pawOwner.Advance(0,motion,"rest",false,"handoff");}
  }
  void AdvanceShoppers(float seconds,bool motion){
   if(ActiveStoreId!="paw_mart")return;
   float x=200*VoxelWorld.Unit;
   // Shoppers loop the central gondola in the grocery hall.
   var route=new[]{new Vector3(x-1.5f,.18f,-3.2f),new Vector3(x+.5f,.18f,-3.2f),new Vector3(x+.5f,.18f,.95f),new Vector3(x-1.5f,.18f,.95f)};
   const float perimeter=12.3f;
   for(int i=0;i<2;i++){
    shopperDistance[i]+=Mathf.Max(0,seconds)*.55f;float along=Mathf.Repeat(shopperDistance[i]+i*perimeter/2,perimeter);
    for(int segment=0;segment<4;segment++){
     var from=route[segment];var to=route[(segment+1)%4];float length=Vector3.Distance(from,to);
     if(along>length){along-=length;continue;}
     shoppers[i].Root.localPosition=Vector3.Lerp(from,to,along/length);shoppers[i].Root.localRotation=Quaternion.LookRotation(to-from);break;
    }
    shoppers[i].Advance(seconds,motion,"push_cart",seconds>0);
    carts[i+1].SetPose(shoppers[i].Root.localPosition,shoppers[i].Root.localRotation,shopperDistance[i],!motion);
   }
  }
  public bool Back(){if(!IsVisible)return false;if(conversation){CloseConversation();return true;}Exit();return true;}
  public void CloseConversation(){ClearClothingPreview();conversation=false;}
 }
 public sealed class StoreInteriorPause:MonoBehaviour {
  public bool IsPaused {get;private set;}
  void OnApplicationPause(bool paused){IsPaused=paused;}
 }
 public sealed class StoreCashierHit:MonoBehaviour {}
}
