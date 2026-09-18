using System;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.EventSystems;
namespace Purrington.Presentation
{
 public sealed class CareGestureInput:MonoBehaviour,IPointerDownHandler,IPointerUpHandler,IDragHandler,IInitializePotentialDragHandler
 {
  HotelApp app;Action<string> reward;readonly CareGestureRecognizer gesture=new CareGestureRecognizer();
  int pointer=int.MinValue;bool held;float automatic,play;Vector2 last,velocity;

  public void Initialize(HotelApp value,int cat,string selected,Action<string> callback){app=value;reward=callback;gesture.SetTool(selected);}
  public static string Help(string kind){switch(kind){case "pet":return "Stroke your cat, or rest your finger gently.";case "brush":return "Brush gently across your cat's coat.";case "wand":return "Drag the feather. Watch those little paws!";case "yarn":return "Drag and flick the yarn for a little chase.";case "cushion":return "Tap the room to offer a soft spot to rest.";default:return "Tap to offer a box. Tap again to peek!";}}
  public void SetTool(string value){Suspend();gesture.SetTool(value);app.World.CarePointer(gesture.Tool,Vector2.zero,"select",Vector2.zero);}
  public void OnInitializePotentialDrag(PointerEventData e){e.useDragThreshold=false;}

  public void OnPointerDown(PointerEventData e)
  {
   if(pointer!=int.MinValue)return;
   pointer=e.pointerId;held=true;last=e.position;velocity=Vector2.zero;automatic=play=0;gesture.Begin();
   app.World.CarePointer(gesture.Tool,last,"begin",velocity);
   if(gesture.Tool=="pet"||gesture.Tool=="brush")ApplyContact(app.World.CareHit(last));
   else if(gesture.TapPlacement())Fire();
  }

  public void OnDrag(PointerEventData e)
  {
   if(e.pointerId!=pointer||!held)return;
   float dt=Mathf.Max(Time.unscaledDeltaTime,.001f);
   velocity=(e.position-last)/dt;float step=Vector2.Distance(e.position,last);last=e.position;
   if(!RectTransformUtility.RectangleContainsScreenPoint((RectTransform)transform,last)){Suspend();return;}
   gesture.Move(step);
   if(gesture.Tool=="pet"||gesture.Tool=="brush")ApplyContact(app.World.CareHit(last));
   else if((gesture.Tool=="wand"||gesture.Tool=="yarn")&&gesture.TryInitialReward())Fire();
   app.World.CarePointer(gesture.Tool,last,"move",velocity);
  }

  public void OnPointerUp(PointerEventData e)
  {
   if(e.pointerId!=pointer)return;
   app.World.CarePointer(gesture.Tool,e.position,"end",Vector2.ClampMagnitude(velocity,1500));
   if(gesture.Tool=="yarn"||gesture.Tool=="wand")
   {
    if(gesture.CompleteYarnOrWand(velocity.magnitude))Fire();
    play=gesture.Tool=="yarn"?3.5f:1.2f;
   }
   held=false;pointer=int.MinValue;ApplyContact(false);
  }

  void ApplyContact(bool onCat)
  {
   bool was=gesture.Contact;gesture.SetContact(onCat);
   if(onCat!=was){if(onCat)app.Audio?.SetCareContact(true);else app.Audio?.SetCareContact(false);}
   if(onCat&&gesture.TryInitialReward())Fire();
  }

  public void UseSelectedTool()
  {
   Suspend();automatic=2;app.World.PlayCare(gesture.Tool);
   if(gesture.AccessibilityUse())Fire();
   if(gesture.Tool=="pet"||gesture.Tool=="brush")app.Audio?.SetCareContact(true);else play=3.5f;
  }

  void Update()
  {
   float dt=Time.unscaledDeltaTime;
   if(automatic>0){automatic=Mathf.Max(0,automatic-dt);if(automatic==0&&!held){gesture.SetContact(false);app.Audio?.SetCareContact(false);}}
   if(play>0)play=Mathf.Max(0,play-dt);
   gesture.Tick(dt);
   if(gesture.TryInitialReward())Fire();
   if((gesture.ChaseActive(held,play)||gesture.Contact)&&gesture.TryPulseReward())Fire();
  }

  void Fire(){reward?.Invoke(gesture.Tool);}

  public void Suspend()
  {
   held=false;pointer=int.MinValue;automatic=play=0;string tool=gesture.Tool;gesture.ClearMotion();gesture.SetTool(tool);
   app.Audio?.SetCareContact(false);if(app!=null)app.World.CarePointer(gesture.Tool,last,"cancel",Vector2.zero);
  }

  void OnApplicationFocus(bool focus){if(!focus)Suspend();}
  void OnApplicationPause(bool paused){if(paused)Suspend();}
  void OnDisable(){Suspend();}
 }
}