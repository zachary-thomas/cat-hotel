using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests {
 // Phase B: lamp lights, voxel particles and tweens.
 public sealed class WorldJuiceTests {
  sealed class MemoryStore:ISaveStore {HotelState state;public HotelState Load()=>state==null?null:HotelModel.Copy(state);public bool Save(HotelState value){state=HotelModel.Copy(value);return true;}}
  GameObject root;
  [SetUp] public void Setup(){ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);TownContent.LoadJson(Resources.Load<TextAsset>("Content/MainStreet").text);Wardrobe.LoadJson(Resources.Load<TextAsset>("Content/Wardrobe").text);root=new GameObject("juice test");Tween.Reduced=false;}
  [TearDown] public void Cleanup(){Object.DestroyImmediate(root);Tween.Reduced=false;}

  [Test] public void LampsLightOnlyAfterDuskAndStayWithinBudget(){
   var model=new HotelModel(new MemoryStore(),ParityContent.Current);Assert.IsTrue(model.LoadOrCreate().success);
   var world=root.AddComponent<VoxelWorld>();world.Initialize(model);
   Assert.That(LampAnchorCount(),Is.GreaterThan(0),"starter lamps and garden lamps are light sources");
   typeof(VoxelWorld).GetMethod("UpdateCamera",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(world,null);
   world.Lamps.Refresh(0);Assert.AreEqual(0,world.Lamps.Lit,"no lamp lights by day");
   world.Lamps.Refresh(.9f);Assert.That(world.Lamps.Lit,Is.InRange(1,WorldLamps.Budget),"the nearest lamps light up at night, capped for mobile");
   Assert.That(world.Lamps.transform.Find("Lamp lights").GetComponentsInChildren<Light>().Count(l=>l.enabled),Is.EqualTo(world.Lamps.Lit));
  }
  static int LampAnchorCount()=>Object.FindObjectsByType<LampAnchor>(FindObjectsSortMode.None).Length;

  [Test] public void LanternSwatchGlowsLikeWindowGlass(){
   using(var geometry=new GodotGeometry()){
    Assert.IsTrue(geometry.Material(SurfacePalette.LanternGlow).IsKeywordEnabled("_EMISSION"));
    Assert.IsFalse(geometry.Material("738448").IsKeywordEnabled("_EMISSION"));
   }
  }

  [Test] public void EffectsEmitOnlyWithMotionOn(){
   using(var geometry=new GodotGeometry()){
    var fx=new VoxelFx(geometry,root.transform);
    fx.Motion=false;fx.Hearts(Vector3.zero);fx.Coins(Vector3.zero);Assert.AreEqual(0,fx.Live,"reduced motion keeps effects off");
    fx.Motion=true;fx.Hearts(Vector3.zero,3);fx.Coins(Vector3.zero,5);Assert.AreEqual(8,fx.Live);
    var petals=fx.Root.Find("Blossom petals").GetComponent<ParticleSystem>();var fireflies=fx.Root.Find("Fireflies").GetComponent<ParticleSystem>();
    fx.Ambient(Vector3.zero,0,true);Assert.That(petals.emission.rateOverTime.constant,Is.GreaterThan(0));Assert.AreEqual(0,fireflies.emission.rateOverTime.constant);
    fx.Ambient(Vector3.zero,1,true);Assert.AreEqual(0,petals.emission.rateOverTime.constant);Assert.That(fireflies.emission.rateOverTime.constant,Is.GreaterThan(0));
    fx.Ambient(Vector3.zero,1,false);Assert.AreEqual(0,fireflies.emission.rateOverTime.constant,"no fireflies indoors");
   }
  }

  [Test] public void ForestSwapsPetalsForLeavesAndDustDriftsOnlyByDay(){
   using(var geometry=new GodotGeometry()){
    var fx=new VoxelFx(geometry,root.transform);
    float Rate(string name)=>fx.Root.Find(name).GetComponent<ParticleSystem>().emission.rateOverTime.constant;
    fx.Ambient(Vector3.zero,0,true);Assert.AreEqual(0,Rate("Autumn leaves"));Assert.That(Rate("Dust motes"),Is.GreaterThan(0));
    fx.Ambient(Vector3.zero,0,true,true);Assert.AreEqual(0,Rate("Blossom petals"));Assert.That(Rate("Autumn leaves"),Is.GreaterThan(0));
    fx.Ambient(Vector3.zero,1,true);Assert.AreEqual(0,Rate("Dust motes"),"no dust motes at night");
    fx.Motion=false;fx.Ambient(Vector3.zero,0,true,true);Assert.AreEqual(0,Rate("Autumn leaves"));Assert.AreEqual(0,Rate("Dust motes"));
   }
  }

  [Test] public void IncomePopsShowTheEarnedAmountAndRespectReducedMotion(){
   using(var geometry=new GodotGeometry()){
    var fx=new VoxelFx(geometry,root.transform);
    fx.Motion=false;fx.Pop(Vector3.zero,"+5");Assert.IsNull(fx.Root.Find("Income pops"),"reduced motion shows no pops");
    fx.Motion=true;for(int i=0;i<6;i++)fx.Pop(Vector3.up,"+"+(10+i));
    var labels=fx.Root.GetComponentsInChildren<TMPro.TextMeshProUGUI>(true).Where(l=>l.transform.parent.name=="Income pop").ToArray();
    Assert.AreEqual(4,labels.Length,"pop labels are pooled");Assert.That(labels.Select(l=>l.text),Does.Contain("+15"));
    Assert.AreEqual(0,fx.ActivePops,"outside Play mode a pop finishes at once");
   }
  }

  [Test] public void TweensSnapToTheirEndStateOutsidePlayModeOrWithReducedMotion(){
   var t=new GameObject("tweened").transform;t.SetParent(root.transform);t.localScale=Vector3.one*2;
   Tween.Settle(t);Assert.That(t.localScale,Is.EqualTo(Vector3.one*2));
   Tween.Reduced=true;Tween.Punch(t);Assert.That(t.localScale,Is.EqualTo(Vector3.one*2));
   float seen=-1;Tween.Run(t,1,k=>seen=k);Assert.AreEqual(1,seen);
  }
 }
}
