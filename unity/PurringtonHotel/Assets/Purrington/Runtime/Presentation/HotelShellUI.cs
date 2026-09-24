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
        RectTransform FloorChip(Transform parent)
        {
            var levels=app.Model.Hotel().floors.Select(f=>f.level).OrderBy(level=>level).ToArray();
            currentFloor=app.World.ViewFloor;
            if(levels.Length==0)return null;
            int index=System.Array.IndexOf(levels,currentFloor);
            if(index<0){index=System.Array.IndexOf(levels,0);if(index<0)index=0;currentFloor=levels[index];app.World.SetViewFloor(currentFloor);}
            if(levels.Length<2)return null;
            var row=Row(parent,40);
            int below=index>0?levels[index-1]:currentFloor,above=index<levels.Length-1?levels[index+1]:currentFloor;
            Button(row,"▼",()=>SwitchFloor(below),index>0?Mint:Cream,14);
            Button(row,FloorName(currentFloor),()=>{},Gold,13);
            Button(row,"▲",()=>SwitchFloor(above),index<levels.Length-1?Mint:Cream,14);
            return row;
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
