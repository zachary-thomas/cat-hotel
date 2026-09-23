using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace Purrington.Presentation {
// Opt-in player check that sends actual mouse press/release events through VoxelWorld.ReadInput.
public sealed class FloorPickAcceptance:MonoBehaviour {
 [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
 static void Install(){if(Environment.GetCommandLineArgs().Contains("-purrington-floor-pick"))new GameObject("Floor pick acceptance").AddComponent<FloorPickAcceptance>();}
 IEnumerator Start(){
  var args=Environment.GetCommandLineArgs();string output=Application.persistentDataPath;
  for(int i=0;i<args.Length-1;i++)if(args[i]=="-purrington-floor-pick")output=Path.GetFullPath(args[i+1]);
  Directory.CreateDirectory(output);HotelApp app=null;
  while((app=FindFirstObjectByType<HotelApp>())==null||app.World==null)yield return null;
  var previous=InputSystem.settings.backgroundBehavior;InputSystem.settings.backgroundBehavior=InputSettings.BackgroundBehavior.IgnoreFocus;
  var mouse=InputSystem.AddDevice<Mouse>("Floor pick acceptance mouse");
  Screen.SetResolution(1280,800,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(1);
  app.UI.gameObject.SetActive(false);app.World.ObjectSelected-=app.UI.SelectObject;app.World.RoomSelected-=app.UI.SelectRoom;app.World.CatSelected-=app.UI.OpenCare;app.World.GroundClicked-=app.UI.GroundClicked;app.World.SetInputBlocked(false);app.World.SetWorldRect(new Rect(0,0,Screen.width,Screen.height));app.World.SetViewFloor(1);
  foreach(var pick in FindObjectsByType<WorldPick>(FindObjectsInactive.Include,FindObjectsSortMode.None)){var collider=pick.GetComponent<Collider>();if(collider)collider.enabled=false;}
  var floorOf=(Dictionary<Transform,int>)typeof(VoxelWorld).GetField("floorOf",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(app.World);
  int selected=0,rooms=0,cats=0,ground=0;string selectedId="";
  app.World.ObjectSelected+=id=>{selected++;selectedId=id;};app.World.RoomSelected+=id=>rooms++;app.World.CatSelected+=id=>cats++;app.World.GroundClicked+=p=>ground++;
  Vector2 point=new Vector2(Screen.width*.5f,Screen.height*.5f);
  var ray=app.World.WorldCamera.ScreenPointToRay(point);
  var root=new GameObject("QA ground object");root.transform.position=ray.GetPoint(5);var hit=root.AddComponent<BoxCollider>();hit.size=Vector3.one;root.AddComponent<WorldPick>().objectId="qa-ground";floorOf[root.transform]=0;Physics.SyncTransforms();
  yield return Click(mouse,point);bool groundObjectBlocked=selected==0&&ground==1;string first="selected="+selected+", cats="+cats+", ground="+ground;
  root.SetActive(false);Physics.SyncTransforms();var room=new GameObject("QA ground room");room.transform.position=ray.GetPoint(5);room.AddComponent<BoxCollider>().size=Vector3.one;room.AddComponent<WorldPick>().objectId="room:qa-ground";floorOf[room.transform]=0;Physics.SyncTransforms();
  yield return Click(mouse,point);bool groundRoomBlocked=rooms==0&&ground==2;room.SetActive(false);Physics.SyncTransforms();
  var guest=app.Model.Actors.FirstOrDefault(a=>a.kind==ActorKind.Guest&&a.floor==0);
  bool catBlocked=false;if(guest!=null){var cat=new GameObject("QA ground cat");cat.transform.position=ray.GetPoint(5);cat.AddComponent<BoxCollider>().size=Vector3.one;cat.AddComponent<WorldPick>().catId=guest.catId;Physics.SyncTransforms();yield return Click(mouse,point);catBlocked=cats==0&&ground==3;cat.SetActive(false);Physics.SyncTransforms();}string second="selected="+selected+", rooms="+rooms+", cats="+cats+", ground="+ground;
  var upper=new GameObject("QA upper object");upper.transform.position=ray.GetPoint(5);upper.AddComponent<BoxCollider>().size=Vector3.one;upper.AddComponent<WorldPick>().objectId="qa-upstairs";floorOf[upper.transform]=1;Physics.SyncTransforms();
  yield return Click(mouse,point);bool upperSelected=selected==1&&selectedId=="qa-upstairs";
  bool pass=groundObjectBlocked&&groundRoomBlocked&&catBlocked&&upperSelected;
  File.WriteAllText(Path.Combine(output,"result.txt"),(pass?"PASS":"FAIL")+": ground object blocked="+groundObjectBlocked+" ("+first+"), ground room blocked="+groundRoomBlocked+", ground cat blocked="+catBlocked+" ("+second+"), upstairs object selected="+upperSelected+" (selected="+selected+", id="+selectedId+"), ground clicks="+ground+", guest="+(guest?.id??"missing"));
  InputSystem.settings.backgroundBehavior=previous;app.ExitWithoutSaving();
 }
 static IEnumerator Click(Mouse mouse,Vector2 point){InputSystem.QueueStateEvent(mouse,new MouseState{position=point});yield return null;InputSystem.QueueStateEvent(mouse,new MouseState{position=point,buttons=1});yield return null;yield return null;InputSystem.QueueStateEvent(mouse,new MouseState{position=point});yield return null;yield return null;}
}
}
