using System;
using System.Linq;
using Purrington.Domain;
using TMPro;
using UnityEngine;
namespace Purrington.Presentation {
 // Life play view: the manager HUD, the pie menu over a tapped guest, and the Animal Crossing style chat box.
 public sealed partial class HotelUI {
  const float TypeSpeed=45;
  int pieCat=-1;
  string pieNeighbor,giftPending,farewellName,farewellLine;
  bool giftPicker;
  float farewellUntil,foundUntil;
  string foundMessage;
  bool Found=>foundMessage!=null&&Time.unscaledTime<foundUntil;
  public void ShowFound(string message){foundMessage=message;foundUntil=Time.unscaledTime+5;app.Audio?.PlayEffect("bell");if(tab=="Life")Rebuild();else ShowNotice(message,false);}
  TextMeshProUGUI eventLabel;
  string EventLine(){
   var m=app.Model;var e=PlazaContent.Current?.Find(m.PlazaEventId);
   if(e!=null)return e.name+" · "+Mathf.CeilToInt(m.PlazaRemaining)+"s · Buzz "+m.PlazaBuzz+" ("+HotelModel.BuzzTier(m.PlazaBuzz)+")";
   if(m.MarketDayRemaining>0)return "Market Day · "+Mathf.CeilToInt(m.MarketDayRemaining)+"s left";
   return "Plaza · host an event";
  }
  // The event plan sheet: each plaza event with its hours, fee and who would come right now.
  void EventsPanel(){
   var content=Sheet("Plaza events","Host something in the square",.7f);
   var m=app.Model;
   foreach(var e in PlazaContent.Current.Events){
    string id=e.id;var can=m.CanHost(id);var coming=m.PredictAttendees(id).Select(n=>NeighborContent.Current.Find(n)?.name).ToArray();
    var topic=ChatterContent.Current?.FindTopic(e.topic)?.label??e.topic;
    var card=Info(content,e.name.ToUpperInvariant(),e.pitch+"\n"+((int)e.from/60).ToString("00")+":00–"+((int)e.to/60%24).ToString("00")+":00 · "+e.price+" Cat Coins · for cats who like "+topic+"\n"+(coming.Length>0?"Would come now: "+string.Join(", ",coming):"Nobody's free for this right now"));Height((RectTransform)card.transform.parent,196*textScale);
    Height(Button(content,can.success?"Host "+e.name:can.message,()=>{var r=m.HostEvent(id);app.Report(r);if(r.success){lifeFocus="";Navigate("Life");var walk=m.OrderManagerStreet("square");if(walk.success)app.World.FollowManager(true);}},can.success?Gold:Lilac,13),50*textScale);
   }
   Info(content,"MARKET DAY",HotelTownUI.MarketStatus(m));
   Height(Button(content,"Back to Life",()=>{lifeFocus="";Rebuild();},Mint,14),50*textScale);
  }
  public void ShowEvents(){lifeFocus="events";Navigate("Life");}
  string SpotName(string id)=>QuestContent.Current?.FindSpot(id)?.name??"outskirts";
  RectTransform pieRoot,topicRow,reactionChip;
  TextMeshProUGUI chatText,managerStatus;
  long chatShown=-1,chatBuiltFor=-2;
  float typed,reactionUntil;
  string queueShown="";
  bool LifePlay=>tab=="Life"&&lifeFocus==""&&!settings&&careCat<0&&app!=null&&app.Model.State.currentHotel==0&&!app.Model.RequiresSaveRecovery;
  public int PieCat=>pieCat;
  public bool ChatTyping=>app?.Model.CurrentChat!=null&&typed<app.Model.CurrentChat.line.Length;

