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
            if(levels.Length<2)return null;
            currentFloor=app.World.ViewFloor;
            int index=System.Array.IndexOf(levels,currentFloor);
            if(index<0){index=System.Array.IndexOf(levels,0);currentFloor=levels[index<0?0:index];}
            var row=Row(parent,40);
            int below=index>0?levels[index-1]:currentFloor,above=index<levels.Length-1?levels[index+1]:currentFloor;
            Button(row,"▼",()=>SwitchFloor(below),index>0?Mint:Cream,14);
            Button(row,FloorName(currentFloor),()=>{},Gold,13);
            Button(row,"▲",()=>SwitchFloor(above),index<levels.Length-1?Mint:Cream,14);
            return row;
        }
        void SwitchFloor(int level){if(level==currentFloor)return;CancelPlacement(false);app.World.StopWatching();currentFloor=level;app.World.SetViewFloor(level);Rebuild();}
        bool ShellDrawing(string action){return action=="paint_floor"||action=="erase_floor"||action=="draw_room";}
        void ShellCatalogue(RectTransform content)
        {
            if(category!="Hotel")return;
            currentFloor=app.World.ViewFloor;
            string lockCopy=app.Model.FloorLock(currentFloor);
            if(lockCopy!=null){Info(content,"FLOOR LOCKED",lockCopy);return;}
            Card(content,"Grow the hotel","Drag across land · "+ShellGrid.CellPrice.ToString("N0")+" coins a tile · land for sale is bought as you go","Grow",()=>BeginCommand("paint_floor",new JObject{{"floor",currentFloor},{"cells",new JArray()},{"buy",true}},"Grow the hotel"),Mint);
            foreach(var kind in new[]{"regular","suite","shared"})
            {
                string name=kind=="regular"?"Bedroom":kind=="suite"?"Suite":"Lounge";string chosen=kind;
                Card(content,name,"Drag a rectangle · inside the hotel or on open land","Draw",()=>BeginCommand("draw_room",new JObject{{"kind",chosen},{"floor",currentFloor},{"name",name}},name),Gold);
            }
            Card(content,"Stairs",app.Model.FloorLock(currentFloor+1)??"Opens the floor above","Draw",()=>BeginCommand("draw_room",new JObject{{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",currentFloor}},"Stairs"),Gold);
            if(currentFloor==0&&app.Model.FloorLock(-1)==null)Card(content,"Stairs down","Opens the basement","Draw",()=>BeginCommand("draw_room",new JObject{{"kind","stairs"},{"w",2},{"h",3},{"rotation",0},{"floor",-1}},"Stairs down"),Gold);
            string themed=currentFloor==1?"sunroom":currentFloor==2?"garden":currentFloor==-1?"spa":null;
            if(themed!=null){string title=themed=="sunroom"?"Sunroom":themed=="garden"?"Garden":"Spa";string subtitle=themed=="sunroom"?"Sunny naps · +15 coins/min when furnished":themed=="garden"?"Open-air plants · +20 coins/min":"Warm soaks · +25 coins/min";Card(content,title,subtitle,"Draw",()=>BeginCommand("draw_room",new JObject{{"kind",themed},{"floor",currentFloor},{"name",title}},title),Gold);}
            Card(content,"Doors & windows","Tap a wall: wall → door → window → archway","Edit",()=>BeginCommand("set_edge",new JObject{{"floor",currentFloor},{"kind","door"},{"edges",new JArray()}},"Doors & windows"),Mint);
            Card(content,"Remove floor","Drag across empty hotel floor · refunds the tiles","Erase",()=>BeginCommand("erase_floor",new JObject{{"floor",currentFloor},{"cells",new JArray()}},"Remove floor"),Coral);
        }
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
