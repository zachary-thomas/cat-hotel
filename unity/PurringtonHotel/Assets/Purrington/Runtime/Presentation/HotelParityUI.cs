using System;

using System.Linq;

using Newtonsoft.Json.Linq;

using UnityEngine;

using TMPro;

namespace Purrington.Presentation

{

    public sealed partial class HotelUI

    {

        string commandAction="", commandTitle="", dialogTitle="", dialogCopy="";

        JObject commandPayload=new JObject();

        Action dialogConfirm;

        bool careDetails;

        TextMeshProUGUI careBond, careHint;

        CareGestureInput gestureInput;

        Vector2Int? lastPathCell;

        void Run(string action,JObject payload=null)

        {

            var result=app.Model.Execute(action,payload??new JObject()); if(result.success)app.Audio?.PlayEffect("spend"); app.Report(result); Rebuild(); ShowNotice(result.message,!result.success);

        }

        void BeginCommand(string action,JObject payload,string title)

        {

            CancelPlacement(false);lastPathCell=null; commandAction=action;commandPayload=(JObject)payload.DeepClone();commandTitle=title;placement="command";

            rotation=(int?)payload["rotation"]??0;hasTarget=action=="buy_plot"||action=="resize_room";

            app.World.SetPathPainting(action=="paint_path"||action=="erase_path");Rebuild();

            if(hasTarget)PreviewCommand();

        }

        void UpdateCommandTarget(Vector3 point)

        {

            target=new Vector3(Mathf.Round(point.x*2)/2,0,Mathf.Round(point.z*2)/2);

            if(commandAction=="paint_path"||commandAction=="erase_path")

            {

                int endX=Mathf.FloorToInt(point.x),endZ=Mathf.FloorToInt(point.z);var cells=(JArray)commandPayload["cells"];

                int x=lastPathCell?.x??endX,z=lastPathCell?.y??endZ,dx=Math.Abs(endX-x),dz=Math.Abs(endZ-z),sx=x<endX?1:-1,sz=z<endZ?1:-1,error=dx-dz;

                for(int n=0;n<1024;n++){if(!cells.Any(c=>(int)c[0]==x&&(int)c[1]==z))cells.Add(new JArray(x,z));if(x==endX&&z==endZ)break;int twice=2*error;if(twice>-dz){error-=dz;x+=sx;}if(twice<dx){error+=dx;z+=sz;}}

                lastPathCell=new Vector2Int(endX,endZ);

            }

            else {commandPayload["x"]=(commandAction.Contains("room")||commandAction=="place_template")?Mathf.Round(point.x):target.x;commandPayload["y"]=(commandAction.Contains("room")||commandAction=="place_template")?Mathf.Round(point.z):target.z;}

            hasTarget=true;PreviewCommand();

        }

        void PreviewCommand()

        {

            var quote=app.Model.Quote(commandAction,commandPayload);

            app.World.SetCommandPreview(commandAction,commandPayload,quote.success);

            ShowNotice((quote.success?"Confirm · "+quote.cost.ToString("N0")+" coins. ":"")+quote.message,!quote.success,false);

        }

        void PlaceCommand()

        {

            if(!hasTarget){ShowNotice("Tap the hotel to choose a position.",false);return;}

            var result=app.Model.Execute(commandAction,commandPayload);if(result.success){app.Audio?.PlayEffect("build");CancelPlacement(false);}

            app.Report(result);Rebuild();ShowNotice(result.message,!result.success);

        }

        public void GroundDragged(Vector3 point){if(commandAction=="paint_path"||commandAction=="erase_path")UpdateCommandTarget(point);}

        public void SelectRoom(string id){if(tab=="Build"&&!IsPlacing)EditRoom(id);}

        void BuildExtras(RectTransform content)

        {

            var row=Row(content,50);

            Button(row,"Fit hotel",()=>app.World.FitHotel(),Gold,13);

            if(selectedObject.Length>0)Button(row,"Focus selection",()=>app.World.FocusObject(selectedObject),Mint,13);

        }

        void RoomExtras(RectTransform content,string id,int width,int depth)

