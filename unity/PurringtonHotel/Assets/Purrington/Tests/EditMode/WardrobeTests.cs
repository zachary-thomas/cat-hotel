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
  Assert.AreEqual(12,Wardrobe.All.Length);
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
    Assert.That(tie.localPosition.z,Is.GreaterThan(0));
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
}
