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
 public void SetViewFloor(int level){ViewFloor=level;foreach(var pair in floorOf)if(pair.Key){pair.Key.gameObject.SetActive(FloorVisible(pair.Value,ViewFloor));if(rooms.ContainsValue(pair.Key))ApplyCutaway(pair.Key,pair.Value);}if(scenery)scenery.gameObject.SetActive(ViewFloor>=0);foreach(var n in neighborhoods) n.Value.Root.gameObject.SetActive(ViewFloor>=0&&n.Key==currentMap);}
 void ApplyCutaway(Transform root,int level){var full=root.Find("FullWalls");var cut=root.Find("CutawayWalls");var roof=root.Find("Roof");bool showFull=level<ViewFloor||exterior;if(full)full.gameObject.SetActive(showFull);if(cut)cut.gameObject.SetActive(!showFull);if(roof)roof.gameObject.SetActive(showFull&&level!=2);}
 public event Action GroundDragEnded;
 Vector2 pinchMid;bool pinchMidValid;
 readonly System.Collections.Generic.Dictionary<string,string> outfitShown=new System.Collections.Generic.Dictionary<string,string>();
 // Maps a domain wall run onto Wall()'s rectangle convention (side 0 at x=w, 1 at z=d, 2 at x=0, 3 at z=0, facing inward).
 public static void ShellWallPlacement(WallRun run,float unit,out Vector3 origin,out float w,out float d,out int side){float length=run.length*unit;origin=new Vector3(run.x*unit,0,run.z*unit);if(run.axis=='v'){w=0;d=length;side=run.inward<0?0:2;}else{w=length;d=0;side=run.inward<0?1:3;}}
 // Cutaway view: camera-facing outside walls drop to a curb; back walls and interior partitions stay tall, like pavilion rooms.
 public static float CutawayHeight(int side,int inward){return inward!=0&&(side==0||side==1)?.25f:2.1f;}
 void BuildShell(){foreach(var floor in model.Hotel().floors){var root=Group(layout,"Shell_"+floor.level);rooms["shell:"+floor.level]=root;OnFloor(root,floor.level);var boards=Group(root,"Floor");foreach(var key in floor.cells.Keys){ShellGrid.TryCell(key,out int x,out int z);if(model.State.rooms.Any(r=>r.kind=="stairs"&&r.floor==floor.level-1&&InRoom(r,x+.5f,z+.5f)))continue;if(model.State.rooms.Any(r=>r.floor==floor.level&&HotelModel.Interior(model.Hotel(),r)&&InRoom(r,x+.5f,z+.5f)))continue;ShellBoards(boards,x,z);}Bake(boards);
  var full=Group(root,"FullWalls");var cut=Group(root,"CutawayWalls");string accent=(string)model.Map()["accent"]??"a86030";foreach(var run in ShellDraw.Runs(floor)){ShellWallPlacement(run,Unit,out var origin,out float w,out float d,out int side);string panel=new[]{"738448","7E8C65","87936E","697F59"}[Math.Abs(run.x*31+run.z*17)%4];foreach(var (group,height) in new[]{(full,floor.level==2?.6f:2.46f),(cut,floor.level==2?.6f:CutawayHeight(side,run.inward))}){var at=Group(group,"Run_"+run.axis+run.x+"_"+run.z);at.localPosition=origin;ShellRun(at,run,w,d,side,height,accent,panel);}}Bake(full);Bake(cut);
  if(floor.level!=2){var roof=Group(root,"Roof");string color=new[]{"a87868","82a9a2","7c8e6d","d9e1d7"}[currentMap];foreach(var key in floor.cells.Keys){if(ShellGrid.Indoor(HotelModel.Floor(model.Hotel(),floor.level+1),key))continue;ShellGrid.TryCell(key,out int x,out int z);Box(roof,new Vector3((x+.5f)*Unit,2.84f,(z+.5f)*Unit),new Vector3(Unit+.02f,.23f,Unit+.02f),Shade(color,-.14f));}Bake(roof);}SetCutawayOn(root,floor.level);}}
 static bool InRoom(RoomState r,float x,float z){HotelModel.RoomSize(r,out float w,out float d);return x>=r.x&&z>=r.z&&x<r.x+w&&z<r.z+d;}
 void ShellBoards(Transform parent,int x,int z){float x0=x*Unit,z0=z*Unit;Box(parent,new Vector3(x0+Unit/2,.07f,z0+Unit/2),new Vector3(Unit,.2f,Unit),"a86030");for(int row=0;row<3;row++){int grain=(x*7+z*3+row)%4;Box(parent,new Vector3(x0+Unit/2,.151f,z0+(row+.5f)*Unit/3),new Vector3(Unit-.014f,.048f,Unit/3-.011f),Shade("D2AD77",(grain-1.5f)*.032f));}}
 void ShellRun(Transform at,WallRun run,float w,float d,int side,float height,string accent,string panel){float length=run.length*Unit;
  if(run.kind=="wall"){Wall(at,w,d,side,height,false,accent,panel,decor:run.inward!=0);return;}
  if(run.kind=="door"){Wall(at,w,d,side,height,true,accent,panel,decor:false,doorWidth:length-.2f);return;}
  if(run.kind=="open"){if(height<1)return;bool ew=run.axis=='v';foreach(float t in new[]{.08f,length-.08f})Box(at,ew?new Vector3(0,GroundY+1.15f,t):new Vector3(t,GroundY+1.15f,0),new Vector3(.22f,2.3f,.22f),accent);Box(at,ew?new Vector3(0,GroundY+2.3f,length/2):new Vector3(length/2,GroundY+2.3f,0),ew?new Vector3(.24f,.18f,length):new Vector3(length,.18f,.24f),accent);return;}
  // window: plain wall plus one sill-and-pane window per cell, sized to fit a single cell (auto-decor windows need 1.4+ units).
  Wall(at,w,d,side,height,false,accent,panel,decor:false);if(height<1)return;bool v=run.axis=='v';for(int i=0;i<run.length;i++){float c=(i+.5f)*Unit;var p=v?new Vector3(0,1.52f,c):new Vector3(c,1.52f,0);Box(at,p,v?new Vector3(.2f,.97f,.9f):new Vector3(.9f,.97f,.2f),accent);Box(at,p,v?new Vector3(.215f,.8f,.74f):new Vector3(.74f,.8f,.215f),"90bfc0");Box(at,p-Vector3.up*.53f,v?new Vector3(.43f,.12f,1f):new Vector3(1f,.12f,.43f),"f0d8c0");}}
 void SetCutawayOn(Transform root,int level){ApplyCutaway(root,level);}
 Vector2 DrawPoint(Vector2 p){return Touchscreen.current!=null&&Touchscreen.current.primaryTouch.press.isPressed?p+Vector2.up*(Screen.dpi>0?Screen.dpi*.35f:90f):p;}
}}
