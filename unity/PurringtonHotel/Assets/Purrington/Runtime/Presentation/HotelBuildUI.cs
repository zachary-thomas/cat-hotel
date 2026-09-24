using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using TMPro;
using UnityEngine;

namespace Purrington.Presentation {
 // The Build tab (docs/superpowers/plans/2026-09-23-build-ui-refactor.md): mode tabs (Build · Furnish · Storage), grouped
 // tool tiles, a floor rail that explains how each floor opens, a tool guide with step hints and a live quote while a
 // tool is active, and a selection bar for the room or furnishing that was tapped.
 public sealed partial class HotelUI {
  string buildMode="Build";int stairsOpened=int.MinValue,selectFrame=-1;
  TextMeshProUGUI toolStatus;UnityEngine.UI.Button toolConfirm;bool toolValid;string toolMessage="";
  RectTransform tileParent,tileRow;int tileCount;
  public string BuildMode=>buildMode;
  public void SetBuildMode(string mode){buildMode=mode;category="All";selectedObject="";selectedRoom="";Rebuild();}

  void BuildPanel(){
   if(IsPlacing){ToolChrome();return;}
   if(SelectionBar())return;
   var content=Sheet("Build catalogue","Build",.5f);
   BuildHeader();
   // A side rail needs height; short screens get the floors as a row inside the sheet instead.
   if(wideLayout&&lastSafe.height/Mathf.Max(.01f,canvas.scaleFactor)>=540)FloorRail(safe,true);else FloorRail(content,false);
   ModeTabs(content);
   if(buildMode=="Furnish")FurnishCatalogue(content);else if(buildMode=="Storage")StorageList(content);else StructureTools(content);
  }

  void BuildHeader(){
   var undo=Button(sheet,"Undo",()=>{app.Report(app.Model.Undo());Rebuild();},Lilac,12);Pin(undo,Vector2.one,Vector2.one,Vector2.one,new Vector2(-190,-56),new Vector2(-130,-8));
   var redo=Button(sheet,"Redo",()=>{app.Report(app.Model.Redo());Rebuild();},Lilac,12);Pin(redo,Vector2.one,Vector2.one,Vector2.one,new Vector2(-126,-56),new Vector2(-70,-8));
  }

  // ---- Walls: up, cut away (the default) or down, like The Sims --------------------------------------------------------
  static string WallLabel(string mode)=>"Walls: "+(mode==VoxelWorld.WallsUp?"Up":mode==VoxelWorld.WallsDown?"Down":"Cutaway");
  void CycleWalls(){var mode=app.World.WallMode;app.World.SetWallMode(mode==VoxelWorld.WallsCut?VoxelWorld.WallsDown:mode==VoxelWorld.WallsDown?VoxelWorld.WallsUp:VoxelWorld.WallsCut);Rebuild();}

  // ---- Grab and carry: press a furnishing and drag it; let go on open floor to drop it there --------------------------
  string grabCandidate="";bool grabbedMove;Vector3 grabOffset;
  bool GrabAllowed=>tab=="Build"&&!settings&&careCat<0&&!welcome;
  public bool BuildGrabStart(Vector2 screen){
   grabCandidate="";grabbedMove=false;
   if(!GrabAllowed)return false;
   var ground=app.World.ScreenToGround(screen);
   if(IsPlacing){
    // The ghost follows the finger. Once it is down, only a press on the ghost carries it; elsewhere the camera pans.
    if(commandAction.Length>0||placement=="room")return false;
    var size=GrabSize(placement);
    if(!hasTarget){grabOffset=new Vector3(-size.x/2,0,-size.y/2);return true;}
    var center=new Vector3(target.x+size.x/2,0,target.z+size.y/2);
    if(new Vector2(ground.x-center.x,ground.z-center.z).magnitude>Mathf.Max(1.6f,Mathf.Max(size.x,size.y)*.7f))return false;
    grabOffset=target-new Vector3(ground.x,0,ground.z);return true;
   }
   var pick=app.World.PickAt(screen);
   if(pick.catId>=0||string.IsNullOrEmpty(pick.objectId)||pick.objectId.StartsWith("room:"))return false;
   var item=app.Model.State.objects.FirstOrDefault(o=>o.id==pick.objectId);
   if(item==null)return false;
   grabCandidate=item.id;grabOffset=new Vector3(item.x-ground.x,0,item.z-ground.z);return true;
  }
  Vector2 GrabSize(string itemId){var def=Catalog.Find(itemId);if(def==null)return Vector2.one;bool swap=rotation%2!=0;return new Vector2(swap?def.depth:def.width,swap?def.width:def.depth);}
  public void BuildGrabMoved(Vector3 ground){
   if(!GrabAllowed)return;
   if(grabCandidate.Length>0&&!IsPlacing){BeginMove(grabCandidate);grabbedMove=true;grabCandidate="";}
   if(!IsPlacing||commandAction.Length>0)return;
   var corner=new Vector3(ground.x,0,ground.z)+grabOffset;
   var next=new Vector3(Mathf.Round(corner.x*2)/2,0,Mathf.Round(corner.z*2)/2);
   if(hasTarget&&next==target)return;
   target=next;hasTarget=true;Preview();
  }
  public void BuildGrabEnded(Vector3 ground){
   BuildGrabMoved(ground);
   // A carried furnishing drops where it is let go. New purchases still wait for Place, so nothing is bought by accident.
   if(grabbedMove&&movingObject.Length>0){if(toolValid)Place();else ShowNotice(toolMessage+" · drag it somewhere open, or Cancel.",false);}
   grabCandidate="";grabbedMove=false;
  }

