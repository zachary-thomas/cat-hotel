using System;
using System.Linq;
using Purrington.Domain;
using Newtonsoft.Json.Linq;

// Meadow Life build track: B2 paint and tints, B3 room vibe and saved designs.
static class BuildSuites
{
 public static void Run(Action<bool,string> check,Func<string,JObject> P,ParityContent content)
 {
  RunPaint(check,P,content);
  RunVibe(check,content);
  RunBlueprints(check,content);
  Console.WriteLine("Build suite passed");
 }

 static ObjectState Item(string id,float x,float z)=>new ObjectState{id=id+x+z,itemId=id,x=x,z=z};
 static void RunVibe(Action<bool,string> check,ParityContent content)
 {
  var room=new RoomState{id="r",kind="regular",x=0,z=0,width=6,depth=5};
  var empty=HotelModel.Vibe(room,new ObjectState[0]);
  check(empty.TopScore==0&&empty.tip=="add some furniture"&&empty.Label=="No vibe yet","an empty room has no vibe and asks for furniture");
  var cozy=HotelModel.Vibe(room,new[]{Item("lamp",0,0),Item("blanket",2,0),Item("fireplace",4,2)});
  check(cozy.Top=="Cozy"&&cozy.cozy>cozy.calm&&cozy.cozy>cozy.lively,"lamps, blankets and a fireplace read Cozy");
  var lively=HotelModel.Vibe(room,new[]{Item("cafe_table",0,0),Item("tunnel",3,0),Item("scratch",0,3)});
  check(lively.Top=="Lively","tables and toys read Lively");
  var calm=HotelModel.Vibe(room,new[]{Item("plant",0,0),Item("rug",2,2),Item("perch",4,0)});
  check(calm.Top=="Calm","plants, rugs and perches read Calm");
  var noLight=HotelModel.Vibe(room,new[]{Item("cave",0,0),Item("canopy_bed",2,0)});
  check(noLight.Top=="Cozy"&&noLight.tip=="add a warm light","a cozy room without a lamp asks for warm light");
  var painted=new RoomState{id="p",kind="regular",width=6,depth=5,wallPaint="rose",floorPaint="walnut"};
  check(HotelModel.Vibe(painted,new[]{Item("lamp",0,0)}).cozy>HotelModel.Vibe(room,new[]{Item("lamp",0,0)}).cozy,"warm paint adds coziness");
  var small=new RoomState{id="s",kind="shared",width=2,depth=2};
  var packed=HotelModel.Vibe(small,new[]{Item("plant",0,0),Item("rug",1,0),Item("plant",0,1),Item("lamp",1,1)});
  check(packed.calm<HotelModel.Vibe(room,new[]{Item("plant",0,0),Item("rug",1,0),Item("plant",0,1),Item("lamp",1,1)}).calm,"crowding costs calm");
  check(HotelModel.Vibe(new RoomState{kind="stairs",width=2,depth=3},new[]{Item("lamp",0,0)}).TopScore==0,"stairs have no vibe");
  check(HotelModel.VibeFor("warm")=="Cozy"&&HotelModel.VibeFor("quiet")=="Calm"&&HotelModel.VibeFor("play")=="Lively","preferences map to vibes");
  var m=Fresh(content);var any=m.Hotel().rooms.First(r=>r.kind!="stairs");var before=m.Vibe(any.id);
  m.Execute("paint_room",Paint(any.id,"wall","rose"));
  check(!ReferenceEquals(before,m.Vibe(any.id)),"vibe refreshes after an edit");
 }

