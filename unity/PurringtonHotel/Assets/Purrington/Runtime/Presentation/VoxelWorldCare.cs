using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Purrington.Presentation {public sealed partial class VoxelWorld {
 Transform careStage,careProp,careCushion;GodotCatRig careRig;int careId=-1,careMap=-1;readonly Vector3 careOrigin=new Vector3(600,0,600);string careToolId="pet";Vector3 yarnVelocity;bool careHeld,careContact;bool careArmed,careCompleted,carePlacement;float careEngagement,careWanderClock;Vector3 careDestination;float careClock,carePlayClock,careAutomatic,furClock;readonly List<Fur> fur=new List<Fur>();sealed class Fur{public Transform node;public Vector3 start;public float time;}
 public void SetCareMode(int catId,bool active){if(!active){if(care){focus=savedFocus;zoom=savedZoom;}care=false;careHeld=careContact=careArmed=careCompleted=carePlacement=false;if(careStage)careStage.gameObject.SetActive(false);UpdateCamera();return;}if(!care){savedFocus=focus;savedZoom=zoom;}if(!careStage||careId!=catId||careMap!=currentMap){DisposeNode(careStage);careStage=Group(renderRoot,"Care room");careStage.localPosition=careOrigin;var bindings=new Dictionary<string,Transform>();var room=Group(careStage,"Expanded care interior");geometry.Build(room,(JObject)geometry.Map(currentMap)["care"],bindings);room.localScale=new Vector3(1.35f,1,1.25f);foreach(var t in careStage.GetComponentsInChildren<Transform>(true))if(t.name=="CareCushion")careCushion=t;careRig=new GodotCatRig(geometry,careStage,"cats",catId.ToString(),catId);careRig.Root.localPosition=Vector3.zero;careRig.Root.localScale=Vector3.one*1.3f;careProp=Group(careStage,"Care tool");careId=catId;careMap=currentMap;SelectCareTool("pet");}care=true;careStage.gameObject.SetActive(true);focus=careOrigin+new Vector3(0,.85f,0);var careViewport=VisibleWorldRect();zoom=Mathf.Max(1.7f,1.65f*careViewport.height/Mathf.Max(1,careViewport.width))*Screen.height/Mathf.Max(1,careViewport.height);UpdateCamera();}
 public bool CareHit(Vector2 screen){if(!care||careRig==null)return false;var ray=WorldCamera.ScreenPointToRay(screen);foreach(var r in careRig.Root.GetComponentsInChildren<MeshRenderer>()){if(!r.enabled||!r.gameObject.activeInHierarchy)continue;var filter=r.GetComponent<MeshFilter>();if(!filter)continue;var local=new Ray(r.transform.InverseTransformPoint(ray.origin),r.transform.InverseTransformVector(ray.direction));if(filter.sharedMesh.bounds.IntersectRay(local))return true;}return false;}
 Vector3 CarePoint(Vector2 screen,float y){var p=GroundPoint(screen,y)-careOrigin;return new Vector3(Mathf.Clamp(p.x,-1.55f,1.55f),y,Mathf.Clamp(p.z,-.7f,1.05f));}
 public void CarePointer(string tool,Vector2 screen,string phase,Vector2 velocity){if(!care)return;if(tool=="feather")tool="wand";if(phase=="select"||careToolId!=tool){SelectCareTool(tool);if(phase=="select")return;}if(phase=="cancel"){careHeld=careContact=careArmed=careCompleted=carePlacement=false;carePlayClock=careAutomatic=careEngagement=0;yarnVelocity=Vector3.zero;if(tool=="brush")careProp.gameObject.SetActive(false);return;}
 if(phase=="begin"){careHeld=true;careClock=carePlayClock=careAutomatic=0;yarnVelocity=Vector3.zero;}
 if(phase=="begin"||phase=="move"){if(tool=="pet"||tool=="brush"){careContact=CareHit(screen);if(careContact){careRig.Stroke=Vector2.ClampMagnitude(velocity/600,1);if(careRig.Reaction=="")careRig.React(tool=="brush"?"brush":"purr",2);}if(tool=="brush"){careProp.gameObject.SetActive(careContact);var ray=WorldCamera.ScreenPointToRay(screen);float d;var brushPlane=new Plane(WorldCamera.transform.forward,careRig.Root.position+Vector3.up*.75f);if(brushPlane.Raycast(ray,out d))careProp.position=ray.GetPoint(d)+Vector3.right*.15f;}}else if(tool=="wand"||tool=="yarn"){careProp.gameObject.SetActive(true);careProp.localPosition=CarePoint(screen,tool=="wand"?.8f:.16f);}else if(phase=="begin")UseCarePlacement(tool,CarePoint(screen,0));}
 if(phase=="end"){if(tool=="yarn"&&careHeld){yarnVelocity=(CarePoint(screen+Vector2.ClampMagnitude(velocity,1500)*.15f,.16f)-careProp.localPosition)*4;carePlayClock=6f;}else if(tool=="wand"&&careHeld)carePlayClock=1.2f;careHeld=careContact=false;if(tool=="brush")careProp.gameObject.SetActive(false);}}
 public void PlayCare(string tool){if(!care)return;if(tool=="feather")tool="wand";if(careToolId!=tool)SelectCareTool(tool);careClock=0;if(tool=="pet"||tool=="brush"){careRig.React(tool=="brush"?"brush":"purr",2);if(!careHeld){careAutomatic=2;careContact=true;if(tool=="brush"){careProp.gameObject.SetActive(true);careProp.localPosition=new Vector3(.55f,.95f,.9f);}}}else if(tool=="cushion"||tool=="box")UseCarePlacement(tool,new Vector3(.9f,0,.3f));else if(!careHeld){careProp.gameObject.SetActive(true);careProp.localPosition=new Vector3(.75f,tool=="wand"?.85f:.16f,.2f);carePlayClock=tool=="yarn"?6f:3.5f;if(tool=="yarn")yarnVelocity=new Vector3(-.9f,0,.2f);}}
 public void ArmCareInteraction(string tool){if(!care||tool!=careToolId)return;careArmed=true;careCompleted=false;careEngagement=0;}
 public bool ConsumeCareInteraction(string tool){if(!careCompleted||tool!=careToolId)return false;careCompleted=false;return true;}
 void UseCarePlacement(string tool,Vector3 position){careProp.localPosition=position;careDestination=position;careDestination.y=0;carePlacement=true;careEngagement=0;if(tool=="cushion"){careCushion.gameObject.SetActive(true);careCushion.position=careStage.TransformPoint(position);careProp.gameObject.SetActive(false);}else careProp.gameObject.SetActive(true);}
 void SelectCareTool(string tool){careToolId=tool;careHeld=careContact=false;carePlayClock=careAutomatic=careClock=0;yarnVelocity=Vector3.zero;careArmed=careCompleted=carePlacement=false;careEngagement=0;careRig.Reaction="";careRig.Stroke=Vector2.zero;if(careCushion)careCushion.gameObject.SetActive(false);foreach(Transform t in careProp)DisposeNode(t);careProp.localPosition=Vector3.zero;careProp.gameObject.SetActive(false);
 geometry.Build(careProp,geometry.Recipe("careTools",tool));}
 Transform Ball(Transform parent,Vector3 at,float radius,string color,Vector3 scale){var g=GameObject.CreatePrimitive(PrimitiveType.Sphere);g.transform.SetParent(parent,false);g.transform.localPosition=at;g.transform.localScale=scale*radius*2;Destroy(g.GetComponent<Collider>());g.GetComponent<MeshRenderer>().sharedMaterial=geometry.Material(color);return g.transform;}
 void AnimateCare()
 {
  if(!care||careRig==null)return;
  float dt=Time.deltaTime;bool motion=model.State.settings.motion;careClock+=dt;
  bool chasing=(careToolId=="wand"||careToolId=="yarn")&&(careHeld||carePlayClock>0);
  if(careAutomatic>0){careAutomatic=Mathf.Max(0,careAutomatic-dt);if(careAutomatic==0&&!careHeld)careContact=false;}
  if(carePlayClock>0)carePlayClock=Mathf.Max(0,carePlayClock-dt);
  if(chasing&&careToolId=="yarn"&&!careHeld)
  {
   var p=careProp.localPosition+yarnVelocity*dt;
   if(Mathf.Abs(p.x)>1.55f)yarnVelocity.x*=-.7f;
   if(p.z<-.7f||p.z>1.05f)yarnVelocity.z*=-.7f;
   p.x=Mathf.Clamp(p.x,-1.55f,1.55f);p.z=Mathf.Clamp(p.z,-.7f,1.05f);careProp.localPosition=p;
   yarnVelocity=Vector3.MoveTowards(yarnVelocity,Vector3.zero,dt*.4f);
  }
  bool walk=false;var position=careRig.Root.localPosition;
  if(!careContact)
  {
   if(chasing){careDestination=careProp.localPosition;careDestination.y=0;}
   else if(!carePlacement)
   {
    careWanderClock-=dt;
    if(careWanderClock<=0){careWanderClock=UnityEngine.Random.Range(5f,9f);careDestination=new Vector3(UnityEngine.Random.Range(-1.4f,1.4f),0,UnityEngine.Random.Range(-.5f,.85f));}
   }
   var delta=careDestination-position;delta.y=0;walk=delta.magnitude>.12f;
   if(walk)
   {
    careRig.Root.localPosition=Vector3.MoveTowards(position,careDestination,dt*(chasing?1.3f:.55f));
    careRig.Root.localRotation=Quaternion.RotateTowards(careRig.Root.localRotation,Quaternion.LookRotation(delta),dt*160f);
   }
  }
  if(careContact)
  {
   var towardViewer=careStage.InverseTransformDirection(WorldCamera.transform.position-careRig.Root.position);towardViewer.y=0;
   if(towardViewer.sqrMagnitude>.001f)careRig.Root.localRotation=Quaternion.RotateTowards(careRig.Root.localRotation,Quaternion.LookRotation(towardViewer),dt*90f);
  }
  // A reached yarn ball is caught by the paws instead of rolling straight through the cat.
  if(chasing&&careToolId=="yarn"&&!careHeld&&Vector2.Distance(new Vector2(careRig.Root.localPosition.x,careRig.Root.localPosition.z),new Vector2(careProp.localPosition.x,careProp.localPosition.z))<.45f)
  {
   yarnVelocity=Vector3.MoveTowards(yarnVelocity,Vector3.zero,dt*8f);
   if(careArmed)carePlayClock=Mathf.Max(carePlayClock,1f);
  }
  bool engaged=careContact || (carePlacement&&!walk) || (chasing&&Vector2.Distance(new Vector2(careRig.Root.localPosition.x,careRig.Root.localPosition.z),new Vector2(careProp.localPosition.x,careProp.localPosition.z))<.45f);
  if(careArmed)
  {
   careEngagement=engaged?careEngagement+dt:0;
   if(careEngagement>=.65f){careArmed=false;careCompleted=true;careRig.React(careToolId=="cushion"?"settle":careToolId=="box"?"sniff":careContact?"purr":"play",2);}
  }
  careRig.Advance(dt,motion,walk?"walk":carePlacement&&careToolId=="cushion"?"sleep":"rest",walk,engaged&&careToolId=="box"?"peek":engaged&&chasing?"play_object":"",careClock);
  if(careContact)
  {
   if(careRig.Reaction=="")careRig.React(careToolId=="brush"?"brush":"purr",2);
   if(careToolId=="brush"&&motion)
   {
    if(careAutomatic>0&&!careHeld)careProp.localPosition=careRig.Root.localPosition+new Vector3(.55f,.95f+Mathf.Sin(careClock*6)*.12f,.35f);
    furClock+=dt;if(furClock>.25f){furClock=0;var p=careProp.localPosition+Vector3.left*.1f;fur.Add(new Fur{node=Ball(careStage,p,.025f,Shade((string)model.Content.Cats[careId]["color"],.3f),Vector3.one),start=p});}
   }
  }
  for(int i=fur.Count-1;i>=0;i--){var f=fur[i];if(!f.node){fur.RemoveAt(i);continue;}f.time+=dt;float p=Mathf.Clamp01(f.time/.55f);f.node.localPosition=f.start+new Vector3(.15f,-.35f,.05f)*p;f.node.localScale=Vector3.one*.05f*(1-p);if(p>=1){DisposeNode(f.node);fur.RemoveAt(i);}}
 }
 void OnApplicationFocus(bool focused){if(!focused){careHeld=careContact=careArmed=careCompleted=carePlacement=false;carePlayClock=careAutomatic=careEngagement=0;yarnVelocity=Vector3.zero;}}
}}



