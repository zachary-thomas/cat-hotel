using System;
using System.Collections.Generic;
using UnityEngine;
namespace Purrington.Presentation {
// Direct port of voxel_cat.gd's local rig poses. World positions belong to life simulation.
public sealed class GodotCatRig {
 public readonly Transform Root; public readonly Dictionary<string,Transform> Bindings=new Dictionary<string,Transform>();
 readonly Dictionary<Transform,Vector3> scales=new Dictionary<Transform,Vector3>();
 readonly Transform body,head,tail,mouth; readonly List<Transform> legs=new List<Transform>(),eyes=new List<Transform>(),ears=new List<Transform>();
 readonly TextMesh thought; readonly int seed; float phase; public string Reaction="";public float ReactionTime,ReactionDuration=4; public Vector2 Stroke;
 public GodotCatRig(GodotGeometry geometry,Transform parent,string collection,string id,int seed):this(geometry,parent,geometry.Recipe(collection,id),seed) {}
 public GodotCatRig(GodotGeometry geometry,Transform parent,Newtonsoft.Json.Linq.JObject recipe,int seed) {this.seed=seed;Root=geometry.Build(parent,recipe,Bindings);body=Get("body");head=Get("head");tail=Get("tail");mouth=Get("mouth");for(int i=0;i<4;i++)legs.Add(Get("legs."+i));for(int i=0;i<2;i++){eyes.Add(Get("eyes."+i));ears.Add(Get("ears."+i));}Blush(geometry);foreach(var t in Bindings.Values)scales[t]=t.localScale;phase=seed*1.71f;thought=Root.GetComponentInChildren<TextMesh>(true);if(thought)thought.text="";}
 // Rosy cheeks just below and outside each eye, built in the head's space so they follow every head pose.
 void Blush(GodotGeometry geometry){
  var headAt=Root.InverseTransformPoint(head.position);
  var rel=new Vector3(Mathf.Abs(head.lossyScale.x/Root.lossyScale.x),Mathf.Abs(head.lossyScale.y/Root.lossyScale.y),Mathf.Abs(head.lossyScale.z/Root.lossyScale.z));
  for(int i=0;i<eyes.Count;i++){
   var eye=Root.InverseTransformPoint(eyes[i].position);float outward=Mathf.Sign(eye.x-headAt.x);if(outward==0)outward=i==0?-1:1;
   var at=head.InverseTransformPoint(Root.TransformPoint(eye+new Vector3(outward*.05f,-.075f,.012f)));
   var size=new Vector3(.08f/rel.x,.035f/rel.y,.02f/rel.z);
   var cheek=geometry.Build(head,ManagerCatArt.Node("Blush",at,size,"F2A7B5"));cheek.name="Blush";
  }
 }
 Transform Get(string name){if(!Bindings.TryGetValue(name,out var t))throw new InvalidOperationException("Authored cat is missing rig binding "+name);return t;}
 static float S(float x)=>Mathf.Sin(x);static void Rot(Transform t,float x=0,float y=0,float z=0){t.localRotation=Quaternion.Euler(new Vector3(x,y,z)*Mathf.Rad2Deg);}static void Y(Transform t,float v){var p=t.localPosition;p.y=v;t.localPosition=p;}static void ScaleY(Transform t,float v){var s=t.localScale;s.y=v;t.localScale=s;}
 void Close(){foreach(var e in eyes)ScaleY(e,.012f);}
 void Prop(string name){if(Bindings.TryGetValue("props."+name,out var t))t.gameObject.SetActive(true);}
 Transform PropNode(string name){Bindings.TryGetValue("props."+name,out var t);return t;}
 // The shared screen-space overlay owns dialogue; never leave floating text on the rig.
 public void Speech(string text){if(thought){thought.text="";thought.gameObject.SetActive(false);}}
 public void React(string kind,float duration=4){Reaction=kind;ReactionTime=0;ReactionDuration=duration;}
 public void Advance(float delta,bool motion,string action,bool walking,string gesture="",float activityTime=0,bool staff=false,int role=0){
  if(Reaction!=""){ReactionTime+=delta;if(ReactionTime>=ReactionDuration)Reaction="";}
  body.localPosition=Vector3.zero;body.localRotation=Quaternion.identity;body.localScale=Vector3.one;Rot(head);Rot(tail); mouth.localScale=scales[mouth];foreach(var l in legs)Rot(l);foreach(var e in ears)Rot(e);
  foreach(var b in Bindings)if(b.Key.StartsWith("props.")){b.Value.gameObject.SetActive(false);b.Value.localPosition=Vector3.zero;Rot(b.Value);}
  if(!motion){if(action=="push_cart"){Rot(legs[1],-.6f);Rot(legs[3],-.6f);}ScaleY(body,action=="sleep"?.68f:1);foreach(var e in eyes)ScaleY(e,action=="sleep"?.012f:.09f);return;}
  phase+=delta;for(int i=0;i<legs.Count;i++)Rot(legs[i],walking?S(phase*9+(i%3)*Mathf.PI)*.30f:0);Rot(tail,0,0,S(phase*1.8f)*.17f);
  switch(action){case "push_cart":Rot(legs[1],-.6f);Rot(legs[3],-.6f);Rot(head,0,0,S(phase*1.2f)*.04f);break;case "walk":{float hop=walking?Mathf.Abs(S(phase*9)):0;Y(body,hop*.05f);if(walking){float land=1-hop;body.localScale=new Vector3(1+land*.05f,1-land*.06f+hop*.03f,1-land*.02f);}break;}case "sleep":ScaleY(body,.66f+S(phase*1.6f)*.02f);Rot(head,-.12f);break;case "eat":case "work":case "drink":case "serve":case "clean":Rot(head,.12f+S(phase*3.5f)*.12f);break;case "play":Y(body,Mathf.Max(0,S(phase*2))*.17f);Rot(head,0,0,S(phase*1.5f)*.15f);break;default:ScaleY(body,1+S(phase*1.8f)*.015f);Rot(head,0,0,S(phase*.9f)*.05f);break;}
  foreach(var e in eyes)ScaleY(e,action=="sleep"||phase%5.3f<.12f?.012f:.09f);for(int i=0;i<ears.Count;i++)Rot(ears[i],0,0,S(phase*.6f+i)*.09f);
  string pose=Reaction;float t=ReactionTime;
  if(pose==""&&!walking){pose=staff?(action=="clean"?"sweep":new[]{"checkin","cook","towels"}[Math.Abs(role)%3]):action=="rest"?new[]{"rest","groom","rest","yawn","rest","stretch","rest","loaf"}[(int)(phase/6)%8]:action=="play"?"pounce":action;t=phase%4;}
  Pose(pose,t);if(gesture!=""&&!walking&&Reaction=="")Social(gesture=="chat"?"talk":gesture,activityTime);
 }
 void Pose(string pose,float t){float ease=S(Mathf.Clamp01(t/Mathf.Max(.5f,ReactionDuration))*Mathf.PI);switch(pose){
 case "purr":case "brush":case "head_bump":Close();Rot(head,-.12f+Stroke.y*.10f,0,S(t*2)*.14f+Stroke.x*.10f);ScaleY(body,.91f+S(phase*25)*.007f);foreach(int i in new[]{1,3})Rot(legs[i],S(t*6+i*Mathf.PI*.5f)*.23f);Rot(tail,0,0,S(t)*.38f);if(pose=="head_bump")body.localPosition=new Vector3(0,0,S(t*2)*.12f);else if(pose=="purr"){switch(Math.Abs(seed)%4){case 0:ScaleY(body,body.localScale.y+ease*.08f);break;case 1:Rot(head,-.12f+Stroke.y*.1f,S(t)*.13f,S(t*2)*.14f+Stroke.x*.1f);break;case 2:Rot(body,0,0,ease*.28f);break;case 3:ScaleY(body,body.localScale.y-ease*.1f);break;}}break;
 case "pounce":case "missed_jump":Prop("toy");t%=4;if(t<1.3f){ScaleY(body,.75f);Rot(body,0,S(t*22)*.07f);}else if(t<2.3f){float jump=S((t-1.3f)*Mathf.PI);body.localPosition=new Vector3(0,jump*(pose=="missed_jump"?.3f:.6f),jump*.3f);Rot(legs[0],-jump*.6f);Rot(legs[2],-jump*.6f);}else{Rot(head,.25f);PropNode("toy").localPosition=Vector3.back*.38f;}break;
 case "chase":case "zoomies":if(pose=="chase")Prop("toy");PropNode("toy").localPosition=Vector3.right*S(t*3)*.4f;body.localPosition=new Vector3(S(t*3-.5f)*.34f,Mathf.Abs(S(t*12))*.06f,0);Rot(body,0,Mathf.Cos(t*3)*.4f);for(int i=0;i<4;i++)Rot(legs[i],S(t*15+i*Mathf.PI*.7f)*.5f);break;
 case "groom":Rot(legs[1],-1.5f+S(t*5)*.2f);Rot(head,.25f,0,-.18f);break;
 case "yawn":Close();mouth.localScale=new Vector3(.08f,.055f+Mathf.Abs(S(t*.8f))*.13f,.02f);Rot(head,-.23f);break;
 case "stretch":body.localScale=new Vector3(1,1,1+Mathf.Abs(S(t))*.15f);Rot(head,.25f);Rot(legs[1],-.7f);Rot(legs[3],-.7f);break;
 case "settle":if(t<1.4f)Rot(body,0,t/1.4f*Mathf.PI*2);else if(t<2.8f){Rot(legs[1],S(t*8)*.3f);Rot(legs[3],-S(t*8)*.3f);}else{ScaleY(body,.66f);Close();}break;
 case "loaf":case "shared_nap":ScaleY(body,.68f);Close();Rot(tail,0,0,.7f);break;
 case "box":Prop("box");ScaleY(body,.72f);Rot(head,0,0,S(t)*.16f);break;
 case "blanket":Prop("blanket");ScaleY(body,.72f);body.localPosition=Vector3.back*ease*.16f;Close();break;
 case "sniff":Rot(head,.24f+S(t*8)*.06f);Rot(legs[1],-.5f*Mathf.Abs(S(t*2)));break;
 case "friendship":if(t<2){body.localPosition=Vector3.forward*S(t*Mathf.PI/2)*.15f;Rot(head,-.06f);}else if(t<4){Rot(legs[1],-.9f);Rot(head,0,0,S(t*3)*.10f);}else{ScaleY(body,.68f);Close();}break;
 case "arrival":case "departure":Prop("suitcase");Rot(PropNode("suitcase"),0,0,S(t*6)*.05f);Rot(legs[1],0,0,S(t*5)*.4f);Rot(head,S(t*2)*.15f);break;
 case "greet":case "checkin":if(pose=="checkin")Prop("key");Rot(head,Mathf.Max(0,S(t*2))*.3f);Rot(legs[1],-.6f*Mathf.Abs(S(t*2)));break;
 case "cook":Prop("spoon");Rot(PropNode("spoon"),0,S(t*4)*.45f);Rot(legs[1],S(t*4)*.3f);Rot(head,.2f);break;
 case "towels":Prop("towels");Rot(PropNode("towels"),0,0,S(t*2)*.05f);Rot(head,0,0,S(t*1.3f)*.07f);break;
 case "sweep":Prop("broom");Rot(PropNode("broom"),0,0,S(t*5)*.25f);Rot(legs[1],S(t*5)*.3f);Rot(head,.18f);break;
 case "trim":Prop("shears");Rot(PropNode("shears"),0,S(t*6)*.25f);Rot(legs[1],S(t*6)*.35f);break;
 case "construction":Prop("hat");Prop("hammer");Rot(PropNode("hammer"),-Mathf.Abs(S(t*4.5f))*.65f);Rot(legs[1],S(t*9)*.55f);Y(body,Mathf.Abs(S(t*4))*.04f);break;
 case "celebrate":Y(body,Mathf.Max(0,S(t*4))*.28f);Rot(legs[1],0,0,.45f);Rot(legs[3],0,0,-.45f);break;case "inspect":Rot(head,0,S(t*1.5f)*.4f);Rot(legs[1],-.65f);break;
 }}
 void Social(string kind,float t){switch(kind){case "wave":Rot(legs[1],-.85f,0,S(t*11)*.22f);Rot(head,0,0,-.1f);break;case "talk":Rot(head,S(t*6)*.055f,S(t*3.5f)*.12f);ScaleY(mouth,.055f+Mathf.Max(0,S(t*10))*.035f);Rot(legs[1],-.18f-Mathf.Abs(S(t*3))*.18f);break;case "listen":Rot(head,S(t*2.4f)*.045f,0,.12f+S(t*1.7f)*.035f);Rot(tail,0,0,S(t*2)*.24f);break;case "happy":Close();Y(body,t<1.3f?Mathf.Max(0,S(t*5))*.08f:0);Rot(head,0,0,S(t*3)*.1f);Rot(tail,0,0,S(t*4)*.27f);break;case "warm":Close();Rot(legs[1],-.45f);Rot(legs[3],-.45f);Rot(head,-.08f);break;case "curious":Rot(head,0,S(t*2.1f)*.23f,.14f);Rot(legs[1],-Mathf.Max(0,S(t*2.8f))*.65f);break;
 case "dig":Rot(head,.26f);ScaleY(body,.84f);foreach(float marker in new[]{1.1f,2.3f,3.5f}){float kick=Mathf.Max(0,1-Mathf.Abs(t-marker)/.32f);Rot(legs[0],kick*.85f);Rot(legs[2],kick*.5f);if(kick>0)break;}if(t>4.5f)Rot(head,.26f,0,S(t*2)*.12f);break;case "scratch":Rot(head,.2f);Rot(legs[1],-.72f+S(t*9)*.3f);Rot(legs[3],-.72f-S(t*9)*.3f);break;case "peek":ScaleY(body,.72f+(S(t*1.7f)*.5f+.5f)*.28f);Rot(head,0,0,S(t*2)*.16f);break;case "knead":Rot(legs[1],S(t*7)*.3f);Rot(legs[3],-S(t*7)*.3f);ScaleY(body,.87f+S(t*7)*.018f);Close();break;case "play_object":Y(body,Mathf.Max(0,S(t*3))*.06f);Rot(legs[1],-Mathf.Max(0,S(t*5))*.8f);Rot(head,0,S(t*2)*.12f);break;case "serve":Rot(legs[1],-.6f+S(t*7)*.1f);Rot(head,.18f);break;case "handoff":Rot(legs[1],-.95f);Rot(head,-.06f);break;}}
}
}
