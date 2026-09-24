using System.Linq;
using Purrington.Domain;
using TMPro;
using UnityEngine;
namespace Purrington.Presentation {
 // The Neighbors page in the Cats tab and the gift shelf at Paw Mart.
 public sealed partial class HotelUI {
  string catsView="Guests";
  public void ShowNeighbors(){catsView="Neighbors";Navigate("Cats");}
  bool HasNeighbors=>NeighborContent.Current!=null&&app.Model.State.currentHotel==0;
  // Guests | Neighbors switch at the top of the Cats sheet. Returns true when the neighbors page was drawn instead.
  bool CatsSwitch(RectTransform content){
   if(!HasNeighbors){catsView="Guests";return false;}
   var row=Row(content,42*textScale);
   foreach(var view in new[]{"Guests","Neighbors"}){string v=view;Button(row,v,()=>{catsView=v;Rebuild();},catsView==v?Mint:Lilac,14);}
   if(catsView!="Neighbors")return false;
   NeighborsPage(content);
   return true;
  }
  public static string LikesLine(NeighborContent.Neighbor n,NeighborState state){
   string Known(string topic){var t=ChatterContent.Current?.FindTopic(topic);return state.learned.Contains(topic)?t?.label??topic:"?";}
   return "Loves "+Known(n.love)+" · Likes "+string.Join(", ",n.like.Select(Known))+" · Dislikes "+Known(n.dislike);
  }
  public static string WhereLine(NeighborView v,TownContent town){
   if(v==null||!v.present)return "At home";
   string place=v.place=="square"?"the square":v.place=="bench_west"||v.place=="bench_east"?"a plaza bench":v.place=="paw_mart_door"?"Paw Mart":v.place=="clothing_door"?"the clothing store":v.place=="hotel_gate"?"your front gate":"Main Street";
   return (v.walking?"Heading to ":"At ")+place;
  }
  void NeighborsPage(RectTransform content){
   var model=app.Model;
   foreach(var n in NeighborContent.Current.Neighbors){
    string id=n.id;var state=model.NeighborData(id);var view=model.Neighbor(id);int tier=Mathf.Clamp(state.tier,0,3);
    float s=textScale;
    var card=Panel("Neighbor "+n.name,content,Color.white);Height(card,176*s);
    var portrait=Rect("Portrait",card);Pin(portrait,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(10,-58*s),new Vector2(52,-16*s));
    PixelIcon(portrait,"cat",36,Hex((TownContent.Current?.CoatColor(n.coat)??"#B3824C").TrimStart('#')));
    void Line(string text,float size,Color color,bool bold,float top,float bottom,float right){var t=Text(card,text,size,color,bold);t.richText=false;Pin(t.rectTransform,new Vector2(0,1),new Vector2(1,1),new Vector2(0,1),new Vector2(62,-bottom*s),new Vector2(-right,-top*s));}
    Line(n.name,17,Ink,true,8,30,88);
    Line(n.personality,11.5f,InkSoft,false,30,46,88);
    // Three hearts, one per tier above Stranger, then progress toward the next tier.
    var hearts=Rect("Tier hearts",card);Pin(hearts,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(60,-72*s),new Vector2(140,-50*s));
    for(int i=0;i<3;i++){var slot=Rect("Heart",hearts);slot.anchorMin=slot.anchorMax=new Vector2(0,.5f);slot.anchoredPosition=new Vector2(12+i*24,0);slot.sizeDelta=new Vector2(22,22);PixelIcon(slot,"heart",18,i<tier?Coral:Lilac);}
    int next=tier<3?HotelModel.TierFriendship[tier+1]:100;
    var status=Text(card,HotelModel.TierNames[tier]+" · "+state.friendship+(tier<3?"/"+next:""),11.5f,LeafText,true);Pin(status.rectTransform,new Vector2(0,1),new Vector2(1,1),new Vector2(0,1),new Vector2(138,-72*s),new Vector2(-8,-50*s));
    string favor=model.RequestText(state);
    Line(LikesLine(n,state)+(favor.Length>0?"\nFavor: "+favor+" ("+model.RequestProgress(state)+")":""),11,InkSoft,false,76,136,8);
    Line(WhereLine(view,TownContent.Current)+" · favorite gift: "+(state.giftDay>0||tier>=2?NeighborContent.Current.FindGift(n.favoriteGift)?.name:"?"),11,InkSoft,false,138,170,8);
    var visit=Button(card,"Visit",()=>{var r=app.Model.OrderManagerNeighbor(id);if(!r.success){ShowNotice(r.message,false);return;}lifeFocus="";Navigate("Life");app.World.FollowManager(true);},view!=null&&view.present?Coral:Lilac,14);
    Pin(visit,new Vector2(1,1),new Vector2(1,1),new Vector2(1,1),new Vector2(-82,-46*s),new Vector2(-8,-8*s));
   }
   var basket=OwnedGiftSummary();
   Info(content,"GIFT BASKET",basket.Length>0?basket:"Empty · Paw Mart sells gifts");
  }
  string OwnedGiftSummary()=>string.Join(" · ",NeighborContent.Current.Gifts.Where(g=>app.Model.GiftCount(g.id)>0).Select(g=>g.name+" x"+app.Model.GiftCount(g.id)));
  // Paw Mart's gift shelf, under the specials in the Buy view.
  void GiftShelf(RectTransform content){
   if(NeighborContent.Current==null)return;
   Info(content,"GIFTS FOR NEIGHBORS","Each neighbor has a favorite. One present a day counts.");
   foreach(var g in NeighborContent.Current.Gifts){
    string id=g.id;int owned=app.Model.GiftCount(id);
    var row=Row(content,52*textScale);
    var label=Text(row,g.name+"\n<size=75%>"+g.price+" Cat Coins"+(owned>0?" · you have "+owned:"")+"</size>",14,Ink,true);label.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=2;
    Button(row,"Buy",()=>ReportCashier(app.Model.BuyGift(id)),Gold,14);
   }
  }
 }
}