        {

            var row=Row(content,52);

            Button(row,"Focus",()=>app.World.FocusRoom(id),Mint,13);

            Button(row,"Copy",()=>BeginCommand("copy_room",new JObject{{"id",id},{"w",width},{"h",depth},{"rotation",0}},"Copy room and furniture"),Gold,13);

            var sizes=Row(content,52);

            foreach(var delta in new[]{-1,1})

            {

                int d=delta;

                Button(sizes,d<0?"Narrower":"Wider",()=>BeginCommand("resize_room",new JObject{{"id",id},{"w",Math.Max(2,width+d)},{"h",depth}},"Resize room"),Lilac,12);

                Button(sizes,d<0?"Shorter":"Deeper",()=>BeginCommand("resize_room",new JObject{{"id",id},{"w",width},{"h",Math.Max(2,depth+d)}},"Resize room"),Lilac,12);

            }

        }

        void ParityCatalogue(RectTransform content)

        {

            if(category=="All"||category=="Rooms")

                foreach(var kind in new[]{"regular","suite","cottage"})

                {

                    string name=kind=="regular"?"Guest room":kind=="suite"?"Grand suite":"Garden cottage";

                    var payload=new JObject{{"kind",kind=="cottage"?"regular":kind},{"w",4},{"h",kind=="suite"?5:kind=="cottage"?4:3},{"rotation",0},{"name",name}};

                    CatalogCard(content,name,"Rooms",app.Model.CatalogPrice("place_room",payload),()=>BeginCommand("place_room",payload,name),Gold,"room");

                }

            if(category=="Arrangements")foreach(var entry in app.Model.Content.Templates)

            {

                var payload=new JObject{{"template",(string)entry["id"]},{"rotation",0}};

                CatalogCard(content,(string)entry["name"],"Individually editable furnishings",app.Model.CatalogPrice("place_template",payload),()=>BeginCommand("place_template",payload,(string)entry["name"]),Gold,"room");

            }

            if(category=="Land")foreach(var plot in app.Model.Map()["plots"]??new JArray())

            {

                var p=(JObject)plot;Card(content,(string)p["name"],((int?)p["cost"]??0)+" coins","Select",()=>BeginCommand("buy_plot",new JObject{{"id",p["id"]}},(string)p["name"]),Mint);

            }

            if(category=="Paths")foreach(var style in new[]{"earth","gravel","brick","erase"})

            {

                string chosen=style;Card(content,style+" path","Tap or drag across cells, then confirm.","Paint",()=>BeginCommand(chosen=="erase"?"erase_path":"paint_path",new JObject{{"cells",new JArray()},{"style",chosen=="erase"?"earth":chosen}},chosen+" path"),Gold);

            }

        }

        void ParityLifePanel()

        {

            var mapName=(string)app.Model.Map()["name"];
            var content=Sheet("Hotel life","Life at "+mapName,.70f);var hotel=JObject.FromObject(app.Model.Hotel());
            int staying=app.Model.Actors.Count(a=>a.catId<1000);
            int arriving=app.Model.Actors.Count(a=>a.catId<1000&&!a.checkedIn);
            int capacity=app.Model.GuestCapacity();
            Info(content,"LIFE AT "+mapName.ToUpperInvariant(),
                "+"+Math.Round(app.Model.Rate()).ToString("N0")+" / min · "+Math.Floor(app.Model.State.coins).ToString("N0")+" coins
"+
                staying+" guests staying · "+capacity+" capacity · "+(arriving>0?arriving+" arriving":"reception ready")+"
"+
                (hotel["visits"]??0)+" visits · "+(hotel["happy"]??0)+" happy guests");

            Info(content,"HOTEL LEVEL "+(hotel["level"]??1),"Upgrade your services to grow your hotel. Every two service upgrades increase your hotel level.");

            Card(content,"Housekeeping",(hotel["cleaned"]??0)+" rooms cleaned",(bool?)hotel["maid"]==true?"Hired":"Hire",()=>Run("hire_housekeeper"),Mint);

            string[] services={"Rooms & housekeeping","Kitchen & milkshakes","Lounge & play","Reception & arrivals"};

            for(int i=0;i<4;i++){int index=i;var p=new JObject{{"service",i}};var q=app.Model.Quote("upgrade",p);Card(content,services[i],"Level "+(hotel["upgrades"]?[i]??0)+" · "+q.cost.ToString("N0")+" coins","Upgrade",()=>Run("upgrade",new JObject{{"service",index}}),Mint);}

            for(int i=0;i<3;i++){int index=i;var staff=app.Model.Content.Staff[i];var q=app.Model.Quote("train",new JObject{{"staff",i}});Card(content,(string)staff["name"]+" · "+(string)staff["job"],"Training "+(hotel["staff"]?[i]??0)+" · "+q.cost.ToString("N0")+" coins","Train",()=>Run("train",new JObject{{"staff",index}}),Gold);}

            foreach(var venue in app.Model.Venues()){var v=JObject.FromObject(venue);Info(content,(string)v["name"]??"Social space",(string)v["status"]??v.ToString(Newtonsoft.Json.Formatting.None));}

        }

