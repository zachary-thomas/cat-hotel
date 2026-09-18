using System.Collections.Generic;
using UnityEngine;
namespace Purrington.Presentation
{
 public sealed class HotelAudio:MonoBehaviour
 {
  HotelApp app;readonly AudioSource[] music=new AudioSource[2],voices=new AudioSource[6];readonly Dictionary<string,AudioClip> clips=new Dictionary<string,AudioClip>();
  AudioSource purr;int hotel=-1,current,voice,meowIndex;float fade=1,lastTap=-10,meowTimer=12,coinTimer,purrFade;bool foreground=true,contact;double lastCoins,income;
  void Start(){app=GetComponent<HotelApp>();for(int i=0;i<2;i++){music[i]=gameObject.AddComponent<AudioSource>();music[i].loop=true;}for(int i=0;i<6;i++)voices[i]=gameObject.AddComponent<AudioSource>();purr=gameObject.AddComponent<AudioSource>();string[] keys={"tap","income","spend","collect","open","build","purr","toy","bell","meow0","meow1","meow2"};string[] names={"ui_tap","coin_idle","coin_spend","coin_collect","hotel_open","room_built","cat_purr","toy_rustle","dinner_bell","meow_1","meow_2","meow_3"};for(int i=0;i<keys.Length;i++)clips[keys[i]]=Resources.Load<AudioClip>("Audio/"+names[i]);}
  void Update()
  {
   if(app?.Model==null||purr==null)return;var state=app.Model.State;bool audible=foreground&&state.settings.sound;
   if(!audible){foreach(var source in voices)source.Stop();SetCareContact(false,true);}
   if(!foreground||!state.settings.music){foreach(var source in music)if(source.isPlaying)source.Pause();}
   else{if(hotel!=state.currentHotel){hotel=state.currentHotel;current=1-current;music[current].clip=Resources.Load<AudioClip>("Audio/"+(hotel%2==0?"meadow_lullaby":"seaside_waltz"));music[current].volume=0;music[current].Play();fade=0;}else if(!music[current].isPlaying&&music[current].clip)music[current].UnPause();fade=Mathf.Min(1,fade+Time.unscaledDeltaTime);music[current].volume=Mathf.Lerp(.0056f,.2f,fade);music[1-current].volume=.2f*(1-fade);if(fade>=1)music[1-current].Stop();}
   if(!contact&&purr.isPlaying){purrFade+=Time.unscaledDeltaTime;purr.volume=.4f*Mathf.Clamp01(1-purrFade/.35f);if(purrFade>=.35f)purr.Stop();}
   bool ambient=audible&&app.UI!=null&&!app.UI.IsInCare;
   if(ambient){income+=System.Math.Max(0,state.coins-lastCoins);coinTimer+=Time.unscaledDeltaTime;meowTimer-=Time.unscaledDeltaTime;if(income>=1&&coinTimer>=5.5f){PlayEffect("income");coinTimer=0;income=0;}if(meowTimer<=0){PlayEffect("meow"+(meowIndex%3));meowIndex++;meowTimer=24+(meowIndex%4)*5;}}else income=0;lastCoins=state.coins;
  }
  public void PlayEffect(string kind){if(app?.Model==null||!foreground||!app.Model.State.settings.sound||!clips.TryGetValue(kind,out var clip)||clip==null)return;if(kind=="tap"){if(Time.unscaledTime-lastTap<.07f)return;lastTap=Time.unscaledTime;}var source=voices[voice++%voices.Length];source.clip=clip;source.volume=kind=="tap"||kind=="income"?.14f:.316f;source.pitch=1+((voice%3)-1)*.035f;source.Play();}
  public void SetCareContact(bool active,bool immediate=false){if(purr==null)return;contact=active&&foreground&&app.Model.State.settings.sound;purrFade=0;if(contact){purr.loop=true;purr.volume=.4f;if(!purr.isPlaying){purr.clip=clips["purr"];if(purr.clip)purr.Play();}}else if(immediate)purr.Stop();}
  void OnApplicationFocus(bool value){foreground=value;if(!value)SetCareContact(false,true);}void OnApplicationPause(bool value){foreground=!value;if(value)SetCareContact(false,true);}
  void OnDisable(){foreach(var source in music)if(source)source.Stop();foreach(var source in voices)if(source)source.Stop();if(purr)purr.Stop();}
 }
}