 static void RunBlueprints(Action<bool,string> check,ParityContent content)
 {
  var m=Fresh(content);m.State.coins=100000;
  var room=m.Hotel().rooms.First(r=>r.kind!="stairs"&&m.RoomObjects(r).Any());
  m.Execute("paint_room",Paint(room.id,"wall","lilac"));m.Execute("paint_room",Paint(room.id,"floor","ash"));
  var first=m.RoomObjects(room).First();m.Execute("tint_object",new JObject{{"id",first.id},{"tint",3}});
  int pieces=m.RoomObjects(room).Count();
  var saved=m.SaveBlueprint(room.id);
  check(saved.success&&m.State.blueprints.Count==1,"a room saves as a design");
  var design=m.State.blueprints[0];
  check(design.kind==room.kind&&design.w==room.width&&design.h==room.depth&&design.wallPaint=="lilac"&&design.floorPaint=="ash","the design keeps kind, size and paint");
  check(design.items.Count>0&&design.items.Count<=pieces&&design.items.Any(i=>i.tint==3),"the design keeps furnishings and tints");
  check(design.items.All(i=>i.x>=0&&i.z>=0&&i.x<=design.w&&i.z<=design.h),"pieces sit in the design's own frame");
  check(!m.SaveBlueprint("nope").success,"a missing room can't be saved");
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(round.blueprints.Count==1&&round.blueprints[0].items.Count==design.items.Count,"designs survive a save");

  // Buy the Meadow's land, then find open ground: try spots across the lot until the quote succeeds.
  foreach(var plot in m.Map()["plots"])m.Execute("buy_plot",new JObject{{"id",(string)plot["id"]}});
  JObject spot=null;
  for(int x=-40;x<=40&&spot==null;x+=2)for(int z=-40;z<=40&&spot==null;z+=2){var p=new JObject{{"blueprint",design.id},{"x",x},{"y",z},{"rotation",0},{"floor",0}};if(m.Quote("place_blueprint",p).success)spot=p;}
  check(spot!=null,"a design fits somewhere on the lot");
  if(spot!=null){
   int rooms=m.Hotel().rooms.Count,objects=m.Hotel().objects.Count;double coins=m.State.coins;
   var quote=m.Quote("place_blueprint",spot);var placed=m.Execute("place_blueprint",spot);
   check(placed.success&&m.Hotel().rooms.Count==rooms+1&&m.Hotel().objects.Count==objects+design.items.Count,"placing a design builds the room and its pieces");
   var copy=m.Hotel().rooms.Last();
   check(copy.wallPaint=="lilac"&&copy.floorPaint=="ash"&&m.Hotel().objects.Any(o=>o.room==copy.id&&o.tint==3),"the copy carries paint and tints");
   check(Math.Abs(coins-quote.cost-m.State.coins)<.01&&quote.cost>0,"placing charges the quoted price");
   check(m.Undo().success&&m.Hotel().rooms.Count==rooms&&m.State.blueprints.Count==1,"undo removes the copy but keeps the design");
   var turned=(JObject)spot.DeepClone();turned["rotation"]=1;
   bool anyTurned=false;for(int x=-40;x<=40&&!anyTurned;x+=2)for(int z=-40;z<=40&&!anyTurned;z+=2){turned["x"]=x;turned["y"]=z;if(m.Quote("place_blueprint",turned).success){anyTurned=m.Execute("place_blueprint",turned).success;}}
   check(anyTurned&&HotelModel.Valid(m.State),"a rotated copy is valid");
  }
  check(!m.Quote("place_blueprint",new JObject{{"blueprint","nope"},{"x",0},{"y",0}}).success,"an unknown design can't be placed");
  var bad=HotelModel.Copy(m.State);bad.blueprints[0].items[0].itemId="rocket";check(!HotelModel.Valid(bad),"a design with unknown furniture is invalid");
  bad=HotelModel.Copy(m.State);bad.blueprints[0].wallPaint="neon";check(!HotelModel.Valid(bad),"a design with unknown paint is invalid");
  bad=HotelModel.Copy(m.State);bad.blueprints.Add(HotelModel.Copy(m.State).blueprints[0]);check(!HotelModel.Valid(bad),"duplicate design ids are invalid");
  check(m.RenameBlueprint(design.id,"Lilac nook").success&&m.Blueprint(design.id).name=="Lilac nook"&&!m.RenameBlueprint(design.id,"").success,"designs can be renamed");
  check(m.DeleteBlueprint(design.id).success&&m.State.blueprints.Count==0&&!m.DeleteBlueprint(design.id).success,"designs can be forgotten");
  for(int i=0;i<HotelModel.BlueprintLimit;i++)m.SaveBlueprint(room.id);
  check(m.State.blueprints.Count==HotelModel.BlueprintLimit&&!m.SaveBlueprint(room.id).success,"designs cap at the limit");
 }

 static HotelModel Fresh(ParityContent content){var m=new HotelModel(new MemoryStore(),content);m.LoadOrCreate();m.State.coins=5000;return m;}
 static JObject Paint(string id,string surface,string paint)=>new JObject{{"id",id},{"surface",surface},{"paint",paint}};