        void ParityMapPanel()

        {

            var content=Sheet("Destinations","Four places to feel at home",.76f);Banner(content,"world-map",150);

            for(int i=0;i<app.Model.Content.Maps.Length;i++)

            {

                int index=i;var map=app.Model.Content.Maps[i];var gate=app.Model.CanTravel(i);

                Card(content,(string)map["name"],i==app.Model.State.currentHotel?"You are here":gate.message,i==app.Model.State.currentHotel?"Here":gate.cost>0?"Unlock":"Travel",()=>{var result=app.Model.Travel(index);app.Report(result);if(result.success){app.World.FitHotel();Navigate("Hotel");}else ShowNotice(result.message,true,false);},Mint);

                if(i>=2)Card(content,"Preview expansion","Test unlock · no real payment","Unlock",()=>{app.Report(app.Model.GrantEntitlement(index==2?"purrington.forest_lodge":"purrington.snowcap_spa"));Rebuild();},Gold);

            }

            Card(content,"Cat Club","Preview membership · no real payment","Try",()=>{app.Report(app.Model.GrantEntitlement("purrington.cat_club"));Rebuild();},Lilac);

        }

        void SettingsExtras(RectTransform content)

        {

            var s=JObject.FromObject(app.Model.State.settings);

            Card(content,"God mode","Unlock all maps, land and cats. Free building and upgrades.",(bool?)s["godMode"]==true?"On":"Off",()=>{app.Report(app.Model.SetGodMode(!((bool?)s["godMode"]??false)));Rebuild();},Gold);

            Card(content,"Exterior walls","Show the outside of your hotel",(bool?)s["exterior"]==true?"On":"Off",()=>{app.Report(app.Model.SetViewSettings(!((bool?)s["exterior"]??false),(bool?)s["evening"]??false));app.World.SetCutaway(!app.Model.State.settings.exterior);Rebuild();},Mint);

            Card(content,"Evening light","Warm lamps and night atmosphere",(bool?)s["evening"]==true?"On":"Off",()=>{app.Report(app.Model.SetViewSettings((bool?)s["exterior"]??false,!((bool?)s["evening"]??false)));app.World.SetEvening(app.Model.State.settings.evening);Rebuild();},Lilac);

            Card(content,"Offline earnings","Collect the coins earned while you were away.","Claim",()=>{app.Report(app.Model.ClaimOffline());Rebuild();},Gold);

            Card(content,"Save recovery","Retry writing your current hotel safely.","Retry",app.RetrySave,Mint);

            Card(content,"Start fresh","Replace this profile's progress with the complete starter hotel.","Reset",()=>Confirm("Start a fresh hotel?","Buildings, coins and unlocks will reset. Your other profiles stay safe.",()=>{var result=app.Model.Reset();app.Report(result);if(result.success){app.World.FitHotel();Navigate("Hotel");}}),Coral);

            Card(content,"Leave Purrington","Save your hotel before closing.","Exit",app.RequestExit,Lilac);

        }

        public void Confirm(string title,string copy,Action action){gestureInput?.Suspend();dialogTitle=title;dialogCopy=copy;dialogConfirm=action;Rebuild();}

        public void ExitFailed(){Confirm("Couldn't save before exit","Retry saving, or keep your hotel open. You can also exit without saving the latest changes.",app.RequestExit);}

        void DialogPanel()

