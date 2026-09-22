using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
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
        int failures,careRewardCount,careRewardGain,careRewardCatId;string careRewardTool;
        InputSettings.BackgroundBehavior priorBackgroundBehavior;bool backgroundBehaviorChanged;

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
            priorBackgroundBehavior=InputSystem.settings.backgroundBehavior;InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;backgroundBehaviorChanged=true;
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
                if(!app.Model.State.settings.godMode)app.Model.SetGodMode(true);
                yield return DrawRoom(false);yield return DrawRoom(true);
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
                    yield return Click("Pet");
                    var gesture=app.UI.GetComponentInChildren<CareGestureInput>();int gestureId=gesture.GetInstanceID();careRewardCatId=gesture.CatId;gesture.RewardObserved+=ObserveCareReward;
                    Rect stage=HotelUI.ScreenBounds((RectTransform)gesture.transform);Vector2 catPoint=FindCatPoint(stage);
                    Check("cat is hittable inside care viewport",app.World.CareHit(catPoint),catPoint.ToString());
                    Vector3 carePosition=app.World.WorldCamera.transform.position;float careZoom=app.World.WorldCamera.orthographicSize;
                    // Isolated acceptance-profile fixture: keep rewards away from cap/cooldown.
                    ResetCareRewardFixture();int bond=CareBond();
                    yield return TouchGesture(catPoint,catPoint,.025f);
                    Check("mere cat tap grants no friendship",CareBond()==bond);
                    catPoint=FindCatPoint(stage);double elapsed=app.Model.State.elapsed;
                    yield return TouchGesture(catPoint,catPoint,1.05f);
                    CheckCareGain("deliberate pet hold grants exact friendship","pet",bond);
                    Check("hotel simulation continues during care",app.Model.State.elapsed>elapsed+.5);
                    int rewarded=CareBond();yield return Frames(8);
                    Check("completed pet gesture grants only once",CareBond()==rewarded);

                    if(cases.Count==1)
                    {
                    yield return Click("Brush");ResetCareRewardFixture();bond=CareBond();
                    catPoint=FindCatPoint(stage);yield return MouseGesture(catPoint,catPoint,.8f);
                    Check("stationary brush grants no friendship",CareBond()==bond);
                    yield return BrushCoat(stage);
                    CheckCareGain("deliberate coat strokes grant exact friendship","brush",bond);

                    yield return Click("Feather");ResetCareRewardFixture();bond=CareBond();
                    catPoint=FindCatPoint(stage);yield return MouseGesture(catPoint,catPoint,.025f);
                    yield return new WaitForSecondsRealtime(.8f);
                    Check("feather tap grants no friendship",CareBond()==bond);
                    yield return FeatherEngagement(stage,bond);
                    CheckCareGain("cat catching deliberately dragged feather grants exact friendship","wand",bond);

                    yield return Click("Yarn");ResetCareRewardFixture();bond=CareBond();
                    float unit=app.UI.GetComponent<Canvas>().scaleFactor;
                    Vector2 yarnFrom=stage.center-Vector2.right*30*unit,yarnTo=stage.center+Vector2.right*30*unit;
                    yield return TouchGesture(yarnFrom,yarnTo,1f);
                    yield return new WaitForSecondsRealtime(1f);
                    Check("slow yarn drag grants no friendship",CareBond()==bond);
                    yield return ValidYarnFlick(stage);Check("fast yarn release recognizes deliberate flick",gesture.HasRecognizedGesture);yield return WaitForCareReward(bond,8f);
                    CheckCareGain("deliberate yarn flick and chase grant exact friendship","yarn",bond);

                    yield return Click("Cushion");ResetCareRewardFixture();bond=CareBond();
                    yield return TouchGesture(stage.center,stage.center,.025f);
                    Check("cushion placement alone grants no friendship",CareBond()==bond);
                    yield return WaitForCareReward(bond,8f);
                    CheckCareGain("walking to cushion and settling grants exact friendship","cushion",bond);
                    yield return Click("Box");ResetCareRewardFixture();bond=CareBond();
                    yield return MouseGesture(stage.center,stage.center,.025f);
                    Check("box placement alone grants no friendship",CareBond()==bond);
                    yield return WaitForCareReward(bond,8f);
                    CheckCareGain("walking to box and investigating grants exact friendship","box",bond);
                    yield return Click("Box");ResetCareRewardFixture();bond=CareBond();
                    yield return MouseGesture(stage.center,stage.center,.025f);yield return Click("Pet");
                    yield return new WaitForSecondsRealtime(1.2f);
                    Check("tool change cancels pending placement reward",CareBond()==bond);
                    ResetCareRewardFixture();bond=CareBond();yield return SecondaryPointerIgnored(stage);
                    Check("second pointer cannot grant care reward",CareBond()==bond);
                    yield return Click("Brush");ResetCareRewardFixture();bond=CareBond();
                    Vector2 outside=FindOffCatPoint(stage);yield return MouseGesture(outside,outside+Vector2.right*4,.9f);
                    Check("off-cat brush input grants no friendship",CareBond()==bond);
                    // Rebuild through the normal layout entry after changing the isolated fixture setting.
                    app.Model.State.settings.assistedCare=true;app.UI.ConfigureAcceptanceLayout(safe,scale);yield return Frames(3);
                    gesture=app.UI.GetComponentInChildren<CareGestureInput>();gesture.RewardObserved+=ObserveCareReward;
                    ResetCareRewardFixture();bond=CareBond();yield return Click("Help me use this tool");
                    Check("assisted action waits for cat response",CareBond()==bond);
                    yield return WaitForCareReward(bond,4f);CheckCareGain("assisted brush grants exact friendship after response","brush",bond);
                    app.Model.State.settings.assistedCare=false;app.UI.ConfigureAcceptanceLayout(safe,scale);yield return Frames(3);
                    gesture=app.UI.GetComponentInChildren<CareGestureInput>();gesture.RewardObserved+=ObserveCareReward;gestureId=gesture.GetInstanceID();
                    }

                    Check("care gesture input remains active",app.UI.GetComponentInChildren<CareGestureInput>().GetInstanceID()==gestureId);
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
                var scroll=app.UI.GetComponentsInChildren<ScrollRect>().FirstOrDefault(s=>(ancestor=="Catalogue categories"?s.horizontal:s.vertical)&&s.isActiveAndEnabled);
                if(!scroll)break;
                var viewport=HotelUI.ScreenBounds(scroll.viewport);
                if(scroll.horizontal)
                {
                    float left=Mathf.Lerp(viewport.xMin,viewport.xMax,.25f),right=Mathf.Lerp(viewport.xMin,viewport.xMax,.75f);
                    yield return MouseGesture(new Vector2(left,viewport.center.y),new Vector2(right,viewport.center.y),.18f);continue;
                }
                float low=Mathf.Lerp(viewport.yMin,viewport.yMax,.25f),high=Mathf.Lerp(viewport.yMin,viewport.yMax,.70f);
                float x=Mathf.Lerp(viewport.xMin,viewport.xMax,.5f);
                yield return MouseGesture(new Vector2(x,step<24?low:high),new Vector2(x,step<24?high:low),.18f);
            }
            if(!button){Check("click "+(label??ancestor),false,"No visible raycastable control after real pointer-drag scrolling");yield break;}
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
        IEnumerator DrawRoom(bool withTouch)
        {
            int before=app.Model.Hotel().rooms.Count;
            yield return Click("Hotel","Catalogue categories");yield return Click("Draw","Bedroom");
            Check((withTouch?"touch":"mouse")+" bedroom draw opened",app.UI.IsPlacing);
            if(!FindRoomDraw(withTouch,out int x,out int z))
            {
                Check((withTouch?"touch":"mouse")+" found visible empty lawn",false,"No valid 4x3 lawn rectangle in the world viewport");
                yield return Click("Cancel");yield break;
            }
            Vector2 from=RoomDrawPoint(x,z,withTouch),to=RoomDrawPoint(x+3,z+2,withTouch);
            Check((withTouch?"touch":"mouse")+" draw start round trips",RoomDrawCell(from,withTouch)==new Vector2Int(x,z),RoomDrawCell(from,withTouch).ToString());
            Check((withTouch?"touch":"mouse")+" draw end round trips",RoomDrawCell(to,withTouch)==new Vector2Int(x+3,z+2),RoomDrawCell(to,withTouch).ToString());
            if(withTouch)yield return TouchGesture(from,to,.35f);else yield return MouseGesture(from,to,.35f);
            yield return Click("Confirm");
            var hotel=app.Model.Hotel();var room=hotel.rooms.Count==before+1?hotel.rooms[hotel.rooms.Count-1]:null;
            Check((withTouch?"touch":"mouse")+" draw adds one room",hotel.rooms.Count==before+1,"before="+before+", after="+hotel.rooms.Count);
            Check((withTouch?"touch":"mouse")+" drawn room is interior",room!=null&&HotelModel.Interior(hotel,room),room==null?"room missing":room.id);
            var undone=app.Model.Undo();yield return Frames(3);
            Check((withTouch?"touch":"mouse")+" draw undo",undone.success&&app.Model.Hotel().rooms.Count==before,undone.message+", rooms="+app.Model.Hotel().rooms.Count);
        }
        bool FindRoomDraw(bool withTouch,out int foundX,out int foundZ)
        {
            foundX=foundZ=0;var hotel=app.Model.Hotel();var floor=HotelModel.Floor(hotel,0);var map=app.Model.Map();var rect=map["base"];
            int left=(int)rect[0],top=(int)rect[1],right=left+(int)rect[2]-4,bottom=top+(int)rect[3]-3;
            float best=float.MaxValue;bool found=false;Rect viewport=app.UI.AvailableWorldRect;
            for(int z=top;z<=bottom;z++)for(int x=left;x<=right;x++)
            {
                bool empty=true;
                for(int dz=0;dz<3&&empty;dz++)for(int dx=0;dx<4;dx++)if(floor!=null&&floor.cells.ContainsKey((x+dx)+","+(z+dz))){empty=false;break;}
                if(!empty)continue;
                var draft=app.Model.RoomDraft(x,z,x+3,z+2,"regular");if(!app.Model.Quote("draw_room",draft).success)continue;
                Vector2 a=RoomDrawPoint(x,z,withTouch),b=RoomDrawPoint(x+3,z+2,withTouch);if(!viewport.Contains(a)||!viewport.Contains(b))continue;
                float score=((a+b)*.5f-viewport.center).sqrMagnitude;if(score>=best)continue;
                best=score;foundX=x;foundZ=z;found=true;
            }
            return found;
        }
        Vector2 RoomDrawPoint(int x,int z,bool withTouch)
        {
            Vector2 point=app.World.WorldCamera.WorldToScreenPoint(new Vector3((x+.5f)*VoxelWorld.Unit,.18f,-(z+.5f)*VoxelWorld.Unit));
            if(withTouch)point.y-=Screen.dpi>0?Screen.dpi*.35f:90f;
            return point;
        }
        Vector2Int RoomDrawCell(Vector2 point,bool withTouch)
        {
            if(withTouch)point.y+=Screen.dpi>0?Screen.dpi*.35f:90f;
            Vector3 ground=app.World.ScreenToGround(point);return new Vector2Int(Mathf.FloorToInt(ground.x),Mathf.FloorToInt(ground.z));
        }
        // Count only observed, persisted care transactions for the selected cat; ambient bonds cannot satisfy a check.
        int CareBond()=>careRewardCount;
        void ObserveCareReward(string tool,int gain,bool timestampChanged){if(timestampChanged){careRewardCount++;careRewardGain=gain;careRewardTool=tool;}}
        void CheckCareGain(string name,string tool,int before){var cat=app.Model.State.cats.First(c=>c.id==careRewardCatId);int expected=cat.favoriteAction==tool?6:3;Check(name,careRewardCount==before+1&&careRewardTool==tool&&careRewardGain==expected,"care transactions="+(careRewardCount-before)+", gain="+careRewardGain+", expected="+expected);}
        Vector2 FindOffCatPoint(Rect stage){for(int x=1;x<10;x++)for(int y=1;y<10;y++){var p=new Vector2(Mathf.Lerp(stage.xMin,stage.xMax,x/10f),Mathf.Lerp(stage.yMin,stage.yMax,y/10f));if(!app.World.CareHit(p)&&!app.World.CareHit(p+Vector2.right*4))return p;}return stage.min+Vector2.one*5;}
        IEnumerator SecondaryPointerIgnored(Rect stage)
        {
            var first=FindOffCatPoint(stage);var second=FindCatPoint(stage);
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=1,phase=UnityEngine.InputSystem.TouchPhase.Began,position=first,pressure=1});yield return Frames(2);
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=2,phase=UnityEngine.InputSystem.TouchPhase.Began,position=second,pressure=1});yield return new WaitForSecondsRealtime(.8f);
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=2,phase=UnityEngine.InputSystem.TouchPhase.Ended,position=second});yield return Frames(2);
            InputSystem.QueueStateEvent(touch,new TouchState{touchId=1,phase=UnityEngine.InputSystem.TouchPhase.Ended,position=first});yield return Frames(3);
        }
        IEnumerator ValidYarnFlick(Rect stage)
        {
            float unit=app.UI.GetComponent<Canvas>().scaleFactor;Vector2 end=FindCatPoint(stage);
            float direction=stage.xMax-end.x>=end.x-stage.xMin?1:-1;
            Vector2 start=end+Vector2.right*(65*unit*direction);start.x=Mathf.Clamp(start.x,stage.xMin+4,stage.xMax-4);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=start});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=start,buttons=1});yield return Frames(2);
            // Establish movement before acceleration so initial pointer-down latency is not part of flick velocity.
            InputSystem.QueueStateEvent(mouse,new MouseState{position=Vector2.Lerp(start,end,.04f),buttons=1});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=end,buttons=1});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=end});yield return Frames(3);
        }
        void ResetCareRewardFixture(){var cat=app.Model.State.cats.First(c=>c.id==careRewardCatId);cat.bond=20;cat.lastCare=(float)app.Model.State.elapsed-20;}
        IEnumerator WaitForCareReward(int before,float seconds){float until=Time.unscaledTime+seconds;while(CareBond()==before&&Time.unscaledTime<until)yield return null;}
        Vector2 FindCatPoint(Rect stage)
        {
            Vector2 best=stage.center;int bestScore=-1;
            for(float y=stage.yMin+4;y<stage.yMax-3;y+=8)for(float x=stage.xMin+4;x<stage.xMax-3;x+=8)
            {
                var p=new Vector2(x,y);
                if(!app.World.CareHit(p))continue;
                int score=0;foreach(var offset in new[]{Vector2.left,Vector2.right,Vector2.up,Vector2.down})for(int r=3;r<=15;r+=3)if(app.World.CareHit(p+offset*r))score++;
                if(score>bestScore){best=p;bestScore=score;}
            }
            return best;
        }
        IEnumerator BrushCoat(Rect stage)
        {
            Vector2 center=FindCatPoint(stage);float unit=app.UI.GetComponent<Canvas>().scaleFactor;
            float radius=8*unit;while(radius>2&&(!app.World.CareHit(center+Vector2.left*radius)||!app.World.CareHit(center+Vector2.right*radius)))radius-=1;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=center});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=center,buttons=1});yield return Frames(2);
            float elapsed=0;Vector2 point=center;
            while(elapsed<1.4f)
            {
                elapsed+=Time.unscaledDeltaTime;point=center+Vector2.right*(Mathf.Sin(elapsed*24)*radius);
                InputSystem.QueueStateEvent(mouse,new MouseState{position=point,buttons=1});yield return null;
            }
            InputSystem.QueueStateEvent(mouse,new MouseState{position=point});yield return Frames(3);
        }
        IEnumerator FeatherEngagement(Rect stage,int before)
        {
            float unit=app.UI.GetComponent<Canvas>().scaleFactor;var center=FindCatPoint(stage);
            // Finish near the cat, then keep the feather still for a visible approach/catch.
            float direction=stage.xMax-center.x>=center.x-stage.xMin?1:-1;
            Vector2 from=center+Vector2.right*(48*unit*direction);from.x=Mathf.Clamp(from.x,stage.xMin+4,stage.xMax-4);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=from});yield return null;
            InputSystem.QueueStateEvent(mouse,new MouseState{position=from,buttons=1});yield return Frames(2);
            Check("feather pointer down grants no friendship",CareBond()==before);
            float elapsed=0;while(elapsed<.25f){elapsed+=Time.unscaledDeltaTime;InputSystem.QueueStateEvent(mouse,new MouseState{position=Vector2.Lerp(from,center,Mathf.Clamp01(elapsed/.25f)),buttons=1});yield return null;}
            Check("feather drag awaits the cat response",CareBond()==before);
            yield return WaitForCareReward(before,5f);
            InputSystem.QueueStateEvent(mouse,new MouseState{position=center});yield return Frames(3);
        }
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
        void Write(string status){File.WriteAllText(Path.Combine(output,"input-acceptance.json"),new JObject{{"status",status},{"cases",cases},{"failedChecks",failures},{"runtimeErrors",errors},{"inputMethod","queued MouseState and TouchState through InputSystemUIInputModule"},{"layoutSetup","Viewport, simulated safe insets and text scale configured before each case; opt-in care fixtures reset bonds to 20 and clear cooldown before gesture assertions"}}.ToString(Formatting.Indented));}
        void Finish(string status){if(finished)return;finished=true;Write(status);Application.logMessageReceived-=OnLog;if(mouse!=null)InputSystem.RemoveDevice(mouse);if(touch!=null)InputSystem.RemoveDevice(touch);if(backgroundBehaviorChanged)InputSystem.settings.backgroundBehavior=priorBackgroundBehavior;if(app)app.ExitWithoutSaving();else Application.Quit();}
        void Update(){if(!finished&&deadline>0&&Time.realtimeSinceStartup>deadline)Finish("timeout");}
    }
}
