using System.Linq;using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class LivingColorTests {
 [Test]public void ToneVariantIsStablePerPositionAndAtMostThreePerColor(){using(var g=new GodotGeometry()){var a=g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f));Assert.AreSame(a,g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f)));var set=Enumerable.Range(0,60).Select(i=>g.Material("#fff8e9ff",new Vector3(i,0,i*2))).Distinct().ToArray();Assert.AreEqual(3,set.Length);}}
 [Test]public void PlainOverloadIsTheBaseTone(){using(var g=new GodotGeometry()){Assert.AreEqual(ConceptTheme.Surface("fff8e9"),g.Material("#fff8e9ff").color);}}
 [Test]public void GlassAndWaterNeverVary(){using(var g=new GodotGeometry()){var set=Enumerable.Range(0,30).Select(i=>g.Material("90bfc0",new Vector3(i,0,i*3))).Distinct().ToArray();Assert.AreEqual(1,set.Length);}}
 [Test]public void GlowReachesExistingAndLaterGlassMaterials(){using(var g=new GodotGeometry()){var early=g.Material("90bfc0");g.SetGlow(2.2f);var late=g.Material("b5ddcf");foreach(var m in new[]{early,late}){Assert.IsTrue(m.IsKeywordEnabled("_EMISSION"));Assert.Greater(m.GetColor("_EmissionColor").maxColorComponent,1f);}g.SetGlow(0);Assert.AreEqual(0f,early.GetColor("_EmissionColor").maxColorComponent,1e-4f);Assert.IsFalse(g.Material("fff8e9").IsKeywordEnabled("_EMISSION"));}}
 // C1: builds keep URP Lit's _EMISSION variant only through WorldGlowMaterial, so glass and lamp twins must be cloned from it.
 [Test]public void GlassAndLampTwinsCloneTheGlowTemplate(){var template=Resources.Load<Material>("WorldGlowMaterial");Assert.IsNotNull(template,"Resources/WorldGlowMaterial.mat is missing: run tools/unity.ps1 Rendering");Assert.IsTrue(template.IsKeywordEnabled("_EMISSION"));
  using(var g=new GodotGeometry()){var glass=g.Material("90bfc0");Assert.AreSame(template.shader,glass.shader);Assert.IsTrue(glass.IsKeywordEnabled("_EMISSION"));Assert.IsTrue(glass.enableInstancing);Assert.AreEqual(ConceptTheme.Surface("90bfc0"),glass.color);
   var body=g.Material("fff8e9");var twin=g.GlowTwin(body);Assert.AreNotSame(body,twin);Assert.AreSame(twin,g.GlowTwin(body));Assert.IsTrue(twin.IsKeywordEnabled("_EMISSION"));Assert.AreEqual(body.color,twin.color);Assert.AreEqual(0f,twin.GetColor("_EmissionColor").maxColorComponent,1e-4f);Assert.IsFalse(body.IsKeywordEnabled("_EMISSION"));}}
 [Test]public void SmallGlowStepsAreSkippedButZeroAlwaysLands(){using(var g=new GodotGeometry()){var glass=g.Material("90bfc0");g.SetGlow(1f);float at=glass.GetColor("_EmissionColor").maxColorComponent;g.SetGlow(1.005f);Assert.AreEqual(at,glass.GetColor("_EmissionColor").maxColorComponent,1e-5f);g.SetGlow(.005f);g.SetGlow(0);Assert.AreEqual(0f,glass.GetColor("_EmissionColor").maxColorComponent,1e-5f);}}
 // I1: WorldLighting drives a deep copy of the grading profile, never ParityGrading.asset's own components.
 [Test]public void LightingOverridesACopyOfTheGradingProfile(){
  var asset=Resources.Load<UnityEngine.Rendering.VolumeProfile>("ParityGrading");Assert.IsNotNull(asset);Assert.IsTrue(asset.TryGet<UnityEngine.Rendering.Universal.ColorAdjustments>(out var shared));float exposure=shared.postExposure.value;
  var volume=new GameObject("volume").AddComponent<UnityEngine.Rendering.Volume>();volume.isGlobal=true;volume.sharedProfile=asset;var host=new GameObject("lighting");
  try{var lighting=host.AddComponent<WorldLighting>();lighting.Initialize(null,null,null);Assert.IsTrue(volume.profile.TryGet<UnityEngine.Rendering.Universal.ColorAdjustments>(out var driven));Assert.AreNotSame(shared,driven);
   lighting.Pin(720);Assert.AreEqual(0f,WorldLighting.Glow,1e-4f);lighting.Pin(1380);Assert.AreEqual(1f,WorldLighting.Glow,1e-4f);Assert.AreEqual(exposure,shared.postExposure.value,1e-5f);
  }finally{var copy=volume.HasInstantiatedProfile()?volume.profile:null;if(copy!=null){foreach(var c in copy.components)Object.DestroyImmediate(c);Object.DestroyImmediate(copy);}Object.DestroyImmediate(host);Object.DestroyImmediate(volume.gameObject);}}
 [Test]public void ApplyToSetsTrilightSunAndBackground(){
  var cycle=DayCycle.Parse(Resources.Load<TextAsset>("Content/DayCycle").text);
  var sun=new GameObject("sun").AddComponent<Light>();var cam=new GameObject("cam").AddComponent<Camera>();
  try{
   WorldLighting.ApplyTo(sun,cam,cycle.Evaluate(750));
   Assert.AreEqual(UnityEngine.Rendering.AmbientMode.Trilight,RenderSettings.ambientMode);Assert.AreEqual(.58f,sun.shadowStrength,1e-3f);Assert.AreEqual(1.2f,sun.intensity,1e-3f);
   var day=cam.backgroundColor;WorldLighting.ApplyTo(sun,cam,cycle.Evaluate(1380));Assert.Less(cam.backgroundColor.grayscale,day.grayscale);Assert.Less(sun.intensity,.4f);
  }finally{Object.DestroyImmediate(sun.gameObject);Object.DestroyImmediate(cam.gameObject);}}
}
}
