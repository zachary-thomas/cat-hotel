using Purrington.Domain;
using System.Linq;
using UnityEngine;

namespace Purrington.Presentation {
 // Market fixtures live beyond the central crossing and appear only during an event.
 public sealed class TownSquareArt {
  public readonly Transform Root;
  public readonly Transform Market;
  public readonly TextMesh BoardText;
  readonly GodotCatRig[] shoppers;
  readonly TextMesh[] chatter;
  int seenReaction;
  float reactionLeft;
  public int KioskCount=>2;
  public bool IsMarketVisible=>Market.gameObject.activeSelf;
  public TownSquareArt(GodotGeometry geometry,Transform parent,TownContent content,HotelModel model){
   Root=MainStreetArt.Group(parent,"Town square event");
   var q=content.Point("square");float u=VoxelWorld.Unit;
   // A small arch centered over the path from the crosswalk, in the same style and letter size as the hotel's sign.
   var board=MainStreetArt.Group(Root,"Market arch");
   board.localPosition=new Vector3(q.x*u,0,(q.z-4.7f)*u);
   const string title="MARKET";float width=VoxelLetters.Width(title,MainStreetArt.SignPixel)+.4f;
   foreach(float side in new[]{-1f,1f})Box(geometry,board,"Arch post",new Vector3(side*(width/2+.08f),1.35f,0),new Vector3(.14f,2.7f,.14f),"B3824C");
   Box(geometry,board,"Signboard",new Vector3(0,2.42f,0),new Vector3(width,.62f,.1f),"425C35");
   Box(geometry,board,"Signboard trim",new Vector3(0,2.78f,0),new Vector3(width+.34f,.08f,.18f),"B3824C");
   var boardLetters=geometry.Build(board,VoxelLetters.Recipe("Market letters",title,MainStreetArt.SignPixel,.05f,"F4EAD5"));boardLetters.localPosition=new Vector3(0,2.42f,.05f);boardLetters.localScale=new Vector3(1,1,-1);
   // The status text is kept for the panel and tests but not drawn as a floating label.
   BoardText=Sign(board,"Market Day",new Vector3(0,1.65f,-.16f),.14f);BoardText.GetComponent<MeshRenderer>().enabled=false;
   Market=MainStreetArt.Group(Root,"Market Day fixtures");
   shoppers=new GodotCatRig[2];chatter=new TextMesh[2];
   for(int i=0;i<2;i++){
    int side=i==0?-1:1;float x=(q.x+side*5f)*u,z=(q.z-.5f)*u;
    var kiosk=MainStreetArt.Group(Market,"Market kiosk "+(i+1));
    Box(geometry,kiosk,"Counter",new Vector3(x,.65f,z),new Vector3(2.1f,1,.95f),"B3824C");
    foreach(float post in new[]{-.9f,.9f})Box(geometry,kiosk,"Post",new Vector3(x+post,1.5f,z),new Vector3(.12f,2.7f,.12f),"D2AD77");
    Box(geometry,kiosk,"Awning",new Vector3(x,2.75f,z),new Vector3(2.5f,.25f,1.5f),i==0?"738448":"BF7958");
    var name=geometry.Build(kiosk,VoxelLetters.Recipe(i==0?"Treats sign":"Flowers sign",i==0?"TREATS":"FLOWERS",.055f,.05f,"F4EAD5"));name.localPosition=new Vector3(x,2.75f,z+.78f);name.localScale=new Vector3(1,1,-1);
    Box(geometry,kiosk,"String light",new Vector3(x,2.48f,z-.7f),new Vector3(2.25f,.08f,.08f),"D7AE55");
    for(int bulb=0;bulb<5;bulb++)Box(geometry,kiosk,"Lantern",new Vector3(x-.9f+bulb*.45f,2.37f,z-.72f),new Vector3(.13f,.18f,.13f),"F5DA83");
    shoppers[i]=new GodotCatRig(geometry,Market,ManagerCatArt.Recipe(geometry,i==0?"cream":"ginger",i==0?"tuxedo":"tabby"),110+i);
    shoppers[i].Root.localScale=Vector3.one*.72f;
    shoppers[i].Root.localPosition=new Vector3((q.x+side*2.4f)*u,.18f,(q.z+1.2f)*u);
    shoppers[i].Root.localRotation=Quaternion.Euler(0,i==0?65:-65,0);
    var speech=MainStreetArt.Group(shoppers[i].Root,"Market conversation");speech.localPosition=new Vector3(0,2.7f,0);
    chatter[i]=Sign(speech,i==0?"Lovely day!":"Hello, friend!",Vector3.zero,.12f);
   }
   seenReaction=model.MarketDayReactionToken;
   Update(model,0,false);
  }
  static Transform Box(GodotGeometry geometry,Transform parent,string name,Vector3 at,Vector3 size,string color)=>geometry.Build(parent,ManagerCatArt.Node(name,at,size,color));
  static TextMesh Sign(Transform parent,string value,Vector3 at,float size){var node=MainStreetArt.Group(parent,value);node.localPosition=at;var text=node.gameObject.AddComponent<TextMesh>();text.text=value;text.fontSize=64;text.characterSize=size;text.anchor=TextAnchor.MiddleCenter;text.color=new Color(.98f,.96f,.89f);node.gameObject.AddComponent<VoxelBillboard>();return text;}
  public void Update(HotelModel model,float dt,bool motion){
   if(model.MarketDayReactionToken>seenReaction){seenReaction=model.MarketDayReactionToken;reactionLeft=4;}
   if(reactionLeft>0)reactionLeft=Mathf.Max(0,reactionLeft-dt);
   bool running=model.State.currentHotel==0&&model.MarketDayRemaining>0;
   Market.gameObject.SetActive(running);
   if(running){
    BoardText.text="MARKET DAY\n"+Mathf.CeilToInt(model.MarketDayRemaining)+"s left";
    for(int i=0;i<shoppers.Length;i++){if(motion)shoppers[i].Advance(dt,true,"rest",false);chatter[i].text=i==0?"Lovely day!":"Hello, friend!";}
   }else if(reactionLeft>0)BoardText.text="MARKET DAY\nWelcome, new guests!";
   else if(model.MarketDayCompleted)BoardText.text="MARKET DAY\nCompleted";
   else if(model.TownInventory.Contains("market_bundle"))BoardText.text="MARKET DAY\nReady to start";
   else BoardText.text="MARKET DAY\nVisit Paw Mart";
  }
 }
}
