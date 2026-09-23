using System;
using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation {
public sealed partial class HotelUI {
 bool wardrobeOpen;
 string wardrobeSlot="head",tryingOn="";

 void WardrobePanel(RectTransform content) {
  var cat=app.Model.State.cats.First(c=>c.id==careCat);
  var slots=Row(content,48*textScale);
  foreach(var slot in Wardrobe.Slots) {
   var chosen=slot;
   Button(slots,char.ToUpper(slot[0])+slot.Substring(1),()=>{wardrobeSlot=chosen;tryingOn="";app.World.PreviewOutfit(cat.outfit);Rebuild();},slot==wardrobeSlot?Gold:Mint,13);
  }
  cat.outfit.TryGetValue(wardrobeSlot,out var worn);
  Card(content,"Nothing","Leave this spot bare.","Take off",()=>Wear(cat.id,""),Mint,!string.IsNullOrEmpty(worn));
  foreach(var wear in Wardrobe.All.Where(w=>w.slot==wardrobeSlot)) {
   var item=wear;bool owned=app.Model.OwnsWear(item.id),wearing=item.id==worn,gift=item.giftCat>=0;
   string giftNote=gift&&item.giftCat<app.Model.State.cats.Count?"Gift from "+app.Model.State.cats[item.giftCat].name+" at friendship "+item.giftBond:"Friendship gift";
   bool questLocked=!owned&&item.quest!=null;
   string note=questLocked?"Free from First Look at Thread & Paw":wearing?"Wearing now":gift?giftNote:owned?"In the wardrobe":item.price.ToString("N0")+" coins";
   string action=questLocked?"Quest reward":wearing?"Worn":owned?"Wear":gift?"Locked":tryingOn==item.id?"Buy & wear":"Try on";
   Card(content,item.name,note,action,()=>{
    if(owned){Wear(cat.id,item.id);return;}
    if(gift||questLocked)return;
    if(tryingOn!=item.id){tryingOn=item.id;var preview=CareTryOnOutfit(cat.outfit,item.slot,item.id);app.World.PreviewOutfit(preview);Rebuild();return;}
    var bought=app.Model.BuyWear(item.id);
    if(!bought.success){app.Report(bought);app.World.PreviewOutfit(app.Model.State.cats.First(c=>c.id==cat.id).outfit);tryingOn="";Rebuild();return;}
    app.Audio?.PlayEffect("spend");Wear(cat.id,item.id);
   },wearing?Gold:Mint,!wearing&&!questLocked&&(owned||!gift));
  }
 }

 public static Dictionary<string,string> CareTryOnOutfit(Dictionary<string,string> outfit,string slot,string id){var preview=new Dictionary<string,string>(outfit);preview[slot]=id;return preview;}
 void Wear(int catId,string id){var result=app.Model.Dress(catId,wardrobeSlot,id);tryingOn="";app.Report(result);app.World.PreviewOutfit(app.Model.State.cats.First(c=>c.id==catId).outfit);Rebuild();}
 void CloseWardrobe(){if(!wardrobeOpen)return;wardrobeOpen=false;tryingOn="";if(careCat>=0){var cat=app.Model.State.cats.FirstOrDefault(c=>c.id==careCat);if(cat!=null)app.World.PreviewOutfit(cat.outfit);}}
}
}