        {

            var shade=Panel("Modal backdrop",safe,new Color(0,0,0,.65f));Stretch(shade);

            var panel=Panel("Confirmation",shade,Cream);Pin(panel,new Vector2(.5f,.5f),new Vector2(.5f,.5f),new Vector2(.5f,.5f),new Vector2(-170,-220),new Vector2(170,220));

            var column=Vertical(panel,10,16);Info(column,dialogTitle,dialogCopy);

            Height(Button(column,"Confirm",()=>{var action=dialogConfirm;dialogTitle="";Rebuild();action?.Invoke();},Coral,15),55);

            Height(Button(column,"Keep my hotel open",()=>{dialogTitle="";Rebuild();},Mint,15),55);

            if(dialogTitle.Contains("exit"))Height(Button(column,"Exit without saving",app.ExitWithoutSaving,Lilac,14),55);

        }

        void GestureCarePanel()

        {

            var cat=app.Model.State.cats.First(c=>c.id==careCat);

            var bondPanel=Panel("Care friendship",safe,Cream);
            Pin(bondPanel,new Vector2(0,1),Vector2.one,Vector2.one,new Vector2(12,-146),new Vector2(-12,-94));
            careBond=Text(bondPanel,cat.name+" · friendship "+cat.bond+" / 100",17,Ink,true);Stretch(careBond.rectTransform,12,4,12,4);

            var surface=Rect("Care gesture surface",safe);Pin(surface,Vector2.zero,Vector2.one,Vector2.zero,new Vector2(10,250),new Vector2(-10,-148));

            surface.gameObject.AddComponent<UnityEngine.UI.Image>().color=new Color(1,1,1,.001f);

            gestureInput=surface.gameObject.AddComponent<CareGestureInput>();gestureInput.Initialize(app,careCat,careTool,OnCareAction);

            var tray=Panel("Care tools",safe,Cream);Pin(tray,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,10),new Vector2(-10,244));

            var column=Vertical(tray,5,8);careHint=Text(column,CareGestureInput.Help(careTool),13,Ink);Height(careHint.rectTransform,40);

            string[] tools={"pet","brush","wand","yarn","cushion","box"};

            var choices=new System.Collections.Generic.Dictionary<string,UnityEngine.UI.Image>();

            for(int r=0;r<2;r++){var row=Row(column,48);for(int c=0;c<3;c++){string tool=tools[r*3+c];var button=Button(row,tool=="wand"?"Feather":char.ToUpper(tool[0])+tool.Substring(1),()=>{careTool=tool;gestureInput.SetTool(tool);careHint.text=CareGestureInput.Help(tool);foreach(var entry in choices)entry.Value.color=entry.Key==tool?Gold:Lilac;},careTool==tool?Gold:Lilac,13);choices[tool]=button.GetComponent<UnityEngine.UI.Image>();}}

            var footer=Row(column,50);Button(footer,"Use tool",()=>gestureInput.UseSelectedTool(),Mint,13);Button(footer,"About & friends",()=>{careDetails=true;Rebuild();},Gold,13);

            if(careDetails)

            {

                gestureInput.Suspend();var detail=Sheet("Cat details","About & friends",.8f);Info(detail,cat.name,(string)app.Model.Content.Cats[careCat]["traits"]+"\nFavorite: "+cat.favoriteAction+" · loves "+cat.preference+"\nAn open lounge and 10 friendship with both cats makes a playdate possible.");

                Height(Button(detail,"Back to play",()=>{careDetails=false;Rebuild();},Mint,14),52);

                foreach(var other in app.Model.State.cats.Where(c=>c.known&&c.id!=careCat)){int id=other.id;Card(detail,other.name,"Friendship "+other.bond,"Invite",()=>Run("playdate",new JObject{{"cat",careCat},{"other",id}}),Coral);}

            }

        }

        void OnCareAction(string tool)

        {

            var result=app.Model.Care(careCat,tool);if(!result.success||result.progressChanged)app.Report(result);

            var cat=app.Model.State.cats.First(c=>c.id==careCat);if(careBond)careBond.text=cat.name+" · friendship "+cat.bond+" / 100";

            if(result.success&&result.progressChanged)app.Audio?.PlayEffect(tool=="pet"||tool=="brush"?"purr":"toy");

        }

    }

}