 static void RunPaint(Action<bool,string> check,Func<string,JObject> P,ParityContent content)
 {
  check(Purrington.Domain.Paint.Walls.Select(s=>s.id).Distinct().Count()==Purrington.Domain.Paint.Walls.Length&&Purrington.Domain.Paint.Floors.Select(s=>s.id).Distinct().Count()==Purrington.Domain.Paint.Floors.Length,"paint ids are unique");
  check(Purrington.Domain.Paint.Walls.Skip(1).All(s=>s.main.Length==6&&s.trim.Length==6)&&Purrington.Domain.Paint.Floors.Skip(1).All(s=>s.main.Length==6),"swatches carry hex colors");
  var m=Fresh(content);
  var room=m.Hotel().rooms.First(r=>Purrington.Domain.Paint.HasWalls(r));
  double coins=m.State.coins,price=HotelModel.PaintPrice(room);
  var quote=m.Quote("paint_room",Paint(room.id,"wall","rose"));
  check(quote.success&&quote.cost==price&&room.wallPaint=="","paint quote prices the room and changes nothing");
  var painted=m.Execute("paint_room",Paint(room.id,"wall","rose"));
  check(painted.success&&m.Hotel().rooms.First(r=>r.id==room.id).wallPaint=="rose"&&Math.Abs(m.State.coins-(coins-price))<.01,"painting walls saves the color and charges");
  check(!m.Execute("paint_room",Paint(room.id,"wall","rose")).success,"repainting the same color is refused");
  check(m.Execute("paint_room",Paint(room.id,"floor","walnut")).success&&m.Hotel().rooms.First(r=>r.id==room.id).floorPaint=="walnut","painting the floor");
  check(!m.Execute("paint_room",Paint(room.id,"wall","neon")).success,"unknown colors are refused");
  check(!m.Execute("paint_room",Paint(room.id,"ceiling","rose")).success,"unknown surfaces are refused");
  check(!m.Execute("paint_room",Paint("nope","wall","rose")).success,"a missing room is refused");
  check(m.Undo().success&&m.Hotel().rooms.First(r=>r.id==room.id).floorPaint==""&&m.Hotel().rooms.First(r=>r.id==room.id).wallPaint=="rose","undo removes the floor paint only");
  check(m.Execute("paint_room",Paint(room.id,"wall","")).success&&m.Hotel().rooms.First(r=>r.id==room.id).wallPaint=="","house style paints back the default");
  var garden=new RoomState{kind="garden"};var stairs=new RoomState{kind="stairs"};var terrace=new RoomState{kind="terrace"};
  check(!Purrington.Domain.Paint.HasWalls(garden)&&!Purrington.Domain.Paint.HasWalls(stairs)&&!Purrington.Domain.Paint.HasWalls(terrace)&&Purrington.Domain.Paint.HasBoards(terrace)&&!Purrington.Domain.Paint.HasBoards(garden),"only walled rooms take wall paint");

  // Tints restyle a furnishing.
  var item=m.Hotel().objects.First();double tintPrice=HotelModel.TintPrice(Catalog.Find(item.itemId));coins=m.State.coins;
  check(m.Execute("tint_object",new JObject{{"id",item.id},{"tint",2}}).success&&m.Hotel().objects.First(o=>o.id==item.id).tint==2&&Math.Abs(m.State.coins-(coins-tintPrice))<.01,"tinting a furnishing saves and charges");
  check(!m.Execute("tint_object",new JObject{{"id",item.id},{"tint",2}}).success,"same tint is refused");
  check(!m.Execute("tint_object",new JObject{{"id",item.id},{"tint",9}}).success&&!m.Execute("tint_object",new JObject{{"id",item.id},{"tint",1.5}}).success,"invalid tints are refused");

  // Paint travels with copies and saves strictly.
  m.Execute("paint_room",Paint(room.id,"wall","mint"));
  var codec=new NewtonsoftSaveCodec();var round=codec.Deserialize(codec.Serialize(m.State));
  check(round.hotels[round.currentHotel].rooms.First(r=>r.id==room.id).wallPaint=="mint"&&round.hotels[round.currentHotel].objects.First(o=>o.id==item.id).tint==2,"paint and tints survive a save");
  var bad=HotelModel.Copy(m.State);bad.hotels[bad.currentHotel].rooms.First(r=>r.id==room.id).wallPaint="neon";check(!HotelModel.Valid(bad),"an unknown wall color is invalid");
  bad=HotelModel.Copy(m.State);bad.hotels[bad.currentHotel].objects.First(o=>o.id==item.id).tint=-1;check(!HotelModel.Valid(bad),"a negative tint is invalid");
  var json=JObject.Parse(codec.Serialize(m.State));json["hotels"][m.State.currentHotel]["rooms"][0]["wallPaint"]=5;bool rejected=false;try{codec.Deserialize(json.ToString());}catch{rejected=true;}check(rejected,"strict saves reject a non-string wall paint");
  var god=Fresh(content);god.SetGodMode(true);double godCoins=god.State.coins;var godRoom=god.Hotel().rooms.First(r=>Purrington.Domain.Paint.HasWalls(r));
  check(god.Execute("paint_room",Paint(godRoom.id,"wall","sky")).success&&god.State.coins==godCoins,"god mode paints for free");
 }
}
