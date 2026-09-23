using System;

using System.Collections.Generic;

using System.Linq;

using Purrington.Domain;

using TMPro;

using UnityEngine;

using UnityEngine.EventSystems;

using UnityEngine.InputSystem;

namespace Purrington.Presentation

{

    // All measurements are logical phone units, including the minimum hit targets.

    // Rebuild only on navigation/layout changes; income updates only the wallet label.

    public sealed partial class HotelUI : MonoBehaviour

    {

        static readonly Color Ink = ConceptTheme.Ink, Cream = ConceptTheme.Cream, Mint = ConceptTheme.Sage, Coral = ConceptTheme.Clay, Gold = ConceptTheme.Honey, Lilac = Hex("E6DFCE");

        HotelApp app;

        Canvas canvas;

        RectTransform safe, sheet, dock;

        TMP_FontAsset body, heading;

        TextMeshProUGUI wallet, walletRate, toast;

        string tab = "Hotel", category = "All", placement = "", selectedObject = "", careTool = "pet";

        int rotation, careCat = -1;

        Vector3 target;

        bool hasTarget, settings, compactObjective=true, saveError;

        Vector2 lastSize;

        Rect lastSafe;

        bool wideLayout,buildToolsExpanded;

        string persistentSaveError="";

        float textScale = 1, noticeUntil;

        Sprite rounded;

        UnityEngine.UI.ScrollRect activeScroll;

        UnityEngine.UI.ScrollRect categoryScroll;

        RectTransform selectedCategoryChip;

        string scrollKey = "", movingObject = "", retrievingObject = "", movingRoom = "", selectedRoom = "";

        readonly Dictionary<string,float> scrollPositions = new Dictionary<string,float>();

        readonly Dictionary<string, Sprite> illustrations = new Dictionary<string, Sprite>();

        public string ActiveTab => tab;

        public bool IsPlacing => placement.Length > 0;

        public bool IsInCare => careCat >= 0;
        Rect? acceptanceSafeArea;
        public Rect AvailableWorldRect { get; private set; }
        Rect EffectiveSafeArea => acceptanceSafeArea ?? Screen.safeArea;
        public void ConfigureAcceptanceLayout(Rect area,float scale)
        {
            acceptanceSafeArea=area;
            var s=app.Model.State.settings;
            app.Model.SetSettings(scale,s.motion,s.music,s.sound);
            Rebuild();
        }

        public void Initialize(HotelApp value)

        {

            app = value;

            body = Resources.Load<TMP_FontAsset>("Fonts/Nunito SDF");

            heading = Resources.Load<TMP_FontAsset>("Fonts/Fredoka SDF");

            rounded = RoundedSprite();

            canvas = gameObject.AddComponent<Canvas>();

            canvas.renderMode = RenderMode.ScreenSpaceOverlay;

            canvas.sortingOrder = 20;

            gameObject.AddComponent<UnityEngine.UI.GraphicRaycaster>();

            var scaler = gameObject.AddComponent<UnityEngine.UI.CanvasScaler>();

            scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ConstantPixelSize;

            app.Model.Changed += RefreshValues;

            Rebuild();

        }

        void Update()

        {

            if (lastSize != new Vector2(Screen.width,Screen.height) || lastSafe != EffectiveSafeArea) Rebuild();
            if (toast != null && !saveError && Time.unscaledTime > noticeUntil) toast.transform.parent.gameObject.SetActive(false);

            if (Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame) Back();

            if (Keyboard.current != null && Keyboard.current.rKey.wasPressedThisFrame && IsPlacing) Rotate();

            if(!(Mouse.current?.leftButton.isPressed??false)&&!(Touchscreen.current?.primaryTouch.press.isPressed??false))lastPathCell=null;

            RefreshValues();

        }

        void OnDestroy() { if (app != null && app.Model != null) app.Model.Changed -= RefreshValues; }

        void RefreshValues()

        {

            RefreshMarketStatus();
            if (wallet == null) return;
            double rate = app.Model.Rate();
            wallet.text = "<b>" + Math.Floor(app.Model.State.coins).ToString("N0") + "</b>";
            if (walletRate != null) walletRate.text = "<color=#17612F>+" + Math.Round(rate).ToString("N0") + " / min</color>";
            else wallet.text += " · +" + Math.Round(rate).ToString("N0") + " / min";

        }

        public void Navigate(string destination)

        {

            bool returningFromTown=app.World.IsTownMode;
            if(returningFromTown){managerEditing=false;app.World.ExitTownMode();}
            if (careCat >= 0) { CloseWardrobe(); app.World.SetCareMode(careCat,false); }

            careCat = -1; settings=false; tab=destination; CancelPlacement(false); Rebuild();
            if (destination == "Hotel" && !returningFromTown) app.World.FitHotel();

        }

        public void OpenSettings()

        {

            if(careCat>=0){CloseWardrobe();app.World.SetCareMode(careCat,false);}

            careCat=-1;CancelPlacement(false);settings=true;Rebuild();

        }

        public void Back()

        {

            if(tab=="Town"&&!settings){if(BackFromStore())return;if(managerEditing){managerEditing=false;app.World.ClearManagerPreview();Rebuild();}else CloseTown();return;}
            if (IsPlacing) { CancelPlacement(); return; }

            if (careCat>=0) { if(careDetails){careDetails=false;Rebuild();}else if(wardrobeOpen){CloseWardrobe();Rebuild();}else CloseCare(); return; }

            if (settings) {settings=false; Rebuild(); return;}

            Navigate("Hotel");

        }

        public void OpenCare(int id)

        {

            if (IsPlacing || app.World.IsTownMode) return;

            CloseWardrobe(); careCat=id; careTool="pet"; careDetails=false; settings=false;

            app.World.SetCareMode(id,true); Rebuild();

        }

