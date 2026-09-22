using System;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.EventSystems;
namespace Purrington.Presentation
{
 public sealed class CareGestureInput:MonoBehaviour,IPointerDownHandler,IPointerUpHandler,IDragHandler,IInitializePotentialDragHandler
 {
  public int CatId {get;private set;}
  public bool HasRecognizedGesture=>gesture.Recognized;
  public event Action<string,int,bool> RewardObserved;
  HotelApp app;Action<string> reward;readonly CareGestureRecognizer gesture=new CareGestureRecognizer();
  int pointer=int.MinValue;bool held,pending;Vector2 last,velocity,motionAnchor;float lastMove;
  float ReferenceScale {get {var canvas=GetComponentInParent<Canvas>();return canvas?Mathf.Max(.01f,canvas.scaleFactor):1f;}}
  public void Initialize(HotelApp value,int cat,string selected,Action<string> callback){app=value;CatId=cat;reward=callback;gesture.SetTool(selected);}
  public static string Help(string kind){switch(kind){case "pet":return "Stroke your cat, or rest your finger gently.";case "brush":return "Brush gently across your cat's coat.";case "wand":return "Drag the feather and let your cat catch it.";case "yarn":return "Flick the yarn, then watch your cat chase it.";case "cushion":return "Tap the room and let your cat find a soft spot.";default:return "Offer a box and wait for a curious peek.";}}
  public void SetTool(string value){Suspend();gesture.SetTool(value);app.World.CarePointer(gesture.Tool,Vector2.zero,"select",Vector2.zero);}
  public void OnInitializePotentialDrag(PointerEventData e){e.useDragThreshold=false;}
  public void OnPointerDown(PointerEventData e)
  {
   if(pointer!=int.MinValue||app==null)return;
   Suspend();pointer=e.pointerId;held=true;last=motionAnchor=e.position;lastMove=Time.unscaledTime;gesture.Begin();
   app.World.CarePointer(gesture.Tool,last,"begin",Vector2.zero);
   if(IsContactTool)ApplyContact(app.World.CareHit(last));
   else if(gesture.Tool=="box"||gesture.Tool=="cushion")Arm();
  }
  bool IsContactTool=>gesture.Tool=="pet"||gesture.Tool=="brush";
  public void OnDrag(PointerEventData e)
  {
   if(e.pointerId!=pointer||!held)return;
   float dt=Mathf.Max(Time.unscaledTime-lastMove,.001f);var previous=last;
   velocity=(e.position-last)/dt;last=e.position;lastMove=Time.unscaledTime;
   if(!RectTransformUtility.RectangleContainsScreenPoint((RectTransform)transform,last)){Suspend();return;}
   // Both endpoints must contact the coat: entering the cat cannot count off-cat travel.
   if(IsContactTool)ApplyContact(app.World.CareHit(previous)&&app.World.CareHit(last));
   float deliberateDistance=Vector2.Distance(last,motionAnchor)/ReferenceScale;
   if(IsContactTool&&!gesture.Contact)motionAnchor=last;
   else if(deliberateDistance>=2f){gesture.Move(deliberateDistance);motionAnchor=last;}
   if(gesture.TryInitialReward()){if(IsContactTool)Fire();else Arm();}
   app.World.CarePointer(gesture.Tool,last,"move",velocity);
  }
  public void OnPointerUp(PointerEventData e)
  {
   if(e.pointerId!=pointer)return;
   if(!RectTransformUtility.RectangleContainsScreenPoint((RectTransform)transform,e.position)){Suspend();return;}
   if(Time.unscaledTime-lastMove>.12f)velocity=Vector2.zero;
   bool valid=gesture.CompleteYarnOrWand(velocity.magnitude/ReferenceScale);
   app.World.CarePointer(gesture.Tool,e.position,gesture.Tool=="yarn"&&!valid?"cancel":"end",Vector2.ClampMagnitude(velocity,1500));
   if(valid)Arm();held=false;pointer=int.MinValue;ApplyContact(false);
  }
  void ApplyContact(bool contact){bool was=gesture.Contact;gesture.SetContact(contact);if(contact!=was)app.Audio?.SetCareContact(contact);}
  void Arm(){pending=true;app.World.ArmCareInteraction(gesture.Tool);}
  public void UseSelectedTool()
  {
   if(app==null||!app.Model.State.settings.assistedCare)return;
   Suspend();app.World.PlayCare(gesture.Tool);Arm();
  }
  void Update()
  {
   if(app==null)return;
   if(held&&IsContactTool)ApplyContact(app.World.CareHit(last));
   gesture.Tick(Time.unscaledDeltaTime);
   if(IsContactTool&&gesture.TryInitialReward())Fire();
   if(pending&&app.World.ConsumeCareInteraction(gesture.Tool)){pending=false;Fire();}
  }
  void Fire()
  {
   var cat=app.Model.State.cats.Find(c=>c.id==CatId);int before=cat.bond;float marker=cat.lastCare;
   reward?.Invoke(gesture.Tool);
   cat=app.Model.State.cats.Find(c=>c.id==CatId);
   RewardObserved?.Invoke(gesture.Tool,cat.bond-before,cat.lastCare!=marker);
  }
  public void Suspend()
  {
   held=pending=false;pointer=int.MinValue;velocity=Vector2.zero;gesture.ClearMotion();
   if(app==null)return;app.Audio?.SetCareContact(false);if(app.World!=null)app.World.CarePointer(gesture.Tool,last,"cancel",Vector2.zero);
  }
  void OnApplicationFocus(bool focus){if(!focus)Suspend();}
  void OnApplicationPause(bool paused){if(paused)Suspend();}
  void OnDisable()=>Suspend();
 }
}
