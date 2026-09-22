using Purrington.Domain;
using TMPro;
using UnityEngine;
namespace Purrington.Presentation {
 public sealed class HotelTownUI {
  readonly HotelApp app;
  public HotelTownUI(HotelApp app){this.app=app;}
  public void Explore()=>app.UI.ExploreMainStreet();
  public void Follow()=>app.World.FocusManager();
  public void Skip()=>app.Report(app.Model.SkipManagerTravel());
  public void Rename(string name)=>app.Report(app.Model.RenameManager(name));
  public void Destination(string id)=>app.Report(app.Model.SendManager(id));
  public void SelectStore(string id){var store=TownContent.Current.Shop(id);if(store!=null)Destination(store.door);}
 }
 public sealed partial class HotelUI {
  bool managerEditing;string townCoat,townMarkings,townName;
  public void ExploreMainStreet(){
   if(app.Model.State.currentHotel!=0){ShowNotice("Main Street is at Meadow House.",false);return;}
   if(careCat>=0)app.World.SetCareMode(careCat,false);
   careCat=-1;settings=false;CancelPlacement(false);managerEditing=false;tab="Town";
   app.World.EnterTownMode();Rebuild();app.World.FocusManager();
  }
  void CloseTown(){managerEditing=false;app.World.ClearManagerPreview();app.World.ExitTownMode();tab="Hotel";Rebuild();}
  void TownPanel(){
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
 }
}
