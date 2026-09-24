using System;
using System.Linq;

namespace Purrington.Domain
{
 // What the chat view shows. Serial changes whenever the cat says something new.
 public sealed class ChatOffer
 {
  public int catId;
  // Set when talking to a Meadow neighbor instead of a hotel guest.
  public string neighbor;
  public string name,line="",reaction="",tierUp="",reward="",request="";
  public bool gifted,requestReady,requestDone,rumor;
  public string[] topics=Array.Empty<string>();
  public int exchangesLeft,bondDelta,bond;
  public bool counts,busy;
  public long serial;
 }
 // Animal Crossing style chats: the manager offers three topics, the guest answers from Chatter.json and
 // friendship moves with how much it likes the topic. Only the first few chats each game day count.
 public sealed partial class HotelModel
 {
  public const int ManagerChatsPerDay=3,ChatExchanges=3;
  const float ChatTimeout=45;
  ChatOffer chat;
  float chatClock;
  string lastTopic;
  long chatSerial;
  public ChatOffer CurrentChat=>chat;
  public static int ReactionBond(string reaction)=>reaction=="love"?4:reaction=="like"?2:reaction=="dislike"?-1:1;

  string Voice(string line)=>line.Replace("{manager}",State.managerName);
  bool Dozing(Actor a)=>a.view.action=="sleep"&&(a.phase=="activity"||a.phase=="sit");

  public CommandResult BeginChat(int catId)
  {
   var gate=MeadowOnly();if(gate!=null)return gate;
   var content=ChatterContent.Current;if(content==null)return CommandResult.Fail("Chatting isn't ready yet.");
   var guest=catId>=0&&catId<State.cats.Count?GuestActor(catId):null;
   if(guest==null)return CommandResult.Fail("That cat isn't here right now.");
   var cat=State.cats[catId];
   if(!ManagerInHotel||guest.Position.floor!=ManagerPosition.floor||ManagerPosition.Distance(guest.Position)>ChatReach+.3f)return CommandResult.Fail("Walk over to "+cat.name+" first.");
   EndChatNow();
   if(guest==momentA||guest==momentB)CancelMoment();
   int day=Clock.day,used=cat.chatDay==day?cat.chatsToday:0;
   bool busy=Dozing(guest),counts=!busy&&used<ManagerChatsPerDay;
   uint hash=StableHash(day+":"+catId+":"+used+":"+chatSerial);
   chat=new ChatOffer{catId=catId,name=cat.name,busy=busy,counts=counts,bond=cat.bond,exchangesLeft=busy?0:ChatExchanges};
   chat.line=Voice(content.Pool(busy?"busy":counts?"greeting":"chattedOut",hash));
   lastTopic=null;chatClock=0;
   chat.topics=busy?Array.Empty<string>():OfferTopics(content,catId);
   chat.serial=++chatSerial;
   FaceManager(guest);guest.view.gesture=busy?"":"wave";
   Changed?.Invoke();
   return CommandResult.Ok(chat.line);
  }

  public CommandResult Talk(string topic)
  {
   if(chat==null)return CommandResult.Fail("Start a chat first.");
   if(chat.exchangesLeft<=0||!chat.topics.Contains(topic))return CommandResult.Fail("Pick one of the topics.");
   if(chat.neighbor!=null)return TalkNeighbor(topic);
   var guest=GuestActor(chat.catId);if(guest==null){EndChatNow();return CommandResult.Fail("They wandered off.");}
   var content=ChatterContent.Current;var cat=State.cats[chat.catId];
   string reaction=content.Reaction(cat.preference,topic);
   int day=Clock.day,used=cat.chatDay==day?cat.chatsToday:0,exchange=ChatExchanges-chat.exchangesLeft;
   bool first=exchange==0,counts=chat.counts;
   string line=Voice(content.Pick("guest",cat.preference,topic,reaction,StableHash(day+":"+cat.id+":"+topic+":"+used+":"+exchange)));
   int before=cat.bond;
   var r=Transaction(()=>{if(counts&&first){cat.chatDay=day;cat.chatsToday=used+1;}if(counts)cat.bond=Math.Max(0,Math.Min(100,cat.bond+ReactionBond(reaction)));},line);
   if(!r.success)return r;
   chat.exchangesLeft--;chat.line=line;chat.reaction=reaction;chat.bond=cat.bond;chat.bondDelta=cat.bond-before;
   lastTopic=topic;chatClock=0;
   chat.topics=chat.exchangesLeft>0?OfferTopics(content,cat.id):Array.Empty<string>();
   chat.serial=++chatSerial;
   FaceManager(guest);guest.view.gesture=reaction=="love"?"happy":reaction=="dislike"?"":"talk";
   r.progressChanged=chat.bondDelta!=0;
   return r;
  }

  // Bye: the guest signs off in its own speech bubble and goes back to what it was doing.
  public CommandResult EndChat()
  {
   if(chat==null)return CommandResult.Fail("No chat to end.");
   if(chat.neighbor!=null){var n=NeighborContent.Current?.Find(chat.neighbor);string bye=n==null?"":Voice(Pick(n.signoff,StableHash(chat.neighbor+":"+chatSerial)));EndChatNow();Changed?.Invoke();return CommandResult.Ok(bye);}
   var guest=GuestActor(chat.catId);var content=ChatterContent.Current;
   string line=chat.busy||content==null?"":Voice(content.Pool("signoff",StableHash(chat.catId+":"+chatSerial)));
   EndChatNow();
   if(guest!=null&&line.Length>0){guest.view.speech=line;guest.view.speechElapsed=0;guest.view.speechDuration=2.8f;guest.view.gesture="wave";}
   Changed?.Invoke();
   return CommandResult.Ok(line);
  }
  void EndChatNow()
  {
   if(chat==null)return;
   if(chat.neighbor==null){var guest=GuestActor(chat.catId);if(guest!=null)guest.view.gesture="";}
   chat=null;
  }
  string[] OfferTopics(ChatterContent content,int catId)
  {
   long serial=chatSerial;int day=Clock.day;
   return content.TopicIds.Where(t=>t!=lastTopic).OrderBy(t=>StableHash(t+":"+catId+":"+serial+":"+day)).ThenBy(t=>t,StringComparer.Ordinal).Take(3).ToArray();
  }
  void FaceManager(Actor guest)
  {
   var m=ManagerPosition;float dx=m.x-guest.view.x,dz=m.z-guest.view.z;
   if(dx*dx+dz*dz>.0001f)guest.view.facing=(float)Math.Atan2(dx,dz);
  }
  bool Chatting(Actor a)=>chat!=null&&a.view.kind==ActorKind.Guest&&a.view.catId==chat.catId;
  void AdvanceChat(float seconds)
  {
   if(chat==null)return;
   chatClock+=seconds;
   if(chat.neighbor!=null)
   {
    // The neighbor waits while you talk: its routine runs that much later today.
    neighborDelay[chat.neighbor]=(neighborDelay.TryGetValue(chat.neighbor,out float waited)?waited:0)+seconds;
    if(chatClock>ChatTimeout||!ManagerMeets(Neighbor(chat.neighbor),NeighborReach+1.5f))EndChatNow();
    return;
   }
   var guest=GuestActor(chat.catId);
   if(guest==null||chatClock>ChatTimeout||!ManagerInHotel||guest.Position.floor!=ManagerPosition.floor||guest.Position.Distance(ManagerPosition)>ChatReach+1.5f)EndChatNow();
  }
 }
}