        void CloseCare() { gestureInput?.Suspend(); CloseWardrobe(); app.World.SetCareMode(careCat,false);careCat=-1;careDetails=false;Rebuild(); }

        public void SelectObject(string id)

        {

            if (tab!="Build" || IsPlacing) return;

            selectedObject=id;selectedRoom="";if(activeScroll!=null)activeScroll.verticalNormalizedPosition=1; Rebuild();

        }

        void EditRoom(string id){selectedRoom=id;selectedObject="";if(activeScroll!=null)activeScroll.verticalNormalizedPosition=1;Rebuild();}

        public void GroundClicked(Vector3 point)

        {

            if (careCat>=0) return;

            if (!IsPlacing) return;

            if (commandAction.Length > 0) { UpdateCommandTarget(point); return; }

            target = new Vector3(Mathf.Round(point.x*2)/2,0,Mathf.Round(point.z*2)/2);

            if (placement=="room") target = new Vector3(Mathf.Round(point.x),0,Mathf.Round(point.z));

            hasTarget=true; Preview();

        }

        void BeginPlace(string id) { placement=id;rotation=0;hasTarget=false;selectedObject="";Rebuild(); }

        void BeginMove(string id)

        {

            var item=app.Model.State.objects.FirstOrDefault(x=>x.id==id);

            if(item==null)return;

            movingObject=id;placement=item.itemId;rotation=item.rotation;hasTarget=false;Rebuild();

        }

        void BeginRetrieve(string id)

        {

            var item=app.Model.State.storage.FirstOrDefault(x=>x.id==id);

            if(item==null)return;

            retrievingObject=id;placement=item.itemId;rotation=item.rotation;hasTarget=false;Rebuild();

        }

        void BeginMoveRoom(string id,bool rotate=false)

        {

            var room=app.Model.State.rooms.FirstOrDefault(x=>x.id==id);

            if(room==null)return;

            movingRoom=id;placement="room";rotation=(room.rotation+(rotate?1:0))%4;

            target=new Vector3(room.x,0,room.z);hasTarget=true;Rebuild();Preview();

        }

        void Preview()

        {

            if(commandAction.Length>0){PreviewCommand();return;}

            var result=movingRoom.Length>0 ? app.Model.PreviewMoveRoom(movingRoom,(int)target.x,(int)target.z,rotation) : retrievingObject.Length>0 ? app.Model.PreviewRetrieveObject(retrievingObject,target.x,target.z,rotation) : movingObject.Length>0 ? app.Model.PreviewMoveObject(movingObject,target.x,target.z,rotation) : placement=="room" ? app.Model.PreviewRoom((int)target.x,(int)target.z) : app.Model.PreviewObject(placement,target.x,target.z,rotation);

            if(movingRoom.Length>0)

            {

                var room=app.Model.State.rooms.FirstOrDefault(x=>x.id==movingRoom);

                if(room==null){CancelPlacement();return;}

                bool swap=rotation%2!=0;

                app.World.SetRoomPlacementPreview(swap?room.depth:room.width,swap?room.width:room.depth,target,rotation,result.success);

            }

            else app.World.SetPlacementPreview(placement,target,rotation,result.success);

            ShowNotice(result.success ? "Looks good! Confirm to place." : result.message,!result.success,false);

        }

        void Rotate()

        {

            if(commandAction.Length>0){rotation=(rotation+1)%4;commandPayload["rotation"]=rotation;if(hasTarget)PreviewCommand();return;}

            if(placement=="room"&&movingRoom.Length==0){ShowNotice("Place the room first, then choose Rooms → Edit → Rotate.",false);return;}

            rotation=(rotation+1)%4;if(hasTarget)Preview();

        }

        void Place()

        {

            if(commandAction.Length>0){PlaceCommand();return;}

            if(!hasTarget){ShowNotice("Tap an open spot in your hotel first.",false);return;}

            var result=movingRoom.Length>0 ? app.Model.MoveRoom(movingRoom,(int)target.x,(int)target.z,rotation) : retrievingObject.Length>0 ? app.Model.RetrieveObject(retrievingObject,target.x,target.z,rotation) : movingObject.Length>0 ? app.Model.MoveObject(movingObject,target.x,target.z,rotation) : placement=="room" ? app.Model.PlaceRoom((int)target.x,(int)target.z) : app.Model.PlaceObject(placement,target.x,target.z,rotation);

            app.Report(result);

            if(result.success){app.Audio?.PlayEffect("build");CancelPlacement(false);Rebuild();ShowNotice(result.message,false);}

        }

        void CancelPlacement(bool rebuild=true){app.World.SetPathPainting(false);commandAction="";placement="";movingObject="";retrievingObject="";movingRoom="";hasTarget=false;app.World.ClearPreview();if(rebuild)Rebuild();}

        void Rebuild()

