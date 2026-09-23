using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace Purrington.Presentation
{
    // Opt-in player verification; isolated profiles are supplied by the test launcher.
    public sealed class PreviewVerification : MonoBehaviour
    {
        bool failed;
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void StartIfRequested()
        {
            if(Environment.GetCommandLineArgs().Contains("-purrington-smoke"))
                new GameObject("Preview verification").AddComponent<PreviewVerification>();
        }
        IEnumerator Start()
        {
            var args=Environment.GetCommandLineArgs();
            string output=Path.Combine(Application.persistentDataPath,"verification");
            for(int i=0;i<args.Length-1;i++)if(args[i]=="-purrington-smoke")output=Path.GetFullPath(args[i+1]);
            Directory.CreateDirectory(output);
            yield return null;yield return null;
            var app=FindFirstObjectByType<HotelApp>();
            if(app==null||app.Model==null||app.World==null||app.UI==null){Debug.LogError("PURRINGTON_SMOKE_FAILED: missing app");Application.Quit(2);yield break;}
            Screen.SetResolution(390,844,FullScreenMode.Windowed);
            yield return new WaitForSecondsRealtime(2);
            if(!app.World.WorldCamera.orthographic){Debug.LogError("PURRINGTON_SMOKE_FAILED: perspective camera");Application.Quit(2);yield break;}
            yield return Capture(output,"01-hotel-390x844");
            app.UI.Navigate("Build");yield return Capture(output,"02-build-390x844");
            app.UI.Navigate("Cats");yield return Capture(output,"03-cats-390x844");
            app.UI.OpenCare(0);yield return Capture(output,"04-care-390x844");
            app.World.PlayCare("feather");yield return Capture(output,"05-care-feather");
            app.UI.Back();app.UI.Navigate("Life");yield return Capture(output,"06-life");
            app.UI.Navigate("Map");yield return Capture(output,"07-map");
            Screen.SetResolution(430,932,FullScreenMode.Windowed);
            yield return new WaitForSecondsRealtime(1);
            app.UI.Navigate("Hotel");yield return Capture(output,"hotel-430x932");CheckHeader(app,"430x932");
            foreach(var (minute,label) in new[]{(750f,"noon"),(1050f,"golden"),(1170f,"dusk"),(1380f,"night")}){app.World.Lighting.Pin(minute);yield return Capture(output,"living-"+label+"-430x932");}
            app.World.Lighting.Pin(1380);var lit=app.Model.State.settings;app.Model.SetSettings(lit.textScale,false,lit.music,lit.sound);yield return new WaitForSecondsRealtime(.3f);
            // Emission only survives a player build if the _EMISSION variant was kept, so count glowing world pixels with the HUD hidden (none before the fix).
            yield return CountGlow(app,output,"living-night-world-430x932");Check(glowPixels>=150,"Windows and lamps must glow at 23:00 (glowing pixels "+glowPixels+")");
            var lamps=FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None).Where(r=>r.sharedMaterial&&r.sharedMaterial.IsKeywordEnabled("_EMISSION")&&r.HasPropertyBlock()).ToArray();
            var block=new MaterialPropertyBlock();Check(lamps.Length==0||lamps.Any(r=>{r.GetPropertyBlock(block);return block.GetColor("_EmissionColor").maxColorComponent>.5f;}),"Lamps must glow at night with reduced motion");
            app.Model.SetSettings(lit.textScale,true,lit.music,lit.sound);app.World.Lighting.Pin(null);
            var tokens=ConceptTheme.Ui.All;var safeArea=app.UI.transform.Find("SafeArea");
            foreach(var chrome in new[]{"Hotel status","Navigation"}){var root=safeArea.Find(chrome);Check(root!=null,"Missing chrome "+chrome);if(root==null)continue;
             foreach(var g in root.GetComponentsInChildren<UnityEngine.UI.Graphic>(true)){var c=g.color;Check(tokens.Any(t=>Mathf.Abs(t.r-c.r)<.01f&&Mathf.Abs(t.g-c.g)<.01f&&Mathf.Abs(t.b-c.b)<.01f),chrome+" uses an off-token color on "+g.name);}}
            app.UI.Navigate("Build");yield return Capture(output,"build-430x932");
            app.UI.OpenCare(0);yield return Capture(output,"care-430x932");app.UI.Back();
            app.UI.Navigate("Hotel");
            var setting=app.Model.State.settings;
            app.Model.SetSettings(1.5f,setting.motion,false,false);
            Screen.SetResolution(360,640,FullScreenMode.Windowed);
            yield return new WaitForSecondsRealtime(1);
            app.UI.Navigate("Hotel");yield return Capture(output,"08-hotel-360x640-150");
            CheckHeader(app,"360x640@150%");
            app.UI.Navigate("Build");yield return Capture(output,"09-build-360x640-150");
            app.UI.OpenSettings();yield return Capture(output,"10-settings-360x640-150");
            app.Model.SetSettings(1,true,true,true);
            Screen.SetResolution(1280,800,FullScreenMode.Windowed);
            yield return new WaitForSecondsRealtime(1);
            app.UI.Navigate("Hotel");yield return Capture(output,"11-hotel-desktop");
            // Main Street: the whole street, then each shop interior standing in place with the town still around it.
            app.UI.ExploreMainStreet();yield return new WaitForSecondsRealtime(.6f);app.World.FitTown();yield return Capture(output,"town-fit-desktop");
            foreach(var shop in new[]{"paw_mart","clothing"}){var sent=app.Model.SendManager(shop+"_door");var skipped=app.Model.SkipManagerTravel();Debug.Log("PURRINGTON_TOWN "+shop+": send="+sent.message+" skip="+skipped.message+" shop="+app.Model.Hotel(0).town.shop);app.World.ExitTownMode();app.World.EnterTownMode();yield return new WaitForSecondsRealtime(1.2f);Check(app.World.ActiveStoreInteriorCount==1,shop+" interior opens in place");yield return Capture(output,"town-"+shop+"-inside-desktop");app.World.ExitStoreInterior();}
            app.UI.Navigate("Hotel");yield return new WaitForSecondsRealtime(.4f);
            app.World.Lighting.Pin(750);yield return Capture(output,"living-noon-desktop");app.World.Lighting.Pin(1380);yield return Capture(output,"living-night-desktop");app.World.Lighting.Pin(null);
            app.UI.Navigate("Build");yield return Capture(output,"12-build-desktop");
            foreach(var size in new[]{new Vector2Int(640,480),new Vector2Int(800,760),new Vector2Int(320,480)})
            {
                Screen.SetResolution(size.x,size.y,FullScreenMode.Windowed);
                yield return new WaitForSecondsRealtime(.5f);
                app.UI.Navigate("Hotel");yield return Capture(output,"fit-hotel-"+size.x+"x"+size.y);
                app.UI.Navigate("Build");yield return Capture(output,"fit-build-"+size.x+"x"+size.y);
            }
            app.UI.Navigate("Hotel");
            var mouse=Mouse.current;
            if(mouse!=null)
            {
                float before=app.World.WorldCamera.orthographicSize;
                InputState.Change(mouse.position,new Vector2(Screen.width*.5f,Screen.height*.4f));
                InputState.Change(mouse.scroll,new Vector2(0,1));
                app.World.SendMessage("ReadInput");
                InputState.Change(mouse.scroll,Vector2.zero);
                app.World.SendMessage("UpdateCamera");
                Check(Mathf.Abs(app.World.WorldCamera.orthographicSize-before*.85f)<.02f,"One wheel step must zoom in by 15 percent");
                InputState.Change(mouse.scroll,new Vector2(0,-1));
                app.World.SendMessage("ReadInput");
                InputState.Change(mouse.scroll,Vector2.zero);
                app.World.SendMessage("UpdateCamera");
                Check(Mathf.Abs(app.World.WorldCamera.orthographicSize-before)<.02f,"Opposite wheel step must restore zoom");
            }
            Screen.SetResolution(1280,800,FullScreenMode.Windowed);
            yield return new WaitForSecondsRealtime(1);
            float sampleStart=Time.realtimeSinceStartup;int frames=0;float worst=0;
            while(frames<180){yield return null;frames++;worst=Mathf.Max(worst,Time.unscaledDeltaTime);}
            float sampleTime=Time.realtimeSinceStartup-sampleStart;
            File.WriteAllText(Path.Combine(output,"performance.txt"),"Windows development preview, 1280x800, starter Meadow; "+frames+" frames / "+sampleTime.ToString("F2")+" s; average "+(frames/sampleTime).ToString("F1")+" FPS; worst frame "+(worst*1000).ToString("F1")+" ms. Target cap: "+Application.targetFrameRate+" FPS. This is not mobile-device performance.");
            int previousQuality=QualitySettings.GetQualityLevel();int mobileQuality=System.Array.FindIndex(QualitySettings.names,n=>n.IndexOf("Mobile",System.StringComparison.OrdinalIgnoreCase)>=0);
            if(mobileQuality>=0)QualitySettings.SetQualityLevel(mobileQuality,true);
            Screen.SetResolution(390,844,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(1);app.UI.Navigate("Hotel");
            sampleStart=Time.realtimeSinceStartup;frames=0;worst=0;while(frames<180){yield return null;frames++;worst=Mathf.Max(worst,Time.unscaledDeltaTime);}
            sampleTime=Time.realtimeSinceStartup-sampleStart;
            File.WriteAllText(Path.Combine(output,"performance-mobile.txt"),"quality="+(mobileQuality>=0?QualitySettings.names[mobileQuality]:"none")+"; 390x844; frames="+frames+"; averageMs="+(sampleTime/frames*1000).ToString("F2",System.Globalization.CultureInfo.InvariantCulture)+"; worstMs="+(worst*1000).ToString("F1",System.Globalization.CultureInfo.InvariantCulture));
            QualitySettings.SetQualityLevel(previousQuality,true);
            var save=app.Model.Save();
            bool passed=save.success&&!failed;
            File.WriteAllText(Path.Combine(output,"result.txt"),passed?"PASS: startup, orthographic camera, navigation, care stage, panel bounds, wheel zoom, layouts, night glow, header fit, save. Screenshots require visual review.":"FAIL: inspect player.log; "+save.message);
            Debug.Log(passed?"PURRINGTON_SMOKE_OK":"PURRINGTON_SMOKE_FAILED");
            Application.Quit(passed?0:2);
        }
        int glowPixels;
        IEnumerator CountGlow(HotelApp app,string output,string name)
        {
            var canvas=app.UI.GetComponent<Canvas>();if(canvas)canvas.enabled=false;
            yield return new WaitForSecondsRealtime(.3f);yield return new WaitForEndOfFrame();
            var texture=ScreenCapture.CaptureScreenshotAsTexture();int count=0;
            // Tonemapped glow reads as near-white cream; nothing else in the night world gets this bright. Rows start at the bottom: skip the build watermark.
            var pixels=texture.GetPixels32();for(int i=texture.width*(texture.height/16);i<pixels.Length;i++){var p=pixels[i];if(p.r>229&&p.g>204)count++;}
            File.WriteAllBytes(Path.Combine(output,name+".png"),texture.EncodeToPNG());Destroy(texture);
            if(canvas)canvas.enabled=true;glowPixels=count;Debug.Log("PURRINGTON_SMOKE_GLOW_PIXELS "+name+" "+count);
        }
        // Each header text must show in full on portrait phones, and the clock chip must carry "Day N".
        void CheckHeader(HotelApp app,string where)
        {
            var status=app.UI.transform.Find("SafeArea/Hotel status");Check(status!=null,where+": missing Hotel status");if(status==null)return;
            foreach(var (path,label) in new[]{("Wallet chip/Text","wallet"),("Wallet chip/Rate pill/Text","rate"),("Clock chip/Text","clock"),("Text","title")})
            {
                var t=status.Find(path)?.GetComponent<TMPro.TextMeshProUGUI>();
                if(label=="title"&&t!=null&&!t.gameObject.activeSelf)continue;
                Check(t!=null,where+": missing header "+label);if(t==null)continue;
                t.ForceMeshUpdate();Check(t.text.Length>0&&!t.isTextTruncated,where+": header "+label+" is truncated: "+t.text.Replace("\n"," / "));
            }
            var clock=status.Find("Clock chip/Text")?.GetComponent<TMPro.TextMeshProUGUI>();Check(clock!=null&&clock.text.Contains("Day"),where+": clock chip must show Day N");
        }
        void Check(bool condition,string reason){if(!condition){failed=true;Debug.LogError("PURRINGTON_SMOKE_FAILED: "+reason);}}
        IEnumerator Capture(string output,string name)
        {
            yield return new WaitForSecondsRealtime(.5f);
            yield return new WaitForEndOfFrame();
            var app=FindFirstObjectByType<HotelApp>();
            var safe=app.UI.transform.Find("SafeArea");
            foreach(RectTransform panel in safe)
            {
                if(!panel.gameObject.activeInHierarchy)continue;
                var corners=new Vector3[4];panel.GetWorldCorners(corners);
                Check(corners.All(p=>p.x>=-1&&p.y>=-1&&p.x<=Screen.width+1&&p.y<=Screen.height+1),name+": panel off screen: "+panel.name);
            }
            var texture=ScreenCapture.CaptureScreenshotAsTexture();
            File.WriteAllBytes(Path.Combine(output,name+".png"),texture.EncodeToPNG());
            Destroy(texture);
        }
    }
}
