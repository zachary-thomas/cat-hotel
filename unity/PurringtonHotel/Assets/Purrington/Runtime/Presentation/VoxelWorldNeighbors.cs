using System;
using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;
namespace Purrington.Presentation {
 // Meadow neighbors on Main Street. Their positions come from the model every frame; the rigs only animate.
 public sealed partial class VoxelWorld {
  public const string NeighborPickPrefix="neighbor:";
  readonly Dictionary<string,GodotCatRig> neighborRigs=new Dictionary<string,GodotCatRig>();
  readonly Dictionary<string,string> neighborOutfits=new Dictionary<string,string>();
  public event Action<string,Vector2> NeighborTapped;
  public int VisibleNeighborCount=>neighborRigs.Values.Count(r=>r.Root.gameObject.activeSelf);
  void SyncNeighbors(float delta){
   var content=NeighborContent.Current;
   if(content==null)return;
   bool shown=currentMap==0&&(storeInterior==null||!storeInterior.IsVisible);
   var views=shown?model.NeighborViews:Array.Empty<NeighborView>();
   var chat=model.CurrentChat;
   foreach(var n in content.Neighbors){
    var view=views.FirstOrDefault(v=>v.id==n.id);
    if(!neighborRigs.TryGetValue(n.id,out var rig)){
     if(view==null||!view.present)continue;
     rig=new GodotCatRig(geometry,renderRoot,ManagerCatArt.Recipe(geometry,n.coat,n.markings),300+Array.IndexOf(content.Neighbors,n));
     rig.Root.name="Neighbor "+n.name;rig.Root.localScale=Vector3.one*.83f;
     var collider=rig.Root.gameObject.AddComponent<BoxCollider>();collider.center=new Vector3(0,.6f,0);collider.size=new Vector3(.95f,1.3f,1.15f);
     rig.Root.gameObject.AddComponent<WorldPick>().objectId=NeighborPickPrefix+n.id;
     neighborRigs[n.id]=rig;
    }
    bool present=view!=null&&view.present;
    rig.Root.gameObject.SetActive(present);
    if(!present)continue;
    var col=rig.Root.GetComponent<BoxCollider>();if(col)col.enabled=lifeControl;
    // Best friends wear the gift they gave you, so the friendship shows on the street.
    string outfit=view.tier>=3&&model.NeighborTierClaimed(n.id)>=3?n.bestGift:"";
    if(!neighborOutfits.TryGetValue(n.id,out var worn)||worn!=outfit){
     var wear=Wardrobe.Find(outfit);var dress=new Dictionary<string,string>();if(wear!=null)dress[wear.slot]=wear.id;
     CatOutfitView.Apply(geometry,rig,dress);neighborOutfits[n.id]=outfit;
    }
    rig.Root.localPosition=new Vector3(view.position.x*Unit,GroundY,view.position.z*Unit);
    bool talking=chat!=null&&chat.neighbor==n.id;
    float facing=view.facing;
    if(talking){var m=model.ManagerPosition;float dx=m.x-view.position.x,dz=m.z-view.position.z;if(dx*dx+dz*dz>.0001f)facing=Mathf.Atan2(dx,dz);}
    var turn=Quaternion.Euler(0,facing*Mathf.Rad2Deg,0);
    rig.Root.localRotation=Quaternion.Slerp(rig.Root.localRotation,turn,Mathf.Clamp01(delta*8));
    bool walking=view.walking&&!talking;
    // Nap-a-thon attendees nap until you talk to them.
    bool napping=!talking&&model.PlazaEventId=="nap_a_thon"&&model.PlazaAttendees.Contains(n.id);
    rig.Advance(delta,model.State.settings.motion,walking?"walk":napping?"sleep":"rest",walking,talking?"talk":"");
   }
  }
  public bool NeighborHeadScreen(string id,out Vector2 screen){
   screen=default;
   if(id==null||!neighborRigs.TryGetValue(id,out var rig)||!rig.Root.gameObject.activeInHierarchy)return false;
   var p=WorldCamera.WorldToScreenPoint(rig.Root.position+Vector3.up*1.25f);
   if(p.z<=0)return false;screen=p;return true;
  }
  public void NeighborReaction(string id,string reaction){
   if(fx==null||!neighborRigs.TryGetValue(id,out var rig))return;
   if(reaction=="love")fx.Hearts(rig.Root.position+Vector3.up*1.1f,6);else if(reaction=="like")fx.Hearts(rig.Root.position+Vector3.up*1.1f,2);
  }
 }
}
