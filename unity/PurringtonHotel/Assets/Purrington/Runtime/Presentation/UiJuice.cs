using System;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Purrington.Presentation {
 // Buttons sink a little under the finger and spring back on release.
 public sealed class PressBounce:MonoBehaviour,IPointerDownHandler,IPointerUpHandler,IPointerExitHandler {
  bool down;
  public void OnPointerDown(PointerEventData e){down=true;var t=transform;Tween.Run(this,.08f,k=>{if(t)t.localScale=Vector3.one*Mathf.Lerp(1,.93f,Tween.OutCubic(k));});}
  public void OnPointerUp(PointerEventData e){Release();}
  public void OnPointerExit(PointerEventData e){if(down)Release();}
  void Release(){down=false;var t=transform;float from=t.localScale.x;Tween.Run(this,.28f,k=>{if(t)t.localScale=Vector3.one*Mathf.LerpUnclamped(from,1,Tween.OutBack(k));},()=>{if(t)t.localScale=Vector3.one;});}
  void OnDisable(){Tween.Stop(this);transform.localScale=Vector3.one;}
 }

 // The wallet counts up to the real balance instead of jumping, and the coin gives a little hop on a big gain.
 // The shown value survives UI rebuilds; outside Play mode or with reduced motion it is always exact.
 public sealed class CountUp:MonoBehaviour {
  static double shown=-1;
  public double Target;public TextMeshProUGUI Label;public Transform Coin;
  public static string Format(double value)=>Math.Floor(value).ToString("N0");
  public void Set(double target){
   if(shown<0||!Application.isPlaying||Tween.Reduced||Math.Abs(target-shown)>1e7)shown=target;
   else if(target-shown>=Math.Max(10,Target*.01)&&Coin)Tween.Punch(Coin,.22f,.3f);
   Target=target;Render();
  }
  void Update(){
   if(Math.Abs(Target-shown)<.5){if(shown!=Target){shown=Target;Render();}return;}
   shown+=(Target-shown)*Math.Min(1,Time.unscaledDeltaTime*7);if(Math.Abs(Target-shown)<1)shown=Target;Render();
  }
  void Render(){if(Label)Label.text=Format(shown);}
  public static void Reset()=>shown=-1;
 }

 public static class UiMotion {
  // New sheets rise and fade in; rebuilding the same sheet (a tap inside it) does not replay the motion.
  public static void SlideIn(RectTransform sheet,float distance=36){
   if(!sheet||Tween.Reduced||!Application.isPlaying)return;
   var group=sheet.GetComponent<CanvasGroup>()??sheet.gameObject.AddComponent<CanvasGroup>();
   var rest=sheet.anchoredPosition;
   Tween.Run(sheet,.24f,k=>{if(!sheet)return;float e=Tween.OutCubic(k);sheet.anchoredPosition=rest+Vector2.down*distance*(1-e);group.alpha=Mathf.Clamp01(k*2.2f);},()=>{if(sheet){sheet.anchoredPosition=rest;group.alpha=1;}});
  }
 }
}