  public void LifeCatTapped(int catId,Vector2 screen){if(!LifePlay||app.Model.CurrentChat!=null)return;ClosePie();pieCat=catId;Rebuild();}
  public void LifeNeighborTapped(string id,Vector2 screen){if(!LifePlay||app.Model.CurrentChat!=null)return;ClosePie();pieNeighbor=id;Rebuild();}
  public string PieNeighbor=>pieNeighbor;
  public void LifeManagerTapped(){if(!LifePlay)return;OpenManagerLook();}
  public void ManagerReachedCat(int catId,string kind){if(kind=="pet"&&tab=="Life"&&careCat<0&&!settings)OpenCare(catId);}
  void OpenManagerLook(){ExploreMainStreet();managerEditing=true;townCoat=app.Model.State.managerCoat;townMarkings=app.Model.State.managerMarkings;townName=app.Model.State.managerName;Rebuild();app.World.FocusManagerAppearance();}
  bool LifeBack(){
   if(tab!="Life"||careCat>=0||settings)return false;
   if(pieCat>=0||pieNeighbor!=null){ClosePie();Rebuild();return true;}
   if(giftPicker){giftPicker=false;Rebuild();return true;}
   if(app.Model.CurrentChat!=null){SayBye();return true;}
   if(lifeFocus.Length>0&&app.Model.State.currentHotel==0){lifeFocus="";Rebuild();return true;}
   return false;
  }
  void LeaveLife(string destination){
   ClosePie();giftPicker=false;farewellLine=null;
   if(destination!="Life"&&app.Model.CurrentChat!=null)app.Model.EndChat();
   app.Model.PauseManagerOrders(destination=="Build");
  }

  string QueueSignature(){var m=app.Model;return string.Join(",",m.ManagerOrders.Select(o=>o.kind+":"+o.catId+o.neighbor))+"|"+app.World.FollowingManager+"|"+giftPicker+"|"+m.RumorSpot+"|"+Found+"|"+m.PlazaEventActive;}
  string ManagerStatusLine()=>ManagerStatusFor(app.Model);
  public static string ManagerStatusFor(HotelModel m){
   var order=m.ManagerOrders.FirstOrDefault();
   if(order!=null&&order.kind==ManagerOrderKind.Search)return "Heading to the "+(QuestContent.Current?.FindSpot(order.neighbor)?.name??"outskirts");
   if(order!=null&&order.kind==ManagerOrderKind.ChatNeighbor)return "Off to see "+(NeighborContent.Current?.Find(order.neighbor)?.name??"a neighbor");
   if(order!=null&&order.kind!=ManagerOrderKind.Walk){string name=m.State.cats[order.catId].name;return order.kind==ManagerOrderKind.Chat?"Off to chat with "+name:order.kind==ManagerOrderKind.Pet?"Off to pet "+name:"Following "+name;}
   if(m.ManagerWalking)return m.ManagerInHotel?"On the way":"Strolling down Main Street";
   if(!m.ManagerInHotel)return "On Main Street · tap the hotel to head back";
   return "Tap the ground to walk · tap a cat to chat";
  }

