using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using TMPro;
using UnityEngine;

namespace Purrington.Presentation {
 // B2 paint tool: pick Walls, Floor or Items and a swatch, then tap rooms or furnishings. Each tap saves and can be undone.
 // The eyedropper picks up the color of whatever is tapped next.
 public sealed partial class HotelUI {
  bool eyedropper;
  const string PaintTool="paint";
  public bool IsPainting=>commandAction==PaintTool;
  string PaintSurface=>(string)commandPayload?["surface"]??"wall";
  public void BeginPaint(){BeginCommand(PaintTool,new JObject{{"surface","wall"},{"paint","buttercream"},{"floorPaint","maple"},{"tint",1}},"Paint & style");eyedropper=false;}
  string PaintChoiceName(){
   string surface=PaintSurface;
   if(surface=="item")return Paint.Tints[(int)commandPayload["tint"]];
   return (surface=="wall"?Paint.Wall((string)commandPayload["paint"]):Paint.Floor((string)commandPayload["floorPaint"]))?.name??"";
  }
  string PaintHint()=>eyedropper?"Eyedropper · tap a room or furnishing to copy its color.":PaintSurface=="item"?"Tap a furnishing to make it "+PaintChoiceName()+".":"Tap a room to paint its "+(PaintSurface=="wall"?"walls ":"floor ")+PaintChoiceName()+" · 3 coins a tile.";

  // Surfaces and the eyedropper share the options row; swatches get their own row below it.
  void PaintOptions(System.Collections.Generic.List<(string,bool,Action)> list){
   foreach(var (surface,label) in new[]{("wall","Walls"),("floor","Floor"),("item","Items")}){string chosen=surface;list.Add((label,!eyedropper&&PaintSurface==surface,()=>{commandPayload["surface"]=chosen;eyedropper=false;hasTarget=false;Rebuild();}));}
   list.Add(("Eyedropper",eyedropper,()=>{eyedropper=!eyedropper;hasTarget=false;Rebuild();}));
  }
  void PaintSwatches(RectTransform stack){
   var row=Row(stack,44);row.name="Paint swatches";
   string surface=PaintSurface;
   if(surface=="item"){for(int i=0;i<Paint.Tints.Length;i++){int tint=i;Swatch(row,Paint.Tints[i],i==0?Color.white:Color.HSVToRGB(Paint.TintHues[i]/360f,.42f,.93f),(int)commandPayload["tint"]==i,()=>{commandPayload["tint"]=tint;eyedropper=false;hasTarget=false;Rebuild();});}return;}
   var swatches=surface=="wall"?Paint.Walls:Paint.Floors;string key=surface=="wall"?"paint":"floorPaint";
   foreach(var s in swatches){string id=s.id;string main=s.main??(surface=="wall"?"fff8e9":"D2AD77");Swatch(row,s.id.Length==0?"House":s.name,Hex(main),(string)commandPayload[key]==id,()=>{commandPayload[key]=id;eyedropper=false;hasTarget=false;Rebuild();});}
  }
  void Swatch(RectTransform row,string label,Color color,bool on,Action act){
   var chip=Button(row,label,act,color,10);chip.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   var text=chip.GetComponentInChildren<TextMeshProUGUI>();text.enableAutoSizing=true;text.fontSizeMin=7;text.fontSizeMax=10;text.textWrappingMode=TextWrappingModes.NoWrap;
   if(on){var ring=chip.gameObject.AddComponent<UnityEngine.UI.Outline>();ring.effectColor=Ink;ring.effectDistance=new Vector2(3,-3);text.fontStyle=FontStyles.Bold;}
  }