        {

            if (app == null) return;

            if(activeScroll!=null && scrollKey.Length>0)scrollPositions[scrollKey]=activeScroll.verticalNormalizedPosition;

            activeScroll=null;

            categoryScroll=null;selectedCategoryChip=null;

            lastSize=new Vector2(Screen.width,Screen.height);lastSafe=EffectiveSafeArea;
            if(lastSafe.width<=0 || lastSafe.height<=0)lastSafe=new Rect(0,0,Screen.width,Screen.height);

            textScale=app.Model.State.settings.textScale;

            foreach(Transform child in transform) { child.gameObject.SetActive(false); Destroy(child.gameObject); }

            var scaler=GetComponent<UnityEngine.UI.CanvasScaler>();

            // One breakpoint for scaling and all panels; fit both dimensions of the usable display.

            wideLayout=lastSafe.width>lastSafe.height;

            scaler.scaleFactor=Mathf.Max(wideLayout?.925f:.1f,Mathf.Min(lastSafe.width/(wideLayout?1000f:360f),lastSafe.height/(wideLayout?700f:640f)));

            canvas.scaleFactor=scaler.scaleFactor;

            safe=Rect("SafeArea",transform);

            safe.anchorMin=new Vector2(lastSafe.xMin/Screen.width,lastSafe.yMin/Screen.height);

            safe.anchorMax=new Vector2(lastSafe.xMax/Screen.width,lastSafe.yMax/Screen.height);

            safe.offsetMin=safe.offsetMax=Vector2.zero;

            Header();

            if(careCat>=0){CarePanel();}

            else

            {

                // Placement chrome is item/price/Rotate/Cancel/Place only — hide the dock.
                if(!IsPlacing) Navigation();
                else dock=null;

                if(settings)SettingsPanel();

                else if(tab=="Town")TownPanel();

                else if(tab=="Hotel")HotelPanel();

                else if(tab=="Build")BuildPanel();

                else if(tab=="Cats")CatsPanel();

                else if(tab=="Life")LifePanel();

                else MapPanel();

            }

            var notice=Panel("Notice",safe,Ink);

            Pin(notice,new Vector2(0,1),new Vector2(1,1),new Vector2(.5f,1),new Vector2(14,-180),new Vector2(-14,-98));

            toast=Text(notice,"",14,Cream); Stretch(toast.rectTransform,12,6,saveError?65:12,6);

            notice.gameObject.SetActive(false);

            if(saveError)ShowNotice(persistentSaveError,true);

            app.World.SetInputBlocked(settings || careCat>=0 || (tab!="Hotel" && tab!="Build" && tab!="Town"));

            if(dialogTitle.Length>0)DialogPanel();

            RefreshValues();

            if(activeScroll!=null)

            {

                Canvas.ForceUpdateCanvases();

                activeScroll.verticalNormalizedPosition=scrollPositions.TryGetValue(scrollKey,out var position)?position:1;

            }

            if(categoryScroll!=null&&selectedCategoryChip!=null)
            {

                Canvas.ForceUpdateCanvases();

                float overflow=categoryScroll.content.rect.width-categoryScroll.viewport.rect.width;

                if(overflow>0)categoryScroll.horizontalNormalizedPosition=Mathf.Clamp01((selectedCategoryChip.anchoredPosition.x+selectedCategoryChip.rect.width*.5f-categoryScroll.viewport.rect.width*.5f)/overflow);
            }
            Canvas.ForceUpdateCanvases();
            var header=FindActiveRect("Hotel status");
            Rect visible=lastSafe;
            if(header)visible.yMax=ScreenBounds(header).yMin;
            if(careCat>=0)
            {
                var gesture=FindActiveRect("Care gesture surface");
                if(gesture)visible=ScreenBounds(gesture);
            }
            else
            {
                if(dock)visible.yMin=Mathf.Max(visible.yMin,ScreenBounds(dock).yMax);
                var overview=FindActiveRect("Hotel overview");
                if(overview)visible.yMin=Mathf.Max(visible.yMin,ScreenBounds(overview).yMax);
                var placementPanel=FindActiveRect("Placement");
                if(placementPanel)visible.yMin=Mathf.Max(visible.yMin,ScreenBounds(placementPanel).yMax);
                else if(sheet&&sheet.gameObject.activeInHierarchy)
                {
                    var panelBounds=ScreenBounds(sheet);
                    if(wideLayout)visible.xMax=Mathf.Min(visible.xMax,panelBounds.xMin);
                    else visible.yMin=Mathf.Max(visible.yMin,panelBounds.yMax);
                }
            }
            AvailableWorldRect=visible;
            app.World.SetWorldRect(visible);
        }
        RectTransform FindActiveRect(string name)=>GetComponentsInChildren<RectTransform>().FirstOrDefault(r=>r.name==name&&r.gameObject.activeInHierarchy);
        public static Rect ScreenBounds(RectTransform rect){var corners=new Vector3[4];rect.GetWorldCorners(corners);return UnityEngine.Rect.MinMaxRect(corners[0].x,corners[0].y,corners[2].x,corners[2].y);}

        void Header()

        {

            // Slim cream status strip + gold wallet chip (not a tall full-width banner).
            float headerH=careCat>=0?56f:52f;

            var panel=Panel("Hotel status",safe,Cream);

            Pin(panel,new Vector2(0,1),Vector2.one,new Vector2(.5f,1),new Vector2(10,-8-headerH),new Vector2(-10,-8));

            if(wideLayout)Pin(panel,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(12,-8-headerH),new Vector2(420,-8));

            float chipW=textScale>1?176f:158f;

            var chip=Panel("Wallet chip",panel,Gold);

            Pin(chip,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(8,-18),new Vector2(8+chipW,18));

            wallet=Text(chip,"",12,Ink,true);
            walletRate=Text(panel,"",11,new Color(0.09f,0.38f,0.19f));
            Pin(walletRate.rectTransform,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(14,34),new Vector2(-86,52));

            Stretch(wallet.rectTransform,10,2,8,2);

            var title=Text(panel,careCat>=0?"CAT TIME":"PURRINGTON",13,Ink,true);

            Pin(title.rectTransform,new Vector2(0,.5f),new Vector2(1,.5f),new Vector2(0,.5f),new Vector2(16+chipW,-14),new Vector2(careCat>=0?-96:-88,14));

            var gear=Button(panel,careCat>=0?"Back":"Menu",careCat>=0?(Action)CloseCare:()=>{settings=!settings;Rebuild();},Mint,13);

            float targetHalf=Mathf.Max(22f,22f/canvas.scaleFactor);
            Pin(gear,new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(textScale>1?-90:-74,-targetHalf),new Vector2(-8,targetHalf));

        }

        void Navigation()

        {

            dock=Panel("Navigation",safe,Cream);

            Pin(dock,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(10,10),new Vector2(-10,84));

            if(wideLayout)Pin(dock,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-240,10),new Vector2(240,84));

            var row=Horizontal(dock,4,4);

            string[] tabs={"Hotel","Cats","Build","Life","Map"};

