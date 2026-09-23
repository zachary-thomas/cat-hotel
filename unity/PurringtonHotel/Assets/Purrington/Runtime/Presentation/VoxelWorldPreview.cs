using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {public sealed partial class VoxelWorld {
 public event Action<Vector3> GroundDragged;public event Action<string> RoomSelected;bool pathPainting;
 public void SetPathPainting(bool active){pathPainting=active;}
 public void SetCommandPreview(string action,JObject p,bool valid){ClearPreview();preview=Group(renderRoot,"Command preview");preview.localPosition=new Vector3(0,FloorY((int?)p["floor"]??ViewFloor),0);string color=valid?"92c39f":"d89487";float x=(float?)p["x"]??0,z=(float?)p["y"]??0;int rotation=(int?)p["rotation"]??0;
 if(action=="paint_path"||action=="erase_path"||action=="paint_floor"||action=="erase_floor"){foreach(var c in p["cells"]??new JArray())Outline((float)c[0],(float)c[1],1,1,color);return;}
 if(action=="buy_plot"){foreach(var plot in model.Map()["plots"]??new JArray())if((string)plot["id"]==(string)p["id"]){var r=plot["rect"];Outline((float)r[0],(float)r[1],(float)r[2],(float)r[3],color);}return;}
 if(action=="place_template"){var t=model.Content.Templates.FirstOrDefault(a=>(string)a["id"]==(string)p["template"]);if(t!=null){float w=(float)t["w"],d=(float)t["h"];Outline(x,z,rotation%2==0?w:d,rotation%2==0?d:w,color);}return;}
 if(action.Contains("room")){var source=model.State.rooms.FirstOrDefault(r=>r.id==(string)p["id"]);float w=(float?)p["w"]??source?.width??4,d=(float?)p["h"]??source?.depth??3;x=(float?)p["x"]??source?.x??0;z=(float?)p["y"]??source?.z??0;rotation=(int?)p["rotation"]??source?.rotation??0;Outline(x,z,rotation%2==0?w:d,rotation%2==0?d:w,color);var room=new RoomState{x=(int)x,z=(int)z,width=(int)w,depth=(int)d,rotation=rotation,door=(int?)p["door"]??-1};HotelModel.DoorPosition(room,out float dx,out float dz);Box(preview,new Vector3(dx*Unit,.3f,dz*Unit),new Vector3(.4f,.18f,.4f),"f5e2a9");return;}
 var obj=model.State.objects.Concat(model.State.storage).FirstOrDefault(o=>o.id==(string)p["id"]);var item=Catalog.Find((string)p["item"]??obj?.itemId);if(item!=null){rotation=(int?)p["rotation"]??obj?.rotation??0;Outline(x,z,rotation%2==0?item.width:item.depth,rotation%2==0?item.depth:item.width,color);}
 }
 void Outline(float x,float z,float w,float d,string c){x*=Unit;z*=Unit;w*=Unit;d*=Unit;foreach(float side in new[]{-1f,1f}){Box(preview,new Vector3(x+w/2+side*w/2,.22f,z+d/2),new Vector3(.06f,.07f,d+.08f),c);Box(preview,new Vector3(x+w/2,.22f,z+d/2+side*d/2),new Vector3(w+.08f,.07f,.06f),c);}}
}}