  void LifeHud(){
   sheet=null;
   var chat=app.Model.CurrentChat;
   chatBuiltFor=ChatKey();queueShown=QueueSignature();
   if(chat!=null){ChatPanel(chat);return;}
   if(Farewell){ChatBox(farewellName,farewellLine,128*textScale);return;}
   giftPicker=false;
   if(Found)FoundBanner();
   bool rumor=app.Model.RumorSpot.Length>0,plaza=PlazaContent.Current!=null;
   float h=(118+(rumor?48:0)+(plaza?48:0))*textScale;
   var panel=Panel("Hotel overview",safe,Cream);
   Pin(panel,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(12,96),new Vector2(-12,96+h));
   if(wideLayout)Pin(panel,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-245,96),new Vector2(245,96+h));
   var column=Vertical(panel,6,10);
   var top=Row(column,44*textScale);top.GetComponent<UnityEngine.UI.HorizontalLayoutGroup>().childForceExpandWidth=false;
   var portrait=Rect("Manager portrait",top);var portraitSize=portrait.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();portraitSize.minWidth=portraitSize.preferredWidth=34;
   PixelIcon(portrait,"cat",26,Hex(ManagerCoatHex()));
   var words=Rect("Manager words",top);words.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=1;
   var name=Text(words,app.Model.State.managerName,15,Ink,true);Pin(name.rectTransform,new Vector2(0,.5f),Vector2.one,new Vector2(0,1),Vector2.zero,Vector2.zero);name.richText=false;
   managerStatus=Text(words,ManagerStatusLine(),11.5f,InkSoft);Pin(managerStatus.rectTransform,Vector2.zero,new Vector2(1,.5f),new Vector2(0,0),Vector2.zero,Vector2.zero);
   // Queued actions: tap one to cancel it.
   var orders=app.Model.ManagerOrders;
   for(int i=0;i<orders.Count;i++){
    int index=i;var o=orders[i];
    var chip=Panel("Queued "+o.kind,top,i==0?Mint:Lilac);var size=chip.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();size.minWidth=size.preferredWidth=40*textScale;
    var button=chip.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=chip.GetComponent<UnityEngine.UI.Image>();button.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");app.Model.CancelManagerOrder(index);Rebuild();});
    PixelIcon(chip,o.kind==ManagerOrderKind.Chat||o.kind==ManagerOrderKind.ChatNeighbor?"chat":o.kind==ManagerOrderKind.Pet?"paw":o.kind==ManagerOrderKind.Follow?"steps":"steps",22,Ink);
   }
   if(plaza){
    var row=Row(column,40*textScale);
    eventLabel=Text(row,EventLine(),13,Ink,true);eventLabel.richText=false;eventLabel.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=2;
    if(app.Model.PlazaEventActive)Button(row,"Join",()=>{var r=app.Model.OrderManagerStreet("square");if(!r.success&&!r.message.Contains("Already"))ShowNotice(r.message,false);else app.World.FollowManager(true);Rebuild();},Gold,13);
    else Button(row,"Plan",()=>{lifeFocus="events";Rebuild();},Lilac,13);
   }
   if(rumor){
    var hint=Row(column,40*textScale);
    var tag=Text(hint,"Rumor · "+SpotName(app.Model.RumorSpot),13,Ink,true);tag.gameObject.AddComponent<UnityEngine.UI.LayoutElement>().flexibleWidth=2;
    Button(hint,"Go look",()=>{var r=app.Model.OrderManagerSearch();if(!r.success)ShowNotice(r.message,false);else app.World.FollowManager(true);Rebuild();},Gold,13);
   }
   var actions=Row(column,44*textScale);
   bool following=app.World.FollowingManager;
   Button(actions,following?"Following":"Follow",()=>{app.World.FollowManager(!app.World.FollowingManager);Rebuild();},following?Mint:Lilac,13);
   Button(actions,"Main Street",()=>{app.Model.ClearManagerOrders();ExploreMainStreet();},Gold,13);
   Button(actions,"Hotel life",()=>{lifeFocus="overview";Rebuild();},Cream,13);
   if(pieCat>=0||pieNeighbor!=null)PieMenu();
  }
  string ManagerCoatHex(){var c=TownContent.Current?.CoatColor(app.Model.State.managerCoat)??"#B3824C";return c.TrimStart('#');}