            for(int i=0;i<tabs.Length;i++)

            {

                string dest=tabs[i];

                bool build=dest=="Build";

                var btn=Button(row,dest,()=>Navigate(dest),tab==dest?Mint:(build?Gold:Cream),build?13:12);

                var size=btn.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();size.flexibleWidth=build?1.35f:1;size.minWidth=build?64:48;

                var caption=btn.GetComponentInChildren<TextMeshProUGUI>();Stretch(caption.rectTransform,2,build?32:35,2,3);

                NavigationIcon(btn,dest);

            }

        }

        void NavigationIcon(RectTransform parent,string destination)

        {

            var icon=Rect(destination+" icon",parent);

            Pin(icon,new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(-13,-32),new Vector2(13,-6));

            void Block(float x,float y,float w,float h,Color color)

            {

                var part=Rect("Block",icon);part.anchorMin=part.anchorMax=Vector2.zero;part.pivot=Vector2.zero;part.anchoredPosition=new Vector2(x,y);part.sizeDelta=new Vector2(w,h);

                var image=part.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=false;

            }

            if(destination=="Cats")

            {

                Block(3,3,20,17,Ink);Block(3,18,6,6,Ink);Block(17,18,6,6,Ink);Block(7,12,3,3,Cream);Block(17,12,3,3,Cream);Block(12,6,3,3,Coral);

            }

            else if(destination=="Build")

            {

                Block(3,2,20,8,Ink);Block(3,12,9,9,Ink);Block(14,12,9,9,Ink);Block(6,21,4,3,Ink);Block(16,21,4,3,Ink);

            }

            else if(destination=="Hotel")

            {

                Block(4,2,18,17,Ink);Block(1,19,24,4,Ink);Block(10,2,6,10,Cream);Block(6,13,4,3,Gold);Block(16,13,4,3,Gold);

            }

            else if(destination=="Life")

            {

                Block(7,3,12,8,Ink);Block(4,11,5,7,Ink);Block(10,17,6,7,Ink);Block(18,12,5,7,Ink);Block(11,7,4,3,Coral);

            }

            else

            {

                Block(2,3,6,19,Ink);Block(10,1,6,19,Ink);Block(18,4,6,19,Ink);Block(11,10,4,4,Gold);

            }

        }

