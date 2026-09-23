using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.Rendering;
namespace Purrington.Presentation {public sealed partial class VoxelWorld {
 public event Action<Vector3> GroundDragged;public event Action<string> RoomSelected;bool pathPainting;Transform hiddenPreviewSource;
 public void SetPathPainting(bool active){pathPainting=active;}
 void ShowFurniturePreview(ItemDefinition item,Vector3 position,int rotation,bool valid,string sourceId=null){
  ClearPreview();preview=Group(renderRoot,"Furniture placement preview");preview.localPosition=new Vector3(0,FloorY(ViewFloor),0);
  if(!string.IsNullOrEmpty(sourceId)&&objects.TryGetValue(sourceId,out hiddenPreviewSource))hiddenPreviewSource.gameObject.SetActive(false);
  float w=rotation%2==0?item.width:item.depth,d=rotation%2==0?item.depth:item.width;
  float cx=position.x+w/2,cz=position.z+d/2;
  string cell=Mathf.FloorToInt(cx)+","+Mathf.FloorToInt(cz);
  bool inRoom=model.State.rooms.Any(r=>InRoom(r,cx,cz));
  bool raised=inRoom||model.Hotel().paths.ContainsKey(cell)||ShellGrid.Indoor(HotelModel.Floor(model.Hotel(),ViewFloor),cell);
  float surface=raised?GroundY:GrassY;
  var footprint=Group(preview,"Placement validity voxel");footprint.localPosition=new Vector3(position.x*Unit,surface+.025f,position.z*Unit);
  string color=valid?"42D487":"ED5145";
  Box(footprint,new Vector3(w*Unit/2,.015f,d*Unit/2),new Vector3(w*Unit+.12f,.03f,d*Unit+.12f),color);
  foreach(float x in new[]{0,w*Unit})Box(footprint,new Vector3(x,.048f,d*Unit/2),new Vector3(.055f,.035f,d*Unit+.11f),color);
  foreach(float z in new[]{0,d*Unit})Box(footprint,new Vector3(w*Unit/2,.048f,z),new Vector3(w*Unit+.11f,.035f,.055f),color);
  var ghost=geometry.Build(preview,geometry.Recipe("items",item.id));ghost.name="Furniture ghost";
  ghost.localPosition=new Vector3(cx*Unit,surface,cz*Unit);ghost.localRotation=Quaternion.Euler(0,-rotation*90,0);
  foreach(var renderer in ghost.GetComponentsInChildren<MeshRenderer>(true)){
   renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
   if(!valid)renderer.sharedMaterial=geometry.Material("ED5145");
  }
  if(!valid)foreach(var label in ghost.GetComponentsInChildren<TextMesh>(true))label.color=Hex("ED5145");
 }
 public void SetCommandPreview(string action,JObject p,bool valid){ClearPreview();preview=Group(renderRoot,"Command preview");preview.localPosition=new Vector3(0,FloorY((int?)p["floor"]??ViewFloor),0);string color=valid?"92c39f":"d89487";float x=(float?)p["x"]??0,z=(float?)p["y"]??0;int rotation=(int?)p["rotation"]??0;
 if(action=="paint_path"||action=="erase_path"||action=="paint_floor"||action=="erase_floor"){foreach(var c in p["cells"]??new JArray())Outline((float)c[0],(float)c[1],1,1,color);return;}
 if(action=="buy_plot"){foreach(var plot in model.Map()["plots"]??new JArray())if((string)plot["id"]==(string)p["id"]){var r=plot["rect"];Outline((float)r[0],(float)r[1],(float)r[2],(float)r[3],color);}return;}
 if(action=="place_template"){var t=model.Content.Templates.FirstOrDefault(a=>(string)a["id"]==(string)p["template"]);if(t!=null){float w=(float)t["w"],d=(float)t["h"];Outline(x,z,rotation%2==0?w:d,rotation%2==0?d:w,color);}return;}
 if(action=="draw_wall"&&p["from"] is JArray from&&p["to"] is JArray to){foreach(var edge in HotelModel.WallPath((int)from[0],(int)from[1],(int)to[0],(int)to[1])){ShellGrid.TryEdge(edge,out char axis,out int ex,out int ez);Outline(ex,ez,axis=='v'?.01f:1,axis=='v'?1:.01f,color);}return;}
 if(action=="claim_room"){Outline((float)p["x"],(float)p["y"],1,1,color);return;}
 if(action.Contains("room")){var source=model.State.rooms.FirstOrDefault(r=>r.id==(string)p["id"]);float w=(float?)p["w"]??source?.width??4,d=(float?)p["h"]??source?.depth??3;x=(float?)p["x"]??source?.x??0;z=(float?)p["y"]??source?.z??0;rotation=(int?)p["rotation"]??source?.rotation??0;Outline(x,z,rotation%2==0?w:d,rotation%2==0?d:w,color);var room=new RoomState{x=(int)x,z=(int)z,width=(int)w,depth=(int)d,rotation=rotation,door=(int?)p["door"]??-1};HotelModel.DoorPosition(room,out float dx,out float dz);Box(preview,new Vector3(dx*Unit,.3f,dz*Unit),new Vector3(.4f,.18f,.4f),"f5e2a9");return;}
 var obj=model.State.objects.Concat(model.State.storage).FirstOrDefault(o=>o.id==(string)p["id"]);var item=Catalog.Find((string)p["item"]??obj?.itemId);if(item!=null){rotation=(int?)p["rotation"]??obj?.rotation??0;ShowFurniturePreview(item,new Vector3(x,0,z),rotation,valid,action=="move_object"?obj?.id:null);}
 }
 void Outline(float x,float z,float w,float d,string c){x*=Unit;z*=Unit;w*=Unit;d*=Unit;foreach(float side in new[]{-1f,1f}){Box(preview,new Vector3(x+w/2+side*w/2,.22f,z+d/2),new Vector3(.06f,.07f,d+.08f),c);Box(preview,new Vector3(x+w/2,.22f,z+d/2+side*d/2),new Vector3(w+.08f,.07f,.06f),c);}}
}}

