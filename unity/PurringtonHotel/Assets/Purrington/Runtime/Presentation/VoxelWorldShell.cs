using System;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Purrington.Presentation {public sealed partial class VoxelWorld {
 public const float FloorHeight=2.9f;
 public static float FloorY(int level){return level*FloorHeight;}
 public static bool FloorVisible(int level,int viewFloor){return level<=viewFloor;}
 public int ViewFloor{get;private set;}
 readonly System.Collections.Generic.Dictionary<Transform,int> floorOf=new System.Collections.Generic.Dictionary<Transform,int>();
 readonly System.Collections.Generic.Dictionary<string,float> actorY=new System.Collections.Generic.Dictionary<string,float>();
 int watchCatId=-1;
 public bool WatchCat(int catId){if(model==null||!model.Actors.Any(a=>a.kind==ActorKind.Guest&&a.catId==catId))return false;if(care)SetCareMode(0,false);watchCatId=catId;manualCamera=true;zoom=Mathf.Min(zoom,5.5f);return true;}
 public void StopWatching(){watchCatId=-1;FitHotel();}
 public int WatchedCatId=>watchCatId;
 void OnFloor(Transform root,int level){floorOf[root]=level;var p=root.localPosition;p.y+=FloorY(level);root.localPosition=p;}
 public void SetViewFloor(int level){ViewFloor=level;foreach(var pair in floorOf)if(pair.Key){pair.Key.gameObject.SetActive(FloorVisible(pair.Value,ViewFloor));if(rooms.ContainsValue(pair.Key))ApplyCutaway(pair.Key,pair.Value);}if(scenery)scenery.gameObject.SetActive(ViewFloor>=0);foreach(var n in neighborhoods)n.Value.Root.gameObject.SetActive(ViewFloor>=0&&n.Key==currentMap);RefreshBackground();}
 // The day cycle owns the sky color; only the basement view keeps its own dark backdrop.
 void RefreshBackground(){if(Lighting!=null)Lighting.BackgroundOverride=ViewFloor==-1?Hex("3B3128"):(Color?)null;}
 // Walls up / cutaway / down, like The Sims. Exterior view (roofs on) and floors below the viewed one always show full walls.
 public const string WallsUp="up",WallsCut="cut",WallsDown="down";
 public string WallMode{get;private set;}=WallsCut;
 public void SetWallMode(string mode){if(mode!=WallsUp&&mode!=WallsDown)mode=WallsCut;WallMode=mode;foreach(var r in rooms.Values)if(floorOf.TryGetValue(r,out int level))ApplyCutaway(r,level);}
 void ApplyCutaway(Transform root,int level){var full=root.Find("FullWalls");var cut=root.Find("CutawayWalls");var roof=root.Find("Roof");bool below=level<ViewFloor||exterior;bool showFull=below||WallMode==WallsUp;bool showCut=!showFull&&WallMode==WallsCut;if(full)full.gameObject.SetActive(showFull);if(cut)cut.gameObject.SetActive(showCut);if(roof)roof.gameObject.SetActive(below&&level!=2);}
 public event Action GroundDragEnded;
 Vector2 pinchMid;bool pinchMidValid;
 // Maps a domain wall run onto Wall()'s rectangle convention (side 0 at x=w, 1 at z=d, 2 at x=0, 3 at z=0, facing inward).
 public static void ShellWallPlacement(WallRun run,float unit,out Vector3 origin,out float w,out float d,out int side){float length=run.length*unit;origin=new Vector3(run.x*unit,0,run.z*unit);if(run.axis=='v'){w=0;d=length;side=run.inward<0?0:2;}else{w=length;d=0;side=run.inward<0?1:3;}}
 // Cutaway view: camera-facing outside walls drop to a curb; back walls and interior partitions stay tall, like pavilion rooms.
 public static float CutawayHeight(int side,int inward){return inward!=0&&(side==0||side==1)?.25f:2.1f;}
 void BuildShell(){foreach(var floor in model.Hotel().floors){var root=Group(layout,"Shell_"+floor.level);rooms["shell:"+floor.level]=root;OnFloor(root,floor.level);var boards=Group(root,"Floor");foreach(var key in floor.cells.Keys){ShellGrid.TryCell(key,out int x,out int z);if(model.State.rooms.Any(r=>r.kind=="stairs"&&r.floor==floor.level-1&&InRoom(r,x+.5f,z+.5f)))continue;if(model.State.rooms.Any(r=>r.floor==floor.level&&HotelModel.Interior(model.Hotel(),r)&&InRoom(r,x+.5f,z+.5f)))continue;ShellBoards(boards,x,z);}Bake(boards);
  var full=Group(root,"FullWalls");var cut=Group(root,"CutawayWalls");var beds=Group(root,"Wall beds");string accent=(string)model.Map()["accent"]??"a86030";foreach(var run in ShellDraw.Runs(floor)){ShellWallPlacement(run,Unit,out var origin,out float w,out float d,out int side);var paint=Paint.Wall(RunRoom(floor.level,run)?.wallPaint);string panel=paint?.trim??(floor.level==-1?"8A6F55":PanelTones[Mathf.Clamp(currentMap,0,3)][Math.Abs(run.x*31+run.z*17)%4]);foreach(var (group,height) in new[]{(full,floor.level==2?.6f:2.46f),(cut,floor.level==2?.6f:CutawayHeight(side,run.inward))}){var at=Group(group,"Run_"+run.axis+run.x+"_"+run.z);at.localPosition=origin;ShellRun(at,run,w,d,side,height,accent,panel,paint?.main);DressRun(at,beds,run,side,height,floor.level,group==full);}}Bake(full);Bake(cut);Bake(beds);
  if(floor.level!=2)BuildRoof(root,floor);SetCutawayOn(root,floor.level);}}
 // Each destination dresses the hotel in its own materials: Meadow's sage wainscot, Seaside's white plaster and sky-blue
 // boards, Forest Lodge's timber and Snowcap's stone.
 static readonly string[][] PanelTones={new[]{"738448","7E8C65","87936E","697F59"},new[]{"7FBFD0","8CC8D6","74B3C6","98CFDA"},new[]{"8A5E3C","96694A","7E5638","A07452"},new[]{"97A4AE","A5B1B9","8B99A4","B0BBC2"}};
 static readonly string[] WallTones={"fff8e9","FBFBF6","F0DDBF","F4F1EA"};
 string WallTone=>WallTones[Mathf.Clamp(currentMap,0,3)];
 static bool InRoom(RoomState r,float x,float z){return HotelModel.RoomHas(r,x,z);}
 // The room a shell wall run faces, so painted rooms color their own side. Partitions take the room on either side.
 RoomState RunRoom(int level,WallRun run){int mid=run.length/2;bool v=run.axis=='v';foreach(int sign in run.inward!=0?new[]{run.inward}:new[]{1,-1}){int x=v?(sign>0?run.x:run.x-1):run.x+mid,z=v?run.z+mid:(sign>0?run.z:run.z-1);var room=model.State.rooms.FirstOrDefault(r=>r.floor==level&&InRoom(r,x+.5f,z+.5f));if(room!=null)return room;}return null;}
 void ShellBoards(Transform parent,int x,int z,string color="D2AD77"){float x0=x*Unit,z0=z*Unit;Box(parent,new Vector3(x0+Unit/2,.07f,z0+Unit/2),new Vector3(Unit,.2f,Unit),"a86030");for(int row=0;row<3;row++){int grain=(x*7+z*3+row)%4;Box(parent,new Vector3(x0+Unit/2,.151f,z0+(row+.5f)*Unit/3),new Vector3(Unit-.014f,.048f,Unit/3-.011f),Shade(color,(grain-1.5f)*.032f));}}
 void ShellRun(Transform at,WallRun run,float w,float d,int side,float height,string accent,string panel,string tone=null){float length=run.length*Unit;
  if(run.kind=="wall"){Wall(at,w,d,side,height,false,accent,panel,decor:run.inward!=0,tone:tone);return;}
  if(run.kind=="door"){Wall(at,w,d,side,height,true,accent,panel,decor:false,doorWidth:length-.2f,tone:tone);return;}
  if(run.kind=="open"){if(height<1)return;bool ew=run.axis=='v';foreach(float t in new[]{.08f,length-.08f})Box(at,ew?new Vector3(0,GroundY+1.15f,t):new Vector3(t,GroundY+1.15f,0),new Vector3(.22f,2.3f,.22f),accent);Box(at,ew?new Vector3(0,GroundY+2.3f,length/2):new Vector3(length/2,GroundY+2.3f,0),ew?new Vector3(.24f,.18f,length):new Vector3(length,.18f,.24f),accent);return;}
  // window: plain wall plus one sill-and-pane window per cell, sized to fit a single cell (auto-decor windows need 1.4+ units).
  Wall(at,w,d,side,height,false,accent,panel,decor:false,tone:tone);if(height<1)return;bool v=run.axis=='v';for(int i=0;i<run.length;i++){float c=(i+.5f)*Unit;var p=v?new Vector3(0,1.52f,c):new Vector3(c,1.52f,0);Box(at,p,v?new Vector3(.2f,.97f,.9f):new Vector3(.9f,.97f,.2f),accent);Box(at,p,v?new Vector3(.215f,.8f,.74f):new Vector3(.74f,.8f,.215f),"90bfc0");Box(at,p-Vector3.up*.53f,v?new Vector3(.43f,.12f,1f):new Vector3(1f,.12f,.43f),"f0d8c0");}}
 void SetCutawayOn(Transform root,int level){ApplyCutaway(root,level);}
 Vector2 DrawPoint(Vector2 p){return Touchscreen.current!=null&&Touchscreen.current.primaryTouch.press.isPressed?p+Vector2.up*(Screen.dpi>0?Screen.dpi*.35f:90f):p;}
}}