  // Taps while painting arrive as room or furnishing selections.
  bool PaintRoomTap(string roomId){
   if(!IsPainting)return false;
   var room=app.Model.State.rooms.FirstOrDefault(r=>r.id==roomId);if(room==null)return true;
   if(eyedropper){
    string surface=PaintSurface=="floor"?"floor":"wall";
    if(surface=="wall"&&!Paint.HasWalls(room))surface="floor";
    if(surface=="wall")commandPayload["paint"]=room.wallPaint;else commandPayload["floorPaint"]=room.floorPaint;
    commandPayload["surface"]=surface;eyedropper=false;hasTarget=false;Rebuild();ShowNotice("Picked up "+PaintChoiceName()+(surface=="wall"?" walls":" floor"),false);return true;
   }
   if(PaintSurface=="item"){ShowNotice("Tap a furnishing to restyle it, or choose Walls or Floor.",false);return true;}
   string paint=PaintSurface=="wall"?(string)commandPayload["paint"]:(string)commandPayload["floorPaint"];
   RunPaint("paint_room",new JObject{{"id",roomId},{"surface",PaintSurface},{"paint",paint}});
   return true;
  }
  bool PaintObjectTap(string objectId){
   if(!IsPainting)return false;
   var item=app.Model.State.objects.FirstOrDefault(o=>o.id==objectId);if(item==null)return true;
   if(eyedropper){commandPayload["tint"]=item.tint;commandPayload["surface"]="item";eyedropper=false;hasTarget=false;Rebuild();ShowNotice("Picked up "+PaintChoiceName(),false);return true;}
   if(PaintSurface!="item"){var room=RoomUnder(item);if(room!=null)PaintRoomTap(room.id);else ShowNotice("That furnishing isn't in a room · choose Items to restyle it.",false);return true;}
   RunPaint("tint_object",new JObject{{"id",objectId},{"tint",(int)commandPayload["tint"]}});
   return true;
  }
  RoomState RoomUnder(ObjectState o){
   if(!string.IsNullOrEmpty(o.room)){var owner=app.Model.State.rooms.FirstOrDefault(r=>r.id==o.room);if(owner!=null)return owner;}
   HotelModel.Size(o,out float w,out float d);return app.Model.State.rooms.FirstOrDefault(r=>r.floor==o.floor&&HotelModel.RoomHas(r,o.x+w/2,o.z+d/2));
  }
  void RunPaint(string action,JObject payload){
   var result=app.Model.Execute(action,payload);app.Report(result);
   if(result.success){app.Audio?.PlayEffect("build");string vibe=action=="paint_room"?" · "+app.Model.Vibe((string)payload["id"]).Label:"";ApplyToolStatus(result.message+vibe+(result.cost>0?" · "+result.cost.ToString("N0")+" coins":""),true);}
   else ApplyToolStatus(result.message,false);
   hasTarget=true;
  }
  public void ShowDesigns(){Navigate("Build");buildMode="Furnish";category="Sets";Rebuild();}

  // B3 saved designs, listed first under Furnish → Sets. Each card places a copy; Forget removes the design.
  void DesignCards(RectTransform content){
   var designs=app.Model.State.blueprints;
   if(designs.Count==0){Info(content,"YOUR DESIGNS","Tap a decorated room and choose Save to keep its paint and furniture as a design you can place again.");return;}
   var label=Text(content,"YOUR DESIGNS · "+designs.Count+"/"+HotelModel.BlueprintLimit,12,InkSoft,true);Height(label.rectTransform,24);
   foreach(var b in designs.ToList()){
    string id=b.id;var payload=new JObject{{"blueprint",id},{"rotation",0}};
    var vibe=HotelModel.Vibe(new RoomState{kind=b.kind,width=b.w,depth=b.h,wallPaint=b.wallPaint,floorPaint=b.floorPaint},b.items.Select(i=>new ObjectState{itemId=i.itemId,x=i.x,z=i.z,rotation=i.rotation,tint=i.tint}).ToList());
    CatalogCard(content,b.name,b.w+" × "+b.h+" · "+b.items.Count+" pieces · "+vibe.Label,app.Model.BlueprintPrice(b),()=>BeginCommand("place_blueprint",payload,b.name),Gold,"room");
    var card=(RectTransform)content.GetChild(content.childCount-1);
    var forget=Button(card,"Forget",()=>{var r=app.Model.DeleteBlueprint(id);app.Report(r);ShowNotice(r.message,!r.success);Rebuild();},Lilac,11);forget.name="Forget design";
    Pin(forget,Vector2.one,Vector2.one,Vector2.one,new Vector2(-84,-40),new Vector2(-8,-8));
   }
   var more=Text(content,"ARRANGEMENTS",12,InkSoft,true);Height(more.rectTransform,24);
  }
 }
}
