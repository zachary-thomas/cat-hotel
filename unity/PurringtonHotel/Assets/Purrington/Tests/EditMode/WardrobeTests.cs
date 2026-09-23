using System.Collections.Generic;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
public sealed class WardrobeTests {
 [Test]public void WardrobeContentLoadsFromResources(){var content=Resources.Load<TextAsset>("Content/Wardrobe");Assert.IsNotNull(content);Wardrobe.LoadJson(content.text);Assert.AreEqual(12,Wardrobe.All.Length);}
 [Test]public void OutfitPiecesFollowTheirAnchorsAndClearAway(){
  Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
  using(var geometry=new GodotGeometry()){var parent=new GameObject("Rig parent").transform;try{
   var rig=new GodotCatRig(geometry,parent,"cats","0",0);
   CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{"head","sun_hat"},{"neck","bow_tie"}});
   var hat=rig.Bindings["head"].Find("Wear_head");Assert.IsNotNull(hat);Assert.AreEqual(3,hat.childCount);
   var tie=rig.Bindings["body"].Find("Wear_neck");Assert.IsNotNull(tie);Assert.AreEqual(3,tie.childCount);
   Assert.Greater(tie.localPosition.z,0,"Miso's face is along the body's positive Z axis");
   Assert.Greater(tie.localPosition.z,.5f,"Tie must clear the head and sit visibly below Miso's chin");
   Assert.Greater(hat.GetChild(0).localScale.x,.7f,"Hat brim uses the head core mesh width");
   Assert.Less(hat.localPosition.y,rig.Bindings["ears.0"].localPosition.y+.15f,"Hat brim stays between Miso's ears");
   CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>());
   Assert.IsNull(rig.Bindings["head"].Find("Wear_head"));Assert.IsNull(rig.Bindings["body"].Find("Wear_neck"));
  }finally{Object.DestroyImmediate(parent.gameObject);}}}
 [Test]public void OutfitSignatureChangesOnlyWhenAnEquippedSlotChanges(){
  var outfit=new Dictionary<string,string>{{"head","sun_hat"}};var initial=CatOutfitView.Signature(outfit);
  outfit["neck"]="bow_tie";Assert.AreNotEqual(initial,CatOutfitView.Signature(outfit));
  outfit.Remove("neck");Assert.AreEqual(initial,CatOutfitView.Signature(outfit));
 }
}
}
