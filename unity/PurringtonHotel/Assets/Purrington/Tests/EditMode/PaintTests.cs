using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

public sealed class PaintTests {
 [Test] public void TintsRehueColorfulPartsOnly() {
  float rose=Paint.TintHues[1]/360f;
  Assert.AreEqual("#D2AD77ff",VoxelWorld.TintColor("#D2AD77ff",rose),"wood keeps its color");
  Assert.AreEqual("#F8F3E3ff",VoxelWorld.TintColor("#F8F3E3ff",rose),"neutrals keep their color");
  var tinted=VoxelWorld.TintColor("#5C8FD6ff",rose);
  Assert.AreNotEqual("#5C8FD6ff",tinted);
  Assert.IsTrue(tinted.EndsWith("ff"),"alpha survives");
  ColorUtility.TryParseHtmlString(tinted,out var c);Color.RGBToHSV(c,out float h,out _,out _);
  Assert.AreEqual(rose,h,.02f,"blue turns rose");
 }
 [Test] public void EverySwatchHasAHouseStyleFirst() {
  Assert.AreEqual("",Paint.Walls[0].id);Assert.AreEqual("",Paint.Floors[0].id);
  Assert.AreEqual(Paint.Tints.Length,Paint.TintHues.Length);
 }
}
