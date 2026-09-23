using System;
using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation {
 // Small ease helper for world and UI juice. Runs on unscaled time so pauses and slow-motion never strand a tween,
 // and snaps straight to the end state when the player has reduced motion on.
 public sealed class Tween:MonoBehaviour {
  public static bool Reduced;
  sealed class Job {public UnityEngine.Object owner;public float time,duration,delay;public Action<float> step;public Action done;}
  static Tween runner;
  readonly List<Job> jobs=new List<Job>();
  public static int Active=>runner?runner.jobs.Count:0;
  static Tween Runner(){if(runner)return runner;var host=new GameObject("Tweens");host.hideFlags=HideFlags.HideAndDontSave;if(Application.isPlaying)DontDestroyOnLoad(host);runner=host.AddComponent<Tween>();return runner;}
  // Runs step(0..1) over duration seconds after delay; a new tween on the same owner replaces the old one.
  public static void Run(UnityEngine.Object owner,float duration,Action<float> step,Action done=null,float delay=0){
   if(!owner)return;
   if(Reduced||duration<=0||!Application.isPlaying){step(1);done?.Invoke();return;}
   var r=Runner();r.jobs.RemoveAll(j=>j.owner==owner);r.jobs.Add(new Job{owner=owner,duration=duration,delay=delay,step=step,done=done});step(0);
  }
  public static void Stop(UnityEngine.Object owner){if(runner)runner.jobs.RemoveAll(j=>j.owner==owner);}
  void Update(){
   float dt=Time.unscaledDeltaTime;
   for(int i=jobs.Count-1;i>=0;i--){
    var j=jobs[i];if(!j.owner){jobs.RemoveAt(i);continue;}
    if(j.delay>0){j.delay-=dt;continue;}
    j.time+=dt;float t=Mathf.Clamp01(j.time/j.duration);
    try{j.step(t);}catch(Exception e){Debug.LogException(e);jobs.RemoveAt(i);continue;}
    if(t>=1){jobs.RemoveAt(i);j.done?.Invoke();}
   }
  }
  public static float OutBack(float t){const float c=1.70158f;float u=t-1;return 1+(c+1)*u*u*u+c*u*u;}
  public static float OutCubic(float t){float u=1-t;return 1-u*u*u;}
  public static float OutElastic(float t){if(t<=0||t>=1)return t;return Mathf.Pow(2,-10*t)*Mathf.Sin((t*10-.75f)*(2*Mathf.PI/3))+1;}
  // Scale tweens restart from the transform's resting scale, even when a previous tween was interrupted mid-bounce.
  static readonly Dictionary<Transform,Vector3> rests=new Dictionary<Transform,Vector3>();
  static Vector3 Rest(Transform t){if(!rests.TryGetValue(t,out var r)||!IsRunning(t)){r=t.localScale;rests[t]=r;}return r;}
  static bool IsRunning(UnityEngine.Object owner)=>runner&&runner.jobs.Exists(j=>j.owner==owner);
  static void Release(Transform t,Vector3 rest){if(t)t.localScale=rest;rests.Remove(t);}
  // Drop-in-and-settle for newly placed furniture: grows from a squashed seed, overshoots, wobbles still.
  public static void Settle(Transform t){
   if(!t)return;var rest=Rest(t);
   Run(t,.5f,k=>{if(!t)return;float s=OutElastic(k);float squash=1+(1-k)*.25f*Mathf.Sin(k*Mathf.PI*3);t.localScale=new Vector3(rest.x*s*squash,rest.y*s/squash,rest.z*s*squash);},()=>Release(t,rest));
  }
  // A quick scale punch, used for buttons and pops.
  public static void Punch(Transform t,float amount=.12f,float duration=.25f){
   if(!t)return;var rest=Rest(t);
   Run(t,duration,k=>{if(t)t.localScale=rest*(1+amount*Mathf.Sin(k*Mathf.PI)*(1-k*.5f));},()=>Release(t,rest));
  }
 }
}
