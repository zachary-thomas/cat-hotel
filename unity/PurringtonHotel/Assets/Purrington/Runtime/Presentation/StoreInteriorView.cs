using System;
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
  string managerLook="honey/solid";
  Vector3 entry,aisle,counter;
  int waypoint;
  bool walking,conversation;
  public event Action<string> CashierSelected;
  public string ActiveStoreId {get;private set;}="";
  public string OwnerName=>ActiveStoreId=="paw_mart"?"Miso":ActiveStoreId=="clothing"?"Clover":"";
  public bool IsVisible=>ActiveStoreId.Length>0;
  public bool IsConversationOpen=>conversation;
  public int VisibleStoreCount=>(pawMartRoot.gameObject.activeSelf?1:0)+(clothingRoot.gameObject.activeSelf?1:0);
  public Vector3 Focus=>new Vector3((ActiveStoreId=="paw_mart"?200:240)*VoxelWorld.Unit,1.2f,0);
  public StoreInteriorView(GodotGeometry geometry,Transform parent) {
   this.geometry=geometry;this.parent=parent;
   pawMartRoot=MainStreetArt.Group(parent,"Paw Mart interior");pawMartRoot.gameObject.AddComponent<TownInterior>();
   clothingRoot=MainStreetArt.Group(parent,"Clothing interior");clothingRoot.gameObject.AddComponent<TownInterior>();
   BuildPawMart(pawMartRoot,200*VoxelWorld.Unit);
   BuildClothing(clothingRoot,240*VoxelWorld.Unit);
   pawOwner=Owner(pawMartRoot,"Miso","ginger","tuxedo",new Vector3(200*VoxelWorld.Unit+2,.2f,1.4f),"Grocery apron","738448");
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
   foreach(float side in new[]{-2.5f,0f}){
    Furnish(root,x,"Grocery shelf",new Vector3(side,.75f,-.6f),new Vector3(1.1f,1.4f,2.7f),"B3824C");
    foreach(float z in new[]{-1.3f,-.4f,.5f})Furnish(root,x,"Produce group",new Vector3(side,1.55f,z),new Vector3(.7f,.35f,.55f),z<0?"738448":"D7AE55");
   }
   Furnish(root,x,"Chilled cabinet",new Vector3(-2.8f,1.1f,3.55f),new Vector3(2.5f,2.1f,.55f),"DCE5C5");
   Furnish(root,x,"Checkout counter",new Vector3(2,.65f,2.3f),new Vector3(3.2f,1.15f,1),"B3824C");
   Furnish(root,x,"Register",new Vector3(2.5f,1.33f,2.35f),new Vector3(.5f,.3f,.4f),"425C35");
   Furnish(root,x,"Basket stack",new Vector3(3.2f,.32f,-2.4f),new Vector3(.8f,.55f,.8f),"BF7958");
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
   ActiveStoreId=storeId;conversation=walking=false;waypoint=0;
   pawMartRoot.gameObject.SetActive(storeId=="paw_mart");clothingRoot.gameObject.SetActive(storeId=="clothing");
   float x=(storeId=="paw_mart"?200:240)*VoxelWorld.Unit;
   entry=new Vector3(x,.18f,-3);aisle=new Vector3(x+.8f,.18f,-.6f);counter=new Vector3(x+2,.18f,.35f);
   managerRoot.localPosition=entry;managerRoot.localRotation=Quaternion.identity;managerRoot.gameObject.SetActive(true);
  }
  public void Exit(){conversation=walking=false;ActiveStoreId="";pawMartRoot.gameObject.SetActive(false);clothingRoot.gameObject.SetActive(false);managerRoot.gameObject.SetActive(false);}
  public bool SelectCashier(){if(!IsVisible||walking||conversation)return false;walking=true;waypoint=0;return true;}
  public void Advance(float seconds,bool motion){
   if(!IsVisible)return;
   pawOwner.Advance(seconds,motion,"rest",false);clothingOwner.Advance(seconds,motion,"rest",false);
   if(!walking){manager.Advance(seconds,motion,"rest",false);return;}
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
  public bool Back(){if(!IsVisible)return false;if(conversation){conversation=false;return true;}Exit();return true;}
  public void CloseConversation(){conversation=false;}
 }
 public sealed class StoreCashierHit:MonoBehaviour {}
}
