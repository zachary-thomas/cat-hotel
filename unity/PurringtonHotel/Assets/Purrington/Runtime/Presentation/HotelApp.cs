using System;

using System.IO;

using Purrington.Domain;

using UnityEngine;

using UnityEngine.EventSystems;

using UnityEngine.InputSystem.UI;

namespace Purrington.Presentation

{

 // Compatibility for older editor fixtures; dictionary state requires Newtonsoft.

 public sealed class UnitySaveCodec:ISaveCodec

 {

  readonly NewtonsoftSaveCodec codec=new NewtonsoftSaveCodec();

  public string Serialize(HotelState state)=>codec.Serialize(state);

  public HotelState Deserialize(string json)=>codec.Deserialize(json);

 }

 public sealed class HotelApp:MonoBehaviour

 {

  public HotelModel Model{get;private set;}public VoxelWorld World{get;private set;}public HotelUI UI{get;private set;}public HotelAudio Audio{get;private set;}

  public string LastMessage{get;private set;}="Welcome to your little corner of Purrington.";public event Action<string> Notice;

  float autosave;string saveRoot,initializationError="";bool allowQuit;

  void Awake()

  {

   Application.targetFrameRate=60;Application.wantsToQuit+=WantsToQuit;

   if(FindFirstObjectByType<EventSystem>()==null)new GameObject("UI Event System",typeof(EventSystem),typeof(InputSystemUIInputModule));

   saveRoot=Application.persistentDataPath;var args=Environment.GetCommandLineArgs();for(int i=0;i<args.Length-1;i++)if(args[i]=="-purrington-profile")saveRoot=Path.GetFullPath(args[i+1]);

   InitializeProfile();

  }

  void InitializeProfile()

  {

   if(!ParityProfile.TryOpen(saveRoot,out var profile,out initializationError))return;

   try

   {

    var manifest=Resources.Load<TextAsset>("Content/GodotReference");if(manifest==null)throw new InvalidOperationException("The complete hotel content is missing.");

    var content=ParityContent.LoadJson(manifest.text);var wardrobe=Resources.Load<TextAsset>("Content/Wardrobe");if(wardrobe==null)throw new InvalidOperationException("The wardrobe content is missing.");Wardrobe.LoadJson(wardrobe.text);Model=new HotelModel(new JournalSaveStore(Path.Combine(profile,"hotel"),new NewtonsoftSaveCodec()),content);var loaded=Model.LoadOrCreate();

    World=new GameObject("Voxel Hotel").AddComponent<VoxelWorld>();World.Initialize(Model);

    UI=new GameObject("Mobile Interface").AddComponent<HotelUI>();UI.Initialize(this);World.CatSelected+=UI.OpenCare;World.GroundClicked+=UI.GroundClicked;World.ObjectSelected+=UI.SelectObject;World.RoomSelected+=UI.SelectRoom;World.GroundDragged+=UI.GroundDragged;World.GroundDragEnded+=UI.GroundDragEnded;

    Audio=GetComponent<HotelAudio>()??gameObject.AddComponent<HotelAudio>();

    World.SetCutaway(!Model.State.settings.exterior);World.SetEvening(Model.State.settings.evening);Report(loaded);if(loaded.success)Report(Model.Reconcile(DateTimeOffset.UtcNow.ToUnixTimeSeconds()),false);initializationError="";

   }

   catch(Exception ex){Debug.LogException(ex);initializationError="Couldn't open the hotel safely. "+ex.Message;if(UI){UI.gameObject.SetActive(false);Destroy(UI.gameObject);}if(World){World.gameObject.SetActive(false);Destroy(World.gameObject);}UI=null;World=null;Model=null;}

  }

  void OnGUI(){if(initializationError.Length==0)return;GUI.Box(new Rect(20,20,Mathf.Min(Screen.width-40,520),180),initializationError);if(GUI.Button(new Rect(40,140,160,44),"Retry opening hotel"))InitializeProfile();}

  void Update(){if(Model==null)return;Model.Tick(Time.deltaTime);autosave+=Time.deltaTime;if(autosave>=30){autosave=0;Report(Model.Save(),false);}}

  public void Report(CommandResult result,bool showSuccess=true){if(result.success&&!showSuccess){UI?.ClearSaveFailure();return;}LastMessage=result.message;Notice?.Invoke(LastMessage);UI?.ShowNotice(LastMessage,!result.success);}

  public void RetrySave(){if(Model==null){InitializeProfile();return;}Report(Model.RetrySave());}

  public void RequestExit(){if(Model==null){ExitWithoutSaving();return;}var result=Model.Save();Report(result,false);if(result.success)ExitWithoutSaving();else UI.ExitFailed();}

  public void ExitWithoutSaving(){allowQuit=true;Application.Quit();}

  bool WantsToQuit(){if(allowQuit)return true;if(Model==null)return true;var result=Model.Save();if(result.success)return true;Report(result);UI.ExitFailed();return false;}

  void OnApplicationPause(bool paused){if(Model==null)return;if(paused)Report(Model.Save(),false);else Model.Reconcile(DateTimeOffset.UtcNow.ToUnixTimeSeconds());}

  void OnApplicationFocus(bool focused){if(!focused&&Model!=null)Report(Model.Save(),false);}

  void OnDestroy(){Application.wantsToQuit-=WantsToQuit;}

 }

}

