using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
    public sealed partial class HotelUI
    {
        Vector2Int? roomAnchor;
        int currentFloor;
        static string FloorName(int level){return level==-1?"Basement":level==0?"Ground":level==1?"Upstairs":"Rooftop";}
        // The Hotel tab's floor stack: every built floor, top floor first, the one in view highlighted. It sits on the world's
        // right edge so going up or down (to see inside a lower floor) is always one tap.
        RectTransform FloorStack()
        {
            var levels=app.Model.Hotel().floors.Where(f=>f.level==0||f.cells.Count>0).Select(f=>f.level).Union(new[]{0}).OrderByDescending(level=>level).ToArray();
            currentFloor=VoxelWorld.ShownFloor(app.Model,app.World.ViewFloor);if(currentFloor!=app.World.ViewFloor)app.World.SetViewFloor(currentFloor);
            if(levels.Length<2)return null;
            var stack=Panel("Floor stack",safe,CardTone);
            float top=wideLayout?-100:-136,h=26+levels.Length*50;
            Pin(stack,Vector2.one,Vector2.one,Vector2.one,new Vector2(-10-108,top-h),new Vector2(-10,top));
            var title=Text(stack,"Floors",12,InkSoft,true);title.alignment=TMPro.TextAlignmentOptions.Center;Pin(title.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(.5f,1),new Vector2(4,-24),new Vector2(-4,-4));
            var list=Rect("Levels",stack);Stretch(list,6,26,6,6);var v=list.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();v.spacing=4;v.childControlWidth=v.childControlHeight=true;v.childForceExpandWidth=v.childForceExpandHeight=true;
            foreach(int level in levels){int chosen=level;var b=Button(list,(level>currentFloor?"▲ ":level<currentFloor?"▼ ":"")+FloorName(level),()=>SwitchFloor(chosen),level==currentFloor?Gold:Color.white,13);b.name=FloorName(level);}
            return stack;
        }
        void SwitchFloor(int level){if(level==currentFloor)return;CancelPlacement(false);app.World.StopWatching();currentFloor=level;app.World.SetViewFloor(level);Rebuild();}
        bool ShellDrawing(string action){return action=="paint_floor"||action=="erase_floor"||action=="draw_room"||action=="draw_wall";}
        bool ShellTarget(Vector3 point)
        {
            if(commandAction=="set_edge")
            {
                var floor=HotelModel.Floor(app.Model.Hotel(),currentFloor);string edge=ShellDraw.NearestEdge(point.x,point.z);
                if(floor==null||ShellGrid.WallAt(floor,edge)==null){ShowNotice("Tap a wall of the hotel.",true);return true;}
                var payload=new JObject{{"floor",currentFloor},{"kind",ShellDraw.NextKind(floor,edge)},{"edges",new JArray(edge)}};
                var result=app.Model.Execute("set_edge",payload);if(result.success)app.Audio?.PlayEffect("build");
                app.Report(result);Rebuild();ShowNotice(result.message+(result.success&&result.cost!=0?(result.cost>0?" · "+result.cost.ToString("N0")+" coins":" · "+(-result.cost).ToString("N0")+" coins refunded"):""),!result.success);
                return true;
            }
            if(commandAction=="draw_wall")
            {
                int gx=Mathf.RoundToInt(point.x),gz=Mathf.RoundToInt(point.z);if(roomAnchor==null)roomAnchor=new Vector2Int(gx,gz);
                commandPayload["from"]=new JArray(roomAnchor.Value.x,roomAnchor.Value.y);commandPayload["to"]=new JArray(gx,gz);
                hasTarget=true;PreviewCommand();return true;
            }
            if(commandAction=="claim_room"){commandPayload["x"]=Mathf.FloorToInt(point.x);commandPayload["y"]=Mathf.FloorToInt(point.z);hasTarget=true;PreviewCommand();return true;}
            if(!ShellDrawing(commandAction))return false;
            int cx=Mathf.FloorToInt(point.x),cz=Mathf.FloorToInt(point.z);
            if(commandAction=="draw_room")
            {
                if((string)commandPayload["kind"]=="stairs")
                {
                    commandPayload["x"]=cx;commandPayload["y"]=cz;hasTarget=true;PreviewCommand();return true;
                }
                if(roomAnchor==null)roomAnchor=new Vector2Int(cx,cz);
                var draft=app.Model.RoomDraft(roomAnchor.Value.x,roomAnchor.Value.y,cx,cz,(string)commandPayload["kind"]??"regular",currentFloor);
                draft["name"]=commandPayload["name"]??commandTitle;commandPayload=draft;
            }
            else
            {
                var cells=(JArray)commandPayload["cells"];var from=lastPathCell??new Vector2Int(cx,cz);
                foreach(var (x,z) in ShellDraw.Line(from.x,from.y,cx,cz))if(!cells.Any(c=>(int)c[0]==x&&(int)c[1]==z))cells.Add(new JArray(x,z));
                lastPathCell=new Vector2Int(cx,cz);
            }
            hasTarget=true;PreviewCommand();return true;
        }
        public void GroundDragEnded(){lastPathCell=null;roomAnchor=null;}
    }
}
