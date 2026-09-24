using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
// Saved room designs (B3): a decorated room's kind, size, paint and furnishings, kept in the room's own unrotated frame
// so a copy can be placed anywhere, like the built-in Arrangements. Designs are shared by every destination.
[Serializable] public sealed class BlueprintItem {public string itemId;public float x,z;public int rotation,tint;}
[Serializable] public sealed class BlueprintState {public string id,name,kind,wallPaint="",floorPaint="";public int w,h;public List<BlueprintItem> items=new List<BlueprintItem>();}
public sealed partial class HotelModel {
 public const int BlueprintLimit=12;
 public BlueprintState Blueprint(string id)=>State.blueprints.Find(b=>b.id==id);
 // What placing a design costs before land or layout checks: the room, its paint and every piece.
 public double BlueprintPrice(BlueprintState b){if(b==null||State.settings.godMode)return 0;var r=new RoomState{kind=b.kind,width=b.w,depth=b.h};double paint=PaintPrice(r)*((b.wallPaint.Length>0?1:0)+(b.floorPaint.Length>0?1:0));return b.w*b.h*25+paint+b.items.Sum(i=>Catalog.Find(i.itemId)?.price??0);}
 public CommandResult SaveBlueprint(string roomId){
  var r=Hotel().rooms.Find(v=>v.id==roomId);
  if(r==null)return CommandResult.Fail("Choose a room to save.");
  if(r.kind=="stairs")return CommandResult.Fail("Stairs can't be saved as a design.");
  if(State.blueprints.Count>=BlueprintLimit)return CommandResult.Fail("You can keep "+BlueprintLimit+" designs · forget one first.");
  var design=new BlueprintState{id="design"+State.nextId,name=string.IsNullOrEmpty(r.name)?"My design":r.name,kind=r.kind,w=r.width,h=r.depth,wallPaint=r.wallPaint,floorPaint=r.floorPaint};
  int turns=(4-r.rotation)%4;var frame=new LotRect(0,0,r.width,r.depth);
  foreach(var o in RoomObjects(r)){
   var copy=new ObjectState{itemId=o.itemId,x=o.x,z=o.z,rotation=o.rotation};TransformObject(copy,Rect(r),frame,turns);
   Size(copy,out float w,out float d);if(copy.x<0||copy.z<0||copy.x+w>r.width||copy.z+d>r.depth)continue;
   design.items.Add(new BlueprintItem{itemId=o.itemId,x=copy.x,z=copy.z,rotation=copy.rotation,tint=o.tint});
  }
  return Transaction(()=>{State.nextId++;State.blueprints.Add(design);},"Saved "+design.name+" · "+design.items.Count+" pieces · find it in Furnish → Sets");
 }
 public CommandResult DeleteBlueprint(string id){var b=Blueprint(id);if(b==null)return CommandResult.Fail("That design is already gone.");return Transaction(()=>State.blueprints.RemoveAll(v=>v.id==id),"Forgot "+b.name);}
 public CommandResult RenameBlueprint(string id,string name){var b=Blueprint(id);name=(name??"").Trim();if(b==null)return CommandResult.Fail("Choose a design.");if(name.Length==0||name.Length>32)return CommandResult.Fail("Names are 1 to 32 letters.");return Transaction(()=>b.name=name,"Renamed to "+name);}
 CommandResult ApplyBlueprint(JObject p,HotelData h){
  var b=Blueprint((string)p["blueprint"]);if(b==null)return CommandResult.Fail("Choose a saved design.");
  if(!Whole(p["x"])||!Whole(p["y"]))return CommandResult.Fail("Place the design on the grid.");
  var r=new RoomState{id=Id("space"),kind=b.kind,name=b.name,x=(int)p["x"],z=(int)p["y"],width=b.w,depth=b.h,rotation=(int?)p["rotation"]??0,floor=(int?)p["floor"]??0,wallPaint=b.wallPaint,floorPaint=b.floorPaint};
  if(!RoomShape(r))return CommandResult.Fail("This design no longer fits the room rules.");
  double cost=r.paid=Price(r.width*r.depth*25);h.rooms.Add(r);
  if(r.wallPaint.Length>0)cost+=Price(PaintPrice(r));if(r.floorPaint.Length>0)cost+=Price(PaintPrice(r));
  foreach(var item in b.items){var def=Catalog.Find(item.itemId);if(def==null)continue;var o=new ObjectState{id=Id("object"),itemId=item.itemId,x=item.x,z=item.z,rotation=item.rotation,tint=item.tint,room=r.id,floor=r.floor,paid=Price(def.price)};TransformObject(o,new LotRect(0,0,b.w,b.h),Rect(r),r.rotation);cost+=o.paid;h.objects.Add(o);}
  return CommandResult.Ok(b.name+" placed",cost);
 }
 static bool ValidBlueprints(HotelState s){
  if(s.blueprints==null||s.blueprints.Count>BlueprintLimit)return false;var ids=new HashSet<string>();
  foreach(var b in s.blueprints){
   if(b==null||string.IsNullOrEmpty(b.id)||!ids.Add(b.id)||string.IsNullOrEmpty(b.name)||b.name.Length>64||b.items==null)return false;
   if(!RoomShape(new RoomState{kind=b.kind,width=b.w,depth=b.h})||Paint.Wall(b.wallPaint)==null||Paint.Floor(b.floorPaint)==null)return false;
   foreach(var i in b.items){if(i==null||Catalog.Find(i.itemId)==null||i.rotation<0||i.rotation>3||!Paint.ValidTint(i.tint)||!Finite(i.x)||!Finite(i.z)||i.x*2!=Math.Floor(i.x*2)||i.z*2!=Math.Floor(i.z*2)||i.x<0||i.z<0||i.x>b.w||i.z>b.h)return false;}
  }
  return true;
 }
}
}
