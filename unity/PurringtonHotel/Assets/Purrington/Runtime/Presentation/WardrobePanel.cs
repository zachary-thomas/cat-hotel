using System;
using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    public sealed partial class HotelUI
    {
        bool wardrobeOpen;
        string wardrobeSlot="head", tryingOn="";

        void OpenWardrobe()
        {
            gestureInput?.Suspend();
            wardrobeOpen=true;
            wardrobeSlot="head";
            tryingOn="";
            WardrobePreviewActual();
            Rebuild();
        }

        void CloseWardrobe()
        {
            if(!wardrobeOpen)return;
            wardrobeOpen=false;
            tryingOn="";
            WardrobePreviewActual();
        }

        void WardrobePreviewActual()
        {
            if(careCat<0||app?.Model?.State?.cats==null)return;
            var cat=app.Model.State.cats.FirstOrDefault(c=>c.id==careCat);
            if(cat!=null)app.World?.PreviewOutfit(cat.outfit);
        }

        void WardrobePanel()
        {
            var cat=app.Model.State.cats.First(c=>c.id==careCat);
            var panel=Panel("Wardrobe",safe,Cream);
            if(wideLayout)Pin(panel,new Vector2(1,0),Vector2.one,new Vector2(1,.5f),new Vector2(-360,12),new Vector2(-12,-76));
            else Pin(panel,Vector2.zero,new Vector2(1,.48f),Vector2.zero,new Vector2(10,10),new Vector2(-10,0));

            var title=Text(panel,cat.name+"'s wardrobe",18,Ink,true);
            Pin(title.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-55),new Vector2(-105,-7));
            var back=Button(panel,"Back",()=>{CloseWardrobe();Rebuild();},Gold,13);
            Pin(back,new Vector2(1,1),Vector2.one,Vector2.one,new Vector2(-92,-55),new Vector2(-9,-7));

            var content=Scroll(panel,62,10);
            scrollKey="Wardrobe/"+wardrobeSlot;
            var slots=Row(content,48);
            foreach(var slot in Wardrobe.Slots)
            {
                string chosen=slot;
                Button(slots,char.ToUpper(slot[0])+slot.Substring(1),()=>
                {
                    wardrobeSlot=chosen;
                    tryingOn="";
                    WardrobePreviewActual();
                    Rebuild();
                },slot==wardrobeSlot?Gold:Mint,13);
            }

            cat.outfit.TryGetValue(wardrobeSlot,out var worn);
            Card(content,"Nothing","Leave this slot undressed.","Take off",()=>Wear(cat.id,""),Mint);
            foreach(var wear in Wardrobe.All.Where(w=>w.slot==wardrobeSlot))
            {
                var item=wear;
                bool owned=app.Model.OwnsWear(item.id);
                string note=item.id==worn?"Wearing now":owned?"In the wardrobe":item.giftCat>=0?"Gift from "+app.Model.State.cats[item.giftCat].name+" at friendship "+item.giftBond:item.price.ToString("N0")+" coins";
                string action=item.id==worn?"Worn":owned?"Wear":item.giftCat>=0?"Locked":tryingOn==item.id?"Buy & wear":"Try on";
                Card(content,item.name,note,action,()=>
                {
                    if(owned){Wear(cat.id,item.id);return;}
                    if(item.giftCat>=0){ShowNotice(note,false);return;}
                    if(tryingOn!=item.id)
                    {
                        tryingOn=item.id;
                        var preview=new Dictionary<string,string>(cat.outfit);
                        preview[item.slot]=item.id;
                        app.World.PreviewOutfit(preview);
                        Rebuild();
                        return;
                    }
                    var bought=app.Model.BuyWear(item.id);
                    app.Report(bought);
                    if(!bought.success){ShowNotice(bought.message,true);return;}
                    app.Audio?.PlayEffect("spend");
                    Wear(cat.id,item.id);
                },item.id==worn?Gold:Mint,item.id!=worn);
            }
        }

        void Wear(int catId,string id)
        {
            var result=app.Model.Dress(catId,wardrobeSlot,id);
            tryingOn="";
            app.Report(result);
            WardrobePreviewActual();
            Rebuild();
            ShowNotice(result.message,!result.success);
        }
    }
}
