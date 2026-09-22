using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
    public sealed partial class HotelUI
    {
        Vector2Int? roomAnchor;
        bool ShellDrawing(string action){return action=="paint_floor"||action=="erase_floor"||action=="draw_room";}
        void ShellCatalogue(RectTransform content)
        {
            if(category!="Hotel")return;
            Card(content,"Grow the hotel","Drag across land · "+ShellGrid.CellPrice.ToString("N0")+" coins a tile · land for sale is bought as you go","Grow",()=>BeginCommand("paint_floor",new JObject{{"floor",0},{"cells",new JArray()},{"buy",true}},"Grow the hotel"),Mint);
            foreach(var kind in new[]{"regular","suite","shared"})
            {
                string name=kind=="regular"?"Bedroom":kind=="suite"?"Suite":"Lounge";string chosen=kind;
                Card(content,name,"Drag a rectangle · inside the hotel or on open land","Draw",()=>BeginCommand("draw_room",new JObject{{"kind",chosen},{"floor",0},{"name",name}},name),Gold);
            }
            Card(content,"Doors & windows","Tap a wall: wall → door → window → archway","Edit",()=>BeginCommand("set_edge",new JObject{{"floor",0},{"kind","door"},{"edges",new JArray()}},"Doors & windows"),Mint);
            Card(content,"Remove floor","Drag across empty hotel floor · refunds the tiles","Erase",()=>BeginCommand("erase_floor",new JObject{{"floor",0},{"cells",new JArray()}},"Remove floor"),Coral);
        }
        bool ShellTarget(Vector3 point)
        {
            if(commandAction=="set_edge")
            {
                var floor=HotelModel.Floor(app.Model.Hotel(),0);string edge=ShellDraw.NearestEdge(point.x,point.z);
                if(floor==null||ShellGrid.WallAt(floor,edge)==null){ShowNotice("Tap a wall of the hotel.",true);return true;}
                var payload=new JObject{{"floor",0},{"kind",ShellDraw.NextKind(floor,edge)},{"edges",new JArray(edge)}};
                var result=app.Model.Execute("set_edge",payload);if(result.success)app.Audio?.PlayEffect("build");
                app.Report(result);Rebuild();ShowNotice(result.message+(result.success&&result.cost>0?" · "+result.cost.ToString("N0")+" coins":""),!result.success);
                return true;
            }
            if(!ShellDrawing(commandAction))return false;
            int cx=Mathf.FloorToInt(point.x),cz=Mathf.FloorToInt(point.z);
            if(commandAction=="draw_room")
            {
                if(roomAnchor==null)roomAnchor=new Vector2Int(cx,cz);
                var draft=app.Model.RoomDraft(roomAnchor.Value.x,roomAnchor.Value.y,cx,cz,(string)commandPayload["kind"]??"regular");
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