        void HotelPanel()
        {
            // Compact objective card is the default; expand for room/capacity details.
            float h=compactObjective?58:Mathf.Lerp(165,205,(textScale-1)*2);
            var panel=Panel("Hotel overview",safe,Cream);
            Pin(panel,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(12,96),new Vector2(-12,96+h));
            if(wideLayout)Pin(panel,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-245,96),new Vector2(245,96+h));
            string mapName=(string)app.Model.Map()["name"];
            string headline=compactObjective
                ? mapName+" · Lv "+app.Model.Hotel().level+" · "+app.Model.GuestCapacity()+" guests"
                : mapName+" - level "+app.Model.Hotel().level;
            var title=Text(panel,headline,compactObjective?14:15,Ink,true);
            Pin(title.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-48),new Vector2(-62,-6));
            var collapse=Button(panel,compactObjective?"+":"-",()=>{compactObjective=!compactObjective;Rebuild();},Gold,18);
            Pin(collapse,new Vector2(1,1),Vector2.one,Vector2.one,new Vector2(-54,-48),new Vector2(-6,-4));
            if(app.Model.State.currentHotel==0){
                var explore=Button(safe,"Explore Main Street",app.TownUI.Explore,Mint,14);
                Pin(explore,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(12,-126),new Vector2(184,-78));
            }
            if(compactObjective)return;
            int ready=app.Model.State.rooms.Count(r=>app.Model.IsRoomReady(r));
            int staying=app.Model.Actors.Count(a=>a.kind==ActorKind.Guest);
            int arriving=app.Model.Actors.Count(a=>a.kind==ActorKind.Guest&&!a.checkedIn);
            int capacity=app.Model.GuestCapacity();
            string lifeLine=staying+" staying · "+capacity+" capacity · +"+Math.Round(app.Model.Rate()).ToString("N0")+" / min";
            string arrivalLine=arriving>0
                ? arriving+" arriving at reception · "+ready+"/"+app.Model.State.rooms.Count+" rooms ready"
                : ready+"/"+app.Model.State.rooms.Count+" rooms ready · guests rotate in through reception";
            var copy=Text(panel,lifeLine+"\n"+arrivalLine,13,Ink);
            Pin(copy.rectTransform,Vector2.zero,Vector2.one,Vector2.zero,new Vector2(14,62),new Vector2(-14,-50));
            var actions=Rect("Hotel actions",panel);Pin(actions,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,8),new Vector2(-10,58));
            var row=Horizontal(actions,6,0);Button(row,"Build",()=>Navigate("Build"),Gold,14);Button(row,"Life",()=>Navigate("Life"),Mint,14);
            if(app.Model.State.pendingCoins>0)Button(row,"Collect "+Math.Floor(app.Model.State.pendingCoins).ToString("N0"),()=>{var result=app.Model.ClaimOffline();app.Report(result);if(result.success)app.Audio?.PlayEffect("collect");Rebuild();},Coral,13);
            else Button(row,"Fit hotel",()=>app.World.FitHotel(),Lilac,14);
        }

        // Phone sheets/catalogues must leave ≥35% of screen height for the voxel world.
        float CapPhoneSheetFraction(float requested)
        {
            float logicalH=Mathf.Max(1f,lastSafe.height/Mathf.Max(.01f,canvas.scaleFactor));
            float headerLogical=64f;
            float minWorldLogical=.35f*Screen.height/Mathf.Max(.01f,canvas.scaleFactor);
            float maxFraction=1f-(minWorldLogical+headerLogical)/logicalH;
            return Mathf.Clamp(Mathf.Min(requested,maxFraction),.32f,.55f);
        }

        RectTransform Sheet(string name,string title,float fraction=.61f)

        {

            sheet=Panel(name,safe,Cream);

            bool wide=wideLayout;

            if(wide)Pin(sheet,new Vector2(1,0),Vector2.one,new Vector2(1,.5f),new Vector2(-360,96),new Vector2(-12,-98));

            else
            {
                fraction=CapPhoneSheetFraction(fraction);
                Pin(sheet,Vector2.zero,new Vector2(1,fraction),Vector2.zero,new Vector2(10,96),new Vector2(-10,0));
            }

            var label=Text(sheet,title,18,Ink,true);

            Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(18,-58),new Vector2(-76,-8));

            var close=Button(sheet,"Back",()=>{if(tab=="Town")Back();else Navigate("Hotel");},Gold,12);

            Pin(close,new Vector2(1,1),Vector2.one,Vector2.one,new Vector2(-66,-56),new Vector2(-10,-8));

            return Scroll(sheet,64,12);

        }

        void BuildPanel()

        {

            if(IsPlacing)

            {

                // Placement chrome only: item, price, Rotate, Cancel, Place — keep ≥50% safe height for the world.
                var tray=Panel("Placement",safe,Cream);

                float logicalSafeHeight=lastSafe.height/Mathf.Max(.01f,canvas.scaleFactor);

                float headerReserve=56f;

                float maxTrayTop=Mathf.Max(120f,logicalSafeHeight*.5f-headerReserve);

                float trayTop=Mathf.Min(128f,maxTrayTop);

                Pin(tray,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,10),new Vector2(-10,trayTop));

                string name=commandAction.Length>0?commandTitle:movingRoom.Length>0?"Move room + furnishings":placement=="room"?"Cozy guest room":Catalog.All.First(x=>x.id==placement).name;

                double price=commandAction.Length>0?0:movingRoom.Length>0||movingObject.Length>0||retrievingObject.Length>0?0:placement=="room"?450:Catalog.All.First(x=>x.id==placement).price;

                string priceBit=price>0?" · "+price.ToString("N0")+" coins":"";

                var label=Text(tray,name+priceBit+"\nTap hotel to position",13,Ink,true);

                Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(14,-52),new Vector2(-14,-6));

                var row=Horizontal(tray,6,8);row.offsetMin=new Vector2(8,8);row.offsetMax=new Vector2(-8,-58);

                Button(row,"Cancel",()=>CancelPlacement(),Lilac,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                if(placement!="room"||movingRoom.Length>0)Button(row,"Rotate",Rotate,Gold,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                string placeLabel=commandAction.Length>0?"Confirm":(movingRoom.Length>0||movingObject.Length>0?"Move":"Place");

                Button(row,placeLabel,Place,Mint,14).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                return;

            }

            var content=Sheet("Build catalogue","Build",.55f);

            var tools=Button(sheet,buildToolsExpanded?"Done":"Tools",()=>{buildToolsExpanded=!buildToolsExpanded;Rebuild();},Mint,12);
            Pin(tools,Vector2.one,Vector2.one,Vector2.one,new Vector2(textScale>1?-150:-130,-56),new Vector2(-74,-8));

            if(buildToolsExpanded)
            {

            var controls=Row(content,54);

            Button(controls,"Undo",()=>{app.Report(app.Model.Undo());Rebuild();},Lilac,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

            Button(controls,"Redo",()=>{app.Report(app.Model.Redo());Rebuild();},Lilac,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

            Button(controls,"Play",()=>Navigate("Hotel"),Mint,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

            BuildExtras(content);
            }

            if(selectedRoom.Length>0)

            {

                var room=app.Model.State.rooms.FirstOrDefault(x=>x.id==selectedRoom);

                if(room!=null)

                {

                    string id=room.id;

                    RoomExtras(content,id,room.width,room.depth);

                    Info(content,"EDIT ROOM",room.width+" × "+room.depth+" tiles · "+(app.Model.IsRoomReady(room)?"Ready for guests":"Needs reachable bed and reception")+"\nRemoving stores furniture and returns "+room.paid.ToString("N0")+" shell coins.");

                    var actions=Row(content,56);

                    Button(actions,"Move",()=>BeginMoveRoom(id),Mint,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                    Button(actions,"Rotate",()=>BeginMoveRoom(id,true),Gold,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                    Button(actions,"Remove",()=>{var result=app.Model.RemoveRoom(id);app.Report(result);if(result.success)selectedRoom="";Rebuild();ShowNotice(result.message,!result.success);},Coral,13).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                }

            }

            if(selectedObject.Length>0)

            {

                var selected=app.Model.State.objects.FirstOrDefault(x=>x.id==selectedObject);

                if(selected!=null)

                {

                    string id=selected.id;

                    Info(content,Catalog.Find(selected.itemId).name,"Move this furnishing, or keep it in Storage for later.");

                    var actions=Row(content,56);

                    Button(actions,"Move",()=>BeginMove(id),Mint,14).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                    Button(actions,"Store",()=>{var result=app.Model.StoreObject(id);app.Report(result);if(result.success)selectedObject="";Rebuild();},Coral,14).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

                }

            }

            var categories=new[]{"All","Rooms","Arrangements","Land","Paths"}.Concat(Catalog.All.Select(x=>x.category).Distinct()).Concat(new[]{"Storage"}).ToArray();

            CategoryChips(content,categories);

            ParityCatalogue(content);

            if(category=="Rooms")

            {

                int number=0;

                foreach(var room in app.Model.State.rooms)

                {

                    string id=room.id;number++;

                    Card(content,"Room "+number+" · "+room.width+" × "+room.depth,app.Model.IsRoomReady(room)?"Ready for guests":"Unfinished · add bed and access","Edit",()=>EditRoom(id),Gold);

                }

            }

            if(category=="Storage")

            {

                if(app.Model.State.storage.Count==0)Info(content,"ROOM TO REARRANGE","Stored furnishings appear here. Select a furnishing in your hotel to move it into Storage.");

                foreach(var stored in app.Model.State.storage)

                {

                    string id=stored.id;var item=Catalog.Find(stored.itemId);

                    CatalogCard(content,item.name,"Ready to place",0,()=>BeginRetrieve(id),Mint,item.role,item.id);

                }

            }

            foreach(var item in Catalog.All.Where(x=>category=="All"||category==x.category))

            {

                var chosen=item;

                CatalogCard(content,item.name,item.role+" · "+(item.indoorOnly?"Indoors":"Any floor")+(item.bond>0?" · "+item.bond+" bond":""),app.Model.State.settings.godMode?0:item.price,()=>BeginPlace(chosen.id),Mint,item.role,chosen.id);

            }

        }

        void CategoryChips(RectTransform parent,string[] categories)

        {

            var root=Rect("Catalogue categories",parent);Height(root,52);

            categoryScroll=root.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();

            categoryScroll.horizontal=true;categoryScroll.vertical=false;categoryScroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;categoryScroll.scrollSensitivity=26;

            var viewport=Rect("Viewport",root);Stretch(viewport);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();

            var hit=viewport.gameObject.AddComponent<UnityEngine.UI.Image>();hit.color=new Color(1,1,1,.001f);

            var content=Rect("Chips",viewport);content.anchorMin=Vector2.zero;content.anchorMax=new Vector2(0,1);content.pivot=new Vector2(0,.5f);

            float x=0;

            foreach(string value in categories)

            {

                string chosen=value;

                var chip=Button(content,chosen,()=>{category=chosen;selectedObject="";selectedRoom="";Rebuild();},category==chosen?Gold:Color.white,13);

                var text=chip.GetComponentInChildren<TextMeshProUGUI>();

                float width=Mathf.Max(76,text.GetPreferredValues(chosen).x+30);

                chip.anchorMin=new Vector2(0,0);chip.anchorMax=new Vector2(0,1);chip.pivot=new Vector2(0,.5f);chip.offsetMin=new Vector2(x,2);chip.offsetMax=new Vector2(x+width,-2);

                if(category==chosen)selectedCategoryChip=chip;

                x+=width+8;

            }

            content.sizeDelta=new Vector2(Mathf.Max(0,x-8),0);

            categoryScroll.viewport=viewport;categoryScroll.content=content;

        }

        void CatsPanel()

        {

            var content=Sheet("Cat collection","Meet your guests",.78f);

            foreach(var cat in app.Model.State.cats.Where(c=>c.known))

            {

                int id=cat.id;

                var card=Panel("Cat "+cat.name,content,Color.white);Height(card,100*textScale);

                var pic=Image(card,Portrait(id));

                Pin(pic.rectTransform,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(5,-40),new Vector2(85,40));

                var name=Text(card,cat.name+"\n<size=70%>Friendship "+cat.bond+" / 100</size>",19,Ink,true);

                Stretch(name.rectTransform,91,12,83,12);

                var visit=Button(card,"Visit",()=>OpenCare(id),Coral,14);

                Pin(visit,new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(-79,-28),new Vector2(-7,28));

            }

        }

        void CarePanel() { GestureCarePanel(); }

        void LifePanel() { ParityLifePanel(); }

        void MapPanel() { ParityMapPanel(); }

        void SettingsPanel()

        {

            var content=Sheet("Settings","Make yourself at home",.83f);

            SettingsExtras(content);

            Info(content,"TEXT SIZE","Comfortable controls, at every size.");

            var row=Row(content,56);

            foreach(float scale in new[]{1f,1.25f,1.5f})

            {

                float chosen=scale;

                Button(row,(scale*100)+"%",()=>{var s=app.Model.State.settings;app.Report(app.Model.SetSettings(chosen,s.motion,s.music,s.sound));Rebuild();},Mathf.Approximately(textScale,scale)?Mint:Lilac,14).gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;

            }

            var state=app.Model.State.settings;

            Card(content,"Animated motion","Cat movement and little world details",state.motion?"On":"Off",()=>{app.Report(app.Model.SetSettings(state.textScale,!state.motion,state.music,state.sound));Rebuild();},Gold);

            Card(content,"Assisted care","Guided actions for easier cat care",state.assistedCare?"On":"Off",()=>{app.Report(app.Model.SetAssistedCare(!state.assistedCare));Rebuild();},Mint);

            Card(content,"Music","Background music",state.music?"On":"Off",()=>{app.Report(app.Model.SetSettings(state.textScale,state.motion,!state.music,state.sound));Rebuild();},Lilac);

            Card(content,"Sound effects","Little purrs and happy moments",state.sound?"On":"Off",()=>{app.Report(app.Model.SetSettings(state.textScale,state.motion,state.music,!state.sound));Rebuild();},Lilac);

            Card(content,"Your hotel is yours","Progress is saved on this device.","Save",()=>app.Report(app.Model.Save()),Mint);

            Info(content,"YOUR PURRINGTON PROFILE","All four destinations share your progress.\nYour original Godot hotel remains untouched.");

        }

        public void ShowNotice(string message,bool error,bool persistent=true)

        {

            bool saving=message.IndexOf("sav",StringComparison.OrdinalIgnoreCase)>=0;

            if(error&&persistent&&saving){saveError=true;persistentSaveError=message;}

            else if(!error&&saving&&persistent){saveError=false;persistentSaveError="";}

            else if(saveError){message=persistentSaveError;error=true;}

            if(toast==null)return;

            toast.text=message;

            toast.transform.parent.gameObject.SetActive(true);

            noticeUntil=Time.unscaledTime+5;

            if(saveError && toast.transform.parent.Find("Retry")==null)

            {

                var retry=Button(toast.transform.parent,"Retry",()=>app.RetrySave(),Gold,12);

                retry.name="Retry";

                Pin(retry,Vector2.one,Vector2.one,Vector2.one,new Vector2(-68,-52),new Vector2(-5,-4));

            }

        }

        public void ClearSaveFailure(){if(!saveError)return;saveError=false;persistentSaveError="";if(toast)toast.transform.parent.gameObject.SetActive(false);}

        void Card(Transform parent,string title,string description,string action,Action callback,Color accent,bool enabled=true)

        {

            var card=Panel(title,parent,Color.white);Height(card,Mathf.Max(112,116*textScale));

            var label=Text(card,title,16,Ink,true);Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(12,-12-46*textScale),new Vector2(-99,-8));

            var desc=Text(card,description,12,Ink);Pin(desc.rectTransform,Vector2.zero,Vector2.one,Vector2.zero,new Vector2(12,8),new Vector2(-99,-15-46*textScale));

            var btn=Button(card,action,callback,accent,14);

            btn.GetComponent<UnityEngine.UI.Button>().interactable=enabled;

            if(!enabled)btn.GetComponent<UnityEngine.UI.Image>().color=new Color(accent.r*.82f,accent.g*.82f,accent.b*.82f,.72f);

            Pin(btn,new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(-91,-28),new Vector2(-7,28));

        }

        void CatalogCard(Transform parent,string title,string categoryName,double price,Action callback,Color accent,string role,string itemId="")

        {

            var card=Panel(title,parent,Color.white);Height(card,Mathf.Lerp(128,172,(textScale-1)*2));

            var icon=Panel("Voxel illustration",card,role=="room"?Gold:role=="bed"?Lilac:Mint);

            Pin(icon,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(10,-84),new Vector2(84,-10));

            icon.GetComponent<UnityEngine.UI.Image>().raycastTarget=false;

            string key="build-previews/"+(itemId??"").Replace('_','-');

            Sprite preview=Art(key);

            if(preview!=null)

            {

                icon.GetComponent<UnityEngine.UI.Image>().color=Cream;

                var img=Image(icon,preview);Stretch(img.rectTransform,4,4,4,4);

            }

            else VoxelIcon(icon,role);

            var label=Text(card,title,16,Ink,true);

            Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(94,-80),new Vector2(-10,-8));

            var meta=Text(card,categoryName,12,Ink);

            Pin(meta.rectTransform,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(12,10),new Vector2(-128,48));

            var add=Button(card,price==0?"Place · free":price.ToString("N0")+"  +",callback,price>0?Gold:accent,13);

            Pin(add,new Vector2(1,0),new Vector2(1,0),new Vector2(1,0),new Vector2(-126,8),new Vector2(-8,56));

        }

        void VoxelIcon(Transform parent,string role)

        {

            // Small native block illustrations stay crisp without extra imported assets.

            void Block(string name,float x,float y,float w,float h,Color color)

            {

                var r=Rect(name,parent);r.anchorMin=r.anchorMax=Vector2.zero;r.pivot=Vector2.zero;r.anchoredPosition=new Vector2(x,y);r.sizeDelta=new Vector2(w,h);

                var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=false;

            }

            if(role=="room")

            {

                Block("Floor",8,8,38,7,Ink);Block("Wall",10,15,34,24,Cream);Block("Roof",6,39,42,6,Coral);Block("Door",25,15,11,16,Mint);

            }

            else if(role=="bed"||role=="seat")

            {

                Block("Leg",10,8,5,15,Ink);Block("Leg",39,8,5,15,Ink);Block("Base",8,17,38,13,Coral);Block("Pillow",12,29,14,8,Cream);Block("Cover",26,29,18,6,Gold);

            }

            else if(role=="reception")

            {

                Block("Counter",9,11,36,23,Coral);Block("Top",6,34,42,7,Cream);Block("Bell",31,41,6,4,Gold);Block("Panel",15,16,22,10,Gold);

            }

            else if(role=="play")

            {

                Block("Base",9,8,38,7,Ink);Block("Post",22,15,10,22,Coral);Block("Perch",11,33,30,7,Cream);Block("Toy",36,24,7,7,Gold);

            }

            else

            {

                Block("Pot",17,8,22,14,Coral);Block("Stem",25,21,5,15,Ink);Block("Leaf",12,29,16,10,Cream);Block("Leaf",29,34,15,10,Gold);

            }

        }

        TextMeshProUGUI Info(Transform parent,string title,string description)

        {

            var panel=Panel(title,parent,Color.white);Height(panel,120*textScale);

            var label=Text(panel,title+"\n<size=80%>"+description+"</size>",17,Ink,true);Stretch(label.rectTransform,14,12,14,12);return label;

        }

        void Banner(Transform parent,string asset,float height)

        {

            var img=Image(parent,Art(asset));Height(img.rectTransform,height);img.preserveAspect=true;

        }

        Sprite Art(string name)

        {

            if(illustrations.TryGetValue(name,out var sprite))return sprite;

            var texture=Resources.Load<Texture2D>("Art/"+name);

            if(texture==null)return null;

            sprite=Sprite.Create(texture,new Rect(0,0,texture.width,texture.height),new Vector2(.5f,.5f));illustrations[name]=sprite;return sprite;

        }

        Sprite Portrait(int id)

        {

            string key="portrait"+id;if(illustrations.TryGetValue(key,out var sprite))return sprite;

            var atlas=Resources.Load<Texture2D>("Art/cats-0"+(id/6+1));if(atlas==null)return null;

            int index=id%6;float w=atlas.width/3f,h=atlas.height/2f;

            sprite=Sprite.Create(atlas,new Rect(index%3*w,(1-index/3)*h,w,h),new Vector2(.5f,.5f));illustrations[key]=sprite;return sprite;

        }

        RectTransform Scroll(RectTransform parent,float top,float bottom)

        {

            var root=Rect("Scroll",parent);Stretch(root,10,top,10,bottom);

            var scroll=root.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroll.horizontal=false;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;

            activeScroll=scroll;scrollKey=settings?"Settings":tab=="Build"?"Build/"+category:tab;

            var viewport=Rect("Viewport",root);Stretch(viewport);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();

            var hit=viewport.gameObject.AddComponent<UnityEngine.UI.Image>();hit.color=new Color(1,1,1,.001f);

            var content=Rect("Content",viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;

            var layout=content.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();layout.spacing=9;layout.padding=new RectOffset(2,2,2,4);layout.childControlWidth=true;layout.childControlHeight=true;layout.childForceExpandHeight=false;

            var fitter=content.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>();fitter.verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;

            scroll.viewport=viewport;scroll.content=content;scroll.scrollSensitivity=25;return content;

        }

        RectTransform Row(Transform parent,float h){var r=Rect("Row",parent);Height(r,h);var l=r.gameObject.AddComponent<UnityEngine.UI.HorizontalLayoutGroup>();l.spacing=6;l.childControlWidth=true;l.childControlHeight=true;l.childForceExpandWidth=true;return r;}

        RectTransform Horizontal(Transform parent,int gap,int padding){var r=Rect("Row",parent);Stretch(r,padding,padding,padding,padding);var l=r.gameObject.AddComponent<UnityEngine.UI.HorizontalLayoutGroup>();l.spacing=gap;l.childControlHeight=true;l.childControlWidth=true;return r;}

        RectTransform Vertical(Transform parent,int gap,int padding){var r=Rect("Column",parent);Stretch(r,padding,padding,padding,padding);var l=r.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();l.spacing=gap;l.childControlHeight=true;l.childControlWidth=true;l.childForceExpandHeight=false;return r;}

        RectTransform Button(Transform parent,string label,Action action,Color color,float fontSize)

        {

            var r=Panel(label,parent,color);var button=r.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=r.GetComponent<UnityEngine.UI.Image>();button.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");action();});

            var colors=button.colors;colors.highlightedColor=new Color(1.04f,1.04f,1.04f);colors.pressedColor=new Color(.86f,.9f,.88f);button.colors=colors;

            var text=Text(r,label,fontSize,Ink,true);text.alignment=TextAlignmentOptions.Center;Stretch(text.rectTransform,4,3,4,3);return r;

        }

        RectTransform Panel(string name,Transform parent,Color color){var r=Rect(name,parent);var img=r.gameObject.AddComponent<UnityEngine.UI.Image>();img.sprite=rounded;img.type=UnityEngine.UI.Image.Type.Sliced;img.color=color;if(parent==safe){var shadow=r.gameObject.AddComponent<UnityEngine.UI.Shadow>();shadow.effectColor=new Color(.12f,.18f,.12f,.14f);shadow.effectDistance=new Vector2(0,-3);shadow.useGraphicAlpha=true;}return r;}

        UnityEngine.UI.Image Image(Transform parent,Sprite sprite){var r=Rect("Illustration",parent);var img=r.gameObject.AddComponent<UnityEngine.UI.Image>();img.sprite=sprite;img.preserveAspect=true;img.raycastTarget=false;if(sprite==null)img.color=Color.clear;return img;}

        TextMeshProUGUI Text(Transform parent,string value,float size,Color color,bool bold=false)

        {

            var r=Rect("Text",parent);var t=r.gameObject.AddComponent<TextMeshProUGUI>();t.text=value;t.font=bold?(heading??body):body;t.fontSize=size*textScale;t.color=color;t.raycastTarget=false;t.fontStyle=bold?FontStyles.Bold:FontStyles.Normal;t.fontWeight=bold?FontWeight.Bold:FontWeight.Medium;t.textWrappingMode=TextWrappingModes.Normal;t.overflowMode=TextOverflowModes.Ellipsis;t.verticalAlignment=VerticalAlignmentOptions.Middle;return t;

        }

        static RectTransform Rect(string name,Transform parent){var go=new GameObject(name,typeof(RectTransform));go.transform.SetParent(parent,false);return (RectTransform)go.transform;}

        static void Stretch(RectTransform r,float left=0,float top=0,float right=0,float bottom=0){r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(left,bottom);r.offsetMax=new Vector2(-right,-top);}

        static void Pin(RectTransform r,Vector2 min,Vector2 max,Vector2 pivot,Vector2 offsetMin,Vector2 offsetMax)

        {

            if(Mathf.Approximately(min.y,max.y)&&offsetMin.y>offsetMax.y){float y=offsetMin.y;offsetMin.y=offsetMax.y;offsetMax.y=y;}

            r.anchorMin=min;r.anchorMax=max;r.pivot=pivot;r.offsetMin=offsetMin;r.offsetMax=offsetMax;

        }

        static void Height(RectTransform r,float value){var le=r.gameObject.GetComponent<UnityEngine.UI.LayoutElement>()??r.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();le.minHeight=value;le.preferredHeight=value;}

        static Color Hex(string text){ColorUtility.TryParseHtmlString("#"+text,out var c);return c;}

        static Sprite RoundedSprite()

        {

            const int n=64;const float radius=18;var texture=new Texture2D(n,n,TextureFormat.RGBA32,false);texture.filterMode=FilterMode.Bilinear;

            for(int y=0;y<n;y++)for(int x=0;x<n;x++){float dx=Mathf.Max(radius-x,Mathf.Max(x-(n-1-radius),0)),dy=Mathf.Max(radius-y,Mathf.Max(y-(n-1-radius),0));float a=Mathf.Clamp01(radius-Mathf.Sqrt(dx*dx+dy*dy));texture.SetPixel(x,y,new Color(1,1,1,a));}

            texture.Apply();return Sprite.Create(texture,new Rect(0,0,n,n),new Vector2(.5f,.5f),100,0,SpriteMeshType.FullRect,new Vector4(20,20,20,20));

        }

    }

}
