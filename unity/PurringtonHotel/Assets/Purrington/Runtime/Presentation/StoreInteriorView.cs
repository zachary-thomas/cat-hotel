using System;
using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation {
 // Interior stages live far from the authored street and are inactive until a door arrival.
 public sealed class StoreInteriorView {
  readonly Transform pawMartRoot,clothingRoot;
  readonly GodotCatRig pawOwner,clothingOwner;
  GodotCatRig manager;
  Transform managerRoot;
  readonly GodotGeometry geometry;
  readonly Transform parent;
  readonly StoreInteriorPause pause;
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
  public Vector3 Focus=>new Vector3((ActiveStoreId=="paw_mart"?200:240)*VoxelWorld.Unit,1.2f,0);
  public StoreInteriorView(GodotGeometry geometry,Transform parent) {
   this.geometry=geometry;this.parent=parent;pause=parent.gameObject.AddComponent<StoreInteriorPause>();
   pawMartRoot=MainStreetArt.Group(parent,"Paw Mart interior");pawMartRoot.gameObject.AddComponent<TownInterior>();
   clothingRoot=MainStreetArt.Group(parent,"Clothing interior");clothingRoot.gameObject.AddComponent<TownInterior>();
   BuildPawMart(pawMartRoot,200*VoxelWorld.Unit);
   BuildClothing(clothingRoot,240*VoxelWorld.Unit);
   carts[0]=new ShoppingCartRig(geometry,pawMartRoot,"Manager");
   for(int i=0;i<2;i++){
    shoppers[i]=new GodotCatRig(geometry,pawMartRoot,ManagerCatArt.Recipe(i==0?"cream":"cocoa",i==0?"tabby":"tuxedo"),110+i);
    shoppers[i].Root.name=i==0?"Olive shopper":"Bean shopper";shoppers[i].Root.localScale=Vector3.one*.83f;
    carts[i+1]=new ShoppingCartRig(geometry,pawMartRoot,shoppers[i].Root.name);carts[i+1].SetContents(i==0?"welcome_basket":"market_bundle");
   }
   pawOwner=Owner(pawMartRoot,"Miso","ginger","tuxedo",new Vector3(200*VoxelWorld.Unit+2.8f,.2f,3.3f),"Grocery apron","738448");
   pawOwner.Root.localRotation=Quaternion.Euler(0,180,0);
   clothingOwner=Owner(clothingRoot,"Clover","gray","patchwork",new Vector3(240*VoxelWorld.Unit+2,.2f,1.4f),"Boutique scarf","BF7958");
   manager=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe("honey","solid"),91);
   managerRoot=manager.Root;managerRoot.name="Interior manager";managerRoot.localScale=Vector3.one*.83f;managerRoot.gameObject.SetActive(false);
   pawMartRoot.gameObject.SetActive(false);clothingRoot.gameObject.SetActive(false);
  }
  public void SetManagerAppearance(string coat,string markings){
   string look=coat+"/"+markings;if(managerLook==look)return;
   var replacement=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe(coat,markings),91);
   replacement.Root.name="Interior manager";replacement.Root.localScale=Vector3.one*.83f;
   replacement.Root.gameObject.SetActive(false);
   if(managerRoot!=null){managerRoot.gameObject.SetActive(false);UnityEngine.Object.Destroy(managerRoot.gameObject);}
   manager=replacement;managerRoot=replacement.Root;managerLook=look;
  }
  GodotCatRig Owner(Transform parent,string name,string coat,string markings,Vector3 at,string outfit,string color){
   var rig=new GodotCatRig(geometry,parent,ManagerCatArt.Recipe(coat,markings),-1);
   rig.Root.name=name+" cashier";rig.Root.localPosition=at;rig.Root.localScale=Vector3.one*.83f;
   Box(rig.Root,outfit,new Vector3(0,.69f,.34f),new Vector3(.55f,.32f,.12f),color);
   var hit=rig.Root.gameObject.AddComponent<BoxCollider>();hit.center=new Vector3(0,.65f,0);hit.size=new Vector3(1,1.4f,1);
   rig.Root.gameObject.AddComponent<StoreCashierHit>();
   return rig;
  }
  void Box(Transform parent,string name,Vector3 at,Vector3 size,string color){geometry.Build(parent,ManagerCatArt.Node(name,at,size,color));}
  void Furnish(Transform parent,float x,string name,Vector3 at,Vector3 size,string color){Box(parent,name,at+new Vector3(x,0,0),size,color);}
  void Base(Transform parent,float x,string wall){
   Furnish(parent,x,"Floor",new Vector3(0,-.05f,0),new Vector3(9,.2f,8),"CAC4B2");
   Furnish(parent,x,"Back wall",new Vector3(0,1.6f,4),new Vector3(9,3.2f,.3f),wall);
   Furnish(parent,x,"Left wall",new Vector3(-4.5f,1.6f,0),new Vector3(.3f,3.2f,8),wall);
   Furnish(parent,x,"Right wall",new Vector3(4.5f,1.6f,0),new Vector3(.3f,3.2f,8),wall);
  }
  void BuildPawMart(Transform root,float x){
   Base(root,x,"EFE2C9");
   PawMartArt.Build(geometry,root,x);
  }
  void BuildClothing(Transform root,float x){
   Base(root,x,"F4E4D8");
   foreach(float side in new[]{-2.5f,0f}){
    Furnish(root,x,"Clothing rack",new Vector3(side,1.35f,-.7f),new Vector3(.12f,1.8f,2.5f),"425C35");
    foreach(float z in new[]{-1.4f,-.7f,0f})Furnish(root,x,"Hanging garment",new Vector3(side,1.32f,z),new Vector3(.65f,.75f,.48f),z<-.8f?"BF7958":"738448");
   }
   Furnish(root,x,"Mirror",new Vector3(-2.8f,1.45f,3.78f),new Vector3(1.5f,2.2f,.12f),"DCE5C5");
   Furnish(root,x,"Try on platform",new Vector3(-2.8f,.12f,2.45f),new Vector3(1.8f,.18f,1.5f),"D2AD77");
   Furnish(root,x,"Checkout counter",new Vector3(2,.65f,2.3f),new Vector3(3.2f,1.15f,1),"B3824C");
   Furnish(root,x,"Register",new Vector3(2.5f,1.33f,2.35f),new Vector3(.5f,.3f,.4f),"425C35");
   Furnish(root,x,"Folded clothes",new Vector3(3.2f,1.3f,2.3f),new Vector3(.55f,.2f,.5f),"BF7958");
  }
  public void Enter(string storeId){
   if(storeId!="paw_mart"&&storeId!="clothing")throw new ArgumentException("Unknown store",nameof(storeId));
   ActiveStoreId=storeId;conversation=walking=IsShopping=false;waypoint=0;managerDistance=checkoutTime=0;carts[0].Root.gameObject.SetActive(false);
   pawMartRoot.gameObject.SetActive(storeId=="paw_mart");clothingRoot.gameObject.SetActive(storeId=="clothing");
   float x=(storeId=="paw_mart"?200:240)*VoxelWorld.Unit;
   entry=new Vector3(x,.18f,-3);aisle=new Vector3(x+.8f,.18f,-.6f);counter=new Vector3(x+2,.18f,.35f);
   managerRoot.localPosition=entry;managerRoot.localRotation=Quaternion.identity;managerRoot.gameObject.SetActive(true);AdvanceShoppers(0,false);
  }
  public void Exit(){conversation=walking=IsShopping=false;ActiveStoreId="";pawMartRoot.gameObject.SetActive(false);clothingRoot.gameObject.SetActive(false);managerRoot.gameObject.SetActive(false);}
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
   var route=new[]{new Vector3(x+3,.18f,.35f),new Vector3(x+3,.18f,-.8f),new Vector3(x+1.7f,.18f,-.8f),counter};
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
   var route=new[]{new Vector3(x-1.7f,.18f,-1.8f),new Vector3(x+.1f,.18f,-1.8f),new Vector3(x+.1f,.18f,1.5f),new Vector3(x-1.7f,.18f,1.5f)};
   const float perimeter=10.2f;
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
  public bool Back(){if(!IsVisible)return false;if(conversation){conversation=false;return true;}Exit();return true;}
  public void CloseConversation(){conversation=false;}
 }
 public sealed class StoreInteriorPause:MonoBehaviour {
  public bool IsPaused {get;private set;}
  void OnApplicationPause(bool paused){IsPaused=paused;}
 }
 public sealed class StoreCashierHit:MonoBehaviour {}
}
