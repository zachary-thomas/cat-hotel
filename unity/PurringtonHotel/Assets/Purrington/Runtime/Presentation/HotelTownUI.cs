using Purrington.Domain;
using System.Linq;
using TMPro;
using UnityEngine;
namespace Purrington.Presentation {
 public sealed class HotelTownUI {
  // Refresh only explicit successful cashier commands; idle wallet updates stay lightweight.
  public static void RefreshCashier(CommandResult result,System.Action refresh,System.Action<CommandResult> report){if(result.success)refresh();report(result);}
  readonly HotelApp app;
  public HotelTownUI(HotelApp app){this.app=app;}
  public void Explore()=>app.UI.ExploreMainStreet();
  public void Follow()=>app.World.FocusManager();
  public void Skip()=>app.Report(app.Model.SkipManagerTravel());
  public void Rename(string name)=>app.Report(app.Model.RenameManager(name));
  public void Destination(string id){
   var state=app.Model.Hotel(0).town;
   if(state.destination==""&&state.shop.Length>0&&TownContent.Current.Shop(state.shop)?.door==id){app.World.EnterStoreInterior(state.shop);app.UI.StoreArrived(id);return;}
   app.Report(app.Model.SendManager(id));
  }
  public void SelectStore(string id){var store=TownContent.Current.Shop(id);if(store!=null)Destination(store.door);}
 }
 public sealed partial class HotelUI {
  bool managerEditing;string townCoat,townMarkings,townName,storeChoice="";
  public void StoreArrived(string target){if(tab=="Town"&&app.World.StoreInterior.IsVisible){storeChoice="";Rebuild();}}
  public void CashierArrived(string id){if(tab=="Town"){storeChoice="";Rebuild();}}
  void LeaveStore(){storeChoice="";app.World.ExitStoreInterior();Rebuild();}
  bool BackFromStore(){
   var interior=app.World.StoreInterior;
   if(interior==null||!interior.IsVisible)return false;
   if(storeChoice.Length>0){storeChoice="";Rebuild();return true;}
   if(interior.IsConversationOpen){interior.CloseConversation();Rebuild();return true;}
   LeaveStore();return true;
  }
  public void ExploreMainStreet(){
   if(app.Model.State.currentHotel!=0){ShowNotice("Main Street is at Meadow House.",false);return;}
   if(careCat>=0){CloseWardrobe();app.World.SetCareMode(careCat,false);}
   careCat=-1;settings=false;CancelPlacement(false);managerEditing=false;tab="Town";
   app.World.EnterTownMode();Rebuild();app.World.FocusManager();
  }
  void CloseTown(){managerEditing=false;app.World.ClearManagerPreview();app.World.ExitTownMode();tab="Hotel";Rebuild();}
  void TownPanel(){
   var interior=app.World.StoreInterior;
   if(interior!=null&&interior.IsVisible){StorePanel(interior);return;}
   var content=Sheet(managerEditing?"Manager look":"Main Street",app.Model.State.managerName,managerEditing?.57f:.39f);
   var controls=Row(content,48*textScale);
   Button(controls,"Follow",app.TownUI.Follow,Mint,13);Button(controls,"Fit street",app.World.FitTown,Lilac,13);Button(controls,"Skip walk",app.TownUI.Skip,Gold,13);
   if(!managerEditing){
    var destinations=Row(content,48*textScale);Button(destinations,"Paw Mart",()=>app.TownUI.Destination("paw_mart_door"),Mint,13);Button(destinations,"Clothing",()=>app.TownUI.Destination("clothing_door"),Coral,13);
    var next=Row(content,48*textScale);Button(next,"Square",()=>app.TownUI.Destination("square"),Gold,13);Button(next,"Manager",()=>{managerEditing=true;townCoat=app.Model.State.managerCoat;townMarkings=app.Model.State.managerMarkings;townName=app.Model.State.managerName;Rebuild();app.World.FocusManagerAppearance();},Mint,13);
    var back=Row(content,48*textScale);Button(back,"Fit hotel",()=>app.World.FitHotel(),Lilac,13);Button(back,"Back to Hotel",CloseTown,Cream,13);
    return;
   }
   var field=Panel("Manager name",content,Cream);Height(field,48*textScale);
   var input=field.gameObject.AddComponent<TMP_InputField>();input.targetGraphic=field.GetComponent<UnityEngine.UI.Image>();
   var viewport=Rect("Name viewport",field);Stretch(viewport,10,4,10,4);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
   var label=Text(viewport,townName,16,Ink);Stretch(label.rectTransform);label.richText=false;input.textViewport=viewport;input.textComponent=label;input.text=townName;input.characterLimit=48;input.onValueChanged.AddListener(value=>townName=value);
   var rename=Button(content,"Rename",()=>{app.TownUI.Rename(townName);},Gold,14);Height(rename,48*textScale);
   for(int row=0;row<2;row++){
    var choices=Row(content,48*textScale);for(int col=0;col<3;col++){string coat=ManagerCatArt.Coats[row*3+col];Button(choices,coat,()=>{townCoat=coat;app.World.PreviewManagerAppearance(townCoat,townMarkings);Rebuild();},townCoat==coat?Mint:Cream,13);}
   }
   for(int row=0;row<2;row++){
    var choices=Row(content,48*textScale);for(int col=0;col<2;col++){string marking=ManagerCatArt.Markings[row*2+col];Button(choices,marking,()=>{townMarkings=marking;app.World.PreviewManagerAppearance(townCoat,townMarkings);Rebuild();},townMarkings==marking?Mint:Cream,13);}
   }
   var actions=Row(content,48*textScale);
   Button(actions,"Save look",()=>{var result=app.Model.SetManagerAppearance(townCoat,townMarkings);app.Report(result);if(result.success){managerEditing=false;app.World.ClearManagerPreview();Rebuild();app.World.FocusManager();}},Mint,14);
   Button(actions,"Cancel",()=>{managerEditing=false;app.World.ClearManagerPreview();Rebuild();app.World.FocusManager();},Lilac,14);
  }
  void ReportCashier(CommandResult result)=>HotelTownUI.RefreshCashier(result,Rebuild,value=>app.Report(value));
  void StorePanel(StoreInteriorView interior){
   string name=interior.OwnerName;
   var content=Sheet(interior.ActiveStoreId=="paw_mart"?"Paw Mart":"Thread & Paw",interior.IsConversationOpen?name+" · cashier":"Tap "+name+" at the counter",.48f);
   if(!interior.IsConversationOpen){
    var row=Row(content,52*textScale);Button(row,"Meet "+name,()=>{if(app.World.SelectStoreCashier())Rebuild();},Mint,14);Button(row,"Leave",LeaveStore,Cream,14);
    Info(content,"INSIDE THE SHOP","Walk to the cashier to talk, see quests, or browse.");return;
   }
   if(storeChoice.Length>0){
    if(storeChoice=="Talk")Info(content,"Talk",interior.ActiveStoreId=="paw_mart"?"Miso: Welcome in! These specials are optional treats for your hotel.":"Clover: Accept First Look for a free ribbon, then equip it on your manager.");
    else if(storeChoice=="Quest"){
     foreach(var quest in TownContent.Current.Quests.Where(q=>(string)q["store"]==interior.ActiveStoreId)){
      string id=(string)quest["id"];bool accepted=app.Model.TownQuestAccepted(id),done=app.Model.TownQuestCompleted(id);
      Info(content,(string)quest["name"],done?"Completed · reward claimed":accepted?"Accepted":id=="first_look"?"Free ribbon · equip it on your manager":"Welcome Basket · 30 Cat Coins · invite Biscuit");
      if(!done){Height(Button(content,accepted?"Complete quest":"Accept quest",()=>ReportCashier(accepted?app.Model.CompleteTownQuest(id):app.Model.AcceptTownQuest(id)),Gold,14),52*textScale);
       if(id=="first_look"&&accepted)Height(Button(content,"Equip store ribbon",()=>ReportCashier(app.Model.DressManager("neck","store_ribbon")),Mint,14),52*textScale);}
     }
    }else if(interior.ActiveStoreId=="paw_mart"){
     foreach(var offer in TownContent.Current.Offers.Where(o=>(string)o["store"]=="paw_mart")){
      string id=(string)offer["id"];bool owned=app.Model.TownInventory.Contains(id);
      Info(content,(string)offer["name"],(string)offer["price"]+" Cat Coins · "+(owned?"Owned · ready to use":"Available"));
      if(!owned)Height(Button(content,"Buy "+(string)offer["name"],()=>ReportCashier(app.Model.BuyTownItem(id)),Gold,14),52*textScale);
     }
    }else{
     foreach(var wear in Wardrobe.All){
      string id=wear.id,slot=wear.slot;bool owned=app.Model.OwnsWear(id);
      Info(content,wear.name,owned?"Owned":wear.quest!=null?"Free · First Look quest":wear.giftCat>=0?"Friendship gift · "+app.Model.State.cats[wear.giftCat].name:wear.price+" Cat Coins");
      if(owned)Height(Button(content,"Equip on manager",()=>ReportCashier(app.Model.DressManager(slot,id)),Mint,14),52*textScale);
      else if(wear.giftCat<0&&wear.quest==null)Height(Button(content,"Buy "+wear.name,()=>ReportCashier(app.Model.BuyWear(id)),Gold,14),52*textScale);
     }
    }
    Height(Button(content,"Back to "+name,()=>{storeChoice="";Rebuild();},Mint,14),52*textScale);return;
   }   var choices=Row(content,54*textScale);Button(choices,"Talk",()=>{storeChoice="Talk";Rebuild();},Mint,14);Button(choices,"Quest",()=>{storeChoice="Quest";Rebuild();},Gold,14);
   var actions=Row(content,54*textScale);Button(actions,"Buy",()=>{storeChoice="Buy";Rebuild();},Coral,14);Button(actions,"Leave",LeaveStore,Cream,14);
  }
 }
}
