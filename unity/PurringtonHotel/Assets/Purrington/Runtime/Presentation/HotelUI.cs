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
        static readonly Color CardTone=ConceptTheme.Ui.Card,InkSoft=ConceptTheme.Ui.InkSoft,LeafText=ConceptTheme.Ui.LeafText,Coin=ConceptTheme.Ui.Coin;

        HotelApp app;

        Canvas canvas;

        RectTransform safe, sheet, dock;

        TMP_FontAsset body, heading;

        TextMeshProUGUI wallet, walletRate, toast;

        string tab = "Hotel", category = "All", placement = "", selectedObject = "", careTool = "pet";

        int rotation, careCat = -1;

        Vector3 target;

        CountUp walletCounter;string lastSheetName="";
        bool hasTarget, settings, welcome, welcomeCameraHidden, compactObjective=true, saveError;

        Vector2 lastSize;

        Rect lastSafe;

        bool wideLayout;

        string persistentSaveError="";

        float textScale = 1, noticeUntil;

        Sprite rounded;

        RectTransform welcomePlaque, welcomeRibbon, welcomeActions, welcomePlay, welcomePaw;
        RectTransform[] welcomeGlints;
        CanvasGroup welcomePlaqueFade, welcomeRibbonFade, welcomeActionsFade;
        CanvasGroup[] welcomeGlintFades;
        UnityEngine.UI.RawImage welcomePicture;
        Rect welcomePictureUv;
        Vector2 welcomePlaquePosition, welcomeRibbonPosition, welcomeActionsPosition;
        float welcomeAnimationStart;

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

            var args=Environment.GetCommandLineArgs();
            welcome=!args.Any(a=>a=="-purrington-smoke"||a=="-purrington-input-acceptance"||a=="-purrington-render-acceptance"||a=="-purrington-concept");

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

            if(app == null || app.Model == null || app.World == null) return;

            if (lastSize != new Vector2(Screen.width,Screen.height) || lastSafe != EffectiveSafeArea) Rebuild();
            if (toast != null && !saveError && Time.unscaledTime > noticeUntil) toast.transform.parent.gameObject.SetActive(false);

            if (Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame) Back();

            if (Keyboard.current != null && Keyboard.current.rKey.wasPressedThisFrame && IsPlacing) Rotate();

            if(!(Mouse.current?.leftButton.isPressed??false)&&!(Touchscreen.current?.primaryTouch.press.isPressed??false))lastPathCell=null;

            RefreshValues();
            AnimateWelcome();

        }

        void OnDestroy() { if (welcomeCameraHidden && app != null && app.World != null && app.World.WorldCamera) app.World.WorldCamera.enabled=true; if (app != null && app.Model != null) app.Model.Changed -= RefreshValues; }

        void RefreshValues()

        {

            if (app == null || app.Model == null) return;
            RefreshMarketStatus();
            if (wallet == null) return;
            double rate = app.Model.Rate();
            if (walletRate != null && walletCounter != null) { walletCounter.Set(app.Model.State.coins); walletRate.text = "+" + Math.Round(rate).ToString("N0") + " / min"; }
            else { wallet.text = Math.Floor(app.Model.State.coins).ToString("N0"); if (walletRate != null) walletRate.text = "+" + Math.Round(rate).ToString("N0") + " / min"; else wallet.text += " · +" + Math.Round(rate).ToString("N0") + " / min"; }

        }

        public void Navigate(string destination)

        {

            welcome=false;
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

            if (welcome) return;

            Navigate("Hotel");

        }

        public void OpenCare(int id)

        {

            if (IsPlacing || app.World.IsTownMode) return;

            welcome=false;
            CloseWardrobe(); careCat=id; careTool="pet"; careDetails=false; settings=false;

            app.World.SetCareMode(id,true); Rebuild();

        }

        void CloseCare() { gestureInput?.Suspend(); CloseWardrobe(); app.World.SetCareMode(careCat,false);careCat=-1;careDetails=false;Rebuild(); }

        public void SelectObject(string id)

        {

            if (tab!="Build" || IsPlacing) return;

            selectedObject=id;selectedRoom="";NoteSelection();Rebuild();

        }

        void EditRoom(string id){selectedRoom=id;selectedObject="";NoteSelection();Rebuild();}

        public void GroundClicked(Vector3 point)

        {

            if (careCat>=0) return;

            // Tapping open ground in Build clears the selection (a room or furnishing tap also reports the ground under it).
            if (!IsPlacing) { if(tab=="Build"&&!JustSelected&&(selectedRoom.Length>0||selectedObject.Length>0)){selectedRoom="";selectedObject="";Rebuild();} return; }

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

            var result=movingRoom.Length>0 ? app.Model.PreviewMoveRoom(movingRoom,(int)target.x,(int)target.z,rotation) : retrievingObject.Length>0 ? app.Model.PreviewRetrieveObject(retrievingObject,target.x,target.z,rotation,currentFloor) : movingObject.Length>0 ? app.Model.PreviewMoveObject(movingObject,target.x,target.z,rotation) : placement=="room" ? app.Model.PreviewRoom((int)target.x,(int)target.z) : app.Model.PreviewObject(placement,target.x,target.z,rotation,currentFloor);

            if(movingRoom.Length>0)

            {

                var room=app.Model.State.rooms.FirstOrDefault(x=>x.id==movingRoom);

                if(room==null){CancelPlacement();return;}

                bool swap=rotation%2!=0;

                app.World.SetRoomPlacementPreview(swap?room.depth:room.width,swap?room.width:room.depth,target,rotation,result.success);

            }

            else app.World.SetPlacementPreview(placement,target,rotation,result.success,movingObject);

            ApplyToolStatus(result.success ? "Looks good · tap Place to confirm." : result.message,result.success);

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

            var result=movingRoom.Length>0 ? app.Model.MoveRoom(movingRoom,(int)target.x,(int)target.z,rotation) : retrievingObject.Length>0 ? app.Model.RetrieveObject(retrievingObject,target.x,target.z,rotation,currentFloor) : movingObject.Length>0 ? app.Model.MoveObject(movingObject,target.x,target.z,rotation) : placement=="room" ? app.Model.PlaceRoom((int)target.x,(int)target.z) : app.Model.PlaceObject(placement,target.x,target.z,rotation,currentFloor);

            app.Report(result);

            if(result.success){app.Audio?.PlayEffect("build");CancelPlacement(false);Rebuild();ShowNotice(result.message,false);}

        }

        void CancelPlacement(bool rebuild=true){app.World.SetPathPainting(false);commandAction="";placement="";movingObject="";retrievingObject="";movingRoom="";hasTarget=false;app.World.ClearPreview();if(rebuild)Rebuild();}

        void Rebuild()

        {

            if (app == null || app.Model == null || app.World == null) return;

            if(activeScroll!=null && scrollKey.Length>0)scrollPositions[scrollKey]=activeScroll.verticalNormalizedPosition;

            activeScroll=null;

            categoryScroll=null;selectedCategoryChip=null;

            lastSize=new Vector2(Screen.width,Screen.height);lastSafe=EffectiveSafeArea;
            if(lastSafe.width<=0 || lastSafe.height<=0)lastSafe=new Rect(0,0,Screen.width,Screen.height);

            textScale=app.Model.State.settings.textScale;

            // Rebuild destroys the previous welcome hierarchy at the end of this frame.
            welcomePicture=null;
            welcomeGlints=null;
            welcomeGlintFades=null;

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

            if(welcome)
            {
                if(app.World.WorldCamera && app.World.WorldCamera.enabled)
                {
                    app.World.WorldCamera.enabled=false;
                    welcomeCameraHidden=true;
                }
                WelcomePanel();
                app.World.SetInputBlocked(true);
                AvailableWorldRect=lastSafe;
                return;
            }

            if(welcomeCameraHidden && app.World.WorldCamera)
            {
                app.World.WorldCamera.enabled=true;
                welcomeCameraHidden=false;
            }

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
                var placementPanel=FindActiveRect("Placement")??FindActiveRect("Selection");
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

        void WelcomePanel()
        {
            dock=null;
            sheet=null;
            var backdrop=Rect("Welcome background",safe);
            Stretch(backdrop);
            backdrop.gameObject.AddComponent<UnityEngine.UI.Image>().color=Hex("E8DDC5");
            var width=Mathf.Min(430f,lastSafe.width/Mathf.Max(.01f,canvas.scaleFactor));
            var card=Rect("Welcome content",backdrop);
            Pin(card,new Vector2(.5f,0),new Vector2(.5f,1),new Vector2(.5f,.5f),new Vector2(-width*.5f,0),new Vector2(width*.5f,0));
            card.gameObject.AddComponent<UnityEngine.UI.Image>().color=Hex("FFF8E9");
            var cardShadow=card.gameObject.AddComponent<UnityEngine.UI.Shadow>();
            cardShadow.effectColor=new Color(.13f,.16f,.11f,.27f);
            cardShadow.effectDistance=new Vector2(0,-5);

            var art=Rect("Hotel exterior",card);
            Stretch(art);
            var picture=art.gameObject.AddComponent<UnityEngine.UI.RawImage>();
            welcomePicture=picture;
            var texture=Resources.Load<Texture2D>("Art/welcome-exterior")??Resources.Load<Texture2D>("Art/welcome-hotel");
            picture.texture=texture;
            picture.raycastTarget=false;
            if(texture!=null)
            {
                float frameAspect=width/(lastSafe.height/Mathf.Max(.01f,canvas.scaleFactor));
                float artAspect=(float)texture.width/texture.height;
                if(frameAspect<artAspect)
                {
                    float visibleWidth=frameAspect/artAspect;
                    picture.uvRect=new Rect((1f-visibleWidth)*.5f,0,visibleWidth,1);
                }
                else
                {
                    float visibleHeight=artAspect/frameAspect;
                    picture.uvRect=new Rect(0,(1f-visibleHeight)*.5f,1,visibleHeight);
                }
            }
            welcomePictureUv=picture.uvRect;

            var plaque=Panel("Hotel name plaque",card,Hex("B3824C"));
            Pin(plaque,new Vector2(.095f,.833f),new Vector2(.905f,.967f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);
            var plaqueShadow=plaque.gameObject.AddComponent<UnityEngine.UI.Shadow>();
            plaqueShadow.effectColor=new Color(.23f,.17f,.10f,.29f);
            plaqueShadow.effectDistance=new Vector2(0,-4);
            var plaqueFace=Panel("Cream plaque face",plaque,Hex("FFF8E9"));
            Stretch(plaqueFace,3,3,3,3);
            var brand=Text(plaqueFace,"PURRINGTON\nHOTEL",textScale>1.25f?20:25,Ink,true);
            brand.alignment=TextAlignmentOptions.Center;
            brand.characterSpacing=1.3f;
            brand.lineSpacing=-5f;
            brand.overflowMode=TextOverflowModes.Truncate;
            Stretch(brand.rectTransform,8,3,8,3);
            var ribbon=Panel("Welcome tagline ribbon",card,Hex("FFF8E9"));
            Pin(ribbon,new Vector2(.19f,.778f),new Vector2(.81f,.825f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);
            var tagline=Text(ribbon,"Cozy stays. Happy cats.",14,Ink,true);
            tagline.alignment=TextAlignmentOptions.Center;
            tagline.overflowMode=TextOverflowModes.Truncate;
            Stretch(tagline.rectTransform,4,1,4,1);

            var actions=Panel("Welcome actions",card,Hex("CAB286"));
            Pin(actions,new Vector2(.026f,.022f),new Vector2(.974f,.275f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);
            var actionsShadow=actions.gameObject.AddComponent<UnityEngine.UI.Shadow>();
            actionsShadow.effectColor=new Color(.20f,.17f,.12f,.23f);
            actionsShadow.effectDistance=new Vector2(0,-4);
            var face=Panel("Welcome action surface",actions,Hex("FFF9EF"));
            Stretch(face,2,2,2,2);

            var play=Button(face,"Open your hotel",()=>{welcome=false;settings=false;Rebuild();app.World.FitHotel();},Hex("258F78"),19);
            Pin(play,new Vector2(.035f,.54f),new Vector2(.965f,.90f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);
            var playShadow=play.gameObject.AddComponent<UnityEngine.UI.Shadow>();
            playShadow.effectColor=new Color(.10f,.27f,.21f,.35f);
            playShadow.effectDistance=new Vector2(0,-3);
            var playLabel=play.GetComponentInChildren<TextMeshProUGUI>();
            playLabel.color=Color.white;
            playLabel.overflowMode=TextOverflowModes.Truncate;
            Stretch(playLabel.rectTransform,48,2,14,2);
            var paw=WelcomePaw(play,Hex("FFE1A0"));

            var settingsRim=Panel("Settings outline",face,Hex("CCBFA9"));
            Pin(settingsRim,new Vector2(.20f,.20f),new Vector2(.80f,.52f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);
            var preferences=Button(settingsRim,"Settings",()=>{settings=true;Rebuild();},Hex("FFFDF8"),15);
            Stretch(preferences,2,2,2,2);
            preferences.GetComponentInChildren<TextMeshProUGUI>().overflowMode=TextOverflowModes.Truncate;
            var note=Text(face,"Your hotel earns while you're away.",12,Ink);
            note.alignment=TextAlignmentOptions.Center;
            note.overflowMode=TextOverflowModes.Truncate;
            Pin(note.rectTransform,new Vector2(.05f,.035f),new Vector2(.95f,.19f),new Vector2(.5f,.5f),Vector2.zero,Vector2.zero);

            if(app.Model.State.settings.motion)
            {
                welcomePlaque=plaque;
                welcomeRibbon=ribbon;
                welcomeActions=actions;
                welcomePlay=play;
                welcomePaw=paw;
                welcomePlaquePosition=plaque.anchoredPosition;
                welcomeRibbonPosition=ribbon.anchoredPosition;
                welcomeActionsPosition=actions.anchoredPosition;
                welcomePlaqueFade=plaque.gameObject.AddComponent<CanvasGroup>();
                welcomeRibbonFade=ribbon.gameObject.AddComponent<CanvasGroup>();
                welcomeActionsFade=actions.gameObject.AddComponent<CanvasGroup>();
                welcomePlaqueFade.alpha=0;
                welcomeRibbonFade.alpha=0;
                welcomeActionsFade.alpha=0;
                welcomeGlints=new RectTransform[3];
                welcomeGlintFades=new CanvasGroup[3];
                welcomeGlints[0]=WelcomeGlint(card,new Vector2(.13f,.62f),out welcomeGlintFades[0]);
                welcomeGlints[1]=WelcomeGlint(card,new Vector2(.86f,.69f),out welcomeGlintFades[1]);
                welcomeGlints[2]=WelcomeGlint(card,new Vector2(.82f,.39f),out welcomeGlintFades[2]);
                welcomeAnimationStart=Time.unscaledTime;
            }

            if(!settings)return;
            SettingsPanel();
        }

        void AnimateWelcome()
        {
            if(!welcome || app.Model == null || !app.Model.State.settings.motion || welcomePlaque == null) return;

            float elapsed=Time.unscaledTime-welcomeAnimationStart;
            float Arrive(float delay,float duration)
            {
                float progress=Mathf.Clamp01((elapsed-delay)/duration);
                return progress*progress*(3f-2f*progress);
            }
            float plaqueArrival=Arrive(0,.55f);
            float ribbonArrival=Arrive(.13f,.52f);
            float actionsArrival=Arrive(.25f,.58f);
            welcomePlaqueFade.alpha=plaqueArrival;
            welcomeRibbonFade.alpha=ribbonArrival;
            welcomeActionsFade.alpha=actionsArrival;
            welcomePlaque.anchoredPosition=welcomePlaquePosition+new Vector2(0,-12f*(1f-plaqueArrival)+1.3f*Mathf.Sin(elapsed*1.45f)*plaqueArrival);
            welcomeRibbon.anchoredPosition=welcomeRibbonPosition+new Vector2(0,-8f*(1f-ribbonArrival)+.7f*Mathf.Sin(elapsed*1.45f+.7f)*ribbonArrival);
            welcomeActions.anchoredPosition=welcomeActionsPosition+new Vector2(0,-16f*(1f-actionsArrival));

            float breathe=Mathf.Sin(elapsed*2.5f);
            welcomePlay.localScale=Vector3.one*(1f+.012f*breathe*actionsArrival);
            welcomePaw.localRotation=Quaternion.Euler(0,0,7f*Mathf.Sin(elapsed*3.1f)*actionsArrival);

            // Change only the sampled UVs so the illustration never grows outside its frame.
            if(welcomePicture != null && welcomePicture.texture != null)
            {
                float zoom=.986f+.003f*Mathf.Sin(elapsed*.8f);
                float width=welcomePictureUv.width*zoom;
                float height=welcomePictureUv.height*zoom;
                float driftX=.5f+.32f*Mathf.Sin(elapsed*.37f);
                float driftY=.5f+.32f*Mathf.Sin(elapsed*.29f+.8f);
                welcomePicture.uvRect=new Rect(
                    welcomePictureUv.x+(welcomePictureUv.width-width)*driftX,
                    welcomePictureUv.y+(welcomePictureUv.height-height)*driftY,
                    width,height);
            }

            for(int i=0;i<welcomeGlints.Length;i++)
            {
                float phase=elapsed*1.9f+i*2.1f;
                float shimmer=Mathf.Max(0,Mathf.Sin(phase));
                welcomeGlintFades[i].alpha=plaqueArrival*(.12f+.6f*shimmer*shimmer);
                welcomeGlints[i].anchoredPosition=new Vector2(0,2.5f*Mathf.Sin(elapsed*1.1f+i));
                welcomeGlints[i].localRotation=Quaternion.Euler(0,0,9f*Mathf.Sin(elapsed*.8f+i));
            }
        }

        RectTransform WelcomeGlint(RectTransform parent,Vector2 anchor,out CanvasGroup fade)
        {
            var glint=Rect("Welcome glint",parent);
            Pin(glint,anchor,anchor,new Vector2(.5f,.5f),new Vector2(-10,-10),new Vector2(10,10));
            fade=glint.gameObject.AddComponent<CanvasGroup>();
            fade.alpha=0;
            void Ray(string name,Vector2 size)
            {
                var ray=Rect(name,glint);
                ray.anchorMin=ray.anchorMax=new Vector2(.5f,.5f);
                ray.pivot=new Vector2(.5f,.5f);
                ray.anchoredPosition=Vector2.zero;
                ray.sizeDelta=size;
                var glow=ray.gameObject.AddComponent<UnityEngine.UI.Image>();
                glow.sprite=rounded;
                glow.type=UnityEngine.UI.Image.Type.Sliced;
                glow.color=Hex("FFF0BB");
                glow.raycastTarget=false;
            }
            Ray("Vertical sparkle",new Vector2(3,18));
            Ray("Horizontal sparkle",new Vector2(18,3));
            return glint;
        }

        RectTransform WelcomePaw(RectTransform parent,Color color)
        {
            var paw=Rect("Paw emblem",parent);
            Pin(paw,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(17,-14),new Vector2(45,14));
            void Pad(string name,float x,float y,float w,float h)
            {
                var part=Rect(name,paw);
                part.anchorMin=part.anchorMax=Vector2.zero;
                part.pivot=Vector2.zero;
                part.anchoredPosition=new Vector2(x,y);
                part.sizeDelta=new Vector2(w,h);
                var mark=part.gameObject.AddComponent<UnityEngine.UI.Image>();
                mark.sprite=rounded;
                mark.color=color;
                mark.raycastTarget=false;
            }
            Pad("Paw pad",7,2,15,13);
            Pad("Left toe",1,16,6,8);
            Pad("Middle toe",9,19,6,8);
            Pad("Right toe",18,16,6,8);
            return paw;
        }

        void Header()

        {

            // Slim cream card strip: paw-coin wallet chip, day clock chip, hotel name and gear (not a tall full-width banner).
            float headerH=careCat>=0?56f:52f;

            var panel=Panel("Hotel status",safe,CardTone);

            Pin(panel,new Vector2(0,1),Vector2.one,new Vector2(.5f,1),new Vector2(10,-8-headerH),new Vector2(-10,-8));

            if(wideLayout)Pin(panel,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(12,-8-headerH),new Vector2(420,-8));

            // Portrait canvases are ~360 units wide on every phone: size the chips from textScale and auto-size their text so balance, rate, day and time always show.
            void Fit(TextMeshProUGUI t,float max,float min){t.enableAutoSizing=true;t.fontSizeMin=min;t.fontSizeMax=max*textScale;t.textWrappingMode=TextWrappingModes.NoWrap;}
            float chipW=Mathf.Round(50+60*textScale);

            var chip=Panel("Wallet chip",panel,CardTone);

            Pin(chip,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(8,-22),new Vector2(8+chipW,22));
            var coin=UiCoin.Create(chip,rounded,26);coin.anchorMin=coin.anchorMax=coin.pivot=new Vector2(0,.5f);coin.anchoredPosition=new Vector2(4,0);

            wallet=Text(chip,"",13,Ink,true);Fit(wallet,13,8);
            walletCounter=wallet.gameObject.AddComponent<CountUp>();walletCounter.Label=wallet;walletCounter.Coin=coin;
            var ratePill=Panel("Rate pill",chip,Mint);Pin(ratePill,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(32,3),new Vector2(-6,19));walletRate=Text(ratePill,"",10,LeafText,true);Fit(walletRate,10,7);Stretch(walletRate.rectTransform,6,1,6,1);

            Stretch(wallet.rectTransform,34,2,8,20);

            float clockW=0f;
            if(careCat<0){bool compactClock=((RectTransform)safe).rect.width<380||textScale>1.25f;clockW=compactClock?Mathf.Round(40+28*textScale):116f;float clockH=compactClock?22f:16f;var clockPanel=Panel("Clock chip",panel,CardTone);Pin(clockPanel,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(14+chipW,-clockH),new Vector2(14+chipW+clockW,clockH));var sunImg=Panel("Sun",clockPanel,Coin).GetComponent<UnityEngine.UI.Image>();var moonImg=Panel("Moon",clockPanel,InkSoft).GetComponent<UnityEngine.UI.Image>();foreach(var g in new[]{sunImg,moonImg}){var r=g.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,.5f);r.sizeDelta=new Vector2(16,16);r.anchoredPosition=new Vector2(8,0);g.raycastTarget=false;}var clockText=Text(clockPanel,"",11,Ink,true);Fit(clockText,11,7);Stretch(clockText.rectTransform,28,2,6,2);clockPanel.gameObject.AddComponent<HotelClockChip>().Bind(app.Model,clockText,sunImg,moonImg,compactClock);}

            var title=Text(panel,careCat>=0?"CAT TIME":(string)app.Model.Map()["name"],14,Ink,true);title.enableAutoSizing=true;title.fontSizeMin=10*textScale;title.fontSizeMax=14*textScale;title.textWrappingMode=wideLayout?TextWrappingModes.NoWrap:TextWrappingModes.Normal;

            Pin(title.rectTransform,new Vector2(0,.5f),new Vector2(1,.5f),new Vector2(0,.5f),new Vector2(20+chipW+clockW,-14),new Vector2(careCat>=0?-96:-58,14));
            // Below ~80 units the name is only an ellipsis (360 px at 150%), so it steps aside for the wallet and clock.
            float titleW=(wideLayout?408f:((RectTransform)safe).rect.width-20)-(careCat>=0?96:58)-(20+chipW+clockW);title.gameObject.SetActive(titleW>=80&&!(tab=="Hotel"&&careCat<0&&!welcome));

            if(careCat>=0)
            {
                var back=Button(panel,"Back",CloseCare,CardTone,13);
                float targetHalf=Mathf.Max(22f,22f/canvas.scaleFactor);
                Pin(back,new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(textScale>1?-90:-74,-targetHalf),new Vector2(-8,targetHalf));
            }
            else
            {
                // Gear drawn from ink rects so the menu needs no icon font.
                var gear=Button(panel,"",()=>{settings=!settings;Rebuild();},CardTone,13);gear.name="Menu";
                Pin(gear,new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(1,.5f),new Vector2(-52,-22),new Vector2(-8,22));
                for(int i=0;i<8;i++){float a=i*45f*Mathf.Deg2Rad;var tooth=Rect("Tooth",gear);tooth.anchorMin=tooth.anchorMax=tooth.pivot=new Vector2(.5f,.5f);tooth.sizeDelta=new Vector2(4,6);tooth.anchoredPosition=new Vector2(Mathf.Sin(a),Mathf.Cos(a))*11;tooth.localRotation=Quaternion.Euler(0,0,-i*45f);var t=tooth.gameObject.AddComponent<UnityEngine.UI.Image>();t.color=Ink;t.raycastTarget=false;}
                foreach(var (size,color) in new[]{(16f,Ink),(7f,CardTone)}){var disc=Panel("Gear disc",gear,color);disc.anchorMin=disc.anchorMax=disc.pivot=new Vector2(.5f,.5f);disc.sizeDelta=new Vector2(size,size);disc.anchoredPosition=Vector2.zero;disc.GetComponent<UnityEngine.UI.Image>().raycastTarget=false;}
            }

        }

        void Navigation()

        {

            dock=Panel("Navigation",safe,CardTone);

            Pin(dock,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(10,10),new Vector2(-10,84));

            if(wideLayout)Pin(dock,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-240,10),new Vector2(240,84));

            var row=Horizontal(dock,4,4);

            string[] tabs={"Hotel","Cats","Build","Life","Map"};

            // The mint highlight is one pill that slides from the previous tab to the new one; tab buttons stay clear over the dock.
            var pill=Panel("Active tab",row,Mint);pill.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().ignoreLayout=true;pill.GetComponent<UnityEngine.UI.Image>().raycastTarget=false;
            var buttons=new Dictionary<string,RectTransform>();

            for(int i=0;i<tabs.Length;i++)

            {

                string dest=tabs[i];

                bool build=dest=="Build";

                var btn=Button(row,dest,()=>Navigate(dest),new Color(CardTone.r,CardTone.g,CardTone.b,0),build?13:12);buttons[dest]=btn;

                var size=btn.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();size.flexibleWidth=build?1.35f:1;size.minWidth=build?64:48;

                var caption=btn.GetComponentInChildren<TextMeshProUGUI>();Stretch(caption.rectTransform,2,build?32:35,2,3);

                NavigationIcon(btn,dest);

            }

            SlideActiveTab(row,pill,buttons);

        }

        static string shownTab;
        void SlideActiveTab(RectTransform row,RectTransform pill,Dictionary<string,RectTransform> buttons)
        {
            if(!buttons.TryGetValue(tab??"",out var target)){pill.gameObject.SetActive(false);shownTab=null;return;}
            UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(row);
            pill.anchorMin=pill.anchorMax=pill.pivot=new Vector2(.5f,.5f);
            Vector2 Center(RectTransform r)=>(Vector2)row.InverseTransformPoint(r.TransformPoint(r.rect.center));
            Vector2 to=Center(target),toSize=target.rect.size;
            bool slide=shownTab!=null&&shownTab!=tab&&buttons.TryGetValue(shownTab,out var from);
            Vector2 start=slide?Center(buttons[shownTab]):to,startSize=slide?buttons[shownTab].rect.size:toSize;shownTab=tab;
            Tween.Run(pill,slide?.28f:0,k=>{if(!pill)return;float e=Tween.OutCubic(k);pill.localPosition=Vector2.LerpUnclamped(start,to,e);pill.sizeDelta=Vector2.LerpUnclamped(startSize,toSize,e);});
        }

        void NavigationIcon(RectTransform parent,string destination)

        {

            var icon=Rect(destination+" icon",parent);

            Pin(icon,new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(-13,-32),new Vector2(13,-6));
            icon.localScale=Vector3.one*1.12f;

            void Block(float x,float y,float w,float h,Color color)

            {

                var part=Rect("Block",icon);part.anchorMin=part.anchorMax=Vector2.zero;part.pivot=Vector2.zero;part.anchoredPosition=new Vector2(x,y);part.sizeDelta=new Vector2(w,h);

                var image=part.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=false;

            }

            if(destination=="Cats")

            {

                Block(3,3,20,17,Ink);Block(3,18,6,6,Ink);Block(17,18,6,6,Ink);Block(7,12,3,3,CardTone);Block(17,12,3,3,CardTone);Block(12,6,3,3,Coin);

            }

            else if(destination=="Build")

            {

                Block(3,2,20,8,Ink);Block(3,12,9,9,Ink);Block(14,12,9,9,Ink);Block(6,21,4,3,Ink);Block(16,21,4,3,Ink);

            }

            else if(destination=="Hotel")

            {

                Block(4,2,18,17,Ink);Block(1,19,24,4,Ink);Block(10,2,6,10,CardTone);Block(6,13,4,3,Coin);Block(16,13,4,3,Coin);

            }

            else if(destination=="Life")

            {

                Block(7,3,12,8,Ink);Block(4,11,5,7,Ink);Block(10,17,6,7,Ink);Block(18,12,5,7,Ink);Block(11,7,4,3,Coin);

            }

            else

            {

                Block(2,3,6,19,Ink);Block(10,1,6,19,Ink);Block(18,4,6,19,Ink);Block(11,10,4,4,Coin);

            }

        }

        void HotelPanel()
        {
            lastSheetName="";
            // Compact objective card is the default; expand for room/capacity details.
            bool floorChoices=app.Model.Hotel().floors.Count>1;
            float goalArea=64+12*textScale;
            float h=(compactObjective?goalArea:Mathf.Lerp(165,205,(textScale-1)*2))+(floorChoices?44:0);
            HomeTitle();
            var panel=Panel("Hotel overview",safe,Cream);
            Pin(panel,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(12,96),new Vector2(-12,96+h));
            if(wideLayout)Pin(panel,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-245,96),new Vector2(245,96+h));
            string mapName=(string)app.Model.Map()["name"];
            if(compactObjective){
                // The goal card: tap the card for hotel details, the chevron to act on the goal.
                var details=panel.gameObject.AddComponent<UnityEngine.UI.Button>();details.targetGraphic=panel.GetComponent<UnityEngine.UI.Image>();details.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");compactObjective=false;Rebuild();});
                GoalCard(panel,goalArea);
                if(app.Model.State.currentHotel==0){bool shortLabel=!wideLayout&&(textScale>1.2f||((RectTransform)safe).rect.width<380);var exploreStreet=Button(safe,shortLabel?"Main Street":"Explore Main Street",app.TownUI.Explore,Mint,14);exploreStreet.name="Explore Main Street";Pin(exploreStreet,new Vector2(0,1),new Vector2(0,1),new Vector2(0,1),new Vector2(12,-126),new Vector2(184,-78));}
                if(floorChoices){var floorChip=FloorChip(panel);Pin(floorChip,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,6),new Vector2(-10,46));}
                return;
            }
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
            if(floorChoices){var chip=FloorChip(panel);Pin(chip,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(10,-94),new Vector2(-10,-54));}
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
            Pin(copy.rectTransform,Vector2.zero,Vector2.one,Vector2.zero,new Vector2(14,62),new Vector2(-14,floorChoices?-94:-50));
            var actions=Rect("Hotel actions",panel);Pin(actions,Vector2.zero,new Vector2(1,0),Vector2.zero,new Vector2(10,8),new Vector2(-10,58));
            var row=Horizontal(actions,6,0);Button(row,"Build",()=>Navigate("Build"),Gold,14);Button(row,"Life",()=>Navigate("Life"),Mint,14);
            if(app.Model.State.pendingCoins>0)Button(row,"Collect "+Math.Floor(app.Model.State.pendingCoins).ToString("N0"),()=>{var result=app.Model.ClaimOffline();app.Report(result);if(result.success)app.Audio?.PlayEffect("collect");Rebuild();},Coral,13);
            else if(app.World.WatchedCatId>=0)Button(row,"Stop watch",()=>{app.World.StopWatching();Rebuild();},Lilac,13);
            else {var guest=app.Model.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest);if(guest!=null)Button(row,"Watch cat",()=>{app.World.WatchCat(guest.catId);Rebuild();},Lilac,13);else Button(row,"Fit hotel",()=>app.World.FitHotel(),Lilac,14);}
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
                fraction=welcome?.78f:CapPhoneSheetFraction(fraction);
                Pin(sheet,Vector2.zero,new Vector2(1,fraction),Vector2.zero,new Vector2(10,welcome?10:96),new Vector2(-10,0));
            }

            if(name!=lastSheetName)UiMotion.SlideIn(sheet);lastSheetName=name;
            var label=Text(sheet,title,18,Ink,true);

            Pin(label.rectTransform,new Vector2(0,1),Vector2.one,new Vector2(0,1),new Vector2(18,-58),new Vector2(-76,-8));

            var close=Button(sheet,"Back",()=>{if(tab=="Town")Back();else if(welcome){settings=false;Rebuild();}else Navigate("Hotel");},Gold,12);

            Pin(close,new Vector2(1,1),Vector2.one,Vector2.one,new Vector2(-66,-56),new Vector2(-10,-8));

            return Scroll(sheet,64,12);

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

            Card(content,"Animated motion","Welcome sparkles, cat movement, and little world details",state.motion?"On":"Off",()=>{app.Report(app.Model.SetSettings(state.textScale,!state.motion,state.music,state.sound));Rebuild();},Gold);

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

            activeScroll=scroll;scrollKey=settings?"Settings":tab=="Build"?"Build/"+buildMode+"/"+category:tab;

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

            var r=Panel(label,parent,color);var button=r.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=r.GetComponent<UnityEngine.UI.Image>();button.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");action();});r.gameObject.AddComponent<PressBounce>();

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

        static void Height(RectTransform r,float value){if(!r.TryGetComponent<UnityEngine.UI.LayoutElement>(out var le))le=r.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();le.minHeight=value;le.preferredHeight=value;}

        static Color Hex(string text){ColorUtility.TryParseHtmlString("#"+text,out var c);return c;}

        internal static Sprite RoundedSprite()

        {

            const int n=64;const float radius=18;var texture=new Texture2D(n,n,TextureFormat.RGBA32,false);texture.filterMode=FilterMode.Bilinear;

            for(int y=0;y<n;y++)for(int x=0;x<n;x++){float dx=Mathf.Max(radius-x,Mathf.Max(x-(n-1-radius),0)),dy=Mathf.Max(radius-y,Mathf.Max(y-(n-1-radius),0));float a=Mathf.Clamp01(radius-Mathf.Sqrt(dx*dx+dy*dy));texture.SetPixel(x,y,new Color(1,1,1,a));}

            texture.Apply();return Sprite.Create(texture,new Rect(0,0,n,n),new Vector2(.5f,.5f),100,0,SpriteMeshType.FullRect,new Vector4(20,20,20,20));

        }

    }

}
