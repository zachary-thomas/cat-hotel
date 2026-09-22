using System;
using System.Collections;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
 // Explicit opt-in evidence capture. Launch with an isolated -purrington-profile.
 public sealed class ConceptSceneVerification : MonoBehaviour
 {
  string output;
  [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
  static void Requested()
  {
   var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,"-purrington-concept");
   if(i<0||i+1>=args.Length)return;
   new GameObject("Concept evidence").AddComponent<ConceptSceneVerification>().output=Path.GetFullPath(args[i+1]);
  }
  IEnumerator Start()
  {
   Directory.CreateDirectory(output);yield return new WaitForSecondsRealtime(1);
   var app=FindFirstObjectByType<HotelApp>();var model=app.Model;
   model.State.coins=10000;
   var bar=model.Execute("place_object",new JObject{{"item","milkshake_counter"},{"x",0},{"y",8},{"rotation",0}});
   var seat=model.Execute("place_object",new JObject{{"item","bench"},{"x",4},{"y",8},{"rotation",0}});
   if(!bar.success||!seat.success){File.WriteAllText(Path.Combine(output,"result.txt"),"FAIL fixture: "+bar.message+" / "+seat.message);app.ExitWithoutSaving();yield break;}
   Screen.SetResolution(1280,800,FullScreenMode.Windowed);app.UI.Navigate("Hotel");
   yield return new WaitForSecondsRealtime(2);
   yield return Shot("meadow-concept-desktop");
   var counter=model.State.objects.Last(o=>o.itemId=="milkshake_counter");
   app.World.FocusObject(counter.id);
   bool order=false,reply=false;float deadline=Time.realtimeSinceStartup+150;
   while(Time.realtimeSinceStartup<deadline&&(!order||!reply))
   {
    var guest=model.Actors.FirstOrDefault(a=>a.kind!=ActorKind.Staff&&a.venueId==counter.id&&a.phase=="order"&&a.activityElapsed>.5f&&a.activityElapsed<1.5f);
    if(!order&&guest!=null){yield return Shot("milkshake-order-front-of-desk");order=true;}
    var staff=model.Actors.FirstOrDefault(a=>a.kind==ActorKind.Staff&&a.venueId==counter.id&&a.action=="serve"&&a.activityElapsed>.6f&&a.activityElapsed<2);
    if(order&&!reply&&staff!=null){yield return Shot("milkshake-staff-reply");reply=true;}
    yield return null;
   }
   bool drinking=false,departing=false;float departureDeadline=Time.realtimeSinceStartup+100;
   while(Time.realtimeSinceStartup<departureDeadline&&model.CompletedDayVisits==0)
   {
    if(!drinking&&model.Actors.Any(a=>a.kind==ActorKind.DayVisitor&&a.action=="drink")){yield return Shot("visitor-drinking");drinking=true;}
    if(!departing&&model.Actors.Any(a=>a.kind==ActorKind.DayVisitor&&a.phase=="walk_depart")){yield return Shot("visitor-departing");departing=true;}
    yield return null;
   }
   app.World.FocusHotel();yield return Shot("meadow-with-day-visitors");
   Screen.SetResolution(430,932,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(1);
   app.UI.OpenCare(0);yield return new WaitForSecondsRealtime(2);yield return Shot("care-roaming");
   File.WriteAllText(Path.Combine(output,"result.txt"),"Order captured: "+order+"; staff reply captured: "+reply+"; visitor drinking: "+drinking+"; visitor departing: "+departing+"; completed day visits: "+model.CompletedDayVisits+". Fixtures use an isolated profile.");
   app.ExitWithoutSaving();
  }
  IEnumerator Shot(string name)
  {
   yield return new WaitForEndOfFrame();var texture=ScreenCapture.CaptureScreenshotAsTexture();
   File.WriteAllBytes(Path.Combine(output,name+".png"),texture.EncodeToPNG());Destroy(texture);
  }
 }
}
