using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Purrington.Presentation {
// Explicit opt-in capture runner. Production startup never reads reference files.
public sealed class ParityRenderAcceptance:MonoBehaviour {
 HotelApp app;string output;JArray references;JObject current;readonly List<double> timings=new List<double>();bool lockCamera;
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]static void Boot(){if(Environment.GetCommandLineArgs().Contains("-purrington-render-acceptance"))new GameObject("Rendered parity acceptance").AddComponent<ParityRenderAcceptance>();}
 IEnumerator Start(){var args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-purrington-render-acceptance");output=Path.GetFullPath(args[at+1]);references=(JArray)JObject.Parse(File.ReadAllText(args[at+2]))["captures"];Directory.CreateDirectory(output);yield return null;yield return null;app=FindFirstObjectByType<HotelApp>();if(!app||app.Model==null){Debug.LogError("PARITY_RENDER_STARTUP_FAILED");Application.Quit(2);yield break;}Screen.SetResolution(1280,800,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(1);app.enabled=false;app.UI.gameObject.SetActive(false);Time.captureFramerate=10;
 foreach(int map in Enumerable.Range(0,4)){
  app.Model.State.currentHotel=map;app.World.SendMessage("Refresh");app.Model.State.settings.evening=false;app.World.SetEvening(false);
  for(int n=0;n<100;n++){app.Model.Tick(.1f);yield return null;}
  foreach(string suffix in new[]{"opening","neighborhood","evening"}){current=references.OfType<JObject>().First(r=>(string)r["name"]=="map-"+map+"-"+suffix);lockCamera=true;app.World.SetEvening(suffix=="evening");yield return null;yield return Capture((string)current["name"]);}
  if(map==0){app.World.SetEvening(false);foreach(string scene in new[]{"neighborhood","fountain","cafe-service"}){current=references.OfType<JObject>().First(r=>(string)r["name"]==scene+"-000");for(int frame=0;frame<30;frame++){app.Model.Tick(.1f);yield return null;yield return Capture(scene+"-"+frame.ToString("000"));}}}
 }
 lockCamera=false;Time.captureFramerate=0;app.Model.State.currentHotel=0;app.World.SendMessage("Refresh");app.World.SetEvening(false);app.World.FocusHotel();app.enabled=true;Application.targetFrameRate=-1;QualitySettings.vSyncCount=0;yield return new WaitForSecondsRealtime(2);
 for(int n=0;n<300;n++){double start=Time.realtimeSinceStartupAsDouble;yield return null;timings.Add((Time.realtimeSinceStartupAsDouble-start)*1000);}
 timings.Sort();File.WriteAllText(Path.Combine(output,"render-results.json"),new JObject{["scenario"]="populated starter hotel and neighborhood",["frames"]=timings.Count,["medianFrameMs"]=timings[timings.Count/2],["p95FrameMs"]=timings[(int)(timings.Count*.95)],["averageFps"]=1000/timings.Average(),["width"]=Screen.width,["height"]=Screen.height,["gpu"]=SystemInfo.graphicsDeviceName,["visualAcceptance"]="requires reviewed matching captures"}.ToString());Debug.Log("PARITY_RENDER_CAPTURE_OK");Application.Quit();
 }
 void LateUpdate(){if(!lockCamera||current==null||app?.World==null)return;var p=current["cameraPosition"];var camera=app.World.WorldCamera;camera.transform.position=new Vector3((float)p[0],(float)p[1],-(float)p[2]);camera.transform.rotation=Quaternion.LookRotation(new Vector3(-1,-1.05f,1));camera.orthographicSize=(float)current["cameraSize"]*.5f;}
 IEnumerator Capture(string name){yield return new WaitForEndOfFrame();var image=ScreenCapture.CaptureScreenshotAsTexture();File.WriteAllBytes(Path.Combine(output,name+".png"),image.EncodeToPNG());Destroy(image);}
}
}
