using System.Collections.Generic;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class WardrobeTests {
 [Test] public void WardrobeContentLoadsFromResources() {
  var asset=Resources.Load<TextAsset>("Content/Wardrobe");
  Assert.IsNotNull(asset);
  Wardrobe.LoadJson(asset.text);
  Assert.AreEqual(19,Wardrobe.All.Length); // 13 plus six neighbor best-friend gifts
 }

 [Test] public void OutfitPiecesSitOnTheirAnchorsAndClearAway() {
  Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
  using(var geometry=new GodotGeometry()) {
   var parent=new GameObject("Rig parent").transform;
   try {
    var rig=new GodotCatRig(geometry,parent,"cats","0",0);
    CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{"head","sun_hat"},{"neck","bow_tie"}});
    var hat=rig.Bindings["head"].Find("Wear_head");
    Assert.IsNotNull(hat);
    Assert.AreEqual(3,hat.childCount);
    Assert.That(hat.localPosition.y,Is.GreaterThan(.15f));
    var tie=rig.Bindings["body"].Find("Wear_neck");
    Assert.IsNotNull(tie);
    Assert.AreEqual(3,tie.childCount);
    Assert.That(tie.localPosition.z,Is.GreaterThan(.5f),"Tie clears the head and sits below the chin");
    Assert.That(hat.GetChild(0).localScale.x,Is.GreaterThan(.7f),"Hat brim uses the head core mesh width");
    Assert.That(hat.localPosition.y,Is.LessThan(rig.Bindings["ears.0"].localPosition.y+.15f),"Hat brim stays between the ears");
    CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>());
    Assert.IsNull(rig.Bindings["head"].Find("Wear_head"));
    Assert.IsNull(rig.Bindings["body"].Find("Wear_neck"));
   } finally {Object.DestroyImmediate(parent.gameObject);}
  }
 }

 [Test] public void ReplacedAndClearedWearStopsRenderingImmediately() {
  Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);
  using(var geometry=new GodotGeometry()) {
   var parent=new GameObject("Outfit replacement").transform;
   try {
    var rig=new GodotCatRig(geometry,parent,"cats","0",0);
    CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{"head","sun_hat"},{"neck","bow_tie"}});
    var oldHat=rig.Bindings["head"].Find("Wear_head");
    var oldTie=rig.Bindings["body"].Find("Wear_neck");
    CatOutfitView.Apply(geometry,rig,new Dictionary<string,string>{{"head","beanie"}});
    Assert.IsNotNull(rig.Bindings["head"].Find("Wear_head"));
    Assert.IsNull(rig.Bindings["body"].Find("Wear_neck"));
    // EditMode destroys immediately; Play mode retains the old roots until frame end.
    if(Application.isPlaying) {
     Assert.IsFalse(oldHat.gameObject.activeSelf);
     Assert.IsFalse(oldTie.gameObject.activeSelf);
    } else {
     Assert.IsTrue(oldHat==null);
     Assert.IsTrue(oldTie==null);
    }
   } finally {Object.DestroyImmediate(parent.gameObject);}
  }
 }

 [Test] public void OutfitSignatureChangesOnlyWhenAnEquippedSlotChanges() {
  var outfit=new Dictionary<string,string>{{"head","sun_hat"}};
  var initial=CatOutfitView.Signature(outfit);
  outfit["neck"]="bow_tie";
  Assert.AreNotEqual(initial,CatOutfitView.Signature(outfit));
  outfit.Remove("neck");
  Assert.AreEqual(initial,CatOutfitView.Signature(outfit));
 }
}