  void ModeTabs(RectTransform content){
   var row=Row(content,48);row.name="Build modes";
   int stored=app.Model.State.storage.Count;
   foreach(var mode in new[]{"Build","Furnish","Storage"}){
    string chosen=mode;string label=mode=="Storage"&&stored>0?"Storage · "+stored:mode;
    var b=Button(row,label,()=>SetBuildMode(chosen),buildMode==mode?Gold:Color.white,14);b.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   }
  }

  // ---- Floors -------------------------------------------------------------------------------------------------------
  static readonly int[] RailLevels={2,1,0,-1};
  bool FloorBuilt(int level)=>FloorBuilt(app.Model,level);
  static bool FloorBuilt(HotelModel model,int level)=>level==0||(HotelModel.Floor(model.Hotel(),level)?.cells.Count??0)>0;
  static int NeedLevel(int level)=>level==1?3:level==2?5:7;
  public enum FloorState{Built,Openable,Locked}
  public struct FloorEntry{public int Level;public string Name,Label;public FloorState State;}
  // What the floor rail shows, top floor first.
  public static FloorEntry[] FloorStates(HotelModel model)=>RailLevels.Select(level=>{
   bool built=FloorBuilt(model,level);string lockCopy=model.FloorLock(level);var state=built?FloorState.Built:lockCopy!=null?FloorState.Locked:FloorState.Openable;
   return new FloorEntry{Level=level,Name=FloorName(level),State=state,Label=state==FloorState.Built?FloorName(level):state==FloorState.Locked?FloorName(level)+"\nLv "+NeedLevel(level):"+ "+FloorName(level)};}).ToArray();
  // Floors are listed top to bottom: a built floor opens when tapped; a floor that can be opened offers the stairs tool
  // on the floor it connects to; a locked floor says which hotel level opens it.
  void FloorRail(Transform parent,bool overlay){
   currentFloor=app.World.ViewFloor;
   if(!FloorBuilt(currentFloor)&&app.Model.FloorLock(currentFloor)!=null){currentFloor=0;app.World.SetViewFloor(0);}
   RectTransform rail;
   if(overlay){
    rail=Panel("Floor rail",parent,CardTone);Pin(rail,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(10,-186-4*62-44),new Vector2(10+132,-186));
    var walls=Button(parent,WallLabel(app.World.WallMode),CycleWalls,Color.white,12);walls.name="Walls toggle";Pin(walls,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(10,-186-4*62-44-54),new Vector2(10+132,-186-4*62-44-8));
    var title=Text(rail,"Floors",12,InkSoft,true);Pin(title.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(10,-34),new Vector2(-6,-6));
    var list=Rect("Levels",rail);Stretch(list,6,38,6,6);var v=list.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();v.spacing=4;v.childControlWidth=v.childControlHeight=true;v.childForceExpandWidth=true;v.childForceExpandHeight=true;
    rail=list;
   }
   else{rail=Row(parent,58);rail.name="Floor rail";}
   foreach(var entry in FloorStates(app.Model)){
    int level=entry.Level,chosen=level;bool built=entry.State==FloorState.Built;string lockCopy=app.Model.FloorLock(level);string label=entry.Label;
    Color color=level==currentFloor?Gold:built?Color.white:lockCopy!=null?new Color(.9f,.88f,.83f):Mint;
    var b=Button(rail,label,()=>{if(built)SwitchFloor(chosen);else if(lockCopy!=null)ShowNotice(lockCopy,false);else OpenFloor(chosen);},color,overlay?13:11);
    b.name=FloorName(level);if(!overlay)b.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
    if(lockCopy!=null&&!built)b.GetComponentInChildren<TextMeshProUGUI>().color=InkSoft;
   }
   if(!overlay){var walls=Button(rail,WallLabel(app.World.WallMode),CycleWalls,Color.white,11);walls.name="Walls toggle";walls.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1.3f;}
  }
  // A floor opens through stairs on its neighbour: upstairs from the ground, the rooftop from upstairs, the basement
  // with stairs down from the ground.
  void OpenFloor(int level){
   int from=level==-1?0:level-1;
   if(!FloorBuilt(from)){ShowNotice("Open "+FloorName(from)+" first.",false);return;}
   if(from!=currentFloor)SwitchFloor(from);
   StartStairs(level);
   ShowNotice("Tap "+FloorName(from).ToLower()+" floor to place stairs to "+FloorName(level).ToLower()+".",false);
  }
  void StartStairs(int level){
   int floor=level==-1?-1:level-1;
   BeginCommand("draw_room",new JObject{{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",floor}},level==-1?"Stairs down":"Stairs to "+FloorName(level).ToLower());
  }

  // ---- Build mode ---------------------------------------------------------------------------------------------------
  void StructureTools(RectTransform content){
   var tools=Rect("Build tools",content);var v=tools.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();v.spacing=8;v.childControlWidth=v.childControlHeight=true;v.childForceExpandWidth=true;v.childForceExpandHeight=false;
   if(stairsOpened!=int.MinValue&&FloorBuilt(stairsOpened)){int level=stairsOpened;Card(tools,"Stairs built","Stairs built · "+FloorName(level)+" is open. Go "+(level>currentFloor?"up":"down")+" to grow it and draw rooms.",level>currentFloor?"Go up":"Go down",()=>{stairsOpened=int.MinValue;SwitchFloor(level);},Mint);}
   string floorName=FloorName(currentFloor);
   string lockCopy=app.Model.FloorLock(currentFloor);
   if(lockCopy!=null){Info(tools,floorName.ToUpper()+" IS LOCKED",lockCopy);return;}
   if(!FloorBuilt(currentFloor)){Info(tools,floorName.ToUpper()+" IS NOT OPEN YET","Build stairs from the floor below to open it.");return;}
   Group(tools,"ROOMS · "+floorName.ToUpper());
   var kinds=RoomKinds(currentFloor);
   foreach(var kind in kinds){
    string chosen=kind,name=KindName(kind);
    Tile(name,KindHint(kind),"room",Gold,()=>BeginCommand("draw_room",new JObject{{"kind",chosen},{"floor",currentFloor},{"name",name}},name));
   }
   Tile("Room from walls","Tap inside walls with a door","walls",Gold,()=>BeginCommand("claim_room",new JObject{{"floor",currentFloor},{"kind",kinds[0]},{"name",KindName(kinds[0])}},"Room from walls"));
   EndGroup();
   Group(tools,"FLOORS & STAIRS");
   if(currentFloor==0||currentFloor==1){int up=currentFloor+1;string upLock=app.Model.FloorLock(up);Tile("Stairs up",upLock==null?"Opens "+FloorName(up).ToLower():"Hotel level "+NeedLevel(up),"stairs",Mint,()=>StartStairs(up),upLock);}
   if(currentFloor==0){string downLock=app.Model.FloorLock(-1);Tile("Stairs down",downLock==null?"Opens the basement":"Hotel level "+NeedLevel(-1),"stairs",Mint,()=>StartStairs(-1),downLock);}
   Tile("Grow floor","Drag across land · "+ShellGrid.CellPrice.ToString("N0")+" a tile","floor",Mint,()=>BeginCommand("paint_floor",new JObject{{"floor",currentFloor},{"cells",new JArray()},{"buy",true}},"Grow floor"));
   Tile("Remove floor","Drag across empty floor","erase",Coral,()=>BeginCommand("erase_floor",new JObject{{"floor",currentFloor},{"cells",new JArray()}},"Remove floor"));
   EndGroup();
   Group(tools,"WALLS & DOORS");
   Tile("Walls","Drag along the grid · "+ShellGrid.WallPrice.ToString("N0")+" an edge","walls",Mint,()=>BeginCommand("draw_wall",new JObject{{"floor",currentFloor}},"Walls"));
   Tile("Doors & windows","Tap a wall to change it","door",Mint,()=>BeginCommand("set_edge",new JObject{{"floor",currentFloor},{"kind","door"},{"edges",new JArray()}},"Doors & windows"));
   Tile("Paint & style","Walls, floors and furnishings","paint",Gold,BeginPaint);
   EndGroup();
   if(currentFloor==0){
    Group(tools,"OUTSIDE");
    foreach(var kind in new[]{"regular","suite","cottage"}){
     string name=kind=="regular"?"Guest room":kind=="suite"?"Grand suite":"Garden cottage";
     var payload=new JObject{{"kind",kind=="cottage"?"regular":kind},{"w",4},{"h",kind=="suite"?5:kind=="cottage"?4:3},{"rotation",0},{"name",name}};
     Tile(name,"Outdoor pavilion · "+app.Model.CatalogPrice("place_room",payload).ToString("N0"),"room",Lilac,()=>BeginCommand("place_room",payload,name));
    }
    Tile("Paths","Drag to paint a path","path",Lilac,()=>BeginCommand("paint_path",new JObject{{"cells",new JArray()},{"style","gravel"}},"Paths"));
    Tile("Erase path","Drag across a path","erase",Coral,()=>BeginCommand("erase_path",new JObject{{"cells",new JArray()},{"style","earth"}},"Erase path"));
    foreach(var plot in app.Model.Map()["plots"]??new JArray()){
     var p=(JObject)plot;string id=(string)p["id"];if(app.Model.Hotel().plots.Contains(id))continue;
     Tile((string)p["name"],"Land · "+((int?)p["cost"]??0).ToString("N0")+" coins","land",Lilac,()=>BeginCommand("buy_plot",new JObject{{"id",id}},(string)p["name"]));
    }
    EndGroup();
   }
   var rooms=app.Model.State.rooms.Where(r=>r.floor==currentFloor).ToList();
   if(rooms.Count>0){
    Group(tools,"YOUR ROOMS");int number=0;
    foreach(var room in rooms){string id=room.id;number++;var status=app.Model.RoomStatus(id);Tile(RoomLabel(room,number),room.kind=="stairs"?status.status:app.Model.Vibe(id).Label+" · "+status.status,room.kind=="stairs"?"stairs":"room",Color.white,()=>{selectedRoom=id;selectedObject="";app.World.FocusRoom(id);Rebuild();});}
    EndGroup();
   }
  }
  public static string[] RoomKinds(int level)=>level==2?new[]{"garden"}:level==1?new[]{"regular","suite","shared","sunroom"}:level==-1?new[]{"regular","suite","shared","spa"}:new[]{"regular","suite","shared"};
  static string KindName(string kind)=>kind=="regular"?"Bedroom":kind=="suite"?"Suite":kind=="shared"?"Lounge":kind=="stairs"?"Stairs":char.ToUpper(kind[0])+kind.Substring(1);
  static string KindHint(string kind)=>kind=="sunroom"?"Sunny naps · +15/min":kind=="garden"?"Open-air · +20/min":kind=="spa"?"Warm soaks · +25/min":kind=="suite"?"Drag a 4 × 5 or larger":"Drag a 4 × 3 or larger";
  string RoomLabel(RoomState room,int number)=>room.kind=="stairs"?"Stairs":(string.IsNullOrEmpty(room.name)?KindName(room.kind):room.name)+" "+number;

  void Group(RectTransform parent,string title){
   var label=Text(parent,title,12,InkSoft,true);Height(label.rectTransform,24);
   tileParent=parent;tileRow=null;tileCount=0;
  }
  void EndGroup(){if(tileRow!=null&&tileCount%2==1){var spacer=Rect("Spacer",tileRow);spacer.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;}tileRow=null;}
  // A two-up tool tile: glyph, title and a one-line hint. A locked tile explains why instead of starting the tool.
  void Tile(string title,string hint,string glyph,Color accent,Action onTap,string locked=null){
   if(tileCount%2==0)tileRow=Row(tileParent,Mathf.Max(76,70*textScale));tileCount++;
   var tile=Button(tileRow,title,locked==null?onTap:()=>ShowNotice(locked,false),locked==null?Color.white:new Color(.93f,.91f,.86f),14);
   tile.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   var label=tile.GetComponentInChildren<TextMeshProUGUI>();label.alignment=TextAlignmentOptions.TopLeft;label.enableAutoSizing=true;label.fontSizeMin=9;label.fontSizeMax=14;label.textWrappingMode=TextWrappingModes.NoWrap;label.overflowMode=TextOverflowModes.Ellipsis;Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(54,-34),new Vector2(-8,-10));
   var sub=Text(tile,hint,11,locked==null?InkSoft:Coral);sub.raycastTarget=false;sub.enableAutoSizing=true;sub.fontSizeMin=8;sub.fontSizeMax=11;Stretch(sub.rectTransform,54,36,8,6);
   var icon=Panel("Glyph",tile,locked==null?accent:new Color(.84f,.82f,.77f));icon.GetComponent<UnityEngine.UI.Image>().raycastTarget=false;Pin(icon,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(8,-19),new Vector2(46,19));
   ToolGlyph(icon,glyph);
  }
  // Tiny block pictograms, drawn with UI rects so no icon font is needed.
  void ToolGlyph(RectTransform icon,string glyph){
   void B(float x,float y,float w,float h,Color c){var r=Rect("Block",icon);r.anchorMin=r.anchorMax=r.pivot=Vector2.zero;r.anchoredPosition=new Vector2(x,y);r.sizeDelta=new Vector2(w,h);var img=r.gameObject.AddComponent<UnityEngine.UI.Image>();img.color=c;img.raycastTarget=false;}
   Color ink=Ink,light=Cream;
   switch(glyph){
    case "room":B(8,8,22,4,ink);B(8,8,4,20,ink);B(26,8,4,20,ink);B(8,24,22,4,ink);B(14,12,10,6,light);break;
    case "walls":B(7,8,24,5,ink);B(7,8,5,22,ink);B(12,20,6,5,light);break;
    case "stairs":B(8,8,24,6,ink);B(14,14,18,6,ink);B(20,20,12,6,ink);B(26,26,6,4,ink);break;
    case "floor":for(int i=0;i<3;i++)for(int j=0;j<3;j++)B(7+i*8,7+j*8,7,7,(i+j)%2==0?ink:light);break;
    case "erase":B(9,17,20,5,ink);B(12,12,14,3,Coral);B(12,24,14,3,Coral);break;
    case "door":B(7,8,5,22,ink);B(26,8,5,22,ink);B(7,26,24,4,ink);B(14,8,10,15,light);break;
    case "path":for(int i=0;i<4;i++)B(6+i*7,8+i*5,8,6,i%2==0?ink:light);break;
    case "paint":B(8,22,22,8,ink);B(10,24,18,4,Gold);B(28,14,3,10,ink);B(17,6,4,10,ink);B(17,14,14,3,ink);break;
    case "land":B(6,8,26,5,ink);B(10,13,4,10,ink);B(8,21,8,6,Mint);B(22,13,3,7,ink);break;
    default:B(10,10,18,18,ink);break;
   }
  }

  // ---- Furnish and Storage ------------------------------------------------------------------------------------------
  void FurnishCatalogue(RectTransform content){
   var filters=new[]{"All"}.Concat(Catalog.All.Select(x=>x.category).Distinct()).Concat(new[]{"Sets"}).ToArray();
   if(!filters.Contains(category))category="All";
   CategoryChips(content,filters);
   if(selectedObject.Length>0||selectedRoom.Length>0){selectedObject="";selectedRoom="";}
   if(category=="Sets"){
    DesignCards(content);
    foreach(var entry in app.Model.Content.Templates){var payload=new JObject{{"template",(string)entry["id"]},{"rotation",0}};CatalogCard(content,(string)entry["name"],"A furnished set · each piece stays editable",app.Model.CatalogPrice("place_template",payload),()=>BeginCommand("place_template",payload,(string)entry["name"]),Gold,"room");}
    return;
   }
   foreach(var item in Catalog.All.Where(x=>category=="All"||category==x.category)){
    var chosen=item;
    CatalogCard(content,item.name,item.role+" · "+(item.indoorOnly?"Indoors":"Any floor")+(item.bond>0?" · "+item.bond+" bond":""),app.Model.State.settings.godMode?0:item.price,()=>BeginPlace(chosen.id),Mint,item.role,chosen.id);
   }
  }
  void StorageList(RectTransform content){
   if(app.Model.State.storage.Count==0){Info(content,"NOTHING STORED","Tap a furnishing in your hotel and choose Store to keep it here for later.");return;}
   foreach(var stored in app.Model.State.storage){string id=stored.id;var item=Catalog.Find(stored.itemId);CatalogCard(content,item.name,"Ready to place",0,()=>BeginRetrieve(id),Mint,item.role,item.id);}
  }

  // ---- Selection ----------------------------------------------------------------------------------------------------
  bool SelectionBar(){
   RoomState room=selectedRoom.Length>0?app.Model.State.rooms.FirstOrDefault(x=>x.id==selectedRoom):null;
   ObjectState item=room==null&&selectedObject.Length>0?app.Model.State.objects.FirstOrDefault(x=>x.id==selectedObject):null;
   if(room==null)selectedRoom="";if(item==null)selectedObject="";
   if(room==null&&item==null)return false;
   bool resizable=room!=null&&room.cells==null&&room.kind!="stairs";
   float height=resizable?196:136;
   var bar=Panel("Selection",safe,Cream);Pin(bar,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(10,96),new Vector2(-10,96+height));
   if(wideLayout)Pin(bar,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-260,96),new Vector2(260,96+height));
   UiMotion.SlideIn(bar,20);
   string title,detail;
   if(room!=null){var status=app.Model.RoomStatus(room.id);title=room.kind=="stairs"?"Stairs":(string.IsNullOrEmpty(room.name)?KindName(room.kind):room.name);
    detail=(room.cells==null?room.width+" × "+room.depth:room.cells.Count+" tiles")+" · "+status.status+(room.kind=="stairs"?" · remove to move them":room.cells!=null?" · reshape it with Walls":"");if(room.kind!="stairs")detail=app.Model.Vibe(room.id).Line+" · "+detail;}
   else{var def=Catalog.Find(item.itemId);title=def.name;detail=def.role+" · move it, or keep it in Storage";}
   var head=Text(bar,title,15,Ink,true);Pin(head.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-34),new Vector2(-14,-8));
   var sub=Text(bar,detail,12,InkSoft);sub.enableAutoSizing=true;sub.fontSizeMin=9;sub.fontSizeMax=12;Pin(sub.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-58),new Vector2(-14,-34));
   var actions=Rect("Selection actions",bar);Stretch(actions,8,64,8,8);var v=actions.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();v.spacing=6;v.childControlWidth=v.childControlHeight=true;v.childForceExpandWidth=true;v.childForceExpandHeight=false;
   var row=Row(actions,56);
   void Act(RectTransform r,string label,Action a,Color c){Button(r,label,a,c,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;}
   if(room!=null){
    string id=room.id;
    if(room.cells==null&&room.kind!="stairs"){Act(row,"Move",()=>BeginMoveRoom(id),Mint);Act(row,"Rotate",()=>BeginMoveRoom(id,true),Gold);Act(row,"Copy",()=>BeginCommand("copy_room",new JObject{{"id",id},{"w",room.width},{"h",room.depth},{"rotation",0}},"Copy room"),Gold);}
    if(room.kind!="stairs")Act(row,"Save",()=>{var saved=app.Model.SaveBlueprint(id);app.Report(saved);ShowNotice(saved.message,!saved.success);},Mint);
    Act(row,"Remove",()=>{var result=app.Model.RemoveRoom(id);app.Report(result);if(result.success)selectedRoom="";Rebuild();ShowNotice(result.message,!result.success);},Coral);
    Act(row,"Done",()=>{selectedRoom="";Rebuild();},Lilac);
    if(resizable){var sizes=Row(actions,52);foreach(var (label,w,d) in new[]{("Narrower",-1,0),("Wider",1,0),("Shorter",0,-1),("Deeper",0,1)}){int nw=Math.Max(2,room.width+w),nd=Math.Max(2,room.depth+d);Act(sizes,label,()=>BeginCommand("resize_room",new JObject{{"id",id},{"w",nw},{"h",nd}},"Resize room"),Lilac);}}
   }
   else{
    string id=item.id;
    Act(row,"Move",()=>BeginMove(id),Mint);
    Act(row,"Store",()=>{var result=app.Model.StoreObject(id);app.Report(result);if(result.success)selectedObject="";Rebuild();},Coral);
    Act(row,"Done",()=>{selectedObject="";Rebuild();},Lilac);
   }
   return true;
  }

