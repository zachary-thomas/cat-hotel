using System;
using UnityEngine;
using UnityEngine.EventSystems;
namespace Purrington.Presentation
{
 public sealed class CareGestureInput:MonoBehaviour,IPointerDownHandler,IPointerUpHandler,IDragHandler,IInitializePotentialDragHandler
 {
  HotelApp app;Action<string> reward;string tool;int pointer=int.MinValue;bool contact,held;float clock,automatic,play;Vector2 last,velocity;
  public void Initialize(HotelApp value,int cat,string selected,Action<string> callback){app=value;tool=selected;reward=callback;}
  public static string Help(string kind){switch(kind){case "pet":return "Stroke your cat, or rest your finger gently.";case "brush":return "Brush gently across your cat's coat.";case "wand":return "Drag the feather. Watch those little paws!";case "yarn":return "Drag and flick the yarn for a little chase.";case "cushion":return "Tap the room to offer a soft spot to rest.";default:return "Tap to offer a box. Tap again to peek!";}}
  public void SetTool(string value){Suspend();tool=value;app.World.CarePointer(tool,Vector2.zero,"select",Vector2.zero);}
  public void OnInitializePotentialDrag(PointerEventData e){e.useDragThreshold=false;}
  public void OnPointerDown(PointerEventData e){if(pointer!=int.MinValue)return;pointer=e.pointerId;held=true;last=e.position;velocity=Vector2.zero;clock=0;automatic=0;app.World.CarePointer(tool,last,"begin",velocity);if(tool=="pet"||tool=="brush")Contact(app.World.CareHit(last));else reward?.Invoke(tool);}
  public void OnDrag(PointerEventData e){if(e.pointerId!=pointer||!held)return;velocity=(e.position-last)/Mathf.Max(Time.unscaledDeltaTime,.001f);last=e.position;if(!RectTransformUtility.RectangleContainsScreenPoint((RectTransform)transform,last)){Suspend();return;}if(tool=="pet"||tool=="brush")Contact(app.World.CareHit(last));app.World.CarePointer(tool,last,"move",velocity);}
  public void OnPointerUp(PointerEventData e){if(e.pointerId!=pointer)return;app.World.CarePointer(tool,e.position,"end",Vector2.ClampMagnitude(velocity,1500));if(tool=="yarn")play=3.5f;else if(tool=="wand")play=1.2f;held=false;pointer=int.MinValue;Contact(false);}
  void Contact(bool value){if(value==contact)return;contact=value;if(value){app.Audio?.SetCareContact(true);reward?.Invoke(tool);}else app.Audio?.SetCareContact(false);}
  public void UseSelectedTool(){Suspend();automatic=2;app.World.PlayCare(tool);if(tool=="pet"||tool=="brush")Contact(true);else{play=3.5f;reward?.Invoke(tool);}}
  void Update(){if(automatic>0){automatic=Mathf.Max(0,automatic-Time.unscaledDeltaTime);if(automatic==0&&!held)Contact(false);}if(play>0)play=Mathf.Max(0,play-Time.unscaledDeltaTime);if(contact||((tool=="wand"||tool=="yarn")&&(held||play>0))){clock+=Time.unscaledDeltaTime;if(clock>=1){clock=0;reward?.Invoke(tool);}}}
  public void Suspend(){held=false;pointer=int.MinValue;automatic=play=clock=0;Contact(false);if(app!=null)app.World.CarePointer(tool,last,"cancel",Vector2.zero);}
  void OnApplicationFocus(bool focus){if(!focus)Suspend();}void OnApplicationPause(bool paused){if(paused)Suspend();}void OnDisable(){Suspend();}
 }
}
