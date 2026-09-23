using System.Linq;using NUnit.Framework;using Purrington.Domain;using Purrington.Presentation;using UnityEngine;
namespace Purrington.Tests {
public sealed class LivingColorTests {
 [Test]public void ToneVariantIsStablePerPositionAndAtMostThreePerColor(){using(var g=new GodotGeometry()){var a=g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f));Assert.AreSame(a,g.Material("#fff8e9ff",new Vector3(1.2f,0,3.4f)));var set=Enumerable.Range(0,60).Select(i=>g.Material("#fff8e9ff",new Vector3(i,0,i*2))).Distinct().ToArray();Assert.AreEqual(3,set.Length);}}
 [Test]public void PlainOverloadIsTheBaseTone(){using(var g=new GodotGeometry()){Assert.AreEqual(ConceptTheme.Surface("fff8e9"),g.Material("#fff8e9ff").color);}}
 [Test]public void GlassAndWaterNeverVary(){using(var g=new GodotGeometry()){var set=Enumerable.Range(0,30).Select(i=>g.Material("90bfc0",new Vector3(i,0,i*3))).Distinct().ToArray();Assert.AreEqual(1,set.Length);}}
 [Test]public void GlowReachesExistingAndLaterGlassMaterials(){using(var g=new GodotGeometry()){var early=g.Material("90bfc0");g.SetGlow(2.2f);var late=g.Material("b5ddcf");foreach(var m in new[]{early,late}){Assert.IsTrue(m.IsKeywordEnabled("_EMISSION"));Assert.Greater(m.GetColor("_EmissionColor").maxColorComponent,1f);}g.SetGlow(0);Assert.AreEqual(0f,early.GetColor("_EmissionColor").maxColorComponent,1e-4f);Assert.IsFalse(g.Material("fff8e9").IsKeywordEnabled("_EMISSION"));}}
}
}
