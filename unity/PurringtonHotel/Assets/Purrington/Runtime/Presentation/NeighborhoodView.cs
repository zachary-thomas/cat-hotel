using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Purrington.Presentation {
public sealed class NeighborhoodView {
 public readonly Transform Root;readonly List<Walker> walkers=new List<Walker>();
 sealed class Walker{public GodotCatRig rig;public Vector2 start,finish;public float length,distance,speed,turn,turnFrom;public int direction;}
 public NeighborhoodView(GodotGeometry g,Transform parent,int map){Root=new GameObject("Independent neighborhood "+map).transform;Root.SetParent(parent,false);g.Build(Root,(JObject)g.Map(map)["neighborhood"]);int i=0;foreach(var route in g.Map(map)["routes"]??new JArray()){var w=new Walker{rig=new GodotCatRig(g,Root,"neighbors",i.ToString(),i+30),start=new Vector2((float)route["start"][0],(float)route["start"][1]),finish=new Vector2((float)route["finish"][0],(float)route["finish"][1]),length=(float)route["length"],speed=.52f+i%3*.025f,direction=i<3?1:-1};float ratio=new[]{.47f,.28f,.36f,.58f,.76f,.65f}[i];if(map==0&&i==1)ratio=.8f;if(map==0&&i==4)ratio=.24f;w.distance=w.length*ratio;w.rig.Root.localScale=Vector3.one*.88f;Place(w);walkers.Add(w);i++;}if(walkers.Count!=6)throw new InvalidOperationException("Each destination requires six independent sidewalk cats");}
 static void Place(Walker w){var p=Vector2.Lerp(w.start,w.finish,w.distance/w.length);w.rig.Root.localPosition=new Vector3(p.x*VoxelWorld.Unit,.175f,p.y*VoxelWorld.Unit);w.rig.Root.localRotation=Quaternion.Euler(0,w.direction>0?90:-90,0);}
 public void Advance(float delta,bool motion){if(!motion)return;foreach(var w in walkers){float remaining=delta;while(remaining>.00001f){float step;if(w.turn>.00001f){step=Mathf.Min(remaining,w.turn);w.turn=Mathf.Max(0,w.turn-step);float t=1-w.turn/1.6f;w.rig.Root.localRotation=Quaternion.Euler(0,(w.turnFrom+Mathf.PI*Mathf.SmoothStep(0,1,t))*Mathf.Rad2Deg,0);w.rig.Advance(step,true,"sniff",false);}else{float toEnd=w.direction>0?w.length-w.distance:w.distance;step=Mathf.Min(remaining,toEnd/w.speed);w.distance=Mathf.Clamp(w.distance+w.direction*w.speed*step,0,w.length);Place(w);w.rig.Advance(step,true,"walk",true);if(step>=toEnd/w.speed-.00001f){w.turnFrom=w.direction>0?Mathf.PI/2:-Mathf.PI/2;w.direction=-w.direction;w.turn=1.6f;}}remaining-=step;}}}
}
}