  void PieMenu(){
   string name;
   (string id,string text,Action act)[] choices;
   if(pieNeighbor!=null){
    var v=app.Model.Neighbor(pieNeighbor);
    if(v==null||!v.present){ClosePie();return;}
    name=v.name;string id=pieNeighbor;
    choices=new(string,string,Action)[]{
     ("chat","Chat",()=>PieOrder(app.Model.OrderManagerNeighbor(id))),
     ("gift","Gift",()=>{giftPending=id;PieOrder(app.Model.OrderManagerNeighbor(id));}),
     ("close","Cancel",()=>{ClosePie();Rebuild();})};
   }else{
    var guest=app.Model.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest&&a.catId==pieCat);
    if(guest==null){ClosePie();return;}
    name=guest.name;int cat=pieCat;
    choices=new(string,string,Action)[]{
     ("chat","Chat",()=>PieOrder(app.Model.OrderManagerChat(cat))),
     ("paw","Pet",()=>PieOrder(app.Model.OrderManagerPet(cat))),
     ("steps","Follow",()=>PieOrder(app.Model.OrderManagerFollow(cat))),
     ("close","Cancel",()=>{ClosePie();Rebuild();})};
   }
   // A clear backdrop closes the menu without also sending the manager somewhere.
   var backdrop=Rect("Pie backdrop",safe);Stretch(backdrop);
   var catcher=backdrop.gameObject.AddComponent<UnityEngine.UI.Image>();catcher.color=Color.clear;
   var close=backdrop.gameObject.AddComponent<UnityEngine.UI.Button>();close.targetGraphic=catcher;close.onClick.AddListener(()=>{ClosePie();Rebuild();});
   pieRoot=Rect("Pie menu",safe);pieRoot.anchorMin=pieRoot.anchorMax=Vector2.zero;pieRoot.pivot=new Vector2(.5f,.5f);pieRoot.sizeDelta=Vector2.zero;
   var nameTag=Panel("Pie name",pieRoot,Ink);nameTag.anchorMin=nameTag.anchorMax=new Vector2(.5f,.5f);nameTag.sizeDelta=new Vector2(128*textScale,24*textScale);nameTag.anchoredPosition=new Vector2(0,-6);
   var label=Text(nameTag,name,12,Cream,true);label.alignment=TextAlignmentOptions.Center;label.richText=false;Stretch(label.rectTransform,4,0,4,0);
   float radius=76*textScale,bubble=54*textScale,spread=choices.Length>1?130f/(choices.Length-1):0;
   for(int i=0;i<choices.Length;i++){
    var c=choices[i];float angle=Mathf.Deg2Rad*(155-i*spread);
    var b=Panel("Pie "+c.text,pieRoot,c.id=="close"?Lilac:i==0?Mint:Cream);b.anchorMin=b.anchorMax=new Vector2(.5f,.5f);b.sizeDelta=new Vector2(bubble,bubble);
    var to=new Vector2(Mathf.Cos(angle),Mathf.Sin(angle))*radius+new Vector2(0,22*textScale);
    var button=b.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=b.GetComponent<UnityEngine.UI.Image>();var act=c.act;button.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");act();});b.gameObject.AddComponent<PressBounce>();
    var art=Rect("Icon",b);Pin(art,new Vector2(.5f,.5f),new Vector2(.5f,.5f),new Vector2(.5f,.5f),new Vector2(-14,-4),new Vector2(14,22));PixelIcon(art,c.id,28,Ink);
    var caption=Text(b,c.text,9.5f,Ink,true);caption.alignment=TextAlignmentOptions.Center;Pin(caption.rectTransform,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(0,3),new Vector2(0,17*textScale));
    b.anchoredPosition=to;
    if(app.Model.State.settings.motion){b.localScale=Vector3.zero;var target=b;Tween.Run(target,.22f,k=>{if(target){target.localScale=Vector3.one*Tween.OutBack(k);target.anchoredPosition=Vector2.LerpUnclamped(Vector2.zero,to,Tween.OutBack(k));}},null,i*.04f);}
   }
   PlacePie();
  }
  void ClosePie(){pieCat=-1;pieNeighbor=null;}
  void PieOrder(CommandResult result){ClosePie();if(!result.success){giftPending=null;ShowNotice(result.message,false);}Rebuild();}
  void PlacePie(){if(pieRoot==null)return;if(Head(pieCat,pieNeighbor,out var screen))pieRoot.position=screen;}
  bool Head(int catId,string neighbor,out Vector2 screen){screen=default;return neighbor!=null?app.World.NeighborHeadScreen(neighbor,out screen):catId>=0&&app.World.CatHeadScreen(catId,out screen);}
  float VoicePitch(ChatOffer chat)=>.82f+(chat.neighbor!=null?(int)((uint)chat.neighbor.GetHashCode()%7):chat.catId%7)*.07f;

  // The chat box: name tag, a line typed out letter by letter, then topic bubbles (and gifts, for neighbors).
  void ChatPanel(ChatOffer chat){
   bool gifts=chat.neighbor!=null&&!chat.gifted&&OwnedGifts().Length>0&&chat.exchangesLeft>0;
   bool choices=chat.topics.Length>0||giftPicker;
   float h=(choices?182:128)*textScale;
   var panel=ChatBox(chat.name,chat.line,h);
   if(!chat.counts&&!chat.busy){var note=Text(panel,"chatted out today",10,InkSoft);note.alignment=TextAlignmentOptions.Right;Pin(note.rectTransform,new Vector2(1,1),new Vector2(1,1),new Vector2(1,1),new Vector2(-170,-24),new Vector2(-14,-6));}
   topicRow=Rect("Chat topics",panel);Pin(topicRow,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(12,10),new Vector2(-12,10+(choices?80:44)*textScale));
   var layout=topicRow.gameObject.AddComponent<UnityEngine.UI.HorizontalLayoutGroup>();layout.spacing=8;layout.childControlWidth=true;layout.childControlHeight=true;layout.childForceExpandWidth=true;layout.childAlignment=TextAnchor.MiddleCenter;
   if(giftPicker){
    foreach(var g in OwnedGifts()){
     string gift=g.id;
     IconChoice(g.name+" x"+app.Model.GiftCount(g.id),"gift",Lilac,()=>{giftPicker=false;var r=app.Model.GiveGift(gift);if(!r.success){ShowNotice(r.message,false);Rebuild();}});
    }
    var back=Button(topicRow,"Back",()=>{giftPicker=false;Rebuild();},Cream,13);var backSize=back.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();backSize.flexibleWidth=.6f;
   }else{
    var content=ChatterContent.Current;
    foreach(var id in chat.topics){
     var t=content?.FindTopic(id);if(t==null)continue;string topic=id;
     IconChoice(t.label,t.icon,Lilac,()=>{var r=app.Model.Talk(topic);if(!r.success)ShowNotice(r.message,true);});
    }
    if(gifts)IconChoice("Gift","gift",Gold,()=>{giftPicker=true;Rebuild();});
    if(chat.request.Length>0&&chat.exchangesLeft>0)IconChoice(chat.requestReady?"Done!":"Favor","note",chat.requestReady?Mint:Cream,()=>{var r=app.Model.AnswerRequest();if(!r.success)ShowNotice(r.message,false);});
    var bye=Button(topicRow,chat.busy?"Let them sleep":chat.exchangesLeft>0?"Bye":"Bye!",SayBye,Mint,13);
    if(chat.topics.Length>0){var byeSize=bye.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();byeSize.flexibleWidth=.6f;}
   }
   topicRow.gameObject.SetActive(typed>=chat.line.Length);
   if(chat.tierUp.Length>0||chat.requestDone&&chat.reward.Length>0)TierBanner(chat,panel);
   if(chat.rumor){var pill=Panel("Rumor tag",panel,Coral);Pin(pill,new Vector2(0,1),new Vector2(0,1),new Vector2(0,.5f),new Vector2(16+Mathf.Max(90,chat.name.Length*11+34)*textScale+8,-2),new Vector2(16+Mathf.Max(90,chat.name.Length*11+34)*textScale+100*textScale,24*textScale-2));var pt=Text(pill,"Rumor!",12,Cream,true);pt.alignment=TextAlignmentOptions.Center;Stretch(pt.rectTransform);}
   if(chat.reaction.Length>0&&Time.unscaledTime<reactionUntil){
    reactionChip=Panel("Chat reaction",safe,CardTone);reactionChip.anchorMin=reactionChip.anchorMax=Vector2.zero;reactionChip.sizeDelta=new Vector2(74*textScale,34*textScale);
    var art=Rect("Icon",reactionChip);Pin(art,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(6,-11),new Vector2(28,11));
    PixelIcon(art,chat.reaction=="love"?"heart":chat.reaction=="like"?"sparkle":chat.reaction=="dislike"?"grump":"dots",22,chat.reaction=="love"?Coral:chat.reaction=="dislike"?Ink:LeafText);
    var delta=Text(reactionChip,chat.bondDelta==0?"·":(chat.bondDelta>0?"+":"")+chat.bondDelta,13,chat.bondDelta<0?Coral:LeafText,true);Pin(delta.rectTransform,new Vector2(0,0),Vector2.one,new Vector2(0,.5f),new Vector2(32,0),new Vector2(-6,0));
    if(app.Model.State.settings.motion){var chip=reactionChip;chip.localScale=Vector3.zero;Tween.Run(chip,.3f,k=>{if(chip)chip.localScale=Vector3.one*Tween.OutBack(k);});}
    PlaceReaction(chat);
   }else reactionChip=null;
  }
  RectTransform ChatBox(string name,string line,float h){
   var panel=Panel("Hotel overview",safe,Cream);
   Pin(panel,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(12,96),new Vector2(-12,96+h));
   if(wideLayout)Pin(panel,new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(.5f,0),new Vector2(-260,96),new Vector2(260,96+h));
   // Tapping the box finishes the line at once.
   var skip=panel.gameObject.AddComponent<UnityEngine.UI.Button>();skip.targetGraphic=panel.GetComponent<UnityEngine.UI.Image>();skip.transition=UnityEngine.UI.Selectable.Transition.None;skip.onClick.AddListener(()=>typed=line.Length);
   var tag=Panel("Chat name",panel,Gold);Pin(tag,new Vector2(0,1),new Vector2(0,1),new Vector2(0,.5f),new Vector2(16,-2),new Vector2(16+Mathf.Max(90,name.Length*11+34)*textScale,26*textScale-2));
   var who=Text(tag,name,13,Ink,true);who.alignment=TextAlignmentOptions.Center;who.richText=false;Stretch(who.rectTransform,6,0,6,0);
   chatText=Text(panel,line,17,Ink);chatText.richText=false;chatText.verticalAlignment=VerticalAlignmentOptions.Top;chatText.overflowMode=TextOverflowModes.Overflow;
   Pin(chatText.rectTransform,new Vector2(0,1),new Vector2(1,1),new Vector2(.5f,1),new Vector2(18,-26-62*textScale),new Vector2(-18,-26));
   chatText.maxVisibleCharacters=(int)typed;
   return panel;
  }
  void IconChoice(string label,string icon,Color tone,Action act){
   var b=Panel("Choice "+label,topicRow,tone);var button=b.gameObject.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=b.GetComponent<UnityEngine.UI.Image>();b.gameObject.AddComponent<PressBounce>();
   button.onClick.AddListener(()=>{app.Audio?.PlayEffect("tap");act();});
   var art=Rect("Icon",b);Pin(art,new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(-17,-44*textScale),new Vector2(17,-10*textScale));PixelIcon(art,icon,34,Ink);
   var caption=Text(b,label,label.Length>12?10:12,Ink,true);caption.alignment=TextAlignmentOptions.Center;caption.richText=false;Pin(caption.rectTransform,Vector2.zero,new Vector2(1,0),new Vector2(.5f,0),new Vector2(2,4),new Vector2(-2,24*textScale));
  }
  NeighborContent.Gift[] OwnedGifts()=>NeighborContent.Current?.Gifts.Where(g=>app.Model.GiftCount(g.id)>0).ToArray()??new NeighborContent.Gift[0];
  // A new friendship tier: the tier name and what the neighbor gave you, above the chat box.
  void TierBanner(ChatOffer chat,RectTransform box){
   int tier=Mathf.Clamp(app.Model.NeighborData(chat.neighbor??"").tier,0,3);
   var banner=Panel("Friendship banner",safe,Gold);banner.anchorMin=banner.anchorMax=new Vector2(.5f,0);banner.pivot=new Vector2(.5f,0);
   banner.sizeDelta=new Vector2(wideLayout?500:Mathf.Max(260,((RectTransform)safe).rect.width-24),64*textScale);banner.anchoredPosition=new Vector2(0,box.offsetMax.y+36*textScale);
   var art=Rect("Icon",banner);Pin(art,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(10,-15),new Vector2(40,15));PixelIcon(art,"heart",28,Ink);
   var text=Text(banner,(chat.tierUp.Length>0?HotelModel.TierNames[tier]+"!  ":"Favor done!  ")+chat.reward,13,Ink,true);text.richText=false;Stretch(text.rectTransform,50,6,10,6);
   if(app.Model.State.settings.motion){banner.localScale=Vector3.zero;Tween.Run(banner,.35f,k=>{if(banner)banner.localScale=Vector3.one*Tween.OutBack(k);},null,.4f);}
  }
  void FoundBanner(){
   var banner=Panel("Found banner",safe,Gold);Pin(banner,new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(.5f,1),new Vector2(-230,-190*textScale),new Vector2(230,-110));
   var art=Rect("Icon",banner);Pin(art,new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(0,.5f),new Vector2(12,-16),new Vector2(44,16));PixelIcon(art,"sparkle",30,Ink);
   var text=Text(banner,foundMessage,14,Ink,true);text.richText=false;Stretch(text.rectTransform,56,8,12,8);
   if(app.Model.State.settings.motion){banner.localScale=Vector3.zero;Tween.Run(banner,.35f,k=>{if(banner)banner.localScale=Vector3.one*Tween.OutBack(k);});}
  }
  void PlaceReaction(ChatOffer chat){if(reactionChip!=null&&Head(chat.catId,chat.neighbor,out var screen))reactionChip.position=screen+new Vector2(0,26*canvas.scaleFactor);}
  // Bye: the cat's sign-off stays in the box for a moment before it closes.
  void SayBye(){
   var chat=app.Model.CurrentChat;if(chat==null)return;
   string name=chat.name;giftPicker=false;var r=app.Model.EndChat();
   if(r.success&&r.message.Length>0){farewellName=name;farewellLine=r.message;farewellUntil=Time.unscaledTime+2.4f;typed=0;}
   Rebuild();
  }
  bool Farewell=>farewellLine!=null&&Time.unscaledTime<farewellUntil;
  long ChatKey(){var chat=app.Model.CurrentChat;return chat!=null?chat.serial:Farewell?-3:-1;}

  // Called every frame from Update: opens and closes the chat box, types the line out, and keeps menus over their cats.
  void UpdateLife(){
   if(app?.Model==null||app.World==null)return;
   bool play=LifePlay;
   app.World.SetLifeControl(play&&!IsPlacing&&!welcome);
   if(!play)return;
   var chat=app.Model.CurrentChat;
   if(chat!=null&&chat.serial!=chatShown){
    bool opened=chatShown<0;
    chatShown=chat.serial;typed=0;farewellLine=null;
    if(opened&&chat.neighbor!=null&&giftPending==chat.neighbor){giftPending=null;if(OwnedGifts().Length>0)giftPicker=true;else ShowNotice("Paw Mart sells gifts for your neighbors.",false);}
    if(chat.reaction.Length>0){
     reactionUntil=Time.unscaledTime+2.4f;
     if(chat.neighbor!=null)app.World.NeighborReaction(chat.neighbor,chat.reaction);else app.World.ChatReaction(chat.catId,chat.reaction);
     if(chat.reaction=="love"||chat.tierUp.Length>0)app.Audio?.PlayEffect("bell");
    }
   }
   if(chat==null)chatShown=-1;
   if(ChatKey()!=chatBuiltFor){if(chat!=null)ClosePie();Rebuild();return;}
   if(QueueSignature()!=queueShown){Rebuild();return;}
   string line=chat!=null?chat.line:Farewell?farewellLine:null;
   if(line!=null&&chatText!=null){
    if(typed<line.Length){
     int before=(int)typed;typed=Mathf.Min(line.Length,typed+Time.unscaledDeltaTime*TypeSpeed);
     float pitch=chat!=null?VoicePitch(chat):.9f;
     for(int i=before;i<(int)typed;i++)if(char.IsLetterOrDigit(line[i])){app.Audio?.Blip(pitch+(i%3)*.03f);break;}
    }
    chatText.maxVisibleCharacters=(int)typed;
    if(chat!=null&&topicRow&&topicRow.gameObject.activeSelf!=(typed>=line.Length))topicRow.gameObject.SetActive(typed>=line.Length);
    if(chat!=null&&reactionChip!=null){if(Time.unscaledTime>=reactionUntil){Destroy(reactionChip.gameObject);reactionChip=null;}else PlaceReaction(chat);}
   }
   if(pieCat>=0||pieNeighbor!=null){
    bool gone=pieNeighbor!=null?!(app.Model.Neighbor(pieNeighbor)?.present??false):!app.Model.Actors.Any(a=>a.kind==ActorKind.Guest&&a.catId==pieCat);
    if(gone){ClosePie();Rebuild();return;}
    PlacePie();
   }
   if(managerStatus!=null){string status=ManagerStatusLine();if(managerStatus.text!=status)managerStatus.text=status;}
   if(eventLabel!=null){string plazaLine=EventLine();if(eventLabel.text!=plazaLine)eventLabel.text=plazaLine;}
  }

  public static readonly string[] PixelIconIds={"fish","moon","yarn","bubble","chat","sun","house","paw","steps","close","heart","sparkle","dots","grump","cat","gift","note"};
  // Tiny pixel-block icons in the same style as the navigation bar, drawn on a 26 x 26 grid.
  void PixelIcon(RectTransform parent,string id,float size,Color ink){
   var icon=Rect(id+" icon",parent);icon.anchorMin=icon.anchorMax=icon.pivot=new Vector2(.5f,.5f);icon.sizeDelta=new Vector2(26,26);icon.localScale=Vector3.one*(size/26f)*textScale;
   void B(float x,float y,float w,float h,Color c){var part=Rect("Block",icon);part.anchorMin=part.anchorMax=Vector2.zero;part.pivot=Vector2.zero;part.anchoredPosition=new Vector2(x,y);part.sizeDelta=new Vector2(w,h);var image=part.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=c;image.raycastTarget=false;}
   switch(id){
    case "fish":B(4,9,14,9,ink);B(2,11,2,5,ink);B(18,11,3,5,ink);B(21,8,3,4,ink);B(21,15,3,4,ink);B(7,13,2,2,Cream);B(12,10,4,1,Coin);break;
    case "moon":B(7,4,6,18,ink);B(5,7,2,12,ink);B(13,4,4,3,ink);B(13,19,4,3,ink);B(17,15,6,2,Coin);B(21,17,2,2,Coin);B(17,19,6,2,Coin);break;
    case "yarn":B(6,5,14,14,Coral);B(4,8,2,8,Coral);B(20,8,2,8,Coral);B(9,3,8,2,Coral);B(9,19,8,2,Coral);B(8,9,10,2,Cream);B(8,13,10,2,Cream);B(20,2,4,2,ink);B(22,4,2,4,ink);break;
    case "bubble":case "chat":B(3,8,20,13,ink);B(5,6,16,2,ink);B(5,21,16,2,ink);B(6,3,4,5,ink);B(7,13,3,3,Coin);B(12,13,3,3,Coin);B(17,13,3,3,Coin);break;
    case "sun":B(8,8,10,10,Coin);B(12,2,2,4,Coin);B(12,20,2,4,Coin);B(2,12,4,2,Coin);B(20,12,4,2,Coin);B(4,4,3,3,Coin);B(19,4,3,3,Coin);B(4,19,3,3,Coin);B(19,19,3,3,Coin);B(11,11,4,4,ink);break;
    case "house":B(5,3,16,11,ink);B(3,14,20,3,ink);B(6,17,14,3,ink);B(9,20,8,3,ink);B(11,3,4,6,Coin);B(7,9,3,3,Cream);B(16,9,3,3,Cream);break;
    case "paw":B(8,3,10,9,ink);B(6,5,2,5,ink);B(18,5,2,5,ink);B(4,13,4,5,ink);B(9,16,4,6,ink);B(14,16,4,6,ink);B(19,13,4,5,ink);break;
    case "steps":B(4,4,5,7,ink);B(4,12,5,3,ink);B(14,11,5,7,ink);B(14,19,5,3,ink);break;
    case "close":B(5,5,4,4,ink);B(9,9,4,4,ink);B(13,13,4,4,ink);B(17,17,4,4,ink);B(17,5,4,4,ink);B(13,9,4,4,ink);B(9,13,4,4,ink);B(5,17,4,4,ink);break;
    case "heart":B(4,12,8,8,ink);B(14,12,8,8,ink);B(6,8,14,6,ink);B(9,5,8,3,ink);B(12,3,2,2,ink);break;
    case "sparkle":B(11,3,4,20,ink);B(3,11,20,4,ink);B(9,9,8,8,ink);B(19,19,3,3,Coin);break;
    case "dots":B(3,11,4,4,ink);B(11,11,4,4,ink);B(19,11,4,4,ink);break;
    case "grump":B(4,14,5,3,Coral);B(9,17,3,5,Coral);B(17,14,5,3,Coral);B(14,17,3,5,Coral);B(4,9,5,3,Coral);B(9,4,3,5,Coral);B(17,9,5,3,Coral);B(14,4,3,5,Coral);break;
    case "cat":B(3,3,20,15,ink);B(3,18,6,6,ink);B(17,18,6,6,ink);B(7,11,3,3,Ink);B(16,11,3,3,Ink);B(12,6,3,2,Coral);break;
    case "note":B(5,3,16,20,Cream);B(5,3,16,2,ink);B(5,21,16,2,ink);B(5,3,2,20,ink);B(19,3,2,20,ink);B(8,16,10,2,ink);B(8,12,10,2,ink);B(8,8,7,2,ink);B(16,5,6,6,Coral);break;
    case "gift":B(4,3,18,12,Coral);B(3,15,20,4,Coral);B(12,3,3,16,Coin);B(3,16,20,2,Coin);B(8,19,4,4,Coin);B(14,19,4,4,Coin);break;
    default:B(6,6,14,14,ink);break;
   }
  }
 }
}
