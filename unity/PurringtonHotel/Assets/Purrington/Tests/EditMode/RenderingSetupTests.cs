using System.Linq;using NUnit.Framework;using UnityEditor;using UnityEngine.Rendering;using UnityEngine.Rendering.Universal;
namespace Purrington.Tests {
public sealed class RenderingSetupTests {
 [Test]public void GradingIsHighKeyPastel(){var p=AssetDatabase.LoadAssetAtPath<VolumeProfile>("Assets/Resources/ParityGrading.asset");Assert.IsNotNull(p);
  Assert.IsTrue(p.TryGet<ColorAdjustments>(out var c));Assert.AreEqual(30f,c.saturation.value,1e-3f);Assert.AreEqual(16f,c.contrast.value,1e-3f);
  Assert.IsTrue(p.TryGet<Bloom>(out var b)&&b.active);Assert.AreEqual(1f,b.threshold.value,1e-3f);Assert.AreEqual(.4f,b.intensity.value,1e-3f);Assert.AreEqual(.7f,b.scatter.value,1e-3f);Assert.IsFalse(b.highQualityFiltering.value);
  Assert.IsTrue(p.TryGet<SplitToning>(out var s)&&s.active);Assert.AreEqual(0f,s.balance.value,1e-3f);
  Assert.IsTrue(p.TryGet<LiftGammaGain>(out var l)&&l.active);Assert.Greater(l.lift.value.w,0f);Assert.Less(l.lift.value.w,.02f,"a strong lift washes the world out");
  Assert.IsTrue(p.TryGet<WhiteBalance>(out _));Assert.IsFalse(p.TryGet<Vignette>(out _));
  Assert.IsTrue(p.TryGet<Tonemapping>(out var t));Assert.AreEqual(TonemappingMode.Neutral,t.mode.value);}
 [Test]public void GlowTemplateKeepsTheEmissionVariant(){var m=AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/Resources/WorldGlowMaterial.mat");Assert.IsNotNull(m,"run tools/unity.ps1 Rendering");Assert.AreEqual("Universal Render Pipeline/Lit",m.shader.name);
  Assert.IsTrue(m.IsKeywordEnabled("_EMISSION"));Assert.IsTrue(m.enableInstancing);Assert.AreEqual(UnityEngine.MaterialGlobalIlluminationFlags.RealtimeEmissive,m.globalIlluminationFlags,"URP clears _EMISSION on reimport unless a flag is emissive");StringAssert.Contains("- _EMISSION",System.IO.File.ReadAllText("Assets/Resources/WorldGlowMaterial.mat"),"the serialized asset must keep the keyword");Assert.AreEqual(0f,m.GetColor("_EmissionColor").maxColorComponent,1e-4f);}
 [Test]public void MobileRendererHasDownsampledSsao(){var r=AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/Settings/Mobile_Renderer.asset");var ssao=r.rendererFeatures.FirstOrDefault(f=>f!=null&&f.GetType().Name=="ScreenSpaceAmbientOcclusion");Assert.IsNotNull(ssao,"mobile SSAO feature");Assert.IsTrue(ssao.isActive);
  var data=new SerializedObject(ssao);Assert.IsTrue(data.FindProperty("m_Settings.Downsample").boolValue);Assert.AreEqual(.4f,data.FindProperty("m_Settings.Intensity").floatValue,1e-3f);}
}
}
