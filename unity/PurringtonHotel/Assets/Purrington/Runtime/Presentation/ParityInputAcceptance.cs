using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    // Explicit opt-in player harness. All navigation and care use queued device
    // events through the real InputSystemUIInputModule; no Button.onClick calls.
    public sealed class ParityInputAcceptance : MonoBehaviour
    {
        HotelApp app;
        Mouse mouse;
        Touchscreen touch;
        string output,caseName;
        float deadline;
        bool finished;
        readonly JArray cases=new JArray(),errors=new JArray();
        JObject current;
        JArray checks;
        int failures;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Install()
        {
            var args=Environment.GetCommandLineArgs();int index=Array.IndexOf(args,"-purrington-input-acceptance");
            if(index<0)return;
            var instance=new GameObject("Parity input acceptance").AddComponent<ParityInputAcceptance>();
            instance.output=index+1<args.Length&&!args[index+1].StartsWith("-")?Path.GetFullPath(args[index+1]):Path.Combine(Application.persistentDataPath,"input-acceptance");
        }
        IEnumerator Start()
        {
            Directory.CreateDirectory(output);deadline=Time.realtimeSinceStartup+600;
            Application.logMessageReceived+=OnLog;
            while((app=FindFirstObjectByType<HotelApp>())==null||app.UI==null){if(Time.realtimeSinceStartup>deadline){Finish("startup timeout");yield break;}yield return null;}
            mouse=InputSystem.AddDevice<Mouse>("Parity acceptance mouse");touch=InputSystem.AddDevice<Touchscreen>("Parity acceptance touch");
            var sizes=new[]{new Vector2Int(360,640),new Vector2Int(360,800),new Vector2Int(390,844),new Vector2Int(430,932),new Vector2Int(640,480),new Vector2Int(800,760),new Vector2Int(1280,800)};
            foreach(var size in sizes)foreach(float scale in new[]{1f,1.25f,1.5f})
            {
                caseName=size.x+"x"+size.y+"-text"+(int)(scale*100);checks=new JArray();current=new JObject{{"case",caseName},{"checks",checks}};cases.Add(current);
                Screen.SetResolution(size.x,size.y,FullScreenMode.Windowed);
                float end=Time.realtimeSinceStartup+4;
                while((Screen.width!=size.x||Screen.height!=size.y)&&Time.realtimeSinceStartup<end)yield return null;
                yield return null;
                Check("requested viewport",Screen.width==size.x&&Screen.height==size.y,Screen.width+"x"+Screen.height);
                // Insets are injected only for layout setup; state-changing UI is driven below.
                Rect safe=new Rect(8,16,Screen.width-16,Screen.height-40);app.UI.ConfigureAcceptanceLayout(safe,scale);
                yield return Frames(3);
                yield return Click("Hotel","Navigation");
                yield return Click("Build","Navigation");Check("Build navigation",app.UI.ActiveTab=="Build");
                Check("browse world height",app.UI.AvailableWorldRect.height/Screen.height>=.35f,app.UI.AvailableWorldRect.ToString());
                CheckLayout(safe);
                var cameraPosition=app.World.WorldCamera.transform.position;float cameraZoom=app.World.WorldCamera.orthographicSize;
                var scroll=app.UI.GetComponentsInChildren<ScrollRect>().FirstOrDefault(s=>s.vertical);
                if(scroll){yield return Wheel(HotelUI.ScreenBounds(scroll.viewport).center,-180);yield return Wheel(HotelUI.ScreenBounds(scroll.viewport).center,180);}
                Check("catalogue wheel does not zoom world",CameraEqual(cameraPosition,cameraZoom));
                yield return Click("Rooms");
                yield return Click(null,"Guest room");Check("room placement opened",app.UI.IsPlacing);
                Check("placement world height",app.UI.AvailableWorldRect.height/Screen.height>=.5f,app.UI.AvailableWorldRect.ToString());
                yield return Screenshot("placement");
                cameraPosition=app.World.WorldCamera.transform.position;cameraZoom=app.World.WorldCamera.orthographicSize;
                yield return Click("Rotate");Check("rotate UI does not pan world",CameraEqual(cameraPosition,cameraZoom));
                yield return Click("Cancel");Check("placement cancelled",!app.UI.IsPlacing);
                yield return Click("Cats","Navigation");Check("Cats navigation",app.UI.ActiveTab=="Cats");
                cameraPosition=app.World.WorldCamera.transform.position;cameraZoom=app.World.WorldCamera.orthographicSize;
                yield return Click("Visit");Check("care opened",app.UI.IsInCare);
                if(app.UI.IsInCare)
                {
                    var gesture=app.UI.GetComponentInChildren<CareGestureInput>();int gestureId=gesture.GetInstanceID();
                    Rect stage=HotelUI.ScreenBounds((RectTransform)gesture.transform);Vector2 catPoint=FindCatPoint(stage);
                    Check("cat is hittable inside care viewport",app.World.CareHit(catPoint),catPoint.ToString());
                    double elapsed=app.Model.State.elapsed;int bond=app.Model.State.cats.Sum(c=>c.bond);
                    Vector3 carePosition=app.World.WorldCamera.transform.position;float careZoom=app.World.WorldCamera.orthographicSize;
                    yield return TouchGesture(catPoint,catPoint+new Vector2(48,6),1.15f);
                    Check("hotel simulation continues during care",app.Model.State.elapsed>elapsed+.5);
                    Check("care friendship does not regress",app.Model.State.cats.Sum(c=>c.bond)>=bond);
                    yield return Click("Brush");yield return MouseGesture(catPoint+Vector2.left*12,catPoint+Vector2.right*15,.35f);
                    yield return Click("Feather");yield return MouseGesture(stage.center+Vector2.left*30,stage.center+Vector2.right*35,.35f);
                    yield return Click("Yarn");yield return TouchGesture(stage.center+Vector2.left*40,stage.center+Vector2.right*50,.12f);
                    yield return Click("Cushion");yield return TouchGesture(stage.center,stage.center,.1f);
                    yield return Click("Box");yield return MouseGesture(stage.center,stage.center,.1f);yield return MouseGesture(stage.center,stage.center,.1f);
                    Check("care gestures retain persistent stage",app.UI.GetComponentInChildren<CareGestureInput>().GetInstanceID()==gestureId);
                    Check("care gestures do not move world camera",CameraEqual(carePosition,careZoom));
                    yield return Screenshot("care");
                    yield return Click("Back","Hotel status");
                    Check("care returns to Cats",!app.UI.IsInCare&&app.UI.ActiveTab=="Cats");
                    Check("care restores hotel camera",CameraEqual(cameraPosition,cameraZoom));
                }
                yield return Click("Life","Navigation");Check("Life navigation",app.UI.ActiveTab=="Life");
                yield return Click("Map","Navigation");Check("Map navigation",app.UI.ActiveTab=="Map");
                yield return Click("Menu","Hotel status");
                Check("settings opened",app.UI.GetComponentsInChildren<RectTransform>().Any(r=>r.name=="Settings"));
                CheckLayout(safe);yield return Screenshot("settings");
                yield return Click("Hotel","Navigation");Write("running");
            }
            Finish("completed");
        }
        IEnumerator Frames(int count){for(int i=0;i<count;i++)yield return null;}
        bool Ancestor(Transform item,string name){for(var t=item;t!=null;t=t.parent)if(t.name==name)return true;return false;}
        Button FindButton(string label,string ancestor)
        {
            return app.UI.GetComponentsInChildren<Button>().FirstOrDefault(b=>b.isActiveAndEnabled&&b.interactable&&(label==null||b.name==label)&&(ancestor==null||Ancestor(b.transform,ancestor))&&Hit(b));
        }
        bool Hit(Button button)
        {
            var position=HotelUI.ScreenBounds((RectTransform)button.transform).center;
            if(position.x<0||position.y<0||position.x>Screen.width||position.y>Screen.height)return false;
            var hits=new List<RaycastResult>();EventSystem.current.RaycastAll(new PointerEventData(EventSystem.current){position=position},hits);
            return hits.Count>0&&hits[0].gameObject.GetComponentInParent<Button>()==button;
        }
        IEnumerator Click(string label,string ancestor=null)
        {
            Button button=null;
            for(int step=0;step<36;step++)
            {
                button=FindButton(label,ancestor);if(button)break;
                var scroll=app.UI.GetComponentsInChildren<ScrollRect>().FirstOrDefault(s=>s.vertical&&s.isActiveAndEnabled);
                if(!scroll)break;
                yield return Wheel(HotelUI.ScreenBounds(scroll.viewport).center,step<24?-180:360);
            }
            if(!button){Check("click "+(label??ancestor),false,"No visible raycastable control after real scroll input");yield break;}
            yield return MouseGesture(HotelUI.ScreenBounds((RectTransform)button.transform).center,HotelUI.ScreenBounds((RectTransform)button.transform).center,.07f);
        }
        IEnumerator Wheel(Vector2 position,float delta)
        {
            InputSystem.QueueStateEvent(mouse,new MouseState{position=position,scroll=new Vector2(0,delta)});yield return Frames(2);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=position});yield return Frames(2);
        }
        IEnumerator MouseGesture(Vector2 from,Vector2 to,float seconds)
        {
            InputSystem.QueueStateEvent(mouse,new MouseState{position=from});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=from,buttons=1});yield return Frames(2);
            float elapsed=0;while(elapsed<seconds){elapsed+=Time.unscaledDeltaTime;InputSystem.QueueStateEvent(mouse,new MouseState{position=Vector2.Lerp(from,to,Mathf.Clamp01(elapsed/seconds)),buttons=1});yield return null;}
            InputSystem.QueueStateEvent(mouse,new MouseState{position=to});yield return Frames(3);
        }
        IEnumerator TouchGesture(Vector2 from,Vector2 to,float seconds)
        {
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=1,phase=UnityEngine.InputSystem.TouchPhase.Began,position=from,pressure=1});yield return Frames(2);
            float elapsed=0;while(elapsed<seconds){elapsed+=Time.unscaledDeltaTime;InputSystem.QueueStateEvent(touch,new TouchState{touchId=1,phase=UnityEngine.InputSystem.TouchPhase.Moved,position=Vector2.Lerp(from,to,Mathf.Clamp01(elapsed/seconds)),pressure=1});yield return null;}
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=1,phase=UnityEngine.InputSystem.TouchPhase.Ended,position=to});yield return Frames(3);
        }
        Vector2 FindCatPoint(Rect stage){for(int y=2;y<9;y++)for(int x=2;x<9;x++){var p=new Vector2(Mathf.Lerp(stage.xMin,stage.xMax,x/10f),Mathf.Lerp(stage.yMin,stage.yMax,y/10f));if(app.World.CareHit(p))return p;}return stage.center;}
        bool CameraEqual(Vector3 position,float zoom)=>Vector3.Distance(position,app.World.WorldCamera.transform.position)<.015f&&Mathf.Abs(zoom-app.World.WorldCamera.orthographicSize)<.015f;
        void CheckLayout(Rect safe)
        {
            var canvas=app.UI.GetComponent<Canvas>();int count=0;var small=new JArray();var outside=new JArray();var physicallySmall=new JArray();
            foreach(var button in app.UI.GetComponentsInChildren<Button>())if(Hit(button))
            {
                count++;var r=HotelUI.ScreenBounds((RectTransform)button.transform);
                if(r.width/canvas.scaleFactor<43.5f||r.height/canvas.scaleFactor<43.5f)small.Add(button.name);
                if(r.width<43.5f||r.height<43.5f)physicallySmall.Add(button.name);
                if(!safe.Contains(r.center))outside.Add(button.name);
            }
            Check("visible controls stay in safe area",outside.Count==0,outside.ToString(Formatting.None));
            Check("visible controls have 44 logical unit targets",small.Count==0,small.ToString(Formatting.None));
            Check("visible controls have 44 screen pixel targets",physicallySmall.Count==0,physicallySmall.ToString(Formatting.None));
            Check("interactive controls exist",count>4,count.ToString());
        }
        IEnumerator Screenshot(string context)
        {
            yield return new WaitForEndOfFrame();string path=Path.Combine(output,caseName+"-"+context+".png");ScreenCapture.CaptureScreenshot(path);yield return Frames(2);
            if(current["screenshots"]==null)current["screenshots"]=new JArray();((JArray)current["screenshots"]).Add(path);
        }
        void Check(string name,bool passed,string detail=""){checks?.Add(new JObject{{"name",name},{"passed",passed},{"detail",detail}});if(!passed)failures++;if(checks!=null)Write("running");}
        void OnLog(string message,string trace,LogType type){if(type!=LogType.Exception&&type!=LogType.Error)return;if(errors.Count<40)errors.Add(new JObject{{"message",message},{"trace",trace}});}
        void Write(string status){File.WriteAllText(Path.Combine(output,"input-acceptance.json"),new JObject{{"status",status},{"cases",cases},{"failedChecks",failures},{"runtimeErrors",errors},{"inputMethod","queued MouseState and TouchState through InputSystemUIInputModule"},{"layoutSetup","Viewport, simulated safe insets and text scale configured before each case"}}.ToString(Formatting.Indented));}
        void Finish(string status){if(finished)return;finished=true;Write(status);Application.logMessageReceived-=OnLog;if(mouse!=null)InputSystem.RemoveDevice(mouse);if(touch!=null)InputSystem.RemoveDevice(touch);if(app)app.ExitWithoutSaving();else Application.Quit();}
        void Update(){if(!finished&&deadline>0&&Time.realtimeSinceStartup>deadline)Finish("timeout");}
    }
}
