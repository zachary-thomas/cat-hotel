using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation {
 // Marks a light source (lamp shade, lantern, sconce). WorldLamps lights the nearest few as evening falls.
 public sealed class LampAnchor:MonoBehaviour {
  internal static readonly List<LampAnchor> All=new List<LampAnchor>();
  public float Range=3.6f,Strength=1;
  // Registered when marked rather than in OnEnable, so the registry also works for worlds built outside Play mode.
  public static LampAnchor Mark(Transform at,float range=3.6f,float strength=1){if(!at)return null;var a=at.GetComponent<LampAnchor>();if(!a){a=at.gameObject.AddComponent<LampAnchor>();All.Add(a);}a.Range=range;a.Strength=strength;return a;}
  void OnDestroy(){All.Remove(this);}
 }

 // A small pool of real point lights follows the lamps closest to the middle of the view, so glowing lamps
 // throw warm pools on floors and walls at dusk and night. Mobile keeps the pool small for URP's per-object light limit.
 public sealed class WorldLamps:MonoBehaviour {
  public Camera View;
  readonly List<Light> pool=new List<Light>();
  readonly List<(LampAnchor lamp,float score)> ranked=new List<(LampAnchor,float)>();
  public static int Budget=>Application.isMobilePlatform?4:8;
  public int Lit {get;private set;}
  void EnsurePool(){if(pool.Count>0)return;var group=new GameObject("Lamp lights").transform;group.SetParent(transform,false);for(int i=0;i<8;i++){var light=new GameObject("Lamp light "+i).AddComponent<Light>();light.transform.SetParent(group,false);light.type=LightType.Point;light.shadows=LightShadows.None;light.color=GodotGeometry.GlowColor;light.renderMode=LightRenderMode.ForcePixel;light.enabled=false;pool.Add(light);}}
  void LateUpdate(){Refresh(WorldLighting.Glow);}
  public void Refresh(float glow){
   Lit=0;EnsurePool();LampAnchor.All.RemoveAll(a=>!a);
   if(glow>.04f&&View){
    ranked.Clear();
    foreach(var lamp in LampAnchor.All){
     if(!lamp.gameObject.activeInHierarchy)continue;
     var v=View.WorldToViewportPoint(lamp.transform.position);
     if(v.z<0||v.x<-.15f||v.x>1.15f||v.y<-.15f||v.y>1.15f)continue;
     ranked.Add((lamp,(new Vector2(v.x,v.y)-new Vector2(.5f,.5f)).sqrMagnitude));
    }
    ranked.Sort((a,b)=>a.score.CompareTo(b.score));
    int budget=Mathf.Min(Budget,pool.Count);
    for(;Lit<ranked.Count&&Lit<budget;Lit++){
     var light=pool[Lit];var lamp=ranked[Lit].lamp;
     light.transform.position=lamp.transform.position;light.range=lamp.Range;light.intensity=glow*1.6f*lamp.Strength;light.enabled=true;
    }
   }
   for(int i=Lit;i<pool.Count;i++)pool[i].enabled=false;
  }
 }
}
