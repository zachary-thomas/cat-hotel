using System;
using System.Linq;
using Newtonsoft.Json.Linq;
namespace Purrington.Domain {
// Paint for rooms and a tint for furnishings, a small version of The Sims' paint tool and Create-a-Style. An empty id is the
// destination's own house style. Walls carry a main tone and a wainscot trim; floors carry one board color.
public sealed class PaintSwatch {public string id,name,main,trim;}
public static class Paint {
 public static readonly PaintSwatch[] Walls={
  new PaintSwatch{id="",name="House style"},
  new PaintSwatch{id="buttercream",name="Buttercream",main="F7E7B8",trim="C9A55A"},
  new PaintSwatch{id="rose",name="Rose",main="F6D5D3",trim="C7867E"},
  new PaintSwatch{id="mint",name="Mint",main="DDEFE0",trim="6E9B7A"},
  new PaintSwatch{id="sky",name="Sky",main="D8E9F0",trim="6F9DB3"},
  new PaintSwatch{id="lilac",name="Lilac",main="E6DDF0",trim="8E7AA8"},
  new PaintSwatch{id="cocoa",name="Cocoa",main="EAD9C6",trim="7A5A44"},
  new PaintSwatch{id="moss",name="Moss",main="E8EBD8",trim="5E6E43"}};
 public static readonly PaintSwatch[] Floors={
  new PaintSwatch{id="",name="House style"},
  new PaintSwatch{id="maple",name="Maple",main="E0BC86"},
  new PaintSwatch{id="walnut",name="Walnut",main="8E6446"},
  new PaintSwatch{id="ash",name="Ash",main="D9CFBF"},
  new PaintSwatch{id="cherry",name="Cherry",main="B06F55"},
  new PaintSwatch{id="sage",name="Sage",main="A9BB94"},
  new PaintSwatch{id="slate",name="Slate",main="9AA3A8"},
  new PaintSwatch{id="blush",name="Blush",main="F0C4BE"}};
 // Item tints re-hue a furnishing's colorful parts; wood and neutral parts keep their color. Hue is in degrees.
 public static readonly string[] Tints={"Original","Rose","Sage","Sky","Honey"};
 public static readonly float[] TintHues={-1,350,105,200,42};
 public static PaintSwatch Wall(string id)=>Walls.FirstOrDefault(s=>s.id==(id??""));
 public static PaintSwatch Floor(string id)=>Floors.FirstOrDefault(s=>s.id==(id??""));
 public static bool ValidTint(int tint)=>tint>=0&&tint<Tints.Length;
 public static bool HasWalls(RoomState r)=>r.kind!="terrace"&&r.kind!="garden"&&r.kind!="stairs";
 public static bool HasBoards(RoomState r)=>r.kind!="garden"&&r.kind!="stairs";
}
public sealed partial class HotelModel {
 // Paint is priced by the room's footprint, so a big lounge costs more than a closet. Tints cost a tenth of the item.
 static int PaintArea(RoomState r){if(r.cells!=null)return r.cells.Count;RoomSize(r,out float w,out float d);return (int)Math.Ceiling(w*d);}
 public static double PaintPrice(RoomState r)=>Math.Max(10,PaintArea(r)*3);
 public static double TintPrice(ItemDefinition item)=>Math.Max(5,Math.Round((item?.price??0)*.1));
 CommandResult ApplyPaint(string action,JObject p,HotelData h){
  string id=(string)p["id"]??"";
  if(action=="tint_object"){
   var o=h.objects.Find(v=>v.id==id);if(o==null)return CommandResult.Fail("Tap a furnishing to restyle it.");
   if(p["tint"]==null||!Whole(p["tint"]))return CommandResult.Fail("Choose a style.");int tint=(int)p["tint"];if(!Paint.ValidTint(tint))return CommandResult.Fail("Choose a style.");
   var item=Catalog.Find(o.itemId);if(o.tint==tint)return CommandResult.Fail("It already looks like that.");
   o.tint=tint;return CommandResult.Ok((item?.name??"Furnishing")+" · "+Paint.Tints[tint],Price(TintPrice(item)));
  }
  var r=h.rooms.Find(v=>v.id==id);if(r==null)return CommandResult.Fail("Tap a room to paint it.");
  string surface=(string)p["surface"]??"",paint=(string)p["paint"]??"";
  if(surface=="wall"){
   if(!Paint.HasWalls(r))return CommandResult.Fail(r.kind=="stairs"?"Stairs keep their wood.":"This space has no walls to paint.");
   var swatch=Paint.Wall(paint);if(swatch==null)return CommandResult.Fail("Choose a wall color.");
   if(r.wallPaint==swatch.id)return CommandResult.Fail("These walls are already "+swatch.name+".");
   r.wallPaint=swatch.id;return CommandResult.Ok(r.name+" walls · "+swatch.name,Price(PaintPrice(r)));
  }
  if(surface=="floor"){
   if(!Paint.HasBoards(r))return CommandResult.Fail(r.kind=="garden"?"Gardens keep their grass.":"Stairs keep their wood.");
   var swatch=Paint.Floor(paint);if(swatch==null)return CommandResult.Fail("Choose a floor color.");
   if(r.floorPaint==swatch.id)return CommandResult.Fail("This floor is already "+swatch.name+".");
   r.floorPaint=swatch.id;return CommandResult.Ok(r.name+" floor · "+swatch.name,Price(PaintPrice(r)));
  }
  return CommandResult.Fail("Choose walls or floor.");
 }
}
}