  // ---- Tool guide ---------------------------------------------------------------------------------------------------
  bool ToolRotates=>commandAction.Length==0?(placement!="room"||movingRoom.Length>0):commandAction=="place_room"||commandAction=="place_template"||commandAction=="place_blueprint"||commandAction=="copy_room"||commandAction=="draw_room"&&(string)commandPayload?["kind"]=="stairs";
  string ToolTitle(){
   if(commandAction.Length>0)return commandTitle;
   if(movingRoom.Length>0)return "Move room";
   var def=Catalog.All.FirstOrDefault(x=>x.id==placement);string name=def?.name??"Room";
   double price=movingObject.Length>0||retrievingObject.Length>0||app.Model.State.settings.godMode?0:def?.price??0;
   return (movingObject.Length>0?"Move ":"")+name+(price>0?" · "+price.ToString("N0")+" coins":"");
  }
  string ToolHint()=>ToolHintFor(commandAction,commandPayload,movingRoom.Length>0);
  public static string ToolHintFor(string commandAction,JObject commandPayload,bool movingRoom){
   switch(commandAction){
    case "draw_room":return (string)commandPayload["kind"]=="stairs"?"Tap the floor where the stairs go (2 × 3). Rotate to turn them. They open the floor "+((int?)commandPayload["floor"]==-1?"below":"above")+".":"Drag across the grid to draw the room. Bedrooms start at 4 × 3, suites at 4 × 5.";
    case "claim_room":return "Tap inside a space closed by walls with a door. Pick the room type below.";
    case "paint_floor":return "Drag across land to add hotel floor. Land for sale is bought as you go.";
    case "erase_floor":return "Drag across empty hotel floor to remove it. Tiles are refunded.";
    case "draw_wall":return "Drag along the grid lines to build a wall. One bend per drag.";
    case "paint":return "Tap a room to paint it, or a furnishing to restyle it. Each tap saves; Undo takes it back.";
    case "set_edge":return "Tap a wall to cycle wall → door → window → archway. Each tap saves.";
    case "paint_path":return "Drag across the lawn to paint a path. Pick a style below.";
    case "erase_path":return "Drag across a path to remove it.";
    case "buy_plot":return "Confirm to buy this land for your hotel.";
    case "resize_room":return "Check the new size, then confirm.";
    case "":return movingRoom?"Tap where the room should go. Rotate to turn it.":"Tap a spot to place it. Rotate to turn it.";
    default:return "Tap to position it. Rotate to turn it.";
   }
  }
  // One bottom panel: the tool's title, a step hint (when the screen has room), a live status line, option chips
  // and Cancel · Rotate · Confirm. Keeping it in one place leaves at least half the screen for the world.
  void ToolChrome(){
   float scale=Mathf.Max(.01f,canvas.scaleFactor),logicalHeight=lastSafe.height/scale;
   bool roomy=logicalHeight>=620&&textScale<1.4f;
   var options=ToolOptions();
   float head=roomy?84:50,height=head+(options.Count>0?54:0)+(IsPainting?50:0)+58+16;
   var tray=Panel("Placement",safe,Cream);
   if(wideLayout)Pin(tray,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-280,10),new Vector2(280,10+height));
   else Pin(tray,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,10),new Vector2(-10,10+height));
   var title=Text(tray,ToolTitle(),14,Ink,true);title.enableAutoSizing=true;title.fontSizeMin=10;title.fontSizeMax=14;title.textWrappingMode=TextWrappingModes.NoWrap;title.overflowMode=TextOverflowModes.Ellipsis;
   Pin(title.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-28),new Vector2(-14,-8));
   if(roomy){var hint=Text(tray,ToolHint(),12,Ink);hint.enableAutoSizing=true;hint.fontSizeMin=9;hint.fontSizeMax=12;Pin(hint.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-62),new Vector2(-14,-28));}
   toolStatus=Text(tray,"",12,InkSoft,true);toolStatus.enableAutoSizing=true;toolStatus.fontSizeMin=8;toolStatus.fontSizeMax=12;toolStatus.name="Tool status";
   Pin(toolStatus.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-head),new Vector2(-14,-head+22));
   var stack=Rect("Tool actions",tray);Stretch(stack,8,head+4,8,8);var v=stack.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();v.spacing=6;v.childControlWidth=v.childControlHeight=true;v.childForceExpandWidth=true;v.childForceExpandHeight=false;v.childAlignment=TextAnchor.LowerCenter;
   if(options.Count>0){var chips=Row(stack,48);chips.name="Tool options";foreach(var (label,on,act) in options)Button(chips,label,act,on?Gold:Color.white,12).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;}
   if(IsPainting)PaintSwatches(stack);
   var row=Row(stack,58);
   Button(row,"Cancel",()=>CancelPlacement(),Lilac,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   if(ToolRotates)Button(row,"Rotate",Rotate,Gold,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   bool instant=commandAction=="set_edge"||IsPainting;
   string confirm=instant?"Done":commandAction.Length>0?"Confirm":movingRoom.Length>0||movingObject.Length>0?"Move":"Place";
   var place=Button(row,confirm,instant?()=>CancelPlacement():(Action)Place,Mint,14);place.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1.3f;
   toolConfirm=instant?null:place.GetComponent<UnityEngine.UI.Button>();
   // Before anything is chosen the status line carries the step hint, so compact screens still say what to do.
   if(IsPainting)ApplyToolStatus(hasTarget&&!eyedropper?toolMessage:PaintHint(),hasTarget&&toolValid);
   else ApplyToolStatus(hasTarget?toolMessage:roomy?"Nothing chosen yet.":ToolHint(),hasTarget&&toolValid);
  }
  List<(string label,bool on,Action act)> ToolOptions(){
   var list=new List<(string,bool,Action)>();
   if(commandAction=="claim_room"||commandAction=="draw_room"&&(string)commandPayload["kind"]!="stairs"){
    foreach(var kind in RoomKinds(currentFloor)){string chosen=kind;list.Add((KindName(kind),(string)commandPayload["kind"]==kind,()=>{commandPayload["kind"]=chosen;commandPayload["name"]=KindName(chosen);if(commandAction=="draw_room")commandTitle=KindName(chosen);if(hasTarget&&commandAction=="claim_room")PreviewCommand();Rebuild();}));}
   }
   if(IsPainting)PaintOptions(list);
   if(commandAction=="paint_path")foreach(var style in new[]{"earth","gravel","brick"}){string chosen=style;list.Add((char.ToUpper(style[0])+style.Substring(1),(string)commandPayload["style"]==style,()=>{commandPayload["style"]=chosen;if(hasTarget)PreviewCommand();Rebuild();}));}
   return list;
  }
  // Preview results land in the tool guide rather than a toast; Confirm only lights up once there is something valid.
  void ApplyToolStatus(string message,bool ok){
   toolMessage=message;toolValid=ok;
   if(toolStatus){toolStatus.text=message;toolStatus.color=ok?LeafText:(hasTarget?Coral:InkSoft);}
   if(toolConfirm){toolConfirm.interactable=ok;toolConfirm.GetComponent<UnityEngine.UI.Image>().color=ok?Mint:new Color(Mint.r,Mint.g,Mint.b,.45f);}
  }
  void NoteSelection(){selectFrame=Time.frameCount;}
  bool JustSelected=>selectFrame==Time.frameCount;
 }
}
