using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
namespace Purrington.Presentation {
 public sealed partial class ParityInputAcceptance {
  IEnumerator MainStreetAcceptance(){
   deadline=Time.realtimeSinceStartup+1800;
   if(Environment.GetCommandLineArgs().Contains("-purrington-art-matrix")){yield return MainStreetArtMatrix();yield return WardrobeArtCaptures();yield break;}
   if(Environment.GetCommandLineArgs().Contains("-purrington-wardrobe-only")){yield return WardrobeArtCaptures();yield break;}
   if(Environment.GetCommandLineArgs().Contains("-purrington-legacy")){var legacy=JObject.FromObject(app.Model.State);foreach(string key in new[]{"managerName","managerCoat","managerMarkings","managerOutfit","wardrobe"})legacy.Remove(key);foreach(var hotel in legacy["hotels"])((JObject)hotel).Remove("town");foreach(var cat in legacy["cats"])((JObject)cat).Remove("outfit");if(!app.Model.RestoreJson(legacy.ToString()))throw new InvalidOperationException("Legacy fixture did not load");}
   foreach(var size in new[]{new Vector2Int(360,640),new Vector2Int(390,844),new Vector2Int(430,932),new Vector2Int(1280,800)}.Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-desktop-only")||v.x==1280).Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-legacy")||v.x==390))foreach(float scale in new[]{1f,1.5f}.Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-legacy")||v==1)){
    caseName=size.x+"x"+size.y+"-text"+(int)(scale*100);checks=new JArray();current=new JObject{{"case",caseName},{"checks",checks}};cases.Add(current);
    Screen.SetResolution(size.x,size.y,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(.6f);
    Check("requested viewport",Screen.width==size.x&&Screen.height==size.y);
    var safe=new Rect(8,16,Screen.width-16,Screen.height-40);app.UI.ConfigureAcceptanceLayout(safe,scale);yield return Frames(3);
    app.UI.Navigate("Hotel");yield return Frames(3);
    // An isolated economy fixture keeps every matrix case independently purchasable.
    app.Model.State.coins=10000;
    yield return MainStreetInput(safe);
    app.Model.SendManager("hotel_gate");app.Model.SkipManagerTravel();
    yield return Click("Build","Navigation");yield return Click("Rooms");yield return Click(null,"Guest room");
    Check("placement fixture is really active",app.UI.IsPlacing);
    // There is no Explore button during placement: invoke the public navigation boundary.
    app.UI.ExploreMainStreet();yield return Frames(3);Check("Explore cancels active placement",app.World.IsTownMode&&!app.UI.IsPlacing);
    yield return Click("Manager");
    var field=app.UI.GetComponentInChildren<TMPro.TMP_InputField>();
    if(field){yield return MouseGesture(HotelUI.ScreenBounds((RectTransform)field.transform).center,HotelUI.ScreenBounds((RectTransform)field.transform).center,.07f);field.text="Maple";}
    yield return Click("Rename");yield return Click("Save look");Check("rename persisted",app.Model.State.managerName=="Maple");
    yield return Click("Paw Mart");yield return Click("Skip walk");yield return Frames(4);
    Check("Paw Mart entered",app.World.StoreInterior.ActiveStoreId=="paw_mart");yield return new WaitForSecondsRealtime(5.2f);yield return Screenshot("paw-mart-entry");
    yield return Click("Meet Miso");yield return new WaitForSecondsRealtime(3.4f);Check("cashier arrival opens conversation",app.World.StoreInterior.IsConversationOpen);CheckLayout(safe);yield return Screenshot("paw-mart-cashier");
    yield return Click("Talk");yield return Screenshot("paw-mart-talk");yield return Click("Back to Miso");
    yield return Click("Quest");if(!app.Model.TownQuestAccepted("welcome_picnic"))yield return Click("Accept quest");yield return Click("Back to Miso");
    yield return Click("Buy");
    if(!app.Model.TownInventory.Contains("welcome_basket")){yield return BlockedClick("Buy Welcome Basket");yield return Click("Buy Welcome Basket");yield return Screenshot("cart-push");yield return new WaitForSecondsRealtime(6);yield return Screenshot("cart-park");}
    if(!app.Model.TownInventory.Contains("market_bundle")){yield return BlockedClick("Buy Market Day bundle");yield return Click("Buy Market Day bundle");}
    yield return Click("Back to Miso");yield return Click("Quest");if(!app.Model.TownQuestCompleted("welcome_picnic")){yield return BlockedClick("Complete quest");yield return Click("Complete quest");}yield return Click("Back to Miso");yield return Click("Leave");
    Check("Leave returns outdoors",app.World.ActiveStoreInteriorCount==0);
    yield return Click("Clothing");yield return Click("Skip walk");yield return Frames(4);Check("boutique entered",app.World.StoreInterior.ActiveStoreId=="clothing");yield return new WaitForSecondsRealtime(5.2f);yield return Screenshot("boutique-entry");
    yield return Click("Meet Clover");yield return new WaitForSecondsRealtime(3.4f);CheckLayout(safe);yield return Screenshot("boutique-cashier");
    yield return Click("Quest");if(!app.Model.TownQuestAccepted("first_look")){yield return BlockedClick("Accept quest");yield return Click("Accept quest");}if(!app.Model.TownQuestCompleted("first_look"))yield return Click("Equip store ribbon");Check("First Look complete",app.Model.TownQuestCompleted("first_look"));yield return Click("Back to Clover");
    yield return Click("Buy");yield return Click("head");yield return Click("Try on");yield return Frames(3);Check("boutique try-on active",app.World.StoreInterior.IsTryingOn);yield return Screenshot("boutique-try-on");
    if(!app.Model.OwnsWear("sun_hat")){yield return BlockedClick("Buy");yield return Click("Buy");}yield return Click("Wear");Check("manager wears purchased hat",app.Model.State.managerOutfit.TryGetValue("head",out var hat)&&hat=="sun_hat");
    yield return Click("Back to Clover");yield return Click("Leave");yield return Click("Square");yield return Click("Skip walk");yield return Click("Fit street");yield return Screenshot("market-quiet");
    if(app.Model.TownInventory.Contains("market_bundle")){yield return BlockedClick("Start Market Day");yield return Click("Start Market Day");}Check("market running",app.Model.MarketDayRemaining>0);yield return Screenshot("market-running");
    var timings=new List<float>();for(int i=0;i<60;i++){yield return null;timings.Add(Time.unscaledDeltaTime*1000);}
    current["marketAverageFrameMs"]=timings.Average();current["marketWorstFrameMs"]=timings.Max();
    Check("active market save",app.Model.Save().success);
    // Reload through the real journal in a second model; do not overwrite the active app model.
    var args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-purrington-profile");
    if(at>=0&&ParityProfile.TryOpen(args[at+1],out var profile,out var error)){
     var reload=new HotelModel(new JournalSaveStore(System.IO.Path.Combine(profile,"hotel"),new NewtonsoftSaveCodec()),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
     Check("journal reload",reload.LoadOrCreate().success);Check("journal keeps manager and wardrobe",reload.State.managerName=="Maple"&&reload.State.managerOutfit.ContainsKey("head"));Check("journal resumes market",reload.MarketDayRemaining>0);
    }
    // Fast-forward only the event clock for an ended-state capture; label as fixture.
    app.Model.Tick(95);yield return Frames(3);Check("market completes",app.Model.MarketDayCompleted&&app.Model.MarketDayRemaining==0);yield return Screenshot("market-ended-fixture");
    yield return Click("Back to Hotel");Check("return to hotel",app.UI.ActiveTab=="Hotel"&&!app.World.IsTownMode);
   }
   if(!Environment.GetCommandLineArgs().Contains("-purrington-input-only"))yield return WardrobeArtCaptures();
  }
  Texture2D CaptureOffscreen(){
   var camera=app.World.WorldCamera;var canvas=app.UI.GetComponent<Canvas>();
   var mode=canvas.renderMode;var priorCamera=canvas.worldCamera;float distance=canvas.planeDistance;
   var target=new RenderTexture(Screen.width,Screen.height,24,RenderTextureFormat.ARGB32);var previous=RenderTexture.active;
   try{
    canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;Canvas.ForceUpdateCanvases();
    UnityEngine.Rendering.RenderPipeline.SubmitRenderRequest(camera,new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest{destination=target});
    RenderTexture.active=target;var result=new Texture2D(Screen.width,Screen.height,TextureFormat.RGB24,false);result.ReadPixels(new Rect(0,0,Screen.width,Screen.height),0,0);result.Apply();return result;
   }finally{RenderTexture.active=previous;canvas.renderMode=mode;canvas.worldCamera=priorCamera;canvas.planeDistance=distance;target.Release();Destroy(target);Canvas.ForceUpdateCanvases();}
  }
  IEnumerator MainStreetArtMatrix(){
   foreach(var size in new[]{new Vector2Int(360,640),new Vector2Int(390,844),new Vector2Int(430,932),new Vector2Int(1280,800)}.Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-desktop-only")||v.x==1280).Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-legacy")||v.x==390))foreach(float scale in new[]{1f,1.5f}.Where(v=>!Environment.GetCommandLineArgs().Contains("-purrington-legacy")||v==1)){
    caseName=size.x+"x"+size.y+"-text"+(int)(scale*100);checks=new JArray();current=new JObject{{"case",caseName},{"checks",checks},{"setup","Programmatic art fixtures; same world and UI; URP offscreen render for hidden-window reliability"}};cases.Add(current);
    Screen.SetResolution(size.x,size.y,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(.6f);app.UI.ConfigureAcceptanceLayout(new Rect(8,16,Screen.width-16,Screen.height-40),scale);
    app.enabled=false;app.Model.State.coins=10000;app.UI.ExploreMainStreet();app.World.ExitStoreInterior();app.Model.SendManager("square");app.Model.SkipManagerTravel();app.UI.ExploreMainStreet();app.World.FitTown();yield return new WaitForSecondsRealtime(5.2f);yield return Screenshot("exterior-quiet");
    app.Model.SendManager("paw_mart_door");app.Model.SkipManagerTravel();yield return Frames(4);yield return Screenshot("paw-mart-entry");
    app.World.SelectStoreCashier();app.World.StoreInterior.Advance(30,true);yield return Frames(4);yield return Screenshot("paw-mart-cashier");
    app.World.StoreInterior.StartPurchaseRoutine("welcome_basket");app.World.StoreInterior.Advance(.5f,true);yield return Frames(2);yield return Screenshot("cart-push");
    app.World.StoreInterior.Advance(30,true);yield return Frames(2);yield return Screenshot("cart-park");
    app.World.ExitStoreInterior();app.Model.SendManager("clothing_door");app.Model.SkipManagerTravel();yield return Frames(4);yield return Screenshot("boutique-entry");
    app.World.SelectStoreCashier();app.World.StoreInterior.Advance(30,true);yield return Frames(4);yield return Screenshot("boutique-cashier");
    app.World.StoreInterior.PreviewClothing(-1,"honey","solid",new Dictionary<string,string>{{"neck","store_ribbon"}},"sun_hat");yield return Frames(3);yield return Screenshot("boutique-outfit");
    app.World.ExitStoreInterior();app.Model.SendManager("square");app.Model.SkipManagerTravel();app.Model.BuyTownItem("market_bundle");app.Model.StartMarketDay();app.UI.ExploreMainStreet();app.World.FitTown();yield return Frames(4);yield return Screenshot("market-running");
    app.Model.Tick(95);app.UI.ExploreMainStreet();app.World.FitTown();yield return Frames(4);yield return Screenshot("market-ended");app.UI.Navigate("Hotel");app.enabled=true;
   }
  }
  IEnumerator BlockedClick(string label){
   var args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-purrington-profile");
   if(at<0)yield break;
   ParityProfile.TryOpen(args[at+1],out var profile,out var error);
   string path=System.IO.Path.Combine(profile,"hotel");
   app.enabled=false;string before=Newtonsoft.Json.JsonConvert.SerializeObject(app.Model.State);
   using(var first=new System.IO.FileStream(path+".0.save.tmp",System.IO.FileMode.OpenOrCreate,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None))
   using(var second=new System.IO.FileStream(path+".1.save.tmp",System.IO.FileMode.OpenOrCreate,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None)){
    yield return Click(label);
    Check("blocked journal: "+label,app.LastMessage.StartsWith("Couldn't save")&&Newtonsoft.Json.JsonConvert.SerializeObject(app.Model.State)==before,app.LastMessage);
   }
   yield return Click("Retry");app.enabled=true;
  }
  IEnumerator WardrobeArtCaptures(){
   caseName="wardrobe-390x844";checks=new JArray();current=new JObject{{"case",caseName},{"checks",checks}};cases.Add(current);
   Screen.SetResolution(390,844,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(.6f);app.UI.ConfigureAcceptanceLayout(new Rect(0,0,390,844),1);
   // Current roster recipes share one size; use explicit scale fixtures, not fictional roster ages.
   var ids=new[]{1,0,2};var rigScales=new[]{.75f,1f,1.25f};current["catIds"]=new JArray(ids);current["sizeFixtures"]=new JArray(rigScales);
   for(int sample=0;sample<ids.Length;sample++){
    int id=ids[sample];app.Model.State.cats.First(c=>c.id==id).known=true;app.UI.OpenCare(id);yield return Frames(3);
    var rig=(GodotCatRig)typeof(VoxelWorld).GetField("careRig",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(app.World);rig.Root.localScale=Vector3.one*1.3f*rigScales[sample];app.World.enabled=false;
    foreach(var wear in Wardrobe.All){rig.Root.localRotation=Quaternion.Euler(0,wear.slot=="back"?160:0,0);app.World.PreviewOutfit(new Dictionary<string,string>{{wear.slot,wear.id}});yield return Frames(2);yield return Screenshot("sample"+sample+"-cat"+id+"-"+wear.id);}app.World.enabled=true;
    app.UI.Back();
   }
   foreach(var id in new[]{"sun_hat","bow_tie","beanie","bandana","sailor_cap","raincoat"})app.Model.BuyWear(id);
   app.Model.Dress(0,"head","sun_hat");app.Model.Dress(0,"neck","bow_tie");app.Model.Dress(1,"head","beanie");app.Model.Dress(1,"neck","bandana");app.Model.Dress(2,"head","sailor_cap");app.Model.Dress(2,"back","raincoat");
   Check("dressed roster saved",app.Model.Save().success);
   var args=Environment.GetCommandLineArgs();int profileAt=Array.IndexOf(args,"-purrington-profile");ParityProfile.TryOpen(args[profileAt+1],out var profile,out var error);
   var reload=new HotelModel(new JournalSaveStore(System.IO.Path.Combine(profile,"hotel"),new NewtonsoftSaveCodec()),ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
   Check("dressed roster reload",reload.LoadOrCreate().success&&Enumerable.Range(0,3).All(id=>CatOutfitView.Signature(reload.State.cats[id].outfit)==CatOutfitView.Signature(app.Model.State.cats[id].outfit)));
   app.UI.OpenCare(0);yield return Frames(3);yield return Screenshot("care-outfit");app.UI.Back();
   caseName="wardrobe-1280x800";checks=new JArray();current=new JObject{{"case",caseName},{"checks",checks}};cases.Add(current);
   Screen.SetResolution(1280,800,FullScreenMode.Windowed);yield return new WaitForSecondsRealtime(.6f);app.UI.ConfigureAcceptanceLayout(new Rect(0,0,1280,800),1);
   app.UI.OpenCare(0);yield return Frames(3);yield return Screenshot("care-outfit");app.UI.Back();app.UI.Navigate("Hotel");app.World.FitHotel();yield return Frames(5);yield return Screenshot("roaming");
  }
 }
}